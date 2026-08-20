[bits 32]

global bootjvm_start


; ESTADO Y VARIABLES GLOBALES DE LA VM

global operand_stack
global stack_ptr
global local_vars
global cp_offsets
global cp_end_ptr                   ; <-- Variable expuesta para find_method_bytecode
global current_class_ptr
global pc_ptr
global frame_ptr
global frame_stack

global sys_arg_id
global sys_arg_a
global sys_arg_b
global sys_arg_c
global sys_arg_d
global tmp_opcode
global tmp_base
global tmp_offset

global parse_constant_pool
global find_main_method


; INVOCACIONES EXTERNAS

extern g_boot_class_start
extern sys_hardware_init
extern sys_kalloc
extern sys_hlt
extern sys_serial_puts
extern jvm_dispatch_loop
extern find_method_bytecode

section .text


; PUNTO DE ENTRADA PRINCIPAL DE BOOTJVM

bootjvm_start:
    ; 1. Inicialización centralizada de Hardware e Interrupciones (HAL)
    call sys_hardware_init

    push msg_dbg_start
    call sys_serial_puts
    add esp, 4

    ; 2. Inicializar puntero de la clase principal
    mov esi, g_boot_class_start
    mov [current_class_ptr], esi

    ; 3. Validar Magic Number (0xCAFEBABE)
    mov eax, [esi]
    bswap eax
    cmp eax, 0xCAFEBABE
    jne fatal_magic_error

    push msg_dbg_magic_ok
    call sys_serial_puts
    add esp, 4

    ; 4. Inicializar Estado Virtual de la JVM
    mov dword [stack_ptr], 0
    mov dword [frame_ptr], 0

    ; Crear array vacío para String[] args
    push dword 8
    call sys_kalloc
    add esp, 4
    mov dword [eax], 0              ; length = 0
    mov dword [eax + 4], 0          ; atype = 0 (objeto)
    add eax, 8                      ; Puntero al área de datos del arreglo
    
    ; Asignar el array de argumentos a la Variable Local 0 de main()
    mov [local_vars + 0], eax

    ; 5. Parsear Constant Pool de la clase cargada
    call parse_constant_pool
    jc fatal_class_format_error

    push msg_dbg_cp_ok
    call sys_serial_puts
    add esp, 4

    ; 6. Buscar el método de entrada "main"
    call find_main_method
    jc fatal_main_not_found
	; 7. Cargar el Puntero de Programa (PC Virtual)
    mov [pc_ptr], eax
    push msg_dbg_main_ok
    call sys_serial_puts
    add esp, 4   

    ; 8. Delegar la ejecución al ciclo de despacho principal
    jmp jvm_dispatch_loop


; SUBRUTINA DE PARSING DEL CONSTANT POOL

parse_constant_pool:
    mov esi, [current_class_ptr]
    add esi, 8                      ; Omitir Magic (4B) y Versión (4B)

    mov ax, [esi]
    xchg al, ah
    movzx ecx, ax                   ; ECX = Constant Pool Count
    dec ecx
    add esi, 2

    mov ebx, 1                      ; CP Index arranca en #1
.cp_loop:
    cmp ecx, 0
    jle .cp_done

    mov [cp_offsets + ebx * 4], esi ; Guardar offset físico de la entrada #ebx

    mov al, [esi]
    inc esi
    cmp al, 1                       ; Tag UTF-8
    je .tag_utf8
    cmp al, 5                       ; Tag Long
    je .tag_8b
    cmp al, 6                       ; Tag Double
    je .tag_8b
    cmp al, 15                      ; MethodHandle
    je .tag_3b
    cmp al, 7                       ; Class
    je .tag_2b
    cmp al, 8                       ; String
    je .tag_2b
    cmp al, 16                      ; MethodType
    je .tag_2b
    
    add esi, 4                      ; Integer, Float, Fieldref, Methodref, NameAndType (4 bytes)
    jmp .next_entry

.tag_utf8:
    mov ax, [esi]
    xchg al, ah
    movzx eax, ax
    add esi, 2
    add esi, eax
    jmp .next_entry

.tag_2b:
    add esi, 2
    jmp .next_entry

.tag_3b:
    add esi, 3
    jmp .next_entry

.tag_8b:
    add esi, 8
    inc ebx                         ; Long y Double ocupan 2 slots en CP
    dec ecx

.next_entry:
    inc ebx
    dec ecx
    jmp .cp_loop

.cp_done:
    mov [cp_end_ptr], esi           ; Guardar el fin exacto de la Constant Pool
    clc
    ret


; SUBRUTINA DE BÚSQUEDA DEL MÉTODO MAIN

find_main_method:
    push edx
    push ecx
    push ebx

    push dword main_name_str
    push dword 4                    ; Longitud de "main"
    call find_method_bytecode
    add esp, 8

    cmp eax, 0
    je .main_not_found_err

    ; Preservar EAX (dirección del bytecode) en la pila mientras restauramos registros
    push eax                        
    pop eax                         ; Restaurar EAX
    pop ebx
    pop ecx
    pop edx
    clc
    ret

.main_not_found_err:
    pop ebx
    pop ecx
    pop edx
    stc
    ret


; MANEJADORES DE ERRORES CRÍTICOS GLOBALES

fatal_magic_error:
    push msg_err_magic
    call sys_serial_puts
    add esp, 4
    jmp fatal_halt

fatal_class_format_error:
    push msg_err_format
    call sys_serial_puts
    add esp, 4
    jmp fatal_halt

fatal_main_not_found:
    push msg_err_nomain
    call sys_serial_puts
    add esp, 4
    jmp fatal_halt

fatal_halt:
    mov dword [0x000B8000], 0x4F214F45 ; 'EO!' en VGA buffer
    cli
.loop:
    call sys_hlt
    jmp .loop

section .rodata
main_name_str:         db "main"
msg_dbg_start:         db 13, 10, "[BootJVM] Booting JVM Kernel...", 13, 10, 0
msg_dbg_magic_ok:      db "[BootJVM] Magic CAFEBABE Verified!", 13, 10, 0
msg_dbg_cp_ok:         db "[BootJVM] Constant Pool Parsed Successfully!", 13, 10, 0
msg_dbg_main_ok:       db "[BootJVM] Method 'main' found! Jumping to interpreter...", 13, 10, 0

msg_err_magic:         db 13, 10, "[BootJVM Panic] ClassFormatError: Bad Magic!", 13, 10, 0
msg_err_format:        db 13, 10, "[BootJVM Panic] ClassFormatError: Corrupted CP!", 13, 10, 0
msg_err_nomain:        db 13, 10, "[BootJVM Panic] NoSuchMethodError: main not found!", 13, 10, 0

section .data
sys_arg_id:        dd 0
sys_arg_a:         dd 0
sys_arg_b:         dd 0
sys_arg_c:         dd 0
sys_arg_d:         dd 0

tmp_opcode:        db 0
tmp_base:          dd 0
tmp_offset:        dd 0

current_class_ptr: dd 0
cp_end_ptr:        dd 0
pc_ptr:            dd 0
frame_ptr:         dd 0

section .bss
stack_ptr:         resd 1
operand_stack:     resd 1024
local_vars:        resd 256
cp_offsets:        resd 1024
frame_stack:       resd 512

section .note.GNU-stack noalloc noexec nowrite progbits