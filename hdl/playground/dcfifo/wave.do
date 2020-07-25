onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /glbl/GSR
add wave -noupdate /dualclk_testbench/adc_clk
add wave -noupdate /dualclk_testbench/dsp_clk
add wave -noupdate /dualclk_testbench/rst
add wave -noupdate /dualclk_testbench/almost_full
add wave -noupdate /dualclk_testbench/almost_empty
add wave -noupdate /dualclk_testbench/rd_count
add wave -noupdate /dualclk_testbench/wr_count
add wave -noupdate /dualclk_testbench/DUT/vip_inst/ram
add wave -noupdate /dualclk_testbench/DUT/xpm_fifo_axis_inst/almost_empty_axis
add wave -noupdate /dualclk_testbench/DUT/xpm_fifo_axis_inst/almost_full_axis
add wave -noupdate /dualclk_testbench/DUT/xpm_fifo_axis_inst/rd_data_count_axis
add wave -noupdate /dualclk_testbench/DUT/xpm_fifo_axis_inst/wr_data_count_axis
add wave -noupdate /dualclk_testbench/DUT/xpm_fifo_axis_inst/s_axis_tdata
add wave -noupdate /dualclk_testbench/DUT/xpm_fifo_axis_inst/s_axis_tready
add wave -noupdate /dualclk_testbench/DUT/xpm_fifo_axis_inst/s_axis_tvalid
add wave -noupdate /dualclk_testbench/DUT/xpm_fifo_axis_inst/m_axis_tdata
add wave -noupdate /dualclk_testbench/DUT/xpm_fifo_axis_inst/m_axis_tready
add wave -noupdate /dualclk_testbench/DUT/xpm_fifo_axis_inst/m_axis_tvalid
add wave -noupdate /dualclk_testbench/DUT/src_ctr_inst/m_axis/tdata
add wave -noupdate /dualclk_testbench/DUT/src_ctr_inst/m_axis/tvalid
add wave -noupdate /dualclk_testbench/DUT/src_ctr_inst/m_axis/tready
add wave -noupdate /dualclk_testbench/DUT/xpm_fifo_axis_inst/xpm_fifo_base_inst/wr_rst_busy
add wave -noupdate /dualclk_testbench/DUT/xpm_fifo_axis_inst/xpm_fifo_base_inst/full
add wave -noupdate /dualclk_testbench/DUT/xpm_fifo_axis_inst/xpm_fifo_base_inst/empty
add wave -noupdate /dualclk_testbench/DUT/xpm_fifo_axis_inst/xpm_fifo_base_inst/wr_data_count
add wave -noupdate /dualclk_testbench/DUT/xpm_fifo_axis_inst/xpm_fifo_base_inst/rd_data_count
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {500788 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 376
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 0
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ns
update
WaveRestoreZoom {0 ps} {2261700 ps}
