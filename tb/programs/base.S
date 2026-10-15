# 基础指令和扩展指令集成测试。
# 第一段：构造基础数据，并验证 add、slt、sltu 和逻辑立即数。
ori  x1, x0, 10
ori  x2, x0, 20
# 将 10 和 20 相加，后续访存和分支测试都会使用该结果。
add  x3, x1, x2
# 验证有符号和无符号比较方向。
slt  x4, x3, x2
slt  x5, x2, x3
ori  x6, x0, 0x7ff
addi x7, x0, -1
sltu x8, x7, x6
sltu x9, x6, x7
# 第二段：验证 I 型移位、U 型立即数和 auipc 的 PC 相对结果。
ori  x10, x0, 5
slli x11, x10, 3
srli x12, x7, 4
srai x13, x7, 4
ori  x14, x0, 0x40
lui  x15, 0x12345
here:
auipc x16, 0
# 第三段：通过 sw/lw 验证数据存储器读写和 Load 数据写回。
sw   x3, 8(x0)
lw   x17, 8(x0)
# 第四段：taken 分支跳过后面的常量写入，从而验证控制流冲刷。
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
# 第五段：验证定制 mac 的累加语义，以及寄存器形式的三种移位。
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
# 程序停在这一条自身跳转指令上，便于测试平台在固定周期后检查结果。
jal  x0, halt
