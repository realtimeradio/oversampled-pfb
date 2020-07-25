onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /phasecomp_tb/DUT/clk
add wave -noupdate /phasecomp_tb/DUT/cs
add wave -noupdate /phasecomp_tb/DUT/cs_rAddr
add wave -noupdate /phasecomp_tb/DUT/cs_wAddr
add wave -noupdate /phasecomp_tb/DUT/din
add wave -noupdate /phasecomp_tb/DUT/dout
add wave -noupdate /phasecomp_tb/DUT/incShift
add wave -noupdate /phasecomp_tb/DUT/ns
add wave -noupdate /phasecomp_tb/DUT/ns_rAddr
add wave -noupdate /phasecomp_tb/DUT/ns_wAddr
add wave -noupdate /phasecomp_tb/DUT/ren
add wave -noupdate /phasecomp_tb/DUT/rst
add wave -noupdate /phasecomp_tb/DUT/shiftOffset
add wave -noupdate /phasecomp_tb/DUT/wen
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {228 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 150
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
configure wave -timelineunits ps
update
WaveRestoreZoom {0 ps} {1 ns}
