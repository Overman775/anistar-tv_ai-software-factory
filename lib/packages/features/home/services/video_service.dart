import '../models/video_model.dart';

/// Service for managing videos
class VideoService {
  /// Get a list of demo videos
  List<VideoModel> getVideos() {
    // In a real app, this would fetch from an API
    return [
      VideoModel(
        id: '1',
        title: 'Big Buck Bunny',
        description:
            'Big Buck Bunny tells the story of a giant rabbit with a heart bigger than himself.',
        thumbnailUrl: 'assets/images/big_buck_bunny.jpg',
        videoUrl:
            'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
        duration: const Duration(minutes: 9, seconds: 56),
        category: 'Animation',
      ),
      VideoModel(
        id: '2',
        title: 'Elephant Dream',
        description: 'The first Blender Open Movie from 2006.',
        thumbnailUrl: 'assets/images/elephant_dream.jpg',
        videoUrl:
            'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4',
        duration: const Duration(minutes: 10, seconds: 53),
        category: 'Animation',
      ),
      VideoModel(
        id: '3',
        title: 'Sintel',
        description: 'Sintel is a fantasy computer animated short film.',
        thumbnailUrl: 'assets/images/sintel.jpg',
        videoUrl:
            'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/Sintel.mp4',
        duration: const Duration(minutes: 14, seconds: 48),
        category: 'Animation',
      ),
      VideoModel(
        id: '4',
        title: 'Tears of Steel',
        description:
            'Tears of Steel was realized with crowd-funding by users of the open source 3D creation tool Blender.',
        thumbnailUrl: 'assets/images/tears_of_steel.jpg',
        videoUrl:
            'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/TearsOfSteel.mp4',
        duration: const Duration(minutes: 12, seconds: 14),
        category: 'Sci-Fi',
      ),
    ];
  }

  /// Get a video by ID
  VideoModel? getVideoById(String id) {
    final videos = getVideos();
    try {
      return videos.firstWhere((video) => video.id == id);
    } catch (e) {
      return null;
    }
  }
}
