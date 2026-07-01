// ---------------------------------------------------------------------------
// PortalReply — decoded response from the verdict endpoint
// ---------------------------------------------------------------------------
// Wire format (application/json):
//   { "ok": true,  "url": "https://...", "expires": 1700000000 }
//   { "ok": false, "message": "organic" }
// ---------------------------------------------------------------------------

class PortalReply {
  final bool ok;
  final String? url;
  final int? expires;
  final String? note;

  const PortalReply({
    required this.ok,
    this.url,
    this.expires,
    this.note,
  });

  factory PortalReply.fromJson(Map<String, dynamic> json) {
    return PortalReply(
      ok: json['ok'] == true,
      url: (json['url'] as String?)?.trim().isNotEmpty == true
          ? (json['url'] as String).trim()
          : null,
      expires: (json['expires'] is int)
          ? json['expires'] as int
          : int.tryParse('${json['expires']}'),
      note: json['message'] as String?,
    );
  }

  factory PortalReply.failure(String reason) =>
      PortalReply(ok: false, note: reason);

  bool get hasUrl => (url ?? '').isNotEmpty;
}
