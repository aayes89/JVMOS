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
    test_bytecode_p2: db 0x10, 0x42, 0xAC                           ; bipush 66, ireturn
    test_bytecode_p3: db 0x10, 0x0A, 0x3B, 0x10, 0x14, 0x3C, 0x1B, 0xAC ; ret 20 (local_var 1)
    test_bytecode_p4: db 0x10, 0x0A, 0x3B, 0x10, 0x14, 0x3C, 0x1A, 0x1B, 0x60, 0xAC ; 10 + 20 = 30
    test_bytecode_p5: db 0x1A, 0x1B, 0x60, 0xAC                      ; param0 + param1 (40 + 60 = 100)
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
	extern cp_base_ptr
	; Símbolos de Syscalls del Kernel (de jvm_native.asm / sys_api.asm)	
	extern sys_arg_id, sys_arg_a, sys_arg_b, sys_arg_c, sys_arg_d
	extern jvm_invoke_native
	extern sys_kalloc

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
    mov al, 0x83                ; sub esp, 64 (Espacio seguro para 16 locales)
    call jit_emit_byte
    mov al, 0xEC
    call jit_emit_byte
    mov al, 0x40
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
; OPCODES UNIFICADOS Y MIGRACIONES ARITMÉTICAS
; ----------------------------------------------------------------------------
; Opcode 0x00: null
jit_op_aconst_null:
    mov al, 0x6A
    call jit_emit_byte
    mov al, 0x00
    call jit_emit_byte
    ret

; Opcode 0x02: iconst_m1 -> Empujar -1 (0xFFFFFFFF) a la pila nativa x86 (push -1)
jit_op_iconst_m1:
    mov al, 0x6A                ; push imm8 (con signo)
    call jit_emit_byte
    mov al, 0xFF                ; -1 en complemento a dos
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

jit_op_iconst_2:
    mov al, 0x6A
    call jit_emit_byte
    mov al, 0x02
    call jit_emit_byte
    ret

jit_op_iconst_3:
    mov al, 0x6A
    call jit_emit_byte
    mov al, 0x03
    call jit_emit_byte
    ret

jit_op_iconst_4:
    mov al, 0x6A
    call jit_emit_byte
    mov al, 0x04
    call jit_emit_byte
    ret

jit_op_iconst_5:
    mov al, 0x6A
    call jit_emit_byte
    mov al, 0x05
    call jit_emit_byte
    ret

jit_op_lconst_0:
    mov al, 0x6A                ; push 0
    call jit_emit_byte
    mov al, 0x00
    call jit_emit_byte
    mov al, 0x6A                ; push 0
    call jit_emit_byte
    mov al, 0x00
    call jit_emit_byte
    ret

jit_op_lconst_1:
    mov al, 0x6A                ; push 0
    call jit_emit_byte
    mov al, 0x00
    call jit_emit_byte
    mov al, 0x6A                ; push 1
    call jit_emit_byte
    mov al, 0x01
    call jit_emit_byte
    ret

; Opcode 0x10 bipush    
jit_op_bipush:
    movsx eax, byte [esi]       ; Lectura con extensión de signo (8 a 32 bits)
    inc esi
    push eax
    mov al, 0x68                ; push imm32
    call jit_emit_byte
    pop eax
    call jit_emit_dword
    ret

; Opcode 0x11: sipush <short> (Lee 16-bit Big-Endian de la JVM y extiende a 32-bit)
jit_op_sipush:
    movzx eax, byte [esi]       ; Byte alto
    inc esi
    movzx ebx, byte [esi]       ; Byte bajo
    inc esi
    shl eax, 8
    or eax, ebx
    movsx eax, ax               ; Extensión de signo de 16 a 32 bits

    push eax
    mov al, 0x68                ; push imm32
    call jit_emit_byte
    pop eax
    call jit_emit_dword
    ret

; Opcode 0x12: ldc (Lee 1 byte de índice de la Constant Pool)
jit_op_ldc:
    movzx eax, byte [esi]       ; Leer índice de 8 bits de la Constant Pool
    inc esi                     ; Consumir el byte del índice

    mov ebx, [cp_base_ptr]
    test ebx, ebx
    jz .fallback_zero
    mov eax, [ebx + eax * 4]    ; Extraer constante de 32 bits real
    jmp .emit_val

.fallback_zero:
    xor eax, eax

.emit_val:
    push eax
    mov al, 0x68                ; push imm32 (0x68 <DWORD>)
    call jit_emit_byte
    pop eax
    call jit_emit_dword
    ret
	
; Opcode 0x13: ldc_w (Lee 2 bytes de índice en la Constant Pool)
jit_op_ldc_w:
    movzx eax, byte [esi]       ; Byte alto del índice
    inc esi
    movzx ebx, byte [esi]       ; Byte bajo del índice
    inc esi
    shl eax, 8
    or eax, ebx                 ; EAX = Index de la Constant Pool

    mov ebx, [cp_base_ptr]
    test ebx, ebx
    jz .fallback_zero
    mov eax, [ebx + eax * 4]    ; Extraer constante de 32 bits
    jmp .emit_val

.fallback_zero:
    xor eax, eax

.emit_val:
    push eax
    mov al, 0x68                ; push imm32
    call jit_emit_byte
    pop eax
    call jit_emit_dword
    ret

; Opcode 0xB7: invokespecial <method_index_16bit>
jit_op_invokespecial:
    add esi, 2                  ; Ignorar índice del CP (Constructor vacío Object.<init>)
    ; Para constructores base simples, no se requiere emitir nada a nivel x86 (NOP)
    ret
	
; Opcode 0xB8: invokestatic <method_index_16bit>
jit_op_invokestatic:
    add esi, 2                  ; Saltar el índice de 16-bit del CP

    ; Desapilar argumentos hacia variables globales del Kernel
    mov al, 0x58                ; pop eax
    call jit_emit_byte
    mov al, 0xA3                ; mov [sys_arg_d], eax
    call jit_emit_byte
    mov eax, sys_arg_d
    call jit_emit_dword

    mov al, 0x58                ; pop eax
    call jit_emit_byte
    mov al, 0xA3                ; mov [sys_arg_c], eax
    call jit_emit_byte
    mov eax, sys_arg_c
    call jit_emit_dword

    mov al, 0x58                ; pop eax
    call jit_emit_byte
    mov al, 0xA3                ; mov [sys_arg_b], eax
    call jit_emit_byte
    mov eax, sys_arg_b
    call jit_emit_dword

    mov al, 0x58                ; pop eax
    call jit_emit_byte
    mov al, 0xA3                ; mov [sys_arg_a], eax
    call jit_emit_byte
    mov eax, sys_arg_a
    call jit_emit_dword

    mov al, 0x58                ; pop eax
    call jit_emit_byte
    mov al, 0xA3                ; mov [sys_arg_id], eax
    call jit_emit_byte
    mov eax, sys_arg_id
    call jit_emit_dword

    ; Emitir llamada directa a jvm_invoke_native del Kernel
    mov al, 0xE8                ; call rel32
    call jit_emit_byte
    mov eax, jvm_invoke_native
    mov ebx, [jit_buffer_ptr]
    add ebx, 4
    sub eax, ebx
    call jit_emit_dword

    ; Volver a empujar el resultado dejado en EAX a la pila nativa
    mov al, 0x50                ; push eax
    call jit_emit_byte
    ret
	
; --- CONSTANTES FLOTANTES (fconst_0, fconst_1, fconst_2) ---
; Opcode 0x0B: fconst_0 (0.0f) -> push dword 0x00000000
jit_op_fconst_0:
    mov al, 0x68                ; push imm32
    call jit_emit_byte
    mov eax, 0x00000000
    call jit_emit_dword
    ret

; Opcode 0x0C: fconst_1 (1.0f) -> push dword 0x3F800000
jit_op_fconst_1:
    mov al, 0x68                ; push imm32
    call jit_emit_byte
    mov eax, 0x3F800000
    call jit_emit_dword
    ret

; Opcode 0x0D: fconst_2 (2.0f) -> push dword 0x40000000
jit_op_fconst_2:
    mov al, 0x68                ; push imm32
    call jit_emit_byte
    mov eax, 0x40000000
    call jit_emit_dword
    ret

; Opcode 0x0E: dconst_0 (0.0) Double de 64bits
jit_op_dconst_0:
    mov al, 0x68                ; push imm32 (parte alta)
    call jit_emit_byte
    mov eax, 0x00000000
    call jit_emit_dword
    mov al, 0x68                ; push imm32 (parte baja)
    call jit_emit_byte
    mov eax, 0x00000000
    call jit_emit_dword
    ret

; Opcode 0x0F: dconst_1 (1.0) -> push 0x3FF00000 (alta), push 0x00000000 (baja)
jit_op_dconst_1:
    mov al, 0x68                ; push imm32 (parte alta)
    call jit_emit_byte
    mov eax, 0x3FF00000
    call jit_emit_dword
    mov al, 0x68                ; push imm32 (parte baja)
    call jit_emit_byte
    mov eax, 0x00000000
    call jit_emit_dword
    ret
	
; --- CARGAS DE VARIABLES (iload / aload) ---
; Opcode 0x15: iload <index_8bit>
; Opcode 0x17: fload <index_8bit>
; Opcode 0x19: aload <index_8bit>
jit_op_iload:
jit_op_fload:
jit_op_aload:
    movzx ebx, byte [esi]       ; Leer índice de variable local
    inc esi                     ; Consumir byte de índice

    inc ebx
    shl ebx, 2
    neg ebx                     ; EBX = -((index + 1) * 4)

    mov al, 0x8B                ; mov eax, [ebp + disp8]
    call jit_emit_byte
    mov al, 0x45
    call jit_emit_byte
    mov al, bl                  ; Offset EBP de la variable local
    call jit_emit_byte
    mov al, 0x50                ; push eax
    call jit_emit_byte
    ret

; Opcodes del 0x22 al 0x25
jit_op_iload_0:
jit_op_aload_0:
jit_op_fload_0:
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
jit_op_aload_1:
jit_op_fload_1:
    mov al, 0x8B                ; mov eax, [ebp - 8]
    call jit_emit_byte
    mov al, 0x45
    call jit_emit_byte
    mov al, 0xF8
    call jit_emit_byte
    mov al, 0x50                ; push eax
    call jit_emit_byte
    ret

jit_op_iload_2:
jit_op_aload_2:
jit_op_fload_2:
    mov al, 0x8B                ; mov eax, [ebp - 12]
    call jit_emit_byte
    mov al, 0x45
    call jit_emit_byte
    mov al, 0xF4
    call jit_emit_byte
    mov al, 0x50                ; push eax
    call jit_emit_byte
    ret

jit_op_iload_3:
jit_op_aload_3:
jit_op_fload_3:
    mov al, 0x8B                ; mov eax, [ebp - 16]
    call jit_emit_byte
    mov al, 0x45
    call jit_emit_byte
    mov al, 0xF0
    call jit_emit_byte
    mov al, 0x50                ; push eax
    call jit_emit_byte
    ret
	
; Opcode 0x36: istore <index_8bit>
; Opcode 0x3A: astore <index_8bit>
jit_op_istore:
jit_op_astore:
    movzx ebx, byte [esi]       ; Leer índice de variable local
    inc esi                     ; Consumir byte de índice

    inc ebx
    shl ebx, 2
    neg ebx                     ; EBX = -((index + 1) * 4)

    mov al, 0x58                ; pop eax
    call jit_emit_byte
    mov al, 0x89                ; mov [ebp + disp8], eax
    call jit_emit_byte
    mov al, 0x45
    call jit_emit_byte
    mov al, bl                  ; Offset EBP de la variable local
    call jit_emit_byte
    ret
	
jit_op_iload_4:
jit_op_aload_4:
jit_op_fload_4:
    mov al, 0x8B                ; mov eax, [ebp - 20]
    call jit_emit_byte
    mov al, 0x45
    call jit_emit_byte
    mov al, 0xEC                ; -20 en complemento a dos (0xEC)
    call jit_emit_byte
    mov al, 0x50                ; push eax
    call jit_emit_byte
    ret

jit_op_iload_5:
jit_op_aload_5:
jit_op_fload_5:
    mov al, 0x8B                ; mov eax, [ebp - 24]
    call jit_emit_byte
    mov al, 0x45
    call jit_emit_byte
    mov al, 0xE8                ; -24 en complemento a dos (0xE8)
    call jit_emit_byte
    mov al, 0x50                ; push eax
    call jit_emit_byte
    ret

; --- CARGAS DE VARIABLES LONG (64-BIT) ---
; Opcode 0x20: lload_0
; Opcode 0x26: dload_0
jit_op_lload_0:
jit_op_dload_0:
    mov al, 0x8B                ; mov eax, [ebp - 4] (parte alta)
    call jit_emit_byte
    mov al, 0x45
    call jit_emit_byte
    mov al, 0xFC
    call jit_emit_byte
    mov al, 0x50                ; push eax
    call jit_emit_byte
    mov al, 0x8B                ; mov eax, [ebp - 8] (parte baja)
    call jit_emit_byte
    mov al, 0x45
    call jit_emit_byte
    mov al, 0xF8
    call jit_emit_byte
    mov al, 0x50                ; push eax
    call jit_emit_byte
    ret

; Opcode 0x21: lload_1 -> Carga [ebp - 8] y [ebp - 12]
jit_op_lload_1:
    mov al, 0x8B                ; mov eax, [ebp - 8]
    call jit_emit_byte
    mov al, 0x45
    call jit_emit_byte
    mov al, 0xF8
    call jit_emit_byte
    mov al, 0x50                ; push eax
    call jit_emit_byte
    mov al, 0x8B                ; mov eax, [ebp - 12]
    call jit_emit_byte
    mov al, 0x45
    call jit_emit_byte
    mov al, 0xF4
    call jit_emit_byte
    mov al, 0x50                ; push eax
    call jit_emit_byte
    ret

; --- ALMACENAMIENTO DE VARIABLES LONG (64-BIT) ---
; Opcode 0x3F: lstore_0 -> Guarda en [ebp - 8] y [ebp - 4]
jit_op_lstore_0:
    mov al, 0x58                ; pop eax (parte baja)
    call jit_emit_byte
    mov al, 0x89                ; mov [ebp - 8], eax
    call jit_emit_byte
    mov al, 0x45
    call jit_emit_byte
    mov al, 0xF8
    call jit_emit_byte
    mov al, 0x58                ; pop eax (parte alta)
    call jit_emit_byte
    mov al, 0x89                ; mov [ebp - 4], eax
    call jit_emit_byte
    mov al, 0x45
    call jit_emit_byte
    mov al, 0xFC
    call jit_emit_byte
    ret

; Opcode 0x40: lstore_1 -> Guarda en [ebp - 12] y [ebp - 8]
jit_op_lstore_1:
    mov al, 0x58                ; pop eax (parte baja)
    call jit_emit_byte
    mov al, 0x89                ; mov [ebp - 12], eax
    call jit_emit_byte
    mov al, 0x45
    call jit_emit_byte
    mov al, 0xF4
    call jit_emit_byte
    mov al, 0x58                ; pop eax (parte alta)
    call jit_emit_byte
    mov al, 0x89                ; mov [ebp - 8], eax
    call jit_emit_byte
    mov al, 0x45
    call jit_emit_byte
    mov al, 0xF8
    call jit_emit_byte
    ret
	
; --- ALMACENAMIENTO DE VARIABLES (istore / astore) ---
jit_op_istore_0:
jit_op_astore_0:
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
jit_op_astore_1:
    mov al, 0x58                ; pop eax
    call jit_emit_byte
    mov al, 0x89                ; mov [ebp - 8], eax
    call jit_emit_byte
    mov al, 0x45
    call jit_emit_byte
    mov al, 0xF8
    call jit_emit_byte
    ret

jit_op_istore_2:
jit_op_astore_2:
    mov al, 0x58                ; pop eax
    call jit_emit_byte
    mov al, 0x89                ; mov [ebp - 12], eax
    call jit_emit_byte
    mov al, 0x45
    call jit_emit_byte
    mov al, 0xF4
    call jit_emit_byte
    ret

jit_op_istore_3:
jit_op_astore_3:
    mov al, 0x58                ; pop eax
    call jit_emit_byte
    mov al, 0x89                ; mov [ebp - 16], eax
    call jit_emit_byte
    mov al, 0x45
    call jit_emit_byte
    mov al, 0xF0
    call jit_emit_byte
    ret

jit_op_istore_4:
jit_op_astore_4:
    mov al, 0x58                ; pop eax
    call jit_emit_byte
    mov al, 0x89                ; mov [ebp - 20], eax
    call jit_emit_byte
    mov al, 0x45
    call jit_emit_byte
    mov al, 0xEC
    call jit_emit_byte
    ret

jit_op_istore_5:
jit_op_astore_5:
    mov al, 0x58                ; pop eax
    call jit_emit_byte
    mov al, 0x89                ; mov [ebp - 24], eax
    call jit_emit_byte
    mov al, 0x45
    call jit_emit_byte
    mov al, 0xE8
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

; --- OPERACIONES ARITMÉTICAS Y LÓGICAS ---
; a+b
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

; a-b
jit_op_isub:
    mov al, 0x5B                ; pop ebx (b)
    call jit_emit_byte
    mov al, 0x58                ; pop eax (a)
    call jit_emit_byte
    mov al, 0x29                ; sub eax, ebx (EAX = a - b)
    call jit_emit_byte
    mov al, 0xD8
    call jit_emit_byte
    mov al, 0x50                ; push eax
    call jit_emit_byte
    ret

; a*b
jit_op_imul:
    mov al, 0x5B                ; pop ebx
    call jit_emit_byte
    mov al, 0x58                ; pop eax
    call jit_emit_byte
    mov al, 0x0F
    call jit_emit_byte
    mov al, 0xAF
    call jit_emit_byte
    mov al, 0xC3                ; ModRM byte para EAX, EBX
    call jit_emit_byte
    mov al, 0x50                ; push eax
    call jit_emit_byte
    ret

; a/b
jit_op_idiv:
    mov al, 0x5B                ; pop ebx (b = divisor)
    call jit_emit_byte
    mov al, 0x58                ; pop eax (a = dividendo)
    call jit_emit_byte
    mov al, 0x99                ; cdq
    call jit_emit_byte
    mov al, 0xF7                ; idiv ebx (Bytes: 0xF7 0xFB)
    call jit_emit_byte
    mov al, 0xFB
    call jit_emit_byte
    mov al, 0x50                ; push eax (cociente)
    call jit_emit_byte
    ret

; modulo a%b
jit_op_irem:
    mov al, 0x5B                ; pop ebx (b = divisor)
    call jit_emit_byte
    mov al, 0x58                ; pop eax (a = dividendo)
    call jit_emit_byte
    mov al, 0x99                ; cdq
    call jit_emit_byte
    mov al, 0xF7                ; idiv ebx (Bytes: 0xF7 0xFB)
    call jit_emit_byte
    mov al, 0xFB
    call jit_emit_byte
    mov al, 0x52                ; push edx (residuo en EDX)
    call jit_emit_byte
    ret

; negación (-1)*a
jit_op_ineg:
    mov al, 0x58                ; pop eax
    call jit_emit_byte
    mov al, 0xF7                ; neg eax
    call jit_emit_byte
    mov al, 0xD8
    call jit_emit_byte
    mov al, 0x50                ; push eax
    call jit_emit_byte
    ret

jit_op_ishl:
    mov al, 0x59                ; pop ecx
    call jit_emit_byte
    mov al, 0x58                ; pop eax
    call jit_emit_byte
    mov al, 0xD3                ; shl eax, cl
    call jit_emit_byte
    mov al, 0xE0
    call jit_emit_byte
    mov al, 0x50                ; push eax
    call jit_emit_byte
    ret

jit_op_ishr:
    mov al, 0x59                ; pop ecx
    call jit_emit_byte
    mov al, 0x58                ; pop eax
    call jit_emit_byte
    mov al, 0xD3                ; sar eax, cl
    call jit_emit_byte
    mov al, 0xF8
    call jit_emit_byte
    mov al, 0x50                ; push eax
    call jit_emit_byte
    ret

jit_op_iushr:
    mov al, 0x59                ; pop ecx
    call jit_emit_byte
    mov al, 0x58                ; pop eax
    call jit_emit_byte
    mov al, 0xD3                ; shr eax, cl
    call jit_emit_byte
    mov al, 0xE8
    call jit_emit_byte
    mov al, 0x50                ; push eax
    call jit_emit_byte
    ret

jit_op_iand:
    mov al, 0x5B                ; pop ebx
    call jit_emit_byte
    mov al, 0x58                ; pop eax
    call jit_emit_byte
    mov al, 0x21                ; and eax, ebx
    call jit_emit_byte
    mov al, 0xD8
    call jit_emit_byte
    mov al, 0x50                ; push eax
    call jit_emit_byte
    ret

jit_op_ior:
    mov al, 0x5B                ; pop ebx
    call jit_emit_byte
    mov al, 0x58                ; pop eax
    call jit_emit_byte
    mov al, 0x09                ; or eax, ebx
    call jit_emit_byte
    mov al, 0xD8
    call jit_emit_byte
    mov al, 0x50                ; push eax
    call jit_emit_byte
    ret

jit_op_ixor:
    mov al, 0x5B                ; pop ebx
    call jit_emit_byte
    mov al, 0x58                ; pop eax
    call jit_emit_byte
    mov al, 0x31                ; xor eax, ebx
    call jit_emit_byte
    mov al, 0xD8
    call jit_emit_byte
    mov al, 0x50                ; push eax
    call jit_emit_byte
    ret

jit_op_iinc:
    movzx ebx, byte [esi]       ; Leer index
    inc esi
    movsx ecx, byte [esi]       ; Leer const
    inc esi

    inc ebx
    shl ebx, 2
    neg ebx                     ; EBX = Offset negativo en EBP

    mov al, 0x83                ; add dword [ebp + disp8], imm8
    call jit_emit_byte
    mov al, 0x45
    call jit_emit_byte
    mov al, bl                  ; Offset variable local
    call jit_emit_byte
    mov al, cl                  ; Constante
    call jit_emit_byte
    ret
    
; Opcode 0x85: i2l (Int 32-bit -> Long 64-bit)
jit_op_i2l:
    mov al, 0x58                ; pop eax
    call jit_emit_byte
    mov al, 0x99                ; cdq (EDX = Signo, EAX = Valor)
    call jit_emit_byte
    mov al, 0x52                ; push edx (Parte alta)
    call jit_emit_byte
    mov al, 0x50                ; push eax (Parte baja)
    call jit_emit_byte
    ret

; Opcode 0x88: l2i (Long 64-bit -> Int 32-bit)
jit_op_l2i:
    mov al, 0x58                ; pop eax (Low - se conserva)
    call jit_emit_byte
    mov al, 0x5B                ; pop ebx (High - se descarta)
    call jit_emit_byte
    mov al, 0x50                ; push eax
    call jit_emit_byte
    ret

; Opcode 0x91: i2b (Int -> Byte con signo)
jit_op_i2b:
    mov al, 0x58                ; pop eax
    call jit_emit_byte
    mov al, 0x0F                ; movsx eax, al (Bytes: 0x0F 0xBE 0xC0)
    call jit_emit_byte
    mov al, 0xBE
    call jit_emit_byte
    mov al, 0xC0
    call jit_emit_byte
    mov al, 0x50                ; push eax
    call jit_emit_byte
    ret

; Opcode 0x92: i2c (Int -> Char UTF-16)
jit_op_i2c:
    mov al, 0x58                ; pop eax
    call jit_emit_byte
    mov al, 0x0F                ; movzx eax, ax (Bytes: 0x0F 0xB7 0xC0)
    call jit_emit_byte
    mov al, 0xB7
    call jit_emit_byte
    mov al, 0xC0
    call jit_emit_byte
    mov al, 0x50                ; push eax
    call jit_emit_byte
    ret

; Opcode 0x99: ifeq <branchbyte1, branchbyte2>
jit_op_ifeq:
    movzx eax, byte [esi]       ; Byte alto del offset (Big-Endian)
    inc esi
    movzx ebx, byte [esi]       ; Byte bajo del offset
    inc esi
    shl eax, 8
    or eax, ebx
    movsx eax, ax               ; Extension de signo de 16 a 32 bits (Offset Java)

    ; 1. Desapilar el valor a comparar
    mov al, 0x58                ; pop eax
    call jit_emit_byte

    ; 2. Comparar con 0 (cmp eax, 0)
    mov al, 0x83                ; cmp eax, 0
    call jit_emit_byte
    mov al, 0xF8
    call jit_emit_byte
    mov al, 0x00
    call jit_emit_byte

    ; 3. Emitir Je rel32 (0x0F 0x84 <offset32>)
    mov al, 0x0F
    call jit_emit_byte
    mov al, 0x84
    call jit_emit_byte

    ; Calcular salto nativo hacia atrás/adelante usando loop_start_addr
    mov eax, [loop_start_addr]
    mov ebx, [jit_buffer_ptr]
    add ebx, 4
    sub eax, ebx
    call jit_emit_dword
    ret

; Saltos condicionales
jit_op_ifne:
    movzx eax, byte [esi]
    inc esi
    movzx ebx, byte [esi]
    inc esi
    shl eax, 8
    or eax, ebx
    movsx eax, ax

    mov al, 0x58                ; pop eax
    call jit_emit_byte
    mov al, 0x83                ; cmp eax, 0
    call jit_emit_byte
    mov al, 0xF8
    call jit_emit_byte
    mov al, 0x00
    call jit_emit_byte

    mov al, 0x0F                ; JNE rel32
    call jit_emit_byte
    mov al, 0x85
    call jit_emit_byte

    mov eax, [loop_start_addr]
    mov ebx, [jit_buffer_ptr]
    add ebx, 4
    sub eax, ebx
    call jit_emit_dword
    ret

; Opcode 0x9E: ifle <branchbyte1, branchbyte2>
jit_op_ifle:
    movzx eax, byte [esi]       ; Byte alto del offset
    inc esi
    movzx ebx, byte [esi]       ; Byte bajo del offset
    inc esi
    shl eax, 8
    or eax, ebx
    movsx eax, ax               ; Extensión de signo 16 a 32 bits

    ; 1. Desapilar valor
    mov al, 0x58                ; pop eax
    call jit_emit_byte

    ; 2. Comparar con 0 (cmp eax, 0)
    mov al, 0x83
    call jit_emit_byte
    mov al, 0xF8
    call jit_emit_byte
    mov al, 0x00
    call jit_emit_byte

    ; 3. Emitir JLE rel32 (0x0F 0x8E <offset32>)
    mov al, 0x0F
    call jit_emit_byte
    mov al, 0x8E
    call jit_emit_byte

    ; Calcular salto relativo
    mov eax, [loop_start_addr]
    mov ebx, [jit_buffer_ptr]
    add ebx, 4
    sub eax, ebx
    call jit_emit_dword
    ret

; Opcode 0x9C: ifge <branchbyte1, branchbyte2>
jit_op_ifge:
    movzx eax, byte [esi]       ; Byte alto del offset
    inc esi
    movzx ebx, byte [esi]       ; Byte bajo del offset
    inc esi
    shl eax, 8
    or eax, ebx
    movsx eax, ax               ; Extensión de signo 16 a 32 bits

    mov al, 0x58                ; pop eax
    call jit_emit_byte
    mov al, 0x83                ; cmp eax, 0
    call jit_emit_byte
    mov al, 0xF8
    call jit_emit_byte
    mov al, 0x00
    call jit_emit_byte

    mov al, 0x0F                ; JGE rel32 (0x0F 0x8D)
    call jit_emit_byte
    mov al, 0x8D
    call jit_emit_byte

    mov eax, [loop_start_addr]
    mov ebx, [jit_buffer_ptr]
    add ebx, 4
    sub eax, ebx
    call jit_emit_dword
    ret


	
; Helper genérico para emitir: pop ebx, pop eax, cmp eax, ebx, jcc rel32
jit_emit_icmp_branch:
    push ecx                    ; ECX tiene la condición Jcc x86 (0x85=JNE, 0x8C=JL, 0x8D=JGE, 0x8F=JG, 0x8E=JLE)
    movzx eax, byte [esi]
    inc esi
    movzx ebx, byte [esi]
    inc esi
    shl eax, 8
    or eax, ebx
    movsx eax, ax

    mov al, 0x5B                ; pop ebx (op2)
    call jit_emit_byte
    mov al, 0x58                ; pop eax (op1)
    call jit_emit_byte
    mov al, 0x39                ; cmp eax, ebx
    call jit_emit_byte
    mov al, 0xD8
    call jit_emit_byte

    mov al, 0x0F                ; Prefijo de salto rel32
    call jit_emit_byte
    pop ecx
    mov al, cl                  ; Byte de condición Jcc
    call jit_emit_byte

    mov eax, [loop_start_addr]
    mov ebx, [jit_buffer_ptr]
    add ebx, 4
    sub eax, ebx
    call jit_emit_dword
    ret

; Opcode 0xA0: if_icmpne
jit_op_if_icmpne:
    mov ecx, 0x85               ; JNE
    jmp jit_emit_icmp_branch

; Opcode 0xA1: if_icmplt
jit_op_if_icmplt:
    mov ecx, 0x8C               ; JL
    jmp jit_emit_icmp_branch

; Opcode 0xA2: if_icmpge
jit_op_if_icmpge:
    mov ecx, 0x8D               ; JGE
    jmp jit_emit_icmp_branch

; Opcode 0xA3: if_icmpgt
jit_op_if_icmpgt:
    mov ecx, 0x8F               ; JG
    jmp jit_emit_icmp_branch

; Opcode 0xA4: if_icmple
jit_op_if_icmple:
    mov ecx, 0x8E               ; JLE
    jmp jit_emit_icmp_branch

; Manejo de arreglos (iaload, iastore, arraylength) ---
; Opcode 0x2E: iaload
; Opcode 0x32: aaload
jit_op_iaload:
jit_op_aaload:
    mov al, 0x59                ; pop ecx (index)
    call jit_emit_byte
    mov al, 0x58                ; pop eax (arrayref)
    call jit_emit_byte
    mov al, 0x8B                ; mov eax, [eax + ecx * 4]
    call jit_emit_byte
    mov al, 0x04
    call jit_emit_byte
    mov al, 0x88
    call jit_emit_byte
    mov al, 0x50                ; push eax
    call jit_emit_byte
    ret

; Opcode 0x4F: iastore (int - enteros)
jit_op_iastore:
    mov al, 0x5A                ; pop edx (value)
    call jit_emit_byte
    mov al, 0x59                ; pop ecx (index)
    call jit_emit_byte
    mov al, 0x58                ; pop eax (arrayref)
    call jit_emit_byte
    mov al, 0x89                ; mov [eax + ecx * 4], edx
    call jit_emit_byte
    mov al, 0x14
    call jit_emit_byte
    mov al, 0x88
    call jit_emit_byte
    ret
	
; Opcode 0x35: saload (Cargar short de short[])
jit_op_saload:
    mov al, 0x59                ; pop ecx (index)
    call jit_emit_byte
    mov al, 0x5B                ; pop ebx (arrayref)
    call jit_emit_byte
    mov al, 0x0F                ; movsx eax, word [ebx + ecx * 2]
    call jit_emit_byte
    mov al, 0xBF
    call jit_emit_byte
    mov al, 0x04
    call jit_emit_byte
    mov al, 0x4B
    call jit_emit_byte
    mov al, 0x50                ; push eax
    call jit_emit_byte
    ret

; Opcode 0x53: aastore (Guardar referencia en Object[])
jit_op_aastore:
    mov al, 0x58                ; pop eax (value)
    call jit_emit_byte
    mov al, 0x59                ; pop ecx (index)
    call jit_emit_byte
    mov al, 0x5B                ; pop ebx (arrayref)
    call jit_emit_byte
    mov al, 0x89                ; mov [ebx + ecx * 4], eax
    call jit_emit_byte
    mov al, 0x04
    call jit_emit_byte
    mov al, 0x8B
    call jit_emit_byte
    ret

; Opcode 0x54: bastore (Guardar byte en byte[])
jit_op_bastore:
    mov al, 0x58                ; pop eax (value)
    call jit_emit_byte
    mov al, 0x59                ; pop ecx (index)
    call jit_emit_byte
    mov al, 0x5B                ; pop ebx (arrayref)
    call jit_emit_byte
    mov al, 0x88                ; mov [ebx + ecx], al
    call jit_emit_byte
    mov al, 0x04
    call jit_emit_byte
    mov al, 0x0B
    call jit_emit_byte
    ret

; Opcode 0x55: castore (Guardar char UTF-16 en char[])
; Opcode 0x56: sastore (Guardar short en short[])
jit_op_castore:
jit_op_sastore:
    mov al, 0x58                ; pop eax (value)
    call jit_emit_byte
    mov al, 0x59                ; pop ecx (index)
    call jit_emit_byte
    mov al, 0x5B                ; pop ebx (arrayref)
    call jit_emit_byte
    mov al, 0x66                ; mov [ebx + ecx * 2], ax (0x66 0x89 0x04 0x4B)
    call jit_emit_byte
    mov al, 0x89
    call jit_emit_byte
    mov al, 0x04
    call jit_emit_byte
    mov al, 0x4B
    call jit_emit_byte
    ret
	
; Opcode 0xBE: arraylength
jit_op_arraylength:
    mov al, 0x58                ; pop eax (arrayref)
    call jit_emit_byte
    mov al, 0x8B                ; mov eax, [eax - 8] (Length en cabecera)
    call jit_emit_byte
    mov al, 0x40
    call jit_emit_byte
    mov al, 0xF8
    call jit_emit_byte
    mov al, 0x50                ; push eax
    call jit_emit_byte
    ret
	
; Swap de pila (0x5F: swap) 
jit_op_swap:
    mov al, 0x58                ; pop eax (val1)
    call jit_emit_byte
    mov al, 0x5B                ; pop ebx (val2)
    call jit_emit_byte
    mov al, 0x50                ; push eax
    call jit_emit_byte
    mov al, 0x53                ; push ebx
    call jit_emit_byte
    ret	
	
jit_op_dup:
    mov al, 0x58                ; pop eax
    call jit_emit_byte
    mov al, 0x50                ; push eax
    call jit_emit_byte
    mov al, 0x50                ; push eax
    call jit_emit_byte
    ret

jit_op_pop:
    mov al, 0x58                ; pop eax
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

jit_op_return:
    call jit_emit_epilogue
    ret

; Opcode 0xBC: newarray <atype_8bit>
jit_op_newarray:
    movzx ebx, byte [esi]       ; Leer atype (ignorado o usado para tipo)
    inc esi                     ; Consumir atype byte

    ; Emitir wrapper nativo x86 para alojar el array:
    ; 1. Desapilar el tamaño (count) enviado por Java
    mov al, 0x58                ; pop eax (count)
    call jit_emit_byte

    ; 2. Calcular bytes a pedir: (count * 4) + 8 (cabecera)
    mov al, 0x89                ; mov ecx, eax
    call jit_emit_byte
    mov al, 0xC1
    call jit_emit_byte
    
    mov al, 0xC1                ; shl eax, 2 (count * 4)
    call jit_emit_byte
    mov al, 0xE0
    call jit_emit_byte
    mov al, 0x04
    call jit_emit_byte

    mov al, 0x83                ; add eax, 8
    call jit_emit_byte
    mov al, 0xC0
    call jit_emit_byte
    mov al, 0x08
    call jit_emit_byte

    ; 3. Llamar a sys_kalloc(bytes)
    mov al, 0x50                ; push eax
    call jit_emit_byte
    mov al, 0xE8                ; call rel32 sys_kalloc
    call jit_emit_byte
    mov eax, sys_kalloc
    mov ebx, [jit_buffer_ptr]
    add ebx, 4
    sub eax, ebx
    call jit_emit_dword
    mov al, 0x83                ; add esp, 4
    call jit_emit_byte
    mov al, 0xC4
    call jit_emit_byte
    mov al, 0x04
    call jit_emit_byte

    ; 4. Escribir cabecera: [EAX] = count (length)
    mov al, 0x89                ; mov [eax], ecx
    call jit_emit_byte
    mov al, 0x08
    call jit_emit_byte

    ; 5. Devolver puntero al inicio de los datos (EAX + 8)
    mov al, 0x83                ; add eax, 8
    call jit_emit_byte
    mov al, 0xC0
    call jit_emit_byte
    mov al, 0x08
    call jit_emit_byte

    ; 6. Empujar la referencia del array a la pila nativa
    mov al, 0x50                ; push eax
    call jit_emit_byte
    ret
	
; Manejador de Opcodes No Soportados con Diagnóstico Hexadecimal
jit_op_unsupported:
    movzx eax, byte [esi - 1]   ; Cargar el opcode que falló en EAX

    mov ebx, eax
    shr ebx, 4                  ; Nibble alto
    call .nibble_to_hex
    mov [hex_byte_str], bl

    mov ebx, eax
    and ebx, 0x0F               ; Nibble bajo
    call .nibble_to_hex
    mov [hex_byte_str + 1], bl

    push msg_panic_head
    call sys_serial_puts
    add esp, 4

    push hex_byte_str
    call sys_serial_puts
    add esp, 4

    cli
    hlt

.nibble_to_hex:
    cmp bl, 9
    jbe .is_digit
    add bl, 7
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
; EJECUSIÓN REAL DE MÉTODOS JAVA DESDE 'main'
; ----------------------------------------------------------------------------
jit_execute_method:
    push ebp
    mov ebp, esp
    push ebx
    push ecx
    push edx

    ; Tamaño dinámico para compilar todo Boot.main (4096 bytes)
    mov ecx, 4096

    ; Compilar el bytecode
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
msg_panic_head:         db 13, 10, "[JIT Panic] Unsupported Opcode: 0x", 0
hex_byte_str:           db "00!", 13, 10, 0

section .rodata
align 4
jit_opcode_table:
    dd jit_op_nop                   ; 0x00 - nop
    dd jit_op_aconst_null           ; 0x01 - aconst_null
    dd jit_op_iconst_m1             ; 0x02 - iconst_m1
    dd jit_op_iconst_0              ; 0x03 - iconst_0
    dd jit_op_iconst_1              ; 0x04 - iconst_1
    dd jit_op_iconst_2              ; 0x05 - iconst_2
    dd jit_op_iconst_3              ; 0x06 - iconst_3
    dd jit_op_iconst_4              ; 0x07 - iconst_4
    dd jit_op_iconst_5              ; 0x08 - iconst_5
    dd jit_op_lconst_0              ; 0x09 - lconst_0
    dd jit_op_lconst_1              ; 0x0A - lconst_1
    dd jit_op_fconst_0              ; 0x0B - fconst_0
    dd jit_op_fconst_1              ; 0x0C - fconst_1
    dd jit_op_fconst_2              ; 0x0D - fconst_2
    dd jit_op_dconst_0              ; 0x0E - dconst_0 
    dd jit_op_dconst_1              ; 0x0F - dconst_1 
    dd jit_op_bipush                ; 0x10 - bipush
    dd jit_op_sipush                ; 0x11 - sipush
    dd jit_op_ldc                   ; 0x12 - ldc
    dd jit_op_ldc_w                 ; 0x13 - ldc_w 
    dd jit_op_unsupported           ; 0x14 - ldc2_w
    dd jit_op_iload                 ; 0x15 - iload
    dd jit_op_unsupported           ; 0x16 - lload
    dd jit_op_fload                 ; 0x17 - fload 
    dd jit_op_unsupported           ; 0x18 - dload
    dd jit_op_aload                 ; 0x19 - aload
    dd jit_op_iload_0               ; 0x1A - iload_0
    dd jit_op_iload_1               ; 0x1B - iload_1
    dd jit_op_iload_2               ; 0x1C - iload_2 
    dd jit_op_iload_3               ; 0x1D - iload_3 
    dd jit_op_iload_4               ; 0x1E - iload_4
    dd jit_op_iload_5               ; 0x1F - iload_5
    dd jit_op_lload_0               ; 0x20 - lload_0 
    dd jit_op_lload_1               ; 0x21 - lload_1 
    dd jit_op_fload_0               ; 0x22 - fload_0
    dd jit_op_fload_1               ; 0x23 - fload_1
    dd jit_op_fload_2               ; 0x24 - fload_2
    dd jit_op_fload_3               ; 0x25 - fload_3
    dd jit_op_dload_0               ; 0x26 - dload_0 
    times 3 dd jit_op_unsupported   ; 0x27..0x29 - dload_1..3
    dd jit_op_aload_0               ; 0x2A - aload_0
    dd jit_op_aload_1               ; 0x2B - aload_1 
    dd jit_op_aload_2               ; 0x2C - aload_2 
    dd jit_op_aload_3               ; 0x2D - aload_3 
    dd jit_op_aload_4               ; 0x2E - aload_4
    dd jit_op_aload_5               ; 0x2F - aload_5
    dd jit_op_iaload                ; 0x30 - iaload
    dd jit_op_unsupported           ; 0x31 - laload
    dd jit_op_aaload                ; 0x32 - aaload 
    dd jit_op_unsupported           ; 0x33 - baload
    dd jit_op_unsupported           ; 0x34 - caload
    dd jit_op_saload                ; 0x35 - saload
    dd jit_op_istore                ; 0x36 - istore
    dd jit_op_unsupported           ; 0x37 - lstore
    dd jit_op_unsupported           ; 0x38 - fstore
    dd jit_op_unsupported           ; 0x39 - dstore
    dd jit_op_astore                ; 0x3A - astore 
    dd jit_op_istore_0              ; 0x3B - istore_0
    dd jit_op_istore_1              ; 0x3C - istore_1
    dd jit_op_istore_2              ; 0x3D - istore_2 
    dd jit_op_istore_3              ; 0x3E - istore_3 
    dd jit_op_lstore_0              ; 0x3F - lstore_0
    dd jit_op_lstore_1              ; 0x40 - lstore_1
    times 6 dd jit_op_unsupported   ; 0x41..0x46
    dd jit_op_astore_0              ; 0x47 - astore_0 
    dd jit_op_astore_1              ; 0x48 - astore_1 
    dd jit_op_astore_2              ; 0x49 - astore_2 
    dd jit_op_astore_3              ; 0x4A - astore_3 
    dd jit_op_astore_4              ; 0x4B - astore_4
    dd jit_op_astore_5              ; 0x4C - astore_5
    times 2 dd jit_op_unsupported   ; 0x4D..0x4E
    dd jit_op_iastore               ; 0x4F - iastore
    times 3 dd jit_op_unsupported   ; 0x50..0x52
    dd jit_op_aastore               ; 0x53 - aastore 
    dd jit_op_bastore               ; 0x54 - bastore 
    dd jit_op_castore               ; 0x55 - castore 
    dd jit_op_sastore               ; 0x56 - sastore 
    dd jit_op_pop                   ; 0x57 - pop 
    dd jit_op_unsupported           ; 0x58 - pop2
    dd jit_op_dup                   ; 0x59 - dup
    times 5 dd jit_op_unsupported   ; 0x5A..0x5E 
    dd jit_op_swap                  ; 0x5F - swap 
    dd jit_op_iadd                  ; 0x60 - iadd
    dd jit_op_unsupported           ; 0x61 - ladd
    dd jit_op_unsupported           ; 0x62 - fadd
    dd jit_op_unsupported           ; 0x63 - dadd
    dd jit_op_isub                  ; 0x64 - isub 
    dd jit_op_unsupported           ; 0x65 - lsub
    dd jit_op_unsupported           ; 0x66 - fsub
    dd jit_op_unsupported           ; 0x67 - dsub
    dd jit_op_imul                  ; 0x68 - imul 
    dd jit_op_unsupported           ; 0x69 - lmul
    dd jit_op_unsupported           ; 0x6A - fmul
    dd jit_op_imul                  ; 0x6B - dmul/imul
    dd jit_op_idiv                  ; 0x6C - idiv 
    dd jit_op_unsupported           ; 0x6D - ldiv
    dd jit_op_unsupported           ; 0x6E - fdiv
    dd jit_op_unsupported           ; 0x6F - ddiv
    dd jit_op_irem                  ; 0x70 - irem 
    dd jit_op_unsupported           ; 0x71 - lrem
    dd jit_op_unsupported           ; 0x72 - frem
    dd jit_op_unsupported           ; 0x73 - drem
    dd jit_op_ineg                  ; 0x74 - ineg 
    times 3 dd jit_op_unsupported   ; 0x75..0x77
    dd jit_op_ishl                  ; 0x78 - ishl 
    dd jit_op_unsupported           ; 0x79 - lshl
    dd jit_op_ishr                  ; 0x7A - ishr 
    dd jit_op_unsupported           ; 0x7B - lshr
    dd jit_op_iushr                 ; 0x7C - iushr 
    dd jit_op_unsupported           ; 0x7D - lushr
    dd jit_op_iand                  ; 0x7E - iand 
    dd jit_op_unsupported           ; 0x7F - land
    dd jit_op_ior                   ; 0x80 - ior  
    dd jit_op_unsupported           ; 0x81 - lor
    dd jit_op_ixor                  ; 0x82 - ixor 
    dd jit_op_unsupported           ; 0x83 - lxor
    dd jit_op_iinc                  ; 0x84 - iinc
    dd jit_op_i2l                   ; 0x85 - i2l  
    times 2 dd jit_op_unsupported   ; 0x86..0x87
    dd jit_op_l2i                   ; 0x88 - l2i 
    times 8 dd jit_op_unsupported   ; 0x89..0x90
    dd jit_op_i2b                   ; 0x91 - i2b 
    dd jit_op_i2c                   ; 0x92 - i2c 
    times 6 dd jit_op_unsupported   ; 0x93..0x98
    dd jit_op_ifeq                  ; 0x99 - ifeq
    dd jit_op_ifne                  ; 0x9A - ifne 
    dd jit_op_unsupported           ; 0x9B - iflt
    dd jit_op_ifge                  ; 0x9C - ifge 
    dd jit_op_unsupported           ; 0x9D - ifgt
    dd jit_op_ifle                  ; 0x9E - ifle
    dd jit_op_if_icmpeq             ; 0x9F - if_icmpeq
    dd jit_op_if_icmpne             ; 0xA0 - if_icmpne 
    dd jit_op_if_icmplt             ; 0xA1 - if_icmplt 
    dd jit_op_if_icmpge             ; 0xA2 - if_icmpge 
    dd jit_op_if_icmpgt             ; 0xA3 - if_icmpgt 
    dd jit_op_if_icmple             ; 0xA4 - if_icmple 
    times 2 dd jit_op_unsupported   ; 0xA5..0xA6
    dd jit_op_goto                  ; 0xA7 - goto
    times 4 dd jit_op_unsupported   ; 0xA8..0xAB
    dd jit_op_ireturn               ; 0xAC - ireturn
    times 4 dd jit_op_unsupported   ; 0xAD..0xB0
    dd jit_op_return                ; 0xB1 - return
    times 5 dd jit_op_unsupported   ; 0xB2..0xB6
    dd jit_op_invokespecial         ; 0xB7 - invokespecial 
    dd jit_op_invokestatic          ; 0xB8 - invokestatic
    times 3 dd jit_op_unsupported   ; 0xB9..0xBB
    dd jit_op_newarray              ; 0xBC - newarray
    dd jit_op_unsupported           ; 0xBD - anewarray
    dd jit_op_arraylength           ; 0xBE - arraylength 
    times 65 dd jit_op_unsupported  ; 0xBF..0xFF

section .note.GNU-stack noalloc noexec nowrite progbits
