`include "data_structures.sv"

module reservation_stations (
    input logic in_rst,
    input logic in_clk,
    // Inputs From ROB (sourced from either regfile or ROB)
    input rob_interface in_rob_sigs,
    // inputs from ROB for broadcast
    input rob_broadcast_interface in_rob_broadcast,
    input logic in_rob_is_mispred,
    // Inputs from FU (LS)
    input logic in_fu_ls_ready,
    // Inputs from FU (ALU)
    input logic in_fu_alu_ready,
    // Outputs for FU (ALU)
    output rs_interface out_alu_sigs,
    output rs_interface_alu_ext out_alu_sigs_ext,
    // outputs for FU (LS)
    output rs_interface out_ls_sigs
);

  // Buffer
  logic ls_ready, alu_ready;
  always_ff @(posedge in_clk) begin
    alu_ready <= in_fu_alu_ready;
    ls_ready  <= in_fu_ls_ready;
  end

  logic rs_ls_has_free, rs_ls_has_ready;
  logic rs_alu_has_free, rs_alu_has_ready;
  logic alu_primed, ls_primed;  // Primed to execute on next cycle;
  logic alu_stall;  // Stall ALU if LS is primed

  // Resolve structural hazard.
  always_comb begin
    // We need some comb logic to check whether both
    // signals are ready to run, and stop them from both running
    alu_primed = rs_alu_has_ready & alu_ready;
    ls_primed  = rs_ls_has_ready & ls_ready;
    alu_stall  = alu_primed & ls_primed;
  end

  logic tmp;
  reservation_station_module ls (
      .in_rst(in_rst),
      .in_clk(in_clk),
      .out_alu_sigs_ext(out_alu_sigs_ext),
      .in_rob_broadcast(in_rob_broadcast),
      .in_rob_is_mispred(in_rob_is_mispred),
      .in_stall(tmp),
      .in_fu_ready(ls_ready),
      .in_rob_sigs(in_rob_sigs),
      .out_fu_sigs(out_ls_sigs),
      .out_ls_sigs(tmp),
      .out_has_free(rs_ls_has_free),
      .out_has_ready(rs_ls_has_ready)
  );

  reservation_station_module alu (
      .in_rst(in_rst),
      .in_clk(in_clk),
      .in_rob_is_mispred(in_rob_is_mispred),
      .in_rob_broadcast(in_rob_broadcast),
      .in_stall(alu_stall),
      .in_fu_ready(alu_ready),
      .in_rob_sigs(in_rob_sigs),
      .out_fu_sigs(out_alu_sigs),
      .out_ls_sigs(tmp),
      .out_alu_sigs_ext(out_alu_sigs_ext),
      .out_has_free(rs_alu_has_free),
      .out_has_ready(rs_alu_has_ready)
  );

endmodule

module reservation_station_module #(
    parameter RS_SIZE = 8,
    parameter RS_IDX_SIZE = 3
) (
    // Timing & Reset
    input logic in_rst,
    input logic in_clk,
    input logic in_fu_ready,
    input logic in_stall,
    // Inputs From ROB (sourced from either regfile or ROB)
    input rob_interface in_rob_sigs,
    // Inputs from ROB (for broadcast)
    input rob_broadcast_interface in_rob_broadcast,
    input logic in_rob_is_mispred,

    // Outputs for FU (ALU)
    output rs_interface out_fu_sigs,
    output rs_interface_alu_ext out_alu_sigs_ext,

    // Outputs for FU (LS)
    output logic out_ls_sigs,

    // Output for RS Controller
    output logic out_has_free,
    output logic out_has_ready
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
  rs_entry_t [`RS_SIZE-1:0] rs;
  logic delayed_clk;
  // Buffered state
  logic rob_alu_val_a_valid;
  logic rob_alu_val_b_valid;
  logic rob_nzcv_valid;
  logic [`GPR_SIZE-1:0] rob_alu_val_a_value;
  logic [`GPR_SIZE-1:0] rob_alu_val_b_value;
  logic rob_set_nzcv;
  nzcv_t rob_nzcv;
  logic [`ROB_IDX_SIZE-1:0] rob_alu_val_a_rob_index;
  logic [`ROB_IDX_SIZE-1:0] rob_alu_val_b_rob_index;
  logic [`ROB_IDX_SIZE-1:0] rob_dst_rob_index;
  logic [`ROB_IDX_SIZE-1:0] rob_nzcv_rob_index;
  fu_op_t rob_fu_op;
  logic rob_done;
  logic fu_ready;
  logic rob_uses_nzcv;
  integer stur_counter;
  // For broadcasts
  logic [`ROB_IDX_SIZE-1:0] rob_broadcast_index;
  logic [`GPR_SIZE-1:0] rob_broadcast_value;
  logic rob_broadcast_set_nzcv;
  logic rob_broadcast_done;
  nzcv_t rob_broadcast_nzcv;

  always_ff @(posedge in_clk, negedge in_clk) begin
    delayed_clk <= #1 in_clk;
  end

  logic [RS_IDX_SIZE-1:0] free_station_index;
  logic [RS_IDX_SIZE-1:0] ready_station_index;
  logic has_free;
  logic has_ready;
  // This is where the actual code starts lol

  always_ff @(posedge in_clk) begin : rs_on_clk
    if (in_rst) begin
      `DEBUG(("(RS) Resetting both reservation stations"));
      // Reset root control signal
      rob_done <= 0;
      // Reset internal state
      for (int i = 0; i < RS_SIZE; i += 1) begin
        rs[i].entry_valid <= 0;
      end
    end else begin : rs_not_reset
      if (fu_ready & has_ready) begin : fu_consume_entry
        rs[ready_station_index].entry_valid <= ~fu_ready;
        `DEBUG(
            ("(RS) Remove entry RS[%0d] = op: %s. FU consumed entry at start of this cycle.", ready_station_index, rob_fu_op.name));
      end : fu_consume_entry
      // Buffer state
      rob_alu_val_a_valid <= in_rob_sigs.val_a_valid;
      rob_alu_val_b_valid <= in_rob_sigs.val_b_valid;
      rob_nzcv_valid <= in_rob_sigs.nzcv_valid;
      rob_alu_val_a_value <= in_rob_sigs.val_a_value;
      rob_alu_val_b_value <= in_rob_sigs.val_b_value;
      stur_counter <= in_rob_sigs.stur_counter;
      rob_set_nzcv <= in_rob_sigs.set_nzcv;
      rob_nzcv <= in_rob_sigs.nzcv;
      rob_alu_val_a_rob_index <= in_rob_sigs.val_a_rob_index;
      rob_alu_val_b_rob_index <= in_rob_sigs.val_b_rob_index;
      rob_dst_rob_index <= in_rob_sigs.dst_rob_index;
      rob_nzcv_rob_index <= in_rob_sigs.nzcv_rob_index;
      rob_fu_op <= in_rob_sigs.fu_op;
      rob_done <= in_rob_sigs.done;
      fu_ready <= in_fu_ready;
      rob_uses_nzcv <= in_rob_sigs.uses_nzcv;
      // For broadcast
      rob_broadcast_index <= in_rob_broadcast.index;
      rob_broadcast_value <= in_rob_broadcast.value;
      rob_broadcast_nzcv <= in_rob_broadcast.nzcv;
      rob_broadcast_set_nzcv <= in_rob_broadcast.set_nzcv;
      rob_broadcast_done <= in_rob_broadcast.done;

      // Unused state
      out_alu_sigs_ext.cond_codes <= in_rob_sigs.cond_codes;

    end : rs_not_reset
  end : rs_on_clk

  always_ff @(posedge in_clk) begin
    #2
    if (rob_broadcast_done) begin : rs_broadcast
      `DEBUG(("(RS) Received a broadcast for ROB[%0d] -> %0d", rob_broadcast_index, $signed(
             rob_broadcast_value)));
      // Update reservation stations with values from the ROB
      for (int i = 0; i < RS_SIZE; i += 1) begin
        if (rs[i].entry_valid) begin
          // src1
          // checks whether to update the value in the RS. All loads must only be updated if there
          // are no pending sturs
          if (~rs[i].op1.valid & rs[i].op1.rob_index == rob_broadcast_index & (stur_counter != 0 & in_rob_sigs.fu_op == OP_LDUR)) begin
            `DEBUG(("(RS) \tUpdating RS[%0d] op1 -> %0d (op: %s)", i, $signed(rob_broadcast_value
                   ), rs[i].op.name));
            if (rs[i].op == FU_OP_LDUR | rs[i].op == FU_OP_STUR) begin
              `DEBUG(
                  ("op1.value: %0d, rob_broadcast_value: %0d", rs[i].op1.value, rob_broadcast_value));
              rs[i].op1.value <= rs[i].op1.value + rob_broadcast_value;
            end else begin
              rs[i].op1.value <= rob_broadcast_value;
            end
            rs[i].op1.valid <= 1;
          end

          // src2
          if (~rs[i].op2.valid & rs[i].op2.rob_index == rob_broadcast_index & (stur_counter != 0 & in_rob_sigs.fu_op == OP_LDUR)) begin
            `DEBUG(("(RS) \tUpdating RS[%0d] op2 -> %0d", i, $signed(rob_broadcast_value)));
            rs[i].op2.value <= rob_broadcast_value;
            rs[i].op2.valid <= 1;
          end

          // nzcv
          if (rob_broadcast_set_nzcv & rs[i].set_nzcv & rs[i].nzcv_rob_index == rob_broadcast_index) begin
            rs[i].nzcv <= rob_broadcast_nzcv;
            rs[i].nzcv_valid <= 1;
          end
        end
      end
    end : rs_broadcast
  end

  rob_interface rob_sigs ();

  always_ff @(posedge in_clk) begin
    rob_sigs <= in_rob_sigs;
    #1
    if (in_rob_sigs.done & has_free) begin : in_rs_add_entry
      rs[free_station_index].op1.valid <= rob_sigs.val_a_valid;
      rs[free_station_index].op2.valid <= rob_sigs.val_b_valid;
      rs[free_station_index].op1.value <= rob_sigs.val_a_value;
      rs[free_station_index].op2.value <= rob_sigs.val_b_value;
      rs[free_station_index].op1.rob_index <= rob_sigs.val_a_rob_index;
      rs[free_station_index].op2.rob_index <= rob_sigs.val_b_rob_index;
      rs[free_station_index].dst_rob_index <= rob_sigs.dst_rob_index;
      rs[free_station_index].op <= rob_sigs.fu_op;
      rs[free_station_index].entry_valid <= 1;
      rs[free_station_index].nzcv_valid <= rob_nzcv_valid;
      rs[free_station_index].set_nzcv <= rob_set_nzcv;
      rs[free_station_index].nzcv <= rob_nzcv;
      rs[free_station_index].nzcv_rob_index <= rob_nzcv_rob_index;

      if (rob_done & has_free) begin
        `DEBUG(
            ("(in_rs) \tset_nzcv: %0d, use_nzcv: %0d, fu_op: %0d", rob_sigs.nzcv, rob_sigs.uses_nzcv, rob_sigs.fu_op))
        `DEBUG(
            ("(in_rs) \tnzcv: [uses: %0d, valid: %0d, value: %0d, rob_index: %0d],", rob_sigs.uses_nzcv, rob_sigs.nzcv_valid, rob_sigs.nzcv, rob_sigs.nzcv_rob_index))
        `DEBUG(
            ("(in_rs) Adding new entry to in_rs[%0d] for ROB[%0d]", free_station_index, rob_sigs.dst_rob_index))
        `DEBUG(
            ("(in_rs) \tset_nzcv: %0d, use_nzcv: %0d, fu_op: %0d", rob_sigs.set_nzcv, rob_sigs.uses_nzcv, rob_sigs.fu_op))
        `DEBUG(
            ("(in_rs) \top1: [valid: %0d, value: %0d, rob_index: %0d],", rob_sigs.val_a_valid, rob_sigs.val_a_value, rob_sigs.val_a_rob_index))
        `DEBUG(
            ("(in_rs) \top2: [valid: %0d, value: %0d, rob_index: %0d],", rob_sigs.val_b_valid, rob_sigs.val_b_value, rob_sigs.val_b_rob_index))
        `DEBUG(
            ("(in_rs) \tnzcv: [uses: %0d, valid: %0d, value: %0d, rob_index: %0d],", rob_sigs.uses_nzcv, rob_sigs.nzcv_valid, rob_sigs.nzcv, rob_sigs.nzcv_rob_index))
      end
    end : in_rs_add_entry
  end

  always_comb begin
    // Allow the ALU to consume the value when ready
    out_fu_sigs.start = fu_ready & has_ready & ~in_stall;
    out_fu_sigs.fu_op = rs[ready_station_index].op;
    out_fu_sigs.val_a = rs[ready_station_index].op1.value;
    out_fu_sigs.val_b = rs[ready_station_index].op2.value;
    out_fu_sigs.dst_rob_index = rs[ready_station_index].dst_rob_index;
    out_alu_sigs_ext.nzcv = rs[ready_station_index].nzcv;
    out_alu_sigs_ext.set_nzcv = rs[ready_station_index].set_nzcv;
  end


  localparam logic [RS_IDX_SIZE:0] INVALID_INDEX = RS_SIZE;

  // Create bitmap of occupies entries
  logic [RS_IDX_SIZE:0] _free_station_index;
  logic [RS_SIZE:0] occupied_entries;
  assign occupied_entries[INVALID_INDEX] = 0;  // invalid entry always free
  for (genvar i = 0; i < RS_SIZE; i += 1) begin
    assign occupied_entries[i] = rs[i].entry_valid;
  end

  // Create bitmap of ready entries
  logic [RS_IDX_SIZE:0] _ready_station_index;
  logic [RS_SIZE:0] ready_entries;
  assign ready_entries[INVALID_INDEX] = 1;  // invalid entry always ready
  for (genvar i = 0; i < RS_SIZE; i += 1) begin
    assign ready_entries[i] = rs[i].entry_valid & rs[i].op1.valid & rs[i].op2.valid & (rs[i].uses_nczv ? rs[i].nzcv_valid : 1);
  end

  // Do priority encoding
  always_comb begin
    // Priority encoder LUT for most significant 0 bit
    _free_station_index = INVALID_INDEX;
    for (logic [RS_IDX_SIZE:0] i = RS_IDX_SIZE - 1; i < INVALID_INDEX; i -= 1) begin
      if (occupied_entries[i] == 1'b0) _free_station_index = i;
    end

    _ready_station_index = INVALID_INDEX;
    // Priority encoder LUT for most significant 1 bit
    for (logic [RS_IDX_SIZE:0] i = RS_IDX_SIZE - 1; i < INVALID_INDEX; i -= 1) begin
      if (ready_entries[i] == 1'b1) _ready_station_index = i;
    end
  end

  // Set up outputs
  assign free_station_index = _free_station_index[RS_IDX_SIZE-1:0];
  assign has_free = _free_station_index != INVALID_INDEX;
  assign ready_station_index = _ready_station_index[RS_IDX_SIZE-1:0];
  assign has_ready = _ready_station_index != INVALID_INDEX;

endmodule
