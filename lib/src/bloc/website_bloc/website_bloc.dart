import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kumbha_path/src/bloc/website_bloc/website_event.dart';
import 'package:kumbha_path/src/bloc/website_bloc/website_state.dart';
import 'package:kumbha_path/src/constant/config.dart';
import 'package:kumbha_path/src/repository/repository/website_repository.dart';

/// Website data (announcements, listings, CMS text) from `/api/v1/`, the
/// same data the admin panel publishes to kumbhapath.in.
///
/// A refresh keeps the previous data on screen until the new data arrives;
/// a failed refresh keeps it too and only reports `failed` when there was
/// nothing to show.
class WebsiteBloc extends Bloc<WebsiteEvent, WebsiteState> {
  WebsiteBloc({WebsiteRepository? repository})
    : _repo = repository ?? websiteRepository,
      super(const WebsiteState()) {
    on<LoadAnnouncements>((e, emit) => _settle(e, _onAnnouncements(emit)));
    on<LoadListings>((e, emit) => _settle(e, _onListings(e, emit)));
    on<LoadPageContent>((e, emit) => _settle(e, _onPageContent(e, emit)));
  }

  final WebsiteRepository _repo;

  /// Completes the event's [WebsiteEvent.done] however the handler ends.
  Future<void> _settle(WebsiteEvent event, Future<void> work) async {
    try {
      await work;
    } finally {
      if (!(event.done?.isCompleted ?? true)) event.done!.complete();
    }
  }

  Future<void> _onAnnouncements(Emitter<WebsiteState> emit) async {
    final hadData = state.announcementsStatus == WebsiteStatus.ready;
    if (!hadData) {
      emit(state.copyWith(announcementsStatus: WebsiteStatus.loading));
    }
    try {
      final items = await _repo.getAnnouncements();
      emit(
        state.copyWith(
          announcementsStatus: WebsiteStatus.ready,
          announcements: items,
        ),
      );
    } catch (e) {
      debugPrint('website announcements failed: $e');
      emit(
        state.copyWith(
          announcementsStatus:
              hadData ? WebsiteStatus.ready : WebsiteStatus.failed,
        ),
      );
    }
  }

  Future<void> _onListings(LoadListings event, Emitter<WebsiteState> emit) async {
    final c = event.category;
    final hadData = state.listingsStatusOf(c) == WebsiteStatus.ready;
    if (!hadData) {
      emit(
        state.copyWith(
          listingsStatus: {...state.listingsStatus, c: WebsiteStatus.loading},
        ),
      );
    }
    try {
      final items = await _repo.getListings(c);
      emit(
        state.copyWith(
          listingsStatus: {...state.listingsStatus, c: WebsiteStatus.ready},
          listings: {...state.listings, c: items},
        ),
      );
    } catch (e) {
      debugPrint('website listings (${c.name}) failed: $e');
      emit(
        state.copyWith(
          listingsStatus: {
            ...state.listingsStatus,
            c: hadData ? WebsiteStatus.ready : WebsiteStatus.failed,
          },
        ),
      );
    }
  }

  Future<void> _onPageContent(
    LoadPageContent event,
    Emitter<WebsiteState> emit,
  ) async {
    try {
      final page = await _repo.getPageContent(event.page);
      emit(state.copyWith(content: {...state.content, event.page: page}));
    } catch (e) {
      // The app's own text stays on screen; nothing to report.
      debugPrint('website content (${event.page}) failed: $e');
    }
  }
}
