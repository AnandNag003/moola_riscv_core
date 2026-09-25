//=============================================================================
// Project      : Moola-V (MR5) Core Verification
// File Name    : tb_moola_core.sv
// Description  : Standalone Core-Level Testbench
//=============================================================================

`timescale 1ns / 1ps

module tb_moola_core;
  import moola_pkg::*;

  logic        clk;
  logic        rst_n;

  // IMEM Interface
  logic [31:0] imem_addr;
  logic        imem_req;
  logic [31:0] imem_rdata;

  // DMEM Interface
  logic [31:0] dmem_addr;
  logic [31:0] dmem_wdata;
  logic [3:0]  dmem_wstrb;
  logic        dmem_req;
  logic [31:0] dmem_rdata;

  // 64 KB Memory Array
  logic [7:0] mem [0:65535];

  // Shadow Register File
  logic [31:0] shadow_rf [0:31];

  int clock_cycles = 0;
  int error_count  = 0;

  // -------------------------------------------------------------------------
  // DUT Instantiation
  // -------------------------------------------------------------------------
  moola_core dut (
    .clk        (clk),
    .rst_n      (rst_n),
    .imem_addr  (imem_addr),
    .imem_req   (imem_req),
    .imem_rdata (imem_rdata),
    .dmem_addr  (dmem_addr),
    .dmem_wdata (dmem_wdata),
    .dmem_wstrb (dmem_wstrb),
    .dmem_req   (dmem_req),
    .dmem_rdata (dmem_rdata)
  );

  // Clock Generation (100 MHz)
  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  always @(posedge clk) begin
    if (rst_n) clock_cycles <= clock_cycles + 1;
    else       clock_cycles <= 0;
  end

  // Lower 16-bit address offsets
  wire [15:0] imem_offset = dut.if_pc[15:0];
  wire [15:0] dmem_offset = dmem_addr[15:0];

  // IMEM Data paired directly with if_pc (aligning with decode stage)
  always_comb begin
    if (imem_offset <= 16'hFFFC) begin
      imem_rdata = {mem[imem_offset + 3],
                    mem[imem_offset + 2],
                    mem[imem_offset + 1],
                    mem[imem_offset + 0]};
    end else begin
      imem_rdata = 32'h0000_0013; // NOP
    end
  end

  // DMEM Read (Combinational read returning data for EX/MEM)
  always_comb begin
    if (dmem_req && (dmem_offset <= 16'hFFFC)) begin
      dmem_rdata = {mem[dmem_offset + 3],
                    mem[dmem_offset + 2],
                    mem[dmem_offset + 1],
                    mem[dmem_offset + 0]};
    end else begin
      dmem_rdata = 32'h0;
    end
  end

  // DMEM Synchronous Write
  always_ff @(posedge clk) begin
    if (rst_n && dmem_req && (dmem_offset <= 16'hFFFC) && (|dmem_wstrb)) begin
      if (dmem_wstrb[0]) mem[dmem_offset + 0] <= dmem_wdata[7:0];
      if (dmem_wstrb[1]) mem[dmem_offset + 1] <= dmem_wdata[15:8];
      if (dmem_wstrb[2]) mem[dmem_offset + 2] <= dmem_wdata[23:16];
      if (dmem_wstrb[3]) mem[dmem_offset + 3] <= dmem_wdata[31:24];
      $display("[DMEM WRITE] Cycle %02d | Addr=0x%08h Data=0x%08h Strb=%b", 
               clock_cycles, dmem_addr, dmem_wdata, dmem_wstrb);
    end
  end

  // Shadow Register File Tracker
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (int i = 0; i < 32; i++) shadow_rf[i] <= 32'h0;
    end else begin
      if (dut.u_regfile.reg_write && (dut.u_regfile.rd_addr != 5'd0)) begin
        shadow_rf[dut.u_regfile.rd_addr] <= dut.u_regfile.rd_data;
        $display("[RETIRE]     Cycle %02d | x%02d <= 0x%08h (%0d)", 
                 clock_cycles, dut.u_regfile.rd_addr, dut.u_regfile.rd_data, $signed(dut.u_regfile.rd_data));
      end
    end
  end

  // Helper Task to Write Instructions
  task write_inst(input int index, input logic [31:0] inst);
    mem[(index*4) + 0] = inst[7:0];
    mem[(index*4) + 1] = inst[15:8];
    mem[(index*4) + 2] = inst[23:16];
    mem[(index*4) + 3] = inst[31:24];
  endtask

  // Test Sequence
  initial begin
    rst_n = 0;

    $dumpfile("sim/core_sim.vcd");
    $dumpvars(0, tb_moola_core);

    for (int i = 0; i < 65536; i = i + 4) begin
      mem[i + 0] = 8'h13;
      mem[i + 1] = 8'h00;
      mem[i + 2] = 8'h00;
      mem[i + 3] = 8'h00;
    end

    // -----------------------------------------------------------------------
    // Verified Test Program:
    // [0] ADDI x1, x0, 10       -> x1 = 10
    // [1] ADDI x2, x0, 20       -> x2 = 20
    // [2] ADD  x3, x1, x2       -> x3 = 30
    // [3] SW   x3, 100(x0)      -> Mem[100] = 30
    // [4] LW   x4, 100(x0)      -> x4 = 30
    // [5] ADDI x5, x4, 5        -> x5 = 35
    // [6] BEQ  x3, x4, 8        -> Branch to PC+8
    // [7] ADDI x6, x0, 99       -> Flushed slot
    // [8] ADDI x7, x0, 77       -> Branch target
    // -----------------------------------------------------------------------
    write_inst(0, 32'h00A00093); // addi x1, x0, 10
    write_inst(1, 32'h01400113); // addi x2, x0, 20
    write_inst(2, 32'h002081B3); // add  x3, x1, x2
    write_inst(3, 32'h06302223); // sw   x3, 100(x0)
    write_inst(4, 32'h06402203); // lw   x4, 100(x0)
    write_inst(5, 32'h00520293); // addi x5, x4, 5
    write_inst(6, 32'h00418463); // beq  x3, x4, 8
    write_inst(7, 32'h06300313); // addi x6, x0, 99
    write_inst(8, 32'h04D00393); // addi x7, x0, 77

    $display("\n========================================================");
    $display("       STARTING STANDALONE MOOLA-V CORE SIMULATION      ");
    $display("========================================================\n");

    repeat (3) @(posedge clk);
    @(negedge clk);
    rst_n = 1;

    repeat (35) @(posedge clk);

    $display("\n--- VERIFYING RETIRED ARCHITECTURAL REGISTER STATE ---");

    if (shadow_rf[1] !== 32'd10) begin
      $error("[FAIL] x1 mismatch: Expected 10, Got %0d", shadow_rf[1]);
      error_count++;
    end else $display("[PASS] x1 = %0d", shadow_rf[1]);

    if (shadow_rf[2] !== 32'd20) begin
      $error("[FAIL] x2 mismatch: Expected 20, Got %0d", shadow_rf[2]);
      error_count++;
    end else $display("[PASS] x2 = %0d", shadow_rf[2]);

    if (shadow_rf[3] !== 32'd30) begin
      $error("[FAIL] x3 (RAW Forwarding) mismatch: Expected 30, Got %0d", shadow_rf[3]);
      error_count++;
    end else $display("[PASS] x3 = %0d (EX-to-EX Forwarding OK)", shadow_rf[3]);

    if (shadow_rf[4] !== 32'd30) begin
      $error("[FAIL] x4 (Load Data) mismatch: Expected 30, Got %0d", shadow_rf[4]);
      error_count++;
    end else $display("[PASS] x4 = %0d (Store -> Load Memory Access OK)", shadow_rf[4]);

    if (shadow_rf[5] !== 32'd35) begin
      $error("[FAIL] x5 (Load-Use Stall) mismatch: Expected 35, Got %0d", shadow_rf[5]);
      error_count++;
    end else $display("[PASS] x5 = %0d (Load-Use Interlock OK)", shadow_rf[5]);

    if (shadow_rf[6] !== 32'd0) begin
      $error("[FAIL] x6 mismatch: Expected 0 (Flushed), Got %0d", shadow_rf[6]);
      error_count++;
    end else $display("[PASS] x6 = 0 (Branch Flush Cleared Speculative Slot OK)");

    if (shadow_rf[7] !== 32'd77) begin
      $error("[FAIL] x7 (Branch Target) mismatch: Expected 77, Got %0d", shadow_rf[7]);
      error_count++;
    end else $display("[PASS] x7 = %0d (Branch Target Landing OK)", shadow_rf[7]);

    $display("\n========================================================");
    if (error_count == 0) begin
      $display("  ALL CORE INTEGRATION & HAZARD TESTS PASSED!");
    end else begin
      $display("  CORE VERIFICATION FAILED WITH %0d ERRORS.", error_count);
    end
    $display("========================================================\n");
    $finish;
  end

endmodule : tb_moola_core