`define RS_SIZE 2
`define ROB_SIZE 2
`define REG_SIZE 64
`define GPR_COUNT 32
`define GPR_IDX_SIZE $clog2(`GPR_COUNT)

// NOTE(Nate): I stopped here. Contemplating a couple things.
// - Change rs_entry to op_entry since it only deals with one op. Then have
//   rs_entry have two operands in it.
// - Change the re-order-buffer to use a struct
typedef struct packed {
  logic valid;
  logic [`GPR_IDX_SIZE-1:0] gpr_index;
  logic [`REG_SIZE-1:0] value;
} rs_op;

typedef struct packed {
  rs_op op1;
  rs_op op2;
} rs_entry;

typedef struct packed {
  rs_entry [`RS_SIZE-1:0] rs;
  logic [`ROB_SIZE-1:0]   rob;
} debug_info;

module core #(
    parameter int RS_SIZE  = 2,
    parameter int ROB_SIZE = 2
) (
    input wire i_clk,
    input wire i_reset,
    // input for an instruction
    output debug_info o_debug
);
  always_ff @(posedge i_clk) begin : main
    if (i_reset) begin
      o_debug.rs[0] <= {1'b0, {`GPR_IDX_SIZE{1'b0}}, `REG_SIZE'b0};
      // NOTE(Nate): Need to use replication for expressions
      o_debug.rob   <= 0;
    end else begin
      o_debug.rs[0] <= o_debug.rs[0].op1 + 1;
    end
  end : main
endmodule : core

module testbench ();
  localparam int RESERVATION_STATION_SIZE = 2;
  localparam int REORDER_BUFFER_SIZE = 2;

  debug_info debug_data;
  logic clk;
  logic reset;

  core #(
      .RS_SIZE(2),
      .RB_SIZE(2)
  ) cpu_core (
      .o_debug(debug_data),
      .i_clk  (clk),
      .i_reset(reset)
  );

  initial begin
    clk   = 0;
    reset = 1;
    #5;
    clk = 1;
    #5;
    clk   = 0;
    reset = 0;
    for (int i = 0; i < 8; i++) begin
      #5;
      clk = ~clk;
      $display("\nclk: %b Debug: %x", clk, debug_data.rs[0]);
      $write(
          "Reservation Station: op1_valid: %1h | op1_value: %d | op1_gpr_idx: %d | op2_valid: %d | op2_value: %d | op2_gpr_idx: %d",
          debug_data.rs[0].op1.valid, debug_data.rs[0].op1.value, debug_data.rs[0].op1.gpr_index,
          debug_data.rs[0].op2.valid, debug_data.rs[0].op2.value, debug_data.rs[0].op2.gpr_index);
    end
  end
endmodule
