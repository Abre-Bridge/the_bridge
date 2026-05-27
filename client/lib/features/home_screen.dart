import 'package:flutter/material.dart';
import 'chat/screens/chat_list_screen.dart';
import 'channels/screens/channels_screen.dart';
import 'meetings/screens/meetings_screen.dart';
import 'settings/screens/settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _idx = 0;
  final _screens = [const ChatListScreen(), const ChannelsScreen(), const MeetingsScreen(), const SettingsScreen()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_idx],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _idx,
        onTap: (i) => setState(() => _idx = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chats'),
          BottomNavigationBarItem(icon: Icon(Icons.tag), label: 'Channels'),
          BottomNavigationBarItem(icon: Icon(Icons.videocam), label: 'Meetings'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}
