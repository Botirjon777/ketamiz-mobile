import 'dart:ui';

import 'package:flutter_translate/flutter_translate.dart';

class Utils {
  /// Localized "Sat, 8 June" style format for the search date chip.
  /// Date only — the trip search filters by day, not time.
  static String searchDateFormat(DateTime t) {
    final wd = translate('date.wd_${t.weekday}');
    final month = translate('date.m_${t.month}');
    return '$wd, ${t.day} $month';
  }

  /// 24h "HH:mm" format used on trip cards.
  static String timeFormat(DateTime t) {
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  /// Localized "8 June" day+month format shown next to trip times.
  static String dateFormat(DateTime t) {
    return '${t.day} ${translate('date.m_${t.month}')}';
  }

  /// Parses a hex color string (e.g. "#FF0000", "FF0000", "AARRGGBB") into a
  /// [Color]. Returns [fallback] when the value is empty or unparseable.
  static Color colorFromHex(String code,
      {Color fallback = const Color(0xFFCBD5E1)}) {
    var hex = code.trim().replaceAll('#', '');
    if (hex.isEmpty) return fallback;
    if (hex.length == 6) hex = 'FF$hex';
    if (hex.length != 8) return fallback;
    final value = int.tryParse(hex, radix: 16);
    return value == null ? fallback : Color(value);
  }

  static String tripDateFormat(DateTime time) {
    String month = '';
    time.month == 1
        ? month = 'January'
        : time.month == 2
            ? month = 'February'
            : time.month == 3
                ? month = 'March'
                : time.month == 4
                    ? month = 'April'
                    : time.month == 5
                        ? month = 'May'
                        : time.month == 6
                            ? month = 'June'
                            : time.month == 7
                                ? month = 'July'
                                : time.month == 8
                                    ? month = 'August'
                                    : time.month == 9
                                        ? month = 'September'
                                        : time.month == 10
                                            ? month = 'October'
                                            : time.month == 11
                                                ? month = 'November'
                                                : month = 'December';

    String hourFormat = time.hour >= 12 ? 'pm' : 'am';

    String hour = '';
    if (time.hour == 0) {
      hour = '12';
    } else if (time.hour > 12) {
      hour = (time.hour - 12).toString();
    } else {
      hour = time.hour.toString();
    }

    return "$month ${time.day.toString()} at $hour:${time.minute} $hourFormat";
  }

  static String scheduleDateFormat(DateTime time) {
    String weekDay = '';
    String month = '';
    time.weekday == 1
        ? weekDay = 'Monday'
        : time.weekday == 2
            ? weekDay = 'Tuesday'
            : time.weekday == 3
                ? weekDay = 'Wednesday'
                : time.weekday == 4
                    ? weekDay = 'Thursday'
                    : time.weekday == 5
                        ? weekDay = 'Friday'
                        : time.weekday == 6
                            ? weekDay = 'Saturday'
                            : weekDay = 'Sunday';

    time.month == 1
        ? month = 'Jan'
        : time.month == 2
            ? month = 'Feb'
            : time.month == 3
                ? month = 'March'
                : time.month == 4
                    ? month = 'Apr'
                    : time.month == 5
                        ? month = 'May'
                        : time.month == 6
                            ? month = 'June'
                            : time.month == 7
                                ? month = 'July'
                                : time.month == 8
                                    ? month = 'Aug'
                                    : time.month == 9
                                        ? month = 'Sep'
                                        : time.month == 10
                                            ? month = 'Oct'
                                            : time.month == 11
                                                ? month = 'Nov'
                                                : month = 'Dec';

    return '$weekDay, $month ${time.day}';
  }

  static String historyDateFormat(DateTime time) {
    String month = '';

    time.month == 1
        ? month = 'Jan'
        : time.month == 2
            ? month = 'Feb'
            : time.month == 3
                ? month = 'March'
                : time.month == 4
                    ? month = 'Apr'
                    : time.month == 5
                        ? month = 'May'
                        : time.month == 6
                            ? month = 'June'
                            : time.month == 7
                                ? month = 'July'
                                : time.month == 8
                                    ? month = 'Aug'
                                    : time.month == 9
                                        ? month = 'Sep'
                                        : time.month == 10
                                            ? month = 'Oct'
                                            : time.month == 11
                                                ? month = 'Nov'
                                                : month = 'Dec';

    return '${time.day} $month ${time.hour}:${time.minute}';
  }

  /// Money from a numeric value: grouped thousands, no decimals.
  static String priceFromNum(num value) => priceFormat(value.round().toString());

  /// Weight/dimension: whole numbers show without a decimal, fractional values
  /// keep up to one decimal place (e.g. 18 → "18", 18.5 → "18.5").
  static String weightFormat(num value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value
        .toStringAsFixed(1)
        .replaceAll(RegExp(r'\.0$'), '');
  }

  static String priceFormat(String price) {
    String priceResult = '';
    if(price.contains('.')){
      priceResult = price.split('.')[0];
    }else{
      priceResult = price;
    }
    priceResult = priceResult.replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},');
    return priceResult;
  }

  String formatCardNumber(String cardNumber) {
    if (cardNumber.length <= 4) {
      return cardNumber; // or handle as an error, card number too short
    }
    String lastFourDigits = cardNumber.substring(cardNumber.length - 4);
    return "**** **** **** $lastFourDigits";
  }

  int stringToInt(String value) {
    String cleaned = value.replaceAll(',', '');
    double parsed = double.parse(cleaned);
    return parsed.toInt();
  }


}
