CC=clang
CFLAGS = -c --target=aarch64-unknown-linux-gnu

LD = ld.lld
LSCRIPT = ooo.ld

# assumes compiled load_elf
mem: mem.sv
	@iverilog -o mem.out -g2012 $<

%.mem : %.s
	$(eval FNAME := $(basename $<))
	@$(CC) load_elf.c -o load_elf
	@$(CC) $(CFLAGS) -o $(FNAME).o $<
	@$(LD) $(LSCRIPT) $(FNAME).o -o $(FNAME)_linked.o
	@./load_elf $(FNAME)_linked.o
	@xxd -b -c1 IMEM_t.txt | awk '{ print $$2 }' > imem.txt
	@xxd -b -c1 DMEM_t.txt | awk '{ print $$2 }' > dmem.txt
	@rm $(FNAME)_linked.o $(FNAME).o IMEM_t.txt DMEM_t.txt
	@echo Output is in imem.txt and dmem.txt.
	
clean: 
	@rm imem.txt dmem.txt load_elf mem.out entry.txt
.PHONY: % clean
