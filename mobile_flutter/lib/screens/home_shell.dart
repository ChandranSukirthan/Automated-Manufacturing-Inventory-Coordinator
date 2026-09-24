import 'package:flutter/material.dart';

import '../app_state.dart';
import '../app_colors.dart';
import '../services/quality_service.dart';
import 'dashboard_screen.dart';
import 'defects_screen.dart';
import 'defect_form_screen.dart';
import 'quarantine_screen.dart';
import 'quarantine_history_screen.dart';
import 'role_dashboard_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({
    required this.appState,
    required this.qualityService,
    super.key,
  });

  final AppState appState;
  final QualityService qualityService;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _selectedIndex = 0;
  int _selectedNavigationIndex = 0;

  Future<void> _showProfilePopup() async {
    final user = widget.appState.session!.user;
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.58),
      builder: (_) => _ProfilePopup(
        fullName: user.fullName,
        email: user.email,
        onSaveName: widget.appState.updateProfile,
        onSignOut: widget.appState.logout,
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.appState.session!.user;
    final isQualityInspector = user.isQualityInspector;
    final screens = isQualityInspector
        ? [
            DashboardScreen(
              service: widget.qualityService,
              appState: widget.appState,
            ),
            DefectsScreen(service: widget.qualityService, showAppBar: false),
            QuarantineScreen(service: widget.qualityService),
            QuarantineHistoryScreen(
              service: widget.qualityService,
              showPageChrome: false,
            ),
          ]
        : [
            RoleDashboardScreen(
              service: widget.qualityService,
              role: user.role,
            ),
          ];
    final titles = isQualityInspector
        ? ['Dashboard', 'Defect reports', 'Quarantine', 'History']
        : ['Dashboard'];
    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_selectedIndex]),
        actions: [
          IconButton(
            onPressed: _showProfilePopup,
            icon: const Icon(Icons.account_circle_outlined),
            color: AppColors.primaryLight,
            tooltip: 'Profile',
          ),
        ],
      ),
      body: IndexedStack(index: _selectedIndex, children: screens),
      bottomNavigationBar: isQualityInspector
          ? NavigationBar(
              selectedIndex: _selectedNavigationIndex,
              onDestinationSelected: (index) async {
                if (index == 2) {
                  await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          DefectFormScreen(service: widget.qualityService),
                    ),
                  );
                  if (mounted) {
                    setState(() {
                      _selectedIndex = 1;
                      _selectedNavigationIndex = 1;
                    });
                  }
                  return;
                }
                setState(() {
                  _selectedNavigationIndex = index;
                  _selectedIndex = index > 2 ? index - 1 : index;
                });
              },
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  selectedIcon: Icon(Icons.dashboard),
                  label: 'Overview',
                ),
                NavigationDestination(
                  icon: Icon(Icons.fact_check_outlined),
                  selectedIcon: Icon(Icons.fact_check),
                  label: 'Defects',
                ),
                NavigationDestination(
                  icon: Icon(Icons.add_circle_outline),
                  selectedIcon: Icon(Icons.add_circle),
                  label: 'Create\nDefect',
                ),
                NavigationDestination(
                  icon: Icon(Icons.inventory_2_outlined),
                  selectedIcon: Icon(Icons.inventory_2),
                  label: 'Quarantine',
                ),
                NavigationDestination(
                  icon: Icon(Icons.history),
                  label: 'History',
                ),
              ],
            )
          : null,
    );
  }
}

class _ProfilePopup extends StatefulWidget {
  const _ProfilePopup({
    required this.fullName,
    required this.email,
    required this.onSaveName,
    required this.onSignOut,
  });

  final String fullName;
  final String email;
  final Future<dynamic> Function(String fullName) onSaveName;
  final Future<void> Function() onSignOut;

  @override
  State<_ProfilePopup> createState() => _ProfilePopupState();
}

class _ProfilePopupState extends State<_ProfilePopup> {
  late final TextEditingController _nameController = TextEditingController(
    text: widget.fullName,
  );
  bool _editing = false;
  bool _saving = false;
  bool _signingOut = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Name is required.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSaveName(name);
      if (mounted) {
        setState(() {
          _editing = false;
          _saving = false;
        });
      }
    } catch (exception) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = exception.toString();
        });
      }
    }
  }

  Future<void> _signOut() async {
    setState(() => _signingOut = true);
    await widget.onSignOut();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
    backgroundColor: Colors.transparent,
    elevation: 0,
    child: Container(
      constraints: const BoxConstraints(maxWidth: 390),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF131B2E), Color(0xFF0F1523)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF2A3958), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.4),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.18),
                      blurRadius: 14,
                    ),
                  ],
                ),
                child: Text(
                  widget.fullName.trim().isEmpty
                      ? '?'
                      : widget.fullName.trim()[0].toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.strongText,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _editing
                    ? TextField(
                        controller: _nameController,
                        autofocus: true,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _saveName(),
                        style: const TextStyle(
                          color: AppColors.strongText,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Your name',
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                      )
                    : InkWell(
                        onTap: () => setState(() => _editing = true),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  widget.fullName,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.strongText,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: () =>
                                    setState(() => _editing = true),
                                icon: const Icon(Icons.edit_outlined, size: 18),
                                color: AppColors.primaryLight,
                                tooltip: 'Edit name',
                                visualDensity: VisualDensity.compact,
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
              if (_editing)
                IconButton(
                  onPressed: _saving ? null : _saveName,
                  icon: _saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_rounded),
                  color: AppColors.primaryLight,
                  tooltip: 'Save name',
                ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 60),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.mutedText,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 3),
                const Text(
                  'QA',
                  style: TextStyle(
                    color: AppColors.mutedText,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              style: const TextStyle(color: AppColors.errorText, fontSize: 12),
            ),
          ],
          const SizedBox(height: 14),
          Divider(height: 1, color: const Color(0xFF2A3958).withValues(alpha: 0.8)),
          const SizedBox(height: 5),
          TextButton.icon(
            onPressed: _signingOut ? null : _signOut,
            icon: _signingOut
                ? const SizedBox.square(
                    dimension: 17,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.logout_rounded, size: 19),
            label: const Align(
              alignment: Alignment.centerLeft,
              child: Text('Sign out'),
            ),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              alignment: Alignment.centerLeft,
            ),
          ),
        ],
      ),
    ),
  );
}
