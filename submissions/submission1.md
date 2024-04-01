Testcases

Our intention was to test several instructions chArm-v3. Naturally, these test cases will have dependencies and hazards which must be resolved using Tomasulo.

Two testcases are attached to this post, as well as a C file which will allow you to run the testcases with some example inputs:
File
testcases.s
File
run_arm.c

1.
binary search(int arr[], int size, int target);

Given an sorted array of size integers, binary search will return the target if target is present in the array. Otherwise it will return -1.

Ops Used:

    MOVZ

    SUB

    CMP

    B.cond

    ASR

    ADD

    LDUR

    ANDS

    B

    RET

2.
bool is_same_tree(node* tree1, node* tree2); 

Given two binary trees, this function will return true if the binary trees contain the same nodes, and false otherwise.

The node struct looks like so:
typedef struct node {
    struct node* left;
    struct node* right;
    int64_t value;
} node;

Ops used:

    STP

    STUR

    B.cond

    MOVZ

    ADD

    ORR

    CBZ

    LDUR

    CMP

    BL

    CBZ

    CBNZ

    LDP

    RET

This submission is for all the members of my group:

    Nathan Williams

    Dylan Dang

    Joshua Wong

    Kavya Rathod

    Pranay Gosar

    Namish Kukreja

Extra Credit: An LLVM Backend

Our group created an LLVM backend for chArm-v3. It is fully functional, but not very feature rich. To compile and run the full product, a user must perform the following steps:

    Clone llvm at commit 342f7d0d35774ffdcb56e8b92252763a59bd2c29

    Download the patch file and place it in th root of the llvm-project directory

    patch the llvm install. patch -p1 -N <final.out.

    Compile llvm cd llvm && mkdir build && cd build && cmake .. -DCMAKE_BUILD_TYPE=Release && make

    Use clang (built in) to compile C code into LLVM's IR (intermediate representation). (clang -S -emit-llvm foo.c) will produce foo.ll, which will be used shortly.

    Use the compiled program,bin/llc, to assemble .llc files. .llc files are files that define instructions using without specifying hardware by using LLVM's intermediate representation. The command we have been using looks like so: bin/llc -view-isel-dags --show-mc-encoding -debug --simplify-mir --aarch64-enable-global-isel-at-O=-1 --print-after-isel --fast-isel=0 -O0 -march=aarch64 -mcpu=generic -mattr=-neon,-fp-armv8,-ete < foo.ll

File
final.patch

The information below is not to b graded, but the information may be useful to others.
Extra Credit: The Testbench

For extra credit, we created a testbench in Verilog, as well as th interface to our core. We have attached the verilog sections of our test bench. Our design is as follows:

The core of the CPU emulates how a real core would. As a result, upon sending a reset signal, the core travels to a known memory location. At this location, there will be a short program in ROM, which will wait for input from the user. We refer to this program as the boot program, and its purpose is to prevent the core from executing garbage code while it is waiting for the HPS to load the testcase into its memory.

From here, the HPS will load the arm instructions for the testcase into a known memory location of the processor. This is done using a custom elf parser. The known memory address is typically set up so that is at a know position in the core's virtual memory (typically at 0x0 in virtual memory).

Upon this completing, the HPS will then send the start signal to the core. This function of this signal is equivalent to forcing the core to perform BL 0x0 - the program counter of the core will be set to 0x0, and the link register will be set to the next instruction of the previous program counter (recall that the previous program counter is in this boot program).

The core can then run all of the code of the testcase. Furthermore, the testing code in verilog will print out the contents of the registers, re-order buffers, and reservation stations on every cycle. It should be noted that this cannot be run using iverilog since it does not support pretty printing.

There is a sizeable C backend to support the arbitrary loading of testcases while the core is running.
File
testbench.sv
File
DE10_Nano_golden_top.v


