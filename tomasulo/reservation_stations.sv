`include "data_structures.sv"

module reservation_station_module #(
    parameter RS_SIZE = 8,
    parameter RS_IDX_SIZE = 3
) (
    // Timing & Reset
    input logic in_rst,
    input logic in_clk,
    // Inputs From ROB (sourced from either regfile or ROB)
    input logic in_rob_set_nzcv,
    input nzcv_t in_rob_nzcv,
    input logic in_rob_val_a_valid,
    input logic in_rob_val_b_valid,
    input logic [`GPR_SIZE-1:0] in_rob_val_a_value,
    input logic [`GPR_SIZE-1:0] in_rob_val_b_value,
    input logic [`ROB_IDX_SIZE-1:0] in_rob_val_a_rob_index,
    input logic [`ROB_IDX_SIZE-1:0] in_rob_val_b_rob_index,
    input logic [`GPR_IDX_SIZE-1:0] in_rob_dst_rob_idx,
    input logic in_rob_should_broadcast,
    input logic [`ROB_IDX_SIZE-1:0] in_rob_broadcast_index,
    input logic [`GPR_SIZE-1:0] in_rob_broadcast_value,
    input logic in_rob_is_mispred,
    // Inputs from FU
    input logic in_fu_ready,  // ready to receive inputs
    // Outputs for FU
    output logic [`GPR_SIZE-1:0] out_fu_val_a,
    output logic [`GPR_SIZE-1:0] out_fu_val_b,
    output logic [`ROB_IDX_SIZE-1:0] out_fu_dst,
    output logic out_fu_set_nzcv,
    output nzcv_t out_fu_nzcv
    // Outputs for system
    // TODO(Nate): We should probably have a stall signal
);

  // TODO(Nate): This module is hardcoded for now. LUT should be generated
  // based on parameters
  rs_entry_t [RS_SIZE-1:0] rs;
  logic [RS_SIZE-1:0] rs_valid;

  // Wires up the ready entry of each rs
  for (genvar i = 0; i < RS_SIZE; i += 1) begin
    assign rs_valid[i] = rs[i].op1.valid & rs[i].op2.valid;
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
  // TODO: not sure why we have a unoptimizable error here, but looks safe to ignore for now
  // https://github.com/verilator/verilator/issues/63, fix later
  /* verilator lint_off UNOPTFLAT */
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
  for (genvar i = 0; i < RS_SIZE; i += 1) begin
    assign ready_entries[i] = rs[i].entry_valid & rs_valid[i];
  end
  assign ready_entries[INVALID_INDEX] = 1;

  always_latch begin
    // Priority encoder for most significant 0 bit
    for (logic signed [RS_IDX_SIZE:0] i = RS_IDX_SIZE; i >= 0; i -= 1) begin
      if (occupied_entries[i] == 1'b0) free_station_index = i;
    end

    // Priority encoder for most significant 1 bit
    for (logic signed [RS_IDX_SIZE:0] i = RS_IDX_SIZE; i >= 0; i -= 1) begin
      if (ready_entries[i] == 1'b1) ready_station_index = i;
    end
  end

  // This is where the actual code starts lol

  always_ff @(posedge in_clk) begin
    if (in_rst) begin
      rs = 0;
    end else if (!in_rob_is_mispred) begin
`ifdef DEBUG_PRINT
      $display("(reservation_stations) not mispredicted");
`endif
      if (in_rob_should_broadcast) begin
        // Update reservation stations with values from the ROB
        for (int i = 0; i < RS_SIZE; i += 1) begin
          if (rs[i].entry_valid) begin
            if (rs[i].op1.rob_index == in_rob_broadcast_index) begin
`ifdef DEBUG_PRINT
              $display("(reservation_stations) not mispred Updating RS[%0d] op1", i);
`endif
              rs[i].op1.value = in_rob_broadcast_value;
              rs[i].op1.valid = 1;
            end
            if (rs[i].op2.rob_index == in_rob_broadcast_index) begin
`ifdef DEBUG_PRINT
              $display("(reservation_stations) not mispred Updating RS[%0d] op2", i);
`endif

              rs[i].op2.value = in_rob_broadcast_value;
              rs[i].op2.valid = 1;
            end
          end
        end
      end
      if (in_fu_ready && ready_station_index != INVALID_INDEX) begin
`ifdef DEBUG_PRINT
        $display("(reservation_stations) FU ready");
`endif
        // Allow the FU to read the value
        out_fu_val_a <= rs[ready_station_index].op1.value;
        out_fu_val_b <= rs[ready_station_index].op2.value;
        out_fu_dst <= rs[ready_station_index].dst_rob_index;
        out_fu_nzcv <= rs[ready_station_index].nzcv;
        out_fu_set_nzcv <= rs[ready_station_index].set_nzcv;
      end
    end else if (in_rob_is_mispred) begin
`ifdef DEBUG_PRINT
      $display("(regfile) Deleting mispredicted instructions");
`endif
      // todo handle mispred
    end
  end

  always_ff @(negedge in_clk) begin
    #1;
    // Add new reservation station entry from dispatch
    if (free_station_index != INVALID_INDEX) begin : update_from_dispatch
`ifdef DEBUG_PRINT
      $display("(reservation_stations) instantiating RS[%0d]", free_station_index);
`endif
      rs[free_station_index].op1.value <= in_rob_val_a_value;
      rs[free_station_index].op1.rob_index <= in_rob_val_a_rob_index;
      rs[free_station_index].op1.valid <= in_rob_val_a_valid;
      rs[free_station_index].op2.value <= in_rob_val_b_value;
      rs[free_station_index].op2.rob_index <= in_rob_val_b_rob_index;
      rs[free_station_index].op2.valid <= in_rob_val_b_valid;
      rs[free_station_index].entry_valid <= 1;
      rs[free_station_index].dst_rob_index <= in_rob_dst_rob_idx;
      rs[free_station_index].set_nzcv <= in_rob_set_nzcv;
      rs[free_station_index].nzcv <= in_rob_nzcv;
`ifdef DEBUG_PRINT
      $display("RS[%0d] op1: %0d, op2: %0d, dst: %0d, valid1: %0d, valid2: %0d, set_nzcv: %0d",
               free_station_index, in_rob_val_a_value, in_rob_val_b_value, in_rob_dst_rob_idx,
               in_rob_val_a_valid, in_rob_val_b_valid, in_rob_set_nzcv);
`endif
    end : update_from_dispatch
    // Update entry because FU has consumed the value. This will execute
    // in lockstep with the FU actually consuming the value.
    if (ready_station_index != INVALID_INDEX) begin : fu_consume_entry
      // Delay updating to account for hold time
`ifdef DEBUG_PRINT
      $display("(reservation_stations) FU consumed RS[%0d]", ready_station_index);
`endif
      #1 rs[ready_station_index].entry_valid <= ~in_fu_ready;
    end : fu_consume_entry
    // TODO(Nate): Add case for updating from rob broadcast
    // Mispred broadcast
    // for (int i = 0; i < RS_SIZE; i+=1) begin
    //     `ifdef DEBUG_PRINT
    //         $display("(reservation_stations) Mispred");
    //     `endif
    //     if (rs[i].entry_valid) begin // Unnecessary check, but will help energy
    //         if (rs[i].op1.rob_index == in_rob_broadcast_index) begin
    //             `ifdef DEBUG_PRINT
    //                 $display("(reservation_stations) mispred Updating RS[%0d] op1", i);
    //             `endif
    //             rs[i].op1.value <= in_rob_broadcast_val;
    //             rs[i].op1.valid <= 1;
    //         end
    //         if (rs[i].op2.rob_index == in_rob_broadcast_index) begin
    //             `ifdef DEBUG_PRINT
    //                 $display("(reservation_stations) mispred Updating RS[%0d] op2", i);
    //             `endif
    //             rs[i].op2.value <= in_rob_broadcast_val;
    //             rs[i].op1.valid <= 1;
    //         end
    //     end
    // end
  end

endmodule
