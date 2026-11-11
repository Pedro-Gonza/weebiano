`default_nettype none

module tt_um_Pedro-Gonza_weeb-iano(
  input  wire [7:0] ui_in,
  output wire [7:0] uo_out,
  input  wire [7:0] uio_in,
  output wire [7:0] uio_out,
  output wire [7:0] uio_oe,
  input  wire       ena,
  input  wire       clk,
  input  wire       rst_n
);
  localparam NFRAMES = 450;     // value printed by the Python script

  wire play    = ui_in[0];
  wire restart = ui_in[1];
  wire loop_en = ui_in[2];

  wire hsync, vsync, video_active;
  wire [9:0] pix_x, pix_y;

  hvsync_generator hvsync_gen(
    .clk(clk), .reset(~rst_n),
    .hsync(hsync), .vsync(vsync),
    .display_on(video_active),
    .hpos(pix_x), .vpos(pix_y)
  );

  reg [8:0] frame;
  reg [1:0] div;
  reg vsync_q;

  always @(posedge clk) begin
    if (!rst_n || restart) begin
      frame <= 0;
      div   <= 0;
    end else begin
      vsync_q <= vsync;
      if (vsync != vsync_q && vsync) begin   // one edge per video frame
        if (play) begin
          div <= div + 1;
          if (div == 3) begin                // 60 Hz / 4 = 15 fps
            if (frame == NFRAMES - 1) begin
              if (loop_en) frame <= 0;       // else hold the last frame
            end else begin
              frame <= frame + 1;
            end
          end
        end
      end
    end
  end

  wire pixel;
  bitmap_rom rom(
    .frame(frame),
    .x(pix_x[9:4]),     // 640/16 = 40 columns
    .y(pix_y[9:4]),     // 480/16 = 30 rows
    .pixel(pixel)
  );

  wire on = video_active && pixel;
  wire [1:0] c = on ? 2'b11 : 2'b00;

  assign uo_out  = {hsync, c[0], c[0], c[0], vsync, c[1], c[1], c[1]};
  assign uio_out = 0;
  assign uio_oe  = 0;

  wire _unused = &{ena, uio_in, ui_in[7:3], 1'b0};
endmodule
