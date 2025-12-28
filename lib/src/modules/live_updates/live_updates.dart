
import 'package:flutter/material.dart';
import 'package:kumbha_path/main_layout.dart';
import 'package:flutter/material.dart';
import 'package:kumbha_path/src/constant/app_responsive.dart';
import 'package:kumbha_path/src/constant/language_helper.dart';

class LiveUpdates extends StatefulWidget {
  const LiveUpdates({super.key});

  @override
  State<LiveUpdates> createState() => _LiveUpdates();
}

class _LiveUpdates extends State<LiveUpdates> {
  int _selectedTabIndex = 0; 

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final isMobile = context.isMobile;
    final isTablet = context.isTablet;
    final isDesktop = context.isDesktop;

    return MainLayout(
      showDefaultBottom: true,
      ctx: 1,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor ?? cs.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.menu, color: cs.onSurface),
          onPressed: () {},
        ),
        centerTitle: true,
        title: Text(
          LanguageHelper.t('live_updates_title'),
          style: theme.textTheme.titleMedium?.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: cs.onSurface,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: cs.onSurface),
            onPressed: () {},
          ),
        ],
      ),
      body: ValueListenableBuilder<String>(
        valueListenable: LanguageHelper.currentLang,
        builder: (context, lang, _) {
          final list = _filteredItems;

          return Container(
            color: theme.scaffoldBackgroundColor,
            child: Column(
              children: [
                // ======= TABS =======
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 16 : isTablet ? 32 : 56,
                    vertical: isMobile ? 12 : 16,
                  ),
                  child: _TabsBar(
                    selectedIndex: _selectedTabIndex,
                    onChanged: (index) {
                      setState(() {
                        _selectedTabIndex = index;
                      });
                    },
                  ),
                ),

                // ======= LIST =======
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 16 : isTablet ? 32 : 56,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: isDesktop ? 520 : 480,
                      ),
                      child: ListView.separated(
                        itemCount: list.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 10),
                        itemBuilder: (context, index) =>
                            _UpdateCard(item: list[index]),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ------------- ITEMS -----------------

  List<_LiveUpdateItem> get _allItems => [
        _LiveUpdateItem(
          type: _UpdateType.alert,
          icon: Icons.groups_2_outlined,
          titleKey: 'live_update_high_crowd_title',
          timeKey: 'live_update_5_mins_ago',
          accentColor: Colors.red,
          iconBgColor: Colors.red.withOpacity(0.12),
          iconColor: Colors.red.shade700,
        ),
        _LiveUpdateItem(
          type: _UpdateType.alert,
          icon: Icons.wb_sunny_outlined,
          titleKey: 'live_update_next_snan_title',
          timeKey: 'live_update_1_hour_ago',
          accentColor: Colors.blue,
          iconBgColor: Colors.blue.withOpacity(0.12),
          iconColor: Colors.blue.shade700,
        ),
        _LiveUpdateItem(
          type: _UpdateType.message,
          icon: Icons.directions_bus_filled_outlined,
          titleKey: 'live_update_shuttle_title',
          timeKey: 'live_update_1_hour_ago',
          accentColor: Colors.green,
          iconBgColor: Colors.green.withOpacity(0.12),
          iconColor: Colors.green.shade700,
        ),
        _LiveUpdateItem(
          type: _UpdateType.alert,
          icon: Icons.warning_amber_outlined,
          titleKey: 'live_update_gate_closed_title',
          timeKey: 'live_update_2_hours_ago',
          accentColor: Colors.red,
          iconBgColor: Colors.red.withOpacity(0.12),
          iconColor: Colors.red.shade700,
        ),
        _LiveUpdateItem(
          type: _UpdateType.message,
          icon: Icons.temple_hindu_outlined,
          titleKey: 'live_update_evening_aarti_title',
          timeKey: 'live_update_3_hours_ago',
          accentColor: Colors.blue,
          iconBgColor: Colors.blue.withOpacity(0.12),
          iconColor: Colors.blue.shade700,
        ),
        _LiveUpdateItem(
          type: _UpdateType.message,
          icon: Icons.cloudy_snowing,
          titleKey: 'live_update_light_showers_title',
          timeKey: 'live_update_4_hours_ago',
          accentColor: Colors.green,
          iconBgColor: Colors.green.withOpacity(0.12),
          iconColor: Colors.green.shade700,
        ),
      ];

  List<_LiveUpdateItem> get _filteredItems {
    switch (_selectedTabIndex) {
      case 1:
        return _allItems.where((e) => e.type == _UpdateType.alert).toList();
      case 2:
        return _allItems.where((e) => e.type == _UpdateType.message).toList();
      default:
        return _allItems;
    }
  }
}

// ================== DATA MODEL ==================

enum _UpdateType { alert, message }

class _LiveUpdateItem {
  final _UpdateType type;
  final IconData icon;
  final String titleKey;
  final String timeKey;
  final Color accentColor;
  final Color iconBgColor;
  final Color iconColor;

  _LiveUpdateItem({
    required this.type,
    required this.icon,
    required this.titleKey,
    required this.timeKey,
    required this.accentColor,
    required this.iconBgColor,
    required this.iconColor,
  });
}

// ================== TABS BAR ==================

class _TabsBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const _TabsBar({required this.selectedIndex, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: cs.surfaceVariant,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          _TabChip(
            label: LanguageHelper.t('live_updates_tab_all'),
            index: 0,
            selectedIndex: selectedIndex,
            onTap: onChanged,
          ),
          _TabChip(
            label: LanguageHelper.t('live_updates_tab_alerts'),
            index: 1,
            selectedIndex: selectedIndex,
            onTap: onChanged,
          ),
          _TabChip(
            label: LanguageHelper.t('live_updates_tab_messages'),
            index: 2,
            selectedIndex: selectedIndex,
            onTap: onChanged,
          ),
        ],
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  final String label;
  final int index;
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const _TabChip({
    required this.label,
    required this.index,
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bool isSelected = index == selectedIndex;

    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: isSelected ? cs.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected
                  ? cs.onSurface
                  : cs.onSurface.withOpacity(0.6),
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}

// ================== UPDATE CARD ==================

class _UpdateCard extends StatelessWidget {
  final _LiveUpdateItem item;

  const _UpdateCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: cs.shadow.withOpacity(0.06),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Accent bar
            Container(
              width: 3,
              height: 40,
              decoration: BoxDecoration(
                color: item.accentColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),

            // Icon circle
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: item.iconBgColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                item.icon,
                color: item.iconColor,
                size: 22,
              ),
            ),
            const SizedBox(width: 10),

            // Text area
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    LanguageHelper.t(item.titleKey),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    LanguageHelper.t(item.timeKey),
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 12,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
