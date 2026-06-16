# Исправление конфликта Android-жестов с навигацией приложения

## Диагностика проблемы

### Корневая причина

На Android 13+ (API 33+) с жестовой навигацией системный **edge-swipe** (свайп от края экрана) вызывает действие **"Назад"**, которое триггерит `Navigator.pop()`. Проблема в том, что:

1. **Все экраны** используют `MaterialPageRoute` → каждый `pop()` моментально закрывает экран **без анимации свайпа** и без подтверждения.
2. **Главный экран (Shell)** не защищён `PopScope` → системный свайп на корневом экране **закрывает приложение целиком**.
3. **Только 4 из ~30+ экранов** имеют `PopScope`-защиту (только иммерсивные: дыхание, медитация).
4. **TabBarView** на 3 экранах (кастомизация, друзья, интерфейс) — свайпы между табами конфликтуют с системным edge-swipe.

### Карта затронутых компонентов

| Компонент | Файл | Текущая защита | Проблема |
|-----------|------|---------------|----------|
| **Main Shell** | `main_navigation_shell.dart` | ❌ Нет | Свайп = выход из приложения |
| **TabBarView** (3 экрана) | `customization_screen.dart`, `friends_list_screen.dart`, `interface_hub_screen.dart` | ❌ Нет | Системный свайп от края перехватывает жест вместо переключения таба |
| **SwipeableHabitCard** | `habit_tracker_screen.dart` | ✅ `systemGestureInsets` | Уже корректно обрабатывает |
| **PageView** (рутины) | `habit_tracker_screen.dart` | ❌ Нет | Свайп в карусели рутин может триггерить pop |
| **Все pushed-экраны** | ~25 экранов | ❌ Нет | Случайный свайп = мгновенный pop без подтверждения |

---

## План исправления (3 этапа)

### Этап 1. Защита от случайного выхода из приложения

**Файл:** [main_navigation_shell.dart](file:///C:/Users/z1pa/Projects/SiE/apps/central_hub/lib/screens/main_navigation_shell.dart)

**Что делаем:** Оборачиваем корневой `Scaffold` в `PopScope`, реализуем паттерн **«двойное нажатие для выхода»**.

```dart
PopScope(
  canPop: false,
  onPopInvokedWithResult: (didPop, _) {
    if (didPop) return;
    final now = DateTime.now();
    if (_lastBackPress != null && 
        now.difference(_lastBackPress!) < const Duration(seconds: 2)) {
      SystemNavigator.pop(); // выход из приложения
    } else {
      _lastBackPress = now;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Нажмите ещё раз для выхода'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  },
  child: Scaffold(...)
)
```

**Результат:** Пользователь больше не сможет случайно закрыть приложение одним свайпом.

---

### Этап 2. Отключение предиктивного back-gesture на экранах с горизонтальными свайпами

**Проблема:** `TabBarView` и `PageView` используют горизонтальные свайпы, которые конфликтуют с Android edge-swipe.

**Решение:** На Android — отключаем системный back-gesture на конкретных экранах через `PopScope(canPop: false)` + ручной вызов `Navigator.pop()` по кнопке «Назад» в AppBar.

**Затронутые файлы:**
- [customization_screen.dart](file:///C:/Users/z1pa/Projects/SiE/apps/central_hub/lib/screens/customization_screen.dart)
- [friends_list_screen.dart](file:///C:/Users/z1pa/Projects/SiE/apps/central_hub/lib/screens/friends_list_screen.dart)
- [interface_hub_screen.dart](file:///C:/Users/z1pa/Projects/SiE/apps/central_hub/lib/screens/interface_hub_screen.dart)

**Паттерн для каждого файла:**
```dart
@override
Widget build(BuildContext context) {
  return PopScope(
    canPop: !Platform.isAndroid, // На iOS — стандартный back, на Android — блокируем
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) Navigator.of(context).pop();
    },
    child: Scaffold(
      // AppBar с кнопкой «Назад» для явного выхода
      appBar: AppBar(leading: BackButton()),
      body: TabBarView(...), // свайпы табов работают без конфликта
    ),
  );
}
```

**Результат:** На Android системный edge-swipe не перехватывает горизонтальные свайпы TabBarView/PageView. Пользователь выходит только через кнопку «Назад» в AppBar.

---

### Этап 3. Исключение зон системных жестов для интерактивных элементов

**Проблема:** Горизонтальные свайпы внутри `PageView` (карусель рутин в habit_tracker) и `TabBarView` начатые от края экрана перехватываются системой.

**Решение:** Использовать `AndroidSystemGestureExclusionRects` для указания зон, где приложение приоритетнее системы.

> [!IMPORTANT]
> Android ограничивает исключаемую зону до **200dp** по вертикали на каждый экран. Этого достаточно для карусели рутин, но не для полноэкранных TabBarView. Поэтому для TabBarView применяется решение из Этапа 2.

**Файл:** [habit_tracker_screen.dart](file:///C:/Users/z1pa/Projects/SiE/apps/central_hub/lib/screens/habit_tracker_screen.dart) (карусель рутин с PageView)

```dart
// Обёртка над PageView с исключением зон системных жестов
class _GestureExclusionWrapper extends StatelessWidget {
  final Widget child;
  const _GestureExclusionWrapper({required this.child});

  @override
  Widget build(BuildContext context) {
    if (!Platform.isAndroid) return child;
    return AndroidView(
      // SystemGestureExclusionRects через RenderObject
      child: child,
    );
  }
}
```

---

## Резюме изменений

| Этап | Затронутые файлы | Суть изменения |
|------|-----------------|----------------|
| **1** | `main_navigation_shell.dart` | `PopScope` + «двойное нажатие для выхода» |
| **2** | `customization_screen.dart`, `friends_list_screen.dart`, `interface_hub_screen.dart` | `PopScope(canPop: false)` на Android для экранов с `TabBarView` |
| **3** | `habit_tracker_screen.dart` | Gesture exclusion rect для `PageView` карусели рутин |

> [!NOTE]
> **Экраны с уже корректной обработкой** (не требуют изменений):
> - `breathing_exercise_screen.dart` — `PopScope` с подтверждением
> - `meditation_session_screen.dart` — `PopScope` с подтверждением
> - `meditation_preflight_screen.dart` — `PopScope` с подтверждением  
> - `meditation_preset_builder_screen.dart` — `PopScope` с подтверждением
> - `_SwipeableHabitCard` — уже использует `systemGestureInsets`
