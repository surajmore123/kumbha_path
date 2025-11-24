import 'package:flutter/material.dart';

import 'package:kumbha_path/main_layout.dart';
import 'package:kumbha_path/src/constant/app_responsive.dart';
import 'package:kumbha_path/src/constant/language_helper.dart';
class NearTemples extends StatelessWidget {
  const NearTemples({super.key});

  @override
  Widget build(BuildContext context) {
    final isMobile = context.isMobile;
    final isTablet = context.isTablet;
    final isDesktop = context.isDesktop;

   
    final temples = [
      {
        'titleKey': 'triambak_title',
        'descriptionKey': 'triambak_description',
        'image': 'assets/images/triambakeshwar.png',
      },
      {
        'titleKey': 'kashi_title',
        'descriptionKey': 'kashi_description',
        'image': 'assets/images/kashi.png',
      },
      {
        'titleKey': 'mahakal_title',
        'descriptionKey': 'mahakal_description',
        'image': 'assets/images/rameshwaram.png',
      },
      {
        'titleKey': 'sankat_title',
        'descriptionKey': 'sankat_description',
        'image': 'assets/images/kedarnath.png',
      },
    ];

    return MainLayout(
      showDefaultBottom: true,
      ctx: 0,
      appBar: AppBar(
        backgroundColor: Colors.white,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          LanguageHelper.t('nearby_temples_title'), // e.g. "Nearby Temples"
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: Icon(Icons.search),
          ),
        ],
      ),
      body: ValueListenableBuilder<String>(
        valueListenable: LanguageHelper.currentLang,
        builder: (context, lang, _) {
          final titleStyle =
              Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: isMobile
                        ? 18
                        : isTablet
                            ? 20
                            : 22,
                  );

          final subtitleStyle =
              Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: isMobile ? 13 : 14,
                    color: Colors.grey[700],
                    height: 1.4,
                  );

          return Container(
            color: const Color(0xFFF2F6FB),
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile
                    ? 16
                    : isTablet
                        ? 32
                        : 56,
                vertical: isMobile ? 16 : 24,
              ),
              child: ConstrainedBox(
                constraints:
                    BoxConstraints(maxWidth: isDesktop ? 520 : 480),
                child: Column(
                  children: [
                    // =================== MAP CIRCLE ===================
                    Card(
                      color: Colors.white,
                      elevation: 1.5,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Center(
                          child: SizedBox(
                            width: isMobile ? 260 : 300,
                            height: isMobile ? 260 : 300,
                            child: ClipOval(
                              child: Image.asset(
                                'assets/images/map_circle.png',
                                fit: BoxFit.cover, // fills the circle
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // =================== LIST OF TEMPLES ===================
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: temples.length,
                      itemBuilder: (context, index) {
                        final temple = temples[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: _TempleCard(
                            title: LanguageHelper.t(
                              temple['titleKey'] as String,
                            ),
                            description: LanguageHelper.t(
                              temple['descriptionKey'] as String,
                            ),
                            imagePath: temple['image'] as String,
                            titleStyle: titleStyle,
                            subtitleStyle: subtitleStyle,
                            onTap: () {
                              // TODO: navigate to temple details
                            },
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TempleCard extends StatelessWidget {
  final String title;
  final String description;
  final String imagePath;
  final TextStyle? titleStyle;
  final TextStyle? subtitleStyle;
  final VoidCallback? onTap;

  const _TempleCard({
    required this.title,
    required this.description,
    required this.imagePath,
    required this.titleStyle,
    required this.subtitleStyle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      elevation: 1.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Text column – Flexible to avoid overflow
              Flexible(
                fit: FlexFit.tight,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: titleStyle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      description,
                      style: subtitleStyle,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    _LearnMoreButton(
                      text: LanguageHelper.t('temple_learn_more'),
                      onTap: (){
                         Navigator.pushNamed(context, '/templeDetail');
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // Image on right
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset(
                  imagePath,
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LearnMoreButton extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;

  const _LearnMoreButton({required this.text, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            colors: [
              Color(0xFFFFA726),
              Color(0xFFFFC107),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.orange.withOpacity(0.3),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
