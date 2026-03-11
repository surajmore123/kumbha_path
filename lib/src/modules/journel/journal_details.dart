import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kumbha_path/main_layout.dart';
import 'package:kumbha_path/src/bloc/app_details_bloc/app_details_bloc.dart'
    show AppDetailsBloc;
import 'package:kumbha_path/src/bloc/app_details_bloc/app_details_state.dart';
import 'package:kumbha_path/src/constant/api_constatnt.dart';
import 'package:kumbha_path/src/constant/app_color.dart';
import 'package:kumbha_path/src/constant/app_responsive.dart';
import 'package:kumbha_path/src/constant/time_formator.dart';

class JournalDetails extends StatefulWidget {
  const JournalDetails({super.key});

  @override
  State<JournalDetails> createState() => _JournalDetailsState();
}

class _JournalDetailsState extends State<JournalDetails> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final isMobile = context.isMobile;
    final isTablet = context.isTablet;
    final isDesktop = context.isDesktop;
    final Map<String, String> moodEmoji = {
      "peaceful": "🙏",
      "joyful": "😊",
      "enlightened": "✨",
      "reflective": "🤔",
      "emotional": "😢",
    };
    return MainLayout(
      showDefaultBottom: false,
      ctx: 3,
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: blackColor),
        title: Text(
          "Journal Entry",
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        // actions: [
        //   Padding(
        //     padding: const EdgeInsets.only(right: 12),
        //     child: CircleAvatar(
        //       backgroundColor: Colors.orange.shade100,
        //       child: Icon(Icons.edit, color: Colors.orange.shade700),
        //     ),
        //   ),
        // ],
      ),

      body: BlocConsumer<AppDetailsBloc, AppDetailsState>(
        listener: (context, state) {},
        builder: (context, state) {
          final journalData = state.journalDetailsModel;
          final moodValue = journalData!.mood?.toLowerCase() ?? "";
          final emoji = moodEmoji[moodValue] ?? "🙂";
          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal:
                  isMobile
                      ? 16
                      : isTablet
                      ? 32
                      : 56,
              vertical: isMobile ? 16 : 24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                journalData!.photo!.isNotEmpty
                    ? ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(
                        '${journalData.photo}',
                        height: isMobile ? 220 : 320,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    )
                    : SizedBox.shrink(),

                const SizedBox(height: 18),

                /// Date & Time
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today,
                      size: 16,
                      color: Colors.orange,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      DateTimeHelper.formatAlertTime(
                        journalData.createdAt.toString(),
                      ),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.orange,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                /// Title
                Text(
                  journalData.title.toString(),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    height: 1.3,
                  ),
                ),

                const SizedBox(height: 14),

                /// Mood Chip
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.orange.shade200),
                    color: Colors.orange.shade50,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(emoji, style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 6),
                      Text(
                        journalData.mood.toString(),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.orange.shade800,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 22),

                journalData.aiPrompt!.isNotEmpty
                    ? Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cs.surfaceVariant.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.lightbulb_outline, size: 18),
                              const SizedBox(width: 6),
                              Text(
                                "Daily Prompt",
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            journalData.aiPrompt.toString(),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontStyle: FontStyle.italic,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    )
                    : SizedBox.shrink(),

                const SizedBox(height: 22),

                /// Journal Content
                Text(
                  journalData.notes.toString(),
                  style: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
                ),

                const SizedBox(height: 28),

                journalData.aiReflection!.isNotEmpty
                    ? Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: Colors.orange.shade50,
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.auto_awesome,
                                color: Colors.orange,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                "AI Guru Reflection",
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          Text(
                            journalData.aiReflection.toString(),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              height: 1.6,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    )
                    : SizedBox.shrink(),

                const SizedBox(height: 30),
              ],
            ),
          );
        },
      ),
    );
  }
}
