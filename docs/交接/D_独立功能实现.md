# D 的人物、协作与玩家侧接入交接单 v0.6

更新日期为 2026-11-22。D 使用 **DSH Agent**，交付人物控制、镜头、抓取与工具操作、输入绑定、HUD、房间界面和玩家侧联机。D 接操作意图、玩家侧反馈与服务消费。E 裁决车货物理、货物状态、凝胶、订单和正式联网，B 确认接口语义。以下为开发任务与验收规格。[灰盒设计 v0.5](../灰盒设计_v0.1.md) · [API 与联调契约 v0.6](../API与联调契约_v0.2.md)

## 1. 功能交付

| 编号 | D 实现 | 规则与依赖 |
|---|---|---|
| D01 人物 | 移动、站蹲、碰撞、跳跃、车内移动与玩家侧恢复 | 默认 1.5 头身，站高 1.20、头直径 0.80、碰撞直径 0.80、视觉宽 0.96、眼高 1.02，蹲高 0.85、眼高 0.70 m |
| D02 手册与绑定 | 准备区实体手册、本地独立页码、改键和冲突反馈 | 靠近、空手、面向手册后交互，四页说明移动、凝胶、驾驶与应急，HUD 读取实际绑定 |
| D03 镜头 | 上下文优先级、切换、避障与失效恢复 | 步行、装卸和后舱第一人称，驾驶第三人称，其他已配置座位第一人称。按 E 确认座位切换 |
| D04 共同操作 | 选物与抓取、调整距离、旋转、松手、鸡笼门操作入口，以及离笼鸡的抓取、携带和放回输入 | 各玩家提交自己的抓点和目标，E 裁决每人一个物理目标、每实体最多两人与实际受力。笼门正式映射见第 2 节 |
| D05 凝胶枪操作 | 持枪与切换、瞄准、发射与回收目标选择、发射与回收输入、取消操作、枪颜色、储量与容量、成功和失败反馈 | 向 E 的 IGelService 提交意图。按确认结果与快照显示满枪、正被处理、已回收、过期或不可达等状态 |
| D06 运输 HUD 与订单 | 速度、油量/容量、载荷、偏载、巡航、货物状态、凝胶连接、出库操作、倒计时、鸡笼交付选择与结算显示 | 使用 E 的确认快照、订单清单与结算。迟到可继续，显示单鸡可抓回、回笼、待确认交付、已交付或确认丢失，结算单列包装未归还费 |
| D07 路线与加油 | 层状图、合法出边、预计时间/油量、风险、室外加油报价、可注入量、进度与收据 | 司机停车预选与确认，由 E 锁定。商店仅呈现加油与共享钱包，使用带版本的升数请求 |
| D08 事件与恢复提示 | UFO、龙卷风、骑牛飞车党的方向、阶段、实际应对，以及翻车恢复提示 | 根据 E 的事件与车辆状态显示。驾驶避让、门闩、凝胶操作及可选喇叭走现有入口 |
| D09 房间与玩家侧联机 | 建房/连接/离开的界面操作、成员与队友状态、失败与掉线提示、重连后呈现、输入投递 | 调用 E 的 ISessionService，按确认玩家 ID 绑定操作与队友显示。1～4 人可开始，房主端裁决与正式连接由 E 实现 |
| D10 表现与声音 | 正常人物动画、局部物理反馈、本地头部隐藏、持枪瞄准、确认交互与本地音频 | 按 A 的挂点及 C 的音频映射接本地交互与提示声，按事件 ID 和请求键去重 |
| D11 检查与回交 | 独立玩家测试场、可替换模拟服务、运行说明、边界测试与互审 | B 组织验收，E 参与真实服务接入，记录实际结果 |

平稳行驶时后舱保持 OnFoot，SupportedVehicleId 表示实际承载关系。身体质量、移动和施力参数按灰盒第 5.1 节标定。围绕确认门洞和后斜板，分别试空舱四人、临时三货加三人，以及两人共同搬一件时第三人避让。

行走、奔跑、抓取和搬运由常规角色控制器稳定驱动。D 按实际物理状态接入急刹、碰撞与翻车的短时失衡、摔倒及适度布娃娃反馈，反馈限于对应阶段，恢复后回到常规控制。实现方案与参数随实测确定。

试装为单笼一鸡、一个空鱼缸、一个球形货物，首关最终数量和品质方案待确认。单人 35 kg 支持能力、抱持 650 N、推拖 450 N 为待标定种子。轻重货携物跳跃按实际质量标定，重货释放本人抓持后起跳，其他参与者继续。胶枪的暂行操作为本人先松手再切枪，另一人保持抓持，键位及持货时能否切枪待确认。

## 2. 操作入口及 API 调用

| D 操作 | 提供或调用的接口 | 接入结果 |
|---|---|---|
| 人物与本地工具 | D 提供 IPlayerService、ICameraContextService、IHandbookService、IBindingsService | E 接入人物模块和确认状态，D 控制本地操作与界面 |
| 抓取、目标、松手与回笼 | 调用 E 的 IPhysicsObjectService，RequestGrab、SubmitGripTarget、RequestRelease、RequestReturnChickenToCage、ReadCargo、ReadParticipants | 按 `TargetEntityId` 分组显示确认参与者、人数和抓点，同一货保留不同实体的操作 |
| 鸡笼门开合 | 调用 E 的 IPhysicsObjectService，RequestSetCageDoor、ReadCargo | 以确认的 CageDoorOpen、CageDoorRevision 和 CommandResolved 呈现开合及反馈 |
| 车辆驾驶、座位、车门、后门门闩与恢复 | 调用 E 的 IVehicleService，SubmitDriveInput、RequestEnterSeat/RequestExitSeat、RequestToggleCruise、RequestSetDoor、RequestSetRearLatch、RequestRoadsideRecovery | 确认后切镜头、显示实际门闩或恢复状态，S 和手刹同次输入取消巡航 |
| 胶枪 | IGelService 的 RequestFireGel、RequestRecoverGel、RequestCancelGelRecovery、ReadGelState | 以 GelCommandResolved 和 GelStateChanged 驱动胶量、准星目标、操作进度与结果 |
| 订单和路线 | IOrderService / IRouteService 的 RequestStartOrder、RequestSelectRoute、RequestCommitRoute、RequestConfirmCargoLost、RequestEndOrder、RequestReset | 显示确认时钟、交付、主动结束与重试，按 RouteRevision 提交预选和锁定 |
| 单鸡交付选择 | 调用 E 的 IOrderService，`ReadOrder`、`RequestResolveChickenDeliveryChoice` | 显示确认的 `ChickenDeliveryChoice`，提交选择并按 `CommandResolved` 和确认快照反馈，结算读取 `PackagingFeeFen` 与 `NetPayFen` |
| 室外加油 | IEconomyService 的 ReadRefuelQuote、RequestRefuel、ReadEconomy | 提交站点、车、请求升数和报价版本，消费收据与实际注入量 |
| 正式会话 | ISessionService 的 CreateRoom、Connect、Disconnect、ReadSession 与 SessionChanged | D 绑定房间和玩家状态，按确认 ID 投递操作及恢复界面 |

D 选择鸡、笼体或其笼门。`CargoId` 标识订单货物与默认笼体。用 `ReadParticipants(cargoId)` 按 `TargetEntityId` 计算各实体的抓持数。笼内鸡通过默认笼体操作。对离笼鸡，抓取、持续抓持和松手的 `targetEntityId` 使用 `ChickenEntityId`。回笼调用 `RequestReturnChickenToCage`，提交 `CommandKey`、`CargoId`，以确认的 `ConditionRevision` 填入 `expectedConditionRevision`。用 `ChickenCondition.Pose`、`InCage`、确认抓持与订单状态呈现位置、携带、回笼、交付与丢失。C42 按当次 `CargoGrabbed` 确认播放。[API 第 3 节](../API与联调契约_v0.2.md#3-人物共同抓取与力贡献) · [C 音频触发](C_音乐与音效.md#2-触发与播放生命周期)

笼门开合调用 `RequestSetCageDoor`，提交 `CommandKey`、`CargoId`、目标开合值 `open`，以确认的 `CageDoorRevision` 填入 `expectedCageDoorRevision`。开合与回笼的结果用 `CommandResolved`，拒绝原因用 `ReasonKey`，状态按 `SnapshotChanged` 读取 `ReadCargo` 的确认快照。具体键位、抓回与回笼流程、回笼是否须开门由 B 确认。[API 第 4.1 节](../API与联调契约_v0.2.md#41-车辆门闩与货物状态)

现有室外交付界面按灰盒第 10.3 节显示缺笼提示，报价取 `ChickenDeliveryChoice.PackagingFeeFen`。`RequestResolveChickenDeliveryChoice` 使用 `CommandKey`、当前 `OrderId`、选择中的 `CargoId`，以 `ChickenDeliveryChoice.Revision` 填入 `expectedChoiceRevision`。「返回取鸡笼」和明确取消传 `deliverWithoutCage=false`，「仍然交付」传 `true`。D 从 `CommandResolved` 读结果或拒绝原因，按 `SnapshotChanged` 刷新选择和终态。重传复用原请求键，重连以确认快照恢复提示或结算。显示 `Settlement.PackagingFeeFen` 为「包装未归还费」，按 `NetPayFen` 显示最终实发。复用现有 UI 确认、拒绝和 `CargoDelivered` 反馈。[灰盒交付判定](../灰盒设计_v0.1.md#103-交付判定) · [API 第 6 节](../API与联调契约_v0.2.md#6-订单路线与结算)

发射提交本地瞄准方向和命中提示，回收提交 TargetGelId，两者均包含 Key、GunId 与 ExpectedGunRevision，Key 包含回合、玩家、请求和输入编号。HUD 从确认的 StoredUnits / CapacityUnits 与枪颜色读值。请求处理中展示等待，使用绝对库存和最新确认版本刷新，收到原请求重传结果时保持同一次结算。库存、胶块身份、连接与弹性约束由 E 裁决，D 按同一版本的确认结果呈现。

跨玩家回收以当前执行者的枪为准。测试回收者再次发射时使用自己的颜色，胶块保持独立。失败结果用 API 的 GelGunFull、GelBusy、GelAlreadyRecovered 等枚举映射原因。D 分别保存每人的抓取、输入与操作上下文。UI 开启或失焦发送中性人物输入，正在运输的世界与时钟继续推进，驾驶刹车和手刹保留可达输入。

房间重连后按最新确认快照恢复队友、当前回合、库存与事件状态，旧回合的请求和提示随上下文清理。HUD 和音效用确认结果与事件驱动，回收取消或重置清理瞄准、等待和持续反馈。D 的玩家侧适配通过同一接口连接模拟服务及 E 的正式会话。[API 第 2～5 节与第 11 节](../API与联调契约_v0.2.md)

## 3. 独立玩家测试场

D/E 从同一 Git 基线各开分支并记 SHA。D 用 DSH Agent 提交独立玩家测试场和玩家功能包，目标入口为 who-sent-this-guy/tests/player_operations/player_operations_test.tscn，功能包沿用 who-sent-this-guy/features/player_operations/。共享声明、正式主场景和工程设置由 E 接入，契约变更由 B 确认。

A 静态建模期间，D 可用现有模型、静态导出件或占位几何和可替换模拟服务继续验证玩家侧。E 的正式服务接入时消费同一版共享接口。

1. 运行玩家测试场，使用占位车厢、货物和可替换模拟服务，验证走动、镜头、抓取与按实体分组的参与者反馈。用同版模拟接口验证笼门确认开合与版本冲突、鸡离笼可找回、抓持携带和回笼，以及回笼失败、交付和确认丢失的反馈。模拟两人抓笼加第三人抓离笼鸡及笼内抓取拒绝。
2. 选择枪并瞄准测试胶块，通过同一接口提交操作。模拟发射成功、回收成功、满枪 GelGunFull、目标已被回收 GelAlreadyRecovered，核对每次请求字段、胶量、反馈和目标状态。
3. 模拟房间成员进出、队友确认状态与掉线重连，验证玩家映射、过期请求处理和房间界面。模拟只交鸡和返回取笼、取消、重复操作和重连后的有效选择或结算，核对拒绝、包装费与实发显示。交接附场景入口、模拟用例、采用配置及实际日志。

## 4. 与 E 首次联调

用 D 的角色在本地权威场景瞄准 E 的真实胶块，按测试回收键提交 RequestRecoverGel。E 更新目标胶块、相关连接及回收者枪库存，D 根据确认结果显示储量增加一单位。先核对这一条链路，再跑满枪拒绝与两个玩家抢收同一块，记录两端请求键、结果版本和 HUD。单人装运卸闭环通过后，由 E 接正式联网，D 将房间界面和玩家侧输入切到同一正式会话入口。[API 并行开发约定](../API与联调契约_v0.2.md#11-de-并行开发约定)

## 5. 验收与五条线

- 交常规移动、跑步、抓取与搬运稳定性，以及急刹、碰撞与翻车时的局部反馈记录。保留站蹲、眼点、手册、改键、驾驶镜头及后舱活动检查，1～4 人按实际人数操作。
- 交单人三类试装货物装卸与双人同物不同抓点记录，松手和掉线只移除本人操作。
- 交单鸡各阶段的确认反馈、室外加油界面、UFO/龙卷风/骑牛飞车党的提示和单人翻车恢复入口。对照模拟和权威确认检查笼门状态与拒绝反馈，验证 C42 在重传、断线、重连时按同一确认去重。
- 交模拟服务在场景中可替换的证据，验证发射、回收、满枪、已回收、重复确认、胶量和失败原因。
- 交真实回收链路及房间界面验证记录，接入后覆盖 1～4 人、队友状态、掉线提示、恢复和旧回合清理。
- 交付说明注明启动入口、基线 SHA、契约版本、模拟或真实服务、参数与未执行项。策划线回报行为差异，文档线记录依赖和版本，实践线交可运行场景，CI 测试线交真实构建与回归结果，审查线交互审和复测。B 统一接收。

| 版本 | 日期 | 内容 |
|---|---|---|
| v0.3 | 2026-11-10 | 实体手册、多人、后舱与跳跃 |
| v0.4 | 2026-11-15 | 比例、协作、路线和玩家界面 |
| v0.5 | 2026-11-21 | DSH 玩家侧、凝胶操作、房间与独立模拟场景，明确首次回收联调 |
| v0.6 | 2026-11-22 | 明确单鸡输入与状态反馈、笼门契约缺口、持枪 HUD 和加油界面，补齐占位开发与玩家侧验收 |
| v0.6（鸡交互修订） | 2026-11-22 | 接入统一的抓取、回笼和笼门契约，更新确认反馈与独立测试规格 |
| v0.6（鸡笼交付修订） | 2026-11-22 | 同步按实体计数、室外交付选择、版本反馈及包装费用显示 |
