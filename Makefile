TESTBENCH = testbench.sv
VC-UTCS = /u/nklayman/public/iverilog/bin/iverilog
VVP-UTCS = /u/nklayman/public/iverilog/bin/vvp
VC-LOCAL = iverilog
VVP-LOCAL = vvp
EXEC = proc
FLAGS = -g2012 

proc: ${TESTBENCH} ${SRC}
	${VC-LOCAL} -o ${EXEC} ${FLAGS} ${TESTBENCH} ${SRC}

test: ${TEST_BENCH} ${SRC}
	${VC-LOCAL} -o ${EXEC} ${FLAGS} ${TESTBENCH} ${SRC} && ${VVP-LOCAL} ${EXEC}

utcs-proc: ${TEST_BENCH} ${SRC}
	${VC-UTCS} -o ${EXEC} ${FLAGS} ${TESTBENCH} ${SRC} 

utcs-test: ${TEST_BENCH} ${SRC}
	${VC-UTCS} -o ${EXEC} ${FLAGS} ${TESTBENCH} ${SRC} && ${VVP-UTCS} ${EXEC}

clean:
	rm ${EXEC}