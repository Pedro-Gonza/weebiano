// 8 labels x 6 rows x 12 bits
module label_rom (
    input  wire [2:0] note,
    input  wire [3:0] x,       // 0..11
    input  wire [2:0] y,       // 0..5
    output wire       pixel
);
  reg [15:0] mem[47:0];
  initial begin
    mem[0] = 16'h0003;
    mem[1] = 16'h0025;
    mem[2] = 16'h0055;
    mem[3] = 16'h0055;
    mem[4] = 16'h0023;
    mem[5] = 16'h0000;
    mem[6] = 16'h0063;
    mem[7] = 16'h0055;
    mem[8] = 16'h0073;
    mem[9] = 16'h0015;
    mem[10] = 16'h0065;
    mem[11] = 16'h0000;
    mem[12] = 16'h0025;
    mem[13] = 16'h0007;
    mem[14] = 16'h0027;
    mem[15] = 16'h0025;
    mem[16] = 16'h0025;
    mem[17] = 16'h0000;
    mem[18] = 16'h0007;
    mem[19] = 16'h0031;
    mem[20] = 16'h0063;
    mem[21] = 16'h0051;
    mem[22] = 16'h0061;
    mem[23] = 16'h0000;
    mem[24] = 16'h0306;
    mem[25] = 16'h0221;
    mem[26] = 16'h0252;
    mem[27] = 16'h0254;
    mem[28] = 16'h0723;
    mem[29] = 16'h0000;
    mem[30] = 16'h0001;
    mem[31] = 16'h0031;
    mem[32] = 16'h0061;
    mem[33] = 16'h0051;
    mem[34] = 16'h0067;
    mem[35] = 16'h0000;
    mem[36] = 16'h0026;
    mem[37] = 16'h0001;
    mem[38] = 16'h0022;
    mem[39] = 16'h0024;
    mem[40] = 16'h0023;
    mem[41] = 16'h0000;
    mem[42] = 16'h0003;
    mem[43] = 16'h0025;
    mem[44] = 16'h0055;
    mem[45] = 16'h0055;
    mem[46] = 16'h0023;
    mem[47] = 16'h0000;
  end
  wire [5:0] addr = note * 6'd6 + y;
  assign pixel = mem[addr][x];
endmodule