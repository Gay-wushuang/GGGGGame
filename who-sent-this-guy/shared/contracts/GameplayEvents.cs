using Godot;

namespace DeliveryGame.Contracts;

// 待 B 确认：通用字段在无对应实体、玩家或位置时暂为可空。
public sealed record GameplayEvent(
    ulong EventId,
    StateStamp Stamp,
    GameplayEventKind Kind,
    ulong? SourceEntityId,
    ulong? ActorPlayerId,
    Vector3? PositionM,
    GameplayEventPayload Payload);

public enum GameplayEventKind
{
    CargoGrabbed,
    CargoReleased,
    ObjectImpact,
    CargoConditionChanged,
    GelFired,
    GelAttached,
    GelRecoveryStarted,
    GelRecoveryCanceled,
    GelRecovered,
    GelConnectionRemoved,
    HornPlayed,
    CruiseChanged,
    DoorChanged,
    RearLatchChanged,
    CargoDelivered,
    CargoLost,
    CargoDestroyed,
    OrderStarted,
    OrderBecameOvertime,
    OrderSettled,
    RouteCommitted,
    FuelRefuelStarted,
    FuelRefuelCanceled,
    TransactionCommitted,
    IncidentWarned,
    IncidentStageChanged,
    IncidentResolved,
    CargoStolen,
    VehicleRolledOver,
    VehicleRecoveryStarted,
    VehicleRecoveryFinished,
    RoundReset
}

// 待 B 确认：第 9 节的载荷暂用以下记录类型，未规定的字段名、可空性和
// 来源、原因、追回应对的键格式待确认。载荷类型及枚举序号尚无传输约定。
public abstract record GameplayEventPayload;

// CargoGrabbed / CargoReleased 的实际抓取实体由 SourceEntityId 给出。
public sealed record CargoGripPayload(
    ulong CargoId,
    ulong PlayerId,
    string? Reason) : GameplayEventPayload;

public sealed record ObjectImpactPayload(
    ulong EntityId,
    string SurfaceId,
    float Intensity01,
    ulong ImpactId) : GameplayEventPayload;

public sealed record CargoConditionChangedPayload(
    ulong CargoId,
    CargoCondition Condition,
    uint ConditionRevision) : GameplayEventPayload;

public sealed record GelFiredPayload(
    ulong GunId,
    ulong GelId,
    Color Color,
    CommandKey Key) : GameplayEventPayload;

public sealed record GelAttachedPayload(
    ulong GelId,
    ulong ConnectionId,
    ulong EntityAId,
    ulong EntityBId,
    Vector3 ConnectionPositionM) : GameplayEventPayload;

// GelRecoveryStarted / GelRecoveryCanceled 的 Key 均为原回收请求键。
public sealed record GelRecoveryPayload(
    ulong GunId,
    ulong GelId,
    CommandKey Key,
    Vector3 TargetPositionM,
    string? Reason) : GameplayEventPayload;

public sealed record GelRecoveredPayload(
    ulong GunId,
    ulong GelId,
    CommandKey Key) : GameplayEventPayload;

public sealed record GelConnectionRemovedPayload(
    ulong ConnectionId,
    ulong EntityAId,
    ulong EntityBId,
    string? Reason) : GameplayEventPayload;

public sealed record HornPlayedPayload(ulong VehicleId, ulong PlayedAtTick) : GameplayEventPayload;

public sealed record CruiseChangedPayload(
    ulong VehicleId,
    bool CruiseEnabled,
    float CruiseTargetMps) : GameplayEventPayload;

// DoorChanged / RearLatchChanged 同时提供门扇和门闩的确认状态。
public sealed record VehicleDoorChangedPayload(
    ulong VehicleId,
    DoorSnapshot Door,
    string? Source) : GameplayEventPayload;

// CargoDelivered / CargoLost / CargoDestroyed。
public sealed record CargoOutcomePayload(
    string OrderId,
    ulong CargoId,
    float FinalQuality01,
    string? Reason) : GameplayEventPayload;

public sealed record OrderStartedPayload(string OrderId, ulong StartedAtTick) : GameplayEventPayload;

public sealed record OrderBecameOvertimePayload(
    string OrderId,
    float OvertimeSeconds) : GameplayEventPayload;

public sealed record OrderSettledPayload(string OrderId, Settlement Settlement) : GameplayEventPayload;

public sealed record RouteCommittedPayload(
    string GraphId,
    string FromNodeId,
    string EdgeId,
    uint RouteRevision) : GameplayEventPayload;

// FuelRefuelStarted / FuelRefuelCanceled。
public sealed record RefuelLifecyclePayload(
    ulong TransactionId,
    ulong VehicleId,
    string StationId,
    string? Reason) : GameplayEventPayload;

public sealed record TransactionCommittedPayload(TransactionReceipt Receipt) : GameplayEventPayload;

// IncidentWarned / IncidentStageChanged / IncidentResolved。
public sealed record IncidentLifecyclePayload(
    ulong IncidentId,
    string DefinitionId,
    IncidentStage Stage,
    ulong StageStartedTick,
    float StageDurationSeconds,
    string? ResolvedReason) : GameplayEventPayload;

public sealed record CargoStolenPayload(
    IncidentLifecyclePayload Incident,
    ulong CargoId,
    string? RecoveryHintKey) : GameplayEventPayload;

// VehicleRolledOver / VehicleRecoveryStarted / VehicleRecoveryFinished。
public sealed record VehicleIncidentPayload(
    ulong VehicleId,
    bool IsRolledOver,
    bool RecoveryInProgress,
    string? Reason) : GameplayEventPayload;

public sealed record RoundResetPayload(uint NewEpoch, string CheckpointId) : GameplayEventPayload;
