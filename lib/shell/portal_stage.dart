import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../cortex/agent_client.dart';
import '../cortex/beacon_dispatcher.dart';
import '../cortex/net_sensor.dart';
import '../cortex/vault_keeper.dart';
import 'connection_lost.dart';

// ---------------------------------------------------------------------------
// PortalStage — the WebView shell that hosts the verdict URL
// ---------------------------------------------------------------------------
// The screen is deliberately opaque about its purpose. Every fix that landed
// in gray_part_pitfalls is applied here:
//   * VPN-aware offline routing with a 700ms debounce (pitfall #3)
//   * onWebResourceError covers the native error page immediately and skips
//     the redundant DNS probe for the well-known DNS/disconnect codes
//     (pitfall #4)
//   * resizeToAvoidBottomInset:false + adjustResize + JS keyboard injection
//     with behavior:'auto' single 350ms setTimeout (webview_keyboard rule)
//   * safe-area CSS killer on onPageFinished, patched to skip re-application
//     while the on-screen keyboard is up (gray_part_pitfalls #3B)
//   * FilePicker.platform.pickFiles(...) — never the deprecated static call
//   * landscape padding respects viewPadding.left/right for camera notches
// ---------------------------------------------------------------------------

/// Pre-warm hook so PortalGate can start loading this library asynchronously
/// while attribution is still resolving.
Future<void> warmupPortalStage() async {}

class PortalStage extends StatefulWidget {
  final String entryUrl;
  final VaultKeeper vault;
  final BeaconDispatcher beacon;
  final NetSensor sensor;

  const PortalStage({
    super.key,
    required this.entryUrl,
    required this.vault,
    required this.beacon,
    required this.sensor,
  });

  @override
  State<PortalStage> createState() => _PortalStageState();
}

class _PortalStageState extends State<PortalStage>
    with WidgetsBindingObserver {
  late final WebViewController _web;
  bool _busy = true;
  bool _routingOffline = false;
  StreamSubscription<List<ConnectivityResult>>? _channelSub;
  Timer? _offlineDebounce;

  String? _lastMainUrl;
  int _redirectRetries = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _applyImmersive();

    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(agent.userAgent)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) {
          if (mounted) setState(() => _busy = true);
        },
        onPageFinished: (_) {
          if (mounted) setState(() => _busy = false);
          _redirectRetries = 0;
          _injectSafeAreaKill();
          _injectKeyboardFocusHelper();
        },
        onWebResourceError: _handleWebError,
        onNavigationRequest: _decideNavigation,
      ))
      ..enableZoom(false)
      ..loadRequest(Uri.parse(widget.entryUrl));

    _configureAndroidPlatform();

    // Warm push tap forwards to the WebView without a restart.
    widget.beacon.onWarmTap = (url) {
      if (!mounted) return;
      _web.loadRequest(Uri.parse(url));
    };

    _channelSub = widget.sensor.channelStream.listen(_onChannelChanged);
  }

  void _applyImmersive() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _applyImmersive();
  }

  // ------------------ Navigation + errors -------------------

  NavigationDecision _decideNavigation(NavigationRequest request) {
    final uri = Uri.tryParse(request.url);
    if (uri == null) return NavigationDecision.prevent;
    switch (uri.scheme) {
      case 'http':
      case 'https':
      case 'about':
      case 'data':
      case 'blob':
        if (request.isMainFrame) _lastMainUrl = request.url;
        return NavigationDecision.navigate;
      default:
        _openExternal(uri);
        return NavigationDecision.prevent;
    }
  }

  Future<void> _openExternal(Uri uri) async {
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  void _handleWebError(WebResourceError error) {
    if (error.isForMainFrame != true) return;
    final desc = error.description.toLowerCase();

    // Redirect loop mitigation (per gray guide).
    final looksLikeRedirectLoop = desc.contains('too_many_redirects') ||
        desc.contains('too many redirects') ||
        error.errorCode == -1007 ||
        error.errorCode == -9;
    if (looksLikeRedirectLoop &&
        _lastMainUrl != null &&
        _redirectRetries < 3) {
      _redirectRetries++;
      _web.loadRequest(Uri.parse(_lastMainUrl!));
      return;
    }

    // Immediately cover the black Android error page with our spinner
    // (pitfall #4).
    if (mounted) setState(() => _busy = true);

    final isDnsOrDisconnect = desc.contains('name_not_resolved') ||
        desc.contains('err_name_not_resolved') ||
        desc.contains('internet_disconnected') ||
        desc.contains('network_changed') ||
        error.errorCode == -105 ||
        error.errorCode == -106 ||
        error.errorCode == -21;

    if (isDnsOrDisconnect) {
      _routeOfflineNow();
    } else {
      _routeOfflineWithProbe();
    }
  }

  // ------------------ Connectivity handling -------------------

  void _onChannelChanged(List<ConnectivityResult> snapshot) {
    final noneAll = NetSensor.allInactive(snapshot);
    if (!noneAll) {
      _offlineDebounce?.cancel();
      return;
    }
    _offlineDebounce?.cancel();
    _offlineDebounce =
        Timer(const Duration(milliseconds: 700), _routeOfflineNow);
  }

  Future<void> _routeOfflineWithProbe() async {
    if (_routingOffline) return;
    final stillOnline = await widget.sensor.isOnline();
    if (stillOnline) return;
    _routeOfflineNow();
  }

  Future<void> _routeOfflineNow() async {
    if (_routingOffline || !mounted) return;
    _routingOffline = true;

    final currentUrl = await _web.currentUrl() ?? widget.entryUrl;
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ConnectionLostView(
          retryBuilder: (_) => PortalStage(
            entryUrl: currentUrl,
            vault: widget.vault,
            beacon: widget.beacon,
            sensor: widget.sensor,
          ),
        ),
      ),
    );
  }

  // ------------------ Android platform tuning -------------------

  void _configureAndroidPlatform() {
    if (!Platform.isAndroid) return;
    final platform = _web.platform;
    if (platform is! AndroidWebViewController) return;

    // Autoplay for videos (many affiliate sites embed intro loops).
    platform.setMediaPlaybackRequiresUserGesture(false);

    // Third-party cookies — the majority of affiliate flows depend on them.
    final cookies = AndroidWebViewCookieManager(
      AndroidWebViewCookieManagerCreationParams
          .fromPlatformWebViewCookieManagerCreationParams(
        const PlatformWebViewCookieManagerCreationParams(),
      ),
    );
    cookies.setAcceptThirdPartyCookies(platform, true);

    // <input type="file"> — always use the instance API; the static one is
    // deprecated and disappears in file_picker 6+.
    platform.setOnShowFileSelector((params) async {
      try {
        final result = await FilePicker.platform.pickFiles(
          allowMultiple: params.mode == FileSelectorMode.openMultiple,
          type: FileType.any,
          withData: false,
        );
        if (result == null) return const <String>[];
        return result.files
            .where((f) => f.path != null)
            .map((f) => Uri.file(f.path!).toString())
            .toList();
      } catch (_) {
        return const <String>[];
      }
    });
  }

  // ------------------ JS bridges -------------------

  Future<void> _injectKeyboardFocusHelper() async {
    // Pitfall #3B + webview_keyboard rule:
    //  * behavior:'auto' — never 'smooth'
    //  * single setTimeout at 350ms after focusin
    //  * visualViewport.resize fallback at 120ms for Samsung/MIUI keyboards
    const js = r'''
(function () {
  if (window.__olKbArmed) return;
  window.__olKbArmed = true;
  function editable(el) {
    if (!el) return false;
    var t = el.tagName;
    return t === 'INPUT' || t === 'TEXTAREA' || el.isContentEditable === true;
  }
  function pull() {
    var el = document.activeElement;
    if (!editable(el)) return;
    var vv = window.visualViewport;
    if (vv) {
      var box = el.getBoundingClientRect();
      var bottom = vv.offsetTop + vv.height;
      if (box.bottom > bottom - 20 || box.top < vv.offsetTop) {
        el.scrollIntoView({ behavior: 'auto', block: 'nearest' });
      }
    } else {
      el.scrollIntoView({ behavior: 'auto', block: 'nearest' });
    }
  }
  document.addEventListener('focusin', function (ev) {
    if (editable(ev.target)) setTimeout(pull, 350);
  });
  if (window.visualViewport) {
    var lastH = window.visualViewport.height;
    window.visualViewport.addEventListener('resize', function () {
      var h = window.visualViewport.height;
      if (h < lastH) setTimeout(pull, 120);
      lastH = h;
    });
  }
})();
''';
    try {
      await _web.runJavaScript(js);
    } catch (_) {}
  }

  Future<void> _injectSafeAreaKill() async {
    // The re-applier is guarded so it doesn't fire while the keyboard is up
    // (pitfall #3B). Otherwise a viewport meta swap in mid-keyframe drops
    // the WKWebView into a layout loop.
    const js = r'''
(function () {
  if (window.__olSaftyArmed) return;
  window.__olSaftyArmed = true;
  var CSS_ID = '__olSafety';
  var CSS_TEXT =
    ':root{' +
      '--safe-area-inset-top:0px!important;' +
      '--safe-area-inset-right:0px!important;' +
      '--safe-area-inset-bottom:0px!important;' +
      '--safe-area-inset-left:0px!important;' +
      '--sat:0px!important;--sar:0px!important;' +
      '--sab:0px!important;--sal:0px!important;' +
    '}' +
    'html,body,#__nuxt,#__layout,#app,#root{' +
      'padding-top:0!important;' +
      'padding-left:0!important;' +
      'padding-right:0!important;' +
      'margin-top:0!important;' +
    '}';
  function keyboardOpen() {
    if (!window.visualViewport) return false;
    return window.visualViewport.height < window.innerHeight * 0.75;
  }
  function apply() {
    if (keyboardOpen()) return;
    var head = document.head || document.documentElement;
    if (!head) return;
    var m = document.querySelector('meta[name="viewport"]');
    if (m && !/viewport-fit\s*=\s*contain/i.test(m.getAttribute('content') || '')) {
      var c = (m.getAttribute('content') || '')
        .replace(/,?\s*viewport-fit\s*=\s*\w+/ig, '').trim();
      m.setAttribute('content', c + (c ? ', ' : '') + 'viewport-fit=contain');
    }
    var s = document.getElementById(CSS_ID);
    if (!s) {
      s = document.createElement('style');
      s.id = CSS_ID;
      head.appendChild(s);
    }
    if (s.textContent !== CSS_TEXT) s.textContent = CSS_TEXT;
  }
  apply();
  ['pushState', 'replaceState'].forEach(function (fn) {
    var orig = history[fn];
    history[fn] = function () {
      var r = orig.apply(this, arguments);
      setTimeout(apply, 90);
      setTimeout(apply, 420);
      return r;
    };
  });
  window.addEventListener('popstate', function () { setTimeout(apply, 90); });
  setInterval(apply, 2500);
})();
''';
    try {
      await _web.runJavaScript(js);
    } catch (_) {}
  }

  // ------------------ System back -------------------

  Future<bool> _handleBack() async {
    if (await _web.canGoBack()) {
      await _web.goBack();
    }
    return false;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _offlineDebounce?.cancel();
    _channelSub?.cancel();
    widget.beacon.onWarmTap = null;
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final landscape = mq.orientation == Orientation.landscape;

    // Landscape: keep the WebView inside the horizontal safe area so the
    // camera cutout / notch doesn't paint on top of tappable UI.
    // Portrait: only apply the status-bar height as top padding.
    final padding = landscape
        ? EdgeInsets.only(
            left: mq.viewPadding.left,
            right: mq.viewPadding.right,
          )
        : EdgeInsets.only(top: mq.viewPadding.top);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) await _handleBack();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        // CRITICAL: must stay false — Flutter must not resize while
        // Android's adjustResize + our JS injection handle the IME.
        resizeToAvoidBottomInset: false,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Padding(
              padding: padding,
              child: WebViewWidget(controller: _web),
            ),
            if (_busy)
              const ColoredBox(
                color: Color(0xB0000814),
                child: Center(
                  child: CircularProgressIndicator(
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Color(0xFFFFD873)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
