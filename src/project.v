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
  // ---------------- keys -> note (lowest key wins) ----------------
  wire playing = |ui_in;
  reg [2:0] note;
  always @* begin
    casez (ui_in)
      8'b???????1: note = 3'd0;   // Do
      8'b??????10: note = 3'd1;   // Re
      8'b?????100: note = 3'd2;   // Mi
      8'b????1000: note = 3'd3;   // Fa
      8'b???10000: note = 3'd4;   // Sol
      8'b??100000: note = 3'd5;   // La
      8'b?1000000: note = 3'd6;   // Si
      default:     note = 3'd7;   // Do (high)
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

  // ---------------- animation ----------------
  reg       vsync_q, playing_q;
  reg [4:0] tick;
  reg [1:0] phase;

  always @(posedge clk) begin
    if (!rst_n) begin
      vsync_q <= 0; playing_q <= 0; tick <= 0; phase <= 0;
    end else begin
      vsync_q   <= vsync;
      playing_q <= playing;
      if (playing != playing_q) begin          // key pressed/released: restart loop
        tick  <= 0;
        phase <= 0;
      end else if (vsync && !vsync_q) begin    // once per video frame (60 Hz)
        if (tick == (playing ? 5'd7 : 5'd31)) begin
          tick <= 0;
          if (playing) phase <= (phase == 2'd2) ? 2'd0 : phase + 2'd1;
          else         phase <= {1'b0, ~phase[0]};
        end else begin
          tick <= tick + 5'd1;
        end
      end
    end
  end

  wire [2:0] frame = playing ? (3'd2 + {1'b0, phase}) : {2'b00, phase[0]};

  // ---------------- picture / label ----------------
  wire [5:0] cx = pix_x[9:4];                       // 16x16 pixel cells
  wire [5:0] cy = pix_y[9:4];
  wire in_pic = video_active &&
                (cx >= 6'd4) && (cx < 6'd36) &&     // 32 columns, centered
                (cy >= 6'd3) && (cy < 6'd27);       // 24 rows, centered
  wire [4:0] px = cx[4:0] - 5'd4;                   // 0..31
  wire [4:0] py = cy[4:0] - 5'd3;                   // 0..23

  wire in_label = playing && (px < 5'd12) && (py < 5'd6);

  wire pic_pix, lab_pix;
  frame_rom pic_rom (.frame(frame), .x(px), .y(py), .pixel(pic_pix));
  label_rom lab_rom (.note(note), .x(px[3:0]), .y(py[2:0]), .pixel(lab_pix));

  wire pic_on = in_pic && !in_label && pic_pix;     // white
  wire lab_on = in_pic &&  in_label && lab_pix;     // yellow

  wire [1:0] r = (pic_on || lab_on) ? 2'b11 : 2'b00;
  wire [1:0] g = (pic_on || lab_on) ? 2'b11 : 2'b00;
  wire [1:0] b = pic_on             ? 2'b11 : 2'b00;

  // TT VGA pinout: {hsync, B0, G0, R0, vsync, B1, G1, R1}
  assign uo_out = {hsync, b[0], g[0], r[0], vsync, b[1], g[1], r[1]};

  // ---------------- audio (square wave on uio[7]) ----------------
  // half-period in clk cycles for a 25.175 MHz clock
  reg [14:0] half;
  always @* begin
    case (note)
      3'd0: half = 15'd24055;  // C5  523 Hz
      3'd1: half = 15'd21431;  // D5  587 Hz
      3'd2: half = 15'd19093;  // E5  659 Hz
      3'd3: half = 15'd18021;  // F5  698 Hz
      3'd4: half = 15'd16055;  // G5  784 Hz
      3'd5: half = 15'd14303;  // A5  880 Hz
      3'd6: half = 15'd12742;  // B5  988 Hz
      default: half = 15'd12027; // C6 1047 Hz
    endcase
  end

  reg [14:0] tcnt;
  reg        tone;
  always @(posedge clk) begin
    if (!rst_n || !playing) begin
      tcnt <= 0;
      tone <= 0;
    end else if (tcnt >= half) begin
      tcnt <= 0;
      tone <= ~tone;
    end else begin
      tcnt <= tcnt + 15'd1;
    end
  end

  assign uio_out = {tone, 7'b0};
  assign uio_oe  = 8'h80;

  wire _unused = &{ena, uio_in, 1'b0};
endmodule
