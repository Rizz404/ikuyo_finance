# Auto Transaction — Implementation Plan

## Referensi Pola Kode

Seluruh implementasi mengikuti pola yang ada di `lib/features/transaction/`:
- **Entity**: `@Entity()` + `@Id() int id` + `@Unique() String ulid` + `ToOne<T>` + `createdAt/updatedAt`
- **Repository**: `abstract class` + `TaskEither<Failure, Success<T>>` (fpdart)
- **BLoC**: `sealed class` events, `Equatable` state, status enum terpisah untuk read & write
- **DI**: `registerLazySingleton` untuk repository, `registerFactory` untuk BLoC di `lib/di/`
- **Router**: `GoRoute` + `AppRoutes` + `AppNavigator` extension

---

## Packages Baru

Jalankan di root project:
```bash
flutter pub add workmanager
flutter pub add flutter_local_notifications
flutter pub add timezone
```

Platform setup tambahan:
- **Android**: `AndroidManifest.xml` — tambah `RECEIVE_BOOT_COMPLETED`, `SCHEDULE_EXACT_ALARM` permissions + `BroadcastReceiver` untuk Workmanager
- **iOS**: `AppDelegate.swift` — setup `UNUserNotificationCenter`

---

## Urutan Implementasi

```
Phase 1: Foundation (Models + ObjectBox)
Phase 2: Repository Layer
Phase 3: Scheduler Service
Phase 4: Notification Service
Phase 5: BLoC Layer
Phase 6: DI + Router
Phase 7: Platform Config
Phase 8: UI Layer (Screens + Widgets)
```

> UI dibuat terakhir karena membutuhkan BLoC yang sudah ter-inject (Phase 6),
> permission yang sudah dikonfigurasi (Phase 7), dan semua service yang sudah tersedia.

---

## Phase 1 — Models & ObjectBox Entities

### Files yang dibuat

**`lib/features/auto_transaction/models/auto_schedule_frequency.dart`**
```dart
enum AutoScheduleFrequency { daily, weekly, monthly, yearly }
```

**`lib/features/auto_transaction/models/auto_transaction_log_status.dart`**
```dart
enum AutoTransactionLogStatus { success, partial, failed, skipped }
```

**`lib/features/auto_transaction/models/auto_transaction_group.dart`**
- `@Entity()` class sesuai desain
- Relasi: `items = ToMany<AutoTransactionItem>` (backlink), `logs = ToMany<AutoTransactionLog>` (backlink)
- Helper method: `isCurrentlyPaused()` → bool

**`lib/features/auto_transaction/models/auto_transaction_item.dart`**
- `@Entity()` class
- Tidak menduplikasi field transaksi — cukup referensi ke template
- Relasi: `transaction = ToOne<Transaction>` (template), `group = ToOne<AutoTransactionGroup>`
- Fields: `isActive`, `sortOrder`, `createdAt`, `updatedAt`

**`lib/features/auto_transaction/models/auto_transaction_log.dart`**
- `@Entity()` class
- Relasi: `group = ToOne<AutoTransactionGroup>`

### Setelah selesai: jalankan
```bash
dart run build_runner build --delete-conflicting-outputs
```
Ini meregenerasi `objectbox.g.dart` dan `objectbox-model.json`.

---

## Phase 2 — Repository Layer

### Structure
```
lib/features/auto_transaction/repositories/
├── auto_transaction_repository.dart        ← abstract
└── auto_transaction_repository_impl.dart   ← ObjectBox impl
```

### Abstract interface
```dart
abstract class AutoTransactionRepository {
  // * Group CRUD
  TaskEither<Failure, Success<AutoTransactionGroup>> createGroup(CreateAutoGroupParams params);
  TaskEither<Failure, Success<AutoTransactionGroup>> updateGroup(UpdateAutoGroupParams params);
  TaskEither<Failure, ActionSuccess> deleteGroup({required String ulid});
  TaskEither<Failure, Success<List<AutoTransactionGroup>>> getGroups();
  TaskEither<Failure, Success<AutoTransactionGroup>> getGroupByUlid({required String ulid});

  // * Item CRUD
  TaskEither<Failure, Success<AutoTransactionItem>> createItem(CreateAutoItemParams params);
  TaskEither<Failure, Success<AutoTransactionItem>> updateItem(UpdateAutoItemParams params);
  TaskEither<Failure, ActionSuccess> deleteItem({required String ulid});
  TaskEither<Failure, Success<List<AutoTransactionItem>>> getItemsByGroup({required String groupUlid});

  // * Pause management
  TaskEither<Failure, ActionSuccess> pauseGroup({required String ulid, DateTime? resumeAt});
  TaskEither<Failure, ActionSuccess> resumeGroup({required String ulid});

  // * Scheduler operations
  TaskEither<Failure, Success<List<AutoTransactionGroup>>> getPendingGroups();  // nextExecutedAt ≤ now
  TaskEither<Failure, ActionSuccess> saveExecutionLog(AutoTransactionLog log);
  TaskEither<Failure, Success<List<AutoTransactionLog>>> getLogsByGroup({required String groupUlid});
}
```

### Impl notes
- `getPendingGroups()` → query `isActive == true` + `nextExecutedAt.lessOrEqual(now)`
- Gunakan `TransactionRepository` (inject) untuk `createManyTransactions()` saat eksekusi — jangan duplikasi logika balance update
- `createGroup()` → hitung `nextExecutedAt` awal sebelum simpan
- `createItem(params)` → params hanya butuh `groupUlid`, `transactionUlid`, `sortOrder`; scheduler baca `item.transaction.target` saat eksekusi
- Jika `item.transaction.target == null` saat eksekusi → skip item, catat error di log

### Params models
```
lib/features/auto_transaction/models/
├── create_auto_group_params.dart
├── update_auto_group_params.dart
├── create_auto_item_params.dart    ← groupUlid, transactionUlid, sortOrder
└── update_auto_item_params.dart    ← ulid, sortOrder, isActive
```

---

## Phase 3 — Scheduler Service

**`lib/features/auto_transaction/services/auto_transaction_scheduler.dart`**

Ini adalah "otak" fitur. Bertanggung jawab atas:

```dart
class AutoTransactionScheduler {
  final AutoTransactionRepository _repo;
  final TransactionRepository _transactionRepo;

  /// * Entry point — dipanggil dari Workmanager callback dan on-app-open
  Future<void> runPendingExecutions();

  /// * Hitung scheduledTime berikutnya dari referensi waktu
  DateTime calculateNextExecution(AutoTransactionGroup group, DateTime from);

  /// * Eksekusi 1 "tick" untuk 1 grup
  Future<AutoTransactionLog> _executeGroup(
    AutoTransactionGroup group,
    DateTime scheduledAt,
  );

  /// * Bangun list CreateTransactionParams dari items aktif
  /// * Membaca item.transaction.target sebagai template (amount, asset, category, description)
  List<CreateTransactionParams> _buildParams(
    List<AutoTransactionItem> items,
    DateTime transactionDate,
  );
}
```

### Logika `runPendingExecutions()`
```
pendingGroups = repo.getPendingGroups()
for each group:
  if group.isCurrentlyPaused():
    if pauseEndAt != null && pauseEndAt ≤ now:
      auto-resume group
    else:
      simpan log skipped, skip
      continue

  scheduled = group.nextExecutedAt
  window_start = now - 7.days

  while scheduled ≤ now:
    if scheduled < window_start:
      simpan log skipped ("terlewat >7 hari")
      scheduled = calculateNext(group, scheduled)
      continue

    log = await _executeGroup(group, scheduled)
    kirim notifikasi(group, log)
    scheduled = calculateNext(group, scheduled)

  group.nextExecutedAt = scheduled
  group.lastExecutedAt = now
  if group.endDate != null && scheduled > group.endDate:
    group.isActive = false
  repo.save(group)
```

### Helper `calculateNextExecution()`
```
daily   → from + 1 day (same hour:minute)
weekly  → from + 7 days
monthly → next occurrence of dayOfMonth (bulan depan jika hari sudah lewat)
yearly  → next occurrence of monthOfYear/dayOfMonth (tahun depan jika sudah lewat)
```
Gunakan package `timezone` untuk konsistensi lokal.

---

## Phase 4 — Notification Service

**`lib/features/auto_transaction/services/auto_transaction_notification_service.dart`**

```dart
class AutoTransactionNotificationService {
  final FlutterLocalNotificationsPlugin _plugin;

  Future<void> initialize();
  Future<void> requestPermission(); // Android 13+ & iOS
  Future<void> showExecutionResult(AutoTransactionGroup group, AutoTransactionLog log);
}
```

- Channel IDs: `auto_tx_success`, `auto_tx_warning`, `auto_tx_error`
- Payload: group ulid → diparse saat user tap notifikasi → navigate ke log screen
- Setup di `main.dart`: `NotificationService.initialize()` + handle background tap

---

## Phase 5 — BLoC Layer

> Setelah Phase 5 selesai, lanjut ke Phase 6 (DI + Router) dan Phase 7 (Platform Config) sebelum membuat UI.

```
lib/features/auto_transaction/bloc/
├── auto_transaction_bloc.dart
├── auto_transaction_event.dart
└── auto_transaction_state.dart
```

### Events (sealed class)
```dart
// * Group operations
final class AutoGroupFetched extends AutoTransactionEvent
final class AutoGroupCreated extends AutoTransactionEvent { CreateAutoGroupParams params }
final class AutoGroupUpdated extends AutoTransactionEvent { UpdateAutoGroupParams params }
final class AutoGroupDeleted extends AutoTransactionEvent { String ulid }
final class AutoGroupToggled extends AutoTransactionEvent { String ulid; bool isActive }
final class AutoGroupPaused extends AutoTransactionEvent { String ulid; DateTime? resumeAt }
final class AutoGroupResumed extends AutoTransactionEvent { String ulid }

// * Item operations
final class AutoItemsFetched extends AutoTransactionEvent { String groupUlid }
final class AutoItemCreated extends AutoTransactionEvent { CreateAutoItemParams params }
final class AutoItemUpdated extends AutoTransactionEvent { UpdateAutoItemParams params }
final class AutoItemDeleted extends AutoTransactionEvent { String ulid }
final class AutoItemToggled extends AutoTransactionEvent { String ulid; bool isActive }
final class AutoItemReordered extends AutoTransactionEvent { String groupUlid; List<String> orderedUlids }

// * Log
final class AutoLogsFetched extends AutoTransactionEvent { String groupUlid }

// * Reset
final class AutoWriteStatusReset extends AutoTransactionEvent
```

### State
```dart
enum AutoTransactionStatus { initial, loading, success, failure }
enum AutoTransactionWriteStatus { initial, loading, success, failure }

class AutoTransactionState extends Equatable {
  final AutoTransactionStatus status;
  final List<AutoTransactionGroup> groups;
  final List<AutoTransactionItem> currentItems;  // items untuk grup yang sedang dibuka
  final List<AutoTransactionLog> currentLogs;
  final AutoTransactionWriteStatus writeStatus;
  final String? errorMessage;
  final String? writeSuccessMessage;
  final String? writeErrorMessage;
}
```

---

## Phase 6 — DI & Router

### `lib/di/repositories.dart`
```dart
..registerLazySingleton<AutoTransactionRepository>(
  () => AutoTransactionRepositoryImpl(getIt<ObjectBoxStorage>(), getIt<TransactionRepository>()),
)
```

### `lib/di/blocs.dart`
```dart
..registerFactory<AutoTransactionBloc>(
  () => AutoTransactionBloc(getIt<AutoTransactionRepository>()),
)
```

### `lib/di/injection.dart`
```dart
// * Inisialisasi Workmanager dan NotificationService di setupDependencies()
await AutoTransactionNotificationService.initialize();
Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
Workmanager().registerPeriodicTask('auto_tx_task', 'autoTransactionTask', frequency: Duration(minutes: 15));
```

### `lib/core/router/app_routes.dart` — tambah route names & paths
```dart
static const autoTransactionName = 'auto-transaction';
static const autoTransactionPath = '/auto-transaction';
// dst...
```

### `lib/core/router/app_router.dart` — tambah `StatefulShellBranch` baru atau tambah ke branch existing

### `lib/core/router/app_navigator.dart` — tambah extension methods
```dart
void goToAutoTransaction() => go(AppRoutes.autoTransactionPath);
void pushToAddAutoGroup() => push(...);
// dst...
```

### `lib/di/commons.dart`
Tambahkan `registerLazySingleton<AutoTransactionNotificationService>(...)` dan `registerLazySingleton<AutoTransactionScheduler>(...)`.

---

## Phase 7 — Platform Config

### Android (`android/app/src/main/AndroidManifest.xml`)
```xml
<!-- Workmanager -->
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
<!-- Notifications -->
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>

<!-- Workmanager BroadcastReceiver (sudah di-handle package, cek apakah perlu manual) -->
```

### iOS (`ios/Runner/AppDelegate.swift`)
```swift
if #available(iOS 10.0, *) {
  UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
}
```

---

## Phase 8 — UI Layer

### Screens

**`lib/features/auto_transaction/screens/`**

| File | Deskripsi |
|---|---|
| `auto_transaction_screen.dart` | List semua grup, dengan toggle aktif/pause per item |
| `auto_transaction_group_upsert_screen.dart` | Form create/edit grup (nama, jadwal, date range, pause range) |
| `auto_transaction_item_list_screen.dart` | List items dalam satu grup, bisa reorder drag |
| `auto_transaction_item_upsert_screen.dart` | Form create/edit item (name, amount, asset, category, type) |
| `auto_transaction_log_screen.dart` | Riwayat eksekusi grup, dengan status badge |

### Widgets

**`lib/features/auto_transaction/widgets/`**

| File | Deskripsi |
|---|---|
| `auto_group_tile.dart` | Card grup dengan info jadwal, badge status, toggle switch |
| `auto_item_tile.dart` | Item tile dengan drag handle — tampil nama dari `item.transaction.target` |
| `auto_log_tile.dart` | Log entry dengan status chip (success/partial/failed/skipped) |
| `schedule_form_section.dart` | Reusable form section untuk input frekuensi + jadwal |
| `pause_form_section.dart` | Reusable form section untuk input pause range |

### Form Scheduler UX
- Pilih frekuensi → tampilkan field relevan secara kondisional:
  - `daily` → hanya time picker
  - `weekly` → time picker + day of week (Mon-Sun chips)
  - `monthly` → time picker + day of month (1-28, dropdown)
  - `yearly` → time picker + month selector + day of month

### Item UX (AutoTransactionItemUpsertScreen)
- User memilih Transaction yang sudah ada (dropdown/search) sebagai template
- Preview otomatis tampilkan: amount, asset, category dari transaction yang dipilih
- Tidak ada form input manual untuk amount/asset/category — semuanya dari template

---

## File Structure Lengkap (Feature Baru)

```
lib/features/auto_transaction/
├── bloc/
│   ├── auto_transaction_bloc.dart
│   ├── auto_transaction_event.dart
│   └── auto_transaction_state.dart
├── models/
│   ├── auto_schedule_frequency.dart
│   ├── auto_transaction_group.dart
│   ├── auto_transaction_item.dart
│   ├── auto_transaction_log.dart
│   ├── auto_transaction_log_status.dart
│   ├── create_auto_group_params.dart
│   ├── create_auto_item_params.dart
│   ├── update_auto_group_params.dart
│   └── update_auto_item_params.dart
├── repositories/
│   ├── auto_transaction_repository.dart
│   └── auto_transaction_repository_impl.dart
├── screens/
│   ├── auto_transaction_screen.dart
│   ├── auto_transaction_group_upsert_screen.dart
│   ├── auto_transaction_item_list_screen.dart
│   ├── auto_transaction_item_upsert_screen.dart
│   └── auto_transaction_log_screen.dart
├── services/
│   ├── auto_transaction_scheduler.dart
│   └── auto_transaction_notification_service.dart
├── translations/
│   ├── auto_transaction_en-US.json
│   └── auto_transaction_id-ID.json
├── validators/
│   ├── create_auto_group_validator.dart
│   └── create_auto_item_validator.dart
└── widgets/
    ├── auto_group_tile.dart
    ├── auto_item_tile.dart
    ├── auto_log_tile.dart
    ├── schedule_form_section.dart
    └── pause_form_section.dart
```

---

## Files yang Dimodifikasi

| File | Perubahan |
|---|---|
| `pubspec.yaml` | Tambah 3 packages baru |
| `lib/di/repositories.dart` | Register `AutoTransactionRepository` |
| `lib/di/blocs.dart` | Register `AutoTransactionBloc` |
| `lib/di/commons.dart` | Init Workmanager + NotificationService |
| `lib/di/injection.dart` | Panggil setup baru |
| `lib/core/router/app_routes.dart` | Tambah route constants |
| `lib/core/router/app_router.dart` | Tambah route definitions |
| `lib/core/router/app_navigator.dart` | Tambah navigation methods |
| `lib/objectbox-model.json` | Auto-update by build_runner |
| `lib/objectbox.g.dart` | Auto-regenerate by build_runner |
| `android/app/src/main/AndroidManifest.xml` | Tambah permissions |
| `ios/Runner/AppDelegate.swift` | Setup notification delegate |
| `lib/main.dart` | Init notification tap handler |

---

## Urutan Pengerjaan yang Disarankan

1. `flutter pub add workmanager flutter_local_notifications timezone`
2. Buat semua model files (Phase 1) → jalankan `build_runner`
3. Buat repository layer (Phase 2)
4. Buat scheduler service (Phase 3)
5. Buat notification service (Phase 4)
6. Buat BLoC (Phase 5)
7. Wire DI & Router (Phase 6)
8. Platform config Android & iOS (Phase 7)
9. Buat UI screens & widgets (Phase 8)
10. Jalankan `dart run tools/merge_translations.dart` setelah translation files dibuat

---

## Notes Teknis

- **ObjectBox query untuk scheduler**: Gunakan `AutoTransactionGroup_.nextExecutedAt.lessOrEqual(now.millisecondsSinceEpoch)` — ObjectBox menyimpan date sebagai int milliseconds
- **Workmanager callback**: Harus top-level function atau static method (`@pragma('vm:entry-point')`)
- **Isolate safety**: Workmanager jalan di isolate terpisah — ObjectBoxStorage harus diinisialisasi ulang di dalam callback, bukan dari `getIt`
- **Balance update**: Selalu delegasikan ke `TransactionRepository.createManyTransactions()` — jangan bypass untuk menjaga konsistensi balance asset
- **dayOfMonth 29-31**: Jika montly/yearly dan hari tidak exist di bulan tersebut, ambil hari terakhir bulan (`clamp to last day`)
