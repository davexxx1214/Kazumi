package com.pichillilorenzo.flutter_inappwebview_android.webview.in_app_webview;

import android.util.Log;
import androidx.test.platform.app.InstrumentationRegistry;
import com.pichillilorenzo.flutter_inappwebview_android.InAppWebViewFlutterPlugin;
import com.pichillilorenzo.flutter_inappwebview_android.webview.WebViewChannelDelegate;
import com.pichillilorenzo.flutter_inappwebview_android.types.WebResourceErrorExt;
import com.pichillilorenzo.flutter_inappwebview_android.types.WebResourceRequestExt;
import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodChannel;
import java.nio.ByteBuffer;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicReference;
import org.junit.Test;
import static org.junit.Assert.*;

/** Exercises the real plugin client and channel error serialization, without an Activity. */
public class WebViewErrorDeviceTest {
  @Test public void failedMainFrameAndSubresourceThenJavascriptExtraction() throws Exception {
    InAppWebView[] view = {null};
    CountDownLatch mainError = new CountDownLatch(1), resourceError = new CountDownLatch(1);
    CountDownLatch extracted = new CountDownLatch(1), failedPageFinished = new CountDownLatch(1);
    AtomicReference<String> source = new AtomicReference<>();
    try {
      InstrumentationRegistry.getInstrumentation().runOnMainSync(() -> {
        InAppWebView w = new InAppWebView(InstrumentationRegistry.getInstrumentation().getTargetContext());
        view[0] = w;
        w.plugin = new InAppWebViewFlutterPlugin();
        w.plugin.applicationContext = w.getContext();
        BinaryMessenger messenger = new BinaryMessenger() {
          public void send(String channel, ByteBuffer message) {}
          public void send(String channel, ByteBuffer message, BinaryReply callback) {
            if (callback != null) callback.reply(null);
          }
          public void setMessageHandler(String channel, BinaryMessageHandler handler) {}
        };
        w.channelDelegate = new WebViewChannelDelegate(w, new MethodChannel(messenger, "test")) {
          @Override public void onReceivedError(WebResourceRequestExt request, WebResourceErrorExt error) {
            assertTrue(error.getType() < 0);
            assertFalse(error.getDescription().isEmpty());
            Log.i("KazumiErrorTest", "ERROR main=" + request.isForMainFrame() + " " + error);
            if (request.isForMainFrame()) mainError.countDown(); else resourceError.countDown();
          }
          @Override public void onLoadStop(String url) {
            Log.i("KazumiErrorTest", "LOAD STOP " + url);
            if (url.contains("missing-main")) failedPageFinished.countDown();
          }
        };
        w.prepare();
        Log.i("KazumiErrorTest", "client=" + w.getWebViewClient().getClass().getSimpleName());
        w.loadUrl("http://127.0.0.1:1/missing-main");
      });
      assertTrue("main error callback", mainError.await(20, TimeUnit.SECONDS));
      assertTrue("failed page finishes", failedPageFinished.await(20, TimeUnit.SECONDS));
      InstrumentationRegistry.getInstrumentation().runOnMainSync(() -> view[0].loadDataWithBaseURL(
          "https://fixture.invalid/", "<html><body><img src='http://127.0.0.1:1/missing-image'>"
          + "<video preload='none' src='https://fixture.invalid/video.m3u8'></video></body></html>", "text/html", "UTF-8", null));
      assertTrue("resource error callback", resourceError.await(20, TimeUnit.SECONDS));
      // A failed resource need not produce a second onPageFinished on every
      // provider. Verify the parser's JS operation against the real plugin client.
      for (int attempt = 0; attempt < 20 && extracted.getCount() > 0; attempt++) {
        InstrumentationRegistry.getInstrumentation().runOnMainSync(() -> view[0].evaluateJavascript(
            "document.querySelector('video')?.getAttribute('src')", value -> {
              if (value != null && value.contains("video.m3u8")) { source.set(value); extracted.countDown(); }
            }));
        extracted.await(250, TimeUnit.MILLISECONDS);
      }
      assertEquals("JavaScript still executes after load errors", 0, extracted.getCount());
      assertEquals("\"https://fixture.invalid/video.m3u8\"", source.get());
      Log.i("KazumiErrorTest", "PASS: main/subresource errors and subsequent JS extraction");
    } finally {
      InstrumentationRegistry.getInstrumentation().runOnMainSync(() -> {
        if (view[0] != null) { view[0].channelDelegate.dispose(); view[0].destroy(); }
      });
    }
  }
}
