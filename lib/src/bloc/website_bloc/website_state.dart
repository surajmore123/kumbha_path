import 'package:equatable/equatable.dart';
import 'package:kumbha_path/src/models/website_models.dart';

/// Load state of one section. Every section keeps its own, so loading
/// listings never shows the announcements as loading (or failed).
enum WebsiteStatus { initial, loading, ready, failed }

class WebsiteState extends Equatable {
  const WebsiteState({
    this.announcementsStatus = WebsiteStatus.initial,
    this.announcements = const [],
    this.listingsStatus = const {},
    this.listings = const {},
    this.content = const {},
  });

  final WebsiteStatus announcementsStatus;
  final List<Announcement> announcements;

  final Map<ListingCategory, WebsiteStatus> listingsStatus;
  final Map<ListingCategory, List<Listing>> listings;

  /// Loaded CMS pages. A page that failed to load is simply absent, and the
  /// app shows its own text.
  final Map<String, PageContent> content;

  WebsiteStatus listingsStatusOf(ListingCategory c) =>
      listingsStatus[c] ?? WebsiteStatus.initial;

  List<Listing> listingsOf(ListingCategory c) => listings[c] ?? const [];

  PageContent page(String id) => content[id] ?? PageContent.empty;

  WebsiteState copyWith({
    WebsiteStatus? announcementsStatus,
    List<Announcement>? announcements,
    Map<ListingCategory, WebsiteStatus>? listingsStatus,
    Map<ListingCategory, List<Listing>>? listings,
    Map<String, PageContent>? content,
  }) {
    return WebsiteState(
      announcementsStatus: announcementsStatus ?? this.announcementsStatus,
      announcements: announcements ?? this.announcements,
      listingsStatus: listingsStatus ?? this.listingsStatus,
      listings: listings ?? this.listings,
      content: content ?? this.content,
    );
  }

  @override
  List<Object?> get props => [
    announcementsStatus,
    announcements,
    listingsStatus,
    listings,
    content,
  ];
}
