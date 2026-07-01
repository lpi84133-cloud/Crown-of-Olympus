import 'dart:convert';

import '../boot/crest_config.dart';
import '../verdict/portal_reply.dart';
import 'agent_client.dart';
import 'vault_keeper.dart';

// ---------------------------------------------------------------------------
// VerdictGateway — POST the attribution payload, cache the reply
// ---------------------------------------------------------------------------
// Contract with the backend:
//   POST { verdict URL }
//   headers: Content-Type: application/json
//   body:    full attribution + device dict
//   answer:  { ok, url?, expires?, message? }
//
// Behaviours per TZ:
//   * Any non-200 or timeout becomes a soft failure — the caller falls back
//     to the cached URL if one exists.
//   * A fresh ok:true reply replaces the cache (per gray_resume_recheck: the
//     backend rotates the landing URL, we must never freeze it).
//   * A cached URL that has expired is still preferable to a blank screen
//     when the network round-trip fails.
// ---------------------------------------------------------------------------

class VerdictGateway {
  final VaultKeeper _vault;

  VerdictGateway(this._vault);

  static const Duration _timeout = Duration(seconds: 15);

  Future<PortalReply> ask(Map<String, dynamic> payload) async {
    final endpoint = CrestConfig.verdictEndpoint;
    if (endpoint.isEmpty) {
      return PortalReply.failure('verdict endpoint missing');
    }

    try {
      final response = await agent
          .post(
            Uri.parse(endpoint),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(_timeout);

      if (response.statusCode != 200) {
        return PortalReply.failure('http ${response.statusCode}');
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final reply = PortalReply.fromJson(decoded);

      if (reply.ok && reply.hasUrl) {
        await _vault.writeVerdictUrl(reply.url!);
        if (reply.expires != null) {
          await _vault.writeExpires(reply.expires!);
        }
      }
      return reply;
    } catch (e) {
      return PortalReply.failure(e.toString());
    }
  }

  Future<String?> cachedUrl() => _vault.readVerdictUrl();
}
