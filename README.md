# The Out Of Order Processor
This document describes some of the needs of the project

## Development Setup
Before we were working with iverilog. However, we are now trying to synthesize the Verilog on an actual FPGA. We need to use dedicated software for this. We are going to use Intel Quartus Prime Lite, as this is what was recommended to interface with the DE10-Nano. Described in the "My First FPGA" article on the [FPGA page](https://www.terasic.com.tw/cgi-bin/page/archive.pl?Language=English&CategoryNo=205&No=1046&PartNo=4#contents). You need to install with Cyclone V support. 

## GCC Patching

Seems like for starters, modifying this file should get us a lot of the way there, to make sure only certain instructions are defined. Then it may require removing code that uses these instructions
gcc/config/aarch64/aarch64.md

Some helpful links:

https://kristerw.blogspot.com/2017/08/writing-gcc-backend_4.html

http://atgreen.github.io/ggx/

## Testcases
Fundamentally, a test requires you to predict the correct result, and then compare the correct result to the acquired result.

We need to test for both correctness of our program result, and for the correct implementation of Tomosulo. Both of these can be incorrect independently.

### Basic Functionality Tests
The easiest way to test for correctness is to run a testcase twice. Once on an actual ARM machine, and the other inside of our emulator. We then only need to check th results.

The easiest way to check for Tomosulo would be to compare the cycle count with no Tomosulo implemented with the cycle count with Tomosulo implemented. If there are hazards in the assembly, Tomosulo should always result in some speedup. If there is no speedup, then our tomosulo is not working.

### Useful Unit Tests
Unit tests for Tomosulo would provide useful information about its functionality. Ideally, we should create unique tests for each hazard to ensure that it actually works. We can begin with 4 unique test cases for each type of hazard (RAR, RAW, WAR, and WAW).

Given that we have a 5 stage pipeline and 41 possible instructions (each with roughly 3 possible operand orderings), we have (41^3)^5 possible orderings. 

### The Gold Standard
The gold standard would be to have a perfect simulation. This means we should have knowledge of each register's expected state during each cycle (both GPRs and hardware registers). We can then compare the state of the registers at each cycle with the state that our simluator produces.

Calculating these expected states may need to be done by hand (ie. on paper, in excel, or in a simulator written by us in a higher level language). I do not believe that we will be able to use any existing simulators, since our specific processor which is running ARM will be so hyper-specific (a 5-stage processor with OOO).

It would be useful to do this for at least one or two fairly complex test cases.

## The Testbench
The testbench should ideally provide the following useful information every cycle to be able to debug Tomosulo and correctness:
- GPR contents
- Hardware register contents
- Information about renamings such as:
  * The specific hazard which caused the rename
  * The register name before and after the rename
