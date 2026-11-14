`default_nettype none

// 1 base sprite (22 rows x 28 bits, mirrored, 2bpp) + 3 expression overlays
// (6 rows x 7 half-columns) + 0 generated flat rectangle(s).
// frame -> expression: [0, 1, 1, 2]. y is 0..21 (original row minus 2).
module frame_rom (
    input  wire [2:0] frame,   // 0-1 idle, 2-3 singing
    input  wire [4:0] x,       // 0..27
    input  wire [4:0] y,       // 0..21
    output wire [1:0] pixel
);
  reg [27:0] bmem[21:0];
  reg [13:0] omem[23:0];
  initial begin
    bmem[0] = 28'h000003f;
    bmem[1] = 28'h0000355;
    bmem[2] = 28'h00ffd55;
    bmem[3] = 28'h0d5f555;
    bmem[4] = 28'h0d7d5d5;
    bmem[5] = 28'h05f55d5;
    bmem[6] = 28'h35f57d5;
    bmem[7] = 28'h37d5eb5;
    bmem[8] = 28'h15d5eb5;
    bmem[9] = 28'hd5d7aad;
    bmem[10] = 28'hd754000;
    bmem[11] = 28'h5754000;
    bmem[12] = 28'h5754000;
    bmem[13] = 28'h57dc000;
    bmem[14] = 28'h57dc000;
    bmem[15] = 28'h57dc000;
    bmem[16] = 28'h57deaaf;
    bmem[17] = 28'h573faaa;
    bmem[18] = 28'h5703fff;
    bmem[19] = 28'h570003a;
    bmem[20] = 28'h54000fa;
    bmem[21] = 28'h54003ea;
    omem[0] = 14'h3bed;
    omem[1] = 14'h3b6b;
    omem[2] = 14'h3b6a;
    omem[3] = 14'h2bea;
    omem[4] = 14'h2aaa;
    omem[5] = 14'h2aba;
    omem[6] = 14'h0000;
    omem[7] = 14'h0000;
    omem[8] = 14'h3aad;
    omem[9] = 14'h3aab;
    omem[10] = 14'h3bfa;
    omem[11] = 14'h2aaa;
    omem[12] = 14'h2aaa;
    omem[13] = 14'h2aba;
    omem[14] = 14'h0000;
    omem[15] = 14'h0000;
    omem[16] = 14'h3aad;
    omem[17] = 14'h3bfb;
    omem[18] = 14'h3aaa;
    omem[19] = 14'h2aaa;
    omem[20] = 14'h2aaa;
    omem[21] = 14'h2aaf;
    omem[22] = 14'h0000;
    omem[23] = 14'h0000;
  end

  // mirror: c = 0 on the centre line, 13 at the outer edge
  wire [4:0] cc = (x >= 5'd14) ? (x - 5'd14) : (5'd13 - x);
  wire [3:0] c  = cc[3:0];

  // base sprite
  wire [27:0] brow = bmem[y];
  wire [1:0]  bpix = brow[{c, 1'b0} +: 2];

  // expression overlay (eyes + mouth)
  reg [1:0] ex;
  always @* case (frame[1:0])
    2'd0: ex = 2'd0;
    2'd1: ex = 2'd1;
    2'd2: ex = 2'd1;
    2'd3: ex = 2'd2;
    default: ex = 0;
  endcase
  wire [4:0] oy = y - 5'd10;
  wire [3:0] oc = c - 4'd0;
  wire in_win = (y >= 5'd10) && (y <= 5'd15) && (c >= 4'd0) && (c <= 4'd6);
  wire [13:0] orow = omem[{ex, oy[2:0]}];
  wire [1:0] opix = in_win ? orow[{oc[2:0], 1'b0} +: 2] : 2'd0;

  wire [1:0] rpix = 2'd0;

  // the three layers never overlap (their ROM cells are zeroed)
  assign pixel = bpix | opix | rpix;
endmodule

// 8 note labels x 5 rows x 8 bits
module label_rom (
    input  wire [2:0] note,
    input  wire [2:0] x,
    input  wire [2:0] y,       // 0..4
    output wire       pixel
);
  reg [7:0] mem[39:0];
  initial begin
    mem[0] = 8'h03;
    mem[1] = 8'h25;
    mem[2] = 8'h55;
    mem[3] = 8'h55;
    mem[4] = 8'h23;
    mem[5] = 8'h63;
    mem[6] = 8'h55;
    mem[7] = 8'h73;
    mem[8] = 8'h15;
    mem[9] = 8'h65;
    mem[10] = 8'h51;
    mem[11] = 8'h1b;
    mem[12] = 8'h55;
    mem[13] = 8'h51;
    mem[14] = 8'h51;
    mem[15] = 8'h07;
    mem[16] = 8'h31;
    mem[17] = 8'h63;
    mem[18] = 8'h51;
    mem[19] = 8'h61;
    mem[20] = 8'h06;
    mem[21] = 8'h21;
    mem[22] = 8'h52;
    mem[23] = 8'h54;
    mem[24] = 8'h23;
    mem[25] = 8'h01;
    mem[26] = 8'h31;
    mem[27] = 8'h61;
    mem[28] = 8'h51;
    mem[29] = 8'h67;
    mem[30] = 8'h16;
    mem[31] = 8'h01;
    mem[32] = 8'h12;
    mem[33] = 8'h14;
    mem[34] = 8'h13;
    mem[35] = 8'h03;
    mem[36] = 8'h25;
    mem[37] = 8'h55;
    mem[38] = 8'h55;
    mem[39] = 8'h23;
  end
  wire [5:0] addr = note * 6'd5 + {3'b0, y};
  assign pixel = mem[addr][x];
endmodule