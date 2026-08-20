[bits 32]

; SÍMBOLOS GLOBALES (OPCODES DE LOAD Y STORE)
global op_iload, op_lload, op_fload, op_dload, op_aload
global op_iload_0, op_iload_1, op_iload_2, op_iload_3
global op_lload_0, op_lload_1, op_lload_2, op_lload_3
global op_fload_0, op_fload_1, op_fload_2, op_fload_3
global op_dload_0, op_dload_1, op_dload_2, op_dload_3
global op_aload_0, op_aload_1, op_aload_2, op_aload_3

global op_istore, op_lstore, op_fstore, op_dstore, op_astore
global op_istore_0, op_istore_1, op_istore_2, op_istore_3
global op_lstore_0, op_lstore_1, op_lstore_2, op_lstore_3
global op_fstore_0, op_fstore_1, op_fstore_2, op_fstore_3
global op_dstore_0, op_dstore_1, op_dstore_2, op_dstore_3
global op_astore_0, op_astore_1, op_astore_2, op_astore_3

; SÍMBOLOS EXTERNOS
extern vm_push
extern vm_pop
extern local_vars
extern frame_ptr
extern pc_ptr
extern check_local_bounds
extern jvm_dispatch_next

section .text

; FAMILIA DE CARGAS (LOADS: 0x15 - 0x2D)

op_iload:
op_fload:
op_aload:
    movzx ebx, byte [esi]
    inc esi                         ; PC++
    mov [pc_ptr], esi
    add ebx, [frame_ptr]
    call check_local_bounds
    mov eax, [local_vars + ebx * 4]
    call vm_push
    jmp jvm_dispatch_next

op_lload:
op_dload:
    movzx ebx, byte [esi]
    inc esi                         ; PC++
    mov [pc_ptr], esi
    add ebx, [frame_ptr]
    call check_local_bounds
    mov eax, [local_vars + ebx * 4] ; High dword
    call vm_push
    inc ebx
    call check_local_bounds
    mov eax, [local_vars + ebx * 4] ; Low dword
    call vm_push
    jmp jvm_dispatch_next

op_iload_0:
    mov ebx, 0
    jmp do_iload
op_iload_1:
    mov ebx, 1
    jmp do_iload
op_iload_2:
    mov ebx, 2
    jmp do_iload
op_iload_3:
    mov ebx, 3
do_iload:
    add ebx, [frame_ptr]
    call check_local_bounds
    mov eax, [local_vars + ebx * 4]
    call vm_push
    jmp jvm_dispatch_next

op_lload_0:
    mov ebx, 0
    jmp do_lload
op_lload_1:
    mov ebx, 1
    jmp do_lload
op_lload_2:
    mov ebx, 2
    jmp do_lload
op_lload_3:
    mov ebx, 3
do_lload:
    add ebx, [frame_ptr]
    call check_local_bounds
    mov eax, [local_vars + ebx * 4] ; High
    call vm_push
    inc ebx
    call check_local_bounds
    mov eax, [local_vars + ebx * 4] ; Low
    call vm_push
    jmp jvm_dispatch_next

op_fload_0:
    mov ebx, 0
    jmp do_fload
op_fload_1:
    mov ebx, 1
    jmp do_fload
op_fload_2:
    mov ebx, 2
    jmp do_fload
op_fload_3:
    mov ebx, 3
do_fload:
    add ebx, [frame_ptr]
    call check_local_bounds
    mov eax, [local_vars + ebx * 4]
    call vm_push
    jmp jvm_dispatch_next

op_dload_0:
    mov ebx, 0
    jmp do_dload
op_dload_1:
    mov ebx, 1
    jmp do_dload
op_dload_2:
    mov ebx, 2
    jmp do_dload
op_dload_3:
    mov ebx, 3
do_dload:
    add ebx, [frame_ptr]
    call check_local_bounds
    mov eax, [local_vars + ebx * 4] ; High
    call vm_push
    inc ebx
    call check_local_bounds
    mov eax, [local_vars + ebx * 4] ; Low
    call vm_push
    jmp jvm_dispatch_next

op_aload_0:
    mov ebx, [frame_ptr]
    call check_local_bounds
    mov eax, [local_vars + ebx * 4]
    call vm_push
    jmp jvm_dispatch_next
op_aload_1:
    mov ebx, 1
    jmp do_aload
op_aload_2:
    mov ebx, 2
    jmp do_aload
op_aload_3:
    mov ebx, 3
do_aload:
    add ebx, [frame_ptr]
    call check_local_bounds
    mov eax, [local_vars + ebx * 4]
    call vm_push
    jmp jvm_dispatch_next

; FAMILIA DE ALMACENAMIENTOS (STORES: 0x36 - 0x4E)

op_istore:
op_fstore:
op_astore:
    movzx ebx, byte [esi]
    inc esi                         ; PC++
    mov [pc_ptr], esi
    add ebx, [frame_ptr]
    call check_local_bounds
    call vm_pop
    mov [local_vars + ebx * 4], eax
    jmp jvm_dispatch_next

op_lstore:
op_dstore:
    movzx ebx, byte [esi]
    inc esi                         ; PC++
    mov [pc_ptr], esi
    add ebx, [frame_ptr]
    inc ebx
    call check_local_bounds
    call vm_pop                     ; Low dword
    mov [local_vars + ebx * 4], eax
    dec ebx
    call check_local_bounds
    call vm_pop                     ; High dword
    mov [local_vars + ebx * 4], eax
    jmp jvm_dispatch_next

op_istore_0:
    mov ebx, 0
    jmp do_istore
op_istore_1:
    mov ebx, 1
    jmp do_istore
op_istore_2:
    mov ebx, 2
    jmp do_istore
op_istore_3:
    mov ebx, 3
do_istore:
    add ebx, [frame_ptr]
    call check_local_bounds
    call vm_pop
    mov [local_vars + ebx * 4], eax
    jmp jvm_dispatch_next

op_lstore_0:
    mov ebx, 0
    jmp do_lstore
op_lstore_1:
    mov ebx, 1
    jmp do_lstore
op_lstore_2:
    mov ebx, 2
    jmp do_lstore
op_lstore_3:
    mov ebx, 3
do_lstore:
    add ebx, [frame_ptr]
    inc ebx
    call check_local_bounds
    call vm_pop                     ; Low dword
    mov [local_vars + ebx * 4], eax
    dec ebx
    call check_local_bounds
    call vm_pop                     ; High dword
    mov [local_vars + ebx * 4], eax
    jmp jvm_dispatch_next

op_fstore_0:
    mov ebx, 0
    jmp do_fstore
op_fstore_1:
    mov ebx, 1
    jmp do_fstore
op_fstore_2:
    mov ebx, 2
    jmp do_fstore
op_fstore_3:
    mov ebx, 3
do_fstore:
    add ebx, [frame_ptr]
    call check_local_bounds
    call vm_pop
    mov [local_vars + ebx * 4], eax
    jmp jvm_dispatch_next

op_dstore_0:
    mov ebx, 0
    jmp do_dstore
op_dstore_1:
    mov ebx, 1
    jmp do_dstore
op_dstore_2:
    mov ebx, 2
    jmp do_dstore
op_dstore_3:
    mov ebx, 3
do_dstore:
    add ebx, [frame_ptr]
    inc ebx
    call check_local_bounds
    call vm_pop                     ; Low dword
    mov [local_vars + ebx * 4], eax
    dec ebx
    call check_local_bounds
    call vm_pop                     ; High dword
    mov [local_vars + ebx * 4], eax
    jmp jvm_dispatch_next

op_astore_0:
    call vm_pop
    mov ebx, [frame_ptr]
    call check_local_bounds
    mov [local_vars + ebx * 4], eax
    jmp jvm_dispatch_next
op_astore_1:
    mov ebx, 1
    jmp do_astore
op_astore_2:
    mov ebx, 2
    jmp do_astore
op_astore_3:
    mov ebx, 3
do_astore:
    add ebx, [frame_ptr]
    call check_local_bounds
    call vm_pop
    mov [local_vars + ebx * 4], eax
    jmp jvm_dispatch_next

section .note.GNU-stack noalloc noexec nowrite progbits
