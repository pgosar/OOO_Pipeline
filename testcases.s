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


    .align  2
    .p2align 3,,7
    .global is_same_tree
    .type   is_same_tree, %function

    is_same_tree:
        stp     x29, x30, [sp, -32]!
        cmp x0, #0
        b.eq .is_second_zero

        cmp x1, #0
        b.eq .is_other_zero
    
    

        
        
        movz  x9, #0
        add   x9, x9, x0
        orr   x0, x1, x0
        cbz   x0, .is_true //if both are null return true

        movz  x10, #0
        add   x10, x10, x1 // move x0 t0 x10
        
        
        ldur  x2, [x9, 16] //get the val from x9 (technically x0)
        ldur  x1, [x1, 16] //get the val from xq
        cmp   x2, x1
        b.ne  .is_false
        
        //prepping parameters for recursion for left side
        ldur  x0, [x9]  //check left of x0
        ldur  x1, [x10] //check left of x1
        stur  x9, [sp, #16]
        stur  x10, [sp, #24]
        bl    is_same_tree
        ldur  x9, [sp, #16]
        ldur  x10, [sp, #24]
        cbz   x0, .is_false //vals are not equao return false
        
        //prepping parameters and preserving old vals for recursion for right size

        ldur  x1, [x10, 8]
        ldur  x0, [x9, 8]
        stur  x9, [sp, #16]
        stur  x10, [sp, #24]
        bl    is_same_tree
        ldur  x9, [sp, #16]
        ldur  x10, [sp, #24]
        cmp   x0, 0
        b.ne  .is_false
        
        cmp   x0, 0
        b.ne  .is_false
    .is_true:
        movz x0, #1
        ldp  x29, x30, [sp], 32
        ret
    .is_false:
        ldp  x29, x30, [sp], 32
        ret

    .is_other_zero:
        cmp x0, #1
        movz x0, #0
        b.eq .is_false
        movz x0, #1
        b.ne .is_true

    .is_second_zero:
        cmp x1, #0
        b.eq .is_true
        movz x0, #0
        b.ne .is_false
       

    .size   is_same_tree, .-is_same_tree
    // ... and ends with the .size above this line.