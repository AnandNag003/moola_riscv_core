//=============================================================================
// IP Name      : Moola True Dual-Port Byte-Enable SRAM (moola_dp_sram)
// Description  : Parameterized True Dual-Port Synchronous SRAM with
//                independent byte write strobes per port.
// Features     : 
//   - Parameterizable DATA_WIDTH, ADDR_WIDTH, and BYTE_WIDTH
//   - Independent Clock, Enable, Write-Strobe, Address, and Data buses
//   - Read-First synchronous memory array behavior
//   - ASIC standard-cell and FPGA synthesizable
//=============================================================================

`timescale 1ns / 1ps

module moola_dp_sram #(
  parameter DATA_WIDTH   = 32,                          // Width of data bus in bits
  parameter ADDR_WIDTH   = 6,                           // Default 64 words (256 B) for DFF synthesis
  parameter BYTE_WIDTH   = 8,                           // Bits per byte lane
  parameter NUM_BYTES    = DATA_WIDTH / BYTE_WIDTH,     // Number of byte strobes
  parameter INIT_FILE_EN = 0,                           // Enable pre-loading from file (sim only)
  parameter INIT_FILE    = "tb/program.hex"
)(
  // -------------------------------------------------------------------------
  // Port A Interface
  // -------------------------------------------------------------------------
  input  logic                      clk_a,
  input  logic                      rst_a,                    // Synchronous read-port reset
  input  logic                      en_a,                     // Port A chip enable
  input  logic [NUM_BYTES-1:0]      wstrb_a,                  // Port A byte-write enable mask
  input  logic [ADDR_WIDTH-1:0]     addr_a,                   // Port A word address
  input  logic [DATA_WIDTH-1:0]     wdata_a,                  // Port A write data
  output logic [DATA_WIDTH-1:0]     rdata_a,                  // Port A read data

  // -------------------------------------------------------------------------
  // Port B Interface
  // -------------------------------------------------------------------------
  input  logic                      clk_b,
  input  logic                      rst_b,                    // Synchronous read-port reset
  input  logic                      en_b,                     // Port B chip enable
  input  logic [NUM_BYTES-1:0]      wstrb_b,                  // Port B byte-write enable mask
  input  logic [ADDR_WIDTH-1:0]     addr_b,                   // Port B word address
  input  logic [DATA_WIDTH-1:0]     wdata_b,                  // Port B write data
  output logic [DATA_WIDTH-1:0]     rdata_b                   // Port B read data
);

  localparam DEPTH = 1 << ADDR_WIDTH;

  // Parameter Validation
`ifndef SYNTHESIS
  initial begin
    if (DATA_WIDTH % BYTE_WIDTH != 0) begin
      $fatal(1, "[moola_dp_sram] DATA_WIDTH (%0d) must be an integer multiple of BYTE_WIDTH (%0d).",
             DATA_WIDTH, BYTE_WIDTH);
    end
  end
`endif

  // Memory Array
  (* ram_style = "block" *) logic [BYTE_WIDTH-1:0] mem_array [NUM_BYTES-1:0][DEPTH-1:0];

  logic [DATA_WIDTH-1:0] rdata_a_reg;

  // Zero-Initialization & Optional File Preload (Simulation Only)
`ifndef SYNTHESIS
  initial begin
    for (int w = 0; w < DEPTH; w++) begin
      for (int b = 0; b < NUM_BYTES; b++) begin
        mem_array[b][w] = {BYTE_WIDTH{1'b0}};
      end
    end

    if (INIT_FILE_EN) begin
      logic [DATA_WIDTH-1:0] temp_init_mem [0:DEPTH-1];
      for (int w = 0; w < DEPTH; w++) begin
        temp_init_mem[w] = '0;
      end

`ifndef VERIFICATION
      $readmemh(INIT_FILE, temp_init_mem);
`endif

      for (int w = 0; w < DEPTH; w++) begin
        for (int b = 0; b < NUM_BYTES; b++) begin
          mem_array[b][w] = temp_init_mem[w][(b*BYTE_WIDTH) +: BYTE_WIDTH];
        end
      end
    end
  end
`endif

  // Port A Synchronous Logic (Read-First Mode)
  generate
    for (genvar i = 0; i < NUM_BYTES; i++) begin : gen_port_a
      always_ff @(posedge clk_a) begin
        if (rst_a) begin
          rdata_a_reg[(i*BYTE_WIDTH) +: BYTE_WIDTH] <= '0;
        end else if (en_a) begin
          rdata_a_reg[(i*BYTE_WIDTH) +: BYTE_WIDTH] <= mem_array[i][addr_a];
          if (wstrb_a[i]) begin
            mem_array[i][addr_a] <= wdata_a[(i*BYTE_WIDTH) +: BYTE_WIDTH];
          end
        end
      end
    end
  endgenerate

  // Port B Synchronous Write & Combinational Read
  generate
    for (genvar j = 0; j < NUM_BYTES; j++) begin : gen_port_b
      always_ff @(posedge clk_b) begin
        if (!rst_b && en_b && wstrb_b[j]) begin
          mem_array[j][addr_b] <= wdata_b[(j*BYTE_WIDTH) +: BYTE_WIDTH];
        end
      end

      assign rdata_b[(j*BYTE_WIDTH) +: BYTE_WIDTH] = (en_b) ? mem_array[j][addr_b] : '0;
    end
  endgenerate

  assign rdata_a = rdata_a_reg;

`ifdef VERIFICATION
  task load_hex(input string hex_path);
    logic [DATA_WIDTH-1:0] temp_load_mem [0:DEPTH-1];

    for (int w = 0; w < DEPTH; w++) begin
      temp_load_mem[w] = {DATA_WIDTH{1'b0}};
      for (int b = 0; b < NUM_BYTES; b++) begin
        mem_array[b][w] = {BYTE_WIDTH{1'b0}};
      end
    end

    $readmemh(hex_path, temp_load_mem);

    for (int w = 0; w < DEPTH; w++) begin
      for (int b = 0; b < NUM_BYTES; b++) begin
        mem_array[b][w] = temp_load_mem[w][(b*BYTE_WIDTH) +: BYTE_WIDTH];
      end
    end
  endtask
`endif

endmodule : moola_dp_sram