# API 与联调契约 v0.4

更新日期：2026-11-15。沿用原文件名，正文升级。规则采用[灰盒设计 v0.4](灰盒设计_v0.1.md)，分工采用 [B 总表](交接/B_策划_API与协调.md)。本文是**待实现的 C# 接口规格**；当前工程为 GDScript 比例和事件预览，尚无完整联机送货、计薪、商店或事件 AI。下列签名说明行为，不表示源码已经存在。

## 1. 服务边界与共同基础

| 服务 | 提供 | 消费 | 权责 |
|---|---|---|---|
| IPlayerService / IInteractionService | D | E、人物 UI | 人物输入、抓取参与和每人作用力 |
| ICameraContextService / IHandbookService / IBindingsService | D | 本地界面 | 镜头、实体手册阅读、实际按键绑定 |
| ISessionService | D | D/E | 1～4 人标识、输入投递、状态传播 |
| IPhysicsObjectService / IVehicleService | E | D、声音 | 车货物理、座位、门、固定、载荷与巡航 |
| IOrderService / IRouteService | E | D 的 UI | 订单时钟、交付/损失、路线边与锁定 |
| IEconomyService | E | D 的 UI | 共享钱包、交易、修理加油、道具和局内升级 |
| IIncidentService | E | D、声音 | 事件种子、预警、效果、反制与结束 |

B 维护版本和定义数据；D 首次接入公共类型到 who-sent-this-guy/shared/contracts，命名空间建议 DeliveryGame.Contracts。网络、刚体方案和测试框架须由实际工程验证后记录，不能把接口文档当成采用证据。

~~~csharp
void Connect(SessionOptions options);
void Disconnect();
bool IsPhysicsAuthority { get; }
ulong LocalPlayerId { get; }
event Action<ulong> PlayerJoined;
event Action<ulong> PlayerLeft;
~~~

SessionOptions 至少有会话角色、连接地址、MaxPlayers=4、配置ID。输入投递到权威端，快照和事件只读下发；网络写入归属不占用同物体参与资格。

公共单位：m、kg、s、N、rad/s；字段含 Deg 才使用度。货物尺寸顺序宽 X、高 Y、长 Z。1.5 头身人物站高 1.20、头直径 0.80、碰撞直径 0.80、视觉宽 0.96、眼高 1.02；蹲高 0.85、眼高 0.70。车宽含轮胎最大 3.00，路面总宽 6.00。

## 2. 标识、权威、结果与幂等

| 类型 | 必需字段和语义 |
|---|---|
| CommandKey | uint RoundEpoch，ulong PlayerId、RequestId、InputTick；RequestId 在连接期间递增 |
| PoseState | Vector3 PositionM/LinearVelocityMps/AngularVelocityRadps，Quaternion Rotation，ulong StateTick，uint Revision |
| CommandResolution | CommandKey Key，ResultCode Code，ulong? TargetId，uint Revision，string ReasonKey |
| GameplayEvent | ulong EventId，uint RoundEpoch，ulong StateTick，string Kind，ulong? SourceEntityId/ActorPlayerId，Vector3 PositionM，事件专属只读 Payload |
| EventEnvelope | 所有专属事件载荷有类型定义，不以 UI 文本解析业务；本文表内字段即最低要求 |

ResultCode 至少包括 Accepted、AlreadyApplied、InvalidRound、InvalidActor、TargetMissing、OutOfReach、Obstructed、HandsBusy、FixedCargo、GripFull、SeatOccupied、VehicleMoving、NoSafeExit、StateChanged、InvalidState、InsufficientFunds、OutOfStock、RouteUnavailable、OrderClosed、Cooldown、InventoryFull、NotAuthorized。

所有共享状态只由**同一权威端**写入；客户端发意图，不能提交最终伤害、工资、余额、随机结果或完成状态。请求先校验回合/发送者，再查 (RoundEpoch, PlayerId, RequestId) 幂等缓存，再验证资格。重复离散请求返回原结果，绝不再次扣钱/交付/拔销/用道具。旧回合返回 InvalidRound。连续输入按玩家和输入流保留最新样本，重传不能叠加作用。

快照携带 RoundEpoch、StateTick、Revision；接收端丢弃旧回合和过期版本。事件按 (RoundEpoch, EventId) 去重。网络传输与发布频率由标定决定，物理步初值 60 Hz；连续输入超过 0.3 s 未更新时，清理该玩家抓取目标、司机安全制动并关闭巡航。断线清理本人关联，其他参与者继续。

## 3. 人物、共同抓取与力贡献

~~~csharp
void SubmitInput(CommandKey key, CharacterInput input);
PlayerSnapshot? ReadPlayer(ulong playerId);
void RequestGrab(CommandKey key, ulong cargoId, Vector3 localPointM);
void RequestRelease(CommandKey key, ulong cargoId);
void SubmitGripTarget(CommandKey key, ulong cargoId,
    Vector3 positionWorldM, Quaternion rotationWorld);
GripParticipant[] ReadParticipants(ulong cargoId);
void AddForceContribution(ForceContribution contribution); // 权威内部入口
~~~

CharacterInput：Vector2 MoveAxis/LookDeltaRad，bool SprintHeld/CrouchHeld/JumpPressed。PlayerSnapshot：PlayerId、RoundEpoch、Pose、LifeState(Active/Recovering/Disconnected)、LocomotionMode(OnFoot/Seated)、Stance、HeldCargoId?、SeatedVehicleId?、SeatId?、SupportedVehicleId?、BodyMassKg。SupportedVehicleId 表示实际受车承载，不能只凭座位算乘员质量。

GripParticipant：PlayerId、CargoId、LocalPointM、TargetPositionM、TargetRotation、GripMode、LastInputTick。每人一物，每物最多两人；P2 加入追加到 P1，松手/断线只移除本人。抓取要求 Active、OnFoot、空手、未固定、距离有效且无遮挡；成功时目标先取当前抓点，避免突跳。超过有效距离持续 0.2 s 只释放超距者。

SupportedCarry 在质量 ≤35 kg×有效人数时成立，否则 PhysicalDrag；因此鸡笼和鱼缸单人可抱持，45 kg 炸弹单人慢推拖、两人更高效。弹簧 900 N/m、阻尼 120 N·s/m、抱持上限 650 N/人、拖拽/推力 450 N/人均为待标定种子，必须满足单人经斜板装卸三类货物。模式变化 0.2 s 平滑，保留碰撞、合力与力矩。

ForceContribution：RoundEpoch、PhysicsTick、PlayerId、EntityId、Kind(Grip/BodyPush)、LocalPointM、ForceWorldN。去重键为上述前五项；同键最新值替换，不同玩家同时保留，每个物理步用后清空。E 在同一物理状态对全部作用点施力，不能让最后写入者覆盖他人。

空手正常跳跃；鸡笼为轻货携物低跳样本；鱼缸和炸弹先释放跳跃者本人的抓取再起跳，货物不继承跳跃冲量，其余参与者不受影响。蹲起前检查完整体积；越界恢复先清理抓取/座位。后舱活动保持 OnFoot，平稳行驶可相对车体移动。

## 4. 货物、车辆、门与固定

~~~csharp
CargoSnapshot? ReadCargo(ulong cargoId);
VehicleSnapshot? ReadVehicle(ulong vehicleId);
void RequestEnterSeat(CommandKey key, ulong vehicleId, string seatId);
void RequestExitSeat(CommandKey key);
void SubmitDriveInput(CommandKey key, ulong vehicleId, DriveInput input);
void RequestToggleCruise(CommandKey key, ulong vehicleId);
void RequestHorn(CommandKey key, ulong vehicleId);
void RequestSetDoor(CommandKey key, ulong vehicleId, string doorId, bool open);
void RequestSetSecured(CommandKey key, ulong cargoId, ulong vehicleId, SecureMode mode,
    string? anchorId, SecuringSource securingSource);
~~~

| 类型 | 必需字段 |
|---|---|
| CargoDefinition | DefinitionId，SizeM，MassKg，SurfaceId，BaseFeeFen，支持搬运/固定方式 |
| CargoSnapshot | EntityId，DefinitionId，Pose，MassKg，Participants[]，SecuredVehicleId?，SecuringAnchorId?，SecuringSource(BuiltIn/ExtraStrap)，SecureMode(None/Temporary/Full)，Quality01，ConditionRevision，CargoStatus，RoundEpoch |
| 三类专属状态 | 鸡笼 ChickenCount/InitialChickenCount、DoorOpen、Alarm01；鱼缸 Water01、Slosh01、Integrity01；炸弹 Danger01、Armed、Exploded |
| VehicleSnapshot | EntityId，Pose，SpeedMps，RollDeg，LoadMassKg，OccupantMassKg，TransportedSystemMassKg，VehicleRigidBodyMassKg，EffectiveCenterOfMassLocalM，EngineLoad01，SkidIntensity01，Seats[]，Doors[]，CruiseEnabled，CruiseTargetMps，HornCooldownRemainingSeconds，FuelLiters，FuelCapacityLiters，BodyHp，RearPinState，AttachedHajimi[]，RoundEpoch |
| SeatSnapshot | SeatId，OccupantPlayerId?，SeatTransform，ExitCandidates[] |
| DriveInput | float ForwardAxis/SteeringAxis[-1,1]，bool HandbrakeHeld |
| CargoStatus | Pending、StolenRecoverable、Delivered、Lost、Destroyed；StolenRecoverable 为仍可追回的被盗货物，后三项为终态，不可重复交付或二次计薪 |

货物：chicken_cage 为 0.80×0.70×0.60、18 kg、cage、180 元；fish_tank 为 0.90×0.75×0.65、35 kg、glass、260 元；bomb 为 0.65 立方、45 kg、bomb_shell、320 元。首关各二件，196 kg，满额 1520 元。Quality01 由 E 按主文档的每类规则计算并夹到 [0,1]：鸡笼为活鸡数/3，鱼缸未碎且水量≥25%时为剩余水比例、否则0，炸弹安全交付1、毁损0。客户端不能上传品质。

只有 driver 占用者可驾驶/巡航，空手可达且空位才入座。退出要求车速 <0.5 m/s 且有安全站立落点。负向油门先刹车，前速 <0.5 m/s 才倒车。巡航记录当前前进速度，松 W 维持、W 不加速、A/D 转向；C 关闭恢复滑行，S 或手刹同一步立即关闭巡航并制动。断线、驾驶位失效、重置清巡航。

固定要求货物在舱内、相对车体稳定、无冲突抓取；完整固定另要求车停或低速稳定。完整重新固定初始要求车速 ≤1 m/s、相对线速 <0.1 m/s、角速 <0.2 rad/s 持续0.5 s，颠簸稳定阈值待实测。Temporary 是扶持后的临时稳定，不能获得 Full 的抗事件效果。基础固定点有4个，每槽1件、可免费复用；anchorId 指向合法空基础点时不耗商品，SecuringSource=BuiltIn 且合法空槽时免费；无空基础槽位货物可选 ExtraStrap 才消耗一条额外绑带。解除额外绑带不返还商品；同状态重复请求不消耗第二次。释放继承车辆对应位置的运动，不能清零速度。门交互检查可达与阻挡；RearPinState 与后门能否被盗开为独立共享状态。

载荷统计含受车承载的货物，人员含座位与后舱步行者并按 PlayerId 去重。TransportedSystemMassKg=空车+货物+人员；实际刚体质量另记，独立刚体与合并质量不能重复贡献。UFO 通过外力或有效向下重力系数改变车的受力，**不更改定义质量、库存或诊断总质量**。

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

镜头：DefaultFirstPerson 默认0、注册地点第三人称10、驾驶第三人称/乘员第一人称100。确认座位驱动切换；退出/销毁清上下文；地点白名单默认空。镜头是本地呈现，不改世界权威。

开局提示去实体手册，靠近、空手、看向后 E 打开，Esc 关闭；一本手册支持多人各自独立阅读与页码。**取消原自动弹出、随身 F1 和驾驶简版手册**。阅读只消费本地输入并发中性移动，重力与世界时钟继续；设置仍可查看改键。文字读取实际绑定，修改保存/取消、同上下文冲突有结果；不以硬编码 E/F/C 文本作为唯一绑定源。

## 6. 订单、路线与结算

~~~csharp
OrderSnapshot ReadOrder();
RouteGraphSnapshot ReadRouteGraph();
void RequestStartOrder(CommandKey key, string orderId);
void RequestSelectRoute(CommandKey key, string edgeId, uint expectedRouteRevision);
void RequestCommitRoute(CommandKey key, string edgeId, uint expectedRouteRevision);
void RequestConfirmCargoLost(CommandKey key, ulong cargoId);
void RequestReset(CommandKey key); // 仅已授权调试或重试入口
~~~

| 类型 | 必需字段 |
|---|---|
| OrderSnapshot | OrderId，RoundEpoch，Phase，CargoIds[]，DeadlineSeconds，StartedAtTick?，ElapsedSeconds，OvertimeSeconds，DeliveredIds[]，LostIds[]，RequiredCount，Settlement?，Revision |
| OrderPhase | Preparing、Loading、InTransit、Unloading、Settled、Resetting |
| RouteGraphSnapshot | GraphId，Seed，Nodes[]，Edges[]，CurrentNodeId，SelectedEdgeId?，CommittedEdgeIds[]，Revision |
| RouteNode | NodeId，Layer，Kind(Departure/Junction/Service/Delivery)，PositionM，Offers[]，DisclosedRisks[] |
| RouteEdge | EdgeId，FromNodeId，ToNodeId，EstimatedTravelSeconds，EstimatedFuelLiters，RiskTags[]，RoadSectionId |
| Settlement | SettlementId，OrderId，FinalElapsedSeconds，CargoLines[]，GrossFeeFen，OvertimePenaltyFen，NetPayFen |
| CargoSettlementLine | CargoId，BaseFeeFen，FinalQuality01，Status，EarnedFeeFen |

所有金额字段后缀 Fen（如 BaseFeeFen、WalletFen、CostFen）均为 **整数分，100分=1元**；表格价格和工资公式以元展示，配置加载时元价乘100。钱包初始50000分、货物单价18000/26000/32000分。工资内部F/P保留计算精度，先按元用四舍五入（中点远离0）得到最终整数元，再乘100分原子入账；快照中的GrossFeeFen/OvertimePenaltyFen/单件EarnedFeeFen为到分取整的展示明细，不用于反算或再次舍入实发。不能把1520元当1520分。

首关 DeadlineSeconds=720。装货准备不计时，司机主动出库确认开始后，驾驶、事件、地图选择、购物维修、卸货均计入；最后一件货物进入 Delivered/Lost/Destroyed 后停表并结算，t=720 恰好不扣薪。超时仍能送货，未送/损毁 q=0；不能因时限归零直接删除货物。主动确认损失须从 UI 显示影响后由玩家明确发请求；爆炸由权威裁决Destroyed，偷走先StolenRecoverable，在下节点边界前可追、越界或主动放弃后才Lost。

工资 F=sum(fee×q)，L=max(0,t-720)，P=min(0.8F,20×ceil(L/30))，实发 round(F-P)。内部用足够精度计算，到最终实发才四舍五入；明细显示与总额一致。F=1520、t=781 时扣60、实发1460；F=0 时无负工资。每单 SettlementId 唯一，入账一次。

路线是有限有向无环图，边仅连向下一层；所有可达分支最终到交付，不生成死路。司机在合法分叉停车点、车速 <0.5 m/s 时用 RequestSelectRoute 预选可用出边；expectedRouteRevision 防止两人或延迟消息覆盖选择。预选可改，司机停车点击“确认出发”发 RequestCommitRoute；E 再验证当前节点、可用边、司机资格、速度与修订，接受后立即锁定并发 RouteCommitted，不设驶出确认线。锁定后不可回退，不能往返刷服务/事件/奖励；D 只绘图和发请求，不本地锁定。图展示预计时间/油量、服务、已披露风险，事件细节允许随机。

RequestReset 增加 RoundEpoch 并清输入、抓取、座位、固定、事件、订单和声音；重试从本关起点的**同一钱包/库存/升级检查点**恢复，重试不保留本关结算和消费，避免重复领奖或反复购货复制。调试重置不得写入正式存档。跨关经济提交与该关结算原子保存。

## 7. 共享钱包、购买、修车、油与道具

~~~csharp
EconomySnapshot ReadEconomy();
void RequestPurchase(CommandKey key, string stationId, string offerId,
    int quantity, uint expectedEconomyRevision);
void RequestUseItem(CommandKey key, string inventoryEntryId, ulong? targetId);
void RequestService(CommandKey key, string stationId, ServiceKind kind,
    int quantity, ulong? targetEntityId, uint expectedEconomyRevision);
void RequestRefuel(CommandKey key, string stationId, decimal liters,
    uint expectedEconomyRevision);
void RequestRoadsideRecovery(CommandKey key, ulong vehicleId);
~~~

EconomySnapshot：WalletFen(int，≥0)、Revision、Inventory(InventoryEntryId/ItemId/Quantity/RemainingLiters?)[]、Upgrades(UpgradeId/Level)[]、Transactions[]。RemainingLiters 仅油桶实例有效，购买初始10 L，注油后保留实际余量，为0才移除该实例；不能把同类部分油桶只记一个数量。TransactionReceipt：TransactionId、CommandKey、OrderId、StationId、OfferId、Quantity、CostFen、WalletBeforeFen/WalletAfterFen、InventoryDelta、AppliedAtTick。交易检查停车/服务范围、阶段、库存、数量正整数、钱、容量、等级上限、预期版本；扣款与服务/增物/升级**一次原子提交**，失败全部不变。共享钱包没有每人复制余额，退款/卖出首轮不提供。油/修理按实际可补量计价，不能对满值多扣款。

| 服务或物品 | 初值 |
|---|---|
| 起始钱包/车辆 | 500 元，100 HP，60 L 油箱，初始35 L |
| 加油 / 修车 / 补胎 | 5 元/L，5 元/HP，60 元/次；油按实际 Liters，可用 decimal 数量的独立 Refuel 请求实现，禁止 int 截断 |
| 额外绑带 / 鱼干 / 备用销 | 40 / 30 / 50 元，单次消耗；基础固定点免费复用 |
| 应急修理包 / 应急油桶 | 100 元(+20 HP) / 80 元(10 L)，实际补量受上限约束，不转卖 |
| 局内升级 | 减震300、车销护套250、防雨布200、油箱扩容300，各首轮最多一级 |

签名中的 int quantity 用于件数、HP 等整数单位；targetEntityId 指定补水鱼缸或补胎轮位。RequestRefuel 接受最小0.01 L、步长0.01 L，实际可补量不足0.01 L时不成交；容量裁剪后按实际升数×500分/L四舍五入到分。付费加油的正量不得零成本，失败无加油无扣款。UI 可按1 L步进选择；精度、存储与计价保持一致。价格表和实际恢复量由权威报价，客户端不能传价。

加油2s/5 L、修理2s/10 HP、补胎3s/个；每缸一次免费补至80%水量占10s，碎缸不可补。服务耗时计入订单；完成时原子提交恢复与扣款，中断不吞钱/道具。修理包4s，油桶4s；桶里未注入的油量留在该库存实例，不因容量裁剪被吞，每种物品最多三件。行驶0.02 L/s与停车怠速0.003 L/s互斥，熄火不耗；菜单不停止状态消耗。

升级初值：减震仅减路面传货冲击25%，护套将拔销6→12s，遮盖泼水率减半，油箱60→80 L不赠油；首轮每项一级。

RequestRoadsideRecovery 对零油/零HP/翻车/卡住每单免费一次：熄火、移至可达服务路肩扶正，最低修到20 HP、补至最多5 L，保留货损，订单ElapsedSeconds另加45s。只补缺口，不降低已有HP/燃油，不发库存商品/现金；同请求重传不重复加45s。第二次停驶有结束本单或关前检查点重试入口。无钱仍能免费处理基础事件，付费道具不能是唯一解。

## 8. 五事件服务与公平性

~~~csharp
IncidentSnapshot[] ReadIncidents();
void RequestCounterIncident(CommandKey key, string incidentId,
    CounterAction action, ulong? targetId);
~~~

IncidentSnapshot：IncidentId、DefinitionId、Seed、Stage、StageStartedTick、StageDurationSeconds、InfluenceBounds、AffectedEntityIds[]、CounterProgress01、ResolvedReason、Revision、RoundEpoch。Stage 为 Warn→Active→Recovery→Resolved；E 的权威时钟推进阶段，D 只呈现，客户不得自行开始事件。首关最多两次主事件、教程一次；一次最多一个事件占用主事件预算，哈吉米不叠主事件。炸弹引信已燃、车辆恢复、服务区和终点卸货时不投新主事件；Resolved 后45 s冷却。离开节点/重置终止效果，清理作用力、减益、偷货和附着，定义质量不变。

| 事件 DefinitionId | Warn / Active / Recovery 秒 | 最低共享状态与反制 |
|---|---|---|
| ufo | 6 / 10 / 3 | 车辆受力减轻、BeamStrength01、UFOPosition；环境母牛被吸；提前停车/离开光束，恢复平滑 |
| tornado | 8 / 12 / 4 | 风场中心/方向/强度、牵引对象；母牛卷飞；预警停车进安全侧区 |
| cow_rider | 6 / 18 / 4 | RiderId、TargetPinId、PinPullProgress01、TargetCargoId、StealProgress01；拔销6 s、偷松散货6 s，最多1件；停车赶走/保销固定货 |
| cow_rain | 8 / 15 / 4 | 每个落点 ImpactId、PositionM、ImpactAtTick；落地前2 s预告，车可绕开/停车等间隙 |
| hajimi | 6 / 最多20 / 3 | 每轮附着 AttachmentId/WheelId；最多2只，稳定附着≥4 s后每只转向降低10%/滚阻+15%；停车E每只2 s免费移除或用鱼干，禁止锁死轮胎 |

车销拔除不等于货物立即丢失；固定货物不能被直接偷走。骑牛党拖走的货物先标 StolenRecoverable，在前方可达路肩保留原ID和品质，下一节点边界前可免费追回；越过该边界或玩家明确确认放弃时由权威转Lost并给出原因。喇叭打断接近、冷却5s；松销停车E持续2s可免费复位，真正损坏才需备用销。RequestHorn 与 CounterAction.Honk 表达同一喇叭意图，Q 默认绑定；仅当前司机可发，权威5s冷却，接受后打断一次骑牛党接近，重复消息不重置冷却或重复打断。牛雨离散 ImpactId 去重，环境表演母牛默认无伤害，实际危险落点才有碰撞。UFO、风场和哈吉米恢复时移除自己登记的 modifier，不重置其他系统状态。单人能先停车后反制，不要求边驾驶边操作后舱；困难来自时间成本而非强制多人。

CounterAction 至少含 RemoveHajimi、RepelRider、Honk、RestorePin、Shelter、DisarmBomb、CatchChicken、SootheChicken；服务端检查距离、速度、对象和持续操作条件。需要鱼干/备用销的动作走同一原子库存消费入口；中断是否消耗按主文档定义，默认完成时消耗，不能一次多用。只有开发构建可有调试触发事件入口。

## 9. 事件订阅与音频

各服务提供对应 SnapshotChanged、CommandResolved；共享 GameplayEventRaised 由会话统一传播。专属载荷最低要求如下。

| Kind | 载荷 |
|---|---|
| CargoGrabbed/Released/Secured/Unsecured | CargoId、PlayerId?、SecureMode、Reason |
| ObjectImpact / CargoConditionChanged | EntityId、SurfaceId、Intensity01、PositionM / 新条件修订与状态 |
| HornPlayed | VehicleId、ActorPlayerId、CooldownUntilTick；按事件去重播放喇叭 |
| CruiseChanged / DoorChanged | VehicleId、Enabled/TargetMps 或 DoorId/Open |
| CargoDelivered/CargoLost/CargoDestroyed | OrderId、CargoId、FinalQuality01、Reason |
| OrderStarted/OrderBecameOvertime/OrderSettled | OrderId、StartTick 或 DeadlineTick 或 Settlement |
| RouteCommitted | GraphId、FromNodeId、EdgeId、RouteRevision |
| TransactionCommitted | TransactionReceipt |
| IncidentWarned/IncidentStageChanged/IncidentResolved | IncidentId、DefinitionId、Stage、StageStartedTick、Duration、Reason |
| RearPinRemoved/CargoStolen | IncidentId、VehicleId、PinId 或 CargoId |
| HajimiAttached/Detached | IncidentId、AttachmentId、VehicleId、WheelId、Reason |
| RoundReset | NewEpoch、CheckpointId |

C 按[声音交接单](交接/C_音乐与音效.md)映射文件；持续声从快照恢复，单次声按事件去重。网络重传不重复结算或播放确认音。UI 的扣薪预估是显示值，以 Settlement 的权威结果入账。

## 10. 联调与交付判据

| 批次 | 必须提供的运行证据 |
|---|---|
| I01 人物车货 | 几何尺度/真实门洞、实体手册多人各自阅读、改键、单人搬运三类货物、车上移动和镜头 |
| I02 运输与共同作用 | 两人同物件不同抓点、松手/断线不移除他人、载荷只计一次、巡航制动、固定释放连续 |
| I03 订单路线经济 | 单人一单、2～4人闭环、720/720.001/750/781s边界、全损工资0、重复结算/购买无重复入账扣款、分支可达交付 |
| I04 五事件 | 固定种子复现、每种预警/免费反制/超时恢复、事件互斥、丢货最多一件、哈吉米不锁轮、UFO不改质量 |
| I05 生命周期 | 交易并发余额不负、旧回合拒绝、重连恢复当前状态、重试恢复检查点无刷钱、零油零HP可恢复、循环声清理 |

这些是后续实现验收要求，不能写成已经通过的测试。本次文档升级同步了旧版巡航、活动人员计重、实体阅读与负重跳跃的遗漏，并扩展限时订单/路线/经济/事件；实际技术基线与测试日志由 D/E 实现时交付。
