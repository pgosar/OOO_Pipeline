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
	rm -f ooo_testcases
	rm -f run_arm.o


all: clean build

build:
	gcc run_arm.c -c -o  run_arm.o -lm
	gcc testcases.s run_arm.o -o ooo_testcases -g -lm

verify:
	python3 verify.py

# this target is used to generate .o files. Will not be used in the production version.
dev: clean
	gcc -g run_arm.c -c -o run_arm.o -g
	gcc testcases.s run_arm.o -o ooo_testcases -g -lm