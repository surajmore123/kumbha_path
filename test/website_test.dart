import 'package:flutter_test/flutter_test.dart';
import 'package:kumbha_path/src/models/website_models.dart';

void main() {
  group('Announcement.fromJson', () {
    test('reads the /api/v1/announcements shape', () {
      final a = Announcement.fromJson({
        'id': 'a1',
        'title': ' Ramkund ghat closed ',
        'body': 'Use Gandhi Talav ghat.',
        'link': '/today',
        'kind': 'alert',
        'pinned': true,
        'published': true,
        'starts_on': '2026-10-20',
        'ends_on': null,
        'created_at': '2026-10-20T04:30:00Z',
        'updated_at': '2026-10-20T04:30:00Z',
      });
      expect(a.title, 'Ramkund ghat closed');
      expect(a.kind, AnnouncementKind.alert);
      expect(a.pinned, isTrue);
      expect(a.link, '/today');
      expect(a.startsOn, DateTime(2026, 10, 20));
      expect(a.endsOn, isNull);
      expect(a.createdAt, isNotNull);
    });

    test('unknown kind and missing fields fall back safely', () {
      final a = Announcement.fromJson({'id': 'x', 'title': 'T', 'kind': 9});
      expect(a.kind, AnnouncementKind.info);
      expect(a.body, isNull);
      expect(a.pinned, isFalse);
    });
  });

  group('Listing.tryParse', () {
    test('reads the /api/v1/listings item shape', () {
      final l = Listing.tryParse({
        'id': 'l1',
        'category': 'hotels',
        'name': 'Panchavati Dharamshala',
        'type': 'Dharamshala',
        'town': 'Nashik',
        'area': 'Panchavati',
        'price_from': 800,
        'unit': 'night',
        'highlights': ['Near Ramkund', '', 7],
        'distance': '1 km to Ramkund',
        'duration': null,
        'trust': 'official',
        'wheelchair': true,
        'image': 'ramkund',
        'is_sample': false,
        'source': 'internal',
      })!;
      expect(l.category, ListingCategory.hotels);
      expect(l.priceFrom, 800);
      expect(l.highlights, ['Near Ramkund']);
      expect(l.official, isTrue);
      expect(l.wheelchair, isTrue);
      expect(l.image, 'ramkund');
      expect(l.duration, isNull);
    });

    test('skips rows without id, name or a known category', () {
      expect(Listing.tryParse({'id': 'a', 'name': 'n'}), isNull);
      expect(Listing.tryParse({'category': 'cabs', 'name': 'n'}), isNull);
      expect(Listing.tryParse('not a map'), isNull);
    });
  });

  group('PageContent', () {
    test('edited text wins, otherwise the fallback', () {
      final c = PageContent.fromJson({
        'home.services.title': 'Find a stay',
        'home.services.subtitle': '   ',
      });
      expect(c.text('home.services.title', 'default'), 'Find a stay');
      expect(c.text('home.services.subtitle', 'default'), 'default');
    });

    test('images resolve only for /media/ paths', () {
      final c = PageContent.fromJson({
        'home.hero.image': '/media/abc.webp',
        'home.today.image': 'https://evil.example/x.png',
      }, apiBase: 'https://api.kumbhapath.in/api/v1');
      expect(
        c.image('home.hero.image'),
        'https://api.kumbhapath.in/api/v1/media/abc.webp',
      );
      expect(c.image('home.today.image'), isNull);
      expect(c.image('missing'), isNull);
    });

    test('non-map body is empty', () {
      expect(PageContent.fromJson(['x']), PageContent.empty);
    });
  });
}
