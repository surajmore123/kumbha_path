
import 'package:intl/intl.dart';

String formatEventDate(String? date) {
  if (date == null || date.isEmpty) return '';

  try {
    final parsedDate = DateTime.parse(date);
    return DateFormat('dd MMM yyyy').format(parsedDate);
  } catch (e) {
    return date;
  }
}

String formatEventTimeRange({
  required String? startTime,
  required String? endTime,
}) {
  if (startTime == null || endTime == null) return '';

  try {
    // Parse backend time (HH:mm:ss)
    final start = DateFormat('HH:mm:ss').parse(startTime);
    final end = DateFormat('HH:mm:ss').parse(endTime);

    // Format to 12-hour time
    final formatter = DateFormat('h a');

    return '${formatter.format(start)} to ${formatter.format(end)}';
  } catch (e) {
    return '';
  }
}
