# =========================================================================
# COMPILADORES Y BANDERAS
# =========================================================================
CC      = gcc-12
LD      = ld
AS      = nasm
JAVAC   = javac

CFLAGS  = -m32 -ffreestanding -fno-pic -fno-stack-protector -fno-builtin -nostdlib -O2 -Wall -Wextra -Iinclude
ASFLAGS = -f elf32
LDFLAGS = -m elf_i386 -T linker.ld

# Archivos de salida
KERNEL_BIN = kernel.bin
OS_ISO     = os.iso

# =========================================================================
# CAPTURA AUTÓNOMA Y ORDENAMIENTO ESTRICTO DE OBJETOS
# =========================================================================
C_SOURCES   := $(wildcard *.c) $(wildcard */*.c) $(wildcard */*/*.c)
ASM_SOURCES := $(wildcard *.asm) $(wildcard */*.asm) $(wildcard */*/*.asm)

# Mapeo dinámico a .o
C_OBJS   := $(patsubst %.c,%.o,$(C_SOURCES))
ASM_OBJS := $(patsubst %.asm,%.o,$(ASM_SOURCES))

# GARANTIZAR EL ORDEN DE ARRANQUE:
# 1. boot/multiboot.o debe ser obligatoriamente el PRIMER objeto en la lista
BOOT_OBJ  := boot/multiboot.o
REST_OBJS := $(filter-out $(BOOT_OBJ), $(ASM_OBJS) $(C_OBJS))

# Lista final ordenada sin duplicados
ALL_OBJS  := $(BOOT_OBJ) $(REST_OBJS)

# Captura de fuentes Java
JAVA_SOURCES := $(wildcard kernel/*.java)

# Detectar Entorno (Windows vs POSIX)
ifeq ($(OS),Windows_NT)
    CLEAN_CMD = if exist isodir rmdir /s /q isodir & if exist *.bin del /q *.bin & if exist *.iso del /q *.iso & if exist kernel\*.class del /q kernel\*.class
    MKDIR     = if not exist isodir\boot\grub mkdir isodir\boot\grub
else
    CLEAN_CMD = rm -rf isodir *.bin *.iso kernel/*.class $(ALL_OBJS)
    MKDIR     = mkdir -p isodir/boot/grub
endif

# =========================================================================
# REGLAS DE COMPILACIÓN
# =========================================================================
all: $(OS_ISO)

# 1. Compilación de archivos Java
kernel/Boot.class: $(JAVA_SOURCES)
	$(JAVAC) -source 8 -target 8 -cp . kernel/*.java

# 2. Dependencia para la incrustación del bytecode
boot/boot_class.o: boot/boot_class.asm kernel/Boot.class
	$(AS) $(ASFLAGS) $< -o $@

# 3. Regla genérica Ensamblador
%.o: %.asm
	$(AS) $(ASFLAGS) $< -o $@

# 4. Regla genérica C
%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

# Enlazado final del Kernel ELF
$(KERNEL_BIN): kernel/Boot.class $(ALL_OBJS)
	$(LD) $(LDFLAGS) -o $@ $(ALL_OBJS)

# Generación de la ISO con GRUB
$(OS_ISO): $(KERNEL_BIN)
	@$(MKDIR)
	cp $(KERNEL_BIN) isodir/boot/kernel.bin
	@echo set timeout=0 > isodir/boot/grub/grub.cfg
	@echo set default=0 >> isodir/boot/grub/grub.cfg
	@echo menuentry "JVM-OS Self-Hosting" { >> isodir/boot/grub/grub.cfg
	@echo     multiboot /boot/kernel.bin >> isodir/boot/grub/grub.cfg
	@echo     boot >> isodir/boot/grub/grub.cfg
	@echo } >> isodir/boot/grub/grub.cfg
	grub-mkrescue -o $(OS_ISO) isodir

# Ejecución en QEMU
run: $(OS_ISO)
	qemu-system-i386 -cdrom $(OS_ISO) -drive file=disk.img,format=raw -m 128M -serial stdio -rtc base=localtime

# Limpieza
clean:
	@$(CLEAN_CMD)

.PHONY: all run clean