import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/artech_loading_widget.dart';
import '../../../core/widgets/artech_pull_to_refresh.dart';
import '../data/models/notification_models.dart';
import '../data/notifications_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<NotificationItem> _notifications = [];
  int _unreadCount = 0;
  bool _filterUnreadOnly = false;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    final res = await NotificationsService.getNotifications(
      unreadOnly: _filterUnreadOnly ? true : null,
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (res.success && res.data != null) {
          _notifications = res.data!;
          _unreadCount = res.unreadCount ?? _notifications.where((n) => !n.isRead).length;
          NotificationsService.unreadCountNotifier.value = _unreadCount;
        } else {
          _errorMessage = res.message;
        }
      });
    }
  }

  Future<void> _markOneAsRead(NotificationItem item) async {
    if (!item.isRead) {
      setState(() {
        final index = _notifications.indexWhere((n) => n.id == item.id);
        if (index != -1) {
          _notifications[index] = _notifications[index].copyWith(isRead: true);
          if (_unreadCount > 0) _unreadCount--;
          NotificationsService.unreadCountNotifier.value = _unreadCount;
        }
      });
      await NotificationsService.markAsRead(item.id);
    }

    if (mounted && item.data != null) {
      _showNotificationDetail(item);
    }
  }

  Future<void> _markAllAsRead() async {
    if (_unreadCount == 0) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Tandai Semua Dibaca?'),
        content: const Text('Semua notifikasi yang belum dibaca akan ditandai sebagai telah dibaca.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Ya, Tandai Semua'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _notifications = _notifications.map((n) => n.copyWith(isRead: true)).toList();
        _unreadCount = 0;
        NotificationsService.unreadCountNotifier.value = 0;
      });
      final success = await NotificationsService.markAllAsRead();
      if (!success && mounted) {
        _fetchNotifications(silent: true);
      }
    }
  }

  Future<void> _sendTestPush() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Mengirim test push notification ke server...')),
    );

    final res = await NotificationsService.testPush(
      title: 'Uji Coba Push Notification Central Portal',
      body: 'Pengajuan Anda telah diverifikasi oleh atasan!',
    );

    if (!mounted) return;

    if (res.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message),
          backgroundColor: Colors.green,
        ),
      );
      _fetchNotifications(silent: true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _showNotificationDetail(NotificationItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
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
              const SizedBox(height: 18),
              Row(
                children: [
                  _buildTypeIcon(item.type, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.timeAgo,
                          style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  item.body,
                  style: const TextStyle(fontSize: 13, height: 1.4),
                ),
              ),
              if (item.data != null) ...[
                const SizedBox(height: 16),
                const Text(
                  'Rincian Pengajuan',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.outline),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.5)),
                  ),
                  child: Column(
                    children: [
                      if (item.data?.requestNumber != null)
                        _buildDetailRow('No. Pengajuan', item.data!.requestNumber!),
                      if (item.data?.requestType != null)
                        _buildDetailRow('Jenis', item.data!.requestType!.toUpperCase()),
                      if (item.data?.decision != null)
                        _buildDetailRow('Keputusan', item.data!.decision!),
                      if (item.data?.reviewer != null)
                        _buildDetailRow('Reviewer', item.data!.reviewer!),
                      if (item.data?.note != null && item.data!.note!.isNotEmpty)
                        _buildDetailRow('Catatan', item.data!.note!),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Tutup'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
            ),
          ),
          const Text(': ', style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant)),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeIcon(String type, {double size = 20}) {
    Color color;
    IconData icon;
    final lower = type.toLowerCase();

    if (lower.contains('approved') || lower.contains('setuju')) {
      color = const Color(0xFF10B981);
      icon = Icons.check_circle_rounded;
    } else if (lower.contains('rejected') || lower.contains('tolak')) {
      color = AppColors.error;
      icon = Icons.cancel_rounded;
    } else if (lower.contains('pending') || lower.contains('tunggu')) {
      color = Colors.amber.shade800;
      icon = Icons.schedule_rounded;
    } else {
      color = AppColors.primary;
      icon = Icons.notifications_rounded;
    }

    return Container(
      width: size + 16,
      height: size + 16,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: size),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: ArtechPullToRefresh(
        onRefresh: () => _fetchNotifications(silent: true),
        refreshingText: 'Memperbarui notifikasi...',
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(context),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildFilterTabs(),
                    const SizedBox(height: 14),
                    _buildContentList(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
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
          Padding(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 12,
              left: 16,
              right: 16,
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
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                          onPressed: () => Navigator.pop(context),
                          visualDensity: VisualDensity.compact,
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'Notifikasi',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        if (_unreadCount > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$_unreadCount baru',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    PopupMenuButton<String>(
                      icon: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.14),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
                        ),
                        child: const Icon(Icons.more_vert_rounded, color: Colors.white, size: 18),
                      ),
                      onSelected: (val) {
                        if (val == 'mark_all') {
                          _markAllAsRead();
                        } else if (val == 'test_push') {
                          _sendTestPush();
                        }
                      },
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(
                          value: 'mark_all',
                          child: Row(
                            children: [
                              Icon(Icons.done_all_rounded, size: 18, color: AppColors.primary),
                              SizedBox(width: 8),
                              Text('Tandai Semua Dibaca'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'test_push',
                          child: Row(
                            children: [
                              Icon(Icons.send_rounded, size: 18, color: Colors.orange),
                              SizedBox(width: 8),
                              Text('Kirim Test Push Notification'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text(
                    'Pembaruan status pengajuan, kehadiran, dan aktivitas akun',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.78),
                      fontSize: 12,
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

  Widget _buildFilterTabs() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (_filterUnreadOnly) {
                  setState(() => _filterUnreadOnly = false);
                  _fetchNotifications();
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: !_filterUnreadOnly ? AppColors.surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: !_filterUnreadOnly
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    'Semua (${_notifications.length})',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: !_filterUnreadOnly ? FontWeight.bold : FontWeight.w500,
                      color: !_filterUnreadOnly ? AppColors.primary : AppColors.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (!_filterUnreadOnly) {
                  setState(() => _filterUnreadOnly = true);
                  _fetchNotifications();
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: _filterUnreadOnly ? AppColors.surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: _filterUnreadOnly
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    'Belum Dibaca ($_unreadCount)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: _filterUnreadOnly ? FontWeight.bold : FontWeight.w500,
                      color: _filterUnreadOnly ? AppColors.primary : AppColors.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentList() {
    if (_isLoading) {
      return ArtechLoadingWidget.page(
        message: 'Memuat notifikasi...',
      );
    }

    if (_errorMessage != null && _notifications.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.4)),
        ),
        child: Column(
          children: [
            const Icon(Icons.cloud_off_rounded, size: 40, color: AppColors.error),
            const SizedBox(height: 10),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: AppColors.error),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => _fetchNotifications(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      );
    }

    final items = _filterUnreadOnly
        ? _notifications.where((n) => !n.isRead).toList()
        : _notifications;

    if (items.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.4)),
        ),
        child: Column(
          children: [
            const Icon(Icons.notifications_none_rounded, size: 48, color: AppColors.outline),
            const SizedBox(height: 10),
            Text(
              _filterUnreadOnly ? 'Semua Notifikasi Telah Dibaca' : 'Belum Ada Notifikasi',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              _filterUnreadOnly
                  ? 'Tidak ada pesan notifikasi baru saat ini.'
                  : 'Pemberitahuan terkait pengajuan dan aktivitas Anda akan muncul di sini.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    return Column(
      children: items.map((item) => _buildNotificationCard(item)).toList(),
    );
  }

  Widget _buildNotificationCard(NotificationItem item) {
    return GestureDetector(
      onTap: () => _markOneAsRead(item),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: item.isRead ? AppColors.surface : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: item.isRead
                ? const Color(0xFFE2E8F0)
                : AppColors.primary.withValues(alpha: 0.35),
            width: item.isRead ? 1 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: item.isRead
                  ? Colors.black.withValues(alpha: 0.02)
                  : AppColors.primary.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTypeIcon(item.type, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: item.isRead ? FontWeight.w600 : FontWeight.bold,
                              color: AppColors.onSurface,
                            ),
                          ),
                        ),
                        if (!item.isRead) ...[
                          const SizedBox(width: 6),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.body,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: item.isRead ? AppColors.onSurfaceVariant : const Color(0xFF334155),
                        height: 1.35,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          item.timeAgo,
                          style: const TextStyle(fontSize: 10, color: AppColors.outline),
                        ),
                        if (item.data?.decision != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: item.data!.decision!.toLowerCase().contains('setuju')
                                  ? const Color(0xFF10B981).withValues(alpha: 0.12)
                                  : AppColors.error.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              item.data!.decision!,
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: item.data!.decision!.toLowerCase().contains('setuju')
                                    ? const Color(0xFF10B981)
                                    : AppColors.error,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
