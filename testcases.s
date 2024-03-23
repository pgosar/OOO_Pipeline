    .arch armv8-a
    .text
    // Code for all functions go here.

    // ***** WEEK 1 deliverables *****
    .align  2
    .p2align 3,,7
    .global binary_search
    .type   binary_search, %function

    binary_search:
        movz x3, #0 // initialization of left
        movz x4, #0 // initialization of right
        sub x4, x1, #1 //right = size - 1
    
    .loop:
        cmp x3, x4
        b.gt .end
        movz x5, #0 //initialization of mid
        sub x5, x4, x3 //mid = right - left
        asr x5, x5, #1 // mid = (right - left) /2
        add x5, x3, x5 //mid = left + (right - left) /2

        add  x6, x0, x5, lsl #2 //x0 + mid * 4
        ldur  x7, [x6, #0]        
        ands  x7, x7, #0xffffffff 

        cmp x7, x2 //compare array[mid] to target
        b.eq .returnMid
        b.ge .decRight
        add x3, x5, #1
        b .loop

    .returnMid:
        sub x0, x0, x0
        add x0, x0, x5
        ret

    .decRight:
        sub x4, x5, #1
        b .loop

    .end:
        movz x0, #0
        sub x0, x0, #1
        ret

    

    .size   binary_search, .-binary_search
    // ... and ends with the .size above this line.