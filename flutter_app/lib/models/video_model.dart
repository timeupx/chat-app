/// A single short-form video shown in the Videos (TikTok-style) feed.
class VideoModel {
  final String id;
  final String videoUrl;
  final String username;
  final String caption;
  final String songName;
  final int likes;
  final int comments;
  final bool isLiked;

  const VideoModel({
    required this.id,
    required this.videoUrl,
    required this.username,
    required this.caption,
    required this.songName,
    this.likes = 0,
    this.comments = 0,
    this.isLiked = false,
  });

  /// Public sample MP4s (Google's test video bucket) used as mock data.
  static const List<VideoModel> mockVideos = [
    VideoModel(
      id: '1',
      videoUrl:
          'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
      username: '@bunny_official',
      caption: 'Just another day in the meadow 🐰',
      songName: 'Original sound - Big Buck Bunny',
      likes: 12500,
      comments: 342,
    ),
    VideoModel(
      id: '2',
      videoUrl:
          'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4',
      username: '@dream_studio',
      caption: 'Chasing dreams through the machine ⚙️',
      songName: 'Elephants Dream - Score',
      likes: 8420,
      comments: 210,
    ),
    VideoModel(
      id: '3',
      videoUrl:
          'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4',
      username: '@blaze.it',
      caption: 'Bigger blazes, bigger vibes 🔥',
      songName: 'For Bigger Blazes - Theme',
      likes: 45200,
      comments: 1893,
    ),
    VideoModel(
      id: '4',
      videoUrl:
          'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerEscapes.mp4',
      username: '@escape.plans',
      caption: 'Weekend escape plans loading... ✈️',
      songName: 'For Bigger Escapes - Cut',
      likes: 6721,
      comments: 98,
    ),
    VideoModel(
      id: '5',
      videoUrl:
          'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerFun.mp4',
      username: '@funhouse',
      caption: 'This is why we can\'t have nice things 😂',
      songName: 'For Bigger Fun - Remix',
      likes: 98110,
      comments: 5023,
      isLiked: true,
    ),
    VideoModel(
      id: '6',
      videoUrl:
          'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerJoyrides.mp4',
      username: '@joyride',
      caption: 'Sunday joyride with the crew 🚗💨',
      songName: 'For Bigger Joyrides - Extended',
      likes: 15300,
      comments: 421,
    ),
  ];
}
