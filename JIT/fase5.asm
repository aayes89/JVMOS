; ============================================================================
; JVMOS - JIT Engine (Fase 5: Parámetros Dinámicos y Convención de Llamada)
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
