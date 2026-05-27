import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'auth_provider.dart';
import 'chat_provider.dart';

final fileProvider = Provider((ref) => FileHandler(ref));

class FileHandler {
  final Ref _ref;
  FileHandler(this._ref);

  Future<void> sendFile(String chatId, bool isChannel) async {
    final result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.single.path == null) return;

    final file = result.files.single;
    final api = _ref.read(apiServiceProvider);
    
    try {
      final uploadRes = await api.uploadFile(
        file.path!, 
        file.name, 
        _getContentType(file.extension ?? '')
      );

      final fileInfo = {
        'url': uploadRes['file']['url'],
        'name': uploadRes['file']['name'],
        'size': uploadRes['file']['size'],
        'type': uploadRes['file']['type'],
      };

      _ref.read(chatMessagesProvider({'chatId': chatId, 'isChannel': isChannel}).notifier)
         .sendMessage('', type: 'file', fileInfo: fileInfo);
         
    } catch (e) {
      print('File upload error: $e');
    }
  }

  String _getContentType(String ext) {
    switch (ext.toLowerCase()) {
      case 'jpg': case 'jpeg': return 'image/jpeg';
      case 'png': return 'image/png';
      case 'pdf': return 'application/pdf';
      default: return 'application/octet-stream';
    }
  }
}
