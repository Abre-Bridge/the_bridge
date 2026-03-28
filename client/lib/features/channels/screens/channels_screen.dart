import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_widgets.dart';
import '../../../core/providers/chat_provider.dart';
import '../../chat/screens/chat_screen.dart';

class ChannelsScreen extends ConsumerWidget {
  const ChannelsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final channelsAsync = ref.watch(channelsProvider);

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Channels',
                  style: Theme.of(context).textTheme.displayMedium,
                ),
                Row(
                  children: [
                    GlassContainer(
                      padding: const EdgeInsets.all(10),
                      borderRadius: 14,
                      child: const Icon(
                        Icons.search_rounded,
                        color: AppTheme.textSecondary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 8),
                    GlassContainer(
                      padding: const EdgeInsets.all(10),
                      borderRadius: 14,
                      onTap: () {},
                      child: const Icon(
                        Icons.add_rounded,
                        color: AppTheme.primaryStart,
                        size: 22,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ).animate().fadeIn(duration: 400.ms),

          const SizedBox(height: 20),

          // Channel list
          Expanded(
            child: channelsAsync.when(
              data: (channels) => ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: channels.length,
                itemBuilder: (context, index) {
                  final channel = channels[index];
                  return _buildChannelTile(context, channel, index);
                },
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error: $err')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChannelTile(
    BuildContext context,
    Map<String, dynamic> channel,
    int index,
  ) {
    final name = channel['name'] ?? 'Untitled';
    final memberCount = channel['_count']?['members'] ?? 0;
    final isPrivate = channel['is_private'] ?? false;
    final color = AppTheme.primaryStart; // Or use a generated color

    return Container(
          margin: const EdgeInsets.only(bottom: 4),
          child: GlassContainer(
            padding: const EdgeInsets.all(14),
            borderRadius: 14,
            color: AppTheme.glassSubtle,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ChatScreen(
                    chatId: channel['id'],
                    name: '#$name',
                    status: '',
                    isChannel: true,
                  ),
                ),
              );
            },
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isPrivate ? Icons.lock_rounded : Icons.tag_rounded,
                    color: color,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$memberCount members',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        )
        .animate()
        .fadeIn(
          duration: 400.ms,
          delay: Duration(milliseconds: 50 * index),
        )
        .slideX(begin: 0.05);
  }
}
