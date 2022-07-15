package android.util;

/**
 * Mock Android's logging functions.
 */
public class Log {
    public static int d(String tag, String msg) {
        System.out.println("DEBUG: " + tag + ": " + msg);
        return 0;
    }

    public static int i(String tag, String msg) {
        System.out.println("INFO: " + tag + ": " + msg);
        return 0;
    }

    public static int w(String tag, String msg, Throwable thr) {
        System.out.println("WARN: " + tag + ": " + msg + ": " + thr.toString());
        return 0;
    }

    public static int e(String tag, String msg, Throwable thr) {
        System.out.println("ERROR: " + tag + ": " + msg + ": " + thr.toString());
        return 0;
    }
}
