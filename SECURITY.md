# Security Policy

## Supported Branch

Security fixes target the `main` branch first. Release packages are produced by
GitHub Actions from `v*` tags after the fix is merged.

## Reporting

Open a private report with the repository owner or contact the maintainer
directly. Do not file public Issues for:

- music account credentials, cookies, or tokens
- Android signing keys or passwords
- Cloudflare API tokens, R2 keys, or Worker credentials
- exploitable proxy behavior in `scripts/cf.js`

## Secret Handling

Build-time secrets must stay in GitHub Actions secrets or variables. The app can
receive Sy110 credentials through:

```text
SY110_USERNAME
SY110_PASSWORD
```

Do not commit real values to source, documentation, screenshots, logs, or test
fixtures.

## Validation

Before releasing a security-sensitive change:

- run `flutter analyze`
- run `flutter test`
- run `node --check scripts/cf.js` when the Worker script changes
- verify the relevant GitHub Actions run
- publish through a `v*` tag only after the workflow is green
