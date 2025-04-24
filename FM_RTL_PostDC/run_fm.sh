#!/bin/sh
mkdir -p logs
fm_shell -f div_ASIC.tcl 	| tee -i logs/div_ASIC.log