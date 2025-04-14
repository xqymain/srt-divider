date
set TOP_MODULE div
set	search_path	"$search_path  $topDir "

set 	synopsys_auto_setup 	true
set_svf ${svfDir}/${TOP_MODULE}.svf

#set hdlin_interface_only "vs_*"

read_db "lib/SMIC18_Ver2.7/FEView_STDIO/STD/Synopsys/smic18_tt_1p8v_25c.db lib/SMIC18_Ver2.7/FEView_STDIO/IO/Synopsys/smic18io_line_tt_1p8v_3p3v_25c.db"

read_verilog  -r [sh ls $topDir/*.v]
read_sverilog -r [sh ls $topDir/*.sv]
set_top ${TOP_MODULE}


#read_db -i lib/user_ram/vs_dp_16x64/vs_dp_16x64_worst.db

#read_ddc -i ${TOP_MODULE}.ddc
read_verilog -i ${TOP_MODULE}.vg
set_top ${TOP_MODULE}


match
if [ verify ] {
	date
	exit
} else {
  	diagnose
        report_unmatched
        report_failing
        report_error_candidates
}

date