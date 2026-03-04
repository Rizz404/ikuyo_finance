// Copilot Guidelines - Ikuyo Finance

// 1) Extensions (mandatory)
import 'package:ikuyo_finance/core/extensions/theme_extension.dart';
import 'package:ikuyo_finance/core/extensions/localization_extension.dart';
// Access: context.theme|textTheme|colorScheme|colors|semantic|isDarkMode
// Access: context.l10n|locale|isEnglish|isIndonesian|isJapanese

// 2) Theming (never hardcode colors!)
// ✅ DO: context.colorScheme.primary, context.colors.surface, context.textTheme.bodyMedium
// ❌ DON'T: Color(0xFF...), Colors.red, hardcoded colors

// 3) Logging (replace all print!)
import 'package:ikuyo_finance/core/utils/logging.dart';
// Use: logInfo|logError|logData|logDomain|logPresentation|logService
// Example: logService('Process started'); logError('Failed', e, s);
// ❌ DON'T: Add logging in widgets/screens unless explicitly requested
// ✅ DO: Keep logging in BLoCs, Repositories, Services, Use Cases only
// If unsure about UI logging, ask first before adding it

// 4) Comments (Better Comments format)
// TODO: | FIXME: | ! warning | ? question | \* important note

// 5) const everywhere possible
// const SizedBox(height: 16), const Duration(milliseconds: 300)

// 6) Response: brief & to the point
// Only mention what changed/added/removed, no lengthy explanations

// 7) Docs: NO .md files unless explicitly requested
// Keep inline comments 1-2 lines max, code should be self-explanatory

// 8) Shared Widgets (use existing components first!)
// Import from: 'package:ikuyo_finance/shared/widgets/...'
// Available:
// - AppButton (primary/secondary/text buttons)
// - AppTextField, AppSearchField (text inputs)
// - AppDropdown, AppCheckbox, AppRadioGroup (form controls)
// - AppDateTimePicker, AppTimePicker (date/time)
// - AppText (themed text widget)
// - CustomAppBar, ScreenWrapper (layout)
// - AdminShell, UserShell, AppEndDrawer (navigation shells)
// ✅ DO: Use these widgets instead of raw Material/Cupertino widgets
// ❌ DON'T: Create new TextField, Dropdown, Button when app widgets exist

// 9) Text/Localization (IMPORTANT!)
// ✅ DO: Use static text strings by default ('Submit', 'Cancel', etc.)
// ❌ DON'T: Use context.l10n or edit .json files UNLESS explicitly asked
// If unsure whether to localize, ask first: "Mau pakai translation atau static text?"
//
// ⚠️ IF EXPLICITLY REQUESTED to add translations, strictly follow this pattern:
// - Add the new keys to ALL available .json files inside that feature's `translations` folder.
// - Example: If editing `lib/features/appraisal/screens/appraisal_result_screen.dart`,
// add translations to all .json files in `lib/features/appraisal/translations/`.
// - After updating the .json files, you MUST run the following command:
// dart run tools/merge_translations.dart

// 10) Widget Structure — Hybrid Approach
//
// Keep everything inline inside build() as long as it stays readable.
// Only extract when there is a clear reason — not just to "organize".
//
// Scaffold-level slots (appBar, body, drawer, bottomNavigationBar, floatingActionButton)
// must always be written inline. Never wrap them in \_buildAppBar(), \_buildBody(), etc.
// Use shared components directly (CustomAppBar, AppEndDrawer, ScreenWrapper, etc.)
//
// Extract to TIER 1 / TIER 2 only for deep leaf content that has grown complex,
// not for top-level scaffold slots.
//
// TIER 1 — Private Function (\_buildX)
// When: a leaf subtree is complex enough to reduce nesting,
// accesses parent scope directly (widget.x, state, controller),
// no independent props needed — any length is fine
//
// TIER 2 — Private Class (\_MyWidget)
// When: ONLY if one of these is needed:
// - independent props (not from parent scope)
// - const constructor for rebuild optimization
// - own local state
// - own lifecycle (initState, dispose, etc.)
// ❌ DON'T: use just because a widget is long without the above needs
//
// TIER 3 — Public Class in /widgets
// When: used across more than 1 screen/file
// Location: feature/category/widgets/category_card.dart
//
// Decision tree:
// Used in > 1 screen? → TIER 3
// Needs independent props / own state / lifecycle? → TIER 2
// Deep leaf content that reduces nesting? → TIER 1
// Everything else (including scaffold slots) → inline in build()
//
// Feature structure:
// lib/features/category/
// ├── screens/
// │ └── category_screen.dart ← inline build, TIER 1 & TIER 2 if needed
// └── widgets/
// └── category_card.dart ← TIER 3

// 11) Widget Member Ordering
// Applies to: StatelessWidget, StatefulWidget, ConsumerWidget,
// ConsumerStatefulWidget, HookWidget, HookConsumerWidget
//
// ── STATELESS / CONSUMER WIDGET ──────────────────────────────────────────
// 1. Fields / final variables
// 2. Constructor
// 3. Override methods (except build)
// 4. build()
// 5. Private widget functions (\_buildX) ← always last, per rule 10
//
// ── STATEFUL / CONSUMER STATEFUL ─────────────────────────────────────────
// StatefulWidget class:
// 1. Fields / final variables (props)
// 2. Constructor
// 3. createState()
//
// State class:
// 1. Variables (controllers, flags, notifiers, etc.)
// 2. Override methods (initState, didChangeDependencies, dispose, etc.)
// 3. Private logic functions (\_handleX, \_loadX, etc.)
// 4. build() — widget tree only, no logic/vars inside
// 5. Private widget functions (\_buildX) ← always last, per rule 10
//
// ❌ DON'T: declare variables or logic inside build()
// Widget build(BuildContext context) {
// final ctrl = TextEditingController(); // ❌
// final isValid = value.isNotEmpty; // ❌
// }
// ✅ DO: move to class-level or initState

// 12) Terminal: use modern CLI tools
// Files: eza, fd, rg, bat, sd | Git: lazygit, gh, delta
// Nav: z (zoxide), fzf, yazi | Dev: glow, jq, tldr, micro
// Monitor: btm, procs, dust, duf
// ❌ Avoid: dir, findstr, find, grep, cat, manual cd

// ═══════════════════════════════════════════════════════════════════════════
// EXAMPLES
// ═══════════════════════════════════════════════════════════════════════════

// ── Theming & Static Text ─────────────────────────────────────────────────
Widget build(BuildContext context) => Container(
color: context.colors.surface,
child: AppText('Title', style: AppStyle.titleMedium),
);

AppButton(
text: 'Submit',
onPressed: onSubmit,
)

// ── Scaffold slots inline, no wrapping functions ──────────────────────────
// ❌ DON'T
Widget build(BuildContext context) => Scaffold(
appBar: \_buildAppBar(), // ❌
body: \_buildBody(), // ❌
drawer: \_buildDrawer(), // ❌
);

// ✅ DO: scaffold slots inline, shared components used directly
Widget build(BuildContext context) => Scaffold(
appBar: CustomAppBar(title: 'Category'),
drawer: AppEndDrawer(),
body: ListView.builder(
itemCount: items.length,
itemBuilder: (\_, i) => \_buildItem(items[i]), // ✅ \_buildX only at leaf
),
);

// ── TIER 1: Private Function (complex leaf, accesses parent scope) ────────
class \_CategoryScreenState extends State<CategoryScreen> {
Widget \_buildEmptyState() => Center(child: AppText('No categories'));
Widget \_buildItemTile(CategoryModel item) => Column(
children: [
AppText(item.name),
AppText(item.description),
AppButton(text: 'Select', onPressed: () => _handleSelect(item)),
],
);
}

// ── TIER 2: Private Class (independent props, rebuild optimization) ───────
class \_CategoryItem extends StatelessWidget {
final String title;
final String subtitle;
final VoidCallback onTap;

const \_CategoryItem({
required this.title,
required this.subtitle,
required this.onTap,
});

@override
Widget build(BuildContext context) => ListTile(
leading: \_buildLeading(),
title: AppText(title),
subtitle: AppText(subtitle),
onTap: onTap,
);

Widget \_buildLeading() => Icon(Icons.car_repair, color: context.colors.primary);
}

// ── TIER 3: Public Class in /widgets (reusable across screens) ───────────
// lib/features/category/widgets/category_card.dart
class CategoryCard extends StatelessWidget {
final String title;
final VoidCallback onTap;

const CategoryCard({super.key, required this.title, required this.onTap});

@override
Widget build(BuildContext context) => GestureDetector(
onTap: onTap,
child: Container(
color: context.colors.surface,
child: AppText(title),
),
);
}

// ── Stateful Widget ───────────────────────────────────────────────────────
class CategoryScreen extends StatefulWidget {
final String categoryId;
final VoidCallback? onBack;

const CategoryScreen({super.key, required this.categoryId, this.onBack});

@override
State<CategoryScreen> createState() => \_CategoryScreenState();
}

class \_CategoryScreenState extends State<CategoryScreen> {
late final ScrollController \_scrollController;
bool \_isLoading = false;

@override
void initState() {
super.initState();
\_scrollController = ScrollController();
}

@override
void dispose() {
\_scrollController.dispose();
super.dispose();
}

void \_handleRefresh() => setState(() => \_isLoading = false);

@override
Widget build(BuildContext context) => Scaffold(
appBar: CustomAppBar(title: widget.categoryId),
body: _isLoading
? const Center(child: CircularProgressIndicator())
: ListView.builder(
controller: \_scrollController,
itemCount: 10,
itemBuilder: (_, i) => CategoryCard(
title: widget.categoryId,
onTap: \_handleRefresh,
),
),
);
}

// ── BLoC / Service Logging ────────────────────────────────────────────────
class UserBloc extends Bloc<UserEvent, UserState> {
Future<void> \_onLoad(UserLoad event, Emitter<UserState> emit) async {
logInfo('Loading user data');
try {
final user = await repository.getUser();
emit(UserLoaded(user));
} catch (e, s) {
logError('Failed to load user', e, s);
}
}
}

// ═══════════════════════════════════════════════════════════════════════════
// TERMINAL WORKFLOWS
// ═══════════════════════════════════════════════════════════════════════════
// fd -e dart | rg "TODO" // find TODOs
// eza --tree -L 3 lib/ // show structure
// z sigma // jump to project
// lazygit // interactive git
