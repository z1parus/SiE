enum LifeArea {
  health,
  mind,
  productivity,
  relationships,
  finance,
  spirit,
}

extension LifeAreaX on LifeArea {
  String get label => switch (this) {
    LifeArea.health        => 'Здоровье',
    LifeArea.mind          => 'Ум',
    LifeArea.productivity  => 'Продуктивность',
    LifeArea.relationships => 'Отношения',
    LifeArea.finance       => 'Финансы',
    LifeArea.spirit        => 'Дух',
  };

  String get icon => switch (this) {
    LifeArea.health        => '❤️',
    LifeArea.mind          => '🧠',
    LifeArea.productivity  => '⚡',
    LifeArea.relationships => '👥',
    LifeArea.finance       => '💰',
    LifeArea.spirit        => '🌿',
  };

  static LifeArea? fromString(String? s) =>
      s == null ? null : LifeArea.values.where((e) => e.name == s).firstOrNull;
}
