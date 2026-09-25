//=============================================================================
// Project      : Moola-V (MR5) Core
// File Name    : moola_hazard_unit.sv
// Description  : Hazard Detection Unit for Load-Use Stalls and Control Flushes
//=============================================================================

`timescale 1ns / 1ps

module moola_hazard_unit (
  input  logic [4:0] if_id_rs1_addr,
  input  logic [4:0] if_id_rs2_addr,
  input  logic       id_use_rs1,
  input  logic       id_use_rs2,
  input  logic [4:0] id_ex_rd_addr,
  input  logic       id_ex_mem_read,
  input  logic       pc_redirect,

  output logic       stall_if,
  output logic       stall_id,
  output logic       stall_ex,
  output logic       flush_id,
  output logic       flush_ex
);

  logic load_use_hazard;

  // Detect genuine Load-Use Hazard only when ID stage actually reads the register
  assign load_use_hazard = id_ex_mem_read &&
                           (id_ex_rd_addr != 5'd0) &&
                           ((id_use_rs1 && (id_ex_rd_addr == if_id_rs1_addr)) ||
                            (id_use_rs2 && (id_ex_rd_addr == if_id_rs2_addr)));

  always_comb begin
    stall_if = 1'b0;
    stall_id = 1'b0;
    stall_ex = 1'b0;
    flush_id = 1'b0;
    flush_ex = 1'b0;

    if (pc_redirect) begin
      flush_id = 1'b1;
      flush_ex = 1'b1;
    end else if (load_use_hazard) begin
      stall_if = 1'b1;
      stall_id = 1'b1;
      flush_ex = 1'b1;
    end
  end

endmodule : moola_hazard_unit