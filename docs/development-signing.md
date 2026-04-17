# Stable Development Signing Workflow For SnipKey

Use the signed app bundle workflow for daily development. Avoid `swift run` when you want macOS permissions such as Accessibility and Input Monitoring to remain attached to one stable app identity.

This workflow works with either:

- a free Apple Account signed into Xcode, which Xcode exposes as a `Personal Team`
- a paid Apple Developer Program membership

## Targets

- `make signing-identities`: list available `Apple Development` signing identities
- `make signing-help`: print the Xcode Personal Team setup steps
- `make bootstrap-personal-team`: ask Xcode to create a Personal Team `Apple Development` identity using this package's macOS scheme
- `make print-signing-identity`: print the identity selected for signing
- `make bundle-dev`: build a signed dev app bundle in `.build/dev-bundle/SnipKey Dev.app`
- `make install-dev`: install the signed app to `~/Applications/SnipKey Dev.app`
- `make run-dev`: reinstall, restart, and launch the fixed-path dev app
- `make restart-dev`: alias for `make run-dev`
- `make verify-dev`: print the installed app's identifier and designated requirement
- `make run-swift`: run the bare Swift executable without bundling or signing

## Identity Used For TCC

The dev workflow signs the app with an `Apple Development` certificate and rewrites the installed dev bundle's identifier to `com.snipkey.app.dev`.

That gives the development app a stable identity as long as these stay the same:

- `Apple Development` signing identity
- bundle identifier
- installed app path `~/Applications/SnipKey Dev.app`

## Setup With A Free Apple Account

If `make signing-identities` prints no matches, sign into Xcode with your Apple Account first:

1. Open `Xcode`
2. Go to `Settings...`
3. Open `Accounts`
4. Add your Apple Account
5. Confirm you see a team with `(Personal Team)` in its name

After that, let this repo trigger Xcode's automatic signing flow for the package:

```bash
make bootstrap-personal-team
make signing-identities
make run
```

## Limits Of Personal Team

Apple's free `Personal Team` workflow is enough for local testing, but Apple notes that this setup may require periodic re-provisioning. The fixed-path signed app workflow in this repo reduces unnecessary identity churn between rebuilds, but Personal Team is still less durable than a paid development membership for long-lived signing assets.

If you have multiple development certificates, pick one explicitly:

```bash
make run-dev APPLE_DEVELOPMENT_IDENTITY="Apple Development: Your Name (TEAMID)"
```
