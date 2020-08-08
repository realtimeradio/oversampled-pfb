onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /glbl/GSR
add wave -noupdate /impulse_ospfb_tb/adc_clk
add wave -noupdate /impulse_ospfb_tb/dsp_clk
add wave -noupdate /impulse_ospfb_tb/rst
add wave -noupdate /impulse_ospfb_tb/en
add wave -noupdate /impulse_ospfb_tb/vip_full
add wave -noupdate /impulse_ospfb_tb/rd_count
add wave -noupdate /impulse_ospfb_tb/wr_count
add wave -noupdate /impulse_ospfb_tb/event_frame_started
add wave -noupdate /impulse_ospfb_tb/event_fft_overflow
add wave -noupdate /impulse_ospfb_tb/event_data_in_channel_halt
add wave -noupdate /impulse_ospfb_tb/event_tlast_missing
add wave -noupdate /impulse_ospfb_tb/DUT/ospfb_inst/ns
add wave -noupdate /impulse_ospfb_tb/DUT/ospfb_inst/cs
add wave -noupdate /impulse_ospfb_tb/DUT/ospfb_inst/hold_rst
add wave -noupdate /impulse_ospfb_tb/DUT/ospfb_inst/din_im
add wave -noupdate /impulse_ospfb_tb/DUT/ospfb_inst/din_re
add wave -noupdate /impulse_ospfb_tb/DUT/ospfb_inst/s_axis/tdata
add wave -noupdate /impulse_ospfb_tb/DUT/ospfb_inst/s_axis/tvalid
add wave -noupdate /impulse_ospfb_tb/DUT/ospfb_inst/s_axis/tready
add wave -noupdate /impulse_ospfb_tb/DUT/ospfb_inst/s_axis_fft_data/tdata
add wave -noupdate /impulse_ospfb_tb/DUT/ospfb_inst/s_axis_fft_data/tvalid
add wave -noupdate /impulse_ospfb_tb/DUT/ospfb_inst/s_axis_fft_data/tready
add wave -noupdate /impulse_ospfb_tb/DUT/ospfb_inst/fft_inst/m_axis_data_tdata
add wave -noupdate /impulse_ospfb_tb/DUT/ospfb_inst/fft_inst/m_axis_data_tlast
add wave -noupdate /impulse_ospfb_tb/DUT/ospfb_inst/fft_inst/m_axis_data_tvalid
add wave -noupdate /impulse_ospfb_tb/DUT/ospfb_inst/fft_inst/m_axis_status_tdata
add wave -noupdate /impulse_ospfb_tb/DUT/ospfb_inst/fft_inst/m_axis_status_tvalid
add wave -noupdate /impulse_ospfb_tb/DUT/ospfb_inst/fft_inst/s_axis_data_tdata
add wave -noupdate /impulse_ospfb_tb/DUT/ospfb_inst/fft_inst/s_axis_data_tlast
add wave -noupdate /impulse_ospfb_tb/DUT/ospfb_inst/fft_inst/s_axis_data_tready
add wave -noupdate /impulse_ospfb_tb/DUT/ospfb_inst/fft_inst/s_axis_data_tvalid
add wave -noupdate /impulse_ospfb_tb/DUT/ospfb_inst/fft_inst/event_fft_overflow
add wave -noupdate /impulse_ospfb_tb/DUT/ospfb_inst/fft_inst/event_frame_started
add wave -noupdate /impulse_ospfb_tb/DUT/ospfb_inst/fft_inst/event_data_in_channel_halt
add wave -noupdate /impulse_ospfb_tb/DUT/ospfb_inst/fft_inst/s_axis_config_tdata
add wave -noupdate /impulse_ospfb_tb/DUT/ospfb_inst/fft_inst/s_axis_config_tready
add wave -noupdate /impulse_ospfb_tb/DUT/ospfb_inst/fft_inst/s_axis_config_tvalid
add wave -noupdate /impulse_ospfb_tb/DUT/vip_inst/s_axis/tdata
add wave -noupdate /impulse_ospfb_tb/DUT/vip_inst/s_axis/tready
add wave -noupdate /impulse_ospfb_tb/DUT/vip_inst/s_axis/tvalid
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {3026480 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 299
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
WaveRestoreZoom {2513279 ps} {3151745 ps}
