# Ikuyo Finance — Copilot Instructions

## Purpose

These instructions apply to all Dart/Flutter files in this repository.
They define coding standards, patterns, and constraints specific to Ikuyo Finance.
Follow these rules on every suggestion, edit, or generation — no exceptions.

---

## 1. Imports & Extensions

Always import these extensions at the top of any widget file:

```dart
import 'package:ikuyo_finance/core/extensions/theme_extension.dart';
import 'package:ikuyo_finance/core/extensions/localization_extension.dart';
```

- Use `context.theme`, `context.colorScheme`, `context.colors`, `context.textTheme`, `context.isDarkMode`
- Use `context.l10n`, `context.locale`, `context.isEnglish`, `context.isIndonesian`, `context.isJapanese`

---

## 2. Theming — Never Hardcode Colors

```dart
// Avoid
color: Color(0xFF1A1A2E)
color: Colors.red

// Prefer
color: context.colorScheme.primary
color: context.colors.surface
```

Never use `Color(0xFF...)`, `Colors.*`, or any hardcoded color value anywhere.

---

## 3. Logging

Import logger and use the correct function per layer:

```dart
import 'package:ikuyo_finance/core/utils/logger.dart';

logInfo('Starting process');
logError('Something failed', e, stackTrace);
```

- Use: `logInfo`, `logError`, `logData`, `logDomain`, `logPresentation`, `logService`
- Only add logging in: BLoCs, Repositories, Services, Use Cases
- Never add logging inside widgets or screens unless explicitly asked

---

## 4. Comments

Use Better Comments format only:

```dart
// TODO: implement pagination
// FIXME: null check missing here
// ! warning: this mutates shared state
// ? should this use a stream instead?
// * this is called on every frame
```

---

## 5. Const

Use `const` everywhere it is valid:

```dart
const SizedBox(height: 16)
const Duration(milliseconds: 300)
const EdgeInsets.symmetric(horizontal: 16)
```

---

## 6. Response Style

- Be brief and to the point
- Only mention what changed, added, or removed
- No lengthy explanations unless asked

---

## 7. Documentation

- No `.md` files unless explicitly requested
- Inline comments: 1–2 lines max
- Code should be self-explanatory

---

## 8. Shared Widgets — Search Before Creating

**Before writing any widget, check if a shared widget already exists.**

Run: `rg "class App" lib/shared/widgets/` or `eza --tree lib/shared/widgets/`

If a shared widget covers the use case → use it. Do not create a new one.

Available shared widgets (import from `package:ikuyo_finance/shared/widgets/...`):

| Widget | Purpose |
|---|---|
| `AppButton` | Primary / secondary / text buttons |
| `AppTextField` | Standard text input |
| `AppSearchField` | Search input with icon |
| `AppDropdown` | Dropdown selector |
| `AppCheckbox` | Checkbox input |
| `AppRadioGroup` | Radio button group |
| `AppDateTimePicker` | Date + time picker |
| `AppTimePicker` | Time-only picker |
| `AppText` | Themed text (replaces raw `Text()`) |
| `CustomAppBar` | App bar (replaces raw `AppBar()`) |
| `ScreenWrapper` | Screen-level layout wrapper |
| `AdminShell` | Admin navigation shell |
| `UserShell` | User navigation shell |
| `AppEndDrawer` | End drawer |

**Decision rule before using any raw Material/Cupertino widget:**
1. Shared widget exists? → **Use it**
2. Feature-local widget exists? → **Reuse it**
3. Neither exists? → Create new, following widget tier rules below

```dart
// Avoid
TextField(decoration: InputDecoration(...))
ElevatedButton(onPressed: ..., child: Text('Submit'))

// Prefer
AppTextField(...)
AppButton(text: 'Submit', onPressed: onSubmit)
```

---

## 9. Text & Localization

- Use static text strings by default: `'Submit'`, `'Cancel'`, `'Save'`
- Do **not** use `context.l10n` or edit `.json` files unless explicitly asked
- If unsure, ask: *"Mau pakai translation atau static text?"*

**If localization is explicitly requested:**
1. Add the new key to **all** `.json` files in the feature's `translations/` folder
2. Run: `dart run tools/merge_translations.dart`

---

## 10. Widget Structure

Keep everything inline in `build()` unless there is a clear reason to extract.

### Scaffold slots are always inline

```dart
// Avoid
appBar: _buildAppBar()
body: _buildBody()

// Prefer
appBar: CustomAppBar(title: 'Screen Title')
body: ListView.builder(...)
```

### Extraction tiers

**Tier 1 — Private function `_buildX`**
When: leaf content is complex, accesses parent scope, no independent props needed.

```dart
Widget _buildEmptyState() => Center(child: AppText('No items'));
```

**Tier 2 — Private class `_MyWidget`**
Only when one of these is required:
- Independent props (not from parent scope)
- `const` constructor for rebuild optimization
- Own local state
- Own lifecycle (`initState`, `dispose`)

**Tier 3 — Public class in `/widgets`**
Only when used across more than one screen or file.
Location: `lib/features/<feature>/widgets/<name>.dart`

**Decision tree:**
- Used in > 1 screen? → Tier 3
- Needs independent props / own state / lifecycle? → Tier 2
- Complex leaf that reduces nesting? → Tier 1
- Everything else (including scaffold slots) → inline

---

## 11. Widget Member Ordering

**StatelessWidget / ConsumerWidget:**
1. Fields / final variables
2. Constructor
3. Override methods (except `build`)
4. `build()`
5. Private widget functions `_buildX`

**StatefulWidget State class:**
1. Variables (controllers, flags, notifiers)
2. Override methods (`initState`, `dispose`, etc.)
3. Private logic functions (`_handleX`, `_loadX`)
4. `build()` — widget tree only, no logic or variable declarations inside
5. Private widget functions `_buildX`

```dart
// Avoid
Widget build(BuildContext context) {
  final ctrl = TextEditingController(); // ❌ never declare here
}

// Prefer — declare at class level
late final TextEditingController _ctrl;

@override
void initState() {
  super.initState();
  _ctrl = TextEditingController();
}
```

---

## 12. Terminal Tools

Prefer modern CLI tools:

| Task | Tool |
|---|---|
| List files | `eza` |
| Find files | `fd` |
| Search content | `rg` |
| Read files | `bat` |
| Replace text | `sd` |
| Git UI | `lazygit` |
| Navigate | `z` (zoxide) |
| Monitor | `btm`, `procs` |

Avoid: `dir`, `findstr`, `find`, `grep`, `cat`, manual `cd`
