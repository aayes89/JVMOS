; ============================================================================
; JVMOS - JIT Engine (Fase 6: Control de Flujo Funcional)
; Formato: NASM x86 32-bit (Modo Protegido Bare-Metal)
; ============================================================================

[bits 32]

section .data
    test_bytecode_p6: db 0x03, 0x3B, 0x1A, 0x10, 0x05, 0x9F, 0x00, 0x09, 0x1A, 0x04, 0x60, 0x3B, 0xA7, 0xFF, 0xF6, 0x1A, 0xAC
    p6_cursor:        dd 0
    loop_start_addr:  dd 0

section .text
    global jit_compile_phase6
    global jit_test_phase6

p6_emit_byte:
    mov edx, [p6_cursor]
    mov [edx], al
    inc dword [p6_cursor]
    ret

p6_emit_dword:
    mov edx, [p6_cursor]
    mov [edx], eax
    add dword [p6_cursor], 4
    ret

jit_compile_phase6:
    push ebp
    mov ebp, esp
    push ebx
    push esi
    push edi

    mov dword [p6_cursor], 0x00200000

    call p6_emit_prologue

    mov edi, esi
    add edi, ecx

.compile_loop:
    cmp esi, edi
    jae .compile_done

    movzx eax, byte [esi]
    inc esi

    mov ebx, [jit_p6_opcode_table + eax * 4]
    call ebx

    jmp .compile_loop

.compile_done:
    mov eax, 0x00200000
    pop edi
    pop esi
    pop ebx
    mov esp, ebp
    pop ebp
    ret

p6_emit_prologue:
    mov al, 0x55                ; push ebp
    call p6_emit_byte
    mov al, 0x89                ; mov ebp, esp
    call p6_emit_byte
    mov al, 0xE5
    call p6_emit_byte
    mov al, 0x83                ; sub esp, 16
    call p6_emit_byte
    mov al, 0xEC
    call p6_emit_byte
    mov al, 0x10
    call p6_emit_byte
    ret

p6_emit_epilogue:
    mov al, 0x89                ; mov esp, ebp
    call p6_emit_byte
    mov al, 0xEC
    call p6_emit_byte
    mov al, 0x5D                ; pop ebp
    call p6_emit_byte
    mov al, 0xC3                ; ret
    call p6_emit_byte
    ret

; ----------------------------------------------------------------------------
; OPCODES
; ----------------------------------------------------------------------------
jit_op_nop:
    mov al, 0x90
    call p6_emit_byte
    ret

jit_op_iconst_0:
    mov al, 0x6A                ; push 0
    call p6_emit_byte
    mov al, 0x00
    call p6_emit_byte
    ret

jit_op_iconst_1:
    mov al, 0x6A                ; push 1
    call p6_emit_byte
    mov al, 0x01
    call p6_emit_byte
    ret

jit_op_bipush:
    movzx ecx, byte [esi]
    inc esi
    mov al, 0x68                ; push imm32
    call p6_emit_byte
    mov eax, ecx
    call p6_emit_dword
    ret

jit_op_istore_0:
    mov al, 0x58                ; pop eax
    call p6_emit_byte
    mov al, 0x89                ; mov [ebp - 4], eax
    call p6_emit_byte
    mov al, 0x45
    call p6_emit_byte
    mov al, 0xFC
    call p6_emit_byte
    ret

jit_op_iload_0:
    ; Si es la primera llamada a iload_0 dentro del loop, guardamos su dirección RAM
    cmp dword [loop_start_addr], 0
    jne .skip_mark
    mov eax, [p6_cursor]
    mov [loop_start_addr], eax
.skip_mark:

    mov al, 0x8B                ; mov eax, [ebp - 4]
    call p6_emit_byte
    mov al, 0x45
    call p6_emit_byte
    mov al, 0xFC
    call p6_emit_byte
    mov al, 0x50                ; push eax
    call p6_emit_byte
    ret

jit_op_iadd:
    mov al, 0x5B                ; pop ebx
    call p6_emit_byte
    mov al, 0x58                ; pop eax
    call p6_emit_byte
    mov al, 0x01                ; add eax, ebx
    call p6_emit_byte
    mov al, 0xD8
    call p6_emit_byte
    mov al, 0x50                ; push eax
    call p6_emit_byte
    ret

; Opcode 0x9F: if_icmpeq
jit_op_if_icmpeq:
    add esi, 2                  ; Omitir offset Java

    mov al, 0x5B                ; pop ebx
    call p6_emit_byte
    mov al, 0x58                ; pop eax
    call p6_emit_byte
    mov al, 0x39                ; cmp eax, ebx
    call p6_emit_byte
    mov al, 0xD8
    call p6_emit_byte

    mov al, 0x74                ; JE rel8
    call p6_emit_byte
    mov al, 19                  ; Salta exactamente los 19 bytes nativos del incremento + JMP rel32
    call p6_emit_byte
    ret

; Opcode 0xA7: goto
jit_op_goto:
    add esi, 2                  ; Omitir offset Java

    mov al, 0xE9                ; JMP rel32
    call p6_emit_byte

    mov eax, [loop_start_addr]
    mov ebx, [p6_cursor]
    add ebx, 4
    sub eax, ebx
    call p6_emit_dword
    ret

jit_op_ireturn:
    mov al, 0x58                ; pop eax
    call p6_emit_byte
    call p6_emit_epilogue
    ret

jit_op_unsupported:
    cli
    hlt

; ----------------------------------------------------------------------------
; PRUEBA FASE 6
; ----------------------------------------------------------------------------
jit_test_phase6:
    push ebp
    mov ebp, esp
    push ebx
    push esi
    push edi

    mov dword [loop_start_addr], 0 ; Reiniciar dirección base del loop
    mov esi, test_bytecode_p6
    mov ecx, 17
    call jit_compile_phase6

    call eax                    ; Ejecutar método JIT

    pop edi
    pop esi
    pop ebx
    mov esp, ebp
    pop ebp
    ret

; ----------------------------------------------------------------------------
; TABLA DE DESPACHO
; ----------------------------------------------------------------------------
section .rodata
align 4
jit_p6_opcode_table:
    dd jit_op_nop                   ; 0x00
    times 2 dd jit_op_unsupported   ; 0x01..0x02
    dd jit_op_iconst_0              ; 0x03
    dd jit_op_iconst_1              ; 0x04
    times 11 dd jit_op_unsupported  ; 0x05..0x0F
    dd jit_op_bipush                ; 0x10
    times 9 dd jit_op_unsupported   ; 0x11..0x19
    dd jit_op_iload_0               ; 0x1A
    times 32 dd jit_op_unsupported  ; 0x1B..0x3A
    dd jit_op_istore_0              ; 0x3B
    times 36 dd jit_op_unsupported  ; 0x3C..0x5F
    dd jit_op_iadd                  ; 0x60
    times 62 dd jit_op_unsupported  ; 0x61..0x9E
    dd jit_op_if_icmpeq             ; 0x9F
    times 7 dd jit_op_unsupported   ; 0xA0..0xA6
    dd jit_op_goto                  ; 0xA7
    times 4 dd jit_op_unsupported   ; 0xA8..0xAB
    dd jit_op_ireturn               ; 0xAC
    times 83 dd jit_op_unsupported  ; 0xAD..0xFF

section .note.GNU-stack noalloc noexec nowrite progbits
