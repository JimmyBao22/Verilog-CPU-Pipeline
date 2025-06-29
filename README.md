# Verilog-CPU-Pipeline - Pipelined CPU in Verilog

This project implements a pipelined processor for a custom 16-bit instruction set architecture (ISA), written in Verilog.

## Overview

The assignment involves:

- Completing the CPU pipeline implementation in `cpu.v`
- Preserving the interface and timing of `mem.v` and `regs.v`
- Writing and contributing a custom test program (`.hex`) and its expected output (`.ok`)
- Answering conceptual questions in `REPORT.txt`
- Evaluating performance via cycles-per-instruction (CPI) and output correctness

## Architecture

- **Word size**: 16 bits
- **Registers**: 16 general-purpose (`r0` to `r15`)
- **Special Register `r0`**:
  - Reading `r0` always returns 0
  - Writing to `r0` prints the character represented by the low 8 bits (ASCII)

## Instruction Set

| Encoding             | Instruction     | Description                                   |
|----------------------|------------------|----------------------------------------------|
| `0000aaaabbbbtttt`   | `sub rt,ra,rb`   | `rt = ra - rb`                               |
| `1000iiiiiiiitttt`   | `movl rt,i`      | `rt = sign_extend(i)`                        |
| `1001iiiiiiiitttt`   | `movh rt,i`      | `rt = (rt & 0xff) | (i << 8)`                |
| `1110aaaa0000tttt`   | `jz rt,ra`       | `if ra == 0: pc = rt else pc += 2`           |
| `1110aaaa0001tttt`   | `jnz rt,ra`      | `if ra != 0: pc = rt else pc += 2`           |
| `1110aaaa0010tttt`   | `js rt,ra`       | `if ra < 0: pc = rt else pc += 2`            |
| `1110aaaa0011tttt`   | `jns rt,ra`      | `if ra >= 0: pc = rt else pc += 2`           |
| `1111aaaa0000tttt`   | `ld rt,ra`       | `rt = mem[ra]`                               |
| `1111aaaa0001tttt`   | `st rt,ra`       | `mem[ra] = rt`                               |

Any illegal instruction halts the processor and ends simulation.

## Files

| File          | Description                              |
|---------------|------------------------------------------|
| `cpu.v`       | CPU Pipeline                             |
| `mem.v`       | Memory module                            |
| `regs.v`      | Register file                            |
| `counter.v`   | Cycle counter used for performance (CPI) |
| `clock.v`     | Clock signal generator                   |

## Test Structure

Each test consists of:

- `*.hex` - Your test program
- `*.ok`  - Expected output
- After simulation:
  - `*.raw` - Raw simulator output
  - `*.out` - Filtered output lines starting with `#`
  - `*.cycles` - Number of cycles the program took
  - `*.vcd` - Waveform dump for visualization

### To run tests:

    make test

### To make the output less noisy:

    make -s test

### To run one test

    make -s t0.test

### Make targets/files:
    <test name>.raw        => the raw output from running the test
    <test name>.out        => lines from *.raw that start with #
    <test name>.cycles     => number of cycles needed to run the test
    <test name>.vcd        => vcd file after running test
    <test name>.ok         => expected output
    <test name>.hex        => the test program
