# Auto Transaction — Feature Design

## Overview

Fitur Auto Transaction memungkinkan user mendefinisikan template grup transaksi berulang yang dieksekusi secara otomatis pada jadwal tertentu. Cocok untuk pengeluaran/pemasukan harian yang konsisten (parkir, ojol, kereta, dll).

---

## Business Rules

| Aturan | Nilai |
|---|---|
| Max item per grup | 20 |
| Max grup dengan hour:minute yang sama (global) | 10 |
| Jumlah grup total | Unlimited |
| Window eksekusi terlewat | 7 hari |
| Background execution interval | ~15 menit (batas minimum Workmanager) |

### Alasan limit 10 grup per jam yang sama
5 terlalu cepat penuh — pengguna dengan rutinitas pagi dan malam berbeda bisa dengan mudah mencapai batas 5 hanya dari Daily saja. Angka 10 tetap memberikan batas bermakna untuk mencegah overload scheduler sambil memberi ruang yang cukup untuk kustomisasi.

---

## Data Model

### 1. `AutoTransactionGroup` (entitas baru)

```
AutoTransactionGroup
├── id: int                   (@Id)
├── ulid: String              (@Unique)
├── name: String
├── description: String?
├── isActive: bool            -- master toggle (false = tidak pernah jalan)
├── isPaused: bool            -- pause sementara
├── pauseStartAt: DateTime?   -- kapan pause dimulai
├── pauseEndAt: DateTime?     -- null = pause manual (sampai di-resume manual)
├── frequency: int            -- enum AutoScheduleFrequency (stored as int)
├── scheduleHour: int         -- 0-23
├── scheduleMinute: int       -- 0-59
├── dayOfWeek: int?           -- 1-7, hanya für weekly (1=Mon, 7=Sun)
├── dayOfMonth: int?          -- 1-31, untuk monthly & yearly
├── monthOfYear: int?         -- 1-12, hanya untuk yearly
├── startDate: DateTime       -- kapan grup mulai aktif
├── endDate: DateTime?        -- null = unlimited
├── nextExecutedAt: DateTime? -- tanggal eksekusi berikutnya (kunci scheduler)
├── lastExecutedAt: DateTime? -- referensi eksekusi terakhir
├── createdAt: DateTime
└── updatedAt: DateTime
```

### 2. `AutoTransactionItem` (entitas baru)

Item tidak menduplikasi field — cukup menunjuk ke `Transaction` yang sudah ada sebagai template. Saat eksekusi, scheduler membaca `transaction.target` dan menyalin `amount`, `asset`, `category`, `description` ke transaksi baru.

```
AutoTransactionItem
├── id: int                          (@Id)
├── ulid: String                     (@Unique)
├── isActive: bool                   -- bisa disable 1 item tanpa hapus grup
├── sortOrder: int                   -- urutan tampil dalam grup
├── transaction: ToOne<Transaction>  -- template transaksi (required)
├── group: ToOne<AutoTransactionGroup>
├── createdAt: DateTime
└── updatedAt: DateTime
```

### 3. `AutoTransactionLog` (entitas baru)

```
AutoTransactionLog
├── id: int                    (@Id)
├── ulid: String               (@Unique)
├── group: ToOne<AutoTransactionGroup>
├── scheduledAt: DateTime      -- harusnya kapan eksekusi terjadi
├── executedAt: DateTime       -- kapan benar-benar dieksekusi
├── status: int                -- enum AutoTransactionLogStatus (stored as int)
├── successCount: int
├── failureCount: int
├── errorMessage: String?      -- detail error jika ada
├── createdAt: DateTime
└── updatedAt: DateTime
```

---

## Enums

```dart
enum AutoScheduleFrequency {
  daily,    // setiap hari jam H:M
  weekly,   // setiap minggu, hari D, jam H:M
  monthly,  // setiap bulan, tanggal D, jam H:M
  yearly,   // setiap tahun, bulan M tanggal D, jam H:M
}

enum AutoTransactionLogStatus {
  success,   // semua item berhasil
  partial,   // sebagian berhasil
  failed,    // semua item gagal
  skipped,   // dilewati karena melebihi window 7 hari
}
```

---

## Logika Schedule

### Cara menghitung `nextExecutedAt` awal
Saat grup dibuat/diaktifkan, hitung jadwal berikutnya dari `startDate` dengan kriteria:
- **daily** → hari ini (atau besok jika jam sudah lewat) pukul `scheduleHour:scheduleMinute`
- **weekly** → hari dalam minggu ini yang cocok `dayOfWeek` (atau minggu depan)
- **monthly** → bulan ini tanggal `dayOfMonth` (atau bulan depan)
- **yearly** → bulan `monthOfYear` tanggal `dayOfMonth` tahun ini (atau tahun depan)

### Cara menghitung `nextExecutedAt` berikutnya setelah eksekusi
Dari jadwal yang terlewat, tambahkan interval sesuai frekuensi hingga menemukan waktu di masa depan:
```
nextExecutedAt = previousScheduled + 1 interval
// terus loop sampai > DateTime.now()
```

---

## Mekanisme Eksekusi

### Skenario Trigger

| Trigger | Kapan |
|---|---|
| On app open | Setiap kali app foreground (via `WidgetsBindingObserver`) |
| Background | Workmanager periodic task, interval ~15 menit |

### Alur Eksekusi (per grup)

```
1. Query: isActive == true && nextExecutedAt ≤ now
2. Lewati jika:
   - isPaused == true && (pauseEndAt == null || pauseEndAt > now)
   - Jika pauseEndAt ≤ now → auto-resume: set isPaused = false, pauseEndAt = null
3. Iterasi semua "tick" yang terlewat dalam window 7 hari:
   while (scheduledTime ≤ now && scheduledTime ≥ (now - 7 hari)):
     eksekusi → buat Transaction dari setiap item dengan isActive == true
     simpan AutoTransactionLog per tick
     hitung scheduledTime berikutnya
4. Jika nextExecutedAt < (now - 7 hari):
   → skip, simpan log status=skipped
   → tetap hitung nextExecutedAt baru (lompat ke masa depan)
5. Cek endDate: jika nextExecutedAt > endDate → set isActive = false
6. Update lastExecutedAt dan nextExecutedAt di grup
```

### Catatan Multi-tick
Untuk frekuensi `daily` dengan 3 hari terlewat dan 20 item per grup → 60 transaksi dibuat sekaligus di background. Semua dilakukan via `TransactionRepository.createManyTransactions()` yang sudah ada untuk efisiensi.

---

## Fitur Pause

### Mode Pause

| Mode | Cara | Keterangan |
|---|---|---|
| Quick pause | `isPaused=true, pauseEndAt=null` | Sampai di-resume manual |
| Scheduled pause | `isPaused=true, pauseStartAt=X, pauseEndAt=Y` | Auto-resume saat `Y` terlewat |

### Perilaku Selama Pause
- `nextExecutedAt` tidak diubah — tetap berjalan normal
- Saat scheduler jalan dan grup masih pause → tick diabaikan, log status `skipped`
- Transaksi yang "terlewat" selama pause tetap masuk hitungan window 7 hari saat resume
- Jika durasi pause > 7 hari → semua tick selama pause akan berstatus `skipped` saat resume, dan grup langsung melanjutkan ke jadwal berikutnya

---

## Notifikasi (flutter_local_notifications)

Notifikasi dikirim setelah setiap batch eksekusi (per run Workmanager):

| Kondisi | Channel | Pesan |
|---|---|---|
| Semua sukses | `auto_tx_success` | ✅ "[Nama Grup] — 5 transaksi berhasil dibuat" |
| Sebagian gagal | `auto_tx_warning` | ⚠️ "[Nama Grup] — 3 sukses, 2 gagal. Tap untuk detail." |
| Semua gagal | `auto_tx_error` | ❌ "[Nama Grup] gagal dieksekusi. Tap untuk detail." |
| Dilewati >7 hari | `auto_tx_warning` | ⚠️ "[Nama Grup] dilewati (terlewat >7 hari)" |

Tap pada notifikasi → navigasi langsung ke halaman Log grup tersebut.

---

## Struktur Layar

```
/auto-transaction                     → AutoTransactionScreen (list grup)
/auto-transaction/add                 → AutoTransactionGroupUpsertScreen (tambah)
/auto-transaction/:groupUlid/edit     → AutoTransactionGroupUpsertScreen (edit)
/auto-transaction/:groupUlid/items    → AutoTransactionItemListScreen (kelola item)
/auto-transaction/:groupUlid/items/add      → AutoTransactionItemUpsertScreen
/auto-transaction/:groupUlid/items/:ulid    → AutoTransactionItemUpsertScreen (edit)
/auto-transaction/:groupUlid/logs     → AutoTransactionLogScreen (riwayat)
```

---

## Validasi

| Field | Rule |
|---|---|
| Nama grup | Required, max 100 karakter |
| Jadwal konflik | Max 10 grup dengan `hour:minute` yang sama (global) |
| Items per grup | Max 20 item aktif |
| Amount item | Required, > 0 |
| Asset item | Required |
| Tanggal grup | `startDate` harus ≤ `endDate` jika endDate diisi |
| Pause range | `pauseStartAt` harus ≤ `pauseEndAt` jika keduanya diisi |
| dayOfMonth | 1-28 untuk bulan yang konsisten (hindari 29-31 yang tidak selalu ada) |

---

## Edge Cases

| Skenario | Penanganan |
|---|---|
| Asset pada template transaction dihapus | Item skip, catat error di log |
| Category pada template transaction dihapus | Transaksi baru dibuat tanpa kategori |
| Template transaction dihapus | Item skip, catat error "template tidak ditemukan" di log |
| 0 item aktif dalam grup | Grup tetap jalan, log sukses dengan 0 transaksi |
| `dayOfMonth=31` di bulan Feb | Ambil hari terakhir bulan tersebut |
| Workmanager tidak support di device | Fallback ke on-app-open execution saja |
