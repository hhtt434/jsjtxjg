# Implementation Plan

1. Create failing unit tests for ALU, immediate generation, control decode,
   forwarding, and Load-use hazard detection.
2. Implement the combinational CPU building blocks and run the unit tests.
3. Create failing integration tests for base instructions, extensions,
   hazards, control transfers, and the custom `mac` instruction.
4. Implement the five pipeline registers and top-level CPU.
5. Add a small assembly-to-hex test program generator and verify known
   encodings.
6. Run all ModelSim tests in batch mode.
7. Create and run a generic `xc7z020clg400-1` Vivado synthesis project.

