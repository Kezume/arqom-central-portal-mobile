class SopDocument {
  final int id;
  final String title;
  final String category;
  final String categoryLabel;
  final String? description;
  final String divisionScope;
  final String targetLabel;
  final List<String> targetDivisions;
  final String documentType;
  final String? originalName;
  final String? mimeType;
  final int? fileSize;
  final String? fileSizeFormatted;
  final String? fileExtension;
  final String? downloadUrl;
  final String? viewUrl;
  final String? externalUrl;
  final String? publishedAt;
  final String? publishedDate;
  final String? createdByName;

  SopDocument({
    required this.id,
    required this.title,
    required this.category,
    required this.categoryLabel,
    this.description,
    required this.divisionScope,
    required this.targetLabel,
    required this.targetDivisions,
    required this.documentType,
    this.originalName,
    this.mimeType,
    this.fileSize,
    this.fileSizeFormatted,
    this.fileExtension,
    this.downloadUrl,
    this.viewUrl,
    this.externalUrl,
    this.publishedAt,
    this.publishedDate,
    this.createdByName,
  });

  factory SopDocument.fromJson(Map<String, dynamic> json) {
    List<String> parseDivisions(dynamic raw) {
      if (raw is List) {
        return raw.map((e) => e.toString()).toList();
      }
      return [];
    }

    return SopDocument(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      title: json['title'] ?? '',
      category: json['category'] ?? '',
      categoryLabel: json['category_label'] ?? json['category'] ?? '',
      description: json['description'],
      divisionScope: json['division_scope'] ?? 'all',
      targetLabel: json['target_label'] ?? (json['division_scope'] == 'all' ? 'Semua Divisi' : 'Khusus'),
      targetDivisions: parseDivisions(json['target_divisions']),
      documentType: json['document_type'] ?? 'file',
      originalName: json['original_name'],
      mimeType: json['mime_type'],
      fileSize: json['file_size'] is int ? json['file_size'] : int.tryParse(json['file_size']?.toString() ?? ''),
      fileSizeFormatted: json['file_size_formatted'],
      fileExtension: json['file_extension'],
      downloadUrl: json['download_url'],
      viewUrl: json['view_url'],
      externalUrl: json['external_url'],
      publishedAt: json['published_at'],
      publishedDate: json['published_date'],
      createdByName: json['created_by_name'],
    );
  }

  bool get isPdf =>
      fileExtension?.toLowerCase() == 'pdf' ||
      mimeType == 'application/pdf' ||
      originalName?.toLowerCase().endsWith('.pdf') == true;

  bool get isExternal => documentType == 'url' || (externalUrl != null && externalUrl!.isNotEmpty);
}

class SopCategory {
  final String key;
  final String name;
  final int count;

  SopCategory({
    required this.key,
    required this.name,
    required this.count,
  });

  factory SopCategory.fromJson(Map<String, dynamic> json) {
    return SopCategory(
      key: json['key'] ?? '',
      name: json['name'] ?? '',
      count: json['count'] is int ? json['count'] : int.tryParse(json['count']?.toString() ?? '0') ?? 0,
    );
  }
}

class SopPaginationMeta {
  final int currentPage;
  final int lastPage;
  final int perPage;
  final int total;

  SopPaginationMeta({
    required this.currentPage,
    required this.lastPage,
    required this.perPage,
    required this.total,
  });

  factory SopPaginationMeta.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return SopPaginationMeta(currentPage: 1, lastPage: 1, perPage: 20, total: 0);
    }
    return SopPaginationMeta(
      currentPage: json['current_page'] is int ? json['current_page'] : int.tryParse(json['current_page']?.toString() ?? '1') ?? 1,
      lastPage: json['last_page'] is int ? json['last_page'] : int.tryParse(json['last_page']?.toString() ?? '1') ?? 1,
      perPage: json['per_page'] is int ? json['per_page'] : int.tryParse(json['per_page']?.toString() ?? '20') ?? 20,
      total: json['total'] is int ? json['total'] : int.tryParse(json['total']?.toString() ?? '0') ?? 0,
    );
  }
}

class SopListResponse {
  final bool isForbidden;
  final String? message;
  final List<SopDocument> documents;
  final SopPaginationMeta? meta;

  SopListResponse({
    this.isForbidden = false,
    this.message,
    required this.documents,
    this.meta,
  });
}
