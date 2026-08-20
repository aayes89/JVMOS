[bits 32]

; SÍMBOLOS GLOBALES (OPCODES DE CONVERSIÓN DE TIPOS)
; --- Conversiones desde int (0x85 - 0x87, 0x91 - 0x93) ---
global op_i2l
global op_i2f
global op_i2d
global op_i2b
global op_i2c
global op_i2s

; --- Conversiones desde long (0x88 - 0x8A) ---
global op_l2i
global op_l2f
global op_l2d

; --- Conversiones desde float (0x8B - 0x8D) ---
global op_f2i
global op_f2l
global op_f2d

; --- Conversiones desde double (0x8E - 0x90) ---
global op_d2i
global op_d2l
global op_d2f

; SÍMBOLOS EXTERNOS
extern vm_push
extern vm_pop
extern jvm_dispatch_next            ; Salto de retorno al despachador

section .text

; CONVERSIONES DESDE INT (0x85 - 0x87, 0x91 - 0x93)

; --- i2l (0x85) ---
; Convierte int (32-bit con signo) a long (64-bit con signo)
op_i2l:
    call vm_pop                     ; eax = int
    cdq                             ; EDX = High (signo), EAX = Low
    push eax                        ; Guardar Low
    mov eax, edx
    call vm_push                    ; High 32 bits
    pop eax
    call vm_push                    ; Low 32 bits
    jmp jvm_dispatch_next

; --- i2f (0x86) ---
; Convierte int a float (32-bit IEEE 754) usando FPU
op_i2f:
    sub esp, 4
    call vm_pop                     ; int
    mov [esp], eax

    fild dword [esp]                ; Cargar int de 32 bits a la pila FPU
    fstp dword [esp]                ; Extraer como float de 32 bits

    mov eax, [esp]
    add esp, 4
    call vm_push
    jmp jvm_dispatch_next

; --- i2d (0x87) ---
; Convierte int a double (64-bit IEEE 754) usando FPU
op_i2d:
    sub esp, 8
    call vm_pop                     ; int
    mov [esp], eax

    fild dword [esp]                ; Cargar int
    fstp qword [esp]                ; Extraer como double de 64 bits (esp=Low, esp+4=High)

    mov eax, [esp + 4]              ; High 32 bits
    call vm_push
    mov eax, [esp]                  ; Low 32 bits
    call vm_push
    add esp, 8
    jmp jvm_dispatch_next

; --- i2b (0x91) ---
; Estrecha int a byte (8-bit con signo) y re-extiende a int
op_i2b:
    call vm_pop
    movsx eax, al                   ; Extender signo desde los 8 bits de AL
    call vm_push
    jmp jvm_dispatch_next

; --- i2c (0x92) ---
; Estrecha int a char (16-bit sin signo, UTF-16) y re-extiende a int
op_i2c:
    call vm_pop
    movzx eax, ax                   ; Extender con ceros desde los 16 bits de AX
    call vm_push
    jmp jvm_dispatch_next

; --- i2s (0x93) ---
; Estrecha int a short (16-bit con signo) y re-extiende a int
op_i2s:
    call vm_pop
    movsx eax, ax                   ; Extender signo desde los 16 bits de AX
    call vm_push
    jmp jvm_dispatch_next

; CONVERSIONES DESDE LONG (0x88 - 0x8A)

; --- l2i (0x88) ---
; Convierte long (64-bit) a int (32-bit), descartando los 32 bits superiores
op_l2i:
    call vm_pop                     ; Low dword
    mov ecx, eax
    call vm_pop                     ; High dword (se descarta)
    mov eax, ecx
    call vm_push
    jmp jvm_dispatch_next

; --- l2f (0x89) ---
; Convierte long (64-bit) a float usando FPU
op_l2f:
    sub esp, 8
    call vm_pop                     ; Low dword
    mov [esp], eax
    call vm_pop                     ; High dword
    mov [esp + 4], eax

    fild qword [esp]                ; Cargar entero de 64 bits a FPU
    fstp dword [esp]                ; Extraer float

    mov eax, [esp]
    add esp, 8
    call vm_push
    jmp jvm_dispatch_next

; --- l2d (0x8A) ---
; Convierte long (64-bit) a double usando FPU
op_l2d:
    sub esp, 8
    call vm_pop                     ; Low dword
    mov [esp], eax
    call vm_pop                     ; High dword
    mov [esp + 4], eax

    fild qword [esp]                ; Cargar int 64 bits
    fstp qword [esp]                ; Extraer double 64 bits

    mov eax, [esp + 4]              ; High
    call vm_push
    mov eax, [esp]                  ; Low
    call vm_push
    add esp, 8
    jmp jvm_dispatch_next

; CONVERSIONES DESDE FLOAT (0x8B - 0x8D)

; --- f2i (0x8B) ---
; Convierte float a int (truncando hacia cero)
op_f2i:
    sub esp, 8
    call vm_pop                     ; float
    mov [esp], eax

    fld dword [esp]                 ; Cargar float
    fisttp dword [esp + 4]          ; Convertir a entero truncando (SSE3/x87)
    
    mov eax, [esp + 4]
    add esp, 8
    call vm_push
    jmp jvm_dispatch_next

; --- f2l (0x8C) ---
; Convierte float a long
op_f2l:
    sub esp, 8
    call vm_pop                     ; float
    mov [esp], eax

    fld dword [esp]
    fisttp qword [esp]              ; Convertir a entero de 64 bits truncando

    mov eax, [esp + 4]              ; High
    call vm_push
    mov eax, [esp]                  ; Low
    call vm_push
    add esp, 8
    jmp jvm_dispatch_next

; --- f2d (0x8D) ---
; Amplía float (32-bit) a double (64-bit)
op_f2d:
    sub esp, 8
    call vm_pop                     ; float
    mov [esp], eax

    fld dword [esp]                 ; Cargar float
    fstp qword [esp]                ; Guardar como double (esp=Low, esp+4=High)

    mov eax, [esp + 4]              ; High
    call vm_push
    mov eax, [esp]                  ; Low
    call vm_push
    add esp, 8
    jmp jvm_dispatch_next

; CONVERSIONES DESDE DOUBLE (0x8E - 0x90)

; --- d2i (0x8E) ---
; Convierte double a int
op_d2i:
    sub esp, 8
    call vm_pop                     ; Low
    mov [esp], eax                  ; Corregido: esp = Low
    call vm_pop                     ; High
    mov [esp + 4], eax              ; Corregido: esp + 4 = High

    fld qword [esp]                 ; Cargar double
    fisttp dword [esp]              ; Truncar a entero de 32 bits

    mov eax, [esp]
    add esp, 8
    call vm_push
    jmp jvm_dispatch_next

; --- d2l (0x8F) ---
; Convierte double a long
op_d2l:
    sub esp, 8
    call vm_pop                     ; Low
    mov [esp], eax                  ; Corregido: esp = Low
    call vm_pop                     ; High
    mov [esp + 4], eax              ; Corregido: esp + 4 = High

    fld qword [esp]
    fisttp qword [esp]              ; Truncar a entero de 64 bits

    mov eax, [esp + 4]              ; High
    call vm_push
    mov eax, [esp]                  ; Low
    call vm_push
    add esp, 8
    jmp jvm_dispatch_next

; --- d2f (0x90) ---
; Estrecha double (64-bit) a float (32-bit)
op_d2f:
    sub esp, 8
    call vm_pop                     ; Low
    mov [esp], eax                  ; Corregido: esp = Low
    call vm_pop                     ; High
    mov [esp + 4], eax              ; Corregido: esp + 4 = High

    fld qword [esp]                 ; Cargar double
    fstp dword [esp]                ; Extraer float

    mov eax, [esp]
    add esp, 8
    call vm_push
    jmp jvm_dispatch_next

section .note.GNU-stack noalloc noexec nowrite progbits
