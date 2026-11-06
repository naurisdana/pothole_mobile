import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'camera_hud_screen.dart';
import 'distribution_map_screen.dart';
import 'history_screen.dart';

/// Navigasi utama pengemudi: Kamera HUD, Riwayat, dan Peta Sebaran.
class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _index = 0;

  static const _pages = <Widget>[
    CameraHudScreen(),
    HistoryScreen(),
    DistributionMapScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _index == 0 ? const Color(0xFF0B1220) : const Color(0xFFF7F8FB),
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: _RoadSafeNavBar(
        index: _index,
        onSelected: (value) => setState(() => _index = value),
      ),
    );
  }
}

class _NavItem {
  const _NavItem({required this.label, required this.icon});

  final String label;
  final IconData icon;
}

const _items = <_NavItem>[
  _NavItem(label: 'Kamera HUD', icon: LucideIcons.video),
  _NavItem(label: 'Riwayat', icon: LucideIcons.barChart3),
  _NavItem(label: 'Peta Sebaran', icon: LucideIcons.map),
];

class _RoadSafeNavBar extends StatelessWidget {
  const _RoadSafeNavBar({required this.index, required this.onSelected});

  final int index;
  final ValueChanged<int> onSelected;

  static const _active = Color(0xFF3B6CFF);
  static const _activeBg = Color(0xFFE7F0FF);
  static const _inactive = Color(0xFF9AA3AF);

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Material(
      color: Colors.white,
      elevation: 8,
      shadowColor: const Color(0x140F172A),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFFE8EDF3))),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(8, 8, 8, bottom > 0 ? bottom : 10),
          child: Row(
            children: [
              for (var i = 0; i < _items.length; i++)
                Expanded(
                  child: _NavButton(
                    item: _items[i],
                    selected: i == index,
                    active: _active,
                    activeBg: _activeBg,
                    inactive: _inactive,
                    onTap: () => onSelected(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.selected,
    required this.active,
    required this.activeBg,
    required this.inactive,
    required this.onTap,
  });

  final _NavItem item;
  final bool selected;
  final Color active;
  final Color activeBg;
  final Color inactive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? active : inactive;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: selected ? activeBg : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(item.icon, size: 22, color: color),
            ),
            const SizedBox(height: 4),
            Text(
              item.label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
