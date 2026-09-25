module moola_if_id_reg
  import moola_pkg::*;
(
  input  logic        clk,
  input  logic        rst_n,

  // Hazard Controls
  input  logic        stall_id,
  input  logic        flush_id,

  // Fetch Stage Inputs
  input  logic [31:0] if_pc,
  input  logic [31:0] if_pc_plus_4,
  input  logic [31:0] imem_rdata,

  // Outputs to Decode
  output logic [31:0] id_pc,
  output logic [31:0] id_pc_plus_4,
  output logic [31:0] id_inst,
  output logic        id_valid          // <--- ADD THIS
);

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      id_pc        <= RESET_VECTOR;
      id_pc_plus_4 <= RESET_VECTOR + 32'd4;
      id_inst      <= 32'h0000_0013; // NOP
      id_valid     <= 1'b0;          // <--- RESET TO INVALID (0)
    end else if (flush_id) begin
      id_pc        <= if_pc;
      id_pc_plus_4 <= if_pc_plus_4;
      id_inst      <= 32'h0000_0013;
      id_valid     <= 1'b0;          // <--- FLUSH TO INVALID (0)
    end else if (!stall_id) begin
      id_pc        <= if_pc;
      id_pc_plus_4 <= if_pc_plus_4;
      id_inst      <= imem_rdata;
      id_valid     <= 1'b1;          // <--- VALID FETCHED INSTRUCTION
    end
  end

endmodule