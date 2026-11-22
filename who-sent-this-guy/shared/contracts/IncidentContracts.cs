using System.Collections.Generic;
using Godot;

namespace DeliveryGame.Contracts;

public interface IIncidentService
{
    IncidentSnapshot[] ReadIncidents();
}

// 待 B 确认：InfluenceBounds 暂用 Aabb，类型专属状态的表示及字段名暂定。
public sealed record IncidentSnapshot(
    ulong IncidentId,
    string DefinitionId,
    StateStamp Stamp,
    IncidentStage Stage,
    ulong StageStartedTick,
    float StageDurationSeconds,
    Aabb InfluenceBounds,
    IReadOnlyList<ulong> AffectedEntityIds,
    string? ResolvedReason,
    IncidentState? State);

public enum IncidentStage
{
    Warn,
    Active,
    Recovery,
    Resolved
}

public abstract record IncidentState;

public sealed record UfoState(
    Vector3 BeamPositionM,
    float BeamIntensity,
    IReadOnlyList<ulong> AffectedVehicleIds) : IncidentState;

public sealed record TornadoState(Vector3 WindDirection, float WindIntensity) : IncidentState;

public sealed record CowRiderState(
    ulong? RiderEntityId,
    ulong? VehicleId,
    string? RearDoorId,
    string? AttemptStage,
    float Progress01,
    ulong? TargetCargoId) : IncidentState;
