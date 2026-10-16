import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/artech_loading_widget.dart';
import '../../../core/widgets/artech_pull_to_refresh.dart';
import '../../auth/presentation/login_screen.dart';
import '../../auth/data/auth_service.dart';
import '../../notifications/presentation/notifications_screen.dart';
import '../../notifications/data/notifications_service.dart';
import '../../sop/presentation/sop_list_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _userData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    NotificationsService.refreshUnreadCount();
  }

  Future<void> _loadUserData() async {
    final data = await AuthService.getUserData();
    if (mounted) {
      setState(() {
        _userData = data;
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshData() async {
    await Future.wait([
      _loadUserData(),
      NotificationsService.refreshUnreadCount(),
      Future.delayed(const Duration(milliseconds: 600)),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: _isLoading 
          ? const ArtechLoadingWidget.fullScreen(size: 80, message: 'Memuat profil...')
          : ArtechPullToRefresh(
              onRefresh: _refreshData,
              refreshingText: 'Memperbarui profil...',
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                  _buildProfileHeader(context),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildSectionTitle(context, 'Akun & Keamanan'),
                        const SizedBox(height: 10),
                        _buildMenuCard(
                          children: [
                            _buildMenuItem(context, Icons.lock_outline, 'Ubah Kata Sandi', onTap: () {}),
                            _buildDivider(),
                            _buildMenuItem(
                              context,
                              Icons.fingerprint,
                              'Autentikasi Biometrik',
                              trailing: Switch(
                                value: true,
                                onChanged: (v) {},
                                activeColor: AppColors.primary,
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _buildSectionTitle(context, 'Pengaturan Aplikasi'),
                        const SizedBox(height: 10),
                        _buildMenuCard(
                          children: [
                            _buildMenuItem(
                              context,
                              Icons.notifications_none,
                              'Notifikasi',
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                                );
                              },
                            ),
                            _buildDivider(),
                            _buildMenuItem(
                              context,
                              Icons.language,
                              'Bahasa',
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('Indonesia', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.chevron_right, color: AppColors.outline, size: 18),
                                ],
                              ),
                              onTap: () {},
                            ),
                            _buildDivider(),
                            _buildMenuItem(
                              context,
                              Icons.dark_mode_outlined,
                              'Mode Gelap',
                              trailing: Switch(
                                value: false,
                                onChanged: (v) {},
                                activeColor: AppColors.primary,
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _buildSectionTitle(context, 'Bantuan & Info'),
                        const SizedBox(height: 10),
                        _buildMenuCard(
                          children: [
                            _buildMenuItem(
                              context,
                              Icons.menu_book_outlined,
                              'SOP & Dokumen Resmi',
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => const SopListScreen()),
                                );
                              },
                            ),
                            _buildDivider(),
                            _buildMenuItem(context, Icons.help_outline, 'Pusat Bantuan', onTap: () {}),
                            _buildDivider(),
                            _buildMenuItem(context, Icons.description_outlined, 'Syarat & Ketentuan', onTap: () {}),
                            _buildDivider(),
                            _buildMenuItem(context, Icons.info_outline, 'Versi Aplikasi', trailing: Text('1.0.0', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.onSurfaceVariant))),
                          ],
                        ),
                        const SizedBox(height: 24),
                        OutlinedButton.icon(
                          onPressed: () async {
                            await AuthService.logout();
                            if (context.mounted) {
                              Navigator.of(context).pushAndRemoveUntil(
                                MaterialPageRoute(builder: (_) => const LoginScreen()),
                                (route) => false,
                              );
                            }
                          },
                          icon: const Icon(Icons.logout, size: 18),
                          label: const Text('Keluar dari Akun'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.error,
                            side: const BorderSide(color: AppColors.error),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  static String _extractStr(dynamic val, {String fallback = ''}) {
    if (val == null) return fallback;
    if (val is String) {
      final s = val.trim();
      return s.isEmpty ? fallback : s;
    }
    if (val is Map) {
      final possible = val['name'] ?? val['title'] ?? val['label'];
      if (possible != null) {
        final s = possible.toString().trim();
        if (s.isNotEmpty) return s;
      }
      return fallback;
    }
    final s = val.toString().trim();
    return s.isEmpty ? fallback : s;
  }

  Widget _buildProfileHeader(BuildContext context) {
    final rawName = _userData?['employee']?['name'] ?? _userData?['name'];
    final name = _extractStr(rawName, fallback: 'Pengguna');
    final rawRole = _userData?['employee']?['position'] ??
        _userData?['position'] ??
        _userData?['role'];
    final role = _extractStr(rawRole, fallback: 'Staff');
    final identifier = _extractStr(_userData?['email'] ?? _userData?['nik'], fallback: '-');
    final rawPhoto = _userData?['profile_photo_url'] ??
        _userData?['employee']?['profile_photo_url'];
    final photoUrl = (rawPhoto is String && rawPhoto.isNotEmpty)
        ? rawPhoto
        : 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(name)}&background=0037b0&color=fff';

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
              children: [
                // Title bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text(
                      'Profil',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.22),
                          width: 1,
                        ),
                      ),
                      child: ValueListenableBuilder<int>(
                        valueListenable: NotificationsService.unreadCountNotifier,
                        builder: (context, unreadCount, _) {
                          const iconWidget = Icon(
                            Icons.notifications_none_rounded,
                            color: Colors.white,
                            size: 21,
                          );

                          return IconButton(
                            padding: EdgeInsets.zero,
                            icon: unreadCount > 0
                                ? const Badge(
                                    backgroundColor: Color(0xFFEF4444),
                                    smallSize: 8,
                                    child: iconWidget,
                                  )
                                : iconWidget,
                            onPressed: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                              );
                              NotificationsService.refreshUnreadCount();
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                // Avatar + info row
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.45),
                          width: 2.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.16),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 30,
                        backgroundImage: NetworkImage(photoUrl),
                        backgroundColor: Colors.white24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            role,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                                const Icon(Icons.email_outlined, size: 12, color: Colors.white70),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    identifier,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.onSurface,
          ),
    );
  }

  Widget _buildMenuCard({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF091E47).withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context,
    IconData icon,
    String title, {
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              if (trailing != null)
                trailing
              else if (onTap != null)
                const Icon(Icons.chevron_right, color: AppColors.outline, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      color: AppColors.outlineVariant.withValues(alpha: 0.3),
      indent: 64, // Menyesuaikan dengan ikon menu
    );
  }
}
