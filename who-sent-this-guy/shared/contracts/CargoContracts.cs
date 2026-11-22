using System.Collections.Generic;
using Godot;

namespace DeliveryGame.Contracts;

public interface IPhysicsObjectService
{
    // 每人限抓一个实体，每个实际目标最多两人。单鸡货物默认目标为笼体。
    // 鸡离笼后，才可用 ChickenEntityId 将其作为独立抓取目标。
    void RequestGrab(CommandKey key, ulong cargoId, Vector3 localPointM,
        ulong? targetEntityId = null);
    void RequestRelease(CommandKey key, ulong cargoId, ulong? targetEntityId = null);
    void SubmitGripTarget(CommandKey key, ulong cargoId,
        Vector3 positionWorldM, Quaternion rotationWorld, ulong? targetEntityId = null);

    // 返回同一货物的全部参与者，由 TargetEntityId 区分各实际目标。
    GripParticipant[] ReadParticipants(ulong cargoId);
    CargoSnapshot? ReadCargo(ulong cargoId);

    // 回笼和笼门请求分别使用 ConditionRevision 和 CageDoorRevision。
    void RequestReturnChickenToCage(CommandKey key, ulong cargoId, uint expectedConditionRevision);
    void RequestSetCageDoor(CommandKey key, ulong cargoId,
        bool open, uint expectedCageDoorRevision);
}

// 待 B 确认：GripMode 的取值暂用可空键。
public sealed record GripParticipant(
    ulong PlayerId,
    ulong CargoId,
    ulong TargetEntityId,
    Vector3 LocalPointM,
    Vector3 TargetPositionM,
    Quaternion TargetRotation,
    string? GripMode,
    ulong LastInputTick);

// 待 B 确认：ShapeKind 的取值和 ParameterVersion 的字段名。
public sealed record CargoDefinition(
    string DefinitionId,
    Vector3 SizeM,
    string ShapeKind,
    float? SphereDiameterM,
    float MassKg,
    string SurfaceId,
    long BaseFeeFen,
    uint ParameterVersion);

// 单鸡货物的 CargoId 和 Pose 指向笼体，Condition 中保存独立的鸡实体。
public sealed record CargoSnapshot(
    ulong CargoId,
    string DefinitionId,
    string? OrderId,
    StateStamp Stamp,
    PoseState Pose,
    float MassKg,
    IReadOnlyList<GripParticipant> Participants,
    IReadOnlyList<ulong> GelConnectionIds,
    float Quality01,
    CargoCondition? Condition,
    uint ConditionRevision,
    CargoStatus Status);

public enum CargoStatus
{
    Pending,
    StolenRecoverable,
    Delivered,
    Lost,
    Destroyed
}

// 待 B 确认：条件载荷的类型表示。暂用有类型的载荷，球形货物可用空条件。
public abstract record CargoCondition;

public sealed record FishTankCondition(FishTankState State) : CargoCondition;

public enum FishTankState
{
    Intact,
    Cracked,
    Broken
}

// Pose 为鸡的世界姿态。只交鸡时，Delivered 与 CageLeftInLevel 可以同时成立。
// 留笼标记供 E 在实际切换到下一关时清理对应笼体。
public sealed record ChickenCondition(
    ulong ChickenEntityId,
    bool InCage,
    PoseState Pose,
    bool CageDoorOpen,
    uint CageDoorRevision,
    bool CageLeftInLevel = false) : CargoCondition;
