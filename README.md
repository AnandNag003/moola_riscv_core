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

---

## 🎯 Target Specifications & Feature Set

The core has progressed from primitive blocks to a fully integrated 5-stage in-order pipeline:

* **Instruction Set Architecture (ISA):** 32-bit RISC-V Base Integer ISA (**RV32I**)
  * Support for all base instructions across R, I, S, B, U, and J formats.
  * Standard 32 general-purpose architectural registers ($x0$ hardwired to 0).
* **Pipeline Microarchitecture:** Classical 5-stage in-order execution datapath:
  1. **Fetch (IF):** Program counter generation (reset vector `0x8000_0000`), sequential $+4$ fetch address generator, branch/jump redirect mux.
  2. **Decode (ID):** Instruction decoding, immediate sign-extension, and strict opcode-qualified operand filtering.
  3. **Execute (EX):** 32-bit ALU operations, operand forwarding selection, branch condition evaluation, and jump target arithmetic.
  4. **Memory (MEM):** Byte-addressable load/store handling with byte-enable masking (`dmem_wstrb[3:0]`) and sign/zero extension (`LB`, `LBU`, `LH`, `LHU`, `LW`).
  5. **Write-Back (WB):** Register file write-back commit with internal forwarding/write-through.
* **Hazard Management & Datapath Efficiency:**
  * Full RAW data forwarding network (EX-to-EX and MEM-to-EX operand bypassing directly to ALU inputs).
  * Hardware Load-Use Hazard Detection Unit with automated 1-cycle stall bubble insertion.
  * Two-instruction pipeline flush mechanism on taken branches and jumps (`JAL`/`JALR`).
* **Memory Subsystem:** True Dual-Port (TDP) Byte-Enable synchronous SRAM interface (`moola_dp_sram.sv`) enabling simultaneous instruction fetch and data read/write transactions.

---

## 🛠️ Toolchain & Software Stack

This project strictly utilizes open-source, vendor-neutral EDA tools:

| Category | Tool | Purpose |
| :--- | :--- | :--- |
| **HDL Language** | SystemVerilog (IEEE 1800-2012) | Synthesizable RTL design & verification |
| **Simulation** | Icarus Verilog (`iverilog`) / Verilator | Logic compilation, event-driven & cycle simulation |
| **Waveform Debug** | GTKWave | Signal tracing, bus inspection & hazard verification |
| **Co-Simulation & Compliance** | Cocotb / Python ISS / RISCOF / Spike | Lock-step co-simulation & architectural compliance |
| **Synthesis & PnR** | Yosys / OpenROAD *(Planned)* | Open-source ASIC synthesis and implementation |

---

### Stage Datapath Mapping & Modules

| Pipeline Stage / Block | Module Name | Primary Responsibilities |
| :--- | :--- | :--- |
| **Global Package** | `moola_pkg.sv` | Global typedefs, opcode definitions, ALU operations, and branch types. |
| **Fetch (IF)** | `moola_fetch.sv` | Program counter generation (reset vector `0x8000_0000`), $+4$ sequential incrementer, branch/jump redirect mux. |
| **IF/ID Reg** | `moola_if_id_reg.sv` | Synchronous inter-stage register supporting synchronous reset, stall hold, and flush. |
| **Decode (ID)** | `moola_decode.sv` | Immediate sign-extension, strict opcode-based $rs1$/$rs2$ address filtering (preventing false RAW hazard stalls), control signal decoding. |
| **ID/EX Reg** | `moola_id_ex_reg.sv` | Control and operand propagation with synchronous bubble injection (flush) capability on hazards. |
| **Execute (EX)** | `moola_execute.sv` | Parameterized 32-bit ALU instantiation, input operand selection ($PC, rs1, rs2, imm$, forwarded paths), branch target calculation, branch evaluation. |
| **ALU Core** | `moola_alu.sv` | Arithmetic, logical, shift (SLL, SRL, SRA), comparison (SLT, SLTU), and branch comparator logic. |
| **Hazard Unit** | `moola_hazard_unit.sv` | Load-use hazard detection, PC stall, IF/ID stall, and ID/EX bubble insertion. |
| **Forwarding Unit** | `moola_forwarding_unit.sv` | RAW operand forwarding (EX-to-EX and MEM-to-EX) with $x0$ write protection. |
| **EX/MEM Reg** | `moola_ex_mem_reg.sv` | Stores ALU result, store data, target register address, and memory control strobes. |
| **Memory (MEM)** | `moola_memory.sv` | Byte/half-word/word sign-extension, byte-enable strobe generation (`dmem_wstrb[3:0]`). |
| **MEM/WB Reg** | `moola_mem_wb_reg.sv` | Latches memory read data, ALU results, destination register address, and write-enable signals. |
| **Write-Back (WB)** | `moola_regfile.sv` | $32 \times 32$-bit dual-read single-write register file ($x0$ hardwired to zero) with internal write-through logic. |
| **SRAM Subsystem** | `moola_dp_sram.sv` | True Dual-Port synchronous byte-enable SRAM macro for unified instruction and data storage. |
| **Core Top** | `moola_core.sv` | Datapath assembly connecting all 5 stages, pipeline registers, and hazard logic. |
| **SoC Top** | `moola_soc_top.sv` | Top-level SoC wrapper integrating `moola_core` with `moola_dp_sram`. |

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
│   ├── moola_regfile.sv                  # 32x32-bit dual-read register file
│   ├── moola_fetch.sv                    # Instruction fetch stage & PC sequencing
│   ├── moola_execute.sv                  # Execution stage wrapper
│   ├── moola_memory.sv                   # Memory access & sign/zero extension
│   ├── moola_if_id_reg.sv                # IF/ID pipeline boundary register
│   ├── moola_id_ex_reg.sv                # ID/EX pipeline boundary register
│   ├── moola_ex_mem_reg.sv               # EX/MEM pipeline boundary register
│   ├── moola_mem_wb_reg.sv               # MEM/WB pipeline boundary register
│   ├── moola_hazard_unit.sv              # Load-use hazard detection unit
│   ├── moola_forwarding_unit.sv          # RAW data forwarding unit
│   ├── moola_dp_sram.sv                  # True Dual-Port synchronous SRAM
│   ├── moola_core.sv                     # 5-stage RV32I core top-level datapath
│   └── moola_soc_top.sv                  # SoC wrapper (Core + TDP-SRAM)
├── sim/
│   ├── core_sim                          # Compiled core simulation binary
│   ├── core_sim.vcd                      # Core simulation waveform trace
│   ├── soc_sim                           # Compiled SoC simulation binary
│   └── tb_moola_soc_top.vcd              # SoC simulation waveform trace
├── tb/
│   ├── program.hex                       # Preloaded hex program for SoC simulation
│   ├── tb_moola_alu.sv                   # ALU unit testbench
│   ├── tb_moola_decode.sv                # Decoder unit testbench
│   ├── tb_moola_regfile.sv               # Register file unit testbench
│   ├── tb_moola_tdp_sram.sv              # Dual-port SRAM unit testbench
│   ├── tb_moola_core.sv                  # Full core pipeline & hazard testbench
│   └── tb_moola_soc_top.sv               # Complete SoC functional testbench
├── software/
│   └── sanity.s                          # Assembly sanity test program
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
4. Full Core Integration & Hazard Verification (tb_moola_core.sv)
Exercises RAW forwarding (EX-to-EX), load-use stall insertion, memory store-to-load ordering, and branch flush cancellation:
```bash

# Compile and simulate
iverilog -g2012 -DVERIFICATION -I rtl -o sim/core_sim \
  rtl/moola_pkg.sv rtl/moola_alu.sv rtl/moola_fetch.sv rtl/moola_if_id_reg.sv \
  rtl/moola_decode.sv rtl/moola_id_ex_reg.sv rtl/moola_execute.sv rtl/moola_ex_mem_reg.sv \
  rtl/moola_memory.sv rtl/moola_mem_wb_reg.sv rtl/moola_regfile.sv rtl/moola_hazard_unit.sv \
  rtl/moola_forwarding_unit.sv rtl/moola_core.sv tb/tb_moola_core.sv

vvp sim/core_sim

# View waveform trace
gtkwave sim/core_sim.vcd &
```

5. Full SoC Top-Level Verification (tb_moola_soc_top.sv)
Exercises the processor running out of the True Dual-Port synchronous SRAM macro:

```bash
# Compile and simulate
iverilog -g2012 -DVERIFICATION -I rtl -o sim/soc_sim \
  rtl/moola_pkg.sv rtl/moola_alu.sv rtl/moola_fetch.sv rtl/moola_if_id_reg.sv \
  rtl/moola_decode.sv rtl/moola_id_ex_reg.sv rtl/moola_execute.sv rtl/moola_ex_mem_reg.sv \
  rtl/moola_memory.sv rtl/moola_mem_wb_reg.sv rtl/moola_regfile.sv rtl/moola_hazard_unit.sv \
  rtl/moola_forwarding_unit.sv rtl/moola_dp_sram.sv rtl/moola_core.sv rtl/moola_soc_top.sv \
  tb/tb_moola_soc_top.sv

vvp sim/soc_sim

# View waveform trace
gtkwave sim/tb_moola_soc_top.vcd &
```

---

🚀 Development Roadmap & Learning Journey
[x] Milestone 0: Architecture Specification & Microarchitecture Blueprint

[x] Milestone 1: Memory Subsystem Development (moola_dp_sram.sv)

[x] Milestone 2: Core Stage Primitives (moola_pkg, moola_alu, moola_decode, moola_regfile)

[x] Milestone 3: 5-Stage Pipeline Registers & Datapath Assembly (moola_core.sv)

[x] Milestone 4: Hazard Detection & RAW Forwarding Bypass Networks (moola_hazard_unit, moola_forwarding_unit)

[x] Milestone 5: Synchronous Dual-Port SRAM SoC Integration (moola_soc_top.sv)

[ ] Milestone 6: Cocotb Python Co-Simulation Testbench & RISCOF Architectural Compliance Suite

[ ] Milestone 7: SkyWater 130nm ASIC Synthesis & Timing Closure Flow (OpenROAD / Tiny Tapeout)


🤝 Community & Feedback
This repository is built in public to document my engineering takeaways, microarchitecture trade-offs, and simulation hurdles step-by-step.

Suggestions, architecture advice, and code reviews from digital design and computer architecture engineers are warmly welcomed! Feel free to open an issue or start a discussion.


Author: Anand Nagaraj
GitHub: @AnandNag003