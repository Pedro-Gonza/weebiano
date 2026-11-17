`default_nettype none

module tt_um_peterm_weebiano (
    input  wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n
);
  // ---------------- test switch ----------------
  // The playground cannot drive the uio pins, so in test mode they are forced from UIO_FORCE.
  // Set TEST_UIO = 1'b0 before manufacturing
  localparam       TEST_UIO  = 1'b0;
  localparam [7:0] UIO_FORCE = 8'b0000_0000;   // bit n = uio[n] held high (bit 6 = demo on)
  wire [7:0] uio = TEST_UIO ? UIO_FORCE : uio_in;

  // ---------------- demo tune ----------------
  // One entry per note, 8 bits, entry 0 in the lowest bits:
  //   bits 2:0 note (0 Do, 1 Re, 2 Mi, 3 Fa, 4 Sol, 5 La, 6 Si, 7 high Do), bit 3 sharp,
  //   bit 4 rest, bits 7:5 = length - 1 (in time units).
  localparam        DEMO_EVENTS = 136;   // entries in the table; 304 time units = 30.4 s per loop
  localparam        DEMO_BITS   = 8;   // bits needed to count the entries
  localparam        DEMO_FRAMES_HW = 6;  // video frames per time unit at 60 fps: 150 BPM, 4 units per beat
  localparam [1087:0] DEMO_TUNE = 1088'h27202030f0302010042d100f100310001004233064233064706023242324233064233064706023242324233064233064706023242324233064233064f0f070f0636903046d2703102c242323450d10052d27272020450d252d272710001000450d10052d271047276d27030c2c24232310250d252d27272020450d1005100d27272020450d252d27;
  // The playground runs far below 60 video frames per second and the demo counts video
  // frames, so in test mode it uses DEMO_FRAMES_SIM instead: 1 at about 12 fps, 2 at about 25 fps.
  localparam        DEMO_FRAMES_SIM = 2;
  localparam        DEMO_FRAMES = TEST_UIO ? DEMO_FRAMES_SIM : DEMO_FRAMES_HW;

  // ---------------- controls on the bidirectional pins (bits 6:0 are inputs, bit 7 is audio out) ----------------
  wire       oct_up   = uio[0];
  wire       oct_dn   = uio[1];
  wire       sharp_in = uio[2];
  wire [1:0] timbre   = uio[4:3];   // 0: 50% square, 1: 25%, 2: 12.5%, 3: pluck
  wire       vib_en   = uio[5];
  wire       demo_en  = uio[6];     // plays the demo tune while no key is held

  // ---------------- keys -> note (lowest key wins) ----------------
  wire key_active = |ui_in;
  reg [2:0] key_note;
  always @* begin
    casez (ui_in)
      8'b???????1: key_note = 3'd0;
      8'b??????10: key_note = 3'd1;
      8'b?????100: key_note = 3'd2;
      8'b????1000: key_note = 3'd3;
      8'b???10000: key_note = 3'd4;
      8'b??100000: key_note = 3'd5;
      8'b?1000000: key_note = 3'd6;
      default:     key_note = 3'd7;
    endcase
  end

  // ---------------- VGA timing ----------------
  wire hsync, vsync, video_active;
  wire [9:0] pix_x, pix_y;
  hvsync_generator hvsync_gen (
      .clk(clk), .reset(~rst_n),
      .hsync(hsync), .vsync(vsync),
      .display_on(video_active),
      .hpos(pix_x), .vpos(pix_y)
  );

  reg vsync_q;
  always @(posedge clk) vsync_q <= rst_n ? vsync : 1'b0;
  wire vs_edge = vsync && !vsync_q;          // once per video frame (60 Hz)

  // ---------------- demo jingle ----------------
  wire demo_active = demo_en && !key_active;
  reg [4:0] dtick;       // frames inside one time unit
  reg [2:0] dunit;       // units already played inside the current note
  reg [DEMO_BITS-1:0] dev;   // current entry in the table
  wire [7:0] dent      = DEMO_TUNE[dev * 8 +: 8];
  wire [2:0] demo_note = dent[2:0];
  wire       demo_shrp = dent[3];
  wire       demo_rest = dent[4];
  wire [2:0] demo_len  = dent[7:5];          // length - 1
  always @(posedge clk) begin
    if (!rst_n || !demo_active) begin
      dtick <= 0; dunit <= 0; dev <= 0;
    end else if (vs_edge) begin
      if (dtick == DEMO_FRAMES - 1) begin
        dtick <= 0;
        if (dunit == demo_len) begin
          dunit <= 0;
          dev   <= (dev == DEMO_EVENTS - 1) ? {DEMO_BITS{1'b0}} : dev + {{(DEMO_BITS-1){1'b0}}, 1'b1};
        end else dunit <= dunit + 3'd1;
      end else dtick <= dtick + 5'd1;
    end
  end

  wire [2:0] note     = key_active ? key_note : demo_note;
  wire       anim_on  = key_active || (demo_active && !demo_rest);
  // each demo note starts with a short silence so repeated notes are heard separately:
  // one video frame on the chip; in test mode only the top part of a frame, so that
  // notes lasting a single frame are not swallowed
  wire       demo_gap = (dtick == 5'd0 && dunit == 3'd0) && (TEST_UIO ? (pix_y[9:7] == 3'd0) : 1'b1);
  wire       sound_on = key_active || (demo_active && !demo_rest && !demo_gap);
  // Mi and Si have no sharp (no black key after them), so the button is ignored there
  wire       sharp    = key_active ? (sharp_in && note != 3'd2 && note != 3'd6)
                                   : (demo_active && !demo_rest && demo_shrp);

  // ---------------- animation (2 idle + 2 singing frames) ----------------
  // frame 0 = eyes open, 1 = eyes closed (idle blink), 2 = eyes closed, 3 = mouth open
  reg       anim_q, phase;
  reg [4:0] tick;
  always @(posedge clk) begin
    if (!rst_n) begin
      anim_q <= 0; tick <= 0; phase <= 0;
    end else begin
      anim_q <= anim_on;
      if (anim_on != anim_q) begin             // start/stop: restart loop
        tick <= 0; phase <= 0;
      end else if (vs_edge) begin
        if (tick == (anim_on ? 5'd7 : 5'd31)) begin   // sing ~7.5 Hz, idle ~2 Hz
          tick  <= 0;
          phase <= ~phase;
        end else tick <= tick + 5'd1;
      end
    end
  end
  wire [2:0] frame = {1'b0, anim_on, phase};   // 0-1 idle, 2-3 singing

  // time since the key went down (frames, saturates): pluck timbre
  reg [3:0] age;
  always @(posedge clk) if (!rst_n || !sound_on) age <= 4'd0; else if (vs_edge && age != 4'd15) age <= age + 4'd1;

  // ---------------- picture (28 x 22 cells, 16x16 px each) ----------------
  wire [5:0] cx = pix_x[9:4];                  // 0..39
  wire [5:0] cy = pix_y[9:4];                  // 0..29

  wire       bob    = phase;                   // sprite drops 1 cell on alternate animation frames
  wire       in_pic = video_active && cx >= 6'd6 && cx < 6'd34 && cy >= (6'd8 + {5'b0, bob});
  wire [4:0] px = cx[4:0] - 5'd6;              // 0..27
  wire [4:0] py = cy[4:0] - 5'd8 - {4'b0, bob};  // 0..21

  wire [1:0] pic_pix;
  frame_rom pic_rom (.frame(frame), .x(px), .y(py), .pixel(pic_pix));
  wire [1:0] idx = in_pic ? pic_pix : 2'd0;

  // note label, top-left (cells x 1..8, y 0..4)
  wire in_lab = video_active && anim_on && cx >= 6'd1 && cx < 6'd9 && cy < 6'd5;
  wire lab_pix;
  label_rom lab_rom (.note(note), .x(cx[2:0] - 3'd1), .y(cy[2:0]), .pixel(lab_pix));

  // sharp glyph "#" (5x5, cells x 10..14, y 0..4): odd columns and odd rows
  wire in_sh  = video_active && sharp && cx >= 6'd10 && cx < 6'd15 && cy < 6'd5;
  wire sh_pix = cx[0] | cy[0];

  // octave indicator, top-right (cells x 36..38, y 1..3): "-" = down, "+" = up, hidden if normal
  wire in_oct  = video_active && (oct_up ^ oct_dn) && cx >= 6'd36 && cx < 6'd39 &&
                 cy >= 6'd1 && cy < 6'd4;
  wire oct_pix = (cy == 6'd2) || (oct_up && cx == 6'd37);

  // ---------------- colors {R,G,B}, 2 bits each ----------------
  // ring colours per note: {dark band, light band}, same idea as the idle palettes.
  // All differ from each other and from the sprite (hair 001010, skin 111110,
  // outline 010101) and avoid white/yellow so the yellow label stays readable.
  reg [5:0] play_a, play_b;
  always @* case (note)
    3'd0: begin play_a = 6'b010000; play_b = 6'b100000; end   // Do   red
    3'd1: begin play_a = 6'b100100; play_b = 6'b111000; end   // Re   orange
    3'd2: begin play_a = 6'b010100; play_b = 6'b101000; end   // Mi   olive
    3'd3: begin play_a = 6'b000100; play_b = 6'b001000; end   // Fa   green
    3'd4: begin play_a = 6'b000110; play_b = 6'b001011; end   // Sol  azure
    3'd5: begin play_a = 6'b000010; play_b = 6'b000011; end   // La   blue
    3'd6: begin play_a = 6'b100001; play_b = 6'b110010; end   // Si   magenta
    default: begin play_a = 6'b010110; play_b = 6'b101011; end // Do'  periwinkle
  endcase

  reg [5:0] bgt;                               // frame counter: vibrato LFO, slow clocks
  always @(posedge clk) bgt <= !rst_n ? 6'd0 : (vs_edge ? bgt + 6'd1 : bgt);

  // ring phase accumulator: speed follows the note's pitch (C=8 ... C'=16, ratio 1:2)
  reg [4:0] spd;
  always @* case (note)
    3'd0: spd = 5'd8;   3'd1: spd = 5'd9;   3'd2: spd = 5'd10;  3'd3: spd = 5'd11;
    3'd4: spd = 5'd12;  3'd5: spd = 5'd13;  3'd6: spd = 5'd15;  default: spd = 5'd16;
  endcase
  reg [4:0] rph;
  always @(posedge clk) rph <= !rst_n ? 5'd0 : (vs_edge ? rph + (anim_on ? spd : 5'd8) : rph);
  wire [1:0] tm = rph[4:3];

  // slow clock for idle palette drift (changes every ~2 s)
  reg [2:0] cyc;
  always @(posedge clk) cyc <= !rst_n ? 3'd0 : ((vs_edge && bgt == 6'd63) ? cyc + 3'd1 : cyc);

  // rings centred behind the head (cell boundary x=20, y=18)
  wire [5:0] dx6 = (cx >= 6'd20) ? (cx - 6'd20) : (6'd19 - cx);
  wire [5:0] dy6 = (cy >= 6'd18) ? (cy - 6'd18) : (6'd17 - cy);

  // distance from the centre in cells: floor(sqrt((dx+.5)^2 + (dy+.5)^2)) = isqrt(dx*(dx+1) + dy*(dy+1))
  function [8:0] tri9(input [4:0] n);
    case (n)
      5'd0: tri9 = 9'd0;
      5'd1: tri9 = 9'd2;
      5'd2: tri9 = 9'd6;
      5'd3: tri9 = 9'd12;
      5'd4: tri9 = 9'd20;
      5'd5: tri9 = 9'd30;
      5'd6: tri9 = 9'd42;
      5'd7: tri9 = 9'd56;
      5'd8: tri9 = 9'd72;
      5'd9: tri9 = 9'd90;
      5'd10: tri9 = 9'd110;
      5'd11: tri9 = 9'd132;
      5'd12: tri9 = 9'd156;
      5'd13: tri9 = 9'd182;
      5'd14: tri9 = 9'd210;
      5'd15: tri9 = 9'd240;
      5'd16: tri9 = 9'd272;
      5'd17: tri9 = 9'd306;
      5'd18: tri9 = 9'd342;
      5'd19: tri9 = 9'd380;
      default: tri9 = 9'd0;
    endcase
  endfunction
  function [4:0] isqrt(input [9:0] n);
    reg [9:0] x, r, b;
    integer i;
    begin
      x = n; r = 10'd0; b = 10'd256;
      for (i = 0; i < 5; i = i + 1) begin
        if (x >= r + b) begin x = x - (r + b); r = (r >> 1) + b; end
        else r = r >> 1;
        b = b >> 2;
      end
      isqrt = r[4:0];
    end
  endfunction
  wire [9:0] qsum = {1'b0, tri9(dx6[4:0])} + {1'b0, tri9(dy6[4:0])};
  wire [4:0] rex  = isqrt(qsum);

  // rings are 2 cells wide, so only the low 2 bits of the distance matter
  // singing: rings expand outward; idle: rings contract inward
  wire [1:0] ph   = anim_on ? (rex[1:0] - tm) : (rex[1:0] + tm);
  wire       ring = ph[1];

  // idle palettes {dark band, light band}
  wire [1:0] hue = cyc[2:1];                   // drifts through 4 palettes
  reg [5:0] idle_a, idle_b;
  always @* case (hue)
    2'd0: begin idle_a = 6'b000001; idle_b = 6'b000010; end   // navy / blue
    2'd1: begin idle_a = 6'b000100; idle_b = 6'b001000; end   // green
    2'd2: begin idle_a = 6'b010001; idle_b = 6'b100010; end   // purple
    default: begin idle_a = 6'b000101; idle_b = 6'b001001; end // teal
  endcase

  // plain dark box behind the label / sharp sign so they are always legible
  wire in_box = anim_on && cx < (sharp ? 6'd16 : 6'd10) && cy < 6'd6;

  wire [5:0] bg_play = ring ? play_b : play_a;
  wire [5:0] bg_idle = ring ? idle_b : idle_a;
  wire [5:0] bg      = in_box ? 6'b000000 : (anim_on ? bg_play : bg_idle);

  reg [5:0] pal;
  always @* case (idx)
    2'd1:    pal = 6'b001010;   // hair  (0,170,170) teal
    2'd2:    pal = 6'b111110;   // skin  (255,255,170); 6'b111010 for pink
    default: pal = 6'b010101;   // dark detail (85,85,85)
  endcase

  wire [5:0] rgb = !video_active                    ? 6'b000000 :
                   (in_lab && lab_pix) || (in_sh && sh_pix) ? 6'b111100 :
                   in_oct && oct_pix                ? 6'b111111 :
                   (idx != 2'd0)                    ? pal : bg;

  // TT VGA pinout: {hsync, B0, G0, R0, vsync, B1, G1, R1}
  assign uo_out = {hsync, rgb[0], rgb[2], rgb[4], vsync, rgb[1], rgb[3], rgb[5]};

  // ---------------- audio ----------------
  // half-period in clk cycles @ 25.175 MHz, index {sharp, note}
  reg [15:0] half;
  always @* case ({sharp, note})
    4'd0:  half = 16'd24056;  // C5
    4'd1:  half = 16'd21432;  // D5
    4'd2:  half = 16'd19094;  // E5
    4'd3:  half = 16'd18022;  // F5
    4'd4:  half = 16'd16055;  // G5
    4'd5:  half = 16'd14304;  // A5
    4'd6:  half = 16'd12743;  // B5
    4'd7:  half = 16'd12028;  // C6
    4'd8:  half = 16'd22706;  // C#5
    4'd9:  half = 16'd20228;  // D#5
    4'd11: half = 16'd17010;  // F#5
    4'd12: half = 16'd15154;  // G#5
    4'd13: half = 16'd13501;  // A#5
    4'd15: half = 16'd11353;  // C#6
    default: half = 16'd24056;
  endcase

  wire [15:0] half_oct = (oct_up && !oct_dn) ? (half >> 1) :
                         (oct_dn && !oct_up) ? (half << 1) : half;

  // vibrato: triangle of about 6 Hz, depth about +-190 cycles
  wire [2:0]  vph  = bgt[2:0];             // 60 Hz / 8 = 7.5 Hz
  wire [1:0]  tria = vph[2] ? ~vph[1:0] : vph[1:0];
  wire [15:0] half_v = vib_en ? (half_oct + {7'b0, tria, 7'b0} - 16'd192) : half_oct;

  // 8 slots per period; the waveform is a pattern over the slots
  reg [13:0] tcnt;
  reg [2:0]  slot;
  wire [13:0] tick_lim = half_v[15:2];
  always @(posedge clk) begin
    if (!rst_n) begin
      tcnt <= 0; slot <= 0;
    end else if (!sound_on) begin
      tcnt <= 0; slot <= 0;
    end else if (tcnt >= tick_lim) begin
      tcnt <= 0;
      slot <= slot + 3'd1;
    end else begin
      tcnt <= tcnt + 14'd1;
    end
  end

  reg wave;
  always @* case (timbre)
    2'd0: wave = slot[2];              // 50%
    2'd1: wave = (slot[2:1] == 2'd0);  // 25%
    2'd2: wave = (slot == 3'd0);       // 12.5%
    default: wave = age[3] ? (slot == 3'd0) : age[2] ? (slot[2:1] == 2'd0) : slot[2];  // pluck
  endcase

  assign uio_out = {sound_on & wave, 7'b0};
  assign uio_oe  = 8'h80;

  wire _unused = &{ena, uio_in, uio[7], pix_x[3:0], pix_y[3:0], dx6[5], dy6[5], rex[4:2], ph[0], cyc[0], half_v[1:0], 1'b0};
endmodule
