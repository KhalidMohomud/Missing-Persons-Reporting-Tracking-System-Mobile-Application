enum AdminTab { dashboard, missing, found, tips, users }

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
      label: 'This Month',
      rangeText: '',
      missingCount: 0,
      foundCount: 0,
      totalCount: 0,
      missing: [],
      found: [],
    );
  }
}

class YearlyData {
  final String label;
  final String rangeText;
  final int missingCount;
  final int foundCount;
  final int totalCount;
  final List<Map<String, dynamic>> missing;
  final List<Map<String, dynamic>> found;

  const YearlyData({
    required this.label,
    required this.rangeText,
    required this.missingCount,
    required this.foundCount,
    required this.totalCount,
    required this.missing,
    required this.found,
  });

  factory YearlyData.empty() {
    return const YearlyData(
      label: 'This Year',
      rangeText: '',
      missingCount: 0,
      foundCount: 0,
      totalCount: 0,
      missing: [],
      found: [],
    );
  }
}
