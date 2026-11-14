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
  // ---------------- build options ----------------
  // The playground can't drive uio_in, so TEST_UIO forces values.
  // Set TEST_UIO = 0 for real hardware / final submission.
  localparam       TEST_UIO  = 1'b0;
  localparam [7:0] UIO_FORCE = 8'b0000_0000;   // bit n = uio[n] held high

  wire [7:0] uio = TEST_UIO ? UIO_FORCE : uio_in;

  wire       oct_up   = uio[0];
  wire       oct_dn   = uio[1];
  wire       sharp_in = uio[2];
  wire [1:0] timbre   = uio[4:3];
  wire       vib_en   = uio[5];
  wire       demo_en  = uio[6];

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
  reg [3:0] dtick, dstep;                    // 15 vsyncs per step = 4 notes/s
  always @(posedge clk) begin
    if (!rst_n || !demo_active) begin
      dtick <= 0; dstep <= 0;
    end else if (vs_edge) begin
      if (dtick == 4'd14) begin dtick <= 0; dstep <= dstep + 4'd1; end
      else                dtick <= dtick + 4'd1;
    end
  end

  reg [2:0] demo_note;
  reg       demo_rest;
  always @* begin
    demo_rest = 1'b0;
    case (dstep)             // E E F G | G F E D | C C D E | E D D -
      4'd0, 4'd1, 4'd6, 4'd11, 4'd12: demo_note = 3'd2;
      4'd2, 4'd5:                      demo_note = 3'd3;
      4'd3, 4'd4:                      demo_note = 3'd4;
      4'd7, 4'd10, 4'd13, 4'd14:       demo_note = 3'd1;
      4'd8, 4'd9:                      demo_note = 3'd0;
      default: begin demo_note = 3'd0; demo_rest = 1'b1; end
    endcase
  end

  wire [2:0] note     = key_active ? key_note : demo_note;
  wire       anim_on  = key_active || (demo_active && !demo_rest);
  wire       sound_on = key_active || (demo_active && !demo_rest && dtick != 4'd0);
  wire       sharp    = sharp_in && key_active && note != 3'd2 && note != 3'd6;

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

  // ---------------- picture (28 x 22 cells, 16x16 px each) ----------------
  wire [5:0] cx = pix_x[9:4];                  // 0..39
  wire [5:0] cy = pix_y[9:4];                  // 0..29

  wire       in_pic = video_active && cx >= 6'd6 && cx < 6'd34 && cy >= 6'd8;
  wire [4:0] px = cx[4:0] - 5'd6;              // 0..27
  wire [4:0] py = cy[4:0] - 5'd8;              // 0..21

  wire [1:0] pic_pix;
  frame_rom pic_rom (.frame(frame), .x(px), .y(py), .pixel(pic_pix));
  wire [1:0] idx = in_pic ? pic_pix : 2'd0;

  // note label, top-left (cells x 1..8, y 0..4)
  wire in_lab = video_active && anim_on && cx >= 6'd1 && cx < 6'd9 && cy < 6'd5;
  wire lab_pix;
  label_rom lab_rom (.note(note), .x(cx[2:0] - 3'd1), .y(cy[2:0]), .pixel(lab_pix));

  // sharp glyph "#" (3x5) next to the label (cells x 10..12, y 0..4)
  wire       in_sh = video_active && sharp && cx >= 6'd10 && cx < 6'd13 && cy < 6'd5;
  wire [1:0] gx = cx[1:0] - 2'd2;
  wire [2:0] gy = cy[2:0];
  wire       sh_pix = (gx != 2'd1) || gy[0];

  // octave indicator, top-right: 1 cell = down, 3 cells = up, hidden if normal
  wire [5:0] oct_end = oct_up ? 6'd36 : 6'd34;
  wire in_oct = video_active && (oct_up ^ oct_dn) && cy == 6'd1 &&
                cx >= 6'd34 && cx <= oct_end;

  // ---------------- colors {R,G,B}, 2 bits each ----------------
  reg [5:0] accent;
  always @* case (note)
    3'd0: accent = 6'b110000;
    3'd1: accent = 6'b111000;
    3'd2: accent = 6'b111100;
    3'd3: accent = 6'b001100;
    3'd4: accent = 6'b001111;
    3'd5: accent = 6'b000011;
    3'd6: accent = 6'b110011;
    default: accent = 6'b111111;
  endcase

  reg [5:0] bgt;                               // frame counter: ring motion + vibrato LFO
  always @(posedge clk) bgt <= !rst_n ? 6'd0 : (vs_edge ? bgt + 6'd1 : bgt);

  // concentric octagon rings centred behind the head (cell boundary x=20, y=18)
  wire [5:0] dx6 = (cx >= 6'd20) ? (cx - 6'd20) : (6'd19 - cx);
  wire [5:0] dy6 = (cy >= 6'd18) ? (cy - 6'd18) : (6'd17 - cy);
  wire       xbig = dx6 > dy6;
  wire [4:0] dmx  = xbig ? dx6[4:0] : dy6[4:0];
  wire [4:0] dmn  = xbig ? dy6[4:0] : dx6[4:0];
  wire [4:0] rd   = dmx + {1'b0, dmn[4:1]};        // ~ circular distance
  // singing: rings expand outward; idle: rings contract inward
  wire [2:0] ph   = anim_on ? (rd[2:0] - bgt[5:3]) : (rd[2:0] + bgt[5:3]);
  wire       ring = ph[2];

  // the two bands always differ: black vs. tinted (tint is never 0)
  wire [5:0] bg = anim_on ? (ring ? (accent & 6'b010101) : 6'b000000)
                          : (ring ? 6'b000010 : 6'b000001);

  reg [5:0] pal;
  always @* case (idx)
    2'd1:    pal = 6'b001010;   // hair  (0,170,170) teal
    2'd2:    pal = 6'b111110;   // skin  (255,255,170); 6'b111010 for pink
    default: pal = 6'b010101;   // dark detail (85,85,85)
  endcase

  wire [5:0] rgb = !video_active                    ? 6'b000000 :
                   (in_lab && lab_pix) || (in_sh && sh_pix) ? 6'b111100 :
                   in_oct                           ? 6'b111111 :
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
  reg [3:0] age;
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

  always @(posedge clk) if (!sound_on) age <= 4'd0; else if (vs_edge && age != 4'd15) age <= age + 4'd1;
  reg wave;
  always @* case (timbre)
    2'd0: wave = slot[2];              // 50%
    2'd1: wave = (slot[2:1] == 2'd0);  // 25%
    2'd2: wave = (slot == 3'd0);       // 12.5%
    default: wave = age[3] ? (slot == 3'd0) : age[2] ? (slot[2:1] == 2'd0) : slot[2];  // pluck
  endcase

  assign uio_out = {sound_on & wave, 7'b0};
  assign uio_oe  = 8'h80;

  wire _unused = &{ena, uio_in, 1'b0};
endmodule
