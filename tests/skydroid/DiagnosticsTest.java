package org.navosmart.connectivity;
import com.skydroid.rcsdk.KeyManager;
import com.skydroid.rcsdk.common.airlink.UartBaudRate;
import com.skydroid.rcsdk.common.callback.CompletionCallbackWith;
import com.skydroid.rcsdk.common.callback.KeyListener;
import com.skydroid.rcsdk.common.error.SkyException;
import android.os.SystemClock;
import android.os.Handler;

public class DiagnosticsTest {
    static void check(boolean ok,String why){if(!ok)throw new AssertionError(why);}
    @SuppressWarnings("unchecked")
    public static void main(String[] args){
        KeyManager key=KeyManager.INSTANCE;
        SkydroidDiagnostics diag=new SkydroidDiagnostics();
        check(diag.snapshot().toString().contains("Semnal radio: indisponibil"),"missing is unknown");
        diag.start(); int gets=key.gets,listens=key.listens; diag.start();
        check(gets==5 && key.gets==gets && listens==2 && key.listens==listens,"one metadata batch and listener pair");
        key.emit("signal",0);key.emit("raw","{\"dev_connect\":true,\"is_pairing\":false,\"ap_snr\":\"12\",\"dev_snr\":\"9\",\"ap_ldpc_err\":\"0\",\"dev_ldpc_err\":\"0.1\"}");
        key.reply("baud",UartBaudRate.B115200);key.reply("model","G20");key.reply("version","MCU 1.3");key.reply("ground","20250110");key.reply("air","v2");
        String rows=diag.snapshot().toString();
        check(rows.contains("Radio GR01: CONECTAT")&&rows.contains("Semnal radio: 0%"),"real zero valid, radio separate");
        check(rows.contains("UART0 receptor: 115200")&&rows.contains("SNR radio: G20 12.0 / GR01 9.0"),"vendor baud enum and raw numeric strings");
        SystemClock.now+=6001;rows=diag.snapshot().toString();
        check(rows.contains("Semnal radio: date învechite")&&rows.contains("UART0 receptor: 115200"),"independent radio and metadata expiry");
        key.emit("signal",101);check(diag.snapshot().toString().contains("Semnal radio: indisponibil"),"out-of-range signal rejected");
        key.emit("raw","{\"dev_connect\":false}");rows=diag.snapshot().toString();
        check(rows.contains("Radio GR01: DECONECTAT")&&rows.contains("SNR radio: indisponibil"),"partial sample cannot retain old raw fields");
        key.emit("raw","{\"dev_connect\":\"true\",\"ap_snr\":\"NaN\",\"dev_snr\":\"2\"}");
        check(diag.snapshot().toString().contains("Radio GR01: indisponibil"),"string booleans never treated as connected");
        key.emit("raw","broken");check(diag.snapshot().toString().contains("date radio invalide"),"malformed raw explicit");
        key.reply("baud",UartBaudRate.UNKNOWN);check(diag.snapshot().toString().contains("UART0 receptor: indisponibil"),"UNKNOWN is not a baud reading");
        CompletionCallbackWith<String> old=(CompletionCallbackWith<String>)key.requests.get("air");
        KeyListener<Integer> oldSignal=(KeyListener<Integer>)key.listeners.get("signal");
        ((CompletionCallbackWith<String>)key.requests.get("version")).onFailure(new SkyException());
        check(diag.snapshot().toString().contains("Firmware telecomandă: indisponibil"),"GET errors visible");
        diag.stop();old.onSuccess("late");oldSignal.onValueChange(1,100);
        check(diag.snapshot().toString().contains("Firmware radio GR01: indisponibil")&&!diag.snapshot().toString().contains("100%"),"late callbacks ignored after stop");
        diag.start();old.onSuccess("late");oldSignal.onValueChange(1,100);check(!diag.snapshot().toString().contains("late")&&!diag.snapshot().toString().contains("100%"),"prior-generation GET and listener ignored after restart");
        key.reply("baud",UartBaudRate.B115200);
        SystemClock.now+=45001;check(diag.snapshot().toString().contains("UART0 receptor: date învechite"),"metadata never stays fresh forever");
        CompletionCallbackWith<String> priorBatch=(CompletionCallbackWith<String>)key.requests.get("air");
        int before=key.gets;Handler.fireTimer();check(key.gets==before+5,"metadata refresh continues every scheduled batch");
        priorBatch.onSuccess("obsolete");check(!diag.snapshot().toString().contains("obsolete"),"late metadata from prior poll ignored");
        diag.stop();check(key.listeners.isEmpty(),"listeners released");
        System.out.println("PASS read-only Skydroid diagnostics: real/unknown/stale values, malformed/partial raw, zero signal, baud enums, GET failure, old replies and cleanup");
    }
}
