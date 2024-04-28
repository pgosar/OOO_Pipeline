`include "data_structures.sv"


module reservation_stations (
    input logic in_rst,
    input logic in_clk,
    // Inputs From ROB (sourced from either regfile or ROB)
    input logic in_rob_done,
    input fu_t in_rob_fu_id,
    input alu_op_t in_rob_fu_op,
    input logic in_rob_val_a_valid,
    input logic in_rob_val_b_valid,
    input logic in_rob_nzcv_valid,
    input logic [`GPR_SIZE-1:0] in_rob_val_a_value,
    input logic [`GPR_SIZE-1:0] in_rob_val_b_value,
    input nzcv_t in_rob_nzcv,
    input logic in_rob_set_nzcv,
    input logic [`ROB_IDX_SIZE-1:0] in_rob_val_a_rob_index,
    input logic [`ROB_IDX_SIZE-1:0] in_rob_val_b_rob_index,
    input logic [`GPR_IDX_SIZE-1:0] in_rob_dst_rob_index,
    input logic [`GPR_IDX_SIZE-1:0] in_rob_nzcv_rob_index,
    input logic in_rob_broadcast_done,
    input logic [`ROB_IDX_SIZE-1:0] in_rob_broadcast_index,
    input logic [`GPR_SIZE-1:0] in_rob_broadcast_value,
    input logic in_rob_broadcast_set_nzcv,
    input nzcv_t in_rob_broadcast_nzcv,
    input logic in_rob_is_mispred,
    input logic in_rob_instr_uses_nzcv,
    // Inputs from FU (LS)
    input logic in_fu_ls_ready,
    // Inputs from FU (ALU)
    input logic in_fu_alu_ready,
    // Outputs for FU (ALU)
    output logic out_fu_alu_start,
    output logic out_fu_ls_start,
    output alu_op_t out_fu_alu_op,
    output logic [`GPR_SIZE-1:0] out_fu_alu_val_a,
    output logic [`GPR_SIZE-1:0] out_fu_alu_val_b,
    output logic [`ROB_IDX_SIZE-1:0] out_fu_alu_dst_rob_index,
    output logic out_fu_alu_set_nzcv,
    output nzcv_t out_fu_alu_nzcv
);

  logic ls_ready, alu_ready;
  // assign alu_ready = in_rob_fu_id == FU_ALU & in_fu_alu_ready;
  // assign ls_ready  = in_rob_fu_id == FU_LS & in_fu_ls_ready;
  // reservation_station_module ls (
  //     .*,
  //     .in_fu_alu_ready(alu_ready)
  // );
  reservation_station_module alu (
      .*
      // .in_fu_alu_ready(ls_ready)
  );

endmodule

module reservation_station_module #(
    parameter RS_SIZE = 8,
    parameter RS_IDX_SIZE = 3
) (
    // Timing & Reset
    input logic in_rst,
    input logic in_clk,
    // Inputs From ROB
    input logic in_rob_done,
    input alu_op_t in_rob_fu_op,
    input logic in_rob_val_a_valid,
    input logic in_rob_val_b_valid,
    input logic in_rob_nzcv_valid,
    input logic [`GPR_SIZE-1:0] in_rob_val_a_value,
    input logic [`GPR_SIZE-1:0] in_rob_val_b_value,
    input nzcv_t in_rob_nzcv,
    input logic in_rob_set_nzcv,
    input logic [`ROB_IDX_SIZE-1:0] in_rob_val_a_rob_index,
    input logic [`ROB_IDX_SIZE-1:0] in_rob_val_b_rob_index,
    input logic [`GPR_IDX_SIZE-1:0] in_rob_dst_rob_index,
    input logic [`GPR_IDX_SIZE-1:0] in_rob_nzcv_rob_index,
    input logic in_rob_instr_uses_nzcv,

    // Inputs from ROB (for broadcast)
    input logic in_rob_broadcast_done,
    input logic [`ROB_IDX_SIZE-1:0] in_rob_broadcast_index,
    input logic [`GPR_SIZE-1:0] in_rob_broadcast_value,
    input logic in_rob_broadcast_set_nzcv,
    input nzcv_t in_rob_broadcast_nzcv,
    input logic in_rob_is_mispred,

    // Inputs from FU (LS)
    input logic in_fu_ls_ready,
    // Inputs from FU (ALU)
    input logic in_fu_alu_ready,

    // Outputs for FU (ALU)
    output logic out_fu_alu_start,  // A
    output logic out_fu_ls_start,  // B
    output alu_op_t out_fu_alu_op,  // AA
    output logic [`GPR_SIZE-1:0] out_fu_alu_val_a,  // AB
    output logic [`GPR_SIZE-1:0] out_fu_alu_val_b,  // AC
    output logic [`ROB_IDX_SIZE-1:0] out_fu_alu_dst_rob_index,  // AD
    output logic out_fu_alu_set_nzcv,  // AE
    output nzcv_t out_fu_alu_nzcv  // AF
);

  // In RS, we create two bitmaps. One shows entries which are READY to
  // be consumed by the FU. The other shows entries which are FREE and
  // can receive new values. We use these bitmaps in order to get the
  // next entry to consume and the next entry to be inserted into using
  // a priority encoding (which will hopefully be synthesized into a LUT).
  // An additional entry is added to both tables to represent that there are
  // no ready or free entries respectively. This sentinel index is referred to
  // as the INVALID_INDEX.

  // Internal state
  rs_entry_t [RS_SIZE-1:0] rs;
  logic delayed_clk;
  // Buffered state
  logic rob_val_a_valid;
  logic rob_val_b_valid;
  logic rob_nzcv_valid;
  logic [`GPR_SIZE-1:0] rob_val_a_value;
  logic [`GPR_SIZE-1:0] rob_val_b_value;
  logic rob_set_nzcv;
  nzcv_t rob_nzcv;
  logic [`ROB_IDX_SIZE-1:0] rob_val_a_rob_index;
  logic [`ROB_IDX_SIZE-1:0] rob_val_b_rob_index;
  logic [`ROB_IDX_SIZE-1:0] rob_dst_rob_index;
  logic [`ROB_IDX_SIZE-1:0] rob_nzcv_rob_index;
  alu_op_t rob_fu_op;
  logic rob_done;
  logic fu_alu_ready;
  logic rob_instr_uses_nzcv;
  // For broadcasts
  logic [`ROB_IDX_SIZE-1:0] rob_broadcast_index;
  logic [`GPR_SIZE-1:0] rob_broadcast_value;
  logic rob_broadcast_set_nzcv;
  logic rob_broadcast_done;
  nzcv_t rob_broadcast_nzcv;

  always_ff @(posedge in_clk, negedge in_clk) begin
    delayed_clk <= #1 in_clk;
  end

  localparam logic [RS_IDX_SIZE:0] INVALID_INDEX = RS_SIZE;

  // Create bitmap of occupies entries
  logic [RS_SIZE:0] occupied_entries;
  assign occupied_entries[INVALID_INDEX] = 0;  // invalid entry always free
  logic [RS_IDX_SIZE:0] free_station_index;
  for (genvar i = 0; i < RS_SIZE; i += 1) begin
    assign occupied_entries[i] = rs[i].entry_valid;
  end

  // Create bitmap of ready entries
  logic [RS_SIZE:0] ready_entries;
  assign ready_entries[INVALID_INDEX] = 1;  // invalid entry always ready
  logic [RS_IDX_SIZE:0] ready_station_index;
  // always_comb begin
  for (genvar i = 0; i < RS_SIZE; i += 1) begin
    // $display(
    //     "rs[%0d].entry_valid: %b, rs[%0d].op1.valid: %b, rs[%0d].op2.valid: %b, rs[%0d].set_nzcv: %b, rs[%0d].nzcv_valid: %b",
    //     i, rs[i].entry_valid, i, rs[i].op1.valid, i, rs[i].op2.valid, i, rs[i].set_nzcv, i,
    //     rs[i].nzcv_valid);
    assign ready_entries[i] = rs[i].entry_valid & rs[i].op1.valid & rs[i].op2.valid & (rs[i].uses_nczv ? rs[i].nzcv_valid : 1);
    // end
  end

  // Do priority encoding
  always_comb begin
    // Priority encoder LUT for most significant 0 bit
    free_station_index = INVALID_INDEX;
    for (logic [RS_IDX_SIZE:0] i = RS_IDX_SIZE - 1; i < INVALID_INDEX; i -= 1) begin
      if (occupied_entries[i] == 1'b0) free_station_index = i;
    end

    ready_station_index = INVALID_INDEX;
    // Priority encoder LUT for most significant 1 bit
    for (logic [RS_IDX_SIZE:0] i = RS_IDX_SIZE - 1; i < INVALID_INDEX; i -= 1) begin
      if (ready_entries[i] == 1'b1) ready_station_index = i;
    end
  end

  // This is where the actual code starts lol

  always_ff @(posedge in_clk) begin : rs_on_clk
    if (in_rst) begin
`ifdef DEBUG_PRINT
      $display("(RS) Resetting both reservation stations");
`endif
      // Reset root control signal
      rob_done <= 0;
      // Reset internal state
      for (int i = 0; i < RS_SIZE; i += 1) begin
        rs[i].entry_valid <= 0;
      end
    end else begin : rs_not_reset
      if (in_rob_is_mispred) begin
`ifdef DEBUG_PRINT
        $display("(regfile) Deleting mispredicted instructions");
`endif
        // todo handle mispred
      end else begin : rs_not_mispred
        if (fu_alu_ready & (ready_station_index != INVALID_INDEX)) begin
          rs[ready_station_index].entry_valid <= 0;
        end
        if (fu_alu_ready & (ready_station_index != INVALID_INDEX)) begin : fu_consume_entry
`ifdef DEBUG_PRINT
          $display("(RS) Remove entry RS[%0d] becasue FU is ready to run on next cycle",
                   ready_station_index);
`endif
          rs[ready_station_index].entry_valid <= ~fu_alu_ready;
        end : fu_consume_entry
        // Update consumed entry
        // Add new reservation station entry from decode
        // Update entry because FU has consumed the value. This will execute
        // in lockstep with the FU actually consuming the value.
        $display("FU ALU Ready: %0d, Ready Station Index: %0d, invalid index", fu_alu_ready,
                 ready_station_index, INVALID_INDEX);
        $display("val a valid: %0d, val b valid: %0d, nzcv valid: %0d", rob_val_a_valid,
                 rob_val_b_valid, rob_nzcv_valid);
      end : rs_not_mispred
      // Buffer state
      rob_val_a_valid <= in_rob_val_a_valid;
      rob_val_b_valid <= in_rob_val_b_valid;
      rob_nzcv_valid <= in_rob_nzcv_valid;
      rob_val_a_value <= in_rob_val_a_value;
      rob_val_b_value <= in_rob_val_b_value;
      rob_set_nzcv <= in_rob_set_nzcv;
      rob_nzcv <= in_rob_nzcv;
      rob_val_a_rob_index <= in_rob_val_a_rob_index;
      rob_val_b_rob_index <= in_rob_val_b_rob_index;
      rob_dst_rob_index <= in_rob_dst_rob_index;
      rob_nzcv_rob_index <= in_rob_nzcv_rob_index;
      rob_fu_op <= in_rob_fu_op;
      rob_done <= in_rob_done;
      fu_alu_ready <= in_fu_alu_ready;
      rob_instr_uses_nzcv <= in_rob_instr_uses_nzcv;
      // For broadcast
      rob_broadcast_index <= in_rob_broadcast_index;
      rob_broadcast_value <= in_rob_broadcast_value;
      rob_broadcast_nzcv <= in_rob_broadcast_nzcv;
      rob_broadcast_set_nzcv <= in_rob_broadcast_set_nzcv;
      rob_broadcast_done <= in_rob_broadcast_done;
    end : rs_not_reset
  end : rs_on_clk

  always_ff @(posedge in_clk) begin
    #1
    if (rob_broadcast_done) begin : rs_broadcast
`ifdef DEBUG_PRINT
      $display("(RS) Received a broadcast for ROB[%0d] -> %0d", rob_broadcast_index,
               rob_broadcast_value);
`endif
      // Update reservation stations with values from the ROB
      for (int i = 0; i < RS_SIZE; i += 1) begin
        if (rs[i].entry_valid) begin
          if (rs[i].op1.rob_index == rob_broadcast_index) begin
`ifdef DEBUG_PRINT
            $display("(RS) \tUpdating RS[%0d] op1 -> %0d", i, rob_broadcast_value);
`endif
            rs[i].op1.value <= rob_broadcast_value;
            rs[i].op1.valid <= 1;
          end
          if (rs[i].op2.rob_index == rob_broadcast_index) begin
`ifdef DEBUG_PRINT
            $display("(RS) \tUpdating RS[%0d] op2 -> %0d", i, rob_broadcast_value);
`endif

            rs[i].op2.value <= rob_broadcast_value;
            rs[i].op2.valid <= 1;
          end
          if (rob_broadcast_set_nzcv && rs[i].set_nzcv && rs[i].nzcv_rob_index == rob_broadcast_index) begin
            rs[i].nzcv <= rob_broadcast_nzcv;
            rs[i].nzcv_valid <= 1;
          end
        end
      end
    end : rs_broadcast
  end

  always_ff @(posedge in_clk) begin
    #2
    if (rob_done & free_station_index != INVALID_INDEX) begin : rs_add_entry
      rs[free_station_index].op1.valid <= rob_val_a_valid;
      rs[free_station_index].op2.valid <= rob_val_b_valid;
      rs[free_station_index].nzcv_valid <= rob_nzcv_valid;
      rs[free_station_index].op1.value <= rob_val_a_value;
      rs[free_station_index].op2.value <= rob_val_b_value;
      rs[free_station_index].set_nzcv <= rob_set_nzcv;
      rs[free_station_index].nzcv <= rob_nzcv;
      rs[free_station_index].op1.rob_index <= rob_val_a_rob_index;
      rs[free_station_index].op2.rob_index <= rob_val_b_rob_index;
      rs[free_station_index].dst_rob_index <= rob_dst_rob_index;
      rs[free_station_index].nzcv_rob_index <= rob_nzcv_rob_index;
      rs[free_station_index].op <= rob_fu_op;
      rs[free_station_index].entry_valid <= 1;

`ifdef DEBUG_PRINT
      $display("(RS) Adding new entry to RS[%0d] for ROB[%0d]", free_station_index,
                rob_dst_rob_index);
      $display("(RS) \tset_nzcv: %0d, use_nzcv: %0d, fu_op: %0d", rob_set_nzcv,
                rob_instr_uses_nzcv, rob_fu_op);
      $display("(RS) \top1: [valid: %0d, value: %0d, rob_index: %0d],", rob_val_a_valid,
                rob_val_a_value, rob_val_a_rob_index);
      $display("(RS) \top2: [valid: %0d, value: %0d, rob_index: %0d],", rob_val_b_valid,
                rob_val_b_value, rob_val_b_rob_index);
      $display("(RS) \tnzcv: [valid: %0d, value: %0d, rob_index: %0d],", rob_nzcv_valid,
                rob_nzcv, rob_nzcv_rob_index);
`endif
    end : rs_add_entry
  end

  always_comb begin
    // Allow the ALU to consume the value when ready
    out_fu_alu_start = fu_alu_ready & ready_station_index != INVALID_INDEX;
    out_fu_alu_op = rs[ready_station_index].op;
    out_fu_alu_val_a = rs[ready_station_index].op1.value;
    out_fu_alu_val_b = rs[ready_station_index].op2.value;
    out_fu_alu_dst_rob_index = rs[ready_station_index].dst_rob_index;
    out_fu_alu_nzcv = rs[ready_station_index].nzcv;
    out_fu_alu_set_nzcv = rs[ready_station_index].set_nzcv;
  end

  always_ff @(posedge delayed_clk) begin
    #2;  // TODO(Nate): Verilator REFUSES to believe that the delayed clk is
    // actually delayed, and throws multi-driven signal errors without
    // this line

    // TODO(Nate): Add case for updating from rob broadcast
    // Mispred broadcast
    // for (int i = 0; i < RS_SIZE; i+=1) begin
    //     `ifdef DEBUG_PRINT
    //         $display("(RS) Mispred");
    //     `endif
    //     if (rs[i].entry_valid) begin // Unnecessary check, but will help energy
    //         if (rs[i].op1.rob_index == in_rob_broadcast_index) begin
    //             `ifdef DEBUG_PRINT
    //                 $display("(RS) mispred Updating RS[%0d] op1", i);
    //             `endif
    //             rs[i].op1.value <= in_rob_broadcast_value;
    //             rs[i].op1.valid <= 1;
    //         end
    //         if (rs[i].op2.rob_index == in_rob_broadcast_index) begin
    //             `ifdef DEBUG_PRINT
    //                 $display("(RS) mispred Updating RS[%0d] op2", i);
    //             `endif
    //             rs[i].op2.value <= in_rob_broadcast_value;
    //             rs[i].op1.valid <= 1;
    //         end
    //     end
    // end
  end

endmodule
