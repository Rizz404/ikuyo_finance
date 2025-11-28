// Copilot Guidelines - Sigma Track

// 1) Theming (never hardcode colors!)
// ✅ DO: context.colorScheme.primary, context.colors.surface, context.textTheme.bodyMedium
// ❌ DON'T: Color(0xFF...), Colors.red, hardcoded colors

// 2) Logging (replace all print!)
// Use: this.logInfo|logError|logData|logDomain|logPresentation|logService
// Example: this.logService('Process started'); this.logError('Failed', e, s);

// 3) Comments (Better Comments format)
// TODO: | FIXME: | ! warning | ? question | * important note

// 4) const everywhere possible
// const SizedBox(height: 16), const Duration(milliseconds: 300)

// 5) Response: brief & to the point
// Only mention what changed/added/removed, no lengthy explanations

// 6) Docs: NO .md files unless explicitly requested
// Keep inline comments 1-2 lines max, code should be self-explanatory

// 7) Shared Widgets (use existing components first!)
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

// 8) Terminal: use modern CLI tools
// Files: eza, fd, rg, bat, sd | Git: lazygit, gh, delta
// Nav: z (zoxide), fzf, yazi | Dev: glow, jq, tldr, micro
// Monitor: btm, procs, dust, duf
// ❌ Avoid: dir, findstr, find, grep, cat, manual cd

// Quick examples:
Widget build(BuildContext context) => Container(
  color: context.colors.surface,
  child: AppText(context.l10n.ok, style: AppStyle.titleMedium),
);

AppButton(
  text: context.l10n.submit,
  onPressed: onSubmit,
)

// Terminal workflows:
// fd -e dart | rg "TODO"  // find TODOs
// eza --tree -L 3 lib/    // show structure
// z sigma                 // jump to project
// lazygit                 // interactive git
