enum AdminTab { dashboard, missing, found, users }

class MonthlyData {
  final String label;
  final String rangeText;
  final int missingCount;
  final int foundCount;
  final int totalCount;
  final List<Map<String, dynamic>> missing;
  final List<Map<String, dynamic>> found;

  const MonthlyData({
    required this.label,
    required this.rangeText,
    required this.missingCount,
    required this.foundCount,
    required this.totalCount,
    required this.missing,
    required this.found,
  });

  factory MonthlyData.empty() {
    return const MonthlyData(
      label: 'Last Month',
      rangeText: '',
      missingCount: 0,
      foundCount: 0,
      totalCount: 0,
      missing: [],
      found: [],
    );
  }
}
