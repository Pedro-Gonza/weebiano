# Weeb-iano testbench (cocotb).  Only top-level pins are used, so it also runs on the gate-level netlist.
#
#   test_vga_timing      hsync / vsync period and pulse width (640x480 @ ~60 Hz)
#   test_notes           8 keys -> audio pitch, sharp, octave, timbre keep the pitch
#   test_key_priority    last pressed key wins, release falls back to the lowest held key
#   test_silence         no key, no demo -> audio pin stays low
#   test_picture         label / sprite / ring colours seen on the VGA pins (one sample per 16x16 cell)
#   test_demo            demo tune starts: first notes, pitch and 150 BPM timing
import itertools
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, FallingEdge, RisingEdge, Timer
from cocotb.utils import get_sim_time

CLK_PS   = 39722                 # 25.175 MHz
H_TOTAL  = 800
V_TOTAL  = 525
FRAME    = H_TOTAL * V_TOTAL     # clocks per frame
CLK_HZ   = 1e12 / CLK_PS

# uio_in control bits
OCT_UP, OCT_DN, SHARP, TIMBRE0, TIMBRE1, VIB, DEMO = (1 << i for i in range(7))

# equal temperament, Hz: C5 D5 E5 F5 G5 A5 B5 C6
NOTES = [523.25, 587.33, 659.25, 698.46, 783.99, 880.00, 987.77, 1046.50]
NAMES = ["Do", "Re", "Mi", "Fa", "Sol", "La", "Si", "Do'"]
SHARPS = {0: 554.37, 1: 622.25, 3: 739.99, 4: 830.61, 5: 932.33}      # Mi / Si have no sharp

# uo_out -> RGB, as in the Tiny Tapeout VGA template
PALETTE = {}
for r1, r0, g1, g0, b1, b0 in itertools.product(range(2), repeat=6):
    rgb = (170 * r1 + 85 * r0, 170 * g1 + 85 * g0, 170 * b1 + 85 * b0)
    for sync in (0x00, 0x08, 0x80, 0x88):
        PALETTE[(b0 << 6 | g0 << 5 | r0 << 4 | b1 << 2 | g1 << 1 | r1) | sync] = rgb
HAIR, SKIN, OUTLINE, YELLOW = (0, 170, 170), (255, 255, 170), (85, 85, 85), (255, 255, 0)


async def reset(dut, ui=0, uio=0):
    cocotb.start_soon(Clock(dut.clk, CLK_PS, unit="ps").start())
    dut.ena.value = 1
    dut.ui_in.value = ui
    dut.uio_in.value = uio
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 2)


async def clean_rising(dut):
    """Next rising edge of the audio pin that stays high for at least 50 ns.
    A real square-wave edge always does; the 1-2 ns glitches that the gate-level netlist (unit
    gate delays) shows when several slot bits change at once do not, and are harmless on the buzzer."""
    while True:
        await RisingEdge(dut.audio)
        await Timer(50, unit="ns")
        if int(dut.audio.value) == 1:
            return


async def measure_hz(dut, periods=4):
    """Frequency of the audio pin, from `periods` full periods (rising edge to rising edge)."""
    await clean_rising(dut)
    t0 = get_sim_time("ps")
    for _ in range(periods):
        await clean_rising(dut)
    return periods * 1e12 / (get_sim_time("ps") - t0)


def close(hz, ref, tol=0.01):
    return abs(hz - ref) <= ref * tol


async def count_edges(dut, clocks):
    n = 0

    async def watch():
        nonlocal n
        while True:
            await dut.audio.value_change
            n += 1

    task = cocotb.start_soon(watch())
    await ClockCycles(dut.clk, clocks)
    task.cancel()
    return n


@cocotb.test()
async def test_vga_timing(dut):
    await reset(dut)
    # hsync: low for 96 clocks, period 800
    await FallingEdge(dut.hsync)
    t0 = get_sim_time("ps")
    await RisingEdge(dut.hsync)
    assert round((get_sim_time("ps") - t0) / CLK_PS) == 96, "hsync pulse width"
    await FallingEdge(dut.hsync)
    assert round((get_sim_time("ps") - t0) / CLK_PS) == H_TOTAL, "hsync period"
    # vsync: low for 2 lines, period one frame (525 lines)
    await FallingEdge(dut.vsync)
    t0 = get_sim_time("ps")
    await RisingEdge(dut.vsync)
    assert round((get_sim_time("ps") - t0) / CLK_PS) == 2 * H_TOTAL, "vsync pulse width"
    await FallingEdge(dut.vsync)
    assert round((get_sim_time("ps") - t0) / CLK_PS) == FRAME, "vsync period"
    dut._log.info("frame rate at 25.175 MHz: %.2f Hz", CLK_HZ / FRAME)


@cocotb.test()
async def test_notes(dut):
    await reset(dut)
    for i, ref in enumerate(NOTES):
        dut.ui_in.value = 1 << i
        await ClockCycles(dut.clk, 2000)
        hz = await measure_hz(dut)
        dut._log.info("%-4s %7.2f Hz (expected %7.2f)", NAMES[i], hz, ref)
        assert close(hz, ref), f"{NAMES[i]}: {hz:.2f} Hz, expected {ref} Hz"

    # sharp pin: semitone up; ignored on Mi and Si
    dut.uio_in.value = SHARP
    for i in range(7):
        dut.ui_in.value = 1 << i
        await ClockCycles(dut.clk, 2000)
        hz = await measure_hz(dut)
        ref = SHARPS.get(i, NOTES[i])
        assert close(hz, ref), f"{NAMES[i]}#: {hz:.2f} Hz, expected {ref} Hz"

    # octave up / down (both pins together cancel)
    dut.ui_in.value = 1 << 0
    for ctl, factor in ((OCT_UP, 2.0), (OCT_DN, 0.5), (OCT_UP | OCT_DN, 1.0)):
        dut.uio_in.value = ctl
        await ClockCycles(dut.clk, 2000)
        hz = await measure_hz(dut)
        assert close(hz, NOTES[0] * factor), f"octave ctl {ctl:#x}: {hz:.2f} Hz"

    # timbre changes the duty cycle, not the pitch
    for t in range(4):
        dut.uio_in.value = t << 3
        await ClockCycles(dut.clk, 2000)
        hz = await measure_hz(dut)
        assert close(hz, NOTES[0]), f"timbre {t}: {hz:.2f} Hz"


@cocotb.test()
async def test_key_priority(dut):
    await reset(dut)
    DO, MI, FA, SOL, LA = 1 << 0, 1 << 2, 1 << 3, 1 << 4, 1 << 5
    steps = [  # (keys held, expected note index, why)
        (DO,            0, "Do alone"),
        (DO | SOL,      4, "Sol pressed later wins"),
        (DO,            0, "Sol released: Do"),
        (DO | MI,       2, "Mi pressed later wins"),
        (DO | MI | LA,  5, "La pressed later wins"),
        (DO | MI,       0, "La released: lowest held key (Do)"),
        (MI,            2, "Do released: Mi"),
        (MI | FA,       3, "Fa pressed later wins"),
    ]
    for keys, idx, why in steps:
        dut.ui_in.value = keys
        await ClockCycles(dut.clk, 3000)
        hz = await measure_hz(dut)
        assert close(hz, NOTES[idx]), f"{why}: got {hz:.2f} Hz, expected {NAMES[idx]} {NOTES[idx]} Hz"


@cocotb.test()
async def test_silence(dut):
    await reset(dut)
    n = await count_edges(dut, FRAME)
    assert n == 0, "audio pin toggles with no key and no demo"
    dut.ui_in.value = 1
    await ClockCycles(dut.clk, 5000)
    dut.ui_in.value = 0
    await ClockCycles(dut.clk, 5000)
    n = await count_edges(dut, FRAME // 2)
    assert n == 0, "audio pin keeps toggling after the key is released"
    assert int(dut.uio_oe.value) == 0x80, "only uio[7] (audio) may be an output"


async def grab_cells(dut):
    """One sample at the centre of every 16x16 cell of the 640x480 picture -> 30 rows x 40 cols of RGB."""
    await FallingEdge(dut.vsync)                          # vsync starts at line 490; line 0 is 35 lines later
    await ClockCycles(dut.clk, 35 * H_TOTAL + 8 * H_TOTAL + 8)
    rows = []
    for cy in range(30):
        row = []
        for cx in range(40):
            row.append(PALETTE[int(dut.uo_out.value)])
            await ClockCycles(dut.clk, 16)
        rows.append(row)
        await ClockCycles(dut.clk, 16 * H_TOTAL - 40 * 16)
    return rows


def save_cells(rows, name):
    try:
        from PIL import Image
        import os
        os.makedirs("output", exist_ok=True)
        im = Image.new("RGB", (40, 30))
        im.putdata([p for r in rows for p in r])
        im.resize((320, 240), Image.NEAREST).save(f"output/{name}.png")
    except Exception:
        pass


def count(rows, colour, x0=0, x1=40, y0=0, y1=30):
    return sum(rows[y][x] == colour for y in range(y0, y1) for x in range(x0, x1))


@cocotb.test()
async def test_picture(dut):
    await reset(dut)
    await ClockCycles(dut.clk, FRAME)

    # idle: sprite visible, no note label, no sharp sign
    idle = await grab_cells(dut)
    save_cells(idle, "idle")
    assert count(idle, HAIR) > 60 and count(idle, SKIN) > 60 and count(idle, OUTLINE) > 60, "idle sprite missing"
    assert count(idle, YELLOW) == 0, "label shown while idle"

    # Do held: yellow label in the top-left box, ring colours red (dark 85,0,0 / light 170,0,0)
    dut.ui_in.value = 1
    await ClockCycles(dut.clk, 2 * FRAME)
    do = await grab_cells(dut)
    save_cells(do, "do")
    assert count(do, YELLOW, 1, 9, 0, 5) > 5, "label missing for Do"
    assert count(do, YELLOW, 10, 15, 0, 5) == 0, "sharp sign shown without sharp"
    left_margin = {do[y][x] for y in range(8, 30) for x in range(0, 5)}
    assert left_margin <= {(85, 0, 0), (170, 0, 0)}, f"Do ring colours wrong: {left_margin}"
    assert count(do, HAIR) > 60, "sprite missing while singing"

    # sharp pin: '#' sign appears next to the label
    dut.uio_in.value = SHARP
    await ClockCycles(dut.clk, 2 * FRAME)
    sh = await grab_cells(dut)
    save_cells(sh, "do_sharp")
    assert count(sh, YELLOW, 10, 15, 0, 5) > 5, "sharp sign missing"

    # octave up: white '+' marker top right
    dut.uio_in.value = OCT_UP
    await ClockCycles(dut.clk, 2 * FRAME)
    up = await grab_cells(dut)
    assert count(up, (255, 255, 255), 36, 39, 1, 4) > 3, "octave marker missing"

    # a different key gives different ring colours (La: blue)
    dut.uio_in.value = 0
    dut.ui_in.value = 1 << 5
    await ClockCycles(dut.clk, 2 * FRAME)
    la = await grab_cells(dut)
    left_margin = {la[y][x] for y in range(8, 30) for x in range(0, 5)}
    assert left_margin <= {(0, 0, 170), (0, 0, 255)}, f"La ring colours wrong: {left_margin}"


@cocotb.test()
async def test_demo(dut):
    # demo enabled, no key held; the tune starts with Do' (2 units), La# (2), La (2), La# (1) ...
    await reset(dut, uio=DEMO)
    unit = 6 * FRAME                                       # one time unit = 6 frames = 0.1 s
    await ClockCycles(dut.clk, 3 * FRAME)                  # inside the first unit (after its 1-frame gap)
    hz = await measure_hz(dut)
    assert close(hz, 1046.50), f"demo note 1: {hz:.1f} Hz, expected Do' 1046.5"
    await ClockCycles(dut.clk, 2 * unit - 3 * FRAME)       # now ~1.1 units into note 2
    hz = await measure_hz(dut)
    assert close(hz, 932.33), f"demo note 2: {hz:.1f} Hz, expected La# 932.3"
    await ClockCycles(dut.clk, 2 * unit)
    hz = await measure_hz(dut)
    assert close(hz, 880.00), f"demo note 3: {hz:.1f} Hz, expected La 880"

    # a key takes over from the demo, and the demo restarts from the top once released
    dut.ui_in.value = 1
    await ClockCycles(dut.clk, 3000)
    hz = await measure_hz(dut)
    assert close(hz, NOTES[0]), "key does not override the demo"
    dut.ui_in.value = 0
    await ClockCycles(dut.clk, 3 * FRAME)
    hz = await measure_hz(dut)
    assert close(hz, 1046.50), "demo does not restart from the first note"
