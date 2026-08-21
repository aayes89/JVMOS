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
