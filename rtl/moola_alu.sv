//=============================================================================
// Project      : Moola-V (MR5) Core
// File Name    : moola_alu.sv
// Description  : RV32I 32-bit Arithmetic Logic Unit (ALU)
//=============================================================================

`timescale 1ns / 1ps

module moola_alu
  import moola_pkg::*;
(
  input  logic [31:0]  alu_in_a,
  input  logic [31:0]  alu_in_b,
  input  alu_op_e      alu_op,
  output logic [31:0]  alu_result
);

  logic [4:0] shamt;
  assign shamt = alu_in_b[4:0];

  always_comb begin
    case (alu_op)
      ALU_ADD:  alu_result = alu_in_a + alu_in_b;
      ALU_SUB:  alu_result = alu_in_a - alu_in_b;
      ALU_SLL:  alu_result = alu_in_a << shamt;
      ALU_SLT:  alu_result = ($signed(alu_in_a) < $signed(alu_in_b)) ? 32'd1 : 32'd0;
      ALU_SLTU: alu_result = ($unsigned(alu_in_a) < $unsigned(alu_in_b)) ? 32'd1 : 32'd0;
      ALU_XOR:  alu_result = alu_in_a ^ alu_in_b;
      ALU_SRL:  alu_result = alu_in_a >> shamt;
      ALU_SRA:  alu_result = $signed(alu_in_a) >>> shamt;
      ALU_OR:   alu_result = alu_in_a | alu_in_b;
      ALU_AND:  alu_result = alu_in_a & alu_in_b;
      default:  alu_result = 32'h0;
    endcase
  end

endmodule : moola_alu