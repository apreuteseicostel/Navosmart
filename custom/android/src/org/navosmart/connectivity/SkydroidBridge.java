package org.navosmart.connectivity;

import android.content.Context;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import android.os.SystemClock;
import com.skydroid.rcsdk.RCSDKManager;
import com.skydroid.rcsdk.SDKManagerCallBack;
import com.skydroid.rcsdk.PipelineManager;
import com.skydroid.rcsdk.comm.CommListener;
import com.skydroid.rcsdk.common.error.SkyException;
import com.skydroid.rcsdk.common.pipeline.Pipeline;
import java.util.ArrayDeque;
import java.util.Arrays;
import java.util.Locale;
import org.json.JSONObject;

/** NAVO-owned adapter. All SDK lifecycle operations run on Android's main looper.
 * No mode/parameter/servo commands, endpoint guesses or persistent output queue.
 */
public final class SkydroidBridge {
    private static final Handler MAIN = new Handler(Looper.getMainLooper());
    private static final int MAX_RX = 256 * 1024;
    private static long nextSession;
    private static Session active;
    private static boolean initialised;
    private static final class Chunk {
        final byte[] data; final long at;
        Chunk(byte[] value) { data = value; at = SystemClock.elapsedRealtime(); }
    }
    private static final class Session {
        long id, rx, tx, dropped;
        int queued;
        boolean running = true, rc, channel;
        String error = "";
        Pipeline pipeline;
        final ArrayDeque<Chunk> input = new ArrayDeque<>();
    }
    private SkydroidBridge() {}
    public static boolean supported() {
        String model = (Build.MODEL + " " + Build.DEVICE + " " + Build.PRODUCT).toLowerCase(Locale.ROOT);
        return model.contains("g20") && architectureSupported();
    }
    private static boolean architectureSupported() {
        // Vendor 1.9.2 contains ARM libraries only. Never initialise it on emulator x86.
        return Build.CPU_ABI != null && Build.CPU_ABI.startsWith("arm");
    }
    public static synchronized long start(Context context, boolean explicitlySelected) {
        if (!architectureSupported() || (!supported() && !explicitlySelected)) return 0;
        if (active != null && active.running) return active.id;
        Session s = new Session(); s.id = ++nextSession; active = s;
        Context app = context.getApplicationContext();
        MAIN.post(() -> initialise(app, s));
        return s.id;
    }
    private static synchronized boolean current(Session s) { return active == s && s.running; }
    private static void initialise(Context context, Session s) {
        if (!current(s)) return;
        try {
            if (!initialised) {
                RCSDKManager.INSTANCE.initSDK(context, new SDKManagerCallBack() {
                    public void onRcConnected() {
                        final Session target;
                        synchronized (SkydroidBridge.class) { target = active; }
                        if (target != null) MAIN.post(() -> openChannel(target));
                    }
                    public void onRcConnectFail(SkyException e) {
                        synchronized (SkydroidBridge.class) {
                            if (active != null) fail(active, "Conectare telecomandă: " + e);
                        }
                    }
                    public void onRcDisconnect() {
                        synchronized (SkydroidBridge.class) {
                            if (active == null || !current(active)) return;
                            active.rc = false; active.channel = false; clearInput(active);
                            active.error = "Legătura cu telecomanda s-a întrerupt";
                        }
                    }
                });
                initialised = true;
            }
            RCSDKManager.INSTANCE.connectToRC();
        } catch (Throwable e) { fail(s, "Inițializare RCSDK: " + e); }
    }
    private static void openChannel(Session s) {
        synchronized (SkydroidBridge.class) {
            if (!current(s)) return;
            s.rc = true;
            // The SDK already reconnects an existing pipeline; do not create duplicates.
            if (s.pipeline != null) return;
        }
        try {
            Pipeline pipeline = PipelineManager.INSTANCE.createG12G20Pipeline();
            synchronized (SkydroidBridge.class) {
                if (!current(s)) return;
                s.pipeline = pipeline;
            }
            pipeline.setOnCommListener(new CommListener() {
                public void onConnectSuccess() {
                    synchronized (SkydroidBridge.class) {
                        if (!current(s)) return;
                        s.channel = true; s.error = "";
                    }
                }
                public void onConnectFail(SkyException e) { fail(s, "Canal GR01: " + e); }
                public void onDisconnect() {
                    synchronized (SkydroidBridge.class) {
                        if (!current(s)) return;
                        s.channel = false; clearInput(s); s.error = "Canalul GR01 s-a închis";
                    }
                }
                public void onReadData(byte[] data) { receive(s, data); }
            });
            PipelineManager.INSTANCE.connectPipeline(pipeline);
        } catch (Throwable e) { fail(s, "Deschidere canal GR01: " + e); }
    }
    private static synchronized void fail(Session s, String message) {
        if (!current(s)) return;
        s.channel = false; s.error = message; clearInput(s);
    }
    private static void clearInput(Session s) { s.input.clear(); s.queued = 0; }
    private static synchronized void receive(Session s, byte[] data) {
        if (!current(s) || !s.rc || !s.channel || data == null || data.length == 0) return;
        s.rx += data.length;
        if (data.length > MAX_RX) { s.dropped += data.length; return; }
        // Drop the entire backlog on overflow; never splice partial MAVLink chunks.
        if (s.queued + data.length > MAX_RX) { s.dropped += s.queued; clearInput(s); }
        s.input.add(new Chunk(Arrays.copyOf(data, data.length))); s.queued += data.length;
    }
    public static synchronized byte[] read(long id) {
        Session s = active;
        if (s == null || s.id != id || !s.running || !s.rc || !s.channel) return new byte[0];
        Chunk chunk;
        while ((chunk = s.input.poll()) != null) {
            s.queued -= chunk.data.length;
            if (SystemClock.elapsedRealtime() - chunk.at <= 1000) return chunk.data;
            s.dropped += chunk.data.length;
        }
        return new byte[0];
    }
    public static synchronized boolean write(long id, byte[] data) {
        Session s = active;
        if (s == null || s.id != id || !s.running || !s.rc || !s.channel || s.pipeline == null || data == null || data.length == 0) return false;
        try { s.pipeline.writeData(data); s.tx += data.length; return true; }
        catch (Throwable e) { fail(s, "Trimitere către GR01: " + e); return false; }
    }
    public static synchronized String snapshot(long id) {
        JSONObject out = new JSONObject(); Session s = active;
        try {
            out.put("supported", supported()); out.put("arm", architectureSupported());
            out.put("model", Build.MODEL); out.put("sdk", "1.9.2");
            boolean valid = s != null && s.id == id && s.running;
            out.put("running", valid); out.put("rc", valid && s.rc); out.put("channel", valid && s.channel);
            out.put("error", valid ? s.error : ""); out.put("rx", valid ? s.rx : 0);
            out.put("tx", valid ? s.tx : 0); out.put("dropped", valid ? s.dropped : 0);
        } catch (Exception ignored) { }
        return out.toString();
    }
    public static synchronized void stop(long id) {
        final Session s = active;
        if (s == null || s.id != id || !s.running) return;
        s.running = false; s.rc = false; s.channel = false; clearInput(s);
        // FIFO on MAIN ensures the old session is closed before a later start.
        MAIN.post(() -> {
            try { if (s.pipeline != null) PipelineManager.INSTANCE.disconnectPipeline(s.pipeline); }
            catch (Throwable ignored) { }
            try { RCSDKManager.INSTANCE.disconnectRC(); } catch (Throwable ignored) { }
        });
    }
}
