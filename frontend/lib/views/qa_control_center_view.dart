import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class _DefectReport {
  final String productType;
  final String description;
  final int quantity;
  final bool isQuarantined;
  final DateTime submittedAt;

  const _DefectReport({
    required this.productType,
    required this.description,
    required this.quantity,
    required this.isQuarantined,
    required this.submittedAt,
  });
}

class QaControlCenterView extends StatefulWidget {
  const QaControlCenterView({super.key});

  @override
  State<QaControlCenterView> createState() => _QaControlCenterViewState();
}

class _QaControlCenterViewState extends State<QaControlCenterView> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _quantityController = TextEditingController();
  late final ScrollController _pageScrollController;

  String? _selectedProductType;
  bool _showProductTypeError = false;
  bool _triggerQuarantine = false;
  bool _notificationsEnabled = true;
  bool _automaticQuarantineEnabled = true;
  int _selectedNavIndex = 0;
  final List<_DefectReport> _reports = [];

  static const _productTypes = [
    'BoxPouch',
    'Biscuit Packaging',
    'Tea Bag',
    'Bag',
    'Can',
    'Bottle',
  ];

  @override
  void initState() {
    super.initState();
    _pageScrollController = ScrollController();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _quantityController.dispose();
    _pageScrollController.dispose();
    super.dispose();
  }

  String _formatTime(DateTime time) {
    final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${time.hour >= 12 ? 'PM' : 'AM'}';
  }

  void _submitReport() {
    final isFormValid = _formKey.currentState?.validate() ?? false;
    if (!isFormValid || _selectedProductType == null) {
      setState(() => _showProductTypeError = _selectedProductType == null);
      return;
    }

    final report = _DefectReport(
      productType: _selectedProductType!,
      description: _descriptionController.text.trim(),
      quantity: int.parse(_quantityController.text),
      isQuarantined: _triggerQuarantine,
      submittedAt: DateTime.now(),
    );

    setState(() {
      _reports.insert(0, report);
      _selectedProductType = null;
      _showProductTypeError = false;
      _descriptionController.clear();
      _quantityController.clear();
      _triggerQuarantine = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF0066CC),
        content: Text(
          report.isQuarantined
              ? 'Defect submitted and the affected batch was quarantined.'
              : 'Defect report submitted. A new report form is ready.',
        ),
      ),
    );
  }

  void _showNotifications() {
    final quarantinedReports =
        _reports.where((report) => report.isQuarantined).toList();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: 280,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(24, 8, 24, 12),
                child: Text(
                  'QA notifications',
                  style: TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: _reports.isEmpty
                    ? const Center(
                        child: Text(
                          'No QA notifications yet.',
                          style: TextStyle(color: Color(0xFF64748B)),
                        ),
                      )
                    : ListView(
                        children: [
                          if (quarantinedReports.isNotEmpty)
                            ListTile(
                              leading: const Icon(
                                Icons.warning_amber_rounded,
                                color: Color(0xFFC62828),
                              ),
                              title: Text(
                                '${quarantinedReports.length} quarantined batch${quarantinedReports.length == 1 ? '' : 'es'} require review',
                              ),
                              subtitle: const Text(
                                'Open Quarantine to review the affected material.',
                              ),
                              onTap: () {
                                Navigator.pop(sheetContext);
                                setState(() => _selectedNavIndex = 1);
                              },
                            ),
                          ListTile(
                            leading: const Icon(
                              Icons.history,
                              color: Color(0xFF0066CC),
                            ),
                            title: Text(
                              '${_reports.length} defect report${_reports.length == 1 ? '' : 's'} logged',
                            ),
                            subtitle: const Text(
                              'Open History to view submitted reports.',
                            ),
                            onTap: () {
                              Navigator.pop(sheetContext);
                              setState(() => _selectedNavIndex = 2);
                            },
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

  Widget _pageBody() {
    switch (_selectedNavIndex) {
      case 1:
        return _buildQuarantinePage();
      case 2:
        return _buildHistoryPage();
      case 3:
        return _buildSettingsPage();
      default:
        return _buildNewReportPage();
    }
  }

  Widget _buildNewReportPage() {
    const primaryBlue = Color(0xFF0066CC);
    const alertRedBg = Color(0xFFFFEBEE);
    const alertRedText = Color(0xFFC62828);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Report New Defect',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Log production anomalies for immediate review and action.',
          style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
        ),
        const SizedBox(height: 20),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Product Type',
                  style: TextStyle(
                    color: Color(0xFF334155),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _productTypes.map((type) {
                    final isSelected = _selectedProductType == type;
                    return ChoiceChip(
                      label: Text(type),
                      selected: isSelected,
                      selectedColor: Colors.white,
                      backgroundColor: Colors.white,
                      labelStyle: TextStyle(
                        color: isSelected
                            ? const Color(0xFF0F172A)
                            : const Color(0xFF64748B),
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.w500,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: isSelected
                              ? const Color(0xFF0F172A)
                              : const Color(0xFFCBD5E1),
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      onSelected: (_) => setState(() {
                        _selectedProductType = type;
                        _showProductTypeError = false;
                      }),
                    );
                  }).toList(),
                ),
                if (_showProductTypeError) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Select a product type.',
                    style: TextStyle(color: Color(0xFFC62828), fontSize: 12),
                  ),
                ],
                const SizedBox(height: 24),
                const Text(
                  'Description',
                  style: TextStyle(
                    color: Color(0xFF334155),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 3,
                  style: const TextStyle(color: Color(0xFF0F172A)),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Describe the defect.'
                      : null,
                  decoration: _inputDecoration(
                    hintText: 'Describe the defect and affected batch.',
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Affected Quantity',
                  style: TextStyle(
                    color: Color(0xFF334155),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _quantityController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(color: Color(0xFF0F172A)),
                  validator: (value) {
                    final quantity = int.tryParse(value ?? '');
                    return quantity == null || quantity < 1
                        ? 'Enter a quantity greater than 0.'
                        : null;
                  },
                  decoration: _inputDecoration(
                    hintText: 'Enter units',
                    suffixText: 'Units',
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  decoration: BoxDecoration(
                    color: alertRedBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFFCDD2)),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: alertRedText,
                        size: 26,
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Trigger Immediate AI Material Quarantine',
                              style: TextStyle(
                                color: alertRedText,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Apply an automated hold to the affected batch.',
                              style: TextStyle(
                                color: Color(0xFFD32F2F),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _triggerQuarantine,
                        activeTrackColor: alertRedText,
                        onChanged: (value) =>
                            setState(() => _triggerQuarantine = value),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.send_rounded),
                    label: const Text(
                      'Log Defect & Submit',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: _submitReport,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuarantinePage() {
    final quarantinedReports =
        _reports.where((report) => report.isQuarantined).toList();
    return _buildListPage(
      title: 'Quarantine',
      subtitle: 'Batches placed on hold by QA.',
      emptyMessage: 'No batches are currently quarantined.',
      reports: quarantinedReports,
      icon: Icons.warning_amber_rounded,
      iconColor: const Color(0xFFC62828),
    );
  }

  Widget _buildHistoryPage() {
    return _buildListPage(
      title: 'Defect History',
      subtitle: 'All defect reports submitted in this session.',
      emptyMessage: 'No defect reports have been submitted yet.',
      reports: _reports,
      icon: Icons.history,
      iconColor: const Color(0xFF0066CC),
    );
  }

  Widget _buildListPage({
    required String title,
    required String subtitle,
    required String emptyMessage,
    required List<_DefectReport> reports,
    required IconData icon,
    required Color iconColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
        ),
        const SizedBox(height: 20),
        if (reports.isEmpty)
          _emptyState(emptyMessage, icon)
        else
          ...reports.map(
            (report) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, color: iconColor),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          report.productType,
                          style: const TextStyle(
                            color: Color(0xFF0F172A),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          report.description,
                          style: const TextStyle(color: Color(0xFF475569)),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${report.quantity} units • ${_formatTime(report.submittedAt)}${report.isQuarantined ? ' • Quarantined' : ''}',
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSettingsPage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'QA Settings',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Control QA notifications and automated handling.',
          style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
        ),
        const SizedBox(height: 20),
        Card(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('Auto-Quarantine Raw Materials'),
                subtitle: const Text(
                  'Automatically lock associated raw material database records when a finished batch is flagged as defective to prevent further use.',
                ),
                value: _automaticQuarantineEnabled,
                onChanged: (value) =>
                    setState(() => _automaticQuarantineEnabled = value),
              ),
              const Divider(height: 1),
              SwitchListTile(
                title: const Text('AI Defect Alert Routing'),
                subtitle: const Text(
                  'Instantly notify the Supply Chain Manager if the Agentic AI detects a recurring defect pattern.',
                ),
                value: _notificationsEnabled,
                onChanged: (value) =>
                    setState(() => _notificationsEnabled = value),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _emptyState(String message, IconData icon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFF94A3B8), size: 36),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hintText,
    String? suffixText,
  }) {
    return InputDecoration(
      hintText: hintText,
      suffixText: suffixText,
      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.all(14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const lightBg = Color(0xFFF8FAFC);

    return Scaffold(
      backgroundColor: lightBg,
      appBar: AppBar(
        backgroundColor: lightBg,
        elevation: 0,
        leading: const Padding(
          padding: EdgeInsets.all(12),
          child: Icon(Icons.factory_outlined, color: Color(0xFF1E293B)),
        ),
        title: const Text(
          'QA CONTROL CENTER',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.bold,
            fontSize: 18,
            letterSpacing: 0.5,
          ),
        ),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.notifications_none_rounded,
                  color: Color(0xFF334155),
                  size: 26,
                ),
                tooltip: 'QA notifications',
                onPressed: _showNotifications,
              ),
              if (_reports.isNotEmpty)
                Positioned(
                  right: 12,
                  top: 12,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Scrollbar(
        controller: _pageScrollController,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: _pageScrollController,
          padding: const EdgeInsets.all(16),
          child: _pageBody(),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
        ),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildBottomNavItem(0, Icons.add_box, 'NEW REPORT'),
            _buildBottomNavItem(1, Icons.warning_amber_rounded, 'QUARANTINE'),
            _buildBottomNavItem(2, Icons.history, 'HISTORY'),
            _buildBottomNavItem(3, Icons.settings_outlined, 'SETTINGS'),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavItem(int index, IconData icon, String label) {
    const primaryBlue = Color(0xFF0066CC);
    final isSelected = _selectedNavIndex == index;

    return InkWell(
      onTap: () {
        setState(() => _selectedNavIndex = index);
        _pageScrollController.jumpTo(0);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isSelected ? primaryBlue : const Color(0xFF64748B),
            size: 22,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? primaryBlue : const Color(0xFF64748B),
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
