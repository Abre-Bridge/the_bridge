import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../../core/providers/meeting_provider.dart';

class MeetingsScreen extends ConsumerWidget {
  const MeetingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meeting = ref.watch(meetingProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Meetings')),
      body: meeting.isJoined 
        ? _buildRoom(context, ref, meeting)
        : Center(
            child: ElevatedButton(
              onPressed: () => ref.read(meetingProvider.notifier).joinMeeting('test-room'),
              child: const Text('Join Test Meeting'),
            ),
          ),
    );
  }

  Widget _buildRoom(BuildContext context, WidgetRef ref, MeetingState state) {
    return Column(
      children: [
        Expanded(
          child: GridView.count(
            crossAxisCount: 2,
            children: [
              RTCVideoView(state.localRenderer, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover),
              ...state.remoteRenderers.values.map((r) => RTCVideoView(r, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              CircleAvatar(backgroundColor: Colors.red, child: IconButton(icon: const Icon(Icons.call_end), onPressed: () => ref.read(meetingProvider.notifier).leave())),
            ],
          ),
        )
      ],
    );
  }
}
