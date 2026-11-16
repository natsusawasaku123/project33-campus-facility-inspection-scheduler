import 'package:flutter/material.dart';

import 'campus_theme.dart';
import 'dashboard_data.dart';

enum CampusTool { inspections, alerts }

class CampusDashboard extends StatefulWidget {
  const CampusDashboard({
    super.key,
    required this.facilities,
    required this.activity,
    required this.name,
    required this.role,
    required this.notice,
    required this.signingOut,
    required this.canSignIn,
    required this.onSignIn,
    required this.onSignOut,
    required this.onRefresh,
    required this.onRefreshActivity,
    required this.onCreatePlan,
    required this.onOpenTool,
    required this.onToggleTheme,
  });
  final Future<List<Facility>> facilities;
  final Future<DashboardActivity>? activity;
  final String? name, role, notice;
  final bool signingOut, canSignIn;
  final VoidCallback onSignIn,
      onSignOut,
      onRefresh,
      onRefreshActivity,
      onToggleTheme;
  final ValueChanged<Facility> onCreatePlan;
  final ValueChanged<CampusTool> onOpenTool;
  @override
  State<CampusDashboard> createState() => _CampusDashboardState();
}

class _CampusDashboardState extends State<CampusDashboard> {
  final _scaffold = GlobalKey<ScaffoldState>();
  final _facilitiesKey = GlobalKey();
  final _scroll = ScrollController();
  final _search = TextEditingController();
  String _section = 'Overview';
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _selectedDay = DateUtils.dateOnly(DateTime.now());
  @override
  void dispose() {
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  void _facilities() {
    _scaffold.currentState?.closeDrawer();
    setState(() => _section = 'Facilities');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _facilitiesKey.currentContext;
      if (target != null) {
        Scrollable.ensureVisible(
          target,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _overview() {
    _scaffold.currentState?.closeDrawer();
    setState(() => _section = 'Overview');
    _scroll.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _tool(CampusTool tool) {
    _scaffold.currentState?.closeDrawer();
    widget.onOpenTool(tool);
  }

  String get _role => widget.role == null
      ? 'Guest workspace'
      : '${widget.role![0].toUpperCase()}${widget.role!.substring(1)}';
  String get _initials => widget.name == null
      ? 'C'
      : widget.name!
            .split(' ')
            .where((s) => s.isNotEmpty)
            .take(2)
            .map((s) => s[0])
            .join()
            .toUpperCase();

  void _guide() => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('A little care, every day.'),
      content: const SizedBox(
        width: 390,
        child: Text(
          '1. Plan ahead\nA supervisor chooses a facility, an inspector and a recurring schedule.\n\n2. Inspect with care\nThe assigned inspector completes the checklist for each inspection.\n\n3. Follow up\nMaintenance reviews delivered finding alerts. Supervisors review escalations and compliance.',
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Got it'),
        ),
      ],
    ),
  );

  Widget _brand() => Row(
    children: [
      Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: context.campus.accent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(
          Icons.spa_outlined,
          color: Theme.of(context).colorScheme.onPrimary,
          size: 23,
        ),
      ),
      const SizedBox(width: 11),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Campus / inspect',
              style: TextStyle(
                fontFamily: 'DM Serif Display',
                fontSize: 21,
                color: context.campus.ink,
              ),
            ),
            Text(
              'SPACES WORTH CARING FOR',
              style: TextStyle(
                fontSize: 8,
                letterSpacing: 1.35,
                fontWeight: FontWeight.w600,
                color: context.campus.muted,
              ),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _nav(
    String label,
    IconData icon,
    VoidCallback action, {
    bool selected = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Material(
      color: selected ? context.campus.soft : Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Icon(
          icon,
          size: 20,
          color: selected ? context.campus.accent : context.campus.muted,
        ),
        title: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? context.campus.accent : context.campus.muted,
          ),
        ),
        onTap: action,
      ),
    ),
  );

  Widget _sidebar() => Container(
    width: 238,
    color: context.campus.sidebar,
    child: SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 30, 20, 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _brand(),
            const SizedBox(height: 40),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 14, bottom: 16),
                    child: Text(
                      'WORKSPACE',
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 2,
                        color: context.campus.muted,
                      ),
                    ),
                  ),
                  _nav(
                    'Overview',
                    Icons.space_dashboard_outlined,
                    _overview,
                    selected: _section == 'Overview',
                  ),
                  _nav(
                    'Facilities',
                    Icons.domain_outlined,
                    _facilities,
                    selected: _section == 'Facilities',
                  ),
                  if (widget.role == 'inspector')
                    _nav(
                      'My Inspections',
                      Icons.fact_check_outlined,
                      () => _tool(CampusTool.inspections),
                    ),
                  if (widget.role == 'supervisor' ||
                      widget.role == 'maintenance')
                    _nav(
                      widget.role == 'supervisor'
                          ? 'Alerts & Compliance'
                          : 'Finding Alerts',
                      Icons.notifications_none_rounded,
                      () => _tool(CampusTool.alerts),
                    ),
                  const SizedBox(height: 64),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: context.campus.soft,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.eco_outlined,
                          color: context.campus.accent,
                          size: 30,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'A little care,\nevery day.',
                          style: TextStyle(
                            fontFamily: 'DM Serif Display',
                            fontSize: 25,
                            height: 1.15,
                            color: context.campus.ink,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'A simple routine for safer campus spaces.',
                          style: TextStyle(
                            color: context.campus.muted,
                            fontSize: 12,
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: _guide,
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            alignment: Alignment.centerLeft,
                          ),
                          child: const Text('How it works  ↗'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const Divider(),
            const SizedBox(height: 16),
            Row(
              children: [
                CircleAvatar(
                  radius: 19,
                  backgroundColor: context.campus.soft,
                  foregroundColor: context.campus.accent,
                  child: Text(
                    _initials,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.name ?? 'Your campus workspace',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        _role,
                        style: TextStyle(
                          fontSize: 11,
                          color: context.campus.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  Widget _searchField() => TextField(
    key: const ValueKey('facility-search'),
    controller: _search,
    onChanged: (_) => setState(() {}),
    onSubmitted: (_) => _facilities(),
    decoration: InputDecoration(
      hintText: 'Search facilities',
      prefixIcon: const Icon(Icons.search_rounded, size: 20),
      suffixIcon: _search.text.isEmpty
          ? null
          : IconButton(
              tooltip: 'Clear search',
              onPressed: () => setState(_search.clear),
              icon: const Icon(Icons.close_rounded, size: 18),
            ),
      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
    ),
  );

  Widget _header(bool wide) => SafeArea(
    bottom: false,
    child: Container(
      height: 86,
      padding: EdgeInsets.symmetric(horizontal: wide ? 30 : 14),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: context.campus.line)),
      ),
      child: Row(
        children: [
          if (!wide)
            IconButton(
              tooltip: 'Open navigation',
              onPressed: () => _scaffold.currentState?.openDrawer(),
              icon: const Icon(Icons.menu_rounded),
            ),
          Expanded(
            child: Text(
              wide ? 'Your overview' : 'Campus inspections',
              style: TextStyle(
                fontFamily: wide ? 'DM Serif Display' : 'DM Sans',
                fontSize: wide ? 27 : 16,
                fontWeight: wide ? FontWeight.w400 : FontWeight.w600,
              ),
            ),
          ),
          if (wide) ...[
            SizedBox(width: 245, child: _searchField()),
            const SizedBox(width: 18),
          ],
          IconButton(
            key: const ValueKey('theme-toggle'),
            tooltip: Theme.of(context).brightness == Brightness.dark
                ? 'Switch to light mode'
                : 'Switch to dark mode',
            onPressed: widget.onToggleTheme,
            icon: Icon(
              Theme.of(context).brightness == Brightness.dark
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
              size: 21,
            ),
          ),
          const SizedBox(width: 4),
          TextButton(
            onPressed: !widget.canSignIn || widget.signingOut
                ? null
                : widget.onSignIn,
            child: Text(
              widget.name == null ? 'Sign in' : 'Switch account',
              style: const TextStyle(fontSize: 12),
            ),
          ),
          if (widget.name != null)
            IconButton(
              tooltip: 'Sign out',
              onPressed: widget.signingOut ? null : widget.onSignOut,
              icon: const Icon(Icons.logout_rounded, size: 20),
            ),
        ],
      ),
    ),
  );

  Widget _hero() => LayoutBuilder(
    builder: (context, box) {
      final illustrated = box.maxWidth >= 610;
      return Container(
        padding: EdgeInsets.all(illustrated ? 28 : 23),
        decoration: BoxDecoration(
          color: context.campus.hero,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: context.campus.line),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.wb_sunny_outlined,
                        size: 16,
                        color: context.campus.accent,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.name == null
                              ? 'A fresh start for your campus'
                              : 'Welcome back, ${widget.name}.',
                          style: TextStyle(
                            fontSize: 12,
                            color: context.campus.muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Small checks.\nSafer spaces.',
                    style: Theme.of(context).textTheme.headlineLarge
                        ?.copyWith(fontSize: illustrated ? 40 : 35),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Plan with purpose. Inspect with care.\nKeep your campus moving safely.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.65,
                      color: context.campus.muted,
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: widget.name == null
                        ? (widget.canSignIn ? widget.onSignIn : null)
                        : widget.role == 'inspector'
                        ? () => _tool(CampusTool.inspections)
                        : _facilities,
                    label: Text(
                      widget.name == null
                          ? 'Sign in'
                          : widget.role == 'inspector'
                          ? 'Open my inspections'
                          : 'Explore facilities',
                    ),
                    icon: const Icon(Icons.arrow_forward_rounded, size: 17),
                    iconAlignment: IconAlignment.end,
                  ),
                ],
              ),
            ),
            if (illustrated)
              const SizedBox(
                width: 220,
                height: 230,
                child: ExcludeSemantics(
                  child: CustomPaint(painter: _CampusIllustration()),
                ),
              ),
          ],
        ),
      );
    },
  );

  Widget _metric(String label, String value, IconData icon) => CampusPanel(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: context.campus.accent, size: 19),
        const SizedBox(height: 12),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: value.length > 4 ? 22 : 30,
            fontWeight: FontWeight.w600,
            height: 1.1,
            color: context.campus.ink,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          maxLines: 2,
          style: TextStyle(fontSize: 11, color: context.campus.muted),
        ),
      ],
    ),
  );

  Widget _metrics(
    AsyncSnapshot<List<Facility>> facilities,
    DashboardActivity? data,
  ) {
    final available =
        facilities.connectionState == ConnectionState.done &&
        !facilities.hasError;
    final secondLabel = widget.role == 'maintenance'
        ? 'Delivered alerts'
        : widget.name == null || widget.role == 'custodian'
        ? 'Your workspace'
        : 'Today’s inspections';
    final secondValue = widget.name == null
        ? 'Guest'
        : widget.role == 'custodian'
        ? 'Browse'
        : widget.role == 'maintenance'
        ? '${data?.alertCount ?? '—'}'
        : '${data?.scheduled ?? '—'}';
    final thirdLabel = widget.role == 'supervisor'
        ? 'Open findings'
        : widget.role == 'inspector'
        ? 'Assigned to you'
        : 'Your tools';
    final thirdValue = widget.role == 'supervisor'
        ? '${data?.openFindings ?? '—'}'
        : widget.role == 'inspector'
        ? '${data?.totalAssigned ?? '—'}'
        : widget.name == null
        ? 'Sign in'
        : widget.role == 'maintenance'
        ? 'Alerts'
        : 'Browse';
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _metric(
              'Campus facilities',
              available ? '${facilities.data!.length}' : '—',
              Icons.domain_outlined,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _metric(
              secondLabel,
              secondValue,
              Icons.event_available_outlined,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _metric(
              thirdLabel,
              thirdValue,
              widget.role == 'supervisor'
                  ? Icons.flag_outlined
                  : Icons.verified_user_outlined,
            ),
          ),
        ],
      ),
    );
  }

  Widget _progress(DashboardActivity? data, bool loading) {
    final progress = data?.progress;
    final title = widget.role == 'maintenance'
        ? 'Finding follow-up'
        : 'Daily progress';
    final detail = widget.name == null
        ? 'Sign in to see your inspection activity.'
        : loading
        ? 'Loading your activity…'
        : data?.scheduled == 0
        ? 'No inspections scheduled for this date.'
        : data?.scheduled != null
        ? '${data!.completed} of ${data.scheduled} inspections completed'
        : widget.role == 'maintenance'
        ? '${data?.alertCount ?? '—'} delivered alerts to review.'
        : 'Your assigned tools are in the navigation.';
    return CampusPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 18),
          Row(
            children: [
              SizedBox(
                width: 100,
                height: 100,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox.expand(
                      child: CircularProgressIndicator(
                        value: progress ?? 0,
                        strokeWidth: 8,
                        backgroundColor: context.campus.soft,
                        color: context.campus.accent,
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          progress == null
                              ? '—'
                              : '${(progress * 100).round()}%',
                          style: TextStyle(
                            fontFamily: 'DM Serif Display',
                            fontSize: 29,
                            color: context.campus.ink,
                          ),
                        ),
                        Text(
                          progress == null ? 'no activity' : 'complete',
                          style: TextStyle(
                            fontSize: 10,
                            color: context.campus.muted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      detail,
                      style: const TextStyle(fontSize: 12, height: 1.6),
                    ),
                    if (data?.reportDate != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        '${MaterialLocalizations.of(context).formatShortDate(data!.reportDate!)}\n${data.timezone}',
                        style: TextStyle(
                          fontSize: 10,
                          height: 1.5,
                          color: context.campus.muted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _routine() => CampusPanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'A thoughtful routine',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 15),
        for (final step in const [
          ('01', 'Plan ahead', 'Choose a space, inspector and schedule.'),
          (
            '02',
            'Inspect with care',
            'Complete every assigned checklist item.',
          ),
          ('03', 'Follow up', 'Review findings, alerts and compliance.'),
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: context.campus.soft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    step.$1,
                    style: TextStyle(
                      color: context.campus.accent,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        step.$2,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        step.$3,
                        style: TextStyle(
                          fontSize: 10,
                          color: context.campus.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );

  Widget _facilityCard(Facility facility) => CampusPanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: context.campus.soft,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.meeting_room_outlined,
                color: context.campus.accent,
                size: 25,
              ),
            ),
            const Spacer(),
            _tag('Campus facility'),
          ],
        ),
        const SizedBox(height: 18),
        Text(facility.name, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          'Facility ID: ${facility.id}',
          style: TextStyle(fontSize: 11, color: context.campus.muted),
        ),
        const SizedBox(height: 20),
        if (widget.role == 'supervisor')
          FilledButton.icon(
            onPressed: () => widget.onCreatePlan(facility),
            icon: const Icon(Icons.add_rounded, size: 17),
            label: const Text('New plan'),
          )
        else if (widget.role == 'inspector')
          OutlinedButton(
            onPressed: () => _tool(CampusTool.inspections),
            child: const Text('View assigned inspections'),
          )
        else if (widget.role == 'maintenance')
          OutlinedButton(
            onPressed: () => _tool(CampusTool.alerts),
            child: const Text('View finding alerts'),
          )
        else if (widget.name == null)
          TextButton.icon(
            onPressed: widget.canSignIn ? widget.onSignIn : null,
            icon: const Icon(Icons.arrow_forward_rounded, size: 16),
            label: const Text('Sign in to inspect'),
          )
        else
          Text(
            'Your account can browse campus facilities.',
            style: TextStyle(color: context.campus.muted, fontSize: 12),
          ),
      ],
    ),
  );

  Widget _tag(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: context.campus.soft,
      borderRadius: BorderRadius.circular(30),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 10,
        color: context.campus.accent,
        fontWeight: FontWeight.w600,
      ),
    ),
  );

  Widget _facilitySection(AsyncSnapshot<List<Facility>> snapshot, bool wide) {
    final all = snapshot.data ?? const <Facility>[];
    final query = _search.text.trim().toLowerCase();
    final rows = all
        .where(
          (f) =>
              f.name.toLowerCase().contains(query) || f.id.toString() == query,
        )
        .toList();
    return Column(
      key: _facilitiesKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Campus facilities',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            IconButton(
              tooltip: 'Refresh dashboard',
              onPressed: widget.onRefresh,
              icon: const Icon(Icons.refresh_rounded, size: 20),
            ),
          ],
        ),
        Text(
          'A space to care for. A good place to start.',
          style: TextStyle(color: context.campus.muted, fontSize: 12),
        ),
        const SizedBox(height: 16),
        if (!wide) ...[_searchField(), const SizedBox(height: 16)],
        if (snapshot.connectionState != ConnectionState.done)
          const CampusPanel(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Loading facilities…'),
                  ],
                ),
              ),
            ),
          )
        else if (snapshot.hasError)
          CampusEmptyState(
            icon: Icons.cloud_off_outlined,
            title: 'Could not load facilities.',
            detail: 'Check your connection, then try again.',
            action: FilledButton.icon(
              onPressed: widget.onRefresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          )
        else if (all.isEmpty)
          const CampusEmptyState(
            icon: Icons.domain_outlined,
            title: 'No facilities found.',
            detail: 'Facilities will appear here when they are available.',
          )
        else if (rows.isEmpty)
          CampusEmptyState(
            icon: Icons.search_off_rounded,
            title: 'No matching facilities.',
            detail: 'Try another name or facility ID.',
            action: OutlinedButton(
              onPressed: () => setState(_search.clear),
              child: const Text('Clear search'),
            ),
          )
        else
          LayoutBuilder(
            builder: (context, box) {
              final columns = box.maxWidth >= 680 ? 2 : 1;
              final width = (box.maxWidth - 18 * (columns - 1)) / columns;
              return Wrap(
                spacing: 18,
                runSpacing: 18,
                children: [
                  for (final facility in rows)
                    SizedBox(width: width, child: _facilityCard(facility)),
                ],
              );
            },
          ),
      ],
    );
  }

  Widget _profile() => CampusPanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Your workspace',
              style: TextStyle(color: context.campus.muted, fontSize: 11),
            ),
            const Spacer(),
            Icon(
              Icons.verified_user_outlined,
              color: context.campus.accent,
              size: 17,
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            CircleAvatar(
              radius: 25,
              backgroundColor: context.campus.soft,
              foregroundColor: context.campus.accent,
              child: Text(
                _initials,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.name ?? 'Make room\nfor a safer campus.',
                    style: TextStyle(
                      fontFamily: widget.name == null
                          ? 'DM Serif Display'
                          : 'DM Sans',
                      fontSize: widget.name == null ? 21 : 14,
                      fontWeight: widget.name == null
                          ? FontWeight.w400
                          : FontWeight.w600,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 7),
                  _tag(_role),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          widget.name == null
              ? 'Your plans, inspections and alerts, together in one calm space.'
              : 'You’re signed in. Your available tools follow your assigned role.',
          style: TextStyle(
            fontSize: 11,
            height: 1.6,
            color: context.campus.muted,
          ),
        ),
      ],
    ),
  );

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
  void _changeMonth(int delta) => setState(() {
    _month = DateTime(_month.year, _month.month + delta);
    _selectedDay = _month;
  });

  Widget _calendar(DashboardActivity? data, bool loading) {
    final localizations = MaterialLocalizations.of(context);
    final days = DateUtils.getDaysInMonth(_month.year, _month.month);
    final offset = (_month.weekday + 6) % 7;
    final events = data?.events ?? const <CampusEvent>[];
    final selected = events
        .where((e) => _sameDay(e.date, _selectedDay))
        .toList();
    final title = widget.role == 'inspector'
        ? 'Inspection calendar'
        : widget.role == 'supervisor' || widget.role == 'maintenance'
        ? 'Alert due dates'
        : 'Your calendar';
    return CampusPanel(
      padding: const EdgeInsets.all(19),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontSize: 22),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  localizations.formatMonthYear(_month),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Previous month',
                onPressed: () => _changeMonth(-1),
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.chevron_left_rounded, size: 18),
              ),
              IconButton(
                tooltip: 'Next month',
                onPressed: () => _changeMonth(1),
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.chevron_right_rounded, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              for (final day in const ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
                Expanded(
                  child: Center(
                    child: Text(
                      day,
                      style: TextStyle(
                        fontSize: 10,
                        color: context.campus.muted,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 7),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: days + offset,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 2,
              crossAxisSpacing: 2,
            ),
            itemBuilder: (context, i) {
              if (i < offset) return const SizedBox.shrink();
              final date = DateTime(_month.year, _month.month, i - offset + 1);
              final chosen = _sameDay(date, _selectedDay);
              final marked = events.any((e) => _sameDay(e.date, date));
              return Tooltip(
                message: localizations.formatFullDate(date),
                child: Semantics(
                  selected: chosen,
                  label: localizations.formatFullDate(date),
                  child: TextButton(
                    onPressed: () => setState(() => _selectedDay = date),
                    style: TextButton.styleFrom(
                      minimumSize: Size.zero,
                      padding: EdgeInsets.zero,
                      foregroundColor: chosen
                          ? Theme.of(context).colorScheme.onPrimary
                          : context.campus.ink,
                      backgroundColor: chosen
                          ? context.campus.accent
                          : Colors.transparent,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${date.day}',
                          style: const TextStyle(fontSize: 10),
                        ),
                        if (marked)
                          Container(
                            width: 3,
                            height: 3,
                            decoration: BoxDecoration(
                              color: chosen
                                  ? Theme.of(context).colorScheme.onPrimary
                                  : context.campus.accent,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 15),
          const Divider(),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  localizations.formatMediumDate(_selectedDay),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => setState(() {
                  final now = DateTime.now();
                  _selectedDay = DateUtils.dateOnly(now);
                  _month = DateTime(now.year, now.month);
                }),
                style: TextButton.styleFrom(
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.all(7),
                ),
                child: const Text('Today', style: TextStyle(fontSize: 10)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (loading)
            Text(
              'Loading your calendar…',
              style: TextStyle(color: context.campus.muted, fontSize: 11),
            )
          else if (selected.isEmpty)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: context.campus.canvas,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.event_note_outlined,
                    color: context.campus.muted,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.name == null
                          ? 'Sign in to see your inspection activity.'
                          : widget.role == 'inspector'
                          ? 'No inspections on this day.'
                          : widget.role == 'custodian'
                          ? 'Your account can browse facilities.'
                          : 'No alert due dates on this day.',
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.5,
                        color: context.campus.muted,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else ...[
            for (final event in selected.take(3))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => _tool(
                    widget.role == 'inspector'
                        ? CampusTool.inspections
                        : CampusTool.alerts,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: context.campus.soft,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          event.completed
                              ? Icons.check_circle_outline
                              : Icons.schedule_rounded,
                          size: 17,
                          color: context.campus.accent,
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                event.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(event.date))} · ${event.detail}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: context.campus.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
          if (widget.role == 'supervisor' || widget.role == 'maintenance')
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'Shows due dates from alerts you can access.',
                style: TextStyle(
                  fontSize: 9,
                  height: 1.5,
                  color: context.campus.muted,
                ),
              ),
            ),
          if (widget.role != null && widget.role != 'custodian')
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: TextButton(
                onPressed: () => _tool(
                  widget.role == 'inspector'
                      ? CampusTool.inspections
                      : CampusTool.alerts,
                ),
                child: Text(
                  widget.role == 'inspector'
                      ? 'View all inspections  ↗'
                      : 'View all alerts  ↗',
                  style: const TextStyle(fontSize: 11),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _body(
    bool wide,
    AsyncSnapshot<List<Facility>> facilities,
    AsyncSnapshot<DashboardActivity> activity,
  ) {
    final data = widget.name == null ? null : activity.data;
    final loading =
        widget.activity != null &&
        activity.connectionState != ConnectionState.done;
    final main = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _hero(),
        const SizedBox(height: 20),
        if (widget.notice != null) ...[
          Semantics(
            liveRegion: true,
            child: CampusPanel(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: context.campus.accent,
                    size: 19,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.notice!,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
        _metrics(facilities, data),
        const SizedBox(height: 20),
        if (activity.hasError) ...[
          CampusPanel(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Could not load your activity.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
                TextButton(
                  onPressed: widget.onRefreshActivity,
                  child: const Text('Retry activity'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
        LayoutBuilder(
          builder: (context, box) => box.maxWidth >= 660
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _progress(data, loading)),
                    const SizedBox(width: 18),
                    Expanded(child: _routine()),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _progress(data, loading),
                    const SizedBox(height: 18),
                    _routine(),
                  ],
                ),
        ),
        const SizedBox(height: 24),
        _facilitySection(facilities, wide),
      ],
    );
    final aside = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _profile(),
        const SizedBox(height: 20),
        _calendar(data, loading),
      ],
    );
    return SingleChildScrollView(
      controller: _scroll,
      padding: EdgeInsets.all(wide ? 30 : 18),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1400),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LayoutBuilder(
                builder: (context, box) => box.maxWidth >= 1030
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: main),
                          const SizedBox(width: 24),
                          SizedBox(width: 280, child: aside),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [main, const SizedBox(height: 24), aside],
                      ),
              ),
              const SizedBox(height: 30),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: 12,
                runSpacing: 8,
                children: [
                  Text(
                    'University of La Salette',
                    style: TextStyle(fontSize: 10, color: context.campus.muted),
                  ),
                  Text(
                    'Campus Facility Inspection Scheduler · Project 33',
                    style: TextStyle(fontSize: 10, color: context.campus.muted),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final wide = box.maxWidth >= 1100;
      return Scaffold(
        key: _scaffold,
        drawer: wide
            ? null
            : Drawer(
                width: 270,
                backgroundColor: context.campus.sidebar,
                child: _sidebar(),
              ),
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (wide) _sidebar(),
            Expanded(
              child: Column(
                children: [
                  _header(wide),
                  Expanded(
                    child: FutureBuilder<List<Facility>>(
                      future: widget.facilities,
                      builder: (context, facilities) =>
                          FutureBuilder<DashboardActivity>(
                            key: ObjectKey(widget.activity),
                            future: widget.activity,
                            builder: (context, activity) =>
                                _body(wide, facilities, activity),
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _CampusIllustration extends CustomPainter {
  const _CampusIllustration();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 240, size.height / 250);
    final paint = Paint();
    void rect(Rect r, double radius, Color color) {
      paint.color = color;
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, Radius.circular(radius)),
        paint,
      );
    }

    paint.color = const Color(0xFFD8C5FB);
    canvas.drawCircle(const Offset(125, 130), 97, paint);
    paint.color = const Color(0xFFE6D9FC);
    canvas.drawCircle(const Offset(187, 72), 32, paint);
    rect(const Rect.fromLTWH(45, 120, 145, 88), 5, const Color(0xFFFCFAF6));
    rect(const Rect.fromLTWH(89, 75, 70, 133), 6, const Color(0xFFFDFBFF));
    final roof = Path()
      ..moveTo(77, 78)
      ..lineTo(124, 44)
      ..lineTo(171, 78)
      ..close();
    paint.color = const Color(0xFF5B2DFF);
    canvas.drawPath(roof, paint);
    for (final x in [104.0, 132.0]) {
      for (final y in [92.0, 121.0, 150.0]) {
        rect(Rect.fromLTWH(x, y, 13, 17), 3, const Color(0xFFC8B4FF));
      }
    }
    for (final x in [57.0, 77.0, 166.0]) {
      for (final y in [136.0, 166.0]) {
        rect(Rect.fromLTWH(x, y, 12, 17), 3, const Color(0xFFE1D5F8));
      }
    }
    rect(const Rect.fromLTWH(112, 178, 25, 30), 3, const Color(0xFF5B2DFF));
    rect(const Rect.fromLTWH(29, 207, 178, 5), 3, const Color(0xFFAD91E4));
    rect(const Rect.fromLTWH(163, 82, 54, 68), 10, const Color(0xFFFFFFFF));
    for (final y in [101.0, 115.0, 129.0]) {
      rect(Rect.fromLTWH(174, y, 8, 8), 3, const Color(0xFFE8DFFA));
      rect(Rect.fromLTWH(187, y + 2, 19, 3), 2, const Color(0xFFC8B4FF));
    }
    paint.color = const Color(0xFF5B2DFF);
    canvas.drawCircle(const Offset(47, 79), 24, paint);
    final check = Path()
      ..moveTo(36, 79)
      ..lineTo(44, 87)
      ..lineTo(59, 71);
    paint
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(check, paint);
    paint.style = PaintingStyle.fill;
    for (final point in [const Offset(25, 152), const Offset(216, 186)]) {
      paint.color = const Color(0xFFAB8CE0);
      canvas.drawOval(
        Rect.fromCenter(center: point, width: 13, height: 31),
        paint,
      );
      rect(
        Rect.fromLTWH(point.dx - 1, point.dy + 8, 2, 32),
        1,
        const Color(0xFF8462B8),
      );
    }
    paint.color = const Color(0xFFFFFFFF);
    canvas.drawCircle(const Offset(192, 40), 4, paint);
    paint.color = const Color(0xFFA98BD7);
    canvas.drawCircle(const Offset(17, 112), 3, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
