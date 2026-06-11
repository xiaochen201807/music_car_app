import 'package:flutter/foundation.dart';
import 'package:flutter_carplay/flutter_carplay.dart';
import '../music_audio_handler.dart';
import '../native_audio_controller.dart';

class CarPlayService {
  CarPlayService(this._audioHandler, this._nativeAudioController);

  final MusicAudioHandler _audioHandler;
  final NativeAudioController _nativeAudioController;

  CPTabBarTemplate? _rootTemplate;

  Future<void> init() async {
    try {
      _rootTemplate = _buildRootTemplate();
      await FlutterCarplay.setRootTemplate(
        rootTemplate: _rootTemplate!,
        animated: false,
      );
      debugPrint('[carplay] Initialized');
    } catch (e) {
      debugPrint('[carplay] Init failed: $e');
    }
  }

  CPTabBarTemplate _buildRootTemplate() {
    return CPTabBarTemplate(
      templates: [
        _buildNowPlayingTemplate(),
        _buildLibraryTemplate(),
      ],
    );
  }

  CPListTemplate _buildNowPlayingTemplate() {
    return CPListTemplate(
      sections: [
        CPListSection(
          items: [
            CPListItem(
              text: '正在播放',
              detailText: '查看播放队列',
              onPress: (complete, self) {
                complete();
              },
            ),
          ],
        ),
      ],
      title: '播放中',
      systemIcon: 'play.circle.fill',
      showsTabBadge: false,
    );
  }

  CPListTemplate _buildLibraryTemplate() {
    return CPListTemplate(
      sections: [
        CPListSection(
          items: [
            CPListItem(
              text: '我的收藏',
              detailText: '收藏的歌曲',
              onPress: (complete, self) {
                complete();
              },
            ),
          ],
        ),
      ],
      title: '音乐库',
      systemIcon: 'music.note.list',
      showsTabBadge: false,
    );
  }

  void dispose() {
    debugPrint('[carplay] Disposed');
  }
}
