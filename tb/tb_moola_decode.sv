//=============================================================================
// Project      : Moola-V (MR5) Core Verification
// File Name    : tb_moola_decode.sv
// Description  : Self-Checking Testbench for Instruction Decode & ImmGen
//=============================================================================

`timescale 1ns / 1ps

module tb_moola_decode;
  import moola_pkg::*;

  // DUT Inputs
  logic [31:0] id_pc;
  logic [31:0] id_pc_plus_4;
  logic [31:0] id_inst;
  logic [31:0] rf_rs1_data;
  logic [31:0] rf_rs2_data;

  // DUT Outputs (Flat signals - Icarus Verilog safe)
  logic [4:0]              rf_rs1_addr;
  logic [4:0]              rf_rs2_addr;
  logic [31:0]             dec_pc;
  logic [31:0]             dec_rs1_data;
  logic [31:0]             dec_rs2_data;
  logic [4:0]              dec_rs1_addr;
  logic [4:0]              dec_rs2_addr;
  logic [4:0]              dec_rd_addr;
  logic [31:0]             dec_imm;
  moola_pkg::alu_op_e      dec_alu_op;
  moola_pkg::alu_src_a_e   dec_alu_src_a;
  moola_pkg::alu_src_b_e   dec_alu_src_b;
  moola_pkg::branch_type_e dec_branch_type;
  logic                    dec_mem_read;
  logic                    dec_mem_write;
  logic                    dec_reg_write;
  moola_pkg::wb_sel_e      dec_wb_sel;

  // Tracking Counters
  int test_count  = 0;
  int error_count = 0;

  // -------------------------------------------------------------------------
  // DUT Instantiation
  // -------------------------------------------------------------------------
  moola_decode dut (
    .id_pc           (id_pc),
    .id_pc_plus_4    (id_pc_plus_4),
    .id_inst         (id_inst),
    .rf_rs1_data     (rf_rs1_data),
    .rf_rs2_data     (rf_rs2_data),
    .rf_rs1_addr     (rf_rs1_addr),
    .rf_rs2_addr     (rf_rs2_addr),
    .dec_pc          (dec_pc),
    .dec_rs1_data    (dec_rs1_data),
    .dec_rs2_data    (dec_rs2_data),
    .dec_rs1_addr    (dec_rs1_addr),
    .dec_rs2_addr    (dec_rs2_addr),
    .dec_rd_addr     (dec_rd_addr),
    .dec_imm         (dec_imm),
    .dec_alu_op      (dec_alu_op),
    .dec_alu_src_a   (dec_alu_src_a),
    .dec_alu_src_b   (dec_alu_src_b),
    .dec_branch_type (dec_branch_type),
    .dec_mem_read    (dec_mem_read),
    .dec_mem_write   (dec_mem_write),
    .dec_reg_write   (dec_reg_write),
    .dec_wb_sel      (dec_wb_sel)
  );

  initial begin
    $dumpfile("sim/decode_sim.vcd");
    $dumpvars(0, tb_moola_decode);
  end

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
    id_inst      = inst;
    id_pc        = pc;
    id_pc_plus_4 = pc + 4;
    rf_rs1_data  = 32'hAAAA_AAAA;
    rf_rs2_data  = 32'h5555_5555;
    #1; // Allow combinational logic to settle

    test_count++;

    if ((rf_rs1_addr !== exp_rs1) ||
        (rf_rs2_addr !== exp_rs2) ||
        (dec_rd_addr !== exp_rd) ||
        (dec_imm !== exp_imm) ||
        (dec_alu_op !== exp_alu_op) ||
        (dec_alu_src_a !== exp_src_a) ||
        (dec_alu_src_b !== exp_src_b) ||
        (dec_wb_sel !== exp_wb_sel) ||
        (dec_mem_read !== exp_mem_read) ||
        (dec_mem_write !== exp_mem_write)) begin
      $error("[FAIL] Test %02d: %s", test_count, test_name);
      $display("\tExpected: rs1=%0d, rs2=%0d, rd=%0d, imm=0x%08h, mem_r=%b, mem_w=%b",
               exp_rs1, exp_rs2, exp_rd, exp_imm, exp_mem_read, exp_mem_write);
      $display("\tGot:      rs1=%0d, rs2=%0d, rd=%0d, imm=0x%08h, mem_r=%b, mem_w=%b",
               rf_rs1_addr, rf_rs2_addr, dec_rd_addr, dec_imm, dec_mem_read, dec_mem_write);
      error_count++;
    end else begin
      $display("[PASS] Test %02d: %-38s (Imm: 0x%08h, rd: x%02d)", test_count, test_name, dec_imm, dec_rd_addr);
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