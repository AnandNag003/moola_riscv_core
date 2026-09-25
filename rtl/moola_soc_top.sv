//=============================================================================
// Project      : Moola-V (MR5) Core
// File Name    : moola_soc_top.sv
// Description  : Top-level integration connecting Moola-V Core to TDP-SRAM
//=============================================================================

`timescale 1ns / 1ps

module moola_soc_top #(
  parameter logic [31:0] BASE_ADDR    = 32'h8000_0000,
  parameter int          ADDR_WIDTH   = 20,              // 16K words = 64 KB
  parameter bit          INIT_FILE_EN = 1'b1,
  parameter       INIT_FILE    = "tb/program.hex"
)(
  input  logic clk,
  input  logic rst_n
  `ifdef VERIFICATION
  ,
  input  logic        load_en,
  output logic        mon_valid,
  output logic [31:0] mon_pc,        // <-- must be [31:0], not just logic mon_pc
  output logic [4:0]  mon_rd_addr,   // <-- must be [4:0],  not just logic mon_rd_addr
  output logic [31:0] mon_rd_data,   // <-- must be [31:0], not just logic mon_rd_data
  output logic        mon_reg_write
`endif
);

  // Core Memory Bus Wires
  logic [31:0] imem_addr;
  logic [31:0] imem_rdata;
  logic        imem_req;

  logic [31:0] dmem_addr;
  logic [31:0] dmem_wdata;
  logic [31:0] dmem_rdata;
  logic [3:0]  dmem_wstrb;
  logic        dmem_req;

  // Synchronous active-high reset for SRAM ports derived from rst_n
  logic sram_rst;
  assign sram_rst = ~rst_n;

  // -------------------------------------------------------------------------
  // 1. Processor Core Instance
  // -------------------------------------------------------------------------
  moola_core u_core (
    .clk        (clk),
    .rst_n      (rst_n),
    .imem_addr  (imem_addr),
    .imem_req   (imem_req),
    .imem_rdata (imem_rdata),
    .dmem_addr  (dmem_addr),
    .dmem_wdata (dmem_wdata),
    .dmem_wstrb (dmem_wstrb),
    .dmem_req   (dmem_req),
    .dmem_rdata (dmem_rdata)

    `ifdef VERIFICATION
  ,
  .mon_valid     (mon_valid),
  .mon_pc        (mon_pc),
  .mon_rd_addr   (mon_rd_addr),
  .mon_rd_data   (mon_rd_data),
  .mon_reg_write (mon_reg_write)
`endif

  );

  // -------------------------------------------------------------------------
  // 2. Address Offset & Word-Indexing Conversion
  // -------------------------------------------------------------------------
  logic [ADDR_WIDTH-1:0] sram_addr_a;
  logic [ADDR_WIDTH-1:0] sram_addr_b;

  // Convert byte addresses relative to BASE_ADDR into word indices
  assign sram_addr_a = (imem_addr - BASE_ADDR) >> 2;
  assign sram_addr_b = (dmem_addr - BASE_ADDR) >> 2;

  // -------------------------------------------------------------------------
  // 3. Generic TDP SRAM Instance (moola_dp_sram)
  // -------------------------------------------------------------------------
  moola_dp_sram #(
    .DATA_WIDTH   (32),
    .ADDR_WIDTH   (ADDR_WIDTH),
    .BYTE_WIDTH   (8),
    .INIT_FILE_EN (INIT_FILE_EN),
    .INIT_FILE    (INIT_FILE)
  ) u_sram (
    // Port A: Instruction Fetch (Read-Only)
    .clk_a   (clk),
    .rst_a   (1'b0),
    .en_a    (imem_req),
    .wstrb_a (4'b0000),
    .addr_a  (sram_addr_a),
    .wdata_a (32'b0),
    .rdata_a (imem_rdata),

    // Port B: Data Access (Read/Write)
    .clk_b   (clk),
    .rst_b   (sram_rst),
    .en_b    (dmem_req),
    .wstrb_b (dmem_wstrb),
    .addr_b  (sram_addr_b),
    .wdata_b (dmem_wdata),
    .rdata_b (dmem_rdata)
  );

`ifdef VERIFICATION
  // Memory loader for Cocotb simulation
  always_ff @(posedge clk) begin
    if (load_en) begin
      u_sram.load_hex("sim_build/program.hex");
    end
  end
`endif

endmodule : moola_soc_top

/*
                             +-------------------------------+
                             |    RTL: moola_dp_sram.sv      |
                             +---------------+---------------+
                                             |
                     +-----------------------+-----------------------+
                     |                                               |
                     v                                               v
        +-------------------------+                     +-------------------------+
        |     FPGA Synthesis      |                     |     ASIC Synthesis      |
        |  (Vivado / Quartus)     |                     | (Yosys / Open-Source)   |
        +------------+------------+                     +------------+------------+
                     |                                               |
                     v                                               v
        +-------------------------+                     +-------------------------+
        | Infers Hard Block RAM   |                     | True Dual Asynch Clocks?|
        | (RAMB36 / RAMB18)       |                     +------------+------------+
        | Low area, zero LUT DFFs |                                  |
        +-------------------------+                 +----------------+----------------+
                                                    |                                 |
                                             YES (clk_a != clk_b)             NO (Unified Clock)
                                                    |                                 |
                                                    v                                 v
                                      +---------------------------+     +---------------------------+
                                      | Leaves $mem_v2 Blackbox   |     | Full Standard Cell Flatten|
                                      | Requires Hard SRAM Macro  |     | 2,112 Sky130 DFF Cells    |
                                      | (e.g., OpenRAM Compiler)  |     | Full Logic Synthesis Done |
                                      +---------------------------+     +---------------------------+
*/


