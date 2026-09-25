//=============================================================================
// Project      : Moola-V (MR5) Core
// File Name    : moola_fetch.sv
// Description  : Instruction Fetch Stage with PC Generation
//=============================================================================

`timescale 1ns / 1ps

import moola_pkg::*;

module moola_fetch (
  input  logic        clk,
  input  logic        rst_n,

  // Hazard Controls
  input  logic        stall_if,
  input  logic        pc_redirect,
  input  logic [31:0] redirect_target,

  // Instruction Memory Interface
  output logic [31:0] imem_addr,
  output logic        imem_req,

  // Outputs to IF/ID
  output logic [31:0] if_pc,
  output logic [31:0] if_pc_plus_4
);

  localparam logic [31:0] RESET_VECTOR = 32'h8000_0000;
  logic [31:0] pc_reg;
  logic [31:0] next_pc;
  logic [31:0] imem_addr_q;

  // Next PC selection logic
  always_comb begin
    if (pc_redirect) begin
      next_pc = redirect_target;
    end else begin
      next_pc = pc_reg + 32'd4;
    end
  end

  // Program counter register
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      pc_reg <= RESET_VECTOR;
    end else if (!stall_if) begin
      pc_reg <= next_pc;
    end
  end

  // Address presented to synchronous SRAM
  assign imem_addr = (!rst_n) ? RESET_VECTOR : (stall_if ? pc_reg : next_pc);
  assign imem_req  = ~stall_if;

  // Delay the requested address by 1 cycle so that if_pc arriving at the
  // IF/ID pipeline register aligns exactly with imem_rdata from the synchronous SRAM
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      imem_addr_q <= RESET_VECTOR;
    end else if (!stall_if) begin
      imem_addr_q <= imem_addr;
    end
  end

  // Outputs paired with imem_rdata
  assign if_pc        = imem_addr_q;
  assign if_pc_plus_4 = imem_addr_q + 32'd4;

endmodule : moola_fetch