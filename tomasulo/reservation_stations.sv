`include "data_structures.sv"

module reservation_station_module # (
    parameter RS_SIZE = 8
) (
    // Reset
    input logic in_rst,
    input logic in_clk,
    // From Dispatch (sourced from either regfile or ROB)
    input logic in_op1_valid,
    input logic in_op2_valid,
    input logic [`ROB_IDX_SIZE-1:0] in_op1_rob_index,
    input logic [`ROB_IDX_SIZE-1:0] in_op2_rob_index,
    input logic [`GPR_SIZE-1:0] in_op1_value,
    input logic [`GPR_SIZE-1:0] in_op2_value,
    input logic [`GPR_IDX_SIZE-1:0] in_dst,
    input logic in_set_nzcv,
    // From ROB
    input logic in_rob_broadcast_done, // is the rob broadcasting?
    input logic [`ROB_IDX_SIZE-1:0] in_rob_broadcast_index,
    input logic [`GPR_SIZE-1:0] in_rob_broadcast_val,
    input logic in_rob_is_mispred,

    // From FU
    input logic in_fu_ready, // ready to receive inputs
    input logic in_fu_done, // has outputs that must be forwarded
    // For FU
    output logic [`RS_IDX_SIZE:0] out_ready_index // The index of the next RS entry to be consumed
);
    // TODO(Nate): Receive forwarded values from the ALU on negedge of clk.
    // could also be forwarding to FUs, not super sure tho.

    // TODO(Nate): This module is hardcoded for now. LUT should be generated
    // based on parameters
    rs_entry_t [`RS_SIZE-1:0] rs;

    // We include an extra bit to mark whether a reservation station index is
    // invalid or not
    // TODO(Nate): Unhardcode (softcode) this `RS_IDX_SIZE;
    localparam logic [`RS_IDX_SIZE:0] INVALID_INDEX = 4'b1000;

    // Map occupied reservation stations entries to wires. These will be used in
    // a LUT in order to determine the index of the next free entry.
    // If all entries are occupied, the INVALID_INDEX will be set.
    logic [`RS_SIZE-1:0] occupied_entries;
    //TODO: not sure why we have a unoptimizable error here, but looks safe to ignore for now
    // https://github.com/verilator/verilator/issues/63, fix later
    /* verilator lint_off UNOPTFLAT */
    logic [`RS_IDX_SIZE:0] free_station_index;
    for (genvar i = 0; i < `RS_SIZE; i+=1) begin
        assign occupied_entries[i] = rs[i].entry_valid;
    end
    always_comb begin : free_stations
        casez (occupied_entries)
            // Imaginary LUT for 8 values
            // 0 = free, 1 = occupied
            8'b????_???0: free_station_index = 0;
            8'b????_??01: free_station_index = 1;
            8'b????_?011: free_station_index = 2;
            8'b????_0111: free_station_index = 3;
            8'b???0_1111: free_station_index = 4;
            8'b??01_1111: free_station_index = 5;
            8'b?011_1111: free_station_index = 6;
            8'b0111_1111: free_station_index = 7;
            default:      free_station_index = INVALID_INDEX;
        endcase
    end : free_stations

    // Map ready reservation stations entries to wires. These will be used in
    // a LUT in order to determine the index of the next entry to be executed.
    // If none are ready to be executed, the INVALID_INDEX will be set.
    logic [`RS_SIZE-1:0] ready_entries;
    logic [`RS_IDX_SIZE:0] ready_station_index;
    for (genvar i = 0; i < `RS_SIZE; i+=1) begin
        assign ready_entries[i] = rs[i].entry_valid & rs[i].ready;
    end
    always_comb begin : ready_stations
        casez (ready_entries)
            // Imaginary LUT for 8 values
            // 0 = free, 1 = occupied
            8'b1000_0000: ready_station_index = 0;
            8'b?100_0000: ready_station_index = 1;
            8'b??10_0000: ready_station_index = 2;
            8'b???1_0000: ready_station_index = 3;
            8'b????_1000: ready_station_index = 4;
            8'b????_?100: ready_station_index = 5;
            8'b????_??10: ready_station_index = 6;
            8'b????_???1: ready_station_index = 7;
            default:      ready_station_index = INVALID_INDEX;
        endcase
        out_ready_index = ready_station_index;
    end : ready_stations

    for (genvar i = 0; i < `RS_SIZE; i+=1) begin
        assign rs[free_station_index].ready = in_op1_valid & in_op2_valid;
    end

    always_ff @(negedge in_clk) begin
        if (in_rob_is_mispred) begin
            `ifdef DEBUG_PRINT
                $display("(regfile) Deleting mispredicted instructions");
            `endif
            // todo handle mispred
        end
    end

    always_ff @(posedge in_clk) begin
        if (in_rst) begin
            rs <= 0;
        end
        // Add new reservation station entry from dispatch
        if (free_station_index != INVALID_INDEX) begin : update_from_dispatch
            `ifdef DEBUG_PRINT
                $display("(reservation_stations) instantiating RS[%0d]", free_station_index);
            `endif
            rs[free_station_index].op1.value <= in_op1_value;
            rs[free_station_index].op1.rob_index <= in_op1_rob_index;
            rs[free_station_index].op1.valid <= in_op1_valid;
            rs[free_station_index].op2.value <= in_op2_value;
            rs[free_station_index].op2.rob_index <= in_op2_rob_index;
            rs[free_station_index].op2.valid <= in_op2_valid;
            rs[free_station_index].entry_valid <= 1;
            rs[free_station_index].dst_rob_index <= in_dst;
            rs[free_station_index].set_nzcv <= in_set_nzcv;
        end : update_from_dispatch
        // Update entry because FU has consumed the value. This will execute
        // in lockstep with the FU actually consuming the value.
        if (ready_station_index != INVALID_INDEX) begin : fu_consume_entry
            // Delay updating to account for hold time
            `ifdef DEBUG_PRINT
                $display("(reservation_stations) FU consumed RS[%0d]", ready_station_index);
            `endif
            #1 rs[ready_station_index].ready <= ~in_fu_ready;
        end : fu_consume_entry
        // TODO(Nate): Add case for updating from rob broadcast
        if (in_rob_broadcast_done) begin : rob_broadcast_update
            `ifdef DEBUG_PRINT
                $display("(reservation_stations) Updating from ROB broadcast");
            `endif
            if (!in_rob_is_mispred) begin
                `ifdef DEBUG_PRINT
                    $display("(reservation_stations) not mispredicted");
                `endif
                for (int i = 0; i < `RS_SIZE; i+=1) begin
                    if (rs[i].entry_valid) begin // Unnecessary check, but will help energy
                        if (rs[i].op1.rob_index == in_rob_broadcast_index) begin
                            `ifdef DEBUG_PRINT
                                $display("(reservation_stations) not mispred Updating RS[%0d] op1",
                                          i);
                            `endif
                            rs[i].op1.value <= in_rob_broadcast_val;
                            rs[i].op1.valid <= 1;
                        end
                        if (rs[i].op2.rob_index == in_rob_broadcast_index) begin
                            `ifdef DEBUG_PRINT
                                $display("(reservation_stations) not mispred Updating RS[%0d] op2",
                                          i);
                            `endif
                            rs[i].op2.value <= in_rob_broadcast_val;
                            rs[i].op1.valid <= 1;
                        end
                    end
                end
            end else begin // Mispred broadcast
                // for (int i = 0; i < `RS_SIZE; i+=1) begin
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
        end
    end
endmodule
