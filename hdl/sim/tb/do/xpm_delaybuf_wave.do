onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /xpm_delaybuf_test/clk
add wave -noupdate /xpm_delaybuf_test/rst
add wave -noupdate /xpm_delaybuf_test/rd_data_count
add wave -noupdate /xpm_delaybuf_test/wr_data_count
add wave -noupdate /xpm_delaybuf_test/m_axis_tuser
add wave -noupdate /xpm_delaybuf_test/s_axis_tuser
add wave -noupdate /xpm_delaybuf_test/DUT/cs
add wave -noupdate /xpm_delaybuf_test/DUT/ns
add wave -noupdate /xpm_delaybuf_test/DUT/almost_full
add wave -noupdate /xpm_delaybuf_test/m_axis/tdata
add wave -noupdate /xpm_delaybuf_test/m_axis/tready
add wave -noupdate /xpm_delaybuf_test/m_axis/tvalid
add wave -noupdate /xpm_delaybuf_test/s_axis/tdata
add wave -noupdate /xpm_delaybuf_test/s_axis/tready
add wave -noupdate /xpm_delaybuf_test/s_axis/tvalid
add wave -noupdate /xpm_delaybuf_test/DUT/s_axis_delaybuf/tdata
add wave -noupdate /xpm_delaybuf_test/DUT/s_axis_delaybuf/tready
add wave -noupdate /xpm_delaybuf_test/DUT/s_axis_delaybuf/tvalid
add wave -noupdate /xpm_delaybuf_test/DUT/m_axis_delaybuf/tdata
add wave -noupdate /xpm_delaybuf_test/DUT/m_axis_delaybuf/tready
add wave -noupdate /xpm_delaybuf_test/DUT/m_axis_delaybuf/tvalid
add wave -noupdate /xpm_delaybuf_test/DUT/delaybuf/m_axis_tdata
add wave -noupdate /xpm_delaybuf_test/DUT/delaybuf/m_axis_tvalid
add wave -noupdate /xpm_delaybuf_test/DUT/delaybuf/m_axis_tready
add wave -noupdate /xpm_delaybuf_test/DUT/delaybuf/s_axis_tdata
add wave -noupdate /xpm_delaybuf_test/DUT/delaybuf/s_axis_tvalid
add wave -noupdate /xpm_delaybuf_test/DUT/delaybuf/s_axis_tready
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {155000 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 317
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
WaveRestoreZoom {0 ps} {1005214 ps}
