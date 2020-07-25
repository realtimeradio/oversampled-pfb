onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /glbl/GSR
add wave -noupdate /dualclk_adc_pt_vip_tb/adc_clk
add wave -noupdate /dualclk_adc_pt_vip_tb/dsp_clk
add wave -noupdate /dualclk_adc_pt_vip_tb/rst
add wave -noupdate /dualclk_adc_pt_vip_tb/adc_en
add wave -noupdate /dualclk_adc_pt_vip_tb/almost_empty
add wave -noupdate /dualclk_adc_pt_vip_tb/DUT/xpm_fifo_axis_inst/xpm_fifo_base_inst/empty
add wave -noupdate /dualclk_adc_pt_vip_tb/rd_count
add wave -noupdate /dualclk_adc_pt_vip_tb/wr_count
add wave -noupdate /dualclk_adc_pt_vip_tb/DUT/ns
add wave -noupdate /dualclk_adc_pt_vip_tb/DUT/cs
add wave -noupdate -max 134086999.99999999 -min -134087000.0 /dualclk_adc_pt_vip_tb/DUT/s_axis/tdata
add wave -noupdate /dualclk_adc_pt_vip_tb/DUT/s_axis/tvalid
add wave -noupdate /dualclk_adc_pt_vip_tb/DUT/s_axis/tready
add wave -noupdate /dualclk_adc_pt_vip_tb/DUT/m_axis/tdata
add wave -noupdate /dualclk_adc_pt_vip_tb/DUT/m_axis/tvalid
add wave -noupdate /dualclk_adc_pt_vip_tb/DUT/m_axis/tready
add wave -noupdate /dualclk_adc_pt_vip_tb/DUT/s_pt_axis/tdata
add wave -noupdate /dualclk_adc_pt_vip_tb/DUT/s_pt_axis/tvalid
add wave -noupdate /dualclk_adc_pt_vip_tb/DUT/s_pt_axis/tready
add wave -noupdate /dualclk_adc_pt_vip_tb/DUT/vip_inst/ram
add wave -noupdate /dualclk_adc_pt_vip_tb/vip_full
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {648844 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 361
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
WaveRestoreZoom {511156 ps} {881477 ps}
