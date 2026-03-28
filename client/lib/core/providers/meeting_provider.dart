import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../services/socket_service.dart';
import 'auth_provider.dart';

final meetingStateProvider = StateNotifierProvider<MeetingNotifier, MeetingState>((ref) {
  return MeetingNotifier(ref.read(socketServiceProvider), ref);
});

class MeetingState {
  final bool isJoined;
  final String? roomId;
  final RTCVideoRenderer localRenderer;
  final Map<String, RTCVideoRenderer> remoteRenderers;
  final List<dynamic> participants;
  final bool isAudioOn;
  final bool isVideoOn;
  final String? error;

  MeetingState({
    this.isJoined = false,
    this.roomId,
    required this.localRenderer,
    this.remoteRenderers = const {},
    this.participants = const [],
    this.isAudioOn = true,
    this.isVideoOn = true,
    this.error,
  });

  MeetingState copyWith({
    bool? isJoined,
    String? roomId,
    Map<String, RTCVideoRenderer>? remoteRenderers,
    List<dynamic>? participants,
    bool? isAudioOn,
    bool? isVideoOn,
    String? error,
    bool clearError = false,
  }) {
    return MeetingState(
      isJoined: isJoined ?? this.isJoined,
      roomId: roomId ?? this.roomId,
      localRenderer: localRenderer,
      remoteRenderers: remoteRenderers ?? this.remoteRenderers,
      participants: participants ?? this.participants,
      isAudioOn: isAudioOn ?? this.isAudioOn,
      isVideoOn: isVideoOn ?? this.isVideoOn,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class MeetingNotifier extends StateNotifier<MeetingState> {
  final SocketService _socketService;
  final Ref _ref;
  MediaStream? _localStream;
  final Map<String, RTCPeerConnection> _peerConnections = {};

  MeetingNotifier(this._socketService, this._ref)
      : super(MeetingState(localRenderer: RTCVideoRenderer())) {
    _initRenderers();
  }

  Future<void> _initRenderers() async {
    await state.localRenderer.initialize();
  }

  Future<void> joinMeeting(String roomId) async {
    state = state.copyWith(clearError: true);
    try {
      _socketService.connectSignaling();
      final signalingSocket = _socketService.signalingSocket;

      if (signalingSocket == null) {
        throw Exception('Signaling socket not connected');
      }

      // Initialize local stream
      _localStream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': {
          'facingMode': 'user',
          'width': 640,
          'height': 480,
        },
      });

      state.localRenderer.srcObject = _localStream;

      signalingSocket.emitWithAck('room:join', {'roomId': roomId}, ack: (data) {
        if (data['success'] == true) {
          final iceServers = (data['iceServers'] as List)
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
          
          state = state.copyWith(
            isJoined: true,
            roomId: roomId,
            participants: data['participants'],
          );

          _setupSignalingListeners(signalingSocket, iceServers);
          _connectToPeers(data['participants'], iceServers);
        } else {
          state = state.copyWith(error: data['error']);
        }
      });
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  void _setupSignalingListeners(dynamic socket, List<Map<String, dynamic>> iceServers) {
    socket.on('signal:offer', (data) async {
      final String fromUserId = data['fromUserId'];
      final dynamic offer = data['offer'];
      
      final pc = await _getOrCreatePeerConnection(fromUserId, iceServers);
      await pc.setRemoteDescription(RTCSessionDescription(offer['sdp'], offer['type']));
      
      final answer = await pc.createAnswer();
      await pc.setLocalDescription(answer);
      
      socket.emit('signal:answer', {
        'targetUserId': fromUserId,
        'answer': {'sdp': answer.sdp, 'type': answer.type},
      });
    });

    socket.on('signal:answer', (data) async {
      final String fromUserId = data['fromUserId'];
      final dynamic answer = data['answer'];
      final pc = _peerConnections[fromUserId];
      if (pc != null) {
        await pc.setRemoteDescription(RTCSessionDescription(answer['sdp'], answer['type']));
      }
    });

    socket.on('signal:ice_candidate', (data) async {
      final String fromUserId = data['fromUserId'];
      final dynamic candidate = data['candidate'];
      final pc = _peerConnections[fromUserId];
      if (pc != null) {
        await pc.addCandidate(RTCIceCandidate(
          candidate['candidate'],
          candidate['sdpMid'],
          candidate['sdpMLineIndex'],
        ));
      }
    });

    socket.on('room:peer_joined', (data) {
      state = state.copyWith(participants: data['participants']);
    });

    socket.on('room:peer_left', (data) {
      final String userId = data['userId'];
      _removePeer(userId);
      state = state.copyWith(participants: data['participants']);
    });
  }

  Future<void> _connectToPeers(List<dynamic> participants, List<Map<String, dynamic>> iceServers) async {
    final myId = _ref.read(authProvider).user?['id'];
    for (var p in participants) {
      final userId = p['userId'];
      if (userId != myId) {
        final pc = await _getOrCreatePeerConnection(userId, iceServers);
        final offer = await pc.createOffer();
        await pc.setLocalDescription(offer);
        
        _socketService.signalingSocket?.emit('signal:offer', {
          'targetUserId': userId,
          'offer': {'sdp': offer.sdp, 'type': offer.type},
        });
      }
    }
  }

  Future<RTCPeerConnection> _getOrCreatePeerConnection(String userId, List<Map<String, dynamic>> iceServers) async {
    if (_peerConnections.containsKey(userId)) {
      return _peerConnections[userId]!;
    }

    final pc = await createPeerConnection({
      'iceServers': iceServers,
      'sdpSemantics': 'unified-plan',
    });

    _peerConnections[userId] = pc;

    _localStream?.getTracks().forEach((track) {
      pc.addTrack(track, _localStream!);
    });

    pc.onIceCandidate = (candidate) {
      _socketService.signalingSocket?.emit('signal:ice_candidate', {
        'targetUserId': userId,
        'candidate': {
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        },
      });
    };

    pc.onTrack = (event) {
      if (event.track.kind == 'video') {
        final remoteRenderer = RTCVideoRenderer();
        remoteRenderer.initialize().then((_) {
          remoteRenderer.srcObject = event.streams[0];
          final newRenderers = Map<String, RTCVideoRenderer>.from(state.remoteRenderers);
          newRenderers[userId] = remoteRenderer;
          state = state.copyWith(remoteRenderers: newRenderers);
        });
      }
    };

    return pc;
  }

  void _removePeer(String userId) {
    _peerConnections[userId]?.close();
    _peerConnections.remove(userId);
    
    final newRenderers = Map<String, RTCVideoRenderer>.from(state.remoteRenderers);
    newRenderers[userId]?.dispose();
    newRenderers.remove(userId);
    state = state.copyWith(remoteRenderers: newRenderers);
  }

  Future<void> leaveMeeting() async {
    _socketService.signalingSocket?.emit('room:leave');
    _localStream?.getTracks().forEach((track) => track.stop());
    _localStream = null;
    state.localRenderer.srcObject = null;
    
    for (var pc in _peerConnections.values) {
      pc.close();
    }
    _peerConnections.clear();
    
    for (var renderer in state.remoteRenderers.values) {
      renderer.dispose();
    }
    
    state = state.copyWith(isJoined: false, remoteRenderers: {}, participants: []);
    _socketService.disconnectSignaling();
  }

  @override
  void dispose() {
    leaveMeeting();
    state.localRenderer.dispose();
    super.dispose();
  }
}
