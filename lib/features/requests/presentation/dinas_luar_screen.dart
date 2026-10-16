import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/artech_loading_widget.dart';
import '../data/models/request_models.dart';
import '../data/requests_service.dart';
import 'widgets/request_error_dialog.dart';

class DinasLuarScreen extends StatefulWidget {
  final RequestItem? existingItem;

  const DinasLuarScreen({super.key, this.existingItem});

  @override
  State<DinasLuarScreen> createState() => _DinasLuarScreenState();
}

class _DinasLuarScreenState extends State<DinasLuarScreen> {
  final _formKey = GlobalKey<FormState>();
  final _locationController = TextEditingController();
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

  // Metadata form options aligned with web portal
  String _tipeWaktu = 'harian'; // 'harian' | 'menginap'
  String _tipePeserta = 'individu'; // 'individu' | 'kelompok'
  List<EmployeeSimple> _availableEmployees = [];
  bool _loadingMeta = true;

  int? _selectedSingleEmployeeId;
  final Set<int> _selectedGroupEmployeeIds = {};

  @override
  void initState() {
    super.initState();
    _fetchMeta();
    if (widget.existingItem != null) {
      final item = widget.existingItem!;
      _locationController.text = item.location ?? '';
      _startDateController.text = item.startDate;
      _startDate = DateTime.tryParse(item.startDate);
      if (item.endDate != null && item.endDate!.isNotEmpty) {
        _endDateController.text = item.endDate!;
        _endDate = DateTime.tryParse(item.endDate!);
      }
      _startTimeController.text = item.startTime ?? '';
      _endTimeController.text = item.endTime ?? '';
      _descriptionController.text = item.description;
      if (item.parsedDetails?.tipeWaktu != null) {
        _tipeWaktu = item.parsedDetails!.tipeWaktu!;
      }
      if (item.parsedDetails?.tipePeserta != null) {
        _tipePeserta = item.parsedDetails!.tipePeserta!;
      }
      if (item.parsedDetails?.pesertaIds.isNotEmpty == true) {
        _selectedGroupEmployeeIds.clear();
        _selectedGroupEmployeeIds.addAll(item.parsedDetails!.pesertaIds);
        _selectedSingleEmployeeId = item.parsedDetails!.pesertaIds.first;
      }
    }
  }

  Future<void> _fetchMeta() async {
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
              'Pengajuan Perjalanan Dinas hanya dapat dibuat oleh akun minimal level Head (Head, Lead, Manager, Direktur).',
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
          if (_availableEmployees.isNotEmpty && widget.existingItem == null) {
            _selectedSingleEmployeeId = _availableEmployees.first.id;
            _selectedGroupEmployeeIds.add(_availableEmployees.first.id);
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _locationController.dispose();
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

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;
    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tanggal mulai dan selesai perjalanan dinas wajib diisi')),
      );
      return;
    }

    final selectedIds = <int>[];
    if (_tipePeserta == 'individu') {
      if (_selectedSingleEmployeeId != null) {
        selectedIds.add(_selectedSingleEmployeeId!);
      }
    } else {
      selectedIds.addAll(_selectedGroupEmployeeIds);
    }

    if (selectedIds.isEmpty && _availableEmployees.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih minimal satu pegawai peserta dinas')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final isEdit = widget.existingItem != null;
    final res = isEdit
        ? await RequestsService.updateRequest(
            id: widget.existingItem!.id,
            requestType: 'perjalanan_dinas',
            description: _descriptionController.text.trim(),
            startDate: _formatDateYmd(_startDate!),
            endDate: _formatDateYmd(_endDate!),
            startTime: _startTimeController.text.trim().isNotEmpty ? _startTimeController.text.trim() : null,
            endTime: _endTimeController.text.trim().isNotEmpty ? _endTimeController.text.trim() : null,
            location: _locationController.text.trim(),
            tipeWaktu: _tipeWaktu,
            tipePeserta: _tipePeserta,
            peserta: selectedIds.isNotEmpty ? selectedIds : null,
            attachment: _attachmentFile,
          )
        : await RequestsService.createRequest(
            requestType: 'perjalanan_dinas',
            description: _descriptionController.text.trim(),
            startDate: _formatDateYmd(_startDate!),
            endDate: _formatDateYmd(_endDate!),
            startTime: _startTimeController.text.trim().isNotEmpty ? _startTimeController.text.trim() : null,
            endTime: _endTimeController.text.trim().isNotEmpty ? _endTimeController.text.trim() : null,
            location: _locationController.text.trim(),
            tipeWaktu: _tipeWaktu,
            tipePeserta: _tipePeserta,
            peserta: selectedIds.isNotEmpty ? selectedIds : null,
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
                          'Pilih Pegawai Peserta Dinas',
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
                          'Pilih Anggota Tim Peserta Dinas',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceContainerLowest,
      appBar: AppBar(
        title: Text(
          widget.existingItem != null ? 'Edit Perjalanan Dinas' : 'Pengajuan Perjalanan Dinas',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.surfaceContainerLowest,
        scrolledUnderElevation: 0,
        centerTitle: true,
      ),
      body: ArtechLoadingWidget.overlay(
        isLoading: _isLoading,
        message: widget.existingItem != null ? 'Menyimpan perubahan dinas luar...' : 'Mengirim pengajuan dinas luar...',
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Notice banner
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.orange, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Perjalanan dinas memerlukan persetujuan berjenjang (Manager ➔ HCGA).',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.orange[800], fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Tipe Waktu (Harian / Menginap)
              Text('Tipe Waktu Dinas *', style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildChoiceChip(
                      label: 'Harian (PP)',
                      isSelected: _tipeWaktu == 'harian',
                      icon: Icons.today_rounded,
                      onTap: () => setState(() => _tipeWaktu = 'harian'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildChoiceChip(
                      label: 'Menginap',
                      isSelected: _tipeWaktu == 'menginap',
                      icon: Icons.hotel_rounded,
                      onTap: () => setState(() => _tipeWaktu = 'menginap'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Tipe Peserta (Individu / Kelompok)
              Text('Tipe Peserta *', style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold)),
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
                      label: 'Kelompok (Tim)',
                      isSelected: _tipePeserta == 'kelompok',
                      icon: Icons.groups_rounded,
                      onTap: () => setState(() => _tipePeserta = 'kelompok'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Peserta Selection (Dropdown)
              Text(
                _tipePeserta == 'individu' ? 'Pegawai yang Ditugaskan *' : 'Daftar Pegawai yang Ditugaskan *',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (_loadingMeta)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.5)),
                  ),
                  child: const Row(
                    children: [
                      ArtechLoadingWidget.small(size: 18),
                      SizedBox(width: 10),
                      Text('Memuat daftar pegawai...', style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant)),
                    ],
                  ),
                )
              else if (_availableEmployees.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.5)),
                  ),
                  child: const Text('Tidak ada data pegawai yang tersedia', style: TextStyle(fontSize: 12, color: AppColors.outline)),
                )
              else if (_tipePeserta == 'individu') ...[
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
              ] else ...[
                // Multi-select dropdown for Kelompok
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
              ],
              const SizedBox(height: 18),

              // Lokasi / Kota Tujuan
              _buildInputField(
                'Alamat / Kota Tujuan Dinas',
                'Contoh: Yogyakarta / Kantor Cabang Solo',
                _locationController,
              ),
              const SizedBox(height: 18),

              // Tanggal Mulai & Tanggal Selesai
              Row(
                children: [
                  Expanded(
                    child: _buildDatePicker(
                      'Tgl Keberangkatan',
                      'Pilih tanggal',
                      _startDateController,
                      onPicked: (dt) {
                        _startDate = dt;
                        if (_endDate != null && _endDate!.isBefore(dt)) {
                          _endDate = dt;
                          _endDateController.text = _formatDateYmd(dt);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _buildDatePicker(
                      'Tgl Kepulangan',
                      'Pilih tanggal',
                      _endDateController,
                      firstDate: _startDate,
                      onPicked: (dt) => _endDate = dt,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Jam Keberangkatan & Jam Kepulangan (Opsional)
              Row(
                children: [
                  Expanded(
                    child: _buildTimePicker('Jam Berangkat (Opsional)', _startTimeController),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _buildTimePicker('Jam Pulang (Opsional)', _endTimeController),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Deskripsi Keperluan
              _buildInputField(
                'Keperluan / Agenda Dinas',
                'Jelaskan agenda pertemuan atau tugas dinas luar',
                _descriptionController,
                maxLines: 3,
              ),
              const SizedBox(height: 18),

              // Lampiran
              Text(
                'Lampiran Bukti Tiket / Undangan (Opsional)',
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
                    color: _selectedFileName != null ? AppColors.primary.withValues(alpha: 0.05) : AppColors.surface,
                    border: Border.all(
                      color: _selectedFileName != null ? AppColors.primary : AppColors.outlineVariant.withValues(alpha: 0.5),
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _selectedFileName != null ? Icons.check_circle : Icons.upload_file,
                        color: AppColors.primary,
                        size: 24,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _selectedFileName ?? 'Unggah surat tugas / tiket (Maks 2MB)',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: _selectedFileName != null ? FontWeight.bold : FontWeight.normal,
                            color: _selectedFileName != null ? AppColors.primary : AppColors.onSurfaceVariant,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 30),

              ElevatedButton(
                onPressed: _isLoading ? null : _submitRequest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: Text(
                  widget.existingItem != null ? 'Simpan Perubahan' : 'Kirim Pengajuan Dinas',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
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
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.outlineVariant.withValues(alpha: 0.5),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: isSelected ? Colors.white : AppColors.onSurfaceVariant),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? Colors.white : AppColors.onSurface,
                ),
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
    DateTime? firstDate,
    required Function(DateTime) onPicked,
  }) {
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
          onTap: () async {
            final pickedDate = await showDatePicker(
              context: context,
              initialDate: firstDate ?? DateTime.now(),
              firstDate: firstDate ?? DateTime.now().subtract(const Duration(days: 7)),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (pickedDate != null) {
              setState(() {
                controller.text = _formatDateYmd(pickedDate);
                onPicked(pickedDate);
              });
            }
          },
          validator: (value) => value == null || value.isEmpty ? 'Wajib diisi' : null,
        ),
      ],
    );
  }

  Widget _buildTimePicker(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          readOnly: true,
          decoration: InputDecoration(
            hintText: 'HH:mm',
            hintStyle: TextStyle(color: AppColors.onSurfaceVariant.withValues(alpha: 0.5), fontSize: 11),
            suffixIcon: const Icon(Icons.access_time, color: AppColors.primary, size: 18),
            filled: true,
            fillColor: AppColors.surface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.outlineVariant.withValues(alpha: 0.5))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.outlineVariant.withValues(alpha: 0.5))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary)),
          ),
          onTap: () => _selectTime(context, controller),
        ),
      ],
    );
  }
}
