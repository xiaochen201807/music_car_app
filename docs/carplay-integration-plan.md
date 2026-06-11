# CarPlay 接入实施方案

## 项目背景

- **目标**：为车载音乐 App 添加 CarPlay 支持
- **场景**：自用，无 Apple 开发者账号
- **构建方式**：GitHub Actions 打包 unsigned IPA
- **安装方式**：Sideloadly/AltStore 等侧载工具

## 技术方案

### 方案选择

使用 **flutter_carplay** 插件（推荐）：
- ✅ 成熟开源，活跃维护
- ✅ 支持 CarPlay 标准模板（List、Tab Bar、Now Playing）
- ✅ 与 audio_service 集成良好
- ✅ 单代码库，开发效率高

### 替代方案对比

| 方案 | 优点 | 缺点 |
|------|------|------|
| flutter_carplay | Flutter 生态，开发快 | 需原生配置 |
| 纯原生 Swift | 完全控制 | 开发量大，需维护两套代码 |
| React Native CarPlay | 跨平台 | 不适合现有 Flutter 项目 |

## 实施步骤

### 第一阶段：环境准备

#### 1.1 添加 flutter_carplay 依赖

```yaml
# pubspec.yaml
dependencies:
  flutter_carplay: ^1.6.0  # 检查最新版本
```

#### 1.2 创建 Entitlements 文件

```bash
# 创建文件
touch ios/Runner/Runner.entitlements
```

```xml
<!-- ios/Runner/Runner.entitlements -->
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.developer.carplay-audio</key>
    <true/>
</dict>
</plist>
```

#### 1.3 更新 Info.plist

```xml
<!-- ios/Runner/Info.plist -->
<!-- 在现有 <dict> 内添加 -->

<!-- CarPlay 场景配置 -->
<key>UIApplicationSceneManifest</key>
<dict>
    <key>UIApplicationSupportsMultipleScenes</key>
    <true/>
    <key>UISceneConfigurations</key>
    <dict>
        <!-- 现有的 UIWindowSceneSessionRoleApplication 保持不变 -->
        
        <!-- 添加 CarPlay 场景 -->
        <key>CPTemplateApplicationSceneSessionRoleApplication</key>
        <array>
            <dict>
                <key>UISceneConfigurationName</key>
                <string>CarPlay</string>
                <key>UISceneDelegateClassName</key>
                <string>$(PRODUCT_MODULE_NAME).CarPlaySceneDelegate</string>
            </dict>
        </array>
    </dict>
</dict>

<!-- 后台音频模式（已有，确认包含 audio） -->
<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
</array>
```

#### 1.4 配置 Xcode 项目

```bash
# 在 Xcode 中打开项目
open ios/Runner.xcworkspace
```

**手动配置步骤**：
1. 选择 Runner target
2. Signing & Capabilities
3. 点击 "+ Capability"
4. 添加 "CarPlay Audio App"（如果可用）
5. Build Settings → Code Signing Entitlements → 设置为 `Runner/Runner.entitlements`

### 第二阶段：Flutter 代码实现

#### 2.1 创建 CarPlay 服务

```dart
// lib/services/carplay_service.dart
import 'package:flutter_carplay/flutter_carplay.dart';
import '../free_music_api.dart';

class CarPlayService {
  CarPlayService(this._audioHandler);

  final MusicAudioHandler _audioHandler;
  final FlutterCarplay _carPlay = FlutterCarplay();
  
  CPTabBarTemplate? _rootTemplate;
  
  Future<void> init() async {
    _carPlay.setRootTemplate(
      rootTemplate: _buildRootTemplate(),
      animated: true,
    );
  }

  CPTabBarTemplate _buildRootTemplate() {
    _rootTemplate = CPTabBarTemplate(
      templates: [
        _buildNowPlayingTemplate(),
        _buildLibraryTemplate(),
        _buildSearchTemplate(),
      ],
    );
    return _rootTemplate!;
  }

  CPListTemplate _buildNowPlayingTemplate() {
    return CPListTemplate(
      sections: [
        CPListSection(
          items: [
            CPListItem(
              text: '正在播放',
              detailText: '查看当前播放',
            ),
          ],
        ),
      ],
      title: '播放中',
      systemIcon: 'play.circle',
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
            ),
            CPListItem(
              text: '播放历史',
              detailText: '最近播放',
            ),
          ],
        ),
      ],
      title: '音乐库',
      systemIcon: 'music.note.list',
    );
  }

  CPListTemplate _buildSearchTemplate() {
    return CPListTemplate(
      sections: [],
      title: '搜索',
      systemIcon: 'magnifyingglass',
    );
  }

  void dispose() {
    // 清理资源
  }
}
```

#### 2.2 在 main.dart 中集成

```dart
// lib/main.dart
late final CarPlayService? _carPlayService;

@override
void initState() {
  super.initState();
  // ... 现有初始化代码
  
  // 初始化 CarPlay（仅 iOS）
  if (Platform.isIOS) {
    _carPlayService = CarPlayService(widget.audioHandler);
    unawaited(_carPlayService?.init());
  }
}

@override
void dispose() {
  _carPlayService?.dispose();
  // ... 现有清理代码
  super.dispose();
}
```

### 第三阶段：原生 Swift 集成

#### 3.1 创建 CarPlaySceneDelegate

```swift
// ios/Runner/CarPlaySceneDelegate.swift
import CarPlay
import Flutter

@available(iOS 13.0, *)
class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    
    var interfaceController: CPInterfaceController?
    
    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        self.interfaceController = interfaceController
        
        // flutter_carplay 插件会自动处理，这里只需保留引用
        NotificationCenter.default.post(
            name: Notification.Name("CarPlayConnected"),
            object: nil
        )
    }
    
    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnect interfaceController: CPInterfaceController
    ) {
        self.interfaceController = nil
        
        NotificationCenter.default.post(
            name: Notification.Name("CarPlayDisconnected"),
            object: nil
        )
    }
}
```

#### 3.2 在 AppDelegate 中注册

```swift
// ios/Runner/AppDelegate.swift
import UIKit
import Flutter

@main
@objc class AppDelegate: FlutterAppDelegate {
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    // CarPlay 场景配置
    override func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        if connectingSceneSession.role == .templateApplication {
            let config = UISceneConfiguration(
                name: "CarPlay",
                sessionRole: connectingSceneSession.role
            )
            config.delegateClass = CarPlaySceneDelegate.self
            return config
        }
        return super.application(
            application,
            configurationForConnecting: connectingSceneSession,
            options: options
        )
    }
}
```

### 第四阶段：GitHub Actions 构建配置

#### 4.1 更新构建脚本

```yaml
# .github/workflows/ios-unsigned-ipa.yml
# 在 "Build Unsigned iOS Device App" 步骤之前添加

- name: Configure CarPlay Entitlements
  run: |
    # 确保 Entitlements 文件存在
    if [ ! -f "ios/Runner/Runner.entitlements" ]; then
      cat > ios/Runner/Runner.entitlements <<EOF
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
        <key>com.apple.developer.carplay-audio</key>
        <true/>
    </dict>
    </plist>
    EOF
    fi
    
    # 修改 project.pbxproj 引用 entitlements
    sed -i '' 's/CODE_SIGN_ENTITLEMENTS = "";/CODE_SIGN_ENTITLEMENTS = Runner\/Runner.entitlements;/g' ios/Runner.xcodeproj/project.pbxproj || true

- name: Build Unsigned iOS Device App
  run: flutter build ios --release --no-codesign
```

### 第五阶段：本地签名与安装

#### 5.1 使用 Sideloadly 签名

1. 下载 GitHub Actions 构建的 unsigned IPA
2. 打开 Sideloadly
3. 选择 IPA 文件
4. 连接 iPhone
5. 输入 Apple ID（免费账号即可）
6. 点击 "Start" 签名并安装

**重要**：Sideloadly 会自动保留 CarPlay entitlements，无需手动干预。

#### 5.2 使用 AltStore 签名

```bash
# 安装 AltStore 到 iPhone
# 通过 AltStore 侧载 IPA
```

#### 5.3 使用 iOS App Signer（Mac 本地）

```bash
# 1. 下载 iOS App Signer
# 2. 选择 unsigned IPA
# 3. 选择签名证书（开发者证书或免费证书）
# 4. Provisioning Profile 选择对应的 profile
# 5. 点击 Start 生成签名后的 IPA
# 6. 通过 Xcode 或其他工具安装
```

## 测试验证

### CarPlay 模拟器测试

```bash
# Xcode 14+ 支持 CarPlay 模拟器
# 1. 运行应用（真机或模拟器）
# 2. Xcode → I/O → External Displays → CarPlay
# 3. 出现 CarPlay 窗口
```

### 真车测试

1. iPhone 通过 USB 或 CarPlay 无线连接车机
2. 车机屏幕出现"车载音乐"图标
3. 点击进入，测试播放控制

## 常见问题

### Q1: 构建时找不到 CarPlaySceneDelegate
**A**: 确保 `ios/Runner.xcodeproj/project.pbxproj` 中包含 `CarPlaySceneDelegate.swift`。手动添加：
```bash
# 在 Xcode 中右键 Runner 目录 → Add Files to "Runner"
# 选择 CarPlaySceneDelegate.swift，勾选 "Copy items if needed"
```

### Q2: 签名后 CarPlay 不可用
**A**: 检查签名后的 IPA 是否保留了 entitlements：
```bash
# 解压 IPA
unzip signed.ipa
# 检查 entitlements
codesign -d --entitlements - Payload/Runner.app
# 应该看到 com.apple.developer.carplay-audio = true
```

### Q3: CarPlay 连接后应用崩溃
**A**: 查看日志：
```bash
# Xcode → Window → Devices and Simulators
# 选择设备 → Open Console
# 过滤 "Runner" 查看崩溃日志
```

## 功能路线图

### MVP (最小可用版本)
- [x] 播放/暂停控制
- [ ] CarPlay 基本界面
- [ ] Now Playing 显示
- [ ] 播放队列

### V1.0
- [ ] 我的收藏浏览
- [ ] 播放历史
- [ ] 简单搜索

### V2.0
- [ ] 歌词显示（CarPlay 不原生支持，可在 Now Playing 信息中显示）
- [ ] 推荐歌单
- [ ] 音质选择

## 参考资料

- [flutter_carplay 插件文档](https://pub.dev/packages/flutter_carplay)
- [Apple CarPlay 开发指南](https://developer.apple.com/carplay/)
- [audio_service 集成](https://pub.dev/packages/audio_service)
- [Sideloadly 使用教程](https://sideloadly.io/)

## 风险与限制

### 技术限制
- ⚠️ CarPlay 界面模板受限（Apple 规定的标准模板）
- ⚠️ 不支持自定义视图（只能用系统提供的模板）
- ⚠️ 免费账号签名每 7 天需重新签名

### 自用场景
- ✅ 无需 App Store 审批
- ✅ 可以保留所有功能（付费音乐、第三方 API）
- ✅ 完全控制更新节奏

## 下一步行动

1. **准备阶段**（1-2 天）
   - 添加 flutter_carplay 依赖
   - 配置 Entitlements 和 Info.plist
   - 创建 CarPlaySceneDelegate

2. **开发阶段**（3-5 天）
   - 实现 CarPlayService
   - 集成 Now Playing
   - 实现播放控制

3. **测试阶段**（2-3 天）
   - CarPlay 模拟器测试
   - 真机侧载测试
   - 真车环境测试

4. **优化阶段**（持续）
   - 界面优化
   - 功能扩展
   - Bug 修复

需要开始实施吗？
