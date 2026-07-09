import 'dart:async';

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../model/event_bus/http_result.dart';
import '../model/passenger_model.dart';
import '../utils/secure_storage.dart';

class ApiProvider {
  static Duration durationTimeout = const Duration(seconds: 30);
  static String get baseUrl => kIsWeb
      ? "http://localhost:8081/api/v1"
      : "https://backend.ketamiz.com/api/v1";

  /// Shared HTTP client. Reused across all requests so the underlying
  /// connection is kept alive/pooled instead of opening a new socket each
  /// call. Per-request Options still override timeouts/headers as needed.
  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: durationTimeout,
      sendTimeout: durationTimeout,
      receiveTimeout: durationTimeout,
    ),
  );

  // --- Helpers ---

  static Future<Map<String, dynamic>> _getReqHeader() async {
    final headers = <String, dynamic>{
      "Accept": "application/json",
      "Content-Type": "application/json",
    };

    final token = await SecureStorage.getToken();
    if (token != null && token.isNotEmpty) {
      headers["Authorization"] = "Bearer $token";
    }

    // Tell the backend which language to localize server-side strings in
    // (region/district/quarter names, messages, etc.) so they match the UI.
    try {
      final prefs = await SharedPreferences.getInstance();
      headers["Accept-Language"] = prefs.getString('language') ?? 'uz';
    } catch (_) {}

    return headers;
  }

  static HttpResult _handleDioError(DioException e) {
    assert(() {
      debugPrint("DioError: ${e.message}");
      return true;
    }());
    if (e.response != null) {
      // Check if response data is usable map
      final result = e.response?.data is Map
          ? e.response?.data
          : {"error": e.response?.data.toString()};
      
      return HttpResult(
        isSuccess: false,
        status: e.response?.statusCode ?? -1,
        result: result,
      );
    } else {
      return HttpResult(
        isSuccess: false,
        status: -1,
        result: {},
      );
    }
  }

  static HttpResult _handleGenericError(Object e) {
    assert(() {
      debugPrint("Error: $e");
      return true;
    }());
    return HttpResult(
      isSuccess: false,
      status: -1,
      result: {"error": e.toString()},
    );
  }

   static HttpResult _processResponse(Response response) {
    // Check for success range
    if (response.statusCode != null &&
        response.statusCode! >= 200 &&
        response.statusCode! <= 299) {
      
      return HttpResult(
        isSuccess: true,
        status: response.statusCode!,
        result: response.data is Map ? response.data : {"data": response.data},
      );
    } else {
      return HttpResult(
        isSuccess: false,
        status: response.statusCode ?? -1,
        result: response.data is Map
            ? response.data
            : {"error": response.data.toString()},
      );
    }
  }

  // --- Core Methods ---

  /// GET Request using Dio
  static Future<HttpResult> getRequest(String url) async {
    final dio = _dio;
    final headers = await _getReqHeader();

    try {
      Response response = await dio.get(
        url,
        options: Options(
          headers: headers,
          sendTimeout: durationTimeout,
          receiveTimeout: durationTimeout,
          validateStatus: (status) => true, // Handle status manually
          followRedirects: false,
        ),
      );
      return _processResponse(response);
    } on DioException catch (e) {
      return _handleDioError(e);
    } catch (e) {
      return _handleGenericError(e);
    }
  }

  /// POST Request (JSON)
  static Future<HttpResult> postRequest(String url, Map<String, dynamic> body) async {
    final dio = _dio;
    final headers = await _getReqHeader();

    try {
      Response response = await dio.post(
        url,
        data: body,
        options: Options(
          headers: headers,
          sendTimeout: durationTimeout,
          receiveTimeout: durationTimeout,
          validateStatus: (status) => true,
        ),
      );
      return _processResponse(response);
    } on DioException catch (e) {
      return _handleDioError(e);
    } catch (e) {
      return _handleGenericError(e);
    }
  }

  static Future<HttpResult> putRequest(
      String url, Map<String, dynamic> body) async {
    final dio = _dio;
    final headers = await _getReqHeader();

    try {
      Response response = await dio.put(
        url,
        data: body,
        options: Options(
          headers: headers,
          sendTimeout: durationTimeout,
          receiveTimeout: durationTimeout,
          validateStatus: (status) => true,
        ),
      );
      return _processResponse(response);
    } on DioException catch (e) {
      return _handleDioError(e);
    } catch (e) {
      return _handleGenericError(e);
    }
  }

  // Legacy postRequest shim (deprecating but keeping if internal usage exists,
  // though we will replace all calls)
  // Replaced by postFormRequest or postJsonRequest usage below.


  /// Register Post
  Future<HttpResult> fetchRegister(
    String firstName,
    String lastName,
    String fatherName,
    String phone,
    String password,
    String passwordConfirm,
  ) async {
    String url = '$baseUrl/auth/register';

    phone = phone.replaceAll(' ', '').replaceAll('-', '').replaceAll('(', '').replaceAll(')', '');
    if (!phone.startsWith('+')) {
      phone = '+$phone';
    }

    // Email is no longer collected at registration — it's gathered later in
    // the profile section. Father's name stays optional and is omitted when
    // empty so backend validation passes.
    final data = {
      "first_name": firstName,
      "last_name": lastName,
      if (fatherName.trim().isNotEmpty) "father_name": fatherName,
      "phone": phone,
      "password": password,
      "password_confirmation": passwordConfirm,
    };
    return await postRequest(url, data);
  }

  /// Verification Resend Post
  Future<HttpResult> fetchVerificationResend(String phone) async {
    String url = '$baseUrl/auth/resend-code';

    phone = phone.replaceAll(' ', '').replaceAll('-', '').replaceAll('(', '').replaceAll(')', '');
    if (!phone.startsWith('+')) {
      phone = '+$phone';
    }

    final data = {
      "phone": phone,
    };
    return await postRequest(url, data);
  }

  /// Send Reset Code Post — step 1 of the password-reset flow.
  Future<HttpResult> fetchSendResetCode(String phone) async {
    String url = '$baseUrl/auth/send-reset-code';

    phone = phone.replaceAll(' ', '').replaceAll('-', '').replaceAll('(', '').replaceAll(')', '');
    if (!phone.startsWith('+')) {
      phone = '+$phone';
    }

    final data = {
      "phone": phone,
    };
    return await postRequest(url, data);
  }

  /// Reset Password Post — step 2 of the password-reset flow.
  Future<HttpResult> fetchResetPassword(
    String phone,
    String verificationCode,
    String password,
    String passwordConfirmation,
  ) async {
    String url = '$baseUrl/auth/reset-password';

    phone = phone.replaceAll(' ', '').replaceAll('-', '').replaceAll('(', '').replaceAll(')', '');
    if (!phone.startsWith('+')) {
      phone = '+$phone';
    }

    final data = {
      "phone": phone,
      "verification_code": verificationCode,
      "password": password,
      "password_confirmation": passwordConfirmation,
    };
    return await postRequest(url, data);
  }

  /// Verify Code Post
  Future<HttpResult> fetchVerifyCode(String phone, String code) async {
    String url = '$baseUrl/auth/verify-code';

    phone = phone.replaceAll(' ', '').replaceAll('-', '').replaceAll('(', '').replaceAll(')', '');
    if (!phone.startsWith('+')) {
      phone = '+$phone';
    }

    final data = {
      "phone": phone,
      "code": code,
    };
    return await postRequest(url, data);
  }

  /// Login Post
  Future<HttpResult> fetchLogin(String phone, String password) async {
    String url = '$baseUrl/auth/login';

    phone = phone.replaceAll(' ', '').replaceAll('-', '').replaceAll('(', '').replaceAll(')', '');
    if (!phone.startsWith('+')) {
      phone = '+$phone';
    }

    final data = {
      "phone": phone,
      "password": password,
    };
    return await postRequest(url, data);
  }

  /// Get User Data
  Future<HttpResult> fetchMe() async {
    String url = '$baseUrl/auth/me';
    return await getRequest(url);
  }

  /// Update Profile Post
  Future<HttpResult> fetchUpdateProfile(
    String firstName,
    String lastName,
    String fatherName,
    String email,
  ) async {
    String url = '$baseUrl/auth/update-profile';
    final data = {
      "first_name": firstName,
      "last_name": lastName,
      "father_name": fatherName,
      "email": email,
    };
    return await postRequest(url, data);
  }

  /// Logout Post
  Future<HttpResult> fetchLogout() async {
    String url = '$baseUrl/auth/logout';
    return await postRequest(url, {});
  }

  /// Register / update this device's FCM token so the backend can push to it.
  /// Requires a valid JWT (auth header is attached automatically).
  Future<HttpResult> fetchRegisterDeviceToken(
    String deviceToken,
    String devicePlatform,
  ) async {
    String url = '$baseUrl/device-token';
    final data = {
      "device_token": deviceToken,
      "device_platform": devicePlatform,
    };
    return await postRequest(url, data);
  }

  /// Remove this device's FCM token (call on logout while the JWT is still
  /// valid). The backend resolves the token from the authenticated user.
  Future<HttpResult> fetchDeleteDeviceToken() async {
    String url = '$baseUrl/device-token';
    return await deleteRequest(url);
  }

  /// Update User Language Post
  Future<HttpResult> fetchUpdateLanguage(String language) async {
    String url = '$baseUrl/auth/update-user-language';
    final data = {
      "language": language,
    };
    return await postRequest(url, data);
  }

  /// Support / Contact Us Post
  Future<HttpResult> fetchSupport(
    String name,
    String email,
    String message,
  ) async {
    String url = '$baseUrl/support';
    final data = {
      "name": name,
      "email": email,
      "message": message,
    };
    return await postRequest(url, data);
  }

  /// Get Trip List
  Future<HttpResult> fetchTripList() async {
    String url = '$baseUrl/public/trips/view';
    return await getRequest(url);
  }

  /// Get all broadcast messages (notifications) for the current user.
  Future<HttpResult> fetchBroadcasts() async {
    return await getRequest('$baseUrl/broadcasts');
  }

  /// Get a single broadcast message by id.
  Future<HttpResult> fetchBroadcast(int id) async {
    return await getRequest('$baseUrl/broadcasts/$id');
  }

  /// Get all regions (bare JSON array: [{id, name_uz, name_ru, name_en}])
  Future<HttpResult> fetchRegions() async {
    return await getRequest('$baseUrl/regions');
  }

  /// Get districts for a region (bare JSON array: [{id, name_uz, name_ru, name_en}])
  Future<HttpResult> fetchDistricts(String regionId) async {
    return await getRequest('$baseUrl/districts/region/$regionId');
  }

  /// Get quarters (neighborhoods) for a district (bare JSON array: [{id, name}])
  Future<HttpResult> fetchQuarters(String districtId) async {
    return await getRequest('$baseUrl/quarters/districts/$districtId');
  }

  /// Get Trip Search
  Future<HttpResult> fetchTripSearch(
    String fromRegionId,
    String toRegionId,
    String fromDistrictId,
    String toDistrictId,
    String fromQuarterId,
    String toQuarterId,
    DateTime departureDate,
    DateTime? returnDate,
    bool? isRoundTrip,
  ) async {
    isRoundTrip ??= false;

    final queryParams = <String, String>{
      'start_region_id': fromRegionId,
      'end_region_id': toRegionId,
      // Search by day only — pin to the start of the day so the exact pick
      // time never excludes trips departing earlier that same day.
      'departure_date': _formatBackendDate(departureDate),
    };
    // District/quarter are optional — only narrow the search when provided.
    // This lets region-to-region searches (district/quarter = "0") work.
    if (fromDistrictId != "0") queryParams['start_district_id'] = fromDistrictId;
    if (toDistrictId != "0") queryParams['end_district_id'] = toDistrictId;
    if (fromQuarterId != "0") queryParams['start_quarter_id'] = fromQuarterId;
    if (toQuarterId != "0") queryParams['end_quarter_id'] = toQuarterId;
    if (isRoundTrip && returnDate != null) {
      queryParams['return_date'] = _formatBackendDate(returnDate);
      queryParams['is_round_trip'] = 'true';
    }

    final uri = Uri.parse('$baseUrl/public/trips/search/available-trips')
        .replace(queryParameters: queryParams);
    return await getRequest(uri.toString());
  }

  /// Format DateTime as `Y-m-d H:i:s` for the backend (Laravel `date_format:Y-m-d H:i:s`)
  static String _formatBackendDateTime(DateTime dt) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} '
        '${two(dt.hour)}:${two(dt.minute)}:${two(dt.second)}';
  }

  /// Format a DateTime as the start of its day (`Y-m-d 00:00:00`) for the
  /// backend. Used by the trip search so only the date matters, not the time.
  static String _formatBackendDate(DateTime dt) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} 00:00:00';
  }


  /// Top Up Balance Post
  Future<HttpResult> fetchTopUp(String amount) async {
    String url = '$baseUrl/auth/fill-balance';

    final data = {
      "amount": amount,
    };
    return await postRequest(url, data);
  }

  /// Book A Trip Post
  Future<HttpResult> fetchBookTrip(
      String tripId, List<PassengerModel> passengers) async {
    String url = '$baseUrl/client/booking';

    final data = {
      "trip_id": int.parse(tripId),
      "passengers": passengers
          .map((e) => {
                "name": e.fullName,
                "phone": e.phoneNumber,
                "longitude": e.longitude,
                "latitude": e.latitude,
              })
          .toList(),
    };
    return await postRequest(url, data);
  }

  /// Get Booked Trips List
  Future<HttpResult> fetchBookedTripsList() async {
    String url = '$baseUrl/client/booking';
    return await getRequest(url);
  }

  /// Get One Booked Trip
  Future<HttpResult> fetchOneBookedTrip(String tripId) async {
    String url = '$baseUrl/client/trips/booking/$tripId';
    return await getRequest(url);
  }

  /// Cancel a client's booking
  Future<HttpResult> fetchCancelBooking(String bookingId) async {
    String url = '$baseUrl/client/booking/$bookingId';
    return await deleteRequest(url);
  }

  /// Update booked passengers' pickup coordinates for a trip.
  /// [passengers] is a list of {id, latitude, longitude} maps.
  Future<HttpResult> fetchUpdatePassengerAddress(
      String tripId, List<Map<String, dynamic>> passengers) async {
    String url = '$baseUrl/client/trips/$tripId/booking';
    final data = {"passengers": passengers};
    return await putRequest(url, data);
  }

  /// Get a single booking (with its passengers) by booking id.
  Future<HttpResult> fetchBookingById(String bookingId) async {
    String url = '$baseUrl/client/booking/$bookingId';
    return await getRequest(url);
  }

  /// Add a passenger to an existing booking.
  Future<HttpResult> fetchAddPassengerToBooking(String bookingId, String name,
      String phone, String latitude, String longitude) async {
    String url = '$baseUrl/client/booking/$bookingId/add-passenger';
    final data = {
      "name": name,
      "phone": phone,
      "latitude": latitude,
      "longitude": longitude,
    };
    return await postRequest(url, data);
  }

  /// Remove a passenger from an existing booking.
  Future<HttpResult> fetchRemovePassengerFromBooking(
      String bookingId, String passengerId) async {
    String url =
        '$baseUrl/client/booking/$bookingId/remove-passenger/$passengerId';
    return await postRequest(url, {});
  }

  /// Get In-Progress Trips
  Future<HttpResult> fetchInProgressTrips() async {
    String url = '$baseUrl/client/trips/get-inprogress-trips';
    return await getRequest(url);
  }

  /// Get Completed Trips
  Future<HttpResult> fetchCompletedTrips() async {
    String url = '$baseUrl/client/trips/get-completed-trips';
    return await getRequest(url);
  }

  /// Get Canceled Trips
  Future<HttpResult> fetchCanceledTrips() async {
    String url = '$baseUrl/client/trips/get-canceled-trips';
    return await getRequest(url);
  }

  /// JPEG mime type for image parts — without an explicit contentType Dio
  /// sends multipart parts as application/octet-stream, which backends may
  /// store/serve as a non-image file that won't open.
  static final DioMediaType _jpegMediaType = DioMediaType('image', 'jpeg');

  static int _resizeCounter = 0;

  Future<File> _resizeImage(File file,
      {int maxWidth = 1280, int quality = 75}) async {
    final bytes = await file.readAsBytes();
    img.Image? image = img.decodeImage(bytes);

    // Undecodable input — upload the original file untouched rather than
    // crashing on the null assert.
    if (image == null) return file;

    // Resize proportionally if wider than maxWidth
    if (image.width > maxWidth) {
      image = img.copyResize(image, width: maxWidth);
    }

    // Encode as JPEG with compression
    final resizedBytes = img.encodeJpg(image, quality: quality);

    // Save into a temporary file. The counter guarantees a unique name even
    // when several images are resized within the same millisecond — with a
    // timestamp alone, a collision silently overwrites the previous file
    // while its multipart part still points at the same path.
    final tempDir = Directory.systemTemp;
    final resizedFile = File(
      '${tempDir.path}/resized_${DateTime.now().millisecondsSinceEpoch}_${_resizeCounter++}.jpg',
    );
    await resizedFile.writeAsBytes(resizedBytes, flush: true);

    return resizedFile;
  }

  static void _deleteTempFile(File? file) {
    if (file != null && file.existsSync()) {
      try {
        file.deleteSync();
      } catch (_) {}
    }
  }

  static void _deleteTempFiles(List<File> files) {
    for (final file in files) {
      _deleteTempFile(file);
    }
  }

  /// Driver Docs Upload (all 3 files in one multipart call as required by backend)
  Future<HttpResult> fetchDriverDocsUpload({
    required String drivingLicenceFrontPath,
    required String drivingLicenceBackPath,
    required String passportPath,
  }) async {
    String url = '$baseUrl/auth/upload-driver-passport-driving-licence';

    final token = await SecureStorage.getToken();
    final dio = _dio;
    final headers = {
      "Accept": "application/json",
      if (token != null) "Authorization": "Bearer $token",
    };

    final List<File> tempFiles = [];
    try {
      final front = await _resizeImage(File(drivingLicenceFrontPath));
      if (front.path != drivingLicenceFrontPath) tempFiles.add(front);
      final back = await _resizeImage(File(drivingLicenceBackPath));
      if (back.path != drivingLicenceBackPath) tempFiles.add(back);
      final passport = await _resizeImage(File(passportPath));
      if (passport.path != passportPath) tempFiles.add(passport);

      final bodyMap = <String, dynamic>{
        "driving_licence_front": await MultipartFile.fromFile(
          front.path,
          filename: basename(front.path),
          contentType: _jpegMediaType,
        ),
        "driving_licence_back": await MultipartFile.fromFile(
          back.path,
          filename: basename(back.path),
          contentType: _jpegMediaType,
        ),
        "driver_passport_image": await MultipartFile.fromFile(
          passport.path,
          filename: basename(passport.path),
          contentType: _jpegMediaType,
        ),
      };

      Response response = await dio.post(
        url,
        data: FormData.fromMap(bodyMap),
        options: Options(headers: headers, validateStatus: (s) => true),
      );
      return _processResponse(response);
    } on DioException catch (e) {
      return _handleDioError(e);
    } catch (e) {
      return _handleGenericError(e);
    } finally {
      _deleteTempFiles(tempFiles);
    }
  }

  /// Upload Profile Image (multipart, field `image`)
  Future<HttpResult> fetchUploadProfileImage(String imagePath) async {
    String url = '$baseUrl/auth/upload-profile-image';

    final token = await SecureStorage.getToken();
    final dio = _dio;
    final headers = {
      "Accept": "application/json",
      if (token != null) "Authorization": "Bearer $token",
    };

    final List<File> tempFiles = [];
    try {
      final resized = await _resizeImage(File(imagePath));
      if (resized.path != imagePath) tempFiles.add(resized);

      final bodyMap = <String, dynamic>{
        "image": await MultipartFile.fromFile(
          resized.path,
          filename: basename(resized.path),
          contentType: _jpegMediaType,
        ),
      };

      Response response = await dio.post(
        url,
        data: FormData.fromMap(bodyMap),
        options: Options(headers: headers, validateStatus: (s) => true),
      );
      return _processResponse(response);
    } on DioException catch (e) {
      return _handleDioError(e);
    } catch (e) {
      return _handleGenericError(e);
    } finally {
      _deleteTempFiles(tempFiles);
    }
  }

  /// Delete Account
  Future<HttpResult> fetchDeleteAccount() async {
    String url = '$baseUrl/auth/delete-account';
    return await deleteRequest(url);
  }

  /// Apply for Driver Post
  Future<HttpResult> fetchApplyDriver(
    String drivingLicenceNumber,
    DateTime expiryDate,
    DateTime birthDate,
  ) async {
    String url = '$baseUrl/auth/become-a-driver';
    String two(int v) => v.toString().padLeft(2, '0');
    // Per API contract: license expiration is `dd,mm,yyyy`, birthday is `dd.mm.yyyy`.
    String expiryDateStr =
        '${two(expiryDate.day)},${two(expiryDate.month)},${expiryDate.year}';
    String birthDateStr =
        '${two(birthDate.day)}.${two(birthDate.month)}.${birthDate.year}';
    final data = {
      "driving_license_number": drivingLicenceNumber,
      "driving_license_expiration_date": expiryDateStr,
      "birthday": birthDateStr,
    };
    return await postRequest(url, data);
  }

  /// Add Vehicle Info Post
  Future<HttpResult> fetchAddVehicleInfo(
      String vehicleNumber,
      String vehicleModel,
      int vehicleColorId,
      String vehicleTechPassport,
      int seats,
      ) async {
    String url = '$baseUrl/vehicles';
    final data = {
      "vehicle_number": vehicleNumber,
      "car_model": vehicleModel,
      "car_color_id": vehicleColorId,
      "tech_passport_number": vehicleTechPassport,
      "seats": seats,
    };
    return await postRequest(url, data);
  }

  /// Verify Driver Post
  Future<HttpResult> fetchVerifyDriver(String userId) async {
    String url = '$baseUrl/auth/approve-driver';

    final data = {
      "user_id": userId,
    };
    return await postRequest(url, data);
  }

  /// Upload Car Images
  Future<HttpResult> fetchUploadCarImages(
      String vehicleId,
      String techPassportFront,
      String techPassportBack,
      List<String> carImages,
      ) async {
    String url = '$baseUrl/auth/upload-car-images';

    final token = await SecureStorage.getToken();
    final dio = _dio;
    final dynamic headers = {
      "Accept": "application/json",
      if (token != null) "Authorization": "Bearer $token",
    };

    // Prepare files
    Map<String, dynamic> bodyMap = {
      'vehicle_id': vehicleId,
    };

    final List<File> tempFiles = [];
    try {
      if (techPassportFront.isNotEmpty) {
        File resizedFront = await _resizeImage(File(techPassportFront));
        if (resizedFront.path != techPassportFront) tempFiles.add(resizedFront);
        bodyMap['tech_passport_front'] = await MultipartFile.fromFile(
          resizedFront.path,
          filename: basename(resizedFront.path),
          contentType: _jpegMediaType,
        );
      }
      if (techPassportBack.isNotEmpty) {
        File resizedBack = await _resizeImage(File(techPassportBack));
        if (resizedBack.path != techPassportBack) tempFiles.add(resizedBack);
        bodyMap['tech_passport_back'] = await MultipartFile.fromFile(
          resizedBack.path,
          filename: basename(resizedBack.path),
          contentType: _jpegMediaType,
        );
      }

      if (carImages.isNotEmpty) {
        List<MultipartFile> carFiles = [];
        for (var path in carImages) {
          File resizedCarImage = await _resizeImage(File(path));
          if (resizedCarImage.path != path) tempFiles.add(resizedCarImage);
          carFiles.add(await MultipartFile.fromFile(
            resizedCarImage.path,
            filename: basename(resizedCarImage.path),
            contentType: _jpegMediaType,
          ));
        }
        bodyMap['car_images[]'] = carFiles;
      }

      FormData formData = FormData.fromMap(bodyMap);

      Response response = await dio.post(
        url,
        data: formData,
        options: Options(
          headers: headers,
          validateStatus: (status) => true,
        ),
      );
      return _processResponse(response);
    } on DioException catch (e) {
      if (e.response?.statusCode == 413) {
        return HttpResult(
          isSuccess: false,
          status: 413,
          result: {"error": "Image file is too large."},
        );
      }
      return _handleDioError(e);
    } catch (e) {
      return _handleGenericError(e);
    } finally {
      _deleteTempFiles(tempFiles);
    }
  }

  /// Create Trip Post
  Future<HttpResult> fetchCreateTrip(
      String vehicleId,
      DateTime startDate,
      DateTime endDate,
      String pricePerSeat,
      String availableSeats,
      String startLat,
      String startLong,
      String endLat,
      String endLong,
      String startRegionId,
      String startDistrictId,
      String startQuarterId,
      String endRegionId,
      String endDistrictId,
      String endQuarterId,
      ) async {
    String url = '$baseUrl/driver/trips';
    final data = {
      "vehicle_id": vehicleId,
      "start_time": _formatBackendDateTime(startDate),
      "end_time": _formatBackendDateTime(endDate),
      "start_region_id": startRegionId,
      "start_district_id": startDistrictId,
      "start_quarter_id": startQuarterId,
      "end_region_id": endRegionId,
      "end_district_id": endDistrictId,
      "end_quarter_id": endQuarterId,
      "price_per_seat": pricePerSeat,
      "available_seats": availableSeats,
      "start_lat": startLat,
      "start_long": startLong,
      "end_lat": endLat,
      "end_long": endLong,
    };
    return await postRequest(url, data);
  }

  /// Get One Driver Trip
  Future<HttpResult> fetchOneDriverTrip(String tripId) async {
    String url = '$baseUrl/driver/trips/$tripId';
    return await getRequest(url);
  }

  /// Cancel Driver Trip
  Future<HttpResult> fetchCancelDriverTrip(String tripId) async {
    String url = '$baseUrl/driver/trips/cancel-trip/$tripId';
    return await deleteRequest(url);
  }

  /// Get Card List
  Future<HttpResult> fetchCardList() async {
    String url = '$baseUrl/bank/my-registered-cards/';
    return await getRequest(url);
  }

  /// Add Credit Card Post (Updated)
  Future<HttpResult> fetchAddCreditCard(
      String cardNumber, String expiry, String phone, String holderName) async {
    String url = '$baseUrl/bank/add-card';
    final data = {
      "number": cardNumber,
      "expiry": expiry,
      "phone": phone,
      "holder_name": holderName,
    };
    return await postRequest(url, data);
  }

  /// Verify Card Post
  Future<HttpResult> fetchVerifyCard(
      int id, String cardKey, String confirmCode) async {
    String url = '$baseUrl/bank/verify-card';
    final data = {
      "id": id.toString(),
      "card_key": cardKey,
      "confirm_code": confirmCode,
    };
    return await postRequest(url, data);
  }

  /// Delete Card
  Future<HttpResult> fetchDeleteCard(int cardId) async {
    String url = '$baseUrl/bank/delete-card/$cardId';
    return await deleteRequest(url);
  }

  /// Resend Payment SMS
  Future<HttpResult> fetchResendPaymentSms(String payId) async {
    String url = '$baseUrl/bank/resend-sms';
    final data = {
      "pay_id": payId,
    };
    return await postRequest(url, data);
  }
  
  /// Create Payment (Fill Balance)
  Future<HttpResult> fetchCreatePayment(String amount, {String? cardId}) async {
    String url = '$baseUrl/bank/create-payment';
    final data = {
      "amount": amount,
      if (cardId != null) "card_id": cardId,
    };
    return await postRequest(url, data);
  }

  /// Confirm Payment
  Future<HttpResult> fetchConfirmPayment(String payId, String confirmCode) async {
    String url = '$baseUrl/bank/confirm-payment';
    final data = {
      "pay_id": payId,
      "confirm_code": confirmCode,
    };
    return await postRequest(url, data);
  }

  /// Get Transaction List
  Future<HttpResult> fetchTransactionList({int page = 1}) async {
    String url = '$baseUrl/user/balance-transactions?page=$page';
    return await getRequest(url);
  }

  /// Download a single transaction receipt as PDF bytes.
  /// Returns the raw bytes on success, or null on any failure.
  Future<List<int>?> fetchTransactionPdfBytes(int transactionId) async {
    try {
      final headers = await _getReqHeader();
      headers["Accept"] = "application/pdf";
      final response = await _dio.get<List<int>>(
        '$baseUrl/user/balance-transactions/pdf/$transactionId',
        options: Options(
          headers: headers,
          responseType: ResponseType.bytes,
        ),
      );
      if (response.statusCode != null &&
          response.statusCode! >= 200 &&
          response.statusCode! <= 299) {
        return response.data;
      }
      return null;
    } catch (e) {
      assert(() {
        debugPrint("fetchTransactionPdfBytes error: $e");
        return true;
      }());
      return null;
    }
  }

  /// Get My Withdraw Requests
  Future<HttpResult> fetchWithdrawList() async {
    String url = '$baseUrl/withdraw';
    return await getRequest(url);
  }

  /// Create Withdraw Request
  Future<HttpResult> fetchWithdraw(String amount) async {
    String url = '$baseUrl/withdraw';
    final data = {"amount": amount};
    return await postRequest(url, data);
  }

  /// GET Request using Dio (DELETE method)
  static Future<HttpResult> deleteRequest(String url) async {
    final dio = _dio;
    final headers = await _getReqHeader();
    try {
      Response response = await dio.delete(
        url,
        options: Options(
          headers: headers,
          sendTimeout: durationTimeout,
          receiveTimeout: durationTimeout,
          validateStatus: (status) => true,
        ),
      );
      return _processResponse(response);
    } on DioException catch (e) {
      return _handleDioError(e);
    } catch (e) {
      return _handleGenericError(e);
    }
  }

  /// Get My Vehicles
  Future<HttpResult> fetchVehiclesList() async {
    String url = '$baseUrl/vehicles';
    return await getRequest(url);
  }

  /// Delete Vehicle
  Future<HttpResult> fetchDeleteVehicle(int vehicleId) async {
    String url = '$baseUrl/vehicles/$vehicleId';
    return await deleteRequest(url);
  }

  /// Get All Driver Trips
  Future<HttpResult> fetchDriverTripsList(String action) async {
    String getDriverTripsUrl(String action) {
      const basePath = '/driver/trips';

      switch (action.toLowerCase()) {
        case 'completed':
          return '$basePath/get-completed-trips/driver';
        case 'canceled':
          return '$basePath/get-canceled-trips/driver';
        case 'active':
          return '$basePath/get-active-trips/driver';
        case 'all':
        default:
          return basePath;
      }
    }

    final String url = '$baseUrl${getDriverTripsUrl(action)}';

    return await getRequest(url);
  }
}
