  .arch armv8-a
  .text
  .align	2
  .p2align 3,,7
  .global start
start:
    add x1, x1, #0x1c
    br x1
.wrong:
    movz x2, #0xBAD
    movz x3, #5
    ret
.correct:
    movz x4, #20
    ret
	.size	start, .-start
	.ident	"GCC: (Ubuntu/Linaro 7.5.0-3ubuntu1~18.04) 7.5.0"
	.section	.note.GNU-stack,"",@progbits
