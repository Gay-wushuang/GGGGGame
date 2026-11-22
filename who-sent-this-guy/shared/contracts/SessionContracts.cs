using System;
using System.Collections.Generic;
using Godot;

namespace DeliveryGame.Contracts;

public interface ISessionService
{
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
}

// 待 B 确认：房间入口、会话阶段、连接状态和成员字段。暂用键与确认玩家 ID。
public sealed record RoomOptions(string LevelConfigId);

public sealed record SessionOptions(string? RoomId, string? ConnectionEntry);

public sealed record SessionMemberSnapshot(ulong PlayerId, string? ConnectionState);

public sealed record SessionSnapshot(
    string? Stage,
    string? FailureReasonKey,
    string? RoomId,
    ulong? LocalPlayerId,
    ulong? HostPlayerId,
    IReadOnlyList<SessionMemberSnapshot> Members,
    string? ConnectionState,
    StateStamp Stamp);

// 待 B 确认：文档未指定宽度的标识、时钟、版本及枚举的传输表示。
// 本地 C# 声明暂用 ulong 表示数字 ID 和 tick，uint 表示回合与版本。
public readonly record struct CommandKey(
    uint RoundEpoch,
    ulong PlayerId,
    ulong RequestId,
    ulong InputTick);

public readonly record struct StateStamp(uint RoundEpoch, ulong StateTick, uint Revision);

// 待 B 确认：姿态采样版本的字段名。
public readonly record struct PoseState(
    Vector3 PositionM,
    Quaternion Rotation,
    Vector3 LinearVelocityMps,
    Vector3 AngularVelocityRadps,
    uint SampleVersion);

// 待 B 确认：通用结果的 TargetId 暂用于数字实体标识，无此类目标时可空。
public sealed record CommandResolution(
    CommandKey Key,
    ResultCode Code,
    ulong? TargetId,
    StateStamp Stamp,
    string? ReasonKey);

public enum ResultCode
{
    Accepted,
    InvalidRound,
    InvalidActor,
    NotAuthorized,
    TargetMissing,
    OutOfReach,
    Obstructed,
    HandsBusy,
    GripFull,
    SeatOccupied,
    VehicleMoving,
    NoSafeExit,
    StateChanged,
    InvalidState,
    InsufficientFunds,
    FuelTankFull,
    NoFuelToAdd,
    RouteUnavailable,
    OrderClosed,
    Cooldown,
    Cancelled,
    GelGunEmpty,
    GelGunFull,
    GelBusy,
    GelAlreadyRecovered,
    GelLimitReached
}
