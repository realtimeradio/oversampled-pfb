`timescale 1ns/1ps
`default_nettype none

/*
  First test of the xpm fifo axis instance with free running counter and AXIS capture
  implementing AXIS TREADY/TVALID.
*/
module dualclk_ctr_top #(
  parameter int SAMP=32,
  parameter int TDATA_WIDTH=16,
  parameter int FIFO_DEPTH=32,
  parameter int DATA_COUNT_WIDTH=$clog2(FIFO_DEPTH)
) (
  input wire logic clka,
  input wire logic clkb,
  input wire logic rst,
  output logic vip_full,

  // examining axis fifo signals
  output logic almost_empty_axis,
  output logic almost_full_axis,
  output logic prog_empty_axis,
  output logic prog_full_axis,
  output logic [DATA_COUNT_WIDTH-1:0] rd_data_count_axis,
  output logic [DATA_COUNT_WIDTH-1:0] wr_data_count_axis
);

axis #(.WIDTH(TDATA_WIDTH)) s_axis(), m_axis();
logic s_axis_tlast, m_axis_tlast;

src_ctr #(
  .WIDTH(TDATA_WIDTH),
  .MAX_CNT(FIFO_DEPTH),
  .ORDER("processing")
) src_ctr_inst (
  .clk(clka),
  .rst(rst),
  .m_axis(s_axis)
);

xpm_fifo_axis #(
   .CDC_SYNC_STAGES(2),                    // DECIMAL
   .CLOCKING_MODE("independent_clock"),    // String
   .ECC_MODE("no_ecc"),                    // String
   .FIFO_DEPTH(FIFO_DEPTH),                // DECIMAL
   .FIFO_MEMORY_TYPE("auto"),              // String
   .PACKET_FIFO("false"),                  // String
   .PROG_EMPTY_THRESH(10),                 // DECIMAL
   .PROG_FULL_THRESH(10),                  // DECIMAL
   .RD_DATA_COUNT_WIDTH(DATA_COUNT_WIDTH), // DECIMAL
   .RELATED_CLOCKS(1),                     // DECIMAL
   .SIM_ASSERT_CHK(1),                     // DECIMAL
   .TDATA_WIDTH(TDATA_WIDTH),              // DECIMAL
   .TDEST_WIDTH(1),                        // DECIMAL
   .TID_WIDTH(1),                          // DECIMAL
   .TUSER_WIDTH(1),                        // DECIMAL
   .USE_ADV_FEATURES("0E0E"),              // String
   .WR_DATA_COUNT_WIDTH(DATA_COUNT_WIDTH)  // DECIMAL
) xpm_fifo_axis_inst (
   .almost_empty_axis(almost_empty_axis),   // 1-bit output: Almost Empty : When asserted, this signal
                                            // indicates that only one more read can be
                                            // performed before the FIFO goes to empty.

   .almost_full_axis(almost_full_axis),     // 1-bit output: Almost Full: When asserted, this signal
                                            // indicates that only one more write can be
                                            // performed before the FIFO is full.

   .m_axis_tdata(m_axis.tdata),
   .m_axis_tlast(m_axis_tlast),
   .m_axis_tvalid(m_axis.tvalid),

   .prog_empty_axis(prog_empty_axis),       // 1-bit output: Programmable Empty- This signal is asserted
                                            // when the number of words in the FIFO is less than
                                            // or equal to the programmable empty threshold
                                            // value. It is de-asserted when the number of words
                                            // in the FIFO exceeds the programmable empty
                                            // threshold value.

   .prog_full_axis(prog_full_axis),         // 1-bit output: Programmable Full: This signal is asserted when
                                            // the number of words in the FIFO is greater than
                                            // or equal to the programmable full threshold
                                            // value. It is de-asserted when the number of words
                                            // in the FIFO is less than the programmable full
                                            // threshold value.

   .rd_data_count_axis(rd_data_count_axis), // RD_DATA_COUNT_WIDTH-bit output: Read Data Count- This bus
                                            // indicates the number of words available for reading in the FIFO.

   .s_axis_tready(s_axis.tready),

   .wr_data_count_axis(wr_data_count_axis), // WR_DATA_COUNT_WIDTH-bit output: Write Data Count: This bus
                                            // indicates the number of words written into the
                                            // FIFO.

   .m_aclk(clkb),

   .m_axis_tready(m_axis.tready),

   .s_aclk(clka),

   .s_aresetn(~rst),

   .s_axis_tdata(s_axis.tdata),
   .s_axis_tlast(s_axis_tlast),
   .s_axis_tvalid(s_axis.tvalid)

);

// End of xpm_fifo_axis_inst instantiation

axis_vip #(
  .WIDTH(TDATA_WIDTH),
  .DEPTH(SAMP)
) vip_inst (
  .clk(clkb),
  .rst(rst),
  .s_axis(m_axis),
  .full(vip_full)
);

endmodule
