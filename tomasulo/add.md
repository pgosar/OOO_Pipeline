# Steps for instructions:

## ADD X1, X1,0xfff

1. - Fetch the instruction
2. - Decode the instruction
   - Dispatch the instruction to regfile
   - Regfile will forward all values to re-order buffer. Any values not available will be retrieved from ROB. A new entry will be written to the ROB.
   - ROB will forward all values to reservation station.
3. - FU will pick up value from reservation station, calculate value, and send to ROB.
4. - On posedge of next cycle, ROB will pick up value from FU and buffer it. Broadcast it to reservation stations on negedge. (must wait )
   - FU will send calculated value to ROB.
   - ROB will broadcast value to all reservation stations. All entries in reservation stations with this gpr_index will pick up a new value.
   - ROB will commit to regfile

### What reads and writes to the ROB

- rob READS output from functional unit & MODIFIES the corresponding line
- rob READS from regfile to insert new entry for destination ROB & MODIFIES new line of code.
- rob READS from regfile to retrieve source1 and source2. These are used to read from the internal state and WRITE to rs.
- rob WRITES to rs (buffers an instruction after receiving signals from regfile)
- rob WRITES values of every rs after the fu is done
- rob WRITES values to regfile

So... reads happen at the start of the cycle and writes are combinational. Modifications will occur first, then typical reads. This means that reads must be buffered with a # delay.
