# macOS Development

This fork currently focuses on getting the macOS client running before adding
cloud sync or Windows support.

## Requirements

- macOS Sonoma 14 or newer
- Xcode with the macOS SDK
- Network access for Swift Package Manager dependencies

## Build

Keep Xcode build products and SwiftPM checkouts inside the repository-local
`work/` directory:

```sh
mkdir -p work/DerivedData work/SourcePackages

xcodebuild -resolvePackageDependencies \
  -project Maccy.xcodeproj \
  -scheme Maccy \
  -derivedDataPath work/DerivedData \
  -clonedSourcePackagesDirPath work/SourcePackages

xcodebuild build \
  -project Maccy.xcodeproj \
  -scheme Maccy \
  -configuration Debug \
  -derivedDataPath work/DerivedData \
  -clonedSourcePackagesDirPath work/SourcePackages \
  CODE_SIGNING_ALLOWED=NO
```

The Debug app is produced at:

```text
work/DerivedData/Build/Products/Debug/Maccy.app
```

## Run

```sh
open work/DerivedData/Build/Products/Debug/Maccy.app
```

For full paste automation, macOS may require granting Accessibility permission
to the built app in System Settings -> Privacy & Security -> Accessibility.

## Tests

Run the unit test target without UI tests:

```sh
xcodebuild test \
  -project Maccy.xcodeproj \
  -scheme Maccy \
  -configuration Debug \
  -destination platform=macOS \
  -only-testing:MaccyTests \
  -derivedDataPath work/DerivedData \
  -clonedSourcePackagesDirPath work/SourcePackages \
  CODE_SIGNING_ALLOWED=NO
```

Two clipboard ignore-application tests depend on the current frontmost
application bundle identifier. They can fail when run from a non-Xcode
automation environment because the test fixture expects Xcode or Finder to be
frontmost.
