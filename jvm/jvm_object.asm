[bits 32]

; SÍMBOLOS GLOBALES EXPORTADOS
global op_getstatic
global op_putstatic
global op_getfield
global op_putfield
global op_new
global op_athrow
global op_checkcast
global op_instanceof
global op_monitorenter
global op_monitorexit

; SÍMBOLOS EXTERNOS
extern vm_push
extern vm_pop
extern cp_offsets
extern pc_ptr
extern sys_kalloc
extern check_null_pointer
extern sys_serial_puts
extern sys_hlt
extern jvm_dispatch_next

section .bss
align 16
; Tabla global de campos estáticos
static_fields_table: resd 1024

section .text

; Helper para sincronizar ESI con pc_ptr
%macro SYNC_PC 0
    mov [pc_ptr], esi
%endmacro

; MANEJO DE CAMPOS ESTÁTICOS

; --- getstatic (0xB2) ---
; Operandos: indexbyte1, indexbyte2
op_getstatic:
    mov ax, [esi]
    xchg al, ah                     ; Big-endian a Little-endian
    movzx eax, ax
    add esi, 2
    SYNC_PC

    ; Leer el valor estático de la tabla por su índice
    mov eax, [static_fields_table + eax * 4]
    call vm_push
    jmp jvm_dispatch_next

; --- putstatic (0xB3) ---
; Operandos: indexbyte1, indexbyte2
op_putstatic:
    mov ax, [esi]
    xchg al, ah
    movzx ebx, ax                   ; Index CP del Fieldref
    add esi, 2
    SYNC_PC

    call vm_pop                     ; EAX = Valor
    mov [static_fields_table + ebx * 4], eax
    jmp jvm_dispatch_next

; MANEJO DE CAMPOS DE INSTANCIA

; --- getfield (0xB4) ---
; Operandos: indexbyte1, indexbyte2
op_getfield:
    mov ax, [esi]
    xchg al, ah
    movzx ebx, ax                   ; Field index
    add esi, 2
    SYNC_PC

    call vm_pop                     ; EAX = objectref
    call check_null_pointer

    ; Leer el campo en el offset especificado por el índice del campo
    mov eax, [eax + ebx * 4]
    call vm_push
    jmp jvm_dispatch_next

; --- putfield (0xB5) ---
; Operandos: indexbyte1, indexbyte2
op_putfield:
    mov ax, [esi]
    xchg al, ah
    movzx ebx, ax                   ; Field index
    add esi, 2
    SYNC_PC

    call vm_pop                     ; EDX = val
    mov edx, eax
    call vm_pop                     ; EAX = objectref
    call check_null_pointer

    mov [eax + ebx * 4], edx
    jmp jvm_dispatch_next

; CREACIÓN Y VERIFICACIÓN DE OBJETOS

; --- new (0xBB) ---
; Operandos: indexbyte1, indexbyte2 (índice de clase en CP)
op_new:
    mov ax, [esi]
    xchg al, ah
    movzx ebx, ax                   ; Index CP de la clase
    add esi, 2
    SYNC_PC

    ; Reservar bloque en el Heap para el objeto (64 bytes por defecto)
    push dword 64
    call sys_kalloc
    add esp, 4

    ; Guardar el CP Class Index en la cabecera del objeto (Offset 0)
    mov [eax], ebx

    call vm_push                    ; Poner objectref en Operand Stack
    jmp jvm_dispatch_next

; --- checkcast (0xC0) ---
; Operandos: indexbyte1, indexbyte2
op_checkcast:
    mov ax, [esi]
    xchg al, ah
    movzx ebx, ax                   ; Index CP
    add esi, 2
    SYNC_PC

    ; checkcast examina la referencia sin eliminarla permanentemente si es válida.
    call vm_pop
    call vm_push                    ; Mantiene el objeto en la pila
    jmp jvm_dispatch_next

; --- instanceof (0xC1) ---
; Operandos: indexbyte1, indexbyte2
op_instanceof:
    mov ax, [esi]
    xchg al, ah
    movzx ebx, ax                   ; Index CP
    add esi, 2
    SYNC_PC

    call vm_pop                     ; EAX = objectref
    cmp eax, 0
    je .is_false

    ; Si la referencia no es nula, por ahora asumimos cast compatible (1)
    mov eax, 1
    call vm_push
    jmp jvm_dispatch_next

.is_false:
    mov eax, 0
    call vm_push
    jmp jvm_dispatch_next

; EXCEPCIONES Y CONCURRENCIA

; --- athrow (0xBF) ---
op_athrow:
    call vm_pop                     ; EAX = Throwable objectref
    call check_null_pointer
    jmp fatal_athrow_unhandled

; --- monitorenter (0xC2) ---
op_monitorenter:
    call vm_pop                     ; EAX = objectref
    call check_null_pointer
    ; NOP en entorno bare-metal uniprocesador sin hilos Java concurrentes
    jmp jvm_dispatch_next

; --- monitorexit (0xC3) ---
op_monitorexit:
    call vm_pop                     ; EAX = objectref
    call check_null_pointer
    jmp jvm_dispatch_next

; MANEJADORES DE ERRORES DE OBJETOS
fatal_athrow_unhandled:
    push msg_err_athrow
    call sys_serial_puts
    add esp, 4
    jmp fatal_halt_obj

fatal_halt_obj:
    mov dword [0x000B8000], 0x4F214F45
.loop:
    call sys_hlt
    jmp .loop

section .rodata
msg_err_athrow: db 13, 10, "[BootJVM Panic] Unhandled Exception Thrown (athrow)!", 13, 10, 0

section .note.GNU-stack noalloc noexec nowrite progbits
