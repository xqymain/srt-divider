#MAX freq : 50M
set SYS_CLK_PERIOD 20.0
#*****************************************************
date
#*****************************************************

set fix_hold_switch       [getenv fix_hold_switch]
set exit_switch           [getenv exit_switch]
set area_switch           [getenv area_switch]
set power_switch          [getenv power_switch]
set ultra_switch          [getenv ultra_switch]
set high_switch           [getenv high_switch]
set remove_tie_dont_use_switch [getenv remove_tie_dont_use_switch]

# Define some variables for design -- {divider}
#*****************************************************
set TOP_MODULE           div_ASIC
set Rst_list		[list PAD_resetn_i]
set Clk_list		[list PAD_div_clk_i]  

set_svf         ${svfDir}/${TOP_MODULE}.svf

#Read saved unmapped ddc file
read_ddc  ${netlistDir}/${TOP_MODULE}_unmapped.ddc

# Define The Design Environment
set_min_library smic18io_line_ss_1p62v_2p97v_125c.db -min_version smic18io_line_ff_1p98v_3p63v_0c.db
set_operating_conditions -analysis_type bc_wc -min FFF -max SS

set_min_library smic18_ss_1p62v_125c.db -min_version  smic18_ff_1p98v_0c.db
set_operating_conditions -analysis_type bc_wc -min ff_1p98v_0c -max ss_1p62v_125c

set_wire_load_mode  "segmented"
set_wire_load_model -name reference_area_10000000 -library smic18_ss_1p62v_125c

#*****************************************************
# List of dont_use cells, Avoiding scan and jk flip-flops, latches
#*****************************************************

if 1 {
set_dont_use smic18_ss_1p62v_125c/FFSD*
set_dont_use smic18_ss_1p62v_125c/FFSED*
set_dont_use smic18_ss_1p62v_125c/FFJK*
set_dont_use smic18_ss_1p62v_125c/FFSJK*
set_dont_use smic18_ff_1p98v_0c/FFSD*
set_dont_use smic18_ff_1p98v_0c/FFSED*
set_dont_use smic18_ff_1p98v_0c/FFJK*
set_dont_use smic18_ff_1p98v_0c/FFSJK*
}

#*****************************************************
# remove dont_use attribute
#*****************************************************
if { $remove_tie_dont_use_switch == "true" } {
    set_attribute [get_lib_cells smic18_ss_1p62v_125c/TIE*] dont_touch false
    set_attribute [get_lib_cells smic18_ff_1p98v_0c/TIE*] dont_touch false
    
    set_attribute [get_lib_cells smic18_ss_1p62v_125c/TIE*] dont_use false
    set_attribute [get_lib_cells smic18_ff_1p98v_0c/TIE*] dont_use false
}

#*****************************************************
# clock defination and reset
#*****************************************************
current_design $TOP_MODULE

create_clock -name main_clk -period $SYS_CLK_PERIOD -waveform [list 0 [expr $SYS_CLK_PERIOD /2]] [get_ports PAD_div_clk_i]
set_dont_touch_network [all_clocks]
set_ideal_network [get_ports PAD_div_clk_i]
set_dont_touch_network [get_ports "$Rst_list"]
set_ideal_network [get_ports "$Rst_list"]

#*****************************************************
# clock constraints
#*****************************************************
#set_clock_latency    0.8     [all_clocks]
set_clock_uncertainty 0.1    [all_clocks]
#set_clock_transition  0.3    [all_clocks]

report_clocks -nosplit > ${reportsDir}/${TOP_MODULE}.clocks.txt

#*****************************************************
# drive and load, max fanout,max capacitance
#*****************************************************
set MAX_LOAD    [load_of smic18_ss_1p62v_125c/INVHD4X/A]

set_drive 0      [get_ports "$Rst_list"]
set_drive 0      [get_ports "$Clk_list"]

#set_max_capacitance [expr $MAX_LOAD*12] [get_designs *]

set_driving_cell -lib_cell INVHD2X [remove_from_collection [all_inputs] [get_ports [list PAD_div_clk_i PAD_resetn_i]]]
set_load [expr 3 * $MAX_LOAD] [all_outputs]

#set_max_fanout 10 [all_inputs]

#set_max_transition 1.0 $TOP_MODULE

#*****************************************************
# input delay and output delay
#*****************************************************
#set wb_in_ports [remove_from_collection [all_inputs]  [get_ports [list PAD_wb_clk_i PAD_wb_rst_i]]]
#set wb_out_ports [get_ports [list PAD_wb_dat_o PAD_wb_ack_o]]

#set_input_delay -max 5 -clock wb_clk $wb_in_ports
#set_input_delay -min 0.1 -clock wb_clk $wb_in_ports

#set_output_delay -max 5 -clock wb_clk $wb_out_ports
#set_output_delay -min -1 -clock wb_clk $wb_out_ports

set_input_delay [expr $SYS_CLK_PERIOD / 2] -clock main_clk [remove_from_collection [all_inputs] [get_ports [list PAD_div_clk_i PAD_resetn_i]]]
set_output_delay [expr $SYS_CLK_PERIOD / 2] -clock main_clk [all_outputs]

# false path
set_false_path -from [get_ports "$Rst_list"]
# case_analysis
set_case_analysis 0 [get_ports "$Rst_list"]
# area and power
if { $area_switch == "true" } {
    set_max_area    0
}
if { $power_switch == "true" } {
    set_max_total_power 0 uw
}

# don't touch
set_dont_touch       [get_cells U_* ]

# Map and Optimize the design
check_design

#compile
#avoid "assign"
set verilogout_no_tri true
set verilogout_equation false

set_fix_multiple_port_nets -buffer_constants -all

if {$ultra_switch == "true"} {
    set ultra_optimization true -force
    }

if {$high_switch == "true"} {
    compile -map_effort high -boundary_optimization
} else {
    compile -map_effort medium -boundary_optimization
}

# fix hold time
if {$fix_hold_switch == "true"} {
    set_fix_hold [get_clocks *]
    compile -incremental -only_hold_time
}

check_design > ${reportsDir}/${TOP_MODULE}.check_design.txt
check_timing > ${reportsDir}/${TOP_MODULE}.check_timing.txt
# Output Reports
report_design -nosplit > ${reportsDir}/${TOP_MODULE}.design.txt
report_port -nosplit > ${reportsDir}/${TOP_MODULE}.port.txt
report_net -nosplit > ${reportsDir}/${TOP_MODULE}.net.txt
report_timing_requirements -nosplit > ${reportsDir}/${TOP_MODULE}.timing_requirements.txt
report_constraint -nosplit -all_violators > ${reportsDir}/${TOP_MODULE}.constraint.txt
report_timing -nosplit > ${reportsDir}/${TOP_MODULE}.timing.txt
report_area -nosplit > ${reportsDir}/${TOP_MODULE}.area.txt
report_power -nosplit > ${reportsDir}/${TOP_MODULE}.power.txt

# Change Naming Rule
remove_unconnected_ports -blast_buses [find -hierarchy cell {*.*}]
set bus_inference_style {%s[%d]}
set bus_naming_style {%s[%d]}
set hdlout_internal_busses true
change_names -hierarchy -rule verilog
define_name_rules name_rule -allowed {a-z A-Z 0-9 _} -max_length 255 -type cell
define_name_rules name_rule -allowed {a-z A-Z 0-9 _[]} -max_length 255 -type net
define_name_rules name_rule -map {{"\\*cell\\*" "cell"}}
define_name_rules name_rule -case_insensitive -remove_internal_net_bus -equal_ports_nets
change_names -hierarchy -rules name_rule

# Output Results
write -format verilog  -hierarchy      -output ${netlistDir}/${TOP_MODULE}.vg
write -format ddc -hierarchy -output ${netlistDir}/${TOP_MODULE}.ddc
write_sdf  ${netlistDir}/${TOP_MODULE}_post_dc.sdf
write_sdc  -nosplit ${netlistDir}/${TOP_MODULE}.sdc

date

# Finish and Quit
if {$exit_switch == "true"} {
exit
}