import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/artech_loading_widget.dart';
import '../../../core/widgets/artech_pull_to_refresh.dart';
import '../data/agenda_service.dart';
import '../data/models/agenda_models.dart';
import 'widgets/agenda_card.dart';

class AgendaListScreen extends StatefulWidget {
  const AgendaListScreen({super.key});

  @override
  State<AgendaListScreen> createState() => _AgendaListScreenState();
}

class _AgendaListScreenState extends State<AgendaListScreen> {
  final List<String> _types = [
    'Semua',
    'Meeting',
    'Libur',
    'Agenda Lainnya',
    'Deadline',
  ];

  String _selectedType = 'Semua';
  DateTime _fromDate = DateTime.now();
  late DateTime _toDate;

  List<AgendaItem> _agendas = [];
  bool _isLoading = true;
  String? _errorMessage;
  int _currentPage = 1;
  AgendaPaginationMeta? _meta;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    // Default 3 bulan ke depan sesuai spesifikasi 6.2
    _toDate = DateTime(_fromDate.year, _fromDate.month + 3, _fromDate.day);
    _fetchAgendas();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchAgendas({bool silent = false, int page = 1}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    final fromStr = DateFormat('yyyy-MM-dd').format(_fromDate);
    final toStr = DateFormat('yyyy-MM-dd').format(_toDate);
    final typeParam = _selectedType == 'Semua' ? null : _selectedType;

    final res = await AgendaService.getAgendas(
      from: fromStr,
      to: toStr,
      type: typeParam,
      page: page,
      perPage: 30,
      forceRefresh: silent,
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (res.success) {
        if (page == 1) {
          _agendas = res.items;
        } else {
          _agendas.addAll(res.items);
        }
        _meta = res.meta;
        _currentPage = page;
        _errorMessage = null;
      } else {
        _errorMessage = res.message;
      }
    });
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
      initialDateRange: DateTimeRange(start: _fromDate, end: _toDate),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF0037B0),
              onPrimary: Colors.white,
              onSurface: Color(0xFF0F172A),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _fromDate = picked.start;
        _toDate = picked.end;
      });
      _fetchAgendas();
    }
  }

  List<AgendaItem> get _filteredAgendas {
    if (_searchQuery.trim().isEmpty) return _agendas;
    final q = _searchQuery.toLowerCase().trim();
    return _agendas.where((a) {
      final titleMatch = a.title.toLowerCase().contains(q);
      final descMatch = a.description?.toLowerCase().contains(q) ?? false;
      final locMatch = a.location?.toLowerCase().contains(q) ?? false;
      final picMatch = a.pic?.toLowerCase().contains(q) ?? false;
      return titleMatch || descMatch || locMatch || picMatch;
    }).toList();
  }

  String _formatDt(DateTime dt) {
    try {
      return DateFormat('d MMM yyyy', 'id_ID').format(dt);
    } catch (_) {
      try {
        return DateFormat('d MMM yyyy').format(dt);
      } catch (_) {
        return '${dt.day}/${dt.month}/${dt.year}';
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredAgendas;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Agenda Perusahaan',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0F172A),
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18,
            color: Color(0xFF0F172A),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.date_range_rounded,
              size: 20,
              color: Color(0xFF0037B0),
            ),
            tooltip: 'Filter Rentang Tanggal',
            onPressed: _pickDateRange,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search & Filter Bar
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            color: Colors.white,
            child: Column(
              children: [
                // Search Input
                Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val;
                      });
                    },
                    style: GoogleFonts.plusJakartaSans(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Cari agenda, lokasi, atau PIC...',
                      hintStyle: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: const Color(0xFF94A3B8),
                      ),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        size: 18,
                        color: Color(0xFF94A3B8),
                      ),
                      suffixIcon:
                          _searchQuery.isNotEmpty
                              ? IconButton(
                                icon: const Icon(
                                  Icons.clear_rounded,
                                  size: 16,
                                  color: Color(0xFF94A3B8),
                                ),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {
                                    _searchQuery = '';
                                  });
                                },
                              )
                              : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Type Filter Chips (Horizontal Scroll)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children:
                        _types.map((type) {
                          final isSelected = _selectedType == type;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(type),
                              selected: isSelected,
                              onSelected: (selected) {
                                if (selected) {
                                  setState(() {
                                    _selectedType = type;
                                  });
                                  _fetchAgendas();
                                }
                              },
                              labelStyle: GoogleFonts.plusJakartaSans(
                                fontSize: 11.5,
                                fontWeight:
                                    isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w600,
                                color:
                                    isSelected
                                        ? Colors.white
                                        : const Color(0xFF475569),
                              ),
                              selectedColor: const Color(0xFF0037B0),
                              backgroundColor: const Color(0xFFF1F5F9),
                              side: BorderSide(
                                color:
                                    isSelected
                                        ? const Color(0xFF0037B0)
                                        : const Color(0xFFE2E8F0),
                                width: 1,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              visualDensity: VisualDensity.compact,
                            ),
                          );
                        }).toList(),
                  ),
                ),
              ],
            ),
          ),

          // Date Range Info Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              border: Border(
                bottom: BorderSide(color: Color(0xFFE2E8F0), width: 0.8),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_month_rounded,
                      size: 13,
                      color: Color(0xFF64748B),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${DateFormat('d MMM yyyy', 'id_ID').format(_fromDate)} - ${DateFormat('d MMM yyyy', 'id_ID').format(_toDate)}${_meta != null ? ' (${_meta!.total} agenda)' : ''}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: _pickDateRange,
                  child: Text(
                    'Ubah Rentang',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0037B0),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Main List Content
          Expanded(child: _buildListContent(filtered)),
        ],
      ),
    );
  }

  Widget _buildListContent(List<AgendaItem> filtered) {
    if (_isLoading) {
      return Center(
        child: ArtechLoadingWidget.page(message: 'Memuat agenda perusahaan...'),
      );
    }

    if (_errorMessage != null && _agendas.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                size: 48,
                color: AppColors.error,
              ),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: AppColors.error,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => _fetchAgendas(),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Coba Lagi'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (filtered.isEmpty) {
      return ArtechPullToRefresh(
        onRefresh: () => _fetchAgendas(silent: true),
        refreshingText: 'Memperbarui agenda...',
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(32),
          children: [
            const SizedBox(height: 60),
            Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF0037B0).withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.event_available_rounded,
                  size: 48,
                  color: Color(0xFF0037B0),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Center(
              child: Text(
                _searchQuery.isNotEmpty
                    ? 'Tidak ada agenda yang cocok'
                    : 'Belum ada agenda pada rentang waktu ini',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Center(
              child: Text(
                _searchQuery.isNotEmpty
                    ? 'Coba ubah kata kunci pencarian atau ganti filter kategori.'
                    : 'Agenda perusahaan yang Anda ikuti akan muncul secara otomatis di sini.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: const Color(0xFF64748B),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return ArtechPullToRefresh(
      onRefresh: () => _fetchAgendas(silent: true),
      refreshingText: 'Memperbarui agenda...',
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final item = filtered[index];
          return AgendaCard(
            item: item,
            onRefreshNeeded: () => _fetchAgendas(silent: true),
          );
        },
      ),
    );
  }
}
