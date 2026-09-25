//=============================================================================
// Project      : Moola-V (MR5) Core
// File Name    : moola_forwarding_unit.sv
// Description  : EX and MEM Stage RAW Operand Forwarding Unit
//=============================================================================

`timescale 1ns / 1ps

module moola_forwarding_unit (
  input  logic [4:0] id_ex_rs1_addr,
  input  logic [4:0] id_ex_rs2_addr,
  input  logic [4:0] ex_mem_rd_addr,
  input  logic       ex_mem_reg_write,
  input  logic       ex_mem_mem_read,
  input  logic [4:0] mem_wb_rd_addr,
  input  logic       mem_wb_reg_write,
  output logic [1:0] fwd_a_sel,
  output logic [1:0] fwd_b_sel
);

  // Forwarding for RS1 (Operand A)
  always_comb begin
    if (ex_mem_reg_write && (ex_mem_rd_addr != 5'd0) && (ex_mem_rd_addr == id_ex_rs1_addr) && !ex_mem_mem_read) begin
      fwd_a_sel = 2'b01; // Forward from EX/MEM
    end else if (mem_wb_reg_write && (mem_wb_rd_addr != 5'd0) && (mem_wb_rd_addr == id_ex_rs1_addr)) begin
      fwd_a_sel = 2'b10; // Forward from MEM/WB
    end else begin
      fwd_a_sel = 2'b00; // No forwarding
    end
  end

  // Forwarding for RS2 (Operand B)
  always_comb begin
    if (ex_mem_reg_write && (ex_mem_rd_addr != 5'd0) && (ex_mem_rd_addr == id_ex_rs2_addr) && !ex_mem_mem_read) begin
      fwd_b_sel = 2'b01; // Forward from EX/MEM
    end else if (mem_wb_reg_write && (mem_wb_rd_addr != 5'd0) && (mem_wb_rd_addr == id_ex_rs2_addr)) begin
      fwd_b_sel = 2'b10; // Forward from MEM/WB
    end else begin
      fwd_b_sel = 2'b00; // No forwarding
    end
  end

endmodule : moola_forwarding_unit