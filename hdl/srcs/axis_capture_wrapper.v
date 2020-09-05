

module axis_capture_wrapper #(
  parameter TDATA_NUM_BYTES=4,
  parameter DEPTH=65536,
  parameter BRAM_ADDR_WID=32
) (
  input wire clk,
  input wire rst,

  input wire signed [TDATA_NUM_BYTES*8-1:0] s_axis_tdata,
  input wire s_axis_tvalid,
  output wire s_axis_tready,

  output wire [TDATA_NUM_BYTES*8-1:0] bram_wdata,        // Data In Bus (optional)
  output wire [TDATA_NUM_BYTES-1:0] bram_we,         // Byte Enables (required w/ BRAM controller)
  output wire bram_en,                       // Chip Enable Signal (optional)

  input wire [TDATA_NUM_BYTES*8-1:0] bram_rdata,    // Data Out Bus (optional)

  output wire [BRAM_ADDR_WID-1:0] bram_addr, // Address Signal (required)
  output wire bram_clk,                      // Clock Signal (required)
  output wire bram_rst,                      // Reset Signal (required)

  output wire full
);

  localparam WIDTH = TDATA_NUM_BYTES*8;

  axis #(.WIDTH(WIDTH)) s_axis();

  assign s_axis.tdata = s_axis_tdata;
  assign s_axis.tvalid = s_axis_tvalid;
  assign s_axis_tready = s_axis.tready;

  axis_capture #(
    .WIDTH(WIDTH),
    .DEPTH(DEPTH),
    .BRAM_ADDR_WID(BRAM_ADDR_WID)
  ) axis_capture_inst (
    .clk(clk),
    .rst(rst),
    .s_axis(s_axis),
    .bram_wdata(bram_wdata),
    .bram_we(bram_we),
    .bram_en(bram_en),
    .bram_rdata(bram_rdata),
    .bram_addr(bram_addr),
    .bram_clk(bram_clk),
    .bram_rst(bram_rst),
    .full(full)
  );

endmodule
