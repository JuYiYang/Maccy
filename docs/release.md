# ClipBridge macOS Release

This repository builds the macOS ClipBridge app. It is a fork of Maccy and keeps
the Xcode scheme name `Maccy` for now.

## Local Release Build

```sh
xcodebuild \
  -project Maccy.xcodeproj \
  -scheme Maccy \
  -configuration Release \
  -derivedDataPath work/DerivedDataRelease \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Output:

```text
work/DerivedDataRelease/Build/Products/Release/ClipBridge.app
```

Package the app:

```sh
ditto -c -k --keepParent \
  work/DerivedDataRelease/Build/Products/Release/ClipBridge.app \
  work/DerivedDataRelease/Build/Products/Release/ClipBridge-macOS-Release.zip
```

Output:

```text
work/DerivedDataRelease/Build/Products/Release/ClipBridge-macOS-Release.zip
```

## GitHub Release Packaging

The workflow in `.github/workflows/release.yml` builds on GitHub's `macos-26`
runner so it has the same Xcode 26 SDK family used by this fork. It uploads
`ClipBridge-macOS-Release.zip` as a workflow artifact.

When a tag matching `v*` is pushed, the workflow also creates or updates a
GitHub Release and uploads the zip as a release asset.

Example:

```sh
git tag v0.1.0
git push origin v0.1.0
```

## Signing

The current automated build uses ad-hoc signing. It is suitable for internal
testing, but not for a polished public distribution.

For public releases, add Apple Developer ID signing and notarization:

- Store the Developer ID certificate in GitHub Actions secrets.
- Sign the app with the Developer ID Application identity.
- Submit the zip or app to Apple notarization.
- Staple the notarization ticket before publishing.

Until that is added, users may need to approve the app manually in macOS Privacy
& Security after downloading.
