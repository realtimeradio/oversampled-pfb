onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /ospfb_tb/dsp_clk
add wave -noupdate /ospfb_tb/rst
add wave -noupdate /ospfb_tb/en
add wave -noupdate /ospfb_tb/DUT/ospfb_inst/hold_rst
add wave -noupdate /ospfb_tb/DUT/s_axis/tdata
add wave -noupdate /ospfb_tb/DUT/s_axis/tvalid
add wave -noupdate /ospfb_tb/DUT/s_axis/tready
add wave -noupdate /ospfb_tb/DUT/ospfb_inst/s_axis_fft_data/tdata
add wave -noupdate /ospfb_tb/DUT/ospfb_inst/s_axis_fft_data/tvalid
add wave -noupdate /ospfb_tb/DUT/ospfb_inst/s_axis_fft_data/tready
add wave -noupdate /ospfb_tb/DUT/ospfb_inst/fft_inst/s_axis_data_tlast
add wave -noupdate /ospfb_tb/DUT/ospfb_inst/fft_inst/s_axis_data_tready
add wave -noupdate /ospfb_tb/DUT/ospfb_inst/fft_inst/s_axis_data_tvalid
add wave -noupdate /ospfb_tb/DUT/ospfb_inst/cs
add wave -noupdate /ospfb_tb/DUT/ospfb_inst/ns
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {2852280 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 290
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
WaveRestoreZoom {1617119 ps} {4188319 ps}
