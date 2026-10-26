# 素材来源与生成记录

2026-10-25/26，使用 Codex 内置 imagegen 生成（未使用 CLI 或 API key）。未提供任何现成游戏素材作为参考输入。输出为原创科幻战机方向，最终发行前仍应核验名称/商标与素材权利。

## 主视觉

路径：`Resources/Assets.xcassets/KeyArt.imageset/key-art.png`

最终提示词：

> Use case: stylized-concept. Asset type: original iOS arcade sci-fi aerial combat game main-menu key art, portrait 1024x1536. Create polished cinematic illustrated key art of a single original sleek pearl-white and midnight-navy interceptor fighter with cyan engine cores and tiny burnt orange accents, seen top-down at a slight dramatic angle, pointed toward the upper right, large in the central upper half, soaring over deep teal ocean islands far below. Gorgeous realistic painted metallic panels, atmospheric blue light, bright cyan engine trails flowing toward the bottom left, tiny distant enemy silhouettes, soft clouds and distant warm explosions. Rich dimensional premium game art, clear strong silhouette. Lower quarter dark navy atmosphere, quiet and uncluttered for overlay UI; no text anywhere, no logos, no existing franchise designs, no borders, no watermark. This must be a unique original aircraft not taken from Sky Force or any existing game. Output a beautiful finished illustration.

## 图标

原始路径：`Resources/Artwork/icon-source.png`。打包图标：`Resources/Assets.xcassets/AppIcon.appiconset/icon.png`，由 `build.sh` 使用 sips 规格化到 1024×1024；仅尺寸转换，无内容重绘。

最终提示词：

> Use case: stylized-concept. Asset type: iOS app icon, square 1024x1024, full bleed opaque artwork with no rounded corners. Original premium science-fiction arcade aircraft game icon. One sleek white titanium and navy interceptor spacecraft, top down three-quarter view, nose pointing upper right, wings spanning most of square, bright cyan twin engine trails toward lower left. Beautiful detailed metallic panels with warm orange tiny accent strips. Deep dark teal ocean far below, subtle atmosphere. Very strong simple readable silhouette and striking cinematic lighting. No text, no letters, no logo, no watermark, no border, no existing game aircraft designs. Keep the aircraft fully inside frame. Distinct original high quality painted game illustration.

## 游戏内资产

2026-10-26 视觉第二版：

- `Ship-player`：基于本项目原有 KeyArt 重新生成正俯视透明战机，保留白色/深蓝机身、双青色引擎与橙色细节。机库和实际战斗共用此图，替换旧版简化多边形飞机。
- `Ship-scout`、`Ship-armored`、`Ship-boss`：分别为深红截击机、重装炮艇、六炮塔航母，透明背景，原始分辨率 1254×1254。
- `Obstacle`：独立雷达高塔，第三版移除碰撞警戒圈，耐久条和受击损伤由代码绘制。
- `CampaignMap`：1024×1536 全屏群岛战略地图；曲线航线、节点、锁定状态和勋章为原生 SwiftUI 叠层。
- 五种 `Terrain-*`：替换为 724×2172 不对称长图；中央有桥梁、岛屿、基地与舰船，不再交替镜像。地图缓慢匀速滚动。

生成指令保存在 [visual-v2-prompts.json](visual-v2-prompts.json)。旧版地表提示词仍保留作历史记录。所有素材使用内置 imagegen 生成，战机参考输入为本项目自己生成的主视觉，未提取 Sky Force 的图片或代码。

历史版本的 `SpriteArt.swift` 使用纹理缓存及程序生成柔光/烟雾；第十版已经替换为完整原生几何模型与光照，不再在游戏世界使用这些精灵；`AudioScore.swift` 合成原创 PCM 循环音乐与战斗音效，`BattleAudio.swift` 管理播放。界面使用系统字体与 SF Symbols。无外部素材包、第三方游戏代码或下载音乐。


## 第四版侧视场景（2026-10-26）

使用内置 image_gen 工具生成，无外部图片引用。生成后原样复制到以下资产目录，保留原有俯视地表资产。

- `Resources/Assets.xcassets/Side-harbor.imageset/art.png`
- `Resources/Assets.xcassets/Side-glacier.imageset/art.png`

最终提示词：

### 港湾

Use case: stylized-concept. Asset type: production background texture for a premium sci-fi side-scrolling iOS aircraft game. Create one wide 1536x1024 landscape image. True SIDE ELEVATION view looking across a vast futuristic industrial harbor canyon at night, NOT aerial or top down. Layered immense drydock walls, hanging gantries near the upper edge, distant shipyard cranes, weathered metallic cliff structures, a few tiny amber navigation lights. Central 65 percent of image is open atmospheric blue gray air with faint far-background structures only, ample readable space for aircraft bullets. Very detailed cinematic realistic materials, subtle volumetric mist, restrained desaturated graphite teal palette, low contrast central play area, no neon overload. Terrain only at uppermost and lowermost edges. Seamlessly repeatable feeling across left and right. No aircraft, bullets, HUD, symbols, words, logos or watermark. This is game environment art not a UI mockup.

### 冰川

Use case: stylized-concept. Asset type: production background texture for a premium sci-fi side-scrolling iOS aircraft game. Create one wide 1536x1024 landscape image. True SIDE ELEVATION view looking across an immense arctic ice canyon with hanging crystalline ice near top edge and detailed layered glacier cliffs near bottom edge, a remote small sci-fi research outpost embedded low on one cliff. NOT top down or aerial. Central 65 percent is open cold blue gray atmospheric air with faint distant mountain silhouettes; plenty of readable negative space for aircraft bullets. Very detailed cinematic realistic ice materials and fissures, soft subtle green aurora high above, desaturated slate blue palette, low contrast central play area, no dazzling saturated colors. Seamlessly repeatable feeling across left and right. No aircraft, bullets, HUD, symbols, words, logos or watermark. This is game environment art not a UI mockup.

## 第五版人物与音乐（2026-10-26）

Q 版救援飞行员由 `SpriteArt.rescuePilot` 原生矢量绘制，头盔、表情、飞行服与挥手动作均在本项目中编写。全局循环音乐为 `AudioScore` 生成的 32 秒原创 PCM 和声、节奏与旋律，无下载音乐；Boss 陨落复用本项目敌舰纹理并程序生成烟雾、爆炸和碎片。

## 第七版剧情角色（2026-10-26）

内置 image_gen 独立生成林汐、韩潮、维拉、奥伦、沈霜与零点六张头像。均为原创角色，不引用任何现有游戏形象；源图保留在生成目录，sips 导出 640 像素 JPEG 到 `Portrait-*.imageset`。完整提示词与源图路径见 [story-portrait-prompts.json](story-portrait-prompts.json)。剧情、人物背景和台词由本项目创作。语音使用 iOS 已有普通话合成声音，不包含第三方录音或声音克隆。


## 第十版：实时几何资产（2026-10-26）

`Sources/App/SpriteArt.swift` 中的 ModelArt、TerrainScene、CombatRenderer、ModelPreview 是本项目新增代码构建资产。使用 SceneKit 原生形状、挤出路径、显式顶点/法线网格与颜色/PBR 参数；无需下载模型、图集或第三方材质。不规则海岸、沙丘和冰川为确定性函数生成。战斗中的烟雾、火花和能量线也使用几何体，没有图片粒子。沿用原有系统音效合成与中文语音。

原有 Ship、Terrain、Side、CampaignMap 图片仍保留在资源库作为历史原稿，目前的战斗、地图、机库和序幕绘制路径不使用它们。通讯头像和 App 图标仍使用既有原创生成图片。模型属于风格化程序建模，不能等同于精细手工建模或 AAA 美术质量。


## 第十二版：按原图重建战机（2026-10-26）

复用第二版的四张原创 `Ship-player/scout/armored/boss`，未重新生成或引入外部素材。ModelArt 在原图的 1254×1254 坐标内描绘轮廓，凹多边形三角化后细分表面，为座舱、主机身、发动机舱添加起伏、侧壁与底面，使用对应 UV 恢复原图细节。引擎喷口、尾焰和 Boss 六座炮塔保持独立几何体；五关 Boss 共用原画母舰本体，再装配对应关卡设备。几何与材质按四种机型缓存。

这取代第十版“不读取 Ship 原图”的绘制方式，仍通过 SceneKit 真实几何受光与侧倾，不是平面精灵。原图包含既有光影，侧面以基础材质填充；属于按原画构建的浮雕式网格，不能视为完整手工高精度模型或逐像素复刻。海岛增加地形采样并共享法线，减轻三角折面；其他地面设施未进行本次原图建模。
