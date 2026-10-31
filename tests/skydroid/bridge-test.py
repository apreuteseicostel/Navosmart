#!/usr/bin/env python3
"""Run the production Java adapter with deterministic Android/SDK doubles.
Native SDK ABI compatibility is compiled separately against the official AAR.
"""
from pathlib import Path
import os
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
SOURCES = {
'android/content/Context.java': '''package android.content; public class Context { public Context getApplicationContext(){return this;} }''',
'android/os/Build.java': '''package android.os; public class Build { public static String MODEL="G20", DEVICE="G20", PRODUCT="G20", CPU_ABI="arm64-v8a"; }''',
'android/os/SystemClock.java': '''package android.os; public class SystemClock { public static long now=1; public static long elapsedRealtime(){return now;} }''',
'android/os/Looper.java': '''package android.os; public class Looper { public static Looper getMainLooper(){return new Looper();} }''',
'android/os/Handler.java': '''package android.os; public class Handler { public Handler(Looper l){} public boolean post(Runnable r){q.add(r);return true;} static java.util.Queue<Runnable> q=new java.util.ArrayDeque<>(); public static void drain(){while(!q.isEmpty())q.remove().run();} }''',
'org/json/JSONObject.java': '''package org.json; public class JSONObject { java.util.Map<String,Object> map=new java.util.LinkedHashMap<>(); public JSONObject put(String k,Object v){map.put(k,v);return this;} public String toString(){return map.toString();} }''',
'com/skydroid/rcsdk/common/error/SkyException.java': '''package com.skydroid.rcsdk.common.error; public class SkyException extends Exception {private static final long serialVersionUID=1L;}''',
'com/skydroid/rcsdk/SDKManagerCallBack.java': '''package com.skydroid.rcsdk; import com.skydroid.rcsdk.common.error.SkyException; public interface SDKManagerCallBack { void onRcConnected();void onRcDisconnect();void onRcConnectFail(SkyException e); }''',
'com/skydroid/rcsdk/comm/CommListener.java': '''package com.skydroid.rcsdk.comm; import com.skydroid.rcsdk.common.error.SkyException; public interface CommListener {void onConnectSuccess();void onDisconnect();void onConnectFail(SkyException e);void onReadData(byte[] d);}''',
'com/skydroid/rcsdk/common/pipeline/Pipeline.java': '''package com.skydroid.rcsdk.common.pipeline; import com.skydroid.rcsdk.comm.CommListener; public class Pipeline { public CommListener listener; public int writes; public boolean throwWrite; public byte[] last; public void setOnCommListener(CommListener l){listener=l;} public void writeData(byte[] b){if(throwWrite)throw new IllegalStateException("write failure");writes++;last=b.clone();} }''',
'com/skydroid/rcsdk/PipelineManager.java': '''package com.skydroid.rcsdk; import com.skydroid.rcsdk.common.pipeline.Pipeline; public class PipelineManager {public static final PipelineManager INSTANCE=new PipelineManager(); public Pipeline pipeline;public int creates,connects,stops; public Pipeline createG12G20Pipeline(){creates++;return pipeline=new Pipeline();} public void connectPipeline(Pipeline p){connects++;} public void disconnectPipeline(Pipeline p){stops++;} }''',
'com/skydroid/rcsdk/RCSDKManager.java': '''package com.skydroid.rcsdk; import android.content.Context; public class RCSDKManager {public static final RCSDKManager INSTANCE=new RCSDKManager();public SDKManagerCallBack callback;public int inits,connects,stops;public void initSDK(Context c,SDKManagerCallBack cb){inits++;callback=cb;} public void connectToRC(){connects++;}public void disconnectRC(){stops++;} }''',
'BridgeTest.java': r'''import org.navosmart.connectivity.SkydroidBridge; import com.skydroid.rcsdk.*; import com.skydroid.rcsdk.common.pipeline.Pipeline; import android.os.*; import android.content.Context; import java.util.Arrays;
public class BridgeTest {
 static void check(boolean b,String m){if(!b)throw new AssertionError(m);}
 static void ready(){RCSDKManager.INSTANCE.callback.onRcConnected();Handler.drain();PipelineManager.INSTANCE.pipeline.listener.onConnectSuccess();}
 public static void main(String[] a){
  Context c=new Context(); Build.MODEL="phone";Build.DEVICE="phone";Build.PRODUCT="phone";
  check(SkydroidBridge.start(c,false)==0,"non-G20 auto start blocked");
  Build.MODEL="G20";Build.CPU_ABI="x86_64";check(SkydroidBridge.start(c,true)==0,"x86 vendor init blocked");Build.CPU_ABI="arm64-v8a";
  long id=SkydroidBridge.start(c,false);check(id>0,"G20 auto start");Handler.drain();
  check(SkydroidBridge.start(c,false)==id,"no duplicate start");check(!SkydroidBridge.write(id,new byte[]{1}),"no output before channel");
  ready();Pipeline old=PipelineManager.INSTANCE.pipeline;
  RCSDKManager.INSTANCE.callback.onRcConnected();Handler.drain();check(PipelineManager.INSTANCE.creates==1,"no duplicate pipeline on RC callback");
  byte[] rx={(byte)0xfd,2,3}; old.listener.onReadData(rx);rx[1]=99;check(Arrays.equals(SkydroidBridge.read(id),new byte[]{(byte)0xfd,2,3}),"real bytes preserved/copied");
  check(SkydroidBridge.write(id,new byte[]{4,5})&&old.writes==1,"QGC bytes forwarded once");
  old.listener.onReadData(new byte[]{8});SystemClock.now+=1001;check(SkydroidBridge.read(id).length==0,"stale backlog discarded");
  old.listener.onReadData(new byte[200000]);old.listener.onReadData(new byte[100000]);check(SkydroidBridge.read(id).length==100000,"bounded overflow drops old whole backlog");
  old.listener.onReadData(new byte[]{9});old.listener.onDisconnect();check(SkydroidBridge.read(id).length==0&&!SkydroidBridge.write(id,new byte[]{7}),"link loss clears RX and refuses output");
  old.listener.onConnectSuccess();old.throwWrite=true;check(!SkydroidBridge.write(id,new byte[]{7}),"SDK write error surfaced");check(SkydroidBridge.snapshot(id).contains("write failure"),"error diagnosis");
  SkydroidBridge.stop(id);long next=SkydroidBridge.start(c,false);Handler.drain();ready();
  check(RCSDKManager.INSTANCE.inits==1,"SDK context initialised once across sessions");
  old.listener.onReadData(new byte[]{33});old.listener.onConnectSuccess();check(SkydroidBridge.read(next).length==0,"late callback from previous generation blocked");
  SkydroidBridge.stop(id);check(SkydroidBridge.write(next,new byte[]{44}),"stale stop cannot stop new session");
  RCSDKManager.INSTANCE.callback.onRcDisconnect();check(!SkydroidBridge.write(next,new byte[]{55}),"RC loss prevents output");
  SkydroidBridge.stop(next);SkydroidBridge.stop(next);Handler.drain();check(PipelineManager.INSTANCE.stops==2,"one SDK cleanup per session");
  check(!SkydroidBridge.write(next,new byte[]{66}),"stop/replay cannot replay queued output");
  System.out.println("PASS production Skydroid bridge: G20/ABI gating, one-time init, duplex bytes, bounded/stale RX, SDK errors, link loss, stale callbacks and idempotent shutdown");
 }
}'''
}
with tempfile.TemporaryDirectory(prefix='navo-skydroid-test-') as folder:
    root = Path(folder)
    for name, text in SOURCES.items():
        path = root / name; path.parent.mkdir(parents=True, exist_ok=True);path.write_text(text)
    sources = [str(p) for p in root.rglob('*.java')]
    sources.append(str(ROOT / 'custom/android/src/org/navosmart/connectivity/SkydroidBridge.java'))
    # ECJ permits the same test on a JRE-only workstation. CI uses javac 17.
    compiler = ['java','-jar',os.environ['NAVO_ECJ'],'-17','-proc:none'] if os.getenv('NAVO_ECJ') else ['javac','--release','17']
    subprocess.run(compiler + ['-d',str(root/'classes')] + sources, check=True)
    subprocess.run(['java','-cp',str(root/'classes'),'BridgeTest'],check=True)
