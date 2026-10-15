# Five-Stage RISC-V CPU Design

## Scope

Implement a synthesizable 32-bit RISC-V CPU with a classic five-stage
`IF/ID/EX/MEM/WB` pipeline. The design supports the nine base instructions
shown in the course assignment, the required instruction extensions, forwarding,
one-cycle Load-use stalling, and one custom instruction.

The current deliverable is RTL and simulation infrastructure. Board-specific
pin constraints, bitstream generation, and the formal course report are out of
scope.

## ISA

Base instructions:

- R-type: `add`, `slt`, `sltu`
- I-type: `ori`, `lw`
- S-type: `sw`
- B-type: `beq`
- J-type: `jal`
- U-type: `lui`

Required extensions:

- Shift instructions: `sll`, `srl`, `sra`, `slli`, `srli`, `srai`
- Branches: `bne`, `blt`, `bge`
- Upper immediate: `auipc`
- Convenience immediate arithmetic: `addi`

Custom instruction:

- `mac rd, rs1, rs2`
- Encoding: `custom-0` opcode `0001011`, `funct3=000`, `funct7=0000000`
- Operation: `rd = rd + low32(rs1 * rs2)`
- Application: multiply-accumulate for low-power IoT signal processing

## Pipeline

- `IF`: fetch instruction, increment PC, redirect on taken branch or jump.
- `ID`: decode instruction, generate immediates, read the register file, and
  detect Load-use hazards.
- `EX`: execute ALU operations, evaluate branches, calculate MAC, and select
  forwarded operands.
- `MEM`: read or write data memory.
- `WB`: write the ALU or load result to the register file.

Branches and jumps resolve in EX. A taken control transfer flushes `IF/ID` and
`ID/EX`. A Load-use dependency stalls the PC and `IF/ID` for one cycle and
inserts a bubble into `ID/EX`.

## Forwarding

The forwarding unit selects the newest ready operand from `EX/MEM` or `MEM/WB`.
Load data is not forwarded from `EX/MEM`; the Load-use interlock covers that
case so the value becomes available from `MEM/WB` on the next cycle.

The custom `mac` instruction also reads its destination operand. That third
source participates in both Load-use detection and forwarding.

The decode stage includes a WB-to-ID bypass so an instruction reading a
register observes the same-cycle register-file write.

## Verification

- Unit tests cover the ALU, immediate generator, control decoder, forwarding
  unit, and hazard unit.
- Integration tests cover base instructions, extensions, forwarding, Load-use
  stalls, branch flushing, jump flushing, and `mac`.
- All tests run under ModelSim in batch mode and report a nonzero exit status
  on failure.
- A Vivado batch script prefers `xc7z020clg400-1` and falls back to an
  available 7-series device for a synthesis-level check.
