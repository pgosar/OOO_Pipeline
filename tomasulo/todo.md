
TODO(Namish): To complete branching:
- Mispreds flushing the pipelines should be up and running
- Branch conditions should be supported (if we can already propogate
conditions this is trivial)
- Add a HLT instruction to stop pipeline execution
- Fix the fetch being delayed
- Fix RETs

TODO(Kavya); Fix signed vs unsigned immediate values
    - 

checkout broken.s

fix load store
stp, ldp

So....
An address in the load/store RS can be resolved like any
other RS. However, when it comes time to execute the actual
load/store instruction, we must look through the ROB for all
entries where (1) the destination is a special ROB_WRITEBACK
destination, (2) the rob entry stores both the address which
was written to and the value to be written.

ALSO, a ldur can only complete if there are no pending sturs
before it in the pipeline. It is otherwise unknown whether the address
will be written to or not. Dependencies canonly be detected
afterthe address is known.

We keep track of these sturs with a counter, and when that
counter hits 0, we know there are no pending sturs. The counter
is added to when a stur is added to the ROB and is decremented
when a ROB receives a broadcast that a stur has completed.
ehem,

NOTE(Pranay): For stur counter,loads must also be checked

NOTE(Pranay): I believe for the broken bits of broken.s such as
instr x5, .., ..
instr x5, x5, ..
this is both a read after write and write after write, this must be
stalled?
