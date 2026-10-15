# Branch and jump control-flow tests.
ori x1, x0, 1
ori x2, x0, 2
beq x1, x2, not_taken
ori x3, x0, 3
not_taken:
bne x1, x2, taken1
ori x4, x0, 99
taken1:
blt x2, x1, taken2
ori x5, x0, 5
taken2:
bge x1, x2, taken3
ori x6, x0, 6
taken3:
jal x7, target
ori x8, x0, 88
target:
jal x0, target

