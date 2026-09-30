# Wispr Assist

A tiny floating control for macOS that appears next to the text cursor, so you can **hold a button to
dictate** and tap another to **delete the line** without reaching for the keyboard.

- **Hold 🌐** — presses and holds the Globe / Fn key for as long as you hold the button. Start and stop
  dictation (Wispr Flow, macOS Dictation, or anything bound to Fn) with the mouse.
- **Right-click 🌐** — sends **Return** (submit a message, run a command, accept a search).
- **⌫** — sends **⌘⌫**, deleting from the caret to the start of the line.
- **Stays where it landed.** The control appears beside the caret and then holds still while you type or
  dictate, so your mouse doesn't have to chase it. It resets when you switch app or field.
- **Move it out of the way.** Hover the control and drag the ✥ handle on its top-left corner to nudge
  it (up to 300 pt) and see what's underneath. It stays there for that field only and resets on the next
  field or app.
- **Only where it's useful.** It appears for editable text fields only and never for password fields.
- Follows the light / dark theme, works in terminals, and runs as a menu-bar app.

> Wispr Assist is an independent project and is not affiliated with Wispr or Wispr Flow. See [NOTICE.md](NOTICE.md).

## Install

**Homebrew** *(available once the first release is published)*

```sh
brew install --cask wispr-assist
```

**Download** the latest notarized `.dmg` from the [Releases](../../releases) page and drag the app to
`/Applications`.

**Build from source** (macOS 13+, Xcode or the Swift 5.9+ toolchain):

```sh
git clone <this repository> && cd <this repository>
./scripts/build_app.sh          # produces build/Wispr Assist.app
open "build/Wispr Assist.app"
```

## First run: grant Accessibility access

Wispr Assist needs **Accessibility** permission to find the focused text field and to send key presses.
macOS will prompt on first launch; otherwise open **System Settings ▸ Privacy & Security ▸ Accessibility**
and switch **Wispr Assist** on. The menu-bar icon changes from ⚠️ to a waveform once it's active.

If the switch is on but nothing happens (this can follow an update or re-signing), reset and re-approve it:

```sh
tccutil reset Accessibility app.wisprassist.WisprAssist
```

## Privacy

Wispr Assist runs entirely on your Mac. It has no network code, no analytics and no accounts. It reads
the *position and type* of the focused text field through the Accessibility API — never the text you
type — and sends only the key presses listed above. An optional local diagnostic log is **off by
default** (see [Troubleshooting](#troubleshooting)).

## Menu-bar options

- **Show Floating Control** — turn the control on or off.
- **Open at Login** — enabled by default the first time you run the app.

## Troubleshooting

It doesn't appear in an app. Some apps don't expose their text fields to Accessibility. To help us add
support, enable the diagnostic log, reproduce the problem, and attach the log to an issue:

```sh
defaults write app.wisprassist.WisprAssist debugLogging -bool true   # then restart the app
cat ~/Library/Logs/WisprAssist.log
```

The log contains app bundle identifiers, UI element roles and flags. It never contains text you type.

## Known limitations

- Fields that don't report a caret position (some Chromium inputs) fall back to the left edge of the field.
- Canvas-based editors (e.g. Google Docs) and some games expose no text fields to Accessibility.
- The Globe button sends a synthetic Fn key event; macOS versions and keyboard settings can change how
  that is interpreted. Reports welcome.

## Contributing

Bug reports, compatibility reports and pull requests are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md)
and [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## License

[MIT](LICENSE).
