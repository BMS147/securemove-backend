import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_service.dart';
import 'backend_config.dart';

class BookingRecord {
  const BookingRecord({
    required this.bookingId,
    required this.tripId,
    required this.bookingReference,
    required this.totalAmount,
    required this.status,
    required this.createdAt,
    this.departureTime,
    this.tripStatus,
    this.origin,
    this.destination,
    this.companyName,
  });

  factory BookingRecord.fromJson(Map<String, dynamic> json) {
    return BookingRecord(
      bookingId: json['booking_id'] as int? ?? 0,
      tripId: json['trip_id'] as int? ?? 0,
      bookingReference:
          (json['booking_reference'] as String?) ?? 'Unknown reference',
      totalAmount: _readAmount(json['total_amount']),
      status: (json['status'] as String?) ?? 'unknown',
      createdAt: json['created_at'] is String
          ? DateTime.tryParse(json['created_at'] as String)?.toLocal() ??
              DateTime.now()
          : DateTime.now(),
      departureTime: json['departure_time'] as String?,
      tripStatus: json['trip_status'] as String?,
      origin: json['origin'] as String?,
      destination: json['destination'] as String?,
      companyName: json['company_name'] as String?,
    );
  }

  final int bookingId;
  final int tripId;
  final String bookingReference;
  final double totalAmount;
  final String status;
  final DateTime createdAt;
  final String? departureTime;
  final String? tripStatus;
  final String? origin;
  final String? destination;
  final String? companyName;

  String get totalAmountLabel => 'K${totalAmount.toStringAsFixed(2)}';

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

class TicketRecord {
  const TicketRecord({
    required this.ticketId,
    required this.bookingId,
    required this.passengerName,
    required this.seatNumber,
    required this.ticketNumber,
    required this.qrCodeHash,
    required this.status,
  });

  factory TicketRecord.fromJson(Map<String, dynamic> json) {
    return TicketRecord(
      ticketId: json['ticket_id'] as int? ?? 0,
      bookingId: json['booking_id'] as int? ?? 0,
      passengerName:
          (json['passenger_name'] as String?) ?? 'SecureMove Passenger',
      seatNumber: (json['seat_number'] as String?) ?? 'AUTO-1',
      ticketNumber: (json['ticket_number'] as String?) ?? 'Ticket',
      qrCodeHash: (json['qr_code_hash'] as String?) ?? '',
      status: (json['status'] as String?) ?? 'unknown',
    );
  }

  final int ticketId;
  final int bookingId;
  final String passengerName;
  final String seatNumber;
  final String ticketNumber;
  final String qrCodeHash;
  final String status;

  bool get hasSignedQr => qrCodeHash.trim().isNotEmpty;
}

class BookingService {
  BookingService._();

  static final BookingService instance = BookingService._();

  String get _baseUrl => BackendConfig.authBaseUrl;

  Future<BookingRecord> reserveBooking({
    required int tripId,
    required double totalAmount,
  }) async {
    final token = await _requireToken();

    final response = await _post(
      '/bookings/reserve',
      token: token,
      body: {
        'trip_id': tripId,
        'total_amount': totalAmount,
      },
      featureName: 'Reserve booking',
    );

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final booking = body['booking'];
    if (booking is! Map<String, dynamic>) {
      throw const AuthException('The backend did not return a booking record.');
    }

    return BookingRecord.fromJson(booking);
  }

  Future<List<BookingRecord>> getMyBookings() async {
    final token = await _requireToken();

    http.Response response;
    try {
      response = await http
          .get(
            Uri.parse('$_baseUrl/bookings/me'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 12));
    } on TimeoutException catch (error) {
      throw AuthException(
        'My bookings timed out while contacting $_baseUrl.\nDetails: $error',
      );
    } on http.ClientException catch (error) {
      throw AuthException(
        '${BackendConfig.buildConnectionHelp(featureName: 'My bookings', baseUrl: _baseUrl)}\nDetails: ${error.message}',
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AuthException(_extractErrorMessage(response));
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final bookings = body['bookings'];
    if (bookings is! List) {
      return const [];
    }

    return bookings
        .whereType<Map<String, dynamic>>()
        .map(BookingRecord.fromJson)
        .toList();
  }

  Future<void> cancelBooking(int bookingId) async {
    final token = await _requireToken();

    await _post(
      '/bookings/$bookingId/cancel',
      token: token,
      body: const {},
      featureName: 'Cancel booking',
    );
  }

  Future<List<TicketRecord>> getBookingTickets(int bookingId) async {
    final token = await _requireToken();

    http.Response response;
    try {
      response = await http
          .get(
            Uri.parse('$_baseUrl/tickets/booking/$bookingId'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 12));
    } on TimeoutException catch (error) {
      throw AuthException(
        'Tickets timed out while contacting $_baseUrl.\nDetails: $error',
      );
    } on http.ClientException catch (error) {
      throw AuthException(
        '${BackendConfig.buildConnectionHelp(featureName: 'Tickets', baseUrl: _baseUrl)}\nDetails: ${error.message}',
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AuthException(_extractErrorMessage(response));
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final tickets = body['tickets'];
    if (tickets is! List) {
      return const [];
    }

    return tickets
        .whereType<Map<String, dynamic>>()
        .map(TicketRecord.fromJson)
        .toList();
  }

  Future<String?> getToken() => AuthService.instance.getToken();

  Future<String> _requireToken() async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      throw const AuthException('Please log in again to continue.');
    }
    return token;
  }

  Future<http.Response> _post(
    String path, {
    required String token,
    required Map<String, dynamic> body,
    required String featureName,
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

    return 'Booking request failed with status ${response.statusCode}.';
  }
}
