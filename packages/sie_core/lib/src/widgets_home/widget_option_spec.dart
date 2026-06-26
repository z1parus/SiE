class WidgetOptionSpec {
  final String id;
  final String label;
  final _OptionType type;
  final dynamic defaultValue;
  final Map<String, String>? choices;
  final num? min;
  final num? max;

  const WidgetOptionSpec._({
    required this.id,
    required this.label,
    required this.type,
    this.defaultValue,
    this.choices,
    this.min,
    this.max,
  });

  const WidgetOptionSpec.toggle(String id, String label,
      {bool defaultValue = false})
      : this._(
            id: id,
            label: label,
            type: _OptionType.toggle,
            defaultValue: defaultValue);

  const WidgetOptionSpec.enumChoice(
      String id, String label, Map<String, String> choices,
      {String? defaultValue})
      : this._(
            id: id,
            label: label,
            type: _OptionType.enumChoice,
            choices: choices,
            defaultValue: defaultValue);

  const WidgetOptionSpec.number(String id, String label,
      {num? min, num? max, num? defaultValue})
      : this._(
            id: id,
            label: label,
            type: _OptionType.number,
            min: min,
            max: max,
            defaultValue: defaultValue);

  bool get isToggle => type == _OptionType.toggle;
  bool get isEnumChoice => type == _OptionType.enumChoice;
  bool get isNumber => type == _OptionType.number;
}

enum _OptionType { toggle, enumChoice, number }
