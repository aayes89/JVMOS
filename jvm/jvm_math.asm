[bits 32]


; SÍMBOLOS GLOBALES (OPCODES DE ARITMÉTICA Y LÓGICA)

global op_iadd, op_ladd, op_fadd, op_dadd
global op_isub, op_lsub, op_fsub, op_dsub
global op_imul, op_lmul, op_fmul, op_dmul
global op_idiv, op_ldiv, op_fdiv, op_ddiv
global op_irem, op_lrem, op_frem, op_drem
global op_ineg, op_lneg, op_fneg, op_dneg
global op_ishl, op_lshl, op_ishr, op_lshr, op_iushr, op_lushr
global op_iand, op_land, op_ior, op_lor, op_ixor, op_lxor
global op_iinc


; SÍMBOLOS EXTERNOS

extern vm_push
extern vm_pop
extern local_vars
extern frame_ptr                    ; Sincronización estricta de variables locales
extern pc_ptr
extern check_local_bounds
extern sys_serial_puts
extern sys_hlt
extern jvm_dispatch_next

section .text


; SUMA Y RESTA (0x60 - 0x67)


op_iadd:
    call vm_pop                     ; b
    mov ecx, eax
    call vm_pop                     ; a
    add eax, ecx
    call vm_push
    jmp jvm_dispatch_next

op_ladd:
    call vm_pop                     ; b_low
    mov ecx, eax
    call vm_pop                     ; b_high
    mov edx, eax
    call vm_pop                     ; a_low
    mov ebx, eax
    call vm_pop                     ; a_high

    add ebx, ecx                    ; low_sum = a_low + b_low
    adc eax, edx                    ; high_sum = a_high + b_high + carry

    push ebx                        ; Preservar res_low
    call vm_push                    ; Push res_high
    pop eax
    call vm_push                    ; Push res_low
    jmp jvm_dispatch_next

op_fadd:
    sub esp, 8
    call vm_pop
    mov [esp], eax                  ; b
    call vm_pop
    mov [esp + 4], eax              ; a

    fld dword [esp + 4]
    fadd dword [esp]
    fstp dword [esp]

    mov eax, [esp]
    add esp, 8
    call vm_push
    jmp jvm_dispatch_next

op_dadd:
    sub esp, 16
    call vm_pop                     ; b_low
    mov [esp + 4], eax
    call vm_pop                     ; b_high
    mov [esp], eax
    call vm_pop                     ; a_low
    mov [esp + 12], eax
    call vm_pop                     ; a_high
    mov [esp + 8], eax

    fld qword [esp + 8]             ; Cargar Double a
    fadd qword [esp]                ; ST(0) = a + b
    fstp qword [esp]                ; Guardar resultado Double

    mov eax, [esp]                  ; high
    call vm_push
    mov eax, [esp + 4]              ; low
    call vm_push
    add esp, 16
    jmp jvm_dispatch_next

op_isub:
    call vm_pop                     ; b
    mov ecx, eax
    call vm_pop                     ; a
    sub eax, ecx
    call vm_push
    jmp jvm_dispatch_next

op_lsub:
    call vm_pop                     ; b_low
    mov ecx, eax
    call vm_pop                     ; b_high
    mov edx, eax
    call vm_pop                     ; a_low
    mov ebx, eax
    call vm_pop                     ; a_high

    sub ebx, ecx                    ; low_diff = a_low - b_low
    sbb eax, edx                    ; high_diff = a_high - b_high - borrow

    push ebx
    call vm_push                    ; res_high
    pop eax
    call vm_push                    ; res_low
    jmp jvm_dispatch_next

op_fsub:
    sub esp, 8
    call vm_pop
    mov [esp], eax                  ; b
    call vm_pop
    mov [esp + 4], eax              ; a

    fld dword [esp + 4]
    fsub dword [esp]
    fstp dword [esp]

    mov eax, [esp]
    add esp, 8
    call vm_push
    jmp jvm_dispatch_next

op_dsub:
    sub esp, 16
    call vm_pop
    mov [esp + 4], eax
    call vm_pop
    mov [esp], eax
    call vm_pop
    mov [esp + 12], eax
    call vm_pop
    mov [esp + 8], eax

    fld qword [esp + 8]
    fsub qword [esp]
    fstp qword [esp]

    mov eax, [esp]
    call vm_push
    mov eax, [esp + 4]
    call vm_push
    add esp, 16
    jmp jvm_dispatch_next


; MULTIPLICACIÓN Y DIVISIÓN (0x68 - 0x6F)


op_imul:
    call vm_pop
    mov ecx, eax
    call vm_pop
    imul eax, ecx
    call vm_push
    jmp jvm_dispatch_next

op_lmul:
    call vm_pop                     ; b_low
    mov ecx, eax
    call vm_pop                     ; b_high
    mov edx, eax
    call vm_pop                     ; a_low
    mov ebx, eax
    call vm_pop                     ; a_high

    imul edx, ebx                   ; b_high * a_low
    imul eax, ecx                   ; a_high * b_low
    add edx, eax

    mov eax, ebx
    mul ecx                         ; edx:eax = a_low * b_low
    add edx, eax

    push eax                        ; low
    mov eax, edx                    ; high
    call vm_push
    pop eax
    call vm_push
    jmp jvm_dispatch_next

op_fmul:
    sub esp, 8
    call vm_pop
    mov [esp], eax
    call vm_pop
    mov [esp + 4], eax

    fld dword [esp + 4]
    fmul dword [esp]
    fstp dword [esp]

    mov eax, [esp]
    add esp, 8
    call vm_push
    jmp jvm_dispatch_next

op_dmul:
    sub esp, 16
    call vm_pop
    mov [esp + 4], eax
    call vm_pop
    mov [esp], eax
    call vm_pop
    mov [esp + 12], eax
    call vm_pop
    mov [esp + 8], eax

    fld qword [esp + 8]
    fmul qword [esp]
    fstp qword [esp]

    mov eax, [esp]
    call vm_push
    mov eax, [esp + 4]
    call vm_push
    add esp, 16
    jmp jvm_dispatch_next

op_idiv:
    call vm_pop
    mov ecx, eax
    cmp ecx, 0
    je fatal_div_zero
    call vm_pop
    cdq
    idiv ecx
    call vm_push
    jmp jvm_dispatch_next

; --- ldiv (0x6D) - División 64-bit completa sin libgcc ---
op_ldiv:
    call vm_pop                     ; b_low
    mov ecx, eax
    call vm_pop                     ; b_high
    mov edx, eax
    call vm_pop                     ; a_low
    mov ebx, eax
    call vm_pop                     ; a_high

    mov esi, edx
    or esi, ecx
    jz fatal_div_zero               ; Divisor == 0

    cmp edx, 0
    jne .full_ldiv_loop

    ; Caso optimizado: Divisor entra en 32 bits
    mov eax, ebx
    mov edx, 0
    div ecx
    push eax                        ; res_low
    mov eax, 0                      ; res_high = 0
    call vm_push
    pop eax
    call vm_push
    jmp jvm_dispatch_next

.full_ldiv_loop:
    ; Algoritmo de resta sucesiva con desplazamiento para 64-bit
    xor esi, esi                    ; quotient_low
    xor edi, edi                    ; quotient_high
    mov ebp, 64

.shift_loop:
    shl ebx, 1
    rcl eax, 1
    shl esi, 1
    rcl edi, 1

    cmp eax, edx
    jb .next_bit
    ja .sub_val
    cmp ebx, ecx
    jb .next_bit

.sub_val:
    sub ebx, ecx
    sbb eax, edx
    inc esi

.next_bit:
    dec ebp
    jnz .shift_loop

    push esi                        ; low
    mov eax, edi                    ; high
    call vm_push
    pop eax
    call vm_push
    jmp jvm_dispatch_next

op_fdiv:
    sub esp, 8
    call vm_pop
    mov [esp], eax
    call vm_pop
    mov [esp + 4], eax

    fld dword [esp + 4]
    fdiv dword [esp]
    fstp dword [esp]

    mov eax, [esp]
    add esp, 8
    call vm_push
    jmp jvm_dispatch_next

op_ddiv:
    sub esp, 16
    call vm_pop
    mov [esp + 4], eax
    call vm_pop
    mov [esp], eax
    call vm_pop
    mov [esp + 12], eax
    call vm_pop
    mov [esp + 8], eax

    fld qword [esp + 8]
    fdiv qword [esp]
    fstp qword [esp]

    mov eax, [esp]
    call vm_push
    mov eax, [esp + 4]
    call vm_push
    add esp, 16
    jmp jvm_dispatch_next


; MÓDULO Y NEGACIÓN (0x70 - 0x77)


op_irem:
    call vm_pop
    mov ecx, eax
    cmp ecx, 0
    je fatal_div_zero
    call vm_pop
    cdq
    idiv ecx
    mov eax, edx                    ; Resto en EDX
    call vm_push
    jmp jvm_dispatch_next

op_lrem:
    call vm_pop                     ; b_low
    mov ecx, eax
    call vm_pop                     ; b_high
    mov edx, eax
    call vm_pop                     ; a_low
    mov ebx, eax
    call vm_pop                     ; a_high

    mov esi, edx
    or esi, ecx
    jz fatal_div_zero

    cmp edx, 0
    jne .full_lrem

    mov eax, ebx
    mov edx, 0
    div ecx
    mov eax, 0                      ; remainder_high = 0
    call vm_push
    mov eax, edx                    ; remainder_low = edx
    call vm_push
    jmp jvm_dispatch_next

.full_lrem:
    xor eax, eax
    call vm_push
    call vm_push
    jmp jvm_dispatch_next

op_frem:
    sub esp, 8
    call vm_pop
    mov [esp], eax                  ; b
    call vm_pop
    mov [esp + 4], eax              ; a

    fld dword [esp]
    fld dword [esp + 4]
.frem_loop:
    fprem
    fstsw ax
    sahf
    jp .frem_loop                   ; Repetir si el cálculo fue incompleto
    fstp dword [esp]
    fstp st0                        ; Limpiar pila FPU

    mov eax, [esp]
    add esp, 8
    call vm_push
    jmp jvm_dispatch_next

op_drem:
    sub esp, 16
    call vm_pop                     ; b_low
    mov [esp + 4], eax
    call vm_pop                     ; b_high
    mov [esp], eax
    call vm_pop                     ; a_low
    mov [esp + 12], eax
    call vm_pop                     ; a_high
    mov [esp + 8], eax

    fld qword [esp]
    fld qword [esp + 8]
.drem_loop:
    fprem
    fstsw ax
    sahf
    jp .drem_loop
    fstp qword [esp]
    fstp st0

    mov eax, [esp]
    call vm_push
    mov eax, [esp + 4]
    call vm_push
    add esp, 16
    jmp jvm_dispatch_next

op_ineg:
    call vm_pop
    neg eax
    call vm_push
    jmp jvm_dispatch_next

op_lneg:
    call vm_pop                     ; low
    mov ecx, eax
    call vm_pop                     ; high
    neg eax
    neg ecx
    sbb eax, 0
    push eax
    mov eax, ecx
    call vm_push
    pop eax
    call vm_push
    jmp jvm_dispatch_next

op_fneg:
    call vm_pop
    xor eax, 0x80000000             ; Invertir bit de signo
    call vm_push
    jmp jvm_dispatch_next

op_dneg:
    call vm_pop                     ; low
    mov ecx, eax
    call vm_pop                     ; high
    xor eax, 0x80000000             ; Invertir bit de signo en dword alto
    call vm_push
    mov eax, ecx
    call vm_push
    jmp jvm_dispatch_next


; SHIFTS Y LÓGICA BITWISE (0x78 - 0x84)


op_ishl:
    call vm_pop                     ; count
    mov ecx, eax
    and ecx, 0x1F                   ; Máscara 5 bits
    call vm_pop
    shl eax, cl
    call vm_push
    jmp jvm_dispatch_next

op_lshl:
    call vm_pop                     ; count
    mov ecx, eax
    and ecx, 0x3F                   ; Máscara 6 bits
    call vm_pop                     ; low
    mov ebx, eax
    call vm_pop                     ; high

    cmp cl, 32
    jge .lshl_large
    shld eax, ebx, cl
    shl ebx, cl
    jmp .lshl_done
.lshl_large:
    mov eax, ebx
    sub cl, 32
    shl eax, cl
    xor ebx, ebx
.lshl_done:
    push ebx                        ; low
    call vm_push                    ; high
    pop eax
    call vm_push                    ; low
    jmp jvm_dispatch_next

op_ishr:
    call vm_pop
    mov ecx, eax
    and ecx, 0x1F
    call vm_pop
    sar eax, cl
    call vm_push
    jmp jvm_dispatch_next

op_lshr:
    call vm_pop
    mov ecx, eax
    and ecx, 0x3F
    call vm_pop                     ; low
    mov ebx, eax
    call vm_pop                     ; high

    cmp cl, 32
    jge .lshr_large
    shrd ebx, eax, cl
    sar eax, cl
    jmp .lshr_done
.lshr_large:
    mov ebx, eax
    sub cl, 32
    sar ebx, cl
    sar eax, 31                     ; Llenar bits de signo
.lshr_done:
    push ebx
    call vm_push
    pop eax
    call vm_push
    jmp jvm_dispatch_next

op_iushr:
    call vm_pop
    mov ecx, eax
    and ecx, 0x1F
    call vm_pop
    shr eax, cl
    call vm_push
    jmp jvm_dispatch_next

op_lushr:
    call vm_pop
    mov ecx, eax
    and ecx, 0x3F
    call vm_pop                     ; low
    mov ebx, eax
    call vm_pop                     ; high

    cmp cl, 32
    jge .lushr_large
    shrd ebx, eax, cl
    shr eax, cl
    jmp .lushr_done
.lushr_large:
    mov ebx, eax
    sub cl, 32
    shr ebx, cl
    xor eax, eax
.lushr_done:
    push ebx
    call vm_push
    pop eax
    call vm_push
    jmp jvm_dispatch_next

op_iand:
    call vm_pop
    mov ecx, eax
    call vm_pop
    and eax, ecx
    call vm_push
    jmp jvm_dispatch_next

op_land:
    call vm_pop                     ; b_low
    mov ecx, eax
    call vm_pop                     ; b_high
    mov edx, eax
    call vm_pop                     ; a_low
    mov ebx, eax
    call vm_pop                     ; a_high

    and eax, edx                    ; high
    and ebx, ecx                    ; low
    push ebx
    call vm_push
    pop eax
    call vm_push
    jmp jvm_dispatch_next

op_ior:
    call vm_pop
    mov ecx, eax
    call vm_pop
    or eax, ecx
    call vm_push
    jmp jvm_dispatch_next

op_lor:
    call vm_pop                     ; b_low
    mov ecx, eax
    call vm_pop                     ; b_high
    mov edx, eax
    call vm_pop                     ; a_low
    mov ebx, eax
    call vm_pop                     ; a_high

    or eax, edx
    or ebx, ecx
    push ebx
    call vm_push
    pop eax
    call vm_push
    jmp jvm_dispatch_next

op_ixor:
    call vm_pop
    mov ecx, eax
    call vm_pop
    xor eax, ecx
    call vm_push
    jmp jvm_dispatch_next

op_lxor:
    call vm_pop                     ; b_low
    mov ecx, eax
    call vm_pop                     ; b_high
    mov edx, eax
    call vm_pop                     ; a_low
    mov ebx, eax
    call vm_pop                     ; a_high

    xor eax, edx
    xor ebx, ecx
    push ebx
    call vm_push
    pop eax
    call vm_push
    jmp jvm_dispatch_next

; --- iinc (0x84) ---
op_iinc:
    movzx ebx, byte [esi]           ; ebx = index
    inc esi
    movsx ecx, byte [esi]           ; ecx = const
    inc esi
    mov [pc_ptr], esi               ; Actualizar PC Virtual en RAM

    add ebx, [frame_ptr]            ; Sumar desplazador de Frame
    call check_local_bounds
    add [local_vars + ebx * 4], ecx
    jmp jvm_dispatch_next


; EXCEPCIONES Y ERRORES


fatal_div_zero:
    push msg_err_div0
    call sys_serial_puts
    add esp, 4
    jmp fatal_halt_math

fatal_halt_math:
    mov dword [0x000B8000], 0x4F214F45
.loop:
    call sys_hlt
    jmp .loop

section .rodata
msg_err_div0: db 13, 10, "[BootJVM Panic] ArithmeticException: / by zero!", 13, 10, 0

section .note.GNU-stack noalloc noexec nowrite progbits