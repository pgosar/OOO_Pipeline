	.arch armv8-a
	.text
	.align	2
    .global start
start:
    // branch not taken -- tested on correct squashing
    movz x0, #1
    movz x1, #2
    subs x3, x0, x1
    b.ne .helper

.goback:
  // Print x0
  // correct: 1
  // eor 	x5, x5, x5
	// mvn 	x5, x5
  adds x0, x1, x0
  mov x5, 0x2000
	stur	x0, [x5, #8]
  ldur x10, [x5, #8]
	ret

.helper:
    movz x0, #65535
    movz x1, #42069
    b .goback

	.size	start, .-start
	.ident	"GCC: (Ubuntu/Linaro 7.5.0-3ubuntu1~18.04) 7.5.0"
	.section	.note.GNU-stack,"",@progbits
