`include "func_units.sv"
`include "data_structures.sv"
`include "decode.sv"  // TODO a cleaner solution is separating useful
                      // modules out into their own files. This will do for now

module fetch #(
    parameter int PAGESIZE = 4096
)  // note: this should always be 4096
(
    input wire in_clk,
    input wire in_rst,
    input wire in_rob_mispredict,
    input wire [`GPR_SIZE-1:0] in_rob_new_PC,
    output fetch_interface out_d_sigs
);

  // access IMEM
  logic [31:0] data;
  // PC is an internal register to fetch.
  logic [63:0] entry_addr[0:0];  // to make verilog see it as a memory
  logic [63:0] PC;
  opcode_t opcode;
  logic signed [`GPR_SIZE-1:0] imm;
  logic rst;

  initial begin
    $readmemb("mem/entry.txt", entry_addr);
  end

  imem #(PAGESIZE) mem (
      .in_addr (PC),
      .out_data(data)
  );

  decode_instruction decoder (
      .in_insnbits(data),
      .out_opcode (opcode)
  );
  extract_immval extractor (
      .in_insnbits(data),
      .opcode(opcode),
      .out_reg_imm(imm)
  );

  logic is_mispred;
  logic no_instruction;
  logic ret_from_main;
  always_comb begin
    ret_from_main   = PC == 0;
    no_instruction  = data == 0;
    out_d_sigs.done = ~rst & ~no_instruction;
    out_d_sigs.pc   = PC;
    if (no_instruction) begin
      out_d_sigs.insnbits = 0;
    end else if (ret_from_main) begin
      out_d_sigs.insnbits = INSNBITS_HLT;
    end else begin
      out_d_sigs.insnbits = data;
    end
  end

  always_ff @(posedge in_clk) begin : fetch_logic
    rst <= in_rst;
    is_mispred <= in_rob_mispredict;
    if (in_rst) begin
      `DEBUG(("(fetch) Resetting. PC: %16x -> %16x (entry point)", PC, entry_addr[0]));
      PC <= entry_addr[0];
    end else begin
      if (rst) begin
        `DEBUG(("(fetch) Last cycle was reset. PC remains %16x", PC));
      end else if (in_rob_mispredict) begin
        `DEBUG(("(fetch) Mispredict received. PC %16x -> %16x", PC, in_rob_new_PC));
        PC <= in_rob_new_PC;
      end else if (ret_from_main) begin
        `DEBUG(("(fetch) PC at 0. Possibly due to return from main. Halting: %16x", PC));
      end else if (no_instruction) begin
        `DEBUG(("(fetch) All insnbits are 0. PC Halted at: %16x", PC));
      end  
      // NOTE(Nate): What comes after is a little jank
      else if (opcode == OP_B | opcode == OP_BL) begin
        `DEBUG(("(fetch) detected branch. changing PC: %16x -> %16x", PC, PC + imm));
        PC <= PC + imm;
      end  
      // NOTE(Nate): But it does the job ig
      else begin
        `DEBUG(("(fetch) PC: %16x -> %16x", PC, PC + 4));
        PC <= PC + 4;
      end
    end
  end : fetch_logic

endmodule : fetch

// Note: the imem is combinational to make accessing memory super easy.
module imem #(
    parameter int PAGESIZE = 4096
) (
    input  logic [63:0] in_addr,
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

