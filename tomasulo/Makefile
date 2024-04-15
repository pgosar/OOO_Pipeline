OUT = testbench.vvp
SRCS = core.sv decode.sv reservation_stations.sv
.PHONY: clean test

MODULE = ArithmeticExecuteUnit

${OUT}: ${SRCS}
	iverilog -g2012 -o ${OUT} ${SRCS}

test: ${OUT}
	vvp ${OUT}

clean:
	rm -rf ${OUT} *.vcd *.vvp db/ incremental_db/ simulation/ obj_dir/ *.rpt *.done *.smsg *.summary *.jdi *.pin *.qpf *.sld *.sof *.qsf *.txt

verilator:
	verilator --binary --build --timing -j 0 --top-module ${MODULE}_tb -o ${MODULE}_tb testbench.sv && ./obj_dir/${MODULE}_tb

quartus:
	quartus_sh --flow compile ${MODULE}
	quartus_eda ${MODULE} --simulation --tool=modelsim --format=verilog
