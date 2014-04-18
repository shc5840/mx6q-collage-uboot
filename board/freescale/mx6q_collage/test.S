	.text
	.arm
	
.global _test1
_test1:
	mov ip, lr
	bl LED_OFF_TEST
	mov	lr, ip
	mov pc, lr

.global _test2
_test2:
	mov ip, lr
	bl LED_ON_TEST
	mov	lr, ip
	mov pc, lr	
	
@ End Reset operation-----------------------------------------
LED_OFF_TEST:
	ldr r0, =0x020b4004		@ LED0 LED1 off
	ldr r1, =0x3
	str r1, [r0]
	bx lr
	
LED_ON_TEST:
	ldr r0, =0x020b4004		@ LED0 LED1 on
	ldr r1, =0x0
	str r1, [r0]
	bx lr
