# 转发和 Load-use 冒险集成测试。
# 第一段：连续 add 形成 EX/MEM 和 MEM/WB 转发链。
ori  x1, x0, 5
ori  x2, x0, 10
add  x3, x1, x2
add  x4, x3, x1
add  x5, x4, x3
# 第二段：先存储再加载，验证数据存储器通路。
sw   x5, 0(x0)
lw   x6, 0(x0)
# Load 后立即使用 x6，触发一次 Load-use 阻塞。
add  x7, x6, x1
lw   x8, 0(x0)
lw   x9, 0(x0)
# 第三段：验证 mac 读取普通源寄存器和旧 rd 累加值时都能正确转发。
mac  x10, x6, x1
lw   x11, 0(x0)
mac  x11, x1, x1
ori  x12, x0, 7
mac  x12, x1, x1
add  x13, x12, x1
mac  x14, x13, x13
add  x15, x14, x14
# 第四段：写入 2738 后立即读出，并用 Load 结果继续执行 mac。
sw   x15, 4(x0)
lw   x16, 4(x0)
mac  x17, x16, x1
halt:
# 程序自跳转，等待测试平台检查寄存器和数据存储器。
jal  x0, halt

