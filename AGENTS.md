# AGENTS.md

## AI Execution Requirements

- Do not build release packages locally. In particular, do not run local release packaging commands such as `flutter build apk`, `flutter build appbundle`, `flutter build ipa`, Gradle release assemble tasks, or Xcode archive/export for deliverable builds unless the user explicitly asks for local packaging.
- For deliverable builds, commit the implementation changes and push them to GitHub. Let the project GitHub Actions workflows perform packaging and artifact publication.
- Local commands are allowed for verification only, such as formatting, static analysis, unit/widget tests, and lightweight debug checks. These checks must not replace GitHub Actions packaging.
- Keep implementation progress, decisions, and remaining gaps recorded in repository documentation, especially `docs/work-log.md` and `docs/development-roadmap.md`.
- When changing GitHub Actions packaging behavior, preserve remote-first builds and document how to retrieve artifacts from the workflow run or release.

## UI Design Requirements

- All UI work must follow the design contract in `docs/ui/design-spec.md` and the task order in `docs/ui/ui-rebuild-playbook.md`.
- All colors, spacing, radii, type styles, and shadows must come from `lib/theme/design_tokens.dart`. Hardcoded literals in widgets (e.g. `Color(0xFF...)`, `BorderRadius.circular(22)`, raw `FontWeight`/`fontSize` pairs) are non-compliant — the only exception is `design_tokens.dart` itself.
- High-saturation accent (violet/rose gradient) is allowed ONLY on: primary play/pause button, played segment of the progress bar, active navigation indicator, and the favorite (heart) active state. Everywhere else uses neutral glass. See design-spec §0 rule 1.
- Cards/panels/pills must use the single shared `GlassCard` component with a real `BackdropFilter` blur — do not assemble `Container + semi-transparent color` ad hoc.
- Network artwork must go through `cached_network_image` with placeholder + error states; raw `Image.network` is non-compliant.
- Before considering UI work done, verify against the visual Definition of Done checklist in design-spec §10.

## Current Build Path

- Android APK packaging is handled by `.github/workflows/android-apk.yml` on GitHub Actions.
- iOS unsigned IPA packaging is handled by `.github/workflows/ios-unsigned-ipa.yml` on GitHub Actions.
- Tags and workflow dispatch runs are the intended paths for release artifacts.
