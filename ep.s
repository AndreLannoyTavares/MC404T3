_start:

.org 0x0
	b restart_handler 			@ Pula para o c�digo que trata o Reset

.org 0x4
	b undef_handler				@ Pula para o c�digo que trata o instru��es inv�lidas

.org 0x8
	b svc_handler				@ Pula para o c�digo que trata syscalls

.org 0xc
	b abort_handler1			@ Pula para o c�digo que trata erros dos barramento ("Prefetch Abort")

.org 0x10
	b abort_handler2			@ Pula para o c�digo que trata erros dos barramento ("Data Abort")

.org 0x18
	b irq_handler				@ Pula para o c�digo que trata interrup��es de hardware (IRQ)

.org 0x1c
	b fiq_handler				@ Pula para o c�digo que trata interrup��es de hardware (FIQ - modo r�pido)

.org 0x100

.align 4

GPT_CR: 		.word 0x53FA0000	@ Endere�o do Registrador de Controle do GPT
GPT_Prescaler:		.word 0x53FA0004	@ Endere�o do Registrador Prescaler do GPT 
GPT_SR:			.word 0x53FA0008	@ Endere�o do Registrador de Status do GPT
GPT_IR:			.word 0x53FA000C	@ Endere�o do Registrador de Interrupt do GPT
GPT_OCR1:		.word 0x53FA0010	@ Endere�o do Registrador Ouptut Compare 1 do GPT

CLOCK_COUNT:		.word 50		@ Valor at� o qual o GPT deve contar antes de gerar uma interrup��o

UART1_URXD:		.word 0x53FBC000	@ Endere�o do Registrador bla do UART
UART4_URXD:		.word 0x53FBC000	@ Endere�o do Registrador Prescaler do GPT 
UART2_URXD:		.word 0x53FC0000	@ Endere�o do Registrador de Status do GPT
UART3_URXD:		.word 0x53FC4000	@ Endere�o do Registrador de Interrupt do GPT

infinito:

	b infinito				@ Loop infinito do Sistema Operacional

restart_handler:

	@ Configurar os valores da Pilha das Pilhas

	.set USR_STACK, 0x11000
	.set SVC_STACK, 0x10800
	.set UND_STACK, 0x07c00
	.set ABT_STACK, 0x07800
	.set FIQ_STACK, 0x07400
	.set IRQ_STACK, 0x07000

	@ First configure stacks for all modes
	mov sp, #SVC_STACK 
	msr CPSR_c, #0xDF	@ Enter system mode, FIQ/IRQ disabled
	mov sp, #USR_STACK
	msr CPSR_c, #0xD1	@ Enter FIQ mode, FIQ/IRQ disabled
	mov sp, #FIQ_STACK
	msr CPSR_c, #0xD2	@ Enter IRQ mode, FIQ/IRQ disabled
	mov sp, #IRQ_STACK
	msr CPSR_c, #0xD7	@ Enter abort mode, FIQ/IRQ disabled
	mov sp, #ABT_STACK
	msr CPSR_c, #0xDB	@ Enter undefined mode, FIQ/IRQ disabled
	mov sp, #UND_STACK
	msr CPSR_c, #0x1F	@ Enter system mode, IRQ/FIQ enabled
	
	@ Habilitar Interrup��es

	msr CPSR_c, #0x13 			@ Muda para o modo supervisor e habilita interrup��es FIQ e IRQ

	@ Configurar o UART

	ldr r2, = UART1_URXD 			@ Carrega o Endere�o da UART atual (UARTx)
	
	mov r1, #0x80
	ldr r0, [r0]
	add r0, r2, r1				@ Calcula o Endere�o de UARTx-UCR1
	mov r1, #0x0001 				
	str r1, [r0]				@ Habilita o UART

	mov r1, #0x84
	ldr r0, [r0]
	add r0, r2, r1				@ Calcula o Endere�o de UARTx-UCR2
	ldr r1, =0x2127
	str r1, [r0]				@ Define o controle de fluxo de Hardware, o formato de dados e habilita o transmissor e o receptor.

	mov r1, #0x88
	ldr r0, [r0]
	add r0, r2, r1				@ Calcula o Endere�o de UARTx-UCR3
	ldr r1, =0x0704
	str r1, [r0]				@ Define UCR3[RXDMUXSEL] = 1

	mov r1, #0x8C
	ldr r0, [r0]
	add r0, r2, r1				@ Calcula o Endere�o de UARTx-UCR4
	ldr r1, =0x7C00
	str r1, [r0]				@ Define CTS Trigger Level como 31
	
	mov r1, #0x90
	ldr r0, [r0]
	add r0, r2, r1				@ Calcula o Endere�o de UARTx-UFCR
	ldr r1, =0x089E
	str r1, [r0]				@ Define o divisor de clock interno como 5 (clock de refer�nica = 100MHz/5). Define TXTl = 2 e RXTL = 30

	mov r1, #0xA4
	ldr r0, [r0]
	add r0, r2, r1				@ Calcula o Endere�o de UARTx-UBIR
	ldr r1, =0x08FF
	str r1, [r0]

	mov r1, #0xA8
	ldr r0, [r0]
	add r0, r2, r1				@ Calcula o Endere�o de UARTx-UBMR				
	ldr r1, =0x0C34
	str r1, [r0]				@ Define a taxa de transmiss�o como 921.6Kbps (baseado no clock de refer�ncia de 20MHz)
	
	@ UCR1 = #0x2201 - N�o habilitaremos interrup��es TRDY e RRDY 

	@ Configurar o GPT (General Purpouse Timer) 

	ldr	r0, =GPT_CR			@ Carrega o endere�o de GPT_CR
	ldr	r0, [r0]			
	mov	r1, #0x00000041			@ Valor que habilita e configura o clock_src
	str	r1, [r0]			@ O Contador ir� contar a cada ciclo do rel�gio dos perif�ricos do sistema

	ldr	r0, =GPT_Prescaler		@ Carrefa o endere�o do GPT_Prescaler
	ldr	r0, [r0]		
	mov	r1, #0
	str	r1, [r0]			@ Mantemos o Prescaler zerado
	
	ldr	r0, =GPT_OCR1			@ Carrega o endere�o do GPT_OCR1
	ldr	r0, [r0]			
	ldr	r1, =CLOCK_COUNT		@ Valor at� o qual desejamos contar antes de gerar uma interrup��o tipo "Output Compare Channel 1"
	ldr	r1, [r1]			
	str	r1, [r0]

	ldr	r0, =GPT_IR			@ Carrega o endere�o de GPT_IR
	ldr	r0, [r0]			
	mov	r1, #1				@ Valor que habilita a interrup��o "Output Compare Channel 1"
	str	r1, [r0]

	@ Configurar o TZIC (TrustZone Interrup Controller)

			   @ Constantes para os endere�os do TZIC
			   @ (n�o s�o instru��es, s�o diretivas do montador!)
			   .set TZIC_BASE, 0x0FFFC000
			   .set TZIC_INTCTRL, 0x0
			   .set TZIC_INTSEC1, 0x84 
			   .set TZIC_ENSET1, 0x104
			   .set TZIC_PRIOMASK, 0xC
			   .set TZIC_PRIORITY9, 0x424

			@ Liga o controlador de interrup��es
			@ R1 <= TZIC_BASE
			ldr	r1, =TZIC_BASE
			@ Configura interrup��o 39 do GPT como n�o segura
			mov	r0, #(1 << 7)
			str	r0, [r1, #TZIC_INTSEC1]
			@ Habilita interrup��o 39 (GPT)
			@ reg1 bit 7 (gpt)
			mov	r0, #(1 << 7)
			str	r0, [r1, #TZIC_ENSET1]
			@ Configure interrupt39 priority as 1
			@ reg9, byte 3
			ldr r0, [r1, #TZIC_PRIORITY9]
			bic r0, r0, #0xFF000000
			mov r2, #1
			orr r0, r0, r2, lsl #24
			str r0, [r1, #TZIC_PRIORITY9]
			@ Configure PRIOMASK as 0
			eor r0, r0, r0
			str r0, [r1, #TZIC_PRIOMASK]
			@ Habilita o controlador de interrup��es
			mov	r0, #1
			str	r0, [r1, #TZIC_INTCTRL]
			   
	b infinito				@ Loop infinito do Sistema Operacional

undef_handler:

svc_handler:

	@ Trata a syscall write

		@ Escreve os R2 bytes do buffer no dispositivo UART. Retorna o n�mero de bytes escritos (0 se nada for escrito, -1 se ocorrer algum erro). Essa implementa��o ignora arquivos e descritores de arquivos.

	@ Trata a syscall exit

		@ Encerra a execu��o do processo que a chamou, e libera seu PID para que possa ser usado por outro processo.

	@ Trata a syscall fork

		

	@ Trata a syscall getpid

		@ Retorna o Process ID do processo que a chamou

abort_handler1:

abort_handler2:

irq_handler:

	push {r0, r1}

	ldr	r0, =GPT_SR			@ Carrefa o endere�o do GPT_SR
	ldr	r0, [r0]			
	mov	r1, #1				@ Valor que informa ao GPT que o processador est� ciente de que ocorreu a interrup��o
	str	r1, [r0]			@ GPT limpa a flag OF1

	ldr 	r1, [r0]
	add	r1, r1, #1
	str	r1, [r0]

	pop {r0, r1}
	
	sub pc, pc, #4				@ Corrige o valor de PC de PC+8 para PC+4, endere�o da pr�xima instru��o
	movs pc, lr				@ Retorna para LR_irq e grava SPSR em CPSR

fiq_handler:

	sub pc, pc, #4				@ Corrige o valor de PC de PC+8 para PC+4, endere�o da pr�xima instru��o
	movs pc, lr
