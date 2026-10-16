import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/artech_loading_widget.dart';
import '../data/models/request_models.dart';
import '../data/requests_service.dart';
import 'widgets/request_error_dialog.dart';

class KerjaLemburScreen extends StatefulWidget {
  final RequestItem? existingItem;

  const KerjaLemburScreen({super.key, this.existingItem});

  @override
  State<KerjaLemburScreen> createState() => _KerjaLemburScreenState();
}

class _KerjaLemburScreenState extends State<KerjaLemburScreen> {
  final _formKey = GlobalKey<FormState>();

  final _startDateController = TextEditingController();
  final _endDateController = TextEditingController();
  final _startTimeController = TextEditingController();
  final _endTimeController = TextEditingController();
  final _descriptionController = TextEditingController();

  DateTime? _startDate;
  DateTime? _endDate;
  File? _attachmentFile;
  String? _selectedFileName;

  bool _isLoading = false;
  bool _loadingMeta = true;

  // Tipe Peserta: 'individu' | 'kelompok'
  String _tipePeserta = 'individu';
  List<EmployeeSimple> _availableEmployees = [];
  int? _selectedSingleEmployeeId;
  final Set<int> _selectedGroupEmployeeIds = {};

  @override
  void initState() {
    super.initState();
    _fetchMetaAndCheckAccess();
    if (widget.existingItem != null) {
      final item = widget.existingItem!;
      _startDateController.text = item.startDate;
      _startDate = DateTime.tryParse(item.startDate);

      if (item.endDate != null && item.endDate!.isNotEmpty) {
        _endDateController.text = item.endDate!;
        _endDate = DateTime.tryParse(item.endDate!);
      }

      _startTimeController.text = item.startTime ?? '';
      _endTimeController.text = item.endTime ?? '';
      _descriptionController.text = item.description;

      if (item.parsedDetails?.tipePeserta != null) {
        _tipePeserta = item.parsedDetails!.tipePeserta!;
      }

      if (item.parsedDetails?.pesertaIds.isNotEmpty == true) {
        if (_tipePeserta == 'kelompok' || item.parsedDetails!.pesertaIds.length > 1) {
          _tipePeserta = 'kelompok';
          _selectedGroupEmployeeIds.clear();
          _selectedGroupEmployeeIds.addAll(item.parsedDetails!.pesertaIds);
        } else {
          _tipePeserta = 'individu';
          _selectedSingleEmployeeId = item.parsedDetails!.pesertaIds.first;
        }
      }
    }
  }

  Future<void> _fetchMetaAndCheckAccess() async {
    final metaRes = await RequestsService.getRequestMeta();
    if (mounted) {
      if (metaRes.success && metaRes.data != null && !metaRes.data!.canUseElevatedTypes) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.gpp_bad_outlined, color: AppColors.error, size: 24),
                SizedBox(width: 8),
                Text('Akses Ditolak (403)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            content: const Text(
              'Pengajuan perjalanan dinas dan lembur hanya bisa diajukan oleh minimal level Head (Head, Lead, Manager, Direktur).',
              style: TextStyle(fontSize: 13),
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Kembali'),
              ),
            ],
          ),
        );
        return;
      }

      setState(() {
        _loadingMeta = false;
        if (metaRes.success && metaRes.data != null) {
          _availableEmployees = metaRes.data!.employees;
        }
      });
    }
  }

  @override
  void dispose() {
    _startDateController.dispose();
    _endDateController.dispose();
    _startTimeController.dispose();
    _endTimeController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  String _formatDateYmd(DateTime dt) {
    return "${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";
  }

  Future<void> _selectDate(BuildContext context, {required bool isStart}) async {
    final initialDate = isStart
        ? (_startDate ?? DateTime.now())
        : (_endDate ?? _startDate ?? DateTime.now());

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime.now().subtract(const Duration(days: 14)),
      lastDate: DateTime.now().add(const Duration(days: 60)),
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          _startDateController.text = _formatDateYmd(picked);
          if (_endDate != null && _endDate!.isBefore(picked)) {
            _endDate = picked;
            _endDateController.text = _formatDateYmd(picked);
          }
        } else {
          _endDate = picked;
          _endDateController.text = _formatDateYmd(picked);
        }
      });
    }
  }

  Future<void> _selectTime(BuildContext context, TextEditingController controller) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      final hours = picked.hour.toString().padLeft(2, '0');
      final minutes = picked.minute.toString().padLeft(2, '0');
      setState(() {
        controller.text = "$hours:$minutes";
      });
    }
  }

  String? _calculateDuration() {
    final startStr = _startTimeController.text.trim();
    final endStr = _endTimeController.text.trim();
    if (startStr.isEmpty || endStr.isEmpty) return null;

    try {
      final startParts = startStr.split(':');
      final endParts = endStr.split(':');
      if (startParts.length != 2 || endParts.length != 2) return null;

      final startMin = int.parse(startParts[0]) * 60 + int.parse(startParts[1]);
      final endMin = int.parse(endParts[0]) * 60 + int.parse(endParts[1]);

      if (endMin <= startMin) {
        return 'Jam selesai harus setelah jam mulai';
      }

      final diffMin = endMin - startMin;
      final hours = diffMin ~/ 60;
      final minutes = diffMin % 60;

      if (minutes == 0) {
        return '$hours Jam';
      } else {
        return '$hours Jam $minutes Menit';
      }
    } catch (_) {
      return null;
    }
  }

  void _showSingleEmployeeDropdownPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final filteredEmployees = _availableEmployees.where((emp) {
              final query = searchQuery.toLowerCase();
              return emp.name.toLowerCase().contains(query) ||
                  emp.division.toLowerCase().contains(query) ||
                  emp.position.toLowerCase().contains(query);
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Pilih Pegawai yang Lembur',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Cari nama atau divisi pegawai...',
                      hintStyle: const TextStyle(fontSize: 12),
                      prefixIcon: const Icon(Icons.search, size: 18),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onChanged: (val) {
                      setModalState(() {
                        searchQuery = val;
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  const Divider(),
                  Expanded(
                    child: filteredEmployees.isEmpty
                        ? const Center(
                            child: Text('Pegawai tidak ditemukan', style: TextStyle(fontSize: 12, color: AppColors.outline)),
                          )
                        : ListView.builder(
                            itemCount: filteredEmployees.length,
                            itemBuilder: (ctx, i) {
                              final emp = filteredEmployees[i];
                              final isSelected = _selectedSingleEmployeeId == emp.id;
                              return ListTile(
                                leading: CircleAvatar(
                                  radius: 16,
                                  backgroundColor: isSelected ? AppColors.primary : AppColors.primaryContainer.withValues(alpha: 0.5),
                                  child: Text(
                                    emp.name.isNotEmpty ? emp.name[0].toUpperCase() : '?',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected ? Colors.white : AppColors.primary,
                                    ),
                                  ),
                                ),
                                title: Text(emp.name, style: TextStyle(fontSize: 13, fontWeight: isSelected ? FontWeight.bold : FontWeight.w600)),
                                subtitle: Text(
                                  '${emp.position.isNotEmpty ? emp.position : "-"} • ${emp.division}',
                                  style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
                                ),
                                trailing: isSelected ? const Icon(Icons.check_circle, color: AppColors.primary) : null,
                                onTap: () {
                                  setState(() {
                                    _selectedSingleEmployeeId = emp.id;
                                  });
                                  Navigator.pop(ctx);
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showGroupEmployeeDropdownPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final filteredEmployees = _availableEmployees.where((emp) {
              final query = searchQuery.toLowerCase();
              return emp.name.toLowerCase().contains(query) ||
                  emp.division.toLowerCase().contains(query) ||
                  emp.position.toLowerCase().contains(query);
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Text(
                          'Pilih Anggota Tim Lembur',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${_selectedGroupEmployeeIds.length} dipilih',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Cari nama atau divisi pegawai...',
                      hintStyle: const TextStyle(fontSize: 12),
                      prefixIcon: const Icon(Icons.search, size: 18),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onChanged: (val) {
                      setModalState(() {
                        searchQuery = val;
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  const Divider(),
                  Expanded(
                    child: filteredEmployees.isEmpty
                        ? const Center(
                            child: Text('Pegawai tidak ditemukan', style: TextStyle(fontSize: 12, color: AppColors.outline)),
                          )
                        : ListView.builder(
                            itemCount: filteredEmployees.length,
                            itemBuilder: (ctx, i) {
                              final emp = filteredEmployees[i];
                              final isSelected = _selectedGroupEmployeeIds.contains(emp.id);
                              return CheckboxListTile(
                                value: isSelected,
                                activeColor: AppColors.primary,
                                title: Text(emp.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                subtitle: Text(
                                  '${emp.position.isNotEmpty ? emp.position : "-"} • ${emp.division}',
                                  style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
                                ),
                                onChanged: (checked) {
                                  setState(() {
                                    if (checked == true) {
                                      _selectedGroupEmployeeIds.add(emp.id);
                                    } else {
                                      _selectedGroupEmployeeIds.remove(emp.id);
                                    }
                                  });
                                  setModalState(() {});
                                },
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Simpan Pilihan', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;
    if (_startDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih tanggal pelaksanaan lembur')),
      );
      return;
    }

    if (_tipePeserta == 'individu') {
      if (_selectedSingleEmployeeId == null && _availableEmployees.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pilih pegawai yang ditugaskan lembur')),
        );
        return;
      }
    } else {
      if (_selectedGroupEmployeeIds.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pilih minimal 1 rekan kerja / anggota tim untuk lembur kelompok')),
        );
        return;
      }
    }

    // Validasi jam
    final startStr = _startTimeController.text.trim();
    final endStr = _endTimeController.text.trim();
    try {
      final s = startStr.split(':');
      final e = endStr.split(':');
      final sMin = int.parse(s[0]) * 60 + int.parse(s[1]);
      final eMin = int.parse(e[0]) * 60 + int.parse(e[1]);
      if (eMin <= sMin) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Jam selesai lembur harus setelah jam mulai')),
        );
        return;
      }
    } catch (_) {}

    setState(() => _isLoading = true);

    final isEdit = widget.existingItem != null;
    final startDateStr = _formatDateYmd(_startDate!);
    final endDateStr = _endDate != null ? _formatDateYmd(_endDate!) : startDateStr;
    final selectedIds = _tipePeserta == 'individu'
        ? (_selectedSingleEmployeeId != null ? [_selectedSingleEmployeeId!] : null)
        : _selectedGroupEmployeeIds.toList();

    final res = isEdit
        ? await RequestsService.updateRequest(
            id: widget.existingItem!.id,
            requestType: 'lembur',
            description: _descriptionController.text.trim(),
            startDate: startDateStr,
            endDate: endDateStr,
            startTime: startStr,
            endTime: endStr,
            tipePeserta: _tipePeserta,
            peserta: selectedIds,
            attachment: _attachmentFile,
          )
        : await RequestsService.createRequest(
            requestType: 'lembur',
            description: _descriptionController.text.trim(),
            startDate: startDateStr,
            endDate: endDateStr,
            startTime: startStr,
            endTime: endStr,
            tipePeserta: _tipePeserta,
            peserta: selectedIds,
            attachment: _attachmentFile,
          );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (res.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
    } else {
      handleRequestApiError(context, res);
    }
  }

  @override
  Widget build(BuildContext context) {
    final durationText = _calculateDuration();

    return ArtechLoadingWidget.overlay(
      isLoading: _isLoading,
      message: widget.existingItem != null ? 'Menyimpan perubahan lembur...' : 'Mengirim pengajuan lembur...',
      child: Scaffold(
        backgroundColor: AppColors.surfaceContainerLowest,
      appBar: AppBar(
        title: Text(
          widget.existingItem != null ? 'Edit Pengajuan Lembur' : 'Pengajuan Kerja Lembur',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.surfaceContainerLowest,
        scrolledUnderElevation: 0,
        centerTitle: true,
      ),
      body: _loadingMeta
          ? ArtechLoadingWidget.page(message: 'Memuat data lembur...')
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Info banner
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.indigo.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.indigo.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: Colors.indigo, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Pengajuan lembur hanya dapat dibuat oleh akun minimal level Head. Dapat diajukan untuk diri sendiri maupun tim.',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.indigo[900], fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Tipe Peserta Lembur (Individu vs Kelompok)
                    Text('Tipe Peserta Lembur *', style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildChoiceChip(
                            label: 'Individu',
                            isSelected: _tipePeserta == 'individu',
                            icon: Icons.person_rounded,
                            onTap: () => setState(() => _tipePeserta = 'individu'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildChoiceChip(
                            label: 'Tim / Kelompok',
                            isSelected: _tipePeserta == 'kelompok',
                            icon: Icons.groups_rounded,
                            onTap: () => setState(() => _tipePeserta = 'kelompok'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Pilihan Pegawai Lembur (Individu vs Kelompok)
                    Text(
                      _tipePeserta == 'individu' ? 'Pegawai yang Lembur *' : 'Anggota Tim yang Lembur *',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    if (_tipePeserta == 'individu') ...[
                      InkWell(
                        onTap: () => _showSingleEmployeeDropdownPicker(context),
                        borderRadius: BorderRadius.circular(12),
                        child: InputDecorator(
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: AppColors.surface,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.outlineVariant.withValues(alpha: 0.5))),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.outlineVariant.withValues(alpha: 0.5))),
                            suffixIcon: const Icon(Icons.arrow_drop_down, color: AppColors.onSurfaceVariant),
                          ),
                          child: Builder(
                            builder: (context) {
                              final selectedEmp = _availableEmployees
                                  .where((e) => e.id == _selectedSingleEmployeeId)
                                  .firstOrNull;
                              if (selectedEmp != null) {
                                return Text(
                                  '${selectedEmp.name} (${selectedEmp.position.isNotEmpty ? selectedEmp.position : selectedEmp.division})',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.onSurface),
                                  overflow: TextOverflow.ellipsis,
                                );
                              }
                              return const Text(
                                'Pilih pegawai dari daftar...',
                                style: TextStyle(fontSize: 12, color: AppColors.outline),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                    ] else ...[
                      InkWell(
                        onTap: () => _showGroupEmployeeDropdownPicker(context),
                        borderRadius: BorderRadius.circular(12),
                        child: InputDecorator(
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: AppColors.surface,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.outlineVariant.withValues(alpha: 0.5))),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.outlineVariant.withValues(alpha: 0.5))),
                            suffixIcon: const Icon(Icons.arrow_drop_down, color: AppColors.onSurfaceVariant),
                          ),
                          child: Text(
                            _selectedGroupEmployeeIds.isEmpty
                                ? 'Pilih anggota tim dari daftar...'
                                : '${_selectedGroupEmployeeIds.length} Pegawai Dipilih',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: _selectedGroupEmployeeIds.isNotEmpty ? FontWeight.w600 : FontWeight.normal,
                              color: _selectedGroupEmployeeIds.isNotEmpty ? AppColors.onSurface : AppColors.outline,
                            ),
                          ),
                        ),
                      ),
                      if (_selectedGroupEmployeeIds.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: _availableEmployees
                              .where((emp) => _selectedGroupEmployeeIds.contains(emp.id))
                              .map((emp) => Chip(
                                    backgroundColor: AppColors.primaryContainer.withValues(alpha: 0.3),
                                    label: Text(
                                      emp.name,
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                                    ),
                                    deleteIcon: const Icon(Icons.close, size: 14, color: AppColors.primary),
                                    onDeleted: () {
                                      setState(() => _selectedGroupEmployeeIds.remove(emp.id));
                                    },
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide.none),
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                  ))
                              .toList(),
                        ),
                      ],
                      const SizedBox(height: 18),
                    ],

                    // Tanggal Pelaksanaan
                    Row(
                      children: [
                        Expanded(
                          child: _buildDatePicker(
                            'Tanggal Lembur',
                            'Pilih tanggal',
                            _startDateController,
                            required: true,
                            onTap: () => _selectDate(context, isStart: true),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _buildDatePicker(
                            'Tanggal Berakhir',
                            'Opsional (sama jika 1 hari)',
                            _endDateController,
                            required: false,
                            onTap: () => _selectDate(context, isStart: false),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Jam Mulai & Jam Selesai
                    Row(
                      children: [
                        Expanded(
                          child: _buildTimePicker(
                            'Jam Mulai (HH:mm)',
                            'Contoh: 17:30',
                            _startTimeController,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _buildTimePicker(
                            'Jam Selesai (HH:mm)',
                            'Contoh: 21:00',
                            _endTimeController,
                          ),
                        ),
                      ],
                    ),
                    if (durationText != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: durationText.contains('harus setelah')
                              ? AppColors.errorContainer.withValues(alpha: 0.3)
                              : Colors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              durationText.contains('harus setelah') ? Icons.error_outline : Icons.timer_outlined,
                              size: 14,
                              color: durationText.contains('harus setelah') ? AppColors.error : Colors.green[800],
                            ),
                            const SizedBox(width: 6),
                            Text(
                              durationText.contains('harus setelah') ? durationText : 'Durasi: $durationText',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: durationText.contains('harus setelah') ? AppColors.error : Colors.green[800],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),

                    // Deskripsi Pekerjaan / Proyek Lembur
                    _buildInputField(
                      'Rincian Pekerjaan / Proyek Lembur',
                      'Contoh: Lembur tim IT untuk finalisasi rilis sprint modul pengajuan...',
                      _descriptionController,
                      maxLines: 4,
                      required: true,
                    ),
                    const SizedBox(height: 18),

                    // Lampiran Memo / Surat Tugas Lembur (Opsional)
                    Text(
                      'Lampiran Dokumen / Memo Tugas Lembur (Opsional)',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () async {
                        FilePickerResult? result = await FilePicker.pickFiles(
                          type: FileType.custom,
                          allowedExtensions: ['jpg', 'pdf', 'png'],
                        );

                        if (result != null && result.files.single.path != null) {
                          setState(() {
                            _selectedFileName = result.files.single.name;
                            _attachmentFile = File(result.files.single.path!);
                          });
                        }
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _selectedFileName != null ? Colors.green.withValues(alpha: 0.05) : AppColors.surface,
                          border: Border.all(
                            color: _selectedFileName != null ? Colors.green : AppColors.outlineVariant.withValues(alpha: 0.5),
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _selectedFileName != null ? Icons.check_circle : Icons.upload_file,
                              color: _selectedFileName != null ? Colors.green : AppColors.primary,
                              size: 26,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _selectedFileName ?? 'Unggah memo atau bukti penugasan',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: _selectedFileName != null ? Colors.green : AppColors.onSurface,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Format: PDF, JPG, PNG (Maks 2MB)',
                                    style: TextStyle(fontSize: 10, color: AppColors.onSurfaceVariant.withValues(alpha: 0.7)),
                                  ),
                                ],
                              ),
                            ),
                            if (_selectedFileName != null)
                              IconButton(
                                icon: const Icon(Icons.close, size: 18, color: AppColors.error),
                                onPressed: () {
                                  setState(() {
                                    _selectedFileName = null;
                                    _attachmentFile = null;
                                  });
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: _isLoading ? null : _submitRequest,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
          child: Text(
            widget.existingItem != null ? 'Simpan Perubahan' : 'Kirim Pengajuan Lembur',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    ),
    );
  }

  Widget _buildChoiceChip({
    required String label,
    required bool isSelected,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.outlineVariant.withValues(alpha: 0.5),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: isSelected ? Colors.white : AppColors.onSurfaceVariant),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : AppColors.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField(
    String label,
    String hint,
    TextEditingController controller, {
    int maxLines = 1,
    bool required = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold)),
            if (required)
              Text(' *', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppColors.error, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: AppColors.onSurfaceVariant.withValues(alpha: 0.5), fontSize: 12),
            filled: true,
            fillColor: AppColors.surface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.outlineVariant.withValues(alpha: 0.5))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.outlineVariant.withValues(alpha: 0.5))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary)),
          ),
          validator: required ? (value) => value == null || value.trim().isEmpty ? 'Wajib diisi' : null : null,
        ),
      ],
    );
  }

  Widget _buildDatePicker(
    String label,
    String hint,
    TextEditingController controller, {
    required bool required,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold)),
            if (required)
              Text(' *', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppColors.error, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          readOnly: true,
          onTap: onTap,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: AppColors.onSurfaceVariant.withValues(alpha: 0.5), fontSize: 11),
            suffixIcon: const Icon(Icons.calendar_month, color: AppColors.primary, size: 18),
            filled: true,
            fillColor: AppColors.surface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.outlineVariant.withValues(alpha: 0.5))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.outlineVariant.withValues(alpha: 0.5))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary)),
          ),
          validator: required ? (value) => value == null || value.isEmpty ? 'Wajib diisi' : null : null,
        ),
      ],
    );
  }

  Widget _buildTimePicker(
    String label,
    String hint,
    TextEditingController controller,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold)),
            Text(' *', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppColors.error, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          readOnly: true,
          onTap: () => _selectTime(context, controller),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: AppColors.onSurfaceVariant.withValues(alpha: 0.5), fontSize: 11),
            suffixIcon: const Icon(Icons.access_time, color: AppColors.primary, size: 18),
            filled: true,
            fillColor: AppColors.surface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.outlineVariant.withValues(alpha: 0.5))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.outlineVariant.withValues(alpha: 0.5))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary)),
          ),
          validator: (value) => value == null || value.isEmpty ? 'Wajib diisi' : null,
        ),
      ],
    );
  }
}
