import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/speda_theme.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/google_auth_service.dart';

/// Ultra-minimal Settings screen - 2026 design
class MinimalSettingsScreen extends StatefulWidget {
  const MinimalSettingsScreen({super.key});

  @override
  State<MinimalSettingsScreen> createState() => _MinimalSettingsScreenState();
}

class _MinimalSettingsScreenState extends State<MinimalSettingsScreen> {
  bool _googleConnected = false;
  bool _loading = true;
  LlmSettings? _llmSettings;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final apiService = context.read<ApiService>();
      final authStatus = await apiService.getAuthStatus();
      final llmSettings = await apiService.getLlmSettings();

      if (mounted) {
        setState(() {
          _googleConnected = authStatus['google'] ?? false;
          _llmSettings = llmSettings;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SpedaColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: SpedaColors.primary,
                        strokeWidth: 2,
                      ),
                    )
                  : _buildSettingsList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          // Menu button
          GestureDetector(
            onTap: () => Scaffold.of(context).openDrawer(),
            child: const Icon(
              Icons.menu_rounded,
              size: 26,
              color: SpedaColors.textSecondary,
            ),
          ),
          const SizedBox(width: 16),
          Text(
            'Settings',
            style: SpedaTypography.heading.copyWith(
              fontSize: 24,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsList() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: [
        // Account section
        _buildSectionHeader('Account'),
        const SizedBox(height: 12),
        _buildSettingCard(
          children: [
            _buildConnectedAccount(
              'Google',
              Icons.g_mobiledata_rounded,
              _googleConnected,
              onTap: _handleGoogleConnect,
            ),
          ],
        ),

        const SizedBox(height: 24),

        // AI section
        _buildSectionHeader('AI Model'),
        const SizedBox(height: 12),
        _buildSettingCard(
          children: [
            _buildSettingTile(
              icon: Icons.psychology_rounded,
              title: 'Model',
              subtitle: _llmSettings?.model ?? 'gpt-4o-mini',
              onTap: _showModelSelector,
            ),
            _buildDivider(),
            _buildSettingTile(
              icon: Icons.cloud_outlined,
              title: 'Provider',
              subtitle: _llmSettings?.provider ?? 'openai',
            ),
          ],
        ),

        const SizedBox(height: 24),

        // About section
        _buildSectionHeader('About'),
        const SizedBox(height: 12),
        _buildSettingCard(
          children: [
            _buildSettingTile(
              icon: Icons.info_outline_rounded,
              title: 'Version',
              subtitle: '1.0.0',
            ),
            _buildDivider(),
            _buildSettingTile(
              icon: Icons.code_rounded,
              title: 'Build',
              subtitle: 'January 2026',
            ),
          ],
        ),

        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        title,
        style: SpedaTypography.label.copyWith(
          color: SpedaColors.textTertiary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildSettingCard({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: SpedaColors.surface,
        borderRadius: BorderRadius.circular(SpedaRadius.lg),
        border: Border.all(color: SpedaColors.border),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(SpedaRadius.lg),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: SpedaColors.surfaceLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: SpedaColors.textSecondary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: SpedaTypography.body),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: SpedaTypography.caption.copyWith(
                          color: SpedaColors.textTertiary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (onTap != null)
                const Icon(
                  Icons.chevron_right_rounded,
                  color: SpedaColors.textTertiary,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConnectedAccount(
    String name,
    IconData icon,
    bool connected, {
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(SpedaRadius.lg),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: SpedaColors.surfaceLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 24, color: SpedaColors.textSecondary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(name, style: SpedaTypography.body),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: connected
                      ? SpedaColors.success.withAlpha(25)
                      : SpedaColors.surfaceLight,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  connected ? 'Connected' : 'Connect',
                  style: SpedaTypography.label.copyWith(
                    color: connected
                        ? SpedaColors.success
                        : SpedaColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 0.5,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      color: SpedaColors.border,
    );
  }

  /// Platform-aware Google authentication
  /// - Android/iOS: Native Google Sign-In
  /// - Windows/Web: Web OAuth flow
  Future<void> _handleGoogleConnect() async {
    if (_googleConnected) {
      // Disconnect
      await _disconnectGoogle();
    } else {
      // Connect
      await _connectGoogle();
    }
  }

  Future<void> _connectGoogle() async {
    try {
      final apiService = context.read<ApiService>();
      final isMobile = GoogleAuthService.shouldUseNativeSignIn;

      if (isMobile) {
        // Use native Google Sign-In on mobile (Android/iOS)
        try {
          final googleAuth = GoogleAuthService();
          final auth = await googleAuth.signIn();

          if (auth != null && auth.accessToken != null) {
            // Send token to backend
            final success = await apiService.sendGoogleMobileToken(
              auth.accessToken!,
              idToken: auth.idToken,
            );

            if (success) {
              setState(() => _googleConnected = true);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Google connected successfully!'),
                    backgroundColor: SpedaColors.success,
                  ),
                );
              }
              return; // Success - exit early
            } else {
              throw Exception('Failed to authenticate with backend');
            }
          } else {
            // User cancelled - just return without error
            return;
          }
        } catch (e) {
          // Native sign-in failed, fall through to web flow
          debugPrint(
              'Native Google Sign-In failed: $e, falling back to web flow');
        }
      }

      // Use web OAuth flow (fallback for mobile if native fails, or primary for desktop)
      final authUrl = await apiService.getGoogleAuthUrl(
        platform: isMobile ? 'mobile' : 'desktop',
      );

      if (authUrl != null) {
        await apiService.openUrl(authUrl);

        // Show waiting dialog for web auth
        if (mounted) {
          _showAuthWaitingDialog();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to connect: $e'),
            backgroundColor: SpedaColors.error,
          ),
        );
      }
    }
  }

  void _showAuthWaitingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: SpedaColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          'Connecting to Google',
          style: SpedaTypography.title,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              color: SpedaColors.primary,
              strokeWidth: 2,
            ),
            const SizedBox(height: 20),
            Text(
              'Complete sign-in in your browser, then click Done.',
              style: SpedaTypography.body.copyWith(
                color: SpedaColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Cancel',
                      style: SpedaTypography.label.copyWith(
                        color: SpedaColors.textSecondary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _loadSettings(); // Refresh auth status
                    },
                    child: const Text('Done'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _disconnectGoogle() async {
    try {
      final apiService = context.read<ApiService>();
      await apiService.logoutGoogle();

      // Also sign out from native Google Sign-In if on mobile
      if (GoogleAuthService.shouldUseNativeSignIn) {
        await GoogleAuthService().signOut();
      }

      setState(() => _googleConnected = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Google disconnected'),
            backgroundColor: SpedaColors.textSecondary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to disconnect: $e'),
            backgroundColor: SpedaColors.error,
          ),
        );
      }
    }
  }

  void _showModelSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: SpedaColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        child: Column(
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: SpedaColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text('Select Model', style: SpedaTypography.title),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 20),
                children: [
                  ...(_llmSettings?.availableModels ??
                          ['gpt-4o-mini', 'gpt-4o', 'gpt-4-turbo'])
                      .map((model) => _buildModelOption(
                            model,
                            model == 'gpt-4o-mini'
                                ? 'Fast & efficient'
                                : model == 'gpt-4o'
                                    ? 'Most capable'
                                    : 'OpenAI Model',
                          )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModelOption(String model, String description) {
    final isSelected = _llmSettings?.model == model;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          Navigator.pop(context);
          try {
            final apiService = context.read<ApiService>();
            final updated = await apiService.updateLlm(
              provider: 'openai',
              model: model,
            );
            setState(() => _llmSettings = updated);
          } catch (e) {
            // Handle error
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? SpedaColors.primarySubtle
                : SpedaColors.surfaceLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? SpedaColors.primary : SpedaColors.border,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(model, style: SpedaTypography.body),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: SpedaTypography.caption,
                    ),
                  ],
                ),
              ),
              if (isSelected)
                const Icon(Icons.check_circle,
                    color: SpedaColors.primary, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
