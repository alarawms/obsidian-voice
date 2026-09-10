# Obsidian Voice Capture

An [Omarchy](https://omarchy.org) plugin: press a key, talk, press it again.
The clip is transcribed locally with Omarchy's built-in `voxtype`
(whisper.cpp — no network, nothing leaves the machine) and filed straight
into your Obsidian vault:

- appended as a bullet under `## Voice Notes` in today's daily note
  (`daily/YYYY-MM-DD.md`, created if missing), linking to —
- a standalone note in `Inbox/` with `tags: [voice-capture]` frontmatter and
  the full transcript.

A microphone icon in the bar mirrors the state (idle / recording /
transcribing) and shows the last capture; the keybinding works with the bar
widget disabled too — a bash CLI does all the actual work.

## Requirements

- Omarchy (Quickshell-based bar/plugin system)
- [`voxtype`](https://github.com/wispbit/voxtype) — Omarchy's built-in
  dictation engine, with a model downloaded (`omarchy-voxtype-install`, or
  Settings → Voxtype)
- `pw-record` (PipeWire — ships with Omarchy)
- `jq`
- An existing Obsidian vault

## Install

```bash
git clone https://github.com/alarawms/obsidian-voice ~/.config/omarchy/plugins/alarawms.obsidian-voice
~/.config/omarchy/plugins/alarawms.obsidian-voice/install.sh
```

or, from a checkout anywhere else:

```bash
git clone https://github.com/alarawms/obsidian-voice
./obsidian-voice/install.sh
```

Then:

1. Set `"vault"` in `~/.config/obsidian-voice/config.json` to your vault's
   absolute path (the file is created — empty — on first run; the plugin
   refuses to record until this is set, so it never guesses at a vault).
2. Add a keybinding — `~/.config/hypr/bindings.lua`:
   ```lua
   o.bind("SUPER + SHIFT + V", "Voice capture to Obsidian", "obsidian-voice-capture toggle")
   ```
   then `hyprctl reload`. (Pick any key combo; check it's free first with
   `omarchy menu keybindings --print`.)

Uninstall: `./install.sh --uninstall`, then `omarchy plugin remove
alarawms.obsidian-voice` if it was added with `omarchy plugin add`.

## Usage

```
obsidian-voice-capture start            begin recording
obsidian-voice-capture stop             stop, transcribe, file the note
obsidian-voice-capture toggle           start if idle, stop if recording   (what the key does)
obsidian-voice-capture cancel           stop and discard, no transcript
obsidian-voice-capture status [--json]  print current state
```

Left-click the bar icon to toggle recording; right-click for the popup
(last capture, shortcuts to open the vault or the config file); middle-click
while recording to discard.

## Config — `~/.config/obsidian-voice/config.json`

| key | default | meaning |
|---|---|---|
| `vault` | *(empty — required)* | Obsidian vault root, absolute path |
| `dailyDir` | `daily` | daily notes folder, relative to vault |
| `inboxDir` | `Inbox` | folder for the per-capture note |
| `dailyHeading` | `## Voice Notes` | heading captures are inserted under (newest first) |
| `filingMode` | `both` | `daily`, `atomic`, or `both` |
| `model` | *(empty — use voxtype's own configured model)* | override, e.g. `base.en`, `small`, `medium` — must already be downloaded |
| `language` | `auto` | voxtype `--language` |
| `maxDurationSecs` | `300` | auto-stops a forgotten recording |
| `keepAudio` | `false` | keep the WAV in `$XDG_RUNTIME_DIR` after transcribing (still lost on logout either way) |

Edit the file directly — no reload needed, the next capture picks it up.

## Notes

- Recording uses `pw-record` at 16kHz mono; transcription is `voxtype
  transcribe`. Only the transcript line of its output is kept (whisper.cpp's
  own init logging is filtered out the same way the Speech to Text plugin's
  daemon does it).
- Silence produces no note — status goes back to idle, nothing is written to
  the vault.
- The marketplace validates listings, not plugin security — like any Omarchy
  plugin, this runs unsandboxed. Read `bin/obsidian-voice-capture` before
  trusting it with your vault.

## License

MIT — see [LICENSE](LICENSE).
