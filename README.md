# Moola-V (MR5): 5-Stage Pipelined RV32I Processor Core

[![SystemVerilog](https://img.shields.io/badge/Language-SystemVerilog%202012-blue.svg)](https://en.wikipedia.org/wiki/SystemVerilog)
[![ISA](https://img.shields.io/badge/ISA-RISC--V%20RV32I-orange.svg)](https://riscv.org/)
[![Toolchain](https://img.shields.io/badge/Simulators-Icarus%20Verilog%20%2F%20GTKWave%20%2F%20Verilator-brightgreen.svg)](http://iverilog.icarus.com/)
[![License](https://img.shields.io/badge/License-MIT-lightgrey.svg)](LICENSE)

---

## 💡 Origin & Motivation

Designing a functional RISC-V processor from the ground up has been on my bucket list for a long time. With my semester break underway, I am taking this opportunity to dive deep into digital microarchitecture and processor design hands-on.

As a beginner in processor microarchitecture, my philosophy for this project is straightforward: **learn by building, breaking, analyzing waveforms, and debugging every single pipeline stage from scratch.**

### Why "Moola"?
In **Kannada (ಮೂಲ)**, the word **"Moola"** translates to **"Origin"**, **"Source"**, or **"Root Foundation"**. 

This name represents the essence of this project: building a clean-slate fundamental baseline integer processor core that serves as the root foundation for future microarchitectural explorations (such as hardware multipliers, branch predictors, cache controllers, and SoC peripherals).

---
## 📐 Microarchitecture Overview

![Moola-V Top-Level Block Diagram](docs/moola_top_level_block_diagram.png)


## 🎯 Target Specifications & Feature Set

This is an iterative, evolving design. The baseline target specifications for the initial milestone include:

* **Instruction Set Architecture (ISA):** 32-bit RISC-V Base Integer ISA (**RV32I**)
  * Support for all 37 base instructions across R, I, S, B, U, and J formats.
  * Standard 32 general-purpose architectural registers ($x0$ hardwired to 0).
* **Pipeline Microarchitecture:** Classical 5-stage in-order execution datapath:
  1. **Fetch (IF):** Program Counter sequencing with redirection logic.
  2. **Decode (ID):** Instruction decode, immediate sign-extension, and strict operand address filtering.
  3. **Execute (EX):** Standalone parameterized ALU and branch condition evaluation.
  4. **Memory (MEM):** Byte-addressable load/store handling with byte-enable masking.
  5. **Write-Back (WB):** Register file write-back with internal forwarding/write-through.
* **Hazard Management & Datapath Efficiency:**
  * Full RAW data forwarding network (EX-to-EX and MEM-to-EX operand bypassing).
  * Hardware Load-Use Hazard Detection Unit with automated 1-cycle interlock stalling.
  * Single-cycle pipeline cancellation and flushing on taken branches/jumps.
* **Memory Subsystem:** True Dual-Port (TDP) Byte-Enable SRAM interface ready for FPGA Block RAM (BRAM) inference.

---

## 🛠️ Toolchain & Software Stack

This project strictly utilizes open-source, vendor-neutral EDA tools:

| Category | Tool | Purpose |
| :--- | :--- | :--- |
| **HDL Language** | SystemVerilog (IEEE 1800-2012) | Synthesizable RTL design & verification |
| **Simulation** | Icarus Verilog (`iverilog`) / Verilator | Logic compilation, event-driven & cycle simulation |
| **Waveform Debug** | GTKWave | Signal tracing, bus inspection & hazard verification |
| **Toolchain & ISS** | GNU RISC-V GCC / Spike / Whisper | Bare-metal software compilation & golden model checking |
| **Synthesis & PnR** | Yosys / OpenROAD *(Planned)* | Open-source ASIC synthesis and implementation |

---

### Stage Datapath Mapping & Modules

| Pipeline Stage | Module Name | Primary Responsibilities |
| :--- | :--- | :--- |
| **Fetch (IF)** | `moola_fetch.sv` | Program counter generation (reset vector `0x8000_0000`), $+4$ sequential incrementer, branch/jump redirect mux. |
| **IF/ID Reg** | `moola_if_id_reg.sv` | Synchronous inter-stage register supporting synchronous reset, stall, and bubble injection. |
| **Decode (ID)** | `moola_decode.sv` | Immediate sign-extension, strict opcode-based $rs1$/$rs2$ address filtering (preventing false RAW hazard stalls), control signal decoding. |
| **ID/EX Reg** | `moola_id_ex_reg.sv` | Control and operand propagation with synchronous flush capability on hazards. |
| **Execute (EX)**| `moola_execute.sv` | Standalone parameterized 32-bit ALU instantiation, input operand selection ($PC, rs1, rs2, imm$, forwarded paths), branch target calculation, branch evaluation. |
| **EX/MEM Reg**| `moola_ex_mem_reg.sv`| Stores ALU result, store data, target register address, and memory control strobes. |
| **Memory (MEM)**| `moola_memory.sv` | Byte/half-word/word sign-extension, byte-enable strobe generation (`dmem_wstrb[3:0]`). |
| **MEM/WB Reg**| `moola_mem_wb_reg.sv`| Latches memory read data, ALU results, destination register address, and write-enable signals. |
| **Write-Back (WB)**| `moola_regfile.sv` | $32 \times 32$-bit dual-read single-write register file ($x0$ hardwired to zero) with internal write-through logic. |

---

## 📁 Repository Structure

```text
moola_riscv_core/
├── docs/
│   └── moola_top_level_block_diagram.png # 5-stage datapath architecture diagram
├── rtl/
│   ├── moola_pkg.sv                      # Global typedefs, opcodes, and enums
│   ├── moola_alu.sv                      # 32-bit ALU and branch comparator
│   ├── moola_decode.sv                   # Instruction decoder & immediate generator
│   └── moola_regfile.sv                  # 32x32-bit dual-read register file
├── sim/
│   ├── alu_sim                           # Compiled simulation binaries
│   ├── alu_sim.vcd                       # VCD waveform traces
│   ├── decode_sim
│   ├── decode_sim.vcd
│   ├── regfile_sim
│   └── regfile_sim.vcd
├── tb/
│   ├── tb_moola_alu.sv                   # ALU testbench
│   ├── tb_moola_decode.sv                # Decoder testbench
│   └── tb_moola_regfile.sv               # Register file testbench
├── software/                             # Bare-metal test programs (assembly & C)
└── README.md                             # Project documentation & progress tracker

``` 

## ⚡ Simulation & Waveform Debug

All unit testbenches are self-checking and dump waveform traces (`.vcd`) directly into the `sim/` directory.

1. 32-bit ALU & Branch Comparator
```bash
# Compile and simulate
iverilog -g2012 -o sim/alu_sim rtl/moola_pkg.sv rtl/moola_alu.sv tb/tb_moola_alu.sv
vvp sim/alu_sim

# View waveform trace
gtkwave sim/alu_sim.vcd &
```

2. Instruction Decoder & Immediate Generator
```bash
# Compile and simulate
iverilog -g2012 -o sim/decode_sim rtl/moola_pkg.sv rtl/moola_decode.sv tb/tb_moola_decode.sv
vvp sim/decode_sim

# View waveform trace
gtkwave sim/decode_sim.vcd &
```

3. General-Purpose Register File
```bash
# Compile and simulate
iverilog -g2012 -o sim/regfile_sim rtl/moola_pkg.sv rtl/moola_regfile.sv tb/tb_moola_regfile.sv
vvp sim/regfile_sim

# View waveform trace
gtkwave sim/regfile_sim.vcd &
```

---

🚀 Development Roadmap & Learning Journey
[x] Milestone 0: Architecture Specification & Microarchitecture Blueprint

[x] Milestone 1: Memory Subsystem Development (moola_dp_sram)

[x] Milestone 2: Core Stage Primitives (moola_pkg, moola_alu, moola_decode, moola_regfile)

[ ] Milestone 3: 5-Stage Pipeline Registers & Datapath Assembly (IF/ID, ID/EX, EX/MEM, MEM/WB)

[ ] Milestone 4: Hazard Detection & Forwarding Bypass Networks

[ ] Milestone 5: SRAM Memory Subsystem Integration & End-to-End Assembly Execution

[ ] Milestone 6: Official RISC-V Architectural Compliance Test Suite (riscv-tests)

[ ] Milestone 7: SkyWater 130nm ASIC Synthesis & Timing Closure Flow


🤝 Community & Feedback
This repository is built in public to document my engineering takeaways, microarchitecture trade-offs, and simulation hurdles step-by-step.

Suggestions, architecture advice, and code reviews from digital design and computer architecture engineers are warmly welcomed! Feel free to open an issue or start a discussion.


Author: Anand Nagaraj
GitHub: @AnandNag003