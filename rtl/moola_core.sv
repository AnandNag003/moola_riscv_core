//=============================================================================
// Project      : Moola-V (MR5) Core
// File Name    : moola_core.sv
// Description  : 5-Stage RV32I Core Top-Level Datapath Integration
//=============================================================================

`timescale 1ns / 1ps

module moola_core (
  input  logic        clk,
  input  logic        rst_n,

  // Instruction Memory Interface
  output logic [31:0] imem_addr,
  output logic        imem_req,
  input  logic [31:0] imem_rdata,

  // Data Memory Interface
  output logic [31:0] dmem_addr,
  output logic [31:0] dmem_wdata,
  output logic [3:0]  dmem_wstrb,
  output logic        dmem_req,
  input  logic [31:0] dmem_rdata

  `ifdef VERIFICATION
  ,
  output logic        mon_valid,
  output logic [31:0] mon_pc,
  output logic [4:0]  mon_rd_addr,
  output logic [31:0] mon_rd_data,
  output logic        mon_reg_write
  `endif
);

  import moola_pkg::*;

  // -------------------------------------------------------------------------
  // Fetch Stage Signals
  // -------------------------------------------------------------------------
  logic [31:0]                if_pc;
  logic [31:0]                if_pc_plus_4;

  // -------------------------------------------------------------------------
  // Decode Stage Signals
  // -------------------------------------------------------------------------
  logic [31:0]                id_pc;
  logic [31:0]                id_pc_plus_4;
  logic [31:0]                id_inst;

  logic [4:0]                 rf_rs1_addr;
  logic [4:0]                 rf_rs2_addr;
  logic [31:0]                rf_rs1_data;
  logic [31:0]                rf_rs2_data;

  logic [31:0]                dec_pc;
  logic [31:0]                dec_rs1_data;
  logic [31:0]                dec_rs2_data;
  logic [4:0]                 dec_rs1_addr;
  logic [4:0]                 dec_rs2_addr;
  logic [4:0]                 dec_rd_addr;
  logic [31:0]                dec_imm;
  moola_pkg::alu_op_e         dec_alu_op;
  moola_pkg::alu_src_a_e      dec_alu_src_a;
  moola_pkg::alu_src_b_e      dec_alu_src_b;
  moola_pkg::branch_type_e    dec_branch_type;
  moola_pkg::mem_size_e       dec_mem_size;
  logic                       dec_mem_read;
  logic                       dec_mem_write;
  logic                       dec_reg_write;
  moola_pkg::wb_sel_e         dec_wb_sel;
  logic                       dec_valid;

  logic                       id_use_rs1;
  logic                       id_use_rs2;

  // -------------------------------------------------------------------------
  // Execute Stage Signals
  // -------------------------------------------------------------------------
  logic                       ex_valid;
  logic [31:0]                ex_pc;
  logic [31:0]                ex_rs1_data;
  logic [31:0]                ex_rs2_data;
  logic [4:0]                 ex_rs1_addr;
  logic [4:0]                 ex_rs2_addr;
  logic [4:0]                 ex_rd_addr;
  logic [31:0]                ex_imm;
  moola_pkg::alu_op_e         ex_alu_op;
  moola_pkg::alu_src_a_e      ex_alu_src_a;
  moola_pkg::alu_src_b_e      ex_alu_src_b;
  moola_pkg::branch_type_e    ex_branch_type;
  moola_pkg::mem_size_e       ex_mem_size;
  logic                       ex_mem_read;
  logic                       ex_mem_write;
  logic                       ex_reg_write;
  moola_pkg::wb_sel_e         ex_wb_sel;

  logic [31:0]                fwd_rs1_data;
  logic [31:0]                fwd_rs2_data;
  logic                       pc_redirect;
  logic [31:0]                redirect_target;

  logic [31:0]                ex_out_pc_plus_4;
  logic [31:0]                ex_out_alu_result;
  logic [31:0]                ex_out_rs2_data;
  logic [4:0]                 ex_out_rd_addr;
  logic                       ex_out_mem_read;
  logic                       ex_out_mem_write;
  logic                       ex_out_reg_write;
  moola_pkg::mem_size_e       ex_out_mem_size;
  moola_pkg::wb_sel_e         ex_out_wb_sel;

  // -------------------------------------------------------------------------
  // Memory Stage Signals
  // -------------------------------------------------------------------------
  logic                       mem_valid;
  logic [31:0]                mem_pc_plus_4;
  logic [31:0]                mem_alu_result;
  logic [31:0]                mem_rs2_data;
  logic [4:0]                 mem_rd_addr;
  logic                       mem_mem_read;
  logic                       mem_mem_write;
  logic                       mem_reg_write;
  moola_pkg::mem_size_e       mem_mem_size;
  moola_pkg::wb_sel_e         mem_wb_sel;

  logic [31:0]                mem_out_pc_plus_4;
  logic [31:0]                mem_out_alu_result;
  logic [31:0]                mem_out_rdata;
  logic [4:0]                 mem_out_rd_addr;
  logic                       mem_out_reg_write;
  moola_pkg::mem_size_e       mem_out_mem_size;
  moola_pkg::wb_sel_e         mem_out_wb_sel;

  // -------------------------------------------------------------------------
  // Write-Back Stage Signals
  // -------------------------------------------------------------------------
  logic                       wb_valid;
  logic [31:0]                wb_pc_plus_4;
  logic [31:0]                wb_alu_result;
  logic [31:0]                wb_mem_rdata;
  logic [4:0]                 wb_rd_addr;
  logic                       wb_reg_write;
  moola_pkg::mem_size_e       wb_mem_size;
  moola_pkg::wb_sel_e         wb_wb_sel;
  logic [31:0]                wb_final_data;

  // -------------------------------------------------------------------------
  // Hazard & Forwarding Controls
  // -------------------------------------------------------------------------
  logic                       stall_if;
  logic                       stall_id;
  logic                       stall_ex;
  logic                       flush_id;
  logic                       flush_ex;
  logic [1:0]                 fwd_a_sel;
  logic [1:0]                 fwd_b_sel;

  // =========================================================================
  // 1. Fetch Stage & IF/ID Register
  // =========================================================================
  moola_fetch u_fetch (
    .clk             (clk),
    .rst_n           (rst_n),
    .stall_if        (stall_if),
    .pc_redirect     (pc_redirect),
    .redirect_target (redirect_target),
    .imem_addr       (imem_addr),
    .imem_req        (imem_req),
    .if_pc           (if_pc),
    .if_pc_plus_4    (if_pc_plus_4)
  );

  moola_if_id_reg u_if_id_reg (
    .clk          (clk),
    .rst_n        (rst_n),
    .stall_id     (stall_id),
    .flush_id     (flush_id),
    .if_pc        (if_pc),
    .if_pc_plus_4 (if_pc_plus_4),
    .imem_rdata   (imem_rdata),
    .id_pc        (id_pc),
    .id_pc_plus_4 (id_pc_plus_4),
    .id_inst      (id_inst)
  );

  // =========================================================================
  // 2. Decode Stage, Regfile & ID/EX Register
  // =========================================================================
  moola_regfile u_regfile (
    .clk       (clk),
    .rst_n     (rst_n),
    .rs1_addr  (rf_rs1_addr),
    .rs1_data  (rf_rs1_data),
    .rs2_addr  (rf_rs2_addr),
    .rs2_data  (rf_rs2_data),
    .reg_write (wb_reg_write),
    .rd_addr   (wb_rd_addr),
    .rd_data   (wb_final_data)
  );

  moola_decode u_decode (
    .id_pc           (id_pc),
    .id_pc_plus_4    (id_pc_plus_4),
    .id_inst         (id_inst),
    .rf_rs1_data     (rf_rs1_data),
    .rf_rs2_data     (rf_rs2_data),
    .rf_rs1_addr     (rf_rs1_addr),
    .rf_rs2_addr     (rf_rs2_addr),
    .dec_pc          (dec_pc),
    .dec_rs1_data    (dec_rs1_data),
    .dec_rs2_data    (dec_rs2_data),
    .dec_rs1_addr    (dec_rs1_addr),
    .dec_rs2_addr    (dec_rs2_addr),
    .dec_rd_addr     (dec_rd_addr),
    .dec_imm         (dec_imm),
    .dec_alu_op      (dec_alu_op),
    .dec_alu_src_a   (dec_alu_src_a),
    .dec_alu_src_b   (dec_alu_src_b),
    .dec_branch_type (dec_branch_type),
    .dec_mem_size    (dec_mem_size),
    .dec_mem_read    (dec_mem_read),
    .dec_mem_write   (dec_mem_write),
    .dec_reg_write   (dec_reg_write),
    .dec_wb_sel      (dec_wb_sel)
  );

  // Determine whether instruction in decode genuinely depends on rs1 or rs2
  always_comb begin
    case (id_inst[6:0])
      7'b0110011: begin // R-type: uses rs1, rs2
        id_use_rs1 = 1'b1;
        id_use_rs2 = 1'b1;
      end
      7'b0010011,       // I-type ALU: uses rs1
      7'b0000011,       // Load: uses rs1
      7'b1100111: begin // JALR: uses rs1
        id_use_rs1 = 1'b1;
        id_use_rs2 = 1'b0;
      end
      7'b0100011,       // S-type: uses rs1, rs2
      7'b1100011: begin // B-type: uses rs1, rs2
        id_use_rs1 = 1'b1;
        id_use_rs2 = 1'b1;
      end
      default: begin    // LUI, AUIPC, JAL: neither
        id_use_rs1 = 1'b0;
        id_use_rs2 = 1'b0;
      end
    endcase
  end

  assign dec_valid = rst_n && !flush_id;

  moola_id_ex_reg u_id_ex_reg (
    .clk             (clk),
    .rst_n           (rst_n),
    .stall_ex        (stall_ex),
    .flush_ex        (flush_ex),
    .dec_valid       (dec_valid),
    .dec_pc          (dec_pc),
    .dec_rs1_data    (dec_rs1_data),
    .dec_rs2_data    (dec_rs2_data),
    .dec_rs1_addr    (dec_rs1_addr),
    .dec_rs2_addr    (dec_rs2_addr),
    .dec_rd_addr     (dec_rd_addr),
    .dec_imm         (dec_imm),
    .dec_alu_op      (dec_alu_op),
    .dec_alu_src_a   (dec_alu_src_a),
    .dec_alu_src_b   (dec_alu_src_b),
    .dec_branch_type (dec_branch_type),
    .dec_mem_size    (dec_mem_size),
    .dec_mem_read    (dec_mem_read),
    .dec_mem_write   (dec_mem_write),
    .dec_reg_write   (dec_reg_write),
    .dec_wb_sel      (dec_wb_sel),
    .ex_valid        (ex_valid),
    .ex_pc           (ex_pc),
    .ex_rs1_data     (ex_rs1_data),
    .ex_rs2_data     (ex_rs2_data),
    .ex_rs1_addr     (ex_rs1_addr),
    .ex_rs2_addr     (ex_rs2_addr),
    .ex_rd_addr      (ex_rd_addr),
    .ex_imm          (ex_imm),
    .ex_alu_op       (ex_alu_op),
    .ex_alu_src_a    (ex_alu_src_a),
    .ex_alu_src_b    (ex_alu_src_b),
    .ex_branch_type  (ex_branch_type),
    .ex_mem_size     (ex_mem_size),
    .ex_mem_read     (ex_mem_read),
    .ex_mem_write    (ex_mem_write),
    .ex_reg_write    (ex_reg_write),
    .ex_wb_sel       (ex_wb_sel)
  );

  // =========================================================================
  // 3. Execute Stage & Forwarding Muxes
  // =========================================================================
  logic [31:0] mem_fwd_data;

  // Safe data selection for EX/MEM forwarding
  always_comb begin
    case (mem_wb_sel)
      WB_SEL_PC4: mem_fwd_data = mem_pc_plus_4;
      WB_SEL_ALU: mem_fwd_data = mem_alu_result;
      default:    mem_fwd_data = mem_alu_result;
    endcase
  end

  always_comb begin
    case (fwd_a_sel)
      2'b01:   fwd_rs1_data = mem_fwd_data;
      2'b10:   fwd_rs1_data = wb_final_data;
      default: fwd_rs1_data = ex_rs1_data;
    endcase

    case (fwd_b_sel)
      2'b01:   fwd_rs2_data = mem_fwd_data;
      2'b10:   fwd_rs2_data = wb_final_data;
      default: fwd_rs2_data = ex_rs2_data;
    endcase
  end

  moola_execute u_execute (
    .ex_pc             (ex_pc),
    .ex_imm            (ex_imm),
    .ex_rd_addr        (ex_rd_addr),
    .ex_alu_op         (ex_alu_op),
    .ex_alu_src_a      (ex_alu_src_a),
    .ex_alu_src_b      (ex_alu_src_b),
    .ex_branch_type    (ex_branch_type),
    .ex_mem_size       (ex_mem_size),
    .ex_mem_read       (ex_mem_read),
    .ex_mem_write      (ex_mem_write),
    .ex_reg_write      (ex_reg_write),
    .ex_wb_sel         (ex_wb_sel),
    .fwd_rs1_data      (fwd_rs1_data),
    .fwd_rs2_data      (fwd_rs2_data),
    .pc_redirect       (pc_redirect),
    .redirect_target   (redirect_target),
    .ex_out_pc_plus_4  (ex_out_pc_plus_4),
    .ex_out_alu_result (ex_out_alu_result),
    .ex_out_rs2_data   (ex_out_rs2_data),
    .ex_out_rd_addr    (ex_out_rd_addr),
    .ex_out_mem_read   (ex_out_mem_read),
    .ex_out_mem_write  (ex_out_mem_write),
    .ex_out_reg_write  (ex_out_reg_write),
    .ex_out_mem_size   (ex_out_mem_size),
    .ex_out_wb_sel     (ex_out_wb_sel)
  );

  moola_ex_mem_reg u_ex_mem_reg (
    .clk               (clk),
    .rst_n             (rst_n),
    .stall_mem         (1'b0),
    .flush_mem         (1'b0),
    .ex_out_valid      (ex_valid),
    .ex_out_pc_plus_4  (ex_out_pc_plus_4),
    .ex_out_alu_result (ex_out_alu_result),
    .ex_out_rs2_data   (ex_out_rs2_data),
    .ex_out_rd_addr    (ex_out_rd_addr),
    .ex_out_mem_read   (ex_out_mem_read),
    .ex_out_mem_write  (ex_out_mem_write),
    .ex_out_reg_write  (ex_out_reg_write),
    .ex_out_mem_size   (ex_out_mem_size),
    .ex_out_wb_sel     (ex_out_wb_sel),
    .mem_valid         (mem_valid),
    .mem_pc_plus_4     (mem_pc_plus_4),
    .mem_alu_result    (mem_alu_result),
    .mem_rs2_data      (mem_rs2_data),
    .mem_rd_addr       (mem_rd_addr),
    .mem_mem_read      (mem_mem_read),
    .mem_mem_write     (mem_mem_write),
    .mem_reg_write     (mem_reg_write),
    .mem_mem_size      (mem_mem_size),
    .mem_wb_sel        (mem_wb_sel)
  );

  // =========================================================================
  // 4. Memory Stage & MEM/WB Register
  // =========================================================================
  moola_memory u_memory (
    .mem_pc_plus_4     (mem_pc_plus_4),
    .mem_alu_result    (mem_alu_result),
    .mem_rs2_data      (mem_rs2_data),
    .mem_rd_addr       (mem_rd_addr),
    .mem_mem_read      (mem_mem_read),
    .mem_mem_write     (mem_mem_write),
    .mem_reg_write     (mem_reg_write),
    .mem_mem_size      (mem_mem_size),
    .mem_wb_sel        (mem_wb_sel),
    .dmem_addr         (dmem_addr),
    .dmem_wdata        (dmem_wdata),
    .dmem_wstrb        (dmem_wstrb),
    .dmem_req          (dmem_req),
    .dmem_rdata        (dmem_rdata),
    .mem_out_pc_plus_4  (mem_out_pc_plus_4),
    .mem_out_alu_result (mem_out_alu_result),
    .mem_out_rdata      (mem_out_rdata),
    .mem_out_rd_addr    (mem_out_rd_addr),
    .mem_out_reg_write  (mem_out_reg_write),
    .mem_out_mem_size   (mem_out_mem_size),
    .mem_out_wb_sel     (mem_out_wb_sel)
  );

  moola_mem_wb_reg u_mem_wb_reg (
    .clk                (clk),
    .rst_n              (rst_n),
    .stall_wb           (1'b0),
    .flush_wb           (1'b0),
    .mem_out_valid      (mem_valid),
    .mem_out_pc_plus_4  (mem_out_pc_plus_4),
    .mem_out_alu_result (mem_out_alu_result),
    .mem_out_rdata      (mem_out_rdata),
    .mem_out_rd_addr    (mem_out_rd_addr),
    .mem_out_reg_write  (mem_out_reg_write),
    .mem_out_mem_size   (mem_out_mem_size),
    .mem_out_wb_sel     (mem_out_wb_sel),
    .wb_valid           (wb_valid),
    .wb_pc_plus_4       (wb_pc_plus_4),
    .wb_alu_result      (wb_alu_result),
    .wb_mem_rdata       (wb_mem_rdata),
    .wb_rd_addr         (wb_rd_addr),
    .wb_reg_write       (wb_reg_write),
    .wb_mem_size        (wb_mem_size),
    .wb_wb_sel          (wb_wb_sel)
  );

  // =========================================================================
  // 5. Write-Back Stage Mux
  // =========================================================================
  always_comb begin
    case (wb_wb_sel)
      WB_SEL_ALU: wb_final_data = wb_alu_result;
      WB_SEL_MEM: wb_final_data = wb_mem_rdata;
      WB_SEL_PC4: wb_final_data = wb_pc_plus_4;
      default:    wb_final_data = wb_alu_result;
    endcase
  end

  // =========================================================================
  // 6. Hazard & Forwarding Units
  // =========================================================================
  moola_forwarding_unit u_fwd_unit (
    .id_ex_rs1_addr    (ex_rs1_addr),
    .id_ex_rs2_addr    (ex_rs2_addr),
    .ex_mem_rd_addr    (mem_rd_addr),
    .ex_mem_reg_write  (mem_reg_write),
    .ex_mem_mem_read   (mem_mem_read),
    .mem_wb_rd_addr    (wb_rd_addr),
    .mem_wb_reg_write  (wb_reg_write),
    .fwd_a_sel         (fwd_a_sel),
    .fwd_b_sel         (fwd_b_sel)
  );

  moola_hazard_unit u_hazard_unit (
    .if_id_rs1_addr    (rf_rs1_addr),
    .if_id_rs2_addr    (rf_rs2_addr),
    .id_use_rs1        (id_use_rs1),
    .id_use_rs2        (id_use_rs2),
    .id_ex_rd_addr     (ex_rd_addr),
    .id_ex_mem_read    (ex_mem_read),
    .pc_redirect       (pc_redirect),
    .stall_if          (stall_if),
    .stall_id          (stall_id),
    .stall_ex          (stall_ex),
    .flush_id          (flush_id),
    .flush_ex          (flush_ex)
  );

  // =========================================================================
  // Verification Retirement Monitoring
  // =========================================================================
  `ifdef VERIFICATION
  assign mon_valid     = rst_n && wb_valid && (wb_pc_plus_4 >= 32'h8000_0004) && wb_reg_write && (wb_rd_addr != 5'd0);
  assign mon_pc        = wb_pc_plus_4 - 32'd4;
  assign mon_rd_addr   = wb_rd_addr;
  assign mon_rd_data   = wb_final_data;
  assign mon_reg_write = wb_reg_write;
  `endif

endmodule : moola_core