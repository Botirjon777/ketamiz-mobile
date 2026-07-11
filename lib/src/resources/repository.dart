import 'package:ketamiz/src/model/api/user_model.dart';
import 'package:ketamiz/src/model/event_bus/http_result.dart';

import '../model/api/get_user_model.dart';
import '../model/passenger_model.dart';
import '../utils/cache.dart';
import 'app_provider.dart';

class Repository {
  final apiProvider = ApiProvider();
  final appCache = AppCache();

  Future<HttpResult> fetchRegister(
    String firstName,
    String lastName,
    String fatherName,
    String phone,
    String password,
    String passwordConfirm,
  ) =>
      apiProvider.fetchRegister(
        firstName,
        lastName,
        fatherName,
        phone,
        password,
        passwordConfirm,
      );

  Future<HttpResult> fetchVerificationResend(String phone) =>
      apiProvider.fetchVerificationResend(phone);

  Future<HttpResult> fetchSendResetCode(String phone) =>
      apiProvider.fetchSendResetCode(phone);

  Future<HttpResult> fetchResetPassword(
    String phone,
    String verificationCode,
    String password,
    String passwordConfirmation,
  ) =>
      apiProvider.fetchResetPassword(
        phone,
        verificationCode,
        password,
        passwordConfirmation,
      );

  Future<HttpResult> fetchVerifyCode(String phone, String code) =>
      apiProvider.fetchVerifyCode(phone, code);

  Future<HttpResult> fetchLogin(String phone, String password) =>
      apiProvider.fetchLogin(phone, password);

  Future<HttpResult> fetchMe() => apiProvider.fetchMe();

  Future<HttpResult> fetchUpdateProfile(
    String firstName,
    String lastName,
    String fatherName,
    String email,
  ) =>
      apiProvider.fetchUpdateProfile(firstName, lastName, fatherName, email);

  Future<HttpResult> fetchLogout() => apiProvider.fetchLogout();

  Future<HttpResult> fetchRegisterDeviceToken(
    String deviceToken,
    String devicePlatform,
  ) =>
      apiProvider.fetchRegisterDeviceToken(deviceToken, devicePlatform);

  Future<HttpResult> fetchDeleteDeviceToken() =>
      apiProvider.fetchDeleteDeviceToken();

  Future<HttpResult> fetchBroadcasts() => apiProvider.fetchBroadcasts();

  Future<HttpResult> fetchBroadcast(int id) => apiProvider.fetchBroadcast(id);

  // ── Parcels ────────────────────────────────────────────────────────────────

  Future<HttpResult> fetchParcelTypes() => apiProvider.fetchParcelTypes();

  Future<HttpResult> fetchCreateParcelBooking({
    required int tripId,
    required int parcelTypeId,
    required double weight,
    required String receiverPhone,
    required String latitude,
    required String longitude,
    int? length,
    int? width,
    int? height,
    String? description,
  }) =>
      apiProvider.fetchCreateParcelBooking(
        tripId: tripId,
        parcelTypeId: parcelTypeId,
        weight: weight,
        receiverPhone: receiverPhone,
        latitude: latitude,
        longitude: longitude,
        length: length,
        width: width,
        height: height,
        description: description,
      );

  Future<HttpResult> fetchClientParcelBookings() =>
      apiProvider.fetchClientParcelBookings();

  Future<HttpResult> fetchClientParcelBooking(int id) =>
      apiProvider.fetchClientParcelBooking(id);

  Future<HttpResult> fetchCancelParcelBooking(int id) =>
      apiProvider.fetchCancelParcelBooking(id);

  Future<HttpResult> fetchDriverParcelBookings() =>
      apiProvider.fetchDriverParcelBookings();

  Future<HttpResult> fetchDriverParcelBookingsByTrip(int tripId) =>
      apiProvider.fetchDriverParcelBookingsByTrip(tripId);

  Future<HttpResult> fetchUpdateLanguage(String language) =>
      apiProvider.fetchUpdateLanguage(language);

  Future<HttpResult> fetchSupport(
    String name,
    String email,
    String message,
  ) =>
      apiProvider.fetchSupport(name, email, message);

  Future<HttpResult> fetchTripList() => apiProvider.fetchTripList();

  Future<HttpResult> fetchRegions() => apiProvider.fetchRegions();

  Future<HttpResult> fetchDistricts(String regionId) =>
      apiProvider.fetchDistricts(regionId);

  Future<HttpResult> fetchQuarters(String districtId) =>
      apiProvider.fetchQuarters(districtId);

  Future<HttpResult> fetchTripSearch(
    String fromRegionId,
    String toRegionId,
    String fromDistrictId,
    String toDistrictId,
    String fromQuarterId,
    String toQuarterId,
    DateTime departureDate,
    DateTime? returnDate,
    bool? isRoundTrip, {
    bool acceptsParcels = false,
  }) =>
      apiProvider.fetchTripSearch(
        fromRegionId,
        toRegionId,
        fromDistrictId,
        toDistrictId,
        fromQuarterId,
        toQuarterId,
        departureDate,
        returnDate,
        isRoundTrip,
        acceptsParcels: acceptsParcels,
      );

  Future<HttpResult> fetchTopUp(String amount) =>
      apiProvider.fetchTopUp(amount);

  Future<HttpResult> fetchBookTrip(
    String tripId,
    List<PassengerModel> passengers,
  ) =>
      apiProvider.fetchBookTrip(
        tripId,
        passengers,
      );

  Future<HttpResult> fetchBookedTripsList() =>
      apiProvider.fetchBookedTripsList();

  Future<HttpResult> fetchDriverDocsUpload({
    required String drivingLicenceFrontPath,
    required String drivingLicenceBackPath,
    required String passportPath,
  }) =>
      apiProvider.fetchDriverDocsUpload(
        drivingLicenceFrontPath: drivingLicenceFrontPath,
        drivingLicenceBackPath: drivingLicenceBackPath,
        passportPath: passportPath,
      );

  Future<HttpResult> fetchUploadProfileImage(String imagePath) =>
      apiProvider.fetchUploadProfileImage(imagePath);

  Future<HttpResult> fetchDeleteAccount() => apiProvider.fetchDeleteAccount();

  Future<HttpResult> fetchApplyDriver(
    String drivingLicenceNumber,
    DateTime expiryDate,
    DateTime birthDate,
  ) =>
      apiProvider.fetchApplyDriver(
        drivingLicenceNumber,
        expiryDate,
        birthDate,
      );

  Future<HttpResult> fetchAddVehicleInfo(
    String vehicleNumber,
    String vehicleModel,
    int vehicleColorId,
    String vehicleTechPassport,
    int seats,
  ) =>
      apiProvider.fetchAddVehicleInfo(
        vehicleNumber,
        vehicleModel,
        vehicleColorId,
        vehicleTechPassport,
        seats,
      );

  Future<HttpResult> fetchUploadCarImages(
    String vehicleId,
    String techPassportFront,
    String techPassportBack,
    List<String> carImages,
  ) =>
      apiProvider.fetchUploadCarImages(
        vehicleId,
        techPassportFront,
        techPassportBack,
        carImages,
      );

  Future<HttpResult> fetchVerifyDriver(String userId) =>
      apiProvider.fetchVerifyDriver(userId);

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
    String endQuarterId, {
    bool acceptsParcels = false,
    double? parcelMaxWeight,
    double? parcelPricePerKg,
    int? parcelMaxLength,
    int? parcelMaxWidth,
    int? parcelMaxHeight,
    List<int> parcelTypeIds = const [],
  }) =>
      apiProvider.fetchCreateTrip(
        vehicleId,
        startDate,
        endDate,
        pricePerSeat,
        availableSeats,
        startLat,
        startLong,
        endLat,
        endLong,
        startRegionId,
        startDistrictId,
        startQuarterId,
        endRegionId,
        endDistrictId,
        endQuarterId,
        acceptsParcels: acceptsParcels,
        parcelMaxWeight: parcelMaxWeight,
        parcelPricePerKg: parcelPricePerKg,
        parcelMaxLength: parcelMaxLength,
        parcelMaxWidth: parcelMaxWidth,
        parcelMaxHeight: parcelMaxHeight,
        parcelTypeIds: parcelTypeIds,
      );

  Future<HttpResult> fetchOneDriverTrip(String tripId) =>
      apiProvider.fetchOneDriverTrip(tripId);

  Future<HttpResult> fetchOneBookedTrip(String tripId) =>
      apiProvider.fetchOneBookedTrip(tripId);

  Future<HttpResult> fetchInProgressTrips() =>
      apiProvider.fetchInProgressTrips();

  Future<HttpResult> fetchCompletedTrips() =>
      apiProvider.fetchCompletedTrips();

  Future<HttpResult> fetchCanceledTrips() =>
      apiProvider.fetchCanceledTrips();

  Future<HttpResult> fetchCancelDriverTrip(String tripId) =>
      apiProvider.fetchCancelDriverTrip(tripId);

  Future<HttpResult> fetchToggleParcelAcceptance(String tripId) =>
      apiProvider.fetchToggleParcelAcceptance(tripId);

  Future<HttpResult> fetchCancelBooking(String bookingId) =>
      apiProvider.fetchCancelBooking(bookingId);

  Future<HttpResult> fetchUpdatePassengerAddress(
          String tripId, List<Map<String, dynamic>> passengers) =>
      apiProvider.fetchUpdatePassengerAddress(tripId, passengers);

  Future<HttpResult> fetchBookingById(String bookingId) =>
      apiProvider.fetchBookingById(bookingId);

  Future<HttpResult> fetchAddPassengerToBooking(String bookingId, String name,
          String phone, String latitude, String longitude) =>
      apiProvider.fetchAddPassengerToBooking(
          bookingId, name, phone, latitude, longitude);

  Future<HttpResult> fetchRemovePassengerFromBooking(
          String bookingId, String passengerId) =>
      apiProvider.fetchRemovePassengerFromBooking(bookingId, passengerId);

  Future<HttpResult> fetchCardList() => apiProvider.fetchCardList();

  Future<HttpResult> fetchAddCreditCard(
    String cardNumber,
    String expiry,
    String phone,
    String holderName,
  ) =>
      apiProvider.fetchAddCreditCard(
        cardNumber,
        expiry,
        phone,
        holderName,
      );

  Future<HttpResult> fetchVerifyCard(
          int id, String cardKey, String confirmCode) =>
      apiProvider.fetchVerifyCard(id, cardKey, confirmCode);

  Future<HttpResult> fetchDeleteCard(int cardId) =>
      apiProvider.fetchDeleteCard(cardId);

  Future<HttpResult> fetchResendPaymentSms(String payId) =>
      apiProvider.fetchResendPaymentSms(payId);

  Future<HttpResult> fetchCreatePayment(String amount, {String? cardId}) =>
      apiProvider.fetchCreatePayment(amount, cardId: cardId);

  Future<HttpResult> fetchConfirmPayment(String payId, String confirmCode) =>
      apiProvider.fetchConfirmPayment(payId, confirmCode);

  Future<HttpResult> fetchTransactionList({int page = 1}) =>
      apiProvider.fetchTransactionList(page: page);

  Future<List<int>?> fetchTransactionPdfBytes(int id) =>
      apiProvider.fetchTransactionPdfBytes(id);

  Future<HttpResult> fetchWithdrawList() => apiProvider.fetchWithdrawList();

  Future<HttpResult> fetchWithdraw(String amount) =>
      apiProvider.fetchWithdraw(amount);

  Future<HttpResult> fetchVehiclesList() => apiProvider.fetchVehiclesList();

  Future<HttpResult> fetchDeleteVehicle(int vehicleId) =>
      apiProvider.fetchDeleteVehicle(vehicleId);

  Future<HttpResult> fetchDriverTripsList(String action) =>
      apiProvider.fetchDriverTripsList(action);

  Future<void> cacheLoginUser(UserModel user) => appCache.saveLoginUser(user);

  Future<void> cacheSetMe(User user) => appCache.saveUser(user);

  Future<User> cacheGetMe() => appCache.cacheGetMe();

  // ── Generic cache-first list cache ─────────────────────────────────────
  Future<void> cacheRawList(String key, List<dynamic> data) =>
      appCache.cacheRawList(key, data);

  Future<List<dynamic>> getCachedList(String key) =>
      appCache.getCachedList(key);
}
