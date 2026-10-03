import 'station.dart';

enum RoutePreference { shortestStations, leastInterchanges, balanced }

extension RoutePreferenceLabel on RoutePreference {
  String get shortLabel {
    switch (this) {
      case RoutePreference.shortestStations:
        return 'Less stations';
      case RoutePreference.leastInterchanges:
        return 'Less line changes';
      case RoutePreference.balanced:
        return 'Best overall';
    }
  }

  String get description {
    switch (this) {
      case RoutePreference.shortestStations:
        return 'Fewer stops on the way';
      case RoutePreference.leastInterchanges:
        return 'Avoid changing trains often';
      case RoutePreference.balanced:
        return 'Mix of speed and comfort';
    }
  }
}

enum FarePaymentMode { tokenOrQr, smartCard }

enum FareDayType { weekday, sundayOrHoliday }

enum FareTimeBand { peak, offPeak }

extension FareEnumsLabel on FarePaymentMode {
  String get label {
    switch (this) {
      case FarePaymentMode.tokenOrQr:
        return 'Token / QR';
      case FarePaymentMode.smartCard:
        return 'Smart Card';
    }
  }
}

extension FareDayTypeLabel on FareDayType {
  String get label {
    switch (this) {
      case FareDayType.weekday:
        return 'Weekday';
      case FareDayType.sundayOrHoliday:
        return 'Sunday/Holiday';
    }
  }
}

extension FareTimeBandLabel on FareTimeBand {
  String get label {
    switch (this) {
      case FareTimeBand.peak:
        return 'Peak';
      case FareTimeBand.offPeak:
        return 'Off-peak';
    }
  }
}

class FareRequest {
  const FareRequest({
    this.paymentMode = FarePaymentMode.smartCard,
    this.dayType = FareDayType.weekday,
    this.timeBand = FareTimeBand.peak,
    this.additionalDiscountPercent = 0,
  });

  final FarePaymentMode paymentMode;
  final FareDayType dayType;
  final FareTimeBand timeBand;
  final int additionalDiscountPercent;

  int get clampedAdditionalDiscountPercent =>
      additionalDiscountPercent.clamp(0, 80);

  bool get qualifiesForOffPeakDiscount {
    return paymentMode == FarePaymentMode.smartCard &&
        dayType == FareDayType.weekday &&
        timeBand == FareTimeBand.offPeak;
  }
}

class FareBreakdown {
  const FareBreakdown({
    required this.estimatedDistanceKm,
    required this.weekdayTokenFare,
    required this.holidayTokenFare,
    required this.baseFare,
    required this.paymentDiscountPercent,
    required this.paymentDiscountAmount,
    required this.offPeakDiscountPercent,
    required this.offPeakDiscountAmount,
    required this.additionalDiscountPercent,
    required this.additionalDiscountAmount,
    required this.payableFare,
    required this.notes,
  });

  final double estimatedDistanceKm;
  final int weekdayTokenFare;
  final int holidayTokenFare;
  final int baseFare;
  final int paymentDiscountPercent;
  final int paymentDiscountAmount;
  final int offPeakDiscountPercent;
  final int offPeakDiscountAmount;
  final int additionalDiscountPercent;
  final int additionalDiscountAmount;
  final int payableFare;
  final List<String> notes;
}

class RouteResult {
  const RouteResult({
    required this.source,
    required this.destination,
    required this.path,
    required this.totalStations,
    required this.interchangeCount,
    required this.estimatedMinutes,
    required this.weight,
    required this.preference,
    required this.fare,
  });

  final Station source;
  final Station destination;
  final List<Station> path;
  final int totalStations;
  final int interchangeCount;
  final int estimatedMinutes;
  final int weight;
  final RoutePreference preference;
  final FareBreakdown fare;
}
