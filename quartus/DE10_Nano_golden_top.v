// ============================================================================
// Copyright (c) 2015 by Terasic Technologies Inc.
// ============================================================================
//
// Permission:
//
//   Terasic grants permission to use and modify this code for use
//   in synthesis for all Terasic Development Boards and Altera Development
//   Kits made by Terasic.  Other use of this code, including the selling
//   ,duplication, or modification of any portion is strictly prohibited.
//
// Disclaimer:
//
//   This VHDL/Verilog or C/C++ source code is intended as a design reference
//   which illustrates how these types of functions can be implemented.
//   It is the user's responsibility to verify their design for
//   consistency and functionality through the use of formal
//   verification methods.  Terasic provides no warranty regarding the use
//   or functionality of this code.
//
// ============================================================================
//
//  Terasic Technologies Inc
//  9F., No.176, Sec.2, Gongdao 5th Rd, East Dist, Hsinchu City, 30070. Taiwan
//
//
//                     web: http://www.terasic.com/
//                     email: support@terasic.com
//
// ============================================================================
//Date:  Tue Mar  3 15:11:40 2015
// ============================================================================

//`define ENABLE_HPS

module DE10_Nano_golden_top(

      ///////// ADC /////////
      output             ADC_CONVST,
      output             ADC_SCK,
      output             ADC_SDI,
      input              ADC_SDO,

      ///////// ARDUINO /////////
      inout       [15:0] ARDUINO_IO,
      inout              ARDUINO_RESET_N,

      ///////// FPGA /////////
      input              FPGA_CLK1_50,
      input              FPGA_CLK2_50,
      input              FPGA_CLK3_50,

      ///////// GPIO /////////
      inout       [35:0] GPIO_0,
      inout       [35:0] GPIO_1,

      ///////// HDMI /////////
      inout              HDMI_I2C_SCL,
      inout              HDMI_I2C_SDA,
      inout              HDMI_I2S,
      inout              HDMI_LRCLK,
      inout              HDMI_MCLK,
      inout              HDMI_SCLK,
      output             HDMI_TX_CLK,
      output      [23:0] HDMI_TX_D,
      output             HDMI_TX_DE,
      output             HDMI_TX_HS,
      input              HDMI_TX_INT,
      output             HDMI_TX_VS,

`ifdef ENABLE_HPS
      ///////// HPS /////////
      inout              HPS_CONV_USB_N,
      output      [14:0] HPS_DDR3_ADDR,
      output      [2:0]  HPS_DDR3_BA,
      output             HPS_DDR3_CAS_N,
      output             HPS_DDR3_CKE,
      output             HPS_DDR3_CK_N,
      output             HPS_DDR3_CK_P,
      output             HPS_DDR3_CS_N,
      output      [3:0]  HPS_DDR3_DM,
      inout       [31:0] HPS_DDR3_DQ,
      inout       [3:0]  HPS_DDR3_DQS_N,
      inout       [3:0]  HPS_DDR3_DQS_P,
      output             HPS_DDR3_ODT,
      output             HPS_DDR3_RAS_N,
      output             HPS_DDR3_RESET_N,
      input              HPS_DDR3_RZQ,
      output             HPS_DDR3_WE_N,
      output             HPS_ENET_GTX_CLK,
      inout              HPS_ENET_INT_N,
      output             HPS_ENET_MDC,
      inout              HPS_ENET_MDIO,
      input              HPS_ENET_RX_CLK,
      input       [3:0]  HPS_ENET_RX_DATA,
      input              HPS_ENET_RX_DV,
      output      [3:0]  HPS_ENET_TX_DATA,
      output             HPS_ENET_TX_EN,
      inout              HPS_GSENSOR_INT,
      inout              HPS_I2C0_SCLK,
      inout              HPS_I2C0_SDAT,
      inout              HPS_I2C1_SCLK,
      inout              HPS_I2C1_SDAT,
      inout              HPS_KEY,
      inout              HPS_LED,
      inout              HPS_LTC_GPIO,
      output             HPS_SD_CLK,
      inout              HPS_SD_CMD,
      inout       [3:0]  HPS_SD_DATA,
      output             HPS_SPIM_CLK,
      input              HPS_SPIM_MISO,
      output             HPS_SPIM_MOSI,
      inout              HPS_SPIM_SS,
      input              HPS_UART_RX,
      output             HPS_UART_TX,
      input              HPS_USB_CLKOUT,
      inout       [7:0]  HPS_USB_DATA,
      input              HPS_USB_DIR,
      input              HPS_USB_NXT,
      output             HPS_USB_STP,
`endif /*ENABLE_HPS*/

      ///////// KEY /////////
      input       [1:0]  KEY,

      ///////// LED /////////
      output      [7:0]  LED,

      ///////// SW /////////
      input       [3:0]  SW
);


//=======================================================
//  REG/WIRE declarations
//=======================================================


//=======================================================
//  Structural coding
//=======================================================

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
    logic [`ROB_SIZE-1:0] rob;
} debug_info;

// Upon a reset signal, the computer should attempt to perform a read from
// a set place in memory. We need to decide where it should read from. On x86,
// this is 0xfffffff0. This is the memory address of the BIOS. The BIOS
// contains the ability to load and run the bootloader. In our machine, the
// BIOS needs to be the code which prepares to receive input from the test
// bench. In other words, the steps are as follows:
// 1. Upon receiving a reset signal, the processor begins executing from
// address 0xfffffff0. This is where our ROM program is. The job of this
// program is to wait for input (via a button), before it begins running
// our testbench.
// 2. We load in the program into memory. The starting memory address must
// always be at a particular location in memory.
// 3. We run the program. Upon the final return, it should return to the loop
// in the BIOS.
//
// So in essence, we are creating a small operating system for our program.
module core #(
    parameter int RS_SIZE = 2,
    parameter int ROB_SIZE = 2
) (
    input logic i_clk,
    input logic i_reset,
		input logic [31:0] i_instruction,
		output logic o_commit,
    output debug_info o_debug
);
    always_ff @(posedge i_clk) begin : main
        if (i_reset) begin
            o_debug.rs[0] <= {1'b0, {`GPR_IDX_SIZE{1'b0}}, `REG_SIZE'b0};
            // NOTE(Nate): Need to use replication for expressions
            o_debug.rob <= 0;
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

    core #(.RS_SIZE(2), .ROB_SIZE(2)) cpu_core (.o_debug(debug_data), .i_clk(clk), .i_reset(reset));

    initial begin
        clk = 0;
        reset = 1;
        #5;
        clk = 1;
        #5;
        clk = 0;
        reset = 0;
        for (int i = 0; i < 8; i++) begin
            #5;
            clk = ~clk;
            $display("\nclk: %b Debug: %x", clk, debug_data.rs[0]);
            $write("Reservation Station: op1_valid: %1h | op1_value: %d | op1_gpr_idx: %d | op2_valid: %d | op2_value: %d | op2_gpr_idx: %d",
                debug_data.rs[0].op1.valid,
                debug_data.rs[0].op1.value,
                debug_data.rs[0].op1.gpr_index,
                debug_data.rs[0].op2.valid,
                debug_data.rs[0].op2.value,
                debug_data.rs[0].op2.gpr_index
            );
        end
    end
endmodule
