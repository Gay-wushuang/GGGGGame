# C 的音乐与音效交接单 v0.4

更新日期：2026-11-15。采用[灰盒设计 v0.4](../灰盒设计_v0.1.md)与[API v0.4](../API与联调契约_v0.2.md)。以下为待制作清单，现有比例/事件展示不表示已接入音频成品。C 提供声音，D 接 UI 与人物，E 接车货、站点和事件。

## 1. 声音目标与交付文件

声音同时传达送货喜剧、货物状态、事件预警与工资压力。警告须在引擎与音乐下可辨，并有文字或图形对应。交付 **33 个音效文件、1 首音乐**，分组如下，每个展开后的文件名对应一件。

运行时放 who-sent-this-guy/assets/audio/，母版、工程和来源说明放 source_assets/audio/。音效运行时 48 kHz、16-bit PCM WAV，3D 单声道、UI 立体声；母版 48 kHz、24-bit WAV。音乐运行时 Ogg Vorbis 并附 WAV 母版。

| ID | 文件名 | 数量 | 时长初稿 / 内容 | 接入 |
|---|---|---|---|---|
| C01 | sfx_engine_idle_loop_01.wav | 1 | 2～4 s 低负载循环 | E |
| C02 | sfx_engine_load_loop_01.wav | 1 | 2～4 s 高负载循环，与 idle 连续混合 | E |
| C03 | sfx_tire_skid_loop_01.wav | 1 | 1～2 s 滑移循环 | E |
| C04 | sfx_cage_impact_01/02.wav | 2 | 0.2～0.8 s 笼栏接触变体 | E |
| C05 | sfx_glass_impact_01/02.wav | 2 | 0.2～0.8 s 玻璃接触变体 | E |
| C06 | sfx_bomb_impact_01/02.wav | 2 | 0.2～0.8 s 炸弹壳接触变体 | E |
| C07 | sfx_chicken_alarm_01.wav | 1 | 0.5～1.5 s 鸡受惊 | E |
| C08 | sfx_grab_01.wav | 1 | 0.1～0.3 s 成功加入抓取 | D |
| C09 | sfx_release_01.wav | 1 | 0.1～0.3 s 主动松手 | D |
| C10 | sfx_secure_01.wav | 1 | 0.2～0.5 s 固定确认 | E |
| C11 | sfx_unsecure_01.wav | 1 | 0.2～0.5 s 解除确认 | E |
| C12 | ui_delivered_01.wav | 1 | 0.3～0.8 s 单件首次交付 | D |
| C13 | ui_order_settled_01.wav | 1 | 1～2 s 订单结算确认 | D |
| C14 | ui_denied_01.wav | 1 | 0.1～0.3 s 失败，仅请求者 | D |
| C15 | music_transport_gray_01.ogg | 1 首音乐 | 60 s，96 BPM、4/4、24 小节循环 | D |
| C16 | sfx_water_slosh_loop_01.wav | 1 | 1～2 s 晃水循环，Slosh01 驱动 | E |
| C17 | sfx_bomb_warning_loop_01.wav | 1 | 1 s 危险提示，Danger01 驱动节奏 | E |
| C18 | sfx_ufo_warning_01.wav | 1 | 1～2 s UFO 预警 | E |
| C19 | sfx_ufo_beam_loop_01.wav | 1 | 2～4 s 光束循环 | E |
| C20 | sfx_tornado_warning_01.wav | 1 | 1～2 s 龙卷风预警 | E |
| C21 | sfx_tornado_loop_01.wav | 1 | 2～4 s 风场循环 | E |
| C22 | sfx_cow_01.wav | 1 | 0.5～1.5 s 母牛叫声，表演复用 | E |
| C23 | sfx_cow_rider_warning_01.wav | 1 | 1～2 s 骑牛飞车党接近 | E |
| C24 | sfx_pin_pull_01.wav | 1 | 0.2～0.5 s 拔销确认 | E |
| C25 | sfx_cow_rain_warning_01.wav | 1 | 1～2 s 母牛雨预警 | E |
| C26 | sfx_cow_land_01.wav | 1 | 0.3～0.8 s 牛落地，并发限流 | E |
| C27 | sfx_hajimi_attach_01.wav | 1 | 0.2～0.6 s 哈吉米吸附轮胎 | E |
| C28 | sfx_hajimi_detach_01.wav | 1 | 0.2～0.6 s 诱离/移除 | E |
| C29 | sfx_repair_refuel_01.wav | 1 | 0.5～1.5 s 服务完成确认 | E |
| C30 | ui_overtime_01.wav | 1 | 0.2～0.6 s 首次超时，每单一次 | D |
| C31 | ui_route_confirm_01.wav | 1 | 0.2～0.6 s 路线锁定确认 | D |

C01～C14 共 17 个音效，C16～C31 共 16 个音效，总计 33；C15 是音乐，不计入音效数。旧木箱/圆桶/重物声音不再作为首关清单。

## 2. 事件与播放生命周期

| 来源 | 播放规则 |
|---|---|
| VehicleSnapshot | EngineLoad01 混合 C01/C02；SkidIntensity01 >0.10 渐入 C03、<0.05 退出，避免抖动 |
| ObjectImpact | SurfaceId 为 cage/glass/bomb_shell；Intensity01 控制音量，同物体每 0.12 s 最多一次，最多两条并发 |
| CargoConditionChanged | 鸡受惊触发 C07；鱼缸 Slosh01 驱动 C16；炸弹 Danger01 驱动 C17 |
| CargoGrabbed/Released | 成功参与者各一次；重传不重复，断线/重置清理可抑制松手声 |
| CargoSecured/Unsecured | 确认变化一次一声，失败请求不播成功声 |
| IncidentWarned | 对应 C18/C20/C23/C25，哈吉米由接近叫声和画面预警表达 |
| IncidentStageChanged | Active 启动循环，Recovery/Resolved 淡出；重连按当前状态恢复循环 |
| RearPinRemoved | C24 提示车销实际失效；偷货由 UI 显示货物 ID |
| HajimiAttached/Detached | C27/C28 跟随对应轮位，状态变化时播放 |
| CargoDelivered/OrderSettled | C12 每件一次，C13 每单一次，失败也显示明细 |
| OrderBecameOvertime/RouteCommitted | C30 每单一次，C31 每次确认路线一次 |
| TransactionCommitted | 服务用 C29，购买可复用 UI 短声，重复交易响应不重播 |
| RoundReset/离开场景 | 停止上一回合全部循环，清理旧实例，不再播放旧事件 |

事件用 (RoundEpoch, EventId) 去重；持续声以 (RoundEpoch, EntityId/IncidentId, LoopKind) 唯一登记。重连从快照重建循环，历史单次叫声与结算声不补播。声音变体不能改变游戏结果。

## 3. 空间、混音与制作要求

发动机参考/最远距离 3/25 m，滑移 2/20 m，货物接触 2/18 m，交互 1/8 m，固定 1/10 m。事件采用方向清楚的 3D 声并配 UI；循环可听范围按实际作用圈试听。步行取人物眼点，驾驶取驾驶员位置，避免第三人称镜头远近改变警报判断。

预警适度压低音乐。主事件互斥，哈吉米也不与主事件叠加。牛雨落地同帧最多两条，短时间叫声限流，预警、炸弹与超时提示优先于环境母牛。声音不替代至少 6 s 的视觉预警。

母版建议真峰值 ≤-1 dBTP，提交实测。清除无意静音与爆音，保留有意尾音；循环标明采样起止点。碰撞可小幅随机音高，操作与警告保持可识别节奏。附音源、采样来源、实际 Studio One/Serum 等插件版本；导出不依赖现场插件。

## 4. 交付与验收

首样 C01/C02/C04/C08/C10/C16/C17 验证驾驶和三类货物；第二批 C12～C15/C29～C31 验证工资、服务、路线；第三批五事件音频。每批交文件、母版、工程、实测表、试听记录；实测表含采样率、编码、声道、时长、循环点、峰值、响度测法、体积。

耳机和普通扬声器各跑一单，检查单人驾驶听到预警、多人重传不重播、五事件启停、重置无残留声。D/E 提供实际触发记录，C 回报混音问题，B 发布采用值。尚未运行的检查记为待验。

| 版本 | 日期 | 内容 |
|---|---|---|
| v0.2 | 2026-11-08 | 原运输音效与音乐 |
| v0.4 | 2026-11-15 | 三类特殊货物、工资路线服务、五事件音频和去重规则 |
