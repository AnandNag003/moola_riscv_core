//=============================================================================
// Project      : Moola-V (MR5) Core Verification
// File Name    : tb_moola_regfile.sv
// Description  : Self-Checking Testbench for Register File (x0 & Internal Bypass)
//=============================================================================

`timescale 1ns / 1ps

module tb_moola_regfile;

  logic        clk;
  logic        rst_n;

  logic [4:0]  rs1_addr;
  logic [31:0] rs1_data;

  logic [4:0]  rs2_addr;
  logic [31:0] rs2_data;

  logic        reg_write;
  logic [4:0]  rd_addr;
  logic [31:0] rd_data;

  int error_count = 0;

  // Instantiate DUT
  moola_regfile dut (
    .clk       (clk),
    .rst_n     (rst_n),
    .rs1_addr  (rs1_addr),
    .rs1_data  (rs1_data),
    .rs2_addr  (rs2_addr),
    .rs2_data  (rs2_data),
    .reg_write (reg_write),
    .rd_addr   (rd_addr),
    .rd_data   (rd_data)
  );

  // Clock Generation (100 MHz)
  always #5 clk = ~clk;

  initial begin
    clk       = 0;
    rst_n     = 0;
    rs1_addr  = 0;
    rs2_addr  = 0;
    reg_write = 0;
    rd_addr   = 0;
    rd_data   = 0;

    // Reset sequence
    #20 rst_n = 1;
    #10;

    $display("\n--- TEST 1: Write and Read General Purpose Registers (x1, x2) ---");
    @(negedge clk);
    reg_write = 1; rd_addr = 5'd1; rd_data = 32'hDEAD_BEEF;
    @(negedge clk);
    reg_write = 1; rd_addr = 5'd2; rd_data = 32'hCAFE_BABE;
    @(negedge clk);
    reg_write = 0;

    // Read back
    rs1_addr = 5'd1;
    rs2_addr = 5'd2;
    #1;
    if (rs1_data !== 32'hDEAD_BEEF || rs2_data !== 32'hCAFE_BABE) begin
      $error("[FAIL] Reg Read Mismatch: x1=0x%08h, x2=0x%08h", rs1_data, rs2_data);
      error_count++;
    end else begin
      $display("[PASS] Read x1=0x%08h, x2=0x%08h", rs1_data, rs2_data);
    end

    $display("\n--- TEST 2: Hardwired x0 Invariance Check ---");
    @(negedge clk);
    reg_write = 1; rd_addr = 5'd0; rd_data = 32'hFFFF_FFFF; // Attempt overwrite x0
    @(negedge clk);
    reg_write = 0;
    rs1_addr = 5'd0;
    #1;
    if (rs1_data !== 32'h0) begin
      $error("[FAIL] x0 was modified! Got: 0x%08h", rs1_data);
      error_count++;
    end else begin
      $display("[PASS] x0 remains hardwired to 0x00000000 after write attempt.");
    end

    $display("\n--- TEST 3: Same-Cycle Write-Through Bypass Check ---");
    @(negedge clk);
    // Write to x3 and read from x3 simultaneously
    reg_write = 1; rd_addr = 5'd3; rd_data = 32'h1234_5678;
    rs1_addr  = 5'd3;
    #1;
    if (rs1_data !== 32'h1234_5678) begin
      $error("[FAIL] Write-through bypass failed! Got: 0x%08h, Expected: 0x12345678", rs1_data);
      error_count++;
    end else begin
      $display("[PASS] Same-cycle bypass successful: x3 read 0x%08h combinationally.", rs1_data);
    end

    @(negedge clk);
    reg_write = 0;

    $display("\n========================================================");
    if (error_count == 0) $display("  ALL REGFILE UNIT TESTS PASSED!");
    else                  $display("  REGFILE TESTS FAILED WITH %0d ERRORS.", error_count);
    $display("========================================================\n");
    $finish;
  end

endmodule : tb_moola_regfile