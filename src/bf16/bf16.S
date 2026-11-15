# BFloat16 routines: hand-written RV32I.
#
# uint16_t bf16_from_f32_asm(uint32_t f32bits)   a0 -> a0
# uint16_t bf16_mul_asm(uint16_t a, uint16_t b)  a0, a1 -> a0
# uint16_t bf16_sqrt_asm(uint16_t a)             a0 -> a0
#
# RV32I and Zicsr only: no mul, div, rem, no floating point, no compressed
# instructions. Tests: tests/tbf16.c.

    .text

    .globl  bf16_from_f32_asm
    .type   bf16_from_f32_asm, @function
    .align  2
bf16_from_f32_asm:   
	li t0, 0xFF    #t0存0xFF
	srli t1, a0, 23  #t1存a0 右移 23 (exponent part)
	and t2, t1, t0 #t2存t0跟t1 and運算
    li t3, 0xFF
	beq t2 , t3, InfNan #如果exponent全部都是1則branch
    srli t4, a0, 16
    andi t5, t4, 1
    add a0, a0, t5
    li t3, 0x7FFF
    add a0, a0, t3
InfNan:
    srli a0, a0, 16
    
    ret #共用ret
    
    .size   bf16_from_f32_asm, .-bf16_from_f32_asm

    .globl  bf16_mul_asm
    .type   bf16_mul_asm, @function
    .align  2

    #t1存exponent_a t2存fraction_a t0最後存sign
bf16_mul_asm:  #a->a0 b->a1
    srli t0, a0, 7 #t0存shifted a0
    andi t1, t0, 0xFF #t1放exponent_a

    andi t2, a0, 0x7F
    xor t3, a0, a1
    li t0, 0x8000
    and t0, t3, t0 #sign

    li t4,0xFF
    bne t1, t4, check_b #如果相等剛好執行下一行
    bne t2, zero, return_a

    #a是inf
    li t4, 0x7FFF
    and t4, a1, t4
    bne t4,zero,return_inf
    li a0,0x7FC0 #quiet Nan
    ret
return_inf:
    li t4,0x7F80
    or a0, t0, t4
    ret
return_a:
    ret

check_b:
    srli t3, a1, 7
    andi t3, t3, 0xFF #t3放exponent_b
    andi t4, a1, 0x7F #t4 放fraction_b

    li t5, 0xFF
    bne t3, t5, finite_zero
    bne t4, zero,return_b

    li t5, 0x7FFF
    and t6, a0, t5
    bne t6, zero, return_inf
    li a0, 0x7FC0 #到這邊已經可以return 0x7Fc0
    ret


return_b:
    add a0,a1, zero
    ret

return_zero:
    add a0, t0, zero
    ret

finite_zero:
    li t5, 0x7FFF
    and t6, a0, t5
    beq t6, zero, return_zero
    and t6, a1, t5
    beq t6, zero, return_zero

    #加入signnificand a check
    #t1存exponent_a t2存fraction_a t0最後存sign
    #t3放exponent_b t4放fraction_b
    add t6, zero, t2 #t6放significand_a
    add t2, zero, t1 #t2放exp_a
    beq t2,zero, a_sub

    ori t6, t6, 0x80
    j sig_b_check
a_sub: #正規化
    li t2, 1
    li t5,0x80

exp_a_loop:
    bgeu t6, t5,sig_b_check
    slli t6, t6, 1
    addi t2, t2, -1
    j exp_a_loop

sig_b_check:
    beq t3, zero, b_sub
    ori t4, t4, 0x80
    j mul_sig

b_sub:
    li t3, 1
    li t5, 0x80
    
exp_b_loop:
    bgeu t4, t5, mul_sig
    slli t4, t4, 1
    addi t3, t3, -1
    j exp_b_loop

mul_sig:
    li t1,0

mul_sig_loop:
    beq t4,zero,mul_sig_done
    andi t5, t4, 1
    beq t5, zero, mul_sig_shift
    add t1, t1, t6

mul_sig_shift:
    slli t6, t6, 1
    srli t4, t4, 1
    j mul_sig_loop

mul_sig_done:
    add t2, t2, t3
    addi t2, t2, -127

    srli t5, t1, 15
    beq t5, zero, mul_shift7
    srli t1, t1, 8
    addi t2, t2 ,1
    j mul_exp_check

mul_shift7:
    srli t1, t1, 7
mul_exp_check:
    li t5, 255
    bge t2, t5, return_inf

    li t5, -6
    blt t2, t5, return_zero

    andi t1, t1,0x7F
    bge zero, t2,mul_sub

    slli t2, t2, 7
    or a0, t2, t1
    or a0, a0, t0
    ret
mul_sub:
    li t5, 1
    sub t5, t5, t2

    srl t1, t1, t5
    or a0, t0, t1
    ret
    




    
    


    


    
    .size   bf16_mul_asm, .-bf16_mul_asm

    .globl  bf16_sqrt_asm
    .type   bf16_sqrt_asm, @function
    .align  2
bf16_sqrt_asm:
    li      a0, 0
    ret
    .size   bf16_sqrt_asm, .-bf16_sqrt_asm
