// xpm_fifo_axis: AXI Stream FIFO
// Xilinx Parameterized Macro, version 2019.1
xpm_fifo_axis #(
   .CDC_SYNC_STAGES(2),
   .CLOCKING_MODE("common_clock"),
   .ECC_MODE("no_ecc"),
   .FIFO_DEPTH(2048),
   .FIFO_MEMORY_TYPE("auto"),
   .PACKET_FIFO("false"),
   .PROG_EMPTY_THRESH(10),
   .PROG_FULL_THRESH(10),
   .RD_DATA_COUNT_WIDTH(1),
   .RELATED_CLOCKS(0),
   .SIM_ASSERT_CHK(0),
   .TDATA_WIDTH(32),
   .TDEST_WIDTH(1),
   .TID_WIDTH(1),
   .TUSER_WIDTH(1),
   .USE_ADV_FEATURES("1000"),
   .WR_DATA_COUNT_WIDTH(1)
)
xpm_fifo_axis_inst (
   .almost_empty_axis(almost_empty_axis),
   .almost_full_axis(almost_full_axis),

   .dbiterr_axis(dbiterr_axis),

   .m_axis_tdata(m_axis_tdata),
   .m_axis_tdest(m_axis_tdest),
   .m_axis_tid(m_axis_tid),
   .m_axis_tkeep(m_axis_tkeep),
   .m_axis_tlast(m_axis_tlast),
   .m_axis_tstrb(m_axis_tstrb),
   .m_axis_tuser(m_axis_tuser),
   .m_axis_tvalid(m_axis_tvalid),

   .prog_empty_axis(prog_empty_axis),
   .prog_full_axis(prog_full_axis),

   .rd_data_count_axis(rd_data_count_axis),

   .s_axis_tready(s_axis_tready),

   .sbiterr_axis(sbiterr_axis),

   .wr_data_count_axis(wr_data_count_axis),

   .injectdbiterr_axis(injectdbiterr_axis),
   .injectsbiterr_axis(injectsbiterr_axis),

   .m_aclk(m_aclk),
   .m_axis_tready(m_axis_tready),

   .s_aclk(s_aclk),
   .s_aresetn(s_aresetn),

   .s_axis_tdata(s_axis_tdata),
   .s_axis_tdest(s_axis_tdest),
   .s_axis_tid(s_axis_tid),
   .s_axis_tkeep(s_axis_tkeep),
   .s_axis_tlast(s_axis_tlast),
   .s_axis_tstrb(s_axis_tstrb),
   .s_axis_tuser(s_axis_tuser),
   .s_axis_tvalid(s_axis_tvalid)
);

// End of xpm_fifo_axis_inst instantiation
