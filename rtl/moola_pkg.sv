//=============================================================================
// Project      : Moola-V (MR5) Core
// File Name    : moola_pkg.sv
// Description  : Central Package Definitions for 5-Stage RV32I Processor Core
//=============================================================================
`timescale 1ns / 1ps
package moola_pkg;

  //---------------------------------------------------------------------------
  // 1. Global Constants
  //---------------------------------------------------------------------------
  localparam logic [31:0] RESET_VECTOR    = 32'h8000_0000;
  localparam logic [31:0] NOP_INSTRUCTION = 32'h0000_0013; // addi x0, x0, 0

  //---------------------------------------------------------------------------
  // 2. Instruction Opcodes (opcode_e)
  //---------------------------------------------------------------------------
  typedef enum logic [6:0] {
    OPCODE_LUI     = 7'b0110111,
    OPCODE_AUIPC   = 7'b0010111,
    OPCODE_JAL     = 7'b1101111,
    OPCODE_JALR    = 7'b1100111,
    OPCODE_BRANCH  = 7'b1100011,
    OPCODE_LOAD    = 7'b0000011,
    OPCODE_STORE   = 7'b0100011,
    OPCODE_OP_IMM  = 7'b0010011,
    OPCODE_OP      = 7'b0110011,
    OPCODE_SYSTEM  = 7'b1110011
  } opcode_e;

  //---------------------------------------------------------------------------
  // 3. ALU Operation Enums (alu_op_e)
  //---------------------------------------------------------------------------
  typedef enum logic [3:0] {
    ALU_ADD  = 4'b0000,
    ALU_SUB  = 4'b0001,
    ALU_SLL  = 4'b0010,
    ALU_SLT  = 4'b0011,
    ALU_SLTU = 4'b0100,
    ALU_XOR  = 4'b0101,
    ALU_SRL  = 4'b0110,
    ALU_SRA  = 4'b0111,
    ALU_OR   = 4'b1000,
    ALU_AND  = 4'b1001
  } alu_op_e;

  //---------------------------------------------------------------------------
  // 4. Branch & Memory Control Enums
  //---------------------------------------------------------------------------
  typedef enum logic [2:0] {
    BR_BEQ  = 3'b000,
    BR_BNE  = 3'b001,
    BR_BLT  = 3'b100,
    BR_BGE  = 3'b101,
    BR_BLTU = 3'b110,
    BR_BGEU = 3'b111,
    BR_NONE = 3'b010
  } branch_type_e;

  // Direct mapping to RISC-V funct3[2:0] for Load/Store instructions
  typedef enum logic [2:0] {
    MEM_BYTE     = 3'b000, // LB  / SB
    MEM_HALFWORD = 3'b001, // LH  / SH
    MEM_WORD     = 3'b010, // LW  / SW
    MEM_BYTE_U   = 3'b100, // LBU
    MEM_HALF_U   = 3'b101  // LHU
  } mem_size_e;

  typedef enum logic [1:0] {
    WB_SEL_ALU = 2'b00,
    WB_SEL_MEM = 2'b01,
    WB_SEL_PC4 = 2'b10
  } wb_sel_e;

  typedef enum logic {
    ALU_SRC_A_RS1 = 1'b0,
    ALU_SRC_A_PC  = 1'b1
  } alu_src_a_e;

  typedef enum logic {
    ALU_SRC_B_RS2 = 1'b0,
    ALU_SRC_B_IMM = 1'b1
  } alu_src_b_e;

  //---------------------------------------------------------------------------
  // 5. Inter-Stage Pipeline Payloads (struct packed)
  //---------------------------------------------------------------------------

  // IF -> ID
  typedef struct packed {
    logic [31:0] pc;
    logic [31:0] pc_plus_4;
    logic [31:0] inst;
  } if_id_payload_t;

  // ID -> EX
  typedef struct packed {
    logic [31:0]   pc;
    logic [31:0]   rs1_data;
    logic [31:0]   rs2_data;
    logic [31:0]   imm;
    logic [4:0]    rs1_addr;
    logic [4:0]    rs2_addr;
    logic [4:0]    rd_addr;
    alu_op_e       alu_op;
    alu_src_a_e    alu_src_a;
    alu_src_b_e    alu_src_b;
    branch_type_e  branch_type;
    logic          mem_read;
    logic          mem_write;
    logic          reg_write;
    mem_size_e     mem_size;
    wb_sel_e       wb_sel;
  } id_ex_payload_t;

  // EX -> MEM
  typedef struct packed {
    logic [31:0]   pc_plus_4;
    logic [31:0]   alu_result;
    logic [31:0]   rs2_data;
    logic [4:0]    rd_addr;
    logic          mem_read;
    logic          mem_write;
    logic          reg_write;
    mem_size_e     mem_size;
    wb_sel_e       wb_sel;
  } ex_mem_payload_t;

  // MEM -> WB
  typedef struct packed {
    logic [31:0]   pc_plus_4;
    logic [31:0]   alu_result;
    logic [31:0]   mem_rdata;
    logic [4:0]    rd_addr;
    logic          reg_write;
    wb_sel_e       wb_sel;
  } mem_wb_payload_t;

endpackage : moola_pkg