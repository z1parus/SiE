# Этап 9 — Плейбук: как добавить виджет нового модуля

> Цель архитектуры — чтобы пятый, шестой, N-й модуль добавлялись по шаблону, **не трогая
> ядро** (`WidgetRegistry`, `WidgetRenderService`, Студию, фоновый воркер). Этот документ —
> чек-лист, доказывающий, что цель достигнута.

## Пример: добавляем виджет для модуля «Медитация» (`meditation`)

### Шаг 1 — Данные (Dart)

Создать `WidgetData`-наследника:

```dart
class MeditationWidgetData extends WidgetData {
  final int sessionsThisWeek;
  final int minutesThisWeek;
  final int zenStreak;
  @override String get signature => '$sessionsThisWeek:$minutesThisWeek:$zenStreak';
}
```

### Шаг 2 — Провайдер модуля

`packages/sie_core/lib/src/widgets_home/modules/meditation_widget_provider.dart`:

```dart
class MeditationWidgetProvider extends ModuleWidgetProvider<MeditationWidgetData> {
  @override String get moduleId => 'meditation';
  @override String get displayName => 'Медитация';
  @override IconData get glyph => Icons.self_improvement;
  @override String get branchSlug => 'meditation';
  @override List<WidgetSizeBucket> get supportedSizes =>
      const [WidgetSizeBucket.small, WidgetSizeBucket.medium];

  @override
  Future<MeditationWidgetData> loadData(AppDatabase db, WidgetConfig cfg) async {
    // читаем LocalMeditationSessions из Drift, агрегируем за неделю
  }

  @override
  Widget render(WidgetRenderContext ctx, WidgetConfig cfg, MeditationWidgetData d) {
    // чистый stateless-виджет в дизайн-токенах (этап 2)
  }

  @override
  List<WidgetOptionSpec> optionSchema(WidgetSizeBucket size) => const [
    WidgetOptionSpec.enumChoice('metric', 'Показатель',
        {'streak': 'Стрик', 'minutes': 'Минуты недели'}),
  ];

  @override
  List<WidgetQuickAction> quickActions(WidgetConfig cfg) => const []; // или старт сессии
}
```

### Шаг 3 — Регистрация (одна строка)

```dart
void registerHomeWidgets() {
  WidgetRegistry
    ..register(PlanningWidgetProvider())
    ..register(BreathingWidgetProvider())
    ..register(FocusWidgetProvider())
    ..register(HabitsWidgetProvider())
    ..register(MeditationWidgetProvider());   // ← +1 строка
}
```

### Шаг 4 — Нативный обвес (шаблон, ~5 минут)

1. Kotlin-наследник (отличается тремя полями):
   ```kotlin
   class MeditationWidgetProvider : SieWidgetProvider() {
       override val layoutId = R.layout.widget_meditation
       override val imageViewId = R.id.widget_image
       override val deepLinkHost = "meditation"
   }
   ```
2. Скопировать `widget_habits.xml` → `widget_meditation.xml` (структура та же).
3. Скопировать `widget_habits_info.xml` → `widget_meditation_info.xml`.
4. Добавить `<receiver>` в манифест.
5. Добавить ветку в deep-link `handleWidgetLaunch` (`case 'meditation':`).

> Шаги 1–5 — чистый boilerplate. Можно вынести в кодоген/шаблонный скрипт
> `tool/new_widget.dart`, генерирующий native-файлы по `moduleId`.

### Что НЕ трогаем

- `WidgetRegistry`, `WidgetRenderService`, `WidgetThemeBridge` — ядро.
- `WidgetStudioScreen` — рисует форму по `optionSchema` автоматически.
- `widgetCallbackDispatcher` / фоновый воркер — итерирует по реестру.
- Конфиг-активность, `WidgetConfigStore` — общие.

## Чек-лист нового модуля

- [ ] `XxxWidgetData extends WidgetData` (+`signature`)
- [ ] `XxxWidgetProvider extends ModuleWidgetProvider` (loadData/render/optionSchema)
- [ ] Drift-чтение офлайн, без сети
- [ ] `render` — чистая функция, дизайн-токены этапа 2, без `ref`
- [ ] Регистрация в `registerHomeWidgets()`
- [ ] Native: Kotlin-наследник + 2 XML + receiver + deep-link case
- [ ] (опц.) `quickActions` + ветки в `WidgetActionRouter`
- [ ] Превью в Студии корректно строится по `optionSchema`

## Метрика успеха

Добавление виджета нового модуля = **1 Dart-файл данных + 1 Dart-провайдер + 1 строка
регистрации + шаблонный native-обвес**. Ноль изменений в ядре. Время < 1 дня.
