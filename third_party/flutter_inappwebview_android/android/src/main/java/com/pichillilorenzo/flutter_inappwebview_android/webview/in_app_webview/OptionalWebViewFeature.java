package com.pichillilorenzo.flutter_inappwebview_android.webview.in_app_webview;

/** Only suppresses an explicitly unsupported optional WebView operation. */
final class OptionalWebViewFeature {
  interface ReadBoolean {
    boolean read();
  }

  interface OnUnsupported {
    void report(UnsupportedOperationException exception);
  }

  static void apply(Runnable operation, OnUnsupported onUnsupported) {
    try {
      operation.run();
    } catch (UnsupportedOperationException exception) {
      onUnsupported.report(exception);
    }
  }

  // null means unknown, not the requested value or a fabricated supported value.
  static Boolean read(ReadBoolean operation, OnUnsupported onUnsupported) {
    try {
      return operation.read();
    } catch (UnsupportedOperationException exception) {
      onUnsupported.report(exception);
      return null;
    }
  }

  private OptionalWebViewFeature() {}
}
