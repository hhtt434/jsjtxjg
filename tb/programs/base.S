# Base ISA and required extensions.
ori  x1, x0, 10
ori  x2, x0, 20
add  x3, x1, x2
slt  x4, x3, x2
slt  x5, x2, x3
ori  x6, x0, 0x7ff
addi x7, x0, -1
sltu x8, x7, x6
sltu x9, x6, x7
ori  x10, x0, 5
slli x11, x10, 3
srli x12, x7, 4
srai x13, x7, 4
ori  x14, x0, 0x40
lui  x15, 0x12345
here:
auipc x16, 0
sw   x3, 8(x0)
lw   x17, 8(x0)
beq  x3, x17, taken1
ori  x18, x0, 99
taken1:
bne  x3, x2, taken2
ori  x19, x0, 98
taken2:
blt  x2, x3, taken3
ori  x20, x0, 97
taken3:
bge  x1, x2, not_taken
ori  x21, x0, 7
not_taken:
jal  x22, jump_target
ori  x23, x0, 88
jump_target:
ori  x24, x0, 24
ori  x25, x0, 7
ori  x26, x0, 9
mac  x25, x26, x26
mac  x27, x26, x26
ori  x28, x0, 1
sll  x29, x28, x10
srl  x30, x7, x10
sra  x31, x7, x10
halt:
jal  x0, halt
