# Release Runbook

This project does not use local release packaging as the delivery path.
GitHub Actions is the release authority.

## Pre-release

1. Confirm the PR is merged into `main`.
2. Confirm `Android APK` on `main` is green.
3. Confirm required secrets and variables are present in the target repository.
4. Choose the release version as `vX.Y.Z`.
5. Run local quality checks that do not create release packages:

```sh
dart run scripts/app_quality_gate.dart
flutter analyze
flutter test
```

6. For user-facing release candidates, complete
   `docs/device-validation-matrix.md` and record any exception in
   `docs/work-log.md`.

## Tag Release

```sh
git fetch --all --tags
git switch main
git pull --ff-only
git tag vX.Y.Z
git push xiaochen201807 vX.Y.Z
```

## Verify

Watch both workflows:

```sh
gh run list --repo xiaochen201807/music_car_app --limit 10
gh run watch --repo xiaochen201807/music_car_app <run-id> --exit-status
```

Expected tag behavior:

- `Android APK` builds ABI-split APKs.
- `Android APK` publishes APKs and `update.json` to Cloudflare R2.
- `Android APK` attaches APK assets to the GitHub Release.
- `iOS Unsigned IPA` builds and attaches an unsigned IPA to the GitHub Release.

## Failure Handling

- If signing secrets are missing, configure them and rerun the tag workflow.
- If R2 validation fails, fix repository secrets/variables before retagging.
- If tests fail, fix on a branch, merge to `main`, and create a new patch tag.
- Do not overwrite release tags unless the maintainer explicitly asks for that.
