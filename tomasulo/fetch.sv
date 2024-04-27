`include "func_units.sv" 
module fetch # (parameter int PAGESIZE = 4096) // note: this should always be 4096
  (
   input wire clk,
   output logic [31:0] insnbits
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
  logic [63:0] PC_load [0:0]; // to make verilog see it as a memory
  logic [63:0] PC;

  initial begin: init_PC
    $readmemb("entry.txt", PC_load);
    PC = PC_load[0];
  end: init_PC

  imem #(PAGESIZE) mem(PC, data);

  always_ff @(posedge clk) begin: fetch_logic
    // fix instruction alias?
    // predict new PC?
    // status updates?
    insnbits <= data;
    PC <= PC + 4;
  end: fetch_logic
endmodule: fetch
