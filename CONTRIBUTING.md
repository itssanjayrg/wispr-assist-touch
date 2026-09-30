# Contributing

Thanks for helping improve Wispr Assist! By participating you agree to the [Code of Conduct](CODE_OF_CONDUCT.md).

## Getting started

```sh
swift build                 # debug build
swift test                  # unit tests (needs Xcode / XCTest)
./scripts/build_app.sh      # builds build/Wispr Assist.app
```

Requirements: macOS 13+, Swift 5.9+. Universal (Apple silicon + Intel) builds need full Xcode.

Because the app is ad-hoc signed locally, macOS forgets its Accessibility permission on every rebuild.
Either re-approve it each time (`tccutil reset Accessibility app.wisprassist.WisprAssist`), or sign with a
stable identity: `SIGN_IDENTITY="Your Certificate" ./scripts/build_app.sh`.

## Project layout

Logic with no UI or OS dependencies lives in `Sources/WisprAssistCore` and is unit tested. Anything
that touches AppKit or the Accessibility API lives in `Sources/WisprAssist`. See
[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md). Prefer putting new decision logic in the core module.

## Style

The code is formatted with `swift format` using the repository's `.swift-format` configuration:

```sh
swift format -i -r Sources Tests      # format
swift format lint --strict -r Sources Tests
```

CI fails on lint errors. Keep comments focused on *why*, and follow the surrounding code's idiom.

## Pull requests

- Keep changes focused; one concern per PR.
- Add or update tests for behaviour in `WisprAssistCore`.
- Update `CHANGELOG.md` under **Unreleased**.
- For UI or placement changes, include a screenshot or short clip and name the apps you tried it in.

## Compatibility reports

The most valuable contribution is "it works / doesn't work in *App X*". Enable the diagnostic log
(see the README) and include the relevant lines.

## Privacy rules for contributors

Do not add networking, telemetry, or anything that reads or stores the text a user types. Any
diagnostic output must stay local and opt-in.
