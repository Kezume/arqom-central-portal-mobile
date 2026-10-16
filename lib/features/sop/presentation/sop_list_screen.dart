import 'dart:async';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/artech_loading_widget.dart';
import '../../../core/widgets/artech_pull_to_refresh.dart';
import '../data/models/sop_models.dart';
import '../data/sop_service.dart';
import '../../notifications/data/push_notification_service.dart';
import '../../notifications/presentation/notifications_screen.dart';
import '../../notifications/data/notifications_service.dart';

class SopListScreen extends StatefulWidget {
  const SopListScreen({super.key});

  @override
  State<SopListScreen> createState() => _SopListScreenState();
}

class _SopListScreenState extends State<SopListScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;

  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _isForbidden = false;
  String? _errorMessage;

  List<SopCategory> _categories = [
    SopCategory(key: 'all', name: 'Semua', count: 0),
    SopCategory(key: 'sop', name: 'SOP', count: 0),
    SopCategory(key: 'peraturan', name: 'Peraturan', count: 0),
    SopCategory(key: 'form', name: 'Formulir', count: 0),
  ];
  String _selectedCategoryKey = 'all';

  String _selectedSort = 'latest';
  final Map<String, String> _sortOptions = {
    'latest': 'Terbaru',
    'oldest': 'Terlama',
    'title_asc': 'Judul (A - Z)',
    'title_desc': 'Judul (Z - A)',
  };

  List<SopDocument> _documents = [];
  SopPaginationMeta? _meta;
  int _currentPage = 1;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoading && !_isLoadingMore && _meta != null && _currentPage < _meta!.lastPage) {
        _loadMoreDocuments();
      }
    }
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _isForbidden = false;
      _currentPage = 1;
    });

    try {
      // 1. Fetch categories
      try {
        final categories = await SopService.fetchCategories();
        if (mounted) {
          setState(() {
            _categories = categories;
          });
        }
      } catch (e) {
        if (e is SopForbiddenException) {
          if (mounted) {
            setState(() {
              _isForbidden = true;
              _isLoading = false;
            });
          }
          return;
        }
        // If categories fail for another reason, continue to try documents
      }

      // 2. Fetch documents
      final response = await SopService.fetchDocuments(
        category: _selectedCategoryKey,
        search: _searchController.text,
        sort: _selectedSort,
        page: 1,
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
          _isForbidden = response.isForbidden;
          if (!response.isForbidden) {
            _documents = response.documents;
            _meta = response.meta;
            _currentPage = 1;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  Future<void> _loadMoreDocuments() async {
    if (_meta == null || _currentPage >= _meta!.lastPage) return;

    setState(() => _isLoadingMore = true);

    try {
      final nextPage = _currentPage + 1;
      final response = await SopService.fetchDocuments(
        category: _selectedCategoryKey,
        search: _searchController.text,
        sort: _selectedSort,
        page: nextPage,
      );

      if (mounted) {
        setState(() {
          _isLoadingMore = false;
          _currentPage = nextPage;
          _documents.addAll(response.documents);
          _meta = response.meta;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingMore = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat halaman berikutnya: $e')),
        );
      }
    }
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _applyFilter();
    });
  }

  void _onCategorySelected(String key) {
    if (_selectedCategoryKey == key) return;
    setState(() {
      _selectedCategoryKey = key;
    });
    _applyFilter();
  }

  void _onSortChanged(String sortKey) {
    if (_selectedSort == sortKey) return;
    setState(() {
      _selectedSort = sortKey;
    });
    _applyFilter();
  }

  Future<void> _applyFilter() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _currentPage = 1;
    });

    try {
      final response = await SopService.fetchDocuments(
        category: _selectedCategoryKey,
        search: _searchController.text,
        sort: _selectedSort,
        page: 1,
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
          _isForbidden = response.isForbidden;
          _documents = response.documents;
          _meta = response.meta;
          _currentPage = 1;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  Future<void> _handleSaveToDevice(SopDocument doc) async {
    final notifId = (doc.id.abs() + 8000) % 2147483647;
    final fileFullName = doc.originalName ?? '${doc.title}.${doc.fileExtension ?? "pdf"}';

    // 1. Munculkan pop-up notifikasi HP saat proses unduh dimulai
    await PushNotificationService.showDownloadProgressNotification(
      id: notifId,
      title: doc.title,
      fileName: fileFullName,
    );

    if (!mounted) return;

    try {
      ArtechLoadingWidget.showLoadingDialog(
        context,
        message: 'Mengunduh berkas ${doc.fileExtension?.toUpperCase() ?? "dokumen"} ke perangkat...',
      );

      final result = await SopService.saveDocumentToStorage(doc);

      if (!mounted) return;
      ArtechLoadingWidget.hideLoadingDialog(context);

      if (result.success) {
        // 2. Munculkan pop-up notifikasi HP saat unduhan selesai
        await PushNotificationService.showDownloadCompletedNotification(
          id: notifId,
          title: doc.title,
          fileName: result.fileName ?? fileFullName,
          filePath: result.savedPath,
        );

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    result.message,
                    style: const TextStyle(fontSize: 12.5),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF059669),
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Bagikan',
              textColor: Colors.white,
              onPressed: () => _handleShare(doc),
            ),
          ),
        );
      } else {
        await PushNotificationService.cancelNotification(notifId);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: const Color(0xFF475569),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ArtechLoadingWidget.hideLoadingDialog(context);

      // 3. Munculkan pop-up notifikasi HP jika unduhan gagal
      await PushNotificationService.showDownloadFailedNotification(
        id: notifId,
        title: doc.title,
        reason: e is SopForbiddenException
            ? 'Akses dibatasi untuk akun magang/intern.'
            : 'Gagal mengunduh berkas.',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e is SopForbiddenException
                ? 'Akses dibatasi untuk akun magang/intern.'
                : 'Gagal mengunduh dokumen: $e',
          ),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _handleShare(SopDocument doc) async {
    try {
      ArtechLoadingWidget.showLoadingDialog(
        context,
        message: 'Menyiapkan berkas ${doc.fileExtension?.toUpperCase() ?? "dokumen"}...',
      );

      final file = await SopService.downloadFile(doc);

      if (!mounted) return;
      ArtechLoadingWidget.hideLoadingDialog(context);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Dokumen Resmi: ${doc.title}',
      );
    } catch (e) {
      if (!mounted) return;
      ArtechLoadingWidget.hideLoadingDialog(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e is SopForbiddenException
                ? 'Akses dibatasi untuk akun magang/intern.'
                : 'Gagal menyiapkan dokumen: $e',
          ),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _showDocumentDetail(SopDocument doc) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _DocumentDetailSheet(
        document: doc,
        onDownload: () {
          Navigator.pop(ctx);
          _handleSaveToDevice(doc);
        },
        onShare: () {
          Navigator.pop(ctx);
          _handleShare(doc);
        },
      ),
    );
  }

  void _showSortModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.sort_rounded, color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Urutkan Dokumen',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ..._sortOptions.entries.map((entry) {
              final isSelected = _selectedSort == entry.key;
              return InkWell(
                onTap: () {
                  Navigator.pop(ctx);
                  _onSortChanged(entry.key);
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  margin: const EdgeInsets.only(bottom: 6),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary.withValues(alpha: 0.08) : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : Colors.transparent,
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        entry.value,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? AppColors.primary : AppColors.onSurface,
                        ),
                      ),
                      if (isSelected)
                        const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 20),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: AppColors.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'SOP & Dokumen Resmi',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: AppColors.onSurface,
              ),
            ),
            Text(
              'Standar Operasional & Kebijakan',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.onSurface.withValues(alpha: 0.6),
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Urutkan Dokumen',
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.sort_rounded, color: AppColors.primary, size: 20),
            ),
            onPressed: _showSortModal,
          ),
          ValueListenableBuilder<int>(
            valueListenable: NotificationsService.unreadCountNotifier,
            builder: (context, unreadCount, _) {
              final iconWidget = Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.notifications_none_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              );

              return IconButton(
                tooltip: 'Notifikasi',
                icon: unreadCount > 0
                    ? Badge(
                        backgroundColor: const Color(0xFFEF4444),
                        smallSize: 8,
                        child: iconWidget,
                      )
                    : iconWidget,
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const NotificationsScreen(),
                    ),
                  );
                  NotificationsService.refreshUnreadCount();
                },
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isForbidden
          ? _buildForbiddenState()
          : Column(
              children: [
                _buildSearchAndFilters(),
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: ArtechLoadingWidget(
                            size: 64,
                            message: 'Memuat dokumen SOP...',
                          ),
                        )
                      : _errorMessage != null
                          ? _buildErrorState()
                          : _documents.isEmpty
                              ? _buildEmptyState()
                              : ArtechPullToRefresh(
                                  onRefresh: _loadInitialData,
                                  child: ListView.separated(
                                    controller: _scrollController,
                                    physics: const AlwaysScrollableScrollPhysics(
                                      parent: BouncingScrollPhysics(),
                                    ),
                                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                                    itemCount: _documents.length + (_isLoadingMore ? 1 : 0),
                                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                                    itemBuilder: (context, index) {
                                      if (index == _documents.length) {
                                        return const Center(
                                          child: Padding(
                                            padding: EdgeInsets.symmetric(vertical: 16),
                                            child: SizedBox(
                                              width: 24,
                                              height: 24,
                                              child: CircularProgressIndicator(strokeWidth: 2.5),
                                            ),
                                          ),
                                        );
                                      }
                                      final doc = _documents[index];
                                      return _buildDocumentCard(doc);
                                    },
                                  ),
                                ),
                ),
              ],
            ),
    );
  }

  // ─── SEARCH & CATEGORY CHIPS ───────────────────────────────────────────────
  Widget _buildSearchAndFilters() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        children: [
          // Search Bar
          Container(
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Cari judul, topik, atau kata kunci...',
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: AppColors.onSurface.withValues(alpha: 0.4),
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          _applyFilter();
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 11),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Categories Horizontal Scroll
          if (_categories.isNotEmpty)
            SizedBox(
              height: 34,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: _categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final cat = _categories[index];
                  final isSelected = _selectedCategoryKey == cat.key;

                  return InkWell(
                    onTap: () => _onCategorySelected(cat.key),
                    borderRadius: BorderRadius.circular(18),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            cat.name,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected ? Colors.white : AppColors.onSurface,
                            ),
                          ),
                          if (cat.count > 0) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.white.withValues(alpha: 0.25)
                                    : AppColors.primary.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${cat.count}',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? Colors.white : AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  // ─── DOCUMENT CARD ─────────────────────────────────────────────────────────
  Widget _buildDocumentCard(SopDocument doc) {
    final categoryColor = _getCategoryColor(doc.category.toLowerCase());
    final isPdf = doc.isPdf;

    return InkWell(
      onTap: () => _showDocumentDetail(doc),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: Type Icon, Category & Scope Pills
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // File Type Badge
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isPdf
                        ? const Color(0xFFFEE2E2)
                        : doc.isExternal
                            ? const Color(0xFFE0E7FF)
                            : const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isPdf
                        ? Icons.picture_as_pdf_rounded
                        : doc.isExternal
                            ? Icons.open_in_browser_rounded
                            : Icons.description_rounded,
                    color: isPdf
                        ? const Color(0xFFDC2626)
                        : doc.isExternal
                            ? const Color(0xFF4F46E5)
                            : const Color(0xFF475569),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),

                // Title & Category
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          // Category Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: categoryColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              doc.categoryLabel.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: categoryColor,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),

                          // Scope Badge
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: doc.divisionScope == 'all'
                                    ? const Color(0xFFECFDF5)
                                    : const Color(0xFFFFFBEB),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: doc.divisionScope == 'all'
                                      ? const Color(0xFFA7F3D0)
                                      : const Color(0xFFFDE68A),
                                  width: 0.8,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    doc.divisionScope == 'all'
                                        ? Icons.public_rounded
                                        : Icons.groups_rounded,
                                    size: 11,
                                    color: doc.divisionScope == 'all'
                                        ? const Color(0xFF059669)
                                        : const Color(0xFFD97706),
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      doc.targetLabel,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: doc.divisionScope == 'all'
                                            ? const Color(0xFF059669)
                                            : const Color(0xFFD97706),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Document Title
                      Text(
                        doc.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.onSurface,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Description snippet (if available)
            if (doc.description != null && doc.description!.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                doc.description!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.onSurface.withValues(alpha: 0.65),
                  height: 1.35,
                ),
              ),
            ],

            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 10),

            // Bottom metadata and actions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Metadata (size, date)
                Flexible(
                  child: Wrap(
                    spacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (doc.fileSizeFormatted != null)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.sd_storage_outlined,
                                size: 13, color: AppColors.onSurface.withValues(alpha: 0.5)),
                            const SizedBox(width: 4),
                            Text(
                              doc.fileSizeFormatted!,
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.onSurface.withValues(alpha: 0.7),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      if (doc.publishedDate != null)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.calendar_today_outlined,
                                size: 12, color: AppColors.onSurface.withValues(alpha: 0.5)),
                            const SizedBox(width: 4),
                            Text(
                              doc.publishedDate!,
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.onSurface.withValues(alpha: 0.7),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),

                // Quick Action Buttons
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Tombol Unduh ke Perangkat
                    InkWell(
                      onTap: () => _handleSaveToDevice(doc),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.file_download_outlined, size: 15, color: AppColors.primary),
                            SizedBox(width: 4),
                            Text(
                              'Unduh',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Tombol Bagikan
                    InkWell(
                      onTap: () => _handleShare(doc),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.share_outlined, size: 14, color: Color(0xFF475569)),
                            SizedBox(width: 4),
                            Text(
                              'Bagikan',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF475569),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── 403 FORBIDDEN INTERN RESTRICTION STATE ────────────────────────────────
  Widget _buildForbiddenState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFFCA5A5), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  Icons.shield_outlined,
                  color: Color(0xFFDC2626),
                  size: 48,
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Akses Dokumen Dibatasi',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: AppColors.onSurface,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Sesuai ketentuan dan aturan web portal perusahaan, akun bertipe Intern / PKL / Magang dibatasi dari akses modul SOP & Dokumen Resmi.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: AppColors.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: Color(0xFFD97706), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Bila Anda membutuhkan dokumen tertentu untuk penugasan magang, silakan koordinasikan dengan mentor atau tim HCGA.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.amber.shade900,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: const Text('Kembali ke Beranda'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── EMPTY STATE ───────────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.folder_open_rounded,
                color: AppColors.primary,
                size: 40,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Tidak Ada Dokumen',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _searchController.text.isNotEmpty
                  ? 'Tidak ditemukan dokumen dengan kata kunci "${_searchController.text}".'
                  : 'Belum ada dokumen yang tersedia untuk kategori ini.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.onSurface.withValues(alpha: 0.6),
              ),
            ),
            if (_searchController.text.isNotEmpty || _selectedCategoryKey != 'all') ...[
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: () {
                  _searchController.clear();
                  _onCategorySelected('all');
                },
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Reset Filter'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─── ERROR STATE ───────────────────────────────────────────────────────────
  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 48),
            const SizedBox(height: 16),
            const Text(
              'Gagal Memuat Dokumen',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Terjadi kesalahan sistem.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _loadInitialData,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Coba Lagi'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getCategoryColor(String cat) {
    if (cat.contains('sop')) return const Color(0xFF2563EB); // Blue
    if (cat.contains('peraturan')) return const Color(0xFF7C3AED); // Purple
    if (cat.contains('form')) return const Color(0xFF059669); // Emerald
    if (cat.contains('struktur')) return const Color(0xFF0891B2); // Cyan
    if (cat.contains('kebijakan')) return const Color(0xFFEA580C); // Orange
    return const Color(0xFF475569); // Slate
  }
}

// ─── DOCUMENT DETAIL BOTTOM SHEET ─────────────────────────────────────────────
class _DocumentDetailSheet extends StatelessWidget {
  final SopDocument document;
  final VoidCallback onDownload;
  final VoidCallback onShare;

  const _DocumentDetailSheet({
    required this.document,
    required this.onDownload,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 12, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Rincian Dokumen',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.onSurface,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // Body
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    document.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Pill badges
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildPill(
                        document.categoryLabel.toUpperCase(),
                        const Color(0xFFEFF6FF),
                        const Color(0xFF1D4ED8),
                      ),
                      _buildPill(
                        document.targetLabel,
                        document.divisionScope == 'all'
                            ? const Color(0xFFECFDF5)
                            : const Color(0xFFFFFBEB),
                        document.divisionScope == 'all'
                            ? const Color(0xFF059669)
                            : const Color(0xFFD97706),
                      ),
                      if (document.fileExtension != null)
                        _buildPill(
                          document.fileExtension!.toUpperCase(),
                          const Color(0xFFF1F5F9),
                          const Color(0xFF475569),
                        ),
                    ],
                  ),

                  // Target divisions list if specific
                  if (document.divisionScope != 'all' && document.targetDivisions.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Divisi yang Berhak Mengakses:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: document.targetDivisions.map((div) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Text(
                            div,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                          ),
                        );
                      }).toList(),
                    ),
                  ],

                  // Description
                  if (document.description != null && document.description!.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    const Text(
                      'Deskripsi Dokumen',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Text(
                        document.description!,
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.45,
                          color: AppColors.onSurface.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 18),
                  const Text(
                    'Informasi Berkas',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Metadata list
                  _buildMetaTile(
                    Icons.attach_file_rounded,
                    'Nama Berkas',
                    document.originalName ?? '${document.title}.${document.fileExtension ?? "pdf"}',
                  ),
                  if (document.fileSizeFormatted != null)
                    _buildMetaTile(
                      Icons.sd_storage_outlined,
                      'Ukuran Berkas',
                      document.fileSizeFormatted!,
                    ),
                  if (document.publishedDate != null)
                    _buildMetaTile(
                      Icons.event_outlined,
                      'Tanggal Diterbitkan',
                      document.publishedDate!,
                    ),
                  if (document.createdByName != null)
                    _buildMetaTile(
                      Icons.person_outline_rounded,
                      'Dibuat / Diunggah Oleh',
                      document.createdByName!,
                    ),
                ],
              ),
            ),
          ),

          // Footer action buttons
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: OutlinedButton.icon(
                    onPressed: onShare,
                    icon: const Icon(Icons.share_outlined, size: 18),
                    label: const Text('Bagikan'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF475569),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: ElevatedButton.icon(
                    onPressed: onDownload,
                    icon: const Icon(Icons.file_download_outlined, size: 20),
                    label: const Text('Unduh Berkas'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPill(String label, Color bg, Color text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: text),
      ),
    );
  }

  Widget _buildMetaTile(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
