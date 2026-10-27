# 验证记录

日期：2026-10-27（Asia/Shanghai）。环境：Apple Silicon、Xcode 27.1、iOS 26.5、iPhone 17 Pro 模拟器 `EagleForce-QA`。

## 第十六版：风格、敌群与渐进补给（2026-10-27，当前）

从上游 413 中断处续接，保留前一会话全部素材和实现，核对本地代码、原版采集图、实际截图与测试日志后完成收尾。

- 独立侦察机/重装机/截击机、坦克/双管炮、磨损钢制补给箱与正常比例救援飞行员均接入实际渲染；水域地面单位/救援点补礁台，固定曝光。本次续接进一步压低水面白浪对比。
- 编队恢复按时间表入场，前两波各 3 架，后续 4–5 架，普通敌机最多 8 架；取消提前补兵。装备前 28 秒禁投、22 秒/8 次新击杀冷却、同屏一箱，五关依次引入过载/维修、护盾/散弹、激光、护航、雷电。
- 续接修复 EMP 屏外击毁可能浪费补给机会的问题：屏外击毁保留击杀奖励，但不生成装备箱或消耗掉落冷却。
- `./build.sh test`：**55 项核心测试通过**，包含五关完整时间线、敌弹职责、密度、掉落池/冷却/同屏限额、新增四边屏外 EMP 及 8 次新击杀回归。日志 `build/resumed-core-console.log`。
- `./build.sh ui-test`：**5 项定向 UI 测试、0 失败**，覆盖五关实际运行/两轴、侧倾/补给模型、横向救援/地面单位、低效果模式、Boss 击落/奖励/下一关解锁。可读取结果包 `build/UI-20261027-094720.xcresult`，日志 `build/resumed-ui-console.log`。
- `./build.sh ios`：最终 iPhoneOS arm64 unsigned Release 编译成功，产物 `build/EagleForce-unsigned.app`，日志 `build/resumed-release-console.log`。模拟器版本覆盖安装并恢复普通启动，原玩家存档 SHA-256 前后相同，记录 `build/resumed-save-check.json`。
- 从本次结果包导出 13 张截图，更新 [v16 索引](screenshots/v16/README.md) 并查看最终补给/敌机/海面实渲。地图/机库与五 Boss 静态展示截图沿用中断前已通过的 `build/UI-20261027-091444.xcresult` / `build/UI-20261027-092820.xcresult`，索引区分了来源。展示夹具的多箱同屏不代表正式掉落。
- `git diff --check`、构建脚本语法通过，`.artifacts` 不存在；临时构建缓存由 `build.sh` 清理。

未重跑完整 UI 套件，未签名安装物理 iPhone或测长局性能/真人难度，未上传。只对照了已有原版采集范围；原版全敌种、全部 Boss/关卡尚未完成对应研究，当前不声称全元素或像素一致。五 Boss 共用母体、后续环境细节重复仍是已知差距。

## 第十五版：全战斗对象迭代（2026-10-27，历史）

- 新增原创红色紧凑双发战机、岩石与装甲材质；敌机、五 Boss 装备、地面单位、五环境、弹芯/尾迹、金属补给、星形奖励、救援与爆炸均接入现有 3D 渲染。新增网格索引/法线/深度断言，继续检查补给无外圈、机体有侧壁底面、双轴输入投影一致。
- `./build.sh check` 的核心部分 **50 项通过**；UI 六项中五项通过，坠毁测试最初因冷启动等待越过定时低血量阶段而失败。失败结果 `build/UI-20261027-074426.xcresult` 保留。Debug 夹具现在保持低血量，测试实际点击后才注入致命敌弹；不改变 Release 战斗规则。
- 坠毁与横向补给复测 **2/2 通过**：`build/UI-20261027-074939.xcresult`。五 Boss/双轴投影、三类特殊武器/三机护航、侧倾/无外圈补给、胜利/奖励/下一关此前已通过。
- 最后一次海面/行星材质修改后，五 Boss 和新增低动态效果测试 **2/2 通过**：`build/UI-20261027-075255.xcresult`。炮台装甲材质最终复测 **1/1 通过**：`build/UI-20261027-075714.xcresult`。本轮涉及的 **7 项不同 UI 测试均已有通过记录**，不是声称完整 UI 套件一次全部通过。
- `./build.sh ios`：最终 unsigned arm64 Release 编译成功，产物 `build/EagleForce-unsigned.app`；模拟器覆盖安装并恢复普通玩家启动。正常存档 SHA-256 前后相同：`54e7edbc2f61af408783290ccc4d46ded30a1fda8010a68a73e77261ec9c69d5`，记录 `build/v15-save-check.json`。
- 已查看五关及补给、武器、低效果的实际渲染截图，修正初版水面纵向拉伸、过强地表对比、行星过亮和炮台无材质问题。截图及逐项索引见 [v15](screenshots/v15/README.md)，设计与来源见 [研究文档](SKY_FORCE_STUDY.md)、[素材记录](ASSET_PROVENANCE.md)。
- `git diff --check` 通过，`.artifacts` 不存在，临时 DerivedData 由构建脚本退出时清理。

本轮没有重新占用共享手机。仍未测物理设备持续帧率/发热/触控、iPad/最低 iOS 版本和完整无障碍路径；未实听原版音效、未签名安装、未上传 TestFlight 或提交 App Store。战机仍是原画驱动的浮雕网格，地形重复与完整手工模型精度仍有差距；不能称为全量或 1:1 复刻。

## 第十四版：参考 UI 结构重做（2026-10-27，历史）

- 地图替换为黑底琥珀雷达、平面海岸、直线圆形节点、竖排勋章与 START 圆环；机库替换为部件线稿、连接线、斜切升级条。战斗采用七段数码星晶读数/细条/圆形按钮，字幕缩小且无内容时不占空位；暂停改为同一黑金/青色布局。
- 首轮 `./build.sh ui-test` 地图/机库/部署测试通过，结果 `build/UI-20261027-071504.xcresult`；真实截图发现圆环顶缘裁切与海岸线过硬，随后修正。
- 最终 `./build.sh ui-test` 五项、0 失败：地图/升级/出击/倍速/EMP、五位人物档案与通讯生命周期、坠毁结算、全局音乐/后台、胜利/奖励保存/解锁下一关。结果 `build/UI-20261027-071756.xcresult`。
- 最终 `./build.sh ios`：unsigned arm64 Release 编译成功。模拟器覆盖安装后正常启动；正常存档 SHA-256 前后一致：`54e7edbc2f61af408783290ccc4d46ded30a1fda8010a68a73e77261ec9c69d5`，核验记录 `build/ui-v14-save-check.json`。
- 最终整图对照：地图 72.79%，机库 76.73%，覆盖率均 100%；改版前分别为 26.00%、48.28%。未达到 95%，不同进度/文案/升级数量影响指标；不能描述为像素一致。已人工查看实际截图与标注差异图。
- `git diff --check` 通过，脚本清理临时构建缓存与 `.artifacts`。截图、对照报告及限制见 [v14](screenshots/v14/README.md)，页面设计映射见 [研究文档](SKY_FORCE_STUDY.md)。

本轮没有修改存档格式、碰撞、经济或关卡时间线；未重跑全部核心/UI 套件，未安装真机，未验证 iPad/小屏/大字体和真机性能。地形/模型精度仍有差距，未上传或提交商店。

## 第十三版：Sky Force 真机参考迭代（2026-10-27，历史）

- 实际打开用户手机中的两款 Sky Force，采集 15 张截图；媒体音量核验为 0%。采集后两个包均 terminate 成功、state=1，已写共享队列交接。不包含原版音效实听、所有 Boss 或通关采集。
- `./build.sh test`：50 项核心测试通过；包含五关模拟、奖励去重/旧存档，以及新增救援/补给音效的非静音、无削波 PCM 检查。
- 定向 `./build.sh ui-test`：地图/机库/出击、五 Boss/两轴投影、横向补给、胜利/奖励/下一关，共 4 项通过、0 失败。结果：`build/UI-20261027-004512.xcresult`。
- 画面复核后细化水面、限制同时存在的补给浮字，再通过五 Boss/两轴实际渲染回归（1 项），结果：`build/UI-20261027-005017.xcresult`。已逐张查看最终五关截图。
- 最终源码经 `./build.sh ios` 成功构建 unsigned arm64 Release：`build/EagleForce-unsigned.app`。模拟器已覆盖安装并正常启动；未安装到物理手机，未上传。
- 正常存档覆盖安装前后 SHA-256 一致：`54e7edbc2f61af408783290ccc4d46ded30a1fda8010a68a73e77261ec9c69d5`。安装后沙盒路径会变化，已重新查询容器位置再校验。
- 第一轮 UI 中新奖励条的子标识被父容器覆盖，两项新断言失败；移除父标识后实际重跑通过。Shader 也经真实画面检查修正过规则光斑/长条纹，最终图不使用这些中间版本。
- `git diff --check` 通过；构建入口清理临时 DerivedData 与 `.artifacts`。参考截图仅在 docs，不在 Xcode Resources 构建阶段。

最终截图见 [v13](screenshots/v13/README.md)，观察与设计见 [研究文档](SKY_FORCE_STUDY.md)。本轮未做真机长局温度/功耗/帧率测量、参考游戏声音分析或全套 UI 回归；不代表精细模型质量、像素一致或 App Store 可提交状态。

## 第十二版：原图战机建模与后方停火（历史）

- 战机、截击机、重装炮艇与母舰以各自原画轮廓、UV 和起伏网格替换通用方块机体；同一模型用于实战、护航、机库、序幕与坠毁。凹形机翼使用耳切三角化与细分，保留实体侧壁和底面，Debug 检查真实深度、非零法线、纹理坐标和三组网格面。海岛共享法线，减少折面。
- 普通敌机、Boss、地面设施只有位于玩家前方时才允许启动新一轮射击；Boss 激光调度同样检查前后位置。横向关卡仍采用世界 y 轴判断；已发射子弹与激光预警不会凭空消失。
- `./build.sh check` 核心 50 项通过。新增测试覆盖五关四类敌人从前方开火到平齐/后方停火、已有弹丸继续运动，以及第 2/3/5 关 Boss 后方不能启动激光。第一次测试夹具把玩家移到既有子弹上，导致子弹被碰撞正常移除；移开横向测试位置后通过，未修改正常碰撞行为。
- 最终 `./build.sh ui-test` 选择三项 UI 测试，全部通过：机库/地图/出击、五个 Boss/投影、横竖两轴侧倾/无环补给。结果包 `build/UI-20261026-151716.xcresult`，日志 `build/reference-final-ui-console.log`。逐张查看机库、横竖实战、五个 Boss 截图，另在安装版本进入正常时间线检查红黑截击机。
- 第一轮实渲暴露 UV 方向颠倒和凹翼径向网格重叠，已改用正确图片坐标与凹多边形三角化，并完整重跑上述三项。首次结果收尾的 `simctl diagnose` 耗时异常，停止该诊断后结果正常保存；构建脚本使用 Xcode 的 `-collect-test-diagnostics never`，保留测试日志、截图及结果包，最终命令正常退出。
- `./build.sh ios` arm64 Release 无签名构建成功，日志 `build/reference-release-console.log`。模拟器已覆盖安装并恢复普通模式，原玩家存档 SHA-256 前后一致，见 `build/reference-save-check.json`。临时构建目录及 `.artifacts` 已清理。

实渲证据：[机库](screenshots/v12/02-hangar.png)、[竖向侧倾](screenshots/v12/bank-ringless-mission-1.png)、[横向侧倾](screenshots/v12/bank-ringless-mission-2.png)、[截击机](screenshots/v12/scout-live.png)、[母舰](screenshots/v12/3d-boss-1.png)。侧倾截图中的编队与补给为展示夹具。

边界：网格依据原画轮廓和机体起伏构建，侧面没有独立精绘纹理，未达到专业 DCC 逐部件精修；五关 Boss 使用同一母舰原画加关卡组件。未验证物理 iPhone 长局帧率、发热及大角度侧视效果，未重跑全部 UI 套件，未上传 TestFlight 或提交商店。

## 第十一版：侧倾、跟随惯性与无环补给（历史）

- 通过根目录 `./build.sh check`（UI_TEST_FILTER 选择 3 项定向测试）：48 项核心测试、3 项 UI 测试全部通过。结果包 `build/UI-20261026-144103.xcresult`，控制台 `build/flight-final-console.log`。
- 新增核心检查涵盖横竖移动的平滑/边界/松手短滑、无效输入、边缘反向、停止、30/60/120 Hz 响应一致性，以及侧倾方向、俯仰、回正。
- UI 用真实拖动验证两个飞行轴的侧倾和暂停/恢复位置稳定；另用 DEBUG 夹具经正式操控与绘制路径在转向中途定格，检查模型侧倾超过 0.5 弧度、投影一致。九类道具逐节点断言不存在 SCNTorus。补给展示回归通过。
- 已人工查看模拟器实渲：[竖向侧倾与补给](screenshots/v11/bank-ringless-mission-1.png)、[横向侧倾与补给](screenshots/v11/bank-ringless-mission-2.png)、[横向补给/飞行员](screenshots/v11/supplies-ground-horizontal.png)。定格图中敌机与道具排列属于展示夹具。
- 已覆盖安装并启动普通模式模拟器版本；普通玩家存档 SHA-256 前后一致，证据 `build/flight-save-check.json`。`./build.sh ios` 的 arm64 Release unsigned 编译通过，证据 `build/flight-release-console.log`。临时构建目录由脚本清理，项目没有 `.artifacts`。

本轮未重跑全部 UI 套件，未安装物理 iPhone、进行真人手感与持续性能验收，未上传 TestFlight 或提交商店。当前是原创程序几何模型；此次改动增强姿态和机身厚度，并不代表最终商业美术验收。

## 第十版：全场景实时 3D（历史）

- `./build.sh test`：44 项核心测试通过；游戏模拟、武器、关卡、奖励和存档代码未修改。证据：`build/3d-core-console.log`。
- 完整 10 项 UI 回归中 9 项通过：五关、地图与机库、通讯、坠毁、五个 Boss 投影、音乐、序幕、六组武器/护航、横向补给。结果包：`build/UI-20261026-122209.xcresult`。通关测试出现一次系统 TextToSpeech/AudioQueue 线程崩溃，原始记录为 `~/Library/Logs/DiagnosticReports/EagleForce-2026-10-26-122810.ips`，不能把这次完整运行报告为全绿。
- 最终 4 项定向复测全部通过（0 failures），覆盖五个 Boss/三维投影、地图/机库、坠毁、通关奖励。语音崩溃本次未复现。证据：`build/3d-verified-ui.log`。随后 Xcode 挂在 `simctl diagnose` 收尾，结果包 `build/UI-20261026-123130.xcresult` 不完整；保留 `build/3d-xcode-finalization.sample.txt` 后结束该构建，再经 `./build.sh run` 单独构建安装最终版本。不能把该次命令报告为正常退出或可读取的完整结果包。
- `./build.sh ios`：最终 iPhoneOS arm64 Release 无签名编译成功，证据：`build/3d-release-verified.log`。这是编译验证，不是真机安装或 App Store 归档。
- Debug 自检遍历战机、五个 Boss、三种地面模型、九类补给，检查实际深度与材质，拒绝 SCNPlane/UIImage 假立体对象。投影测试逐关比较两个世界点、三个高度与真实触控视图映射，误差小于 1 点；校验等到 SCNView 建立实际视口后执行。
- 首轮武器测试出现辅助功能遍历异常，3D 装饰场景从 AX 树移除后，六组武器/护航在定向及完整回归均通过；按钮、HUD 及通讯语义保留。测试过程中遇到的初始视口断言已修复。
- 实渲截图在 `docs/screenshots/v10/`；初版截图后调整海岛高差、太空背景材质和坠毁火焰，并重跑上述四项。Boss 快速预览通过正常模拟快进进入接战，测试不会写普通玩家存档。

最终 `./build.sh run` 正常完成，覆盖安装并启动普通玩家模式；另从安装版本直接捕获五个 Boss 和地图截图。普通玩家存档 SHA-256 前后均为 `c0c362c4f6d97e431ab209b76a37280d994b37c35e65d73e720254eb9b29b03b`（安装后容器路径变化，文件内容不变），证据：`build/3d-installed.log`、`build/3d-save-check.json`。构建脚本语法、源码空白和 `.artifacts` 清理检查通过。

当前范围：五关的背景地形、战机、敌机、Boss、障碍、补给、救援、弹丸及效果均为 SceneKit 实时几何；地图、机库和序幕也已替换。仅 HUD、人物通讯头像、字幕和系统图标保持二维界面。旧的精灵和背景原画保留，但没有活动绘制调用。

边界：模型为原创风格化程序建模；未做物理 iPhone 的长局帧率、发热、耗电、VoiceOver 与语音稳定性验收。系统语音崩溃尚未确证根因，需在真机进一步观察。未上传 TestFlight、未提交 App Store。

## 第九版：特殊武器与三机护航（历史）

- `./build.sh test` / 最终 `./build.sh check`（UI 使用三项筛选）：44 项核心测试通过。新增验证三种武器切换、刷新与到期，激光实际贯穿与侧后方排除，散弹七路弹道和命中，雷电三目标唯一命中、距离限制与递减伤害，护航上限、额外 60 水晶、五关边界、独立伤害与坠毁停火，正式掉落路径及通讯过期/去重。证据：`build/weapons-final-check.log`、`Tests/Core/WeaponTests.swift`。
- 最终 3 项 UI 回归全部通过：新武器与三护航机在两种飞行方向的六组场景、暂停冻结；受损/坠毁/失败结算；Boss 击落/胜利奖励/解锁并进入下一关。完整结果包：`build/UI-20261026-111426.xcresult`。本轮未重跑其余六项既有 UI 测试。
- 截图检查后把第三架护航机从后方改为前方领航，避免默认纵向位置被通讯面板遮住。最终截图均来自真实 SpriteKit 渲染：三架护航可见，光束和弹道随关卡方向旋转，文字保持正向；新 HUD 不替换危险预警。
- `./build.sh ios` 最终 iPhoneOS arm64 Release 无签名构建成功，日志 `build/weapons-final-ios.log`。没有第三方依赖、外部素材或存档字段新增。
- 测试脚本已覆盖安装到 EagleForce-QA 并以普通模式启动。正常存档 SHA-256 前后均为 `ccfd12addf2a4747caf8cb74e2f1334131e24155ab5ecc66c5a13a30084c6065`，见 `build/weapons-save-check.json`。脚本语法、源码尾空白、`.artifacts` 清理检查通过。

截图：[激光贯穿与三架护航](screenshots/v9/weapon-laser-mission-1.png)、[七路散弹](screenshots/v9/weapon-spread-mission-1-frame-1.png)、[横向连锁雷电](screenshots/v9/weapon-lightning-mission-2-frame-1.png)。整齐排列的高耐久敌机和补给属于 DEBUG 夹具；拾取、伤害、护航射击和特效走正式代码。新增武器参数见 [玩法调校](GAMEPLAY_TUNING.md)。

未做真机实听、长局帧率/发热/耗电和真人难度平衡校准；激光穿透、近距离散弹和三机叠加会提高清场效率，需要后续试玩校准。未上传 TestFlight 或提交 App Store。

## 第八版：动态补兵、道具辨识与启动序幕（历史）

- `./build.sh check`：36 项核心测试通过；新增覆盖五关火力拾取后的 3 秒内可见目标、屏幕外编队计数、9 架普通敌机上限、临近 Boss 停止补兵、普通/地面/Boss 敌弹精确提速 50%。原有五关通关、碰撞、奖励、存档与剧情回归通过。证据：`build/density-check.log`、`build/core-tests.log`。
- 首轮完整 8 项 UI 通过并正常生成结果包：`build/UI-20261026-103425.xcresult`。
- 检查截图后，将剧情淡入淡出限制在背景，消除文字叠影；横向地面单位的血条保持水平。最终完整 8 项 UI 再次全部通过，日志 `build/density-final-ui.log`；Xcode 在测试完成后的结果包收尾挂起，采样后终止该进程，该轮结果包不完整，不能作为可导出的报告。
- 随后 3 项定向 UI（启动序幕、横向道具、受损/坠毁）通过并生成完整结果包：`build/UI-20261026-105001.xcresult`。该轮测试后的安装脚本报路径错误，已通过 `./build.sh run` 重新构建、覆盖安装并正常启动，见 `build/density-final-install.log`。测试与安装结果分开记录。
- 最终横向展示夹具调整后，单项 UI 再次通过，完整结果包 `build/UI-20261026-105458.xcresult`；脚本正常结束、覆盖安装并以普通模式启动。最终存档校验见 `build/density-save-check.json`。
- 最终 `./build.sh ios`：iPhoneOS arm64 Release unsigned 构建成功，见 `build/density-final-ios.log`。最后仅调整 DEBUG 展示夹具的救援人物位置，不影响 Release 战斗代码。
- 普通存档 SHA-256 在覆盖安装前后相同：`ccfd12addf2a4747caf8cb74e2f1334131e24155ab5ecc66c5a13a30084c6065`。UI 测试仍使用独立临时档案，没有改变存档结构。

实际截图：[启动序幕](screenshots/v8/opening-01.png)、[林汐入场](screenshots/v8/opening-02.png)、[起航](screenshots/v8/opening-03.png)、[竖向道具与地面敌军](screenshots/v8/07-critical-obstacles-supplies.png)、[横向道具与地面敌军](screenshots/v8/supplies-ground-horizontal.png)。道具/地面敌军的整齐排列属于 DEBUG 展示夹具，绘制、瞄准、射击、拾取和伤害使用正式逻辑。

开场验证包括：冷启动先显示剧情、选关尚不可见、逐段继续、后台返回保留当前段、末段自动进入选关、返回地图不重播、下次冷启动可跳过。语音依旧是系统中文合成声。尚未真机试玩、实听配音/混音、测量耗电和持续帧率；动态补兵增加局内收益，提速提高躲避难度，仍需真人手感与经济平衡校准。未上传 TestFlight 或提交 App Store。

## 第七版：剧情与角色通讯（历史）

新增五关原创连续剧情，通讯官林汐、五位敌军指挥官与六张原创头像。战役地图提供战情/人物档案；战斗底部固定通讯区展示头像字幕，林汐用系统中文语音按真实战况支援。暂停提供记录，结算推进故事，已通关的后记可在档案重读。

- 核心 32 项测试通过：旧存档兼容、语音开关往返保存、章节完整性、真实 Boss 出场/阶段、警报优先与过期、重复抑制、结局清队列、原有五关战斗与奖励。
- 初轮完整 UI 的原有 5 项通过；新增人物/通讯测试因自动化点击标签未切换开关失败。改为点击开关本体并等待值变化后，定向回归通过（`build/UI-20261026-085802.xcresult`）。
- 初轮 Xcode 在结果包收尾时停滞，保存日志与进程采样后终止该次进程；定向回归正常完成并导出截图。
- CUA 手动检查弱点解析、林汐介绍与试听；本机识别为中文女声，点击试听后 `AVSpeechSynthesizer` 的开始回调驱动「林汐正在通讯」状态。此证据不等于物理设备音质验收。
- 视觉检查后将通讯从顶部改到固定底部区域，避免遮挡纵向 Boss。截图为真实模拟器渲染，非效果图。

最终完整回归通过：`./build.sh check` 验证 32 项核心测试、6 项 UI 测试，0 失败；结果包 `build/UI-20261026-090930.xcresult`，控制台 `build/story-final-check.log`。通过 `./build.sh ios` 编译 iPhoneOS arm64 Release unsigned 版本。旧普通玩家存档的 SHA-256 在覆盖安装前后相同，见 `build/story-save-check.json`。测试始终使用独立临时存档。



最后仅上移 Boss 陨落提示以避开状态栏；通关/暂停/结算/解锁定向回归再次通过（`build/UI-20261026-091524.xcresult`），最终 Release 真机架构编译也通过。最终截图已更新，模拟器恢复普通玩家模式。

当前截图：[战斗通讯](screenshots/v7/story-radio-opening.png)、[敌军人物](screenshots/v7/story-dossier-4.png)、[核心弱点与林汐档案](screenshots/v7/zero-dossier.png)、[通讯记录](screenshots/v7/story-radio-log.png)、[语音暂停](screenshots/v7/story-radio-paused.png)。

边界：当前是系统合成语音，没有真人角色配音；敌军登场为头像字幕，未配敌军语音。未在物理 iPhone 上试听混音、核对静音/耳机/电话中断、评估长期性能；未上传 TestFlight 或提交 App Store。

## 第六版验证（历史）

中文名称「苍穹突击」。首页移除底部标签导航和说明卡片，使用全屏战区地图、设置、机库与出击入口。普通侦察机第 1–5 关基础命中次数为 1/1/2/2/3，装甲机为 1/2/2/3/3，升级武器可提前击毁；Boss 和地面高塔的耐久规则保留。

地面改为独立 SceneKit 渲染层，透明 SpriteKit 层负责战机与战斗；纵向使用带高度/法线的纹理网格，横向使用挤出的岩壁剖面。采用定向光、环境补光、投影和立体工业设施。两层在同一个 390×780 画幅对齐，横向相机旋转与战斗坐标一致。岩壁描边每帧使用实际碰撞曲线，网格以 20 Hz 刷新。沙漠、冰川使用连续地形，不叠加独立装饰岩块。

| 范围 | 结果 | 证据 |
|---|---|---|
| 核心规则 | 26 项通过，含全部五关所有普通敌机波次的主炮/弱翼炮/升级炮实际命中测试 | `build/core-tests.log` |
| 伤害隔离 | 普通敌机最多三击，Boss/高塔仍使用原始弹丸伤害 | `ordinaryEnemiesTakeAtMostThreeHits`、`weakShotsKeepTheirDamageAgainstBossesAndObstacles` |
| 完整 UI | 5 项全部通过，含地图/机库/音乐、倍速/暂停/EMP、坠毁、Boss 陨落和通关解锁 | `build/v6-verified-ui.log` |
| 最终地形回归 | 五关拖动、暂停/恢复、EMP 与实际渲染截图；通过结果包见 `build/latest-ui-result.txt` | `build/v6-scenes-console.log` |
| 网格校验 | Debug 验证顶点/UV 数量、有限坐标、索引范围和非零法线 | `TerrainScene.mesh` |
| Release | iPhoneOS arm64 unsigned 编译；检查测试启动参数不进入二进制 | `build/ios-build.log` |
| 存档 | 同 Bundle ID 覆盖安装；普通玩家档案 SHA-1 前后相同 | `build/v6-save-check.txt` |

执行均经 `build.sh`。完整 UI 回归通过后，Xcode 卡在结果包收尾，保存日志及进程采样后结束该次 xcodebuild；随后定向重跑五关并成功生成可读取结果包。早期尝试中的 SK3DNode 地形存在旋转/叠放异常，已改为独立 SCNView；最终截图中逐关检查了战机可见性与通道边界。普通玩家模式已恢复，测试使用独立临时存档。

实际最终截图（模拟器渲染，不是效果图）：

- [首页](screenshots/v6/01-campaign.png)
- [海岛](screenshots/v6/mission-1.png) / [横向港湾](screenshots/v6/mission-2.png)
- [沙漠](screenshots/v6/mission-3.png) / [横向冰川](screenshots/v6/mission-4.png) / [轨道](screenshots/v6/mission-5.png)

边界：战机/Boss/可破坏高塔仍是精灵，部分地面细节仍来自原画纹理；已加入实时地形网格，但不宣称达到原版游戏的模型精度或完整 3D 战斗。未验证物理 iPhone 的长期帧率、发热、耗电与最终美术验收；未提交商店。

## 第五版验证（历史）

游戏中文名已更新为「苍穹突围」。同一 Bundle ID 覆盖安装，存档结构和路径未变；模拟器最终启动普通玩家模式，测试档案独立。

| 范围 | 结果 | 证据 |
|---|---|---|
| 核心逻辑 | 24 项 Swift Testing 测试通过，参数化覆盖五关 | `build/core-tests.log` |
| Boss 节奏 | 五关分别模拟 30 秒，验证短连射/长恢复窗口、间隔上下界；半血弹数/弹速检查保留 | `bossCadenceIncludesBurstsAndRecoveryWindows`、`bossVolleyDensityAndSpeedScaleByMission` |
| Boss 陨落 | 5.2 秒独立阶段；清除敌弹/激光、阻止移动/EMP；2× 不加速演出，结束后唯一结算与奖励去重 | `lethalPulseCompletesBossAndCannotPayTwice`；胜利 UI 回归 |
| 机身与护盾 | 机身只侧倾，不再横向挤压；护盾是独立节点。Debug 每帧断言护盾父节点、旋转为零、两轴缩放为 1 | 五关拖动 UI 回归，Debug 初始护盾夹具 |
| 全局音乐 | 32 秒 PCM 合法、非静音、无削波；AVAudioPlayer 状态在开关、页面切换、前后台恢复后正确 | 声音核心测试；`testGlobalMusicFollowsSettingsAndBackground` |
| UI 回归 | 完整 5 项通过，0 失败；包括五关、机库、暂停/EMP/倍速、Q 版人物场景、玩家坠毁、Boss 陨落暂停/继续、胜利解锁 | `build/UI-20261026-073721.xcresult` |
| Release | iPhoneOS arm64 unsigned 编译通过；二进制不含 Debug 测试启动参数 | `build/ios-build.log`；`build/EagleForce-unsigned.app` |

本轮首次 UI 回归的音乐测试在从后台返回后过早点击档案页，命中点尚不可用；增加可点击等待后完整 5 项重跑通过。执行入口为 `./build.sh check`、`./build.sh ui-test`、`./build.sh ios`。脚本语法与源文件尾空白检查通过，`.artifacts` 不存在，临时 DerivedData 已由脚本清理。

实际截图与录像：

- [新名称与战役地图](screenshots/v5/01-campaign.png)
- [Q 版救援飞行员](screenshots/v5/07-critical-obstacles-supplies.png)
- [Boss 陨落与独立正圆护盾](screenshots/v5/11-boss-fall.png)
- [Boss 陨落录像](screenshots/v5/boss-finale.mp4)：模拟器原始录像截取，包含击破、暂停/继续、下坠解体及结算，无音轨。
- [全局音乐设置与播放状态](screenshots/v5/12-global-music.png)

人物与 Boss 图片已人工查看；录像中 Boss 战斗使用 Debug 无敌瞄准机器人。播放器运行和 PCM 数据检查不代表真机扬声器、耳机或蓝牙听感验收。尚未测试来电音频中断、长时间真机性能和新 Boss 节奏的人类通关难度。

## 第四版验证

| 范围 | 结果 | 证据 |
|---|---|---|
| 核心逻辑 | 23 项 Swift Testing 测试通过，参数化覆盖五关、三档倍速、五种编队、三种障碍 | `build/core-tests.log` |
| 战斗流程 | 未升级战机的无敌瞄准机器人跑过全部五关波次并击破 Boss | `Tests/Core/CampaignTests.swift` |
| 新增规则 | 倍速时间与高速子弹碰撞、逐关/半血 Boss 弹数与速度、编队位移与间距、吸附不越过玩家、弯曲通道及触壁保护、八方向救援指引 | 同上 |
| 声音数据 | 原创循环音乐及 9 类提示音均生成合法非静音 PCM，无削波；代码连接暂停、继续与结算生命周期 | `Sources/Core/AudioScore.swift`；核心测试 |
| 经济与存档 | 首通/勋章/出击去重、失败保留 25%、解锁、升级余额与封顶、原子读写、拒绝损坏档案 | 核心测试；本轮未改变存档结构 |
| iOS UI | 完整 4 项 UI 回归通过，0 失败 | `build/UI-20261026-071406.xcresult` |
| 实际交互 | 五关始终竖屏、横向侧视关卡、相对拖动、暂停/继续、EMP、1×→1.5×→2×→1×、机库购买、SOS 提示、低血量与坠毁结算 | `Tests/UI/EagleForceUITests.swift` |
| 通关闭环 | 第 1 关胜利 → 奖励保存 → 自动选中第 2 关 → 等待转场结束 → 出击第 2 关 | 完整 UI 回归 |
| Release | iPhoneOS arm64 Release unsigned 编译通过 | `build/ios-build.log`；`build/EagleForce-unsigned.app` |

执行入口均为 `./build.sh`。完整 UI 回归后仅补正了救援箭头的八方向计算和 SOS 人物的白色矢量绘制：箭头新增独立核心测试，人物渲染执行定向 UI 回归通过（`build/UI-20261026-072023.xcresult`，1 项、0 失败），并导出实际截图。最终构建覆盖安装模拟器 App、启动普通玩家模式，保留 Application Support；测试使用独立临时档案。

首轮 UI 回归中的失败结算测试在保存奖励界面出现前立即断言按钮存在，产生一次时序失败；改为等待按钮出现后整组通过。首轮失败运行的 Xcode 进程在测试结束后未退出，已终止该次进程；最终通过的结果包正常保存。

## 第四版实际截图（历史）

这些是模拟器实际渲染，不是效果图。Boss/胜利使用 Debug 无敌瞄准机器人；损伤场景使用 Debug 固定障碍/补给与注入敌弹，战斗判定仍走正式代码。地图转场路径由动画实现，UI 回归验证其完成后可以出击下一关。

| 页面 | 截图 |
|---|---|
| 战役地图 | [查看](screenshots/v4/01-campaign.png) |
| 机库 | [查看](screenshots/v4/02-hangar.png) |
| 碧潮群岛 | [查看](screenshots/v4/mission-1.png) |
| 竖屏内横向港湾 | [查看](screenshots/v4/mission-2.png) |
| 赤砂熔谷 | [查看](screenshots/v4/mission-3.png) |
| 竖屏内横向冰川 | [查看](screenshots/v4/mission-4.png) |
| 零点天穹 | [查看](screenshots/v4/mission-5.png) |
| Boss | [查看](screenshots/v4/06-boss-long-scroll.png) |
| 轻量晕影、烟火、SOS 与补给 | [查看](screenshots/v4/07-critical-obstacles-supplies.png) |
| 下一关自动选中 | [查看](screenshots/v4/10-next-mission-selected.png) |

旧版截图和坠毁视频仍保留在 `screenshots/` 根目录作为历史记录，不代表第四版当前视觉。

## 未验证与边界

- 未安装物理 iPhone/iPad，未实听真机混音或校准触感、持续帧率、触控延迟、耗电、发热。声音遵循 iOS ambient/静音开关，音乐与音效共用原有开关。
- 自动机器人只证明五关可到结算，不证明人类玩家难度、倍速可玩性与全部勋章平衡；仍需试玩调整。
- 未执行 iPad、iOS 17 最低版本、多机型、大字体、VoiceOver 全路径回归。
- 战机仍为俯视风格精灵，尚无独立侧视机体模型。第六版加入实时地形网格与岩壁，部分地表细节仍是原画纹理，不是全场景模型化。
- 没有英文完整本地化、云存档、成就平台或 IAP。尚未签名归档、上传 TestFlight 或提交 App Store 审核。
