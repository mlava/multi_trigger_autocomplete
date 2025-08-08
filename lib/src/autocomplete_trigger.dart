import 'package:flutter/material.dart';
import 'package:multi_trigger_autocomplete/src/autocomplete_query.dart';
import 'package:multi_trigger_autocomplete/src/multi_trigger_autocomplete.dart';

/// The type of the [AutocompleteTrigger] callback which returns a [Widget] that
/// displays the specified [options].
typedef AutocompleteTriggerOptionsViewBuilder = Widget Function(
    BuildContext context,
    AutocompleteQuery autocompleteQuery,
    TextEditingController textEditingController,
    FocusNode optionsFocusNode,
    MultiTriggerAutocompleteState autocompleteState,
    );

class AutocompleteTrigger {
  /// Creates a [AutocompleteTrigger] which can be used to trigger
  /// autocomplete suggestions.
  const AutocompleteTrigger({
    required this.trigger,
    required this.optionsViewBuilder,
    this.triggerOnlyAtStart = false,
    this.triggerOnlyAfterSpace = true,
    this.minimumRequiredCharacters = 0,
  });

  /// The trigger character.
  ///
  /// eg. '@', '#', ':'
  final String trigger;

  /// Whether the [trigger] should only be recognised at the start of the input.
  final bool triggerOnlyAtStart;

  /// Whether the [trigger] should only be recognised after a space.
  final bool triggerOnlyAfterSpace;

  /// The minimum required characters for the [trigger] to start recognising
  /// a autocomplete options.
  final int minimumRequiredCharacters;

  /// Builds the selectable options widgets from a list of options objects.
  ///
  /// The options are displayed floating above or below the field using a
  /// [PortalTarget] inside of an [Portal].
  final AutocompleteTriggerOptionsViewBuilder optionsViewBuilder;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AutocompleteTrigger &&
          runtimeType == other.runtimeType &&
          trigger == other.trigger &&
          triggerOnlyAtStart == other.triggerOnlyAtStart &&
          triggerOnlyAfterSpace == other.triggerOnlyAfterSpace &&
          minimumRequiredCharacters == other.minimumRequiredCharacters;

  @override
  int get hashCode =>
      trigger.hashCode ^
      triggerOnlyAtStart.hashCode ^
      triggerOnlyAfterSpace.hashCode ^
      minimumRequiredCharacters.hashCode;

  /// Checks if the user is invoking the recognising [trigger] and returns
  /// the autocomplete query if so.
  AutocompleteQuery? invokingTrigger(TextEditingValue textEditingValue) {
    final text = textEditingValue.text;
    final selection = textEditingValue.selection;

    if (!selection.isValid) return null;
    final cursorPosition = selection.baseOffset;

    final firstTriggerIndexBeforeCursor =
        text.substring(0, cursorPosition).lastIndexOf(trigger);

    if (firstTriggerIndexBeforeCursor == -1) return null;

    if (triggerOnlyAtStart && firstTriggerIndexBeforeCursor != 0) {
      return null;
    }

    final textBeforeTrigger = text.substring(0, firstTriggerIndexBeforeCursor);
    if (triggerOnlyAfterSpace &&
        textBeforeTrigger.isNotEmpty &&
        !(textBeforeTrigger.endsWith(' ') ||
            textBeforeTrigger.endsWith('\n'))) {
      return null;
    }

    final suggestionStart = firstTriggerIndexBeforeCursor + trigger.length;
    final suggestionEnd = cursorPosition;
    if (suggestionStart > suggestionEnd) return null;

    final suggestionText = text.substring(suggestionStart, suggestionEnd);
    if (suggestionText.contains(' ')) return null;

    if (suggestionText.length < minimumRequiredCharacters) return null;

    return AutocompleteQuery(
      query: suggestionText,
      selection: TextSelection(
        baseOffset: suggestionStart,
        extentOffset: suggestionEnd,
      ),
    );
  }
}
