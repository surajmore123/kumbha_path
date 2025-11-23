
import 'package:flutter/material.dart';
import 'package:kumbha_path/src/constant/language_helper.dart' show LanguageHelper;

class DashboardFeatureCard extends StatelessWidget {
  final String iconPath;
  final String titleKey;
  final String subtitleKey;
  final VoidCallback? onTap;

  const DashboardFeatureCard({super.key, 
    required this.iconPath,
    required this.titleKey,
    required this.subtitleKey,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final subtitleStyle = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: Colors.grey[700]);

    return Card(
      elevation: 1.5,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Image.asset(iconPath, width: 60, height: 60),
              const SizedBox(height: 10),
              Text(
                LanguageHelper.t(titleKey),
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
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

  const DashboardWideCard({super.key, 
    required this.iconPath,
    required this.titleKey,
    required this.subtitleKey,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final subtitleStyle = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: Colors.grey[700]);

    return Card(
      elevation: 1.5,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                    Text(
                      LanguageHelper.t(titleKey),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
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
