.PHONY: clean test

SV_FILES = $(wildcard *.sv)

MODULE = core

verilator-debug:
	verilator --binary --build --trace --timing -j 0 -DDEBUG_PRINT ${SV_FILES} --top-module ${MODULE} -o ${MODULE}_tb

verilator:
	verilator --binary --build --timing -j 0 ${SV_FILES} --top-module ${MODULE} -o ${MODULE}_tb

clean:
	rm -rf testbench.vvp *.vcd *.vvp db/ incremental_db/ simulation/ obj_dir/ *.rpt *.done *.smsg *.summary *.jdi *.pin *.qpf *.sld *.sof *.qsf *.txt


quartus:
	quartus_sh --flow compile ${MODULE}
	quartus_eda ${MODULE} --simulation --tool=modelsim --format=verilog
