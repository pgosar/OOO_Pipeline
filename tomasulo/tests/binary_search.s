.arch armv8-a
.text
.align	2
.p2align 3,,7
.global start

// Returns a pointer to the first target value
// in a sorted array of unsigned integers
start:
    adr x0, array   // Starting address of array 
    mov x1, #4      // Size of array
    mov x2, #1      // Target value
    movz x3, #0     // Left index
    sub x4, x1, #1  // Right index
    // mov x5       // Middle index


.loop:
    cmp x3, x4
    b.ge .end
    subs x5, x4, x3 // mid (x5) = right - left
    asr x5, x5, #1  // mid (x5) = (right - left)/2
    adds x5, x3, x5 // mid (x5) = left + ((right - left)/2)

    // Set x6 = &addr[mid]
    lsl x6, x5, #2
    adds x6, x0, x5 

    // Retrieve addr[mid]
    movz  x8, #0xffff 
    lsl   x8, x8, #16
    movk  x8, #0xffff
    ldur  x7, [x6]
    ands  x7, x7, x8

    cmp x7, x2 //compare array[mid] to target
    b.eq .returnMid
    b.ge .decRight
    add x3, x5, #1 // Fall through if less than
    b .loop

.returnMid:
    //once we find the target return
    mov x0, x6
    ret

.decRight:
    sub x4, x5, #1
    b .loop

.end:
    // Set x6 = &addr[mid]
    lsl x6, x5, #2
    adds x6, x0, x5 

    // x7 = addr[mid]
    movz  x8, #0xffff 
    lsl   x8, x8, #16
    movk  x8, #0xffff
    ldur  x7, [x6]
    ands  x7, x7, x8

    // Compare
    mov x9, #0
    cmp x2, x7
    csel x7, x5, x9, eq
    ret

array:
    .word 1, 2, 3, 4

.err:


	.size	start, .-start
	.ident	"GCC: (Ubuntu/Linaro 7.5.0-3ubuntu1~18.04) 7.5.0"
	.section	.note.GNU-stack,"",@progbits