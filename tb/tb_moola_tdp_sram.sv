//=============================================================================
// Project      : Moola-V (MR5) / Standalone SRAM Verification
// File Name    : tb_moola_tdp_sram.sv
// Description  : Self-Checking Testbench for True Dual-Port Byte-Enable SRAM
//=============================================================================

`timescale 1ns / 1ps

module tb_moola_tdp_sram;

  localparam int DATA_WIDTH = 32;
  localparam int ADDR_WIDTH = 10; // 1024 words depth for quick unit simulation
  localparam int BYTE_WIDTH = 8;
  localparam int NUM_BYTES  = DATA_WIDTH / BYTE_WIDTH;

  // Port A Signals
  logic                  clk_a;
  logic                  en_a;
  logic [NUM_BYTES-1:0]  wstrb_a;
  logic [ADDR_WIDTH-1:0] addr_a;
  logic [DATA_WIDTH-1:0] wdata_a;
  logic [DATA_WIDTH-1:0] rdata_a;

  // Port B Signals
  logic                  clk_b;
  logic                  en_b;
  logic [NUM_BYTES-1:0]  wstrb_b;
  logic [ADDR_WIDTH-1:0] addr_b;
  logic [DATA_WIDTH-1:0] wdata_b;
  logic [DATA_WIDTH-1:0] rdata_b;

  // Verification Counters
  int test_count  = 0;
  int error_count = 0;

  // -------------------------------------------------------------------------
  // DUT Instantiation
  // -------------------------------------------------------------------------
  moola_tdp_sram #(
    .DATA_WIDTH   (DATA_WIDTH),
    .ADDR_WIDTH   (ADDR_WIDTH),
    .BYTE_WIDTH   (BYTE_WIDTH),
    .INIT_FILE_EN (1'b0)
  ) dut (
    .clk_a   (clk_a),
    .en_a    (en_a),
    .wstrb_a (wstrb_a),
    .addr_a  (addr_a),
    .wdata_a (wdata_a),
    .rdata_a (rdata_a),

    .clk_b   (clk_b),
    .en_b    (en_b),
    .wstrb_b (wstrb_b),
    .addr_b  (addr_b),
    .wdata_b (wdata_b),
    .rdata_b (rdata_b)
  );

  // Synchronous Clocks (100 MHz)
  always #5 clk_a = ~clk_a;
  assign clk_b = clk_a; // Test with aligned synchronous clocks

  // -------------------------------------------------------------------------
  // Stimulus & Checks
  // -------------------------------------------------------------------------
  initial begin
    clk_a   = 0;
    en_a    = 0;
    wstrb_a = '0;
    addr_a  = '0;
    wdata_a = '0;

    en_b    = 0;
    wstrb_b = '0;
    addr_b  = '0;
    wdata_b = '0;

    #20;

    $display("\n========================================================");
    $display("       STARTING TRUE DUAL-PORT SRAM VERIFICATION        ");
    $display("========================================================\n");

    // -----------------------------------------------------------------------
    // TEST 1: Basic Full-Word Write (Port A) & Read Back (Port A)
    // -----------------------------------------------------------------------
    @(negedge clk_a);
    en_a    = 1;
    wstrb_a = 4'b1111;
    addr_a  = 10'h010;
    wdata_a = 32'hDEAD_BEEF;

    @(negedge clk_a);
    wstrb_a = 4'b0000; // Read mode
    addr_a  = 10'h010;

    @(posedge clk_a);
    #1; // Synchronous read output valid after rising edge
    test_count++;
    if (rdata_a !== 32'hDEAD_BEEF) begin
      $error("[FAIL] Test %0d: Full-word write/read mismatch. Got 0x%08h, Expected 0xDEADBEEF", test_count, rdata_a);
      error_count++;
    end else begin
      $display("[PASS] Test %02d: Full-Word Write & Read on Port A (Got: 0x%08h)", test_count, rdata_a);
    end

    // -----------------------------------------------------------------------
    // TEST 2: Byte-Mask Writes (Individual Byte Lanes on Port A)
    // Initial: 0xDEAD_BEEF -> Write Byte 0 (0x11), Byte 2 (0x33) -> 0xDE33_BE11
    // -----------------------------------------------------------------------
    @(negedge clk_a);
    en_a    = 1;
    wstrb_a = 4'b0101; // Write bytes 0 and 2 only
    addr_a  = 10'h010;
    wdata_a = 32'h0033_0011;

    @(negedge clk_a);
    wstrb_a = 4'b0000;
    addr_a  = 10'h010;

    @(posedge clk_a);
    #1;
    test_count++;
    if (rdata_a !== 32'hDE33_BE11) begin
      $error("[FAIL] Test %0d: Byte-mask write mismatch. Got 0x%08h, Expected 0xDE33BE11", test_count, rdata_a);
      error_count++;
    end else begin
      $display("[PASS] Test %02d: Byte-Mask Selective Write (Got: 0x%08h)", test_count, rdata_a);
    end

    // -----------------------------------------------------------------------
    // TEST 3: Concurrent Access (Port B Writes Addr 0x020, Port A Reads Addr 0x010)
    // -----------------------------------------------------------------------
    @(negedge clk_a);
    // Port A setup: Read Addr 0x010
    en_a    = 1;
    wstrb_a = 4'b0000;
    addr_a  = 10'h010;

    // Port B setup: Write Addr 0x020
    en_b    = 1;
    wstrb_b = 4'b1111;
    addr_b  = 10'h020;
    wdata_b = 32'hCAFE_BABE;

    @(posedge clk_a);
    #1;
    test_count++;
    if (rdata_a !== 32'hDE33_BE11) begin
      $error("[FAIL] Test %0d: Concurrent access Port A read corrupted. Got 0x%08h, Expected 0xDE33BE11", test_count, rdata_a);
      error_count++;
    end else begin
      $display("[PASS] Test %02d: Concurrent Dual-Port Access (Port A Read 0x%08h)", test_count, rdata_a);
    end

    // -----------------------------------------------------------------------
    // TEST 4: Port A Cross-Reads Address Written by Port B
    // -----------------------------------------------------------------------
    @(negedge clk_a);
    en_b    = 0;
    wstrb_b = 4'b0000;

    en_a    = 1;
    wstrb_a = 4'b0000;
    addr_a  = 10'h020;

    @(posedge clk_a);
    #1;
    test_count++;
    if (rdata_a !== 32'hCAFE_BABE) begin
      $error("[FAIL] Test %0d: Cross-port read mismatch. Got 0x%08h, Expected 0xCAFEBABE", test_count, rdata_a);
      error_count++;
    end else begin
      $display("[PASS] Test %02d: Cross-Port Read (Port A read Port B data: 0x%08h)", test_count, rdata_a);
    end

    // -----------------------------------------------------------------------
    // TEST 5: Chip Enable De-assertion (en = 0 Retains Old rdata)
    // -----------------------------------------------------------------------
    @(negedge clk_a);
    en_a   = 0;
    addr_a = 10'h010; // Address changes, but en_a is LOW

    @(posedge clk_a);
    #1;
    test_count++;
    if (rdata_a !== 32'hCAFE_BABE) begin
      $error("[FAIL] Test %0d: Chip enable gating failed. rdata changed with en_a=0. Got 0x%08h", test_count, rdata_a);
      error_count++;
    end else begin
      $display("[PASS] Test %02d: Chip Enable Gating (rdata held: 0x%08h)", test_count, rdata_a);
    end

    // -----------------------------------------------------------------------
    // Summary
    // -----------------------------------------------------------------------
    $display("\n========================================================");
    if (error_count == 0) begin
      $display("  ALL %0d TDP SRAM UNIT TESTS PASSED SUCCESSFULLY!", test_count);
    end else begin
      $display("  TDP SRAM VERIFICATION FAILED WITH %0d ERRORS.", error_count);
    end
    $display("========================================================\n");
    $finish;
  end

endmodule : tb_moola_tdp_sram