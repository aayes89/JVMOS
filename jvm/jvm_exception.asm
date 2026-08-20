[bits 32]

; SÍMBOLOS GLOBALES (MANEJO DE EXCEPCIONES Y PANICS)
global fatal_stack_overflow
global fatal_stack_underflow
global fatal_null_pointer
global fatal_array_bounds
global fatal_div_zero
global fatal_negative_array_size
global fatal_local_out_of_bounds
global fatal_unknown_opcode
global fatal_cp_type_error
global fatal_cp_index_error
global fatal_halt_jvm

; SÍMBOLOS EXTERNOS
extern sys_serial_puts
extern sys_hlt
extern pc_ptr                       ; Puntero al PC Virtual para depuración

section .text

; RUTINAS UNIFICADAS DE PÁNICO Y MANEJO DE EXCEPCIONES RUNTIME

fatal_stack_overflow:
    push msg_err_overflow
    call sys_serial_puts
    add esp, 4
    jmp fatal_halt_jvm

fatal_stack_underflow:
    push msg_err_underflow
    call sys_serial_puts
    add esp, 4
    jmp fatal_halt_jvm

fatal_null_pointer:
    push msg_err_null_ptr
    call sys_serial_puts
    add esp, 4
    jmp fatal_halt_jvm

fatal_array_bounds:
    push msg_err_array_bounds
    call sys_serial_puts
    add esp, 4
    jmp fatal_halt_jvm

fatal_div_zero:
    push msg_err_div_zero
    call sys_serial_puts
    add esp, 4
    jmp fatal_halt_jvm

fatal_negative_array_size:
    push msg_err_neg_array
    call sys_serial_puts
    add esp, 4
    jmp fatal_halt_jvm

fatal_local_out_of_bounds:
    push msg_err_locals
    call sys_serial_puts
    add esp, 4
    jmp fatal_halt_jvm

fatal_unknown_opcode:
    push msg_err_opcode
    call sys_serial_puts
    add esp, 4
    jmp fatal_halt_jvm

fatal_cp_type_error:
    push msg_err_cp_type
    call sys_serial_puts
    add esp, 4
    jmp fatal_halt_jvm

fatal_cp_index_error:
    push msg_err_cp_index
    call sys_serial_puts
    add esp, 4
    jmp fatal_halt_jvm

; PARADA CRÍTICA DEL SISTEMA
fatal_halt_jvm:
    push msg_err_halt
    call sys_serial_puts
    add esp, 4

    ; Escribir "EO!" (End Of execution) en rojo sobre el buffer VGA de respaldo
    mov dword [0x000B8000], 0x4F214F45

.loop:
    call sys_hlt
    jmp .loop

section .rodata
align 4
msg_err_overflow:     db 13, 10, "[BootJVM Panic] StackOverflowError!", 13, 10, 0
msg_err_underflow:    db 13, 10, "[BootJVM Panic] StackUnderflowException!", 13, 10, 0
msg_err_null_ptr:     db 13, 10, "[BootJVM Panic] NullPointerException!", 13, 10, 0
msg_err_array_bounds: db 13, 10, "[BootJVM Panic] ArrayIndexOutOfBoundsException!", 13, 10, 0
msg_err_div_zero:     db 13, 10, "[BootJVM Panic] ArithmeticException: / by zero!", 13, 10, 0
msg_err_neg_array:    db 13, 10, "[BootJVM Panic] NegativeArraySizeException!", 13, 10, 0
msg_err_locals:       db 13, 10, "[BootJVM Panic] LocalVariableTable Index Out of Bounds!", 13, 10, 0
msg_err_opcode:       db 13, 10, "[BootJVM Panic] Unknown or Unimplemented Opcode Executed!", 13, 10, 0
msg_err_cp_type:      db 13, 10, "[BootJVM Panic] VerifyError: Invalid Constant Pool Tag!", 13, 10, 0
msg_err_cp_index:     db 13, 10, "[BootJVM Panic] ConstantPoolOutOfBoundsException!", 13, 10, 0
msg_err_halt:         db 13, 10, "[BootJVM System] System Halted.", 13, 10, 0

section .note.GNU-stack noalloc noexec nowrite progbits
