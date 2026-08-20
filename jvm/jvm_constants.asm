[bits 32]


; SÍMBOLOS GLOBALES (OPCODES DE CONSTANTES Y CARGAS)

global op_nop
global op_aconst_null
global op_iconst_m1
global op_iconst_0
global op_iconst_1
global op_iconst_2
global op_iconst_3
global op_iconst_4
global op_iconst_5
global op_lconst_0
global op_lconst_1
global op_fconst_0
global op_fconst_1
global op_fconst_2
global op_dconst_0
global op_dconst_1
global op_bipush
global op_sipush
global op_ldc
global op_ldc_w
global op_ldc2_w

global push_cp_value


; SÍMBOLOS EXTERNOS

extern vm_push
extern cp_offsets
extern pc_ptr
extern sys_serial_puts
extern sys_hlt
extern jvm_dispatch_next

; Excepciones globales desde jvm_exception.asm
extern fatal_cp_type_error
extern fatal_cp_index_error

section .text


; OPCODES DE CONSTANTES (0x00 - 0x0F)


; --- nop (0x00) ---
op_nop:
    jmp jvm_dispatch_next

; --- aconst_null (0x01) ---
op_aconst_null:
    mov eax, 0
    call vm_push
    jmp jvm_dispatch_next

; --- iconst_m1 (0x02) ---
op_iconst_m1:
    mov eax, -1
    call vm_push
    jmp jvm_dispatch_next

; --- iconst_0 (0x03) ---
op_iconst_0:
    mov eax, 0
    call vm_push
    jmp jvm_dispatch_next

; --- iconst_1 (0x04) ---
op_iconst_1:
    mov eax, 1
    call vm_push
    jmp jvm_dispatch_next

; --- iconst_2 (0x05) ---
op_iconst_2:
    mov eax, 2
    call vm_push
    jmp jvm_dispatch_next

; --- iconst_3 (0x06) ---
op_iconst_3:
    mov eax, 3
    call vm_push
    jmp jvm_dispatch_next

; --- iconst_4 (0x07) ---
op_iconst_4:
    mov eax, 4
    call vm_push
    jmp jvm_dispatch_next

; --- iconst_5 (0x08) ---
op_iconst_5:
    mov eax, 5
    call vm_push
    jmp jvm_dispatch_next

; --- lconst_0 (0x09) ---
op_lconst_0:
    mov eax, 0                      ; High dword
    call vm_push
    mov eax, 0                      ; Low dword
    call vm_push
    jmp jvm_dispatch_next

; --- lconst_1 (0x0A) ---
op_lconst_1:
    mov eax, 0                      ; High dword
    call vm_push
    mov eax, 1                      ; Low dword
    call vm_push
    jmp jvm_dispatch_next

; --- fconst_0 (0x0B) ---
op_fconst_0:
    mov eax, 0x00000000             ; IEEE 754 0.0f
    call vm_push
    jmp jvm_dispatch_next

; --- fconst_1 (0x0C) ---
op_fconst_1:
    mov eax, 0x3F800000             ; IEEE 754 1.0f
    call vm_push
    jmp jvm_dispatch_next

; --- fconst_2 (0x0D) ---
op_fconst_2:
    mov eax, 0x40000000             ; IEEE 754 2.0f
    call vm_push
    jmp jvm_dispatch_next

; --- dconst_0 (0x0E) ---
op_dconst_0:
    mov eax, 0x00000000             ; High (IEEE 754 0.0d)
    call vm_push
    mov eax, 0x00000000             ; Low
    call vm_push
    jmp jvm_dispatch_next

; --- dconst_1 (0x0F) ---
op_dconst_1:
    mov eax, 0x3FF00000             ; High (IEEE 754 1.0d)
    call vm_push
    mov eax, 0x00000000             ; Low
    call vm_push
    jmp jvm_dispatch_next


; OPCODES DE CARGA INMEDIATA (0x10 - 0x11)


; --- bipush (0x10) ---
op_bipush:
    movsx eax, byte [esi]
    inc esi                         ; Avanzar PC 1 byte
    mov [pc_ptr], esi
    call vm_push
    jmp jvm_dispatch_next

; --- sipush (0x11) ---
op_sipush:
    movzx eax, byte [esi]
    shl eax, 8
    mov al, byte [esi + 1]
    movsx eax, ax                   ; Extender signo de 16-bit a 32-bit
    add esi, 2                      ; Avanzar PC 2 bytes
    mov [pc_ptr], esi
    call vm_push
    jmp jvm_dispatch_next


; OPCODES DE CONSTANT POOL (0x12 - 0x14)


; --- ldc (0x12) ---
op_ldc:
    movzx eax, byte [esi]
    inc esi                         ; Avanzar PC 1 byte
    mov [pc_ptr], esi
    call push_cp_value
    jmp jvm_dispatch_next

; --- ldc_w (0x13) ---
op_ldc_w:
    mov ax, [esi]
    xchg al, ah                     ; Big-Endian a Little-Endian
    movzx eax, ax
    add esi, 2                      ; Avanzar PC 2 bytes
    mov [pc_ptr], esi
    call push_cp_value
    jmp jvm_dispatch_next

; --- ldc2_w (0x14) ---
op_ldc2_w:
    mov ax, [esi]
    xchg al, ah
    movzx eax, ax
    add esi, 2                      ; Avanzar PC 2 bytes
    mov [pc_ptr], esi

    mov ebx, [cp_offsets + eax * 4]
    cmp ebx, 0
    je fatal_cp_index_error

    mov cl, [ebx]                   ; Leer Tag del CP
    cmp cl, 5                       ; CONSTANT_Long
    je .read_64bit
    cmp cl, 6                       ; CONSTANT_Double
    je .read_64bit

    jmp fatal_cp_type_error

.read_64bit:
    inc ebx                         ; Saltar Tag
    mov eax, [ebx]
    bswap eax                       ; High 32-bit
    call vm_push

    mov eax, [ebx + 4]
    bswap eax                       ; Low 32-bit
    call vm_push
    jmp jvm_dispatch_next


; RESOLUCIÓN INTERNA DE VALORES DEL CONSTANT POOL


push_cp_value:
    mov ebx, [cp_offsets + eax * 4]
    cmp ebx, 0
    je fatal_cp_index_error

    mov cl, [ebx]                   ; Leer Tag
    inc ebx                         ; Apuntar a los datos de la constante

    cmp cl, 3                       ; CONSTANT_Integer
    je .read_32bit
    cmp cl, 4                       ; CONSTANT_Float
    je .read_32bit
    cmp cl, 8                       ; CONSTANT_String
    je .read_string
    cmp cl, 7                       ; CONSTANT_Class
    je .read_32bit

    jmp fatal_cp_type_error

.read_32bit:
    mov eax, [ebx]
    bswap eax                       ; Big-Endian a Little-Endian x86
    call vm_push
    ret

.read_string:
    mov ax, [ebx]
    xchg al, ah
    movzx eax, ax

    mov ebx, [cp_offsets + eax * 4]
    cmp ebx, 0
    je fatal_cp_index_error

    inc ebx                         ; Skip Tag Utf8 (1 byte)
    add ebx, 2                      ; Skip Length (2 bytes) -> Apunta directo al texto ASCII

    mov eax, ebx
    call vm_push
    ret

section .note.GNU-stack noalloc noexec nowrite progbits