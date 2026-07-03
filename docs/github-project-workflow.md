# GitHub Project Workflow

This repository follows the GitHub-first workflow used by the maintainer.

## Repository State

- Default branch: `main`
- Implementation branches: `codex/*`
- Required release trigger: `v*` tags
- Android package workflow: `Android APK`
- iOS package workflow: `iOS Unsigned IPA`

## Work Intake

Use Issues for concrete work:

- Bug reports need reproduction steps and evidence.
- Feature requests need acceptance criteria.
- Engineering tasks need scope and a verification plan.

Use Milestones for version or stabilization ranges. Project board status should
mirror the Issue lifecycle: Backlog, Ready, In Progress, In Review, Done.

## PR Gate

Before merge:

- `flutter analyze` passes locally or in Actions.
- `flutter test` passes locally or in Actions.
- `node --check scripts/cf.js` passes when the Cloudflare Worker changes.
- Workflow changes are verified by a real GitHub Actions run.
- Documentation is updated for release, proxy, or user-visible behavior.

## Release Gate

`main` push validates the code path but does not publish release assets. To
publish:

1. Confirm `main` Actions are green.
2. Confirm repository secrets and variables are configured.
3. Push a `v*` tag.
4. Watch `Android APK` and `iOS Unsigned IPA`.
5. Verify GitHub Release assets and Cloudflare R2 update manifest.

## Required Repository Secrets

Sy110 app API credentials:

- `SY110_USERNAME`
- `SY110_PASSWORD`

Android signing:

- `ANDROID_RELEASE_KEYSTORE_BASE64`
- `ANDROID_RELEASE_KEYSTORE_PASSWORD`
- `ANDROID_RELEASE_KEY_ALIAS`
- `ANDROID_RELEASE_KEY_PASSWORD`

Cloudflare R2 release publishing:

- `CLOUDFLARE_R2_ACCESS_KEY_ID`
- `CLOUDFLARE_R2_SECRET_ACCESS_KEY`
- `CLOUDFLARE_R2_BUCKET`
- `CLOUDFLARE_R2_PUBLIC_BASE_URL`

Repository variables:

- `CLOUDFLARE_R2_ACCOUNT_ID`
- `CLOUDFLARE_R2_PREFIX=music_car_app`
- optional `MUSIC_CAR_UPDATE_MANIFEST_URL`

## Manual GitHub Settings

These settings should remain enabled:

- Issues
- Projects
- Dependabot alerts
- Secret scanning / push protection where available
- Branch ruleset for `main`

Wiki and Discussions stay disabled until there is a real maintenance need.
