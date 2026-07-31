import 'dart:convert';
import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String defaultApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue:
      'https://diariodiviaggioapi-b0edhndsbahwepag.italynorth-01.azurewebsites.net',
);

String _normalizeApiBaseUrl(String rawBaseUrl) {
  final trimmed = rawBaseUrl.trim().replaceFirst(RegExp(r'/+$'), '');
  return trimmed.replaceFirst(RegExp(r'/api$', caseSensitive: false), '');
}

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => SessionStore(ApiClient()),
      child: const DiarioApp(),
    ),
  );
}

class DiarioApp extends StatelessWidget {
  const DiarioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Diario di Viaggio',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF005F73),
          secondary: const Color(0xFFEE9B00),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const StartupGate(),
    );
  }
}

class StartupGate extends StatefulWidget {
  const StartupGate({super.key});

  @override
  State<StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<StartupGate> {
  late Future<void> _bootstrap;

  @override
  void initState() {
    super.initState();
    _bootstrap = context.read<SessionStore>().initialize();
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionStore>();
    return FutureBuilder<void>(
      future: _bootstrap,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (session.isAuthenticated) {
          return const MainShell();
        }

        return const AuthScreen();
      },
    );
  }
}

class SessionStore extends ChangeNotifier {
  SessionStore(this._apiClient);

  final ApiClient _apiClient;
  String? token;
  String? refreshToken;
  String? username;
  String? email;
  String? profileImageBase64;

  bool get isAuthenticated => token != null && token!.isNotEmpty;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString('token');
    refreshToken = prefs.getString('refreshToken');
    _apiClient.hydrateAuthTokens(token: token, refreshToken: refreshToken);
    username = prefs.getString('username');
    email = prefs.getString('email');
    profileImageBase64 = prefs.getString('profileImageBase64');

    if (isAuthenticated) {
      try {
        final refreshed = await _apiClient.refreshToken(refreshToken);
        token = refreshed.token;
        refreshToken = refreshed.refreshToken;
        _apiClient.hydrateAuthTokens(
          token: refreshed.token,
          refreshToken: refreshed.refreshToken,
        );
        await prefs.setString('token', refreshed.token);
        await prefs.setString('refreshToken', refreshed.refreshToken);
      } catch (_) {
        token = null;
        refreshToken = null;
        username = null;
        email = null;
        profileImageBase64 = null;
        await prefs.remove('token');
        await prefs.remove('refreshToken');
        await prefs.remove('username');
        await prefs.remove('email');
        await prefs.remove('profileImageBase64');
        _apiClient.hydrateAuthTokens(token: null, refreshToken: null);
      }
    }

    notifyListeners();
  }

  Future<void> _saveAuth(AuthResponse auth) async {
    token = auth.token;
    refreshToken = auth.refreshToken;
    _apiClient.hydrateAuthTokens(
      token: auth.token,
      refreshToken: auth.refreshToken,
    );
    username = auth.username;
    email = auth.email;
    profileImageBase64 = auth.profileImageBase64;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', auth.token);
    await prefs.setString('refreshToken', auth.refreshToken);
    await prefs.setString('username', auth.username);
    await prefs.setString('email', auth.email);
    if (auth.profileImageBase64 != null) {
      await prefs.setString('profileImageBase64', auth.profileImageBase64!);
    } else {
      await prefs.remove('profileImageBase64');
    }
    notifyListeners();
  }

  Future<void> login(String userEmail, String password) async {
    final auth = await _apiClient.login(userEmail, password);
    await _saveAuth(auth);
  }

  Future<void> register(
    String userName,
    String userEmail,
    String password,
  ) async {
    final auth = await _apiClient.register(userName, userEmail, password);
    await _saveAuth(auth);
  }

  Future<void> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final latestToken = prefs.getString('token') ?? token;
      final latestRefreshToken =
          prefs.getString('refreshToken') ?? refreshToken;

      if (latestToken != null && latestToken.isNotEmpty) {
        await _apiClient.revokeToken(latestToken, latestRefreshToken);
      }
    } catch (_) {}

    token = null;
    refreshToken = null;
    username = null;
    email = null;
    profileImageBase64 = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('refreshToken');
    await prefs.remove('username');
    await prefs.remove('email');
    await prefs.remove('profileImageBase64');
    _apiClient.hydrateAuthTokens(token: null, refreshToken: null);
    notifyListeners();
  }

  Future<void> updateProfile(UserProfile profile) async {
    username = profile.username;
    email = profile.email;
    profileImageBase64 = profile.profileImageBase64;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('username', profile.username);
    await prefs.setString('email', profile.email);
    if (profile.profileImageBase64 != null) {
      await prefs.setString('profileImageBase64', profile.profileImageBase64!);
    } else {
      await prefs.remove('profileImageBase64');
    }
    notifyListeners();
  }
}

class ApiClient {
  ApiClient()
    : _dio = Dio(
        BaseOptions(
          baseUrl: _normalizeApiBaseUrl(defaultApiBaseUrl),
          connectTimeout: const Duration(seconds: 20),
          receiveTimeout: const Duration(seconds: 20),
        ),
      ) {
    _setupAuthInterceptor();
  }

  final Dio _dio;
  String? _currentAccessToken;
  String? _currentRefreshToken;
  Completer<void>? _refreshCompleter;

  void hydrateAuthTokens({String? token, String? refreshToken}) {
    _currentAccessToken = token;
    _currentRefreshToken = refreshToken;
  }

  void _setupAuthInterceptor() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onError: (error, handler) async {
          if (_shouldAttemptRefresh(error)) {
            try {
              await _refreshAccessTokenInternal();

              final requestOptions = error.requestOptions;
              final retryHeaders = Map<String, dynamic>.from(
                requestOptions.headers,
              );
              retryHeaders['Authorization'] = 'Bearer $_currentAccessToken';

              final retryOptions = requestOptions.copyWith(
                headers: retryHeaders,
              );
              final response = await _dio.fetch(retryOptions);
              handler.resolve(response);
              return;
            } catch (_) {
              // If refresh fails, return original 401 so upper layers can handle logout.
            }
          }

          handler.next(error);
        },
      ),
    );
  }

  bool _shouldAttemptRefresh(DioException error) {
    if (error.response?.statusCode != 401) {
      return false;
    }

    final requestPath = error.requestOptions.path.toLowerCase();
    if (requestPath.contains('/api/auth/login') ||
        requestPath.contains('/api/auth/register') ||
        requestPath.contains('/api/auth/refresh') ||
        requestPath.contains('/api/auth/revoke')) {
      return false;
    }

    final authHeader = error.requestOptions.headers['Authorization']
        ?.toString();
    return authHeader != null && authHeader.startsWith('Bearer ');
  }

  Future<void> _refreshAccessTokenInternal() async {
    if (_refreshCompleter != null) {
      return _refreshCompleter!.future;
    }

    final completer = Completer<void>();
    _refreshCompleter = completer;

    try {
      final prefs = await SharedPreferences.getInstance();
      final tokenFromStorage = prefs.getString('refreshToken');
      final refreshToken = tokenFromStorage ?? _currentRefreshToken;

      if (refreshToken == null || refreshToken.isEmpty) {
        throw Exception('Refresh token non disponibile');
      }

      final refreshed = await this.refreshToken(refreshToken);
      await prefs.setString('token', refreshed.token);
      await prefs.setString('refreshToken', refreshed.refreshToken);
      _currentAccessToken = refreshed.token;
      _currentRefreshToken = refreshed.refreshToken;
      completer.complete();
    } catch (e) {
      completer.completeError(e);
      rethrow;
    } finally {
      _refreshCompleter = null;
    }
  }

  String _errorToMessage(Object error) {
    if (error is DioException) {
      final status = error.response?.statusCode;
      final method = error.requestOptions.method;
      final path = error.requestOptions.path;
      final data = error.response?.data;
      if (data is Map && data['message'] != null) {
        return data['message'].toString();
      }
      if (data is String && data.isNotEmpty) {
        if (status == 404) {
          return 'Endpoint non trovato (404): $method $path. Verifica che il backend pubblicato esponga questa API.';
        }
        if (status == 401) {
          return 'Sessione non autorizzata (401). Effettua di nuovo l\'accesso.';
        }
        if (status == 403) {
          return 'Operazione non consentita (403).';
        }
        return data;
      }
      if (status == 404) {
        return 'Endpoint non trovato (404): $method $path. Verifica che il backend pubblicato esponga questa API.';
      }
      if (status == 401) {
        return 'Sessione non autorizzata (401). Effettua di nuovo l\'accesso.';
      }
      if (status == 403) {
        return 'Operazione non consentita (403).';
      }
      return error.message ?? 'Richiesta non riuscita';
    }
    return 'Errore inatteso';
  }

  Options _auth(String token) => Options(
    headers: {
      'Authorization':
          'Bearer ${_currentAccessToken?.isNotEmpty == true ? _currentAccessToken : token}',
    },
  );

  Future<AuthResponse> register(
    String username,
    String email,
    String password,
  ) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/api/auth/register',
        data: {'username': username, 'email': email, 'password': password},
      );
      final auth = AuthResponse.fromJson(res.data ?? {});
      _currentAccessToken = auth.token;
      _currentRefreshToken = auth.refreshToken;
      return auth;
    } catch (e) {
      throw Exception(_errorToMessage(e));
    }
  }

  Future<AuthResponse> login(String email, String password) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/api/auth/login',
        data: {'email': email, 'password': password},
      );
      final auth = AuthResponse.fromJson(res.data ?? {});
      _currentAccessToken = auth.token;
      _currentRefreshToken = auth.refreshToken;
      return auth;
    } catch (e) {
      throw Exception(_errorToMessage(e));
    }
  }

  Future<void> forgotPassword(String email) async {
    try {
      await _dio.post('/api/auth/forgot-password', data: {'email': email});
    } catch (e) {
      throw Exception(_errorToMessage(e));
    }
  }

  Future<void> resetPassword(String token, String newPassword) async {
    try {
      await _dio.post(
        '/api/auth/reset-password',
        data: {'token': token, 'newPassword': newPassword},
      );
    } catch (e) {
      throw Exception(_errorToMessage(e));
    }
  }

  Future<RefreshSessionResponse> refreshToken(String? refreshToken) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/api/auth/refresh',
        data: {'refreshToken': refreshToken},
      );
      final refreshed = RefreshSessionResponse.fromJson(res.data ?? {});
      _currentAccessToken = refreshed.token;
      _currentRefreshToken = refreshed.refreshToken;
      return refreshed;
    } catch (e) {
      throw Exception(_errorToMessage(e));
    }
  }

  Future<void> revokeToken(String token, String? refreshToken) async {
    await _dio.post(
      '/api/auth/revoke',
      data: {'refreshToken': refreshToken},
      options: _auth(token),
    );
  }

  Future<List<Trip>> getTrips(String token) async {
    try {
      final res = await _dio.get<List<dynamic>>(
        '/api/trip',
        options: _auth(token),
      );
      return (res.data ?? []).map((e) => Trip.fromJson(e)).toList();
    } catch (e) {
      throw Exception(_errorToMessage(e));
    }
  }

  Future<Trip> getTrip(String token, int id) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/api/trip/$id',
        options: _auth(token),
      );
      return Trip.fromJson(res.data ?? {});
    } catch (e) {
      throw Exception(_errorToMessage(e));
    }
  }

  Future<Trip> createTrip(String token, TripUpsert request) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/api/trip',
        options: _auth(token),
        data: request.toJson(),
      );
      return Trip.fromJson(res.data ?? {});
    } catch (e) {
      throw Exception(_errorToMessage(e));
    }
  }

  Future<Trip> updateTrip(String token, int id, TripUpsert request) async {
    try {
      final res = await _dio.put<Map<String, dynamic>>(
        '/api/trip/$id',
        options: _auth(token),
        data: request.toJson(),
      );
      return Trip.fromJson(res.data ?? {});
    } catch (e) {
      throw Exception(_errorToMessage(e));
    }
  }

  Future<void> deleteTrip(String token, int id) async {
    try {
      await _dio.delete('/api/trip/$id', options: _auth(token));
    } catch (e) {
      throw Exception(_errorToMessage(e));
    }
  }

  Future<Trip> shareTrip(String token, int id) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/api/trip/$id/share',
        options: _auth(token),
      );
      return Trip.fromJson(res.data ?? {});
    } catch (e) {
      throw Exception(_errorToMessage(e));
    }
  }

  Future<Trip> joinTrip(String token, String shareCode) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/api/trip/join/$shareCode',
        options: _auth(token),
      );
      return Trip.fromJson(res.data ?? {});
    } catch (e) {
      throw Exception(_errorToMessage(e));
    }
  }

  Future<List<TripItem>> getTripItems(String token, int tripId) async {
    try {
      final res = await _dio.get<List<dynamic>>(
        '/api/tripitem/trip/$tripId',
        options: _auth(token),
      );
      return (res.data ?? []).map((e) => TripItem.fromJson(e)).toList();
    } catch (e) {
      throw Exception(_errorToMessage(e));
    }
  }

  Future<TripItem> createTripItem(
    String token,
    int tripId,
    TripItemUpsert request,
  ) async {
    try {
      final form = FormData.fromMap(await request.toFormMap());
      final res = await _dio.post<Map<String, dynamic>>(
        '/api/tripitem/trip/$tripId',
        options: _auth(token),
        data: form,
      );
      return TripItem.fromJson(res.data ?? {});
    } catch (e) {
      throw Exception(_errorToMessage(e));
    }
  }

  Future<TripItem> updateTripItem(
    String token,
    int itemId,
    TripItemUpsert request,
  ) async {
    try {
      final form = FormData.fromMap(await request.toFormMap());
      final res = await _dio.put<Map<String, dynamic>>(
        '/api/tripitem/$itemId',
        options: _auth(token),
        data: form,
      );
      return TripItem.fromJson(res.data ?? {});
    } catch (e) {
      throw Exception(_errorToMessage(e));
    }
  }

  Future<void> deleteTripItem(String token, int itemId) async {
    try {
      await _dio.delete('/api/tripitem/$itemId', options: _auth(token));
    } catch (e) {
      throw Exception(_errorToMessage(e));
    }
  }

  Future<List<Luggage>> getLuggages(String token, int tripId) async {
    try {
      final res = await _dio.get<List<dynamic>>(
        '/api/luggage/trip/$tripId',
        options: _auth(token),
      );
      return (res.data ?? []).map((e) => Luggage.fromJson(e)).toList();
    } catch (e) {
      throw Exception(_errorToMessage(e));
    }
  }

  Future<Luggage> createLuggage(
    String token,
    int tripId,
    LuggageUpsert request,
  ) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/api/luggage/trip/$tripId',
        options: _auth(token),
        data: request.toJson(),
      );
      return Luggage.fromJson(res.data ?? {});
    } catch (e) {
      throw Exception(_errorToMessage(e));
    }
  }

  Future<Luggage> updateLuggage(
    String token,
    int luggageId,
    LuggageUpsert request,
  ) async {
    try {
      final res = await _dio.put<Map<String, dynamic>>(
        '/api/luggage/$luggageId',
        options: _auth(token),
        data: request.toJson(),
      );
      return Luggage.fromJson(res.data ?? {});
    } catch (e) {
      throw Exception(_errorToMessage(e));
    }
  }

  Future<void> deleteLuggage(String token, int luggageId) async {
    try {
      await _dio.delete('/api/luggage/$luggageId', options: _auth(token));
    } catch (e) {
      throw Exception(_errorToMessage(e));
    }
  }

  Future<Luggage> exportLuggage(
    String token,
    int luggageId,
    int targetTripId,
  ) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/api/luggage/$luggageId/export',
        options: _auth(token),
        data: {'targetTripId': targetTripId},
      );
      return Luggage.fromJson(res.data ?? {});
    } catch (e) {
      throw Exception(_errorToMessage(e));
    }
  }

  Future<LuggageItem> createLuggageItem(
    String token,
    int luggageId,
    LuggageItemUpsert request,
  ) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/api/luggage/$luggageId/items',
        options: _auth(token),
        data: request.toCreateJson(),
      );
      return LuggageItem.fromJson(res.data ?? {});
    } catch (e) {
      throw Exception(_errorToMessage(e));
    }
  }

  Future<LuggageItem> updateLuggageItem(
    String token,
    int itemId,
    LuggageItemUpsert request,
  ) async {
    try {
      final res = await _dio.put<Map<String, dynamic>>(
        '/api/luggage/items/$itemId',
        options: _auth(token),
        data: request.toUpdateJson(),
      );
      return LuggageItem.fromJson(res.data ?? {});
    } catch (e) {
      throw Exception(_errorToMessage(e));
    }
  }

  Future<void> deleteLuggageItem(String token, int itemId) async {
    try {
      await _dio.delete('/api/luggage/items/$itemId', options: _auth(token));
    } catch (e) {
      throw Exception(_errorToMessage(e));
    }
  }

  Future<TripCalendar> getTripCalendar(String token, int tripId) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/api/itinerary/trip/$tripId/calendar',
        options: _auth(token),
      );
      return TripCalendar.fromJson(res.data ?? {});
    } catch (e) {
      throw Exception(_errorToMessage(e));
    }
  }

  Future<ItineraryActivity> createItinerary(
    String token,
    ItineraryUpsert request,
  ) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/api/itinerary',
        options: _auth(token),
        data: request.toJson(),
      );
      return ItineraryActivity.fromJson(res.data ?? {});
    } catch (e) {
      throw Exception(_errorToMessage(e));
    }
  }

  Future<ItineraryActivity> updateItinerary(
    String token,
    int id,
    ItineraryUpsert request,
  ) async {
    try {
      final res = await _dio.put<Map<String, dynamic>>(
        '/api/itinerary/$id',
        options: _auth(token),
        data: request.toJson(),
      );
      return ItineraryActivity.fromJson(res.data ?? {});
    } catch (e) {
      throw Exception(_errorToMessage(e));
    }
  }

  Future<void> deleteItinerary(String token, int id) async {
    try {
      await _dio.delete('/api/itinerary/$id', options: _auth(token));
    } catch (e) {
      throw Exception(_errorToMessage(e));
    }
  }

  Future<UserProfile> getProfile(String token) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/api/profile',
        options: _auth(token),
      );
      return UserProfile.fromJson(res.data ?? {});
    } catch (e) {
      throw Exception(_errorToMessage(e));
    }
  }

  Future<UserProfile> updateProfile(
    String token,
    UserProfileUpdate request,
  ) async {
    try {
      final res = await _dio.put<Map<String, dynamic>>(
        '/api/profile',
        options: _auth(token),
        data: request.toJson(),
      );
      return UserProfile.fromJson(res.data ?? {});
    } catch (e) {
      throw Exception(_errorToMessage(e));
    }
  }

  Future<void> deleteProfileImage(String token) async {
    try {
      await _dio.delete('/api/profile/profile-image', options: _auth(token));
    } catch (e) {
      throw Exception(_errorToMessage(e));
    }
  }
}

class AuthResponse {
  AuthResponse({
    required this.token,
    required this.refreshToken,
    required this.username,
    required this.email,
    this.profileImageBase64,
  });

  final String token;
  final String refreshToken;
  final String username;
  final String email;
  final String? profileImageBase64;

  factory AuthResponse.fromJson(Map<String, dynamic> json) => AuthResponse(
    token: (json['token'] ?? json['Token'] ?? '').toString(),
    refreshToken: (json['refreshToken'] ?? '').toString(),
    username: (json['username'] ?? '').toString(),
    email: (json['email'] ?? '').toString(),
    profileImageBase64: json['profileImageBase64']?.toString(),
  );
}

class RefreshSessionResponse {
  RefreshSessionResponse({required this.token, required this.refreshToken});

  final String token;
  final String refreshToken;

  factory RefreshSessionResponse.fromJson(Map<String, dynamic> json) =>
      RefreshSessionResponse(
        token: (json['token'] ?? json['Token'] ?? '').toString(),
        refreshToken: (json['refreshToken'] ?? '').toString(),
      );
}

class Trip {
  Trip({
    required this.id,
    required this.title,
    required this.startDate,
    required this.shareCode,
    required this.ownerUsername,
    required this.sharedWithUsernames,
    this.description,
    this.endDate,
    this.tripImageBase64,
  });

  final int id;
  final String title;
  final String? description;
  final DateTime startDate;
  final DateTime? endDate;
  final String shareCode;
  final String ownerUsername;
  final List<String> sharedWithUsernames;
  final String? tripImageBase64;

  factory Trip.fromJson(dynamic jsonRaw) {
    final json = Map<String, dynamic>.from(jsonRaw as Map);
    return Trip(
      id: json['id'] as int,
      title: (json['title'] ?? '').toString(),
      description: json['description']?.toString(),
      startDate: DateTime.parse(
        (json['startDate'] ?? DateTime.now().toIso8601String()).toString(),
      ),
      endDate: json['endDate'] == null
          ? null
          : DateTime.tryParse(json['endDate'].toString()),
      shareCode: (json['shareCode'] ?? '').toString(),
      ownerUsername: (json['ownerUsername'] ?? '').toString(),
      sharedWithUsernames: ((json['sharedWithUsernames'] as List?) ?? [])
          .map((e) => e.toString())
          .toList(),
      tripImageBase64: json['tripImageBase64']?.toString(),
    );
  }
}

class TripUpsert {
  TripUpsert({
    required this.title,
    required this.startDate,
    this.description,
    this.endDate,
    this.tripImageBase64,
  });

  final String title;
  final String? description;
  final DateTime startDate;
  final DateTime? endDate;
  final String? tripImageBase64;

  Map<String, dynamic> toJson() => {
    'title': title,
    'description': description,
    'startDate': startDate.toIso8601String(),
    'endDate': endDate?.toIso8601String(),
    'tripImageBase64': tripImageBase64,
  };
}

class TripItem {
  TripItem({
    required this.id,
    required this.title,
    required this.type,
    required this.createdAt,
    required this.createdByUsername,
    this.description,
    this.location,
    this.rating,
    this.imageUrl,
  });

  final int id;
  final String title;
  final String? description;
  final String type;
  final String? location;
  final int? rating;
  final String? imageUrl;
  final DateTime createdAt;
  final String createdByUsername;

  factory TripItem.fromJson(dynamic jsonRaw) {
    final json = Map<String, dynamic>.from(jsonRaw as Map);
    final ratingRaw = json['rating'];
    final parsedRating = ratingRaw is int
        ? ratingRaw
        : ratingRaw is num
        ? ratingRaw.toInt()
        : int.tryParse(ratingRaw?.toString() ?? '');
    return TripItem(
      id: json['id'] as int,
      title: (json['title'] ?? '').toString(),
      description: json['description']?.toString(),
      type: (json['type'] ?? '').toString(),
      location: json['location']?.toString(),
      rating: parsedRating,
      imageUrl: json['imageUrl']?.toString(),
      createdAt: DateTime.parse(
        (json['createdAt'] ?? DateTime.now().toIso8601String()).toString(),
      ),
      createdByUsername: (json['createdByUsername'] ?? '').toString(),
    );
  }
}

class TripItemUpsert {
  TripItemUpsert({
    required this.title,
    required this.type,
    this.description,
    this.location,
    this.rating,
    this.image,
    this.removeImage = false,
  });

  final String title;
  final String type;
  final String? description;
  final String? location;
  final int? rating;
  final XFile? image;
  final bool removeImage;

  Future<Map<String, dynamic>> toFormMap() async {
    final map = <String, dynamic>{
      'title': title,
      'type': type,
      'description': description,
      'location': location,
      'rating': rating,
      'removeImage': removeImage,
    };
    if (image != null) {
      map['image'] = await MultipartFile.fromFile(
        image!.path,
        filename: image!.name,
      );
    }
    map.removeWhere((key, value) => value == null);
    return map;
  }
}

class Luggage {
  Luggage({
    required this.id,
    required this.name,
    required this.items,
    this.description,
  });

  final int id;
  final String name;
  final String? description;
  final List<LuggageItem> items;

  factory Luggage.fromJson(dynamic jsonRaw) {
    final json = Map<String, dynamic>.from(jsonRaw as Map);
    return Luggage(
      id: json['id'] as int,
      name: (json['name'] ?? '').toString(),
      description: json['description']?.toString(),
      items: ((json['items'] as List?) ?? [])
          .map((e) => LuggageItem.fromJson(e))
          .toList(),
    );
  }
}

class LuggageItem {
  LuggageItem({
    required this.id,
    required this.name,
    required this.quantity,
    required this.isPacked,
    this.notes,
  });

  final int id;
  final String name;
  final String? notes;
  final int quantity;
  final bool isPacked;

  factory LuggageItem.fromJson(dynamic jsonRaw) {
    final json = Map<String, dynamic>.from(jsonRaw as Map);
    return LuggageItem(
      id: json['id'] as int,
      name: (json['name'] ?? '').toString(),
      notes: json['notes']?.toString(),
      quantity: json['quantity'] as int? ?? 1,
      isPacked: json['isPacked'] as bool? ?? false,
    );
  }
}

class LuggageUpsert {
  LuggageUpsert({required this.name, this.description});

  final String name;
  final String? description;

  Map<String, dynamic> toJson() => {'name': name, 'description': description};
}

class LuggageItemUpsert {
  LuggageItemUpsert({
    required this.name,
    required this.quantity,
    required this.isPacked,
    this.notes,
  });

  final String name;
  final String? notes;
  final int quantity;
  final bool isPacked;

  Map<String, dynamic> toCreateJson() => {
    'name': name,
    'notes': notes,
    'quantity': quantity,
  };

  Map<String, dynamic> toUpdateJson() => {
    'name': name,
    'notes': notes,
    'quantity': quantity,
    'isPacked': isPacked,
  };
}

class TripCalendar {
  TripCalendar({
    required this.tripId,
    required this.tripTitle,
    required this.calendar,
    required this.startDate,
    this.endDate,
  });

  final int tripId;
  final String tripTitle;
  final DateTime startDate;
  final DateTime? endDate;
  final List<CalendarDay> calendar;

  factory TripCalendar.fromJson(dynamic jsonRaw) {
    final json = Map<String, dynamic>.from(jsonRaw as Map);
    return TripCalendar(
      tripId: json['tripId'] as int,
      tripTitle: (json['tripTitle'] ?? '').toString(),
      startDate: DateTime.parse(
        (json['startDate'] ?? DateTime.now().toIso8601String()).toString(),
      ),
      endDate: json['endDate'] == null
          ? null
          : DateTime.tryParse(json['endDate'].toString()),
      calendar: ((json['calendar'] as List?) ?? [])
          .map((e) => CalendarDay.fromJson(e))
          .toList(),
    );
  }
}

class CalendarDay {
  CalendarDay({required this.date, required this.activities});

  final DateTime date;
  final List<ItineraryActivity> activities;

  factory CalendarDay.fromJson(dynamic jsonRaw) {
    final json = Map<String, dynamic>.from(jsonRaw as Map);
    return CalendarDay(
      date: DateTime.parse(
        (json['date'] ?? DateTime.now().toIso8601String()).toString(),
      ),
      activities: ((json['activities'] as List?) ?? [])
          .map((e) => ItineraryActivity.fromJson(e))
          .toList(),
    );
  }
}

class ItineraryActivity {
  ItineraryActivity({
    required this.id,
    required this.tripId,
    required this.date,
    required this.title,
    required this.activityType,
    required this.timeSlot,
    required this.isCompleted,
    this.description,
    this.location,
    this.notes,
  });

  final int id;
  final int tripId;
  final DateTime date;
  final String title;
  final String? description;
  final int activityType;
  final String? location;
  final int timeSlot;
  final String? notes;
  final bool isCompleted;

  factory ItineraryActivity.fromJson(dynamic jsonRaw) {
    final json = Map<String, dynamic>.from(jsonRaw as Map);
    return ItineraryActivity(
      id: json['id'] as int,
      tripId: json['tripId'] as int,
      date: DateTime.parse(
        (json['date'] ?? DateTime.now().toIso8601String()).toString(),
      ),
      title: (json['title'] ?? '').toString(),
      description: json['description']?.toString(),
      activityType: json['activityType'] as int? ?? 0,
      location: json['location']?.toString(),
      timeSlot: json['timeSlot'] as int? ?? 0,
      notes: json['notes']?.toString(),
      isCompleted: json['isCompleted'] as bool? ?? false,
    );
  }
}

class ItineraryUpsert {
  ItineraryUpsert({
    required this.tripId,
    required this.date,
    required this.title,
    required this.activityType,
    required this.timeSlot,
    required this.isCompleted,
    this.description,
    this.location,
    this.notes,
  });

  final int tripId;
  final DateTime date;
  final String title;
  final String? description;
  final int activityType;
  final String? location;
  final int timeSlot;
  final String? notes;
  final bool isCompleted;

  Map<String, dynamic> toJson() => {
    'tripId': tripId,
    'date': date.toIso8601String(),
    'title': title,
    'description': description,
    'activityType': activityType,
    'location': location,
    'timeSlot': timeSlot,
    'notes': notes,
    'isCompleted': isCompleted,
  };
}

class UserProfile {
  UserProfile({
    required this.id,
    required this.username,
    required this.email,
    this.profileImageBase64,
  });

  final int id;
  final String username;
  final String email;
  final String? profileImageBase64;

  factory UserProfile.fromJson(dynamic jsonRaw) {
    final json = Map<String, dynamic>.from(jsonRaw as Map);
    return UserProfile(
      id: json['id'] as int,
      username: (json['username'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      profileImageBase64: json['profileImageBase64']?.toString(),
    );
  }
}

class UserProfileUpdate {
  UserProfileUpdate({required this.username, this.profileImageBase64});

  final String username;
  final String? profileImageBase64;

  Map<String, dynamic> toJson() => {
    'username': username,
    'profileImageBase64': profileImageBase64,
  };
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [const TripsScreen(), const ProfileScreen()];
    return Scaffold(
      body: SafeArea(child: pages[_currentIndex]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Viaggi',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profilo',
          ),
        ],
        onDestinationSelected: (value) => setState(() => _currentIndex = value),
      ),
    );
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool registerMode = false;
  final emailCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();
  final userCtrl = TextEditingController();
  final emailFocus = FocusNode();
  final passwordFocus = FocusNode();
  bool loading = false;

  @override
  void dispose() {
    emailCtrl.dispose();
    passwordCtrl.dispose();
    userCtrl.dispose();
    emailFocus.dispose();
    passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => loading = true);
    try {
      final session = context.read<SessionStore>();
      if (registerMode) {
        await session.register(
          userCtrl.text.trim(),
          emailCtrl.text.trim(),
          passwordCtrl.text,
        );
      } else {
        await session.login(emailCtrl.text.trim(), passwordCtrl.text);
      }
      if (!mounted) return;
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const MainShell()));
    } catch (e) {
      _showError(context, e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final ctrl = TextEditingController(text: emailCtrl.text);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Recupera password'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'Email'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Invia'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (!mounted) return;
    try {
      final session = context.read<SessionStore>();
      await session._apiClient.forgotPassword(ctrl.text.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Se l\'email esiste, riceverai le istruzioni.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showError(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF005F73), Color(0xFF94D2BD)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      registerMode ? 'Crea account' : 'Bentornato',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 12),
                    if (registerMode)
                      TextField(
                        controller: userCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Username',
                        ),
                      ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: emailCtrl,
                      focusNode: emailFocus,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      selectAllOnFocus: false,
                      enableInteractiveSelection: false,
                      autofillHints: const [AutofillHints.email],
                      onTap: () {
                        if (!emailFocus.hasFocus) {
                          emailFocus.requestFocus();
                        }
                        SystemChannels.textInput.invokeMethod<void>(
                          'TextInput.show',
                        );
                      },
                      onSubmitted: (_) =>
                          FocusScope.of(context).requestFocus(passwordFocus),
                      decoration: const InputDecoration(labelText: 'Email'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: passwordCtrl,
                      focusNode: passwordFocus,
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.password],
                      onSubmitted: (_) {
                        if (!loading) {
                          _submit();
                        }
                      },
                      decoration: const InputDecoration(labelText: 'Password'),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: loading ? null : _submit,
                        child: Text(
                          loading
                              ? 'Attendere...'
                              : registerMode
                              ? 'Registrati'
                              : 'Accedi',
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () =>
                          setState(() => registerMode = !registerMode),
                      child: Text(
                        registerMode
                            ? 'Hai già un account? Accedi'
                            : 'Non hai un account? Registrati',
                      ),
                    ),
                    TextButton(
                      onPressed: _forgotPassword,
                      child: const Text('Password dimenticata?'),
                    ),
                    TextButton(
                      onPressed: () async {
                        final tokenCtrl = TextEditingController();
                        final newPwdCtrl = TextEditingController();
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Reset password'),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TextField(
                                  controller: tokenCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Token reset',
                                  ),
                                ),
                                TextField(
                                  controller: newPwdCtrl,
                                  obscureText: true,
                                  decoration: const InputDecoration(
                                    labelText: 'Nuova password',
                                  ),
                                ),
                              ],
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Annulla'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Conferma'),
                              ),
                            ],
                          ),
                        );
                        if (ok != true) {
                          return;
                        }
                        if (!mounted) {
                          return;
                        }
                        try {
                          final session = this.context.read<SessionStore>();
                          await session._apiClient.resetPassword(
                            tokenCtrl.text.trim(),
                            newPwdCtrl.text,
                          );
                          if (!mounted) {
                            return;
                          }
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Password aggiornata con successo.',
                              ),
                            ),
                          );
                        } catch (e) {
                          if (!mounted) {
                            return;
                          }
                          _showError(
                            this.context,
                            e.toString().replaceFirst('Exception: ', ''),
                          );
                        }
                      },
                      child: const Text('Hai un token di reset?'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class TripsScreen extends StatefulWidget {
  const TripsScreen({super.key});

  @override
  State<TripsScreen> createState() => _TripsScreenState();
}

class _TripsScreenState extends State<TripsScreen> {
  late Future<List<Trip>> _future;
  final joinCodeCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Trip>> _load() {
    final session = context.read<SessionStore>();
    return session._apiClient.getTrips(session.token!);
  }

  Future<void> _reload() async {
    setState(() {
      _future = _load();
    });
  }

  Future<void> _openTripForm([Trip? trip]) async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => TripFormSheet(existing: trip),
    );
    if (created == true) {
      await _reload();
    }
  }

  Future<void> _joinTrip() async {
    try {
      final session = context.read<SessionStore>();
      await session._apiClient.joinTrip(
        session.token!,
        joinCodeCtrl.text.trim(),
      );
      joinCodeCtrl.clear();
      await _reload();
    } catch (e) {
      if (!mounted) return;
      _showError(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionStore>();
    return Scaffold(
      appBar: AppBar(
        title: Text('Viaggi di ${session.username ?? ''}'),
        actions: [
          IconButton(
            onPressed: () async {
              await session.logout();
              if (!context.mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const AuthScreen()),
                (route) => false,
              );
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: joinCodeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Codice condivisione',
                      prefixIcon: Icon(Icons.group_add),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _joinTrip,
                  child: const Text('Unisciti'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: FutureBuilder<List<Trip>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Errore: ${snapshot.error}'));
                  }
                  final trips = snapshot.data ?? [];
                  if (trips.isEmpty) {
                    return const Center(
                      child: Text('Nessun viaggio ancora. Crea il primo.'),
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: _reload,
                    child: ListView.builder(
                      itemCount: trips.length,
                      itemBuilder: (context, index) {
                        final trip = trips[index];
                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.secondaryContainer,
                              backgroundImage: _base64ImageProvider(
                                trip.tripImageBase64,
                              ),
                              child: trip.tripImageBase64 == null
                                  ? const Icon(Icons.flight_takeoff)
                                  : null,
                            ),
                            title: Text(trip.title),
                            subtitle: Text(
                              '${DateFormat('dd/MM/yyyy').format(trip.startDate)} - ${trip.endDate != null ? DateFormat('dd/MM/yyyy').format(trip.endDate!) : 'aperto'}',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit),
                                  onPressed: () => _openTripForm(trip),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () async {
                                    final confirmed = await _askConfirm(
                                      context,
                                      'Eliminare il viaggio "${trip.title}"?',
                                    );
                                    if (!confirmed) {
                                      return;
                                    }
                                    if (!mounted) {
                                      return;
                                    }
                                    final session = this.context
                                        .read<SessionStore>();
                                    await session._apiClient.deleteTrip(
                                      session.token!,
                                      trip.id,
                                    );
                                    await _reload();
                                  },
                                ),
                              ],
                            ),
                            onTap: () {
                              Navigator.of(context)
                                  .push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          TripDetailScreen(tripId: trip.id),
                                    ),
                                  )
                                  .then((_) => _reload());
                            },
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openTripForm(),
        icon: const Icon(Icons.add),
        label: const Text('Nuovo viaggio'),
      ),
    );
  }
}

class TripFormSheet extends StatefulWidget {
  const TripFormSheet({super.key, this.existing});

  final Trip? existing;

  @override
  State<TripFormSheet> createState() => _TripFormSheetState();
}

class _TripFormSheetState extends State<TripFormSheet> {
  late final titleCtrl = TextEditingController(text: widget.existing?.title);
  late final descCtrl = TextEditingController(
    text: widget.existing?.description,
  );
  DateTime start = DateTime.now();
  DateTime? end;
  XFile? image;
  bool loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      start = widget.existing!.startDate;
      end = widget.existing!.endDate;
    }
  }

  Future<void> _pickImage() async {
    final selected = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (selected != null) setState(() => image = selected);
  }

  Future<void> _submit() async {
    setState(() => loading = true);
    try {
      final session = context.read<SessionStore>();
      String? imageBase64 = widget.existing?.tripImageBase64;
      if (image != null) {
        imageBase64 = base64Encode(await image!.readAsBytes());
      }
      final body = TripUpsert(
        title: titleCtrl.text.trim(),
        description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
        startDate: start,
        endDate: end,
        tripImageBase64: imageBase64,
      );
      if (widget.existing == null) {
        await session._apiClient.createTrip(session.token!, body);
      } else {
        await session._apiClient.updateTrip(
          session.token!,
          widget.existing!.id,
          body,
        );
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      _showError(context, e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.existing == null ? 'Nuovo viaggio' : 'Modifica viaggio',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 10),
          TextField(
            controller: titleCtrl,
            decoration: const InputDecoration(labelText: 'Titolo'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: descCtrl,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Descrizione'),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: start,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2035),
                    );
                    if (picked != null) setState(() => start = picked);
                  },
                  icon: const Icon(Icons.event),
                  label: Text(
                    'Inizio ${DateFormat('dd/MM/yyyy').format(start)}',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final initial = end ?? start;
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: initial,
                      firstDate: start,
                      lastDate: DateTime(2035),
                    );
                    if (picked != null) setState(() => end = picked);
                  },
                  icon: const Icon(Icons.event_available),
                  label: Text(
                    end == null
                        ? 'Fine (opzionale)'
                        : 'Fine ${DateFormat('dd/MM/yyyy').format(end!)}',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.image),
                  label: const Text('Immagine viaggio'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: loading ? null : _submit,
              child: const Text('Salva'),
            ),
          ),
        ],
      ),
    );
  }
}

class TripDetailScreen extends StatefulWidget {
  const TripDetailScreen({super.key, required this.tripId});

  final int tripId;

  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen> {
  late Future<Trip> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Trip> _load() {
    final session = context.read<SessionStore>();
    return session._apiClient.getTrip(session.token!, widget.tripId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dettaglio viaggio'),
        actions: [
          IconButton(
            onPressed: () async {
              final session = this.context.read<SessionStore>();
              final refreshed = await session._apiClient.shareTrip(
                session.token!,
                widget.tripId,
              );
              await Clipboard.setData(ClipboardData(text: refreshed.shareCode));
              if (!mounted) {
                return;
              }
              ScaffoldMessenger.of(this.context).showSnackBar(
                SnackBar(
                  content: Text('Codice copiato: ${refreshed.shareCode}'),
                ),
              );
              setState(() => _future = Future.value(refreshed));
            },
            icon: const Icon(Icons.share),
          ),
        ],
      ),
      body: FutureBuilder<Trip>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Errore: ${snapshot.error}'));
          }
          final trip = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        trip.title,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(trip.description ?? 'Nessuna descrizione'),
                      const SizedBox(height: 8),
                      Text('Condivisione: ${trip.shareCode}'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Theme.of(context).dividerColor),
                ),
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Ricordi e trip items'),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => TripItemsScreen(tripId: trip.id),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Theme.of(context).dividerColor),
                ),
                leading: const Icon(Icons.luggage_outlined),
                title: const Text('Bagagli'),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => LuggageScreen(tripId: trip.id),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Theme.of(context).dividerColor),
                ),
                leading: const Icon(Icons.calendar_month_outlined),
                title: const Text('Itinerario'),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ItineraryScreen(tripId: trip.id),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class TripItemsScreen extends StatefulWidget {
  const TripItemsScreen({super.key, required this.tripId});

  final int tripId;

  @override
  State<TripItemsScreen> createState() => _TripItemsScreenState();
}

class _TripItemsScreenState extends State<TripItemsScreen> {
  late Future<List<TripItem>> _future;
  String? _activeType;

  static const List<String> _filters = [
    'Restaurant',
    'Hotel',
    'Attraction',
    'Note',
  ];

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<TripItem>> _load() {
    final session = context.read<SessionStore>();
    return session._apiClient.getTripItems(session.token!, widget.tripId);
  }

  Future<void> _reload() async {
    setState(() => _future = _load());
  }

  Future<void> _openTripItemForm([TripItem? existing]) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) =>
          TripItemFormSheet(tripId: widget.tripId, existing: existing),
    );
    if (ok == true) {
      await _reload();
    }
  }

  List<TripItem> _applyFilter(List<TripItem> items) {
    if (_activeType == null) {
      return items;
    }
    return items.where((item) => item.type == _activeType).toList();
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'Restaurant':
        return Icons.restaurant;
      case 'Hotel':
        return Icons.hotel;
      case 'Attraction':
        return Icons.place;
      case 'Photo':
        return Icons.photo_camera;
      default:
        return Icons.sticky_note_2_outlined;
    }
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'Restaurant':
        return 'Ristorante';
      case 'Hotel':
        return 'Hotel';
      case 'Attraction':
        return 'Attrazione';
      case 'Photo':
        return 'Foto';
      default:
        return 'Nota';
    }
  }

  Widget _buildTripItemCard(TripItem item) {
    final imageProvider = _tripItemImageProvider(item.imageUrl);
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _openTripItemForm(item),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.primaryContainer,
                    child: Icon(
                      _typeIcon(item.type),
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${DateFormat('dd/MM/yyyy').format(item.createdAt)}${item.location != null ? ' • ${item.location}' : ''}',
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (imageProvider != null)
              Image(
                image: imageProvider,
                height: 210,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const SizedBox.shrink(),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _typeLabel(item.type),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  if (item.description != null &&
                      item.description!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      item.description!,
                      style: const TextStyle(fontSize: 16, height: 1.35),
                    ),
                  ],
                  if (item.rating != null && item.rating! > 0) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _buildRatingStars(item.rating!),
                        const SizedBox(width: 8),
                        Text('${item.rating} / 5'),
                      ],
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _openTripItemForm(item),
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('Modifica'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red.shade700,
                          ),
                          onPressed: () async {
                            final confirmed = await _askConfirm(
                              context,
                              'Eliminare "${item.title}"?',
                            );
                            if (!confirmed) {
                              return;
                            }
                            if (!mounted) {
                              return;
                            }
                            final session = context.read<SessionStore>();
                            await session._apiClient.deleteTripItem(
                              session.token!,
                              item.id,
                            );
                            await _reload();
                          },
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Elimina'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Travel Diary Entries')),
      body: FutureBuilder<List<TripItem>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Errore: ${snapshot.error}'));
          }
          final items = snapshot.data ?? [];
          final filtered = _applyFilter(items);
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              padding: const EdgeInsets.all(14),
              children: [
                FilledButton.icon(
                  onPressed: () => _openTripItemForm(),
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('Add Entry'),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _filters.map((type) {
                        return ChoiceChip(
                          selected: _activeType == type,
                          label: Text(_typeLabel(type)),
                          onSelected: (selected) {
                            setState(
                              () => _activeType = selected ? type : null,
                            );
                          },
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                if (items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Text(
                        'Nessun trip item ancora. Aggiungi il primo.',
                      ),
                    ),
                  )
                else if (filtered.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 30),
                    child: Center(
                      child: Text('Nessun elemento con i filtri selezionati.'),
                    ),
                  )
                else
                  ...filtered.map(_buildTripItemCard),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openTripItemForm(),
        icon: const Icon(Icons.add),
        label: const Text('Aggiungi'),
      ),
    );
  }
}

class TripItemFormSheet extends StatefulWidget {
  const TripItemFormSheet({super.key, required this.tripId, this.existing});

  final int tripId;
  final TripItem? existing;

  @override
  State<TripItemFormSheet> createState() => _TripItemFormSheetState();
}

class _TripItemFormSheetState extends State<TripItemFormSheet> {
  late final titleCtrl = TextEditingController(text: widget.existing?.title);
  late final descCtrl = TextEditingController(
    text: widget.existing?.description,
  );
  late final locationCtrl = TextEditingController(
    text: widget.existing?.location,
  );
  String type = 'Note';
  int rating = 0;
  XFile? image;

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      type = widget.existing!.type;
      rating = widget.existing!.rating ?? 0;
    }
  }

  Future<void> _pickImage() async {
    final selected = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (selected != null) setState(() => image = selected);
  }

  Future<void> _submit() async {
    try {
      final session = context.read<SessionStore>();
      final payload = TripItemUpsert(
        title: titleCtrl.text.trim(),
        description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
        type: type,
        location: locationCtrl.text.trim().isEmpty
            ? null
            : locationCtrl.text.trim(),
        rating: rating > 0 ? rating : null,
        image: image,
      );
      if (widget.existing == null) {
        await session._apiClient.createTripItem(
          session.token!,
          widget.tripId,
          payload,
        );
      } else {
        await session._apiClient.updateTripItem(
          session.token!,
          widget.existing!.id,
          payload,
        );
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      _showError(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.existing == null ? 'Nuovo trip item' : 'Modifica trip item',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          TextField(
            controller: titleCtrl,
            decoration: const InputDecoration(labelText: 'Titolo'),
          ),
          TextField(
            controller: descCtrl,
            decoration: const InputDecoration(labelText: 'Descrizione'),
          ),
          DropdownButtonFormField<String>(
            initialValue: type,
            items: const [
              'Photo',
              'Note',
              'Restaurant',
              'Hotel',
              'Attraction',
            ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: (value) => setState(() => type = value ?? 'Note'),
            decoration: const InputDecoration(labelText: 'Tipo'),
          ),
          TextField(
            controller: locationCtrl,
            decoration: const InputDecoration(labelText: 'Luogo'),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Rating',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Row(
            children: [
              for (var i = 1; i <= 5; i++)
                IconButton(
                  onPressed: () => setState(() => rating = i),
                  icon: Icon(
                    i <= rating
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    color: i <= rating ? Colors.amber.shade700 : Colors.grey,
                  ),
                ),
              if (rating > 0)
                TextButton(
                  onPressed: () => setState(() => rating = 0),
                  child: const Text('Reset'),
                ),
            ],
          ),
          if (widget.existing?.imageUrl != null && image == null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image(
                  image: _tripItemImageProvider(widget.existing!.imageUrl)!,
                  height: 120,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const SizedBox.shrink(),
                ),
              ),
            ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _pickImage,
            icon: const Icon(Icons.photo),
            label: Text(image == null ? 'Aggiungi foto' : image!.name),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton(onPressed: _submit, child: const Text('Salva')),
          ),
        ],
      ),
    );
  }
}

class LuggageScreen extends StatefulWidget {
  const LuggageScreen({super.key, required this.tripId});

  final int tripId;

  @override
  State<LuggageScreen> createState() => _LuggageScreenState();
}

class _LuggageScreenState extends State<LuggageScreen> {
  late Future<List<Luggage>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Luggage>> _load() {
    final session = context.read<SessionStore>();
    return session._apiClient.getLuggages(session.token!, widget.tripId);
  }

  Future<void> _reload() async {
    setState(() => _future = _load());
  }

  int _packedCount(Luggage luggage) =>
      luggage.items.where((item) => item.isPacked).length;

  double _progress(Luggage luggage) {
    if (luggage.items.isEmpty) {
      return 0;
    }
    return _packedCount(luggage) / luggage.items.length;
  }

  Future<void> _createLuggage() async {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nuovo bagaglio'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Nome'),
            ),
            TextField(
              controller: descCtrl,
              decoration: const InputDecoration(labelText: 'Descrizione'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Crea'),
          ),
        ],
      ),
    );
    if (ok != true) {
      return;
    }
    if (!mounted) {
      return;
    }
    final session = context.read<SessionStore>();
    await session._apiClient.createLuggage(
      session.token!,
      widget.tripId,
      LuggageUpsert(
        name: nameCtrl.text.trim(),
        description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
      ),
    );
    await _reload();
  }

  Future<void> _exportLuggage(Luggage luggage) async {
    final session = context.read<SessionStore>();
    final trips = await session._apiClient.getTrips(session.token!);
    if (!mounted) {
      return;
    }
    final destinationTrips = trips.where((trip) => trip.id != widget.tripId).toList();

    if (destinationTrips.isEmpty) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Create another trip before exporting luggage.')),
      );
      return;
    }

    int selectedTripId = destinationTrips.first.id;
    final targetTripId = await showDialog<int>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Export luggage'),
          content: DropdownButtonFormField<int>(
            initialValue: selectedTripId,
            decoration: const InputDecoration(
              labelText: 'Destination trip',
              border: OutlineInputBorder(),
            ),
            items: destinationTrips
                .map(
                  (trip) => DropdownMenuItem<int>(
                    value: trip.id,
                    child: Text(trip.title),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value == null) {
                return;
              }
              setDialogState(() => selectedTripId = value);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, selectedTripId),
              child: const Text('Export'),
            ),
          ],
        ),
      ),
    );

    if (targetTripId == null) {
      return;
    }

    await session._apiClient.exportLuggage(session.token!, luggage.id, targetTripId);

    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Luggage exported successfully.')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Luggage Lists')),
      body: FutureBuilder<List<Luggage>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Errore: ${snapshot.error}'));
          }
          final luggages = snapshot.data ?? [];
          if (luggages.isEmpty) {
            return const Center(child: Text('Nessun bagaglio creato'));
          }
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView.builder(
              padding: const EdgeInsets.all(14),
              itemCount: luggages.length,
              itemBuilder: (context, index) {
                final luggage = luggages[index];
                final progress = _progress(luggage);
                final packedCount = _packedCount(luggage);
                return Card(
                  clipBehavior: Clip.antiAlias,
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 14),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.primary,
                              child: const Icon(
                                Icons.luggage,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    luggage.name,
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${luggage.items.length} items ($packedCount packed)',
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (luggage.description != null &&
                            luggage.description!.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(luggage.description!),
                        ],
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            minHeight: 8,
                            value: progress,
                            backgroundColor: Colors.grey.shade200,
                            color: const Color(0xFF1E9E62),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text('${(progress * 100).round()}% packed'),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        LuggageDetailScreen(luggage: luggage),
                                  ),
                                ),
                                icon: const Icon(Icons.list_alt),
                                label: const Text('Manage Items'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _exportLuggage(luggage),
                                icon: const Icon(Icons.outbox_outlined),
                                label: const Text('Export'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.redAccent,
                            ),
                            onPressed: () async {
                              final confirmed = await _askConfirm(
                                context,
                                'Eliminare il bagaglio "${luggage.name}"?',
                              );
                              if (!confirmed) {
                                return;
                              }
                              if (!context.mounted) {
                                return;
                              }
                              final session = context.read<SessionStore>();
                              await session._apiClient.deleteLuggage(
                                session.token!,
                                luggage.id,
                              );
                              await _reload();
                            },
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('Delete'),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createLuggage,
        icon: const Icon(Icons.add),
        label: const Text('Add Luggage List'),
      ),
    );
  }
}

class LuggageDetailScreen extends StatefulWidget {
  const LuggageDetailScreen({super.key, required this.luggage});

  final Luggage luggage;

  @override
  State<LuggageDetailScreen> createState() => _LuggageDetailScreenState();
}

class _LuggageDetailScreenState extends State<LuggageDetailScreen> {
  late Luggage luggage;
  bool isSaving = false;
  bool isLoading = false;
  bool isItemFormVisible = false;
  String itemName = '';
  String itemNotes = '';
  int itemQuantity = 1;
  LuggageItem? editingItem;

  @override
  void initState() {
    super.initState();
    luggage = widget.luggage;
  }

  int get packedCount => luggage.items.where((e) => e.isPacked).length;

  double get progress =>
      luggage.items.isEmpty ? 0 : packedCount / luggage.items.length;

  Future<void> _reloadFromServer() async {
    setState(() => isLoading = true);
    try {
      final session = context.read<SessionStore>();
      final luggages = await session._apiClient.getLuggages(
        session.token!,
        luggage.id,
      );
      final refreshed = luggages.firstWhere(
        (e) => e.id == luggage.id,
        orElse: () => luggage,
      );
      setState(() => luggage = refreshed);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _startCreate() {
    setState(() {
      isItemFormVisible = true;
      editingItem = null;
      itemName = '';
      itemNotes = '';
      itemQuantity = 1;
    });
  }

  void _closeForm() {
    setState(() {
      isItemFormVisible = false;
      editingItem = null;
      itemName = '';
      itemNotes = '';
      itemQuantity = 1;
    });
  }

  void _startEdit(LuggageItem item) {
    setState(() {
      isItemFormVisible = true;
      editingItem = item;
      itemName = item.name;
      itemNotes = item.notes ?? '';
      itemQuantity = item.quantity;
    });
  }

  Future<void> _saveItem() async {
    if (itemName.trim().isEmpty) {
      return;
    }
    setState(() => isSaving = true);
    try {
      final session = context.read<SessionStore>();
      if (editingItem == null) {
        await session._apiClient.createLuggageItem(
          session.token!,
          luggage.id,
          LuggageItemUpsert(
            name: itemName.trim(),
            quantity: itemQuantity,
            notes: itemNotes.trim().isEmpty ? null : itemNotes.trim(),
            isPacked: false,
          ),
        );
      } else {
        await session._apiClient.updateLuggageItem(
          session.token!,
          editingItem!.id,
          LuggageItemUpsert(
            name: itemName.trim(),
            quantity: itemQuantity,
            notes: itemNotes.trim().isEmpty ? null : itemNotes.trim(),
            isPacked: editingItem!.isPacked,
          ),
        );
      }
      await _reloadFromServer();
      _closeForm();
    } catch (e) {
      if (!mounted) return;
      _showError(context, e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  Future<void> _togglePacked(LuggageItem item, bool packed) async {
    final session = context.read<SessionStore>();
    await session._apiClient.updateLuggageItem(
      session.token!,
      item.id,
      LuggageItemUpsert(
        name: item.name,
        quantity: item.quantity,
        notes: item.notes,
        isPacked: packed,
      ),
    );
    await _reloadFromServer();
  }

  Future<void> _deleteItem(LuggageItem item) async {
    final confirmed = await _askConfirm(context, 'Eliminare "${item.name}"?');
    if (!confirmed) {
      return;
    }
    if (!mounted) {
      return;
    }
    final session = context.read<SessionStore>();
    await session._apiClient.deleteLuggageItem(session.token!, item.id);
    await _reloadFromServer();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.luggage.name),
            if (widget.luggage.description != null &&
                widget.luggage.description!.isNotEmpty)
              Text(
                widget.luggage.description!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              onPressed: _startCreate,
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Add Item'),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _reloadFromServer,
        child: ListView(
          padding: const EdgeInsets.all(14),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Packing Progres',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '$packedCount / ${luggage.items.length} items',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        minHeight: 10,
                        value: progress,
                        backgroundColor: Colors.grey.shade200,
                        color: const Color(0xFF1E9E62),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('${(progress * 100).round()}% complete'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (isItemFormVisible) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        editingItem == null ? 'Add New Item' : 'Edit Item',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        decoration: const InputDecoration(
                          labelText: 'Item Name',
                        ),
                        controller: TextEditingController(text: itemName),
                        onChanged: (value) => itemName = value,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              decoration: const InputDecoration(
                                labelText: 'Quantity',
                              ),
                              keyboardType: TextInputType.number,
                              controller: TextEditingController(
                                text: itemQuantity.toString(),
                              ),
                              onChanged: (value) =>
                                  itemQuantity = int.tryParse(value) ?? 1,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        decoration: const InputDecoration(labelText: 'Notes'),
                        controller: TextEditingController(text: itemNotes),
                        onChanged: (value) => itemNotes = value,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _closeForm,
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton(
                              onPressed: isSaving ? null : _saveItem,
                              child: Text(isSaving ? 'Saving...' : 'Save'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 36),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              ...luggage.items.map(
                (item) => Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade300),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Checkbox(
                          value: item.isPacked,
                          onChanged: (value) =>
                              _togglePacked(item, value ?? false),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      item.name,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        decoration: item.isPacked
                                            ? TextDecoration.lineThrough
                                            : TextDecoration.none,
                                      ),
                                    ),
                                  ),
                                  if (item.quantity > 1)
                                    Container(
                                      margin: const EdgeInsets.only(left: 8),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade500,
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                      ),
                                      child: Text(
                                        '${item.quantity}x',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: item.isPacked
                                          ? const Color(0xFF1E9E62)
                                          : Colors.grey.shade400,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      item.isPacked ? 'Packed' : 'Open',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (item.notes != null &&
                                  item.notes!.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  item.notes!,
                                  style: TextStyle(
                                    color: item.isPacked
                                        ? Colors.grey.shade600
                                        : Colors.grey.shade700,
                                    decoration: item.isPacked
                                        ? TextDecoration.lineThrough
                                        : TextDecoration.none,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () => _startEdit(item),
                          icon: const Icon(
                            Icons.edit_outlined,
                            color: Colors.blue,
                          ),
                        ),
                        IconButton(
                          onPressed: () => _deleteItem(item),
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.redAccent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class ItineraryScreen extends StatefulWidget {
  const ItineraryScreen({super.key, required this.tripId});

  final int tripId;

  @override
  State<ItineraryScreen> createState() => _ItineraryScreenState();
}

class _ItineraryScreenState extends State<ItineraryScreen> {
  late Future<TripCalendar> _future;
  DateTime _weekStart = DateTime.now();
  bool _weekInitialized = false;

  @override
  void initState() {
    super.initState();
    _future = _load().then((calendar) {
      if (!_weekInitialized) {
        _weekStart = _startOfWeek(calendar.startDate);
        _weekInitialized = true;
      }
      return calendar;
    });
  }

  Future<TripCalendar> _load() {
    final session = context.read<SessionStore>();
    return session._apiClient.getTripCalendar(session.token!, widget.tripId);
  }

  Future<void> _reload() async {
    setState(() => _future = _load());
  }

  DateTime _startOfWeek(DateTime date) {
    final day = DateUtils.dateOnly(date);
    final weekday = day.weekday; // lun=1 ... dom=7
    return day.subtract(Duration(days: weekday - 1));
  }

  String _monthShortIt(int month) {
    const values = [
      'gen',
      'feb',
      'mar',
      'apr',
      'mag',
      'giu',
      'lug',
      'ago',
      'set',
      'ott',
      'nov',
      'dic',
    ];
    return values[month - 1];
  }

  String _weekdayShortIt(int weekday) {
    const values = ['Lun', 'Mar', 'Mer', 'Gio', 'Ven', 'Sab', 'Dom'];
    return values[weekday - 1];
  }

  String _formatShortDateIt(DateTime date, {bool includeYear = false}) {
    final base =
        '${date.day.toString().padLeft(2, '0')} ${_monthShortIt(date.month)}';
    return includeYear ? '$base ${date.year}' : base;
  }

  String _formatLongDateIt(DateTime date) {
    const weekdays = [
      'lunedì',
      'martedì',
      'mercoledì',
      'giovedì',
      'venerdì',
      'sabato',
      'domenica',
    ];
    const months = [
      'gennaio',
      'febbraio',
      'marzo',
      'aprile',
      'maggio',
      'giugno',
      'luglio',
      'agosto',
      'settembre',
      'ottobre',
      'novembre',
      'dicembre',
    ];
    return '${weekdays[date.weekday - 1]} ${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _weekRangeLabel(DateTime weekStart) {
    final weekEnd = weekStart.add(const Duration(days: 6));
    return '${_formatShortDateIt(weekStart)} - ${_formatShortDateIt(weekEnd, includeYear: true)}';
  }

  List<DateTime> _weekDays() => List.generate(
    7,
    (index) => DateUtils.dateOnly(_weekStart.add(Duration(days: index))),
  );

  bool _isTripDay(DateTime day, TripCalendar calendar) {
    final start = DateUtils.dateOnly(calendar.startDate);
    final end = DateUtils.dateOnly(calendar.endDate ?? calendar.startDate);
    return !day.isBefore(start) && !day.isAfter(end);
  }

  Color _activityBackgroundColor(int activityType) {
    switch (activityType) {
      case 0:
        return const Color.fromRGBO(255, 193, 7, 0.15); // Turismo
      case 1:
        return const Color.fromRGBO(220, 53, 69, 0.15); // Ristorante
      case 2:
        return const Color.fromRGBO(108, 117, 125, 0.15); // Trasporto
      case 3:
        return const Color.fromRGBO(13, 202, 240, 0.15); // Alloggio
      case 4:
        return const Color.fromRGBO(214, 51, 132, 0.15); // Shopping
      case 5:
        return const Color.fromRGBO(111, 66, 193, 0.15); // Intrattenimento
      case 6:
        return const Color.fromRGBO(25, 135, 84, 0.15); // Outdoor
      case 7:
        return const Color.fromRGBO(13, 110, 253, 0.15); // Culturale
      case 8:
        return const Color.fromRGBO(214, 51, 132, 0.12); // Relax
      case 9:
        return const Color.fromRGBO(108, 117, 125, 0.12); // Business
      default:
        return const Color.fromRGBO(173, 181, 189, 0.15); // Altro
    }
  }

  IconData _activityIcon(int activityType) {
    switch (activityType) {
      case 0:
        return Icons.landscape_outlined;
      case 1:
        return Icons.restaurant_outlined;
      case 2:
        return Icons.directions_transit_outlined;
      case 3:
        return Icons.hotel_outlined;
      case 4:
        return Icons.shopping_bag_outlined;
      case 5:
        return Icons.movie_outlined;
      case 6:
        return Icons.terrain_outlined;
      case 7:
        return Icons.museum_outlined;
      case 8:
        return Icons.spa_outlined;
      case 9:
        return Icons.business_center_outlined;
      default:
        return Icons.category_outlined;
    }
  }

  IconData _timeSlotIcon(int slot) =>
      slot == 0 ? Icons.wb_sunny_outlined : Icons.wb_cloudy_outlined;

  String _timeSlotLabel(int slot) => slot == 0 ? 'Mattina' : 'Pomeriggio';

  Future<void> _openCreateActivity(DateTime date, {required int slot}) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ItineraryFormSheet(
        tripId: widget.tripId,
        date: date,
        initialTimeSlot: slot,
      ),
    );
    if (ok == true) {
      await _reload();
    }
  }

  Future<void> _openEditActivity(ItineraryActivity activity) async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ItineraryActivityEditorScreen(
          tripId: widget.tripId,
          existing: activity,
        ),
      ),
    );
    if (ok == true) {
      await _reload();
    }
  }

  Future<void> _deleteActivity(ItineraryActivity activity) async {
    final confirmed = await _askConfirm(context, 'Eliminare questa attività?');
    if (!confirmed) {
      return;
    }
    if (!mounted) {
      return;
    }
    final session = context.read<SessionStore>();
    await session._apiClient.deleteItinerary(session.token!, activity.id);
    await _reload();
  }

  Widget _buildActivityCard(ItineraryActivity activity) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: _activityBackgroundColor(activity.activityType),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _activityIcon(activity.activityType),
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    activity.title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            if (activity.location != null && activity.location!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 14,
                      color: Colors.grey.shade700,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        activity.location!,
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    ),
                  ],
                ),
              ),
            if (activity.description != null &&
                activity.description!.isNotEmpty)
              Text(
                activity.description!,
                style: TextStyle(color: Colors.grey.shade800),
              ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _openEditActivity(activity),
                  icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                  tooltip: 'Modifica',
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _deleteActivity(activity),
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.redAccent,
                  ),
                  tooltip: 'Elimina',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlotSection({
    required DateTime day,
    required int slot,
    required List<ItineraryActivity> activities,
  }) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                Icon(
                  _timeSlotIcon(slot),
                  size: 16,
                  color: Colors.grey.shade700,
                ),
                const SizedBox(width: 6),
                Text(
                  _timeSlotLabel(slot),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                SizedBox(
                  height: 28,
                  width: 28,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
                    onPressed: () => _openCreateActivity(day, slot: slot),
                    child: const Icon(Icons.add, size: 16),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          if (activities.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
                color: Colors.grey.shade50,
              ),
              child: const Center(
                child: Text(
                  'Nessuna attività',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            ...activities.map(_buildActivityCard),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Itinerario')),
      body: FutureBuilder<TripCalendar>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Errore: ${snapshot.error}'));
          }
          final calendar = snapshot.data!;
          final events = <DateTime, List<ItineraryActivity>>{};
          for (final day in calendar.calendar) {
            events[DateUtils.dateOnly(day.date)] = List<ItineraryActivity>.from(
              day.activities,
            )..sort((a, b) => a.id.compareTo(b.id));
          }

          final weekDays = _weekDays();
          final tripStart = DateUtils.dateOnly(calendar.startDate);
          final tripEnd = DateUtils.dateOnly(
            calendar.endDate ?? calendar.startDate,
          );

          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => setState(
                        () => _weekStart = _weekStart.subtract(
                          const Duration(days: 7),
                        ),
                      ),
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          _weekRangeLabel(_weekStart),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => setState(
                        () => _weekStart = _weekStart.add(
                          const Duration(days: 7),
                        ),
                      ),
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          calendar.tripTitle,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Dal ${_formatLongDateIt(tripStart)} al ${_formatLongDateIt(tripEnd)}',
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Wrap(
                          spacing: 8,
                          children: [
                            Chip(
                              avatar: Icon(Icons.wb_sunny_outlined, size: 16),
                              label: Text('Mattina'),
                            ),
                            Chip(
                              avatar: Icon(Icons.wb_cloudy_outlined, size: 16),
                              label: Text('Pomeriggio'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 620,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: weekDays
                          .where((day) => _isTripDay(day, calendar))
                          .map((day) {
                            final activities =
                                events[day] ?? const <ItineraryActivity>[];
                            final morning = activities
                                .where((a) => a.timeSlot == 0)
                                .toList();
                            final afternoon = activities
                                .where((a) => a.timeSlot == 1)
                                .toList();
                            return SizedBox(
                              height: 620,
                              width: 360,
                              child: Card(
                                margin: const EdgeInsets.only(right: 12),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: SingleChildScrollView(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              _weekdayShortIt(day.weekday),
                                              style: TextStyle(
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.onSurfaceVariant,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              day.day.toString(),
                                              style: const TextStyle(
                                                fontSize: 28,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        ),
                                        _buildSlotSection(
                                          day: day,
                                          slot: 0,
                                          activities: morning,
                                        ),
                                        _buildSlotSection(
                                          day: day,
                                          slot: 1,
                                          activities: afternoon,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          })
                          .toList(),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class ItineraryFormSheet extends StatefulWidget {
  const ItineraryFormSheet({
    super.key,
    required this.tripId,
    required this.date,
    this.initialTimeSlot,
  });

  final int tripId;
  final DateTime date;
  final int? initialTimeSlot;

  @override
  State<ItineraryFormSheet> createState() => _ItineraryFormSheetState();
}

class ItineraryActivityEditorScreen extends StatefulWidget {
  const ItineraryActivityEditorScreen({
    super.key,
    required this.tripId,
    required this.existing,
  });

  final int tripId;
  final ItineraryActivity existing;

  @override
  State<ItineraryActivityEditorScreen> createState() =>
      _ItineraryActivityEditorScreenState();
}

class _ItineraryActivityEditorScreenState
    extends State<ItineraryActivityEditorScreen> {
  late DateTime date;
  late final titleCtrl = TextEditingController(text: widget.existing.title);
  late final descCtrl = TextEditingController(
    text: widget.existing.description,
  );
  late final locationCtrl = TextEditingController(
    text: widget.existing.location,
  );
  late final notesCtrl = TextEditingController(text: widget.existing.notes);
  late int activityType = widget.existing.activityType;
  late int timeSlot = widget.existing.timeSlot;
  bool loading = false;

  @override
  void initState() {
    super.initState();
    date = DateUtils.dateOnly(widget.existing.date);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() => date = DateUtils.dateOnly(picked));
    }
  }

  Future<void> _save() async {
    setState(() => loading = true);
    try {
      final session = context.read<SessionStore>();
      await session._apiClient.updateItinerary(
        session.token!,
        widget.existing.id,
        ItineraryUpsert(
          tripId: widget.tripId,
          date: date,
          title: titleCtrl.text.trim(),
          description: descCtrl.text.trim().isEmpty
              ? null
              : descCtrl.text.trim(),
          activityType: activityType,
          location: locationCtrl.text.trim().isEmpty
              ? null
              : locationCtrl.text.trim(),
          timeSlot: timeSlot,
          notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
          isCompleted: true,
        ),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      _showError(context, e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await _askConfirm(context, 'Eliminare questa attività?');
    if (!confirmed) {
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() => loading = true);
    try {
      final session = context.read<SessionStore>();
      await session._apiClient.deleteItinerary(
        session.token!,
        widget.existing.id,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      _showError(context, e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Modifica Attività')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            readOnly: true,
            onTap: _pickDate,
            decoration: InputDecoration(
              labelText: 'Data *',
              suffixIcon: const Icon(Icons.calendar_today),
              hintText: DateFormat('dd/MM/yyyy').format(date),
            ),
            controller: TextEditingController(
              text: DateFormat('dd/MM/yyyy').format(date),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: titleCtrl,
            decoration: const InputDecoration(labelText: 'Titolo *'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: activityType,
            items: const [
              DropdownMenuItem(value: 0, child: Text('Turismo')),
              DropdownMenuItem(value: 1, child: Text('Ristorante')),
              DropdownMenuItem(value: 2, child: Text('Trasporto')),
              DropdownMenuItem(value: 3, child: Text('Alloggio')),
              DropdownMenuItem(value: 4, child: Text('Shopping')),
              DropdownMenuItem(value: 5, child: Text('Intrattenimento')),
              DropdownMenuItem(value: 6, child: Text('Outdoor')),
              DropdownMenuItem(value: 7, child: Text('Culturale')),
              DropdownMenuItem(value: 8, child: Text('Relax')),
              DropdownMenuItem(value: 9, child: Text('Business')),
              DropdownMenuItem(value: 10, child: Text('Altro')),
            ],
            onChanged: (value) => setState(() => activityType = value ?? 0),
            decoration: const InputDecoration(labelText: 'Tipo di Attività *'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: descCtrl,
            minLines: 3,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Descrizione'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: locationCtrl,
            decoration: const InputDecoration(labelText: 'Luogo'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: timeSlot,
            items: const [
              DropdownMenuItem(value: 0, child: Text('Mattina')),
              DropdownMenuItem(value: 1, child: Text('Pomeriggio')),
            ],
            onChanged: (value) => setState(() => timeSlot = value ?? 0),
            decoration: const InputDecoration(labelText: 'Fascia Oraria *'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: notesCtrl,
            minLines: 2,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Note'),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Row(
            children: [
              OutlinedButton.icon(
                onPressed: loading ? null : _delete,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Elimina'),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
              ),
              const Spacer(),
              OutlinedButton(
                onPressed: loading ? null : () => Navigator.pop(context, false),
                child: const Text('Annulla'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: loading ? null : _save,
                icon: const Icon(Icons.check),
                label: Text(loading ? 'Salvataggio...' : 'Aggiorna Attività'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ItineraryFormSheetState extends State<ItineraryFormSheet> {
  final titleCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  final locationCtrl = TextEditingController();
  final notesCtrl = TextEditingController();
  int activityType = 0;
  int timeSlot = 0;

  @override
  void initState() {
    super.initState();
    timeSlot = widget.initialTimeSlot ?? 0;
  }

  Future<void> _submit() async {
    try {
      final session = context.read<SessionStore>();
      await session._apiClient.createItinerary(
        session.token!,
        ItineraryUpsert(
          tripId: widget.tripId,
          date: widget.date,
          title: titleCtrl.text.trim(),
          description: descCtrl.text.trim().isEmpty
              ? null
              : descCtrl.text.trim(),
          activityType: activityType,
          location: locationCtrl.text.trim().isEmpty
              ? null
              : locationCtrl.text.trim(),
          timeSlot: timeSlot,
          notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
          isCompleted: false,
        ),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      _showError(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Nuova attività',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          TextField(
            controller: titleCtrl,
            decoration: const InputDecoration(labelText: 'Titolo'),
          ),
          TextField(
            controller: descCtrl,
            decoration: const InputDecoration(labelText: 'Descrizione'),
          ),
          DropdownButtonFormField<int>(
            initialValue: activityType,
            items: const [
              DropdownMenuItem(value: 0, child: Text('Turismo')),
              DropdownMenuItem(value: 1, child: Text('Ristorante')),
              DropdownMenuItem(value: 2, child: Text('Trasporto')),
              DropdownMenuItem(value: 3, child: Text('Alloggio')),
              DropdownMenuItem(value: 4, child: Text('Shopping')),
              DropdownMenuItem(value: 5, child: Text('Intrattenimento')),
              DropdownMenuItem(value: 6, child: Text('Outdoor')),
              DropdownMenuItem(value: 7, child: Text('Culturale')),
              DropdownMenuItem(value: 8, child: Text('Relax')),
              DropdownMenuItem(value: 9, child: Text('Business')),
              DropdownMenuItem(value: 10, child: Text('Altro')),
            ],
            onChanged: (value) => setState(() => activityType = value ?? 0),
            decoration: const InputDecoration(labelText: 'Tipo attività'),
          ),
          DropdownButtonFormField<int>(
            initialValue: timeSlot,
            items: const [
              DropdownMenuItem(value: 0, child: Text('Mattina')),
              DropdownMenuItem(value: 1, child: Text('Pomeriggio')),
            ],
            onChanged: (value) => setState(() => timeSlot = value ?? 0),
            decoration: const InputDecoration(labelText: 'Fascia oraria'),
          ),
          TextField(
            controller: locationCtrl,
            decoration: const InputDecoration(labelText: 'Luogo'),
          ),
          TextField(
            controller: notesCtrl,
            decoration: const InputDecoration(labelText: 'Note'),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(onPressed: _submit, child: const Text('Salva')),
          ),
        ],
      ),
    );
  }
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool loading = false;
  UserProfile? profile;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final session = context.read<SessionStore>();
      final data = await session._apiClient.getProfile(session.token!);
      setState(() => profile = data);
    } catch (e) {
      if (!mounted) return;
      _showError(context, e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _editProfile() async {
    if (profile == null) return;
    final usernameCtrl = TextEditingController(text: profile!.username);
    XFile? picked;

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Modifica profilo'),
        content: StatefulBuilder(
          builder: (context, setDialog) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: usernameCtrl,
                decoration: const InputDecoration(labelText: 'Username'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  picked = await ImagePicker().pickImage(
                    source: ImageSource.gallery,
                    imageQuality: 80,
                  );
                  setDialog(() {});
                },
                icon: const Icon(Icons.image),
                label: Text(picked == null ? 'Scegli foto' : picked!.name),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Salva'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (!mounted) return;

    try {
      final session = context.read<SessionStore>();
      final updated = await session._apiClient.updateProfile(
        session.token!,
        UserProfileUpdate(
          username: usernameCtrl.text.trim(),
          profileImageBase64: picked == null
              ? profile!.profileImageBase64
              : base64Encode(await picked!.readAsBytes()),
        ),
      );
      await session.updateProfile(updated);
      setState(() => profile = updated);
    } catch (e) {
      if (!mounted) return;
      _showError(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (profile == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profilo')),
        body: const Center(child: Text('Profilo non disponibile')),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Profilo')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            CircleAvatar(
              radius: 46,
              backgroundImage: _base64ImageProvider(
                profile!.profileImageBase64,
              ),
              child: profile!.profileImageBase64 == null
                  ? const Icon(Icons.person, size: 44)
                  : null,
            ),
            const SizedBox(height: 12),
            Text(
              profile!.username,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Text(profile!.email),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _editProfile,
              icon: const Icon(Icons.edit),
              label: const Text('Modifica profilo'),
            ),
          ],
        ),
      ),
    );
  }
}

ImageProvider<Object>? _base64ImageProvider(String? value) {
  if (value == null || value.isEmpty) return null;
  return MemoryImage(base64Decode(value));
}

ImageProvider<Object>? _tripItemImageProvider(String? rawValue) {
  if (rawValue == null || rawValue.trim().isEmpty) {
    return null;
  }
  final value = rawValue.trim();
  if (value.startsWith('http://') || value.startsWith('https://')) {
    return NetworkImage(value);
  }
  if (value.startsWith('data:image/')) {
    final commaIndex = value.indexOf(',');
    if (commaIndex > -1 && commaIndex < value.length - 1) {
      try {
        return MemoryImage(base64Decode(value.substring(commaIndex + 1)));
      } catch (_) {
        return null;
      }
    }
  }
  try {
    return MemoryImage(base64Decode(value));
  } catch (_) {
    if (value.startsWith('/')) {
      return NetworkImage('${_apiOrigin()}$value');
    }
    if (value.startsWith('uploads/') || value.startsWith('wwwroot/')) {
      return NetworkImage(
        '${_apiOrigin()}/${value.replaceFirst('wwwroot/', '')}',
      );
    }
    return NetworkImage('${_apiOrigin()}/$value');
  }
}

String _apiOrigin() {
  final uri = Uri.parse(defaultApiBaseUrl);
  final port = uri.hasPort ? ':${uri.port}' : '';
  return '${uri.scheme}://${uri.host}$port';
}

Widget _buildRatingStars(int rating, {double size = 18}) {
  final stars = rating.clamp(0, 5);
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: List.generate(5, (index) {
      final filled = index < stars;
      return Icon(
        filled ? Icons.star_rounded : Icons.star_border_rounded,
        size: size,
        color: filled ? Colors.amber.shade700 : Colors.grey,
      );
    }),
  );
}

void _showError(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

Future<bool> _askConfirm(BuildContext context, String message) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Conferma'),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Annulla'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Conferma'),
        ),
      ],
    ),
  );
  return result ?? false;
}
