"""Execute the actual Java adapter with SDK/Android doubles. No camera or radio I/O."""
from pathlib import Path
import tempfile,subprocess,shutil,os
repo=Path(__file__).resolve().parents[2]
stubs={
'android/content/Context.java':'package android.content; public class Context {}',
'android/R.java':'package android; public class R {public static class id {public static int content=1;}}',
'android/app/Activity.java':'package android.app; public class Activity extends android.content.Context {public android.widget.FrameLayout root=new android.widget.FrameLayout(this); @SuppressWarnings("unchecked") public <T extends android.view.View>T findViewById(int id){return (T)root;}}',
'android/os/Build.java':'package android.os; public class Build {public static String CPU_ABI="arm64-v8a";}',
'android/os/Looper.java':'package android.os; public class Looper {public static Looper getMainLooper(){return new Looper();}}',
'android/os/SystemClock.java':'package android.os; public class SystemClock {public static long elapsedRealtime(){return 5000;}}',
'android/os/Handler.java':'package android.os; public class Handler {public Handler(Looper l){} static java.util.Queue<Runnable> q=new java.util.ArrayDeque<>();public boolean post(Runnable r){q.add(r);return true;}public static void drain(){while(!q.isEmpty())q.remove().run();}}',
'android/graphics/Rect.java':'package android.graphics; public class Rect {public Rect(int a,int b,int c,int d){}}',
'android/view/MotionEvent.java':'package android.view; public class MotionEvent {public static int ACTION_UP=1;public int getAction(){return ACTION_UP;}}',
'android/view/View.java':'''package android.view; public class View {public static int INVISIBLE=4,VISIBLE=0;Object parent;public View(android.content.Context c){} public interface OnTouchListener{boolean onTouch(View v,MotionEvent e);}public OnTouchListener touch;public void setOnTouchListener(OnTouchListener l){touch=l;}public boolean performClick(){return true;}public Object getParent(){return parent;}public void setLayoutParams(Object p){} public void setVisibility(int v){} public void setClipBounds(android.graphics.Rect r){} public void getLocationOnScreen(int[] a){a[0]=0;a[1]=0;}}''',
'android/view/ViewGroup.java':'''package android.view;public class ViewGroup extends View {public java.util.List<View> children=new java.util.ArrayList<>();public ViewGroup(android.content.Context c){super(c);}public void addView(View v,Object p){children.add(v);v.parent=this;}public void removeView(View v){children.remove(v);v.parent=null;}}''',
'android/widget/FrameLayout.java':'package android.widget;public class FrameLayout extends android.view.ViewGroup {public FrameLayout(android.content.Context c){super(c);}public void setClipChildren(boolean c){}public static class LayoutParams {public int leftMargin,topMargin;public LayoutParams(int w,int h){}}}',
'org/json/JSONObject.java':'package org.json;public class JSONObject {java.util.Map<String,Object> data=new java.util.LinkedHashMap<>();public JSONObject put(String k,Object v){data.put(k,v);return this;}public String toString(){return data.toString();}}',
'com/skydroid/rcsdk/utils/RCSDKUtils.java':'package com.skydroid.rcsdk.utils;public class RCSDKUtils {public static RCSDKUtils getDeviceType(){return new RCSDKUtils();}public int getValue(){return 20;}}',
'com/skydroid/fpvplayer/ffmpeg/FrameInfo.java':'package com.skydroid.fpvplayer.ffmpeg;public class FrameInfo {}',
'com/skydroid/fpvplayer/PlayerType.java':'package com.skydroid.fpvplayer;public enum PlayerType {ONLY_SKY}',
'com/skydroid/fpvplayer/RtspTransport.java':'package com.skydroid.fpvplayer;public enum RtspTransport {AUTO,TCP,UDP}',
'com/skydroid/fpvplayer/ReConnectInterceptor.java':'package com.skydroid.fpvplayer;public interface ReConnectInterceptor {boolean execReConnect();}',
'com/skydroid/fpvplayer/OnPlayerStateListener.java':'package com.skydroid.fpvplayer;public interface OnPlayerStateListener {void onConnected();void onDisconnect();void onReadFrame(com.skydroid.fpvplayer.ffmpeg.FrameInfo f);}',
'com/skydroid/fpvplayer/VideoDecoderCallBack.java':'package com.skydroid.fpvplayer;public interface VideoDecoderCallBack {void onYUV(java.nio.ByteBuffer b,int w,int h,int f);}',
'com/skydroid/fpvplayer/FPVWidget.java':'''package com.skydroid.fpvplayer;public class FPVWidget extends android.widget.FrameLayout {public static FPVWidget last;public static int creates,starts,stops;public ReConnectInterceptor reconnect;public boolean hardware;public RtspTransport transport;public String url;public OnPlayerStateListener listener;public VideoDecoderCallBack decoder;public FPVWidget(android.content.Context c){super(c);last=this;creates++;}public void setReConnectInterceptor(ReConnectInterceptor r){reconnect=r;}public void setPlayerType(PlayerType t){}public void setUsingMediaCodec(boolean b){hardware=b;}public void setRtspTranstype(RtspTransport t){transport=t;}public void setRcType(int n){}public void setShowInfo(boolean b){}public void setUrl(String s){url=s;}public void setOnPlayerStateListener(OnPlayerStateListener l){listener=l;}public void setVideoDecoderCallBack(VideoDecoderCallBack c){decoder=c;}public void start(){starts++;}public void stop(){stops++;}}''',
'Test.java':'''import org.navosmart.video.SkydroidVideoBridge;import com.skydroid.fpvplayer.*;import android.os.*;import android.app.Activity;public class Test {
static void check(boolean b){if(!b)throw new AssertionError();}
public static void main(String[] args){Activity a=new Activity();
Build.CPU_ABI="x86_64";check(SkydroidVideoBridge.start(a,"rtsp://camera",true,"tcp",true)==0);Build.CPU_ABI="arm64-v8a";
long cancelled=SkydroidVideoBridge.start(a,"rtsp://camera",true,"tcp",true);SkydroidVideoBridge.stop(cancelled);Handler.drain();check(FPVWidget.creates==0 && a.root.children.isEmpty());
long id=SkydroidVideoBridge.start(a,"rtsp://camera/stream",false,"udp",true);Handler.drain();FPVWidget p=FPVWidget.last;
check(!p.hardware && p.transport==RtspTransport.UDP && FPVWidget.starts==1 && a.root.children.size()==1);
OnPlayerStateListener late=p.listener;VideoDecoderCallBack old=p.decoder;p.listener.onConnected();check(SkydroidVideoBridge.snapshot(id).contains("age=-1"));
p.listener.onReadFrame(null);check(SkydroidVideoBridge.snapshot(id).contains("frames=0"));
p.decoder.onYUV(java.nio.ByteBuffer.allocate(8),640,360,0);check(SkydroidVideoBridge.snapshot(id).contains("frames=1"));check(SkydroidVideoBridge.snapshot(id).contains("age=0"));
p.listener.onDisconnect();check(SkydroidVideoBridge.snapshot(id).contains("age=-1"));
SkydroidVideoBridge.rect(id,10,20,320,180,0,0,320,180);Handler.drain();
SkydroidVideoBridge.stop(id);check(!p.reconnect.execReConnect());late.onConnected();old.onYUV(java.nio.ByteBuffer.allocate(8),640,360,0);Handler.drain();
check(a.root.children.isEmpty() && FPVWidget.stops==1 && SkydroidVideoBridge.snapshot(id).equals("{}"));
long hw=SkydroidVideoBridge.start(a,"rtsp://camera/stream",true,"tcp",true);Handler.drain();check(FPVWidget.last.hardware && FPVWidget.last.transport==RtspTransport.TCP);SkydroidVideoBridge.stop(hw);Handler.drain();check(a.root.children.isEmpty());
System.out.println("PASS actual FPV adapter: decoder/transport forwarding, queued start cancellation, decoded-only freshness, late callbacks, removal and HW/SW reopen");}}
'''
}
with tempfile.TemporaryDirectory() as directory:
 root=Path(directory)
 for name,text in stubs.items():
  p=root/name;p.parent.mkdir(parents=True,exist_ok=True);p.write_text(text)
 source=repo/'custom/android/src/org/navosmart/video/SkydroidVideoBridge.java'
 javac=shutil.which('javac')
 compiler=[javac] if javac else ['/usr/lib/jvm/java-17-openjdk-amd64/bin/java','-m','jdk.compiler/com.sun.tools.javac.Main']
 subprocess.run(compiler+['-d',str(root/'out')]+[str(p) for p in root.rglob('*.java')]+[str(source)],check=True)
 java=shutil.which('java') or '/usr/lib/jvm/java-17-openjdk-amd64/bin/java'
 subprocess.run([java,'-cp',str(root/'out'),'Test'],check=True)
