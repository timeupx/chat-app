import 'package:flutter/material.dart';

import '../models/video_model.dart';
import '../widgets/video_player_item.dart';

/// TikTok-style vertical video feed. [isActiveTab] tells this screen whether
/// the "Videos" bottom-nav tab is the one currently on screen - since
/// `HomeScreen` keeps every tab alive in an `IndexedStack`, playback must be
/// paused when the user switches to a different tab, not just when they
/// swipe to a different video.
class VideosScreen extends StatefulWidget {
  final bool isActiveTab;

  const VideosScreen({super.key, this.isActiveTab = true});

  @override
  State<VideosScreen> createState() => _VideosScreenState();
}

class _VideosScreenState extends State<VideosScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final videos = VideoModel.mockVideos;

    // IndexedStack keeps this tab mounted even when hidden. Don't build
    // network video players until the Videos tab is actually visible —
    // otherwise unsupported codecs on web can spam console / flash white.
    if (!widget.isActiveTab) {
      return const Scaffold(backgroundColor: Colors.black);
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        itemCount: videos.length,
        onPageChanged: (index) => setState(() => _currentPage = index),
        itemBuilder: (context, index) {
          final isPageActive = widget.isActiveTab && index == _currentPage;
          return VideoPlayerItem(
            key: ValueKey(videos[index].id),
            video: videos[index],
            isActive: isPageActive,
          );
        },
      ),
    );
  }
}
