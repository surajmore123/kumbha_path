import 'package:flutter/material.dart';
import 'package:kumbha_path/src/constant/app_color.dart';
import 'package:kumbha_path/src/constant/language_helper.dart'
    show LanguageHelper;


class DashboardFeatureCard extends StatelessWidget {
  final String iconPath;
  final String titleKey;
  final String subtitleKey;
  final VoidCallback? onTap;

  const DashboardFeatureCard({
    super.key,
    required this.iconPath,
    required this.titleKey,
    required this.subtitleKey,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final cs = Theme.of(context).colorScheme;
    final gradient = buildThemeGradient(context, isPrimary: true);
    final titleStyle = theme.textTheme.bodyMedium?.copyWith(
      fontWeight: FontWeight.w600,
      fontSize: 14,
      color: colorScheme.onSurface,
    );

    final subtitleStyle = theme.textTheme.bodySmall?.copyWith(
      color: colorScheme.onSurface.withOpacity(0.72),
    );

    return Container(
      width: 165,
      height: 180,
       decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).brightness == Brightness.dark
                ? cs.primary.withOpacity(0.12)
                : cs.primary.withOpacity(0.08),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // If you use monochrome icons and want them tinted, replace
              // Image.asset with SvgPicture.asset and provide color: colorScheme.primary
              Image.asset(iconPath, width: 60, height: 60),
              const SizedBox(height: 10),
              Text(LanguageHelper.t(titleKey), style: titleStyle),
              const SizedBox(height: 4),
              Text(LanguageHelper.t(subtitleKey), style: subtitleStyle),
            ],
          ),
        ),
      ),
    );
  }
}

class DashboardWideCard extends StatelessWidget {
  final String iconPath;
  final String titleKey;
  final String subtitleKey;
  final VoidCallback? onTap;

  const DashboardWideCard({
    super.key,
    required this.iconPath,
    required this.titleKey,
    required this.subtitleKey,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
        final cs = Theme.of(context).colorScheme;
    final gradient = buildThemeGradient(context, isPrimary: true);

    final titleStyle = theme.textTheme.bodyMedium?.copyWith(
      fontWeight: FontWeight.w600,
      fontSize: 14,
      color: colorScheme.onSurface,
    );

    final subtitleStyle = theme.textTheme.bodySmall?.copyWith(
      color: colorScheme.onSurface.withOpacity(0.72),
    );

    return Container(
       decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).brightness == Brightness.dark
                ? cs.primary.withOpacity(0.12)
                : cs.primary.withOpacity(0.08),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Image.asset(iconPath, width: 60, height: 60),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(LanguageHelper.t(titleKey), style: titleStyle),
                    const SizedBox(height: 4),
                    Text(LanguageHelper.t(subtitleKey), style: subtitleStyle),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
