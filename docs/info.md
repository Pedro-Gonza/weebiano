<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->

## How it works

8 input "piano", each button represents a note, 8 outputs go to VGA to display currently playing note and a small looping animation or a short 2 frame "idle" animation. An additional IO pin is reserved to connect a passive buzzer to playback the corresponding note that gets presssed.

## How to test

Connect all external hardware and power up, start playing notes by pushing the buttons.

## External hardware

8 pushbuttons to inputs, vga output and a passive buzzer to uio0.
