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
	srli t1, a0, 23  #t1存a0 右移 23 (exponent part)
	andi t1, t1, 0xFF #t2存t0跟t1 and運算
    li t0, 0xFF
	beq t1 , t0, InfNan #如果exponent全部都是1則branch

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
    srli t2, a0, 7            # t2 同時含符號和指數
    andi t1, a0, 0x7F         # t1 = 小數欄
    addi t0, t2, -1
    li   t5, 254
    bgeu t0, t5, .Lsqrt_special

sqrt_normal:
    ori  t1, t1, 0x80
    addi t2, t2, -127

    andi t0, t2, 1
    beq  t0, zero, sqrt_even_exp
    slli t1, t1, 1

sqrt_even_exp:
    srai t2, t2, 1
    addi t2, t2, 127
   

    addi t1, t1, 1
    slli t1, t1, 7
    addi t1, t1, -1          

    li   t3, 0x4000        
    sub t1, t1, t3
    li t4, 0x1000          

sqrt_int_loop:
       # t4 = 0x1000
    add  t5, t3, t4
    srli t3, t3, 1
    bltu t1, t5, .Lsqrt_400
    sub  t1, t1, t5
    add  t3, t3, t4

.Lsqrt_400:
    li   t4, 0x400
    add  t5, t3, t4
    srli t3, t3, 1
    bltu t1, t5, .Lsqrt_100
    sub  t1, t1, t5
    add  t3, t3, t4

.Lsqrt_100:
    li   t4, 0x100
    add  t5, t3, t4
    srli t3, t3, 1
    bltu t1, t5, .Lsqrt_40
    sub  t1, t1, t5
    add  t3, t3, t4

.Lsqrt_40:
    li   t4, 0x40
    add  t5, t3, t4
    srli t3, t3, 1
    bltu t1, t5, .Lsqrt_10
    sub  t1, t1, t5
    add  t3, t3, t4

.Lsqrt_10:
    li   t4, 0x10
    add  t5, t3, t4
    srli t3, t3, 1
    bltu t1, t5, .Lsqrt_4
    sub  t1, t1, t5
    add  t3, t3, t4

.Lsqrt_4:
    li   t4, 4
    add  t5, t3, t4
    srli t3, t3, 1
    bltu t1, t5, .Lsqrt_1
    sub  t1, t1, t5
    add  t3, t3, t4

.Lsqrt_1:
    addi t5, t3, 1
    srli t3, t3, 1
    bltu t1, t5, .Lsqrt_done
    addi t3, t3, 1

.Lsqrt_done:
    # 接原本的 andi t3, t3, 0x7F

    andi t3, t3, 0x7F        
    slli t2, t2, 7           
    or   a0, t2, t3
    ret
.Lsqrt_special:
    andi t2, t2, 0xFF
    li   t0, 0xFF
    bne  t2, t0, .Lsqrt_check_zero
    bne  t1, zero, .Lsqrt_return_a  # NaN 原樣回傳

.Lsqrt_check_zero:
    slli t0, a0, 17                # 丟掉符號，只留下其餘 15 位
    beq  t0, zero, .Lsqrt_return_0 # +0 或 -0
    srli t0, a0, 15
    bne  t0, zero, .Lsqrt_return_qnan
    beq  t2, zero, .Lsqrt_return_0 # 正的次正規數

.Lsqrt_return_a:
    ret                            # NaN 或 +Inf

.Lsqrt_return_qnan:
    li   a0, 0x7FC0
    ret

.Lsqrt_return_0:
    li   a0, 0
    ret

    .size bf16_sqrt_asm, .-bf16_sqrt_asm
