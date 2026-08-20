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
