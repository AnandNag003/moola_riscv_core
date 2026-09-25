//=============================================================================
// Project      : Moola-V (MR5) Core
// File Name    : moola_id_ex_reg.sv
// Description  : ID/EX Inter-Stage Pipeline Register with Flush and Stall
//=============================================================================

`timescale 1ns / 1ps

module moola_id_ex_reg (
  input  logic                 clk,
  input  logic                 rst_n,

  // Hazard Controls
  input  logic                 stall_ex,
  input  logic                 flush_ex,

  // Inputs from Decode
  input  logic [31:0]          dec_pc,
  input  logic [31:0]          dec_rs1_data,
  input  logic [31:0]          dec_rs2_data,
  input  logic [4:0]           dec_rs1_addr,
  input  logic [4:0]           dec_rs2_addr,
  input  logic [4:0]           dec_rd_addr,
  input  logic [31:0]          dec_imm,
  input  moola_pkg::alu_op_e      dec_alu_op,
  input  moola_pkg::alu_src_a_e   dec_alu_src_a,
  input  moola_pkg::alu_src_b_e   dec_alu_src_b,
  input  moola_pkg::branch_type_e dec_branch_type,
  input  logic                 dec_mem_read,
  input  logic                 dec_mem_write,
  input  logic                 dec_reg_write,
  input  moola_pkg::mem_size_e dec_mem_size,
  input  moola_pkg::wb_sel_e   dec_wb_sel,
  input  logic        dec_valid,

  // Outputs to Execute
  output logic        ex_valid,
  output logic [31:0]          ex_pc,
  output logic [31:0]          ex_rs1_data,
  output logic [31:0]          ex_rs2_data,
  output logic [4:0]           ex_rs1_addr,
  output logic [4:0]           ex_rs2_addr,
  output logic [4:0]           ex_rd_addr,
  output logic [31:0]          ex_imm,
  output moola_pkg::alu_op_e      ex_alu_op,
  output moola_pkg::alu_src_a_e   ex_alu_src_a,
  output moola_pkg::alu_src_b_e   ex_alu_src_b,
  output moola_pkg::branch_type_e ex_branch_type,
  output logic                 ex_mem_read,
  output logic                 ex_mem_write,
  output logic                 ex_reg_write,
  output moola_pkg::mem_size_e ex_mem_size,
  output moola_pkg::wb_sel_e   ex_wb_sel
);

  import moola_pkg::*;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n || flush_ex) begin
      ex_valid       <= 1'b0;
      ex_pc          <= 32'h0;
      ex_rs1_data    <= 32'h0;
      ex_rs2_data    <= 32'h0;
      ex_rs1_addr    <= 5'h0;
      ex_rs2_addr    <= 5'h0;
      ex_rd_addr     <= 5'h0;
      ex_imm         <= 32'h0;
      ex_alu_op      <= ALU_ADD;
      ex_alu_src_a   <= ALU_SRC_A_RS1;
      ex_alu_src_b   <= ALU_SRC_B_RS2;
      ex_branch_type <= BR_NONE;
      ex_mem_read    <= 1'b0;
      ex_mem_write   <= 1'b0;
      ex_reg_write   <= 1'b0;
      ex_mem_size    <= MEM_WORD;
      ex_wb_sel      <= WB_SEL_ALU;
    end else if (!stall_ex) begin
      ex_valid       <= dec_valid;
      ex_pc          <= dec_pc;
      ex_rs1_data    <= dec_rs1_data;
      ex_rs2_data    <= dec_rs2_data;
      ex_rs1_addr    <= dec_rs1_addr;
      ex_rs2_addr    <= dec_rs2_addr;
      ex_rd_addr     <= dec_rd_addr;
      ex_imm         <= dec_imm;
      ex_alu_op      <= dec_alu_op;
      ex_alu_src_a   <= dec_alu_src_a;
      ex_alu_src_b   <= dec_alu_src_b;
      ex_branch_type <= dec_branch_type;
      ex_mem_read    <= dec_mem_read;
      ex_mem_write   <= dec_mem_write;
      ex_reg_write   <= dec_reg_write;
      ex_mem_size    <= dec_mem_size;
      ex_wb_sel      <= dec_wb_sel;
    end
  end

endmodule : moola_id_ex_reg