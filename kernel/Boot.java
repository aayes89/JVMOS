/*
MIT License

Copyright (c) 2026 Allan (Slam)

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/

package kernel;

public class Boot {
        
     public static void main(String[] args) {
		// Iniciar teclado
        Native.sys(Native.SYS_SET_KBD_LAYOUT, 1, 0, 0, 0);

        // POST/BIOS dramático para dar sensación de carga
		Native.sys(Native.SYS_SET_COLOR, 0x00000000, 0, 0, 0);
        Native.sys(Native.SYS_FILL_RECT, 0, 0, 1024, 768);
		// Delay de 50000 ms (1 segundos)
        Native.sys(Native.SYS_SLEEP, 50000, 0, 0, 0);        

        Native.sys(Native.SYS_SET_COLOR, 0x0000FF00, 0, 0, 0);
        Native.sys(Native.SYS_DRAW_STRING, 20, 25, "JVMOS BIOS [v2.5]", 0);
        Native.sys(Native.SYS_DRAW_STRING, 20, 45, "=============================================", 0);		  

        Native.sys(Native.SYS_SET_COLOR, 0x0000FF00, 0, 0, 0);
        Native.sys(Native.SYS_DRAW_STRING, 20, 75, "[ OK ]", 0);
        Native.sys(Native.SYS_SET_COLOR, 0x00FFFFFF, 0, 0, 0);
        Native.sys(Native.SYS_DRAW_STRING, 90, 75, "Verificando CPU x86 [Protected Mode 32-Bit]...", 0);
		// Delay de 50000 ms (1 segundos)
        Native.sys(Native.SYS_SLEEP, 50000, 0, 0, 0);        

        Native.sys(Native.SYS_SET_COLOR, 0x0000FF00, 0, 0, 0);
        Native.sys(Native.SYS_DRAW_STRING, 20, 95, "[ OK ]", 0);
        Native.sys(Native.SYS_SET_COLOR, 0x00FFFFFF, 0, 0, 0);
        Native.sys(Native.SYS_DRAW_STRING, 90, 95, "Memoria RAM Detectada: [128MB]", 0);
		// Delay de 50000 ms (1 segundos)
        Native.sys(Native.SYS_SLEEP, 50000, 0, 0, 0);        

        Native.sys(Native.SYS_SET_COLOR, 0x0000FF00, 0, 0, 0);
        Native.sys(Native.SYS_DRAW_STRING, 20, 115, "[ OK ]", 0);
        Native.sys(Native.SYS_SET_COLOR, 0x00FFFFFF, 0, 0, 0);
        Native.sys(Native.SYS_DRAW_STRING, 90, 115, "Cargando Driver PS/2 Keyboard [LATAM ISO Map]", 0);
		// Delay de 50000 ms (1 segundos)
        Native.sys(Native.SYS_SLEEP, 50000, 0, 0, 0);        
		
		Native.sys(Native.SYS_SET_COLOR, 0x0000FF00, 0, 0, 0);
        Native.sys(Native.SYS_DRAW_STRING, 20, 135, "[ OK ]", 0);
        Native.sys(Native.SYS_SET_COLOR, 0x00FFFFFF, 0, 0, 0);
		Native.sys(Native.SYS_DRAW_STRING, 90, 135, "Cargando Driver Mouse i8042 [240 DPI]", 0);
		// Delay de 50000 ms (1 segundos)
        Native.sys(Native.SYS_SLEEP, 50000, 0, 0, 0);        

        Native.sys(Native.SYS_SET_COLOR, 0x0000FF00, 0, 0, 0);
        Native.sys(Native.SYS_DRAW_STRING, 20, 155, "[ OK ]", 0);
        Native.sys(Native.SYS_SET_COLOR, 0x00FFFFFF, 0, 0, 0);
        Native.sys(Native.SYS_DRAW_STRING, 90, 155, "Montando Sistema de Archivos JVMFS [Virtual Ramdisk]", 0);        
		// Delay de 50000 ms (1 segundos)
        Native.sys(Native.SYS_SLEEP, 50000, 0, 0, 0);        
		
		Native.sys(Native.SYS_SET_COLOR, 0x0000FF00, 0, 0, 0);
        Native.sys(Native.SYS_DRAW_STRING, 20, 175, "[ OK ]", 0);
        Native.sys(Native.SYS_SET_COLOR, 0x00FFFFFF, 0, 0, 0);
		Native.sys(Native.SYS_DRAW_STRING, 90, 175, "Modo de Video VBE VESA [1024x768 @ 32bpp]", 0);
		// Delay de 50000 ms (1 segundos)
        Native.sys(Native.SYS_SLEEP, 50000, 0, 0, 0);        
        

        Native.sys(Native.SYS_SET_COLOR, 0x0000FF00, 0, 0, 0);
        Native.sys(Native.SYS_DRAW_STRING, 20, 205, "SISTEMA LISTO. Iniciando Shell interactivo...", 0);

        // Delay de 50000 ms (1 segundos)
        Native.sys(Native.SYS_SLEEP, 50000, 0, 0, 0);        

        // Limpiar pantalla
        Native.sys(Native.SYS_SET_COLOR, 0x00000000, 0, 0, 0);
        Native.sys(Native.SYS_FILL_RECT, 0, 0, 1024, 768);
		
		// Terminal interactivo (shell)
        Native.sys(Native.SYS_SET_COLOR, 0x0000FF00, 0, 0, 0);
        Native.sys(Native.SYS_DRAW_STRING, 20, 30, "JVMOS TERMINAL INTERACTIVA - Escriba 'help' o 'startx'", 0);
        Native.sys(Native.SYS_DRAW_STRING, 20, 50, "-----------------------------------------------------", 0);
   
		// Parametros globales para el shell
        int cursorX = 85;
        int cursorY = 80;
        int lastKey = 0;
        int cmdHash = 0;
        int cmdCount = 0;
		
        Native.sys(Native.SYS_SET_COLOR, 0x0000FF00, 0, 0, 0);
        Native.sys(Native.SYS_DRAW_STRING, 20, cursorY, "JVMOS>", 0);

		// Ciclo principal
        while (true) {
			// Capturar teclas
            int asciiChar = Native.sys(Native.SYS_READ_KEYBOARD, 0, 0, 0, 0);
			
            if (asciiChar != 0 && asciiChar != lastKey) {
				// tecla ENTER para salto de carro o aceptar comando
                if (asciiChar == 13) { 
                    cursorY += 25;
					
					 // comando STARTX
                    if (cmdHash == 486 || cmdHash == 678) {
                        boolean ventanaVisible = true;
                        boolean menuAbierto = false;

                        // Renderizar Escritorio
                        for (int y = 0; y < 728; y += 16) {
                            int b = 60 + (y / 3);
                            if (b > 255) b = 255;
                            int col = ((y / 8) << 16) | ((y / 4) << 8) | b;
                            Native.sys(Native.SYS_SET_COLOR, col, 0, 0, 0);
                            Native.sys(Native.SYS_FILL_RECT, 0, y, 1024, 16);
                        }

                        // Barra de Tareas
                        Native.sys(Native.SYS_SET_COLOR, 0x00333333, 0, 0, 0);
                        Native.sys(Native.SYS_FILL_RECT, 0, 728, 1024, 40);

                        // Botón Inicio
                        Native.sys(Native.SYS_SET_COLOR, 0x0000AA00, 0, 0, 0);
                        Native.sys(Native.SYS_FILL_RECT, 5, 733, 80, 30);
                        Native.sys(Native.SYS_SET_COLOR, 0x00FFFFFF, 0, 0, 0);
                        Native.sys(Native.SYS_DRAW_STRING, 15, 742, "JVMOS", 0);

                        // Ventana Flotante
                        Native.sys(Native.SYS_SET_COLOR, 0x001F4E5B, 0, 0, 0);
                        Native.sys(Native.SYS_FILL_RECT, 200, 150, 600, 30);
                        Native.sys(Native.SYS_SET_COLOR, 0x00FFFFFF, 0, 0, 0);
                        Native.sys(Native.SYS_DRAW_STRING, 210, 160, "ENTORNO GRAFICO INTERACTIVO - JVMOS", 0);

                        Native.sys(Native.SYS_SET_COLOR, 0x00AA0000, 0, 0, 0); // X
                        Native.sys(Native.SYS_FILL_RECT, 765, 155, 25, 20);
                        Native.sys(Native.SYS_SET_COLOR, 0x00FFFFFF, 0, 0, 0);
                        Native.sys(Native.SYS_DRAW_STRING, 773, 160, "X", 0);

                        Native.sys(Native.SYS_SET_COLOR, 0x00CCCCCC, 0, 0, 0);
                        Native.sys(Native.SYS_FILL_RECT, 200, 180, 600, 350);
                        Native.sys(Native.SYS_SET_COLOR, 0x00000000, 0, 0, 0);
                        Native.sys(Native.SYS_DRAW_STRING, 230, 220, "Sistema Operativo Baremetal Java Operativo!", 0);

                        int oldMx = 512;
                        int oldMy = 384;
                        int lastBtn = 0;

                        // BUCLE INTERACTIVO MOUSE / RELOJ / TECLADO
                        while (true) {
                            // Reloj en vivo (extrema derecha)
                            int day   = Native.sys(Native.SYS_GET_TIME, 3, 0, 0, 0);
                            int month = Native.sys(Native.SYS_GET_TIME, 4, 0, 0, 0);
                            int year  = Native.sys(Native.SYS_GET_TIME, 5, 0, 0, 0);
                            int hour  = Native.sys(Native.SYS_GET_TIME, 2, 0, 0, 0);
                            int min   = Native.sys(Native.SYS_GET_TIME, 1, 0, 0, 0);
                            int sec   = Native.sys(Native.SYS_GET_TIME, 0, 0, 0, 0);

                            Native.sys(Native.SYS_SET_COLOR, 0x00222222, 0, 0, 0);
                            Native.sys(Native.SYS_FILL_RECT, 770, 733, 245, 30);
                            Native.sys(Native.SYS_SET_COLOR, 0x0000FF00, 0, 0, 0);

                            Native.sys(Native.SYS_DRAW_CHAR, 780, 742, (day / 10) + '0', 0);
                            Native.sys(Native.SYS_DRAW_CHAR, 790, 742, (day % 10) + '0', 0);
                            Native.sys(Native.SYS_DRAW_CHAR, 800, 742, '/', 0);
                            Native.sys(Native.SYS_DRAW_CHAR, 810, 742, (month / 10) + '0', 0);
                            Native.sys(Native.SYS_DRAW_CHAR, 820, 742, (month % 10) + '0', 0);
                            Native.sys(Native.SYS_DRAW_STRING, 830, 742, "/20", 0);
                            Native.sys(Native.SYS_DRAW_CHAR, 860, 742, (year / 10) + '0', 0);
                            Native.sys(Native.SYS_DRAW_CHAR, 870, 742, (year % 10) + '0', 0);

                            Native.sys(Native.SYS_DRAW_CHAR, 890, 742, (hour / 10) + '0', 0);
                            Native.sys(Native.SYS_DRAW_CHAR, 900, 742, (hour % 10) + '0', 0);
                            Native.sys(Native.SYS_DRAW_CHAR, 910, 742, ':', 0);
                            Native.sys(Native.SYS_DRAW_CHAR, 920, 742, (min / 10) + '0', 0);
                            Native.sys(Native.SYS_DRAW_CHAR, 930, 742, (min % 10) + '0', 0);
                            Native.sys(Native.SYS_DRAW_CHAR, 940, 742, ':', 0);
                            Native.sys(Native.SYS_DRAW_CHAR, 950, 742, (sec / 10) + '0', 0);
                            Native.sys(Native.SYS_DRAW_CHAR, 960, 742, (sec % 10) + '0', 0);

                            // Eventos de Mouse PS/2
                            int mx = Native.sys(Native.SYS_READ_MOUSE, 0, 0, 0, 0);
                            int my = Native.sys(Native.SYS_READ_MOUSE, 1, 0, 0, 0);
                            int btn = Native.sys(Native.SYS_READ_MOUSE, 2, 0, 0, 0);

                            if (mx < 0) mx = 0;
                            if (mx > 1016) mx = 1016;
                            if (my < 0) my = 0;
                            if (my > 760) my = 760;

                            if (mx != oldMx || my != oldMy) {
                                Native.sys(Native.SYS_SET_COLOR, 0x00000000, 0, 0, 0);
                                Native.sys(Native.SYS_FILL_RECT, oldMx, oldMy, 8, 8);

                                if (oldMy >= 728) {
                                    Native.sys(Native.SYS_SET_COLOR, 0x00333333, 0, 0, 0);
                                    Native.sys(Native.SYS_FILL_RECT, oldMx, oldMy, 8, 8);
                                }

                                Native.sys(Native.SYS_SET_COLOR, 0x00FFFFFF, 0, 0, 0);
                                Native.sys(Native.SYS_FILL_RECT, mx, my, 8, 8);

                                oldMx = mx;
                                oldMy = my;
                            }

                            // Procesar Clics
                            if (btn == 1 && lastBtn == 0) {
                                // Clic en Botón Cerrar [X]
                                if (ventanaVisible && mx >= 760 && mx <= 790 && my >= 155 && my <= 175) {
                                    ventanaVisible = false;
                                    Native.sys(Native.SYS_SET_COLOR, 0x00000000, 0, 0, 0);
                                    Native.sys(Native.SYS_FILL_RECT, 200, 150, 600, 380);
                                }
                                // Clic en Botón JVMOS (Menú)
                                else if (mx >= 5 && mx <= 85 && my >= 733 && my <= 763) {
                                    menuAbierto = !menuAbierto;
                                    if (menuAbierto) {
                                        Native.sys(Native.SYS_SET_COLOR, 0x00222222, 0, 0, 0);
                                        Native.sys(Native.SYS_FILL_RECT, 5, 665, 140, 60);
                                        Native.sys(Native.SYS_SET_COLOR, 0x0000AA00, 0, 0, 0);
                                        Native.sys(Native.SYS_DRAW_RECT, 5, 665, 140, 60);
                                        Native.sys(Native.SYS_SET_COLOR, 0x00FF5555, 0, 0, 0);
                                        Native.sys(Native.SYS_DRAW_STRING, 15, 685, "> Apagar", 0);
                                    } else {
                                        Native.sys(Native.SYS_SET_COLOR, 0x00000000, 0, 0, 0);
                                        Native.sys(Native.SYS_FILL_RECT, 5, 665, 140, 60);
                                    }
                                }
                                // Clic en Apagar dentro del Menú
                                else if (menuAbierto && mx >= 5 && mx <= 145 && my >= 665 && my <= 725) {
                                    Native.sys(Native.SYS_SET_COLOR, 0x00000000, 0, 0, 0);
                                    Native.sys(Native.SYS_FILL_RECT, 0, 0, 1024, 768);
                                    Native.sys(Native.SYS_SET_COLOR, 0x00FF5555, 0, 0, 0);
                                    Native.sys(Native.SYS_DRAW_STRING, 380, 360, "SISTEMA APAGADO. CERRANDO EN 2s...", 0);
                                    Native.sys(Native.SYS_SLEEP, 2000, 0, 0, 0);
                                    Native.sys(Native.SYS_EXIT, 0, 0, 0, 0);
                                }

                                lastBtn = 1;
                            } else if (btn == 0) {
                                lastBtn = 0;
                            }

                            // ESC para regresar al Shell
                            int gKey = Native.sys(Native.SYS_READ_KEYBOARD, 0, 0, 0, 0);
                            if (gKey == 27) {
                                break;
                            }

                            Native.sys(Native.SYS_SLEEP, 1, 0, 0, 0);
                        }

                        // Limpiar y restaurar la terminal
                        Native.sys(Native.SYS_SET_COLOR, 0x00000000, 0, 0, 0);
                        Native.sys(Native.SYS_FILL_RECT, 0, 0, 1024, 768);
                        cursorY = 40;
                    }

                    // comando VER
                    if (cmdHash == 237 || cmdHash == 333) {
                        Native.sys(Native.SYS_SET_COLOR, 0x0000FF00, 0, 0, 0);
                        Native.sys(Native.SYS_DRAW_STRING, 20, cursorY, "JVMOS Kernel v2.5 (Baremetal Java x86)", 0);
                        cursorY += 25;
                        Native.sys(Native.SYS_DRAW_STRING, 20, cursorY, "Hecho por Slam 2026", 0);
                        cursorY += 25;
                    }
                    // comando TIME
                    else if (cmdHash == 303 || cmdHash == 431) {
                        int hour = Native.sys(Native.SYS_GET_TIME, 2, 0, 0, 0);
                        int min  = Native.sys(Native.SYS_GET_TIME, 1, 0, 0, 0);
                        int sec  = Native.sys(Native.SYS_GET_TIME, 0, 0, 0, 0);

                        Native.sys(Native.SYS_SET_COLOR, 0x0000FF00, 0, 0, 0);
                        Native.sys(Native.SYS_DRAW_STRING, 20, cursorY, "HORA: ", 0);
                        Native.sys(Native.SYS_DRAW_CHAR, 80, cursorY, (hour / 10) + '0', 0);
                        Native.sys(Native.SYS_DRAW_CHAR, 90, cursorY, (hour % 10) + '0', 0);
                        Native.sys(Native.SYS_DRAW_CHAR, 100, cursorY, ':', 0);
                        Native.sys(Native.SYS_DRAW_CHAR, 110, cursorY, (min / 10) + '0', 0);
                        Native.sys(Native.SYS_DRAW_CHAR, 120, cursorY, (min % 10) + '0', 0);
                        Native.sys(Native.SYS_DRAW_CHAR, 130, cursorY, ':', 0);
                        Native.sys(Native.SYS_DRAW_CHAR, 140, cursorY, (sec / 10) + '0', 0);
                        Native.sys(Native.SYS_DRAW_CHAR, 150, cursorY, (sec % 10) + '0', 0);
                        cursorY += 25;
                    }
                    // comando DATE
                    else if (cmdHash == 286 || cmdHash == 414) {
                        int day   = Native.sys(Native.SYS_GET_TIME, 3, 0, 0, 0);
                        int month = Native.sys(Native.SYS_GET_TIME, 4, 0, 0, 0);
                        int year  = Native.sys(Native.SYS_GET_TIME, 5, 0, 0, 0);

                        Native.sys(Native.SYS_SET_COLOR, 0x0000FF00, 0, 0, 0);
                        Native.sys(Native.SYS_DRAW_STRING, 20, cursorY, "FECHA: ", 0);
                        Native.sys(Native.SYS_DRAW_CHAR, 90, cursorY, (day / 10) + '0', 0);
                        Native.sys(Native.SYS_DRAW_CHAR, 100, cursorY, (day % 10) + '0', 0);
                        Native.sys(Native.SYS_DRAW_CHAR, 110, cursorY, '/', 0);
                        Native.sys(Native.SYS_DRAW_CHAR, 120, cursorY, (month / 10) + '0', 0);
                        Native.sys(Native.SYS_DRAW_CHAR, 130, cursorY, (month % 10) + '0', 0);
                        Native.sys(Native.SYS_DRAW_STRING, 140, cursorY, "/20", 0);
                        Native.sys(Native.SYS_DRAW_CHAR, 170, cursorY, (year / 10) + '0', 0);
                        Native.sys(Native.SYS_DRAW_CHAR, 180, cursorY, (year % 10) + '0', 0);
                        cursorY += 25;
                    }
                    // comando CLEAR
                    else if (cmdHash == 359 || cmdHash == 519) {
                        Native.sys(Native.SYS_SET_COLOR, 0x00000000, 0, 0, 0);
                        Native.sys(Native.SYS_FILL_RECT, 0, 0, 1024, 768);
                        cursorY = 40;
                    }
                    // comando HELP
                    else if (cmdHash == 297 || cmdHash == 425) {
                        Native.sys(Native.SYS_SET_COLOR, 0x0000FF00, 0, 0, 0);
                        Native.sys(Native.SYS_DRAW_STRING, 20, cursorY, "COMANDOS: help | startx | clear | ver | time | date | exit", 0);
                        cursorY += 25;
                    }
					// comando EXIT
                    else if (cmdHash == 314 || cmdHash == 442) {
                        Native.sys(Native.SYS_SET_COLOR, 0x00000000, 0, 0, 0);
                        Native.sys(Native.SYS_FILL_RECT, 0, 0, 1024, 768);
                        Native.sys(Native.SYS_SET_COLOR, 0x00FF5555, 0, 0, 0);
                        Native.sys(Native.SYS_DRAW_STRING, 380, 360, "SISTEMA APAGADO. CERRANDO EN 2s...", 0);
                        Native.sys(Native.SYS_SLEEP, 2000, 0, 0, 0);
                        Native.sys(Native.SYS_EXIT, 0, 0, 0, 0);
                    }

                    // COMANDO DESCONOCIDO
                    else if (cmdCount > 0) {
                        Native.sys(Native.SYS_SET_COLOR, 0x00FF5555, 0, 0, 0);
                        Native.sys(Native.SYS_DRAW_STRING, 20, cursorY, "Error: Comando no reconocido.", 0);
                        cursorY += 25;
                    }

                    cmdHash = 0;
                    cmdCount = 0;

                    if (cursorY > 700) {
                        Native.sys(Native.SYS_SET_COLOR, 0x00000000, 0, 0, 0);
                        Native.sys(Native.SYS_FILL_RECT, 0, 0, 1024, 768);
                        cursorY = 40;
                    }

                    Native.sys(Native.SYS_SET_COLOR, 0x0000FF00, 0, 0, 0);
                    Native.sys(Native.SYS_DRAW_STRING, 20, cursorY, "JVMOS>", 0);
                    cursorX = 85;
                }
                else if (asciiChar == 8) { // tecla BACKSPACE, borrar atrás
                    if (cmdCount > 0 && cursorX > 85) {
                        cursorX -= 10;
                        cmdCount--;
                        if (cmdCount == 0) cmdHash = 0;
                        Native.sys(Native.SYS_SET_COLOR, 0x00000000, 0, 0, 0);
                        Native.sys(Native.SYS_FILL_RECT, cursorX, cursorY, 12, 20);
                    }
                }
                else if (asciiChar >= 32 && asciiChar <= 165) { // borrar CARACTER
                    cmdHash += asciiChar;
                    cmdCount++;

                    if (asciiChar > 32) {
                        Native.sys(Native.SYS_SET_COLOR, 0x00FFFFFF, 0, 0, 0);
                        Native.sys(Native.SYS_DRAW_CHAR, cursorX, cursorY, asciiChar, 0);
                    }

                    cursorX += 10;

                    if (cursorX > 980) {
                        cursorX = 85;
                        cursorY += 25;
                    }
                }

                lastKey = asciiChar;
            } else if (asciiChar == 0) {
                lastKey = 0;
            }

            Native.sys(Native.SYS_SLEEP, 1, 0, 0, 0);
        }
    }
}
