[bits 32]


; SÍMBOLOS GLOBALES EXPORTADOS

global jvm_dispatch_loop
global jvm_dispatch_next
global op_wide


; SÍMBOLOS EXTERNOS

extern pc_ptr
extern local_vars
extern sys_serial_puts
extern sys_serial_putc
extern sys_hlt

; Constantes y Cargas
extern op_nop, op_aconst_null, op_iconst_m1, op_iconst_0, op_iconst_1, op_iconst_2, op_iconst_3, op_iconst_4, op_iconst_5
extern op_lconst_0, op_lconst_1, op_fconst_0, op_fconst_1, op_fconst_2, op_dconst_0, op_dconst_1
extern op_bipush, op_sipush, op_ldc, op_ldc_w, op_ldc2_w

; Loads y Stores
extern op_iload, op_lload, op_fload, op_dload, op_aload
extern op_iload_0, op_iload_1, op_iload_2, op_iload_3, op_lload_0, op_lload_1, op_lload_2, op_lload_3
extern op_fload_0, op_fload_1, op_fload_2, op_fload_3, op_dload_0, op_dload_1, op_dload_2, op_dload_3
extern op_aload_0, op_aload_1, op_aload_2, op_aload_3
extern op_istore, op_lstore, op_fstore, op_dstore, op_astore
extern op_istore_0, op_istore_1, op_istore_2, op_istore_3, op_lstore_0, op_lstore_1, op_lstore_2, op_lstore_3
extern op_fstore_0, op_fstore_1, op_fstore_2, op_fstore_3, op_dstore_0, op_dstore_1, op_dstore_2, op_dstore_3
extern op_astore_0, op_astore_1, op_astore_2, op_astore_3

; Arrays
extern op_iaload, op_laload, op_faload, op_daload, op_aaload, op_baload, op_caload, op_saload
extern op_iastore, op_lastore, op_fastore, op_dastore, op_aastore, op_bastore, op_castore, op_sastore
extern op_newarray, op_anewarray, op_arraylength, op_multianewarray

; Pila Virtual
extern op_pop, op_pop2, op_dup, op_dup_x1, op_dup_x2, op_dup2, op_dup2_x1, op_dup2_x2, op_swap

; Aritmética
extern op_iadd, op_ladd, op_fadd, op_dadd, op_isub, op_lsub, op_fsub, op_dsub
extern op_imul, op_lmul, op_fmul, op_dmul, op_idiv, op_ldiv, op_fdiv, op_ddiv
extern op_irem, op_lrem, op_frem, op_drem, op_ineg, op_lneg, op_fneg, op_dneg
extern op_ishl, op_lshl, op_ishr, op_lshr, op_iushr, op_lushr
extern op_iand, op_land, op_ior, op_lor, op_ixor, op_lxor, op_iinc

; Conversiones
extern op_i2l, op_i2f, op_i2d, op_l2i, op_l2f, op_l2d, op_f2i, op_f2l, op_f2d
extern op_d2i, op_d2l, op_d2f, op_i2b, op_i2c, op_i2s

; Comparaciones
extern op_lcmp, op_fcmpl, op_fcmpg, op_dcmpl, op_dcmpg
extern op_if_acmpeq, op_if_acmpne, op_ifnull, op_ifnonnull

; Control de Flujo
extern op_ifeq, op_ifne, op_iflt, op_ifge, op_ifgt, op_ifle
extern op_if_icmpeq, op_if_icmpne, op_if_icmplt, op_if_icmpge, op_if_icmpgt, op_if_icmple
extern op_goto, op_jsr, op_ret, op_tableswitch, op_lookupswitch, op_goto_w, op_jsr_w
extern op_ireturn, op_lreturn, op_freturn, op_dreturn, op_areturn, op_return

; Objetos e Invocación
extern op_getstatic, op_putstatic, op_getfield, op_putfield, op_new, op_athrow, op_checkcast, op_instanceof, op_monitorenter, op_monitorexit
extern op_invokevirtual, op_invokespecial, op_invokestatic, op_invokeinterface, op_invokedynamic

section .text


; BUCLE INTÉRPRETE / DESPACHADOR DE OPCODES GARANTIZADO

jvm_dispatch_loop:

jvm_dispatch_next:
    ; Cargar SIEMPRE el PC fresco desde memoria RAM
    mov esi, [pc_ptr]

    movzx eax, byte [esi]
    inc esi
    mov [pc_ptr], esi               ; Actualizar PC incrementado en RAM

    ; Depuración por Serie
    ;pusha
    ;push eax
    ;push msg_dbg_opcode
    ;call sys_serial_puts
    ;add esp, 4
    ;pop eax
    
    ;push eax
    ;call dbg_print_hex8
    ;add esp, 4
    ;popa

    jmp [opcode_jump_table + eax * 4]

; Helper de impresión hexadecimal
dbg_print_hex8:
    push ebp
    mov ebp, esp
    push eax
    push ebx
    
    mov al, [ebp + 8]
    mov bl, al
    shr al, 4
    call .hex_digit
    push eax
    call sys_serial_putc
    add esp, 4
    
    mov al, bl
    and al, 0x0F
    call .hex_digit
    push eax
    call sys_serial_putc
    add esp, 4

    push 32                         ; Espacio ASCII
    call sys_serial_putc
    add esp, 4

    pop ebx
    pop eax
    pop ebp
    ret

.hex_digit:
    cmp al, 10
    jl .is_num
    add al, 'A' - 10
    ret
.is_num:
    add al, '0'
    ret


; MANEJADOR DE PREFIJO WIDE (0xC4)

op_wide:
    mov esi, [pc_ptr]
    movzx eax, byte [esi]
    inc esi
    mov [pc_ptr], esi
    
    cmp al, 0x84                    ; ¿iinc?
    je .wide_iinc

    mov ax, [esi]                   ; Índice 16-bit
    xchg al, ah
    movzx ebx, ax
    add esi, 2
    mov [pc_ptr], esi
    jmp jvm_dispatch_next

.wide_iinc:
    mov ax, [esi]                   ; Index (16-bit)
    xchg al, ah
    movzx ebx, ax
    add esi, 2
    mov ax, [esi]                   ; Constante (16-bit signed)
    xchg al, ah
    movsx ecx, ax
    add esi, 2
    mov [pc_ptr], esi
    
    add [local_vars + ebx * 4], ecx
    jmp jvm_dispatch_next


; MANEJADOR PARA OPCODES NO IMPLEMENTADOS O INVÁLIDOS

op_invalid:
    push msg_err_invalid_opcode
    call sys_serial_puts
    add esp, 4
.hang:
    call sys_hlt
    jmp .hang

section .data
msg_err_invalid_opcode: db 13, 10, "[BootJVM Panic] Invalid or Unimplemented Opcode Executed!", 13, 10, 0

section .rodata
msg_dbg_opcode: db 13, 10, "[Opcode] 0x", 0

align 4
opcode_jump_table:
    ; 0x00 - 0x0F
    dd op_nop, op_aconst_null, op_iconst_m1, op_iconst_0, op_iconst_1, op_iconst_2, op_iconst_3, op_iconst_4
    dd op_iconst_5, op_lconst_0, op_lconst_1, op_fconst_0, op_fconst_1, op_fconst_2, op_dconst_0, op_dconst_1
    
    ; 0x10 - 0x1F
    dd op_bipush, op_sipush, op_ldc, op_ldc_w, op_ldc2_w, op_iload, op_lload, op_fload
    dd op_dload, op_aload, op_iload_0, op_iload_1, op_iload_2, op_iload_3, op_lload_0, op_lload_1
    
    ; 0x20 - 0x2F
    dd op_lload_2, op_lload_3, op_fload_0, op_fload_1, op_fload_2, op_fload_3, op_dload_0, op_dload_1
    dd op_dload_2, op_dload_3, op_aload_0, op_aload_1, op_aload_2, op_aload_3, op_iaload, op_laload
    
    ; 0x30 - 0x3F
    dd op_faload, op_daload, op_aaload, op_baload, op_caload, op_saload, op_istore, op_lstore
    dd op_fstore, op_dstore, op_astore, op_istore_0, op_istore_1, op_istore_2, op_istore_3, op_lstore_0
    
    ; 0x40 - 0x4F
    dd op_lstore_1, op_lstore_2, op_lstore_3, op_fstore_0, op_fstore_1, op_fstore_2, op_fstore_3, op_dstore_0
    dd op_dstore_1, op_dstore_2, op_dstore_3, op_astore_0, op_astore_1, op_astore_2, op_astore_3, op_iastore
    
    ; 0x50 - 0x5F
    dd op_lastore, op_fastore, op_dastore, op_aastore, op_bastore, op_castore, op_sastore, op_pop
    dd op_pop2, op_dup, op_dup_x1, op_dup_x2, op_dup2, op_dup2_x1, op_dup2_x2, op_swap
    
    ; 0x60 - 0x6F
    dd op_iadd, op_ladd, op_fadd, op_dadd, op_isub, op_lsub, op_fsub, op_dsub
    dd op_imul, op_lmul, op_fmul, op_dmul, op_idiv, op_ldiv, op_fdiv, op_ddiv
    
    ; 0x70 - 0x7F
    dd op_irem, op_lrem, op_frem, op_drem, op_ineg, op_lneg, op_fneg, op_dneg
    dd op_ishl, op_lshl, op_ishr, op_lshr, op_iushr, op_lushr, op_iand, op_land
    
    ; 0x80 - 0x8F
    dd op_ior, op_lor, op_ixor, op_lxor, op_iinc, op_i2l, op_i2f, op_i2d
    dd op_l2i, op_l2f, op_l2d, op_f2i, op_f2l, op_f2d, op_d2i, op_d2l
    
    ; 0x90 - 0x9F
    dd op_d2f, op_i2b, op_i2c, op_i2s, op_lcmp, op_fcmpl, op_fcmpg, op_dcmpl
    dd op_dcmpg, op_ifeq, op_ifne, op_iflt, op_ifge, op_ifgt, op_ifle, op_if_icmpeq
    
    ; 0xA0 - 0xAF
    dd op_if_icmpne, op_if_icmplt, op_if_icmpge, op_if_icmpgt, op_if_icmple, op_if_acmpeq, op_if_acmpne, op_goto
    dd op_jsr, op_ret, op_tableswitch, op_lookupswitch, op_ireturn, op_lreturn, op_freturn, op_dreturn
    
    ; 0xB0 - 0xBF
    dd op_areturn, op_return, op_getstatic, op_putstatic, op_getfield, op_putfield, op_invokevirtual, op_invokespecial
    dd op_invokestatic, op_invokeinterface, op_invokedynamic, op_new, op_newarray, op_anewarray, op_arraylength, op_athrow
    
    ; 0xC0 - 0xCF
    dd op_checkcast, op_instanceof, op_monitorenter, op_monitorexit, op_wide, op_multianewarray, op_ifnull, op_ifnonnull
    dd op_goto_w, op_jsr_w, op_invalid, op_invalid, op_invalid, op_invalid, op_invalid, op_invalid
    
    ; 0xD0 - 0xFF
    times 48 dd op_invalid

section .note.GNU-stack noalloc noexec nowrite progbits