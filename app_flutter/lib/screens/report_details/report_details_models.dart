class ReportDetailsData {
  final bool isMissing;
  final String reportId;
  final String title;
  final String subtitle;
  final String statusLabel;
  final String imageUrl;
  final String locationLabel;
  final String dateLabel;
  final String description;
  final String contactName;
  final String contactPhone;

  const ReportDetailsData({
    required this.isMissing,
    required this.reportId,
    required this.title,
    required this.subtitle,
    required this.statusLabel,
    required this.imageUrl,
    required this.locationLabel,
    required this.dateLabel,
    required this.description,
    required this.contactName,
    required this.contactPhone,
  });
}
