.org 0x0
	b start_handler 			@ Pula para o código que trata o Reset

.org 0x4
	b undef_handler				@ Pula para o código que trata o instruçÕes inválidas

.org 0x8
	b svc_handler				@ Pula para o código que trata syscalls

.org 0xc
	b abort_handler1			@ Pula para o código que trata erros dos barramento ("Prefetch Abort")

.org 0x10
	b abort_handler2			@ Pula para o código que trata erros dos barramento ("Data Abort")

.org 0x18
	b irq_handler				@ Pula para o código que trata interrupções de hardware (IRQ)

.org 0x1c
	b fiq_handler				@ Pula para o código que trata interrupções de hardware (FIQ - modo rápido)

infinito:

	b infinito				@ Loop infinito do Sistema Operacional

.align 4

GPT_CR: 		.word 0x53FA0000	@ Endereço do Registrador de Controle do GPT
GPT_Prescaler:		.word 0x53FA0004	@ Endereço do Registrador Prescaler do GPT 
GPT_SR:			.word 0x53FA0008	@ Endereço do Registrador de Status do GPT
GPT_IR:			.word 0x53FA000C	@ Endereço do Registrador de Interrupt do GPT
GPT_OCR1:		.word 0x53FA0010	@ Endereço do Registrador Ouptut Compare 1 do GPT

UART1_URXD:		.word 0x53FBC000	@ Endereço do Registrador bla do UART
UART4_URXD:		.word 0x53FBC000	@ Endereço do Registrador Prescaler do GPT 
UART2_URXD:		.word 0x53FC0000	@ Endereço do Registrador de Status do GPT
UART3_URXD:		.word 0x53FC4000	@ Endereço do Registrador de Interrupt do GPT

start_handler:

	@ Configurar os Vetores de Exceção

	@ Inicializar a MMU

	@ Inicializar as pilhas e registradores

	@ Inicializar dispositivos de E/S críticos

	@ Habilitar Interrupções
	msr CPSR_c, #0x13 			@ Muda para o modo supervisor e habilita interrupções FIQ e IRQ

	@ Configurar o UART

	ldr r2, = UART1 			@ Carrega o Endereço da UART atual (UARTx)
	
	mov r1, 0x80
	add r0, r2, r1				@ Calcula o Endereço de UARTx-UCR1
	ldr r0, [r0]
	mov r1, 0x0001 				
	str r1, [r0]				@ Habilita o UART

	mov r1, 0x84
	add r0, r2, r1				@ Calcula o Endereço de UARTx-UCR2
	ldr r0, [r0]
	mov r1, 0x2127
	str r1, [r0]				@ Define o controle de fluxo de Hardware, o formato de dados e habilita o transmissor e o receptor.

	mov r1, 0x88
	add r0, r2, r1				@ Calcula o Endereço de UARTx-UCR3
	ldr r0, [r0]
	mov r1, 0x0704
	str r1, [r0]				@ Define UCR3[RXDMUXSEL] = 1

	mov r1, 0x8C
	add r0, r2, r1				@ Calcula o Endereço de UARTx-UCR4
	ldr r0, [r0]
	mov r1, 0x7C00
	str r1, [r0]				@ Define CTS Trigger Level como 31
	
	mov r1, 0x90
	add r0, r2, r1				@ Calcula o Endereço de UARTx-UFCR
	ldr r0, [r0]
	mov r1, 0x089E
	str r1, [r0]				@ Define o divisor de clock interno como 5 (clock de referênica = 100MHz/5). Define TXTl = 2 e RXTL = 30

	mov r1, 0xA4
	add r0, r2, r1				@ Calcula o Endereço de UARTx-UBIR
	ldr r0, [r0]
	mov r1, 0x08FF
	str r1, [r0]

	mov r1, 0xA8
	add r0, r2, r1				@ Calcula o Endereço de UARTx-UBMR				
	ldr r0, [r0]
	mov r1, 0x0C34
	str r1, [r0]				@ Define a taxa de transmissão como 921.6Kbps (baseado no clock de referência de 20MHz)
	
	@ UCR1 = 0x2201 - Não habilitaremos interrupções TRDY e RRDY 

	@ Configurar o GPT (General Purpouse Timer) 

	ldr	r0, =GPT_CR			@ Carrega o endereço de GPT_CR
	ldr	r0, [r0]			
	mov	r1, #0x00000041			@ Valor que habilita e configura o clock_src
	str	r1, [r0]			@ O Contador irá contar a cada ciclo do relógio dos periféricos do sistema

	ldr	r0, =GPT_Prescaler		@ Carrefa o endereço do GPT_Prescaler
	ldr	r0, [r0]		
	mov	r1, #0
	str	r1, [r0]			@ Mantemos o Prescaler zerado
	
	ldr	r0, =GPT_OCR1			@ Carrega o endereço do GPT_OCR1
	ldr	r0, [r0]			
	mov	r1, #100			@ Valor até o qual desejamos contar antes de gerar uma interrupção tipo "Output Compare Channel 1"
	str	r1, [r0]

	ldr	r0, =GPT_IR			@ Carrega o endereço de GPT_IR
	ldr	r0, [r0]			
	mov	r1, #1				@ Valor que habilita a interrupção "Output Compare Channel 1"
	str	r1, [r0]

	@ Configurar o TZIC (TrustZone Interrup Controller)

		@ Código fornecido pelo professor Edson Borin no enunciado do lab7 de MC404 1s2013

		@ Constantes para os endereços do TZIC
		@ (não são instruções, são diretivas do montador!)
		   .set TZIC_BASE, 0x0FFFC000
		   .set TZIC_INTCTRL, 0x0
		   .set TZIC_INTSEC1, 0x84 
		   .set TZIC_ENSET1, 0x104
		   .set TZIC_PRIOMASK, 0xC
		   .set TZIC_PRIORITY9, 0x424

		@ Liga o controlador de interrupções
		@ R1 <= TZIC_BASE
		ldr	r1, =TZIC_BASE
		@ Configura interrupção 39 do GPT como não segura
		mov	r0, #(1 << 7)
		str	r0, [r1, #TZIC_INTSEC1]
		@ Habilita interrupção 39 (GPT)
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
		@ Habilita o controlador de interrupções
		mov	r0, #1
		str	r0, [r1, #TZIC_INTCTRL]

undef_handler:

svc_handler:

	@ Trata a syscall write

		@ Escreve os R2 bytes do buffer no dispositivo UART. Retorna o número de bytes escritos (0 se nada for escrito, -1 se ocorrer algum erro). Essa implementação ignora arquivos e descritores de arquivos.

	@ Trata a syscall exit

		@ Encerra a execução do processo que a chamou, e libera seu PID para que possa ser usado por outro processo.

	@ Trata a syscall fork

		

	@ Trata a syscall getpid

		@ Retorna o Process ID do processo que a chamou

abort_handler1:

abort_handler2:

irq_handler:

	push{r0, r1}

	ldr	r0, =GPT_SR			@ Carrefa o endereço do GPT_SR
	ldr	r0, [r0]			
	mov	r1, #1				@ Valor que informa ao GPT que o processador está ciente de que ocorreu a interrupção
	str	r1, [r0]			@ GPT limpa a flag OF1

	pop{r0, r1}
	
	sub pc, pc, #4				@ Corrige o valor de PC de PC+8 para PC+4, endereço da próxima instrução
	movs pc, lr				@ Retorna para LR_irq e grava SPSR em CPSR

	@ Salva o Contexto

	@ Trata a Interrupção

	@ Restaura o Contexto

fiq_handler:
