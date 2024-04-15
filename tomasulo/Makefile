OUT = testbench.vvp
SRCS = core.sv decode.sv reservation_stations.sv
.PHONY: clean test

${OUT}: ${SRCS}
	iverilog -g2012 -o ${OUT} ${SRCS}

test: ${OUT}
	vvp ${OUT}

clean:
	rm -f ${OUT} *.vcd