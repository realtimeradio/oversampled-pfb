onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /xpm_ospfb_tb/adc_clk
add wave -noupdate /xpm_ospfb_tb/dsp_clk
add wave -noupdate /xpm_ospfb_tb/rst
add wave -noupdate /xpm_ospfb_tb/en
add wave -noupdate /xpm_ospfb_tb/DUT/ospfb_inst/hold_rst
add wave -noupdate /xpm_ospfb_tb/DUT/ospfb_inst/ns
add wave -noupdate /xpm_ospfb_tb/DUT/ospfb_inst/cs
add wave -noupdate /xpm_ospfb_tb/DUT/ospfb_inst/din_re
add wave -noupdate /xpm_ospfb_tb/DUT/ospfb_inst/din_im
add wave -noupdate /xpm_ospfb_tb/DUT/ospfb_inst/pc_in_re
add wave -noupdate /xpm_ospfb_tb/DUT/ospfb_inst/pc_in_im
add wave -noupdate /xpm_ospfb_tb/DUT/ospfb_inst/s_axis_fir_re/tdata
add wave -noupdate /xpm_ospfb_tb/DUT/ospfb_inst/s_axis_fir_re/tvalid
add wave -noupdate /xpm_ospfb_tb/DUT/ospfb_inst/s_axis_fir_re/tready
add wave -noupdate /xpm_ospfb_tb/DUT/ospfb_inst/s_axis_tuser
add wave -noupdate /xpm_ospfb_tb/DUT/ospfb_inst/s_axis_fir_im/tdata
add wave -noupdate /xpm_ospfb_tb/DUT/ospfb_inst/s_axis_fir_im/tvalid
add wave -noupdate /xpm_ospfb_tb/DUT/ospfb_inst/s_axis_fir_im/tready
add wave -noupdate /xpm_ospfb_tb/DUT/ospfb_inst/m_axis_fir_re/tdata
add wave -noupdate /xpm_ospfb_tb/DUT/ospfb_inst/m_axis_fir_re/tvalid
add wave -noupdate /xpm_ospfb_tb/DUT/ospfb_inst/m_axis_fir_re/tready
add wave -noupdate /xpm_ospfb_tb/DUT/ospfb_inst/m_axis_tuser_re
add wave -noupdate /xpm_ospfb_tb/DUT/ospfb_inst/m_axis_fir_im/tdata
add wave -noupdate /xpm_ospfb_tb/DUT/ospfb_inst/m_axis_fir_im/tvalid
add wave -noupdate /xpm_ospfb_tb/DUT/ospfb_inst/m_axis_fir_im/tready
add wave -noupdate /xpm_ospfb_tb/DUT/ospfb_inst/m_axis_tuser_im
add wave -noupdate /xpm_ospfb_tb/DUT/ospfb_inst/fir_im/s_axis/tdata
add wave -noupdate /xpm_ospfb_tb/DUT/ospfb_inst/fir_im/s_axis/tvalid
add wave -noupdate /xpm_ospfb_tb/DUT/ospfb_inst/fir_im/s_axis/tready
add wave -noupdate {/xpm_ospfb_tb/DUT/ospfb_inst/fir_im/axis_pe_data[0]/tdata}
add wave -noupdate {/xpm_ospfb_tb/DUT/ospfb_inst/fir_im/axis_pe_data[0]/tvalid}
add wave -noupdate {/xpm_ospfb_tb/DUT/ospfb_inst/fir_im/axis_pe_data[0]/tready}
add wave -noupdate {/xpm_ospfb_tb/DUT/ospfb_inst/fir_im/axis_pe_data[4]/tdata}
add wave -noupdate {/xpm_ospfb_tb/DUT/ospfb_inst/fir_im/axis_pe_data[4]/tvalid}
add wave -noupdate {/xpm_ospfb_tb/DUT/ospfb_inst/fir_im/axis_pe_data[4]/tready}
add wave -noupdate {/xpm_ospfb_tb/DUT/ospfb_inst/fir_im/axis_pe_sum[0]/tdata}
add wave -noupdate {/xpm_ospfb_tb/DUT/ospfb_inst/fir_im/axis_pe_sum[0]/tvalid}
add wave -noupdate {/xpm_ospfb_tb/DUT/ospfb_inst/fir_im/axis_pe_sum[0]/tready}
add wave -noupdate {/xpm_ospfb_tb/DUT/ospfb_inst/fir_im/axis_pe_sum[4]/tdata}
add wave -noupdate {/xpm_ospfb_tb/DUT/ospfb_inst/fir_im/axis_pe_sum[4]/tvalid}
add wave -noupdate {/xpm_ospfb_tb/DUT/ospfb_inst/fir_im/axis_pe_sum[4]/tready}
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {2868789 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 371
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
WaveRestoreZoom {0 ps} {3463840 ps}
