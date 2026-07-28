import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/live_room_service.dart';
import '../theme/bigo_theme.dart';
import '../utils/jwt_helper.dart';
import '../utils/secure_storage_helper.dart';
import 'chat_screen.dart';
import 'contacts_screen.dart';
import 'create_live_room_screen.dart';
import 'live_room_list_screen.dart';
import 'live_room_screen.dart';
import 'profile_screen.dart';
import 'videos_screen.dart';

/// Neon Night app shell: charcoal stage, cyan selection, coral Go Live.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _videosTabIndex = 2;

  final _liveRoomService = LiveRoomService();
  int _selectedIndex = 0;
  bool _openingGoLive = false;

  /// One room per user: resume existing host room, otherwise open create.
  Future<void> _openGoLive() async {
    if (_openingGoLive) return;
    setState(() => _openingGoLive = true);
    try {
      final token = await SecureStorageHelper.getToken();
      final String? userId = token == null
          ? null
          : decodeJwtPayload(token)?['userId'] as String?;

      if (userId != null && userId.isNotEmpty) {
        final rooms = await _liveRoomService.listRooms();
        for (final room in rooms) {
          if (room.hostId != userId) continue;
          if (!room.isLive) {
            await _liveRoomService.goLive(room.id);
          }
          if (!mounted) return;
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => LiveRoomScreen(
                roomName: room.id,
                role: LiveRoomRole.host,
                initialFilterName: room.filterName,
                initialSlotCount: room.slotCount,
              ),
            ),
          );
          return;
        }
      }

      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const CreateLiveRoomScreen()),
      );
    } on LiveRoomException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } finally {
      if (mounted) setState(() => _openingGoLive = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BigoColors.bg,
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          const LiveRoomListScreen(),
          const ChatScreen(),
          VideosScreen(isActiveTab: _selectedIndex == _videosTabIndex),
          const ContactsScreen(),
          const ProfileScreen(),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: _GoLiveFab(
        busy: _openingGoLive,
        onTap: _openGoLive,
      ),
      bottomNavigationBar: _NeonBottomBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
      ),
    );
  }
}

class _GoLiveFab extends StatefulWidget {
  final VoidCallback onTap;
  final bool busy;

  const _GoLiveFab({required this.onTap, this.busy = false});

  @override
  State<_GoLiveFab> createState() => _GoLiveFabState();
}

class _GoLiveFabState extends State<_GoLiveFab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_pulse.value);
        return Transform.scale(
          scale: 1.0 + (t * 0.04),
          child: child,
        );
      },
      child: GestureDetector(
        onTap: widget.busy ? null : widget.onTap,
        child: Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: BigoColors.ctaGradient,
            boxShadow: [
              BoxShadow(
                color: BigoColors.hot.withValues(alpha: 0.4),
                blurRadius: 22,
                offset: const Offset(0, 6),
              ),
            ],
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.28),
              width: 2,
            ),
          ),
          child: widget.busy
              ? const Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: Colors.white,
                    ),
                  ),
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.sensors, color: Colors.white, size: 22),
                    Text(
                      'LIVE',
                      style: GoogleFonts.spaceGrotesk(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _NeonBottomBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _NeonBottomBar({
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: BigoColors.bgElevated.withValues(alpha: 0.96),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              _navItem(0, Icons.live_tv_rounded, 'Live'),
              _navItem(1, Icons.chat_bubble_outline_rounded, 'Chat'),
              const SizedBox(width: 76),
              _navItem(2, Icons.auto_awesome_rounded, 'Party'),
              _navItem(4, Icons.person_outline_rounded, 'Me'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData icon, String label) {
    final selected = currentIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () => onTap(index),
        splashColor: BigoColors.primary.withValues(alpha: 0.12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: selected
                    ? BigoColors.primary.withValues(alpha: 0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 22,
                color: selected ? BigoColors.primary : Colors.white54,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? BigoColors.primary : Colors.white54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
