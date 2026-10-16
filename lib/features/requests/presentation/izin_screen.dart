import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/artech_loading_widget.dart';
import '../data/models/request_models.dart';
import '../data/requests_service.dart';
import 'widgets/request_error_dialog.dart';

class IzinScreen extends StatefulWidget {
  final RequestItem? existingItem;

  const IzinScreen({super.key, this.existingItem});

  @override
  State<IzinScreen> createState() => _IzinScreenState();
}

class _IzinScreenState extends State<IzinScreen> {
  final _formKey = GlobalKey<FormState>();
  final _startDateController = TextEditingController();
  final _endDateController = TextEditingController();
  final _descriptionController = TextEditingController();

  File? _attachmentFile;
  String? _selectedFileName;
  bool _isLoading = false;

  DateTime? _startDate;
  DateTime? _endDate;

  final List<String> _quickReasonSuggestions = [
    'Keperluan Keluarga Mendesak',
    'Administrasi Kependudukan / SIM',
    'Acara Pernikahan / Wisuda Keluarga',
    'Urusan Pribadi Penting',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.existingItem != null) {
      final item = widget.existingItem!;
      _startDateController.text = item.startDate;
      _startDate = DateTime.tryParse(item.startDate);
      if (item.endDate != null && item.endDate!.isNotEmpty) {
        _endDateController.text = item.endDate!;
        _endDate = DateTime.tryParse(item.endDate!);
      }
      _descriptionController.text = item.description;
    }
  }

  @override
  void dispose() {
    _startDateController.dispose();
    _endDateController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  String _formatDateYmd(DateTime dt) {
    return "${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;
    if (_startDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih tanggal mulai izin')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final desc = _descriptionController.text.trim();
    final startDateStr = _formatDateYmd(_startDate!);
    final endDateStr = _endDate != null ? _formatDateYmd(_endDate!) : startDateStr;

    final isEdit = widget.existingItem != null;
    final res = isEdit
        ? await RequestsService.updateRequest(
            id: widget.existingItem!.id,
            requestType: 'izin',
            description: desc,
            startDate: startDateStr,
            endDate: endDateStr,
            attachment: _attachmentFile,
          )
        : await RequestsService.createRequest(
            requestType: 'izin',
            description: desc,
            startDate: startDateStr,
            endDate: endDateStr,
            attachment: _attachmentFile,
            useDedicatedEndpoint: true,
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
    return Scaffold(
      backgroundColor: AppColors.surfaceContainerLowest,
      appBar: AppBar(
        title: Text(
          widget.existingItem != null ? 'Edit Pengajuan Tidak Masuk (Izin)' : 'Pengajuan Tidak Masuk (Izin)',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.surfaceContainerLowest,
        scrolledUnderElevation: 0,
        centerTitle: true,
      ),
      body: ArtechLoadingWidget.overlay(
        isLoading: _isLoading,
        message: widget.existingItem != null ? 'Menyimpan perubahan izin...' : 'Mengirim pengajuan izin...',
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Info banner keselarasan absensi & pengajuan
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange.shade800, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Informasi Pengajuan Izin',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange.shade900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Gunakan formulir ini jika berhalangan hadir karena keperluan pribadi, keluarga, atau administrasi kependudukan. Presensi harian otomatis berstatus "Izin" setelah pengajuan disetujui sepenuhnya oleh HCGA.',
                            style: TextStyle(fontSize: 11.5, color: Colors.orange.shade800, height: 1.35),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: _buildDatePicker(
                      'Tanggal Mulai',
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
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildDatePicker(
                      'Tanggal Selesai',
                      'Pilih tanggal',
                      _endDateController,
                      firstDate: _startDate,
                      onPicked: (dt) => _endDate = dt,
                      required: false,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Alasan / Keperluan Izin',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        ' *',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppColors.error, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: _quickReasonSuggestions.map((suggestion) {
                      return InkWell(
                        onTap: () {
                          setState(() {
                            if (_descriptionController.text.trim().isEmpty) {
                              _descriptionController.text = suggestion;
                            } else {
                              _descriptionController.text = '${_descriptionController.text.trim()} - $suggestion';
                            }
                          });
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.orange.shade200),
                          ),
                          child: Text(
                            '+ $suggestion',
                            style: TextStyle(fontSize: 10.5, color: Colors.orange.shade900, fontWeight: FontWeight.w600),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _descriptionController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Jelaskan alasan izin secara jelas dan lengkap (contoh: keperluan administrasi perpanjangan SIM di luar kota)',
                      hintStyle: TextStyle(color: AppColors.onSurfaceVariant.withValues(alpha: 0.5), fontSize: 12.5),
                      filled: true,
                      fillColor: AppColors.surface,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.outlineVariant.withValues(alpha: 0.5))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.outlineVariant.withValues(alpha: 0.5))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary)),
                    ),
                    validator: (val) => val == null || val.trim().isEmpty ? 'Alasan izin wajib diisi' : null,
                  ),
                ],
              ),
              const SizedBox(height: 20),

              Text(
                'Dokumen Pendukung (Opsional)',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              InkWell(
                onTap: () async {
                  FilePickerResult? result = await FilePicker.pickFiles(
                    type: FileType.custom,
                    allowedExtensions: ['jpg', 'pdf', 'png', 'webp', 'jpeg'],
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
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _selectedFileName != null ? AppColors.secondary.withValues(alpha: 0.05) : AppColors.surface,
                    border: Border.all(
                      color: _selectedFileName != null ? AppColors.secondary : AppColors.outlineVariant.withValues(alpha: 0.5),
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        _selectedFileName != null ? Icons.check_circle : Icons.upload_file,
                        color: _selectedFileName != null ? Colors.green : AppColors.secondary,
                        size: 32,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _selectedFileName ?? 'Ketuk untuk mengunggah dokumen pendukung (Maks 2MB)',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: _selectedFileName != null ? Colors.green : AppColors.secondary,
                              fontWeight: FontWeight.bold,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Format didukung: PDF, JPG, PNG',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

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
                  widget.existingItem != null ? 'Simpan Perubahan' : 'Kirim Pengajuan Izin',
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


  Widget _buildDatePicker(
    String label,
    String hint,
    TextEditingController controller, {
    DateTime? firstDate,
    required Function(DateTime) onPicked,
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
          readOnly: true,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: AppColors.onSurfaceVariant.withValues(alpha: 0.5)),
            suffixIcon: const Icon(Icons.calendar_month, color: AppColors.primary),
            filled: true,
            fillColor: AppColors.surface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.outlineVariant.withValues(alpha: 0.5))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.outlineVariant.withValues(alpha: 0.5))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary)),
          ),
          onTap: () async {
            final pickedDate = await showDatePicker(
              context: context,
              initialDate: firstDate ?? DateTime.now(),
              firstDate: firstDate ?? DateTime.now().subtract(const Duration(days: 30)),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (pickedDate != null) {
              setState(() {
                controller.text = _formatDateYmd(pickedDate);
                onPicked(pickedDate);
              });
            }
          },
          validator: required ? (value) => value == null || value.isEmpty ? 'Wajib diisi' : null : null,
        ),
      ],
    );
  }
}
