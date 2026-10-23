import 'package:central_portal_mobile/features/performance/data/models/performance_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DailyTask API contract', () {
    test('parses due_at and user-owned kanban columns from data.meta', () {
      final result = DailyTaskListData.fromJson({
        'tasks': [
          {
            'id': 301,
            'weekly_plan_item_id': 101,
            'monthly_target_id': 89,
            'kanban_column_id': 7,
            'title': 'Finalisasi endpoint mobile',
            'work_date': '2026-10-24',
            'due_at': '2026-10-24 16:30:00',
            'execution_status': 'in_progress',
            'progress_percent': 50,
          },
        ],
        'meta': {
          'kanban_columns': [
            {'id': 7, 'name': 'Sabtu', 'position': 6},
            {'id': 8, 'name': 'Minggu', 'position': 7},
          ],
        },
      });

      expect(result.tasks, hasLength(1));
      expect(result.tasks.single.effectiveDate, '2026-10-24');
      expect(result.tasks.single.isMonthlyTargetTask, isTrue);
      expect(
        result.tasks.single.dueAtForDate('2026-10-25'),
        '2026-10-25 16:30:00',
      );
      expect(result.kanbanColumns.map((column) => column.name), [
        'Sabtu',
        'Minggu',
      ]);
      expect(result.ownsKanbanColumn(7), isTrue);
      expect(result.ownsKanbanColumn(99), isFalse);
    });

    test('keeps compatibility with a legacy list response', () {
      final result = DailyTaskListData.fromJson([
        {
          'id': '11',
          'title': 'Task lama',
          'date': '2026-10-20',
          'status': 'not_started',
        },
      ]);

      expect(result.tasks.single.id, 11);
      expect(result.tasks.single.effectiveDate, '2026-10-20');
      expect(
        result.tasks.single.dueAtForDate('2026-10-21'),
        '2026-10-21',
      );
      expect(result.kanbanColumns, isEmpty);
    });
  });
}
