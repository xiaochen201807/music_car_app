# Contributing

This repository uses GitHub as the source of truth for project work.

## Workflow

1. Create or link an Issue before implementation unless the change is a small
   maintenance fix.
2. Work on a `codex/*` branch.
3. Keep changes scoped to one deliverable.
4. Open a Pull Request into `main`.
5. Wait for GitHub Actions before merging.

Use Chinese for Issue and PR descriptions when the work is primarily for the
current maintainer workflow. Keep GitHub concepts such as Issue, PR, Actions,
Release, and Milestone in English.

## Local Verification

Allowed local checks:

```sh
flutter analyze
flutter test
node --check scripts/cf.js
git diff --check
```

Do not build release deliverables locally unless explicitly requested. Android
APK and iOS unsigned IPA artifacts are produced by GitHub Actions.

## Release Rule

Release packaging is tag-driven:

```sh
git tag vX.Y.Z
git push <remote> vX.Y.Z
```

After pushing a tag, verify the Android and iOS workflow runs and the GitHub
Release assets before telling users that a version is available.
