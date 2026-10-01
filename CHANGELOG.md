# Changelog

All notable changes are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/)
and the project uses [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added
- Floating Globe / Delete-line control that appears beside the caret in editable text fields.
- Hold the Globe button to hold the Fn key (dictation); right-click it to send Return; ⌫ sends ⌘⌫.
- Panel stays at its initial position while typing in the same field.
- Terminal-aware placement, light/dark border, menu-bar item, launch at login, app icon.
- Opt-in local diagnostic log.
- Escape button in a row above the Globe / Delete-line buttons.
- Move handle (✥) on the panel's top-left corner, shown on hover: drag to nudge the panel up to 300 pt;
  the position lasts for the current field only. VoiceOver can nudge it with "Move up/down/left/right".

### Fixed
- Panel no longer stays stranded when the caret jumps far within the same field (e.g. select-all + delete in Obsidian); in note-taking apps (Obsidian, Notes, Bear, ...) it re-places next to the caret unless you moved it by hand. Terminals, browsers and chat apps keep the panel where it first appeared.
