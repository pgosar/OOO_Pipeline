	.arch armv8-a
	.text
	.align	2
	.p2align 3,,7
    .global start
start:
    movz x0, #1
    movz x1, #2
    subs x3, x0, x1
    b .helper

.goback:
    eor 	x5, x5, x5
	mvn 	x5, x5
	stur	x0, [x5]
    ldur    x4, [x5]
	ret

.helper:
    movz x0, #65535
    movz x1, #42069
    b .goback

	.size	start, .-start
	.ident	"GCC: (Ubuntu/Linaro 7.5.0-3ubuntu1~18.04) 7.5.0"
	.section	.note.GNU-stack,"",@progbits
