onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /testbench/DUT/aresetn
add wave -noupdate /testbench/DUT/clk
add wave -noupdate /testbench/DUT/event_data_in_channel_halt
add wave -noupdate /testbench/DUT/event_frame_started
add wave -noupdate /testbench/DUT/event_tlast_missing
add wave -noupdate /testbench/DUT/event_tlast_unexpected
add wave -noupdate /testbench/DUT/fft_inst/event_data_in_channel_halt
add wave -noupdate /testbench/DUT/fft_inst/event_frame_started
add wave -noupdate /testbench/DUT/fft_inst/event_tlast_missing
add wave -noupdate /testbench/DUT/fft_inst/event_tlast_unexpected
add wave -noupdate /testbench/DUT/s_axis_data/tdata
add wave -noupdate /testbench/DUT/s_axis_data/tready
add wave -noupdate /testbench/DUT/s_axis_data/tvalid
add wave -noupdate /testbench/DUT/fft_inst/s_axis_data_tdata
add wave -noupdate /testbench/DUT/fft_inst/s_axis_data_tlast
add wave -noupdate /testbench/DUT/fft_inst/s_axis_data_tready
add wave -noupdate /testbench/DUT/fft_inst/s_axis_data_tvalid
add wave -noupdate /testbench/DUT/fft_inst/m_axis_data_tdata
add wave -noupdate /testbench/DUT/fft_inst/m_axis_data_tlast
add wave -noupdate /testbench/DUT/fft_inst/m_axis_data_tvalid
add wave -noupdate /testbench/m_axis/tdata
add wave -noupdate /testbench/m_axis/tready
add wave -noupdate /testbench/m_axis/tvalid
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {71783774 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 262
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
WaveRestoreZoom {0 ps} {80079139 ps}
