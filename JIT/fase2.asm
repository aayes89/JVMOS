; ============================================================================
; JVMOS - JIT Engine (Fase 2: Lector de Bytecode, Despachador y Opcodes Iniciales)
; Formato: NASM x86 32-bit (Modo Protegido Bare-Metal)
; ============================================================================

section .text
    global jit_compile_method2
    global jit_test_phase2

    ; External de la Fase 1
    extern jit_init
    extern jit_emit_byte
    extern jit_emit_dword
    extern jit_get_cursor

; ----------------------------------------------------------------------------
; jit_compile_method2
; Toma un bloque de bytecode Java y lo traduce completamente a x86 en el buffer JIT.
; Entrada: ESI = Puntero al inicio del bytecode Java (sección Code)
;          ECX = Longitud total del bytecode en bytes
; Salida:  EAX = Dirección de memoria del método nativo compilado
; ----------------------------------------------------------------------------
jit_compile_method2:
    push ebx
    push esi
    push edi
    push edx

    ; 1. Obtener y guardar la dirección donde inicia este método compilado
    call jit_get_cursor
    push eax                    ; Guardar dirección inicial en la pila

    ; 2. Emitir Prólogo Nativo x86 (push ebp / mov ebp, esp)
    call jit_emit_prologue

    ; 3. Límite superior del bytecode (EDX = ESI + ECX)
    lea edx, [esi + ecx]

.compile_loop:
    cmp esi, edx
    jae .compile_done           ; Si procesamos todo el bytecode, finalizar

    ; 4. Leer Opcode actual
    movzx eax, byte [esi]
    inc esi                     ; Avanzar puntero de bytecode

    ; 5. Despachar a la rutina del JIT usando la tabla de saltos
    mov ebx, [jit_opcode_table + eax * 4]
    call ebx

    jmp .compile_loop

.compile_done:
    ; 6. Emitir Epílogo Nativo x86
    call jit_emit_epilogue

    ; 7. Retornar la dirección inicial del método compilado
    pop eax

    pop edx
    pop edi
    pop esi
    pop ebx
    ret

; ----------------------------------------------------------------------------
; Emisión de Prólogo / Epílogo x86
; ----------------------------------------------------------------------------
jit_emit_prologue:
    ; Emitir: push ebp (0x55)
    mov al, 0x55
    call jit_emit_byte
    ; Emitir: mov ebp, esp (0x89 0xE5)
    mov al, 0x89
    call jit_emit_byte
    mov al, 0xE5
    call jit_emit_byte
    ret

jit_emit_epilogue:
    ; Emitir: mov esp, ebp (0x89 0xEC)
    mov al, 0x89
    call jit_emit_byte
    mov al, 0xEC
    call jit_emit_byte
    ; Emitir: pop ebp (0x5D)
    mov al, 0x5D
    call jit_emit_byte
    ; Emitir: ret (0xC3)
    mov al, 0xC3
    call jit_emit_byte
    ret

; ----------------------------------------------------------------------------
; Manejadores de Opcodes en el JIT
; ----------------------------------------------------------------------------

; Opcode 0x00: nop
jit_op_nop:
    mov al, 0x90               ; Emitir NOP nativo en x86
    call jit_emit_byte
    ret

; Opcode 0x03: iconst_0 -> Empujar 0 a la pila x86
; Traduce a x86: push 0  (Bytes: 0x6A 0x00)
jit_op_iconst_0:
    mov al, 0x6A
    call jit_emit_byte
    mov al, 0x00
    call jit_emit_byte
    ret

; Opcode 0x04: iconst_1 -> Empujar 1 a la pila x86
; Traduce a x86: push 1  (Bytes: 0x6A 0x01)
jit_op_iconst_1:
    mov al, 0x6A
    call jit_emit_byte
    mov al, 0x01
    call jit_emit_byte
    ret

; Opcode 0x10: bipush <byte> -> Empujar byte inmediato
; Traduce a x86: push <val> (Bytes: 0x6A <val>)
jit_op_bipush:
    movzx eax, byte [esi]      ; Leer el byte operando
    inc esi                    ; Avanzar el cursor de bytecode
    
    push eax
    mov al, 0x6A               ; push imm8 en x86
    call jit_emit_byte
    pop eax
    
    call jit_emit_byte         ; Emitir el valor constante
    ret

; Opcode 0xAC: ireturn -> Retornar entero
; Traduce a x86: pop eax (Saca el valor de la pila virtual y lo pone en EAX)
jit_op_ireturn:
    mov al, 0x58               ; pop eax en x86
    call jit_emit_byte
    ret

; Handler para opcodes no soportados aún en Fase 2
jit_op_unsupported:
    cli
    hlt

; ----------------------------------------------------------------------------
; PRUEBA DE LA FASE 2
; Bytecode a probar: 0x10 0x42 0xAC (bipush 66; ireturn)
; ----------------------------------------------------------------------------
section .data
    test_bytecode_p2: db 0x10, 0x42, 0xAC   ; Equivalent Java: return 66;

section .text
jit_test_phase2:
    push ebx

    ; 1. Asignar buffer JIT en RAM (0x00200000)
    mov eax, 0x00200000
    mov ebx, 65536
    call jit_init

    ; 2. Compilar el bytecode a código máquina nativo
    mov esi, test_bytecode_p2
    mov ecx, 3                 ; Longitud: 3 bytes
    call jit_compile_method2    ; EAX = Dirección del método nativo resultante

    ; 3. Ejecutar el código traducido por el JIT
    call eax                   ; Llama al método compilado en 0x00200000

    pop ebx
    ret                        ; EAX debe ser 0x42 (66 decimal)

; ----------------------------------------------------------------------------
; Tabla de Despacho (256 Entradas)
; ----------------------------------------------------------------------------
section .rodata
align 4
jit_opcode_table:
    dd jit_op_nop          ; 0x00 - nop
    times 2 dd jit_op_unsupported ; 0x01..0x02
    dd jit_op_iconst_0     ; 0x03 - iconst_0
    dd jit_op_iconst_1     ; 0x04 - iconst_1
    times 11 dd jit_op_unsupported ; 0x05..0x0F
    dd jit_op_bipush       ; 0x10 - bipush
    times 155 dd jit_op_unsupported ; 0x11..0xAB
    dd jit_op_ireturn      ; 0xAC - ireturn
    times 83 dd jit_op_unsupported  ; 0xAD..0xFF

section .note.GNU-stack noalloc noexec nowrite progbits
