# Forwarding and Load-use dependencies.
ori  x1, x0, 5
ori  x2, x0, 10
add  x3, x1, x2
add  x4, x3, x1
add  x5, x4, x3
sw   x5, 0(x0)
lw   x6, 0(x0)
add  x7, x6, x1
lw   x8, 0(x0)
lw   x9, 0(x0)
mac  x10, x6, x1
lw   x11, 0(x0)
mac  x11, x1, x1
ori  x12, x0, 7
mac  x12, x1, x1
add  x13, x12, x1
mac  x14, x13, x13
add  x15, x14, x14
sw   x15, 4(x0)
lw   x16, 4(x0)
mac  x17, x16, x1
halt:
jal  x0, halt

