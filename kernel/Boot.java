/*MIT License

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
SOFTWARE.*/

package kernel;

public class Boot {   

   public static void main(String[] args) {
		Native.sys(Native.SYS_SET_KBD_LAYOUT, 1, 0, 0, 0);
		dramaticBIOS();

		Native.sys(Native.SYS_SET_COLOR, 0x0000FF00, 0, 0, 0);
		Native.sys(Native.SYS_DRAW_STRING, 20, 30, "JVMOS TERMINAL INTERACTIVA - Escriba 'help' o 'startx'", 0);
		Native.sys(Native.SYS_DRAW_STRING, 20, 50, "-----------------------------------------------------", 0);

		int cursorX = 85;
		int cursorY = 80;
		int lastKey = 0;
		int cmdLen = 0;        
		int[] cmdBuffer = new int[16];

		Native.sys(Native.SYS_SET_COLOR, 0x0000FF00, 0, 0, 0);
		Native.sys(Native.SYS_DRAW_STRING, 20, cursorY, "JVMOS>", 0);

		while (true) {
			int asciiChar = Native.sys(Native.SYS_READ_KEYBOARD, 0, 0, 0, 0);

			if (asciiChar != 0 && asciiChar != lastKey) {

				if (asciiChar == 13) { // ENTER
					cursorY += 25; 	

					// --- EVALUACIÓN DIRECTA DE COMANDOS EN MAIN ---
					boolean isVer = (cmdLen == 3 && cmdBuffer[0] == 'v' && cmdBuffer[1] == 'e' && cmdBuffer[2] == 'r');
					boolean isHelp = (cmdLen == 4 && cmdBuffer[0] == 'h' && cmdBuffer[1] == 'e' && cmdBuffer[2] == 'l' && cmdBuffer[3] == 'p');
					boolean isClear = (cmdLen == 5 && cmdBuffer[0] == 'c' && cmdBuffer[1] == 'l' && cmdBuffer[2] == 'e' && cmdBuffer[3] == 'a' && cmdBuffer[4] == 'r') || (cmdLen == 3 && cmdBuffer[0] == 'c' && cmdBuffer[1] == 'l' && cmdBuffer[2] == 's');
					boolean isStartX = (cmdLen == 6 && cmdBuffer[0] == 's' && cmdBuffer[1] == 't' && cmdBuffer[2] == 'a' && cmdBuffer[3] == 'r' && cmdBuffer[4] == 't' && cmdBuffer[5] == 'x');					
					boolean isTime = (cmdLen == 4 && cmdBuffer[0] == 't' && cmdBuffer[1] == 'i' && cmdBuffer[2] == 'm' && cmdBuffer[3] == 'e');
					boolean isDate = (cmdLen == 4 && cmdBuffer[0] == 'd' && cmdBuffer[1] == 'a' && cmdBuffer[2] == 't' && cmdBuffer[3] == 'e');
					boolean isExit = (cmdLen == 4 && cmdBuffer[0] == 'e' && cmdBuffer[1] == 'x' && cmdBuffer[2] == 'i' && cmdBuffer[3] == 't');
					
					// ----- Manejo de comandos -----
					if (isStartX) {
						runStartX(cursorY);
						cursorY = 40;
					}					
					else if(isVer){	
						Native.sys(Native.SYS_SET_COLOR, 0x0000FF00, 0, 0, 0);
						Native.sys(Native.SYS_DRAW_STRING, 20, cursorY, "JVMOS Kernel v2.5 (Baremetal Java x86)", 0);
						cursorY += 25;
						Native.sys(Native.SYS_DRAW_STRING, 20, cursorY, "Hecho por Slam 2026", 0);
						cursorY += 25;
					}
					else if (isTime) {
						showTime(cursorY);
						cursorY += 25;
					}
					else if (isDate) {
						showDate(cursorY);
						cursorY += 25;
					}
					else if (isClear) {
						clearScreen();
						cursorY = 40;
					}
					else if (isHelp) {
						Native.sys(Native.SYS_SET_COLOR, 0x0000FF00, 0, 0, 0);
						Native.sys(Native.SYS_DRAW_STRING, 20, cursorY, "COMANDOS: help | startx | clear | ver | time | date | exit", 0);
						cursorY += 25;
					}
					else if (isExit) {
						clearScreen();
						Native.sys(Native.SYS_SET_COLOR, 0x00FF5555, 0, 0, 0);
						Native.sys(Native.SYS_DRAW_STRING, 380, 360, "SISTEMA APAGADO. CERRANDO EN 2s...", 0);
						Native.sys(Native.SYS_SLEEP, 100000, 0, 0, 0);
						Native.sys(Native.SYS_EXIT, 0, 0, 0, 0);
					}
					else if (cmdLen > 0) {
						Native.sys(Native.SYS_SET_COLOR, 0x00FF5555, 0, 0, 0);
						Native.sys(Native.SYS_DRAW_STRING, 20, cursorY, "Error: Comando no reconocido.", 0);
						cursorY += 25;
					}

					// Reset de memoria y longitud
					for (int i = 0; i < cmdLen; i++) {
						cmdBuffer[i] = 0;
					}                    
					cmdLen = 0;
					
					if (cursorY > 700) {
						clearScreen();
						cursorY = 40;
					}
					Native.sys(Native.SYS_SET_COLOR, 0x0000FF00, 0, 0, 0);
					Native.sys(Native.SYS_DRAW_STRING, 20, cursorY, "JVMOS>", 0);
					cursorX = 85;
				}
				else if (asciiChar == 8) { // BACKSPACE
					if (cmdLen > 0 && cursorX > 85) {                        
						cmdLen--;
						cmdBuffer[cmdLen] = 0; // Limpiar último byte
						cursorX -= 10;                        
						Native.sys(Native.SYS_SET_COLOR, 0x00000000, 0, 0, 0);
						Native.sys(Native.SYS_FILL_RECT, cursorX, cursorY, 12, 20);
					}
				}
				else if (asciiChar >= 32 && asciiChar <= 165) { // TECLAS IMPRIMIBLES
					if (cmdLen < 15) {
						cmdBuffer[cmdLen] = asciiChar;
						cmdLen++;
						
						Native.sys(Native.SYS_SET_COLOR, 0x00FFFFFF, 0, 0, 0);
						Native.sys(Native.SYS_DRAW_CHAR, cursorX, cursorY, asciiChar, 0);
						
						cursorX += 10;
						if (cursorX > 980) {
							cursorX = 85;
							cursorY += 25;
						}
					}					
				}
				lastKey = asciiChar;
			} else if (asciiChar == 0) {
				lastKey = 0;
			}
			Native.sys(Native.SYS_SLEEP, 1, 0, 0, 0);
		}
	}

    // Métodos auxiliares 
    public static void showTime(int y) {
        int hour = Native.sys(Native.SYS_GET_TIME, 2, 0, 0, 0);
		int min  = Native.sys(Native.SYS_GET_TIME, 1, 0, 0, 0);
		int sec  = Native.sys(Native.SYS_GET_TIME, 0, 0, 0, 0);
		
		Native.sys(Native.SYS_SET_COLOR, 0x0000FF00, 0, 0, 0);
		Native.sys(Native.SYS_DRAW_STRING, 20, y, " HORA: ", 0);
		Native.sys(Native.SYS_DRAW_CHAR, 90, y, (hour / 10) + '0', 0);
		Native.sys(Native.SYS_DRAW_CHAR, 100, y, (hour % 10) + '0', 0);
		Native.sys(Native.SYS_DRAW_CHAR, 110, y, ':', 0);
		Native.sys(Native.SYS_DRAW_CHAR, 120, y, (min / 10) + '0', 0);
		Native.sys(Native.SYS_DRAW_CHAR, 130, y, (min % 10) + '0', 0);
		Native.sys(Native.SYS_DRAW_CHAR, 140, y, ':', 0);
		Native.sys(Native.SYS_DRAW_CHAR, 150, y, (sec / 10) + '0', 0);
		Native.sys(Native.SYS_DRAW_CHAR, 160, y, (sec % 10) + '0', 0);

    }

    public static void showDate(int y) {
        int day   = Native.sys(Native.SYS_GET_TIME, 3, 0, 0, 0);
        int month = Native.sys(Native.SYS_GET_TIME, 4, 0, 0, 0);
        int year  = Native.sys(Native.SYS_GET_TIME, 5, 0, 0, 0);
        Native.sys(Native.SYS_SET_COLOR, 0x0000FF00, 0, 0, 0);
        Native.sys(Native.SYS_DRAW_STRING, 20, y, "FECHA: ", 0);
        Native.sys(Native.SYS_DRAW_CHAR, 90, y, (day / 10) + '0', 0);
        Native.sys(Native.SYS_DRAW_CHAR, 100, y, (day % 10) + '0', 0);
        Native.sys(Native.SYS_DRAW_CHAR, 110, y, '/', 0);
        Native.sys(Native.SYS_DRAW_CHAR, 120, y, (month / 10) + '0', 0);
        Native.sys(Native.SYS_DRAW_CHAR, 130, y, (month % 10) + '0', 0);
        Native.sys(Native.SYS_DRAW_STRING, 140, y, "/20", 0);
        Native.sys(Native.SYS_DRAW_CHAR, 170, y, (year / 10) + '0', 0);
        Native.sys(Native.SYS_DRAW_CHAR, 180, y, (year % 10) + '0', 0);
    }

    public static void runStartX(int cursorY) {
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
					clearScreen();
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
		clearScreen();
		cursorY = 40;
    }
	
	// Helper para el POST
    public static void printf(int y, String msg) {        
        Native.sys(Native.SYS_SET_COLOR, 0x0000FF00, 0, 0, 0);
        Native.sys(Native.SYS_DRAW_STRING, 20, y, "[ OK ]", 0);
        Native.sys(Native.SYS_SET_COLOR, 0x00FFFFFF, 0, 0, 0);
        Native.sys(Native.SYS_DRAW_STRING, 90, y, msg, 0);
    }
	
	public static void clearScreen(){
		Native.sys(Native.SYS_SET_COLOR, 0x00000000, 0, 0, 0);
        Native.sys(Native.SYS_FILL_RECT, 0, 0, 1024, 768);
	}
	// Helper de depuración para ver el contenido exacto del buffer
	public static void debugBuffer(int[] buf, int len, int y) {
		//clearScreen();
		Native.sys(Native.SYS_SET_COLOR, 0x00FFFF00, 0, 0, 0); // Amarillo
		Native.sys(Native.SYS_DRAW_STRING, 20, y, "[DEBUG] Len: ", 0);
		//y+=20;
		Native.sys(Native.SYS_DRAW_CHAR, 150, y, (len / 10) + '0', 0);
		Native.sys(Native.SYS_DRAW_CHAR, 160, y, (len % 10) + '0', 0);
		
		Native.sys(Native.SYS_DRAW_STRING, 190, y, "| [", 0);
		int posX = 230;
		
		for (int i = 0; i < len; i++) {
			int val = buf[i];
			// Imprimir el valor numérico ASCII
			Native.sys(Native.SYS_DRAW_CHAR, posX, y, (val / 100) + '0', 0);
			Native.sys(Native.SYS_DRAW_CHAR, posX + 10, y, ((val / 10) % 10) + '0', 0);
			Native.sys(Native.SYS_DRAW_CHAR, posX + 20, y, (val % 10) + '0', 0);
			
			// Imprimir el carácter entre paréntesis
			Native.sys(Native.SYS_DRAW_CHAR, posX + 30, y, '(', 0);
			Native.sys(Native.SYS_DRAW_CHAR, posX + 40, y, val, 0);
			Native.sys(Native.SYS_DRAW_CHAR, posX + 50, y, ')', 0);
			Native.sys(Native.SYS_DRAW_CHAR, posX + 60, y, ' ', 0);
			
			posX += 70;
		}
		Native.sys(Native.SYS_DRAW_STRING, posX, y, "]", 0);
	}
	
    public static void dramaticBIOS() {
        clearScreen();

        Native.sys(Native.SYS_SLEEP, 30000, 0, 0, 0);
        Native.sys(Native.SYS_SET_COLOR, 0x0000FF00, 0, 0, 0);
        Native.sys(Native.SYS_DRAW_STRING, 20, 25, "JVMOS BIOS [v2.5]", 0);
        Native.sys(Native.SYS_DRAW_STRING, 20, 45, "=============================================", 0);

		Native.sys(Native.SYS_SET_COLOR, 0x0000FF00, 0, 0, 0);
        Native.sys(Native.SYS_DRAW_STRING, 20, 75, "[ OK ]", 0);
        Native.sys(Native.SYS_SET_COLOR, 0x00FFFFFF, 0, 0, 0);
        Native.sys(Native.SYS_DRAW_STRING, 90, 75, "Verificando CPU x86 [Protected Mode 32-Bit]...", 0);
		
		Native.sys(Native.SYS_SET_COLOR, 0x0000FF00, 0, 0, 0);
        Native.sys(Native.SYS_DRAW_STRING, 20, 95, "[ OK ]", 0);
        Native.sys(Native.SYS_SET_COLOR, 0x00FFFFFF, 0, 0, 0);
        Native.sys(Native.SYS_DRAW_STRING, 90, 95, "Memoria RAM Detectada: [128MB]", 0);
		
		Native.sys(Native.SYS_SET_COLOR, 0x0000FF00, 0, 0, 0);
        Native.sys(Native.SYS_DRAW_STRING, 20, 115, "[ OK ]", 0);
        Native.sys(Native.SYS_SET_COLOR, 0x00FFFFFF, 0, 0, 0);
        Native.sys(Native.SYS_DRAW_STRING, 90, 115, "Cargando Driver PS/2 Keyboard [LATAM ISO Map]", 0);
		
		Native.sys(Native.SYS_SET_COLOR, 0x0000FF00, 0, 0, 0);
        Native.sys(Native.SYS_DRAW_STRING, 20, 135, "[ OK ]", 0);
        Native.sys(Native.SYS_SET_COLOR, 0x00FFFFFF, 0, 0, 0);
        Native.sys(Native.SYS_DRAW_STRING, 90, 135, "Cargando Driver Mouse i8042 [240 DPI]", 0);
		
		Native.sys(Native.SYS_SET_COLOR, 0x0000FF00, 0, 0, 0);
        Native.sys(Native.SYS_DRAW_STRING, 20, 155, "[ OK ]", 0);
        Native.sys(Native.SYS_SET_COLOR, 0x00FFFFFF, 0, 0, 0);
        Native.sys(Native.SYS_DRAW_STRING, 90, 155, "Montando Sistema de Archivos JVMFS [Virtual Ramdisk]", 0);
		
		Native.sys(Native.SYS_SET_COLOR, 0x0000FF00, 0, 0, 0);
        Native.sys(Native.SYS_DRAW_STRING, 20, 175, "[ OK ]", 0);
        Native.sys(Native.SYS_SET_COLOR, 0x00FFFFFF, 0, 0, 0);
        Native.sys(Native.SYS_DRAW_STRING, 90, 175, "Modo de Video VBE VESA [1024x768 @ 32bpp]", 0);
		
		// Tengo que revisar porque no funcionan los parámetros aquí aún.
        //printf(75, "Verificando CPU x86 [Protected Mode 32-Bit]...");
        //printf(95, "Memoria RAM Detectada: [128MB]");
        //printf(115, "Cargando Driver PS/2 Keyboard [LATAM ISO Map]");
        //printf(135, "Cargando Driver Mouse i8042 [240 DPI]");
        //printf(155, "Montando Sistema de Archivos JVMFS [Virtual Ramdisk]");
        //printf(175, "Modo de Video VBE VESA [1024x768 @ 32bpp]");

        Native.sys(Native.SYS_SET_COLOR, 0x0000FF00, 0, 0, 0);
        Native.sys(Native.SYS_DRAW_STRING, 20, 205, "SISTEMA LISTO. Iniciando Shell interactivo...", 0);
        Native.sys(Native.SYS_SLEEP, 100000, 0, 0, 0);

        clearScreen();
    }	
}
