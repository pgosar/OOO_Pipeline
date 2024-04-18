/**************************************************************************
 * STUDENTS: DO NOT MODIFY.
 * 
 * C S 429 system emulator
 * 
 * elf_loader.c - Module for loading an ELF executable into emulated memory.
 * 
 * Copyright (c) 2022, 2023.
 * Authors: S. Chatterjee, Z. Leeper.
 * All rights reserved.
 * May not be used, modified, or copied without permission.
 **************************************************************************/ 

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <assert.h>
#include <fcntl.h>
#include <string.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include "elf.h"

#define PAGESIZE 4096
#define BASE_PAGE 1024
#define NUM_PAGES 4
#define IMEM 0
#define RODATA 1
#define RAM 2
#define RAM2 3

uint64_t loadElf(const char *fileName) {
    //puts("Loading elf.\n");
    // Open the file.
    int fd = open(fileName, O_RDONLY);
    if (fd < 0) {
        perror(fileName);
        exit(-1);
    }
    
    // Get file stats.
    struct stat statBuffer;
    int rc = fstat(fd, &statBuffer);
    if (rc != 0) {
        perror("stat");
        exit(-1);
    }
    
    // Mmap the file for quick access.
    uintptr_t ptr = (uintptr_t) mmap(0, statBuffer.st_size, PROT_READ, MAP_PRIVATE, fd, 0);
    if ((void *)ptr == MAP_FAILED) {
        perror("mmap");
        exit(-1);
    }
    

    // Get ELF header information.
    Elf64_Ehdr *header = (Elf64_Ehdr *) ptr;
    assert(header->e_type == ET_EXEC); // Check that it's an executable.
    assert(header->e_ident[4] == ELFCLASS64); // Check that our objects are 64 bit.
    uint64_t entry = header->e_entry; // Entry point of ELF executable.
    uint64_t entry_size = header->e_phentsize;
    uint64_t entry_count = header->e_phnum;
    
    // Stores the data memory.
    char mem[NUM_PAGES][PAGESIZE];
    // Let's initialize this to 0.
    memset(mem, 0, PAGESIZE * NUM_PAGES);
    
    // Get ELF program header and load segments.
    Elf64_Phdr *progHeader = (Elf64_Phdr *)(ptr + header->e_phoff);
    for (unsigned i = 0; i < entry_count; i++) {
        if (progHeader->p_type == PT_LOAD) {
            uint8_t *dataPtr = (uint8_t *)(ptr + progHeader->p_offset);
            uint64_t vaddr = progHeader->p_vaddr;
            //printf("section %d: vaddr %llu\n", i, vaddr);
            uint64_t filesz = progHeader->p_filesz;
            uint64_t memsz = progHeader->p_memsz;

            unsigned long v_align = (vaddr % PAGESIZE);
            unsigned long f_align = filesz + (PAGESIZE - ((filesz + vaddr) % PAGESIZE));

            int read = !!(progHeader->p_flags & 0x4);
            int write = !!(progHeader->p_flags & 0x2);
            int exec = !!(progHeader->p_flags & 0x1);
            int ro = read && exec && !write;
            int rw = read && write;
            char *type = ro ? "ro" : (rw ? "rw" : "unknown");
            //printf("base addr of %s load segment: %llu\n", type, vaddr);
            //printf("size: %llu\n", memsz);
            

            // notes: sections that are relevant - 
            /* data, bss, rodata, text.
             * group bss and data together, and rodata and text together.
             * one page for each.
             * */
            // Map data from the file for this segment
            for (uint64_t j = 0; j < filesz + v_align; j++) {
                // grab base address of load section.
                uint64_t addr = vaddr + j;
                uint8_t byte = dataPtr[j];
                uint64_t pnum = addr / PAGESIZE;
                uint64_t poff = addr % PAGESIZE;
                // Heuristic: We have read/write and read/only memory. BSS and Data are 
                // in read write, while text and rodata are in read only.
                mem[pnum][poff] = byte;
            }
            // BSS implicitly complete since we did memset.
        }
        progHeader = (Elf64_Phdr *) (((uintptr_t) progHeader) + entry_size);
    }

    // Read section header to fill in machine memory segments
    Elf64_Shdr *sectionHeader = (Elf64_Shdr *)(ptr + header->e_shoff);
    entry_size = header->e_shentsize;
    entry_count = header->e_shnum;
    Elf64_Shdr *sectionStrings = (Elf64_Shdr *)((char *)sectionHeader + (header->e_shstrndx*entry_size));
    char *strings = (char *)ptr + sectionStrings->sh_offset;

    // TODO: calculate the r/w and r/o offsets and output to a file.
    // ideally this is the min of either address (bss/data, rodata/text)
    // also ideally if we take the min then they will be contiguous and easy to locate.
    for (unsigned i = 0; i < entry_count; i++) {
        char *name = strings + sectionHeader->sh_name;
        if (!strcmp(name, ".text")) {
            //guest.mem->seg_start_addr[TEXT_SEG] = sectionHeader->sh_addr;
          //printf("start TEXT/RODATA: byte address %llu\n", sectionHeader->sh_addr);
        }
        if (!strcmp(name, ".data")) {
            //guest.mem->seg_start_addr[DATA_SEG] = sectionHeader->sh_addr;
          //printf("start DATA/BSS: byte address %llu\n", sectionHeader->sh_addr);
        }
        // print
        sectionHeader = (Elf64_Shdr *) (((uintptr_t) sectionHeader) + entry_size);
    }
    // output
    char fname[] = "IMEM_t.txt";
    FILE *fout = fopen(fname, "w");
    if (fout == NULL) {
      printf("Error opening file.\n");
      return -1;
    }
    // TODO endianness
    for (int i = 0; i < PAGESIZE; ++i) {
      fprintf(fout, "%c", *((char *) mem + i));
    }
    fclose(fout);
    char fname2[] = "DMEM_t.txt";
    FILE *f2out = fopen(fname2, "w");
    if (f2out == NULL) {
      printf("Error opening file.\n");
      return -1;
    }
    for (int i = 0; i < NUM_PAGES * PAGESIZE; ++i) {
      fprintf(f2out, "%c", *((char *) mem + i));
    }
    fclose(f2out);
    return entry;
}

int main(int argc, char *argv[]) {
  if (argc < 2) {
    printf("Usage: load_elf <filename>\n");
    return 1;
  }
  char fname[255];
  strlcpy(fname, argv[1], 255);
  uint64_t entry;
  if ((entry = loadElf(fname)) == -1) {
    puts("ERROR: could not open file\n");
    return 1;
  }
  printf("ENTRY: %llu\n", entry);
  
}
