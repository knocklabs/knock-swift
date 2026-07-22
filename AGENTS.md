# AGENTS.md

## Cursor Cloud specific instructions

### What this repo is
This is the **Knock iOS SDK** (`Knock`), a Swift Package (`Package.swift`) distributed via SPM,
CocoaPods, and Carthage. It is a **library, not a runnable application** — there is no server or
app process to start. The module targets iOS 15+ and imports Apple-only frameworks throughout
(`SwiftUI`, `UIKit`, `WebKit`, `Combine`), and its dependency `SwiftPhoenixClient` relies on
Apple's `FoundationNetworking` types (e.g. `URLSessionWebSocketDelegate`).

### Platform limitation on the Linux cloud VM (important)
Full **build / test / lint require macOS + Xcode + the iOS Simulator** and therefore **cannot run
on this Linux cloud VM.** The canonical commands live in `.github/workflows/ci.yml` (Xcode 15.2,
`xcodebuild build-for-testing` / `test-without-building` against an iOS Simulator). Do not expect
`swift build` or `swift test` to succeed here — both fail on Linux because of the Apple-only
frameworks above (this is a platform constraint, not a setup gap).

### What works on Linux
A Swift toolchain (6.3.3, installed via `swiftly` at `~/.local/share/swiftly`) is available; `swift`
is on `PATH` via `~/.profile` sourcing `~/.local/share/swiftly/env.sh`. The only cross-platform SPM
commands that work are dependency-resolution ones:

- `swift package resolve` — resolves `SwiftPhoenixClient` (matches the CI "Resolve dependencies" step).
- `swift package show-dependencies` — prints the resolved dependency tree.

If a fresh shell cannot find `swift`, run `. "$HOME/.local/share/swiftly/env.sh"` first.

### Tests
Automated tests live in `Tests/KnockTests/`. They can only be executed on macOS via Xcode (see the
CI workflow); they are not runnable on Linux.
