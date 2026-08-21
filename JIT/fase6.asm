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
