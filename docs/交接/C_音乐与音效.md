# C 的音乐与音效交接单 v0.6

更新日期为 2026-11-22。C 负责音乐、音效、空间混音、声音资源交付与质量检查。D 接本地交互、界面提示与运输音乐，E 接车辆、货物、凝胶、室外加油和事件位置声。以下条目为制作与接入要求。[灰盒设计 v0.5](../灰盒设计_v0.1.md) · [API 与联调契约 v0.6](../API与联调契约_v0.2.md)

## 1. 声音目标与交付文件

平稳路段保留交流空间。货物接触、凝胶操作、预警和加油各有可辨声音，预警在引擎与音乐下仍有清楚方向，并配合视觉提示。运行时目标目录为 who-sent-this-guy/assets/audio/，母版、工程和来源说明目标目录为 source_assets/audio/。

音效运行时交 48 kHz、16-bit PCM WAV，3D 单声道，UI 可用立体声。母版为 48 kHz、24-bit WAV。音乐运行时交 Ogg Vorbis，同时交 WAV 母版。

| ID | 文件名 | 数量 | 时长参考 / 内容 | 接入 |
|---|---|---|---|---|
| C01 | sfx_engine_idle_loop_01.wav | 1 | 2～4 s 低负载循环 | E |
| C02 | sfx_engine_load_loop_01.wav | 1 | 2～4 s 高负载循环，与 idle 连续混合 | E |
| C03 | sfx_tire_skid_loop_01.wav | 1 | 1～2 s 滑移循环 | E |
| C04 | sfx_cage_impact_01/02.wav | 2 | 0.2～0.8 s 鸡笼的笼栏接触 | E |
| C05 | sfx_glass_impact_01/02.wav | 2 | 0.2～0.8 s 空缸玻璃接触 | E |
| C06 | sfx_bomb_impact_01/02.wav | 2 | 0.2～0.8 s 球形货物壳体接触 | E |
| C08 | sfx_grab_01.wav | 1 | 0.1～0.3 s 成功加入抓取 | D |
| C09 | sfx_release_01.wav | 1 | 0.1～0.3 s 主动松手 | D |
| C12 | ui_delivered_01.wav | 1 | 0.3～0.8 s 单件首次交付 | D |
| C13 | ui_order_settled_01.wav | 1 | 1～2 s 结算确认 | D |
| C14 | ui_denied_01.wav | 1 | 0.1～0.3 s 当次失败，仅请求者 | D |
| C15 | music_transport_gray_01.ogg | 1 首 | 60 s，96 BPM、4/4、24 小节循环为作曲参考 | D |
| C18 | sfx_ufo_warning_01.wav | 1 | 1～2 s UFO 预警 | E |
| C19 | sfx_ufo_beam_loop_01.wav | 1 | 2～4 s 光束循环 | E |
| C20 | sfx_tornado_warning_01.wav | 1 | 1～2 s 龙卷风预警 | E |
| C21 | sfx_tornado_loop_01.wav | 1 | 2～4 s 风场循环 | E |
| C22 | sfx_cow_01.wav | 1 | 0.5～1.5 s 母牛短声，随事件表现限流复用 | E |
| C23 | sfx_cow_rider_warning_01.wav | 1 | 1～2 s 牛铃或来向预警 | E |
| C24 | sfx_rear_latch_01.wav | 1 | 0.2～0.5 s 后门门闩锁合、放开或复位的实际确认 | E |
| C29 | sfx_refuel_complete_01.wav | 1 | 0.5～1.5 s 室外加油交易完成 | E |
| C30 | ui_overtime_01.wav | 1 | 0.2～0.6 s 首次迟到，每单一次 | D |
| C31 | ui_route_confirm_01.wav | 1 | 0.2～0.6 s 路线锁定确认 | D |
| C32 | sfx_gel_fire_01.wav | 1 | 0.2～0.5 s 一次胶枪发射 | E |
| C33 | sfx_gel_recover_01.wav | 1 | 0.2～0.5 s 回收到枪、胶量确认 | E |
| C34 | sfx_gel_suction_loop_01.wav | 1 | 回收存在持续过程时采用，启停跟随实际状态，时长待确认 | E |
| C35 | sfx_empty_glass_break_01.wav | 1 | 空鱼缸从完好或裂纹进入破碎的短声 | E |
| C36 | sfx_refuel_loop_01.wav | 1 | 室外加油位实际加注期间循环 | E |
| C37 | sfx_rider_approach_loop_01.wav | 1 | 骑牛飞车党事件生效时的接近声，按位置播放 | E |
| C38 | sfx_horn_01.wav | 1 | 车辆已接纳的喇叭输入，可选干扰 | E |
| C39 | sfx_gel_attach_01.wav | 1 | 凝胶块实际附着的短声 | E |
| C40 | sfx_gel_peel_stretch_01.wav | 1 | 持续回收开始时的剥离与拉伸短声 | E |
| C41 | sfx_chicken_escape_01.wav | 1 | 单鸡受惊与逃出共用的短叫或扑翅声 | E |
| C42 | sfx_chicken_caught_01.wav | 1 | 本人确认抓住离笼鸡的提示 | D |
| C43 | sfx_vehicle_impact_01.wav | 1 | 车体实际碰撞的短声 | E |
| C44 | sfx_vehicle_rollover_01.wav | 1 | 确认物理侧翻的短声 | E |
| C45 | sfx_vehicle_recovery_01.wav | 1 | 成功完成基础翻车恢复的短声 | E |

当前规划 36 个资源 ID，运行时共 39 个文件，含 38 个音效文件和 1 首音乐。按表计入音效变体与条件启用的素材，母版、工程和试听文件另交。

单鸡默认装笼。声音动作时长、距离与混音按实测标定，C34 和 C40 随持续回收表现方案确认接入。受惊声与实际离笼反馈合用 C41，抓回沿用已确认抓取。

## 2. 触发与播放生命周期

| 确认来源 | 播放与清理规则 |
|---|---|
| VehicleSnapshot | EngineRunning 控制 C01/C02 启停，EngineLoad01 控制混合。SkidIntensity01 驱动 C03，渐入 0.10、退出 0.05 为待标定滞回种子 |
| ObjectImpact | 按 SurfaceId cage/glass/bomb_shell 选 C04/C05/C06。碰撞对象由 E 确认属于车体时用 C43。Intensity01 控制强弱，ImpactId 去重。同物体 0.12 s、最多两条并发作为试听参考 |
| CargoConditionChanged | 空缸首次确认 Broken 播 C35，该次碎裂声优先于普通接触。对单鸡，实际离笼确认使事件的 Condition 为 ChickenCondition 且 InCage=false，E 用 PositionM 播 C41。按 CargoId 与 ConditionRevision 核对货物条件版本 |
| CargoGrabbed / CargoReleased | D 仅在 CargoGrabbed 的 PlayerId 为本地玩家时检查该抓取。按事件的 CargoId 与 Stamp 匹配当次确认的 CargoSnapshot.Condition，确认是 ChickenCondition，且 InCage=false、SourceEntityId 等于 ChickenEntityId 时播放 C42。其他确认抓取播 C08。主动松手确认播 C09，D 用 Reason 识别回笼、掉线与重试造成的自动释放 |
| GelFired / GelRecovered | 首次确认发射播 C32，成功回收并返还单位后播 C33 |
| GelAttached | 凝胶块形成确认连接时在连接位置播 C39，按确认事件去重并限制短间隔内的同类声并发 |
| GelRecoveryStarted / GelRecoveryCanceled / GelRecovered | 有持续回收时，在确认开始播 C40，并按原请求和目标启动 C34。取消、成功、目标消失、掉线取消或回合切换时停止。重连用 GelStateSnapshot.ActiveRecoveries 恢复仍有效的 C34 |
| IncidentWarned | 按 ufo/tornado/cow_rider 播 C18/C20/C23，每个事件的首次预警一次，短声可跟随事件位置 |
| IncidentStageChanged / IncidentResolved | Active 进入时按类型开 C19/C21/C37，Recovery 淡出，Resolved 或取消释放声源。若 E 在渐退阶段还保留作用，按确认强度完成淡出。背景母牛 C22 按各事件编号和阶段限流 |
| RearLatchChanged / HornPlayed | 车辆后门门闩状态实际变化播 C24，喇叭确认播 C38，按事件编号去重 |
| VehicleRolledOver / VehicleRecoveryStarted / VehicleRecoveryFinished | 实际翻车播 C44，恢复开始时清理已失效的车辆音源，确认成功完成恢复播 C45。发动机和轮胎循环继续按 VehicleSnapshot 启停 |
| FuelRefuelStarted / FuelRefuelCanceled / TransactionCommitted | 室外开始加注按 TransactionId 启动 C36，取消、离开站点中断、断线取消或交易提交时停止。加油成功提交后播一次 C29 |
| CargoDelivered / OrderSettled / OrderBecameOvertime / RouteCommitted | C12/C13/C30/C31 分别在首次确认时播放，D 映射订单、货物或路线确认 |
| CommandResolved / GelCommandResolved | 拒绝原因由 D 按当次请求显示，可播 C14 一次。成功世界声由同一次确认事件触发 |
| 本地运输场景 | D 按场景启停 C15 循环。重连时复用或恢复一个本地音乐声源 |
| RoundReset / 离开场景 | 停止旧回合的回收、加油、车辆与事件循环，清理旧实体声源。退场时停止运输音乐，进入新场景或回合后按当前状态启用对应循环 |

共享事件按 (RoundEpoch, EventId) 去重，失败提示按原请求 Key 去重。持续声按回合、来源 ID 与音源类型登记，回收使用请求键和 GelId，加油使用 TransactionId，事件使用 IncidentId。重连从 GelStateSnapshot.ActiveRecoveries、EconomySnapshot.ActiveRefuels、车辆与事件快照恢复当前有效循环。重连后的单次声以快照版本之后的新确认触发。联调核对触发、启停、取消和重连。[API 第 9 节](../API与联调契约_v0.2.md#9-事件订阅与声音接入)

## 3. 空间、混音与制作要求

发动机参考/最远距离 3/25 m，滑移 2/20 m，货物接触 2/18 m，近距交互 1/8 m，凝胶可从 1/10 m 开始试听。步行取人物眼点，驾驶取驾驶员位置。事件声与预警方向一致，按实际作用范围试听；预警适度压低音乐，合理限制同类短声和背景母牛并发。

母版建议真峰值 ≤−1 dBTP，提交实测。标注循环采样点，检查爆音和重叠衔接。附音源与授权、工程及实际插件版本，运行时使用导出文件。

## 4. 交付与验收

- 第一批试听正常驾驶、后门门闩、抓取、鸡受惊与逃出、抓回提示、三类货物接触及空缸破碎。核对凝胶发射、实际附着、持续回收的剥离与拉伸、吸回完成和失败提示。
- 第二批联调订单、路线、室外加油和失败提示，覆盖加注完成、取消及重连时恢复仍有效的加注循环。
- 第三批用三个实际事件入口核对预警、来向和循环淡出。用独立物理翻车测试核对碰撞、侧翻、单人恢复提示及旧事件声源清理。各批附文件、母版、工程、试听和声道、时长、循环点、峰值、响度测法与体积记录。
- 耳机和普通扬声器各跑一单。用 D/E 记录核对同一确认只播一次，抢收失败、容量已满、回收与加油取消、事件取消、断线重连和回合重置均有对应反馈或清理。B 汇总采用值，未运行项记待验。

| 版本 | 日期 | 内容 |
|---|---|---|
| v0.2 | 2026-11-08 | 原运输音效与音乐 |
| v0.4 | 2026-11-15 | 货物、路线经营和预览事件的音频分组 |
| v0.5 | 2026-11-21 | 更新三货接触、空缸破碎、凝胶、门闩、加油与三个事件的触发和清理 |
| v0.6 | 2026-11-22 | 补齐凝胶附着与回收前段、单鸡和车辆事故反馈，核算资源总量并更新室外加油、重连与声音验收 |
| v0.6（鸡交互修订） | 2026-11-22 | 对齐 C41 离笼与 C42 抓回的确认触发、快照与实体映射 |
