import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../auth/data/auth_service.dart';
import 'models/sop_models.dart';

class SopForbiddenException implements Exception {
  final String message;
  SopForbiddenException([this.message = 'Akses dibatasi untuk akun magang/intern.']);

  @override
  String toString() => message;
}

class SaveDocResult {
  final bool success;
  final String? savedPath;
  final String? fileName;
  final String message;

  SaveDocResult({
    required this.success,
    this.savedPath,
    this.fileName,
    required this.message,
  });
}

class SopService {
  static String get baseUrl => AuthService.baseUrl;

  /// Ambil daftar kategori dokumen utama yang ringkas (Semua, SOP, Peraturan, Formulir)
  static Future<List<SopCategory>> fetchCategories() async {
    final token = await AuthService.getToken();
    final uri = Uri.parse('$baseUrl/sop/categories');

    final response = await http.get(
      uri,
      headers: {
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      final List rawData = json['data'] ?? [];
      final list = rawData.map((e) => SopCategory.fromJson(e)).toList();

      // Batasi hanya kategori utama agar tampilan ringkas dan tidak terlalu banyak tab
      const allowedOrder = ['all', 'sop', 'peraturan', 'form'];
      final Map<String, SopCategory> map = {
        for (var c in list) c.key.toLowerCase(): c,
      };

      final List<SopCategory> conciseList = [];
      for (final key in allowedOrder) {
        if (map.containsKey(key)) {
          final original = map[key]!;
          String cleanName = original.name;
          if (key == 'all') cleanName = 'Semua';
          if (key == 'sop') cleanName = 'SOP';
          if (key == 'peraturan') cleanName = 'Peraturan';
          if (key == 'form') cleanName = 'Formulir';
          conciseList.add(SopCategory(key: key, name: cleanName, count: original.count));
        }
      }

      return conciseList.isNotEmpty ? conciseList : list.take(4).toList();
    } else if (response.statusCode == 403) {
      throw SopForbiddenException();
    } else {
      throw Exception('Gagal memuat kategori dokumen (${response.statusCode})');
    }
  }

  /// Ambil daftar dokumen SOP dengan filter, pencarian, dan pagination
  static Future<SopListResponse> fetchDocuments({
    String? category,
    String? search,
    String? sort,
    int page = 1,
    int perPage = 20,
  }) async {
    final token = await AuthService.getToken();

    final queryParams = <String, String>{
      'page': page.toString(),
      'per_page': perPage.toString(),
    };

    if (category != null && category.isNotEmpty && category != 'all') {
      queryParams['category'] = category;
    }
    if (search != null && search.trim().isNotEmpty) {
      queryParams['search'] = search.trim();
    }
    if (sort != null && sort.isNotEmpty) {
      queryParams['sort'] = sort;
    }

    final uri = Uri.parse('$baseUrl/sop').replace(queryParameters: queryParams);

    final response = await http.get(
      uri,
      headers: {
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      final List rawData = json['data'] ?? [];
      final documents = rawData.map((e) => SopDocument.fromJson(e)).toList();
      final meta = SopPaginationMeta.fromJson(json['meta']);

      return SopListResponse(
        isForbidden: false,
        message: json['message'] ?? 'Berhasil memuat dokumen.',
        documents: documents,
        meta: meta,
      );
    } else if (response.statusCode == 403) {
      return SopListResponse(
        isForbidden: true,
        message: 'Akses dibatasi untuk akun magang/intern.',
        documents: [],
        meta: SopPaginationMeta(currentPage: 1, lastPage: 1, perPage: perPage, total: 0),
      );
    } else {
      throw Exception('Gagal memuat daftar dokumen (${response.statusCode})');
    }
  }

  /// Ambil detail dokumen SOP berdasarkan ID
  static Future<SopDocument> fetchDocumentDetail(int id) async {
    final token = await AuthService.getToken();
    final uri = Uri.parse('$baseUrl/sop/$id');

    final response = await http.get(
      uri,
      headers: {
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return SopDocument.fromJson(json['data']);
    } else if (response.statusCode == 403) {
      throw SopForbiddenException();
    } else {
      throw Exception('Gagal memuat detail dokumen (${response.statusCode})');
    }
  }

  /// Dapatkan URL pratinjau inline yang sudah disematkan query parameter token
  static Future<String> getViewUrlWithToken(SopDocument doc) async {
    final rawUrl = doc.viewUrl ?? '$baseUrl/sop/${doc.id}/view';
    final token = await AuthService.getToken();
    if (token == null || token.isEmpty) return rawUrl;

    final uri = Uri.parse(rawUrl);
    final params = Map<String, String>.from(uri.queryParameters);
    params['token'] = token;
    return uri.replace(queryParameters: params).toString();
  }

  /// Dapatkan URL unduh yang sudah disematkan query parameter token
  static Future<String> getDownloadUrlWithToken(SopDocument doc) async {
    final rawUrl = doc.downloadUrl ?? '$baseUrl/sop/${doc.id}/download';
    final token = await AuthService.getToken();
    if (token == null || token.isEmpty) return rawUrl;

    final uri = Uri.parse(rawUrl);
    final params = Map<String, String>.from(uri.queryParameters);
    params['token'] = token;
    return uri.replace(queryParameters: params).toString();
  }

  /// Unduh file fisik dokumen dan simpan di direktori lokal untuk dibuka atau dibagikan
  static Future<File> downloadFile(SopDocument doc) async {
    final token = await AuthService.getToken();
    final downloadUrl = doc.downloadUrl ?? '$baseUrl/sop/${doc.id}/download';

    final response = await http.get(
      Uri.parse(downloadUrl),
      headers: {
        if (token != null) 'Authorization': 'Bearer $token',
        'Accept': '*/*',
      },
    );

    if (response.statusCode == 200) {
      final tempDir = await getTemporaryDirectory();
      String fileName = doc.originalName ?? '${doc.title.replaceAll(RegExp(r'[^\w\s\.-]'), '_')}.${doc.fileExtension ?? 'pdf'}';
      if (!fileName.contains('.')) {
        fileName = '$fileName.${doc.fileExtension ?? 'pdf'}';
      }

      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(response.bodyBytes);
      return file;
    } else if (response.statusCode == 403) {
      throw SopForbiddenException();
    } else {
      throw Exception('Gagal mengunduh berkas (${response.statusCode})');
    }
  }

  /// Unduh berkas fisik dan simpan langsung ke folder Download / penyimpanan perangkat
  static Future<SaveDocResult> saveDocumentToStorage(SopDocument doc) async {
    final token = await AuthService.getToken();
    final downloadUrl = doc.downloadUrl ?? '$baseUrl/sop/${doc.id}/download';

    final response = await http.get(
      Uri.parse(downloadUrl),
      headers: {
        if (token != null) 'Authorization': 'Bearer $token',
        'Accept': '*/*',
      },
    );

    if (response.statusCode == 403) {
      throw SopForbiddenException();
    }
    if (response.statusCode != 200) {
      throw Exception('Gagal mengunduh berkas (${response.statusCode})');
    }

    String fileName = doc.originalName ??
        '${doc.title.replaceAll(RegExp(r'[^\w\s\.-]'), '_')}.${doc.fileExtension ?? 'pdf'}';
    if (!fileName.contains('.')) {
      fileName = '$fileName.${doc.fileExtension ?? 'pdf'}';
    }

    // 1. Coba simpan langsung ke folder publik Download di Android
    if (Platform.isAndroid) {
      try {
        final downloadDir = Directory('/storage/emulated/0/Download');
        if (await downloadDir.exists()) {
          final targetFile = File('${downloadDir.path}/$fileName');
          await targetFile.writeAsBytes(response.bodyBytes);
          return SaveDocResult(
            success: true,
            savedPath: targetFile.path,
            fileName: fileName,
            message: 'Dokumen berhasil diunduh ke folder Download: $fileName',
          );
        }
      } catch (_) {
        // Jika scoped storage membatasi direct write, lanjutkan ke FilePicker SAF
      }
    }

    // 2. Gunakan FilePicker.saveFile agar pengguna dapat memilih lokasi simpan resmi
    try {
      final savedPath = await FilePicker.saveFile(
        dialogTitle: 'Pilih lokasi simpan dokumen',
        fileName: fileName,
        bytes: response.bodyBytes,
        type: FileType.custom,
        allowedExtensions: [doc.fileExtension?.replaceAll('.', '') ?? 'pdf'],
      );

      if (savedPath != null) {
        return SaveDocResult(
          success: true,
          savedPath: savedPath,
          fileName: fileName,
          message: 'Dokumen berhasil disimpan: $fileName',
        );
      } else {
        return SaveDocResult(
          success: false,
          fileName: fileName,
          message: 'Unduhan dibatalkan oleh pengguna.',
        );
      }
    } catch (_) {
      // 3. Fallback ke Documents directory
      try {
        final appDir = await getApplicationDocumentsDirectory();
        final fallbackFile = File('${appDir.path}/$fileName');
        await fallbackFile.writeAsBytes(response.bodyBytes);
        return SaveDocResult(
          success: true,
          savedPath: fallbackFile.path,
          fileName: fileName,
          message: 'Dokumen berhasil diunduh: $fileName',
        );
      } catch (err) {
        throw Exception('Gagal menyimpan berkas ke perangkat: $err');
      }
    }
  }
}
