# API 与联调契约 v0.6

更新日期为 2026-11-22。玩法、尺寸和参数状态采用灰盒设计 v0.5，工程职责采用本轮分工。以下 C# 签名、目标目录和联调步骤为开发规格，实际完成状态由运行和测试记录确认。[灰盒设计 v0.5](灰盒设计_v0.1.md) · [B 统筹总表](交接/B_策划_API与协调.md)

## 1. 服务边界与共同基础

| 服务 | 实现方 | 调用方与职责 |
|---|---|---|
| IPlayerService | D | D 的玩家操作提交人物输入，E 在权威端接入 D 的人物模块，读取角色姿态、抓持和实际承载状态 |
| ICameraContextService / IHandbookService / IBindingsService | D | 本地镜头、手册与实际按键绑定，E 的确认座位状态驱动镜头上下文 |
| ISessionService | E | D 的房间界面和玩家侧接入发出建房、连接、离开及输入请求，消费会话状态、成员列表、确认快照和事件。E 实现正式会话、房主端裁决、同步与断线处理 |
| IPhysicsObjectService / IVehicleService | E | D 提交抓取目标、回笼、笼门开合、座位、驾驶、门闩和恢复请求。E 裁决抓取参与、鸡、笼体与笼门状态、受力、门、巡航、车货和载荷 |
| IGelService | E | D 提交凝胶枪发射、回收与取消请求，从确认结果和快照更新胶量、目标和反馈。E 裁决库存、实体、附着、约束和回收 |
| IOrderService / IRouteService | E | D 提交出库、损失确认、单鸡交付选择和选路请求，显示订单时钟、货物状态、分支和结算，E 裁决交付与包装未归还费 |
| IEconomyService | E | D 显示共享钱包、燃油与加油报价，提交加油请求。E 确认燃油、费用和交易 |
| IIncidentService | E | E 按路线与物理状态推进三个特殊事件，D 显示预警和应对，C 提供声效 |

B 确认接口语义、参数状态和版本。E 统一接入共享 C# 类型、正常主场景和工程级设置。共享声明目标目录为 who-sent-this-guy/shared/contracts，沿用建议命名空间 DeliveryGame.Contracts。D 的操作入口通过同一组服务接口调用模拟实现或正式实现。单机由本地权威实例裁决，正式房间由 E 接入房主端裁决。具体网络传输方案由 E 试验后交 B 评审。

~~~csharp
// ISessionService
void CreateRoom(RoomOptions options);
void Connect(SessionOptions options);
void Disconnect();
SessionSnapshot ReadSession();
CommandKey CreateCommandKey(ulong inputTick);
bool IsPhysicsAuthority { get; }
ulong? LocalPlayerId { get; }
event Action<SessionSnapshot> SessionChanged;
event Action<ulong> PlayerJoined;
event Action<ulong> PlayerLeft;
event Action<StateStamp> SnapshotChanged;
event Action<CommandResolution> CommandResolved;
event Action<GameplayEvent> GameplayEventRaised;
~~~

RoomOptions 提供关卡配置，SessionOptions 提供房间或连接入口信息。SessionSnapshot 提供会话阶段、失败原因、房间与本地玩家 ID、房主 ID、成员列表、连接状态和版本。房间支持 1～4 人，玩家在同一回合重连时恢复原身份及已确认状态。D 支持模拟创建、加入、退出、掉线和重连状态来开发界面。

共同单位为 m、kg、s、N、rad/s，角度字段带 Deg 时用度。坐标 Y 向上、车前向 −Z，三维代理尺寸字段 SizeM 按宽 X × 高 Y × 长 Z。人物默认 1.5 头身，站高 1.20 m、蹲高 0.85 m，头直径 0.80 m、视觉宽 0.96 m、碰撞直径 0.80 m，眼高 1.02 / 0.70 m。车外部长宽高 8.80 × 3.00 × 3.50 m，后舱净长宽高 5.80 × 2.70 × 2.68 m，道路总宽 6.00 m。门洞、斜板和顶棚按灰盒第 5 节测量。

## 2. 标识、权威、结果与幂等

| 类型 | 必需字段和语义 |
|---|---|
| CommandKey | RoundEpoch、PlayerId、RequestId、InputTick。离散请求 ID 在同一玩家和回合内跨服务唯一，重传沿用原键，重连继续该回合的编号空间 |
| StateStamp | RoundEpoch、StateTick、Revision。权威提交以共同标记关联同一次变化，下发时据此确认版本 |
| PoseState | PositionM、Rotation、LinearVelocityMps、AngularVelocityRadps 和采样版本 |
| CommandResolution | Key、Code、TargetId、Stamp、ReasonKey。Code 为稳定枚举，ReasonKey 供 D 映射文本 |
| GameplayEvent | EventId、Stamp、Kind、SourceEntityId、ActorPlayerId、PositionM 及第 9 节专属载荷。跨端按 (RoundEpoch, EventId) 去重 |

常用 ResultCode 包括 Accepted、InvalidRound、InvalidActor、NotAuthorized、TargetMissing、OutOfReach、Obstructed、HandsBusy、GripFull、SeatOccupied、VehicleMoving、NoSafeExit、StateChanged、InvalidState、InsufficientFunds、FuelTankFull、NoFuelToAdd、RouteUnavailable、OrderClosed、Cooldown、Cancelled。凝胶另有 GelGunEmpty、GelGunFull、GelBusy、GelAlreadyRecovered、GelLimitReached。D 使用相同代码驱动模拟和联调反馈。

权威端先校验回合和已认证的发送者，再查 (RoundEpoch, PlayerId, RequestId) 幂等记录，随后校验资格和相关版本。相同请求重传取得原确认结果或等待同一处理中请求。离散操作只有首次提交改变状态和产生确认事件。旧回合拒绝，当前回合的快照按版本应用。连续输入按玩家和输入流保留最新样本，过期输入停止生效。静止收敛 0.05 m / 2° 和输入过期 0.3 s 为待验证种子。

E 的会话接入先应用同次提交涉及的状态，再通知 SnapshotChanged，各读取服务返回对应的确认快照。通用离散请求使用 CommandResolved，凝胶发射和回收使用第 4.2 节的专属确认。重连用确认快照恢复持续状态，快照前的单次事件由其已确认版本去重。

E 未完成的请求按生命周期取消，已完成的请求按确认记录恢复。司机断线时清本人抓取和座位、关闭巡航并安全制动，其他参与者继续。重连先重建确认快照和成员映射。房主退出时按已验证的快照恢复能力处理，暂缺迁移能力时明确结束并提供可用的重试入口。

## 3. 人物、共同抓取与力贡献

~~~csharp
// IPlayerService
void SubmitInput(CommandKey key, CharacterInput input);
PlayerSnapshot? ReadPlayer(ulong playerId);

// IPhysicsObjectService
void RequestGrab(CommandKey key, ulong cargoId, Vector3 localPointM,
    ulong? targetEntityId = null);
void RequestRelease(CommandKey key, ulong cargoId, ulong? targetEntityId = null);
void SubmitGripTarget(CommandKey key, ulong cargoId,
    Vector3 positionWorldM, Quaternion rotationWorld, ulong? targetEntityId = null);
GripParticipant[] ReadParticipants(ulong cargoId);
CargoSnapshot? ReadCargo(ulong cargoId);
~~~

CharacterInput 包含 MoveAxis、LookDeltaRad、SprintHeld、CrouchHeld、JumpPressed。PlayerSnapshot 包含 PlayerId、Stamp、Pose、LifeState（Active / Recovering / Disconnected）、LocomotionMode（OnFoot / Seated）、Stance、HeldCargoId、SeatedVehicleId、SeatId、SupportedVehicleId 和 BodyMassKg。SupportedVehicleId 表示实际由车承载，适用于平稳行驶中在后舱步行的人。

GripParticipant 保留 PlayerId、CargoId、TargetEntityId、LocalPointM、TargetPositionM、TargetRotation、GripMode 和 LastInputTick。每人同一时刻最多抓持一个物理实体，每个实际 `TargetEntityId` 最多两名参与者。D 发各自目标，E 解析默认或显式目标并校验可达、视线、空手与实际物理条件，在确认抓持时按目标实体校验上限，满员返回 `GripFull`。初始抓取目标取当前抓点，抓扶已有凝胶约束的货物时保持约束和碰撞。松手、超距和失联只解除对应参与者。

`cargoId` 标识货物。通用抓取、持续抓持与松手的 `targetEntityId` 为空时使用默认实体。单鸡货物的默认实体是笼体，显式指定笼体时使用同一个 `CargoId` 值。鸡实际离笼后，操作时传本货物的 `ChickenEntityId`，局部抓点相对于实际目标实体。`InCage=true` 时对鸡的独立抓取返回 `InvalidState`，在笼鸡通过笼体搬运。E 校验目标归属，持续输入与松手匹配申请者的确认抓持。`ReadParticipants(cargoId)` 返回该货物的全部参与者，按 `TargetEntityId` 区分实际抓取的鸡或笼体。

两名玩家抓持笼体占用默认实体的两个名额。第三人抓取离笼鸡时使用 `ChickenEntityId` 对应的名额，三者沿用同一 `CargoId`。

E 按各玩家的局部抓点、目标与力上限计算权威 ForceContribution。同一物理步的同一玩家、实体和作用类型取最新输入，各参与者的力与力矩相加，步后清缓存。支持质量 35 kg/人、抱持 650 N、推拖 450 N 及强制松手阈值沿用为待标定参数。姿态变化检查完整碰撞体积。轻、重货携物跳跃按灰盒第 5.1 节和实际标定分组，释放时仅移除跳跃者本人的抓持，货物运动由剩余作用和碰撞决定。

## 4. 车货物理、门闩与凝胶枪

### 4.1 车辆、门闩与货物状态

~~~csharp
// IVehicleService
VehicleSnapshot? ReadVehicle(ulong vehicleId);
void RequestEnterSeat(CommandKey key, ulong vehicleId, string seatId);
void RequestExitSeat(CommandKey key);
void SubmitDriveInput(CommandKey key, ulong vehicleId, DriveInput input);
void RequestToggleCruise(CommandKey key, ulong vehicleId);
void RequestHorn(CommandKey key, ulong vehicleId);
void RequestSetDoor(CommandKey key, ulong vehicleId, string doorId,
    bool open, uint expectedDoorRevision);
void RequestSetRearLatch(CommandKey key, ulong vehicleId,
    bool latched, uint expectedDoorRevision);
void RequestRoadsideRecovery(CommandKey key, ulong vehicleId);

// IPhysicsObjectService
void RequestReturnChickenToCage(CommandKey key, ulong cargoId, uint expectedConditionRevision);
void RequestSetCageDoor(CommandKey key, ulong cargoId,
    bool open, uint expectedCageDoorRevision);
~~~

| 类型 | 必需字段 |
|---|---|
| VehicleSnapshot | VehicleId、Stamp、Pose、SpeedMps、RollDeg、LoadMassKg、OccupantMassKg、TransportedSystemMassKg、VehicleRigidBodyMassKg、EffectiveCenterOfMassLocalM、EngineRunning、EngineLoad01、SkidIntensity01、Seats、Doors、CruiseEnabled、CruiseTargetMps、HornCooldownRemainingSeconds、FuelLiters、FuelCapacityLiters、IsRolledOver、RecoveryInProgress、RecoveryAvailable、RecoveryReasonKey |
| SeatSnapshot | SeatId、OccupantPlayerId、SeatTransform、ExitCandidates |
| DoorSnapshot | DoorId、Open、LatchState、Revision。后门门闩采用 Latched / Unlatched，门闩状态与门扇开合分别呈现 |
| DriveInput | ForwardAxis 和 SteeringAxis 取值 [−1,1]，HandbrakeHeld |
| CargoDefinition | DefinitionId、SizeM、ShapeKind、SphereDiameterM（球形时）、MassKg、SurfaceId、BaseFeeFen、参数版本 |
| CargoSnapshot | CargoId、DefinitionId、OrderId（准备阶段可空）、Stamp、Pose、MassKg、Participants、GelConnectionIds、Quality01、Condition、ConditionRevision、Status |
| CargoStatus | Pending、StolenRecoverable、Delivered、Lost、Destroyed。后三项为订单终态，同件最多计入一次 |
| 条件载荷 | 单鸡货物用 ChickenCondition，空鱼缸用 Intact / Cracked / Broken，球形货物读取姿态、滚动和交付状态 |
| ChickenCondition | `ChickenEntityId`（ulong）、`InCage`（bool）、`Pose`（PoseState，鸡的世界姿态）、`CageDoorOpen`（bool，确认开合）、`CageDoorRevision`（uint，笼门版本）、`CageLeftInLevel`（bool，默认 `false`，只交鸡后留在本关的未归还笼体标为 `true`）。`CargoSnapshot.Pose` 为笼体姿态，两实体姿态与留笼标记按快照 `Stamp` 同步。`ConditionRevision` 随实际入笼或离笼变化，`CageDoorRevision` 随实际开合变化 |

临时试装用 chicken_cage（笼外包围 0.80 × 0.70 × 0.60 m，单笼一鸡，默认入笼）、fish_tank（空缸 0.90 × 0.75 × 0.65 m）、bomb（球直径 0.65 m，球形碰撞）。接触材质键沿用 cage、glass、bomb_shell。首关件数及品质方案待确认，质量、运费和空缸重击阈值待标定。订单总量和满品质运费按配置清单统计。空缸的裂纹与破碎由实际独立碰撞提交，品质由 E 按灰盒第 7 节所采用的配置裁决。

E 管理单只鸡、笼体与笼门。`CargoId` 在订单中标识一件货物，同时用作默认笼体的实体 ID。`ChickenCondition.ChickenEntityId` 是该鸡的独立实体 ID，鸡及笼体的实体 ID 在同一回合各自唯一且稳定。二者始终关联同一 `CargoId` 和至多一个已签发 `OrderId`，各自具有物理姿态。笼门是该笼体的唯一开合部件，以所属 `CargoId` 寻址。

初始鸡在笼中。实际逃出时确认 `InCage=false` 和鸡的姿态并递增 `ConditionRevision`，保留原订单状态。该货物未终结时，离笼表示可以找回。抓持和携带由实际 `TargetEntityId` 的参与关系与鸡的姿态表示。回笼以 `InCage` 恢复为 `true` 的确认变化表示。`Delivered` 和 `Lost` 仍按第 6 节由订单裁决。

`RequestReturnChickenToCage` 按第 2 节校验 `CommandKey`，用 `expectedConditionRevision` 匹配当前 `ConditionRevision`。E 核对双方实体归属、货物可操作、鸡在笼外、请求者已确认抓持该鸡及回笼可达条件。成功时同次提交更新鸡的姿态、`InCage`、`ConditionRevision` 并解除该鸡的抓持，保留笼体的有效抓持。回笼是否须开门、具体抓回与回笼操作、逃出触发和行为参数待 B 确认。若确认需要开门，E 在提交时检查 `CageDoorOpen`。

`RequestSetCageDoor` 由 D 提交目标开合值 `open`，E 校验本回合玩家资格、`CargoId` 对应的笼体和笼门、可达与遮挡、货物可操作状态以及 `expectedCageDoorRevision`。确认开合发生变化时同次更新 `CageDoorOpen`、`CageDoorRevision` 和快照 `Stamp`。若版本匹配且开合已满足请求，确认 `Accepted` 并返回当前版本。同一版本的并发改变以首次实际提交为准，后续旧版本请求返回 `StateChanged`，同一 `CommandKey` 重传按第 2 节取得原结果。`IVehicleService` 的车门、门闩和车辆 `DoorSnapshot` 用于车辆。

回笼与笼门请求均由 `CommandResolved` 返回结果，`TargetId` 使用原 `CargoId`。失败使用现行结果码及 `ReasonKey`，例如无目标 `TargetMissing`、资格不足 `NotAuthorized`、不可达 `OutOfReach`、遮挡 `Obstructed`、货物不可操作 `InvalidState`、版本冲突 `StateChanged`。状态变更由 `SnapshotChanged` 通知，D 读取 `ReadCargo` 的确认快照。出入笼另按第 9 节发布 `CargoConditionChanged`。

订单清单中的鸡与笼体合计质量按该货物 `MassKg` 计一次。抓取与车载载荷按实际物理质量核算。鸡在笼中随笼承载，质量已并入笼体时计合并值一次。分体模拟时按实体的实际承载关系各计一次。离笼、被抓持或换手时按相同实体 ID 重新归属，车上直接承载与经玩家携带等路径只计该实体一次。

E 校验司机唯一占座、退出的速度与安全站立落点、车门可达和真实门扇阻挡，门闩请求按门当前状态与 Revision 裁决。巡航保持当前目标前进速度，W 保持目标，A/D 转向，S 或手刹同次输入取消，司机失联清巡航并安全制动。车体诊断质量按实际承载的人货去重。实际刚体质量另记，凝胶计重方式待确认，UFO 受力变化保持定义质量一致。

### 4.2 凝胶请求、快照与反馈

~~~csharp
// IGelService
GelStateSnapshot ReadGelState();
void RequestFireGel(GelFireRequest request);
void RequestRecoverGel(GelRecoverRequest request);
void RequestCancelGelRecovery(CommandKey key, ulong recoveryRequestId);
event Action<GelCommandResult> GelCommandResolved;
event Action<GelStateSnapshot> GelStateChanged;
~~~

| 类型 | 必需字段和语义 |
|---|---|
| GelFireRequest | Key、GunId、AimOriginWorldM、AimDirectionWorld、TargetEntityId?、HitLocalPointM?、ExpectedGunRevision。可瞄准货物、货舱允许表面或另一胶块，命中字段为玩家侧提示 |
| GelRecoverRequest | Key、GunId、TargetGelId、ExpectedGunRevision。GunId 为执行回收者的枪 |
| GelGunSnapshot | GunId、PlayerId、CapacityUnits、StoredUnits、ReservedRecoverUnits、Color、GunRevision。版本对应已确认的库存和容量，预留另随共享状态同步 |
| GelBlockSnapshot | GelId、FiredByGunId、Color、Pose、ConnectionIds。每块使用当次发射枪颜色、统一尺寸与独立身份 |
| GelConnectionSnapshot | ConnectionId、两个实体 ID、两端局部连接点、有效状态、参数版本。连接两块胶时各块仍保有各自属性 |
| GelRecoveryProgress | Key、GunId、GelId、Progress01，有持续过程时供进度与重连恢复 |
| GelStateSnapshot | Stamp、Guns、Blocks、Connections、ActiveRecoveries。一次提交的库存、世界胶块与连接作为同一版本应用 |
| GelCommandResult | Resolution、GelId?、Gun?、UnitsDelta。成功发射 −1、成功回收 +1、拒绝或取消 0。Gun 为请求者可见的确认库存快照 |

D 读取瞄准、目标提示和当前操作上下文，提交发射或回收意图。E 校验枪归申请人、回合与 GunRevision，重新验证有效目标、视线、距离、库存、容量和连接预算。发射成功一次提交扣 1 单位、创建独立胶块与本次成立的连接。有效发射但未附着的胶块仍可回收。目标提示、射程与可以粘附的表面按灰盒第 6 节采用配置。

回收在同一步锁定 TargetGelId 并为该枪预留一个位置，开始前要求 StoredUnits + ReservedRecoverUnits < CapacityUnits。任意有资格的玩家都可发起回收。成功时一次提交拆除该块相关连接、移除胶块、释放预留并向回收者的枪加 1 单位，其余有效连接继续生效。再次发射采用当前枪颜色。满枪返回 GelGunFull，目标正被另一请求处理返回 GelBusy，目标已确认回收返回 GelAlreadyRecovered。抢收只成功一次，原成功请求重传取得原确认结果。

取消、断线和目标失效释放未提交的锁与容量预留，保留已确认库存和胶块状态。取消请求的 recoveryRequestId 指向同一玩家及回合内的原请求，通用确认使用 CommandResolved，原发射和回收各以一次 GelCommandResolved 确认终态。异步处理中只呈现等待或回收进度。D 按回合和确认版本用绝对库存刷新 HUD，旧回包可以结束对应的本地等待，但库存采用最新已确认值。效果、HUD 与 E 的连接和实体结果来自同一提交，预留量仅表示容量占用。

凝胶约束按独立连接实现弹性、阻尼与回弹，正常驾驶和实际冲击可解释其运动和失效。胶块粘连后各自保留身份、体积与颜色。交付、破碎与越界处理释放失效连接，保留胶块的独立身份和可回收状态。临时方案为本人先松手再切枪，保留另一抓取者的作用。键位、持货与切枪规则、目标白名单、胶块质量、枪容量、射程、强度、连接上限、过载和回收表现依灰盒第 13 节登记状态。

## 5. 本地镜头、实体手册与绑定

~~~csharp
void EnterContext(string contextId, CameraContextKind kind, ulong focusId);
void ExitContext(string contextId);
CameraContextKind ReadActiveContext();
bool TryOpenWorldHandbook(ulong handbookEntityId);
void CloseHandbook();
BindingSnapshot ReadBindings();
BindingResult TrySetBinding(string actionId, InputBinding binding);
~~~

默认步行、装卸与后舱用第一人称，确认进入驾驶座后用第三人称，其他已配置座位用第一人称挂点。镜头优先级、避障、切换与失效恢复采用灰盒第 6.1 节。实体手册在准备区供空手、可达、面向书的玩家打开，1～4 人各有本地页码。阅读、地图和设置只切换本地输入，订单时钟与世界继续，制动和手刹需及时传给车辆服务。HUD 和手册从绑定表读取本地提示，凝胶枪切换、发射、回收动作先用可配置的测试绑定接入，正式键位待确认。

## 6. 订单、路线与结算

~~~csharp
// IOrderService / IRouteService
OrderSnapshot ReadOrder();
RouteGraphSnapshot ReadRouteGraph();
void RequestStartOrder(CommandKey key);
void RequestSelectRoute(CommandKey key, string edgeId, uint expectedRouteRevision);
void RequestCommitRoute(CommandKey key, string edgeId, uint expectedRouteRevision);
void RequestConfirmCargoLost(CommandKey key, ulong cargoId);
void RequestResolveChickenDeliveryChoice(CommandKey key, string orderId,
    ulong cargoId, bool deliverWithoutCage, uint expectedChoiceRevision);
void RequestEndOrder(CommandKey key, string orderId);
void RequestReset(CommandKey key);
~~~

| 类型 | 必需字段 |
|---|---|
| OrderSnapshot | OrderId（准备阶段可空）、Stamp、Phase、CargoIds、DeadlineSeconds、StartedAtTick、ElapsedSeconds、OvertimeSeconds、DeliveredIds、LostIds、RequiredCount、ChickenDeliveryChoice（可空）、Settlement |
| ChickenDeliveryChoice | `CargoId`（ulong）、`PackagingFeeFen`（报价，非负整数分）、`Revision`（uint）。有有效的仅交鸡选择时提供，D 用其 `Revision` 填入 `expectedChoiceRevision` |
| OrderPhase | Preparing、Loading、InTransit、Unloading、Settled、Resetting |
| RouteGraphSnapshot | GraphId、Seed、Nodes、Edges、CurrentNodeId、SelectedEdgeId、CommittedEdgeIds、RouteRevision、Stamp |
| RouteNode / RouteEdge | NodeId、Layer、Kind、PositionM、FuelStationId、DisclosedRisks / EdgeId、FromNodeId、ToNodeId、EstimatedTravelSeconds、EstimatedFuelLiters、RiskTags、RoadSectionId |
| Settlement / CargoSettlementLine | SettlementId、OrderId、FinalElapsedSeconds、CargoLines、GrossFeeFen、OvertimePenaltyFen、PackagingFeeFen（确认的包装未归还费）、NetPayFen / CargoId、BaseFeeFen、FinalQuality01、Status、EarnedFeeFen |

司机主动出库时 E 确认唯一订单 ID 并起钟。运输、选路、恢复、加油和卸货均计时，零秒后继续送达并记录迟到。E 按正确卸货区、无抓取、外部凝胶连接已解除及稳定判据确认交付，锁定品质，已交付实体按灰盒第 10.3 节退出动态碰撞。附着胶块仍能独立回收，枪库存按第 4.2 节变化。货物均进入终态后停表，服务节点或终点的主动结束按灰盒第 3.1 节确认未交损失。被盗可追回货物保存原 ID 和品质，越过下节点或明确放弃后确认丢失。交付、损失和结算按订单与实例唯一标识去重。

单鸡货物在 `OrderSnapshot.CargoIds` 只占一项。E 分别用 `ChickenCondition.Pose` 和 `CargoSnapshot.Pose` 校验本单鸡与笼体的真实位置，按灰盒第 10.3 节及实际承载核对收货判据。配套笼体实际卸到室外收货区并合格才算归还。两者均合格时正常交付，包装费为 0。仅空笼合格时该件保持未交付。`RequestConfirmCargoLost` 继续传原 `CargoId`，E 按现有失物规则裁决 `Lost`。交付与正式丢失互斥，同一 `OrderId` 与 `CargoId` 只确认一次。逃出对品质和工资的影响仍待 B 确认。

仅鸡合格时，E 在 `OrderSnapshot.ChickenDeliveryChoice` 发布待选 `CargoId`、B 配置的 `PackagingFeeFen` 和 `Revision`，订单保留原未终态并继续计时。每次开启新选择或更新报价使用该单该件的新版本。笼体及时归还时撤下选择并按正常交付处理，鸡失去交付资格或该件已终结时使选择失效。

`RequestResolveChickenDeliveryChoice` 由 D 在现有室外交付界面发出。参数 `deliverWithoutCage=false` 对应「返回取鸡笼」和明确取消，`true` 对应「仍然交付」。E 按第 2 节确认 `CommandKey`，校验当前回合、交付操作资格与可达、`orderId` 和 `cargoId` 的归属、有效选择与 `expectedChoiceRevision`，并在提交前重验鸡已合格且笼体仍未归还。目标缺失或归属不符用 `TargetMissing`，资格不足用 `NotAuthorized`，不可达用 `OutOfReach`，订单结束用 `OrderClosed`，选择过期、版本不符或现场条件变化用 `StateChanged`，拒绝原因通过 `ReasonKey` 返回。

确认返回时，E 关闭该版本的选择，保留未交付。其后笼体合格走正常交付，鸡重新符合交付判据时可生成新选择。确认只交鸡时，E 在同次提交中确认 `Delivered`、记录该选择版本的费用、关闭选择并设置 `CageLeftInLevel=true`。返回和交付均用 `CommandResolved` 确认，`TargetId` 为 `CargoId`。D 通过 `SnapshotChanged` 读取该次订单和货物状态。只有交付成功发布原有 `CargoDelivered`。

同一选择版本只处理一个有效决定。费用在既有交付记录按 (`RoundEpoch`, `OrderId`, `CargoId`) 去重。重传同一 `CommandKey` 取得原结果，并发或重复点击生成的其他请求按最新版本裁决。只交鸡的费用独立于 `Quality01` 与 `Lost`，参与最终结算一次。

只交鸡时，鸡按正常展示位及碰撞清理处理，原笼体留在当关原位置。`CargoSnapshot.Status=Delivered` 可与 `ChickenCondition.CageLeftInLevel=true` 同时成立。笼体继续保留碰撞、有效抓持和约束，按实际承载计入车辆载荷。交付清理按实际实体处理笼与鸡的关联，之后将笼体移入收货区时保留原订单终态与费用。

全部金额字段 Fen 为整数分。用已配置的截止 T、档长 τ、每档扣薪 c 和上限比例 p 计算 F=Σ(feeᵢ×qᵢ)、L=max(0,t−T)、P=min(p×F,c×ceil(L/τ))，实发 W=round(max(0,F−P−PackagingFeeFen)) 在最后四舍五入到整数分。首关 720 s、30 s、20 元和 80% 分别是待验证种子。按这些种子且包装费为 0 时，F=10000 分、L=65 s 的公式样例为扣款 6000 分、实发 4000 分。订单总件数、总质量和满品质运费读取实际清单，D 显示估计和已确认结算。`Settlement.PackagingFeeFen` 汇总本单已确认的包装未归还费，单列展示。`NetPayFen` 为扣费后实际入账的工资，最低为 0。费用随工资结算抵扣。加油费用已在交易提交时记账，结算只展示该支出。

路线采用灰盒第 4 节八节点拓扑。司机在合法岔口停车后预选，确认请求经资格、当前位置、可用边与 RouteRevision 校验后立即锁定。E 保持分支可交付性、加油节点和事件候选一致。重试由 E 切换新 RoundEpoch，从同一关前快照同时恢复人车货、钱包、燃油、枪库存、胶块与连接，沿用随机种子并清理旧请求和事件。

鸡交互的断线处理按第 3 节清理对应玩家的抓持，未提交请求按第 2 节处理。重连按确认快照恢复同回合鸡与笼体姿态、`ChickenCondition`、`ConditionRevision`、有效抓持、有效的 `ChickenDeliveryChoice` 或已确认终态和结算。

E 在实际进入下一关时，按本关交付记录的 `CageLeftInLevel` 清理对应的未归还笼体及由此失效的关联，然后按下一关订单配置生成货物。`RequestReset` 对应本关重试，按关前准备快照重建本关原有鸡、笼、实体及订单关联，恢复选择、费用与留笼标记，并按新 `RoundEpoch` 拒绝旧命令。

## 7. 燃油、钱包与加油交易

~~~csharp
// IEconomyService
EconomySnapshot ReadEconomy();
RefuelQuote? ReadRefuelQuote(string stationId, ulong vehicleId);
void RequestRefuel(CommandKey key, string stationId, ulong vehicleId,
    decimal requestedLiters, uint expectedEconomyRevision);
~~~

| 类型 | 必需字段 |
|---|---|
| EconomySnapshot | WalletFen、EconomyRevision、Stamp、ActiveRefuels、Transactions |
| RefuelQuote | StationId、VehicleId、UnitPriceFenPerLiter、TankFreeLiters、AffordableLiters、EconomyRevision |
| RefuelProgress | TransactionId、Key、StationId、VehicleId、Progress01、Stamp |
| TransactionReceipt | TransactionId、Key、OrderId、StationId、VehicleId、AddedLiters、CostFen、WalletBeforeFen、WalletAfterFen、FuelBeforeLiters、FuelAfterLiters、Stamp |

站点的室外加油为本轮唯一商店服务。油耗、容量、油价、起始余额及注油耗时读取灰盒第 9 节配置，物价和燃油单位采用普通货币与升。E 校验站点、停车、阶段、正请求量和版本，按请求量、剩余油箱容量和可负担量计算实际注油量。费用按确认注入量计到分，油量与扣款同一提交。满油、可注入量为零、报价变化、取消与离线有对应反馈。并发、重传和恢复保持交易幂等。D 提交升数和报价版本，读回交易收据和实际变化。

行驶与怠速两种油耗互斥，熄火耗量为 0。翻车或卡住恢复通过车辆服务，缺油援助或关前重试采用灰盒第 9.4 节。恢复资格、油量和时间代价待验证，事件基础应对与翻车恢复可由单人完成。

## 8. 三个特殊事件与翻车恢复

IIncidentService 提供 IncidentSnapshot[] ReadIncidents()。快照提供 IncidentId、DefinitionId、Stamp、Stage、StageStartedTick、StageDurationSeconds、InfluenceBounds、AffectedEntityIds、ResolvedReason 和类型专属状态。E 按 Warn → Active → Recovery → Resolved 推进。路线标签选择候选，同时最多一主事件，恢复、服务和终点卸货期间停止新增预警。次数、冷却、时序和外力按灰盒第 8 节配置。D 通过驾驶、门闩、共同抓取和凝胶枪应对，喇叭使用 IVehicleService 的 RequestHorn。

| DefinitionId | 最低共享状态与应对 |
|---|---|
| ufo | 光束位置与强度、作用范围、受影响车辆。环境吸牛配合实际升力、轮载或抓地变化，人货按真实物理间接受影响，可减速、换路或驾车脱离 |
| tornado | 风场范围、方向与强度。实际产生横向力或侧倾，玩家可主动驾驶避让、脱离或找遮蔽，退场清理该事件的外力 |
| cow_rider | 盗贼、后门、接近/门闩/拖货阶段与进度、目标货物。实际可达后才尝试取得松散货，每次最多一件，关门、拉开距离与凝胶保护可作为应对，喇叭可干扰接近 |

门闩可复位，E 保留对货物的有效凝胶约束。离场或取消关闭该事件的受力、临时目标和循环反馈，保留已确认的门、货物状态与玩家凝胶连接。三个事件各有独立玩法测试入口。

翻车通过驾驶、载荷、道路与物理状态产生，使用 VehicleSnapshot 和车辆恢复接口记录侧躺、四轮朝天及后续恢复。恢复校验合法位置，按实际承载和连接处理随车人货，保留订单、品质和已确认库存。翻车以独立驾驶测试入口覆盖，车辆恢复参数待验证。

## 9. 事件订阅与声音接入

D 读取第 2 节的请求结果和确认快照。共享 GameplayEventRaised 供 D/E 表现代码和 C 音频接入使用。下表字段在通用事件信封外提供对应类型的载荷。

| Kind | 最低载荷与触发 |
|---|---|
| CargoGrabbed / CargoReleased | CargoId、PlayerId、Reason，每位抓取者的已确认加入或移除。SourceEntityId 为实际抓取实体 |
| ObjectImpact / CargoConditionChanged | EntityId、SurfaceId、Intensity01、ImpactId / CargoId、Condition、ConditionRevision，实际接触或货物条件确认变化，单鸡在确认 `InCage` 变化时发布，`Condition` 为该次确认的 `ChickenCondition`，`SourceEntityId` 与 `PositionM` 指向该鸡及其确认位置 |
| GelFired / GelAttached | GunId、GelId、Color、发射 Key / GelId、ConnectionId、两端实体与连接位置 |
| GelRecoveryStarted / GelRecoveryCanceled | GunId、GelId、原回收 Key、目标位置和原因。有持续回收表现时，成功预留后发 Started，中断发 Canceled |
| GelRecovered / GelConnectionRemoved | GunId、GelId、回收 Key / ConnectionId、端点、Reason。成功回收和实际拆连提交时发出 |
| HornPlayed / CruiseChanged / DoorChanged / RearLatchChanged | VehicleId 与相应喇叭时刻、目标车速、门状态或门闩状态及来源 |
| CargoDelivered / CargoLost / CargoDestroyed | OrderId、CargoId、FinalQuality01、Reason |
| OrderStarted / OrderBecameOvertime / OrderSettled / RouteCommitted | OrderId 与开始时刻、迟到状态或 Settlement / GraphId、FromNodeId、EdgeId、RouteRevision |
| FuelRefuelStarted / FuelRefuelCanceled / TransactionCommitted | TransactionId、VehicleId、StationId、Reason / 确认交易收据。加注循环按同一 TransactionId 启停 |
| IncidentWarned / IncidentStageChanged / IncidentResolved / CargoStolen | IncidentId、DefinitionId、Stage、时序、结束原因。偷货另带 CargoId 与追回应对信息 |
| VehicleRolledOver / VehicleRecoveryStarted / VehicleRecoveryFinished | VehicleId、实际事故或恢复状态、原因。与特殊事件阶段分别记录 |
| RoundReset | NewEpoch、CheckpointId |

E 在 `CargoConditionChanged` 的 `Condition` 为 `ChickenCondition` 且 `InCage=false` 时，用该事件的 `PositionM` 播放 C41。单鸡抓取提交的 `CargoSnapshot` 与 `CargoGrabbed` 共用 `Stamp`，接收端应用该次快照后派发事件。D 在事件的 `PlayerId` 为本地玩家时用 `CargoId` 和 `Stamp` 匹配快照，其中 `ChickenCondition.ChickenEntityId` 等于事件的 `SourceEntityId` 且 `InCage=false` 时播放 C42。两者按 `RoundEpoch` 与 `EventId` 去重，重连以确认快照作为事件起点。

重连使用 GelStateSnapshot.ActiveRecoveries、EconomySnapshot.ActiveRefuels、车辆及事件快照恢复当前循环。回收或加注取消、事件恢复/结束、对象销毁、回合切换与离场停止相应循环。首次确认事件触发单次音效，失败由本地请求结果反馈。[C 声音交接](交接/C_音乐与音效.md)

## 10. 玩法联调与交付判据

| 批次 | 需提供的运行证据 |
|---|---|
| I01 人物与共同作用 | 确认尺寸和真实门洞，空舱四人和临时三货加三人，镜头、实体手册、改键、单人装卸、双人独立抓点与松手/掉线、双人抓笼加第三人抓离笼鸡及笼内鸡拒绝独立抓取，常规控制和局部物理反馈 |
| I02 凝胶与载荷 | 单位、跨玩家回收换色、胶块不融合、满枪与抢收、回收中断、重复请求、物理受力与库存守恒 |
| I03 单人送货 | 装运卸、笼门开合与版本冲突及重传、单鸡逃出后抓回及同次提交回笼与解除抓持、仅空笼保持未交付、完整归还、返回取笼、只交鸡及费用单列、实发保底、原位留笼与车载计重、进入下一关清笼与本关重试恢复、同一货物实例的交付或丢失确认、巡航制动、原路线拓扑、可解释偏载、计时边界、重复交付、燃油容量和幂等交易 |
| I04 事件与事故 | UFO、龙卷风、骑牛飞车党分别实测及清理，翻车通过独立物理测试验证单人恢复和继续运输 |
| I05 正式联网 | E 在单机闭环后接入，实测 1～4 人会话与 2～4 人状态一致性、输入重传、缺油/翻车、断线重连、回合重置和声音清理。核对鸡、笼体、笼门、抓持与订单状态的一致性，以及交付选择并发、取消、重连及包装费去重 |

胶块及连接数量、事件并发与物理帧耗时纳入记录。保留配置版本、执行场景、人数、操作、实际结果及未执行项，与灰盒第 12.3 节核对。首次联调依第 11 节验收。

## 11. D/E 并行开发约定

### 11.1 共同基线与独立测试入口

B 确认最小接口与结果枚举，E 将共享 C# 类型、接口声明与可编译的工程入口接入共同基线。D/E 记录同一 Git 提交 SHA，各从该提交开分支。最小约定覆盖会话、人物、抓取、驾驶与凝胶服务各自在第 1～4 节的请求、快照与结果，第 6 节的单鸡交付选择与结算，以及 D 的本地操作入口。接口变更由 B 确认，E 统一接入共享声明，双方使用同一版本。

| 负责人 | 独立交付与验收 |
|---|---|
| D，使用 DSH | 玩家测试场采用占位车厢和货物，接可切换的模拟服务。实测走动、镜头、两人抓取状态、切枪、瞄准、操作请求和 HUD。模拟发射成功、回收成功、满枪 GelGunFull 和已被回收 GelAlreadyRecovered，另可模拟房间成员、队友状态和掉线 |
| E，使用 Codex | 运输测试场用临时按键或脚本调用正式服务入口，独立实测驾驶、装货、凝胶发射、回收及实际约束。用两个模拟玩家 ID 分别绑定各自枪，针对同一胶块发不同 RequestId，核对只有一次回收、连接清理和单位返还。调试工具仅供应测试入口 |

D 的测试场以模拟服务独立启动，E 的测试场以本地权威和临时操作独立启动。各自提交启动方式、基线 SHA、采用配置和实际结果。E 负责合入正常主场景、工程设置与共享类型。

### 11.2 首次联调顺序

1. 在本地权威测试中用一把枪发射真实胶块并建立有效物理连接，另一名玩家的枪留一个容量位置供回收。D 把玩家侧调用接到 E 的 IGelService。
2. D 的角色瞄准胶块并按回收动作，发送本回合的 Key、GunId、TargetGelId 和 ExpectedGunRevision。E 校验后一次提交移除胶块与相关连接，回收者枪的储量增加一单位。D 依据同一确认版本刷新 HUD，记录请求键、前后库存及连接状态。
3. 换成满枪再次回收，确认 GelGunFull、原胶块与连接保留，HUD 给出拒绝原因。用两个玩家身份抢收同一块，确认一次成功，另一端收到 GelBusy 或 GelAlreadyRecovered，并分别检查确认库存。重传成功请求核对收据和库存。
4. 单机装运卸闭环跑通后，E 接入正式建房、连接、房主裁决、状态同步与断线恢复，再验证两端一致性。此前 D 可用模拟会话独立检查房间界面、队友显示与掉线提示。网络传输方案待 B 评审。

## 12. 修订记录

| 版本 | 日期 | 内容 |
|---|---|---|
| v0.4 | 2026-11-15 | 建立分支送货、经济与事件的 C# 契约 |
| v0.5 | 2026-11-21 | 同步凝胶、简化货物、门闩、加油、三个事件与翻车。明确 E 的正式联网及工程接入职责、D 的玩家侧接口、独立测试与首次回收联调 |
| v0.6 | 2026-11-22 | 补齐笼门请求与版本，明确单鸡身份、抓取与回笼、载荷和订单一致性，落实音频使用的确认事件 |
| v0.6（鸡笼交付修订） | 2026-11-22 | 按抓取实体计人数，增加单鸡交付选择、确认费用及留笼状态，区分换关清理与重试恢复 |
