import 'module_widget_provider.dart';

class WidgetRegistry {
  WidgetRegistry._();
  static final WidgetRegistry instance = WidgetRegistry._();

  final _providers = <String, ModuleWidgetProvider>{};

  WidgetRegistry register(ModuleWidgetProvider provider) {
    _providers[provider.moduleId] = provider;
    return this;
  }

  ModuleWidgetProvider? get(String moduleId) => _providers[moduleId];
  Iterable<ModuleWidgetProvider> get all => _providers.values;
  bool get isEmpty => _providers.isEmpty;
}
