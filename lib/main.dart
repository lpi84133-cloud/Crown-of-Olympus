import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'cortex/agent_client.dart';
import 'cortex/attribution_seer.dart';
import 'cortex/beacon_dispatcher.dart';
import 'cortex/net_sensor.dart';
import 'cortex/vault_keeper.dart';
import 'cortex/verdict_gateway.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Firebase + AppCheck ──────────────────────────────────────────────────
  // Both calls are best-effort so an in-progress project (no
  // google-services.json yet) still boots into the offline game.
  try {
    await Firebase.initializeApp();
    await FirebaseAppCheck.instance.activate(
      androidProvider: kDebugMode
          ? AndroidProvider.debug
          : AndroidProvider.playIntegrity,
    );
  } catch (_) {}

  // Splash tolerates both orientations; PortalGate rewires this per route.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  // ── Cortex wiring ────────────────────────────────────────────────────────
  await agent.prepare();

  final vault = VaultKeeper();
  await vault.boot();

  final sensor = NetSensor();
  final seer = AttributionSeer();
  final gateway = VerdictGateway(vault);
  final beacon = BeaconDispatcher(vault);

  runApp(CrownOfOlympusRoot(
    vault: vault,
    sensor: sensor,
    seer: seer,
    gateway: gateway,
    beacon: beacon,
  ));
}
