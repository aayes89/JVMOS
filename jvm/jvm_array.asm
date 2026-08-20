[bits 32]

; SÍMBOLOS GLOBALES (OPCODES DE ARRAYS)
global op_iaload
global op_laload
global op_faload
global op_daload
global op_aaload
global op_baload
global op_caload
global op_saload

global op_iastore
global op_lastore
global op_fastore
global op_dastore
global op_aastore
global op_bastore
global op_castore
global op_sastore

global op_newarray
global op_anewarray
global op_arraylength
global op_multianewarray

; SÍMBOLOS EXTERNOS
extern vm_push
extern vm_pop
extern stack_ptr                    
extern pc_ptr
extern sys_kalloc
extern check_null_pointer
extern check_array_bounds
extern fatal_negative_array_size
extern jvm_dispatch_next

section .text

; CREACIÓN DE ARRAYS (0xBC, 0xBD, 0xBE, 0xC5)

op_newarray:
    movzx edx, byte [esi]           ; edx = atype
    inc esi                         ; PC++
    mov [pc_ptr], esi
    call vm_pop                     ; eax = count (longitud)

    cmp eax, 0
    jl fatal_negative_array_size

    push eax                        ; Guardar count
    push edx                        ; Guardar atype

    mov ecx, 4                      ; Por defecto 4 bytes
    cmp dl, 8                       ; T_BYTE (8)
    je .elem_1b
    cmp dl, 4                       ; T_BOOLEAN (4)
    je .elem_1b
    cmp dl, 5                       ; T_CHAR (5)
    je .elem_2b
    cmp dl, 9                       ; T_SHORT (9)
    je .elem_2b
    cmp dl, 7                       ; T_DOUBLE (7)
    je .elem_8b
    cmp dl, 11                      ; T_LONG (11)
    je .elem_8b
    jmp .alloc

.elem_1b:
    mov ecx, 1
    jmp .alloc
.elem_2b:
    mov ecx, 2
    jmp .alloc
.elem_8b:
    mov ecx, 8

.alloc:
    imul eax, ecx                   ; eax = count * element_size
    add eax, 8                      ; +8 bytes cabecera [length(4B) | atype(4B)]
    
    push eax
    call sys_kalloc
    add esp, 4                      ; eax = Puntero Base al Bloque

    pop edx                         ; edx = atype
    pop ecx                         ; ecx = count

    mov [eax], ecx                  ; Cabecera +0: length
    mov [eax + 4], edx              ; Cabecera +4: atype
    add eax, 8                      ; Retornar puntero al inicio de datos

    call vm_push
    jmp jvm_dispatch_next

op_anewarray:
    add esi, 2                      ; Skip Class Index (16 bits)
    mov [pc_ptr], esi
    call vm_pop                     ; eax = count

    cmp eax, 0
    jl fatal_negative_array_size

    push eax
    mov ecx, 4                      ; Referencias = 4 bytes
    imul eax, ecx
    add eax, 8                      ; +8 bytes cabecera
    
    push eax
    call sys_kalloc
    add esp, 4

    pop ecx                         ; ecx = count
    mov [eax], ecx                  ; length
    mov dword [eax + 4], 0          ; atype = 0 (objeto)
    add eax, 8

    call vm_push
    jmp jvm_dispatch_next

op_arraylength:
    call vm_pop                     ; eax = Array Ref
    call check_null_pointer
    mov eax, [eax - 8]              ; Leer length de la cabecera
    call vm_push
    jmp jvm_dispatch_next

op_multianewarray:
    add esi, 2                      ; Skip Class Index
    movzx ebx, byte [esi]           ; ebx = dimensions count
    inc esi                         ; PC++
    mov [pc_ptr], esi

    cmp ebx, 2
    jg .alloc_outer

    call vm_pop                     ; dim2
    mov edx, eax
    call vm_pop                     ; dim1
    mov ecx, eax

    push edx
    push ecx
    mov eax, ecx
    shl eax, 2
    add eax, 8
    push eax
    call sys_kalloc
    add esp, 4
    pop ecx
    pop edx

    mov [eax], ecx
    mov dword [eax + 4], 0
    add eax, 8
    call vm_push
    jmp jvm_dispatch_next

.alloc_outer:
    call vm_pop
    call vm_push
    jmp jvm_dispatch_next

; FAMILIA DE CARGAS DE ARRAYS (ARRAY LOADS: 0x2E - 0x35)
op_iaload:
op_faload:
op_aaload:
    call vm_pop                     ; ecx = index
    mov ecx, eax
    call vm_pop                     ; eax = array ref
    call check_null_pointer
    call check_array_bounds
    mov eax, [eax + ecx * 4]
    call vm_push
    jmp jvm_dispatch_next

op_laload:
op_daload:
    call vm_pop                     ; ecx = index
    mov ecx, eax
    call vm_pop                     ; eax = array ref
    call check_null_pointer
    call check_array_bounds
    
    shl ecx, 3                      ; index * 8
    add ecx, eax
    mov eax, [ecx]                  ; High dword
    call vm_push
    mov eax, [ecx + 4]              ; Low dword
    call vm_push
    jmp jvm_dispatch_next

op_baload:
    call vm_pop                     ; ecx = index
    mov ecx, eax
    call vm_pop                     ; eax = array ref
    call check_null_pointer
    call check_array_bounds
    mov edx, eax
    movsx eax, byte [edx + ecx]
    call vm_push
    jmp jvm_dispatch_next

op_caload:
    call vm_pop                     ; ecx = index
    mov ecx, eax
    call vm_pop                     ; eax = array ref
    call check_null_pointer
    call check_array_bounds
    mov edx, eax
    movzx eax, word [edx + ecx * 2]
    call vm_push
    jmp jvm_dispatch_next

op_saload:
    call vm_pop                     ; ecx = index
    mov ecx, eax
    call vm_pop                     ; eax = array ref
    call check_null_pointer
    call check_array_bounds
    mov edx, eax
    movsx eax, word [edx + ecx * 2]
    call vm_push
    jmp jvm_dispatch_next

; FAMILIA DE ALMACENAMIENTOS EN ARRAYS (ARRAY STORES: 0x4F - 0x56)

; --- iastore (0x4F), fastore (0x51), aastore (0x53) ---
; Pila JVM entrada: ..., arrayref, index, value
op_iastore:
op_fastore:
op_aastore:
    ; 1. Validar profundidad de pila
    mov eax, [stack_ptr]
    cmp eax, 3
    jl .skip_store_underflow

    ; 2. Desapilar operandos en orden inverso de la pila
    call vm_pop                     ; 1. Cima = VALUE
    mov edx, eax                    ; EDX = value

    call vm_pop                     ; 2. Siguiente = INDEX
    mov ecx, eax                    ; ECX = index

    call vm_pop                     ; 3. Base = ARRAYREF
    
    ; 3. Preservar ESI (PC actual) antes de las funciones de chequeo
    push esi

    call check_null_pointer         ; Valida EAX != 0
    call check_array_bounds         ; Valida 0 <= ECX < array.length

    ; 4. Escribir valor de 32 bits en el arreglo (arrayref + index * 4)
    mov [eax + ecx * 4], edx

    pop esi                         ; Restaurar ESI (PC Virtual)
    mov [pc_ptr], esi               ; Re-sincronizar PC en memoria
    jmp jvm_dispatch_next

.skip_store_underflow:
    mov [pc_ptr], esi
    jmp jvm_dispatch_next

op_lastore:
op_dastore:
    call vm_pop                     ; edx = value low
    mov edi, eax
    call vm_pop                     ; ebx = value high
    mov ebx, eax
    call vm_pop                     ; ecx = index
    mov ecx, eax
    call vm_pop                     ; eax = array ref
    call check_null_pointer
    call check_array_bounds

    shl ecx, 3                      ; index * 8
    add ecx, eax
    mov [ecx], ebx                  ; Guardar High dword
    mov [ecx + 4], edi              ; Guardar Low dword
    jmp jvm_dispatch_next

op_bastore:
    call vm_pop                     ; edx = value
    mov edx, eax
    call vm_pop                     ; ecx = index
    mov ecx, eax
    call vm_pop                     ; eax = array ref
    call check_null_pointer
    call check_array_bounds
    mov [eax + ecx], dl
    jmp jvm_dispatch_next

op_castore:
op_sastore:
    call vm_pop                     ; edx = value
    mov edx, eax
    call vm_pop                     ; ecx = index
    mov ecx, eax
    call vm_pop                     ; eax = array ref
    call check_null_pointer
    call check_array_bounds
    mov [eax + ecx * 2], dx
    jmp jvm_dispatch_next

section .note.GNU-stack noalloc noexec nowrite progbits
