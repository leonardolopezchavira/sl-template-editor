# SL Template Editor

A native macOS editor for the templates of the **Novation ReMOTE SL and ZeRO SL (MkI)**
MIDI controllers. Novation's own *ReMOTE ZeRO SL Editor* (2006) is a 32-bit PowerPC/Intel
Carbon app that stopped working after macOS 10.14; this one runs natively on Apple Silicon.

It receives templates from the keyboard, edits them, and sends them back over USB or MIDI —
one template at a time or a whole 40-template bank.

The template format was reverse-engineered from the original editor's code and checked
byte-for-byte against hundreds of real templates. See [`Docs/FORMAT.md`](Docs/FORMAT.md).

## Build

You need macOS 13 or later and Xcode (or its command-line tools).

```sh
git clone https://github.com/leonardolopezchavira/sl-template-editor.git
cd sl-template-editor
./build.sh
```

`build.sh` runs the tests, builds a release binary, draws the app icon, and creates
**SL Template Editor.app** in the folder that contains `sl-template-editor`. The first time,
macOS may ask you to confirm opening it because the app is signed locally.

For development, use `swift run` or open `Package.swift` in Xcode.

## Using it

- **Receive from the keyboard.** On the keyboard press Global, page up to "Template xx", then
  press the button beneath it. The template appears in the list at its slot number.
- **Open files.** `.syx` single templates, `.syx` banks, hex `.txt` dumps, or the original
  editor's `FactorySettings.blk`. You can also drop files on the window. Single templates fill
  the list in order (slot 1, 2, 3…); right-click an empty slot to open a file into that slot.
- **Edit.** Click a control on the surface. The inspector shows the fields for its type: CC,
  NRPN/RPN, note, drum note, MMC, SysEx (with `DV` for the value), range, display format,
  button type and step size, pot strategy, channel and port routing. *Template settings* has the
  name, manufacturer and the four keyboard zones.
- **Send This Template (⌘U).** The keyboard shows "Template Dump Received" and holds it in
  temporary memory; press Write on the keyboard to store it (Memory Protect must be off).
- **Send All** stores every listed template in its slot, like a bank dump.
- **Save.** ⌘S saves the current template as `.syx`; ⇧⌘S saves every listed template as a bank.

## Repository contents

| Path | What it is |
|---|---|
| `Sources/SLTemplateKit` | The template codec. It edits the raw 4112-byte SysEx in place, so bytes it doesn't understand are kept exactly. |
| `Sources/SLTemplateEditor` | The SwiftUI app and its CoreMIDI transfer code. |
| `Tests` | Codec tests. The round-trip tests use Novation's factory templates when they are found next to the package; they skip otherwise (those files are not distributed here). |
| `Docs/FORMAT.md` | The reverse-engineered template format, with a confidence level for each field. |
| `Tools/make_icon.swift` | Draws the app icon (run by `build.sh`). |
| `Tools/slcodec.py` | The Python reference codec used during reverse engineering. |
| `Templates/` | Ready-made templates, each with setup notes: Korg wavestate native, M-VAVE FM-1 (emulator), ASM Hydrasynth (NRPN and CC versions). |
| `Patches/fm1-live-midi-panel.patch` | A patch for [fm1-emu](https://github.com/joakimeriksson/fm1-emu)'s desktop app that lets MIDI control the FM-1's panel; needed by the FM-1 template. |

## Known limits

- Some global settings (keyboard octave/velocity/aftertouch, drum-pad options) are kept and
  shown raw but are not yet editable.
- No OS updater, VST plug-in import or Automap features; those depended on discontinued
  Novation software.

## Licence

GNU General Public License v3.0 — see [`LICENSE`](LICENSE).

Not affiliated with or endorsed by Novation / Focusrite. ReMOTE SL and ZeRO SL are trademarks of
their owners. No Novation software, factory templates or documentation are included.
