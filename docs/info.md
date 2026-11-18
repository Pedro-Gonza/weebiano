<!---
This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.
-->

## How it works

Weeb-iano is a tiny 8-key piano with a chibi singing character, driven entirely by hardware logic (no CPU, no frame buffer).

**Keys.** Eight active-high inputs `ui[0..7]` play the notes Do Re Mi Fa Sol La Si Do' (C5 to C6, square wave). The most recently pressed key wins; if it is released while others are still held, the lowest held key takes over.

**Sound.** `uio[7]` is a square-wave output for a passive buzzer or an amplifier. The pitch comes from a half-period table clocked at 25.175 MHz, so the notes are in tune when the board supplies that clock.

**Picture.** `uo[7:0]` is a standard 640x480 @ 60 Hz VGA output with 2 bits per colour channel. The screen is a 40x30 grid of 16x16-pixel cells:
- a 28x22-cell character sprite, stored as one mirrored base sprite plus small eye/mouth overlays (2 bits per pixel), blinks while idle and sings (mouth open and sprite bobbing) while a note plays;
- the playing note is shown top-left (a `#` next to it for sharps, `+` / `-` top-right when the octave is shifted up or down);
- a concentric-ring background is computed on the fly from the distance to the screen centre. While a key is held, the rings expand and take a colour pair per note; when idle they contract and slowly cycle through the eight palettes.

**Extra controls (`uio[6:0]`, all inputs).**

| Pin | Function |
|---|---|
| `uio[0]` | Octave up |
| `uio[1]` | Octave down (both together cancel) |
| `uio[2]` | Sharp (semitone up; ignored on Mi and Si) |
| `uio[4:3]` | Timbre (Duty Cycle variation); 0 = 50%,    1 = 25%,   2 = 12.5%,   3 = pluck (starts wide then narrows) |
| `uio[5]` | Vibrato (about 6 Hz) |
| `uio[6]` | Demo: plays a built-in tune while no key is held (29 s loop at 150 BPM); background is the same as idle patern but with a reversed direction |

Held keys always override the demo.

## How to test

1. Connect a VGA monitor, a passive buzzer between `uio[7]` and ground (add a series resistor if the pin is driven directly), and eight push buttons from 3.3 V to `ui[0..7]` with pull-downs.
2. Seven additional buttons or switches can be connected in order to test the "Extra controls" in a similar fashion as the aforementioned key notes (from 3.3 V to `uio[0..6]` with pull-downs).
3. Set the board clock to 25.175 MHz (about 25 MHz also works).
4. The idle character should appear, blinking. Press a key: the note name appears, the character sings and the buzzer plays the note.
5. Tie `uio[6]` high to start the demo tune; press any key to take over.

The cocotb testbench in `test/` checks the VGA timing, the pitch of all keys, sharp / octave / timbre, key priority, silence, the picture (label, sprite and ring colours) and the start of the demo tune. Can be run with `make -B` inside `test/`.

## External hardware

VGA connector with a resistor DAC (for example the Tiny Tapeout VGA PMOD), 8 push buttons, a passive buzzer or small amplifier on `uio[7]`, optional switches/buttons on `uio[6:0]`.
