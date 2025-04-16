#!/bin/bash
if [ -e work ]
then
    \rm -rf work
fi

#verdi env setting
export PLATFORM=LINUX
export LD_LIBRARY_PATH=$VERDI_INST_DIR/share/PLI/lib/$PLATFORM:$LD_LIBRARY_PATH

vlib work
vmap work work
vlog +acc +nowarnBSOB +nowarnRDGN -f ./vlog.args
vsim -voptargs=+acc -suppress 12088 +nospecify +sdf_verbose -pli $VERDI_INST_DIR/share/PLI/MODELSIM/$PLATFORM/novas_fli.so  work.tb_div -c -do sim.do