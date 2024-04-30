// `include "func_units.sv"
`include "data_structures.sv"

// NOTE(Namish): Various conditions to think about
// fix instruction alias?
// predict new PC?
// status updates?
// select PC logic: we have correction from ret, and
// correction from cond.
// can use 0 PC to indicate ret?
// pseudocode:
// if bcond and !condval - we take successor
// if ret - we take val_a
// else take predicted pc
//
// for predicted pc:
// if it's bl or bcond or b: predict taken
// else: sequential successor
// adrp????

module fetch #(
    parameter int PAGESIZE = 4096
)  // note: this should always be 4096
(
    input wire in_clk,
    input wire in_rst,
    input fetch_interface out_d_sigs
);


  // steps:
  // 1. select PC (?) assuming no mispredictions for now
  // 2. access IMEM with correct PC
  // 3. potentially fix instruction aliases?
  // 4. predict new PC
  // 5. any status updates needed

  // select PC: no-op as of now

  // access IMEM
  logic [31:0] data;
  // PC is an internal register to fetch.
  logic [63:0] entry_addr[0:0];  // entry point. [0:0] to make verilog see it as a memory
  logic [63:0] PC;
  logic rst;
  logic no_instruction;

  // Load entry point from text file
  initial begin
    $readmemb("mem/entry.txt", entry_addr);
  end

  imem #(PAGESIZE) mem (
      .in_addr(PC),
      .out_data(out_d_sigs.insnbits)
  );

  always_comb begin
    no_instruction = out_d_sigs.insnbits == 0;
    out_d_sigs.done = ~rst & ~no_instruction;
  end

  always_ff @(posedge in_clk) begin : fetch_logic
    rst <= in_rst;
    if (in_rst) begin
      `DEBUG(("(fetch) resetting PC: %16x -> %16x", PC, entry_addr[0]));
      PC <= entry_addr[0];
    end else begin
      if (rst) begin
        `DEBUG(("(fetch) Last cycle was reset. PC remains %16x", PC));
      end else if (no_instruction) begin
        `DEBUG(("(fetch) No instruction. PC halted at: %16x", PC));
      end else begin
        `DEBUG(("(fetch) PC: %16x -> %16x", PC, PC + 4));
        PC <= PC + 4;
      end
    end
  end : fetch_logic

endmodule : fetch


// Note: the imem is combinational to make accessing memory super easy.
//
module imem #(
    parameter int PAGESIZE = 4096
) (
  input  logic  [63:0] in_addr,
  output logic [31:0] out_data
);
  // read-only instruction memory module.
  localparam bits_amt = PAGESIZE;
  localparam fname = "mem/imem.txt";
  logic [7:0] mem[bits_amt];
  logic [$clog2(PAGESIZE) - 1:0] addr;

  // Load initial contents of memory into array
  initial begin
    $readmemb(fname, mem);
  end 

  always_comb begin : mem_access
    addr = in_addr[$clog2(PAGESIZE)-1:0];
    out_data = {mem[addr+3], mem[addr+2], mem[addr+1], mem[addr]};
  end : mem_access

endmodule