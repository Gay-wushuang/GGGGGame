using System.Collections.Generic;
using Godot;

namespace DeliveryGame.Contracts;

public interface IVehicleService
{
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
}

public readonly record struct DriveInput(float ForwardAxis, float SteeringAxis, bool HandbrakeHeld);

public sealed record VehicleSnapshot(
    ulong VehicleId,
    StateStamp Stamp,
    PoseState Pose,
    float SpeedMps,
    float RollDeg,
    float LoadMassKg,
    float OccupantMassKg,
    float TransportedSystemMassKg,
    float VehicleRigidBodyMassKg,
    Vector3 EffectiveCenterOfMassLocalM,
    bool EngineRunning,
    float EngineLoad01,
    float SkidIntensity01,
    IReadOnlyList<SeatSnapshot> Seats,
    IReadOnlyList<DoorSnapshot> Doors,
    bool CruiseEnabled,
    float CruiseTargetMps,
    float HornCooldownRemainingSeconds,
    decimal FuelLiters,
    decimal FuelCapacityLiters,
    bool IsRolledOver,
    bool RecoveryInProgress,
    bool RecoveryAvailable,
    string? RecoveryReasonKey);

// 待 B 确认：ExitCandidates 暂为位置列表，坐标空间和是否包含朝向待定。
public sealed record SeatSnapshot(
    string SeatId,
    ulong? OccupantPlayerId,
    Transform3D SeatTransform,
    IReadOnlyList<Vector3> ExitCandidates);

public sealed record DoorSnapshot(string DoorId, bool Open, DoorLatchState? LatchState, uint Revision);

public enum DoorLatchState
{
    Latched,
    Unlatched
}
