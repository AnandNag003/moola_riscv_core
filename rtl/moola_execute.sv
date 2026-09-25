//=============================================================================
// Project      : Moola-V (MR5) Core
// File Name    : moola_execute.sv
// Description  : Execution Stage Datapath (Instantiates Standalone ALU)
//=============================================================================

`timescale 1ns / 1ps

module moola_execute (
  // Inputs from ID/EX Register
  input  logic [31:0]             ex_pc,
  input  logic [31:0]             ex_imm,
  input  logic [4:0]              ex_rd_addr,
  input  moola_pkg::alu_op_e      ex_alu_op,
  input  moola_pkg::alu_src_a_e   ex_alu_src_a,
  input  moola_pkg::alu_src_b_e   ex_alu_src_b,
  input  moola_pkg::branch_type_e ex_branch_type,
  input  moola_pkg::mem_size_e    ex_mem_size,
  input  logic                    ex_mem_read,
  input  logic                    ex_mem_write,
  input  logic                    ex_reg_write,
  input  moola_pkg::wb_sel_e      ex_wb_sel,

  // Forwarded Operands
  input  logic [31:0]             fwd_rs1_data,
  input  logic [31:0]             fwd_rs2_data,

  // Redirect Outputs
  output logic                    pc_redirect,
  output logic [31:0]             redirect_target,

  // Outputs to EX/MEM Register
  output logic [31:0]             ex_out_pc_plus_4,
  output logic [31:0]             ex_out_alu_result,
  output logic [31:0]             ex_out_rs2_data,
  output logic [4:0]              ex_out_rd_addr,
  output logic                    ex_out_mem_read,
  output logic                    ex_out_mem_write,
  output logic                    ex_out_reg_write,
  output moola_pkg::mem_size_e    ex_out_mem_size,
  output moola_pkg::wb_sel_e      ex_out_wb_sel
);
  import moola_pkg::*;

  logic [31:0] alu_in_a;
  logic [31:0] alu_in_b;
  logic [31:0] alu_result;
  logic        branch_taken;

  // 1. Operand Selection
  assign alu_in_a = (ex_alu_src_a == ALU_SRC_A_PC)  ? ex_pc  : fwd_rs1_data;
  assign alu_in_b = (ex_alu_src_b == ALU_SRC_B_IMM) ? ex_imm : fwd_rs2_data;

  // 2. Standalone ALU Instantiation
  moola_alu u_alu (
    .alu_in_a   (alu_in_a),
    .alu_in_b   (alu_in_b),
    .alu_op     (ex_alu_op),
    .alu_result (alu_result)
  );

  // 3. Branch Evaluation
  always_comb begin
    case (ex_branch_type)
      BR_BEQ:  branch_taken = (fwd_rs1_data == fwd_rs2_data);
      BR_BNE:  branch_taken = (fwd_rs1_data != fwd_rs2_data);
      BR_BLT:  branch_taken = ($signed(fwd_rs1_data) < $signed(fwd_rs2_data));
      BR_BGE:  branch_taken = ($signed(fwd_rs1_data) >= $signed(fwd_rs2_data));
      BR_BLTU: branch_taken = ($unsigned(fwd_rs1_data) < $unsigned(fwd_rs2_data));
      BR_BGEU: branch_taken = ($unsigned(fwd_rs1_data) >= $unsigned(fwd_rs2_data));
      default: branch_taken = 1'b0;
    endcase
  end

  // 4. Branch / Jump Redirect Generation
  always_comb begin
    if (ex_wb_sel == WB_SEL_PC4) begin
      if (ex_alu_src_a == ALU_SRC_A_RS1) begin
        // JALR: Target is (rs1 + imm) & ~1
        pc_redirect     = 1'b1;
        redirect_target = (fwd_rs1_data + ex_imm) & 32'hfffffffe;
      end else begin
        // JAL: Target is (PC + imm) & ~1
        pc_redirect     = 1'b1;
        redirect_target = (ex_pc + ex_imm) & 32'hfffffffe;
      end
    end else if (branch_taken) begin
      // Conditional Branch: Target is (PC + imm) & ~1
      pc_redirect     = 1'b1;
      redirect_target = (ex_pc + ex_imm) & 32'hfffffffe;
    end else begin
      pc_redirect     = 1'b0;
      redirect_target = 32'h0;
    end
  end


  // 5. Outputs to EX/MEM
  assign ex_out_pc_plus_4  = ex_pc + 32'd4;
  assign ex_out_alu_result = alu_result;
  assign ex_out_rs2_data   = fwd_rs2_data;
  assign ex_out_rd_addr    = ex_rd_addr;
  assign ex_out_mem_read   = ex_mem_read;
  assign ex_out_mem_write  = ex_mem_write;
  assign ex_out_reg_write  = ex_reg_write;
  assign ex_out_mem_size   = ex_mem_size;
  assign ex_out_wb_sel     = ex_wb_sel;

endmodule : moola_execute