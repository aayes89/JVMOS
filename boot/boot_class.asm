[bits 32]
section .rodata
global g_boot_class_start
global g_boot_class_end

g_boot_class_start:
    incbin "kernel/Boot.class"  ; Incrusta el archivo bytecode directamente en el ELF
g_boot_class_end:

section .note.GNU-stack noalloc noexec nowrite progbits