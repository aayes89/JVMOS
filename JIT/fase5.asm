; ============================================================================
; JVMOS - JIT Engine (Fase 5: Parámetros Dinámicos y Convención de Llamada)
; Formato: NASM x86 32-bit (Modo Protegido Bare-Metal)
; ============================================================================

[bits 32]

section .text
    global jit_compile_phase5
    global jit_test_phase5

p5_emit_byte:
    mov edx, [p5_cursor]
    mov [edx], al
    inc dword [p5_cursor]
    ret

p5_emit_dword:
    mov edx, [p5_cursor]
    mov [edx], eax
    add dword [p5_cursor], 4
    ret

; ----------------------------------------------------------------------------
; COMPILADOR JIT FASE 5
; ----------------------------------------------------------------------------
jit_compile_phase5:
    push ebp
    mov ebp, esp
    push ebx
    push esi
    push edi

    ; Usar memoria física ejecutable
    mov dword [p5_cursor], 0x00200000

    call p5_emit_prologue

    mov edi, esi
    add edi, ecx                ; Límite del bytecode

.compile_loop:
    cmp esi, edi
    jae .compile_done

    movzx eax, byte [esi]
    inc esi

    mov ebx, [jit_p5_opcode_table + eax * 4]
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
; PRÓLOGO Y EPÍLOGO CON MARCO DE PILA
; ----------------------------------------------------------------------------
p5_emit_prologue:
    mov al, 0x55                ; push ebp
    call p5_emit_byte
    mov al, 0x89                ; mov ebp, esp
    call p5_emit_byte
    mov al, 0xE5
    call p5_emit_byte
    mov al, 0x83                ; sub esp, 32 (Espacio para variables internas si se requieren)
    call p5_emit_byte
    mov al, 0xEC
    call p5_emit_byte
    mov al, 0x20
    call p5_emit_byte
    ret

p5_emit_epilogue:
    mov al, 0x89                ; mov esp, ebp
    call p5_emit_byte
    mov al, 0xEC
    call p5_emit_byte
    mov al, 0x5D                ; pop ebp
    call p5_emit_byte
    mov al, 0xC3                ; ret
    call p5_emit_byte
    ret

; ----------------------------------------------------------------------------
; MANEJADORES DE OPCODES
; Note: iload_N lee los parámetros recibidos dinámicamente desde [ebp + 8 + (N*4)]
; ----------------------------------------------------------------------------
jit_op_nop:
    mov al, 0x90
    call p5_emit_byte
    ret

; Opcode 0x1A: iload_0 -> Carga Param 0 de [ebp + 8]
jit_op_iload_0:
    mov al, 0x8B                ; mov eax, [ebp + 8]
    call p5_emit_byte
    mov al, 0x45
    call p5_emit_byte
    mov al, 0x08
    call p5_emit_byte
    mov al, 0x50                ; push eax
    call p5_emit_byte
    ret

; Opcode 0x1B: iload_1 -> Carga Param 1 de [ebp + 12]
jit_op_iload_1:
    mov al, 0x8B                ; mov eax, [ebp + 12]
    call p5_emit_byte
    mov al, 0x45
    call p5_emit_byte
    mov al, 0x0C
    call p5_emit_byte
    mov al, 0x50                ; push eax
    call p5_emit_byte
    ret

; Opcode 0x1C: iload_2 -> Carga Param 2 de [ebp + 16]
jit_op_iload_2:
    mov al, 0x8B                ; mov eax, [ebp + 16]
    call p5_emit_byte
    mov al, 0x45
    call p5_emit_byte
    mov al, 0x10
    call p5_emit_byte
    mov al, 0x50                ; push eax
    call p5_emit_byte
    ret

; Opcode 0x60: iadd -> Suma valores
jit_op_iadd:
    mov al, 0x5B                ; pop ebx
    call p5_emit_byte
    mov al, 0x58                ; pop eax
    call p5_emit_byte
    mov al, 0x01                ; add eax, ebx
    call p5_emit_byte
    mov al, 0xD8
    call p5_emit_byte
    mov al, 0x50                ; push eax
    call p5_emit_byte
    ret

jit_op_ireturn:
    mov al, 0x58                ; pop eax
    call p5_emit_byte
    call p5_emit_epilogue
    ret

jit_op_unsupported:
    cli
    hlt

; ----------------------------------------------------------------------------
; PRUEBA DE LA FASE 5 (Invocación con Argumentos Dinámicos)
; ----------------------------------------------------------------------------
section .data
    test_bytecode_p5: db 0x1A, 0x1B, 0x60, 0xAC  ; iload_0, iload_1, iadd, ireturn
    p5_cursor:        dd 0

section .text
jit_test_phase5:
    push ebp
    mov ebp, esp
    push ebx
    push esi
    push edi

    ; 1. Compilar el método
    mov esi, test_bytecode_p5
    mov ecx, 4
    call jit_compile_phase5     ; Retorna puntero ejecutable en EAX

    ; 2. Invocar la función enviando 2 parámetros dinámicos a la pila x86: (40, 60)
    push dword 60               ; Param 1 (b)
    push dword 40               ; Param 0 (a)
    call eax                    ; Llama al método JIT compilado
    add esp, 8                  ; Limpiar los 2 argumentos de la pila nativa

    pop edi
    pop esi
    pop ebx
    mov esp, ebp
    pop ebp
    ret                         ; EAX debe ser 100 (40 + 60)

; ----------------------------------------------------------------------------
; TABLA DE DESPACHO
; ----------------------------------------------------------------------------
section .rodata
align 4
jit_p5_opcode_table:
    dd jit_op_nop                   ; 0x00
    times 25 dd jit_op_unsupported  ; 0x01..0x19
    dd jit_op_iload_0               ; 0x1A - iload_0
    dd jit_op_iload_1               ; 0x1B - iload_1
    dd jit_op_iload_2               ; 0x1C - iload_2
    times 67 dd jit_op_unsupported  ; 0x1D..0x5F
    dd jit_op_iadd                  ; 0x60 - iadd
    times 75 dd jit_op_unsupported  ; 0x61..0xAB
    dd jit_op_ireturn               ; 0xAC - ireturn
    times 83 dd jit_op_unsupported  ; 0xAD..0xFF

section .note.GNU-stack noalloc noexec nowrite progbits
