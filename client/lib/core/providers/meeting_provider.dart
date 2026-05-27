import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'auth_provider.dart';

class MeetingState {
  final bool isJoined;
  final String? roomId;
  final RTCVideoRenderer localRenderer;
  final Map<String, RTCVideoRenderer> remoteRenderers;

  MeetingState({
    this.isJoined = false, 
    this.roomId, 
    required this.localRenderer, 
    this.remoteRenderers = const {}
  });

  MeetingState copyWith({bool? isJoined, String? roomId, Map<String, RTCVideoRenderer>? remoteRenderers}) {
    return MeetingState(
      isJoined: isJoined ?? this.isJoined,
      roomId: roomId ?? this.roomId,
      localRenderer: localRenderer,
      remoteRenderers: remoteRenderers ?? this.remoteRenderers,
    );
  }
}

final meetingProvider = StateNotifierProvider<MeetingNotifier, MeetingState>((ref) => MeetingNotifier(ref));

class MeetingNotifier extends StateNotifier<MeetingState> {
  final Ref _ref;
  MediaStream? _localStream;
  final Map<String, RTCPeerConnection> _pcs = {};

  MeetingNotifier(this._ref) : super(MeetingState(localRenderer: RTCVideoRenderer())) {
    state.localRenderer.initialize();
  }

  Future<void> joinMeeting(String roomId) async {
    final socket = _ref.read(socketServiceProvider);
    
    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': true, 'video': {'facingMode': 'user'}
    });
    state.localRenderer.srcObject = _localStream;

    socket.on('signal:offer', (data) async => _handleOffer(data));
    socket.on('signal:answer', (data) => _handleAnswer(data));
    socket.on('signal:ice_candidate', (data) => _handleIce(data));

    socket.emit('room:join', {'roomId': roomId});
    state = state.copyWith(isJoined: true, roomId: roomId);
  }

  Future<void> _handleOffer(dynamic data) async {
    final pc = await _createPC(data['fromUserId']);
    await pc.setRemoteDescription(RTCSessionDescription(data['offer']['sdp'], data['offer']['type']));
    final answer = await pc.createAnswer();
    await pc.setLocalDescription(answer);
    _ref.read(socketServiceProvider).emit('signal:answer', {
      'targetUserId': data['fromUserId'], 
      'answer': {'sdp': answer.sdp, 'type': answer.type}
    });
  }

  void _handleAnswer(dynamic data) {
    _pcs[data['fromUserId']]?.setRemoteDescription(RTCSessionDescription(data['answer']['sdp'], data['answer']['type']));
  }

  void _handleIce(dynamic data) {
    _pcs[data['fromUserId']]?.addCandidate(RTCIceCandidate(data['candidate']['candidate'], data['candidate']['sdpMid'], data['candidate']['sdpMLineIndex']));
  }

  Future<RTCPeerConnection> _createPC(String userId) async {
    final pc = await createPeerConnection({'iceServers': [{'urls': 'stun:stun.l.google.com:19302'}]});
    _pcs[userId] = pc;
    _localStream?.getTracks().forEach((t) => pc.addTrack(t, _localStream!));
    pc.onIceCandidate = (c) => _ref.read(socketServiceProvider).emit('signal:ice_candidate', {
      'targetUserId': userId, 'candidate': {'candidate': c.candidate, 'sdpMid': c.sdpMid, 'sdpMLineIndex': c.sdpMLineIndex}
    });
    pc.onTrack = (e) {
      if (e.track.kind == 'video') {
        final render = RTCVideoRenderer();
        render.initialize().then((_) {
          render.srcObject = e.streams[0];
          state = state.copyWith(remoteRenderers: {...state.remoteRenderers, userId: render});
        });
      }
    };
    return pc;
  }

  void leave() {
    _localStream?.getTracks().forEach((t) => t.stop());
    _pcs.values.forEach((pc) => pc.close());
    _pcs.clear();
    state = state.copyWith(isJoined: false, remoteRenderers: {});
  }
}
