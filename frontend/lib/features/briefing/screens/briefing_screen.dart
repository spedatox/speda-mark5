import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/models/api_response.dart';
import '../../../core/theme/jarvis_theme.dart';
import '../providers/briefing_provider.dart';

/// Briefing screen rendered as a dense JARVIS-style HUD.
class BriefingScreen extends StatefulWidget {
  const BriefingScreen({super.key});

  @override
  State<BriefingScreen> createState() => _BriefingScreenState();
}

class _BriefingScreenState extends State<BriefingScreen> {
  final DateFormat _timeFormat = DateFormat('HH:mm');
  final DateFormat _dateFormat = DateFormat('EEE, d MMM');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BriefingProvider>().loadBriefing();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        toolbarHeight: 74,
        backgroundColor: Colors.transparent,
        titleSpacing: 20,
        title: Row(
          children: [
            Container(
              width: 12,
              height: 32,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [JarvisColors.primary, JarvisColors.primaryDark],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(4),
                boxShadow: const [
                  BoxShadow(
                    color: JarvisColors.glowCyan,
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DAILY BRIEFING',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: JarvisColors.primary,
                        letterSpacing: 3,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Realtime situational board',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: JarvisColors.textMuted,
                        letterSpacing: 1.2,
                      ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: _HudButton(
              label: 'REFRESH',
              icon: Icons.sync,
              onTap: () => context.read<BriefingProvider>().loadBriefing(),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: Consumer<BriefingProvider>(
            builder: (context, provider, _) => AnimatedOpacity(
              duration: const Duration(milliseconds: 220),
              opacity: provider.isLoading ? 1 : 0,
              child: const LinearProgressIndicator(
                minHeight: 2,
                color: JarvisColors.primary,
                backgroundColor: Colors.transparent,
              ),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          const _HudBackground(),
          SafeArea(
            child: Consumer<BriefingProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading && !provider.hasBriefing) {
                  return const Center(child: _HudSpinner());
                }

                if (provider.error != null && !provider.hasBriefing) {
                  return Center(
                    child: _HudPanel(
                      title: 'CHANNEL ERROR',
                      subtitle: 'Data stream interrupted',
                      accentColor: JarvisColors.danger,
                      trailing: _HudButton(
                        label: 'RETRY',
                        icon: Icons.refresh,
                        onTap: provider.loadBriefing,
                      ),
                      child: Text(
                        provider.error ?? 'Unknown error',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: JarvisColors.textPrimary),
                      ),
                    ),
                  );
                }

                final briefing = provider.briefing;
                if (briefing == null) {
                  return const Center(
                    child: _HudPanel(
                      title: 'NO DATA',
                      subtitle: 'Awaiting first signal',
                      accentColor: JarvisColors.textMuted,
                      child: SizedBox(),
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: provider.refresh,
                  color: JarvisColors.primary,
                  backgroundColor: JarvisColors.surface,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                    child: _buildBriefingContent(context, briefing),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBriefingContent(BuildContext context, BriefingModel briefing) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 1100;
        final half = (constraints.maxWidth - 16) / 2;
        final third = (constraints.maxWidth - 32) / 3;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderStrip(briefing),
            const SizedBox(height: 18),
            _buildSignalBar(briefing),
            const SizedBox(height: 18),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                if (briefing.weather != null)
                  SizedBox(
                    width: isWide ? third * 1.2 : constraints.maxWidth,
                    child: _buildWeatherPanel(briefing.weather!),
                  ),
                SizedBox(
                  width: isWide ? third * 1.2 : constraints.maxWidth,
                  child: _buildEventsPanel(briefing.eventsToday),
                ),
                SizedBox(
                  width: isWide ? third * 0.9 : constraints.maxWidth,
                  child: _buildNewsPanel(briefing.newsSummary),
                ),
                SizedBox(
                  width: isWide ? half : constraints.maxWidth,
                  child: _buildTasksPanel(
                    overdue: briefing.tasksOverdue,
                    pending: briefing.tasksPending,
                  ),
                ),
                SizedBox(
                  width: isWide ? half : constraints.maxWidth,
                  child: _buildEmailsPanel(briefing.pendingEmails),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeaderStrip(BriefingModel briefing) {
    return _HudPanel(
      title: briefing.greeting.toUpperCase(),
      subtitle: 'Operational snapshot • ${_dateFormat.format(briefing.date)}',
      accentColor: JarvisColors.primary,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _HudChip(label: _timeFormat.format(DateTime.now()), icon: Icons.timer),
          const SizedBox(width: 8),
          const _HudChip(label: 'SYNCED', icon: Icons.check_circle, color: JarvisColors.accent),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'All channels consolidated: weather, agenda, tasks, comms and intel summarized into a single HUD.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: JarvisColors.textSecondary,
                    letterSpacing: 0.4,
                  ),
            ),
          ),
          const SizedBox(width: 16),
          Container(
            height: 54,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: JarvisColors.panelBorder),
              color: JarvisColors.surface.withOpacity(0.4),
              boxShadow: const [
                BoxShadow(
                  color: JarvisColors.glowCyan,
                  blurRadius: 18,
                  spreadRadius: -6,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.grid_4x4, size: 18, color: JarvisColors.primary),
                const SizedBox(width: 10),
                Text(
                  'HYPER-VIEW MODE',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignalBar(BriefingModel briefing) {
    final segments = [
      _SignalMetric('EVENTS', briefing.eventsToday.length, Icons.event, JarvisColors.primary),
      _SignalMetric('OVERDUE', briefing.tasksOverdue.length, Icons.warning, JarvisColors.danger),
      _SignalMetric('PENDING', briefing.tasksPending.length, Icons.list_alt, JarvisColors.accent),
      _SignalMetric('EMAILS', briefing.pendingEmails.length, Icons.mail, JarvisColors.primaryLight),
      _SignalMetric('NEWS', (briefing.newsSummary ?? []).length, Icons.rss_feed, JarvisColors.warning),
    ];

    return Container(
      decoration: BoxDecoration(
        color: JarvisColors.surface.withOpacity(0.45),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: JarvisColors.panelBorder),
        boxShadow: const [
          BoxShadow(color: Color(0x6600D4FF), blurRadius: 20, spreadRadius: -12),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          const _HudBadge(label: 'SPECTRUM FEED', icon: Icons.podcasts),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              children: segments
                  .map(
                    (s) => Expanded(
                      child: _SignalBar(
                        label: s.label,
                        value: s.value,
                        icon: s.icon,
                        color: s.color,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherPanel(WeatherInfo weather) {
    return _HudPanel(
      title: 'ATMOSPHERIC FEED',
      subtitle: weather.location,
      accentColor: JarvisColors.primary,
      child: Stack(
        children: [
          Positioned(
            right: -28,
            top: -16,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [JarvisColors.primary.withOpacity(0.22), Colors.transparent],
                ),
              ),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${weather.temperature.toStringAsFixed(0)}°C',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          color: JarvisColors.primaryLight,
                          height: 0.9,
                        ),
                  ),
                  const SizedBox(height: 6),
                  _HudChip(label: weather.condition, icon: Icons.cloud_queue),
                  const SizedBox(height: 12),
                  Text(
                    'HIGH ${weather.high.toStringAsFixed(0)}°  •  LOW ${weather.low.toStringAsFixed(0)}°',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: JarvisColors.textSecondary,
                          letterSpacing: 1,
                        ),
                  ),
                ],
              ),
              const Spacer(),
              SizedBox(
                height: 120,
                width: 160,
                child: CustomPaint(
                  painter: _GaugePainter(),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'ENV INDEX',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _weatherScore(weather),
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(color: JarvisColors.accent),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEventsPanel(List<BriefingEvent> events) {
    if (events.isEmpty) {
      return _HudPanel(
        title: "TODAY'S EVENTS",
        subtitle: 'Clean slate',
        accentColor: JarvisColors.primaryLight,
        child: Text(
          'No calendar entries found for today.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: JarvisColors.textSecondary,
              ),
        ),
      );
    }

    return _HudPanel(
      title: "TODAY'S EVENTS",
      subtitle: 'Chronology + location overlay',
      accentColor: JarvisColors.primaryLight,
      child: Column(
        children: events
            .map(
              (event) => _TimelineRow(
                time: _timeFormat.format(event.startTime),
                title: event.title,
                location: event.location,
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildNewsPanel(List<String>? news) {
    final items = news ?? [];
    return _HudPanel(
      title: 'INTEL STREAM',
      subtitle: 'Condensed headlines',
      accentColor: JarvisColors.warning,
      trailing: const _HudChip(label: 'RSS LIVE', icon: Icons.wifi_tethering),
      child: items.isEmpty
          ? Text(
              'No news pulled at this time.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: JarvisColors.textSecondary,
                  ),
            )
          : Column(
              children: [
                for (final item in items)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(top: 6),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: JarvisColors.warning,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            item,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildTasksPanel({
    required List<BriefingTask> overdue,
    required List<BriefingTask> pending,
  }) {
    return _HudPanel(
      title: 'TASK DECK',
      subtitle: 'Overdue / Pending split',
      accentColor: JarvisColors.danger,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _TaskColumn(
              label: 'OVERDUE',
              color: JarvisColors.danger,
              tasks: overdue,
              emptyText: 'All clear on overdue front.',
            ),
          ),
          Container(
            width: 1,
            height: 160,
            margin: const EdgeInsets.symmetric(horizontal: 14),
            color: JarvisColors.panelBorder,
          ),
          Expanded(
            child: _TaskColumn(
              label: 'PENDING',
              color: JarvisColors.accent,
              tasks: pending,
              emptyText: 'No pending tasks detected.',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmailsPanel(List<BriefingEmail> emails) {
    return _HudPanel(
      title: 'COMMS QUEUE',
      subtitle: 'Pending outbound mail',
      accentColor: JarvisColors.primary,
      trailing: const _HudChip(label: 'AUTO-SEND PAUSED', icon: Icons.pause_circle),
      child: emails.isEmpty
          ? Text(
              'No outbound messages awaiting confirmation.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: JarvisColors.textSecondary,
                  ),
            )
          : Column(
              children: [
                for (final mail in emails)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        const Icon(Icons.mail_outline, size: 18, color: JarvisColors.primaryLight),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            mail.subject,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: JarvisColors.surfaceLight.withOpacity(0.35),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: JarvisColors.panelBorder),
                          ),
                          child: Text(
                            mail.status.toUpperCase(),
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  String _weatherScore(WeatherInfo weather) {
    final avg = (weather.high + weather.low) / 2;
    return avg >= 28
        ? 'HIGH'
        : avg >= 20
            ? 'OPTIMAL'
            : 'COOL';
  }
}

class _HudBackground extends StatelessWidget {
  const _HudBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [JarvisColors.background, JarvisColors.backgroundLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: CustomPaint(
            painter: _GridPainter(),
          ),
        ),
        Positioned(
          right: -40,
          top: 120,
          child: _GlowOrb(color: JarvisColors.primary.withOpacity(0.18)),
        ),
        Positioned(
          left: -60,
          bottom: 80,
          child: _GlowOrb(color: JarvisColors.accent.withOpacity(0.14)),
        ),
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(color: Colors.black.withOpacity(0)),
        ),
      ],
    );
  }
}

class _HudPanel extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? trailing;
  final Color accentColor;

  const _HudPanel({
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
    this.accentColor = JarvisColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: JarvisColors.panelBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: JarvisColors.panelBorder),
        boxShadow: const [
          BoxShadow(color: Color(0x5500D4FF), blurRadius: 18, spreadRadius: -10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: accentColor,
                          letterSpacing: 1.6,
                        ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
              const Spacer(),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 14),
          Divider(color: JarvisColors.panelBorder.withOpacity(0.7), height: 1),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _SignalMetric {
  final String label;
  final int value;
  final IconData icon;
  final Color color;

  _SignalMetric(this.label, this.value, this.icon, this.color);
}

class _SignalBar extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color color;

  const _SignalBar({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final double intensity = (value.clamp(0, 6) / 6).toDouble();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(label, style: Theme.of(context).textTheme.labelSmall),
            const Spacer(),
            Text(
              value.toString().padLeft(2, '0'),
              style: Theme.of(context).textTheme.labelLarge?.copyWith(color: color),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Container(
            height: 8,
            decoration: BoxDecoration(
              color: JarvisColors.surfaceLight,
              border: Border.all(color: JarvisColors.panelBorder),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: intensity.clamp(0.1, 1),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color.withOpacity(0.2), color],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  final String time;
  final String title;
  final String? location;

  const _TimelineRow({
    required this.time,
    required this.title,
    this.location,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Text(time, style: Theme.of(context).textTheme.bodySmall),
              Container(
                width: 1,
                height: 24,
                color: JarvisColors.panelBorder,
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.bodyLarge),
                if (location != null)
                  Text(
                    location!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskColumn extends StatelessWidget {
  final String label;
  final List<BriefingTask> tasks;
  final Color color;
  final String emptyText;

  const _TaskColumn({
    required this.label,
    required this.tasks,
    required this.color,
    required this.emptyText,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: color)),
          ],
        ),
        const SizedBox(height: 12),
        if (tasks.isEmpty)
          Text(
            emptyText,
            style: Theme.of(context).textTheme.bodySmall,
          )
        else
          ...tasks.map(
            (t) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      t.title,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  if (t.dueDate != null)
                    _HudChip(
                      label: DateFormat('dd MMM').format(t.dueDate!),
                      icon: Icons.schedule,
                      color: color,
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _HudChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  const _HudChip({
    required this.label,
    required this.icon,
    this.color = JarvisColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.8)),
        color: color.withOpacity(0.08),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.3), blurRadius: 10, spreadRadius: -6),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

class _HudButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _HudButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: JarvisColors.primary),
          color: JarvisColors.primary.withOpacity(0.08),
          boxShadow: const [
            BoxShadow(color: JarvisColors.glowCyan, blurRadius: 16, spreadRadius: -10),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: JarvisColors.primary),
            const SizedBox(width: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ],
        ),
      ),
    );
  }
}

class _HudBadge extends StatelessWidget {
  final String label;
  final IconData icon;

  const _HudBadge({
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: JarvisColors.surfaceLight.withOpacity(0.35),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: JarvisColors.panelBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: JarvisColors.primaryLight),
          const SizedBox(width: 8),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;

    final basePaint = Paint()
      ..color = JarvisColors.panelBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawCircle(center, radius, basePaint);

    final sweepPaint = Paint()
      ..shader = const LinearGradient(
        colors: [JarvisColors.primaryLight, JarvisColors.accent],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -0.8,
      3.8,
      false,
      sweepPaint,
    );

    final tickPaint = Paint()
      ..color = JarvisColors.gridLineBright
      ..strokeWidth = 1;

    for (int i = 0; i < 8; i++) {
      final angle = (-0.8) + (3.8 / 7) * i;
      final start = Offset(
        center.dx + (radius - 6) * cos(angle),
        center.dy + (radius - 6) * sin(angle),
      );
      final end = Offset(
        center.dx + (radius - 18) * cos(angle),
        center.dy + (radius - 18) * sin(angle),
      );
      canvas.drawLine(start, end, tickPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = JarvisColors.gridLine.withOpacity(0.35)
      ..strokeWidth = 1;

    const double step = 36;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    final accentPaint = Paint()
      ..color = JarvisColors.gridLineBright.withOpacity(0.4)
      ..strokeWidth = 1;

    for (double x = step * 3; x < size.width; x += step * 3) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), accentPaint);
    }
    for (double y = step * 3; y < size.height; y += step * 3) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), accentPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GlowOrb extends StatelessWidget {
  final Color color;

  const _GlowOrb({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      height: 260,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, Colors.transparent],
        ),
      ),
    );
  }
}

class _HudSpinner extends StatelessWidget {
  const _HudSpinner();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
          height: 64,
          width: 64,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            color: JarvisColors.primary,
            backgroundColor: JarvisColors.panelBorder,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Synchronizing feeds',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

