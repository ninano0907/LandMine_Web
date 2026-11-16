/// One instance per team. Existing and newly spawned units read it live.
/// Keep separate instances for opposing teams; never use a global singleton.
class UnitUpgrades {
  int _attackLevel = 0;
  int _defenseLevel = 0;

  int get attackLevel => _attackLevel;
  int get defenseLevel => _defenseLevel;

  void upgradeAttack() => _attackLevel++;
  void upgradeDefense() => _defenseLevel++;
}
