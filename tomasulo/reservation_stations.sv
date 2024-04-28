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
    output logic out_fu_alu_start,
    output logic out_fu_ls_start,
    output alu_op_t out_fu_alu_op,
    output logic [`GPR_SIZE-1:0] out_fu_alu_val_a,
    output logic [`GPR_SIZE-1:0] out_fu_alu_val_b,
    output logic [`ROB_IDX_SIZE-1:0] out_fu_alu_dst_rob_index,
    output logic out_fu_alu_set_nzcv,
    output nzcv_t out_fu_alu_nzcv
);
  // TODO(Nate): Need to take a look at the look up table

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

  always_ff @(posedge in_clk, negedge in_clk) begin
    delayed_clk <= #1 in_clk;
  end

  // TODO(Nate): Update these comments lol. We essentially want two bitmaps.
  // One which shows ready entries, and one which free entires. We can
  // determine the next index in O(1) time via a priority encoding LUT.
  // An additional bit is always added to the bitmap which is either always
  // free or always ready respectively. This is a sentinel value - it
  // represents an invalid entry in the array. Once a sentinel value is set,
  // it is clear that the reservation station is either full or empty.

  localparam logic [RS_IDX_SIZE:0] INVALID_INDEX = RS_SIZE;
  // Map occupied reservation stations entries to wires. These will be used in
  // a LUT in order to determine the index of the next free entry.
  // If all entries are occupied, the INVALID_INDEX will be set.
  logic [RS_SIZE:0] occupied_entries;
  logic [RS_IDX_SIZE:0] free_station_index;
  for (genvar i = 0; i < RS_SIZE; i += 1) begin
    assign occupied_entries[i] = rs[i].entry_valid;
  end
  assign occupied_entries[INVALID_INDEX] = 0;

  // Map ready reservation stations entries to wires. These will be used in
  // a LUT in order to determine the index of the next entry to be executed.
  // If none are ready to be executed, the INVALID_INDEX will be set.
  logic [RS_SIZE:0] ready_entries;
  logic [RS_IDX_SIZE:0] ready_station_index;
  // Wires up the ready entry of each rs
  // always_comb begin
  //   $display(
  //       "rs[%0d].entry_valid: %b, rs[%0d].op1.valid: %b, rs[%0d].op2.valid: %b, rs[%0d].set_nzcv: %b, rs[%0d].nzcv_valid: %b",
  //       i, rs[i].entry_valid, i, rs[i].op1.valid, i, rs[i].op2.valid, i, rs[i].set_nzcv, i,
  //       rs[i].nzcv_valid);
  // end
  always_comb begin
    for (int i = 0; i < RS_SIZE; i += 1) begin
      // $monitor(
      //     "rs[%0d].entry_valid: %b, rs[%0d].op1.valid: %b, rs[%0d].op2.valid: %b, rs[%0d].set_nzcv: %b, rs[%0d].nzcv_valid: %b",
      //     i, rs[i].entry_valid, i, rs[i].op1.valid, i, rs[i].op2.valid, i, rs[i].set_nzcv, i,
      //     rs[i].nzcv_valid);
      ready_entries[i] = rs[i].entry_valid & rs[i].op1.valid & rs[i].op2.valid & (rs[i].set_nzcv ? rs[i].nzcv_valid : 1);
    end

    ready_entries[INVALID_INDEX] = 1;
  end
  // Set the indexes
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

  always_ff @(posedge in_clk) begin
    if (in_rst) begin
`ifdef DEBUG_PRINT
      $display("(RS) Resetting both reservation stations");
`endif
      // rs <= 0;
      rob_done <= 0;
      for (int i = 0; i < RS_SIZE; i += 1) begin
        rs[i].entry_valid <= 0;
      end
    end else begin
      if (!in_rob_is_mispred) begin

        if (in_rob_broadcast_done) begin
          // Update reservation stations with values from the ROB
          for (int i = 0; i < RS_SIZE; i += 1) begin : rs_broadcast_loop
            if (rs[i].entry_valid) begin
              if (rs[i].op1.rob_index == in_rob_broadcast_index) begin
`ifdef DEBUG_PRINT
                $display("(RS) not mispred Updating RS[%0d] op1", i);
`endif
                rs[i].op1.value <= in_rob_broadcast_value;
                rs[i].op1.valid <= 1;
              end
              if (rs[i].op2.rob_index == in_rob_broadcast_index) begin
`ifdef DEBUG_PRINT
                $display("(RS) not mispred Updating RS[%0d] op2", i);
`endif

                rs[i].op2.value <= in_rob_broadcast_value;
                rs[i].op2.valid <= 1;
              end
              if (in_rob_broadcast_set_nzcv && rs[i].set_nzcv && rs[i].nzcv_rob_index == in_rob_broadcast_index) begin
                rs[i].nzcv <= in_rob_broadcast_nzcv;
                rs[i].nzcv_valid <= 1;
              end
            end
          end : rs_broadcast_loop
        end
        if (fu_alu_ready & ready_station_index != INVALID_INDEX) begin
          // Allow the FU to read the value
          out_fu_alu_op <= rs[ready_station_index].op;
          out_fu_alu_val_a <= rs[ready_station_index].op1.value;
          out_fu_alu_val_b <= rs[ready_station_index].op2.value;
          out_fu_alu_dst_rob_index <= rs[ready_station_index].dst_rob_index;
          out_fu_alu_nzcv <= rs[ready_station_index].nzcv;
          out_fu_alu_set_nzcv <= rs[ready_station_index].set_nzcv;
        end
        // `ifdef DEBUG_PRINT
        //         $display("(RS) FU ready");
        // `endif
      end else begin  /* in_rob_is_mispred */
`ifdef DEBUG_PRINT
        $display("(regfile) Deleting mispredicted instructions");
`endif
        // todo handle mispred
      end
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
    end
  end

`ifdef DEBUG_PRINT
  logic [`RS_IDX_SIZE:0] last_index;
`endif
  always_ff @(negedge in_clk) begin
    if (rob_done) begin
`ifdef DEBUG_PRINT
`endif
    end
  end

  always_ff @(posedge delayed_clk) begin
    #2;  // TODO(Nate): Verilator REFUSES to believe that the delayed clk is
    // actually delayed, and throws multi-driven signal errors without
    // this line

    // Update consumed entry
    if (fu_alu_ready & ready_station_index != INVALID_INDEX) begin
      rs[ready_station_index].entry_valid <= 0;
    end
    // Add new reservation station entry from decode
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
      $display(
          "(RS) Adding new entry to RS[%0d]: op1 valid: %0d, op1 value: %0d op2 valid: %0d, op2 value: %0d set nzcv: %0d nzcv valid: %b nzcv value: %b: fu op %d",
          free_station_index, rob_val_a_valid, rob_val_a_value, rob_val_b_valid, rob_val_b_value,
          rob_set_nzcv, rob_nzcv_valid, rob_nzcv, rob_fu_op);
      last_index <= free_station_index;
`endif
    end : rs_add_entry
    // Update entry because FU has consumed the value. This will execute
    // in lockstep with the FU actually consuming the value.
    out_fu_alu_start <= fu_alu_ready & (ready_station_index != INVALID_INDEX);
    if (fu_alu_ready & (ready_station_index != INVALID_INDEX)) begin : fu_consume_entry
`ifdef DEBUG_PRINT
      $display("(RS) Remove entry RS[%0d] becasue FU is ready to run on next cycle",
               ready_station_index);
`endif
      rs[ready_station_index].entry_valid <= ~fu_alu_ready;
    end : fu_consume_entry
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
    //             rs[i].op1.value <= in_rob_broadcast_val;
    //             rs[i].op1.valid <= 1;
    //         end
    //         if (rs[i].op2.rob_index == in_rob_broadcast_index) begin
    //             `ifdef DEBUG_PRINT
    //                 $display("(RS) mispred Updating RS[%0d] op2", i);
    //             `endif
    //             rs[i].op2.value <= in_rob_broadcast_val;
    //             rs[i].op1.valid <= 1;
    //         end
    //     end
    // end
  end

endmodule
