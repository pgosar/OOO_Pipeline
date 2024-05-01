`include "func_units.sv"
`include "data_structures.sv"
`include "decode.sv"  // TODO a cleaner solution is separating useful
                      // modules out into their own files. This will do for now

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
    input wire in_rob_mispredict,
    input wire [`GPR_SIZE-1:0] in_rob_new_PC,
    output logic [31:0] out_d_insnbits,
    output logic out_d_done,
    output logic [`GPR_SIZE-1:0] out_d_branch_PC
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
  logic [63:0] entry_addr[0:0];  // to make verilog see it as a memory
  logic [63:0] PC;
  logic e;
  opcode_t opcode;
  logic [`GPR_SIZE-1:0] imm;
  logic rst;
  logic no_instruction;
  logic mispredict;

  initial begin
    $readmemb("mem/entry.txt", entry_addr);
  end

  imem #(PAGESIZE) mem (
      .in_addr (PC),
      .out_data(data)
  );

  decode_instruction decoder (
      .in_insnbits(data),
      .out_opcode(opcode)
  );
  extract_immval extractor (
      .in_insnbits(data),
      .opcode(opcode),
      .out_reg_imm(imm)
  );

  always_ff @(posedge in_clk) begin : fetch_logic
    if (in_rst) begin
      `DEBUG(("(fetch) resetting"));
      PC <= entry_addr[0];
      out_d_insnbits <= 0;
      out_d_done <= 0;
    end else begin
      #1;  // There is a data dependency on 'data' from imem
      `DEBUG(("(fetch) opcode is %s", opcode.name));
      `DEBUG(("(fetch) mispredict: %0d", in_rob_mispredict));
      out_d_insnbits <= data;
      out_d_done <= 1;
      if (in_rob_mispredict) begin
        `DEBUG(("(fetch) received rob mispredict directive. setting PC to %0d", in_rob_new_PC));
        out_d_done <= 0;
        PC <= in_rob_new_PC;
      end else if (opcode == OP_B_COND) begin
        out_d_branch_PC <= PC + imm;
        PC <= PC + 4;
      end else if (opcode == OP_B || opcode == OP_BL) begin
        `DEBUG(("(fetch) detected branch. changing PC: %16x -> %16x", PC, PC + imm));
        PC <= PC + imm;
      end else begin
        `DEBUG(("(fetch) no branch. PC: %16x -> %16x", PC, PC + 4));
        PC <= PC + 4;
      end
    end
  end : fetch_logic
endmodule : fetch
