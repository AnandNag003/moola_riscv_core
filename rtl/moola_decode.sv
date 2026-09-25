//=============================================================================
// Project      : Moola-V (MR5) Core
// File Name    : moola_decode.sv
// Description  : Instruction Decode Stage, Immediate Generator & Control Unit
//=============================================================================

`timescale 1ns / 1ps

module moola_decode (
  // Instruction Inputs
  input  logic [31:0]             id_pc,
  input  logic [31:0]             id_pc_plus_4,
  input  logic [31:0]             id_inst,

  // Register File Read Interface
  input  logic [31:0]             rf_rs1_data,
  input  logic [31:0]             rf_rs2_data,
  output logic [4:0]              rf_rs1_addr,
  output logic [4:0]              rf_rs2_addr,

  // Decoded Control & Data Outputs to ID/EX
  output logic [31:0]             dec_pc,
  output logic [31:0]             dec_rs1_data,
  output logic [31:0]             dec_rs2_data,
  output logic [4:0]              dec_rs1_addr,
  output logic [4:0]              dec_rs2_addr,
  output logic [4:0]              dec_rd_addr,
  output logic [31:0]             dec_imm,
  output moola_pkg::alu_op_e      dec_alu_op,
  output moola_pkg::alu_src_a_e   dec_alu_src_a,
  output moola_pkg::alu_src_b_e   dec_alu_src_b,
  output moola_pkg::branch_type_e dec_branch_type,
  output moola_pkg::mem_size_e    dec_mem_size,
  output logic                    dec_mem_read,
  output logic                    dec_mem_write,
  output logic                    dec_reg_write,
  output moola_pkg::wb_sel_e      dec_wb_sel
);
  import moola_pkg::*;

  // Raw Field Unpacking
  logic [6:0]  opcode;
  logic [4:0]  rd_raw;
  logic [2:0]  funct3;
  logic [4:0]  rs1_raw;
  logic [4:0]  rs2_raw;
  logic [6:0]  funct7;
  logic [31:0] imm;

  logic [4:0]  rs1_valid_addr;
  logic [4:0]  rs2_valid_addr;
  logic [4:0]  rd_valid_addr;

  assign opcode  = id_inst[6:0];
  assign rd_raw  = id_inst[11:7];
  assign funct3  = id_inst[14:12];
  assign rs1_raw = id_inst[19:15];
  assign rs2_raw = id_inst[24:20];
  assign funct7  = id_inst[31:25];

  // Source & Destination Register Qualification
  always_comb begin
    case (opcode)
      OPCODE_OP: begin
        rs1_valid_addr = rs1_raw;
        rs2_valid_addr = rs2_raw;
        rd_valid_addr  = rd_raw;
      end

      OPCODE_OP_IMM,
      OPCODE_LOAD,
      OPCODE_JALR: begin
        rs1_valid_addr = rs1_raw;
        rs2_valid_addr = 5'd0;
        rd_valid_addr  = rd_raw;
      end

      OPCODE_STORE: begin
        rs1_valid_addr = rs1_raw;
        rs2_valid_addr = rs2_raw;
        rd_valid_addr  = 5'd0; // S-Type has no rd
      end

      OPCODE_BRANCH: begin
        rs1_valid_addr = rs1_raw;
        rs2_valid_addr = rs2_raw;
        rd_valid_addr  = 5'd0; // B-Type has no rd
      end

      OPCODE_LUI,
      OPCODE_AUIPC,
      OPCODE_JAL: begin
        rs1_valid_addr = 5'd0;
        rs2_valid_addr = 5'd0;
        rd_valid_addr  = rd_raw;
      end

      default: begin
        rs1_valid_addr = 5'd0;
        rs2_valid_addr = 5'd0;
        rd_valid_addr  = 5'd0;
      end
    endcase
  end

  assign rf_rs1_addr  = rs1_valid_addr;
  assign rf_rs2_addr  = rs2_valid_addr;
  assign dec_rs1_addr = rs1_valid_addr;
  assign dec_rs2_addr = rs2_valid_addr;
  assign dec_rd_addr  = rd_valid_addr;
  assign dec_pc       = id_pc;
  assign dec_rs1_data = rf_rs1_data;
  assign dec_rs2_data = rf_rs2_data;

  // Immediate Generator
  always_comb begin
    case (opcode)
      OPCODE_OP_IMM,
      OPCODE_LOAD,
      OPCODE_JALR: begin
        imm = {{20{id_inst[31]}}, id_inst[31:20]};
      end

      OPCODE_STORE: begin
        imm = {{20{id_inst[31]}}, id_inst[31:25], id_inst[11:7]};
      end

      OPCODE_BRANCH: begin
        imm = {{19{id_inst[31]}}, id_inst[31], id_inst[7], id_inst[30:25], id_inst[11:8], 1'b0};
      end

      OPCODE_LUI,
      OPCODE_AUIPC: begin
        imm = {id_inst[31:12], 12'b0};
      end

      OPCODE_JAL: begin
        imm = {{11{id_inst[31]}}, id_inst[31], id_inst[19:12], id_inst[20], id_inst[30:21], 1'b0};
      end

      default: begin
        imm = 32'h0;
      end
    endcase
  end

  assign dec_imm = imm;

  // Control Unit
  always_comb begin
    dec_alu_op      = ALU_ADD;
    dec_alu_src_a   = ALU_SRC_A_RS1;
    dec_alu_src_b   = ALU_SRC_B_RS2;
    dec_branch_type = BR_NONE;
    dec_mem_size    = MEM_WORD;
    dec_mem_read    = 1'b0;
    dec_mem_write   = 1'b0;
    dec_reg_write   = 1'b0;
    dec_wb_sel      = WB_SEL_ALU;

    case (opcode)
      OPCODE_OP: begin
        dec_alu_src_a = ALU_SRC_A_RS1;
        dec_alu_src_b = ALU_SRC_B_RS2;
        dec_reg_write = (rd_valid_addr != 5'd0);
        dec_wb_sel    = WB_SEL_ALU;
        case (funct3)
          3'b000: begin
            if (funct7[5]) dec_alu_op = ALU_SUB;
            else           dec_alu_op = ALU_ADD;
          end
          3'b001: dec_alu_op = ALU_SLL;
          3'b010: dec_alu_op = ALU_SLT;
          3'b011: dec_alu_op = ALU_SLTU;
          3'b100: dec_alu_op = ALU_XOR;
          3'b101: begin
            if (funct7[5]) dec_alu_op = ALU_SRA;
            else           dec_alu_op = ALU_SRL;
          end
          3'b110: dec_alu_op = ALU_OR;
          3'b111: dec_alu_op = ALU_AND;
          default: dec_alu_op = ALU_ADD;
        endcase
      end

      OPCODE_OP_IMM: begin
        dec_alu_src_a = ALU_SRC_A_RS1;
        dec_alu_src_b = ALU_SRC_B_IMM;
        dec_reg_write = (rd_valid_addr != 5'd0);
        dec_wb_sel    = WB_SEL_ALU;
        case (funct3)
          3'b000: dec_alu_op = ALU_ADD;
          3'b001: dec_alu_op = ALU_SLL;
          3'b010: dec_alu_op = ALU_SLT;
          3'b011: dec_alu_op = ALU_SLTU;
          3'b100: dec_alu_op = ALU_XOR;
          3'b101: begin
            if (funct7[5]) dec_alu_op = ALU_SRA;
            else           dec_alu_op = ALU_SRL;
          end
          3'b110: dec_alu_op = ALU_OR;
          3'b111: dec_alu_op = ALU_AND;
          default: dec_alu_op = ALU_ADD;
        endcase
      end

      OPCODE_LOAD: begin
        dec_alu_src_a = ALU_SRC_A_RS1;
        dec_alu_src_b = ALU_SRC_B_IMM;
        dec_alu_op    = ALU_ADD;
        dec_mem_read  = 1'b1;
        dec_reg_write = (rd_valid_addr != 5'd0);
        dec_wb_sel    = WB_SEL_MEM;
        dec_mem_size  = mem_size_e'(funct3);
      end

      OPCODE_STORE: begin
        dec_alu_src_a = ALU_SRC_A_RS1;
        dec_alu_src_b = ALU_SRC_B_IMM;
        dec_alu_op    = ALU_ADD;
        dec_mem_write = 1'b1;
        dec_reg_write = 1'b0;
        dec_mem_size  = mem_size_e'(funct3);
      end

      OPCODE_BRANCH: begin
        dec_alu_src_a   = ALU_SRC_A_PC;
        dec_alu_src_b   = ALU_SRC_B_IMM;
        dec_alu_op      = ALU_SUB;
        dec_reg_write   = 1'b0;
        case (funct3)
          3'b000: dec_branch_type = BR_BEQ;
          3'b001: dec_branch_type = BR_BNE;
          3'b100: dec_branch_type = BR_BLT;
          3'b101: dec_branch_type = BR_BGE;
          3'b110: dec_branch_type = BR_BLTU;
          3'b111: dec_branch_type = BR_BGEU;
          default: dec_branch_type = BR_NONE;
        endcase
      end

      OPCODE_LUI: begin
        dec_alu_src_a = ALU_SRC_A_RS1;
        dec_alu_src_b = ALU_SRC_B_IMM;
        dec_alu_op    = ALU_ADD;
        dec_reg_write = (rd_valid_addr != 5'd0);
        dec_wb_sel    = WB_SEL_ALU;
      end

      OPCODE_AUIPC: begin
        dec_alu_src_a = ALU_SRC_A_PC;
        dec_alu_src_b = ALU_SRC_B_IMM;
        dec_alu_op    = ALU_ADD;
        dec_reg_write = (rd_valid_addr != 5'd0);
        dec_wb_sel    = WB_SEL_ALU;
      end

      OPCODE_JAL: begin
        dec_alu_src_a = ALU_SRC_A_PC;
        dec_alu_src_b = ALU_SRC_B_IMM;
        dec_alu_op    = ALU_ADD;
        dec_reg_write = (rd_valid_addr != 5'd0);
        dec_wb_sel    = WB_SEL_PC4;
      end

      OPCODE_JALR: begin
        dec_alu_src_a = ALU_SRC_A_RS1;
        dec_alu_src_b = ALU_SRC_B_IMM;
        dec_alu_op    = ALU_ADD;
        dec_reg_write = (rd_valid_addr != 5'd0);
        dec_wb_sel    = WB_SEL_PC4;
      end

      default: begin
      end
    endcase
  end

endmodule : moola_decode