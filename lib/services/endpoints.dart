import 'package:zcanopy/config/api_config.dart';

class Endpoints {
  Endpoints._();

  static const String customerSession = '/customer/session';
  static const String validateSession = '/gate-way/validate-session';
  static const String checkSessionValidity =
      '/gate-way/check-session-id-validity';
  static const String logoutUser = '/users/logout-user';

  static const String customerProperties = '/customer/properties';
  static const String customerPropertyDetails =
      '/customer/properties/details';
  static const String customerSearch = '/customer/search';
  static const String listingsSearch = '/listings/search';
  static const String listingsNearby = '/listings/nearby';
  static const String listingsProperties = '/listings/get_properties';
  static const String customerBrokerProperties = '/customer/broker-properties';
  static const String featuredProperties = '/public/properties/featured';
  static const String resolveLocationName =
      '/properties/resolve-location-name';
  static const String currentLocation = '/gate-way/get-current-location';
  static const String propertyLocations = '/properties/locations';

  static const String favoritesToggle = '/customer/favorites/toggle';
  static const String favorites = '/customer/favorites';

  static const String comments = '/customer/comments';
  static String propertyComments(String propertyId) =>
      '/customer/properties/$propertyId/comments';

  static const String searchRecord = '/customer/search/record';
  static const String searchesRetrieve = '/customer/searches/retrieve';
  static const String searches = '/customer/searches';

  static const String customerBookings = '/customer/bookings';
  static const String bookingsBySession = '/bookings';
  static const String customerBookingsPhone = '/customer/bookings/phone';
  static const String bookingsRetrieve = '/customer/bookings/retrieve';
  static const String bookingsRetrieveByCode =
      '/customer/bookings/retrieve-by-code';
  static const String bookingsByCode = '/customer/bookings/code';
  static const String legacyBookings = '/bookings/get_bookings';
  static const String declineBooking = '/gate-way/decline-booking-request';

  static const String transactions = '/payments/transactions';
  static const String transactionRecords = '/payment/get_transaction_records';
  static const String initiatePayment = '/payment/initiate_payment';
  static const String accessPayment = '/customer/properties/access-payment';
  static const String paymentsRetrieve = '/customer/payments/retrieve';

  static const String notifications = '/notifications/get_notifications';
  static const String markNotificationsRead = '/notifications/mark_as_read';

  static const String subscriptionPackages = '/subscriptions/get_packages';
  static const String subscriptionDetails = '/users/get-subscription-details';
  static const String subscriptionCancel = '/subscriptions/cancel';
  static const String brokerSubscribeSuffix = '/subscribe';
  static const String brokerDashboard = '/brokers/dashboard/me';

  static const String feedbackSubmit = '/brokers/feedback/submit';
  static const String accountDeletionOtp =
      '/users/request-account-deletion-otp';
  static const String deleteUserAccount = '/gate-way/delete-user-account';
  static const String changePasswordOtp =
      '/gate-way/get-change-passsword-otp';
  static const String updateUserField = '/users/update-user-field';
  static const String saveUserInfo = '/users/save-user-info';

  static const String properties = '/properties';
  static const String uploadPresign = '/upload/presign';

  static Uri uri(String path, [Map<String, dynamic> query = const {}]) {
    final params = <String, String>{};
    query.forEach((key, value) {
      if (value == null) return;
      final text = value.toString();
      if (text.isEmpty) return;
      params[key] = text;
    });
    return Uri.parse('${ApiConfig.baseUrl}$path')
        .replace(queryParameters: params.isEmpty ? null : params);
  }
}
