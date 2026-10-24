"""Reference codec for Novation ReMOTE SL / ZeRO SL (MkI) template SysEx.

Derived from the original editor's i386 code (control writer at 0xa602a,
template writer at 0x1c64e) and validated against 73 real templates.
"""
TEMPLATE_SIZE = 4112
CONTROL_BASE = 419
CONTROL_SIZE = 41
CONTROL_COUNT = 90

TYPES = {0: "Disabled", 1: "CC", 2: "NRPN", 3: "RPN", 4: "SysEx", 5: "MMC",
         6: "Note On/Off", 7: "Note On/Off (alt)", 8: "Bank Select",
         9: "Program Change", 10: "Pitch Bend", 11: "Drum Note", 12: "Aftertouch"}
DISPLAY = {0: "0 to 127", 1: "-64 to 63", 3: "On/Off", 6: "REL1", 7: "REL2", 17: "APOT"}
ACTIONS = {0: "Normal", 1: "Momentary", 2: "Toggle", 3: "Step"}
CATCHUP = {0: "Jump", 1: "Pickup", 2: "Template", 3: "Global"}
MMC = {1: "Stop", 2: "Play", 3: "Def Play", 4: "Forward", 5: "Rewind", 6: "Record",
       7: "Record Exit", 8: "Record Pause", 9: "Pause", 10: "Eject", 11: "Chase",
       12: "Err Reset", 13: "MMC Reset"}

# group bits shared by port byte (18) and channel byte (19): 0x40 -> group 0, 0x20 -> group 2, none -> group 1
def _group_from_bits(b):
    return 0 if b & 0x40 else (2 if b & 0x20 else 1)

def _group_bits(g):
    return {0: 0x40, 1: 0x00, 2: 0x20}[g]

def ctl_slice(t, i):
    o = CONTROL_BASE + i * CONTROL_SIZE
    return t[o:o + CONTROL_SIZE]

def decode_control(r):
    r = bytes(r)
    return {
        "name": r[0:8].decode("latin1"),
        "type": r[8],
        "lowMSB": r[9], "lowLSB": r[10],      # LSB doubles as MMC command (type 5) / note (type 6)
        "highMSB": r[11], "highLSB": r[12],
        "flagsA": r[13],                       # bit0 14-bit, bit1 pickup, bits2-4 button action (1/2/3)
        "flagsB": r[14],                       # bits5-6 pot catch-up, other bits preserved
        "display": r[15],
        "numMSB": r[16],
        "numLSB": r[17],                       # CC number / NRPN LSB / note
        "ports": r[18],                        # 0x01 MIDI1 0x02 MIDI2 0x04 USB 0x08 USB B 0x10 USB C + group bits
        "channel": r[19],                      # (channel-1) | group bits | 0x10 flag ; MMC device for type 5
        "snapMSB": r[20], "snapLSB": r[21],
        "step": r[22],                         # step size - 1
        "extra": r[23:26],
        "checksumStart": r[26],                # 1 plain, e.g. 4 = Roland checksum start, 0 = no DV
        "sysexLength": r[27],                  # bytes between F0/F7 incl. DV (max 12)
        "dvPosition": r[28],                   # 1-based, 0 = none
        "sysex": r[29:41],                     # every position, placeholder at the DV position
    }

def encode_control(c):
    out = bytearray(c["name"].encode("latin1")[:8].ljust(8, b" "))
    out += bytes([c["type"], c["lowMSB"], c["lowLSB"], c["highMSB"], c["highLSB"],
                  c["flagsA"], c["flagsB"], c["display"], c["numMSB"], c["numLSB"],
                  c["ports"], c["channel"], c["snapMSB"], c["snapLSB"], c["step"]])
    out += bytes(c["extra"])
    out += bytes([c["checksumStart"], c["sysexLength"], c["dvPosition"]])
    out += bytes(c["sysex"])
    assert len(out) == CONTROL_SIZE
    return bytes(out)

def button_action(c):
    a = c["flagsA"]
    return 3 if a & 0x10 else 2 if a & 0x08 else 1 if a & 0x04 else 0

def catchup(c):
    return (c["flagsB"] >> 5) & 3

def midi_channel(c):
    return (c["channel"] & 0x0F) + 1

def decode_template(t):
    t = bytes(t)
    assert len(t) == TEMPLATE_SIZE and t[0] == 0xF0 and t[-1] == 0xF7
    return {
        "header": t[0:13],
        "name": t[13:48].decode("latin1"),
        "manufacturer": t[48:61].decode("latin1"),
        "globals": t[61:CONTROL_BASE],
        "controls": [decode_control(ctl_slice(t, i)) for i in range(CONTROL_COUNT)],
        "trailer": t[CONTROL_BASE + CONTROL_COUNT * CONTROL_SIZE:],
    }

def encode_template(d):
    out = bytearray(d["header"])
    out += d["name"].encode("latin1")[:35].ljust(35, b" ")
    out += d["manufacturer"].encode("latin1")[:13].ljust(13, b" ")
    out += d["globals"]
    for c in d["controls"]:
        out += encode_control(c)
    out += d["trailer"]
    assert len(out) == TEMPLATE_SIZE
    return bytes(out)
