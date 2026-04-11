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
    final activeMeetings = ref.watch(activeMeetingsProvider);

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async {
          await ref.read(activeMeetingsProvider.notifier).refresh();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
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

            // Active meeting cards
            if (activeMeetings.isEmpty)
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
              ).animate().fadeIn(duration: 500.ms, delay: 300.ms).slideY(begin: 0.1)
            else
              SizedBox(
                height: 120,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: activeMeetings.length,
                  itemBuilder: (context, index) {
                    final meeting = activeMeetings[index];
                    return Container(
                      width: 280,
                      margin: const EdgeInsets.only(right: 12),
                      child: GlassContainer(
                        padding: const EdgeInsets.all(16),
                        borderRadius: 16,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: AppTheme.success,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    meeting['title'] ?? 'Meeting',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Room ID: ${meeting['id']}',
                              style: const TextStyle(
                                color: AppTheme.textMuted,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${meeting['participantCount']} participants',
                              style: const TextStyle(
                                color: AppTheme.textMuted,
                                fontSize: 12,
                              ),
                            ),
                            const Spacer(),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () => ref.read(meetingStateProvider.notifier).joinMeeting(meeting['id']),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryStart,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text('Join Meeting', style: TextStyle(fontSize: 12)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
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
        ),
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

  Widget _buildQuickAction({
    required IconData icon,
    required String label,
    required List<Color> gradient,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: gradient.last.withOpacity(0.25),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 30),
            const SizedBox(height: 14),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
            ),
          ],
        ),
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
        // Meeting controls
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.darkCard.withValues(alpha: 0.9),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildControlButton(
                icon: state.isAudioOn ? Icons.mic : Icons.mic_off,
                label: state.isAudioOn ? 'Mute' : 'Unmute',
                color: state.isAudioOn ? AppTheme.success : AppTheme.error,
                onPressed: () {
                  ref.read(meetingStateProvider.notifier).toggleAudio();
                },
              ),
              _buildControlButton(
                icon: state.isVideoOn ? Icons.videocam : Icons.videocam_off,
                label: state.isVideoOn ? 'Stop Video' : 'Start Video',
                color: state.isVideoOn ? AppTheme.success : AppTheme.error,
                onPressed: () {
                  ref.read(meetingStateProvider.notifier).toggleVideo();
                },
              ),
              _buildControlButton(
                icon: Icons.call_end,
                label: 'Leave',
                color: AppTheme.error,
                onPressed: () {
                  ref.read(meetingStateProvider.notifier).leaveMeeting();
                },
              ),
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

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: IconButton(
            onPressed: onPressed,
            icon: Icon(icon, color: color, size: 28),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

}
