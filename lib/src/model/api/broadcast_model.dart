/// A broadcast message (admin push / announcement) shown in the notifications
/// list. Mirrors the backend `broadcast_messages` table exposed via
/// `GET /broadcasts` (list) and `GET /broadcast/{id}` (one).
///
/// The backend already localizes `title`/`body` via the `Accept-Language`
/// header, but the row can also carry a `translations` JSON blob
/// (`{ "uz": { "title": ..., "body": ... }, ... }`); [localizedTitle]/
/// [localizedBody] prefer that per-language value and fall back to the
/// top-level fields.
class BroadcastModel {
  final int id;
  final String title;
  final String body;
  final Map<String, dynamic> translations;
  final DateTime? createdAt;

  const BroadcastModel({
    required this.id,
    required this.title,
    required this.body,
    this.translations = const {},
    this.createdAt,
  });

  factory BroadcastModel.fromJson(Map<String, dynamic> json) {
    return BroadcastModel(
      id: _asInt(json['id']),
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      translations: json['translations'] is Map
          ? Map<String, dynamic>.from(json['translations'] as Map)
          : const {},
      createdAt: _asDate(json['created_at']),
    );
  }

  String localizedTitle(String lang) => _localized(lang, 'title', title);

  String localizedBody(String lang) => _localized(lang, 'body', body);

  String _localized(String lang, String key, String fallback) {
    final t = translations[lang];
    if (t is Map && t[key] != null && t[key].toString().trim().isNotEmpty) {
      return t[key].toString();
    }
    return fallback;
  }

  /// Parses a list response, tolerating a bare array, `{ data: [...] }`, or a
  /// paginated `{ data: { data: [...] } }` envelope.
  static List<BroadcastModel> listFromResult(dynamic result) {
    final payload = _unwrap(result);
    if (payload is List) {
      return payload
          .whereType<Map>()
          .map((e) => BroadcastModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return const [];
  }

  /// Parses a single-item response, tolerating a bare object or `{ data: {...} }`.
  static BroadcastModel? fromResult(dynamic result) {
    final payload = _unwrap(result);
    if (payload is Map) {
      return BroadcastModel.fromJson(Map<String, dynamic>.from(payload));
    }
    return null;
  }

  static dynamic _unwrap(dynamic result) {
    dynamic p = result;
    if (p is Map && p.containsKey('data')) p = p['data'];
    // Laravel pagination nests the rows under a second `data`.
    if (p is Map && p['data'] is List) p = p['data'];
    return p;
  }

  static int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  static DateTime? _asDate(dynamic v) {
    if (v == null) return null;
    return DateTime.tryParse(v.toString())?.toLocal();
  }
}
