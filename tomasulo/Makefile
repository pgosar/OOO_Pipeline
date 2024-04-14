OUT = testbench.vvp
SRCS = testbench.sv core.sv
.PHONY: clean test

${OUT}: ${SRCS}
	iverilog -g2012 -o ${OUT} ${SRCS}

test: ${OUT}
	vvp ${OUT}

clean:
	rm -f ${OUT} *.vcd