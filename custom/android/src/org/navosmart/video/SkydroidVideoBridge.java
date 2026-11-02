package org.navosmart.video;

import android.app.Activity;
import android.content.Context;
import android.graphics.Rect;
import android.graphics.SurfaceTexture;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import android.os.SystemClock;
import android.view.MotionEvent;
import android.view.View;
import android.view.TextureView;
import android.view.ViewGroup;
import android.widget.FrameLayout;
import com.skydroid.fpvplayer.FPVWidget;
import com.skydroid.fpvplayer.OnPlayerStateListener;
import com.skydroid.fpvplayer.PlayerType;
import com.skydroid.fpvplayer.RtspTransport;
import com.skydroid.fpvplayer.ffmpeg.FrameInfo;
import com.skydroid.rcsdk.utils.RCSDKUtils;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicLong;
import org.json.JSONObject;

/** Native video surface only. Owns no RC/MAVLink pipeline and never logs the stream URL. */
public final class SkydroidVideoBridge {
    private static final Handler MAIN = new Handler(Looper.getMainLooper());
    private static final AtomicLong IDS = new AtomicLong();
    private static final ConcurrentHashMap<Long, Session> SESSIONS = new ConcurrentHashMap<>();
    private static final class Session {
        long id;
        volatile boolean running = true, connected;
        volatile long decodedAt, frames, rendered;
        volatile int width, height, taps;
        volatile String error = "";
        FPVWidget player;
        FrameLayout container;
        ViewGroup parent;
    }
    private SkydroidVideoBridge() {}
    public static boolean supported() {
        return Build.CPU_ABI != null && Build.CPU_ABI.startsWith("arm");
    }
    private static boolean current(Session s) { return s.running && SESSIONS.get(s.id) == s; }
    public static long start(Context context, String url, boolean hardware, String transport, boolean autoReconnect) {
        if (!supported() || !(context instanceof Activity) || url == null ||
            !url.toLowerCase(java.util.Locale.ROOT).startsWith("rtsp://")) return 0;
        Session s = new Session(); s.id = IDS.incrementAndGet(); SESSIONS.put(s.id, s);
        MAIN.post(() -> {
            if (!current(s)) return;
            try {
                Activity activity = (Activity) context;
                s.parent = activity.findViewById(android.R.id.content);
                s.container = new FrameLayout(activity);
                s.container.setVisibility(View.INVISIBLE);
                s.container.setClipChildren(true);
                s.player = new FPVWidget(activity);
                // The official demo uses ONLY_SKY for FPV; keep the engine fixed for decoder A/B.
                s.player.setPlayerType(PlayerType.ONLY_SKY);
                s.player.setUsingMediaCodec(hardware);
                s.player.setRtspTranstype("udp".equals(transport) ? RtspTransport.UDP :
                    "tcp".equals(transport) ? RtspTransport.TCP : RtspTransport.AUTO);
                s.player.setRcType(RCSDKUtils.getDeviceType().getValue());
                s.player.setShowInfo(false);
                s.player.setReConnectInterceptor(() -> current(s) && autoReconnect);
                s.player.setUrl(url);
                s.player.setOnPlayerStateListener(new OnPlayerStateListener() {
                    public void onConnected() { if (current(s)) s.connected = true; }
                    public void onDisconnect() { if (current(s)) { s.connected = false; s.decodedAt = 0; } }
                    public void onReadFrame(FrameInfo frame) { /* Encoded RX is not decoded video. */ }
                });
                s.player.setVideoDecoderCallBack((data, width, height, format) -> {
                    if (!current(s) || data == null || width <= 0 || height <= 0) return;
                    s.width = width; s.height = height; s.frames++; s.decodedAt = SystemClock.elapsedRealtime();
                });
                s.container.addView(s.player, new FrameLayout.LayoutParams(-1, -1));
                View touch = new View(activity);
                touch.setOnTouchListener((view, event) -> {
                    if (event.getAction() == MotionEvent.ACTION_UP && current(s)) { s.taps++; view.performClick(); }
                    return true;
                });
                s.container.addView(touch, new FrameLayout.LayoutParams(-1, -1));
                s.parent.addView(s.container, new FrameLayout.LayoutParams(1, 1));
                if (current(s)) { s.player.start(); watchTextures(s, s.player); } else dispose(s);
            } catch (Throwable e) { s.error = "FPV: " + e.getClass().getSimpleName(); dispose(s); }
        });
        return s.id;
    }
    // MediaCodec can render directly to a TextureView without a YUV callback.
    // Forward the SDK listener unchanged while observing actual presented buffers.
    private static void watchTextures(Session s, View view) {
        if (view instanceof TextureView) {
            TextureView texture = (TextureView) view;
            TextureView.SurfaceTextureListener sdk = texture.getSurfaceTextureListener();
            texture.setSurfaceTextureListener(new TextureView.SurfaceTextureListener() {
                public void onSurfaceTextureAvailable(SurfaceTexture surface, int width, int height) {
                    if (sdk != null) sdk.onSurfaceTextureAvailable(surface, width, height);
                }
                public void onSurfaceTextureSizeChanged(SurfaceTexture surface, int width, int height) {
                    if (sdk != null) sdk.onSurfaceTextureSizeChanged(surface, width, height);
                }
                public boolean onSurfaceTextureDestroyed(SurfaceTexture surface) {
                    if (current(s)) s.decodedAt = 0;
                    return sdk == null || sdk.onSurfaceTextureDestroyed(surface);
                }
                public void onSurfaceTextureUpdated(SurfaceTexture surface) {
                    if (sdk != null) sdk.onSurfaceTextureUpdated(surface);
                    if (current(s) && s.connected) { s.rendered++; s.decodedAt = SystemClock.elapsedRealtime(); }
                }
            });
        }
        if (view instanceof ViewGroup) {
            ViewGroup group = (ViewGroup) view;
            for (int i=0; i<group.getChildCount(); i++) watchTextures(s, group.getChildAt(i));
        }
    }
    /** Physical screen pixels, not dp. Qt supplies the clipped video rectangle only. */
    public static void rect(long id, int x, int y, int width, int height, int left, int top, int right, int bottom) {
        Session s = SESSIONS.get(id); if (s == null) return;
        MAIN.post(() -> {
            if (!current(s) || s.container == null || s.parent == null) return;
            int[] origin = new int[2]; s.parent.getLocationOnScreen(origin);
            FrameLayout.LayoutParams p = new FrameLayout.LayoutParams(Math.max(1, width), Math.max(1, height));
            p.leftMargin = x-origin[0]; p.topMargin = y-origin[1];
            s.container.setLayoutParams(p);
            s.container.setClipBounds(new Rect(left, top, right, bottom));
            s.container.setVisibility(width>0 && height>0 && right>left && bottom>top ? View.VISIBLE : View.INVISIBLE);
        });
    }
    private static void dispose(Session s) {
        // All Android view and SDK operations run on the main looper.
        try { if (s.player != null) { s.player.setOnPlayerStateListener(null); s.player.setVideoDecoderCallBack(null); s.player.stop(); } }
        catch (Throwable ignored) { }
        finally {
            if (s.container != null && s.container.getParent() instanceof ViewGroup)
                ((ViewGroup) s.container.getParent()).removeView(s.container);
            s.player = null; s.container = null; s.parent = null;
            s.connected = false; s.decodedAt = 0;
        }
    }
    public static void stop(long id) {
        Session s = SESSIONS.remove(id); if (s == null) return;
        s.running = false; // Fence queued starts and late frame/disconnect callbacks immediately.
        MAIN.post(() -> dispose(s));
    }
    public static String snapshot(long id) {
        Session s = SESSIONS.get(id);
        try {
            JSONObject out = new JSONObject();
            if (s == null || !current(s)) return out.toString();
            out.put("connected", s.connected); out.put("frames", Math.max(s.frames,s.rendered));
            out.put("width", s.width); out.put("height", s.height);
            out.put("age", s.decodedAt>0 ? SystemClock.elapsedRealtime()-s.decodedAt : -1);
            out.put("taps", s.taps); out.put("error", s.error);
            return out.toString();
        } catch (Exception ignored) { return "{}"; }
    }
}
