[bits 32]

; SÍMBOLOS GLOBALES
global jvm_invoke_native

; SÍMBOLOS EXTERNOS DE SYS_API.ASM (HAL)
extern sys_kalloc
extern sys_set_color
extern sys_fill_rect
extern sys_draw_rect
extern sys_draw_line
extern sys_draw_string
extern sys_read_keyboard_scancode
extern sys_read_mouse
extern sys_disk_read_sector
extern sys_disk_write_sector
extern sys_inb
extern sys_outb
extern sys_get_time
extern sys_get_pixel
extern sys_set_keyboard_layout
extern sys_exit
extern sys_get_ticks
extern sys_serial_putc
extern sys_serial_puts
extern sys_pci_read_config
extern sys_beep
extern sys_rtl8139_init
extern sys_rtl8139_send_packet
extern sys_net_receive_packet
extern draw_char_vram
extern current_color

; Argumentos globales
extern sys_arg_id
extern sys_arg_a
extern sys_arg_b
extern sys_arg_c
extern sys_arg_d
extern cp_offsets

section .text

; DESPACHADOR UNIVERSAL NATIVO (SLEEP ULTRA-FLUIDO)
jvm_invoke_native:
    push ebp
    mov ebp, esp

    ; Salvaguardar contexto de la CPU
    push ebx
    push ecx
    push edx
    push esi
    push edi

    mov eax, [sys_arg_id]

    cmp eax, 0
    je .call_kalloc
    cmp eax, 1
    je .call_set_color
    cmp eax, 2
    je .call_fill_rect
    cmp eax, 3
    je .call_draw_rect
    cmp eax, 4
    je .call_draw_line
    cmp eax, 5
    je .call_draw_string
    cmp eax, 6
    je .call_read_kbd
    cmp eax, 7
    je .call_read_mouse
    cmp eax, 8
    je .call_disk_read
    cmp eax, 9
    je .call_disk_write
    cmp eax, 10
    je .call_inb
    cmp eax, 11
    je .call_outb
    cmp eax, 12
    je .call_sleep
    cmp eax, 13
    je .call_get_time
    cmp eax, 14
    je .call_get_pixel
    cmp eax, 15
    je .call_draw_char
    cmp eax, 16
    je .call_set_kbd_layout
    cmp eax, 17
    je .call_exit
    cmp eax, 18
    je .call_get_ticks
    cmp eax, 19
    je .call_serial_putc
    cmp eax, 20
    je .call_serial_puts
    cmp eax, 21
    je .call_pci_read
    cmp eax, 22
    je .call_beep
    cmp eax, 23
    je .call_rtl8139_init
    cmp eax, 24
    je .call_rtl8139_send
    cmp eax, 25
    je .call_net_receive

    xor eax, eax
    jmp .native_exit

.call_kalloc:
    push dword [sys_arg_a]
    call sys_kalloc
    add esp, 4
    jmp .native_exit

.call_set_color:
    push dword [sys_arg_a]
    call sys_set_color
    add esp, 4
    xor eax, eax
    jmp .native_exit

.call_fill_rect:
    push dword [sys_arg_d]
    push dword [sys_arg_c]
    push dword [sys_arg_b]
    push dword [sys_arg_a]
    call sys_fill_rect
    add esp, 16
    xor eax, eax
    jmp .native_exit

.call_draw_rect:
    push dword [sys_arg_d]
    push dword [sys_arg_c]
    push dword [sys_arg_b]
    push dword [sys_arg_a]
    call sys_draw_rect
    add esp, 16
    xor eax, eax
    jmp .native_exit

.call_draw_line:
    push dword [sys_arg_d]
    push dword [sys_arg_c]
    push dword [sys_arg_b]
    push dword [sys_arg_a]
    call sys_draw_line
    add esp, 16
    xor eax, eax
    jmp .native_exit

.call_draw_string:
    mov eax, [sys_arg_c]
    cmp eax, 0
    je .str_done

    mov bl, [eax]
    cmp bl, 8                      ; CONSTANT_String_info Tag
    jne .check_utf8
    
    ; Conversión Big-Endian para el índice del CP
    mov ax, [eax + 1]
    xchg al, ah
    movzx eax, ax
    mov eax, [cp_offsets + eax * 4]

.check_utf8:
    mov bl, [eax]
    cmp bl, 1                      ; CONSTANT_Utf8_info Tag
    jne .raw_ptr
    add eax, 3                     ; Omitir Tag (1 byte) + Length (2 bytes)

.raw_ptr:
    push eax                       ; Texto ASCII / Puntero String
    push dword [sys_arg_b]         ; Posición Y
    push dword [sys_arg_a]         ; Posición X
    call sys_draw_string
    add esp, 12

.str_done:
    xor eax, eax
    jmp .native_exit

; --- LECTURA DE TECLADO PS/2 NO BLOQUEANTE ---
.call_read_kbd:
    mov dx, 0x64
    in al, dx
    test al, 0x01
    jz .no_key

    test al, 0x20                  ; Si Bit 5 es 1, son datos provenientes del Mouse
    jnz .no_key

    call sys_read_keyboard_scancode
    jmp .native_exit

.no_key:
    xor eax, eax
    jmp .native_exit

.call_read_mouse:
    push dword [sys_arg_a]
    call sys_read_mouse
    add esp, 4
    jmp .native_exit

.call_disk_read:
    push dword [sys_arg_b]
    push dword [sys_arg_a]
    call sys_disk_read_sector
    add esp, 8
    jmp .native_exit

.call_disk_write:
    push dword [sys_arg_b]
    push dword [sys_arg_a]
    call sys_disk_write_sector
    add esp, 8
    jmp .native_exit

.call_inb:
    push dword [sys_arg_a]
    call sys_inb
    add esp, 4
    jmp .native_exit

.call_outb:
    push dword [sys_arg_b]
    push dword [sys_arg_a]
    call sys_outb
    add esp, 8
    xor eax, eax
    jmp .native_exit

; --- RETARDO CALIBRADO ---
.call_sleep:
    mov ecx, [sys_arg_a]
    cmp ecx, 0
    jle .sleep_done
    shl ecx, 12
.sleep_loop:
    dec ecx
    jnz .sleep_loop
.sleep_done:
    xor eax, eax
    jmp .native_exit

.call_get_time:
    push dword [sys_arg_a]
    call sys_get_time
    add esp, 4
    jmp .native_exit

.call_get_pixel:
    push dword [sys_arg_b]
    push dword [sys_arg_a]
    call sys_get_pixel
    add esp, 8
    jmp .native_exit

.call_draw_char:
    mov eax, [current_color]
    or eax, 0xFF000000

    push eax                       ; Color (Alpha de opacidad)
    push dword [sys_arg_c]         ; Carácter
    push dword [sys_arg_b]         ; Y
    push dword [sys_arg_a]         ; X
    call draw_char_vram
    add esp, 16
    xor eax, eax
    jmp .native_exit

.call_set_kbd_layout:
    push dword [sys_arg_a]
    call sys_set_keyboard_layout
    add esp, 4
    xor eax, eax
    jmp .native_exit

.call_exit:
    call sys_exit
    jmp .native_exit

.call_get_ticks:
    call sys_get_ticks
    jmp .native_exit

.call_serial_putc:
    push dword [sys_arg_a]
    call sys_serial_putc
    add esp, 4
    xor eax, eax
    jmp .native_exit

.call_serial_puts:
    mov eax, [sys_arg_a]
    cmp eax, 0
    je .ser_puts_done
    push eax
    call sys_serial_puts
    add esp, 4
.ser_puts_done:
    xor eax, eax
    jmp .native_exit

.call_pci_read:
    push dword [sys_arg_d]
    push dword [sys_arg_c]
    push dword [sys_arg_b]
    push dword [sys_arg_a]
    call sys_pci_read_config
    add esp, 16
    jmp .native_exit

.call_beep:
    push dword [sys_arg_a]
    call sys_beep
    add esp, 4
    xor eax, eax
    jmp .native_exit

.call_rtl8139_init:
    push dword [sys_arg_a]
    call sys_rtl8139_init
    add esp, 4
    xor eax, eax
    jmp .native_exit

.call_rtl8139_send:
    push dword [sys_arg_b]
    push dword [sys_arg_a]
    call sys_rtl8139_send_packet
    add esp, 8
    xor eax, eax
    jmp .native_exit

.call_net_receive:
    call sys_net_receive_packet
    jmp .native_exit

.native_exit:
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    mov esp, ebp
    pop ebp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
