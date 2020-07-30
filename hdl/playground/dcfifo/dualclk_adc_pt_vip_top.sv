`timescale 1ns/1ps
`default_nettype none

/*
*/
module dualclk_adc_pt_vip_top #(
  parameter real PERIOD=10,
  parameter int SAMP=32,
  parameter int FFT_LEN=32,
  parameter int DEC_FAC=24,
  parameter int SRT_PHA=23,
  parameter int TDATA_WIDTH=16,
  parameter int FIFO_DEPTH=32,
  parameter int DATA_COUNT_WIDTH=$clog2(FIFO_DEPTH),
  parameter int PROG_EMPTY_THRESH=16,
  parameter int PROG_FULL_THRESH=16
) (
  input wire logic clka,
  input wire logic clkb,
  input wire logic rst,
  input wire logic adc_en,
  output logic vip_full,

  // examining axis fifo signals
  output logic almost_empty_axis,
  output logic almost_full_axis,
  output logic prog_empty_axis,
  output logic prog_full_axis,
  output logic [DATA_COUNT_WIDTH-1:0] rd_data_count_axis,
  output logic [DATA_COUNT_WIDTH-1:0] wr_data_count_axis
);

axis #(.WIDTH(2*TDATA_WIDTH)) s_axis(), m_axis(), s_pt_axis();
logic s_axis_tlast, m_axis_tlast;

logic hold_rst;

adc_model #(
  .PERIOD(PERIOD),
  .TWID(TDATA_WIDTH),
  .DTYPE("CX")
) adc_inst (
  .clk(clka),
  .rst(rst),
   // TODO: is it time to remove en, It was added to test FFT functionality, wasn't it temporary
  .en(adc_en),
  .m_axis(s_axis)
);

xpm_fifo_axis #(
   .CDC_SYNC_STAGES(2),                    // DECIMAL
   .CLOCKING_MODE("independent_clock"),    // String
   .ECC_MODE("no_ecc"),                    // String
   .FIFO_DEPTH(FIFO_DEPTH),                // DECIMAL
   .FIFO_MEMORY_TYPE("auto"),              // String
   .PACKET_FIFO("false"),                  // String
   .PROG_EMPTY_THRESH(PROG_EMPTY_THRESH),  // DECIMAL
   .PROG_FULL_THRESH(PROG_FULL_THRESH),    // DECIMAL
   .RD_DATA_COUNT_WIDTH(DATA_COUNT_WIDTH), // DECIMAL
   .RELATED_CLOCKS(1),                     // DECIMAL
   .SIM_ASSERT_CHK(1),                     // DECIMAL
   .TDATA_WIDTH(2*TDATA_WIDTH),            // DECIMAL
   .TDEST_WIDTH(1),                        // DECIMAL
   .TID_WIDTH(1),                          // DECIMAL
   .TUSER_WIDTH(1),                        // DECIMAL
   .USE_ADV_FEATURES("1E0E"),              // String
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

pt_ctr #(
    .MAX_CNT(FFT_LEN),
    .START(SRT_PHA),
    .PAUSE(DEC_FAC)
  ) pt_ctr_inst (
    .clk(clkb),
    .rst(hold_rst),
    .s_axis(m_axis),
    .m_axis(s_pt_axis)
  );

axis_vip #(
  .WIDTH(2*TDATA_WIDTH),
  .DEPTH(SAMP)
) vip_inst (
  .clk(clkb),
  .rst(hold_rst),
  .s_axis(s_pt_axis),
  .full(vip_full)
);

typedef enum logic [1:0] {WAIT_FIFO_RDY, PROCESS, ERR='X} stateType;
stateType ns, cs;

always_ff @(posedge clkb)
  cs <= ns;

always_comb begin
  // default values so no latches
  ns = ERR;
  hold_rst = 1'b1;

  if (rst)
    ns = WAIT_FIFO_RDY;
  else
    case (cs)
      WAIT_FIFO_RDY: begin
        if (m_axis.tvalid) begin
          hold_rst = 1'b0;
          ns = PROCESS;
        end else begin
          hold_rst = 1'b1;
          ns = WAIT_FIFO_RDY;
        end
      end

      PROCESS: begin
        hold_rst = 1'b0;
        ns = PROCESS;
      end
    endcase
end

endmodule
