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

public class Graphics2D {

    // Primitivas de la clase Graphics adaptadas a mi ABI
    public void setColor(int rgb) {
        Native.sys(Native.SYS_SET_COLOR, rgb, 0, 0, 0);
    }

    public void fillRect(int x, int y, int w, int h) {
        Native.sys(Native.SYS_FILL_RECT, x, y, w, h);
    }

    public void drawRect(int x, int y, int w, int h) {
        Native.sys(Native.SYS_DRAW_RECT, x, y, w, h);
    }

    public void drawLine(int x1, int y1, int x2, int y2) {
        Native.sys(Native.SYS_DRAW_LINE, x1, y1, x2, y2);
    }

    public void drawString(String text, int x, int y) {
        Native.sys(Native.SYS_DRAW_STRING, x, y, text, 0);
    }

    // Faltan drawCircle, fillCircle, drawTriangle, fillTriangle, clipText, etc.
}
