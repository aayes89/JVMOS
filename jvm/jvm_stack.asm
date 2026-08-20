[bits 32]

; SÍMBOLOS GLOBALES (EXPORTADOS PARA LA JVM)
global vm_push
global vm_pop
global check_null_pointer
global check_array_bounds
global check_local_bounds

; Subrutinas de Opcodes de Pila (Java 8 Specification)
global op_pop
global op_pop2
global op_dup
global op_dup_x1
global op_dup_x2
global op_dup2
global op_dup2_x1
global op_dup2_x2
global op_swap

; SÍMBOLOS EXTERNOS
extern operand_stack
extern stack_ptr
extern sys_serial_puts
extern sys_hlt
extern jvm_dispatch_next            ; Punto de retorno al despachador principal

; Excepciones centralizadas en jvm_exception.asm
extern fatal_stack_overflow
extern fatal_stack_underflow
extern fatal_null_pointer
extern fatal_array_bounds
extern fatal_local_out_of_bounds

section .text

; PRIMITIVAS CORE DE LA PILA VIRTUAL (PUSH / POP)

; void vm_push(uint32_t val) -> Inserta un dword (EAX) en la Operand Stack
vm_push:
    push edx
    mov edx, [stack_ptr]
    cmp edx, 1024                   ; Límite corregido para coincidir con resd 1024
    jge fatal_stack_overflow
    mov [operand_stack + edx * 4], eax
    inc dword [stack_ptr]
    pop edx
    ret

; uint32_t vm_pop(void) -> Extrae un dword de la Operand Stack (retorna en EAX)
vm_pop:
    push edx
    mov edx, [stack_ptr]
    cmp edx, 0
    jle fatal_stack_underflow
    dec dword [stack_ptr]
    mov edx, [stack_ptr]
    mov eax, [operand_stack + edx * 4]
    pop edx
    ret

; RUTINAS DE VALIDACIÓN DE LÍMITES Y APUNTADORES

check_null_pointer:
    cmp eax, 0
    je fatal_null_pointer
    ret

check_array_bounds:
    ; ECX = Índice del array, EAX = Puntero a la cabecera del array
    cmp ecx, 0
    jl fatal_array_bounds
    cmp eax, 0
    je fatal_null_pointer
    cmp ecx, [eax - 8]              ; Comparar con el campo 'length' de la cabecera del objeto
    jge fatal_array_bounds
    ret

check_local_bounds:
    cmp ebx, 255                    ; Ajustado a 256 variables locales max (0-255)
    ja fatal_local_out_of_bounds
    ret


; OPCODES DE MANIPULACIÓN DE LA OPERAND STACK
; --- pop (0x57) ---
op_pop:
    call vm_pop
    jmp jvm_dispatch_next

; --- pop2 (0x58) ---
op_pop2:
    call vm_pop
    call vm_pop
    jmp jvm_dispatch_next

; --- dup (0x59) ---
; Stack: ..., value -> ..., value, value
op_dup:
    call vm_pop
    call vm_push
    call vm_push
    jmp jvm_dispatch_next

; --- dup_x1 (0x5A) ---
; Stack: ..., value2, value1 -> ..., value1, value2, value1
op_dup_x1:
    call vm_pop                     ; v1
    mov ecx, eax
    call vm_pop                     ; v2
    mov edx, eax

    mov eax, ecx
    call vm_push                    ; v1
    mov eax, edx
    call vm_push                    ; v2
    mov eax, ecx
    call vm_push                    ; v1
    jmp jvm_dispatch_next

; --- dup_x2 (0x5B) ---
; Stack: ..., value3, value2, value1 -> ..., value1, value3, value2, value1
op_dup_x2:
    call vm_pop                     ; v1
    mov ecx, eax
    call vm_pop                     ; v2
    mov edx, eax
    call vm_pop                     ; v3
    mov ebx, eax

    mov eax, ecx
    call vm_push                    ; v1
    mov eax, ebx
    call vm_push                    ; v3
    mov eax, edx
    call vm_push                    ; v2
    mov eax, ecx
    call vm_push                    ; v1
    jmp jvm_dispatch_next

; --- dup2 (0x5C) ---
; Stack: ..., value2, value1 -> ..., value2, value1, value2, value1
op_dup2:
    call vm_pop                     ; v1
    mov ecx, eax
    call vm_pop                     ; v2
    mov edx, eax

    mov eax, edx
    call vm_push                    ; v2
    mov eax, ecx
    call vm_push                    ; v1
    mov eax, edx
    call vm_push                    ; v2
    mov eax, ecx
    call vm_push                    ; v1
    jmp jvm_dispatch_next

; --- dup2_x1 (0x5D) ---
; Stack: ..., value3, value2, value1 -> ..., value2, value1, value3, value2, value1
op_dup2_x1:
    call vm_pop                     ; v1
    mov ecx, eax
    call vm_pop                     ; v2
    mov edx, eax
    call vm_pop                     ; v3
    mov ebx, eax

    mov eax, edx
    call vm_push                    ; v2
    mov eax, ecx
    call vm_push                    ; v1
    mov eax, ebx
    call vm_push                    ; v3
    mov eax, edx
    call vm_push                    ; v2
    mov eax, ecx
    call vm_push                    ; v1
    jmp jvm_dispatch_next

; --- dup2_x2 (0x5E) ---
; Stack: ..., value4, value3, value2, value1 -> ..., value2, value1, value4, value3, value2, value1
op_dup2_x2:
    call vm_pop                     ; v1
    mov ecx, eax
    call vm_pop                     ; v2
    mov edx, eax
    call vm_pop                     ; v3
    mov ebx, eax
    call vm_pop                     ; v4
    push eax                        ; Preservar v4 en la pila x86 real

    mov eax, edx
    call vm_push                    ; v2
    mov eax, ecx
    call vm_push                    ; v1
    
    pop eax                         ; Restaurar v4
    call vm_push                    ; v4
    mov eax, ebx
    call vm_push                    ; v3
    mov eax, edx
    call vm_push                    ; v2
    mov eax, ecx
    call vm_push                    ; v1
    jmp jvm_dispatch_next

; --- swap (0x5F) ---
; Stack: ..., value2, value1 -> ..., value1, value2
op_swap:
    call vm_pop                     ; v1
    mov ecx, eax
    call vm_pop                     ; v2
    mov edx, eax

    mov eax, ecx
    call vm_push                    ; v1
    mov eax, edx
    call vm_push                    ; v2
    jmp jvm_dispatch_next

section .note.GNU-stack noalloc noexec nowrite progbits
