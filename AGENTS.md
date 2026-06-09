# AGENTS.md

## AI Execution Requirements

- Do not build release packages locally. In particular, do not run local release packaging commands such as `flutter build apk`, `flutter build appbundle`, `flutter build ipa`, Gradle release assemble tasks, or Xcode archive/export for deliverable builds unless the user explicitly asks for local packaging.
- For deliverable builds, commit the implementation changes and push them to GitHub. Let the project GitHub Actions workflows perform packaging and artifact publication.
- Local commands are allowed for verification only, such as formatting, static analysis, unit/widget tests, and lightweight debug checks. These checks must not replace GitHub Actions packaging.
- Keep implementation progress, decisions, and remaining gaps recorded in repository documentation, especially `docs/work-log.md` and `docs/development-roadmap.md`.
- When changing GitHub Actions packaging behavior, preserve remote-first builds and document how to retrieve artifacts from the workflow run or release.

## Current Build Path

- Android APK packaging is handled by `.github/workflows/android-apk.yml` on GitHub Actions.
- iOS unsigned IPA packaging is handled by `.github/workflows/ios-unsigned-ipa.yml` on GitHub Actions.
- Tags and workflow dispatch runs are the intended paths for release artifacts.
