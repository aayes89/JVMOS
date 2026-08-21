; ============================================================================
; MINIJVM - JIT Engine (Fase 3: Local Variables & Native Stack Frame)
; Ensamblador puro NASM - x86 32 bits Bare-Metal
; ============================================================================

[bits 32]

section .text
    global jit_compile_method
    global jit_test_phase3

; ----------------------------------------------------------------------------
; BUFFER LOCAL AISLADO PARA LA FASE 3
; ----------------------------------------------------------------------------
section .bss
align 16
phase3_jit_buffer: resb 256
phase3_cursor:     resd 1

section .text

p3_emit_byte:
    mov edx, [phase3_cursor]
    mov [edx], al
    inc dword [phase3_cursor]
    ret

p3_emit_dword:
    mov edx, [phase3_cursor]
    mov [edx], eax
    add dword [phase3_cursor], 4
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

    ; Usar la memoria libre en 0x00200000 en lugar de la sección .bss
    mov dword [phase3_cursor], 0x00200000

    call p3_emit_prologue

    mov edi, esi
    add edi, ecx

.compile_loop:
    cmp esi, edi
    jae .compile_done

    movzx eax, byte [esi]
    inc esi

    mov ebx, [jit_opcode_table + eax * 4]
    call ebx

    jmp .compile_loop

.compile_done:
    ; Nota: p3_emit_epilogue ya es llamado dinámicamente por jit_op_ireturn
    mov eax, 0x00200000
    pop edi
    pop esi
    pop ebx
    mov esp, ebp
    pop ebp
    ret

; ----------------------------------------------------------------------------
; PRÓLOGO Y EPÍLOGO
; ----------------------------------------------------------------------------
p3_emit_prologue:
    ; push ebp (0x55)
    mov al, 0x55
    call p3_emit_byte

    ; mov ebp, esp (0x89 0xE5)
    mov al, 0x89
    call p3_emit_byte
    mov al, 0xE5
    call p3_emit_byte

    ; sub esp, 16 (0x83 0xEC 0x10)
    mov al, 0x83
    call p3_emit_byte
    mov al, 0xEC
    call p3_emit_byte
    mov al, 0x10
    call p3_emit_byte
    ret

p3_emit_epilogue:
    ; mov esp, ebp (0x89 0xEC)
    mov al, 0x89
    call p3_emit_byte
    mov al, 0xEC
    call p3_emit_byte

    ; pop ebp (0x5D)
    mov al, 0x5D
    call p3_emit_byte

    ; ret (0xC3)
    mov al, 0xC3
    call p3_emit_byte
    ret

; ----------------------------------------------------------------------------
; OPCODES TRADUCIDOS A X86
; ----------------------------------------------------------------------------
jit_op_nop:
    mov al, 0x90
    call p3_emit_byte
    ret

jit_op_bipush:
    movzx ecx, byte [esi]       ; Usar ECX temporalmente en lugar de EDX
    inc esi

    mov al, 0x68                ; push imm32
    call p3_emit_byte

    mov eax, ecx
    call p3_emit_dword
    ret

jit_op_istore_0:
    mov al, 0x58                ; pop eax
    call p3_emit_byte

    mov al, 0x89                ; mov [ebp - 4], eax
    call p3_emit_byte
    mov al, 0x45
    call p3_emit_byte
    mov al, 0xFC
    call p3_emit_byte
    ret

jit_op_istore_1:
    mov al, 0x58                ; pop eax
    call p3_emit_byte

    mov al, 0x89                ; mov [ebp - 8], eax
    call p3_emit_byte
    mov al, 0x45
    call p3_emit_byte
    mov al, 0xF8
    call p3_emit_byte
    ret

jit_op_iload_0:
    mov al, 0x8B                ; mov eax, [ebp - 4]
    call p3_emit_byte
    mov al, 0x45
    call p3_emit_byte
    mov al, 0xFC
    call p3_emit_byte

    mov al, 0x50                ; push eax
    call p3_emit_byte
    ret

jit_op_iload_1:
    mov al, 0x8B                ; mov eax, [ebp - 8]
    call p3_emit_byte
    mov al, 0x45
    call p3_emit_byte
    mov al, 0xF8
    call p3_emit_byte

    mov al, 0x50                ; push eax
    call p3_emit_byte
    ret

jit_op_ireturn:
    mov al, 0x58                ; pop eax
    call p3_emit_byte
    call p3_emit_epilogue
    ret

jit_op_unsupported:
    cli
    hlt

; ----------------------------------------------------------------------------
; PRUEBA FASE 3
; Bytecode: bipush 10 (0x10, 0x0A), istore_0 (0x3B), bipush 20 (0x10, 0x14),
;           istore_1 (0x3C), iload_0 (0x1A), ireturn (0xAC)
; ----------------------------------------------------------------------------
section .data
    test_bytecode_p3: db 0x10, 0x0A, 0x3B, 0x10, 0x14, 0x3C, 0x1B, 0xAC

section .text
jit_test_phase3:
    push ebp
    mov ebp, esp
    push ebx
    push esi
    push edi

    mov esi, test_bytecode_p3
    mov ecx, 8
    call jit_compile_method    ; Retorna puntero a phase3_jit_buffer en EAX

    call eax                    ; Ejecuta el código JIT compilado
                                ; EAX conserva el valor retornado (10)

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
jit_opcode_table:
    dd jit_op_nop                   ; 0x00
    times 15 dd jit_op_unsupported  ; 0x01..0x0F
    dd jit_op_bipush                ; 0x10
    times 9 dd jit_op_unsupported   ; 0x11..0x19
    dd jit_op_iload_0               ; 0x1A
    dd jit_op_iload_1               ; 0x1B
    times 31 dd jit_op_unsupported  ; 0x1C..0x3A (31 entradas)
    dd jit_op_istore_0              ; 0x3B
    dd jit_op_istore_1              ; 0x3C
    times 111 dd jit_op_unsupported ; 0x3D..0xAB (111 entradas)
    dd jit_op_ireturn               ; 0xAC
    times 83 dd jit_op_unsupported  ; 0xAD..0xFF (83 entradas)

section .note.GNU-stack noalloc noexec nowrite progbits
