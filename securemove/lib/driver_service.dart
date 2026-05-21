import 'auth_service.dart';
import 'driver.dart';
import 'services/api_service.dart';

class DriverService {
  DriverService._();

  static final DriverService instance = DriverService._();

  final ApiService _api = ApiService.instance;

  Future<DriverProfile> getCurrentDriver() async {
    final body = await _safeGet('/drivers/me');
    final driver = body['driver'];
    if (driver is! Map<String, dynamic>) {
      throw const AuthException('The backend did not return driver details.');
    }

    return DriverProfile.fromJson(driver);
  }

  Future<List<DriverTrip>> getMyTrips() async {
    final body = await _safeGet('/drivers/me/trips');
    final trips = body['trips'];
    if (trips is! List) {
      return const [];
    }

    return trips
        .whereType<Map<String, dynamic>>()
        .map(DriverTrip.fromJson)
        .toList();
  }

  Future<List<DriverTicket>> getTripTickets(int tripId) async {
    final body = await _safeGet('/drivers/trips/$tripId/tickets');
    final tickets = body['tickets'];
    if (tickets is! List) {
      return const [];
    }

    return tickets
        .whereType<Map<String, dynamic>>()
        .map(DriverTicket.fromJson)
        .toList();
  }

  Future<DriverTicket> verifyTicket(String code) async {
    final body = await _safePost('/drivers/tickets/verify', {'code': code.trim()});
    final ticket = body['ticket'];
    if (ticket is! Map<String, dynamic>) {
      throw const AuthException('The backend did not return the verified ticket.');
    }

    return DriverTicket.fromJson(ticket);
  }

  Future<DriverProfile> getDriverById(int driverId) async {
    final body = await _safeGet('/drivers/$driverId');
    final driver = body['driver'];
    if (driver is! Map<String, dynamic>) {
      throw const AuthException('The backend did not return driver details.');
    }

    return DriverProfile.fromJson(driver);
  }

  Future<Map<String, dynamic>> _safeGet(String path) async {
    try {
      return await _api.get(path);
    } on ApiException catch (error) {
      throw AuthException(_friendlyError(error.message));
    }
  }

  Future<Map<String, dynamic>> _safePost(
    String path,
    Map<String, dynamic> body,
  ) async {
    try {
      return await _api.post(path, body);
    } on ApiException catch (error) {
      throw AuthException(_friendlyError(error.message));
    }
  }

  String _friendlyError(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('invalid error response') ||
        lower.contains('route is unavailable') ||
        lower.contains('cannot get')) {
      return 'Driver workspace is unavailable. Restart or redeploy the backend, then tap Retry.';
    }
    return message;
  }
}

class DriverTrip {
  const DriverTrip({
    required this.tripId,
    required this.status,
    required this.bookingCount,
    required this.ticketCount,
    required this.usedTicketCount,
    this.departureTime,
    this.arrivalTime,
    this.availableSeats,
    this.origin,
    this.destination,
    this.companyName,
    this.registrationNumber,
    this.capacity,
  });

  factory DriverTrip.fromJson(Map<String, dynamic> json) {
    return DriverTrip(
      tripId: json['trip_id'] as int? ?? 0,
      status: (json['status'] as String?) ?? 'scheduled',
      departureTime: json['departure_time'] is String
          ? DateTime.tryParse(json['departure_time'] as String)?.toLocal()
          : null,
      arrivalTime: json['arrival_time'] is String
          ? DateTime.tryParse(json['arrival_time'] as String)?.toLocal()
          : null,
      availableSeats: json['available_seats'] as int?,
      origin: json['origin'] as String?,
      destination: json['destination'] as String?,
      companyName: json['company_name'] as String?,
      registrationNumber: json['registration_number'] as String?,
      capacity: json['capacity'] as int?,
      bookingCount: json['booking_count'] as int? ?? 0,
      ticketCount: json['ticket_count'] as int? ?? 0,
      usedTicketCount: json['used_ticket_count'] as int? ?? 0,
    );
  }

  final int tripId;
  final String status;
  final DateTime? departureTime;
  final DateTime? arrivalTime;
  final int? availableSeats;
  final String? origin;
  final String? destination;
  final String? companyName;
  final String? registrationNumber;
  final int? capacity;
  final int bookingCount;
  final int ticketCount;
  final int usedTicketCount;

  String get routeLabel => '${origin ?? 'Origin'} to ${destination ?? 'Destination'}';
}

class DriverTicket {
  const DriverTicket({
    required this.ticketId,
    required this.bookingId,
    required this.passengerName,
    required this.seatNumber,
    required this.ticketNumber,
    required this.status,
    this.bookingReference,
    this.verifiedAt,
    this.createdAt,
  });

  factory DriverTicket.fromJson(Map<String, dynamic> json) {
    return DriverTicket(
      ticketId: json['ticket_id'] as int? ?? 0,
      bookingId: json['booking_id'] as int? ?? 0,
      passengerName: (json['passenger_name'] as String?) ?? 'Passenger',
      seatNumber: (json['seat_number'] as String?) ?? 'Seat',
      ticketNumber: (json['ticket_number'] as String?) ?? 'Ticket',
      status: (json['status'] as String?) ?? 'unknown',
      bookingReference: json['booking_reference'] as String?,
      verifiedAt: json['verified_at'] is String
          ? DateTime.tryParse(json['verified_at'] as String)?.toLocal()
          : null,
      createdAt: json['created_at'] is String
          ? DateTime.tryParse(json['created_at'] as String)?.toLocal()
          : null,
    );
  }

  final int ticketId;
  final int bookingId;
  final String passengerName;
  final String seatNumber;
  final String ticketNumber;
  final String status;
  final String? bookingReference;
  final DateTime? verifiedAt;
  final DateTime? createdAt;

  bool get isUsed => status == 'used';
}
