//=============================================================================
// Testbench   : tb_moola_soc_top
// Description : Top-Level Functional Verification Testbench for Moola-V SoC
//=============================================================================

`timescale 1ns / 1ps

module tb_moola_soc_top;

  localparam time CLK_PERIOD = 10ns; // 100 MHz
  localparam int  MAX_CYCLES = 500;  // Watchdog limit

  logic clk;
  logic rst_n;

`ifdef VERIFICATION
  logic        load_en;
  logic        mon_valid;
  logic [31:0] mon_pc;
  logic [4:0]  mon_rd_addr;
  logic [31:0] mon_rd_data;
  logic        mon_reg_write;
`endif

  // -------------------------------------------------------------------------
  // DUT Instantiation
  // -------------------------------------------------------------------------
  moola_soc_top #(
    .BASE_ADDR    (32'h8000_0000),
    .ADDR_WIDTH   (14),
    .INIT_FILE_EN (1'b1),
    .INIT_FILE    ("tb/program.hex")
  ) dut (
    .clk   (clk),
    .rst_n (rst_n)
`ifdef VERIFICATION
    ,
    .load_en       (load_en),
    .mon_valid     (mon_valid),
    .mon_pc        (mon_pc),
    .mon_rd_addr   (mon_rd_addr),
    .mon_rd_data   (mon_rd_data),
    .mon_reg_write (mon_reg_write)
`endif
  );

  // -------------------------------------------------------------------------
  // Clock Generator
  // -------------------------------------------------------------------------
  initial clk = 0;
  always #(CLK_PERIOD / 2) clk = ~clk;

  // -------------------------------------------------------------------------
  // Waveform Dump Setup
  // -------------------------------------------------------------------------
  initial begin
    $dumpfile("sim/tb_moola_soc_top.vcd");
    $dumpvars(0, tb_moola_soc_top);
  end

  // -------------------------------------------------------------------------
  // Execution Tracer & Monitor
  // -------------------------------------------------------------------------
  always @(posedge clk) begin
    if (rst_n) begin
      // Log memory writes (Stores)
      if (dut.u_core.dmem_req && (|dut.u_core.dmem_wstrb)) begin
        $display("[MEM_STORE] Time: %0t | Addr: 0x%08h | WData: 0x%08h | WStrb: %b",
                 $time, dut.u_core.dmem_addr, dut.u_core.dmem_wdata, dut.u_core.dmem_wstrb);
      end

      // Log Register File Writes (Write-Back stage)
      if (dut.u_core.wb_reg_write && (dut.u_core.wb_rd_addr != 5'd0)) begin
        $display("[REG_WRITE] Time: %0t | x%0d <= 0x%08h",
                 $time, dut.u_core.wb_rd_addr, dut.u_core.wb_final_data);
      end
    end
  end

  // -------------------------------------------------------------------------
  // Main Verification Driver & Watchdog
  // -------------------------------------------------------------------------
  initial begin
    $display("\n========================================================");
    $display("       STARTING MOOLA-V SOC FUNCTIONAL SIMULATION       ");
    $display("========================================================\n");

    // Initialize inputs & apply reset
    rst_n = 1'b0;

`ifdef VERIFICATION
    load_en = 1'b0;
    // Load instructions using the task in moola_dp_sram.sv
    dut.u_sram.load_hex("tb/program.hex");
`endif

    #(CLK_PERIOD * 3);

    // Release reset synchronously on clock falling edge
    @(negedge clk);
    rst_n = 1'b1;
    $display("[TB] Reset released. Core execution started...\n");

    // Watchdog loop
    for (int cycle = 0; cycle < MAX_CYCLES; cycle++) begin
      @(posedge clk);

      // Self-loop termination check: J . (0x0000006f) indicates program end
      if (dut.u_core.id_inst == 32'h0000_006f) begin
        $display("\n[TB] Detected termination loop (J .) at PC = 0x%08h", dut.u_core.id_pc);
        repeat (4) @(posedge clk); // Allow pipeline to drain in-flight instructions
        $display("[TB] Execution finished successfully at cycle %0d.", cycle + 4);
        $display("\n========================================================");
        $display("             TEST EXECUTION COMPLETED                   ");
        $display("========================================================\n");
        $finish;
      end
    end

    // Watchdog triggered
    $display("\n[ERROR] Simulation watchdog hit MAX_CYCLES (%0d). Halting.", MAX_CYCLES);
    $finish;
  end

endmodule : tb_moola_soc_top