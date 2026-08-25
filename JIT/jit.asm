; ============================================================================
; JVMOS - JavaMonolitic JIT Engine
; Formato: NASM x86 32-bit (Modo Protegido Bare-Metal)
; ============================================================================

[bits 32]

section .bss

align 16
    jit_buffer_base: resd 1    	; base física de memoria JIT (0x00200000)
    jit_buffer_ptr:  resd 1    	; cursor actual
    jit_buffer_end:  resd 1    	; límite de memoria
	
	; tabla de resolución de saltos
	align 4
	pc_map:			 resd 65536	; hasta 64kb de bytecode por método
	fixup_addr:		 resd 1024	; donde sobreescribir métodos nativos
	fixup_target: 	 resd 1024  ; a cual PC del bytecode apuntaba
    fixup_count:  	 resd 1     ; contador de saltos hacia adelante

section .data
    jit_bytecode_base: dd 0
    loop_start_addr:   dd 0

    ; Bytecodes de Prueba
    test_bytecode_p2: db 0x10, 0x42, 0xAC                           ; bipush 66, ireturn
    test_bytecode_p3: db 0x10, 0x0A, 0x3B, 0x10, 0x14, 0x3C, 0x1B, 0xAC ; ret 20 (local_var 1)
    test_bytecode_p4: db 0x10, 0x0A, 0x3B, 0x10, 0x14, 0x3C, 0x1A, 0x1B, 0x60, 0xAC ; 10 + 20 = 30
    test_bytecode_p5: db 0x1A, 0x1B, 0x60, 0xAC                      ; param0 + param1 (40 + 60 = 100)
    test_bytecode_p6: db 0x03, 0x3B, 0x1A, 0x10, 0x05, 0x9F, 0x00, 0x0A, 0x1A, 0x04, 0x60, 0x3B, 0xA7, 0xFF, 0xF6, 0x1A, 0xAC ; loop 5

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
        
	global sys_native_dispatch
	extern sys_kalloc
	extern cp_base_ptr
	extern cp_offsets
	; Símbolos de Syscalls del Kernel (de jvm_native.asm / sys_api.asm)	
	extern sys_arg_id, sys_arg_a, sys_arg_b, sys_arg_c, sys_arg_d			
	extern draw_char_vram, sys_draw_string, sys_serial_puts
	extern current_color
	extern sys_read_keyboard_scancode, sys_set_keyboard_layout, sys_read_mouse 
	extern sys_draw_rect, sys_fill_rect, sys_draw_line, sys_get_pixel, sys_draw_pixel
	extern sys_beep, sys_nosound, sys_get_free_mem, sys_get_ram_size
	extern sys_pci_read_config, sys_disk_read_sector, sys_disk_write_sector
	extern sys_rtl8139_init, sys_rtl8139_send_packet, sys_net_receive_packet
	extern sys_inb, sys_outb, sys_inw, sys_outw, sys_indw, sys_outdw, sys_get_ticks
	extern sys_get_time, sys_sleep, sys_exit

; EMISORES DE CÓDIGO Y NUCLEO (Fase 1)

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
    pop edi
    cli
    hlt

jit_emit_dword:
    push edi
    push ecx
    mov edi, [jit_buffer_ptr]
    lea ecx, [edi + 4]
    cmp ecx, [jit_buffer_end]
    jae .overflow
    mov [edi], eax
    mov [jit_buffer_ptr], ecx
    pop ecx
    pop edi
    ret
.overflow:
    pop ecx
    pop edi
    cli
    hlt

jit_emit_prologue:
    mov al, 0x55                ; push ebp
    call jit_emit_byte
    mov al, 0x89                ; mov ebp, esp
    call jit_emit_byte
    mov al, 0xE5
    call jit_emit_byte

    mov al, 0x53                ; push ebx  -> [ebp - 4]
    call jit_emit_byte
    mov al, 0x56                ; push esi  -> [ebp - 8]
    call jit_emit_byte
    mov al, 0x57                ; push edi  -> [ebp - 12]
    call jit_emit_byte

    mov al, 0x81                ; sub esp, 128 (Locals 0-31 reside at ebp-16 to ebp-144)
    call jit_emit_byte
    mov al, 0xEC
    call jit_emit_byte
    mov eax, 128
    call jit_emit_dword
    ret

jit_emit_epilogue:
    mov al, 0x8D                ; lea esp, [ebp - 12]
    call jit_emit_byte
    mov al, 0x65
    call jit_emit_byte
    mov al, 0xF4                ; -12 in 8-bit two's complement
    call jit_emit_byte

    mov al, 0x5F                ; pop edi
    call jit_emit_byte
    mov al, 0x5E                ; pop esi
    call jit_emit_byte
    mov al, 0x5B                ; pop ebx
    call jit_emit_byte
    mov al, 0x5D                ; pop ebp
    call jit_emit_byte
    mov al, 0xC3                ; ret
    call jit_emit_byte
    ret

sys_native_dispatch:
    push ebp
    mov ebp, esp
    push ebx
    push ecx
    push edx

    mov eax, [sys_arg_id]

    cmp eax, 0                  ; SYS_KALLOC
    je .sys_kalloc
    cmp eax, 1                  ; SYS_SET_COLOR
    je .sys_set_color
    cmp eax, 2                  ; SYS_FILL_RECT
    je .sys_fill_rect
    cmp eax, 3                  ; SYS_DRAW_RECT
    je .sys_draw_rect
    cmp eax, 4                  ; SYS_DRAW_LINE
    je .sys_draw_line
    cmp eax, 5                  ; SYS_DRAW_STRING
    je .sys_draw_string
    cmp eax, 6                  ; SYS_READ_KEYBOARD
    je .sys_read_keyboard
    cmp eax, 7                  ; SYS_READ_MOUSE
    je .sys_read_mouse
    cmp eax, 12                 ; SYS_SLEEP
    je .sys_sleep
    cmp eax, 13                 ; SYS_GET_TIME
    je .sys_get_time
    cmp eax, 15                 ; SYS_DRAW_CHAR
    je .sys_draw_char
    cmp eax, 16                 ; SYS_SET_KBD_LAYOUT / VBE Init
    je .sys_set_kbd_layout
    cmp eax, 17                 ; SYS_EXIT
    je .sys_exit
    cmp eax, 18                 ; SYS_GET_TICKS
    je .sys_get_ticks

    xor eax, eax
    jmp .done

.sys_kalloc:
    push dword [sys_arg_a]
    call sys_kalloc
    add esp, 4
    jmp .done                   ; Retorna puntero en EAX

.sys_set_color:
    mov eax, [sys_arg_a]
    or eax, 0xFF000000
    mov [current_color], eax
    xor eax, eax
    jmp .done

.sys_fill_rect:
    push dword [sys_arg_d]      ; Height
    push dword [sys_arg_c]      ; Width
    push dword [sys_arg_b]      ; Y
    push dword [sys_arg_a]      ; X
    call sys_fill_rect
    add esp, 16
    xor eax, eax
    jmp .done

.sys_draw_rect:
    push dword [sys_arg_d]
    push dword [sys_arg_c]
    push dword [sys_arg_b]
    push dword [sys_arg_a]
    call sys_draw_rect
    add esp, 16
    xor eax, eax
    jmp .done

.sys_draw_line:
    push dword [sys_arg_d]
    push dword [sys_arg_c]
    push dword [sys_arg_b]
    push dword [sys_arg_a]
    call sys_draw_line
    add esp, 16
    xor eax, eax
    jmp .done

.sys_draw_string:
    push dword [sys_arg_c]      ; Pointer String ASCII / Object
    push dword [sys_arg_b]      ; Y
    push dword [sys_arg_a]      ; X
    call sys_draw_string
    add esp, 12
    xor eax, eax
    jmp .done

.sys_read_keyboard:
    call sys_read_keyboard_scancode   ; EAX = ASCII retornado por HAL    
    jmp .done	

.sys_read_mouse:
    push dword [sys_arg_a]      ; Componente (0=X, 1=Y, 2=Btn)
    call sys_read_mouse
    add esp, 4
    jmp .done                   ; Retorna coord/estado en EAX

.sys_sleep:
    push dword [sys_arg_a]
    call sys_sleep
    add esp, 4
    xor eax, eax
    jmp .done

.sys_get_time:
    push dword [sys_arg_a]      ; Campo CMOS RTC
    call sys_get_time
    add esp, 4
    jmp .done                   ; Retorna entero de tiempo en EAX

.sys_draw_char:
    push dword [current_color]
    push dword [sys_arg_b]      ; Y
    push dword [sys_arg_a]      ; X
    push dword [sys_arg_c]      ; Char ASCII
    call draw_char_vram
    add esp, 16
    xor eax, eax
    jmp .done

.sys_set_kbd_layout:
    push dword [sys_arg_a]
    call sys_set_keyboard_layout
    add esp, 4
    mov eax, 1
    jmp .done

.sys_exit:
    call sys_exit
    xor eax, eax
    jmp .done

.sys_get_ticks:
    call sys_get_ticks
    jmp .done

.done:
    pop edx
    pop ecx
    pop ebx
    mov esp, ebp
    pop ebp
    ret

; COMPILADOR JIT

jit_compile_method:
    push ebp
    mov ebp, esp
    push ebx
    push esi
    push edi

    ; Limpiar marcas de bucles
    mov dword [loop_start_addr], 0
    mov dword [fixup_count], 0
    mov [jit_bytecode_base], esi

    ; Forzar reinicio del cursor al inicio de la memoria asignada
    mov eax, 0x00200000
    mov ebx, 65536
    call jit_init

    push esi                    ; Preservar ESI para el compilador
    call jit_emit_prologue

    mov edi, esi
    add edi, ecx                ; EDI = Fin exacto del bytecode

.compile_loop:
    cmp esi, edi
    jae .resolve_fixups         ; En lugar de terminar directo, vamos a parchear saltos

    ; Registrar la correspondencia PC -> Dirección Nativa
    mov ecx, esi
    sub ecx, [jit_bytecode_base] ; ECX = PC actual del bytecode
    mov edx, [jit_buffer_ptr]    ; EDX = Dirección x86 actual
    mov [pc_map + ecx * 4], edx  ; Guardar en el mapa

    ; Extraer y ejecutar opcode
    movzx eax, byte [esi]
    inc esi
    mov ebx, [jit_opcode_table + eax * 4]
    call ebx

    jmp .compile_loop

.resolve_fixups:
    ; Parchear los saltos hacia adelante
    mov ecx, [fixup_count]
    test ecx, ecx
    jz .compile_done            ; Si no hay saltos pendientes, terminar
    xor ebx, ebx                ; EBX = índice del fixup

.fixup_loop:
    mov eax, [fixup_target + ebx * 4] ; EAX = Target PC del bytecode
    mov edx, [pc_map + eax * 4]       ; EDX = Dirección Nativa x86 de ese Target
    mov edi, [fixup_addr + ebx * 4]   ; EDI = Dónde quedó el "0x00000000" por parchear
    
    ; Calcular salto relativo: Destino - (Dirección del parche + 4 bytes de la instrucción)
    mov eax, edx
    sub eax, edi
    sub eax, 4                        
    mov [edi], eax                    ; Sobrescribir los 0s con el salto real!

    inc ebx
    cmp ebx, ecx
    jb .fixup_loop

.compile_done:
    pop esi                     ; Restaurar ESI original
    mov eax, [jit_buffer_base]  ; Retornar 0x00200000 en EAX
    pop edi
    pop esi
    pop ebx
    mov esp, ebp
    pop ebp
    ret


; OPCODES UNIFICADOS Y MIGRACIONES ARITMÉTICAS
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

; Opcode 0x12: ldc (Cargar constante de 32-bit o puntero a String)
jit_op_ldc:
    movzx eax, byte [esi]       ; Leer índice CP
    inc esi                     ; Consumir byte de índice

    mov ebx, [cp_base_ptr]
    test ebx, ebx
    jz .fallback_zero

    mov eax, [ebx + eax * 4]    ; Extraer offset físico de la constante
    test eax, eax
    jz .fallback_zero

    cmp byte [eax], 8           ; ¿Es CONSTANT_String (Tag 8)?
    je .is_string

    ; Si es Integer/Float (Tag 3 o 4), leer valor de 32 bits y convertir Big-Endian -> Little-Endian
    mov eax, [eax + 1]
    bswap eax
    jmp .emit_val

.is_string:
    mov ax, [eax + 1]
    xchg al, ah
    movzx eax, ax               ; EAX = Index del UTF-8 en CP
    mov ebx, [cp_base_ptr]
    mov eax, [ebx + eax * 4]
    add eax, 3                  ; Saltar Tag (1B) y Length (2B) para apuntar al texto char*
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
	
; Opcode 0x13: ldc_w (Lee 2 bytes de índice en la Constant Pool)
jit_op_ldc_w:
    movzx eax, byte [esi]       ; Byte alto
    inc esi
    movzx ebx, byte [esi]       ; Byte bajo
    inc esi
    shl eax, 8
    or eax, ebx                 ; EAX = CP Index de 16 bits

    mov ebx, [cp_offsets + eax * 4]
    test ebx, ebx
    jz .fallback_zero

    cmp byte [ebx], 8
    je .is_string_w

    mov eax, [ebx + 1]
    bswap eax
    jmp .emit_val_w

.is_string_w:
    mov ax, [ebx + 1]
    xchg al, ah
    movzx eax, ax
    mov ebx, [cp_offsets + eax * 4]
    add ebx, 3
    mov eax, ebx
    jmp .emit_val_w

.fallback_zero:
    xor eax, eax

.emit_val_w:
    push eax
    mov al, 0x68                ; push imm32
    call jit_emit_byte
    pop eax
    call jit_emit_dword
    ret

; Opcode 0x14
jit_op_ldc2_w:
    movzx eax, byte [esi]       ; Byte alto del CP Index
    inc esi
    movzx ebx, byte [esi]       ; Byte bajo
    inc esi
    shl eax, 8
    or eax, ebx

    mov ebx, [cp_offsets + eax * 4]
    test ebx, ebx
    jz .fallback_zero_64

    ; Cargar 64 bits de la Constant Pool y convertir Big-Endian a Little-Endian
    mov eax, [ebx + 1]          ; High Dword
    mov edx, [ebx + 5]          ; Low Dword
    bswap eax
    bswap edx
    jmp .emit_val_64

.fallback_zero_64:
    xor eax, eax
    xor edx, edx

.emit_val_64:
    push edx                    ; Parte alta
    push eax                    ; Parte baja
    
    mov al, 0x68                ; push imm32 (High)
    call jit_emit_byte
    pop eax
    call jit_emit_dword
    
    mov al, 0x68                ; push imm32 (Low)
    call jit_emit_byte
    pop eax
    call jit_emit_dword
    ret
	
; Opcode 0xBB: new <index_16bit> (Asignación de nueva instancia de objeto)
jit_op_new:
    push esi                    ; Preservar ESI
    movzx eax, byte [esi]
    inc esi
    movzx ebx, byte [esi]
    inc esi
    shl eax, 8
    or eax, ebx

    mov ebx, [cp_offsets + eax * 4]
    test ebx, ebx
    jz .new_fallback

    movzx eax, word [ebx + 1]
    rol ax, 8
    add eax, 8
    jmp .alloc_obj

.new_fallback:
    mov eax, 32

.alloc_obj:
    mov al, 0x50                ; push eax
    call jit_emit_byte
    mov al, 0xE8                ; call rel32 sys_kalloc
    call jit_emit_byte
    push eax
    mov eax, sys_kalloc
    mov ebx, [jit_buffer_ptr]
    add ebx, 4
    sub eax, ebx
    call jit_emit_dword
    pop eax
    mov al, 0x83                ; add esp, 4
    call jit_emit_byte
    mov al, 0xC4
    call jit_emit_byte
    mov al, 0x04
    call jit_emit_byte
    mov al, 0x50                ; push eax
    call jit_emit_byte
    pop esi                     ; Restaurar ESI
    ret

; Opcode 0xB2: getstatic <index_16bit> (Leer campo estático global)
jit_op_getstatic:
    movzx eax, byte [esi]
    inc esi
    movzx ebx, byte [esi]
    inc esi
    shl eax, 8
    or eax, ebx

    mov ebx, [cp_offsets + eax * 4] ; Dirección base de la variable estática en memoria

    mov al, 0xA1                ; mov eax, [absolute_addr]
    call jit_emit_byte
    mov eax, ebx
    call jit_emit_dword
    mov al, 0x50                ; push eax
    call jit_emit_byte
    ret

; Opcode 0xB3: putstatic <index_16bit> (Escribir campo estático global)
jit_op_putstatic:
    movzx eax, byte [esi]
    inc esi
    movzx ebx, byte [esi]
    inc esi
    shl eax, 8
    or eax, ebx

    mov ebx, [cp_offsets + eax * 4]

    mov al, 0x58                ; pop eax (value)
    call jit_emit_byte
    mov al, 0xA3                ; mov [absolute_addr], eax
    call jit_emit_byte
    mov eax, ebx
    call jit_emit_dword
    ret
	
; Opcode 0xB4: getfield <index_16bit> (Leer campo de objeto: obj_ref -> value)
jit_op_getfield:
    movzx eax, byte [esi]
    inc esi
    movzx ebx, byte [esi]
    inc esi
    shl eax, 8
    or eax, ebx                 ; EAX = Field CP Index

    ; Offset del campo (en un motor JIT plano bare-metal, extraemos el field_offset)
    ; Mapeamos el índice directamente a un offset multiplicando o leyendo del CP
    mov ecx, eax
    shl ecx, 2                  ; Offset = index * 4
    add ecx, 8                  ; +8 para saltar el encabezado del objeto

    mov al, 0x58                ; pop eax (obj_ref)
    call jit_emit_byte
    mov al, 0x8B                ; mov eax, [eax + disp8/disp32]
    call jit_emit_byte
    mov al, 0x40                ; ModRM: [eax + disp8]
    call jit_emit_byte
    mov al, cl                  ; Offset del campo
    call jit_emit_byte
    mov al, 0x50                ; push eax (valor del campo)
    call jit_emit_byte
    ret

; Opcode 0xB5: putfield <index_16bit> (Escribir campo de objeto: obj_ref, value -> )
jit_op_putfield:
    movzx eax, byte [esi]
    inc esi
    movzx ebx, byte [esi]
    inc esi
    shl eax, 8
    or eax, ebx

    mov ecx, eax
    shl ecx, 2
    add ecx, 8                  ; Offset = (index * 4) + 8

    mov al, 0x58                ; pop eax (value)
    call jit_emit_byte
    mov al, 0x5B                ; pop ebx (obj_ref)
    call jit_emit_byte
    mov al, 0x89                ; mov [ebx + disp8], eax
    call jit_emit_byte
    mov al, 0x43
    call jit_emit_byte
    mov al, cl                  ; Offset del campo
    call jit_emit_byte
    ret

; Opcode 0xB6: invokevirtual <index_16bit>
jit_op_invokevirtual:
    movzx eax, byte [esi]
    inc esi
    movzx ebx, byte [esi]
    inc esi
    shl eax, 8
    or eax, ebx                 ; EAX = Vtable Index

    mov ecx, eax
    shl ecx, 2                  ; ECX = offset en bytes (index * 4)

    mov al, 0x5B                ; pop ebx (obj_ref)
    call jit_emit_byte
    mov al, 0x53                ; push ebx (this)
    call jit_emit_byte

    mov al, 0x8B                ; mov eax, [ebx + 4]
    call jit_emit_byte
    mov al, 0x43
    call jit_emit_byte
    mov al, 0x04
    call jit_emit_byte

    mov al, 0xFF                ; call dword [eax + offset]
    call jit_emit_byte
    mov al, 0x50
    call jit_emit_byte
    mov al, cl                  ; Vtable offset
    call jit_emit_byte
    ret

; Opcode 0xB9: invokeinterface <index_16bit, count, 0>
jit_op_invokeinterface:
    add esi, 2                  ; Consumir 2 bytes de CP Index
    inc esi                     ; Consumir byte 'count'
    inc esi                     ; Consumir byte 0 de relleno
    jmp jit_op_invokevirtual    ; Reorganizar mediante vtable directa

; Opcode 0xBA: invokedynamic <index_16bit, 0, 0>
jit_op_invokedynamic:
    add esi, 4                  ; Consumir 4 bytes de operandos de la JVM
    ret							; stub por el momento

; Opcode 0xC0: checkcast <index_16bit> (Verificación de tipo)
jit_op_checkcast:
    add esi, 2                  ; Consumir los 2 bytes de índice CP
    ; En bare-metal simplificado: si obj_ref != null no falla. Mantiene el objeto en la pila.
    ret

; Opcode 0xC1: instanceof <index_16bit> (Comprobación de tipo -> 1 o 0 en la pila)
jit_op_instanceof:
    add esi, 2                  ; Consumir 2 bytes de CP index
    mov al, 0x58                ; pop eax (obj_ref)
    call jit_emit_byte
    mov al, 0x85                ; test eax, eax
    call jit_emit_byte
    mov al, 0xC0
    call jit_emit_byte
    mov al, 0x0F                ; setne al (1 si obj_ref != NULL, 0 si es NULL)
    call jit_emit_byte
    mov al, 0x95
    call jit_emit_byte
    mov al, 0xC0
    call jit_emit_byte
    mov al, 0x0F                ; movzx eax, al
    call jit_emit_byte
    mov al, 0xB6
    call jit_emit_byte
    mov al, 0xC0
    call jit_emit_byte
    mov al, 0x50                ; push eax (resultado boolean 1/0)
    call jit_emit_byte
    ret

; Opcode 0xC2: monitorenter (Desapila referencia del objeto y adquiere Lock)
jit_op_monitorenter:
    mov al, 0x58                ; pop eax (obj_ref)
    call jit_emit_byte
    ; En un entorno bare-metal unihilo es un NOP.
    ; Para multihilo se emitiría una instrucción 'lock bts dword [eax], 0'
    ret

; Opcode 0xC3: monitorexit (Desapila referencia del objeto y libera Lock)
jit_op_monitorexit:
    mov al, 0x58                ; pop eax (obj_ref)
    call jit_emit_byte
    ret
	
; Opcode 0xC4: wide <opcode_target, index_high, index_low>
jit_op_wide:
    movzx eax, byte [esi]       ; Leer sub-opcode objetivo (iload, istore, etc.)
    inc esi
    movzx ebx, byte [esi]       ; Index High
    inc esi
    movzx ecx, byte [esi]       ; Index Low
    inc esi
    shl ebx, 8
    or ebx, ecx                 ; EBX = Índice de 16 bits

    inc ebx
    shl ebx, 2
    neg ebx                     ; EBX = Offset negativo en EBP (-((index + 1) * 4))

    cmp al, 0x15                ; iload
    je .wide_load
    cmp al, 0x36                ; istore
    je .wide_store
    ret

.wide_load:
    mov al, 0x8B                ; mov eax, [ebp + disp32]
    call jit_emit_byte
    mov al, 0x85
    call jit_emit_byte
    mov eax, ebx
    call jit_emit_dword
    mov al, 0x50                ; push eax
    call jit_emit_byte
    ret

.wide_store:
    mov al, 0x58                ; pop eax
    call jit_emit_byte
    mov al, 0x89                ; mov [ebp + disp32], eax
    call jit_emit_byte
    mov al, 0x85
    call jit_emit_byte
    mov eax, ebx
    call jit_emit_dword
    ret

; Opcode 0xC5: multianewarray <index_16bit, dimensions_8bit>
jit_op_multianewarray:
    add esi, 2                  ; Consumir 2 bytes de CP index
    movzx eax, byte [esi]       ; Consumir byte de dimensiones
    inc esi
    jmp jit_op_newarray         ; Redirigir la asignación base
	
; Opcode 0xB7: invokespecial <method_index_16bit>
jit_op_invokespecial:
    add esi, 2                  ; Ignorar índice del CP (Constructor vacío Object.<init>)
    ; Para constructores base simples, no se requiere emitir nada a nivel x86 (NOP)
    ret
	
; Opcode 0xB8: invokestatic
jit_op_invokestatic:
    push esi                    ; Preservar ESI
    movzx eax, byte [esi]
    inc esi
    movzx ebx, byte [esi]
    inc esi
    shl eax, 8
    or eax, ebx                 ; EAX = CP Index del Methodref

    ; Protección contra llamadas sin Constant Pool cargada (evita colapso en Phase 1-6)
    mov ebx, [cp_base_ptr]
    test ebx, ebx
    jz .dispatch_syscall

    mov ebx, [cp_offsets + eax * 4]
    test ebx, ebx
    jz .dispatch_syscall

    ; Extraer Class Index
    movzx eax, word [ebx + 1]
    xchg al, ah
    mov ebx, [cp_offsets + eax * 4]
    test ebx, ebx
    jz .dispatch_syscall
    
    ; Extraer Utf8 Name Index
    movzx eax, word [ebx + 1]
    xchg al, ah
    mov ebx, [cp_offsets + eax * 4]
    test ebx, ebx
    jz .dispatch_syscall
    add ebx, 3                  ; Saltar Tag(1B) y Length(2B)

    ; Comprobar si la clase es 'kernel/Native' (Syscall)
    cmp dword [ebx], 0x6E72656B ; "kern" en ASCII
    je .dispatch_syscall

    ; --- RUTA B: SUBMÉTODO JAVA LOCAL ---
    pop esi                     ; Restaurar ESI
    add esi, 2                  ; Consumir 2 bytes del CP Index

    ; Para submétodos estáticos internos, emitir NOP para preservar pila
    mov al, 0x90
    call jit_emit_byte
    ret

.dispatch_syscall:
    pop esi                     ; Restaurar ESI
    add esi, 2                  ; Consumir 2 bytes del CP Index

    ; Desapilar los 5 argumentos Java -> Variables HAL
    mov al, 0x58                ; pop eax (arg d)
    call jit_emit_byte
    mov al, 0xA3                ; mov [sys_arg_d], eax
    call jit_emit_byte
    mov eax, sys_arg_d
    call jit_emit_dword

    mov al, 0x58                ; pop eax (arg c)
    call jit_emit_byte
    mov al, 0xA3                ; mov [sys_arg_c], eax
    call jit_emit_byte
    mov eax, sys_arg_c
    call jit_emit_dword

    mov al, 0x58                ; pop eax (arg b)
    call jit_emit_byte
    mov al, 0xA3                ; mov [sys_arg_b], eax
    call jit_emit_byte
    mov eax, sys_arg_b
    call jit_emit_dword

    mov al, 0x58                ; pop eax (arg a)
    call jit_emit_byte
    mov al, 0xA3                ; mov [sys_arg_a], eax
    call jit_emit_byte
    mov eax, sys_arg_a
    call jit_emit_dword

    mov al, 0x58                ; pop eax (Syscall ID)
    call jit_emit_byte
    mov al, 0xA3                ; mov [sys_arg_id], eax
    call jit_emit_byte
    mov eax, sys_arg_id
    call jit_emit_dword

    mov al, 0x56                ; push esi
    call jit_emit_byte

    mov al, 0xE8                ; call rel32 sys_native_dispatch
    call jit_emit_byte
    mov eax, sys_native_dispatch
    mov ebx, [jit_buffer_ptr]
    add ebx, 4
    sub eax, ebx
    call jit_emit_dword

    mov al, 0x5E                ; pop esi
    call jit_emit_byte

    ; Empujar el resultado devuelto en EAX a la pila nativa de Java
    mov al, 0x50                ; push eax
    call jit_emit_byte
    ret
	
; constantes tipo float (fconst_0, fconst_1, fconst_2) 
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
	
; carga de variables (iload / aload) 
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

; Opcodes del 0x1A (iload_0), 0x22 (fload_0), 0x2A (aload_0)
; Opcodes iload_0 / istore_0 alineados al prólogo
jit_op_iload_0:
jit_op_aload_0:
jit_op_fload_0:
    cmp dword [loop_start_addr], 0
    jne .skip_mark
    mov eax, [jit_buffer_ptr]
    mov [loop_start_addr], eax
.skip_mark:
    mov al, 0x8B                ; mov eax, [ebp - 16]
    call jit_emit_byte
    mov al, 0x45
    call jit_emit_byte
    mov al, 0xF0
    call jit_emit_byte
    mov al, 0x50                ; push eax
    call jit_emit_byte
    ret

; Opcodes del 0x1B (iload_1), 0x23 (fload_1), 0x2B (aload_1)
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

; carga de variables long (64-BIT) 
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

; almacenamiento de variables long (64-BIT) 
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
	
; almacenamiento de variables (istore / astore) 
jit_op_istore_0:
jit_op_astore_0:
    mov al, 0x58                ; pop eax
    call jit_emit_byte
    mov al, 0x89                ; mov [ebp - 16], eax
    call jit_emit_byte
    mov al, 0x45
    call jit_emit_byte
    mov al, 0xF0
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

; Operaciones de matemática
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
    mov al, 0x58                ; pop eax
    call jit_emit_byte
    mov al, 0x83                ; cmp eax, 0
    call jit_emit_byte
    mov al, 0xF8
    call jit_emit_byte
    mov al, 0x00
    call jit_emit_byte
    mov al, 0x0F                ; JE rel32
    call jit_emit_byte
    mov al, 0x84
    call jit_emit_byte
    call jit_emit_branch_target
    ret

jit_op_ifne:
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
    call jit_emit_branch_target
    ret

; Opcode 0x9E: ifle <branchbyte1, branchbyte2>
jit_op_ifle:
    mov al, 0x58                ; pop eax
    call jit_emit_byte
    mov al, 0x83                ; cmp eax, 0
    call jit_emit_byte
    mov al, 0xF8
    call jit_emit_byte
    mov al, 0x00
    call jit_emit_byte
    mov al, 0x0F                ; JLE rel32
    call jit_emit_byte
    mov al, 0x8E
    call jit_emit_byte
    call jit_emit_branch_target
    ret

; Opcode 0x9C: ifge <branchbyte1, branchbyte2>
jit_op_ifge:
    mov al, 0x58                ; pop eax
    call jit_emit_byte
    mov al, 0x83                ; cmp eax, 0
    call jit_emit_byte
    mov al, 0xF8
    call jit_emit_byte
    mov al, 0x00
    call jit_emit_byte
    mov al, 0x0F                ; JGE rel32
    call jit_emit_byte
    mov al, 0x8D
    call jit_emit_byte
    call jit_emit_branch_target
    ret
	
; Helper genérico para emitir: pop ebx, pop eax, cmp eax, ebx, jcc rel32
jit_emit_icmp_branch:
    push ecx                    ; ECX tiene la condición Jcc x86
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

    call jit_emit_branch_target ; Lee el offset de 2 bytes y emite el rel32
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

; Manejo de arreglos (iaload, iastore, arraylength) 
; Opcode 0x2E: iaload
jit_op_iaload:
    mov al, 0x59                ; pop ecx (index)
    call jit_emit_byte
    mov al, 0x58                ; pop eax (arrayref)
    call jit_emit_byte
    mov al, 0x8B                ; mov eax, [eax + ecx * 4 + 8]
    call jit_emit_byte
    mov al, 0x44
    call jit_emit_byte
    mov al, 0x88
    call jit_emit_byte
    mov al, 0x08                ; Offset +8 de cabecera
    call jit_emit_byte
    mov al, 0x50                ; push eax
    call jit_emit_byte
    ret

; Opcode 0x32: aaload	
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
    mov al, 0x54
    call jit_emit_byte
    mov al, 0x88
    call jit_emit_byte
    mov al, 0x08                ; Offset +8 para la cabecera del Array
    call jit_emit_byte
    ret
	
; Opcode 0x35: saload (Cargar short de short[])
jit_op_saload:
    mov al, 0x59                ; pop ecx (index)
    call jit_emit_byte
    mov al, 0x5B                ; pop ebx (arrayref)
    call jit_emit_byte
    mov al, 0x0F                ; movsx eax, word [ebx + ecx * 2 + 8]
    call jit_emit_byte
    mov al, 0xBF
    call jit_emit_byte
    mov al, 0x4C
    call jit_emit_byte
    mov al, 0x4B
    call jit_emit_byte
    mov al, 0x08                ; Offset +8 de cabecera
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

; Opcode 0x5A: dup_x1 (v1, v2 -> v2, v1, v2)
jit_op_dup_x1:
    mov al, 0x58                ; pop eax (v2)
    call jit_emit_byte
    mov al, 0x5B                ; pop ebx (v1)
    call jit_emit_byte
    mov al, 0x50                ; push eax (v2)
    call jit_emit_byte
    mov al, 0x53                ; push ebx (v1)
    call jit_emit_byte
    mov al, 0x50                ; push eax (v2)
    call jit_emit_byte
    ret

; Opcode 0x5B: dup_x2 (v1, v2, v3 -> v3, v1, v2, v3)
jit_op_dup_x2:
    mov al, 0x58                ; pop eax (v3)
    call jit_emit_byte
    mov al, 0x5B                ; pop ebx (v2)
    call jit_emit_byte
    mov al, 0x59                ; pop ecx (v1)
    call jit_emit_byte
    mov al, 0x50                ; push eax
    call jit_emit_byte
    mov al, 0x51                ; push ecx
    call jit_emit_byte
    mov al, 0x53                ; push ebx
    call jit_emit_byte
    mov al, 0x50                ; push eax
    call jit_emit_byte
    ret

; Opcode 0x5C: dup2 (v1, v2 -> v1, v2, v1, v2)
jit_op_dup2:
    mov al, 0x58                ; pop eax (v2)
    call jit_emit_byte
    mov al, 0x5B                ; pop ebx (v1)
    call jit_emit_byte
    mov al, 0x53                ; push ebx
    call jit_emit_byte
    mov al, 0x50                ; push eax
    call jit_emit_byte
    mov al, 0x53                ; push ebx
    call jit_emit_byte
    mov al, 0x50                ; push eax
    call jit_emit_byte
    ret

; Opcode 0x5D: dup2_x1 y 0x5E: dup2_x2
jit_op_dup2_x1:
jit_op_dup2_x2:
    jmp jit_op_dup2             ; Aliasing defensivo para preservar estabilidad	
    
jit_op_if_icmpeq:
    mov ecx, 0x84               ; JE
    jmp jit_emit_icmp_branch

jit_op_goto:
    mov al, 0xE9                ; JMP rel32
    call jit_emit_byte
    call jit_emit_branch_target
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

; Opcode 0x16: lload <index>
; Opcode 0x18: dload <index>
jit_op_lload:
jit_op_dload:
    movzx ebx, byte [esi]
    inc esi
    inc ebx
    shl ebx, 2
    neg ebx
    ; Cargar parte alta
    mov al, 0x8B                ; mov eax, [ebp + disp8] (High)
    call jit_emit_byte
    mov al, 0x45
    call jit_emit_byte
    mov al, bl
    call jit_emit_byte
    mov al, 0x50                ; push eax
    call jit_emit_byte
    ; Cargar parte baja
    mov al, 0x8B                ; mov eax, [ebp + disp8 - 4] (Low)
    call jit_emit_byte
    mov al, 0x45
    call jit_emit_byte
    mov eax, ebx
    sub eax, 4                  ; Offset para parte baja
    call jit_emit_byte
    mov al, 0x50                ; push eax
    call jit_emit_byte
    ret

; Opcode 0x27: dload_1
jit_op_dload_1:
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

; Opcode 0x28: dload_2
jit_op_dload_2:
    mov al, 0x8B                ; mov eax, [ebp - 12]
    call jit_emit_byte
    mov al, 0x45
    call jit_emit_byte
    mov al, 0xF4
    call jit_emit_byte
    mov al, 0x50                ; push eax
    call jit_emit_byte
    mov al, 0x8B                ; mov eax, [ebp - 16]
    call jit_emit_byte
    mov al, 0x45
    call jit_emit_byte
    mov al, 0xF0
    call jit_emit_byte
    mov al, 0x50                ; push eax
    call jit_emit_byte
    ret

; Opcode 0x29: dload_3
jit_op_dload_3:
    mov al, 0x8B                ; mov eax, [ebp - 16]
    call jit_emit_byte
    mov al, 0x45
    call jit_emit_byte
    mov al, 0xF0
    call jit_emit_byte
    mov al, 0x50                ; push eax
    call jit_emit_byte
    mov al, 0x8B                ; mov eax, [ebp - 20]
    call jit_emit_byte
    mov al, 0x45
    call jit_emit_byte
    mov al, 0xEC
    call jit_emit_byte
    mov al, 0x50                ; push eax
    call jit_emit_byte
    ret

; Opcodes 0x31 (laload), 0x33 (baload), 0x34 (caload)
jit_op_laload:
    jmp jit_op_iaload           ; Tratar como entero de 32 bits en bare-metal

jit_op_baload:
    mov al, 0x59                ; pop ecx (index)
    call jit_emit_byte
    mov al, 0x5B                ; pop ebx (arrayref)
    call jit_emit_byte
    mov al, 0x0F                ; movsx eax, byte [ebx + ecx]
    call jit_emit_byte
    mov al, 0xBE
    call jit_emit_byte
    mov al, 0x0C
    call jit_emit_byte
    mov al, 0x0B
    call jit_emit_byte
    mov al, 0x50                ; push eax
    call jit_emit_byte
    ret

jit_op_caload:
    mov al, 0x59                ; pop ecx (index)
    call jit_emit_byte
    mov al, 0x5B                ; pop ebx (arrayref)
    call jit_emit_byte
    mov al, 0x0F                ; movzx eax, word [ebx + ecx * 2]
    call jit_emit_byte
    mov al, 0xB7
    call jit_emit_byte
    mov al, 0x04
    call jit_emit_byte
    mov al, 0x4B
    call jit_emit_byte
    mov al, 0x50                ; push eax
    call jit_emit_byte
    ret

; Opcodes 0x37 (lstore), 0x38 (fstore), 0x39 (dstore)
jit_op_fstore:
    jmp jit_op_istore

jit_op_lstore:
jit_op_dstore:
    movzx ebx, byte [esi]
    inc esi
    inc ebx
    shl ebx, 2
    neg ebx
    ; Guardar parte baja
    mov al, 0x58                ; pop eax (Low)
    call jit_emit_byte
    mov al, 0x89                ; mov [ebp + disp8 - 4], eax
    call jit_emit_byte
    mov al, 0x45
    call jit_emit_byte
    mov eax, ebx
    sub eax, 4                  ; Offset para parte baja
    call jit_emit_byte
    ; Guardar parte alta
    mov al, 0x58                ; pop eax (High)
    call jit_emit_byte
    mov al, 0x89                ; mov [ebp + disp8], eax
    call jit_emit_byte
    mov al, 0x45
    call jit_emit_byte
    mov al, bl
    call jit_emit_byte
    ret

; Opcodes 0x9B (iflt) y 0x9D (ifgt)
jit_op_iflt:
    mov al, 0x58                ; pop eax
    call jit_emit_byte
    mov al, 0x83                ; cmp eax, 0
    call jit_emit_byte
    mov al, 0xF8
    call jit_emit_byte
    mov al, 0x00
    call jit_emit_byte
    mov al, 0x0F                ; JL rel32
    call jit_emit_byte
    mov al, 0x8C
    call jit_emit_byte
    call jit_emit_branch_target
    ret

jit_op_ifgt:
    mov al, 0x58                ; pop eax
    call jit_emit_byte
    mov al, 0x83                ; cmp eax, 0
    call jit_emit_byte
    mov al, 0xF8
    call jit_emit_byte
    mov al, 0x00
    call jit_emit_byte
    mov al, 0x0F                ; JG rel32
    call jit_emit_byte
    mov al, 0x8F
    call jit_emit_byte
    call jit_emit_branch_target
    ret

; Opcode 0xBD: anewarray (Crear arreglo de objetos/referencias)
jit_op_anewarray:
    add esi, 2                  ; Consumir 2 bytes de CP index
    jmp jit_op_newarray         ; Reusar asignación genérica


; Manejador de negación float/long (0x75..0x77) 
jit_op_lneg:
jit_op_fneg:
jit_op_dneg:
    jmp jit_op_ineg             ; Invertir signo del dword superior en pila

; conversiones y comparadores (0x86..0x87, 0x89..0x90, 0x93..0x98)
; Opcode 0x86: i2f (Int 32-bit -> Float IEEE 754 32-bit)
jit_op_i2f:
    mov al, 0xDB                ; fild dword [esp] (Carga entero de la pila a FPU)
    call jit_emit_byte
    mov al, 0x04
    call jit_emit_byte
    mov al, 0x24
    call jit_emit_byte

    mov al, 0xD9                ; fstp dword [esp] (Guarda float de FPU a la pila)
    call jit_emit_byte
    mov al, 0x1C
    call jit_emit_byte
    mov al, 0x24
    call jit_emit_byte
    ret

; Opcode 0x8B: f2i (Float 32-bit -> Int 32-bit Truncado)
jit_op_f2i:
    mov al, 0xD9                ; fld dword [esp]
    call jit_emit_byte
    mov al, 0x04
    call jit_emit_byte
    mov al, 0x24
    call jit_emit_byte

    mov al, 0xDB                ; fisttp dword [esp] (SSE3) o fistp dword [esp]
    call jit_emit_byte
    mov al, 0x1C
    call jit_emit_byte
    mov al, 0x24
    call jit_emit_byte
    ret
	
jit_op_i2d:
jit_op_l2f:
jit_op_l2d:
jit_op_f2l:
jit_op_f2d:
jit_op_d2i:
jit_op_d2l:
jit_op_d2f:
    ret                         ; No-op: representaciones tratadas como enteros de 32 bits en x86

; Opcode 0x93: i2s (Int -> Short con signo)
jit_op_i2s:
    mov al, 0x58                ; pop eax
    call jit_emit_byte
    mov al, 0x0F                ; movsx eax, ax (0x0F 0xBF 0xC0)
    call jit_emit_byte
    mov al, 0xBF
    call jit_emit_byte
    mov al, 0xC0
    call jit_emit_byte
    mov al, 0x50                ; push eax
    call jit_emit_byte
    ret

; Comparadores 
; Para lcmp (64-bit) - comparación con signo
jit_op_lcmp:
    mov al, 0x5B                ; pop ebx (b_low)
    call jit_emit_byte
    mov al, 0x5A                ; pop edx (b_high)
    call jit_emit_byte
    mov al, 0x59                ; pop ecx (a_low)
    call jit_emit_byte
    mov al, 0x58                ; pop eax (a_high)
    call jit_emit_byte

    mov al, 0x39                ; cmp eax, edx (Comparar partes altas)
    call jit_emit_byte
    mov al, 0xD0
    call jit_emit_byte

    mov al, 0x75                ; jne .cmp_done (Offset 6 bytes)
    call jit_emit_byte
    mov al, 0x06
    call jit_emit_byte

    mov al, 0x39                ; cmp ecx, ebx (Comparar partes bajas sin signo)
    call jit_emit_byte
    mov al, 0xD9
    call jit_emit_byte

.cmp_done:
    mov al, 0x0F                ; setg cl
    call jit_emit_byte
    mov al, 0x9F
    call jit_emit_byte
    mov al, 0xC1
    call jit_emit_byte

    mov al, 0x0F                ; setl dl
    call jit_emit_byte
    mov al, 0x9C
    call jit_emit_byte
    mov al, 0xC2
    call jit_emit_byte

    mov al, 0x0F                ; movzx eax, cl
    call jit_emit_byte
    mov al, 0xB6
    call jit_emit_byte
    mov al, 0xC1
    call jit_emit_byte

    mov al, 0x0F                ; movzx edx, dl
    call jit_emit_byte
    mov al, 0xB6
    call jit_emit_byte
    mov al, 0xD2
    call jit_emit_byte

    mov al, 0x29                ; sub eax, edx
    call jit_emit_byte
    mov al, 0xD0
    call jit_emit_byte

    mov al, 0x50                ; push eax (-1, 0, o 1)
    call jit_emit_byte
    ret

; Helper genérico de comparación Float 32-bit usando FPU x87
; AL = Valor a retornar si hay NaN (1 para fcmpg, -1 para fcmpl)
jit_emit_fcom_routine:
    push eax                    ; Preservar valor default de NaN

    mov al, 0xD9                ; fld dword [esp+4] (Cargar b)
    call jit_emit_byte
    mov al, 0x44
    call jit_emit_byte
    mov al, 0x24
    call jit_emit_byte
    mov al, 0x04
    call jit_emit_byte

    mov al, 0xD9                ; fld dword [esp]   (Cargar a)
    call jit_emit_byte
    mov al, 0x04
    call jit_emit_byte
    mov al, 0x24
    call jit_emit_byte

    mov al, 0xD9                ; fcompp (Comparar y desapilar a y b de la FPU)
    call jit_emit_byte
    mov al, 0xD9
    call jit_emit_byte

    mov al, 0xDF                ; fnstsw ax (Mover flags de FPU a AX)
    call jit_emit_byte
    mov al, 0xE0
    call jit_emit_byte

    mov al, 0x9E                ; sahf (Transferir AH a EFLAGS x86)
    call jit_emit_byte

    mov al, 0x83                ; add esp, 8 (Limpiar los 2 floats de la pila nativa)
    call jit_emit_byte
    mov al, 0xC4
    call jit_emit_byte
    mov al, 0x08
    call jit_emit_byte

    pop eax                     ; Restaurar valor de NaN en EAX
    mov cl, al                  ; CL = default NaN (1 o -1)

    mov al, 0x7A                ; jp .is_nan (Si Parity Flag=1, hubo NaN)
    call jit_emit_byte
    mov al, 0x0A
    call jit_emit_byte

    mov al, 0x0F                ; seta al (a > b)
    call jit_emit_byte
    mov al, 0x97
    call jit_emit_byte
    mov al, 0xC0
    call jit_emit_byte

    mov al, 0x0F                ; setb dl (a < b)
    call jit_emit_byte
    mov al, 0x92
    call jit_emit_byte
    mov al, 0xD2
    call jit_emit_byte

    mov al, 0x0F                ; movzx eax, al
    call jit_emit_byte
    mov al, 0xB6
    call jit_emit_byte
    mov al, 0xC0
    call jit_emit_byte

    mov al, 0x0F                ; movzx edx, dl
    call jit_emit_byte
    mov al, 0xB6
    call jit_emit_byte
    mov al, 0xD2
    call jit_emit_byte

    mov al, 0x29                ; sub eax, edx
    call jit_emit_byte
    mov al, 0xD0
    call jit_emit_byte

    mov al, 0xEB                ; jmp .push_res
    call jit_emit_byte
    mov al, 0x02
    call jit_emit_byte

;.is_nan:
    mov al, 0x0F                ; movsx eax, cl (Cargar 1 o -1)
    call jit_emit_byte
    mov al, 0xBE
    call jit_emit_byte
    mov al, 0xC1
    call jit_emit_byte

;.push_res:
    mov al, 0x50                ; push eax
    call jit_emit_byte
    ret

; Opcode 0x95: fcmpl (NaN -> -1)
jit_op_fcmpl:
    mov al, -1
    call jit_emit_fcom_routine
    ret

; Opcode 0x96: fcmpg (NaN -> 1)
jit_op_fcmpg:
    mov al, 1
    call jit_emit_fcom_routine
    ret

; Opcode 0x97: dcmpl (Double 64-bit Compare, NaN -> -1)
jit_op_dcmpl:
    mov al, 0x83                ; add esp, 8 (Desapilar 64 bits de 'b' extra)
    call jit_emit_byte
    mov al, 0xC4
    call jit_emit_byte
    mov al, 0x08
    call jit_emit_byte
    jmp jit_op_fcmpl            ; Tratar partes altas como float en bare-metal

; Opcode 0x98: dcmpg (Double 64-bit Compare, NaN -> 1)
jit_op_dcmpg:
    mov al, 0x83                ; add esp, 8 (Desapilar 64 bits de 'b' extra)
    call jit_emit_byte
    mov al, 0xC4
    call jit_emit_byte
    mov al, 0x08
    call jit_emit_byte
    jmp jit_op_fcmpg

; saltos condicionales y null point (0xA5..0xA6, 0xC6..0xC7) 
; Opcode 0xA5: if_acmpeq / Opcode 0xA6: if_acmpne
jit_op_if_acmpeq:
    jmp jit_op_if_icmpeq

jit_op_if_acmpne:
    jmp jit_op_if_icmpne

; Opcode 0xC6: ifnull / Opcode 0xC7: ifnonnull
jit_op_ifnull:
    jmp jit_op_ifeq

jit_op_ifnonnull:
    jmp jit_op_ifne

; Opcode 0xC8: goto_w <branchbyte1, branchbyte2, branchbyte3, branchbyte4>
jit_op_goto_w:
    movzx eax, byte [esi]       ; Byte 1 (MSB)
    inc esi
    movzx ebx, byte [esi]       ; Byte 2
    inc esi
    movzx ecx, byte [esi]       ; Byte 3
    inc esi
    movzx edx, byte [esi]       ; Byte 4 (LSB)
    inc esi

    shl eax, 24
    shl ebx, 16
    shl ecx, 8
    or eax, ebx
    or eax, ecx
    or eax, edx                 ; EAX = Offset de 32 bits (Big-Endian -> Native)

    mov al, 0xE9                ; JMP rel32
    call jit_emit_byte

    ; Salto relativo en x86: (loop_start_addr) - (jit_buffer_ptr + 4)
    cmp dword [loop_start_addr], 0
    je .approx_goto_w
    mov eax, [loop_start_addr]
    mov ebx, [jit_buffer_ptr]
    add ebx, 4
    sub eax, ebx
    jmp .emit_goto_w_target

.approx_goto_w:
    imul eax, eax, 5
    sub eax, 6

.emit_goto_w_target:
    call jit_emit_dword
    ret

; Opcode 0xA8: jsr <branchbyte1, branchbyte2> (Salto a Subrutina)
jit_op_jsr:
    ; 1. Calcular el PC de retorno en Bytecode Java
    mov eax, esi
    sub eax, [jit_bytecode_base]  ; PC actual
    add eax, 2                     ; PC después de jsr

    ; 2. Empujar la dirección de retorno en la pila nativa x86
    push eax
    mov al, 0x68                ; push imm32
    call jit_emit_byte
    pop eax
    call jit_emit_dword

    ; 3. Emitir salto JMP rel32 al destino
    mov al, 0xE9
    call jit_emit_byte
    call jit_emit_branch_target
    ret

; Opcode 0xC9: jsr_w <branchbyte1..4> (Salto Largo a Subrutina)
jit_op_jsr_w:
    mov eax, esi
    sub eax, [jit_bytecode_base]  ; PC actual
    add eax, 4                     ; PC después de jsr_w

    push eax
    mov al, 0x68                ; push imm32
    call jit_emit_byte
    pop eax
    call jit_emit_dword

    ; Usar goto_w para el salto
    mov al, 0xE9                ; JMP rel32
    call jit_emit_byte
    call jit_emit_branch_target
    ret

; Opcode 0xA9: ret <index_8bit> (Retorno de Subrutina jsr/jsr_w)
jit_op_ret:
    movzx ebx, byte [esi]       ; Leer índice de variable local
    inc esi

    inc ebx
    shl ebx, 2
    neg ebx                     ; EBX = -((index + 1) * 4)

    ; Desapilar la dirección devuelta en la variable local y saltar
    mov al, 0x8B                ; mov eax, [ebp + disp8]
    call jit_emit_byte
    mov al, 0x45
    call jit_emit_byte
    mov al, bl
    call jit_emit_byte

    mov al, 0xFF                ; jmp eax (0xFF 0xE0)
    call jit_emit_byte
    mov al, 0xE0
    call jit_emit_byte
    ret

; Opcode 0xAA: tableswitch (Switch denso basado en tabla)
jit_op_tableswitch:
    ; Opcional: Alineación del PC en bytecode (múltiplo de 4)
    mov eax, esi
    sub eax, [jit_bytecode_base]
    and eax, 3
    jz .ts_aligned
    neg eax
    add eax, 4
    add esi, eax                ; Consumir padding

.ts_aligned:
    ; Leer default, low, high (32-bit Big-Endian cada uno)
    mov eax, [esi]              ; default_offset
    bswap eax
    add esi, 4
    mov ebx, [esi]              ; low_val
    bswap ebx
    add esi, 4
    mov ecx, [esi]              ; high_val
    bswap ecx
    add esi, 4

    ; Desapilar el índice evaluado (key)
    mov al, 0x58                ; pop eax
    call jit_emit_byte

    ; Bounds Check: Si index < low o index > high -> ir a default
    mov al, 0x3D                ; cmp eax, low_val (imm32)
    call jit_emit_byte
    mov eax, ebx                ; Asegurar que low_val esté en EAX
    call jit_emit_dword

    mov al, 0x0F                ; JL default (0x0F 0x8C)
    call jit_emit_byte
    mov al, 0x8C
    call jit_emit_byte
    push eax
    imul eax, eax, 5
    call jit_emit_dword
    pop eax

    mov al, 0x3D                ; cmp eax, high_val (imm32)
    call jit_emit_byte
    mov eax, ecx                ; Asegurar que high_val esté en EAX
    call jit_emit_dword

    mov al, 0x0F                ; JG default (0x0F 0x8F)
    call jit_emit_byte
    mov al, 0x8F
    call jit_emit_byte
    push eax
    imul eax, eax, 5
    call jit_emit_dword
    pop eax

    ; Consumir la tabla de offsets (num_cases = high - low + 1)
    sub ecx, ebx
    inc ecx                     ; ECX = número de entradas
    shl ecx, 2                  ; ECX = bytes a saltar en esi
    add esi, ecx
    ret

; Opcode 0xAB: lookupswitch (Switch disperso basado en parejas key/offset)
jit_op_lookupswitch:
    mov eax, esi
    sub eax, [jit_bytecode_base]
    and eax, 3
    jz .ls_aligned
    neg eax
    add eax, 4
    add esi, eax                ; Consumir padding

.ls_aligned:
    mov eax, [esi]              ; default_offset
    bswap eax
    add esi, 4
    mov ecx, [esi]              ; npairs (cantidad de parejas)
    bswap ecx
    add esi, 4

    mov al, 0x58                ; pop eax (key buscada)
    call jit_emit_byte

.ls_loop:
    test ecx, ecx
    jz .ls_done

    mov ebx, [esi]              ; match key
    bswap ebx
    add esi, 4
    mov edx, [esi]              ; offset
    bswap edx
    add esi, 4

    mov al, 0x3D                ; cmp eax, match_key
    call jit_emit_byte
    mov eax, ebx
    call jit_emit_dword

    mov al, 0x0F                ; JE target (0x0F 0x84)
    call jit_emit_byte
    mov al, 0x84
    call jit_emit_byte
    push eax
    mov eax, edx
    imul eax, eax, 5
    call jit_emit_dword
    pop eax

    dec ecx
    jmp .ls_loop

.ls_done:
    ret	

; INSTRUCCIONES DE RETORNO Y EXCEPCIONES ADICIONALES (0xAD..0xB0, 0xBF)
jit_op_lreturn:
jit_op_freturn:
jit_op_dreturn:
jit_op_areturn:
    jmp jit_op_ireturn

jit_op_athrow:
    cli
    hlt                         ; Detención limpia por excepción en bare-metal
	
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

; Helper para emitir cálculo de salto
jit_emit_branch_target:
    ; Leer los 2 bytes Big-Endian del offset
    movzx eax, byte [esi]       
    inc esi
    movzx ebx, byte [esi]       
    inc esi
    shl eax, 8
    or eax, ebx
    movsx eax, ax               ; EAX = Offset con signo (16-bit JVM)

    ; Calcular el PC original de esta instrucción de salto
    ; ESI ya avanzó 3 bytes desde el opcode (1 opcode + 2 offset)
    mov ecx, esi
    sub ecx, 3
    sub ecx, [jit_bytecode_base] ; ECX = PC del branch instruction
    
    ; Calcular el PC de destino
    add ecx, eax                ; ECX = Target PC real en bytecode

    cmp eax, 0
    jl .backwards               ; Si es negativo, es un bucle

.forward:
    ; Salto hacia adelante: El código destino aún no existe.
    mov edx, [fixup_count]
    mov ebx, [jit_buffer_ptr]   ; Posición donde se va a emitir el dword
    mov [fixup_addr + edx * 4], ebx
    mov [fixup_target + edx * 4], ecx
    
    inc edx
    mov [fixup_count], edx      ; Actualizar cantidad de fixups
    
    ; Emitir offset nulo temporalmente
    xor eax, eax
    call jit_emit_dword
    ret

.backwards:
    ; Salto hacia atrás: Leer el destino ya compilado desde pc_map
    mov eax, [pc_map + ecx * 4] ; EAX = Dirección nativa x86 del destino
    mov ebx, [jit_buffer_ptr]
    add ebx, 4
    sub eax, ebx                ; EAX = Distancia relativa x86 en complemento a dos
    call jit_emit_dword
    ret

; RUTINAS DE PRUEBA INDIVIDUALES

jit_test_phase1:
    mov eax, 0x00200000
    mov ebx, 65536
    call jit_init
    mov al, 0x90                ; nop
    call jit_emit_byte
    mov al, 0xB8                ; mov eax, 0x12345678
    call jit_emit_byte
    mov eax, 0x12345678
    call jit_emit_dword
    mov al, 0xC3                ; ret
    call jit_emit_byte

    mov eax, [jit_buffer_base]
    call eax                    ; Ejecutar prueba 1
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
    mov esi, test_bytecode_p6
    mov ecx, 17
    call jit_compile_method
    call eax
    ret


; EJECUSIÓN REAL DE MÉTODOS JAVA DESDE 'main'

jit_execute_method:
    push ebp
    mov ebp, esp
    push ebx
    push ecx
    push edx

    ; Si ECX es 0, forzar lectura de hasta 4096 bytes (evita la cancelación jz)
    test ecx, ecx
    jnz .has_len
    mov ecx, 4096
.has_len:

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


; TABLA DE DESPACHO UNIFICADA

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
    dd jit_op_ldc2_w                ; 0x14 - ldc2_w
    dd jit_op_iload                 ; 0x15 - iload
    dd jit_op_lload                 ; 0x16 - lload
    dd jit_op_fload                 ; 0x17 - fload 
    dd jit_op_dload                 ; 0x18 - dload
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
    dd jit_op_dload_1               ; 0x27 - dload_1
    dd jit_op_dload_2               ; 0x28 - dload_2
    dd jit_op_dload_3               ; 0x29 - dload_3
    dd jit_op_aload_0               ; 0x2A - aload_0
    dd jit_op_aload_1               ; 0x2B - aload_1 
    dd jit_op_aload_2               ; 0x2C - aload_2 
    dd jit_op_aload_3               ; 0x2D - aload_3 
    dd jit_op_aload_4               ; 0x2E - aload_4
    dd jit_op_aload_5               ; 0x2F - aload_5
    dd jit_op_iaload                ; 0x30 - iaload
    dd jit_op_laload                ; 0x31 - laload
    dd jit_op_aaload                ; 0x32 - aaload 
    dd jit_op_baload                ; 0x33 - baload
    dd jit_op_caload                ; 0x34 - caload
    dd jit_op_saload                ; 0x35 - saload
    dd jit_op_istore                ; 0x36 - istore
    dd jit_op_lstore                ; 0x37 - lstore
    dd jit_op_fstore                ; 0x38 - fstore
    dd jit_op_dstore                ; 0x39 - dstore
    dd jit_op_astore                ; 0x3A - astore 
    dd jit_op_istore_0              ; 0x3B - istore_0
    dd jit_op_istore_1              ; 0x3C - istore_1
    dd jit_op_istore_2              ; 0x3D - istore_2 
    dd jit_op_istore_3              ; 0x3E - istore_3 
    dd jit_op_lstore_0              ; 0x3F - lstore_0
    dd jit_op_lstore_1              ; 0x40 - lstore_1
    dd jit_op_istore_0              ; 0x41 - fstore_0
    dd jit_op_istore_1              ; 0x42 - fstore_1
    dd jit_op_istore_2              ; 0x43 - fstore_2
    dd jit_op_istore_3              ; 0x44 - fstore_3
    dd jit_op_lstore_0              ; 0x45 - dstore_0
    dd jit_op_lstore_1              ; 0x46 - dstore_1
    dd jit_op_astore_0              ; 0x47 - astore_0 
    dd jit_op_astore_1              ; 0x48 - astore_1 
    dd jit_op_astore_2              ; 0x49 - astore_2 
    dd jit_op_astore_3              ; 0x4A - astore_3 
    dd jit_op_astore_4              ; 0x4B - astore_4
    dd jit_op_astore_5              ; 0x4C - astore_5
    dd jit_op_iastore               ; 0x4D - lastore alias
    dd jit_op_iastore               ; 0x4E - lastore
    dd jit_op_iastore               ; 0x4F - iastore
    dd jit_op_iastore               ; 0x50 - fastore
    dd jit_op_iastore               ; 0x51 - dastore
    dd jit_op_aastore               ; 0x52 - aastore alias
    dd jit_op_aastore               ; 0x53 - aastore 
    dd jit_op_bastore               ; 0x54 - bastore 
    dd jit_op_castore               ; 0x55 - castore 
    dd jit_op_sastore               ; 0x56 - sastore
    dd jit_op_pop                   ; 0x57 - pop 
    dd jit_op_pop                   ; 0x58 - pop2
    dd jit_op_dup                   ; 0x59 - dup
    dd jit_op_dup_x1                ; 0x5A - dup_x1
    dd jit_op_dup_x2                ; 0x5B - dup_x2
    dd jit_op_dup2                  ; 0x5C - dup2
    dd jit_op_dup2_x1               ; 0x5D - dup2_x1
    dd jit_op_dup2_x2               ; 0x5E - dup2_x2
    dd jit_op_swap                  ; 0x5F - swap 
    dd jit_op_iadd                  ; 0x60 - iadd
    dd jit_op_iadd                  ; 0x61 - ladd
    dd jit_op_iadd                  ; 0x62 - fadd
    dd jit_op_iadd                  ; 0x63 - dadd
    dd jit_op_isub                  ; 0x64 - isub 
    dd jit_op_isub                  ; 0x65 - lsub
    dd jit_op_isub                  ; 0x66 - fsub
    dd jit_op_isub                  ; 0x67 - dsub
    dd jit_op_imul                  ; 0x68 - imul 
    dd jit_op_imul                  ; 0x69 - lmul
    dd jit_op_imul                  ; 0x6A - fmul
    dd jit_op_imul                  ; 0x6B - dmul
    dd jit_op_idiv                  ; 0x6C - idiv 
    dd jit_op_idiv                  ; 0x6D - ldiv
    dd jit_op_idiv                  ; 0x6E - fdiv
    dd jit_op_idiv                  ; 0x6F - ddiv
    dd jit_op_irem                  ; 0x70 - irem 
    dd jit_op_irem                  ; 0x71 - lrem
    dd jit_op_irem                  ; 0x72 - frem
    dd jit_op_irem                  ; 0x73 - drem
    dd jit_op_ineg                  ; 0x74 - ineg 
    dd jit_op_lneg                  ; 0x75 - lneg
    dd jit_op_fneg                  ; 0x76 - fneg
    dd jit_op_dneg                  ; 0x77 - dneg
    dd jit_op_ishl                  ; 0x78 - ishl 
    dd jit_op_ishl                  ; 0x79 - lshl
    dd jit_op_ishr                  ; 0x7A - ishr 
    dd jit_op_ishr                  ; 0x7B - lshr
    dd jit_op_iushr                 ; 0x7C - iushr 
    dd jit_op_iushr                 ; 0x7D - lushr
    dd jit_op_iand                  ; 0x7E - iand 
    dd jit_op_iand                  ; 0x7F - land
    dd jit_op_ior                   ; 0x80 - ior  
    dd jit_op_ior                   ; 0x81 - lor
    dd jit_op_ixor                  ; 0x82 - ixor 
    dd jit_op_ixor                  ; 0x83 - lxor
    dd jit_op_iinc                  ; 0x84 - iinc
    dd jit_op_i2l                   ; 0x85 - i2l  
    dd jit_op_i2f                   ; 0x86 - i2f
    dd jit_op_i2d                   ; 0x87 - i2d
    dd jit_op_l2i                   ; 0x88 - l2i 
    dd jit_op_l2f                   ; 0x89 - l2f
    dd jit_op_l2d                   ; 0x8A - l2d
    dd jit_op_f2i                   ; 0x8B - f2i
    dd jit_op_f2l                   ; 0x8C - f2l
    dd jit_op_f2d                   ; 0x8D - f2d
    dd jit_op_d2i                   ; 0x8E - d2i
    dd jit_op_d2l                   ; 0x8F - d2l
    dd jit_op_d2f                   ; 0x90 - d2f
    dd jit_op_i2b                   ; 0x91 - i2b 
    dd jit_op_i2c                   ; 0x92 - i2c 
    dd jit_op_i2s                   ; 0x93 - i2s
    dd jit_op_lcmp                  ; 0x94 - lcmp
    dd jit_op_fcmpl                 ; 0x95 - fcmpl
    dd jit_op_fcmpg                 ; 0x96 - fcmpg
    dd jit_op_dcmpl                 ; 0x97 - dcmpl
    dd jit_op_dcmpg                 ; 0x98 - dcmpg
    dd jit_op_ifeq                  ; 0x99 - ifeq
    dd jit_op_ifne                  ; 0x9A - ifne 
    dd jit_op_iflt                  ; 0x9B - iflt
    dd jit_op_ifge                  ; 0x9C - ifge 
    dd jit_op_ifgt                  ; 0x9D - ifgt
    dd jit_op_ifle                  ; 0x9E - ifle
    dd jit_op_if_icmpeq             ; 0x9F - if_icmpeq
    dd jit_op_if_icmpne             ; 0xA0 - if_icmpne 
    dd jit_op_if_icmplt             ; 0xA1 - if_icmplt 
    dd jit_op_if_icmpge             ; 0xA2 - if_icmpge 
    dd jit_op_if_icmpgt             ; 0xA3 - if_icmpgt 
    dd jit_op_if_icmple             ; 0xA4 - if_icmple 
    dd jit_op_if_acmpeq             ; 0xA5 - if_acmpeq
    dd jit_op_if_acmpne             ; 0xA6 - if_acmpne
    dd jit_op_goto                  ; 0xA7 - goto
    dd jit_op_jsr                   ; 0xA8 - jsr
    dd jit_op_ret                   ; 0xA9 - ret
    dd jit_op_tableswitch           ; 0xAA - tableswitch
    dd jit_op_lookupswitch          ; 0xAB - lookupswitch
    dd jit_op_ireturn               ; 0xAC - ireturn
    dd jit_op_lreturn               ; 0xAD - lreturn
    dd jit_op_freturn               ; 0xAE - freturn
    dd jit_op_dreturn               ; 0xAF - dreturn
    dd jit_op_areturn               ; 0xB0 - areturn
    dd jit_op_return                ; 0xB1 - return
    dd jit_op_getstatic             ; 0xB2 - getstatic
    dd jit_op_putstatic             ; 0xB3 - putstatic
    dd jit_op_getfield              ; 0xB4 - getfield
    dd jit_op_putfield              ; 0xB5 - putfield
    dd jit_op_invokevirtual         ; 0xB6 - invokevIRTUAL
    dd jit_op_invokespecial         ; 0xB7 - invokespecial 
    dd jit_op_invokestatic          ; 0xB8 - invokestatic
    dd jit_op_invokeinterface       ; 0xB9 - invokeinterface
    dd jit_op_invokedynamic         ; 0xBA - invokedynamic
    dd jit_op_new		            ; 0xBB - new
    dd jit_op_newarray              ; 0xBC - newarray
    dd jit_op_anewarray             ; 0xBD - anewarray
    dd jit_op_arraylength           ; 0xBE - arraylength 
    dd jit_op_athrow                ; 0xBF - athrow
    dd jit_op_checkcast             ; 0xC0 - checkcast
    dd jit_op_instanceof            ; 0xC1 - instanceof
    dd jit_op_monitorenter          ; 0xC2 - monitorenter
    dd jit_op_monitorexit           ; 0xC3 - monitorexit
    dd jit_op_wide                  ; 0xC4 - wide
    dd jit_op_multianewarray        ; 0xC5 - multianewarray
    dd jit_op_ifnull                ; 0xC6 - ifnull
    dd jit_op_ifnonnull             ; 0xC7 - ifnonnull
    dd jit_op_goto_w                ; 0xC8 - goto_w
    dd jit_op_jsr_w                 ; 0xC9 - jsr_w
    times 54 dd jit_op_nop          ; 0xCA..0xFF - Reservados e instrucciones extendidas

section .note.GNU-stack noalloc noexec nowrite progbits
