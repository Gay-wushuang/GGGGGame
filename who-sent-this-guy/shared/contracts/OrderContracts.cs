using System.Collections.Generic;
using Godot;

namespace DeliveryGame.Contracts;

public interface IOrderService
{
    OrderSnapshot ReadOrder();
    void RequestStartOrder(CommandKey key);
    void RequestConfirmCargoLost(CommandKey key, ulong cargoId);

    // false 对应返回取笼或明确取消，true 对应只交鸡。
    void RequestResolveChickenDeliveryChoice(CommandKey key, string orderId,
        ulong cargoId, bool deliverWithoutCage, uint expectedChoiceRevision);

    void RequestEndOrder(CommandKey key, string orderId);

    // 重试当前关，从关前快照恢复并切换 RoundEpoch。
    void RequestReset(CommandKey key);
}

public interface IRouteService
{
    RouteGraphSnapshot ReadRouteGraph();
    void RequestSelectRoute(CommandKey key, string edgeId, uint expectedRouteRevision);
    void RequestCommitRoute(CommandKey key, string edgeId, uint expectedRouteRevision);
}

public sealed record OrderSnapshot(
    string? OrderId,
    StateStamp Stamp,
    OrderPhase Phase,
    IReadOnlyList<ulong> CargoIds,
    float DeadlineSeconds,
    ulong? StartedAtTick,
    float ElapsedSeconds,
    float OvertimeSeconds,
    IReadOnlyList<ulong> DeliveredIds,
    IReadOnlyList<ulong> LostIds,
    int RequiredCount,
    ChickenDeliveryChoice? ChickenDeliveryChoice,
    Settlement? Settlement);

// 报价按整数分表示，具体数值待 B 标定。
public sealed record ChickenDeliveryChoice(ulong CargoId, long PackagingFeeFen, uint Revision);

public enum OrderPhase
{
    Preparing,
    Loading,
    InTransit,
    Unloading,
    Settled,
    Resetting
}

// 待 B 确认：文档未规定 Seed 的宽度和路线标识格式。
public sealed record RouteGraphSnapshot(
    string GraphId,
    ulong Seed,
    IReadOnlyList<RouteNode> Nodes,
    IReadOnlyList<RouteEdge> Edges,
    string? CurrentNodeId,
    string? SelectedEdgeId,
    IReadOnlyList<string> CommittedEdgeIds,
    uint RouteRevision,
    StateStamp Stamp);

// 待 B 确认：节点 Kind 和风险标签暂用配置键。
public sealed record RouteNode(
    string NodeId,
    int Layer,
    string Kind,
    Vector3 PositionM,
    string? FuelStationId,
    IReadOnlyList<string> DisclosedRisks);

public sealed record RouteEdge(
    string EdgeId,
    string FromNodeId,
    string ToNodeId,
    float EstimatedTravelSeconds,
    decimal EstimatedFuelLiters,
    IReadOnlyList<string> RiskTags,
    string RoadSectionId);

// 包装费单列。NetPayFen 为扣费后实发。待 B 确认整数分字段的传输宽度。
public sealed record Settlement(
    string SettlementId,
    string OrderId,
    float FinalElapsedSeconds,
    IReadOnlyList<CargoSettlementLine> CargoLines,
    long GrossFeeFen,
    long OvertimePenaltyFen,
    long PackagingFeeFen,
    long NetPayFen);

public sealed record CargoSettlementLine(
    ulong CargoId,
    long BaseFeeFen,
    float FinalQuality01,
    CargoStatus Status,
    long EarnedFeeFen);
