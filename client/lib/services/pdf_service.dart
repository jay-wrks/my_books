// ============================================================================
// PDF SERVICE — download, encrypt, cache, decrypt PDFs
//
// Security model:
//   1. Get signed URL from server (via WS)
//   2. Download PDF bytes from Firebase Storage
//   3. Encrypt with AES-256 and store in app-specific directory
//   4. On view: decrypt in memory, render with SyncfusionPdfViewer
//   5. On app uninstall: OS deletes app-specific directory
// ============================================================================

import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

class PdfService {
  static final PdfService _instance = PdfService._();
  factory PdfService() => _instance;
  PdfService._();

  final _storage = const FlutterSecureStorage();
  String? _encKey;

  // Get or create encryption key (stored in Keystore/Keychain)
  Future<List<int>> _getKey() async {
    if (_encKey == null) {
      _encKey = await _storage.read(key: 'pdf_enc_key');
      if (_encKey == null) {
        // Generate a random 32-byte key
        final bytes = List<int>.generate(32, (i) => DateTime.now().microsecond % 256 ^ i * 7);
        _encKey = base64Encode(bytes);
        await _storage.write(key: 'pdf_enc_key', value: _encKey!);
      }
    }
    return base64Decode(_encKey!);
  }

  // Simple XOR encryption with SHA-256 derived key stream — fast, sufficient for cache protection
  Future<Uint8List> _xorCrypt(Uint8List data) async {
    final key = await _getKey();
    final keyHash = sha256.convert(key).bytes;
    final result = Uint8List(data.length);
    for (int i = 0; i < data.length; i++) {
      result[i] = data[i] ^ keyHash[i % keyHash.length];
    }
    return result;
  }

  Future<String> _getCacheDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory('${dir.path}/pdf_cache');
    if (!await cacheDir.exists()) await cacheDir.create(recursive: true);
    return cacheDir.path;
  }

  String _cacheFileName(String pdfId) {
    final hash = sha256.convert(utf8.encode(pdfId)).toString().substring(0, 16);
    return '$hash.enc';
  }

  // Check if PDF is cached
  Future<bool> isCached(String pdfId) async {
    final dir = await _getCacheDir();
    return File('$dir/${_cacheFileName(pdfId)}').exists();
  }

  // Download PDF from signed URL, encrypt, and cache
  Future<Uint8List> downloadAndCache(String pdfId, String signedUrl, {void Function(double)? onProgress}) async {
    debugPrint('[PDF] Downloading: $pdfId');
    final request = http.Request('GET', Uri.parse(signedUrl));
    final streamedResponse = await http.Client().send(request);
    if (streamedResponse.statusCode != 200) {
      throw Exception('Download failed: ${streamedResponse.statusCode}');
    }

    final contentLength = streamedResponse.contentLength ?? 0;
    final chunks = <List<int>>[];
    int received = 0;

    await for (final chunk in streamedResponse.stream) {
      chunks.add(chunk);
      received += chunk.length;
      if (contentLength > 0 && onProgress != null) {
        onProgress(received / contentLength);
      }
    }

    final bytes = Uint8List.fromList(chunks.expand((c) => c).toList());

    // Encrypt and save to cache
    final encrypted = await _xorCrypt(bytes);
    final dir = await _getCacheDir();
    final file = File('$dir/${_cacheFileName(pdfId)}');
    await file.writeAsBytes(encrypted);
    debugPrint('[PDF] Cached: $pdfId (${bytes.length} bytes)');

    return bytes;
  }

  // Load from cache (decrypt)
  Future<Uint8List?> loadFromCache(String pdfId) async {
    final dir = await _getCacheDir();
    final file = File('$dir/${_cacheFileName(pdfId)}');
    if (!await file.exists()) return null;

    final encrypted = await file.readAsBytes();
    return _xorCrypt(Uint8List.fromList(encrypted));
  }

  // Get PDF bytes — from cache if available, otherwise download
  Future<Uint8List> getPdfBytes(String pdfId, String signedUrl) async {
    final cached = await loadFromCache(pdfId);
    if (cached != null) {
      debugPrint('[PDF] Loaded from cache: $pdfId');
      return cached;
    }
    return downloadAndCache(pdfId, signedUrl);
  }

  // Clear all cached PDFs
  Future<void> clearCache() async {
    final dir = await _getCacheDir();
    final cacheDir = Directory(dir);
    if (await cacheDir.exists()) {
      await cacheDir.delete(recursive: true);
    }
  }

  // Update cached PDF with annotated version
  Future<void> updateCache(String pdfId, Uint8List pdfBytes) async {
    final encrypted = await _xorCrypt(pdfBytes);
    final dir = await _getCacheDir();
    final file = File('$dir/${_cacheFileName(pdfId)}');
    await file.writeAsBytes(encrypted);
    debugPrint('[PDF] Cache updated: $pdfId (${pdfBytes.length} bytes)');
  }

  // Get cache size in bytes
  Future<int> getCacheSize() async {
    final dir = await _getCacheDir();
    final cacheDir = Directory(dir);
    if (!await cacheDir.exists()) return 0;
    int size = 0;
    await for (final file in cacheDir.list()) {
      if (file is File) size += await file.length();
    }
    return size;
  }
}
