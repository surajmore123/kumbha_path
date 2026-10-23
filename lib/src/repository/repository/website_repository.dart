import 'package:kumbha_path/src/constant/api_constatnt.dart';
import 'package:kumbha_path/src/models/website_models.dart';
import 'package:kumbha_path/src/network/api/website_api.dart';

/// Website data (kumbhapath.in) as typed models. Every method throws
/// [WebsiteApiException] on failure, so callers can tell "failed" from
/// "nothing published".
class WebsiteRepository {
  WebsiteRepository({WebsiteApi? api}) : _api = api ?? WebsiteApi();

  final WebsiteApi _api;

  Future<List<Announcement>> getAnnouncements() async {
    final rows = await _api.getAnnouncements();
    return [
      for (final r in rows)
        if (r is Map) Announcement.fromJson(r.cast<String, dynamic>()),
    ].where((a) => a.id.isNotEmpty && a.title.isNotEmpty).toList();
  }

  Future<List<Listing>> getListings(ListingCategory category) async {
    final page = await _api.getListings(category: category.name);
    final items = page['items'];
    if (items is! List) return const [];
    return [
      for (final raw in items)
        if (Listing.tryParse(raw) case final listing?) listing,
    ];
  }

  Future<PageContent> getPageContent(String page) async {
    final values = await _api.getPageContent(page);
    return PageContent.fromJson(values, apiBase: _api.baseUrl);
  }

  /// Photo URL for a listing's website photo id, or null.
  static String? listingImageUrl(String? photoId) {
    if (photoId == null || !RegExp(r'^[a-z0-9-]+$').hasMatch(photoId)) {
      return null;
    }
    return '${ApiConst.websiteUrl}/images/photos/$photoId.webp';
  }

  /// Opens-in-browser URL for an announcement link (absolute, or a website
  /// path like `/today`). Null for anything else.
  static Uri? announcementLink(String? link) {
    if (link == null) return null;
    final uri = Uri.tryParse(
      link.startsWith('/') ? '${ApiConst.websiteUrl}$link' : link,
    );
    if (uri == null || !(uri.scheme == 'https' || uri.scheme == 'http')) {
      return null;
    }
    return uri;
  }
}
