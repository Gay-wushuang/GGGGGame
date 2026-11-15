# D 的人物、协作与 UI 功能交接单 v0.4

更新日期：2026-11-15。采用[灰盒设计 v0.4](../灰盒设计_v0.1.md)及[API v0.4](../API与联调契约_v0.2.md)。沿用文件名，替换旧版待同步说明。以下为后续实现任务；现有 GDScript 场景只用于比例和事件概念观察，不是完整人物/联机/送货系统。

## 1. 完整职责

D 交付1～4人可操作的人物作业包、基础会话和全部玩家界面：实体手册/改键、共同搬运、镜头、订单计时与工资预估、路线选择、商店/修理/油/道具/升级交互、事件预警和反制提示。E 统一裁决车货、订单、路线、钱和事件，D 不在客户端另算最终状态。

单人可开始并完成装卸、驾驶和应急；多人自由分工，同物件最多两人同时施力，整局最多四人。步行/装卸第一人称，驾驶第三人称，乘员第一人称；后舱平稳行驶能活动。

## 2. 逐项功能

| 编号 | D 实现 | 规则与依赖 |
|---|---|---|
| D01 人物 | 移动、站蹲、碰撞、跳跃、车内移动、恢复与断线关联清理 | 默认1.5头身，站高1.20/头0.80/碰撞直径0.80/视觉宽0.96/眼高1.02，蹲高0.85/眼高0.70 m |
| D02 手册/绑定 | 出生引导、实体手册阅读、本地独立页码，设置改键和冲突反馈 | 靠近空手E阅读、Esc关，一本多人同时读；无自动弹窗和随身F1 |
| D03 镜头 | 上下文优先级、切换、避障与失效恢复 | 座位100、注册地点10、默认0，地点白名单空；确认座位驱动切换 |
| D04 共同操作 | 抓取、旋转、目标、松手、每人独立抓点与力贡献 | 每人一物/每物两人，35kg每人支持能力，向E同一物理步提交 |
| D05 运输HUD | 速度、油/HP、载荷、巡航、货物品质与固定状态、参与者、失败原因 | 显示E确认快照，显示单位与风险原因 |
| D06 订单UI | 出库确认、剩余/超时时间、品质运费、预计扣薪、交付损失、结算明细 | E启动时钟/生成Settlement；t=720不扣，零秒后可继续 |
| D07 路线UI | 画层状图，显示可用出边、服务、预计时间油量、风险，司机停车预选、停车点击确认提交后权威锁定 | 发RequestSelectRoute预选、RequestCommitRoute确认和预期Revision，不在UI私自锁定 |
| D08 商店/应急UI | 读共享钱包/库存/报价，购买、油、维修、道具、升级、免费救援入口 | 原子结果才改显示；处理中防重复点但不能以按钮禁用代替幂等 |
| D09 事件UI | Warn倒计时、方向/作用圈、货物/车销/轮胎提示、反制持续进度 | 消费E IncidentSnapshot，操作请求交E；不本地生成事件或伤害 |
| D10 会话 | 1～4人生成/映射、输入投递、只读状态传播、断线重连、快照版本过滤 | 会话上限4，空位不阻止开局，共享钱包和时间保持一致 |
| D11 表现与声音 | A01基础动作、本地头部隐藏、确认交互/结算/路线反馈 | 接C08/C09/C12～C15/C30/C31；EventId去重，循环随快照重建 |
| D12 检查和交付 | 构建、逻辑/边界/联调检查、运行说明与互审 | 与E互审，B组织接收，未运行项标待验 |

## 3. 货物与空间的具体变化

标准货物变为两鸡笼18 kg、两鱼缸35 kg、两炸弹45 kg，总196 kg。18 kg鸡笼允许低于空手的携物跳跃；鱼缸/炸弹先释放跳跃者本人抓取，再让人物跳，货物不获跳跃冲量，其他参与者继续。鱼缸虽可单人抱持，仍按易碎货规则禁止通过携物跳跃规避运输风险。

车辆最大外宽3.00、长8.80、高3.50 m，后舱净宽2.70、长5.80、高2.68，地板0.70，顶棚0.12。隔断净门1.10×1.90，后门1.80×2.00。空车四人、六货三人均按纵向错列检查；取消旧五人并排。双人搬运时第三人用前后避让区，不能声称狭窄中路可以并排超车。

每人速度/施力依主文档种子标定，35 kg支持、650 N抱持/450 N推拖仅为初值。所有标准货物存在单人经斜板装卸方案。平稳后舱活动保持OnFoot，SupportedVehicleId表示承载；不能把所有后舱人员当作座位乘员。

## 4. API 提供和调用

| D 提供 | 入口 |
|---|---|
| IPlayerService | SubmitInput、ReadPlayer、PlayerChanged |
| IInteractionService | RequestGrab、RequestRelease、SubmitGripTarget、ReadParticipants |
| 镜头/手册/绑定 | EnterContext/ExitContext、TryOpenWorldHandbook/CloseHandbook、ReadBindings/TrySetBinding |
| ISessionService | Connect/Disconnect、LocalPlayerId、IsPhysicsAuthority、PlayerJoined/Left及状态投递 |

| 消费E | 使用方式 |
|---|---|
| ReadCargo/Vehicle、AddForceContribution | 目标和受力；仅权威内部调用受力入口，客户端原始请求先验证 |
| 座位/门/固定/巡航/RequestHorn请求 | E确认后同步人物、镜头与HUD，失败显示原因 |
| ReadOrder/ReadRouteGraph | 渲染倒计时、运费、节点/边；E的权威时钟为准 |
| RequestStartOrder/SelectRoute/CommitRoute/ConfirmCargoLost | 司机出库、停车选路、明确确认损失，不在菜单操作时停表 |
| ReadEconomy、RequestPurchase/Service/Refuel/UseItem | 传站点、报价ID、数量和预期修订，不传客户端价格或余额 |
| ReadIncidents、RequestCounterIncident | 发反制动作、目标和持续输入，权威检查距离/速度/阶段 |
| SnapshotChanged/GameplayEventRaised | 状态显示、声音和动画；旧回合/旧修订过滤，事件去重 |

按API规格实现Connect(SessionOptions options)、Disconnect()、IsPhysicsAuthority、LocalPlayerId及PlayerJoined/Left；SessionOptions至少含会话角色、地址、MaxPlayers=4、配置ID。会话不能决定工资或事件随机结果。实际网络工具链由工程验证后补交。

## 5. 交互、输入和生命周期约束

每人局部抓点、世界目标与序号分别保存。P2追加，松手只移除本人，同物件不同玩家贡献同时进入E，不得用单一owner排斥协作。UI打开、失焦发送中性移动；阅读/地图/商店/设置不停止共享时钟或重力。驾驶UI不能吞掉刹车/手刹取消巡航输入。

服务与路线请求带expectedRevision，冲突后刷新并说明状态已变。重复请求可返回原收据，不再次播放成功音。订单失物确认显示该件q=0和运费影响，玩家明确点击才请求；爆炸由E裁决终态，偷走先StolenRecoverable、可追回，过下节点边界或主动确认才Lost。

事件提示包含免费反制：UFO离开光束或提前停车；龙卷风进安全区；骑牛飞车党停车赶走/保销；牛雨看落点绕行；哈吉米停车每只2s移除。Q喇叭经RequestHorn/CounterAction.Honk发同一意图、权威5s冷却打断牛骑党接近；鱼干/备用销/其他道具是节省时间选项。基础Full固定有4个免费复用槽，每槽一件，额外绑带才收费。哈吉米两只最多降低20%转向，不显示“轮胎已锁死”。事件预览标“概念预览”，不能显示已接通订单或物理结果。

重置清理上下文/输入/旧请求，切换新RoundEpoch；重连用快照恢复当前阶段、钱包与事件循环，不补播历史单次提示。司机断线由E制动，空驾驶位可由其他人接替；一人剩余时仍可完成。

## 6. 目标文件和运行入口

后续人物模块放 who-sent-this-guy/features/player_operations/，包含PlayerOperations.tscn、PlayerController/Input/Definition、InteractionService、CameraContextController、HandbookWorld/Panel、BasicBindingsPanel、PlayerHud。路线/订单/商店/事件UI可拆至features/delivery_ui/。公共契约shared/contracts，由B版本管理；会话shared/session/SessionAdapter.cs。

正常入口目标为E的scenes/graybox_delivery.tscn，当前实际独立入口仍为greybox/scale_validation.tscn。测试放tests/player_operations，统一入口tools/ci/run-graybox-checks.ps1；交付说明docs/实现/D_人物作业交付.md。这些均为目标路径，不代表现已存在。

## 7. 验收与五条线

- 1.5头身站蹲碰撞/眼点、真实门洞、车内OnFoot移动，四人和六货三人纵向空间。
- 单人三货装卸；双人同向/反向/不同抓点，P1松手或断线P2保留，超时和重置清理。
- 实体手册多人独立页码、改键刷新和冲突取消；无旧自动手册行为。
- 驾驶镜头确认切换、刹车/手刹取消巡航、菜单开着仍推进订单。
- 路线Revision冲突、商店并发和重复点击、超时不强制失败、单次结算明细一致。
- 五事件警告/免费反制可理解，1人能停车操作，重连快照及声音清理。
- 1/2/3/4人各有完整流程记录；UI不决定权威时间、钱、品质或物理。

策划线回报体验/参数差异；文档线记录实际路径/调用/版本；实践线交可运行增量；CI线交真实构建/逻辑/边界结果；审查线交E互审处理与B复核。不得将上述计划项写成已通过。

| 版本 | 日期 | 内容 |
|---|---|---|
| v0.3 | 2026-11-10 | 实体手册、多人、后舱与跳跃 |
| v0.4 | 2026-11-15 | 新比例、三货、限时工资/路线/商店/事件UI、权威边界和生命周期 |
