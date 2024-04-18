# The Out Of Order Processor
This document describes some of the needs of the project

## Development Setup

### Our FPGA
We are developing for a DE10-Nano FPGA. Version 10-01610104-C0. The version number can be found on the back of the board, and indicates that this board is a revision C board. All documentation can be found on [Terasic's (the FPGA manufacturer) website](https://www.terasic.com.tw/cgi-bin/page/archive.pl?Language=English&CategoryNo=205&No=1046&PartNo=4#contents).

### Our IDE
iVerilog was great for learning, but as we will need to synthesize the SystemVerilog on actual hardware, we will need a more capable compiler and synthesizer. Terasic provides tools for Quartus Prime - an IDE for hardware development made by Intel. These tools allow us to interface with the actual hardware. Since the tools are made for Quartus Prime 17.0, e will be using [Quartus Prime Lite Version 17.0](https://www.intel.com/content/www/us/en/software-kit/669553/intel-quartus-prime-lite-edition-design-software-version-17-0-for-linux.html) for development. Quartus Prime Lite is the version which is free to use.

In the installer, we will need the following:
- Quartus Prime itself for synthesis.
- ModelSim for simulating the circuits.
- Cyclone V support for our particular style of FPGA
*NOTE for Linux Users: The installer may hang if you try to install ModelSim or the Help docs in one go. You can work around this by running the ModelSim and Help installers separately. They are available in the `componnts` dir*

Finally, we will need the [DevKit provided by Terasic for the DE10-Nano](https://www.intel.com/content/www/us/en/design-example/714622/cyclone-v-fpga-terasic-de10-nano-development-kit-baseline-pinout.html). The 17.0 version is the latest at the time of writing and it is preferred. This is **NECESSARY** as it can prevent damage to the board due to incorrect voltage settings or pin assignment.

To upload to the FPGA over JTAG, you need write access to a serial port. Otherwise you get "no hardware detected". [Workaround on arch linux here](https://wiki.archlinux.org/title/Intel_Quartus_Prime#USB-Blaster_not_working)

## GCC Patching

Seems like for starters, modifying this file should get us a lot of the way there, to make sure only certain instructions are defined. Then it may require removing code that uses these instructions
gcc/config/aarch64/aarch64.md

Some helpful links:

https://kristerw.blogspot.com/2017/08/writing-gcc-backend_4.html

http://atgreen.github.io/ggx/

## Testcases
Fundamentally, a test requires you to predict the correct result, and then compare the correct result to the acquired result.

We need to test for both correctness of our program result, and for the correct implementation of Tomasulo. Both of these can be incorrect independently.

### Basic Functionality Tests
The easiest way to test for correctness is to run a testcase twice. Once on an actual ARM machine, and the other inside of our emulator. We then only need to check th results.

The easiest way to check for Tomasulo would be to compare the cycle count with no Tomasulo implemented with the cycle count with Tomasulo implemented. If there are hazards in the assembly, Tomasulo should always result in some speedup. If there is no speedup, then our tomosulo is not working.

### Useful Unit Tests
Unit tests for Tomasulo would provide useful information about its functionality. Ideally, we should create unique tests for each hazard to ensure that it actually works. We can begin with 4 unique test cases for each type of hazard (RAR, RAW, WAR, and WAW).

Given that we have a 5 stage pipeline and 41 possible instructions (each with roughly 3 possible operand orderings), we have (41^3)^5 possible orderings. 

### The Gold Standard
The gold standard would be to have a perfect simulation. This means we should have knowledge of each register's expected state during each cycle (both GPRs and hardware registers). We can then compare the state of the registers at each cycle with the state that our simluator produces.

Calculating these expected states may need to be done by hand (ie. on paper, in excel, or in a simulator written by us in a higher level language). I do not believe that we will be able to use any existing simulators, since our specific processor which is running ARM will be so hyper-specific (a 5-stage processor with OOO).

It would be useful to do this for at least one or two fairly complex test cases.

## The Testbench
**2024-03-29 (Nate):** Me and Kavya decided that the best way to implement a testbench is by using the HPS on the board itself. We can connect to it with the following command: `screen /dev/tty 115200`, **BUT** you must replace `/dev/tty` with the name of the connected tty device. In my case this is `/dev/ttyACM0`. This will be different in every case you can find the latest USB connected using either the `lsusb` command or the `dmesg | grep 'tty'` command.
Furthermore, loads and stores in our assembly assembly language are relying on virtual memory. While in a real computer, the MMU (memory management unit) chip would be partially responsible for doing virtual to physical address translations, an MMU is beyond the scope (and use) of the core, and therefore virtual address mapping will be handled by 'page tables' in C.

From here, we have access to a Linux environment which also has direct access to the FPGA ports. Our intention is to create a program which loads in ELF files, extracts the binary instructions from them, and sends them to the FPGA. It then waits for a response back from the FPGA and will print out the results.

The testbench should ideally provide the following useful information every cycle to be able to debug Tomasulo and correctness:
- GPR contents
- Hardware register contents
- Information about renamings such as:
  * The specific hazard which caused the rename
  * The register name before and after the rename

### The Vision
We have some questions:
- How do we do output.
  * Lowkey don't have to worry about it now, since we test using Verilator
  * The idea is either to use LEDs or output using GPIO pins
- MMIO, what's that about? 
- How to load memory onto it?
  * How to access said memory
  * Where are the bounds of the memory
- How to load an elf binary
  * do we even need headers if we're using very simple ch-ARM files?
- What debug information do we need?
  * reginfo (including PC)
  * reservation stations
  * reorder buffer
  * instr at each stage of pipeline
- *Once we can start loading things from some PC address, things become a little more trivial.*

## Glossary
- [**EPCS**](https://community.intel.com/t5/FPGA-Wiki/EPCS-Guide/ta-p/735919): Flash memory which can be used to configure the FPGA. This is not the only device which can configure the FPGA, however, We typically want our board to use this, rather than HPS configuration. To use this mode, it must be selected using the MSEL switches on the board (MSEL[4:0] = 5'b10010). SRAM hardware images are typically uploaded to the EPCS device via Quartus or the command line. (manual p.12)
- **FPGA**: The field programmable gate array. A fabric which allows you to prototype and synthesize logic gates and circuits without burning them onto hardware. (manual p.13)
- **HPS**: Hard Processor System. A traditional computer system (using a processor, RAM, cache, etc.) which exists on the same board as the FPGA and is highly integrated with it. They share an interconnect and many signals. However, many components on the board belong exclusively to either the FPGA or HPS. [Cornell's guide on the Cyclone-V HPS](https://people.ece.cornell.edu/land/courses/ece5760/DE1_SOC/HPS_INTRO_54001.pdf)
- **JTAG**: Doesn't stand for anything. A standard for testing circuit designs. It allows you to connect debug pins to your circuit and view output information. It can also be used to directly program the FPGA chip. However, the data is volatile. Upload an image to the EPCS flash device for longer lasting storage.
- **Switch Debouncing**: There is quite a bit of noise in analog circuitry. To smooth the data signal and prevent 'bouncing' of a signal between 1 and 0, an algorithm like the [Schmitt Trigger](https://en.wikipedia.org/wiki/Schmitt_trigger) is applied.

### ELF loader
 - A Makefile is provided for convenience. To create and load an assembly file call:
   * ```make <asm_file_path>.mem```
     * this creates an executable, maps memory into two files ```imem.txt``` and ```dmem.txt```, and places them in the root dir.
     * then, call ```make mem``` to make the memory testbench. ```./mem.out``` will then output the test output.
     * TODO: this needs to be changed to verilator at some point 
   * there is a ```make clean``` target provided to clean up the files.
 - All the secrets are in ```ooo.ld```. This linker script maps the elf to our address space.
 - imem simply contains the instruction memory (1 page, pagesize = 4096B) while dmem contains 4 pages (1 page imem, 1 page rodata, 2 pages ram)
    * [FIXED] note: upon writing this readme, I realized it might be written to support only 3 pages. This is an easy fix, just fixing the address widths and RAM size
    * the dmem includes the instruction memory simply for convenient addressing (no need to offset mem accesses)
