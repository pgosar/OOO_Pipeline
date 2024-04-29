ENTRY(start)

PHDRS
{
  headers PT_PHDR PHDRS ;
  text PT_LOAD FILEHDR PHDRS;
  data PT_LOAD ;
}

/* By specifiying a set of memory directives,
 * we force ld to use only this memory space.
 * It is guaranteed that the sections specified
 * will be placed in the desired memory sections.
 * Unspecified sections will be placed according
 * to permission heuristics. 
 */
MEMORY 
{
  insn (rx) : ORIGIN = 0x0000 + SIZEOF_HEADERS, LENGTH = 4K
  rom (r) : ORIGIN = 0x1000 + SIZEOF_HEADERS, LENGTH = 4K
  ram (rw) : ORIGIN = 0x2000 + SIZEOF_HEADERS, LENGTH = 8K
}
SECTIONS
{
  .text : { *(.text) } > insn : text
  .rodata : { *(.rodata) } > rom
  .data : { *(.data) } > ram : data
  .bss : { *(.bss) } > ram
}
