; JVMOS - JIT Engine (Fase 1: Buffer de Código Ejecutable y Emisores)

section .bss
    jit_buffer_base: resd 1    ; Dirección física de inicio del buffer JIT
    jit_buffer_ptr:  resd 1    ; Puntero de escritura actual (Cursor)
    jit_buffer_end:  resd 1    ; Límite superior de memoria del buffer JIT

section .text
    global jit_init
    global jit_reset
    global jit_emit_byte
    global jit_emit_word
    global jit_emit_dword
    global jit_get_cursor
    global jit_test_phase1

; ----------------------------------------------------------------------------
; jit_init
; Inicializa las variables del buffer JIT con la dirección de memoria provista.
; Entrada: EAX = Dirección física inicial asignada al buffer JIT
;          EBX = Tamaño en bytes del buffer asignado (ej. 65536 para 64 KB)
; Salida:  Ninguna
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

; ----------------------------------------------------------------------------
; jit_reset
; Reinicia el cursor de escritura al inicio del buffer JIT.
; ----------------------------------------------------------------------------
jit_reset:
    push eax
    mov eax, [jit_buffer_base]
    mov [jit_buffer_ptr], eax
    pop eax
    ret

; ----------------------------------------------------------------------------
; jit_emit_byte
; ----------------------------------------------------------------------------
jit_emit_byte:
    push edi
    mov edi, [jit_buffer_ptr]

    ; Control de desbordamiento de memoria (Sin signo: jae)
    cmp edi, [jit_buffer_end]
    jae .buffer_overflow

    mov [edi], al
    inc edi
    mov [jit_buffer_ptr], edi

    pop edi
    ret

.buffer_overflow:
    cli
    hlt

; ----------------------------------------------------------------------------
; jit_emit_word
; ----------------------------------------------------------------------------
jit_emit_word:
    push edi
    mov edi, [jit_buffer_ptr]

    lea ecx, [edi + 2]
    cmp ecx, [jit_buffer_end]
    jae jit_emit_byte.buffer_overflow

    mov [edi], ax
    mov [jit_buffer_ptr], ecx

    pop edi
    ret

; ----------------------------------------------------------------------------
; jit_emit_dword
; ----------------------------------------------------------------------------
jit_emit_dword:
    push edi
    push ecx
    mov edi, [jit_buffer_ptr]

    lea ecx, [edi + 4]
    cmp ecx, [jit_buffer_end]
    jae jit_emit_byte.buffer_overflow

    mov [edi], eax
    mov [jit_buffer_ptr], ecx

    pop ecx
    pop edi
    ret

; ----------------------------------------------------------------------------
; jit_get_cursor
; Retorna la posición actual del cursor de escritura en RAM.
; Salida: EAX = Dirección de memoria del cursor JIT actual
; ----------------------------------------------------------------------------
jit_get_cursor:
    mov eax, [jit_buffer_ptr]
    ret

; ----------------------------------------------------------------------------
; jit_test_phase1
; Genera y ejecuta dinámicamente: NOP, MOV EAX, 0x12345678, RET.
; Salida: EAX = 0x12345678 (Si la ejecución del código generado fue exitosa)
; ----------------------------------------------------------------------------
jit_test_phase1:
    push ebx

    ; 1. Configurar un buffer de prueba a partir de la dirección 0x00200000 (64 KB)
    mov eax, 0x00200000
    mov ebx, 65536
    call jit_init

    ; 2. Emitir 'NOP' (Opcode x86: 0x90)
    mov al, 0x90
    call jit_emit_byte

    ; 3. Emitir 'MOV EAX, 0x12345678' (Opcode x86: 0xB8 seguido del dword)
    mov al, 0xB8
    call jit_emit_byte

    mov eax, 0x12345678
    call jit_emit_dword

    ; 4. Emitir 'RET' (Opcode x86: 0xC3)
    mov al, 0xC3
    call jit_emit_byte

    ; 5. Invocar el código compilado dinámicamente en RAM
    call [jit_buffer_base]

    pop ebx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
