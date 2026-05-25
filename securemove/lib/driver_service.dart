import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_service.dart';
import 'backend_config.dart';
import 'driver.dart';
import 'services/api_service.dart';

class DriverService {
  DriverService._();

  static final DriverService instance = DriverService._();
  final ApiService _api = ApiService.instance;

  Future<DriverProfile> getCurrentDriver() async {
    final body = await _safeGet('/driver/me');
    final driver = body['driver'];
    if (driver is! Map<String, dynamic>) {
      throw const AuthException('The backend did not return driver details.');
    }
    return DriverProfile.fromJson(driver);
  }

  Future<DriverProfile> updateProfile({
    required String fullName,
    required String phone,
  }) async {
    final body = await _safePut('/driver/profile', {
      'fullName': fullName,
      'phone': phone,
    });
    final driver = body['driver'];
    if (driver is! Map<String, dynamic>) {
      throw const AuthException('The backend did not return updated profile details.');
    }
    return DriverProfile.fromJson(driver);
  }

  Future<DriverProfile> uploadProfilePhoto(String path) async {
    final token = await AuthService.instance.getToken();
    if (token == null || token.isEmpty) {
      throw const AuthException('Please log in again to continue.');
    }
    final request = http.MultipartRequest(
      'PUT',
      Uri.parse('${BackendConfig.authBaseUrl}/driver/profile/photo'),
    );
    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(await http.MultipartFile.fromPath('photo', path));

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    final decoded = jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AuthException(
        decoded is Map<String, dynamic> && decoded['error'] is String
            ? decoded['error'] as String
            : 'Unable to upload profile photo.',
      );
    }
    final driver = decoded is Map<String, dynamic> ? decoded['driver'] : null;
    if (driver is! Map<String, dynamic>) {
      throw const AuthException('The backend did not return updated profile details.');
    }
    return DriverProfile.fromJson(driver);
  }

  Future<List<DriverTrip>> getTrips({String status = 'upcoming'}) async {
    final body = await _safeGet('/driver/trips?status=$status');
    final trips = body['trips'];
    if (trips is! List) return const [];
    return trips.whereType<Map<String, dynamic>>().map(DriverTrip.fromJson).toList();
  }

  Future<DriverTrip> getTripDetail(int tripId) async {
    final body = await _safeGet('/driver/trips/$tripId');
    final trip = body['trip'];
    if (trip is! Map<String, dynamic>) {
      throw const AuthException('The backend did not return trip details.');
    }
    return DriverTrip.fromJson(trip);
  }

  Future<List<DriverNotification>> getNotifications() async {
    final body = await _safeGet('/driver/notifications');
    final notifications = body['notifications'];
    if (notifications is! List) return const [];
    return notifications
        .whereType<Map<String, dynamic>>()
        .map(DriverNotification.fromJson)
        .toList();
  }

  Future<Map<String, dynamic>> _safeGet(String path) async {
    try {
      return await _api.get(path);
    } on ApiException catch (error) {
      throw AuthException(_friendlyError(error.message));
    }
  }

  Future<Map<String, dynamic>> _safePut(
    String path,
    Map<String, dynamic> body,
  ) async {
    try {
      return await _api.put(path, body);
    } on ApiException catch (error) {
      throw AuthException(_friendlyError(error.message));
    }
  }

  String _friendlyError(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('invalid error response') ||
        lower.contains('route is unavailable') ||
        lower.contains('cannot get')) {
      return 'Driver workspace is unavailable. Restart the backend, then tap Retry.';
    }
    return message;
  }
}

class DriverTrip {
  const DriverTrip({
    required this.tripId,
    required this.status,
    required this.statusLabel,
    required this.boardedCount,
    required this.passengerCount,
    this.departureTime,
    this.arrivalTime,
    this.origin,
    this.destination,
    this.registrationNumber,
    this.capacity,
    this.busType,
    this.conductorName,
    this.conductorBadge,
    this.stops = const [],
  });

  factory DriverTrip.fromJson(Map<String, dynamic> json) {
    return DriverTrip(
      tripId: json['trip_id'] as int? ?? 0,
      status: (json['status'] as String?) ?? 'scheduled',
      statusLabel: (json['status_label'] as String?) ?? 'UPCOMING',
      departureTime: json['departure_time'] is String
          ? DateTime.tryParse(json['departure_time'] as String)?.toLocal()
          : null,
      arrivalTime: json['arrival_time'] is String
          ? DateTime.tryParse(json['arrival_time'] as String)?.toLocal()
          : null,
      origin: json['origin'] as String?,
      destination: json['destination'] as String?,
      registrationNumber: json['registration_number'] as String?,
      capacity: json['capacity'] as int?,
      busType: json['bus_type'] as String?,
      conductorName: json['conductor_name'] as String?,
      conductorBadge: json['conductor_badge'] as String?,
      boardedCount: json['boarded_count'] as int? ?? 0,
      passengerCount: json['passenger_count'] as int? ?? 0,
      stops: json['stops'] is List
          ? (json['stops'] as List).whereType<String>().toList()
          : const [],
    );
  }

  final int tripId;
  final String status;
  final String statusLabel;
  final DateTime? departureTime;
  final DateTime? arrivalTime;
  final String? origin;
  final String? destination;
  final String? registrationNumber;
  final int? capacity;
  final String? busType;
  final String? conductorName;
  final String? conductorBadge;
  final int boardedCount;
  final int passengerCount;
  final List<String> stops;

  String get routeLabel => '${origin ?? 'Origin'} to ${destination ?? 'Destination'}';
}

class DriverNotification {
  const DriverNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.kind,
    this.createdAt,
    this.readAt,
  });

  factory DriverNotification.fromJson(Map<String, dynamic> json) {
    return DriverNotification(
      id: json['notification_id'] as int? ?? 0,
      title: (json['title'] as String?) ?? 'Notification',
      message: (json['message'] as String?) ?? '',
      kind: (json['kind'] as String?) ?? 'info',
      createdAt: json['created_at'] is String
          ? DateTime.tryParse(json['created_at'] as String)?.toLocal()
          : null,
      readAt: json['read_at'] is String
          ? DateTime.tryParse(json['read_at'] as String)?.toLocal()
          : null,
    );
  }

  final int id;
  final String title;
  final String message;
  final String kind;
  final DateTime? createdAt;
  final DateTime? readAt;
}
