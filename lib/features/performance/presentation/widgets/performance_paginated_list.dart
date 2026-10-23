import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';

class PerformancePaginatedList<T> extends StatefulWidget {
  final List<T> items;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final Object? resetKey;
  final int pageSize;
  final double spacing;
  final String itemLabel;

  const PerformancePaginatedList({
    super.key,
    required this.items,
    required this.itemBuilder,
    this.resetKey,
    this.pageSize = 5,
    this.spacing = 10,
    this.itemLabel = 'item',
  }) : assert(pageSize > 0);

  @override
  State<PerformancePaginatedList<T>> createState() =>
      _PerformancePaginatedListState<T>();
}

class _PerformancePaginatedListState<T>
    extends State<PerformancePaginatedList<T>> {
  final GlobalKey _listTopKey = GlobalKey();
  int _currentPage = 0;

  int get _pageCount =>
      math.max(1, (widget.items.length / widget.pageSize).ceil());

  @override
  void didUpdateWidget(covariant PerformancePaginatedList<T> oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.resetKey != widget.resetKey) {
      _currentPage = 0;
      return;
    }

    if (_currentPage >= _pageCount) {
      _currentPage = _pageCount - 1;
    }
  }

  void _changePage(int page) {
    if (page < 0 || page >= _pageCount || page == _currentPage) return;
    setState(() => _currentPage = page);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final listContext = _listTopKey.currentContext;
      if (listContext == null) return;
      Scrollable.ensureVisible(
        listContext,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        alignment: 0.08,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();

    final start = _currentPage * widget.pageSize;
    final end = math.min(start + widget.pageSize, widget.items.length);
    final visibleItems = widget.items.sublist(start, end);

    return KeyedSubtree(
      key: _listTopKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = 0; index < visibleItems.length; index++) ...[
            widget.itemBuilder(context, visibleItems[index], start + index),
            if (index < visibleItems.length - 1)
              SizedBox(height: widget.spacing),
          ],
          if (_pageCount > 1) ...[
            const SizedBox(height: 14),
            _buildPaginationControls(start: start, end: end),
          ],
        ],
      ),
    );
  }

  Widget _buildPaginationControls({required int start, required int end}) {
    return Semantics(
      container: true,
      label: 'Navigasi halaman ${widget.itemLabel}',
      child: Row(
        children: [
          _PaginationButton(
            icon: Icons.chevron_left_rounded,
            tooltip: 'Halaman sebelumnya',
            onPressed:
                _currentPage > 0 ? () => _changePage(_currentPage - 1) : null,
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${start + 1}-$end dari ${widget.items.length} ${widget.itemLabel}',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF334155),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Halaman ${_currentPage + 1} dari $_pageCount',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          _PaginationButton(
            icon: Icons.chevron_right_rounded,
            tooltip: 'Halaman berikutnya',
            onPressed:
                _currentPage < _pageCount - 1
                    ? () => _changePage(_currentPage + 1)
                    : null,
          ),
        ],
      ),
    );
  }
}

class _PaginationButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  const _PaginationButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: Icon(icon, size: 22),
      color: AppColors.primary,
      disabledColor: const Color(0xFFCBD5E1),
      style: IconButton.styleFrom(
        minimumSize: const Size(44, 44),
        side: BorderSide(
          color:
              onPressed == null
                  ? const Color(0xFFE2E8F0)
                  : AppColors.primary.withValues(alpha: 0.28),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
