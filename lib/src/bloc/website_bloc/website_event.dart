import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:kumbha_path/src/models/website_models.dart';

abstract class WebsiteEvent extends Equatable {
  const WebsiteEvent({this.done});

  /// Completed when the request finishes (success or failure), so
  /// pull-to-refresh can stop even when the data didn't change.
  final Completer<void>? done;

  @override
  List<Object?> get props => [];
}

/// Loads the admin announcements shown on the website's Today / Home pages.
class LoadAnnouncements extends WebsiteEvent {
  const LoadAnnouncements({super.done});
}

/// Loads published listings for one category.
class LoadListings extends WebsiteEvent {
  const LoadListings(this.category, {super.done});

  final ListingCategory category;

  @override
  List<Object?> get props => [category];
}

/// Loads the edited CMS values for one website page (e.g. `home`).
class LoadPageContent extends WebsiteEvent {
  const LoadPageContent(this.page, {super.done});

  final String page;

  @override
  List<Object?> get props => [page];
}

/// Adds [event] built with a fresh completer and waits for it to finish.
Future<void> loadAndWait(
  void Function(WebsiteEvent) add,
  WebsiteEvent Function(Completer<void> done) build,
) {
  final done = Completer<void>();
  add(build(done));
  return done.future;
}
