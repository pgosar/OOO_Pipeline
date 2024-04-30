`include "func_units.sv"
`include "data_structures.sv"
`include "decode.sv" // TODO a cleaner solution is separating useful
                     // modules out into their own files. This will do for now

module fetch #(
    parameter int PAGESIZE = 4096
)  // note: this should always be 4096
(
    input wire in_clk,
    input wire in_rst,
    input wire in_reg_correction,
    output logic [31:0] in_fetch_insnbits,
    output logic in_fetch_done
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
  logic [63:0] PC_load[1];  // to make verilog see it as a memory
  logic [63:0] PC;
  logic e;
  opcode_t opcode;
  logic [`GPR_SIZE-1:0] imm;

  imem #(PAGESIZE) mem (
      PC,
      data
  );
  
  decode_instruction decoder (.in_insnbits(data), .opcode(opcode));
  extract_immval extractor(.in_insnbits(data),  .opcode(opcode), .out_reg_imm(imm));

  always_ff @(posedge in_clk) begin : fetch_logic
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
    if (in_rst) begin
`ifdef DEBUG_PRINT
      $display("(fetch) resetting");
`endif
      $readmemb("mem/entry.txt", PC_load);
      PC = PC_load[0];
      in_fetch_insnbits <= 0;
      in_fetch_done <= 0;
    end else begin
      #1  // There is a data dependency on 'data' from imem
      if (data == 0) begin
        in_fetch_insnbits <= data;
        in_fetch_done <= 0;
      end else if (in_reg_correction) begin
`ifdef DEBUG_PRINT
        $display("(fetch) detected regfile correction.");
`endif
        in_fetch_done <= 0;
      end else begin
`ifdef DEBUG_PRINT 
        $display("(fetch) opcode is %s", opcode.name);
`endif
        in_fetch_insnbits <= data;
        in_fetch_done <= 1;
        if (opcode == OP_B || opcode == OP_BL) begin
          PC <= PC + imm;
`ifdef DEBUG_PRINT 
          $display("(fetch) detected branch. changing PC");
`endif
        end else begin
          PC <= PC + 4;
        end
      end
    end
  end : fetch_logic
endmodule : fetch
