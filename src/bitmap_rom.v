`default_nettype none

// idle: 2 frames x 24 rows x 56 bits (full width), 2bpp
// sing: 2 frames x 24 rows x 56 bits (full width), 2bpp
module frame_rom (
    input  wire [2:0] frame,   // 0-1 idle, 2-3 singing
    input  wire [4:0] x,       // 0..27
    input  wire [4:0] y,       // 0..23
    output wire [1:0] pixel
);
  reg [55:0] imem[47:0];
  reg [55:0] smem[47:0];
  initial begin
    imem[0] = 56'h015ff55555557f;
    imem[1] = 56'h015fd55555555f;
    imem[2] = 56'h017fd555555557;
    imem[3] = 56'h057f5555559557;
    imem[4] = 56'h057f5556559557;
    imem[5] = 56'h05ff555a569557;
    imem[6] = 56'h05ff556a569555;
    imem[7] = 56'h05ff5fe95a9557;
    imem[8] = 56'h15fd5ea95a9557;
    imem[9] = 56'h17fdffa96a9557;
    imem[10] = 56'h17fdffe9eaf557;
    imem[11] = 56'h17cdffefaabd57;
    imem[12] = 56'h17cdefaeaabd5f;
    imem[13] = 56'h17cfeabaaffd5f;
    imem[14] = 56'h17cfeaaaaabd7f;
    imem[15] = 56'h17c0eaaaaab75f;
    imem[16] = 56'h57c0faaaaab77f;
    imem[17] = 56'h57c0faaaaaff7f;
    imem[18] = 56'h57c0f2aaaafd7f;
    imem[19] = 56'h57c002aafffd7f;
    imem[20] = 56'h57c006abff7dff;
    imem[21] = 56'h57c006aa5575ff;
    imem[22] = 56'h57c005fd5eaaff;
    imem[23] = 56'h00000000000000;
    imem[24] = 56'hfd5555555ff540;
    imem[25] = 56'hf55555555ff540;
    imem[26] = 56'hd555555557fd40;
    imem[27] = 56'hd556555557fd50;
    imem[28] = 56'hd556559555fd50;
    imem[29] = 56'h555695a555ff50;
    imem[30] = 56'h555695a955ff50;
    imem[31] = 56'h555695abd5ff50;
    imem[32] = 56'h5556a56a95ff50;
    imem[33] = 56'hd557a96bfd7f54;
    imem[34] = 56'hd576ab6fff7fd4;
    imem[35] = 56'hd577fafbff73d4;
    imem[36] = 56'hf57ffabafb73d4;
    imem[37] = 56'hf57ffaaaabf3d4;
    imem[38] = 56'hf57ffaaaabf3d4;
    imem[39] = 56'hf55eaaaaaf03d4;
    imem[40] = 56'hf5deaaaaaf03d4;
    imem[41] = 56'hfdffaaaaaf03d5;
    imem[42] = 56'hfd7faaaaac03d5;
    imem[43] = 56'hfd7fd6aafc03d5;
    imem[44] = 56'hfd7df6aad003d5;
    imem[45] = 56'hff5d55aa5003d5;
    imem[46] = 56'hffaab57f5003d5;
    imem[47] = 56'h00000000000000;
    smem[0] = 56'h00000000000000;
    smem[1] = 56'h00000000000000;
    smem[2] = 56'h00000fffc00000;
    smem[3] = 56'h0000f5555f0000;
    smem[4] = 56'h0033555555ffc0;
    smem[5] = 56'h0dfd5555557f40;
    smem[6] = 56'h0dfd5555755f70;
    smem[7] = 56'h07f5d5f57d5ff0;
    smem[8] = 56'h37f5d5f57957dc;
    smem[9] = 56'h35d5d7b56b575c;
    smem[10] = 56'h15d757b5efd5d4;
    smem[11] = 56'hd5d77ab7aad5d7;
    smem[12] = 56'hd5d7eabeaad5d7;
    smem[13] = 56'hd5d7aaeaaab5d7;
    smem[14] = 56'h555fffaabfb5d5;
    smem[15] = 56'h575feaaaaaf5d5;
    smem[16] = 56'h575faaaaaaf7d5;
    smem[17] = 56'h575faaaaaaf7d5;
    smem[18] = 56'h57dfeaffaaf7d5;
    smem[19] = 56'h57d43aaafff7d5;
    smem[20] = 56'h573c03ffffccd5;
    smem[21] = 56'h570003ffc000d5;
    smem[22] = 56'h00000000000000;
    smem[23] = 56'h00000000000000;
    smem[24] = 56'h00000000000000;
    smem[25] = 56'h0000d555570000;
    smem[26] = 56'h03ff555555ffc0;
    smem[27] = 56'h0dfd5555557f70;
    smem[28] = 56'h0df575d5755f70;
    smem[29] = 56'h07f5d5f57d5ff0;
    smem[30] = 56'h05f5d5f57d57d0;
    smem[31] = 56'h35f5d7b5ef575c;
    smem[32] = 56'h35f5d7a5eb575c;
    smem[33] = 56'h35d5deadea575c;
    smem[34] = 56'h35f5faafaad754;
    smem[35] = 56'h15f5ffaebfd757;
    smem[36] = 56'hd5f5faaaabd757;
    smem[37] = 56'hd5f5eaaaaadf57;
    smem[38] = 56'hd5f5eaffaadf57;
    smem[39] = 56'hd5e5eaffeadf57;
    smem[40] = 56'hd5edeafffbfb57;
    smem[41] = 56'hd56fefaaffeb55;
    smem[42] = 56'hd56afaffebab55;
    smem[43] = 56'hd57aabffeaab55;
    smem[44] = 56'hd57feffffbff55;
    smem[45] = 56'h55fabf3cffeb55;
    smem[46] = 56'h00000000000000;
    smem[47] = 56'h00000000000000;
  end
  wire [5:0] addr = frame[0] ? (6'd24 + {1'b0, y}) : {1'b0, y};
  wire [55:0] irow = imem[addr];
  wire [55:0] srow = smem[addr];
  wire [4:0] cm = (x >= 5'd14) ? (x - 5'd14) : (5'd13 - x);
  wire [55:0] ish = irow >> {x, 1'b0};
  wire [55:0] ssh = srow >> {x, 1'b0};
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