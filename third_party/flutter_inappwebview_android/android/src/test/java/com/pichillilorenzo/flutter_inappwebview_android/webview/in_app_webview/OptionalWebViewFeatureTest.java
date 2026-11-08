package com.pichillilorenzo.flutter_inappwebview_android.webview.in_app_webview;

import org.junit.Test;
import static org.junit.Assert.*;

public class OptionalWebViewFeatureTest {
  @Test public void supportedProviderKeepsBothSettingValues() {
    for (boolean requested : new boolean[] {false, true}) {
      boolean[] value = {!requested};
      OptionalWebViewFeature.apply(() -> value[0] = requested,
          exception -> fail("Supported provider must not fall back"));
      assertEquals(requested, value[0]);
      assertEquals(Boolean.valueOf(requested), OptionalWebViewFeature.read(
          () -> value[0], exception -> fail("Supported getter must not fall back")));
    }
  }

  @Test public void unsupportedSetterDoesNotAbortInitializationOrUpdates() {
    for (int attempt = 0; attempt < 2; attempt++) {
      UnsupportedOperationException failure = new UnsupportedOperationException("provider");
      Throwable[] reported = {null};
      OptionalWebViewFeature.apply(() -> { throw failure; }, e -> reported[0] = e);
      assertSame(failure, reported[0]);
    }
  }

  @Test public void unsupportedGetterReturnsUnknown() {
    int[] warnings = {0};
    assertNull(OptionalWebViewFeature.read(
        () -> { throw new UnsupportedOperationException(); }, e -> warnings[0]++));
    assertEquals(1, warnings[0]);
  }

  @Test public void unrelatedFailuresStillPropagate() {
    IllegalStateException failure = new IllegalStateException("unexpected");
    assertSame(failure, assertThrows(IllegalStateException.class,
        () -> OptionalWebViewFeature.apply(() -> { throw failure; }, e -> fail())));
    assertSame(failure, assertThrows(IllegalStateException.class,
        () -> OptionalWebViewFeature.read(() -> { throw failure; }, e -> fail())));
  }

  @Test public void failingProviderDoesNotDisableAnotherProvider() {
    OptionalWebViewFeature.apply(() -> { throw new UnsupportedOperationException(); }, e -> {});
    boolean[] called = {false};
    OptionalWebViewFeature.apply(() -> called[0] = true, e -> fail());
    assertTrue(called[0]);
    assertEquals(Boolean.TRUE, OptionalWebViewFeature.read(() -> true, e -> fail()));
  }
}
