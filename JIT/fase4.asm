; ============================================================================
; JVMOS - JIT Engine (Fase 4: Operaciones Aritméticas iadd y isub)
; Formato: NASM x86 32-bit (Modo Protegido Bare-Metal)
; ============================================================================

[bits 32]

section .text
    global jit_compile_phase4
    global jit_test_phase4

; ----------------------------------------------------------------------------
; EMISORES AUXILIARES JIT
; ----------------------------------------------------------------------------
p4_emit_byte:
    mov edx, [p4_cursor]
    mov [edx], al
    inc dword [p4_cursor]
    ret

p4_emit_dword:
    mov edx, [p4_cursor]
    mov [edx], eax
    add dword [p4_cursor], 4
    ret

; ----------------------------------------------------------------------------
; COMPILADOR JIT FASE 4
; ----------------------------------------------------------------------------
jit_compile_phase4:
    push ebp
    mov ebp, esp
    push ebx
    push esi
    push edi

    ; Usamos la memoria RAM libre en 0x00200000 para garantizar permisos de ejecución
    mov dword [p4_cursor], 0x00200000

    call p4_emit_prologue

    mov edi, esi
    add edi, ecx                ; Límite final del bytecode

.compile_loop:
    cmp esi, edi
    jae .compile_done

    movzx eax, byte [esi]
    inc esi                     ; Avanzar al siguiente byte

    mov ebx, [jit_p4_opcode_table + eax * 4]
    call ebx

    jmp .compile_loop

.compile_done:
    mov eax, 0x00200000         ; Retornar dirección base del método JIT
    pop edi
    pop esi
    pop ebx
    mov esp, ebp
    pop ebp
    ret

; ----------------------------------------------------------------------------
; PRÓLOGO Y EPÍLOGO NATIVOS
; ----------------------------------------------------------------------------
p4_emit_prologue:
    mov al, 0x55                ; push ebp
    call p4_emit_byte
    mov al, 0x89                ; mov ebp, esp
    call p4_emit_byte
    mov al, 0xE5
    call p4_emit_byte
    mov al, 0x83                ; sub esp, 16
    call p4_emit_byte
    mov al, 0xEC
    call p4_emit_byte
    mov al, 0x10
    call p4_emit_byte
    ret

p4_emit_epilogue:
    mov al, 0x89                ; mov esp, ebp
    call p4_emit_byte
    mov al, 0xEC
    call p4_emit_byte
    mov al, 0x5D                ; pop ebp
    call p4_emit_byte
    mov al, 0xC3                ; ret
    call p4_emit_byte
    ret

; ----------------------------------------------------------------------------
; MANEJADORES DE OPCODES
; ----------------------------------------------------------------------------
jit_op_nop:
    mov al, 0x90
    call p4_emit_byte
    ret

jit_op_bipush:
    movzx ecx, byte [esi]
    inc esi
    mov al, 0x68                ; push imm32
    call p4_emit_byte
    mov eax, ecx
    call p4_emit_dword
    ret

jit_op_istore_0:
    mov al, 0x58                ; pop eax
    call p4_emit_byte
    mov al, 0x89                ; mov [ebp - 4], eax
    call p4_emit_byte
    mov al, 0x45
    call p4_emit_byte
    mov al, 0xFC
    call p4_emit_byte
    ret

jit_op_istore_1:
    mov al, 0x58                ; pop eax
    call p4_emit_byte
    mov al, 0x89                ; mov [ebp - 8], eax
    call p4_emit_byte
    mov al, 0x45
    call p4_emit_byte
    mov al, 0xF8
    call p4_emit_byte
    ret

jit_op_iload_0:
    mov al, 0x8B                ; mov eax, [ebp - 4]
    call p4_emit_byte
    mov al, 0x45
    call p4_emit_byte
    mov al, 0xFC
    call p4_emit_byte
    mov al, 0x50                ; push eax
    call p4_emit_byte
    ret

jit_op_iload_1:
    mov al, 0x8B                ; mov eax, [ebp - 8]
    call p4_emit_byte
    mov al, 0x45
    call p4_emit_byte
    mov al, 0xF8
    call p4_emit_byte
    mov al, 0x50                ; push eax
    call p4_emit_byte
    ret

; Opcode 0x60: iadd -> Suma los dos valores del tope de la pila
; Traduce a x86: pop ebx / pop eax / add eax, ebx / push eax
jit_op_iadd:
    mov al, 0x5B                ; pop ebx
    call p4_emit_byte
    mov al, 0x58                ; pop eax
    call p4_emit_byte
    mov al, 0x01                ; add eax, ebx (Bytes: 0x01 0xD8)
    call p4_emit_byte
    mov al, 0xD8
    call p4_emit_byte
    mov al, 0x50                ; push eax
    call p4_emit_byte
    ret

jit_op_ireturn:
    mov al, 0x58                ; pop eax (Saca el resultado final para retornar en EAX)
    call p4_emit_byte
    call p4_emit_epilogue
    ret

jit_op_unsupported:
    cli
    hlt

; ----------------------------------------------------------------------------
; PRUEBA DE LA FASE 4
; Bytecode: bipush 10, istore_0, bipush 20, istore_1, iload_0, iload_1, iadd, ireturn
; ----------------------------------------------------------------------------
section .data
    test_bytecode_p4: db 0x10, 0x0A, 0x3B, 0x10, 0x14, 0x3C, 0x1A, 0x1B, 0x60, 0xAC
    p4_cursor:        dd 0

section .text
jit_test_phase4:
    push ebp
    mov ebp, esp
    push ebx
    push esi
    push edi

    mov esi, test_bytecode_p4
    mov ecx, 10
    call jit_compile_phase4

    call eax                    ; Ejecuta el código traducido (debe retornar 30 en EAX)

    pop edi
    pop esi
    pop ebx
    mov esp, ebp
    pop ebp
    ret

; ----------------------------------------------------------------------------
; TABLA DE DESPACHO DE OPCODES (Fase 4)
; ----------------------------------------------------------------------------
section .rodata
align 4
jit_p4_opcode_table:
    dd jit_op_nop                   ; 0x00
    times 15 dd jit_op_unsupported  ; 0x01..0x0F
    dd jit_op_bipush                ; 0x10
    times 9 dd jit_op_unsupported   ; 0x11..0x19
    dd jit_op_iload_0               ; 0x1A
    dd jit_op_iload_1               ; 0x1B
    times 31 dd jit_op_unsupported  ; 0x1C..0x3A
    dd jit_op_istore_0              ; 0x3B
    dd jit_op_istore_1              ; 0x3C
    times 35 dd jit_op_unsupported  ; 0x3D..0x5F
    dd jit_op_iadd                  ; 0x60 - iadd
    times 75 dd jit_op_unsupported  ; 0x61..0xAB
    dd jit_op_ireturn               ; 0xAC
    times 83 dd jit_op_unsupported  ; 0xAD..0xFF

section .note.GNU-stack noalloc noexec nowrite progbits
