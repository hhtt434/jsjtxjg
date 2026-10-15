# 分支和跳转控制流测试。
# 第一段：beq 条件不成立，验证顺序执行路径。
ori x1, x0, 1
ori x2, x0, 2
beq x1, x2, not_taken
ori x3, x0, 3
not_taken:
# 第二段：bne 条件成立，跳过 x4 的错误路径写入。
bne x1, x2, taken1
ori x4, x0, 99
taken1:
# 第三段：blt 条件不成立，验证不跳转时继续执行后续指令。
blt x2, x1, taken2
ori x5, x0, 5
taken2:
# 第四段：bge 条件不成立，继续执行 x6 写入。
bge x1, x2, taken3
ori x6, x0, 6
taken3:
# 第五段：jal 跳转到 target，验证返回地址 PC+4 和错误路径冲刷。
jal x7, target
ori x8, x0, 88
target:
# 跳转目标处自循环，测试平台随后读取关键寄存器。
jal x0, target

