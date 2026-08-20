[bits 32]

; SÍMBOLOS GLOBALES (OPCODES DE COMPARACIÓN)
; --- Comparaciones Numéricas (Long / Float / Double) ---
global op_lcmp
global op_fcmpl
global op_fcmpg
global op_dcmpl
global op_dcmpg

; --- Comparaciones de Referencias ---
global op_if_acmpeq
global op_if_acmpne
global op_ifnull
global op_ifnonnull

; SÍMBOLOS EXTERNOS
extern vm_push
extern vm_pop
extern pc_ptr
extern jvm_dispatch_next

section .text

; COMPARACIONES NUMÉRICAS (0x94 - 0x98)
; Devuelven -1 (menor), 0 (igual) o 1 (mayor) en la pila virtual

; --- lcmp (0x94) ---
; Compara dos longs: v1 (a) y v2 (b). Retorna -1 si a < b, 0 si a == b, 1 si a > b
op_lcmp:
    call vm_pop                     ; b_low
    mov ecx, eax
    call vm_pop                     ; b_high
    mov edx, eax
    call vm_pop                     ; a_low
    mov ebx, eax
    call vm_pop                     ; a_high

    cmp eax, edx                    ; Comparar partes altas con signo
    jl .less
    jg .greater

    cmp ebx, ecx                    ; Si partes altas son iguales, comparar partes bajas sin signo
    jb .less
    ja .greater

    mov eax, 0                      ; a == b
    call vm_push
    jmp jvm_dispatch_next

.less:
    mov eax, -1
    call vm_push
    jmp jvm_dispatch_next

.greater:
    mov eax, 1
    call vm_push
    jmp jvm_dispatch_next

; --- fcmpl (0x95) & fcmpg (0x96) ---
op_fcmpl:
    mov dword [nan_default], -1
    jmp do_fcmp

op_fcmpg:
    mov dword [nan_default], 1

do_fcmp:
    sub esp, 8
    call vm_pop                     ; b
    mov [esp], eax
    call vm_pop                     ; a
    mov [esp + 4], eax

    fld dword [esp + 4]             ; ST(0) = a
    fld dword [esp]                 ; ST(0) = b, ST(1) = a
    fcomip st0, st1                 ; Comparar ST(0) con ST(1) y actualizar EFLAGS
    fstp st0                        ; Limpiar pila FPU

    jp .is_nan                      ; Si Parity Flag es 1 -> Es NaN
    je .equal
    ja .less                        ; Si b > a (a < b)
    
    mov eax, 1                      ; a > b
    add esp, 8
    call vm_push
    jmp jvm_dispatch_next

.less:
    mov eax, -1
    add esp, 8
    call vm_push
    jmp jvm_dispatch_next

.equal:
    mov eax, 0
    add esp, 8
    call vm_push
    jmp jvm_dispatch_next

.is_nan:
    mov eax, [nan_default]
    add esp, 8
    call vm_push
    jmp jvm_dispatch_next

; --- dcmpl (0x97) & dcmpg (0x98) ---
op_dcmpl:
    mov dword [nan_default], -1
    jmp do_dcmp

op_dcmpg:
    mov dword [nan_default], 1

do_dcmp:
    sub esp, 16
    call vm_pop                     ; b_low
    mov [esp], eax                  ; Corregido: esp = Low
    call vm_pop                     ; b_high
    mov [esp + 4], eax              ; Corregido: esp + 4 = High
    call vm_pop                     ; a_low
    mov [esp + 8], eax              ; Corregido: esp + 8 = Low
    call vm_pop                     ; a_high
    mov [esp + 12], eax             ; Corregido: esp + 12 = High

    fld qword [esp + 8]             ; Cargar a
    fld qword [esp]                 ; Cargar b
    fcomip st0, st1
    fstp st0

    jp .d_nan
    je .d_equal
    ja .d_less

    mov eax, 1
    add esp, 16
    call vm_push
    jmp jvm_dispatch_next

.d_less:
    mov eax, -1
    add esp, 16
    call vm_push
    jmp jvm_dispatch_next

.d_equal:
    mov eax, 0
    add esp, 16
    call vm_push
    jmp jvm_dispatch_next

.d_nan:
    mov eax, [nan_default]
    add esp, 16
    call vm_push
    jmp jvm_dispatch_next

; COMPARACIONES DE REFERENCIAS Y NULOS (0xA5 - 0xA6, 0xC6 - 0xC7)

; --- if_acmpeq (0xA5) ---
op_if_acmpeq:
    call vm_pop                     ; ref2
    mov ecx, eax
    call vm_pop                     ; ref1

    mov dx, [esi]                   ; Leer branch offset
    xchg dl, dh
    movsx edx, dx
    add esi, 2
    mov [pc_ptr], esi

    cmp eax, ecx
    je do_acmp_branch
    jmp jvm_dispatch_next

; --- if_acmpne (0xA6) ---
op_if_acmpne:
    call vm_pop                     ; ref2
    mov ecx, eax
    call vm_pop                     ; ref1

    mov dx, [esi]
    xchg dl, dh
    movsx edx, dx
    add esi, 2
    mov [pc_ptr], esi

    cmp eax, ecx
    jne do_acmp_branch
    jmp jvm_dispatch_next

; --- ifnull (0xC6) ---
op_ifnull:
    call vm_pop                     ; ref

    mov dx, [esi]
    xchg dl, dh
    movsx edx, dx
    add esi, 2
    mov [pc_ptr], esi

    cmp eax, 0
    je do_acmp_branch
    jmp jvm_dispatch_next

; --- ifnonnull (0xC7) ---
op_ifnonnull:
    call vm_pop                     ; ref

    mov dx, [esi]
    xchg dl, dh
    movsx edx, dx
    add esi, 2
    mov [pc_ptr], esi

    cmp eax, 0
    jne do_acmp_branch
    jmp jvm_dispatch_next

; AUXILIAR DE SALTO RELATIVO PARA REFERENCIAS
do_acmp_branch:
    sub esi, 3                      ; Volver al inicio de la instrucción
    add esi, edx                    ; Sumar salto relativo exacto
    mov [pc_ptr], esi
    jmp jvm_dispatch_next

section .data
nan_default: dd 0

section .note.GNU-stack noalloc noexec nowrite progbits
