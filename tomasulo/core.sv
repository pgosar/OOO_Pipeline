`include "data_structures.sv"

// TODO(Nate): Our nzcv logic is flawed. We currently base a lot of logic based
// on whether we the current instruction will set the nzcv flags or not. This
// is incorrect. A value does not need to wait for the nzcv if it sets nzcv
// flags. It only waits if its operation's result is DEPENDANT upon the current
// nzcv flags. We need extra inputs for this.

module core (
    // input logic in_rst,
    // input logic in_start
    //input logic in_clk
);
  initial begin

    $dumpfile("core.vcd");  // Dump waveform to VCD file
    $dumpvars(0, core);  // Dump all signals
  end

  logic in_rst;
  logic in_clk;

  // for now just run a single cycle
  int   i;
  initial begin
    in_clk = 0;
    for (i = 1; i <= 30; i += 1) begin
      `DEBUG(("\n>>>>> CYCLE COUNT: %0d <<<<<", i));
      #1 in_clk = ~in_clk;  // 100 MHz clock
      #5 in_clk = ~in_clk;
      #4;
    end
  end

  initial begin
    in_rst = 1;
    #10;
    in_rst = 0;
    `DEBUG(("RESET DONE === BEGIN TEST"));
    while (in_fetch_insnbits != 0) begin
      `DEBUG(("itr"));
      `DEBUG(("*******insnbits: %b", in_fetch_insnbits));
      #10;
    end
  end

  logic reset_for_mispred;
  always_ff @(negedge in_clk) begin
    reset_for_mispred = out_fetch_mispredict;
  end

  logic is_mispred_branch;
  logic [`GPR_SIZE-1:0] mispred_new_pc;

  // modules
  fetch f (
      .in_clk,
      .in_rst,
      .in_rob_mispredict(is_mispred_branch),
      .in_rob_new_PC(mispred_new_pc),
      .out_d_sigs(fetch_sigs)
  );

  fetch_interface fetch_sigs ();

  dispatch dp (
      .in_clk,
      .in_rst,
      .in_fetch_sigs(fetch_sigs),
      .out_reg_sigs (d_sigs)
  );

  decode_interface d_sigs ();

  rob_interface_ext_alu rob_alu_sigs ();

  reg_module regfile (
      .in_clk,
      .in_rst,
      .in_d_sigs(d_sigs),
      .in_validate(reset_for_mispred),
      .in_rob_commit_sigs(commit_sigs),
      .in_rob_next_rob_index(next_rob_index),
      .out_rob_sigs(reg_sigs)
  );

  logic next_rob_index;
  reg_interface reg_sigs ();
  rob_commit_interface commit_sigs ();
  integer pending_stur_count;

  rob_module rob (
      .in_rst,
      .in_clk,
      .in_alu_sigs(alu_sigs),
      .in_fu_sigs(alu_sigs_ext),
      .in_reg_sigs(reg_sigs),
      .out_rs_sigs(rob_sigs),
      .out_rs_alu_sigs(rob_alu_sigs),
      .out_rs_broadcast_sigs(rob_broadcast_sigs),
      .out_reg_commit_sigs(commit_sigs),
      .out_reg_next_rob_index(next_rob_index),
      .out_is_mispredict(is_mispred_branch),
      .out_fetch_new_PC(mispred_new_pc),
      .out_rs_pending_stur_count(pending_stur_count)
  );

  rob_interface rob_sigs ();
  rob_broadcast_interface rob_broadcast_sigs ();

  reservation_stations rs (
      .in_clk,
      .in_rst(in_rst | reset_for_mispred),
      .in_fu_alu_ready(alu_ready),
      .in_fu_ls_ready(ls_ready),
      .in_rob_sigs(rob_sigs),
      .in_rob_is_mispred(is_mispred_branch),
      .in_rob_broadcast(rob_broadcast_sigs),
      .out_alu_sigs(alu_sigs),
      .out_alu_sigs_ext(alu_sigs_ext),
      .out_ls_sigs(rs_ls_sigs)
  );

  rs_interface rs_fu_sigs ();
  rs_interface_alu_ext rs_alu_ext_sigs ();
  rs_interface rs_ls_sigs ();
  logic  ls_ready;
  logic  alu_ready;
  logic  fu_rob_done;
  logic  fu_rob_set_nzcv;
  nzcv_t fu_rob_nzcv;
  cond_t fu_rob_alu_cond_codes;
  logic  fu_rob_commit_done;

  func_units fu (
      .in_clk,
      .in_rst,
      .in_rs_alu_sigs(rs_alu_sig),
      .in_rs_alu_sigs_ext(rs_alu_ext_sigs),
      .in_rs_ls_sigs(rs_ls_sigs),
      .in_rob_alu_cond_codes(fu_rob_alu_cond_codes),
      .in_rob_commit_done(fu_rob_commit_done),

      .out_rob_done(fu_rob_done),
      .out_rob_set_nzcv(fu_rob_set_nzcv),
      .out_rob_nzcv(fu_rob_nzcv),
      .out_rob_sigs(rob_sigs),
      .out_rob_alu_sigs(alu_sigs),
      .out_rs_alu_ready(alu_ready),
      .out_rs_ls_ready(ls_ready)
  );

  fu_interface alu_sigs ();
  fu_interface_alu_ext alu_sigs_ext ();
  fu_interface ls_sigs ();
  // fu_interface ls_sigs_ext ();

endmodule

