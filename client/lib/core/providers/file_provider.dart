import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crypto/crypto.dart';
import '../services/socket_service.dart';
import 'auth_provider.dart';

final fileProvider = StateNotifierProvider<FileNotifier, FileState>((ref) {
  return FileNotifier(ref.read(socketServiceProvider));
});

class FileState {
  final Map<String, double> transferProgress; // transferId -> progress (0.0 to 1.0)
  final String? error;

  FileState({this.transferProgress = const {}, this.error});

  FileState copyWith({Map<String, double>? transferProgress, String? error}) {
    return FileState(
      transferProgress: transferProgress ?? this.transferProgress,
      error: error,
    );
  }
}

class FileNotifier extends StateNotifier<FileState> {
  final SocketService _socketService;
  static const int _chunkSize = 64 * 1024; // 64KB

  FileNotifier(this._socketService) : super(FileState()) {
    _socketService.connectFileTransfer();
    _setupListeners();
  }

  void _setupListeners() {
    final fileSocket = _socketService.fileSocket;
    if (fileSocket == null) return;

    fileSocket.on('file:progress', (data) {
      final String transferId = data['transferId'];
      final double progress = (data['progress'] as num).toDouble() / 100.0;
      
      final newProgress = Map<String, double>.from(state.transferProgress);
      newProgress[transferId] = progress;
      state = state.copyWith(transferProgress: newProgress);
    });

    fileSocket.on('file:completed', (data) {
      final String transferId = data['transferId'];
      final newProgress = Map<String, double>.from(state.transferProgress);
      newProgress.remove(transferId);
      state = state.copyWith(transferProgress: newProgress);
    });
  }

  Future<void> sendFile(String receiverId) async {
    try {
      final result = await FilePicker.platform.pickFiles();
      if (result == null || result.files.single.path == null) return;

      final file = File(result.files.single.path!);
      final fileName = result.files.single.name;
      final fileSize = await file.length();
      final fileType = result.files.single.extension ?? 'bin';

      // Compute simple hash for integrity
      final bytes = await file.readAsBytes();
      final hash = sha256.convert(bytes).toString();

      _socketService.requestFileTransfer(
        receiverId: receiverId,
        fileName: fileName,
        fileSize: fileSize,
        fileType: fileType,
        fileHash: hash,
        onResponse: (response) {
          if (response['success'] == true) {
            final transferId = response['transfer']['id'];
            _transferFileChunks(file, transferId);
          } else {
            state = state.copyWith(error: response['error']);
          }
        },
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> _transferFileChunks(File file, String transferId) async {
    final bytes = await file.readAsBytes();
    final totalChunks = (bytes.length / _chunkSize).ceil();

    for (int i = 0; i < totalChunks; i++) {
      final start = i * _chunkSize;
      final end = (start + _chunkSize < bytes.length) ? start + _chunkSize : bytes.length;
      final chunk = bytes.sublist(start, end);

      _socketService.sendFileChunk(
        transferId: transferId,
        chunkIndex: i,
        chunkData: chunk.toList(),
        isLast: i == totalChunks - 1,
      );
      
      // Artificial delay to prevent flooding if necessary
      await Future.delayed(const Duration(milliseconds: 50));
    }
  }
}
