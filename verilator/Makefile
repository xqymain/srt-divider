VERILATOR = verilator
VERILATOR_FLAGS = --trace --cc --exe --Wno-fatal
SRC_DIR = ../div.srcs/sources_1/imports
SIM_DIR = ../div.srcs/sim_1/imports
TB_SRC = sim_main.cpp

all: verilate simulate

verilate:
	@echo "Verilating design..."
	$(VERILATOR) $(VERILATOR_FLAGS) divider_top.v \
                $(SRC_DIR)/div.v \
		$(SRC_DIR)/lzc.sv \
		$(SRC_DIR)/compressor_3_2.v \
		$(SRC_DIR)/r16_block.v \
		$(SRC_DIR)/radix_4_sign_coder.v \
		$(SRC_DIR)/radix_4_sign_detector.v \
		$(TB_SRC) -CFLAGS "-std=c++17"
	@echo "Building verilated design..."
	$(MAKE) -C obj_dir -f Vdivider_top.mk

simulate:
	@echo "Running simulation..."
	./obj_dir/Vdivider_top

clean:
	rm -rf obj_dir
	rm -f *.vcd
	rm -f *.log

.PHONY: all verilate simulate clean
