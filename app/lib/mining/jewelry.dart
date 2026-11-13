import 'dart:math';

/// The second factory converts refined gold into jewelry held for end-of-run
/// settlement. Values are game balance parameters, not real gold prices.
class JewelryWorkshop {
  static const double goldPerPiece = 2;
  static const double laborCostPerPiece = 18;
  int purityLevel = 0;
  int artisanLevel = 0;
  int pieces = 0;
  double goldConsumed = 0;

  // Higher purity improves intrinsic value; skill improves crafting value.
  double get purityMultiplier => 1 + purityLevel * .20;
  double get craftsmanshipMultiplier => 1.5 + artisanLevel * .5;

  double get valuePerPiece =>
      goldPerPiece * 25 * purityMultiplier * craftsmanshipMultiplier;

  double get settlementValue => pieces * valuePerPiece;

  bool canCraft(double availableGold, double cash) =>
      availableGold + 1e-7 >= goldPerPiece &&
      cash + 1e-7 >= laborCostPerPiece;

  int maxAffordablePieces(double availableGold, double cash) =>
      max(0, min((availableGold / goldPerPiece).floor(),
          (cash / laborCostPerPiece).floor()));

  void recordCrafted(int amount) {
    if (amount <= 0) return;
    pieces += amount;
    goldConsumed += goldPerPiece * amount;
  }
}
