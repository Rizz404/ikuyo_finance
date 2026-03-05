---
trigger: always_on
---

# Antigravity Workspace Rules — Ikuyo Finance (Flutter)

You are pairing on the Ikuyo Finance Flutter codebase.
Follow these rules strictly and consistently.

## 0) Scope & behavior
- Apply these rules to all code you generate/modify in this workspace.
- If a request conflicts with these rules, ask a clarifying question before coding.
- Keep your response brief & to the point: mention only what changed/added/removed.

## 1) Extensions (mandatory)
- When accessing theme or localization, always use the project extensions:
  - import 'package:ikuyo_finance/core/extensions/theme_extension.dart';
  - import 'package:ikuyo_finance/core/extensions/localization_extension.dart';
- Theme access must use:
  - context.theme / context.textTheme / context.colorScheme / context.colors / context.semantic / context.isDarkMode
- Localization access must use:
  - context.l10n / context.locale / context.isEnglish / context.isIndonesian / context.isJapanese

## 2) Theming (never hardcode colors)
- DO: use context.colorScheme.*, context.colors.*, context.textTheme.*
- DON'T: Color(0xFF...), Colors.red, any hardcoded colors.
- If a color token does not exist, ask before introducing a new token.

## 3) Logging (replace all print)
- Never use print().
- Use: import 'package:ikuyo_finance/core/utils/logger.dart';
- Use the available helpers on `this`:
  - logInfo, logError, logData, logDomain, logPresentation, logService
- For failures: logError('message', e, s)
- DO NOT add logging in widgets/screens unless explicitly requested.
- Keep logging in business/data layers: BLoCs, Repositories, Services, Use Cases.
- If unsure whether UI logging is needed, ask first: "Perlu logging di widget/screen ini?"

## 4) Comments (Better Comments format)
- Only use these prefixes:
  - TODO: | FIXME: | ! warning | ? question | * important note
- Use Bahasa Indonesia for comments: singkat, padat, jelas.
- Keep inline comments max 1–2 lines; code should be self-explanatory.
- If explanation is long, put it in chat response, NOT in code comments.

## 5) const everywhere possible
- Use const for widgets, durations, paddings, SizedBox, constructors, lists, etc.
- Prefer immutable patterns; avoid unnecessary rebuild churn.

## 6) Docs & files
- Do not create new .md documentation files unless explicitly requested.
- If you need to explain something, do it in the chat message, not as a new docs file.

## 7) Shared Widgets first (no raw Material widgets unless needed)
- Always prefer shared components from:
  - 'package:ikuyo_finance/shared/widgets/...'
- Use existing widgets instead of raw Material/Cupertino equivalents:
  - AppButton (primary/secondary/text)
  - AppTextField, AppSearchField
  - AppDropdown, AppCheckbox, AppRadioGroup
  - AppDateTimePicker, AppTimePicker
  - AppText
  - CustomAppBar, ScreenWrapper
  - AdminShell, UserShell, AppEndDrawer
- If a shared widget is missing a needed capability, ask before creating a new widget.

## 8) Widget Structure — Hybrid Approach
- Keep everything inline inside build() as long as it stays readable.
- Only extract when there is a clear reason — not just to "organize".
- Scaffold-level slots (appBar, body, drawer, bottomNavigationBar, floatingActionButton)
  must always be written inline. Never wrap them in _buildAppBar(), _buildBody(), etc.
  Use shared components directly (CustomAppBar, AppEndDrawer, ScreenWrapper, etc.)
- Extract to TIER 1 / TIER 2 only for deep leaf content that has grown complex,
  not for top-level scaffold slots.

**TIER 1 — Private Function (_buildX)**
  When: a leaf subtree is complex enough to reduce nesting,
        accesses parent scope directly (widget.x, state, controller),
        no independent props needed — any length is fine

**TIER 2 — Private Class (_MyWidget)**
  When: ONLY if one of these is needed:
        - independent props (not from parent scope)
        - const constructor for rebuild optimization
        - own local state
        - own lifecycle (initState, dispose, etc.)
  DON'T: use just because a widget is long without the above needs

**TIER 3 — Public Class in /widgets**
  When: used across more than 1 screen/file
  Location: feature/category/widgets/category_card.dart

**Decision tree:**
  Used in > 1 screen?                              → TIER 3
  Needs independent props / own state / lifecycle? → TIER 2
  Deep leaf content that reduces nesting?          → TIER 1
  Everything else (including scaffold slots)       → inline in build()

**Feature structure:**
```
lib/features/category/
├── screens/
│   └── category_screen.dart   ← inline build, TIER 1 & TIER 2 if needed
└── widgets/
    └── category_card.dart     ← TIER 3
```

## 9) Widget Member Ordering
Applies to: StatelessWidget, StatefulWidget, ConsumerWidget,
            ConsumerStatefulWidget, HookWidget, HookConsumerWidget

**STATELESS / CONSUMER WIDGET**
  1. Fields / final variables
  2. Constructor
  3. Override methods (except build)
  4. build()
  5. Private widget functions (_buildX) ← always last, per rule 8

**STATEFUL / CONSUMER STATEFUL**

StatefulWidget class:
  1. Fields / final variables (props)
  2. Constructor
  3. createState()

State class:
  1. Variables (controllers, flags, notifiers, etc.)
  2. Override methods (initState, didChangeDependencies, dispose, etc.)
  3. Private logic functions (_handleX, _loadX, etc.)
  4. build() — widget tree only, no logic/vars inside
  5. Private widget functions (_buildX) ← always last, per rule 8

- DON'T: declare variables or logic inside build()
- DO: move all variables to class-level or initState

## 10) Static analysis & linting (IMPORTANT)
- Do NOT run or suggest running Flutter/Dart analysis automatically.
- Never run these unless the user explicitly asks:
  - flutter analyze
  - dart analyze
  - dart fix
  - dart format / flutter format
  - any lint command or "auto-fix all"
- If analysis is relevant, ask: "Mau aku jalankan flutter analyze/dart analyze?" and wait for confirmation.
- Do not use any auto-run / turbo execution for analysis/lint commands.

## 11) Translations (static text default)
- DO NOT modify or add to translation files (.json / translations) unless explicitly requested.
- Use static/hardcoded text strings in widgets by default.
- Only use context.l10n when the user specifically asks for localization support.
- If unsure whether to localize, ask first: "Mau pakai translation atau static text?"
- If EXPLICITLY requested to add translations, strictly follow the feature-based l10n pattern:
  - Add the new translation keys to ALL available `.json` files inside the corresponding feature's `translations` folder.
  - Example: If editing `lib/feature/appraisal/screens/appraisal_result_screen.dart`, add the translations to all `.json` files in `lib/feature/appraisal/translations/`.
  - After updating the `.json` files, you MUST run the following command to generate the localization files:
    `dart run tools/merge_translations.dart`

## 12) Terminal workflow preferences
- Prefer modern CLI tools:
  - eza, fd, rg, bat, sd
  - lazygit, gh, delta
  - z (zoxide), fzf, yazi
  - btm, procs, dust, duf
- Avoid: dir, findstr, find, grep, cat, and manual repetitive cd.

## 13) Code output expectations
- Prefer small, focused diffs.
- When editing code, preserve existing architecture and patterns in the repo.
- Avoid introducing new dependencies unless explicitly requested.
