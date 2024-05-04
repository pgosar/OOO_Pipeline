.arch armv8-a
	.text
	.align	2
	.p2align 3,,7
    .global start
start:
    adr x0, array // Load address of array into x0
    mov x1, #4     // Set the target value
    mov x2, #1
    movz x3, #0 // initialization of left
    movz x4, #0 // initialization of right
    sub x4, x1, #1 //right = size - 1

.loop:
    cmp x3, x4
    b.gt .end
    movz x5, #0 //initialization of mid
    subs x5, x4, x3 //mid = right - left
    asr x5, x5, #1 // mid = (right - left) /2
    adds x5, x3, x5 //mid = left + (right - left) /2

    adds  x6, x0, x5, lsl #2 //x0 + mid * 4
    ldur  x7, [x6, #0]
    movz  x8, #0xffff 
    lsl   x8, x8, #16
    movk  x8, #0xffff
    ands  x7, x7, x8

    cmp x7, x2 //compare array[mid] to target
    b.eq .returnMid
    b.ge .decRight
    add x3, x5, #1
    b .loop

.returnMid:
    //once we find the target return
    subs x0, x0, x0
    adds x0, x0, x5
    ret

.decRight:
    sub x4, x5, #1
    b .loop

.end:
    movz x0, #0
    sub x0, x0, #1
    ret
array:
    .word 1, 2, 3, 4

	.size	start, .-start
	.ident	"GCC: (Ubuntu/Linaro 7.5.0-3ubuntu1~18.04) 7.5.0"
	.section	.note.GNU-stack,"",@progbits