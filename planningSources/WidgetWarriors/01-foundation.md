# Этап 1 — Фундамент: мост, реестр, нативный скелет

## Описание

Создаём инфраструктуру, на которой стоят все виджеты модулей: пакет-мост, нативный обвес,
абстракцию `ModuleWidgetProvider` + `WidgetRegistry`, хранилище конфигов и deep-link роутинг.
После этого этапа в системе есть один работающий «пустой» виджет-заглушка, доказывающий, что
весь конвейер (Flutter → PNG → home screen → tap → экран) проходит насквозь.

## Затрагиваемые модули

- `apps/central_hub/pubspec.yaml` — зависимости.
- `apps/central_hub/android/` — манифест, Kotlin-провайдеры, XML.
- `apps/central_hub/lib/main.dart` — инициализация моста, deep-link обработчик.
- **Новый пакет логики:** `packages/sie_core/lib/src/widgets_home/` (или `apps/central_hub/lib/home_widgets/`).
  Размещаем в `sie_core`, т.к. провайдеры данных и `SieColors` живут там.

## Зависимости

```yaml
dependencies:
  home_widget: ^0.7.0      # мост Flutter ↔ App Widget, рендер в PNG
  workmanager: ^0.5.2      # фоновое периодическое обновление (этап 8)
  # shared_preferences, path_provider — уже есть
```

## Нативный скелет (Android)

Пакет приложения: `com.example.central_hub`. Kotlin, JVM 17, NDK 27, `MainActivity : FlutterActivity`.

### 1. Базовый провайдер

`android/app/src/main/kotlin/com/example/central_hub/widgets/SieWidgetProvider.kt`

```kotlin
abstract class SieWidgetProvider : HomeWidgetProvider() {
    abstract val layoutId: Int          // R.layout.widget_<module>
    abstract val imageViewId: Int       // R.id.widget_image
    abstract val deepLinkHost: String   // "planning" | "habits" | ...

    override fun onUpdate(ctx: Context, mgr: AppWidgetManager,
                          ids: IntArray, prefs: SharedPreferences) {
        ids.forEach { id ->
            val views = RemoteViews(ctx.packageName, layoutId)
            // 1) картинка, отрисованная Flutter-ом
            prefs.getString("widget_image_$id", null)?.let { path ->
                views.setImageViewBitmap(imageViewId, BitmapFactory.decodeFile(path))
            }
            // 2) тап по всему виджету → открыть модуль
            views.setOnClickPendingIntent(imageViewId,
                deepLinkIntent(ctx, "sie://widget/$deepLinkHost?id=$id"))
            mgr.updateAppWidget(id, views)
        }
    }
}
```

Каждый модуль — тонкий наследник (отличается только `layoutId`/`deepLinkHost`):

```kotlin
class HabitsWidgetProvider : SieWidgetProvider() {
    override val layoutId = R.layout.widget_habits
    override val imageViewId = R.id.widget_image
    override val deepLinkHost = "habits"
}
```

### 2. Layout (один на модуль, но идентичный по структуре)

`android/app/src/main/res/layout/widget_habits.xml` — `ImageView` на всю площадь +
（опционально) контейнер прозрачных tap-зон для быстрых действий (этап 8).

```xml
<FrameLayout android:layout_width="match_parent" android:layout_height="match_parent">
    <ImageView android:id="@+id/widget_image"
        android:layout_width="match_parent" android:layout_height="match_parent"
        android:scaleType="fitXY" android:adjustViewBounds="true"/>
    <LinearLayout android:id="@+id/widget_actions" .../> <!-- этап 8 -->
</FrameLayout>
```

### 3. widget-info (размеры, превью, конфиг-активность)

`android/app/src/main/res/xml/widget_habits_info.xml`

```xml
<appwidget-provider
    android:minWidth="110dp" android:minHeight="110dp"
    android:targetCellWidth="2" android:targetCellHeight="2"
    android:resizeMode="horizontal|vertical"
    android:widgetCategory="home_screen"
    android:updatePeriodMillis="0"          <!-- обновляем сами, не системой -->
    android:configure="com.example.central_hub.WidgetConfigActivity"
    android:previewLayout="@layout/widget_habits"/>
```

### 4. Манифест

Зарегистрировать каждый провайдер + одну конфиг-активность + интент-фильтр deep-link.
`RECEIVE_BOOT_COMPLETED` уже есть.

```xml
<receiver android:name=".widgets.HabitsWidgetProvider" android:exported="false">
    <intent-filter><action android:name="android.appwidget.action.APPWIDGET_UPDATE"/></intent-filter>
    <meta-data android:name="android.appwidget.provider"
               android:resource="@xml/widget_habits_info"/>
</receiver>
```

`MainActivity` ловит deep-link `sie://widget/...` (launchMode уже `singleTop`).

## Flutter-ядро

### Абстракция модуля

`packages/sie_core/lib/src/widgets_home/module_widget_provider.dart`

```dart
/// Контракт, который реализует КАЖДЫЙ модуль. Ядро больше ничего не знает о модуле.
abstract class ModuleWidgetProvider<T extends WidgetData> {
  String get moduleId;            // 'habits'
  String get displayName;         // 'Привычки'
  IconData get glyph;             // иконка в Студии виджетов
  String get branchSlug;          // 'habit_archive' — для deep-link навигации
  List<WidgetSizeBucket> get supportedSizes;

  /// Offline-first: читаем Drift напрямую, без сети.
  Future<T> loadData(AppDatabase db, WidgetConfig config);

  /// Чистый stateless-виджет. БЕЗ ref/Provider — рендерится в headless-изоляте.
  Widget render(WidgetRenderContext ctx, WidgetConfig config, T data);

  /// Быстрые действия (этап 8). По умолчанию пусто.
  List<WidgetQuickAction> quickActions(WidgetConfig config) => const [];
}
```

### Реестр

`packages/sie_core/lib/src/widgets_home/widget_registry.dart`

```dart
class WidgetRegistry {
  static final _providers = <String, ModuleWidgetProvider>{};
  static void register(ModuleWidgetProvider p) => _providers[p.moduleId] = p;
  static ModuleWidgetProvider? byId(String id) => _providers[id];
  static List<ModuleWidgetProvider> get all => _providers.values.toList();
}

// Точка сборки (вызывается из main и из background-callback):
void registerHomeWidgets() {
  WidgetRegistry
    ..register(PlanningWidgetProvider())
    ..register(BreathingWidgetProvider())
    ..register(FocusWidgetProvider())
    ..register(HabitsWidgetProvider());
}
```

### Хранилище конфигов

`WidgetConfigStore` — обёртка над `SharedPreferences`, ключ `widget_cfg_<appWidgetId>`.
Хранит JSON `WidgetConfig` (см. этап 7): `moduleId`, `sizeBucket`, `themeOverride`,
`accentOverride`, `contentOptions`.

### Deep-link роутинг

В `main.dart` уже есть `rootNavigatorKey` и паттерн `_handleNotificationTap`. Добавляем
обработчик `sie://widget/<host>?id=<appWidgetId>`:

```dart
void handleWidgetLaunch(Uri uri) {
  final nav = rootNavigatorKey.currentState;
  switch (uri.host) {
    case 'planning': nav?.push(route(const PlanningScreen()));
    case 'habits':   nav?.push(route(const HabitTrackerScreen()));
    case 'focus':    nav?.push(route(const FocusProtocolScreen()));
    case 'breathing':nav?.push(route(const BreathingExerciseScreen()));
  }
}
```

Источник запуска — `home_widget`'s `initiallyLaunchedFromHomeWidget()` +
`HomeWidget.widgetClicked` stream.

## Проверка этапа

1. Заглушка-провайдер рисует карточку «Hello SiE» в нужном `SieColors`.
2. Виджет ставится на домашний экран, показывает PNG.
3. Тап открывает экран модуля.
4. `flutter analyze` — 0 errors; сборка APK проходит.

## Открытые вопросы

- Где физически держать код виджетов — `sie_core` (ближе к данным/теме) vs `central_hub`
  (ближе к экранам для deep-link). Предложение: провайдеры данных и рендер — в `sie_core`,
  навигация и регистрация — в `central_hub`.
- Имя схемы deep-link: `sie://` — проверить, не занята ли (сейчас не используется).
