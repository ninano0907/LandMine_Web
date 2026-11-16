/// Shared initial values. Character classes override only their differences.
abstract final class UnitDefaults {
  static const maxHealth = 100;
  static const attackPower = 10;
  static const defense = 0;
  static const speed = 100.0;
  static const radius = 16.0;
  static const attackRange = 48.0;
  static const attackCycle = 0.6;
  static const workCycle = 1.0;
}

class UnitStats {
  const UnitStats({
    this.maxHealth = UnitDefaults.maxHealth,
    this.attackPower = UnitDefaults.attackPower,
    this.defense = UnitDefaults.defense,
    this.speed = UnitDefaults.speed,
    this.radius = UnitDefaults.radius,
    this.attackRange = UnitDefaults.attackRange,
    this.attackUpgradeBonus = 1,
    this.defenseUpgradeBonus = 1,
  });

  final int maxHealth;
  final int attackPower;
  final int defense;
  final double speed;
  final double radius;
  final double attackRange;
  final int attackUpgradeBonus;
  final int defenseUpgradeBonus;
}
