using System.Collections.Generic;

namespace DeliveryGame.Contracts;

public interface IEconomyService
{
    EconomySnapshot ReadEconomy();
    RefuelQuote? ReadRefuelQuote(string stationId, ulong vehicleId);
    void RequestRefuel(CommandKey key, string stationId, ulong vehicleId,
        decimal requestedLiters, uint expectedEconomyRevision);
}

public sealed record EconomySnapshot(
    long WalletFen,
    uint EconomyRevision,
    StateStamp Stamp,
    IReadOnlyList<RefuelProgress> ActiveRefuels,
    IReadOnlyList<TransactionReceipt> Transactions);

public sealed record RefuelQuote(
    string StationId,
    ulong VehicleId,
    long UnitPriceFenPerLiter,
    decimal TankFreeLiters,
    decimal AffordableLiters,
    uint EconomyRevision);

public sealed record RefuelProgress(
    ulong TransactionId,
    CommandKey Key,
    string StationId,
    ulong VehicleId,
    float Progress01,
    StateStamp Stamp);

public sealed record TransactionReceipt(
    ulong TransactionId,
    CommandKey Key,
    string? OrderId,
    string StationId,
    ulong VehicleId,
    decimal AddedLiters,
    long CostFen,
    long WalletBeforeFen,
    long WalletAfterFen,
    decimal FuelBeforeLiters,
    decimal FuelAfterLiters,
    StateStamp Stamp);
