import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_service.dart';
import 'backend_config.dart';
import 'driver.dart';

class CompanyRecord {
  const CompanyRecord({
    required this.companyId,
    required this.name,
    this.createdAt,
  });

  factory CompanyRecord.fromJson(Map<String, dynamic> json) {
    return CompanyRecord(
      companyId: json['company_id'] as int? ?? 0,
      name: (json['name'] as String?) ?? 'Unknown company',
      createdAt: json['created_at'] is String
          ? DateTime.tryParse(json['created_at'] as String)?.toLocal()
          : null,
    );
  }

  final int companyId;
  final String name;
  final DateTime? createdAt;
}

class CompanyDashboard {
  const CompanyDashboard({
    required this.company,
    required this.totalBuses,
    required this.totalDrivers,
    required this.totalTrips,
    required this.scheduledTrips,
    required this.totalBookings,
    required this.paidRevenue,
  });

  factory CompanyDashboard.fromJson(Map<String, dynamic> json) {
    final companyJson = json['company'] as Map<String, dynamic>? ?? const {};
    final stats = json['stats'] as Map<String, dynamic>? ?? const {};

    return CompanyDashboard(
      company: CompanyRecord.fromJson(companyJson),
      totalBuses: stats['totalBuses'] as int? ?? 0,
      totalDrivers: stats['totalDrivers'] as int? ?? 0,
      totalTrips: stats['totalTrips'] as int? ?? 0,
      scheduledTrips: stats['scheduledTrips'] as int? ?? 0,
      totalBookings: stats['totalBookings'] as int? ?? 0,
      paidRevenue: _readAmount(stats['paidRevenue']),
    );
  }

  final CompanyRecord company;
  final int totalBuses;
  final int totalDrivers;
  final int totalTrips;
  final int scheduledTrips;
  final int totalBookings;
  final double paidRevenue;

  String get paidRevenueLabel => 'ZMW ${paidRevenue.toStringAsFixed(2)}';

  static double _readAmount(dynamic rawValue) {
    if (rawValue is num) {
      return rawValue.toDouble();
    }
    if (rawValue is String) {
      return double.tryParse(rawValue) ?? 0;
    }
    return 0;
  }
}

class CompanySchedule {
  const CompanySchedule({
    required this.scheduleId,
    required this.companyId,
    required this.origin,
    required this.destination,
    required this.departureTime,
    required this.price,
    required this.active,
    required this.durationMinutes,
  });

  factory CompanySchedule.fromJson(Map<String, dynamic> json) {
    return CompanySchedule(
      scheduleId: json['schedule_id'] as int? ?? 0,
      companyId: json['company_id'] as int? ?? 0,
      origin: (json['origin'] as String?) ?? 'Origin',
      destination: (json['destination'] as String?) ?? 'Destination',
      departureTime: (json['departure_time'] as String?) ?? 'Time',
      price: (json['price'] as String?) ?? 'K0',
      active: json['active'] as bool? ?? true,
      durationMinutes: json['duration_minutes'] as int? ?? 0,
    );
  }

  final int scheduleId;
  final int companyId;
  final String origin;
  final String destination;
  final String departureTime;
  final String price;
  final bool active;
  final int durationMinutes;

  String get routeLabel => '$origin to $destination';
}

class CompanyTicket {
  const CompanyTicket({
    required this.ticketId,
    required this.bookingId,
    required this.passengerName,
    required this.seatNumber,
    required this.ticketNumber,
    required this.status,
    this.bookingReference,
    this.bookingStatus,
    this.origin,
    this.destination,
    this.driverName,
    this.departureTime,
    this.verifiedAt,
  });

  factory CompanyTicket.fromJson(Map<String, dynamic> json) {
    return CompanyTicket(
      ticketId: json['ticket_id'] as int? ?? 0,
      bookingId: json['booking_id'] as int? ?? 0,
      passengerName: (json['passenger_name'] as String?) ?? 'Passenger',
      seatNumber: (json['seat_number'] as String?) ?? 'Seat',
      ticketNumber: (json['ticket_number'] as String?) ?? 'Ticket',
      status: (json['status'] as String?) ?? 'unknown',
      bookingReference: json['booking_reference'] as String?,
      bookingStatus: json['booking_status'] as String?,
      origin: json['origin'] as String?,
      destination: json['destination'] as String?,
      driverName: json['driver_name'] as String?,
      departureTime: json['departure_time'] is String
          ? DateTime.tryParse(json['departure_time'] as String)?.toLocal()
          : null,
      verifiedAt: json['verified_at'] is String
          ? DateTime.tryParse(json['verified_at'] as String)?.toLocal()
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
  final String? bookingStatus;
  final String? origin;
  final String? destination;
  final String? driverName;
  final DateTime? departureTime;
  final DateTime? verifiedAt;

  String get routeLabel => '${origin ?? 'Origin'} to ${destination ?? 'Destination'}';
}

class CompanyService {
  CompanyService._();

  static final CompanyService instance = CompanyService._();

  String get _baseUrl => BackendConfig.authBaseUrl;

  Future<List<CompanyRecord>> getCompanies() async {
    final token = await _requireToken();
    final response = await _get(
      '/companies',
      token: token,
      featureName: 'Companies',
    );
    final body = jsonDecode(response.body);
    if (body is! List) {
      throw const AuthException('The backend did not return a company list.');
    }

    return body
        .whereType<Map<String, dynamic>>()
        .map(CompanyRecord.fromJson)
        .toList();
  }

  Future<CompanyDashboard> getDashboard(int companyId) async {
    final token = await _requireToken();
    final response = await _get(
      '/companies/$companyId/dashboard',
      token: token,
      featureName: 'Company dashboard',
    );
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return CompanyDashboard.fromJson(body);
  }

  Future<List<DriverProfile>> getDrivers(int companyId) async {
    final token = await _requireToken();
    final response = await _get(
      '/drivers/company/$companyId',
      token: token,
      featureName: 'Company drivers',
    );
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final drivers = body['drivers'];
    if (drivers is! List) {
      return const [];
    }

    return drivers
        .whereType<Map<String, dynamic>>()
        .map(DriverProfile.fromJson)
        .toList();
  }

  Future<DriverProfile> createDriver({
    required int companyId,
    required String fullName,
    required String licenseNumber,
    String? email,
    String? phoneNumber,
  }) async {
    final token = await _requireToken();
    final response = await _post(
      '/drivers',
      token: token,
      featureName: 'Create driver',
      body: {
        'company_id': companyId,
        'full_name': fullName,
        'license_number': licenseNumber,
        if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
        if (phoneNumber != null && phoneNumber.trim().isNotEmpty)
          'phone_number': phoneNumber.trim(),
      },
    );

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final driver = body['driver'];
    if (driver is! Map<String, dynamic>) {
      throw const AuthException('The backend did not return the created driver.');
    }

    return DriverProfile.fromJson(driver);
  }

  Future<List<CompanySchedule>> getSchedules(int companyId) async {
    final token = await _requireToken();
    final response = await _get(
      '/companies/$companyId/schedules',
      token: token,
      featureName: 'Company schedules',
    );
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final schedules = body['schedules'];
    if (schedules is! List) {
      return const [];
    }

    return schedules
        .whereType<Map<String, dynamic>>()
        .map(CompanySchedule.fromJson)
        .toList();
  }

  Future<CompanySchedule> updateSchedule({
    required int companyId,
    required int scheduleId,
    String? price,
    bool? active,
  }) async {
    final token = await _requireToken();
    final response = await _patch(
      '/companies/$companyId/schedules/$scheduleId',
      token: token,
      featureName: 'Update schedule',
      body: {
        if (price != null) 'price': price,
        if (active != null) 'active': active,
      },
    );

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final schedule = body['schedule'];
    if (schedule is! Map<String, dynamic>) {
      throw const AuthException('The backend did not return the updated schedule.');
    }

    return CompanySchedule.fromJson(schedule);
  }

  Future<List<CompanyTicket>> getTickets(int companyId) async {
    final token = await _requireToken();
    final response = await _get(
      '/companies/$companyId/tickets',
      token: token,
      featureName: 'Company tickets',
    );
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final tickets = body['tickets'];
    if (tickets is! List) {
      return const [];
    }

    return tickets
        .whereType<Map<String, dynamic>>()
        .map(CompanyTicket.fromJson)
        .toList();
  }

  Future<CompanyTicket> verifyTicket(String code) async {
    final token = await _requireToken();
    final response = await _post(
      '/drivers/tickets/verify',
      token: token,
      featureName: 'Ticket validation',
      body: {'code': code},
    );
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final ticket = body['ticket'];
    if (ticket is! Map<String, dynamic>) {
      throw const AuthException('The backend did not return the verified ticket.');
    }
    return CompanyTicket.fromJson(ticket);
  }

  Future<String> _requireToken() async {
    final token = await AuthService.instance.getToken();
    if (token == null || token.isEmpty) {
      throw const AuthException('Please log in again to continue.');
    }
    return token;
  }

  Future<http.Response> _get(
    String path, {
    String? token,
    required String featureName,
  }) async {
    try {
      final response = await http
          .get(
            Uri.parse('$_baseUrl$path'),
            headers: {
              'Content-Type': 'application/json',
              if (token != null) 'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw AuthException(_extractErrorMessage(response));
      }

      return response;
    } on TimeoutException catch (error) {
      throw AuthException(
        '$featureName timed out while contacting $_baseUrl.\nDetails: $error',
      );
    } on http.ClientException catch (error) {
      throw AuthException(
        '${BackendConfig.buildConnectionHelp(featureName: featureName, baseUrl: _baseUrl)}\nDetails: ${error.message}',
      );
    }
  }

  Future<http.Response> _post(
    String path, {
    required String token,
    required String featureName,
    required Map<String, dynamic> body,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl$path'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw AuthException(_extractErrorMessage(response));
      }

      return response;
    } on TimeoutException catch (error) {
      throw AuthException(
        '$featureName timed out while contacting $_baseUrl.\nDetails: $error',
      );
    } on http.ClientException catch (error) {
      throw AuthException(
        '${BackendConfig.buildConnectionHelp(featureName: featureName, baseUrl: _baseUrl)}\nDetails: ${error.message}',
      );
    }
  }

  Future<http.Response> _patch(
    String path, {
    required String token,
    required String featureName,
    required Map<String, dynamic> body,
  }) async {
    try {
      final response = await http
          .patch(
            Uri.parse('$_baseUrl$path'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw AuthException(_extractErrorMessage(response));
      }

      return response;
    } on TimeoutException catch (error) {
      throw AuthException(
        '$featureName timed out while contacting $_baseUrl.\nDetails: $error',
      );
    } on http.ClientException catch (error) {
      throw AuthException(
        '${BackendConfig.buildConnectionHelp(featureName: featureName, baseUrl: _baseUrl)}\nDetails: ${error.message}',
      );
    }
  }

  String _extractErrorMessage(http.Response response) {
    try {
      final body = jsonDecode(response.body);
      if (body is Map<String, dynamic>) {
        final error = body['error'];
        final message = body['message'];
        if (error is String && error.isNotEmpty) {
          return error;
        }
        if (message is String && message.isNotEmpty) {
          return message;
        }
      }
    } catch (_) {
      return 'The server returned an invalid error response.';
    }

    return 'Request failed with status ${response.statusCode}.';
  }
}
