# op1, op2, op3 and q_mul: hand-written RV32I.
#
# uint32_t op1_asm(uint32_t a, uint32_t b, int *n)   a0, a1, a2 -> a0
# uint32_t op2_asm(uint32_t a, uint32_t b)           a0, a1 -> a0
# uint32_t op3_asm(uint32_t a, uint32_t b)           a0, a1 -> a0
# int32_t  q_mul_asm(int32_t a, int32_t b)           a0, a1 -> a0
#
# RV32I and Zicsr only: no mul, div, rem, no floating point, no compressed
# instructions. q_mul forms a 64-bit product in a register pair. Tests:
# tests/tfixed.c.

    .text

    .globl  op1_asm
    .type   op1_asm, @function
    .align  2
#a0 a1 a2 最後return a0 用a2紀錄迴圈
op1_asm:
    li t1, 0
    beq a1, zero, op1_done #原本b就是0，不進迴圈

op1_loop:
    and t0, a0, a1 #t0用來放a&b的結果
    slli t0, t0, 1 #把t0左移(進位)
    xor a0, a0, a1
    add a1, zero, t0
    addi t1, t1, 1


    bne a1, zero, op1_loop

op1_done:
    sw t1, 0(a2)
    ret
    .size   op1_asm, .-op1_asm

    .globl  op2_asm
    .type   op2_asm, @function
    .align  2
op2_asm:
    sub a0, a0, a1
    ret
    .size   op2_asm, .-op2_asm

    .globl  op3_asm
    .type   op3_asm, @function
    .align  2
op3_asm:
    and t0, a0, a1
    andi t1,t0,1
    srli a0, a0, 1
    srli a1, a1, 1
    add a0, a0, a1
    add a0, a0, t1
    ret
    .size   op3_asm, .-op3_asm

    .globl  q_mul_asm
    .type   q_mul_asm, @function
    .align  2
q_mul_asm:
    xor t0, a0, a1
    bge a0, zero, a_ready
    sub a0, zero, a0
a_ready:
    bge a1, zero, b_ready
    sub a1, zero, a1
b_ready:
    li t1, 0 #被乘hi_part
    li t2, 0 #product low_part
    li t3, 0 #product hi_part
    beq a1, zero, mul_done #直接結束

mul_loop:
    andi t4, a1, 1
    beq t4, zero, mul_shift
    add t2, t2, a0
    sltu t4, t2, a0
    add t3, t3, t1
    add t3, t3, t4

mul_shift:
    srli t4, a0, 31
    slli t1, t1, 1
    or t1, t1, t4
    slli a0, a0, 1
    srli a1, a1, 1
    bne a1, zero, mul_loop

mul_done:
    bge t0, zero, mul_round
    not t2, t2
    not t3, t3
    addi t2, t2, 1
    bne t2, zero, mul_round
    addi t3, t3, 1

mul_round:
    li t4, 524288
    mv t5, t2
    add t2, t2, t4
    sltu t4, t2, t5
    add t3, t3, t4
    srli t2, t2, 20
    slli t3, t3, 12
    or a0, t2, t3
    ret
    .size   q_mul_asm, .-q_mul_asm
