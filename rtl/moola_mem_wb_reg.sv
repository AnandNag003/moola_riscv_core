//=============================================================================
// Project      : Moola-V (MR5) Core
// File Name    : moola_mem_wb_reg.sv
// Description  : MEM/WB Inter-Stage Pipeline Register with Flush and Stall
//=============================================================================

`timescale 1ns / 1ps

module moola_mem_wb_reg (
  input  logic                 clk,
  input  logic                 rst_n,

  // Hazard Controls
  input  logic                 stall_wb,
  input  logic                 flush_wb,

  // Inputs from Memory Stage
  input  logic [31:0]          mem_out_pc_plus_4,
  input  logic [31:0]          mem_out_alu_result,
  input  logic [31:0]          mem_out_rdata,
  input  logic [4:0]           mem_out_rd_addr,
  input  logic                 mem_out_reg_write,
  input  moola_pkg::mem_size_e mem_out_mem_size,
  input  moola_pkg::wb_sel_e   mem_out_wb_sel,
  input  logic                 mem_out_valid, 

  // Outputs to Write-Back Mux & Register File
  output logic                 wb_valid,
  output logic [31:0]          wb_pc_plus_4,
  output logic [31:0]          wb_alu_result,
  output logic [31:0]          wb_mem_rdata,
  output logic [4:0]           wb_rd_addr,
  output logic                 wb_reg_write,
  output moola_pkg::mem_size_e wb_mem_size,
  output moola_pkg::wb_sel_e   wb_wb_sel
);
  import moola_pkg::*;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n || flush_wb) begin
      wb_valid      <= 1'b0;
      wb_pc_plus_4  <= 32'h0;
      wb_alu_result <= 32'h0;
      wb_mem_rdata  <= 32'h0;
      wb_rd_addr    <= 5'h0;
      wb_reg_write  <= 1'b0;
      wb_mem_size   <= MEM_WORD;
      wb_wb_sel     <= WB_SEL_ALU;
    end else if (!stall_wb) begin
      wb_valid      <= mem_out_valid;
      wb_pc_plus_4  <= mem_out_pc_plus_4;
      wb_alu_result <= mem_out_alu_result;
      wb_mem_rdata  <= mem_out_rdata;
      wb_rd_addr    <= mem_out_rd_addr;
      wb_reg_write  <= mem_out_reg_write;
      wb_mem_size   <= mem_out_mem_size;
      wb_wb_sel     <= mem_out_wb_sel;
    end
  end

endmodule : moola_mem_wb_reg