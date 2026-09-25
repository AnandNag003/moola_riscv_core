//=============================================================================
// Project      : Moola-V (MR5) Core
// File Name    : moola_ex_mem_reg.sv
// Description  : EX/MEM Inter-Stage Pipeline Register with Flush and Stall
//=============================================================================

`timescale 1ns / 1ps

module moola_ex_mem_reg (
  input  logic                 clk,
  input  logic                 rst_n,

  // Hazard Controls
  input  logic                 stall_mem,
  input  logic                 flush_mem,

  // Inputs from Execute
  input  logic [31:0]          ex_out_pc_plus_4,
  input  logic [31:0]          ex_out_alu_result,
  input  logic [31:0]          ex_out_rs2_data,
  input  logic [4:0]           ex_out_rd_addr,
  input  logic                 ex_out_mem_read,
  input  logic                 ex_out_mem_write,
  input  logic                 ex_out_reg_write,
  input  moola_pkg::mem_size_e ex_out_mem_size,
  input  moola_pkg::wb_sel_e   ex_out_wb_sel,
  input  logic                 ex_out_valid,

  // Outputs to Memory Stage
  output logic                 mem_valid,
  output logic [31:0]          mem_pc_plus_4,
  output logic [31:0]          mem_alu_result,
  output logic [31:0]          mem_rs2_data,
  output logic [4:0]           mem_rd_addr,
  output logic                 mem_mem_read,
  output logic                 mem_mem_write,
  output logic                 mem_reg_write,
  output moola_pkg::mem_size_e mem_mem_size,
  output moola_pkg::wb_sel_e   mem_wb_sel
);

  import moola_pkg::*;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n || flush_mem) begin
      mem_valid      <= 1'b0;
      mem_pc_plus_4  <= 32'h0;
      mem_alu_result <= 32'h0;
      mem_rs2_data   <= 32'h0;
      mem_rd_addr    <= 5'h0;
      mem_mem_read   <= 1'b0;
      mem_mem_write  <= 1'b0;
      mem_reg_write  <= 1'b0;
      mem_mem_size   <= MEM_WORD;
      mem_wb_sel     <= WB_SEL_ALU;
    end else if (!stall_mem) begin
      mem_valid      <= ex_out_valid;
      mem_pc_plus_4  <= ex_out_pc_plus_4;
      mem_alu_result <= ex_out_alu_result;
      mem_rs2_data   <= ex_out_rs2_data;
      mem_rd_addr    <= ex_out_rd_addr;
      mem_mem_read   <= ex_out_mem_read;
      mem_mem_write  <= ex_out_mem_write;
      mem_reg_write  <= ex_out_reg_write;
      mem_mem_size   <= ex_out_mem_size;
      mem_wb_sel     <= ex_out_wb_sel;
    end
  end

endmodule : moola_ex_mem_reg