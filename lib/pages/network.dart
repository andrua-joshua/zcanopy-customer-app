import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:pointycastle/export.dart';
import 'package:convert/convert.dart';
import 'dart:typed_data';
import 'package:pointycastle/asymmetric/api.dart';
import 'package:asn1lib/asn1lib.dart';
import 'package:hive_flutter/hive_flutter.dart';

  final database = Hive.box('myStore');
  final sessionID = database.get('sessionID');

class RSAKeyParser {
  RSAPublicKey parse(String publicKeyPem) {
    final lines = publicKeyPem
        .replaceAll('-----BEGIN PUBLIC KEY-----', '')
        .replaceAll('-----END PUBLIC KEY-----', '')
        .replaceAll('\n', '')
        .replaceAll('\r', '');

    final bytes = base64.decode(lines);
    final asn1Parser = ASN1Parser(bytes);
    final topLevelSeq = asn1Parser.nextObject() as ASN1Sequence;

    final publicKeyBitString = topLevelSeq.elements[1] as ASN1BitString;
    final publicKeyAsn = ASN1Parser(publicKeyBitString as Uint8List);
//    final publicKeyAsn =ASN1Parser(publicKeyBitString.stringValues as Uint8List);

    final publicKeySeq = publicKeyAsn.nextObject() as ASN1Sequence;

    final modulus = publicKeySeq.elements[0] as ASN1Integer;
    final exponent = publicKeySeq.elements[1] as ASN1Integer;

    return RSAPublicKey(modulus.valueAsBigInteger, exponent.valueAsBigInteger);
  }
}

class NetworkService {
  // RSA Public Key (example — replace with your actual key)
  static const String _publicKeyPem = '''
-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAv5gPo5NF3xQ3F8iZXDWD
...
fH49Pf5dHJDFwIDAQAB
-----END PUBLIC KEY-----
''';

  // ----------------- Public Methods -----------------

  /// Global GET request
  static Future<Map<String, dynamic>> get(String url) async {
   
    try {
      final response = await http.get(Uri.parse(url+'&sessionID=${sessionID}'));

      if (_isSuccess(response.statusCode)) {
        return jsonDecode(response.body);
      } else {
        throw HttpException('GET request failed: ${response.statusCode}');
      }
    } catch (e) {
      print('GET error: $e');
      rethrow;
    }
  }

  /// Global POST request with RSA encrypted body
  static Future<Map<String, dynamic>> post(
      String url, Map<String, dynamic> data) async {
    try {
      final encryptedData = _encryptData(data);

      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'payload': encryptedData}),
      );

      if (_isSuccess(response.statusCode)) {
        return jsonDecode(response.body);
      } else {
        throw HttpException('POST request failed: ${response.statusCode}');
      }
    } catch (e) {
      print('POST error: $e');
      rethrow;
    }
  }

  // ----------------- Helpers -----------------

  static bool _isSuccess(int statusCode) =>
      statusCode >= 200 && statusCode < 300;

  /// Encrypts the JSON data using RSA
  static String _encryptData(Map<String, dynamic> data) {
    final parser = RSAKeyParser();
    final publicKey = parser.parse(_publicKeyPem) as RSAPublicKey;

    final encryptor = OAEPEncoding(RSAEngine())
      ..init(true, PublicKeyParameter<RSAPublicKey>(publicKey));

    final inputData = utf8.encode(jsonEncode(data));

    // RSA encryption works on chunks smaller than the key size
    final output = <int>[];
    final inputLen = inputData.length;
    final chunkSize =
        publicKey.modulus!.bitLength ~/ 8 - 42; // for OAEP padding

    for (var i = 0; i < inputLen; i += chunkSize) {
      final chunk = inputData.sublist(
          i, (i + chunkSize > inputLen) ? inputLen : i + chunkSize);
      final encryptedChunk = encryptor.process(Uint8List.fromList(chunk));
      output.addAll(encryptedChunk);
    }

    return base64Encode(output);
  }
}

// ----------------- Custom Error -----------------
class HttpException implements Exception {
  final String message;
  HttpException(this.message);

  @override
  String toString() => 'HttpException: $message';
}
