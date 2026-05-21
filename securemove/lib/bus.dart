class Bus {
  final int scheduleId;
  final int? tripId;
  final int? driverId;
  final String company;
  final String origin;
  final String destination;
  final String time;
  final String price;
  final int durationMinutes;
  final int? seatsLeft;
  final List<String> features;
  final String? driverName;
  final String? driverPhone;
  final String? driverLicenseNumber;
  final String? registrationNumber;

  const Bus({
    required this.scheduleId,
    required this.tripId,
    required this.driverId,
    required this.company,
    required this.origin,
    required this.destination,
    required this.time,
    required this.price,
    required this.durationMinutes,
    required this.seatsLeft,
    required this.features,
    required this.driverName,
    required this.driverPhone,
    required this.driverLicenseNumber,
    required this.registrationNumber,
  });

  factory Bus.fromJson(Map<String, dynamic> json) {
    final rawFeatures = json['features'];
    return Bus(
      scheduleId: json['schedule_id'] is int ? json['schedule_id'] as int : 0,
      tripId: _parseOptionalInt(json['trip_id'] ?? json['id']),
      driverId: _parseOptionalInt(json['driver_id']),
      company: (json['company'] as String?) ?? 'Unknown operator',
      origin: (json['origin'] as String?) ?? '',
      destination: (json['destination'] as String?) ?? '',
      time: (json['departure_time'] as String?) ?? '',
      price: (json['price'] as String?) ?? '',
      durationMinutes: json['duration_minutes'] is int
          ? json['duration_minutes'] as int
          : 0,
      seatsLeft: _parseSeatsLeft(json),
      features: rawFeatures is List
          ? rawFeatures.whereType<String>().toList()
          : const [],
      driverName: json['driver_name'] as String?,
      driverPhone: json['driver_phone'] as String?,
      driverLicenseNumber: json['license_number'] as String?,
      registrationNumber: json['registration_number'] as String?,
    );
  }

  String get formattedDuration {
    if (durationMinutes <= 0) {
      return 'Schedule pending';
    }

    final hours = durationMinutes ~/ 60;
    final minutes = durationMinutes % 60;
    if (hours == 0) {
      return '${minutes}m';
    }
    if (minutes == 0) {
      return '${hours}h';
    }
    return '${hours}h ${minutes}m';
  }

  String? get seatAvailabilityLabel {
    final value = effectiveSeatsLeft;
    if (value == 1) {
      return '1 seat left';
    }
    return '$value seats left';
  }

  int get effectiveSeatsLeft {
    final value = seatsLeft;
    if (value != null && value > 0) {
      return value;
    }

    // Fallback demo availability until the backend returns seat counts.
    final seed = scheduleId > 0
        ? scheduleId
        : company.length + origin.length + destination.length + durationMinutes;
    return 18 + (seed % 24);
  }

  bool get hasLiveTripId => tripId != null && tripId! > 0;

  String? get driverSummary {
    if (driverName == null || driverName!.trim().isEmpty) {
      return null;
    }

    if (driverLicenseNumber == null || driverLicenseNumber!.trim().isEmpty) {
      return driverName;
    }

    return '$driverName · ${driverLicenseNumber!}';
  }

  static int? _parseSeatsLeft(Map<String, dynamic> json) {
    final rawValue =
        json['seats_left'] ??
        json['available_seats'] ??
        json['seats_available'] ??
        json['remaining_seats'] ??
        json['seatsLeft'] ??
        json['availableSeats'] ??
        json['seats'];
    if (rawValue is int) {
      return rawValue;
    }
    if (rawValue is String) {
      return int.tryParse(rawValue);
    }
    return null;
  }

  static int? _parseOptionalInt(dynamic rawValue) {
    if (rawValue is int) {
      return rawValue;
    }
    if (rawValue is String) {
      return int.tryParse(rawValue);
    }
    return null;
  }
}
