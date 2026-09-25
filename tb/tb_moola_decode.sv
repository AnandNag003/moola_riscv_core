//=============================================================================
// Project      : Moola-V (MR5) Core Verification
// File Name    : tb_moola_decode.sv
// Description  : Self-Checking Testbench for Instruction Decode & ImmGen
//=============================================================================

`timescale 1ns / 1ps

module tb_moola_decode;
  import moola_pkg::*;

  // DUT Inputs
  if_id_payload_t if_id_in;
  logic [31:0]    rf_rs1_data;
  logic [31:0]    rf_rs2_data;

  // DUT Outputs
  logic [4:0]     rf_rs1_addr;
  logic [4:0]     rf_rs2_addr;
  id_ex_payload_t id_ex_payload_d;

  // Tracking Counters
  int test_count  = 0;
  int error_count = 0;

  // -------------------------------------------------------------------------
  // DUT Instantiation
  // -------------------------------------------------------------------------
  moola_decode dut (
    .if_id_in        (if_id_in),
    .rf_rs1_data     (rf_rs1_data),
    .rf_rs2_data     (rf_rs2_data),
    .rf_rs1_addr     (rf_rs1_addr),
    .rf_rs2_addr     (rf_rs2_addr),
    .id_ex_payload_d (id_ex_payload_d)
  );

  // -------------------------------------------------------------------------
  // Generic Check Task
  // -------------------------------------------------------------------------
  task check_decode(
    input logic [31:0] inst,
    input logic [31:0] pc,
    input logic [4:0]  exp_rs1,
    input logic [4:0]  exp_rs2,
    input logic [4:0]  exp_rd,
    input logic [31:0] exp_imm,
    input alu_op_e     exp_alu_op,
    input alu_src_a_e  exp_src_a,
    input alu_src_b_e  exp_src_b,
    input wb_sel_e     exp_wb_sel,
    input logic        exp_mem_read,
    input logic        exp_mem_write,
    input string       test_name
  );
    if_id_in.inst      = inst;
    if_id_in.pc        = pc;
    if_id_in.pc_plus_4 = pc + 4;
    rf_rs1_data        = 32'hAAAA_AAAA;
    rf_rs2_data        = 32'h5555_5555;
    #1; // Allow combinational logic to settle

    test_count++;

    if ((rf_rs1_addr !== exp_rs1) ||
        (rf_rs2_addr !== exp_rs2) ||
        (id_ex_payload_d.rd_addr !== exp_rd) ||
        (id_ex_payload_d.imm !== exp_imm) ||
        (id_ex_payload_d.alu_op !== exp_alu_op) ||
        (id_ex_payload_d.alu_src_a !== exp_src_a) ||
        (id_ex_payload_d.alu_src_b !== exp_src_b) ||
        (id_ex_payload_d.wb_sel !== exp_wb_sel) ||
        (id_ex_payload_d.mem_read !== exp_mem_read) ||
        (id_ex_payload_d.mem_write !== exp_mem_write)) begin
      $error("[FAIL] Test %02d: %s", test_count, test_name);
      $display("\tExpected: rs1=%0d, rs2=%0d, rd=%0d, imm=0x%08h, mem_r=%b, mem_w=%b",
               exp_rs1, exp_rs2, exp_rd, exp_imm, exp_mem_read, exp_mem_write);
      $display("\tGot:      rs1=%0d, rs2=%0d, rd=%0d, imm=0x%08h, mem_r=%b, mem_w=%b",
               rf_rs1_addr, rf_rs2_addr, id_ex_payload_d.rd_addr, id_ex_payload_d.imm, id_ex_payload_d.mem_read, id_ex_payload_d.mem_write);
      error_count++;
    end else begin
      $display("[PASS] Test %02d: %-38s (Imm: 0x%08h, rd: x%02d)", test_count, test_name, id_ex_payload_d.imm, id_ex_payload_d.rd_addr);
    end
  endtask

  // -------------------------------------------------------------------------
  // Test Stimulus Across Instruction Formats
  // -------------------------------------------------------------------------
  initial begin
    $display("\n========================================================");
    $display("     STARTING MOOLA-V DECODE & IMMGEN VERIFICATION      ");
    $display("========================================================\n");

    // 1. R-Type: ADD x3, x1, x2 (0x002081B3)
    check_decode(
      .inst          (32'h002081B3),
      .pc            (32'h8000_0000),
      .exp_rs1       (5'd1),
      .exp_rs2       (5'd2),
      .exp_rd        (5'd3),
      .exp_imm       (32'h0000_0000),
      .exp_alu_op    (ALU_ADD),
      .exp_src_a     (ALU_SRC_A_RS1),
      .exp_src_b     (ALU_SRC_B_RS2),
      .exp_wb_sel    (WB_SEL_ALU),
      .exp_mem_read  (1'b0),
      .exp_mem_write (1'b0),
      .test_name     ("R-Type: ADD x3, x1, x2")
    );

    // 2. I-Type (Arithmetic): ADDI x5, x1, -1 (0xFFF08293)
    check_decode(
      .inst          (32'hFFF08293),
      .pc            (32'h8000_0004),
      .exp_rs1       (5'd1),
      .exp_rs2       (5'd0),
      .exp_rd        (5'd5),
      .exp_imm       (32'hFFFF_FFFF),
      .exp_alu_op    (ALU_ADD),
      .exp_src_a     (ALU_SRC_A_RS1),
      .exp_src_b     (ALU_SRC_B_IMM),
      .exp_wb_sel    (WB_SEL_ALU),
      .exp_mem_read  (1'b0),
      .exp_mem_write (1'b0),
      .test_name     ("I-Type: ADDI x5, x1, -1 (Negative Imm)")
    );

    // 3. I-Type (Load): LW x6, 8(x1) (0x0080A303)
    check_decode(
      .inst          (32'h0080A303),
      .pc            (32'h8000_0008),
      .exp_rs1       (5'd1),
      .exp_rs2       (5'd0),
      .exp_rd        (5'd6),
      .exp_imm       (32'h0000_0008),
      .exp_alu_op    (ALU_ADD),
      .exp_src_a     (ALU_SRC_A_RS1),
      .exp_src_b     (ALU_SRC_B_IMM),
      .exp_wb_sel    (WB_SEL_MEM),
      .exp_mem_read  (1'b1),
      .exp_mem_write (1'b0),
      .test_name     ("I-Type Load: LW x6, 8(x1)")
    );

    // 4. S-Type (Store): SW x2, -4(x1) (0xFE20AE23)
    check_decode(
      .inst          (32'hFE20AE23),
      .pc            (32'h8000_000C),
      .exp_rs1       (5'd1),
      .exp_rs2       (5'd2),
      .exp_rd        (5'd0),
      .exp_imm       (32'hFFFF_FFFC),
      .exp_alu_op    (ALU_ADD),
      .exp_src_a     (ALU_SRC_A_RS1),
      .exp_src_b     (ALU_SRC_B_IMM),
      .exp_wb_sel    (WB_SEL_ALU),
      .exp_mem_read  (1'b0),
      .exp_mem_write (1'b1),
      .test_name     ("S-Type Store: SW x2, -4(x1)")
    );

    // 5. B-Type (Branch): BEQ x1, x2, -8 (0xFE208CE3)
    check_decode(
      .inst          (32'hFE208CE3),
      .pc            (32'h8000_0010),
      .exp_rs1       (5'd1),
      .exp_rs2       (5'd2),
      .exp_rd        (5'd0),
      .exp_imm       (32'hFFFF_FFF8),
      .exp_alu_op    (ALU_SUB),
      .exp_src_a     (ALU_SRC_A_PC),
      .exp_src_b     (ALU_SRC_B_IMM),
      .exp_wb_sel    (WB_SEL_ALU),
      .exp_mem_read  (1'b0),
      .exp_mem_write (1'b0),
      .test_name     ("B-Type Branch: BEQ x1, x2, -8")
    );

    // 6. U-Type: LUI x10, 0x12345 (0x12345537)
    check_decode(
      .inst          (32'h12345537),
      .pc            (32'h8000_0014),
      .exp_rs1       (5'd0),
      .exp_rs2       (5'd0),
      .exp_rd        (5'd10),
      .exp_imm       (32'h1234_5000),
      .exp_alu_op    (ALU_ADD),
      .exp_src_a     (ALU_SRC_A_RS1),
      .exp_src_b     (ALU_SRC_B_IMM),
      .exp_wb_sel    (WB_SEL_ALU),
      .exp_mem_read  (1'b0),
      .exp_mem_write (1'b0),
      .test_name     ("U-Type: LUI x10, 0x12345")
    );

    // 7. J-Type (Jump): JAL x1, -16 (0xFF1FF0EF)
    check_decode(
      .inst          (32'hFF1FF0EF),
      .pc            (32'h8000_0018),
      .exp_rs1       (5'd0),
      .exp_rs2       (5'd0),
      .exp_rd        (5'd1),
      .exp_imm       (32'hFFFF_FFF0),
      .exp_alu_op    (ALU_ADD),
      .exp_src_a     (ALU_SRC_A_PC),
      .exp_src_b     (ALU_SRC_B_IMM),
      .exp_wb_sel    (WB_SEL_PC4),
      .exp_mem_read  (1'b0),
      .exp_mem_write (1'b0),
      .test_name     ("J-Type Jump: JAL x1, -16")
    );

    // Summary Output
    $display("\n========================================================");
    if (error_count == 0) begin
      $display("  ALL %0d DECODE & IMMGEN TESTS PASSED SUCCESSFULLY!", test_count);
    end else begin
      $display("  DECODE VERIFICATION FAILED WITH %0d ERRORS.", error_count);
    end
    $display("========================================================\n");
    $finish;
  end

endmodule : tb_moola_decode