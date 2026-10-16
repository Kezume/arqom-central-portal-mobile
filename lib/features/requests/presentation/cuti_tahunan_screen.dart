import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/artech_loading_widget.dart';
import '../data/models/request_models.dart';
import '../data/requests_service.dart';
import 'widgets/request_error_dialog.dart';

class CutiTahunanScreen extends StatefulWidget {
  final RequestItem? existingItem;

  const CutiTahunanScreen({super.key, this.existingItem});

  @override
  State<CutiTahunanScreen> createState() => _CutiTahunanScreenState();
}

class _CutiTahunanScreenState extends State<CutiTahunanScreen> {
  final _formKey = GlobalKey<FormState>();
  final _startDateController = TextEditingController();
  final _endDateController = TextEditingController();
  final _reasonController = TextEditingController();
  final _delegationController = TextEditingController();

  DateTime? _startDate;
  DateTime? _endDate;
  bool _isLoading = false;

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
      _reasonController.text = item.description;
    }
  }

  @override
  void dispose() {
    _startDateController.dispose();
    _endDateController.dispose();
    _reasonController.dispose();
    _delegationController.dispose();
    super.dispose();
  }

  String _formatDateYmd(DateTime dt) {
    return "${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;
    if (_startDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih tanggal mulai cuti')),
      );
      return;
    }

    setState(() => _isLoading = true);

    String fullDesc = _reasonController.text.trim();
    if (_delegationController.text.trim().isNotEmpty) {
      fullDesc += ' (Delegasi: ${_delegationController.text.trim()})';
    }

    final isEdit = widget.existingItem != null;
    final res = isEdit
        ? await RequestsService.updateRequest(
            id: widget.existingItem!.id,
            requestType: 'cuti',
            description: fullDesc,
            startDate: _formatDateYmd(_startDate!),
            endDate: _endDate != null ? _formatDateYmd(_endDate!) : null,
          )
        : await RequestsService.createRequest(
            requestType: 'cuti',
            description: fullDesc,
            startDate: _formatDateYmd(_startDate!),
            endDate: _endDate != null ? _formatDateYmd(_endDate!) : null,
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
          widget.existingItem != null ? 'Edit Pengajuan Cuti' : 'Pengajuan Cuti Tahunan',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.surfaceContainerLowest,
        scrolledUnderElevation: 0,
        centerTitle: true,
      ),
      body: ArtechLoadingWidget.overlay(
        isLoading: _isLoading,
        message: widget.existingItem != null ? 'Menyimpan perubahan cuti...' : 'Mengirim pengajuan cuti...',
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildInputField(
                  'Alasan Cuti',
                  'Berikan penjelasan singkat mengenai cuti',
                  _reasonController,
                  maxLines: 3,
                ),
                const SizedBox(height: 20),
                _buildInputField(
                  'Pendelegasian Tugas (Opsional)',
                  'Nama rekan kerja yang mem-backup pekerjaan',
                  _delegationController,
                  required: false,
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
                    widget.existingItem != null ? 'Simpan Perubahan' : 'Kirim Pengajuan',
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
            hintStyle: TextStyle(color: AppColors.onSurfaceVariant.withValues(alpha: 0.5)),
            filled: true,
            fillColor: AppColors.surface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
}
