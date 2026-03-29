import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/meeting_provider.dart';
import '../../../core/widgets/glass_widgets.dart';

class MeetingsScreen extends ConsumerStatefulWidget {
  const MeetingsScreen({super.key});

  @override
  ConsumerState<MeetingsScreen> createState() => _MeetingsScreenState();
}

class _MeetingsScreenState extends ConsumerState<MeetingsScreen> {

  @override
  Widget build(BuildContext context) {
    final meetingState = ref.watch(meetingStateProvider);

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
                  'Meetings',
                  style: Theme.of(context).textTheme.displayMedium,
                ),
                if (meetingState.isJoined)
                  IconButton(
                    onPressed: () => ref.read(meetingStateProvider.notifier).leaveMeeting(),
                    icon: const Icon(Icons.call_end_rounded, color: AppTheme.busy),
                    style: IconButton.styleFrom(
                      backgroundColor: AppTheme.busy.withValues(alpha: 0.1),
                    ),
                  ),
              ],
            ),
          ).animate().fadeIn(duration: 400.ms),

          const SizedBox(height: 20),

          if (meetingState.isJoined)
             Expanded(child: _buildMeetingRoom(meetingState))
          else ...[
            // Quick actions
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: _buildQuickAction(
                      icon: Icons.videocam_rounded,
                      label: 'Start\nMeeting',
                      gradient: [AppTheme.primaryStart, AppTheme.primaryEnd],
                      onTap: () => _handleStartMeeting(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildQuickAction(
                      icon: Icons.add_link_rounded,
                      label: 'Join\nMeeting',
                      gradient: [AppTheme.accentCyan, AppTheme.accentTeal],
                      onTap: () => _handleJoinMeeting(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildQuickAction(
                      icon: Icons.schedule_rounded,
                      label: 'Schedule\nMeeting',
                      gradient: [
                        const Color(0xFFF59E0B),
                        const Color(0xFFEF4444),
                      ],
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Meeting Scheduling coming soon!')),
                        );
                      },
                    ),
                  ),
                ],
              ),
            )
            .animate()
            .fadeIn(duration: 500.ms, delay: 200.ms)
            .slideY(begin: 0.1),

            const SizedBox(height: 24),

            const SizedBox(height: 24),

            // Active meetings
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppTheme.busy,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.busy.withValues(alpha: 0.6),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'ACTIVE NOW',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textMuted,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Active meeting card placeholder
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GlassContainer(
                padding: const EdgeInsets.all(20),
                borderRadius: 20,
                child: const Center(
                  child: Text(
                    'No active meetings to join.',
                    style: TextStyle(color: AppTheme.textMuted),
                  ),
                ),
              ),
            ).animate().fadeIn(duration: 500.ms, delay: 300.ms).slideY(begin: 0.1),

            const SizedBox(height: 24),

            // Upcoming
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'UPCOMING',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textMuted,
                  letterSpacing: 1.2,
                ),
              ),
            ),

            const SizedBox(height: 12),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GlassContainer(
                  padding: const EdgeInsets.all(20),
                  borderRadius: 20,
                  child: const Center(
                    child: Text(
                      'No upcoming meetings scheduled.',
                      style: TextStyle(color: AppTheme.textMuted),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _handleStartMeeting() {
    final roomId = DateTime.now().millisecondsSinceEpoch.toString().substring(7);
    ref.read(meetingStateProvider.notifier).joinMeeting(roomId);
  }

  void _handleJoinMeeting() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkCard,
        title: const Text('Join Meeting'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Enter Room ID'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                ref.read(meetingStateProvider.notifier).joinMeeting(controller.text);
                Navigator.pop(context);
              }
            },
            child: const Text('Join'),
          ),
        ],
      ),
    );
  }

  Widget _buildMeetingRoom(MeetingState state) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Room ID: ${state.roomId}', style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        Expanded(
          child: GridView.count(
            crossAxisCount: 2,
            children: [
              // Local video
              _buildVideoTile(state.localRenderer, 'Me (Local)'),
              // Remote videos
              ...state.remoteRenderers.entries.map((e) {
                return _buildVideoTile(e.value, 'User ${e.key.substring(0, 4)}');
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVideoTile(RTCVideoRenderer renderer, String label) {
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.glassBorder),
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: RTCVideoView(renderer, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover),
          ),
          Positioned(
            bottom: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)),
              child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 10)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAction({
    required IconData icon,
    required String label,
    required List<Color> gradient,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              gradient[0].withValues(alpha: 0.15),
              gradient[1].withValues(alpha: 0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: gradient[0].withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: gradient),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: gradient[0].withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

}
