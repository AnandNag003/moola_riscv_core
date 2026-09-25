//=============================================================================
// Project      : Moola-V (MR5) Core
// File Name    : moola_memory.sv
// Description  : Memory Access Stage & Byte Alignment Formatter
//=============================================================================

`timescale 1ns / 1ps

module moola_memory (
  // Inputs from EX/MEM
  input  logic [31:0]          mem_pc_plus_4,
  input  logic [31:0]          mem_alu_result,
  input  logic [31:0]          mem_rs2_data,
  input  logic [4:0]           mem_rd_addr,
  input  logic                 mem_mem_read,
  input  logic                 mem_mem_write,
  input  logic                 mem_reg_write,
  input  moola_pkg::mem_size_e mem_mem_size,
  input  moola_pkg::wb_sel_e   mem_wb_sel,

  // Memory Interface
  output logic [31:0]          dmem_addr,
  output logic [31:0]          dmem_wdata,
  output logic [3:0]           dmem_wstrb,
  output logic                 dmem_req,
  input  logic [31:0]          dmem_rdata,

  // Outputs to MEM/WB Register
  output logic [31:0]          mem_out_pc_plus_4,
  output logic [31:0]          mem_out_alu_result,
  output logic [31:0]          mem_out_rdata,
  output logic [4:0]           mem_out_rd_addr,
  output logic                 mem_out_reg_write,
  output moola_pkg::mem_size_e mem_out_mem_size,
  output moola_pkg::wb_sel_e   mem_out_wb_sel
);
  import moola_pkg::*;

  assign dmem_addr = mem_alu_result;
  assign dmem_req  = mem_mem_read | mem_mem_write;

  // -------------------------------------------------------------------------
  // Store Byte Strobe & Alignment (SB, SH, SW)
  // -------------------------------------------------------------------------
  always_comb begin
    if (mem_mem_write) begin
      case (mem_mem_size)
        MEM_BYTE: begin // SB
          case (mem_alu_result[1:0])
            2'b00: begin dmem_wstrb = 4'b0001; dmem_wdata = {24'h0, mem_rs2_data[7:0]}; end
            2'b01: begin dmem_wstrb = 4'b0010; dmem_wdata = {16'h0, mem_rs2_data[7:0], 8'h0}; end
            2'b10: begin dmem_wstrb = 4'b0100; dmem_wdata = {8'h0,  mem_rs2_data[7:0], 16'h0}; end
            2'b11: begin dmem_wstrb = 4'b1000; dmem_wdata = {mem_rs2_data[7:0], 24'h0}; end
          endcase
        end

        MEM_HALFWORD: begin // SH
          case (mem_alu_result[1])
            1'b0: begin dmem_wstrb = 4'b0011; dmem_wdata = {16'h0, mem_rs2_data[15:0]}; end
            1'b1: begin dmem_wstrb = 4'b1100; dmem_wdata = {mem_rs2_data[15:0], 16'h0}; end
          endcase
        end

        default: begin // SW / MEM_WORD
          dmem_wstrb = 4'b1111;
          dmem_wdata = mem_rs2_data;
        end
      endcase
    end else begin
      dmem_wstrb = 4'b0000;
      dmem_wdata = 32'h0;
    end
  end

  // -------------------------------------------------------------------------
  // Load Byte/Halfword Steering & Sign Extension (LB, LBU, LH, LHU, LW)
  // -------------------------------------------------------------------------
  logic [31:0] aligned_rdata;
  logic [1:0]  byte_offset;

  assign byte_offset = mem_alu_result[1:0];

  // In moola_memory.sv
  always_comb begin
    case (mem_mem_size)
      MEM_BYTE: begin
        case (byte_offset)
          2'b00: aligned_rdata = {{24{dmem_rdata[7]}},  dmem_rdata[7:0]};
          2'b01: aligned_rdata = {{24{dmem_rdata[15]}}, dmem_rdata[15:8]};
          2'b10: aligned_rdata = {{24{dmem_rdata[23]}}, dmem_rdata[23:16]};
          2'b11: aligned_rdata = {{24{dmem_rdata[31]}}, dmem_rdata[31:24]};
        endcase
      end
      MEM_BYTE_U: begin
        case (byte_offset)
          2'b00: aligned_rdata = {24'h0, dmem_rdata[7:0]};
          2'b01: aligned_rdata = {24'h0, dmem_rdata[15:8]};
          2'b10: aligned_rdata = {24'h0, dmem_rdata[23:16]};
          2'b11: aligned_rdata = {24'h0, dmem_rdata[31:24]};
        endcase
      end
      MEM_HALFWORD: begin
        case (byte_offset[1])
          1'b0: aligned_rdata = {{16{dmem_rdata[15]}}, dmem_rdata[15:0]};
          1'b1: aligned_rdata = {{16{dmem_rdata[31]}}, dmem_rdata[31:16]};
        endcase
      end
      MEM_HALF_U: begin
        case (byte_offset[1])
          1'b0: aligned_rdata = {16'h0, dmem_rdata[15:0]};
          1'b1: aligned_rdata = {16'h0, dmem_rdata[31:16]};
        endcase
      end
      default: begin
        aligned_rdata = dmem_rdata;
      end
    endcase
  end

  // Outputs to MEM/WB
  assign mem_out_pc_plus_4  = mem_pc_plus_4;
  assign mem_out_alu_result = mem_alu_result;
  assign mem_out_rdata      = aligned_rdata;
  assign mem_out_rd_addr    = mem_rd_addr;
  assign mem_out_reg_write  = mem_reg_write;
  assign mem_out_wb_sel     = mem_wb_sel;
  assign mem_out_mem_size = mem_mem_size;

endmodule : moola_memory