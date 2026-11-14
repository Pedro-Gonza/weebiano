`default_nettype none

// idle: 2 frames x 24 rows x 28 bits (mirrored), 2bpp
// sing: 2 frames x 24 rows x 28 bits (mirrored), 2bpp
module frame_rom (
    input  wire [2:0] frame,   // 0-1 idle, 2-3 singing
    input  wire [4:0] x,       // 0..27
    input  wire [4:0] y,       // 0..23
    output wire [1:0] pixel
);
  reg [27:0] imem[47:0];
  reg [27:0] smem[47:0];
  initial begin
    imem[0] = 28'h0000000;
    imem[1] = 28'h0000000;
    imem[2] = 28'h000003f;
    imem[3] = 28'h0000355;
    imem[4] = 28'h00ffd55;
    imem[5] = 28'h0d5f555;
    imem[6] = 28'h0d7d5d5;
    imem[7] = 28'h05f55d5;
    imem[8] = 28'h35f57d5;
    imem[9] = 28'h37d5eb5;
    imem[10] = 28'h15d5eb5;
    imem[11] = 28'hd5d7aad;
    imem[12] = 28'hd757bed;
    imem[13] = 28'h5757b6b;
    imem[14] = 28'h5757b6a;
    imem[15] = 28'h57debea;
    imem[16] = 28'h57deaaa;
    imem[17] = 28'h57deaba;
    imem[18] = 28'h57deaaf;
    imem[19] = 28'h573faaa;
    imem[20] = 28'h5703fff;
    imem[21] = 28'h570003a;
    imem[22] = 28'h5c000fa;
    imem[23] = 28'h5c003ea;
    imem[24] = 28'h0000000;
    imem[25] = 28'h0000000;
    imem[26] = 28'h000003f;
    imem[27] = 28'h0000355;
    imem[28] = 28'h00ffd55;
    imem[29] = 28'h0d5f555;
    imem[30] = 28'h0d7d5d5;
    imem[31] = 28'h05f55d5;
    imem[32] = 28'h35f57d5;
    imem[33] = 28'h37d5eb5;
    imem[34] = 28'h15d5eb5;
    imem[35] = 28'hd5d7aad;
    imem[36] = 28'hd757aad;
    imem[37] = 28'h5757aab;
    imem[38] = 28'h5757bfa;
    imem[39] = 28'h57deaaa;
    imem[40] = 28'h57deaaa;
    imem[41] = 28'h57deaba;
    imem[42] = 28'h57deaaf;
    imem[43] = 28'h573faaa;
    imem[44] = 28'h5703fff;
    imem[45] = 28'h570003a;
    imem[46] = 28'h54000fa;
    imem[47] = 28'h54003ea;
    smem[0] = 28'h0000000;
    smem[1] = 28'h0000000;
    smem[2] = 28'h000003f;
    smem[3] = 28'h0000355;
    smem[4] = 28'h00ffd55;
    smem[5] = 28'h0d5f555;
    smem[6] = 28'h0d7d5d5;
    smem[7] = 28'h05f55d5;
    smem[8] = 28'h35f57d5;
    smem[9] = 28'h37d5eb5;
    smem[10] = 28'h15d5eb5;
    smem[11] = 28'hd5d7aad;
    smem[12] = 28'hd757aad;
    smem[13] = 28'h5757aab;
    smem[14] = 28'h5757bfa;
    smem[15] = 28'h57deaaa;
    smem[16] = 28'h57deaaa;
    smem[17] = 28'h57deaba;
    smem[18] = 28'h57deaaf;
    smem[19] = 28'h573faaa;
    smem[20] = 28'h5703fff;
    smem[21] = 28'h570003a;
    smem[22] = 28'h54000fa;
    smem[23] = 28'h54003ea;
    smem[24] = 28'h0000000;
    smem[25] = 28'h0000000;
    smem[26] = 28'h000003f;
    smem[27] = 28'h0000355;
    smem[28] = 28'h00ffd55;
    smem[29] = 28'h0d5f555;
    smem[30] = 28'h0d7d5d5;
    smem[31] = 28'h05f55d5;
    smem[32] = 28'h35f57d5;
    smem[33] = 28'h37d5eb5;
    smem[34] = 28'h15d5eb5;
    smem[35] = 28'hd5d7aad;
    smem[36] = 28'hd757aad;
    smem[37] = 28'h5757bfb;
    smem[38] = 28'h5757aaa;
    smem[39] = 28'h57deaaa;
    smem[40] = 28'h57deaaa;
    smem[41] = 28'h57deaaf;
    smem[42] = 28'h57deaaf;
    smem[43] = 28'h573faaa;
    smem[44] = 28'h5703fff;
    smem[45] = 28'h570003a;
    smem[46] = 28'h54000fa;
    smem[47] = 28'h54003ea;
  end
  wire [5:0] addr = frame[0] ? (6'd24 + {1'b0, y}) : {1'b0, y};
  wire [27:0] irow = imem[addr];
  wire [27:0] srow = smem[addr];
  wire [4:0] cm = (x >= 5'd14) ? (x - 5'd14) : (5'd13 - x);
  wire [27:0] ish = irow >> {cm, 1'b0};
  wire [27:0] ssh = srow >> {cm, 1'b0};
  assign pixel = frame[1] ? ssh[1:0] : ish[1:0];
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