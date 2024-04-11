`define RS_SIZE 8
`define ROB_SIZE (RS_SIZE)*2+2
`define ROB_IDX_SIZE $clog2(`ROB_SIZE)
`define REG_SIZE 64
`define GPR_COUNT 32
`define GPR_IDX_SIZE $clog2(`GPR_COUNT)
`define GPR_SIZE 5 //IDK WHAT ITS SUPPOSED TO DO

typedef enum logic [1:0] {
    FU_ALU, // Arithmetic & Logic Unit
    FU_LS   // Load / Store Unit
} func_unit;


typedef struct packed {
    logic valid;
    logic [`ROB_IDX_SIZE-1:0] rob_index;
    logic [`REG_SIZE-1:0] value;
} rs_op;

typedef struct packed {
    rs_op op1;
    rs_op op2;
    logic [`ROB_IDX_SIZE-1:0] dst_rob_index;
    logic ready;
    logic entry_valid;
} rs_entry;

typedef struct packed {
    logic valid;
    logic [`ROB_IDX_SIZE-1:0] rob_index;
    logic [`REG_SIZE-1:0] value;
    logic [`GPR_IDX_SIZE-1:0] gpr_idx;
} gpr_entry;

typedef struct packed {
    logic gpr_index;
    logic valid;
    logic [`GPR_IDX_SIZE-1:0] value;
    logic [3:0] nzcv;
    logic set_nzcv;
} rob_entry;

typedef struct packed {
    rs_entry [`RS_SIZE-1:0] rs;
    logic [`ROB_SIZE-1:0] rob;
} debug_info;

module reservation_station # (
  parameter RS_SIZE = 8
)
(
  input logic op1_valid,
  input logic op2_valid,
  input logic [`ROB_IDX_SIZE-1:0] op1_rob_index,
  input logic [`ROB_IDX_SIZE-1:0] op2_rob_index,
  input logic [`REG_SIZE-1:0] op1_value,
  input logic [`REG_SIZE-1:0] op2_value
  
);
    rs_entry [`RS_SIZE-1:0] rs;    

endmodule

module regfile(
    input logic [`ROB_IDX_SIZE-1:0] in_rob_next_free_index,
    input logic [`GPR_IDX_SIZE-1:0] in_regfile_index,
    input logic in_should_commit,
    input logic [`GPR_SIZE-1:0] in_commit_value,
    input logic in_has_nzcv,
    input logic [3:0] in_nzcv
    // TODO: Add inputs for dispatch

);
    gpr_entry [`GPR_COUNT-1:0] gpr;

endmodule

module dispatch (
    input logic insnbits,
    input logic stall,
    output logic d_stalled,
    output func_unit func_unit_id // ID of functional unit 
);
    /* TODO:
     *  - Decode instr bits
     *  - Read srcs from regfile
     *  - Insert into ROB and RS
     */
    logic state;
    
endmodule