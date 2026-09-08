//=============================================================================
// Project      : Moola-V (MR5) Core Verification
// File Name    : tb_moola_alu.sv
// Description  : Directed & Corner-Case Self-Checking Testbench for moola_alu
//=============================================================================

`timescale 1ns / 1ps

module tb_moola_alu;
  import moola_pkg::*;

  // DUT Interface Wires
  logic [31:0]  alu_in_a;
  logic [31:0]  alu_in_b;
  alu_op_e      alu_op;
  logic [31:0]  alu_result;

  // Verification Tracking
  int error_count = 0;
  int test_count  = 0;

  // -------------------------------------------------------------------------
  // DUT Instantiation
  // -------------------------------------------------------------------------
  moola_alu dut (
    .alu_in_a   (alu_in_a),
    .alu_in_b   (alu_in_b),
    .alu_op     (alu_op),
    .alu_result (alu_result)
  );
  
  initial begin
        $dumpfile("sim/alu_sim.vcd");
        $dumpvars(0, tb_moola_alu);
    end
  // -------------------------------------------------------------------------
  // Self-Checking Verification Task
  // -------------------------------------------------------------------------
  task check_alu(
    input logic [31:0] in_a,
    input logic [31:0] in_b,
    input alu_op_e     op,
    input logic [31:0] expected_out,
    input string       test_name
  );
    alu_in_a = in_a;
    alu_in_b = in_b;
    alu_op   = op;
    #1; // Allow combinational propagation through DUT

    test_count++;
    if (alu_result !== expected_out) begin
      $error("[FAIL] Test: %s | Op: %s | A: 0x%08h, B: 0x%08h | Got: 0x%08h, Expected: 0x%08h",
             test_name, op.name(), in_a, in_b, alu_result, expected_out);
      error_count++;
    end else begin
      $display("[PASS] Test %02d: %-38s (Got: 0x%08h)", test_count, test_name, alu_result);
    end
  endtask

  // -------------------------------------------------------------------------
  // Test Stimulus
  // -------------------------------------------------------------------------
  initial begin
    $display("\n========================================================");
    $display("       STARTING MOOLA-V ALU DUT VERIFICATION            ");
    $display("========================================================\n");

    // 1. ADD / SUB Tests
    check_alu(32'd10, 32'd20, ALU_ADD, 32'd30, "ADD: Simple Positive");
    check_alu(32'hFFFF_FFFF, 32'd1, ALU_ADD, 32'h0000_0000, "ADD: Overflow Wrap-around");
    check_alu(32'd30, 32'd10, ALU_SUB, 32'd20, "SUB: Simple Positive");
    check_alu(32'd0, 32'd1, ALU_SUB, 32'hFFFF_FFFF, "SUB: Underflow Wrap-around (-1)");

    // 2. Logic Tests
    check_alu(32'hF0F0_AAAA, 32'h0F0F_5555, ALU_XOR, 32'hFFFF_FFFF, "XOR: Alternating Bit Pattern");
    check_alu(32'hF0F0_AAAA, 32'h0F0F_5555, ALU_OR,  32'hFFFF_FFFF, "OR: Bitwise Set");
    check_alu(32'hFFFF_0000, 32'hFF00_FF00, ALU_AND, 32'hFF00_0000, "AND: Mask Operation");

    // 3. Shifts (Logical vs Arithmetic)
    check_alu(32'h0000_0001, 32'd4,  ALU_SLL, 32'h0000_0010, "SLL: Simple Left Shift");
    check_alu(32'h8000_0000, 32'd4,  ALU_SRL, 32'h0800_0000, "SRL: Zero-fill Right Shift");
    check_alu(32'h8000_0000, 32'd4,  ALU_SRA, 32'hF800_0000, "SRA: Sign-extended Right Shift");
    check_alu(32'hFFFF_FFFF, 32'd36, ALU_SLL, 32'hFFFF_FFF0, "SLL: Shift Masking (36 & 0x1F = 4)");

    // 4. Comparison Corner Cases (Signed vs Unsigned)
    check_alu(32'hFFFF_FFFF, 32'd1, ALU_SLT,  32'd1, "SLT: -1 < 1 (Signed True)");
    check_alu(32'hFFFF_FFFF, 32'd1, ALU_SLTU, 32'd0, "SLTU: 0xFFFFFFFF < 1 (Unsigned False)");
    check_alu(32'd10, 32'd10, ALU_SLT,  32'd0, "SLT: Equal values (False)");
    check_alu(32'd10, 32'd10, ALU_SLTU, 32'd0, "SLTU: Equal values (False)");

    $display("\n========================================================");
    if (error_count == 0) begin
      $display("  ALL %0d ALU DUT TESTS PASSED SUCCESSFULLY!", test_count);
    end else begin
      $display("  ALU DUT VERIFICATION FAILED WITH %0d ERRORS.", error_count);
    end
    $display("========================================================\n");
    $finish;
  end

endmodule : tb_moola_alu