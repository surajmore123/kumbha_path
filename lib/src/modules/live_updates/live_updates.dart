import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kumbha_path/main_layout.dart';
import 'package:kumbha_path/src/bloc/app_details_bloc/app_details_bloc.dart';
import 'package:kumbha_path/src/bloc/app_details_bloc/app_details_event.dart';
import 'package:kumbha_path/src/bloc/app_details_bloc/app_details_state.dart';

import 'package:kumbha_path/src/constant/app_responsive.dart';
import 'package:kumbha_path/src/constant/language_helper.dart';
import 'package:kumbha_path/src/models/notification_model.dart';

class LiveUpdates extends StatefulWidget {
  const LiveUpdates({super.key});

  @override
  State<LiveUpdates> createState() => _LiveUpdates();
}

class _LiveUpdates extends State<LiveUpdates> {
  void initState() {
    super.initState();
    context.read<AppDetailsBloc>().add(GetNotificationsEvent(type: ""));
  }

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
        // leading: IconButton(
        //   icon: Icon(Icons.menu, color: cs.onSurface),
        //   onPressed: () {},
        // ),
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
            onPressed: () {
              context.read<AppDetailsBloc>().add(GetNotificationsEvent(type: ""));
            },
          ),
        ],
      ),
      body: ValueListenableBuilder<String>(
        valueListenable: LanguageHelper.currentLang,
        builder: (context, lang, _) {
          // final list = _filteredItems;

          return BlocBuilder<AppDetailsBloc, AppDetailsState>(
            builder: (context, state) {
              if (state.status == AppDetailsStatus.loading) {
                return const Center(child: CircularProgressIndicator());
              }
              final notifications = state.notificationList;
              if (notifications.isEmpty) {
                return const Center(child: Text("No notifications found"));
              }

              return Container(
                color: theme.scaffoldBackgroundColor,
                child: Column(
                  children: [
                    // ======= TABS =======
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal:
                            isMobile
                                ? 16
                                : isTablet
                                ? 32
                                : 56,
                        vertical: isMobile ? 12 : 16,
                      ),
                      child: _TabsBar(
                        selectedIndex: _selectedTabIndex,
                        onChanged: (index) {
                          setState(() {
                            _selectedTabIndex = index;
                          });
                          String type = "";
                          if (index == 1) {
                            type = "ALERT";
                          } else if (index == 2) {
                            type = "MESSAGE";
                          }
                          context.read<AppDetailsBloc>().add(
                            GetNotificationsEvent(type: type),
                          );
                        },
                      ),
                    ),

                    // ======= LIST =======
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal:
                              isMobile
                                  ? 16
                                  : isTablet
                                  ? 32
                                  : 56,
                        ),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: isDesktop ? 520 : 480,
                          ),
                          child: ListView.separated(
                            itemCount: notifications.length,
                            separatorBuilder:
                                (_, __) => const SizedBox(height: 10),
                            itemBuilder:
                                (context, index) => NotificationCard(
                                  notifications: notifications[index],
                                ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

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
              color: isSelected ? cs.onSurface : cs.onSurface.withOpacity(0.6),
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}

// ================== UPDATE CARD ==================

class NotificationCard extends StatelessWidget {
  final NotificationModel notifications;

  const NotificationCard({super.key, required this.notifications});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bool isAlert = notifications.type == "ALERT";
    final Color accentColor = isAlert ? Colors.red : Colors.blue;

    final IconData icon =
        isAlert ? Icons.warning_amber_rounded : Icons.notifications;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            notifications.title ?? "",
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            notifications.body ?? "",
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: cs.onSurface.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                notifications.zoneName ?? "",
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: cs.onSurface.withOpacity(0.6),
                ),
              ),
              Text(
                _formatDate(notifications.createdAt),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: cs.onSurface.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(String? date) {
    if (date == null || date.isEmpty) return "";
    final parsed = DateTime.parse(date);
    return "${parsed.day}/${parsed.month}/${parsed.year}  ${parsed.hour}:${parsed.minute}";
  }
}
