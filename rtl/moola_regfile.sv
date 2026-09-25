//=============================================================================
// Project      : Moola-V (MR5) Core
// File Name    : moola_regfile.sv
// Description  : 32x32-bit General Purpose Register File with x0=0 & WB Bypass
//=============================================================================

`timescale 1ns / 1ps

module moola_regfile (
  input  logic        clk,
  input  logic        rst_n,

  // Read Ports
  input  logic [4:0]  rs1_addr,
  output logic [31:0] rs1_data,

  input  logic [4:0]  rs2_addr,
  output logic [31:0] rs2_data,

  // Write Port
  input  logic        reg_write,
  input  logic [4:0]  rd_addr,
  input  logic [31:0] rd_data
);

  logic [31:0] regs [31:0];

  // Initialize all registers to 0 to prevent X propagation in simulation
  initial begin
    for (int i = 0; i < 32; i++) begin
      regs[i] = 32'h0;
    end
  end

  // Synchronous Write
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (int i = 0; i < 32; i++) begin
        regs[i] <= 32'h0;
      end
    end else if ((reg_write === 1'b1) && (rd_addr != 5'd0)) begin
      regs[rd_addr] <= rd_data;
    end
  end

  // Read Port 1 with Bypass
  always_comb begin
    if (rs1_addr == 5'd0) begin
      rs1_data = 32'h0;
    end else if ((reg_write === 1'b1) && (rd_addr == rs1_addr)) begin
      rs1_data = rd_data;
    end else begin
      rs1_data = regs[rs1_addr];
    end
  end

  // Read Port 2 with Bypass
  always_comb begin
    if (rs2_addr == 5'd0) begin
      rs2_data = 32'h0;
    end else if ((reg_write === 1'b1) && (rd_addr == rs2_addr)) begin
      rs2_data = rd_data;
    end else begin
      rs2_data = regs[rs2_addr];
    end
  end

endmodule : moola_regfile