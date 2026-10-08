const List<String> kKnownPropertyKeys = [
  'id',
  'name',
  'title',
  'type',
  'propertyType',
  'price',
  'amount',
  'location',
  'subCounty',
  'district',
  'status',
  'isAvailable',
  'image',
  'images',
  'imageUrl',
  'video',
  'videoUrl',
  'uploadDate',
  'createdAt',
  'description',
  'mapLocation',
  'lat',
  'lng',
  'bookState',
  'bookingState',
  'brokerCode',
  'brokersUniqueCode',
  'brokerName',
  'brokerBrandName',
  'brokerPhone',
  'rating',
  'averageRating',
  'ratingCount',
  'totalRatings',
];

Map<String, dynamic> normalizeProperty(Map<String, dynamic> raw) {
  final out = Map<String, dynamic>.from(raw);

  List<String> imageList() {
    final fromImages = raw['images'];
    if (fromImages is List && fromImages.isNotEmpty) {
      return fromImages.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
    }
    final fromUrl = raw['imageUrl'];
    if (fromUrl is List && fromUrl.isNotEmpty) {
      return fromUrl.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
    }
    final single = (raw['image'] ?? '').toString();
    return single.isEmpty ? const [] : [single];
  }

  String? videoUrl() {
    final single = (raw['video'] ?? '').toString();
    if (single.isNotEmpty) return single;
    final fromUrl = raw['videoUrl'];
    if (fromUrl is List && fromUrl.isNotEmpty) {
      final first = fromUrl.first.toString();
      return first.isEmpty ? null : first;
    }
    if (fromUrl is String && fromUrl.isNotEmpty) return fromUrl;
    return null;
  }

  num price() {
    final direct = raw['price'] ?? raw['amount'];
    if (direct is num) return direct;
    return num.tryParse(direct?.toString() ?? '') ?? 0;
  }

  String firstOf(List<dynamic> keys) {
    for (final key in keys) {
      final value = raw[key];
      if (value != null && value.toString().isNotEmpty) {
        return value.toString();
      }
    }
    return '';
  }

  final images = imageList();
  final video = videoUrl();

  out['id'] = firstOf(['id', 'itemID']);
  out['name'] = firstOf(['name', 'title']);
  out['title'] = out['name'];
  out['type'] = firstOf(['type', 'propertyType']);
  out['propertyType'] = out['type'];
  out['price'] = price();
  out['location'] = (raw['location'] ?? raw['area'] ?? '').toString();
  out['subCounty'] = (raw['subCounty'] ?? '').toString();
  out['district'] = (raw['district'] ?? '').toString();

  final isAvailable = raw['isAvailable'];
  out['status'] = (raw['status'] ??
          (isAvailable == false ? 'Booked' : 'Available'))
      .toString();
  out['isAvailable'] = isAvailable ?? true;

  out['images'] = images;
  out['image'] = images.isNotEmpty
      ? images.first
      : (raw['image'] ?? '').toString();
  out['video'] = video ?? '';
  out['uploadDate'] =
      (raw['uploadDate'] ?? raw['createdAt'] ?? '').toString();
  out['description'] = (raw['description'] ?? '').toString();

  final ml = raw['mapLocation'];
  if (ml is Map) {
    out['mapLocation'] = {
      'lat': ml['lat'],
      'lng': ml['lng'],
    };
  } else {
    final lat = raw['lat'];
    final lng = raw['lng'];
    if (lat != null && lng != null) {
      out['mapLocation'] = {'lat': lat, 'lng': lng};
    }
  }

  final bookState = raw['bookState'];
  out['bookState'] = bookState is Map
      ? bookState
      : {
          'isBooked': out['status'] == 'Booked',
          'bookingCount': 0,
        };

  out['brokerCode'] = firstOf(['brokerCode', 'brokersUniqueCode']);
  out['brokersUniqueCode'] = out['brokerCode'];
  out['brokerName'] = firstOf(['brokerName', 'brokerBrandName']);
  if (out['brokerName'].toString().isEmpty) out['brokerName'] = 'Broker';
  out['brokerPhone'] = (raw['brokerPhone'] ?? '').toString();

  final rating = raw['rating'] ?? raw['averageRating'];
  if (rating is num) out['rating'] = rating;
  final ratingCount = raw['ratingCount'] ?? raw['totalRatings'];
  if (ratingCount is num) out['ratingCount'] = ratingCount;

  return out;
}

List<Map<String, dynamic>> normalizeProperties(dynamic list) {
  if (list is! List) return [];
  return list
      .whereType<Map>()
      .map((e) => normalizeProperty(Map<String, dynamic>.from(e)))
      .toList();
}

Map<String, dynamic> normalizeBooking(Map<String, dynamic> raw) {
  final out = Map<String, dynamic>.from(raw);

  String firstOf(List<String> keys) {
    for (final key in keys) {
      final value = raw[key];
      if (value is List && value.isNotEmpty) {
        final first = value.first;
        if (first != null && first.toString().isNotEmpty) {
          return first.toString();
        }
      }
      if (value != null && value.toString().isNotEmpty) {
        return value.toString();
      }
    }
    return '';
  }

  const approved = {'approved', 'accepted', 'confirmed', 'success', 'paid'};
  const rejected = {'rejected', 'declined', 'cancelled', 'canceled', 'failed'};
  final rawStatus = firstOf([
    'status',
    'bookingStatus',
    'state',
  ]).toLowerCase().trim();
  String status;
  if (approved.contains(rawStatus)) {
    status = 'Approved';
  } else if (rejected.contains(rawStatus)) {
    status = 'Rejected';
  } else if (rawStatus.isEmpty || rawStatus == 'pending') {
    status = 'Pending';
  } else {
    status = rawStatus[0].toUpperCase() + rawStatus.substring(1);
  }

  out['id'] = firstOf(['id', 'transactionCode', 'bookingCode', 'bookingId']);
  out['houseName'] =
      firstOf(['houseName', 'propertyName', 'propertyTitle', 'title', 'name']);
  out['houseImg'] = firstOf(
      ['houseImg', 'imageUrl', 'propertyImage', 'image', 'thumbnail']);
  out['date'] = firstOf(['date', 'createdAt', 'bookingDate', 'updatedAt']);
  out['phone'] = firstOf(['phone', 'customerPhone', 'phoneNumber']);
  out['status'] = status;
  out['observed'] = out['observed'] ?? status != 'Pending';
  return out;
}

List<Map<String, dynamic>> normalizeBookings(dynamic list) {
  if (list is! List) return [];
  return list
      .whereType<Map>()
      .map((e) => normalizeBooking(Map<String, dynamic>.from(e)))
      .toList();
}

Map<String, dynamic> normalizeTransaction(Map<String, dynamic> raw) {
  final out = Map<String, dynamic>.from(raw);

  String firstOf(List<String> keys) {
    for (final key in keys) {
      final value = raw[key];
      if (value is List && value.isNotEmpty) {
        final first = value.first;
        if (first != null && first.toString().isNotEmpty) {
          return first.toString();
        }
      }
      if (value != null && value.toString().isNotEmpty) {
        return value.toString();
      }
    }
    return '';
  }

  final amountRaw = raw['amount'];
  final amountNum = amountRaw is num
      ? amountRaw
      : num.tryParse(amountRaw?.toString() ?? '') ?? 0;
  final rawStatus =
      firstOf(['paymentStatus', 'status', 'transactionStatus']).toUpperCase();
  String status;
  if (rawStatus == 'SUCCESS' || rawStatus == 'SUCCESSFUL' || rawStatus == 'PAID') {
    status = 'Success';
  } else if (rawStatus == 'FAILED' || rawStatus == 'DECLINED') {
    status = 'Failed';
  } else if (rawStatus.isEmpty) {
    status = 'Pending';
  } else {
    status = rawStatus[0].toUpperCase() + rawStatus.substring(1).toLowerCase();
  }

  var date = firstOf(['date', 'createdAt', 'paidAt', 'updatedAt']);
  if (date.contains('GMT')) {
    date = date.split(' GMT').first.trim();
    if (date.length > 16) date = date.substring(4, 15);
  } else {
    final parsed = DateTime.tryParse(date);
    if (parsed != null) {
      date =
          '${parsed.year}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}';
    }
  }

  final phone = firstOf(['clientPhone', 'customerPhone', 'phoneNumber']);
  String method = firstOf(['method', 'paymentMethod']);
  if (method.isEmpty) {
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('075') ||
        digits.startsWith('070') ||
        digits.startsWith('077') ||
        digits.startsWith('078')) {
      method = 'MTN Mobile Money';
    } else if (digits.startsWith('074') || digits.startsWith('073')) {
      method = 'Airtel Money';
    } else {
      method = 'Mobile Money';
    }
  }

  out['id'] = firstOf([
    'transactionCode',
    'referenceNumber',
    'id',
  ]);
  out['amount'] = 'UGX ${amountNum.toStringAsFixed(0)} received';
  out['method'] = method;
  out['date'] = date;
  out['status'] = status;
  out['type'] = 'transaction';
  out['package'] = firstOf(['reasonForPayment', 'package', 'reason']);
  out['phone'] = phone;
  out['propertyId'] = firstOf(['propertyId']);
  return out;
}

List<Map<String, dynamic>> normalizeTransactions(dynamic list) {
  if (list is! List) return [];
  return list
      .whereType<Map>()
      .map((e) => normalizeTransaction(Map<String, dynamic>.from(e)))
      .toList();
}

Map<String, dynamic> normalizeNotification(Map<String, dynamic> raw) {
  final out = Map<String, dynamic>.from(raw);

  String firstOf(List<String> keys) {
    for (final key in keys) {
      final value = raw[key];
      if (value is List && value.isNotEmpty) {
        final first = value.first;
        if (first != null && first.toString().isNotEmpty) {
          return first.toString();
        }
      }
      if (value != null && value.toString().isNotEmpty) {
        return value.toString();
      }
    }
    return '';
  }

  final rawType = firstOf(['type', 'category', 'eventType', 'kind'])
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z]'), '');
  String type;
  if (rawType.contains('booking')) {
    type = 'booking';
  } else if (rawType.contains('payment') || rawType.contains('transaction')) {
    type = 'payment';
  } else if (rawType.contains('remove') || rawType.contains('delete')) {
    type = 'propertyRemoved';
  } else if (rawType.contains('upload') ||
      rawType.contains('property') ||
      rawType.contains('review')) {
    type = 'propertyUpload';
  } else if (rawType.isEmpty || rawType.contains('system')) {
    type = 'system';
  } else {
    type = rawType;
  }

  var time = firstOf(['time', 'createdAt', 'date', 'updatedAt']);
  if (time.contains('GMT')) {
    time = time.split(' GMT').first.trim();
  } else {
    final parsed = DateTime.tryParse(time);
    if (parsed != null) {
      final diff = DateTime.now().difference(parsed);
      if (diff.inMinutes < 1) {
        time = 'Just now';
      } else if (diff.inHours < 1) {
        time = '${diff.inMinutes} min ago';
      } else if (diff.inDays < 1) {
        time = '${diff.inHours} hours ago';
      } else if (diff.inDays < 30) {
        time = '${diff.inDays} days ago';
      } else {
        time = '${parsed.day}/${parsed.month}/${parsed.year}';
      }
    }
  }

  out['id'] = firstOf(['id', '_id', 'notificationId']);
  out['type'] = type;
  out['title'] = firstOf(['title', 'subject', 'heading']);
  out['message'] = firstOf(['message', 'body', 'content', 'description']);
  out['time'] = time;
  out['read'] = raw['read'] == true ||
      raw['isRead'] == true ||
      raw['seen'] == true;
  return out;
}

List<Map<String, dynamic>> normalizeNotifications(dynamic list) {
  if (list is! List) return [];
  return list
      .whereType<Map>()
      .map((e) => normalizeNotification(Map<String, dynamic>.from(e)))
      .toList();
}
