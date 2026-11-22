using System;
using System.Collections.Generic;
using Godot;

namespace DeliveryGame.Contracts;

public interface IGelService
{
    GelStateSnapshot ReadGelState();
    void RequestFireGel(GelFireRequest request);
    void RequestRecoverGel(GelRecoverRequest request);
    void RequestCancelGelRecovery(CommandKey key, ulong recoveryRequestId);

    event Action<GelCommandResult> GelCommandResolved;
    event Action<GelStateSnapshot> GelStateChanged;
}

public sealed record GelFireRequest(
    CommandKey Key,
    ulong GunId,
    Vector3 AimOriginWorldM,
    Vector3 AimDirectionWorld,
    ulong? TargetEntityId,
    Vector3? HitLocalPointM,
    uint ExpectedGunRevision);

public sealed record GelRecoverRequest(
    CommandKey Key,
    ulong GunId,
    ulong TargetGelId,
    uint ExpectedGunRevision);

public sealed record GelGunSnapshot(
    ulong GunId,
    ulong PlayerId,
    int CapacityUnits,
    int StoredUnits,
    int ReservedRecoverUnits,
    Color Color,
    uint GunRevision);

public sealed record GelBlockSnapshot(
    ulong GelId,
    ulong FiredByGunId,
    Color Color,
    PoseState Pose,
    IReadOnlyList<ulong> ConnectionIds);

// 待 B 确认：文档给出端点、有效状态及版本语义，以下采用暂定字段名。
public sealed record GelConnectionSnapshot(
    ulong ConnectionId,
    ulong EntityAId,
    ulong EntityBId,
    Vector3 LocalPointAM,
    Vector3 LocalPointBM,
    bool IsActive,
    uint ParameterVersion);

public sealed record GelRecoveryProgress(CommandKey Key, ulong GunId, ulong GelId, float Progress01);

public sealed record GelStateSnapshot(
    StateStamp Stamp,
    IReadOnlyList<GelGunSnapshot> Guns,
    IReadOnlyList<GelBlockSnapshot> Blocks,
    IReadOnlyList<GelConnectionSnapshot> Connections,
    IReadOnlyList<GelRecoveryProgress> ActiveRecoveries);

public sealed record GelCommandResult(
    CommandResolution Resolution,
    ulong? GelId,
    GelGunSnapshot? Gun,
    int UnitsDelta);
