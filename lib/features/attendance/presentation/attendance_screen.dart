import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/artech_loading_widget.dart';
import '../../../core/widgets/artech_pull_to_refresh.dart';
import '../../../core/widgets/live_clock_widget.dart';
import '../../requests/presentation/izin_screen.dart';
import '../data/attendance_service.dart';
import 'attendance_history_screen.dart';
import '../../notifications/presentation/notifications_screen.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  late Future<Map<String, dynamic>?> _todayFuture;
  late Future<Position> _positionFuture;
  late Future<Map<String, dynamic>?> _summaryFuture;
  late Future<List<dynamic>> _historyFuture;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('id_ID', null).then((_) {
      if (mounted) setState(() {});
    });
    _refreshData();
  }


  Future<File?> _takePhoto() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      imageQuality: 50,
      maxWidth: 1024,
      maxHeight: 1024,
    );
    if (image != null) {
      return File(image.path);
    }
    return null;
  }

  Future<void> _refreshData() async {
    setState(() {
      _todayFuture = AttendanceService.getToday();
      _positionFuture = Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.best);
      _summaryFuture = AttendanceService.getSummary();
      _historyFuture = AttendanceService.getHistory();
    });
    try {
      await Future.wait([
        _todayFuture,
        _summaryFuture,
        _historyFuture,
      ]);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: ArtechPullToRefresh(
        onRefresh: _refreshData,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildMiniHeader(context),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildInteractiveAttendanceCard(context),
                    const SizedBox(height: 16),
                    _buildCheckOutButton(context),
                    const SizedBox(height: 20),
                    _buildStatisticsSummary(context),
                    const SizedBox(height: 20),
                    _buildAttendanceCalendar(context),
                    const SizedBox(height: 20),
                    _buildAttendanceHistory(context),
                    const SizedBox(height: 20),
                    _buildQuickActions(context),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF091E47),
            Color(0xFF0037B0),
            Color(0xFF155DFC),
          ],
          stops: [0.0, 0.55, 1.0],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Stack(
        children: [
          // Ambient glow circle 1 (top-right)
          Positioned(
            top: -30,
            right: -20,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.07),
              ),
            ),
          ),
          // Ambient glow circle 2 (bottom-left)
          Positioned(
            bottom: -15,
            left: -15,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFE961D).withValues(alpha: 0.08),
              ),
            ),
          ),
          // Content
          Padding(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 16,
              left: 20,
              right: 20,
              bottom: 24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Kehadiran',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.22),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color(0xFF10B981),
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Text(
                                'Live Presensi',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.22),
                          width: 1,
                        ),
                      ),
                      child: IconButton(
                        icon: const Badge(
                          backgroundColor: Color(0xFFEF4444),
                          smallSize: 8,
                          child: Icon(Icons.notifications_none_rounded, color: Colors.white, size: 20),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                          );
                        },
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Kelola presensi, riwayat kehadiran, dan jadwal kerja',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.78),
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInteractiveAttendanceCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF091E47).withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.secondaryContainer.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.secondary, shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Flexible(child: Text('Sudah Presensi Masuk', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.secondary), overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.calendar_today, size: 14, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text(DateFormat('EEEE, dd MMM yyyy', 'id_ID').format(DateTime.now()), style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppColors.onSurfaceVariant)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          LiveClockWidget(
            timeStyle: Theme.of(context).textTheme.displayLarge?.copyWith(fontWeight: FontWeight.bold, color: AppColors.onSurface),
            amPmStyle: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.primary),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.verified, size: 14, color: AppColors.secondary),
              const SizedBox(width: 6),
              Flexible(child: Text('Shift Normal: 08:30 - 17:30 WIB', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.onSurfaceVariant), overflow: TextOverflow.ellipsis)),
            ],
          ),
          const SizedBox(height: 24),
          FutureBuilder<Map<String, dynamic>?>(
            future: _todayFuture,
            builder: (context, snapshot) {
              final String checkIn = (snapshot.data?['check_in'] as String?) ?? '--:--';
              final String checkOut = (snapshot.data?['check_out'] as String?) ?? '--:--';
              
              final String checkInTime = checkIn != '--:--' && checkIn.length >= 5 ? checkIn.substring(0, 5) : checkIn;
              final String checkOutTime = checkOut != '--:--' && checkOut.length >= 5 ? checkOut.substring(0, 5) : checkOut;

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.outlineVariant.withOpacity(0.5)),
                ),
                child: Row(
                  children: [
                    Expanded(child: _buildAttendanceMetric(context, 'Jam Masuk', checkInTime, checkInTime != '--:--' ? 'Tercatat' : 'Belum Masuk', AppColors.primary, AppColors.secondary)),
                    Container(width: 1, height: 40, color: AppColors.outlineVariant.withOpacity(0.5)),
                    Expanded(child: _buildAttendanceMetric(context, 'Jam Pulang', checkOutTime, checkOutTime != '--:--' ? 'Selesai' : 'Belum Checkout', AppColors.onSurfaceVariant, AppColors.outline)),
                    Container(width: 1, height: 40, color: AppColors.outlineVariant.withOpacity(0.5)),
                    Expanded(child: _buildAttendanceMetric(context, 'Durasi Kerja', '-', '-', AppColors.onSurface, AppColors.secondary, isDuration: true)),
                  ],
                ),
              );
            }
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.outlineVariant.withOpacity(0.5)),
            ),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.location_on, color: AppColors.primary, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Mesin Indonesia(PT Arqom Technology Innovation)', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 2),
                          Text('Yogyakarta, Indonesia', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.onSurfaceVariant), overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: AppColors.secondaryContainer.withOpacity(0.5), borderRadius: BorderRadius.circular(16)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.radar, size: 12, color: AppColors.secondary),
                          const SizedBox(width: 4),
                          Text('Valid', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.secondary, fontSize: 10)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  height: 150,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainer,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.outlineVariant.withOpacity(0.5)),
                  ),
                  child: Stack(
                    children: [
                      FutureBuilder<Position>(
                        future: _positionFuture,
                        builder: (context, snapshot) {
                          final LatLng officeLocation = const LatLng(-7.832365, 110.373963);
                          List<Marker> markers = [
                            Marker(
                              point: officeLocation,
                              width: 40,
                              height: 40,
                              child: const Icon(Icons.business, color: AppColors.primary, size: 40),
                            ),
                          ];

                          if (snapshot.hasData) {
                            markers.add(
                              Marker(
                                point: LatLng(snapshot.data!.latitude, snapshot.data!.longitude),
                                width: 40,
                                height: 40,
                                child: const Icon(Icons.person_pin_circle, color: AppColors.error, size: 40),
                              ),
                            );
                          }

                          return FlutterMap(
                            options: MapOptions(
                              initialCenter: officeLocation,
                              initialZoom: 16.5,
                            ),
                            children: [
                              TileLayer(
                                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                userAgentPackageName: 'com.arqom.mobile',
                              ),
                              CircleLayer(
                                circles: [
                                  CircleMarker(
                                    point: officeLocation,
                                    radius: 100, // Radius absensi 100 meter
                                    useRadiusInMeter: true,
                                    color: AppColors.primary.withValues(alpha: 0.15),
                                    borderColor: AppColors.primary,
                                    borderStrokeWidth: 2,
                                  ),
                                ],
                              ),
                              MarkerLayer(markers: markers),
                            ],
                          );
                        }
                      ),
                      Positioned(
                        bottom: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.95), borderRadius: BorderRadius.circular(6)),
                          child: Row(
                            children: [
                              const Icon(Icons.my_location, size: 12, color: AppColors.secondary),
                              const SizedBox(width: 4),
                              Text('Radius Absensi: 100 meter', style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 10, color: AppColors.onSurface)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceMetric(BuildContext context, String label, String value, String status, Color valueColor, Color statusColor, {bool isDuration = false}) {
    return Column(
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.onSurfaceVariant), overflow: TextOverflow.ellipsis),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Flexible(child: Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: valueColor, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
            if (!isDuration) ...[
              const SizedBox(width: 2),
              Text('WIB', style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 10, fontWeight: FontWeight.normal, color: valueColor)),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Text(status, style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 10, color: statusColor), overflow: TextOverflow.ellipsis),
      ],
    );
  }

  Widget _buildCheckOutButton(BuildContext context) {
    bool isCheckoutTime = DateTime.now().hour >= 17;

    return Column(
      children: [
        Container(
          width: double.infinity,
          height: 64,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isCheckoutTime 
                ? [AppColors.error, Colors.red[400]!]
                : [Colors.grey[400]!, Colors.grey[300]!],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: isCheckoutTime ? [
              BoxShadow(color: AppColors.error.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 4)),
            ] : [],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: isCheckoutTime ? () async {
                File? photo = await _takePhoto();
                if (photo == null) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Foto selfie wajib diambil untuk absen pulang.'), backgroundColor: AppColors.error));
                  }
                  return;
                }
                
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Memproses presensi pulang...')),
                  );
                }
                
                try {
                  Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.best);
                  final result = await AttendanceService.checkOut(
                    position.latitude.toString(),
                    position.longitude.toString(),
                    photo, // Wajib lampirkan foto
                  );
                  
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(result['message'])),
                    );
                    if (result['success']) {
                      _refreshData(); // Refresh UI setelah absen pulang
                    }
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Gagal mendapatkan lokasi. Pastikan GPS menyala.')),
                    );
                  }
                }
              } : () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Belum waktunya pulang. Absen pulang baru bisa dilakukan setelah jam 17:00.')),
                );
              },
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                            child: const Icon(Icons.logout, color: Colors.white, size: 26),
                          ),
                          const SizedBox(width: 16),
                          Flexible(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Presensi Pulang Kerja', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 2),
                                Text('Tap untuk presensi pulang', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white70), overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                      child: const Icon(Icons.east, color: Colors.white, size: 20),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Ketuk tombol di atas untuk memproses presensi pulang',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, String subtitle, {VoidCallback? onTapAction, String? actionLabel}) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
              Text(subtitle, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.onSurfaceVariant, fontSize: 10)),
            ],
          ),
        ),
        if (onTapAction != null && actionLabel != null)
          GestureDetector(
            onTap: onTapAction,
            child: Text(actionLabel, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
          ),
      ],
    );
  }

  Widget _buildStatisticsSummary(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(context, 'Ringkasan Presensi', 'Bulan Ini'),
        const SizedBox(height: 16),
        FutureBuilder<Map<String, dynamic>?>(
          future: _summaryFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: ArtechLoadingWidget(size: 54, showHalo: false)),
              );
            }
            final summaryData = snapshot.data?['summary'] ?? {'present': 0, 'late': 0, 'leave': 0, 'absent': 0};
            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.1,
              children: [
                _buildStatCard(context, 'Tepat Waktu', '${summaryData['present'] ?? 0}', Icons.check_circle, AppColors.secondary, AppColors.secondaryContainer.withOpacity(0.4)),
                _buildStatCard(context, 'Terlambat', '${summaryData['late'] ?? 0}', Icons.schedule, Colors.orange[700]!, Colors.orange[100]!),
                _buildStatCard(context, 'Cuti / Izin', '${summaryData['leave'] ?? 0}', Icons.beach_access, AppColors.primary, AppColors.primaryContainer.withOpacity(0.5)),
                _buildStatCard(context, 'Sakit', '0', Icons.medication, AppColors.onSurfaceVariant, AppColors.surfaceContainerHigh),
                _buildStatCard(context, 'Dinas', '0', Icons.flight_takeoff, AppColors.tertiary, AppColors.tertiaryContainer.withOpacity(0.5)),
                _buildStatCard(context, 'Alpha', '${summaryData['absent'] ?? 0}', Icons.cancel, AppColors.onSurfaceVariant, AppColors.surfaceContainerHigh),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildStatCard(BuildContext context, String label, String value, IconData icon, Color iconColor, Color iconBg) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 10, color: AppColors.onSurfaceVariant), overflow: TextOverflow.ellipsis)),
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
                child: Icon(icon, size: 14, color: iconColor),
              ),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(color: iconColor, fontWeight: FontWeight.bold)),
              const SizedBox(width: 4),
              Text('Hari', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.onSurfaceVariant, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceCalendar(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(context, 'Kalender Presensi', 'Minggu Ini'),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.outlineVariant.withOpacity(0.5)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _buildLegendItem(context, AppColors.secondary, 'Hadir'),
                  const SizedBox(width: 12),
                  _buildLegendItem(context, Colors.orange, 'Late'),
                  const SizedBox(width: 12),
                  _buildLegendItem(context, AppColors.primary, 'Cuti'),
                  const SizedBox(width: 12),
                  _buildLegendItem(context, AppColors.error, 'Alfa'),
                ],
              ),
              const SizedBox(height: 16),
              FutureBuilder<Map<String, dynamic>?>(
                future: _summaryFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 18),
                      child: Center(child: ArtechLoadingWidget(size: 48, showHalo: false)),
                    );
                  }
                  final calendarData = snapshot.data?['calendar'] as List<dynamic>? ?? [];
                  if (calendarData.isEmpty) {
                    return const Text("Belum ada data riwayat presensi.");
                  }
                  
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: () {
                      DateTime now = DateTime.now();
                      int currentWeekday = now.weekday; // 1 = Mon, 7 = Sun
                      DateTime startOfWeek = now.subtract(Duration(days: currentWeekday - 1));
                      
                      List<Widget> dayWidgets = [];
                      List<String> dayNames = ['SEN', 'SEL', 'RAB', 'KAM', 'JUM', 'SAB', 'MIN'];

                      for (int i = 0; i < 7; i++) {
                        DateTime currentDate = startOfWeek.add(Duration(days: i));
                        String dateString = "${currentDate.year}-${currentDate.month.toString().padLeft(2, '0')}-${currentDate.day.toString().padLeft(2, '0')}";
                        
                        // Cari apakah API mengirimkan data untuk tanggal ini
                        var dayData;
                        for (var item in calendarData) {
                          if (item['date'] != null && item['date'].toString().startsWith(dateString)) {
                            dayData = item;
                            break;
                          }
                        }

                        Color dotColor = Colors.transparent;
                        Color bgColor = AppColors.surfaceContainerLowest;
                        bool isToday = (currentDate.year == now.year && currentDate.month == now.month && currentDate.day == now.day);
                        bool isWeekend = (i == 5 || i == 6);
                        double opacity = isWeekend ? 0.4 : 1.0;
                        
                        if (isToday) {
                          bgColor = AppColors.primary;
                        }

                        if (dayData != null) {
                          String status = dayData['status'] ?? 'None';
                          if (status.toLowerCase() == 'hadir' || status.toLowerCase() == 'on_time') {
                            dotColor = AppColors.secondary;
                          } else if (status.toLowerCase() == 'late') {
                            dotColor = Colors.orange;
                          } else if (status.toLowerCase() == 'cuti' || status.toLowerCase() == 'leave') {
                            dotColor = AppColors.primary;
                          }
                          
                          String colorCode = dayData['color_code'] ?? '';
                          if (colorCode.toLowerCase() == 'green') dotColor = AppColors.secondary;
                          else if (colorCode.toLowerCase() == 'orange') dotColor = Colors.orange;
                          else if (colorCode.toLowerCase() == 'blue') dotColor = AppColors.primary;
                          else if (colorCode.toLowerCase() == 'red') dotColor = AppColors.error;
                          
                          // Jika hari ini, dot biru (cuti) akan nabrak background biru, kita ubah dot jadi putih
                          if (isToday && dotColor == AppColors.primary) {
                            dotColor = Colors.white;
                          }
                        }

                        // Menggunakan Expanded dan SizedBox(width:4) agar bentuknya sama persis seperti hardcode sebelumnya
                        dayWidgets.add(
                          Expanded(
                            child: _buildCalendarDay(
                              context, 
                              dayNames[i], 
                              currentDate.day.toString(), 
                              dotColor, 
                              bgColor, 
                              isToday: isToday,
                              isWeekend: isWeekend,
                              opacity: (isToday && dayData == null) ? 1.0 : opacity,
                            ),
                          )
                        );

                        if (i < 6) {
                          dayWidgets.add(const SizedBox(width: 4));
                        }
                      }
                      return dayWidgets;
                    }(),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLegendItem(BuildContext context, Color color, String label) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 10, color: AppColors.onSurfaceVariant)),
      ],
    );
  }

  Widget _buildCalendarDay(BuildContext context, String day, String date, Color dotColor, Color bgColor, {bool isToday = false, bool isWeekend = false, double opacity = 1.0}) {
    return Opacity(
      opacity: opacity,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: isToday ? null : Border.all(color: AppColors.outlineVariant.withOpacity(0.5)),
        ),
        child: Column(
          children: [
            Text(day, style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 10, color: isToday ? Colors.white70 : (isWeekend ? AppColors.error : AppColors.onSurfaceVariant))),
            const SizedBox(height: 4),
            Text(date, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: isToday ? Colors.white : AppColors.onSurface, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Container(width: 6, height: 6, decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceHistory(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          context, 
          'Riwayat Presensi', 
          'Aktivitas terbaru', 
          actionLabel: 'Lihat Semua', 
          onTapAction: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const AttendanceHistoryScreen()));
          }
        ),
        const SizedBox(height: 16),
        FutureBuilder<List<dynamic>>(
          future: _historyFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: ArtechLoadingWidget(size: 56, message: 'Memuat riwayat...')),
              );
            } else if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.outlineVariant.withOpacity(0.5)),
                ),
                child: Center(
                  child: Text('Belum ada riwayat absensi', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.onSurfaceVariant)),
                ),
              );
            }

            final historyList = snapshot.data!;
            return Column(
              children: historyList.map((data) {
                final typeText = data['type'] == 'in' ? 'Masuk' : 'Pulang';
                final time = data['time'] ?? '--:--';
                final date = data['date'] ?? '--';
                final lat = data['latitude'] ?? '-';
                final lng = data['longitude'] ?? '-';
                final bool isLate = data['status'] == 'late';
                
                // Label teks pada kotak sebelah kanan (Masuk / Pulang / Terlambat)
                final String badgeLabel = isLate ? 'Terlambat' : typeText;
                // Warna ikon menyesuaikan status
                final Color iconColor = isLate ? Colors.orange[800]! : (data['type'] == 'in' ? AppColors.secondary : AppColors.primary);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildHistoryItem(
                    context, 
                    date, 
                    badgeLabel, 
                    '$time WIB • Lokasi: $lat, $lng', 
                    iconColor, 
                    data['type'] == 'in' ? Icons.login : Icons.logout,
                    isLate: isLate,
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildHistoryItem(BuildContext context, String date, String status, String desc, Color statusColor, IconData icon, {bool isLate = false}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: isLate ? Colors.orange[100] : AppColors.secondaryContainer.withOpacity(0.5), shape: BoxShape.circle),
            child: Icon(icon, color: statusColor, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(child: Text(date, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: isLate ? Colors.orange[100] : AppColors.secondaryContainer.withOpacity(0.5), borderRadius: BorderRadius.circular(16)),
                      child: Text(status, style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 10, color: isLate ? Colors.orange[800] : AppColors.secondary)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(desc, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(context, 'Aksi & Bantuan Cepat', 'Layanan Presensi'),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildActionItem(context, Icons.edit_calendar, 'Koreksi', AppColors.primary)),
            const SizedBox(width: 8),
            Expanded(
              child: _buildActionItem(
                context, 
                Icons.event_busy, 
                'Cuti/Izin', 
                AppColors.secondary,
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const IzinScreen()));
                },
              ),
            ),
            Expanded(
              child: _buildActionItem(
                context, 
                Icons.analytics, 
                'Rekap', 
                AppColors.tertiary,
                onTap: () => _handleExportCSV(context),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _handleExportCSV(BuildContext context) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Menyiapkan file laporan absensi...')),
    );
    
    final now = DateTime.now();
    final csvString = await AttendanceService.exportAttendanceCSV(now.month, now.year);
    
    if (csvString == null || !context.mounted) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal mengunduh laporan. Coba lagi nanti.'), backgroundColor: AppColors.error),
        );
      }
      return;
    }
    
    try {
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/Rekapan_Absensi_${now.month}_${now.year}.csv');
      await file.writeAsString(csvString);
      
      final xFile = XFile(file.path);
      await Share.shareXFiles([xFile], text: 'Laporan Absensi Bulan ${now.month} Tahun ${now.year}');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan atau membagikan file: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Widget _buildActionItem(BuildContext context, IconData icon, String label, Color iconColor, {VoidCallback? onTap}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant.withOpacity(0.5)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap ?? () {},
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: iconColor.withOpacity(0.1), shape: BoxShape.circle),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(height: 12),
                Text(
                  label, 
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold, fontSize: 10), 
                  textAlign: TextAlign.center, 
                  maxLines: 1, 
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
