# Ikuyo Finance

Personal finance management app built with Flutter. Supports local-first storage with optional Supabase authentication for cloud sync.

---

## Table of Contents

- [Ikuyo Finance](#ikuyo-finance)
  - [Table of Contents](#table-of-contents)
  - [Features](#features)
  - [Architecture](#architecture)
  - [Project Structure](#project-structure)
  - [Dependency Injection](#dependency-injection)
  - [Routing](#routing)
    - [Navigation Shell (bottom nav)](#navigation-shell-bottom-nav)
    - [Full-screen Routes (outside shell)](#full-screen-routes-outside-shell)
    - [Child Routes](#child-routes)
    - [Auth Redirect](#auth-redirect)
  - [Features \& Screens](#features--screens)
    - [Auth](#auth)
    - [Transaction](#transaction)
    - [Asset](#asset)
    - [Category](#category)
    - [Budget](#budget)
    - [Statistic](#statistic)
    - [Backup](#backup)
    - [Other / Settings](#other--settings)
  - [Repositories](#repositories)
  - [Data Models](#data-models)
    - [Transaction](#transaction-1)
    - [Asset](#asset-1)
    - [Category](#category-1)
    - [Budget](#budget-1)
  - [Core Modules](#core-modules)
  - [Shared Widgets](#shared-widgets)
  - [Key Dependencies](#key-dependencies)
  - [Getting Started](#getting-started)
    - [Prerequisites](#prerequisites)
    - [Environment](#environment)
    - [Install \& Run](#install--run)
    - [Build](#build)

---

## Features

- **Transactions** – record income/expense transactions linked to assets and categories
- **Assets** – manage wallets, bank accounts, e-wallets, stocks, and crypto
- **Categories** – hierarchical income/expense categories with custom icons and colors
- **Budgets** – spending limits per category with flexible periods (monthly, weekly, yearly, custom)
- **Statistics** – charts and summaries of spending by category and period
- **Backup & Restore** – export/import all data as JSON
- **Multi-currency** – configurable currency display
- **Theming** – light/dark mode toggle persisted via `SharedPreferences`
- **Localization** – English and Indonesian (`easy_localization`)

---

## Architecture

```
Presentation (Screens)
       ↕
   BLoC / Cubit
       ↕
   Repository (abstract interface)
       ↕
   Repository Impl (ObjectBox / Supabase)
       ↕
   ObjectBoxStorage / SupabaseClient
```

- **State management** – `bloc` + `flutter_bloc`
- **Local database** – ObjectBox (with code generation)
- **Remote auth** – Supabase (PKCE flow, secure storage for session)
- **Navigation** – `go_router` with `StatefulShellRoute` for bottom navigation
- **Error handling** – `fpdart` `TaskEither<Failure, Success<T>>` throughout all repositories
- **Logging** – `talker` + `TalkerBlocObserver` for automatic BLoC event/state logging

---

## Project Structure

```
lib/
├── main.dart                  # App entry point
├── di/                        # Dependency injection
│   ├── injection.dart         # Main setup orchestrator
│   ├── commons.dart           # Logger, storage, Supabase, theme setup
│   ├── repositories.dart      # Repository registrations
│   ├── blocs.dart             # BLoC registrations
│   ├── router.dart            # GoRouter registration
│   └── service_locator.dart   # GetIt instance
├── core/
│   ├── config/                # Supabase config (reads from .env)
│   ├── constants/             # App-wide constants
│   ├── currency/              # Currency cubit, models, migration service
│   ├── locale/                # LocaleCubit (persisted locale)
│   ├── router/                # GoRouter setup & route definitions
│   ├── service/               # AppFileStorage (file I/O)
│   ├── storage/               # ObjectBoxStorage, SecureLocalStorage, DatabaseSeeder
│   ├── theme/                 # AppColors, AppTheme, ThemeCubit
│   ├── utils/                 # Logger (talker instance)
│   └── wrapper/               # Failure / Success wrappers
├── features/
│   ├── auth/                  # Sign in / Sign up
│   ├── transaction/           # Transaction CRUD + bulk copy + search
│   ├── asset/                 # Asset CRUD + search
│   ├── category/              # Category CRUD + search (nested)
│   ├── budget/                # Budget CRUD + search
│   ├── statistic/             # Charts and summaries
│   ├── backup/                # Export / Import JSON
│   ├── other/                 # Other menu + settings
│   └── user/                  # User profile
└── shared/
    ├── utils/                 # Shared utilities
    └── widgets/               # Reusable UI components
```

---

## Dependency Injection

`setupDependencies()` in [lib/di/injection.dart](lib/di/injection.dart) runs at startup in this order:

| Step | Function | Registers |
|------|----------|-----------|
| 1 | `setupCommons()` | Talker, AppFileStorage, FlutterSecureStorage, ObjectBoxStorage (async), SharedPreferences, SupabaseClient, ThemeCubit, LocaleCubit |
| 2 | `seedDatabaseIfNeeded()` | Seeds categories & assets on first install only |
| 3 | `setupCurrency()` | CurrencyCubit (after ObjectBox ready) |
| 4 | `setupRepositories()` | All repository singletons |
| 5 | `setupBlocs()` | All BLoC factories |
| 6 | `setupRouter()` | GoRouter singleton |

**BLoC registration** – all BLoCs registered as `Factory` (new instance per `BlocProvider`).
**Repositories** – all registered as `LazySingleton`.

---

## Routing

Router defined in [lib/core/router/app_router.dart](lib/core/router/app_router.dart) using `go_router`.

### Navigation Shell (bottom nav)

Wrapped in `StatefulShellRoute.indexedStack` → `UserShell`:

| Tab | Route | Screen |
|-----|-------|--------|
| 0 | `/` | `TransactionScreen` |
| 1 | `/statistic` | `StatisticScreen` |
| 2 | `/asset` | `AssetScreen` |
| 3 | `/other` | `OtherScreen` |

### Full-screen Routes (outside shell)

| Route | Path | Screen | Transition |
|-------|------|--------|------------|
| `sign-in` | `/sign-in` | `SignInScreen` | Fade |
| `sign-up` | `/sign-up` | `SignUpScreen` | Slide right |
| `category` | `/categories` | `CategoryScreen` | Slide right |
| `budget` | `/budget` | `BudgetScreen` | Slide right |
| `setting` | `/setting` | `SettingScreen` | Slide right |
| `backup` | `/backup` | `BackupScreen` | Slide right |

### Child Routes

Each main route has nested add / edit / search children with the following transitions:

| Action | Path suffix | Transition |
|--------|-------------|------------|
| Add | `add` | Slide from bottom |
| Edit | `edit` | Slide from right |
| Search | `search` | Slide from right |
| Bulk copy (transaction) | `transaction/bulk-copy` | Slide from bottom |

### Auth Redirect

`SupabaseAuthListenable` (in [lib/core/router/router_listenables.dart](lib/core/router/router_listenables.dart)) listens to Supabase auth state changes and triggers router refresh. Authenticated users are redirected away from auth screens.

---

## Features & Screens

### Auth

| Screen | File | Description |
|--------|------|-------------|
| `SignInScreen` | `features/auth/screens/sign_in_screen.dart` | Email + password sign in via Supabase |
| `SignUpScreen` | `features/auth/screens/sign_up_screen.dart` | Email + password registration |

**BLoC**: `AuthBloc` — events: `AuthCheckRequested`, sign in, sign up, sign out.
**Repository**: `AuthRepository` → `AuthRepositoryImpl(SupabaseClient)`.

---

### Transaction

| Screen | Description |
|--------|-------------|
| `TransactionScreen` | Main transaction list with filters |
| `TransactionUpsertScreen` | Add or edit a transaction (amount, asset, category, date, description, image) |
| `TransactionBulkCopyScreen` | Bulk copy multiple transactions at once |
| `TransactionSearchScreen` | Full-text search across transactions |

**BLoC**: `TransactionBloc` — events: `TransactionFetched`, create, bulk create, update, delete.
On successful write → triggers `AssetBloc.AssetRefreshed` (via `BlocListener` in `main.dart`).

---

### Asset

| Screen | Description |
|--------|-------------|
| `AssetScreen` | List of all assets with balance summary |
| `AssetUpsertScreen` | Add or edit an asset (name, type, balance, icon) |
| `AssetSearchScreen` | Search assets by name |

**Asset types**: `cash`, `bank`, `eWallet`, `stock`, `crypto`.
**BLoC**: `AssetBloc` — events: `AssetFetched`, `AssetRefreshed`, create, update, delete.

---

### Category

| Screen | Description |
|--------|-------------|
| `CategoryScreen` | List of income/expense categories (nested) |
| `CategoryUpsertScreen` | Add or edit a category (name, type, icon, color, parent) |
| `CategorySearchScreen` | Search categories |

**Category types**: `income`, `expense`.
Supports parent–child nesting (one level deep). `CategoryRepository` provides `getValidParentCategories` and `hasChildren` helpers.

**BLoC**: `CategoryBloc` — events: `CategoryFetched`, create, update, delete.

---

### Budget

| Screen | Description |
|--------|-------------|
| `BudgetScreen` | List of budgets with progress indicators |
| `BudgetUpsertScreen` | Add or edit a budget (category, limit, period, date range) |
| `BudgetSearchScreen` | Search budgets |

**Budget periods**: `monthly`, `weekly`, `yearly`, `custom`.
**BLoC**: `BudgetBloc` — events: `BudgetFetched`, create, update, delete.

---

### Statistic

| Screen | Description |
|--------|-------------|
| `StatisticScreen` | Income/expense charts by period, category spending breakdown |

Uses `fl_chart` for visualizations. Data comes from `TransactionRepository`'s statistic queries (`getStatistic`, `getCategorySummary`).
**BLoC**: `StatisticBloc` — depends on `TransactionRepository`.
**Models**: `CategorySummary`, `GetStatisticParams`, `StatisticPeriod`.

---

### Backup

| Screen | Description |
|--------|-------------|
| `BackupScreen` | Export all data to JSON file, import from JSON file |

On successful import → triggers refetch on `CategoryBloc`, `AssetBloc`, `BudgetBloc`, `TransactionBloc` (via `BlocListener` in `main.dart`).
**BLoC**: `BackupBloc`.
**Repository**: `BackupRepository` → methods: `exportData()`, `importData()`, `getDataSummary()`.

---

### Other / Settings

| Screen | Description |
|--------|-------------|
| `OtherScreen` | Menu hub: links to Category, Budget, Setting, Backup, user info |
| `SettingScreen` | Theme toggle, language picker, currency selector |

---

## Repositories

All repositories follow the same functional pattern using `fpdart`:

```dart
TaskEither<Failure, Success<T>>
```

| Repository | Interface | Impl | Storage |
|------------|-----------|------|---------|
| `AuthRepository` | `auth_repository.dart` | `AuthRepositoryImpl` | `SupabaseClient` |
| `CategoryRepository` | `category_repository.dart` | `CategoryRepositoryImpl` | `ObjectBoxStorage` + `AppFileStorage` |
| `AssetRepository` | `asset_repository.dart` | `AssetRepositoryImpl` | `ObjectBoxStorage` + `AppFileStorage` |
| `BudgetRepository` | `budget_repository.dart` | `BudgetRepositoryImpl` | `ObjectBoxStorage` |
| `TransactionRepository` | `transaction_repository.dart` | `TransactionRepositoryImpl` | `ObjectBoxStorage` |
| `BackupRepository` | `backup_repository.dart` | `BackupRepositoryImpl` | `ObjectBoxStorage` |

---

## Data Models

All local models are ObjectBox entities identified by a ULID.

### Transaction
```
id, ulid, amount, transactionDate, description, imagePath, createdAt, updatedAt
→ asset (ToOne<Asset>)
→ category (ToOne<Category>, optional)
```

### Asset
```
id, ulid, name, type (AssetType), balance, icon, createdAt, updatedAt
AssetType: cash | bank | eWallet | stock | crypto
```

### Category
```
id, ulid, name, type (CategoryType), icon, color, createdAt, updatedAt
→ parent (ToOne<Category>, optional – self-referencing)
CategoryType: income | expense
```

### Budget
```
id, ulid, amountLimit, period (BudgetPeriod), startDate, endDate, createdAt, updatedAt
→ category (ToOne<Category>)
BudgetPeriod: monthly | weekly | yearly | custom
```

---

## Core Modules

| Module | Description |
|--------|-------------|
| `core/config/` | `SupabaseConfig` — reads `SUPABASE_URL` and `SUPABASE_ANON_KEY` from `.env` |
| `core/currency/` | `CurrencyCubit`, currency models, `CurrencyMigrationService` |
| `core/locale/` | `LocaleCubit` — persists selected locale to `SharedPreferences` |
| `core/theme/` | `ThemeCubit`, `AppColors`, `AppTheme` — light/dark themes |
| `core/storage/` | `ObjectBoxStorage`, `SecureLocalStorage`, `DatabaseSeeder`, `StorageKeys` |
| `core/service/` | `AppFileStorage` — file read/write/delete helpers |
| `core/utils/` | `logger.dart` — global `talker` instance with helpers (`logInfo`, `logError`, etc.) |
| `core/wrapper/` | `Failure`, `Success<T>`, `ActionSuccess`, `SuccessCursor<T>` |
| `core/router/` | `AppRouter`, `AppRoutes`, `AppPageTransitions`, `SupabaseAuthListenable` |

---

## Shared Widgets

Located in `lib/shared/widgets/`:

| Widget | Description |
|--------|-------------|
| `AppButton` | Primary / secondary / text buttons |
| `AppTextField` | Themed text input |
| `AppSearchField` | Search input with debounce |
| `AppDropdown` | Single-select dropdown |
| `AppMultiSelectDropdown` | Multi-select dropdown |
| `AppSearchableDropdown` | Searchable dropdown |
| `AppCheckbox` | Themed checkbox |
| `AppRadioGroup` | Radio button group |
| `AppDateTimePicker` | Date & time picker |
| `AppTimePicker` | Time-only picker |
| `AppColorPicker` | Color picker dialog |
| `AppFilePicker` | File picker button |
| `AppImage` | Cached network/local image with fallback |
| `AppAvatar` | User avatar widget |
| `AppText` | Themed text with style shortcuts |
| `AppListBottomSheet` | Bottom sheet with a scrollable list |
| `AppLoaderOverlay` | Full-screen loading overlay |
| `AppDetailActionButtons` | Edit/delete action button pair |
| `ScreenWrapper` | Standard scaffold wrapper |
| `UserShell` | Bottom navigation shell |
| `ThemeToggle` | Light/dark mode toggle |
| `CurrencyMigrationDialog` | Dialog shown on currency format migration |

---

## Key Dependencies

| Package | Purpose |
|---------|---------|
| `flutter_bloc` | State management |
| `go_router` | Declarative navigation |
| `objectbox` | Local NoSQL database |
| `supabase_flutter` | Auth + potential cloud sync |
| `fpdart` | Functional error handling (`TaskEither`) |
| `easy_localization` | i18n (EN / ID) |
| `talker` + `talker_bloc_logger` | Structured logging |
| `fl_chart` | Charts for statistics |
| `flutter_form_builder` | Form management |
| `get_it` | Service locator / DI |
| `shared_preferences` | Persisted preferences (theme, locale, seed flag) |
| `flutter_secure_storage` | Secure Supabase session storage |
| `bot_toast` / `toastification` | Toast notifications |
| `image_picker` | Transaction receipt images |
| `file_picker` / `file_saver` | Backup import/export |
| `skeletonizer` | Skeleton loading states |
| `ulid` | Universally unique lexicographically sortable IDs |

---

## Getting Started

### Prerequisites

- Flutter SDK `^3.9.0`
- Dart SDK `^3.9.0`

### Environment

Create a `.env` file in the project root:

```
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
```

### Install & Run

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs  # generates ObjectBox & GoRouter code
flutter run
```

### Build

```bash
flutter build apk --release       # Android
flutter build ios --release       # iOS
flutter build windows --release   # Windows
```
