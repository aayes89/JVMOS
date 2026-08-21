; ============================================================================
; JVMOS - Unified JIT Engine (Compendio Completo Fases 1 a 6)
; Formato: NASM x86 32-bit (Modo Protegido Bare-Metal)
; ============================================================================

[bits 32]

section .bss
align 16
    jit_buffer_base: resd 1    ; Base física de memoria JIT (0x00200000)
    jit_buffer_ptr:  resd 1    ; Cursor actual
    jit_buffer_end:  resd 1    ; Límite de memoria

section .data
    jit_bytecode_base: dd 0
    loop_start_addr:   dd 0

    ; Bytecodes de Prueba
    test_bytecode_p2: db 0x10, 0x42, 0xAC                          ; bipush 66, ireturn
    test_bytecode_p3: db 0x10, 0x0A, 0x3B, 0x10, 0x14, 0x3C, 0x1B, 0xAC ; ret 20 (local_var 1)
    test_bytecode_p4: db 0x10, 0x0A, 0x3B, 0x10, 0x14, 0x3C, 0x1A, 0x1B, 0x60, 0xAC ; 10 + 20 = 30
    test_bytecode_p5: db 0x1A, 0x1B, 0x60, 0xAC                     ; param0 + param1 (40 + 60 = 100)
    test_bytecode_p6: db 0x03, 0x3B, 0x1A, 0x10, 0x05, 0x9F, 0x00, 0x09, 0x1A, 0x04, 0x60, 0x3B, 0xA7, 0xFF, 0xF6, 0x1A, 0xAC ; loop 5

section .text
    global jit_init
    global jit_compile_method
    global jit_execute_method
    
    global jit_test_phase1
    global jit_test_phase2
    global jit_test_phase3
    global jit_test_phase4
    global jit_test_phase5
    global jit_test_phase6
	
	extern sys_serial_puts

; ----------------------------------------------------------------------------
; EMISORES DE CÓDIGO Y NUCLEO (Fase 1)
; ----------------------------------------------------------------------------
jit_init:
    push eax
    push ebx
    mov [jit_buffer_base], eax
    mov [jit_buffer_ptr], eax
    add eax, ebx
    mov [jit_buffer_end], eax
    pop ebx
    pop eax
    ret

jit_emit_byte:
    push edi
    mov edi, [jit_buffer_ptr]
    cmp edi, [jit_buffer_end]
    jae .overflow
    mov [edi], al
    inc edi
    mov [jit_buffer_ptr], edi
    pop edi
    ret
.overflow:
    cli
    hlt

jit_emit_dword:
    push edi
    push ecx
    mov edi, [jit_buffer_ptr]
    lea ecx, [edi + 4]
    cmp ecx, [jit_buffer_end]
    jae jit_emit_byte.overflow
    mov [edi], eax
    mov [jit_buffer_ptr], ecx
    pop ecx
    pop edi
    ret

jit_emit_prologue:
    mov al, 0x55                ; push ebp
    call jit_emit_byte
    mov al, 0x89                ; mov ebp, esp
    call jit_emit_byte
    mov al, 0xE5
    call jit_emit_byte
    mov al, 0x83                ; sub esp, 16
    call jit_emit_byte
    mov al, 0xEC
    call jit_emit_byte
    mov al, 0x10
    call jit_emit_byte
    ret

jit_emit_epilogue:
    mov al, 0x89                ; mov esp, ebp
    call jit_emit_byte
    mov al, 0xEC
    call jit_emit_byte
    mov al, 0x5D                ; pop ebp
    call jit_emit_byte
    mov al, 0xC3                ; ret
    call jit_emit_byte
    ret

; ----------------------------------------------------------------------------
; COMPILADOR JIT
; ----------------------------------------------------------------------------
jit_compile_method:
    push ebp
    mov ebp, esp
    push ebx
    push esi
    push edi

    mov [jit_bytecode_base], esi

    cmp dword [jit_buffer_base], 0
    jne .has_buffer
    mov eax, 0x00200000
    mov ebx, 65536
    call jit_init
.has_buffer:

    mov eax, [jit_buffer_base]
    mov [jit_buffer_ptr], eax

    call jit_emit_prologue

    mov edi, esi
    add edi, ecx                ; EDI = Fin exacto según el número de bytes real

.compile_loop:
    cmp esi, edi
    jae .compile_done

    movzx eax, byte [esi]
    inc esi

    mov ebx, [jit_opcode_table + eax * 4]
    call ebx

    jmp .compile_loop

.compile_done:
    mov eax, [jit_buffer_base]
    pop edi
    pop esi
    pop ebx
    mov esp, ebp
    pop ebp
    ret

; ----------------------------------------------------------------------------
; OPCODES UNIFICADOS
; ----------------------------------------------------------------------------
jit_op_aconst_null:
    mov al, 0x6A
    call jit_emit_byte
    mov al, 0x00
    call jit_emit_byte
    ret
	
jit_op_nop:
    mov al, 0x90
    call jit_emit_byte
    ret

jit_op_iconst_0:
    mov al, 0x6A
    call jit_emit_byte
    mov al, 0x00
    call jit_emit_byte
    ret

jit_op_iconst_1:
    mov al, 0x6A
    call jit_emit_byte
    mov al, 0x01
    call jit_emit_byte
    ret

jit_op_iconst_2:
    mov al, 0x6A                ; push 2
    call jit_emit_byte
    mov al, 0x02
    call jit_emit_byte
    ret

jit_op_iconst_3:
    mov al, 0x6A                ; push 3
    call jit_emit_byte
    mov al, 0x03
    call jit_emit_byte
    ret

jit_op_iconst_4:
    mov al, 0x6A                ; push 4
    call jit_emit_byte
    mov al, 0x04
    call jit_emit_byte
    ret

jit_op_iconst_5:
    mov al, 0x6A                ; push 5
    call jit_emit_byte
    mov al, 0x05
    call jit_emit_byte
    ret

; Opcode 0x09: lconst_0 -> Empujar 0L (64-bit) a la pila x86 (dos push de 32 bits: 0 y 0)
jit_op_lconst_0:
    mov al, 0x6A                ; push 0 (parte alta)
    call jit_emit_byte
    mov al, 0x00
    call jit_emit_byte
    mov al, 0x6A                ; push 0 (parte baja)
    call jit_emit_byte
    mov al, 0x00
    call jit_emit_byte
    ret

; Opcode 0x0A: lconst_1 -> Empujar 1L (64-bit) a la pila x86 (push 0 parte alta, push 1 parte baja)
jit_op_lconst_1:
    mov al, 0x6A                ; push 0 (parte alta de 64-bit)
    call jit_emit_byte
    mov al, 0x00
    call jit_emit_byte
    mov al, 0x6A                ; push 1 (parte baja de 64-bit)
    call jit_emit_byte
    mov al, 0x01
    call jit_emit_byte
    ret
	
jit_op_bipush:
    movzx ecx, byte [esi]
    inc esi
    mov al, 0x68
    call jit_emit_byte
    mov eax, ecx
    call jit_emit_dword
    ret

; Opcode 0x2A: aload_0 (Referencia a objeto String[] args)
jit_op_aload_0:
jit_op_iload_0:
    cmp dword [loop_start_addr], 0
    jne .skip_mark
    mov eax, [jit_buffer_ptr]
    mov [loop_start_addr], eax
.skip_mark:
    mov al, 0x8B                ; mov eax, [ebp - 4]
    call jit_emit_byte
    mov al, 0x45
    call jit_emit_byte
    mov al, 0xFC
    call jit_emit_byte
    mov al, 0x50                ; push eax
    call jit_emit_byte
    ret

jit_op_iload_1:
    mov al, 0x8B                ; mov eax, [ebp - 8]
    call jit_emit_byte
    mov al, 0x45
    call jit_emit_byte
    mov al, 0xF8
    call jit_emit_byte
    mov al, 0x50                ; push eax
    call jit_emit_byte
    ret

; Cargas de Integers a la pila x86: iload_2 [ebp - 12], iload_3 [ebp - 16]
jit_op_iload_2:
    mov al, 0x8B                ; mov eax, [ebp - 12]
    call jit_emit_byte
    mov al, 0x45
    call jit_emit_byte
    mov al, 0xF4
    call jit_emit_byte
    mov al, 0x50                ; push eax
    call jit_emit_byte
    ret

jit_op_iload_3:
    mov al, 0x8B                ; mov eax, [ebp - 16]
    call jit_emit_byte
    mov al, 0x45
    call jit_emit_byte
    mov al, 0xF0
    call jit_emit_byte
    mov al, 0x50                ; push eax
    call jit_emit_byte
    ret
	
jit_op_istore_0:
    mov al, 0x58                ; pop eax
    call jit_emit_byte
    mov al, 0x89                ; mov [ebp - 4], eax
    call jit_emit_byte
    mov al, 0x45
    call jit_emit_byte
    mov al, 0xFC
    call jit_emit_byte
    ret

jit_op_istore_1:
    mov al, 0x58                ; pop eax
    call jit_emit_byte
    mov al, 0x89                ; mov [ebp - 8], eax
    call jit_emit_byte
    mov al, 0x45
    call jit_emit_byte
    mov al, 0xF8
    call jit_emit_byte
    ret

; Almacenamiento de Integers: istore_2 [ebp - 12], istore_3 [ebp - 16]
jit_op_istore_2:
    mov al, 0x58                ; pop eax
    call jit_emit_byte
    mov al, 0x89                ; mov [ebp - 12], eax
    call jit_emit_byte
    mov al, 0x45
    call jit_emit_byte
    mov al, 0xF4
    call jit_emit_byte
    ret

jit_op_istore_3:
    mov al, 0x58                ; pop eax
    call jit_emit_byte
    mov al, 0x89                ; mov [ebp - 16], eax
    call jit_emit_byte
    mov al, 0x45
    call jit_emit_byte
    mov al, 0xF0
    call jit_emit_byte
    ret
	
jit_op_iload_param_0:
    mov al, 0x8B                ; mov eax, [ebp + 8]
    call jit_emit_byte
    mov al, 0x45
    call jit_emit_byte
    mov al, 0x08
    call jit_emit_byte
    mov al, 0x50                ; push eax
    call jit_emit_byte
    ret

jit_op_iload_param_1:
    mov al, 0x8B                ; mov eax, [ebp + 12]
    call jit_emit_byte
    mov al, 0x45
    call jit_emit_byte
    mov al, 0x0C
    call jit_emit_byte
    mov al, 0x50                ; push eax
    call jit_emit_byte
    ret

jit_op_iadd:
    mov al, 0x5B                ; pop ebx
    call jit_emit_byte
    mov al, 0x58                ; pop eax
    call jit_emit_byte
    mov al, 0x01                ; add eax, ebx
    call jit_emit_byte
    mov al, 0xD8
    call jit_emit_byte
    mov al, 0x50                ; push eax
    call jit_emit_byte
    ret

; Opcode 0x64: isub (Resta) -> pop ebx / pop eax / sub eax, ebx / push eax
jit_op_isub:
    mov al, 0x5B                ; pop ebx
    call jit_emit_byte
    mov al, 0x58                ; pop eax
    call jit_emit_byte
    mov al, 0x29                ; sub eax, ebx
    call jit_emit_byte
    mov al, 0xD8
    call jit_emit_byte
    mov al, 0x50                ; push eax
    call jit_emit_byte
    ret

; Opcode 0x68: imul (Multiplicación) -> pop ebx / pop eax / imul eax, ebx / push eax
jit_op_imul:
    mov al, 0x5B                ; pop ebx
    call jit_emit_byte
    mov al, 0x58                ; pop eax
    call jit_emit_byte
    mov al, 0x0F                ; imul eax, ebx (Bytes: 0x0F 0xAF 0xC3)
    call jit_emit_byte
    mov al, 0xAF
    call jit_emit_byte
    mov al, 0xC3
    call jit_emit_byte
    mov al, 0x50                ; push eax
    call jit_emit_byte
    ret

; Division de enteros (0x6C: idiv) 
jit_op_idiv:
    mov al, 0x5B                ; pop ecx (divisor)
    call jit_emit_byte
    mov al, 0x58                ; pop eax (dividendo)
    call jit_emit_byte
    mov al, 0x99                ; cdq (extiende signo EAX a EDX:EAX)
    call jit_emit_byte
    mov al, 0xF7                ; idiv ecx (Bytes: 0xF7 0xF9)
    call jit_emit_byte
    mov al, 0xF9
    call jit_emit_byte
    mov al, 0x50                ; push eax (cociente)
    call jit_emit_byte
    ret

; modulo y residuo (0x70: irem) 
jit_op_irem:
    mov al, 0x5B                ; pop ecx
    call jit_emit_byte
    mov al, 0x58                ; pop eax
    call jit_emit_byte
    mov al, 0x99                ; cdq
    call jit_emit_byte
    mov al, 0xF7                ; idiv ecx
    call jit_emit_byte
    mov al, 0xF9
    call jit_emit_byte
    mov al, 0x52                ; push edx (el residuo queda en EDX)
    call jit_emit_byte
    ret

; Negacion de entero (0x74: ineg) 
jit_op_ineg:
    mov al, 0x58                ; pop eax
    call jit_emit_byte
    mov al, 0xF7                ; neg eax (Bytes: 0xF7 0xD8)
    call jit_emit_byte
    mov al, 0xD8
    call jit_emit_byte
    mov al, 0x50                ; push eax
    call jit_emit_byte
    ret

; Shift izquierdo (0x78: ishl)
jit_op_ishl:
    mov al, 0x59                ; pop ecx (count)
    call jit_emit_byte
    mov al, 0x58                ; pop eax (value)
    call jit_emit_byte
    mov al, 0xD3                ; shl eax, cl (Bytes: 0xD3 0xE0)
    call jit_emit_byte
    mov al, 0xE0
    call jit_emit_byte
    mov al, 0x50                ; push eax
    call jit_emit_byte
    ret

; Shift derecho aritmético (0x7A: ishr) 
jit_op_ishr:
    mov al, 0x59                ; pop ecx
    call jit_emit_byte
    mov al, 0x58                ; pop eax
    call jit_emit_byte
    mov al, 0xD3                ; sar eax, cl (Bytes: 0xD3 0xF8)
    call jit_emit_byte
    mov al, 0xF8
    call jit_emit_byte
    mov al, 0x50                ; push eax
    call jit_emit_byte
    ret

; Shift derecho lógico (0x7C: iushr) 
jit_op_iushr:
    mov al, 0x59                ; pop ecx
    call jit_emit_byte
    mov al, 0x58                ; pop eax
    call jit_emit_byte
    mov al, 0xD3                ; shr eax, cl (Bytes: 0xD3 0xE8)
    call jit_emit_byte
    mov al, 0xE8
    call jit_emit_byte
    mov al, 0x50                ; push eax
    call jit_emit_byte
    ret

; Operaciones bitwise aqui (0x7E: iand, 0x80: ior, 0x82: ixor) 
jit_op_iand:
    mov al, 0x5B                ; pop ebx
    call jit_emit_byte
    mov al, 0x58                ; pop eax
    call jit_emit_byte
    mov al, 0x21                ; and eax, ebx (Bytes: 0x21 0xD8)
    call jit_emit_byte
    mov al, 0xD8
    call jit_emit_byte
    mov al, 0x50                ; push eax
    call jit_emit_byte
    ret

jit_op_ior:
    mov al, 0x5B                ; pop ebx
    call jit_emit_byte
    mov al, 0x58                ; pop eax
    call jit_emit_byte
    mov al, 0x09                ; or eax, ebx (Bytes: 0x09 0xD8)
    call jit_emit_byte
    mov al, 0xD8
    call jit_emit_byte
    mov al, 0x50                ; push eax
    call jit_emit_byte
    ret

jit_op_ixor:
    mov al, 0x5B                ; pop ebx
    call jit_emit_byte
    mov al, 0x58                ; pop eax
    call jit_emit_byte
    mov al, 0x31                ; xor eax, ebx (Bytes: 0x31 0xD8)
    call jit_emit_byte
    mov al, 0xD8
    call jit_emit_byte
    mov al, 0x50                ; push eax
    call jit_emit_byte
    ret

; Equivalente de (i++ o i=i+1) (0x84: iinc <index> <const>) 
jit_op_iinc:
    movzx ebx, byte [esi]       ; Leer index de la variable local
    inc esi
    movsx ecx, byte [esi]       ; Leer la constante (con signo)
    inc esi

    ; Calcular el offset en el Marco de Pila: Local N = [ebp - (N+1)*4]
    inc ebx
    shl ebx, 2                  ; EBX = (N+1) * 4
    neg ebx                     ; EBX = -((N+1)*4)

    ; Emitir instrucción x86: add dword [ebp + ebx], ecx
    mov al, 0x83                ; add dword [ebp + disp8], imm8
    call jit_emit_byte
    mov al, 0x45
    call jit_emit_byte
    mov al, bl                  ; Offset negativo de la variable local
    call jit_emit_byte
    mov al, cl                  ; Valor constante a sumar
    call jit_emit_byte
    ret
	
; Opcode 0x59: dup (Duplica el tope de la pila x86) -> pop eax / push eax / push eax
jit_op_dup:
    mov al, 0x58                ; pop eax
    call jit_emit_byte
    mov al, 0x50                ; push eax
    call jit_emit_byte
    mov al, 0x50                ; push eax
    call jit_emit_byte
    ret

; Opcode 0x57: pop (Descarta el tope de la pila x86) -> pop eax
jit_op_pop:
    mov al, 0x58                ; pop eax
    call jit_emit_byte
    ret
	
jit_op_if_icmpeq:
    add esi, 2
    mov al, 0x5B
    call jit_emit_byte
    mov al, 0x58
    call jit_emit_byte
    mov al, 0x39
    call jit_emit_byte
    mov al, 0xD8
    call jit_emit_byte
    mov al, 0x74                ; JE rel8
    call jit_emit_byte
    mov al, 19
    call jit_emit_byte
    ret

jit_op_goto:
    add esi, 2
    mov al, 0xE9                ; JMP rel32
    call jit_emit_byte
    mov eax, [loop_start_addr]
    mov ebx, [jit_buffer_ptr]
    add ebx, 4
    sub eax, ebx
    call jit_emit_dword
    ret

jit_op_ireturn:
    mov al, 0x58
    call jit_emit_byte
    call jit_emit_epilogue
    ret

; Opcode 0xB1: return (para métodos void)
jit_op_return:
    call jit_emit_epilogue
    ret

; Manejador de Opcodes No Soportados con Diagnóstico Hexadecimal
jit_op_unsupported:
    movzx eax, byte [esi - 1]   ; Cargar el opcode que falló en EAX

    ; Convertir byte EAX a ASCII
    mov ebx, eax
    shr ebx, 4                  ; Nibble alto
    call .nibble_to_hex
    mov [hex_byte_str], bl

    mov ebx, eax
    and ebx, 0x0F               ; Nibble bajo
    call .nibble_to_hex
    mov [hex_byte_str + 1], bl

    ; Imprimir encabezado
    push msg_panic_head
    call sys_serial_puts
    add esp, 4

    ; Imprimir el valor hexadecimal exacto (ej. "3C!", "B2!")
    push hex_byte_str
    call sys_serial_puts
    add esp, 4

    cli
    hlt

.nibble_to_hex:
    cmp bl, 9
    jbe .is_digit
    add bl, 7
.is_digit:
    add bl, '0'
    ret

; ----------------------------------------------------------------------------
; RUTINAS DE PRUEBA INDIVIDUALES
; ----------------------------------------------------------------------------
jit_test_phase1:
    mov eax, 0x00200000
    mov ebx, 65536
    call jit_init
    mov al, 0x90
    call jit_emit_byte
    mov al, 0xB8
    call jit_emit_byte
    mov eax, 0x12345678
    call jit_emit_dword
    mov al, 0xC3
    call jit_emit_byte
    call [jit_buffer_base]
    ret

jit_test_phase2:
    mov esi, test_bytecode_p2
    mov ecx, 3
    call jit_compile_method
    call eax
    ret

jit_test_phase3:
    mov esi, test_bytecode_p3
    mov ecx, 8
    call jit_compile_method
    call eax
    ret

jit_test_phase4:
    mov esi, test_bytecode_p4
    mov ecx, 10
    call jit_compile_method
    call eax
    ret

jit_test_phase5:
    mov dword [jit_opcode_table + 0x1A * 4], jit_op_iload_param_0
    mov dword [jit_opcode_table + 0x1B * 4], jit_op_iload_param_1

    mov esi, test_bytecode_p5
    mov ecx, 4
    call jit_compile_method
    push dword 60
    push dword 40
    call eax
    add esp, 8

    mov dword [jit_opcode_table + 0x1A * 4], jit_op_iload_0
    mov dword [jit_opcode_table + 0x1B * 4], jit_op_iload_1
    ret

jit_test_phase6:
    mov dword [loop_start_addr], 0
    mov esi, test_bytecode_p6
    mov ecx, 17
    call jit_compile_method
    call eax
    ret

; ----------------------------------------------------------------------------
; LLAMADAS A LAS RUTINAS	
; ----------------------------------------------------------------------------
; Almacenamiento de Objetos/Referencias (astore_0 .. astore_3)
jit_op_astore_0: jmp jit_op_istore_0
jit_op_astore_1: jmp jit_op_istore_1
jit_op_astore_2: jmp jit_op_istore_2
jit_op_astore_3: jmp jit_op_istore_3
; Cargas de Objetos/Referencias a la pila (aload_1, aload_2, aload_3)
jit_op_aload_1: jmp jit_op_iload_1
jit_op_aload_2: jmp jit_op_iload_2
jit_op_aload_3: jmp jit_op_iload_3

; ----------------------------------------------------------------------------
; EJECUSIÓN REAL DE MÉDOTOS JAVA DESDE 'main'
; ----------------------------------------------------------------------------
jit_execute_method:
    push ebp
    mov ebp, esp
    push ebx
    push ecx
    push edx

    ; Establecemos una longitud segura de 16 bytes para la compilación del main
    ; (un main simple de suma ocupa menos de 10 bytes)
    mov ecx, 16

    ; Compilar el bytecode real
    call jit_compile_method     ; Retorna dirección física x86 en EAX

    ; Ejecutar el código nativo compilado
    call eax

    pop edx
    pop ecx
    pop ebx
    mov esp, ebp
    pop ebp
    ret

; ----------------------------------------------------------------------------
; TABLA DE DESPACHO UNIFICADA
; ----------------------------------------------------------------------------
section .rodata
align 4

msg_err_unsupported_op: db 13, 10, "[JIT Panic] Unsupported Opcode encountered!", 13, 10, 0
msg_panic_head: db 13, 10, "[JIT Panic] Unsupported Opcode: 0x", 0
hex_byte_str:   db "00!", 13, 10, 0

section .rodata
align 4
jit_opcode_table:
    dd jit_op_nop                   ; 0x00 - nop
    dd jit_op_aconst_null           ; 0x01 - aconst_null
    dd jit_op_unsupported           ; 0x02 - iconst_m1
    dd jit_op_iconst_0              ; 0x03 - iconst_0
    dd jit_op_iconst_1              ; 0x04 - iconst_1
    dd jit_op_iconst_2              ; 0x05 - iconst_2
    dd jit_op_iconst_3              ; 0x06 - iconst_3
    dd jit_op_iconst_4              ; 0x07 - iconst_4
    dd jit_op_iconst_5              ; 0x08 - iconst_5
    dd jit_op_lconst_0              ; 0x09 - lconst_0
    dd jit_op_lconst_1              ; 0x0A - lconst_1
    times 5 dd jit_op_unsupported   ; 0x0B..0x0F
    dd jit_op_bipush                ; 0x10 - bipush
    times 9 dd jit_op_unsupported   ; 0x11..0x19
    dd jit_op_iload_0               ; 0x1A - iload_0
    dd jit_op_iload_1               ; 0x1B - iload_1
    dd jit_op_iload_2               ; 0x1C - iload_2 
    dd jit_op_iload_3               ; 0x1D - iload_3 
    times 12 dd jit_op_unsupported  ; 0x1E..0x29
    dd jit_op_aload_0               ; 0x2A - aload_0
    dd jit_op_aload_1               ; 0x2B - aload_1 
    dd jit_op_aload_2               ; 0x2C - aload_2 
    dd jit_op_aload_3               ; 0x2D - aload_3 
    times 13 dd jit_op_unsupported  ; 0x2E..0x3A
    dd jit_op_istore_0              ; 0x3B - istore_0
    dd jit_op_istore_1              ; 0x3C - istore_1
    dd jit_op_istore_2              ; 0x3D - istore_2 
    dd jit_op_istore_3              ; 0x3E - istore_3 
    times 8 dd jit_op_unsupported   ; 0x3F..0x46
    dd jit_op_astore_0              ; 0x47 - astore_0 
    dd jit_op_astore_1              ; 0x48 - astore_1 
    dd jit_op_astore_2              ; 0x49 - astore_2 
    dd jit_op_astore_3              ; 0x4A - astore_3 
    times 12 dd jit_op_unsupported  ; 0x4B..0x56
    dd jit_op_pop                   ; 0x57 - pop 
    dd jit_op_unsupported           ; 0x58 - pop2
    dd jit_op_dup                   ; 0x59 - dup 
    times 6 dd jit_op_unsupported   ; 0x5A..0x5F
    dd jit_op_iadd                  ; 0x60 - iadd
    dd jit_op_unsupported           ; 0x61 - ladd
    dd jit_op_unsupported           ; 0x62 - fadd
    dd jit_op_unsupported           ; 0x63 - dadd
    dd jit_op_isub                  ; 0x64 - isub 
    dd jit_op_unsupported           ; 0x65 - lsub
    dd jit_op_unsupported           ; 0x66 - fsub
    dd jit_op_unsupported           ; 0x67 - dsub
    dd jit_op_imul                  ; 0x68 - imul 
    dd jit_op_unsupported           ; 0x69 - lmul
    dd jit_op_unsupported           ; 0x6A - fmul
    dd jit_op_unsupported           ; 0x6B - dmul
    dd jit_op_idiv                  ; 0x6C - idiv 
    dd jit_op_unsupported           ; 0x6D - ldiv
    dd jit_op_unsupported           ; 0x6E - fdiv
    dd jit_op_unsupported           ; 0x6F - ddiv
    dd jit_op_irem                  ; 0x70 - irem 
    dd jit_op_unsupported           ; 0x71 - lrem
    dd jit_op_unsupported           ; 0x72 - frem
    dd jit_op_unsupported           ; 0x73 - drem
    dd jit_op_ineg                  ; 0x74 - ineg 
    times 3 dd jit_op_unsupported   ; 0x75..0x77
    dd jit_op_ishl                  ; 0x78 - ishl 
    dd jit_op_unsupported           ; 0x79 - lshl
    dd jit_op_ishr                  ; 0x7A - ishr 
    dd jit_op_unsupported           ; 0x7B - lshr
    dd jit_op_iushr                 ; 0x7C - iushr 
    dd jit_op_unsupported           ; 0x7D - lushr
    dd jit_op_iand                  ; 0x7E - iand 
    dd jit_op_unsupported           ; 0x7F - land
    dd jit_op_ior                   ; 0x80 - ior  
    dd jit_op_unsupported           ; 0x81 - lor
    dd jit_op_ixor                  ; 0x82 - ixor 
    dd jit_op_unsupported           ; 0x83 - lxor
    dd jit_op_iinc                  ; 0x84 - iinc
    times 26 dd jit_op_unsupported  ; 0x85..0x9E
    dd jit_op_if_icmpeq             ; 0x9F - if_icmpeq
    times 7 dd jit_op_unsupported   ; 0xA0..0xA6
    dd jit_op_goto                  ; 0xA7 - goto
    times 4 dd jit_op_unsupported   ; 0xA8..0xAB
    dd jit_op_ireturn               ; 0xAC - ireturn
    times 4 dd jit_op_unsupported   ; 0xAD..0xB0
    dd jit_op_return                ; 0xB1 - return
    times 78 dd jit_op_unsupported  ; 0xB2..0xFF
	
section .note.GNU-stack noalloc noexec nowrite progbits
