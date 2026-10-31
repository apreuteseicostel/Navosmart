package org.navosmart.connectivity;

import android.os.Handler;
import android.os.Looper;
import android.os.SystemClock;
import com.skydroid.rcsdk.KeyManager;
import com.skydroid.rcsdk.common.airlink.UartBaudRate;
import com.skydroid.rcsdk.common.callback.CompletionCallbackWith;
import com.skydroid.rcsdk.common.callback.KeyListener;
import com.skydroid.rcsdk.common.error.SkyException;
import com.skydroid.rcsdk.key.AirLinkKey;
import com.skydroid.rcsdk.key.RemoteControllerKey;
import com.skydroid.rcsdk.key.info.KeyInfo;
import org.json.JSONArray;
import org.json.JSONObject;

/** Read-only RCSDK diagnostics. No channel mapping, RF, mode or parameter writes. */
final class SkydroidDiagnostics {
    private final Handler main = new Handler(Looper.getMainLooper());
    private boolean running;
    private int generation;
    private static final class Reading {
        String value = "", error = "";
        long at;
        boolean known;
        void clear() { value = ""; error = ""; known = false; at = 0; }
    }
    private final Reading signal = new Reading(), receiver = new Reading(), pairing = new Reading();
    private final Reading snr = new Reading(), errors = new Reading(), baud = new Reading();
    private final Reading model = new Reading(), version = new Reading(), ground = new Reading(), air = new Reading();
    private final Reading[] readings = {signal, receiver, pairing, snr, errors, baud, model, version, ground, air};
    private long listenerGeneration;
    private KeyListener<Integer> signalListener;
    private KeyListener<String> rawListener;
    private synchronized void receiveSignal(Integer value, long epoch) {
        if (!running || listenerGeneration != epoch) return;
        if (value == null || value < 0 || value > 100) unavailable(signal, "valoare invalidă");
        else put(signal, value + "%");
    }
    private final Runnable refresh = new Runnable() {
        public void run() {
            synchronized (SkydroidDiagnostics.this) { if (!running) return; }
            pollMetadata();
            main.postDelayed(this, 30000);
        }
    };
    synchronized void start() {
        if (running) return;
        running = true;
        generation++;
        final long epoch = ++listenerGeneration;
        signalListener = (oldValue, value) -> receiveSignal(value, epoch);
        rawListener = (oldValue, value) -> receiveRaw(value, epoch);
        listen(AirLinkKey.INSTANCE.getKeySignalQuality(), signalListener, signal);
        listen(AirLinkKey.INSTANCE.getKeyRawSignalQuality(), rawListener, receiver);
        refresh.run();
    }
    private <T> void listen(KeyInfo<T> key, KeyListener<T> listener, Reading field) {
        try {
            SkyException error = KeyManager.INSTANCE.listen(key, listener);
            if (error != null) unavailable(field, error.toString());
        } catch (Throwable error) { unavailable(field, error.toString()); }
    }
    synchronized void stop() {
        if (!running) return;
        running = false;
        generation++;
        listenerGeneration++;
        main.removeCallbacks(refresh);
        try { KeyManager.INSTANCE.cancelListen(signalListener); } catch (Throwable ignored) { }
        try { KeyManager.INSTANCE.cancelListen(rawListener); } catch (Throwable ignored) { }
        for (Reading field : readings) field.clear();
    }
    private synchronized void pollMetadata() {
        if (!running) return;
        // A new batch invalidates late replies to a previous request batch.
        int batch = ++generation;
        read(AirLinkKey.INSTANCE.getKeyUart0BaudRate(), baud, batch);
        read(RemoteControllerKey.INSTANCE.getKeyModel(), model, batch);
        read(RemoteControllerKey.INSTANCE.getKeyVersion(), version, batch);
        read(AirLinkKey.INSTANCE.getKeyRCVersion(), ground, batch);
        read(AirLinkKey.INSTANCE.getKeySkyVersion(), air, batch);
    }
    private <T> void read(KeyInfo<T> key, Reading field, int batch) {
        try {
            KeyManager.INSTANCE.get(key, new CompletionCallbackWith<T>() {
                public void onSuccess(T value) {
                    synchronized (SkydroidDiagnostics.this) {
                        if (!running || generation != batch) return;
                        String text = value == null ? "" : value.toString().trim();
                        if (value instanceof UartBaudRate) {
                            UartBaudRate rate = (UartBaudRate)value;
                            text = rate == UartBaudRate.UNKNOWN ? "" : rate.name().substring(1);
                        }
                        if (text.isEmpty()) unavailable(field, "răspuns gol / nesuportat");
                        else put(field, text);
                    }
                }
                public void onFailure(SkyException error) {
                    synchronized (SkydroidDiagnostics.this) {
                        if (running && generation == batch) unavailable(field, String.valueOf(error));
                    }
                }
            });
        } catch (Throwable error) { unavailable(field, error.toString()); }
    }
    private static String bounded(String text) {
        if (text == null) return "";
        text = text.replaceAll("[\\p{Cntrl}]", " ");
        return text.length() > 160 ? text.substring(0, 160) : text;
    }
    private static void put(Reading field, String value) {
        field.value = bounded(value); field.at = SystemClock.elapsedRealtime(); field.known = true; field.error = "";
    }
    private static void unavailable(Reading field, String error) {
        field.known = false; field.value = ""; field.error = bounded(error);
    }
    private synchronized void receiveRaw(String value, long epoch) {
        if (!running || listenerGeneration != epoch) return;
        // Each raw sample must stand on its own: missing keys never inherit previous readings.
        for (Reading field : new Reading[]{receiver, pairing, snr, errors}) field.clear();
        try {
            if (value == null || value.length() > 16384) throw new IllegalArgumentException("date radio invalide");
            JSONObject raw = new JSONObject(value);
            Object connected = raw.opt("dev_connect"), binding = raw.opt("is_pairing");
            if (connected instanceof Boolean) put(receiver, (Boolean)connected ? "CONECTAT" : "DECONECTAT");
            if (binding instanceof Boolean) put(pairing, (Boolean)binding ? "ÎN CURS" : "INACTIVĂ");
            String ap = number(raw, "ap_snr"), dev = number(raw, "dev_snr");
            if (ap != null && dev != null) put(snr, "G20 " + ap + " / GR01 " + dev);
            String apErr = number(raw, "ap_ldpc_err"), devErr = number(raw, "dev_ldpc_err");
            if (apErr != null && devErr != null) put(errors, "G20 " + apErr + " / GR01 " + devErr);
        } catch (Exception error) { unavailable(receiver, "date radio invalide"); }
    }
    private static String number(JSONObject raw, String name) {
        Object value = raw.opt(name);
        if (!(value instanceof Number) && !(value instanceof String)) return null;
        try {
            double n = Double.parseDouble(value.toString());
            return Double.isNaN(n) || Double.isInfinite(n) ? null : String.valueOf(n);
        } catch (NumberFormatException error) { return null; }
    }
    private String line(String label, Reading field, long ttl) {
        String result = "indisponibil";
        if (running && field.known) {
            long age = SystemClock.elapsedRealtime() - field.at;
            result = age >= 0 && age <= ttl ? field.value : "date învechite";
        } else if (!field.error.isEmpty()) result += " • " + field.error;
        return label + ": " + result;
    }
    synchronized JSONArray snapshot() {
        JSONArray rows = new JSONArray();
        rows.put(line("Radio GR01", receiver, 6000));
        rows.put(line("Semnal radio", signal, 6000));
        rows.put(line("Împerechere", pairing, 6000));
        rows.put(line("SNR radio", snr, 6000));
        rows.put(line("Erori LDPC raportate", errors, 6000));
        rows.put(line("UART0 receptor", baud, 45000));
        rows.put(line("Model SDK", model, 45000));
        rows.put(line("Firmware telecomandă", version, 45000));
        rows.put(line("Firmware radio G20", ground, 45000));
        rows.put(line("Firmware radio GR01", air, 45000));
        return rows;
    }
}
