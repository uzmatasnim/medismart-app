// lib/screens/reports/reports_screen.dart
// UC-11 + UC-17: View Adherence Report + Export PDF/CSV

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:medismart/models/medication_model.dart';
import 'package:medismart/models/adherence_event_model.dart';
import 'package:medismart/services/medication_service.dart';
import 'package:medismart/services/adherence_service.dart';
import 'package:medismart/services/report_export_service.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final MedicationService _medicationService = MedicationService();
  final AdherenceService _adherenceService = AdherenceService();

  List<Medication> _medications = [];
  List<AdherenceEvent> _events = [];
  Map<String, dynamic> _stats = {};
  bool _isLoading = true;
  bool _isExporting = false;
  String _selectedRange = '30 days';
  final List<String> _ranges = ['7 days', '30 days', '3 months'];

  @override
  void initState() { super.initState(); _loadData(); }

  DateTime _getStartDate() {
    final now = DateTime.now();
    switch (_selectedRange) {
      case '7 days': return now.subtract(const Duration(days: 7));
      case '3 months': return now.subtract(const Duration(days: 90));
      default: return now.subtract(const Duration(days: 30));
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      _medications = await _medicationService.getUserMedications();
      _events = await _adherenceService.getAllUserAdherenceEvents(startDate: _getStartDate(), endDate: DateTime.now());
      _stats = _adherenceService.calculateStats(_events);
    } catch (e) { /* ignore */ }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _exportPDF() async {
    if (kIsWeb) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PDF export available on mobile'), backgroundColor: Colors.orange)); return; }
    setState(() => _isExporting = true);
    try {
      await ReportExportService().exportToPDF(medications: _medications, events: _events, stats: _stats, dateRange: _selectedRange);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ PDF exported!'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export error: $e'), backgroundColor: Colors.red));
    }
    if (mounted) setState(() => _isExporting = false);
  }

  Future<void> _exportCSV() async {
    if (kIsWeb) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('CSV export available on mobile'), backgroundColor: Colors.orange)); return; }
    setState(() => _isExporting = true);
    try {
      await ReportExportService().exportToCSV(events: _events, dateRange: _selectedRange);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ CSV exported!'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export error: $e'), backgroundColor: Colors.red));
    }
    if (mounted) setState(() => _isExporting = false);
  }

  List<BarChartGroupData> _buildWeeklyData() {
    List<BarChartGroupData> groups = [];
    final now = DateTime.now();
    for (int i = 6; i >= 0; i--) {
      final day = now.subtract(Duration(days: i));
      final dayEvents = _events.where((e) => e.scheduledAt.year == day.year && e.scheduledAt.month == day.month && e.scheduledAt.day == day.day).toList();
      int taken = dayEvents.where((e) => e.status == 'TAKEN').length;
      int missed = dayEvents.where((e) => e.status == 'MISSED').length;
      groups.add(BarChartGroupData(x: 6 - i, barRods: [
        BarChartRodData(toY: taken.toDouble(), color: Colors.green, width: 8, borderRadius: BorderRadius.circular(4)),
        BarChartRodData(toY: missed.toDouble(), color: Colors.red, width: 8, borderRadius: BorderRadius.circular(4)),
      ]));
    }
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports & Analytics'),
        actions: [
          if (!_isExporting) ...[
            IconButton(icon: const Icon(Icons.picture_as_pdf), onPressed: _exportPDF, tooltip: 'Export PDF'),
            IconButton(icon: const Icon(Icons.table_chart), onPressed: _exportCSV, tooltip: 'Export CSV'),
          ] else
            const Padding(padding: EdgeInsets.all(12), child: SizedBox(width:20,height:20,child:CircularProgressIndicator(color:Colors.white,strokeWidth:2))),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      body: _isLoading ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Range selector
            Row(children: [
              const Text('Period:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(width: 12),
              DropdownButton<String>(
                value: _selectedRange,
                items: _ranges.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                onChanged: (v) { setState(() => _selectedRange = v!); _loadData(); },
              ),
              const Spacer(),
              Text('${_events.length} records', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
            ]),
            const SizedBox(height: 16),
            _buildOverallCard(),
            const SizedBox(height: 20),
            if (_events.isNotEmpty) ...[
              const Text('Breakdown', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              _buildPieChart(),
              const SizedBox(height: 20),
              const Text('Last 7 Days', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              _buildBarChart(),
              const SizedBox(height: 20),
            ],
            const Text('Per Medication', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            if (_medications.isEmpty)
              _buildEmpty()
            else
              ..._medications.map((med) {
                double adh = _adherenceService.getMedicationAdherencePercentage(_events, med.medId);
                return _buildMedCard(med.name, adh);
              }),
            const SizedBox(height: 20),
            // Export buttons at bottom
            if (!kIsWeb) Row(children: [
              Expanded(child: OutlinedButton.icon(onPressed: _isExporting ? null : _exportPDF,
                icon: const Icon(Icons.picture_as_pdf), label: const Text('Export PDF'))),
              const SizedBox(width: 12),
              Expanded(child: OutlinedButton.icon(onPressed: _isExporting ? null : _exportCSV,
                icon: const Icon(Icons.table_chart), label: const Text('Export CSV'))),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _buildOverallCard() {
    double pct = (_stats['percentage'] as num?)?.toDouble() ?? 0.0;
    int taken = (_stats['taken'] as int?) ?? 0;
    int missed = (_stats['missed'] as int?) ?? 0;
    int total = (_stats['total'] as int?) ?? 0;
    Color adColor = pct >= 70 ? Colors.greenAccent : pct >= 40 ? Colors.orangeAccent : Colors.redAccent;
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF2196F3), Color(0xFF1976D2)], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(16)),
      child: Column(children: [
        const Text('Overall Adherence', style: TextStyle(color: Colors.white70, fontSize: 14)),
        const SizedBox(height: 8),
        Text('${pct.toStringAsFixed(1)}%', style: TextStyle(color: adColor, fontSize: 52, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ClipRRect(borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(value: pct/100, backgroundColor: Colors.white24, valueColor: AlwaysStoppedAnimation<Color>(adColor), minHeight: 10)),
        const SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _miniStat('Taken', '$taken', Colors.greenAccent),
          _miniStat('Missed', '$missed', Colors.redAccent),
          _miniStat('Total', '$total', Colors.white),
        ]),
      ]),
    );
  }

  Widget _miniStat(String label, String value, Color color) => Column(children: [
    Text(value, style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.bold)),
    Text(label, style: TextStyle(color: color.withOpacity(0.8), fontSize: 12)),
  ]);

  Widget _buildPieChart() {
    int taken = (_stats['taken'] as int?) ?? 0;
    int missed = (_stats['missed'] as int?) ?? 0;
    int snoozed = (_stats['snoozed'] as int?) ?? 0;
    if (taken + missed + snoozed == 0) return const SizedBox();
    return Container(height: 200, padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10)]),
      child: Row(children: [
        Expanded(child: PieChart(PieChartData(sections: [
          if (taken > 0) PieChartSectionData(value: taken.toDouble(), color: Colors.green, title: '$taken', radius: 65, titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
          if (missed > 0) PieChartSectionData(value: missed.toDouble(), color: Colors.red, title: '$missed', radius: 65, titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
          if (snoozed > 0) PieChartSectionData(value: snoozed.toDouble(), color: Colors.orange, title: '$snoozed', radius: 65, titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
        ], sectionsSpace: 3, centerSpaceRadius: 30))),
        const SizedBox(width: 20),
        Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
          _legend('Taken', Colors.green), const SizedBox(height: 10),
          _legend('Missed', Colors.red), const SizedBox(height: 10),
          _legend('Snoozed', Colors.orange),
        ]),
      ]),
    );
  }

  Widget _legend(String label, Color color) => Row(children: [
    Container(width: 14, height: 14, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
    const SizedBox(width: 8), Text(label, style: const TextStyle(fontSize: 13)),
  ]);

  Widget _buildBarChart() {
    final groups = _buildWeeklyData();
    final now = DateTime.now();
    final dayNames = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
    final labels = List.generate(7, (i) => dayNames[now.subtract(Duration(days: 6-i)).weekday - 1]);
    return Container(height: 200, padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [_legend('Taken', Colors.green), const SizedBox(width: 16), _legend('Missed', Colors.red)]),
        const SizedBox(height: 8),
        Expanded(child: BarChart(BarChartData(
          barGroups: groups,
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true,
              getTitlesWidget: (v, m) => v.toInt() >= 0 && v.toInt() < 7 ? Text(labels[v.toInt()], style: const TextStyle(fontSize: 10)) : const SizedBox())),
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 24,
              getTitlesWidget: (v, m) => v == v.roundToDouble() ? Text(v.toInt().toString(), style: const TextStyle(fontSize: 10)) : const SizedBox())),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
        ))),
      ]),
    );
  }

  Widget _buildMedCard(String name, double adh) {
    Color c = adh >= 70 ? Colors.green : adh >= 40 ? Colors.orange : Colors.red;
    return Card(margin: const EdgeInsets.only(bottom: 10), elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [
        const Icon(Icons.medication, color: Color(0xFF2196F3), size: 28),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 6),
          ClipRRect(borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: adh/100, backgroundColor: Colors.grey[200], valueColor: AlwaysStoppedAnimation<Color>(c), minHeight: 8)),
        ])),
        const SizedBox(width: 12),
        Text('${adh.toStringAsFixed(0)}%', style: TextStyle(color: c, fontWeight: FontWeight.bold, fontSize: 18)),
      ])),
    );
  }

  Widget _buildEmpty() => Card(elevation: 1, child: Padding(padding: const EdgeInsets.all(24),
    child: Column(children: [
      Icon(Icons.bar_chart, size: 48, color: Colors.grey[400]),
      const SizedBox(height: 12),
      Text('No data yet', style: TextStyle(fontSize: 16, color: Colors.grey[600])),
      const SizedBox(height: 4),
      Text('Start tracking medications to see reports', style: TextStyle(fontSize: 13, color: Colors.grey[500]), textAlign: TextAlign.center),
    ])));
}
