# Novation ReMOTE SL / ZeRO SL (MkI) template format

Recovered with REA from the original *ReMOTE ZeRO SL Editor* 1.1 (2006, i386 slice):

- template writer `0x1c64e`
- control-record writer `0xa602a`
- repair routine `0x1c0b0`
- control-state accessors (vtable `0x2cb7e0`)

Every claim below was cross-checked against real templates: the 40 in the editor's `FactorySettings.blk`, the 33 dumps in `NovationSLMKIIDefaults/`, and 188 messages from Novation's `ReMOTE_SL_Templates_090408` collection. The reference codec (`Tools/slcodec.py`) re-encodes all of them byte-for-byte.

Confidence levels used below:
- **confirmed** = read from the original code *and* consistent with all data.
- **data** = consistent across all 73 templates, meaning not fully named.
- **raw** = preserved untouched by the editor.

## Message

One template is one SysEx message of exactly **4112 bytes**. Every byte between `F0` and `F7` is 7-bit; the original writer forces any byte ≥ 0x80 to 0.

| Offset | Size | Field | Confidence |
|---|---|---|---|
| 0 | 13 | Header `F0 00 20 29 02 03 7F mm 00 vv vv 00 ss` | confirmed |
| 7 | 1 | Transfer mode: `00` = single template for the keyboard's temporary memory (Novation's distributed .syx files, and the original editor's default header); `01` = stored to slot `ss` (keyboard dumps and banks) | confirmed |
| 9–10 | 2 | Format/OS version: editor files use `21 07`, keyboard dumps use `09 06`. Preserved. | data |
| 12 | 1 | Template slot 0–39 | confirmed |
| 13 | 35 | Template name, ASCII, space-padded | confirmed |
| 48 | 13 | Manufacturer name, ASCII, space-padded | confirmed |
| 61 | 7 | Template locals (keyboard/template flags) | raw |
| 68 | 1 | NUMCMN = 0x5A (90 controls); the original repairs any other value | confirmed |
| 69 | 1 | PGCNSIZE = 0x29 (41 bytes per control) | confirmed |
| 70 | 11 | Locals continued | raw |
| 81 | 16 | Row-select defaults: eight 14-bit values (`00 19 00 01 00 21 00 09 00 39 00 11 00 29 00 31`) | data |
| 97 | 14 | Keyboard settings (channel, ports, octave, transpose, velocity…) | raw |
| 111 | 40 | Four keyboard zones, 10 bytes each (see below) | data |
| 151 | 4 | — | raw |
| 155 | 16 | Drum-pad auto-off times, eight 14-bit values (e.g. `03 74` = 500) | data |
| 171 | 8 | Drum-pad velocity curves | data |
| 179 | 240 | Remaining template/pad settings | raw |
| 419 | 90 × 41 | Control records | confirmed |
| 4109 | 3 | Trailer `12 34 F7` | confirmed |

### Keyboard zone (10 bytes, at 111 + 10·n)

| Byte | Meaning |
|---|---|
| +0 | (MIDI channel − 1) \| group bits |
| +1 | Port bits \| group bits (same encoding as controls) |
| +2 | Velocity / curve (raw) |
| +3 | Bottom note |
| +4 | Top note |
| +5 | Transpose + 64 |
| +6 | Flags: 0x01 aftertouch, 0x02 pitch bend, 0x04 mod wheel |
| +7..+9 | Padding |

## Control order (index → physical control)

| Index | Control |
|---|---|
| 0–7 | Encoders 1–8 (left, endless) |
| 8–15 | Pots 1–8 (left section, below the left lower buttons) |
| 16–23 | Sliders 1–8 (right section, above the right upper buttons) |
| 24–31 | Left upper buttons |
| 32–39 | Left lower buttons |
| 40–47 | Right upper buttons |
| 48–55 | Right lower buttons |
| 56–63 | Drum pads 1–8 |
| 64 | Expression pedal |
| 65 | Sustain pedal |
| 66 | Mod wheel |
| 67 | Pitch bend |
| 68–71 | Touchpad X1, Y1, X2, Y2 |
| 72–77 | Transport: Rewind, Forward, Stop, Play, Record, Loop |
| 78–89 | Auxiliary / Automap slots (not used by typical templates) |

## Control record (41 bytes)

| Byte | Field |
|---|---|
| 0–7 | LCD name, 8 ASCII characters, space-padded |
| 8 | Type: 0 Disabled, 1 CC, 2 NRPN, 3 RPN, 4 SysEx, 5 MMC, 6 Note On/Off (note in byte 10, velocity in byte 12), 7 Note On/Off (alt), 8 Bank Select, 9 Program Change, 10 Pitch Bend, 11 Drum Note, 12 Aftertouch |
| 9–10 | Low / press value, 14-bit (MSB, LSB). For MMC the LSB is the MMC command; for drum notes the LSB is the note number. |
| 11–12 | High / release value, 14-bit (MSB, LSB) |
| 13 | Flags A: bit0 send 14-bit, bit1 pot pickup, bits 2/3/4 = button action Momentary/Toggle/Step (none = Normal) |
| 14 | Flags B: bits 5–6 pot catch-up (0 Jump, 1 Pickup, 2 Template, 3 Global); bits 0–4 other flags (raw) |
| 15 | Display format: 0 `0–127`, 1 `-64–63`, 3 On/Off, 6 REL1, 7 REL2, 17 APOT (2 = MMC; other values preserved) |
| 16 | Controller number MSB (NRPN/RPN MSB) |
| 17 | Controller number LSB (CC number, NRPN/RPN LSB, note) |
| 18 | Ports: 0x01 MIDI 1, 0x02 MIDI 2, 0x04 USB, 0x08 USB B, 0x10 USB C; group 0x40 = Common, 0x20 = Keyboard, none = own |
| 19 | (MIDI channel − 1) \| channel group (0x40 Common, 0x20 Keyboard) \| 0x10 flag. For MMC this is the device ID. |
| 20–21 | Snapshot value, 14-bit |
| 22 | Step size − 1 (button Step mode) |
| 23–25 | Extra state bytes (raw) |
| 26 | SysEx checksum start: 1 for a plain message; Roland templates store 4 (checksum over the address and data that follow the command byte). 0 when there is no DV |
| 27 | SysEx message length: bytes between F0 and F7, DV and checksum included, maximum 12 |
| 28 | DV position, 1-based (0 = none) |
| 29–40 | The message bytes for every position, with a placeholder byte at the DV position, zero-padded |

The SysEx data decodes to recognisable manufacturer messages: Access Virus `00 20 33 01 10 71 40 29 DV`, Roland MKS-50 `41 36 00 23 20 01 0E DV`, Yamaha TX81Z `43 10 12 34 DV`, and Roland JV-1080 `41 10 6A 12 03 00 10 6E DV 00` (checksum start 4).

## Transfer

- **Receive.** On the keyboard, press Global, page up to "Template xx", and press the button under it. The keyboard sends one 4112-byte message.
- **Send one template.** Send it with transfer mode `00`. The keyboard shows "Template Dump Received" and holds it in temporary memory; press Write on the keyboard to store it in flash.
- **Bulk.** Send each template with transfer mode `01`. The original pauses about 100 ms between templates (`usleep(100000)`).
- Global "Memory Protect" must be off to write to flash.

Confirmed on a ReMOTE SL (October 2026): single-template send (mode `00`) and Send All / Dump All (mode `01`) both work with this editor, and templates sent from the keyboard (Global → Template xx) are received correctly.
