# ospfb constraints

# clock
# primary required axis adc out clock
create_clock -period 3.906 -name adc_clk [get_ports s_axis_aclk]
# create_clocks? or generated clocks? It seems create_generated clock requires a
# physical clock source so you need a "logical path" connecting the two? What if
# I create another clock and and then assign it as a clock group with some
# derived information?
# derived dsp clock
create_generated_clock -source [get_ports s_axis_aclk] -name dsp_clk -multiply_by 4 -divide_by 3 [get_ports m_axis_aclk]

## pblock
#create_pblock ospfb_pblock;
#add_cells_to_pblock [get_pblocks ospfb_pblock] [get_cells [list
