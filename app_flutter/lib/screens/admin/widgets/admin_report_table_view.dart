import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../admin_theme.dart';
import '../admin_utils.dart';

class AdminReportTableView extends StatefulWidget {
  final List<Map<String, dynamic>> missingReports;
  final List<Map<String, dynamic>> foundReports;
  final String? error;
  final String Function(Map<String, dynamic>) reporterNameFor;

  const AdminReportTableView({
    super.key,
    required this.missingReports,
    required this.foundReports,
    required this.error,
    required this.reporterNameFor,
  });

  @override
  State<AdminReportTableView> createState() => _AdminReportTableViewState();
}

class _AdminReportTableViewState extends State<AdminReportTableView> {
  String _reportType = 'missing';

  bool get _isMissing => _reportType == 'missing';

  List<Map<String, dynamic>> get _reports =>
      _isMissing ? widget.missingReports : widget.foundReports;

  @override
  Widget build(BuildContext context) {
    final title = _isMissing ? 'Missing Reports' : 'Found Reports';

    return ListView(
      key: const ValueKey('report-table'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        if (widget.error != null) ...[
          _ErrorBanner(message: widget.error!),
          const SizedBox(height: 12),
        ],
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _reportType,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Report type',
                        filled: true,
                        fillColor: AdminTheme.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'missing',
                          child: Text('Missing reports'),
                        ),
                        DropdownMenuItem(
                          value: 'found',
                          child: Text('Found reports'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _reportType = value);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton.filledTonal(
                    onPressed: _reports.isEmpty ? null : _printPdf,
                    icon: const Icon(Icons.print_outlined),
                    tooltip: 'Print PDF',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '$title (${_reports.length})',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 10),
              if (_reports.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: Text(
                    _isMissing
                        ? 'No missing reports available.'
                        : 'No found reports available.',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                )
              else
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: WidgetStatePropertyAll(
                      AdminTheme.primaryBlue.withValues(alpha: 0.08),
                    ),
                    columnSpacing: 22,
                    columns: _columns(),
                    rows: _reports
                        .asMap()
                        .entries
                        .map((entry) => _row(entry.key + 1, entry.value))
                        .toList(),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  List<DataColumn> _columns() {
    final labels = _isMissing
        ? [
            '#',
            'Name',
            'Age',
            'Gender',
            'Location',
            'Date',
            'Status',
            'Verification',
            'Reporter',
            'Contact',
          ]
        : ['#', 'Location', 'Age', 'Gender', 'Date', 'Reporter', 'Description'];

    return labels
        .map(
          (label) => DataColumn(
            label: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        )
        .toList();
  }

  DataRow _row(int index, Map<String, dynamic> report) {
    final cells = _isMissing
        ? [
            index.toString(),
            AdminUtils.safeString(report['fullName'], 'Unknown'),
            AdminUtils.formatAge(report['age']),
            AdminUtils.safeString(report['gender'], 'Unknown'),
            AdminUtils.safeString(report['lastSeenLocation'], 'Unknown'),
            AdminUtils.safeString(report['lastSeenDate']),
            AdminUtils.statusLabel(
              AdminUtils.normalizedStatus(report['status']),
            ),
            AdminUtils.verificationStatusLabel(
              AdminUtils.normalizedVerificationStatus(
                report['verificationStatus'],
              ),
            ),
            widget.reporterNameFor(report),
            [
              AdminUtils.safeString(report['contactName']),
              AdminUtils.safeString(report['contactPhone']),
            ].where((value) => value.isNotEmpty).join(' - '),
          ]
        : [
            index.toString(),
            AdminUtils.safeString(report['locationFound'], 'Unknown'),
            AdminUtils.formatAge(report['estimatedAge']),
            AdminUtils.safeString(report['gender'], 'Unknown'),
            AdminUtils.formatDate(report['createdAt']),
            widget.reporterNameFor(report),
            AdminUtils.safeString(report['description']),
          ];

    return DataRow(
      cells: cells
          .map(
            (value) => DataCell(
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 180),
                child: Text(
                  value.isEmpty ? '-' : value,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Future<void> _printPdf() async {
    final doc = pw.Document();
    final title = _isMissing ? 'Missing Reports' : 'Found Reports';
    final headers = _isMissing
        ? [
            '#',
            'Name',
            'Age',
            'Gender',
            'Location',
            'Date',
            'Status',
            'Verification',
            'Reporter',
            'Contact',
          ]
        : ['#', 'Location', 'Age', 'Gender', 'Date', 'Reporter', 'Description'];

    final data = _reports
        .asMap()
        .entries
        .map((entry) => _pdfRow(entry.key + 1, entry.value))
        .toList();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          pw.Text(
            title,
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            'Generated ${DateTime.now().toLocal()}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 14),
          pw.Table.fromTextArray(
            headers: headers,
            data: data,
            headerStyle: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            headerDecoration: const pw.BoxDecoration(
              color: PdfColors.blueGrey800,
            ),
            cellStyle: const pw.TextStyle(fontSize: 8),
            cellAlignment: pw.Alignment.centerLeft,
            headerAlignment: pw.Alignment.centerLeft,
            cellPadding: const pw.EdgeInsets.all(5),
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      name: '${_reportType}_reports.pdf',
      onLayout: (_) => doc.save(),
    );
  }

  List<String> _pdfRow(int index, Map<String, dynamic> report) {
    if (_isMissing) {
      return [
        index.toString(),
        AdminUtils.safeString(report['fullName'], 'Unknown'),
        AdminUtils.formatAge(report['age']),
        AdminUtils.safeString(report['gender'], 'Unknown'),
        AdminUtils.safeString(report['lastSeenLocation'], 'Unknown'),
        AdminUtils.safeString(report['lastSeenDate']),
        AdminUtils.statusLabel(AdminUtils.normalizedStatus(report['status'])),
        AdminUtils.verificationStatusLabel(
          AdminUtils.normalizedVerificationStatus(report['verificationStatus']),
        ),
        widget.reporterNameFor(report),
        [
          AdminUtils.safeString(report['contactName']),
          AdminUtils.safeString(report['contactPhone']),
        ].where((value) => value.isNotEmpty).join(' - '),
      ];
    }

    return [
      index.toString(),
      AdminUtils.safeString(report['locationFound'], 'Unknown'),
      AdminUtils.formatAge(report['estimatedAge']),
      AdminUtils.safeString(report['gender'], 'Unknown'),
      AdminUtils.formatDate(report['createdAt']),
      widget.reporterNameFor(report),
      AdminUtils.safeString(report['description']),
    ];
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;

  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        message,
        style: TextStyle(fontSize: 12, color: Colors.red.shade700),
      ),
    );
  }
}
