<img width="1254" height="1254" alt="theLogo" src="https://github.com/user-attachments/assets/caf5a26c-186d-4e8b-a049-af27ffd08a1f" />

**JVMOS** es un sistema operativo experimental de 32 bits desarrollado en **Ensamblador x86** que ejecuta una **mini-JVM personalizada** directamente sobre el hardware (*Baremetal*), sin depender de Linux, Windows ni de la JVM estándar de Oracle. Basado en otro proyecto escrito en ASM y C durante la carrera de Ingeniería Informática.

---

## ✨ Características Principales

* 💻 **Baremetal Java Kernel:** Intérprete de bytecode Java construido en ensamblador ejecutándose en Modo Protegido x86.
* 🖥️ **Modo Gráfico VESA VBE:** Resolución de `1024x768 @ 32bpp` Direct Color.
* 🌌 **Entorno Gráfico (GUI) Dinámico:** Renderizado en tiempo real.
* ⌨️ **Driver PS/2 Calibrado:** Mapeo completo de teclado físico ISO Latinoamérica (mapeo personalisado al gusto del desarrollador).
* 🐚 **Terminal / Shell Interactivo:** Intérprete de comandos ligero con soporte de comandos internos (`help`, `startx`, `time`, `date`, `ver`, `clear`, `exit`).
* ⏱️ **Integración RTC (CMOS):** Lectura directa de fecha y hora del hardware en tiempo real.
* 🛑 **Power Management:** Extensión de Syscalls nativas para el apagado seguro de la máquina virtual via ACPI / QEMU exit.

---
## 🛠️ Comandos Disponibles en la Terminal

| Comando | Descripción |
| :--- | :--- |
| `startx` | Inicia el entorno gráfico VESA con el fondo de pantalla en gradiente |
| `time` / `date` | Muestra la fecha (`DD/MM/YYYY`) y hora (`HH:MM:SS`) del hardware RTC |
| `ver` | Muestra la versión del Kernel y créditos del autor |
| `clear` / `cls` | Limpia la pantalla de la consola |
| `help` | Muestra el menú de ayuda con los comandos soportados |
| `exit` | Apaga el sistema / detiene la máquina virtual limpiamente |

> 💡 **Nota en Modo Gráfico (`startx`):** Puedes presionar la tecla **`ESC`** regresar al shell de forma directa.

---
## 🚀 Requisitos y Compilación
### Prerrequisitos
Para compilar y ejecutar el proyecto necesitas tener instalado en tu sistema:
* **NASM** (Netwide Assembler)
* **GCC / LD** (Cadena de herramientas de compilación para `i386`)
* **OpenJDK / Java Compiler** (`javac`)
* **QEMU** (`qemu-system-i386`)

### Compilación y Ejecución

* crea una imagen con <code>qemu-img create -f qcow2 disk.img 10M</code> (<b>opcional</b>)
* ejecuta <code>qemu-system-i386 -cdrom os.iso -hda disk.img -m 128M -serial stdio -rtc base=localtime</code>


## 📸 Capturas de Pantalla

### 🐚 Terminal & BIOS POST
> Secuencia dramática de verificación de hardware (RAM, CPU, Drivers) y Shell interactivo procesando comandos.

### 🖥️ Entorno Gráfico (Mandelbrot Desktop)
> Interfaz gráfica en modo VBE con renderizado matemático del Fractal de Mandelbrot y ventana flotante del sistema.

---
<img width="632" height="336" alt="imagen" src="https://github.com/user-attachments/assets/1305d147-1aa2-42a9-815c-a6b80e0a203e" />
<img width="604" height="401" alt="imagen" src="https://github.com/user-attachments/assets/998bfba0-11a2-4054-8dc3-b1eccaebd860" />

<img width="1026" height="825" alt="imagen" src="https://github.com/user-attachments/assets/f5204814-fbdc-4266-8f11-747310468ecc" />
