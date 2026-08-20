[bits 32]

; SÍMBOLOS GLOBALES EXPORTADOS
global op_invokevirtual
global op_invokespecial
global op_invokestatic
global op_invokeinterface
global op_invokedynamic

global call_frame_stack
global call_frame_ptr
global find_method_bytecode

; SÍMBOLOS EXTERNOS
extern vm_push
extern vm_pop
extern cp_offsets
extern cp_end_ptr
extern pc_ptr
extern sys_arg_id
extern sys_arg_a
extern sys_arg_b
extern sys_arg_c
extern sys_arg_d
extern jvm_invoke_native
extern g_boot_class_start
extern frame_ptr
extern jvm_dispatch_next

; Símbolos de renderizado VRAM
extern current_color
extern draw_char_vram

section .bss
align 16
call_frame_stack: resd 512        ; Guarda Pares [Caller_PC, Caller_Frame_Ptr]
call_frame_ptr:   resd 1

section .text

; ENTRADAS DE OPCODES DE INVOCACIÓN

op_invokevirtual:
    jmp dispatch_invoke

op_invokespecial:
    jmp dispatch_invoke

op_invokestatic:
    jmp dispatch_invoke

op_invokeinterface:
    mov ax, [esi]
    xchg al, ah
    movzx eax, ax
    add esi, 4                      ; Skip 2 bytes index + 2 bytes padding/count
    jmp dispatch_invoke

op_invokedynamic:
    mov ax, [esi]
    xchg al, ah
    movzx eax, ax
    add esi, 4
    jmp dispatch_invoke

; DESPACHADOR CENTRAL DE INVOCACIONES
dispatch_invoke:
    mov ax, [esi]                   ; Index CP
    xchg al, ah
    movzx eax, ax
    add esi, 2                      ; Retorno PC + 2
    mov [pc_ptr], esi

    mov ebx, [cp_offsets + eax * 4]
    cmp ebx, 0
    je .done_invoke

    inc ebx                         ; Skip tag
    mov ax, [ebx + 2]               ; Index NameAndType
    xchg al, ah
    movzx eax, ax
    mov ebx, [cp_offsets + eax * 4]
    cmp ebx, 0
    je .done_invoke

    inc ebx                         ; Skip tag NameAndType
    mov ax, [ebx]                   ; Name index (Utf8)
    xchg al, ah
    movzx eax, ax
    mov ebx, [cp_offsets + eax * 4]
    cmp ebx, 0
    je .done_invoke

    mov edx, ebx
    inc ebx                         ; Skip Tag
    add ebx, 2                      ; Skip Length -> Texto UTF-8 ASCII

    ; Constructor Object <init>
    mov eax, [ebx]
    cmp eax, 0x696E693C             ; "<ini"
    je .done_invoke

    ; Verificar si es la Syscall Nativa "sys"
    and eax, 0x00FFFFFF             ; 's' 'y' 's'
    cmp eax, 0x00737973
    je .is_native_sys

    ; INVOCACIÓN DE MÉTODO JAVA REAL EN LA MISMA CLASE
    inc edx                         ; Skip Tag
    mov ax, [edx]                   ; Length
    xchg al, ah
    movzx ecx, ax                   ; ECX = Longitud
    add edx, 2                      ; EDX = Cadena ASCII

    push edx
    push ecx
    call find_method_bytecode
    add esp, 8

    cmp eax, 0
    je .done_invoke

    ; Guardar contexto del método llamador
    mov ecx, [call_frame_ptr]
    cmp ecx, 250
    jge .done_invoke

    mov [call_frame_stack + ecx * 8], esi         ; PC actual del llamador
    mov edx, [frame_ptr]
    mov [call_frame_stack + ecx * 8 + 4], edx     ; Frame Pointer actual
    inc dword [call_frame_ptr]

    add dword [frame_ptr], 16                     ; Reservar espacio para variables locales
    mov esi, eax                                  ; Asignar nuevo PC
    mov [pc_ptr], esi
    jmp jvm_dispatch_next

.is_native_sys:
    call vm_pop
    mov [sys_arg_d], eax
    call vm_pop
    mov [sys_arg_c], eax
    call vm_pop
    mov [sys_arg_b], eax
    call vm_pop
    mov [sys_arg_a], eax
    call vm_pop
    mov [sys_arg_id], eax

    ; TRATAMIENTO ESPECIAL PARA SYS_DRAW_CHAR (ID 15)
    mov ebx, [sys_arg_id]
    cmp ebx, 15
    je .native_draw_char

    call jvm_invoke_native

    ; Todos los Native.sys() devuelven un int -> vm_push(eax)
    call vm_push
    jmp jvm_dispatch_next

.native_draw_char:
    mov eax, [current_color]
    or eax, 0xFF000000          ; Forzar opacidad total

    push eax                    ; color
    push dword [sys_arg_b]      ; y
    push dword [sys_arg_a]      ; x
    push dword [sys_arg_c]      ; asciiChar

    call draw_char_vram
    add esp, 16

    mov eax, 0
    call vm_push
    jmp jvm_dispatch_next

.done_invoke:
    jmp jvm_dispatch_next

; PARSER DEL .CLASS PARA ENCONTRAR MÉTODOS

find_method_bytecode:
    push ebp
    mov ebp, esp
    push ebx
    push ecx
    push edx
    push esi
    push edi

    mov esi, [cp_end_ptr]
    add esi, 6                  ; access_flags + this_class + super_class

    ; --- Skip Interfaces ---
    mov ax, [esi]
    xchg al, ah
    movzx eax, ax
    add esi, 2
    shl eax, 1
    add esi, eax

    ; --- Skip Fields ---
    mov ax, [esi]
    xchg al, ah
    movzx ecx, ax
    add esi, 2
.skip_fields_loop:
    cmp ecx, 0
    jle .fields_done
    add esi, 6                  ; access + name + descriptor
    mov ax, [esi]               ; attributes_count
    xchg al, ah
    movzx eax, ax
    add esi, 2
.skip_f_attrs:
    cmp eax, 0
    je .next_field
    add esi, 2
    mov ebx, [esi]
    bswap ebx
    add esi, 4
    add esi, ebx
    dec eax
    jmp .skip_f_attrs
.next_field:
    dec ecx
    jmp .skip_fields_loop
.fields_done:

    ; --- Methods ---
    mov ax, [esi]
    xchg al, ah
    movzx ecx, ax               ; methods_count
    add esi, 2

.search_methods_loop:
    cmp ecx, 0
    jle .method_not_found

    ; Guardar inicio del método
    mov edi, esi

    add esi, 2                  ; skip access_flags
    mov ax, [esi]               ; name_index
    xchg al, ah
    movzx eax, ax
    add esi, 4                  ; skip name + descriptor

    ; Obtener el nombre real del método desde el Constant Pool
    mov ebx, [cp_offsets + eax * 4]
    cmp ebx, 0
    je .skip_this_method
    inc ebx                     ; skip tag
    mov ax, [ebx]               ; length
    xchg al, ah
    movzx edx, ax               ; EDX = longitud del nombre en el class
    add ebx, 2                  ; EBX = texto UTF-8

    ; Comparar con el nombre buscado
    mov eax, [ebp + 8]          ; longitud buscada
    cmp eax, edx
    jne .skip_this_method

    ; Comparación byte a byte
    push esi
    push edi
    mov esi, [ebp + 12]          ; nombre buscado
    mov edi, ebx                 ; nombre en el class
    mov ecx, edx
    repe cmpsb
    pop edi
    pop esi
    jne .skip_this_method

    ; === Nombre coincide → buscar atributo "Code" ===
    mov ax, [esi]               ; attributes_count
    xchg al, ah
    movzx edx, ax
    add esi, 2

.search_code:
    cmp edx, 0
    je .skip_this_method

    mov ax, [esi]               ; attribute_name_index
    xchg al, ah
    movzx eax, ax

    mov ebx, [cp_offsets + eax * 4]
    add ebx, 3                  ; skip tag + length
    mov eax, [ebx]
    cmp eax, 0x65646F43         ; "Code"
    je .found_code

    ; Saltar atributo
    add esi, 2
    mov eax, [esi]
    bswap eax
    add esi, 4
    add esi, eax
    dec edx
    jmp .search_code

.found_code:
    add esi, 14                 ; apunta al primer bytecode
    mov eax, esi
    jmp .find_done

.skip_this_method:
    ; Saltar todos los atributos de este método
    mov esi, edi
    add esi, 6                  ; access + name + descriptor
    mov ax, [esi]
    xchg al, ah
    movzx edx, ax
    add esi, 2
.skip_attrs:
    cmp edx, 0
    je .next_method
    add esi, 2
    mov eax, [esi]
    bswap eax
    add esi, 4
    add esi, eax
    dec edx
    jmp .skip_attrs
.next_method:
    dec ecx
    jmp .search_methods_loop

.method_not_found:
    xor eax, eax

.find_done:
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    pop ebp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
