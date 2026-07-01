import 'package:flutter/material.dart';

import 'cortex/attribution_seer.dart';
import 'cortex/beacon_dispatcher.dart';
import 'cortex/net_sensor.dart';
import 'cortex/vault_keeper.dart';
import 'cortex/verdict_gateway.dart';
import 'shell/portal_gate.dart';
import 'ui/theme.dart';

/// Root MaterialApp — no `home:` deep-link surface, just a single Navigator
/// with the [PortalGate] as its entry point.
class CrownOfOlympusRoot extends StatelessWidget {
  final VaultKeeper vault;
  final NetSensor sensor;
  final AttributionSeer seer;
  final VerdictGateway gateway;
  final BeaconDispatcher beacon;

  const CrownOfOlympusRoot({
    super.key,
    required this.vault,
    required this.sensor,
    required this.seer,
    required this.gateway,
    required this.beacon,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Crown of Olympus',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(),
      home: PortalGate(
        vault: vault,
        sensor: sensor,
        seer: seer,
        gateway: gateway,
        beacon: beacon,
      ),
    );
  }
}
