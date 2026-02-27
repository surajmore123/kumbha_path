
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


class DateTimeHelper {
  static String formatAlertTime(String? isoString) {
    if (isoString == null || isoString.isEmpty) return "";

    try {
      final dateTime = DateTime.parse(isoString).toLocal();
      final now = DateTime.now();

      final isToday =
          now.year == dateTime.year &&
          now.month == dateTime.month &&
          now.day == dateTime.day;

      final isYesterday =
          now.subtract(const Duration(days: 1)).year == dateTime.year &&
          now.subtract(const Duration(days: 1)).month == dateTime.month &&
          now.subtract(const Duration(days: 1)).day == dateTime.day;

      if (isToday) {
        return "Today • ${DateFormat.jm().format(dateTime)}";
      } else if (isYesterday) {
        return "Yesterday • ${DateFormat.jm().format(dateTime)}";
      } else {
        return "${DateFormat('dd MMM yyyy').format(dateTime)} • ${DateFormat.jm().format(dateTime)}";
      }
    } catch (e) {
      return isoString;
    }
  }
}
