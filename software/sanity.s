.section .text
.globl _start
_start:
    li x1, 15       # load 15 into register x1
    li x2, 25       # load 25 into register x2
    add x3, x1, x2  # x3 = x1 + x2 (should be 40 / 0x28)
loop:
    j loop
