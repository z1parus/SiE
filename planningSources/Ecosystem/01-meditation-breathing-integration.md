# Этап 1: Интеграция модулей Медитации и Дыхания

## Описание
Сейчас «дыхание перед медитацией» и модуль «Дыхание» — это две **разные, несвязанные** реализации:

- **В медитации** (`MeditationSessionProvider`): простой ведомый паттерн — `MeditationPhase.breathing` + `BreathingSubPhase.inhale/holdIn/exhale/holdOut`, конфигурация в `MeditationPreset` (`hasBreathing`, `breathingPatternId` = `box`|`4-7-8`|`coherence`, `breathingDurationMin`). Никаких раундов/задержек/метрик. Пишется одной строкой `meditation_sessions` (сумма `breathingElapsedSecs + meditationElapsedSecs`), строки `breathing_sessions` не создаётся.
- **В модуле Дыхания** (`BreathingExerciseScreen`): полноценная практика в формате Вима Хофа — раунды (`BreathingRound`), циклы, задержки на выдохе/восстановительные, метрики `breaths`/`rounds`/`longestHoldSeconds`/`totalHoldSeconds` + пост-практика (`moodEmoji`/`calmness`/`confidence`). Финал: `BreathingRecoveryScreen` → `BreathingReflectionScreen` → запись через `SessionCompletionNotifier`.

**Цель:** убрать упрощённую реализацию из медитации и соединить модули напрямую. Пользователь настраивает медитацию, выбирает предварительную дыхательную практику — и получает **настоящий** модуль дыхания, сконфигурированный под эту сессию, который по завершении **без лишних действий** переносит его в медитацию. Метрики модулей учитывают друг друга.

## Пользовательский сценарий
1. Пользователь открывает модуль Медитации → выбирает/создаёт пресет → экран `MeditationPreflightScreen`.
2. Включает тумблер «Предварительная дыхательная практика». Вместо чипов `box/4-7-8/coherence` выбирает **настоящую конфигурацию дыхания** (сохранённую `BreathingSequence` или быстрые параметры раундов — см. открытый вопрос №1).
3. Нажимает «Запустить». Открывается **привычный экран дыхания** (`BreathingExerciseScreen`) в режиме «в составе медитации»: тот же UI/сфера/аудио, но без кнопок «Журнал/Статистика/Последовательности» и с прогрессом «дыхание → медитация».
4. Практика дыхания завершается. **Без reflection/recovery-развилок** (или с кратким авто-переходным экраном) пользователь автоматически оказывается на `MeditationSessionScreen`, сразу в фазе медитации по заранее заданной конфигурации — не теряя концентрации.
5. Медитация завершается как обычно (`stateAfter`, награда XP/DP).
6. **Метрики связаны:**
   - В **журнале дыхания** сессия помечена бейджем «в составе медитации» (и тапом ведёт к связанной медитации).
   - В **статистике/итогах медитации** учитываются метрики дыхательной части (дыхания, раунды, задержки, длительность дыхания).

## Логика и поведение
### Режим «цепочки» (chained)
- `BreathingExerciseScreen` получает необязательный параметр `chain` (напр. `MeditationChainConfig` c `preset` + признаком встроенности) и колбэк `onChainComplete(BreathingSessionMetrics metrics)`.
- Когда `chain != null`:
  - Скрываются нав-кнопки журнала/статистики/последовательностей и авто-старт курса.
  - По завершении **не** создаётся отдельная запись `breathing_sessions` внутри экрана и **не** открывается `BreathingReflectionScreen`. Вместо этого метрики возвращаются в поток медитации.
  - Recovery-экран: либо пропускается, либо заменяется коротким авто-переходным экраном «Переход к медитации…» (открытый вопрос №2).
- Поток медитации (новый координатор или расширенный `MeditationPreflight._launch`) на `onChainComplete`:
  1. Пишет строку `breathing_sessions` с метриками, помеченную `meditation_session_id` (линк) и/или флагом `part_of_meditation`.
  2. Открывает `MeditationSessionScreen`, стартуя **сразу с фазы медитации** (без встроенного дыхания), передав длительность дыхания для суммарных метрик.
  3. По завершении медитации пишет `meditation_sessions` с `breathing_session_id` (обратный линк) и суммарной длительностью.

### Удаление старой реализации
- Из `MeditationSessionProvider`: убрать `MeditationPhase.breathing`, `MeditationPhase.transition`, `BreathingSubPhase`, паттерны `box/4-7-8/coherence`, `breathingElapsedSecs`-тик дыхания. Медитация-сессия начинается сразу с `meditating`.
- Из `MeditationSessionScreen`: убрать `_breathScaleCtrl`/`_BreathingCue`/ветку `phase == breathing`.
- Из `MeditationPreflightScreen`: убрать чипы паттернов и слайдер `breathingDurationMin`-паттерна; заменить на выбор реальной конфигурации дыхания.
- Из `MeditationPreset`: поля `breathingPatternId`/`breathingDurationMin` — заменить ссылкой на дыхательную конфигурацию (`breathingSequenceId` или встроенный JSON `BreathingSettings`) — см. открытый вопрос №1. Миграция существующих пресетов: `hasBreathing=true` → дефолтная короткая Вим-Хоф конфигурация.

### Метрики и кросс-учёт
- **Журнал дыхания** (`breathing_journal_provider` / `breathing_journal_screen`): показывать бейдж для сессий с `meditation_session_id`. По желанию — фильтр «в составе медитации».
- **Статистика медитации** (`meditation_stats_provider`): включать дыхательную часть (длительность/дыхания/задержки) в итог сессии.
- **Статистика дыхания** (`breathing_stats_provider`): решить, учитывать ли chained-сессии в общих счётчиках (открытый вопрос №3).
- XP/DP: не задваивать. Дыхательная часть либо даёт свой XP как обычная сессия дыхания, либо её длительность включается в XP медитации — но не оба (открытый вопрос №4).

## Затрагиваемые модули
### Изменяемые файлы
| Файл | Изменение |
|------|-----------|
| `apps/central_hub/lib/screens/breathing_exercise_screen.dart` | Режим `chain` + `onChainComplete`, скрытие нав-кнопок, пропуск reflection/recovery |
| `apps/central_hub/lib/screens/meditation_preflight_screen.dart` | Выбор реальной конфигурации дыхания вместо чипов паттернов; запуск цепочки |
| `apps/central_hub/lib/screens/meditation_session_screen.dart` | Убрать встроенную фазу дыхания и `_BreathingCue` |
| `packages/sie_core/lib/src/providers/meditation_session_provider.dart` | Убрать breathing-фазы/паттерны; старт с медитации; принять длительность дыхания для метрик; записать линк `breathing_session_id` |
| `packages/sie_core/lib/src/models/meditation_preset.dart` | Заменить `breathingPatternId`/`breathingDurationMin` на ссылку дыхательной конфигурации |
| `packages/sie_core/lib/src/providers/achievements_provider.dart` (`SessionCompletionNotifier`) | Запись breathing-сессии с `meditationSessionId` (без reflection) |
| `packages/sie_core/lib/src/providers/breathing_journal_provider.dart` / `breathing_journal_screen.dart` | Бейдж «в составе медитации» |
| `packages/sie_core/lib/src/providers/meditation_stats_provider.dart` | Учёт дыхательной части |
| i18n: `meditationPreflight`, `breathingJournal`, `meditationSession` (ru+en) | Новые строки |

### Переиспользуется
- Весь `BreathingExerciseScreen` (сфера, аудио, раунды), `BreathingSettings`/`BreathingSequence`/`BreathingRound`, `SessionCompletionNotifier`.

## Схема данных
- **Drift + Supabase:**
  - `local_breathing_sessions` / `breathing_sessions`: новый nullable `meditation_session_id` (линк на медитацию, в составе которой прошло дыхание).
  - `local_meditation_sessions` / `meditation_sessions`: новый nullable `breathing_session_id` (обратный линк).
  - `meditation_presets`: `breathing_pattern_id`/`breathing_duration_min` → `breathing_config_json` **или** `breathing_sequence_id` (по итогу открытого вопроса №1).
- Миграция Drift (schema vN+1) + миграции Supabase + правки RPC `log_meditation_session` (принимать `p_breathing_session_id`, суммарную длительность). RLS без изменений.

## Открытые вопросы
1. **Конфигурация дыхания в пресете медитации:** ссылка на сохранённую `BreathingSequence` (переиспользуем билдер последовательностей) или встроенный `BreathingSettings`-JSON (проще, но дублирует)? Или дать оба: «выбрать последовательность» / «быстрые параметры»?
2. **Recovery/переход:** полностью пропускать recovery-экран в цепочке или показывать короткий авто-переходный экран (2–3 сек, «Дыхание завершено — переходим к медитации»)? Нужно ли пользователю подтверждать переход или полностью автоматически?
3. **Статистика дыхания:** учитывать ли chained-сессии в общих счётчиках модуля Дыхания (стрик/итоги) или считать их «медитационными» и показывать отдельно?
4. **XP/DP:** дыхательная часть даёт свой XP (как отдельная сессия дыхания) или её длительность вливается в XP медитации? Важно не задваивать награду и античит (`xp-anti-farming.md`).
5. **Пост-практика дыхания (mood/calmness):** спрашивать ли `calmness/mood` в цепочке (сейчас это делает `BreathingReflectionScreen`, который мы пропускаем)? Возможно объединить с `stateBefore` медитации в один короткий опрос.
6. **Обратная совместимость:** что делать с уже сохранёнными пресетами и историей, где дыхание было ведомым паттерном? (миграция дефолтной конфигурацией; старые записи не трогаем.)
7. **Прерывание цепочки:** если пользователь выходит во время дыхания — считать ли это завершённой дыхательной сессией без медитации, или отменять обе?
