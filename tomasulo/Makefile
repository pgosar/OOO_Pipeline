.PHONY: clean test

SV_FILES = $(wildcard *.sv)

MODULE = core

CC=clang
CFLAGS = -c --target=aarch64-unknown-linux-gnu

LD = ld.lld
LSCRIPT = mem/ooo.ld

%.mem : %.s
	$(eval FNAME := $(basename $<))
	@$(CC) mem/load_elf.c -o mem/load_elf
	@$(CC) $(CFLAGS) -o $(FNAME).o $<
	@$(LD) $(LSCRIPT) $(FNAME).o -o $(FNAME)_linked.o
	@mem/load_elf $(FNAME)_linked.o
	@xxd -b -c1 IMEM_t.txt | awk '{ print $$2 }' > mem/imem.txt
	@xxd -b -c1 DMEM_t.txt | awk '{ print $$2 }' > mem/dmem.txt
	@mv entry.txt mem/entry.txt
	@rm $(FNAME)_linked.o $(FNAME).o IMEM_t.txt DMEM_t.txt
	@echo Output is in mem/imem.txt and mem/dmem.txt.

%.dis : %.s
	$(eval FNAME := $(basename $<))
	$(CC) $(CFLAGS) -o $(FNAME).o $<
	$(LD) $(LSCRIPT) $(FNAME).o -o $(FNAME)_linked.o
	objdump $(FNAME).o --disassemble
	rm $(FNAME).o $(FNAME)_linked.o

# Note: there is a better solution than just suppressing duplicate definition warnings, 
# but this is the best one for now. (-Wno-MODDUP)
verilator-debug:
	verilator --binary --build --cc --trace --trace-structs --timing -j 0 -DDEBUG_PRINT ${SV_FILES} --top-module ${MODULE} -o ${MODULE}_tb

verilator:
	verilator --binary --build --timing -j 0 ${SV_FILES} --top-module ${MODULE} -o ${MODULE}_tb

clean:
	rm -rf testbench.vvp *.vcd *.vvp db/ incremental_db/ simulation/ obj_dir/ *.rpt *.done *.smsg *.summary *.jdi *.pin *.qpf *.sld *.sof *.qsf *.txt
	rm mem/imem.txt mem/dmem.txt mem/load_elf mem/entry.txt

quartus:
	quartus_sh --flow compile ${MODULE}
	quartus_eda ${MODULE} --simulation --tool=modelsim --format=verilog
