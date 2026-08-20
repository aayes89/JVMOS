[bits 32]


; SÍMBOLOS GLOBALES (OPCODES DE CONTROL Y BIFURCACIÓN)

; --- Saltos Condicionales de Enteros (0x99 - 0xA4) ---
global op_ifeq
global op_ifne
global op_iflt
global op_ifge
global op_ifgt
global op_ifle
global op_if_icmpeq
global op_if_icmpne
global op_if_icmplt
global op_if_icmpge
global op_if_icmpgt
global op_if_icmple

; --- Saltos Incondicionales, Subrutinas y Switches (0xA7 - 0xAB, 0xC8, 0xC9) ---
global op_goto
global op_jsr
global op_ret
global op_tableswitch
global op_lookupswitch
global op_goto_w
global op_jsr_w

; --- Retornos de Métodos (0xAC - 0xB1) ---
global op_ireturn
global op_lreturn
global op_freturn
global op_dreturn
global op_areturn
global op_return


; SÍMBOLOS EXTERNOS

extern vm_push
extern vm_pop
extern local_vars
extern pc_ptr
extern check_local_bounds
extern call_frame_stack
extern call_frame_ptr
extern frame_ptr
extern jvm_dispatch_next
extern sys_serial_puts
extern sys_hlt

section .text


; SALTOS CONDICIONALES SOBRE INT CONTRA CERO (0x99 - 0x9E)


; --- ifeq (0x99) ---
op_ifeq:
    call vm_pop
    cmp eax, 0
    je do_branch_16
    add esi, 2                      ; Saltar los 2 bytes del offset si no cumple
    mov [pc_ptr], esi
    jmp jvm_dispatch_next

; --- ifne (0x9A) ---
op_ifne:
    call vm_pop
    cmp eax, 0
    jne do_branch_16
    add esi, 2
    mov [pc_ptr], esi
    jmp jvm_dispatch_next

; --- iflt (0x9B) ---
op_iflt:
    call vm_pop
    cmp eax, 0
    jl do_branch_16
    add esi, 2
    mov [pc_ptr], esi
    jmp jvm_dispatch_next

; --- ifge (0x9C) ---
op_ifge:
    call vm_pop
    cmp eax, 0
    jge do_branch_16
    add esi, 2
    mov [pc_ptr], esi
    jmp jvm_dispatch_next

; --- ifgt (0x9D) ---
op_ifgt:
    call vm_pop
    cmp eax, 0
    jg do_branch_16
    add esi, 2
    mov [pc_ptr], esi
    jmp jvm_dispatch_next

; --- ifle (0x9E) ---
op_ifle:
    call vm_pop
    cmp eax, 0
    jle do_branch_16
    add esi, 2
    mov [pc_ptr], esi
    jmp jvm_dispatch_next


; SALTOS CONDICIONALES ENTRE DOS INTEGERS (0x9F - 0xA4)


; --- if_icmpeq (0x9F) ---
op_if_icmpeq:
    call vm_pop                     ; b
    mov ecx, eax
    call vm_pop                     ; a
    cmp eax, ecx
    je do_branch_16
    add esi, 2
    mov [pc_ptr], esi
    jmp jvm_dispatch_next

; --- if_icmpne (0xA0) ---
op_if_icmpne:
    call vm_pop
    mov ecx, eax
    call vm_pop
    cmp eax, ecx
    jne do_branch_16
    add esi, 2
    mov [pc_ptr], esi
    jmp jvm_dispatch_next

; --- if_icmplt (0xA1) ---
op_if_icmplt:
    call vm_pop
    mov ecx, eax
    call vm_pop
    cmp eax, ecx
    jl do_branch_16
    add esi, 2
    mov [pc_ptr], esi
    jmp jvm_dispatch_next

; --- if_icmpge (0xA2) ---
op_if_icmpge:
    call vm_pop
    mov ecx, eax
    call vm_pop
    cmp eax, ecx
    jge do_branch_16
    add esi, 2
    mov [pc_ptr], esi
    jmp jvm_dispatch_next

; --- if_icmpgt (0xA3) ---
op_if_icmpgt:
    call vm_pop
    mov ecx, eax
    call vm_pop
    cmp eax, ecx
    jg do_branch_16
    add esi, 2
    mov [pc_ptr], esi
    jmp jvm_dispatch_next

; --- if_icmple (0xA4) ---
op_if_icmple:
    call vm_pop
    mov ecx, eax
    call vm_pop
    cmp eax, ecx
    jle do_branch_16
    add esi, 2
    mov [pc_ptr], esi
    jmp jvm_dispatch_next


; SALTOS INCONDICIONALES, SUBRUTINAS Y SWITCHES (0xA7 - 0xAB, 0xC8, 0xC9)


; --- goto (0xA7) ---
op_goto:
    jmp do_branch_16

; --- goto_w (0xC8) ---
op_goto_w:
    jmp do_branch_32

; --- jsr (0xA8) ---
op_jsr:
    mov eax, esi
    add eax, 2                      ; Retorno es PC + 2
    call vm_push
    jmp do_branch_16

; --- jsr_w (0xC9) ---
op_jsr_w:
    mov eax, esi
    add eax, 4                      ; Retorno es PC + 4
    call vm_push
    jmp do_branch_32

; --- ret (0xA9) ---
op_ret:
    movzx ebx, byte [esi]
    inc esi
    add ebx, [frame_ptr]
    call check_local_bounds
    mov esi, [local_vars + ebx * 4]  ; Cargar dirección de retorno guardada
    mov [pc_ptr], esi
    jmp jvm_dispatch_next

; --- tableswitch (0xAA) ---
op_tableswitch:
    mov ebx, esi
    dec ebx                         ; EBX = Base opcode

.align_pad:
    test esi, 0x03
    jz .read_table
    inc esi
    jmp .align_pad

.read_table:
    mov eax, [esi]
    bswap eax
    mov edx, eax                    ; EDX = default_offset
    add esi, 4

    mov eax, [esi]
    bswap eax
    mov ecx, eax                    ; ECX = low
    add esi, 4

    mov eax, [esi]
    bswap eax
    push eax                        ; High
    add esi, 4

    call vm_pop                     ; EAX = index key

    pop edi                         ; EDI = high
    cmp eax, ecx
    jl .use_default
    cmp eax, edi
    jg .use_default

    sub eax, ecx
    mov eax, [esi + eax * 4]
    bswap eax

    add ebx, eax
    mov esi, ebx
    mov [pc_ptr], esi
    jmp jvm_dispatch_next

.use_default:
    add ebx, edx
    mov esi, ebx
    mov [pc_ptr], esi
    jmp jvm_dispatch_next

; --- lookupswitch (0xAB) ---
op_lookupswitch:
    mov ebx, esi
    dec ebx                         ; EBX = Base Opcode

.align_pad_lookup:
    test esi, 0x03
    jz .read_lookup
    inc esi
    jmp .align_pad_lookup

.read_lookup:
    mov eax, [esi]
    bswap eax
    mov edx, eax                    ; EDX = default_offset
    add esi, 4

    mov eax, [esi]
    bswap eax
    mov ecx, eax                    ; ECX = npairs
    add esi, 4

    call vm_pop                     ; EAX = key

.search_pair:
    cmp ecx, 0
    jle .use_lookup_default

    mov edi, [esi]
    bswap edi

    cmp eax, edi
    je .found_pair

    add esi, 8
    dec ecx
    jmp .search_pair

.found_pair:
    mov eax, [esi + 4]
    bswap eax
    add ebx, eax
    mov esi, ebx
    mov [pc_ptr], esi
    jmp jvm_dispatch_next

.use_lookup_default:
    add ebx, edx
    mov esi, ebx
    mov [pc_ptr], esi
    jmp jvm_dispatch_next


; RETORNOS DE MÉTODOS (0xAC - 0xB1)


op_ireturn:
op_lreturn:
op_freturn:
op_dreturn:
op_areturn:
op_return:
    mov edx, [call_frame_ptr]
    cmp edx, 0
    je .exit_main_process            ; Si es el método main (call_frame_ptr == 0), FIN LIMPIO

    dec dword [call_frame_ptr]
    mov edx, [call_frame_ptr]

    ; Restaurar PC y Frame_Ptr del método llamador
    mov esi, [call_frame_stack + edx * 8]
    mov eax, [call_frame_stack + edx * 8 + 4]
    mov [frame_ptr], eax
    mov [pc_ptr], esi
    jmp jvm_dispatch_next

.exit_main_process:
    push msg_dbg_halt
    call sys_serial_puts
    add esp, 4
.halt_loop:
    call sys_hlt
    jmp .halt_loop


; AUXILIARES INTERNOS DE SALTO CORREGIDOS


do_branch_16:
    mov ax, [esi]
    xchg al, ah                     ; Big-Endian a Little-Endian
    movsx eax, ax                   ; Extensión de signo de 16 bits
    dec esi                         ; Apuntar al opcode base (ESI - 1)
    add esi, eax                    ; Puntero Final = (PC_Opcode) + Offset
    mov [pc_ptr], esi
    jmp jvm_dispatch_next

do_branch_32:
    mov eax, [esi]
    bswap eax
    dec esi                         ; Apuntar al opcode base
    add esi, eax
    mov [pc_ptr], esi
    jmp jvm_dispatch_next

section .rodata
msg_dbg_halt: db 13, 10, "[BootJVM] Program Executed Successfully. Halted.", 13, 10, 0

section .note.GNU-stack noalloc noexec nowrite progbits