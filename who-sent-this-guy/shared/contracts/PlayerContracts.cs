using System.Collections.Generic;
using Godot;

namespace DeliveryGame.Contracts;

public interface IPlayerService
{
    void SubmitInput(CommandKey key, CharacterInput input);
    PlayerSnapshot? ReadPlayer(ulong playerId);
}

public interface ICameraContextService
{
    void EnterContext(string contextId, CameraContextKind kind, ulong focusId);
    void ExitContext(string contextId);
    CameraContextKind ReadActiveContext();
}

public interface IHandbookService
{
    bool TryOpenWorldHandbook(ulong handbookEntityId);
    void CloseHandbook();
}

public interface IBindingsService
{
    BindingSnapshot ReadBindings();
    BindingResult TrySetBinding(string actionId, InputBinding binding);
}

public readonly record struct CharacterInput(
    Vector2 MoveAxis,
    Vector2 LookDeltaRad,
    bool SprintHeld,
    bool CrouchHeld,
    bool JumpPressed);

// 待 B 确认：Stance 的取值暂用可空键。
public sealed record PlayerSnapshot(
    ulong PlayerId,
    StateStamp Stamp,
    PoseState Pose,
    PlayerLifeState LifeState,
    LocomotionMode LocomotionMode,
    string? Stance,
    ulong? HeldCargoId,
    ulong? SeatedVehicleId,
    string? SeatId,
    ulong? SupportedVehicleId,
    float BodyMassKg);

public enum PlayerLifeState
{
    Active,
    Recovering,
    Disconnected
}

public enum LocomotionMode
{
    OnFoot,
    Seated
}

// 待 B 确认：上下文类别暂按已确认的两个观察方式表示。
public enum CameraContextKind
{
    FirstPerson,
    ThirdPerson
}

// 待 B 确认：输入设备、绑定编码及冲突结果的细节。暂保留绑定键和操作反馈。
public sealed record InputBinding(string BindingKey);

public sealed record BindingSnapshot(IReadOnlyDictionary<string, InputBinding> Bindings);

public sealed record BindingResult(bool Accepted, string? ReasonKey);
