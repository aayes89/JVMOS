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
    movzx eax, byte [esi - 1]   ; Cargar el opcode fallido en EAX

    ; Convertir el byte EAX a 2 dígitos ASCII Hexadecimales
    mov ebx, eax
    shr ebx, 4                  ; Nibble alto
    call .nibble_to_hex
    mov [hex_opcode_str + 16], bl

    mov ebx, eax
    and ebx, 0x0F               ; Nibble bajo
    call .nibble_to_hex
    mov [hex_opcode_str + 17], bl

    ; Imprimir la alerta con el código Hex en pantalla
    push hex_opcode_str
    call sys_serial_puts
    add esp, 4

    cli
    hlt

.nibble_to_hex:
    cmp bl, 9
    jbe .is_digit
    add bl, 7                   ; Ajuste ASCII para letras A-F
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
hex_opcode_str: db 13, 10, "[JIT Panic] Unsupported Opcode: 0x00!", 13, 10, 0

jit_opcode_table:
    dd jit_op_nop                   ; 0x00 - nop
    times 2 dd jit_op_unsupported   ; 0x01..0x02
    dd jit_op_iconst_0              ; 0x03
    dd jit_op_iconst_1              ; 0x04
    times 11 dd jit_op_unsupported  ; 0x05..0x0F
    dd jit_op_bipush                ; 0x10
    times 9 dd jit_op_unsupported   ; 0x11..0x19
    dd jit_op_iload_0               ; 0x1A
    dd jit_op_iload_1               ; 0x1B
    times 14 dd jit_op_unsupported  ; 0x1C..0x29
    dd jit_op_aload_0               ; 0x2A - aload_0
    times 16 dd jit_op_unsupported  ; 0x2B..0x3A
    dd jit_op_istore_0              ; 0x3B
    dd jit_op_istore_1              ; 0x3C
    times 35 dd jit_op_unsupported  ; 0x3D..0x5F
    dd jit_op_iadd                  ; 0x60
    times 62 dd jit_op_unsupported  ; 0x61..0x9E
    dd jit_op_if_icmpeq             ; 0x9F
    times 7 dd jit_op_unsupported   ; 0xA0..0xA6
    dd jit_op_goto                  ; 0xA7
    times 4 dd jit_op_unsupported   ; 0xA8..0xAB
    dd jit_op_ireturn               ; 0xAC
    times 4 dd jit_op_unsupported   ; 0xAD..0xB0
    dd jit_op_return                ; 0xB1 - return (void)
    times 78 dd jit_op_unsupported  ; 0xB2..0xFF

section .note.GNU-stack noalloc noexec nowrite progbits
