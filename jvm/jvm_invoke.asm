[bits 32]

global op_invokevirtual
global op_invokespecial
global op_invokestatic
global op_invokeinterface
global op_invokedynamic

global call_frame_stack
global call_frame_ptr
global find_method_bytecode

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
extern stack_ptr
extern local_vars
extern jvm_dispatch_next

extern current_color
extern draw_char_vram

section .bss
align 16
call_frame_stack: resd 512
call_frame_ptr:   resd 1

section .text

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
    add esi, 4
    jmp dispatch_invoke

op_invokedynamic:
    mov ax, [esi]
    xchg al, ah
    movzx eax, ax
    add esi, 4
    jmp dispatch_invoke

dispatch_invoke:
    mov ax, [esi]
    xchg al, ah
    movzx eax, ax
    add esi, 2
    mov [pc_ptr], esi

    mov ebx, [cp_offsets + eax * 4]
    cmp ebx, 0
    je .done_invoke

    inc ebx
    mov ax, [ebx + 2]
    xchg al, ah
    movzx eax, ax
    mov ebx, [cp_offsets + eax * 4]
    cmp ebx, 0
    je .done_invoke

    inc ebx
    mov ax, [ebx]
    xchg al, ah
    movzx eax, ax
    mov ebx, [cp_offsets + eax * 4]
    cmp ebx, 0
    je .done_invoke

    mov edx, ebx
    inc ebx
    add ebx, 2

    mov eax, [ebx]
    cmp eax, 0x696E693C
    je .done_invoke

    and eax, 0x00FFFFFF
    cmp eax, 0x00737973
    je .is_native_sys

    inc edx
    mov ax, [edx]
    xchg al, ah
    movzx ecx, ax
    add edx, 2

    push edx
    push ecx
    call find_method_bytecode
    add esp, 8

    cmp eax, 0
    je .done_invoke

    mov edi, eax

    mov ecx, [call_frame_ptr]
    cmp ecx, 250
    jge .done_invoke

    mov [call_frame_stack + ecx * 8], esi
    mov edx, [frame_ptr]
    mov [call_frame_stack + ecx * 8 + 4], edx
    inc dword [call_frame_ptr]

    mov ebx, [frame_ptr]
    add ebx, 16

    mov ecx, [stack_ptr]
    cmp ecx, 0
    je .no_args

    call vm_pop
    mov [local_vars + ebx * 4 + 0], eax

    mov ecx, [stack_ptr]
    cmp ecx, 0
    je .no_args

    mov edx, [local_vars + ebx * 4 + 0]
    call vm_pop
    mov [local_vars + ebx * 4 + 0], eax
    mov [local_vars + ebx * 4 + 4], edx

.no_args:
    add dword [frame_ptr], 16
    mov esi, edi
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

    mov ebx, [sys_arg_id]
    cmp ebx, 15
    je .native_draw_char

    call jvm_invoke_native

    call vm_push
    jmp jvm_dispatch_next

.native_draw_char:
    mov eax, [current_color]
    or eax, 0xFF000000

    push eax
    push dword [sys_arg_b]
    push dword [sys_arg_a]
    push dword [sys_arg_c]

    call draw_char_vram
    add esp, 16

    mov eax, 0
    call vm_push
    jmp jvm_dispatch_next

.done_invoke:
    jmp jvm_dispatch_next

find_method_bytecode:
    push ebp
    mov ebp, esp
    push ebx
    push ecx
    push edx
    push esi
    push edi

    mov esi, [cp_end_ptr]
    add esi, 6

    mov ax, [esi]
    xchg al, ah
    movzx eax, ax
    add esi, 2
    shl eax, 1
    add esi, eax

    mov ax, [esi]
    xchg al, ah
    movzx ecx, ax
    add esi, 2
.skip_fields_loop:
    cmp ecx, 0
    jle .fields_done
    add esi, 6
    mov ax, [esi]
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

    mov ax, [esi]
    xchg al, ah
    movzx ecx, ax
    add esi, 2

.search_methods_loop:
    cmp ecx, 0
    jle .method_not_found

    mov edi, esi

    add esi, 2
    mov ax, [esi]
    xchg al, ah
    movzx eax, ax
    add esi, 4

    mov ebx, [cp_offsets + eax * 4]
    cmp ebx, 0
    je .skip_this_method
    inc ebx
    mov ax, [ebx]
    xchg al, ah
    movzx edx, ax
    add ebx, 2

    mov eax, [ebp + 8]
    cmp eax, edx
    jne .skip_this_method

    push esi
    push edi
    mov esi, [ebp + 12]
    mov edi, ebx
    mov ecx, edx
    repe cmpsb
    pop edi
    pop esi
    jne .skip_this_method

    mov ax, [esi]
    xchg al, ah
    movzx edx, ax
    add esi, 2

.search_code:
    cmp edx, 0
    je .skip_this_method

    mov ax, [esi]
    xchg al, ah
    movzx eax, ax

    mov ebx, [cp_offsets + eax * 4]
    add ebx, 3
    mov eax, [ebx]
    cmp eax, 0x65646F43
    je .found_code

    add esi, 2
    mov eax, [esi]
    bswap eax
    add esi, 4
    add esi, eax
    dec edx
    jmp .search_code

.found_code:
    add esi, 14
    mov eax, esi
    jmp .find_done

.skip_this_method:
    mov esi, edi
    add esi, 6
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
