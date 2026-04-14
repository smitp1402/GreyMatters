// lib/student/student_shell.dart
// Smit owns this file and everything under lib/student/

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/services/attention_stream_provider.dart';
import '../core/services/websocket_client.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import 'screens/dashboard_screen.dart';
import 'screens/library_screen.dart';

/// Root widget for the student module — matches Stitch "Cognitive Sanctuary" dashboard.
///
/// Desktop: Left sidebar (Cognitive Dashboard, nav, Start Session) + main content.
/// Mobile: Bottom navigation bar.
class StudentShell extends ConsumerStatefulWidget {
  const StudentShell({super.key});

  @override
  ConsumerState<StudentShell> createState() => _StudentShellState();
}

class _StudentShellState extends ConsumerState<StudentShell> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 768;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          // Top nav bar
          _buildTopNav(ref),
          Expanded(
            child: Row(
              children: [
                // Sidebar (desktop only)
                if (isDesktop) _buildSidebar(),
                // Main content
                Expanded(
                  child: _selectedIndex == 0
                      ? const DashboardScreen()
                      : const LibraryScreen(),
                ),
              ],
            ),
          ),
        ],
      ),
      // Mobile bottom nav
      bottomNavigationBar: isDesktop
          ? null
          : _buildMobileNav(),
    );
  }

  Widget _buildTopNav(WidgetRef ref) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      color: AppColors.surface.withValues(alpha: 0.95),
      child: Row(
        children: [
          const Text(
            'The Cognitive Sanctuary',
            style: TextStyle(
              fontFamily: 'Segoe UI',
              fontWeight: FontWeight.w700,
              fontSize: 18,
              color: AppColors.primary,
              letterSpacing: -0.3,
            ),
          ),
          const Spacer(),
          _topNavLink('Dashboard', _selectedIndex == 0, () => setState(() => _selectedIndex = 0)),
          const SizedBox(width: 32),
          _topNavLink('Library', _selectedIndex == 1, () => setState(() => _selectedIndex = 1)),
          const SizedBox(width: 32),
          _topNavLink('History', false, () {}),
          const SizedBox(width: 24),
          // Headset connection status
          _buildHeadsetStatus(ref),
          const SizedBox(width: 16),
          // Profile icon
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.account_circle, color: AppColors.primary, size: 28),
          ),
        ],
      ),
    );
  }

  Widget _buildHeadsetStatus(WidgetRef ref) {
    final statusAsync = ref.watch(headsetConnectionProvider);
    final status = statusAsync.valueOrNull ?? HeadsetConnectionStatus.disconnected;

    final (Color color, String label, IconData icon) = switch (status) {
      HeadsetConnectionStatus.connected => (
          AppColors.focused,
          'CROWN LINKED',
          Icons.bluetooth_connected,
        ),
      HeadsetConnectionStatus.connecting => (
          AppColors.drifting,
          'CONNECTING',
          Icons.bluetooth_searching,
        ),
      HeadsetConnectionStatus.disconnected => (
          AppColors.lost,
          'NO CROWN',
          Icons.bluetooth_disabled,
        ),
    };

    return Tooltip(
      message: switch (status) {
        HeadsetConnectionStatus.connected => 'Neurosity Crown is streaming EEG data',
        HeadsetConnectionStatus.connecting => 'Searching for Neurosity Crown...',
        HeadsetConnectionStatus.disconnected => 'Crown not connected — tap to reconnect',
      },
      child: InkWell(
        onTap: () => context.go('/student/connect'),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Segoe UI',
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topNavLink(String label, bool isActive, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Segoe UI',
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
              fontSize: 14,
              color: isActive ? AppColors.primary : AppColors.outline,
            ),
          ),
          const SizedBox(height: 2),
          if (isActive)
            Container(
              width: 28,
              height: 2,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 256,
      color: AppColors.surfaceContainerLow,
      child: Column(
        children: [
          // Profile section
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.surfaceContainerHighest,
                  ),
                  child: const Icon(Icons.person, color: AppColors.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Cognitive Dashboard',
                      style: TextStyle(
                        fontFamily: 'Segoe UI',
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AppColors.primary,
                      ),
                    ),
                    Text(
                      'CURRENT FLOW: 82%',
                      style: TextStyle(
                        fontFamily: 'Segoe UI',
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.5,
                        color: AppColors.onSurfaceVariant.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Nav items
          _sidebarItem(Icons.home, 'Home', 0),
          _sidebarItem(Icons.library_books, 'Library', 1),

          const Spacer(),

          // Start Session button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => context.go('/student/connect'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                ),
                child: const Text(
                  'Start Session',
                  style: TextStyle(
                    fontFamily: 'Segoe UI',
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Settings / Support
          _sidebarSmallItem(Icons.settings, 'Settings'),
          _sidebarSmallItem(Icons.help_outline, 'Support'),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _sidebarItem(IconData icon, String label, int index) {
    final isActive = _selectedIndex == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: isActive ? AppColors.surfaceContainerHighest : Colors.transparent,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: InkWell(
          onTap: () => setState(() => _selectedIndex = index),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(
                  isActive ? icon : icon,
                  size: 20,
                  color: isActive ? AppColors.primary : AppColors.outline,
                ),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Segoe UI',
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                    color: isActive ? AppColors.primary : AppColors.outline,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sidebarSmallItem(IconData icon, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Icon(icon, size: 16, color: AppColors.outline),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: const TextStyle(
                    fontFamily: 'Segoe UI',
                    fontSize: 12,
                    color: AppColors.outline,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileNav() {
    return NavigationBar(
      selectedIndex: _selectedIndex,
      onDestinationSelected: (i) => setState(() => _selectedIndex = i),
      backgroundColor: AppColors.surfaceContainerLow,
      indicatorColor: AppColors.secondaryContainer,
      destinations: const [
        NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
        NavigationDestination(icon: Icon(Icons.library_books_outlined), selectedIcon: Icon(Icons.library_books), label: 'Library'),
      ],
    );
  }
}
