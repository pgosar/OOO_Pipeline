# What's Left For The Core?

## Completeness & Correctness
The following tasks must be completed for this processor to be considered usable.
- [ ] Update the pipeline to use 3 inputs and 2 destinations. So many instructions (STUR, ADD, SUB...) have a third input. Several have a second destination (LDUR with increments, BL) remove the silly add which is in the reservation stations.
- [ ] Implement shifts for register to register instructions.
- [ ] Check on MOVK, I am confident it is broken. I am confident it will require its own FU operation.
- [ ] Integrate UBFM.
- [ ] Integrate SBFM.
- [ ] LDP / STP.
- [ ] Remove all non-sythesizable delays from the code.
- [ ] Convert casez to case ... inside.
- [ ] Separate the testbench from core.
- [ ] Remove all non-synthesizable code.
- [ ] Add a stack pointer

## Usefulness
The following will allow this system to have actual use:
- [x] (Nate) Create a todo list.
- [ ] Include a basic branch predictor.
- [ ] Create a visualizer for the state of the processor.
- [ ] Synthesize. [Here's a good document](https://www.lcdm-eng.com/papers/snug13_SNUG-SV-2013_Synthesizable-SystemVerilog_paper.pdf) on what is synthesizable.
- [ ] Allow for out of order STURS.
- [ ] Make modules trvially swappable, so that one can experiment with different systems.
- [ ] Implement configurable delay on functional units & fetch