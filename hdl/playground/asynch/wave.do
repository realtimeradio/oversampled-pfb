onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /testbench/clk
add wave -noupdate /testbench/rst
add wave -noupdate /testbench/DUT/src_ctr_inst/dout
add wave -noupdate /testbench/DUT/s_axis_asynch/tdata
add wave -noupdate /testbench/DUT/s_axis_asynch/tready
add wave -noupdate /testbench/DUT/s_axis_asynch/tvalid
add wave -noupdate /testbench/DUT/s_axis_synch/tdata
add wave -noupdate /testbench/DUT/s_axis_synch/tready
add wave -noupdate /testbench/DUT/s_axis_synch/tvalid
add wave -noupdate /testbench/m_axis_asynch/tdata
add wave -noupdate /testbench/m_axis_asynch/tready
add wave -noupdate /testbench/m_axis_asynch/tvalid
add wave -noupdate -expand /testbench/DUT/asynch_inst/q
add wave -noupdate /testbench/m_axis_synch/tdata
add wave -noupdate /testbench/m_axis_synch/tready
add wave -noupdate /testbench/m_axis_synch/tvalid
add wave -noupdate -expand /testbench/DUT/synch_inst/q
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {104379 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 276
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
WaveRestoreZoom {0 ps} {110250 ps}
