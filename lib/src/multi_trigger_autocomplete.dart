import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_portal/flutter_portal.dart';
import 'package:multi_trigger_autocomplete/multi_trigger_autocomplete.dart';
import './autocomplete_trigger.dart';

typedef MultiTriggerAutocompleteFieldViewBuilder = Widget Function(
    BuildContext context,
    TextEditingController textEditingController,
    FocusNode focusNode,
    );

/// Positions the [AutocompleteTrigger] options around the [TextField] or
/// [TextFormField] that triggered the autocomplete.
enum OptionsAlignment {
  /// Positions the options to the top of the field.
  top,

  /// Positions the options to the bottom of the field.
  bottom,

  /// Positions the options to the top left of the field.
  topStart,

  /// Positions the options to the top right of the field.
  topEnd,

  /// Positions the options to the bottom left of the field.
  bottomStart,

  /// Positions the options to the bottom right of the field.
  bottomEnd;

  Anchor _toAnchor({double? widthFactor = 1.0}) {
    switch (this) {
      case OptionsAlignment.top:
        return Aligned(
          widthFactor: widthFactor,
          follower: Alignment.bottomCenter,
          target: Alignment.topCenter,
        );
      case OptionsAlignment.bottom:
        return Aligned(
          widthFactor: widthFactor,
          follower: Alignment.topCenter,
          target: Alignment.bottomCenter,
        );
      case OptionsAlignment.topStart:
        return Aligned(
          widthFactor: widthFactor,
          follower: Alignment.bottomLeft,
          target: Alignment.topLeft,
        );
      case OptionsAlignment.topEnd:
        return Aligned(
          widthFactor: widthFactor,
          follower: Alignment.bottomRight,
          target: Alignment.topRight,
        );
      case OptionsAlignment.bottomStart:
        return Aligned(
          widthFactor: widthFactor,
          follower: Alignment.topLeft,
          target: Alignment.bottomLeft,
        );
      case OptionsAlignment.bottomEnd:
        return Aligned(
          widthFactor: widthFactor,
          follower: Alignment.topRight,
          target: Alignment.bottomRight,
        );
    }
  }
}

/// A widget that provides a text field with autocomplete functionality.
class MultiTriggerAutocomplete extends StatefulWidget {

  const MultiTriggerAutocomplete({
    super.key,
    required this.autocompleteTriggers,
    this.fieldViewBuilder = _defaultFieldViewBuilder,
    this.focusNode,
    this.textEditingController,
    this.initialValue,
    this.optionsAlignment = OptionsAlignment.bottom,
    this.optionsWidthFactor = 1.0,
    this.debounceDuration = const Duration(milliseconds: 300),
  })  : assert((focusNode == null) == (textEditingController == null)),
        assert(
        !(textEditingController != null && initialValue != null),
        'textEditingController and initialValue cannot be simultaneously defined.',
        );

  /// The triggers that trigger autocomplete.
  final Iterable<AutocompleteTrigger> autocompleteTriggers;

  /// {@template flutter.widgets.RawAutocomplete.fieldViewBuilder}
  /// Builds the field whose input is used to get the options.
  ///
  /// Pass the provided [TextEditingController] to the field built here so that
  /// RawAutocomplete can listen for changes.
  /// {@endtemplate}
  final MultiTriggerAutocompleteFieldViewBuilder fieldViewBuilder;

  /// The [FocusNode] that is used for the text field.
  ///
  /// {@template flutter.widgets.RawAutocomplete.split}
  /// The main purpose of this parameter is to allow the use of a separate text
  /// field located in another part of the widget tree instead of the text
  /// field built by [fieldViewBuilder]. For example, it may be desirable to
  /// place the text field in the AppBar and the options below in the main body.
  ///
  /// When following this pattern, [fieldViewBuilder] can return
  /// `SizedBox.shrink()` so that nothing is drawn where the text field would
  /// normally be. A separate text field can be created elsewhere, and a
  /// FocusNode and TextEditingController can be passed both to that text field
  /// and to RawAutocomplete.
  ///
  /// {@tool dartpad}
  /// This examples shows how to create an autocomplete widget with the text
  /// field in the AppBar and the results in the main body of the app.
  ///
  /// ** See code in examples/api/lib/widgets/autocomplete/raw_autocomplete.focus_node.0.dart **
  /// {@end-tool}
  /// {@endtemplate}
  ///
  /// If this parameter is not null, then [textEditingController] must also be
  /// not null.
  final FocusNode? focusNode;

  /// The [TextEditingController] that is used for the text field.
  ///
  /// If this parameter is not null, then [focusNode] must also be not null.
  final TextEditingController? textEditingController;

  /// {@template flutter.widgets.RawAutocomplete.initialValue}
  /// The initial value to use for the text field.
  /// {@endtemplate}
  ///
  /// Setting the initial value does not notify [textEditingController]'s
  /// listeners, and thus will not cause the options UI to appear.
  ///
  /// This parameter is ignored if [textEditingController] is defined.
  final TextEditingValue? initialValue;

  /// The alignment of the options.
  ///
  /// The default value is [MultiTriggerAutocompleteAlignment.below].
  final OptionsAlignment optionsAlignment;

  /// The width to make the options as a multiple of the width of the
  /// field.
  ///
  /// The default value is 1.0, which makes the options the same width
  /// as the field.
  final double? optionsWidthFactor;

  /// The duration of the debounce period for the [TextEditingController].
  ///
  /// The default value is [300ms].
  final Duration debounceDuration;

  static Widget _defaultFieldViewBuilder(
      BuildContext context,
      TextEditingController textEditingController,
      FocusNode focusNode,
      ) {
    return _MultiTriggerAutocompleteField(
      focusNode: focusNode,
      textEditingController: textEditingController,
    );
  }

  /// Returns the nearest [StreamAutocomplete] ancestor of the given context.
  static MultiTriggerAutocompleteState of(BuildContext context) {
    final state =
    context.findAncestorStateOfType<MultiTriggerAutocompleteState>();
    assert(state != null, 'MultiTriggerAutocomplete not found');
    return state!;
  }

  @override
  MultiTriggerAutocompleteState createState() =>
      MultiTriggerAutocompleteState();
}

class MultiTriggerAutocompleteState extends State<MultiTriggerAutocomplete> {
  late TextEditingController _textEditingController;
  late FocusNode _focusNode;
  final FocusNode _optionsViewFocusNode = FocusNode();
  late FocusNode _wrapperFocusNode;

  AutocompleteQuery? _currentQuery;
  AutocompleteTrigger? _currentTrigger;

  bool _hideOptions = false;
  String _lastFieldText = '';

  bool get _shouldShowOptions {
    return !_hideOptions &&
        _focusNode.hasFocus &&
        _currentQuery != null &&
        _currentTrigger != null;
  }

  void acceptAutocompleteOption(
      String option, {
        bool keepTrigger = true,
      }) {
    if (option.isEmpty) return;

    final query = _currentQuery;
    final trigger = _currentTrigger;
    if (query == null || trigger == null) return;

    final querySelection = query.selection;
    final text = _textEditingController.text;

    var start = querySelection.baseOffset;
    if (!keepTrigger) start -= 1;

    final end = querySelection.extentOffset;

    final alreadyContainsSpace = text.substring(end).startsWith(' ');

    if (!alreadyContainsSpace) option += ' ';

    var selectionOffset = start + option.length;

    if (alreadyContainsSpace) selectionOffset += 1;

    final newText = text.replaceRange(start, end, option);
    final newSelection = TextSelection.collapsed(offset: selectionOffset);

    _textEditingController.value = TextEditingValue(
      text: newText,
      selection: newSelection,
    );

    return closeOptions();
  }

  void closeOptions() {
    final prevQuery = _currentQuery;
    final prevTrigger = _currentTrigger;
    if (prevQuery == null || prevTrigger == null) return;

    _currentQuery = null;
    _currentTrigger = null;
    if (mounted) setState(() {});
  }

  void showOptions(
      AutocompleteQuery query,
      AutocompleteTrigger trigger,
      ) {
    final prevQuery = _currentQuery;
    final prevTrigger = _currentTrigger;
    if (prevQuery == query && prevTrigger == trigger) return;

    _currentQuery = query;
    _currentTrigger = trigger;
    if (mounted) setState(() {});
  }

  _AutocompleteInvokedTriggerWithQuery? _getInvokedTriggerWithQuery(
      TextEditingValue textEditingValue,
      ) {
    final autocompleteTriggers = widget.autocompleteTriggers.toSet();
    for (final trigger in autocompleteTriggers) {
      final query = trigger.invokingTrigger(textEditingValue);
      if (query != null) {
        return _AutocompleteInvokedTriggerWithQuery(trigger, query);
      }
    }
    return null;
  }

  Timer? _debounceTimer;

  void _onChangedField() {
    if (_debounceTimer?.isActive == true) _debounceTimer?.cancel();
    _debounceTimer = Timer(widget.debounceDuration, () {
      final textEditingValue = _textEditingController.value;

      if (textEditingValue.text == _lastFieldText) return;

      _hideOptions = false;
      _lastFieldText = textEditingValue.text;

      if (textEditingValue.text.isEmpty) return closeOptions();

      final triggerWithQuery = _getInvokedTriggerWithQuery(textEditingValue);

      if (triggerWithQuery == null) return closeOptions();

      final trigger = triggerWithQuery.trigger;
      final query = triggerWithQuery.query;
      return showOptions(query, trigger);
    });
  }

  void _onChangedFocus() {
    _hideOptions = !_focusNode.hasFocus;
    if (mounted) setState(() {});
  }

  void _updateTextEditingController(
      TextEditingController? old, TextEditingController? current) {
    if ((old == null && current == null) || old == current) {
      return;
    }
    if (old == null) {
      _textEditingController.removeListener(_onChangedField);
      _textEditingController.dispose();
      _textEditingController = current!;
    } else if (current == null) {
      _textEditingController.removeListener(_onChangedField);
      _textEditingController = TextEditingController();
    } else {
      _textEditingController.removeListener(_onChangedField);
      _textEditingController = current;
    }
    _textEditingController.addListener(_onChangedField);
  }

  void _updateFocusNode(FocusNode? old, FocusNode? current) {
    if ((old == null && current == null) || old == current) {
      return;
    }
    if (old == null) {
      _focusNode.removeListener(_onChangedFocus);
      _focusNode.dispose();
      _focusNode = current!;
    } else if (current == null) {
      _focusNode.removeListener(_onChangedFocus);
      _focusNode = FocusNode();
    } else {
      _focusNode.removeListener(_onChangedFocus);
      _focusNode = current;
    }
    _focusNode.addListener(_onChangedFocus);
  }

  @override
  void initState() {
    super.initState();
    _textEditingController = widget.textEditingController ??
        TextEditingController.fromValue(widget.initialValue);
    _textEditingController.addListener(_onChangedField);
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_onChangedFocus);
    _wrapperFocusNode = FocusNode(debugLabel: 'MultiTriggerAutocomplete Wrapper');
  }

  @override
  void didUpdateWidget(MultiTriggerAutocomplete oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateTextEditingController(
      oldWidget.textEditingController,
      widget.textEditingController,
    );
    _updateFocusNode(oldWidget.focusNode, widget.focusNode);
  }

  @override
  void dispose() {
    _textEditingController.removeListener(_onChangedField);
    if (widget.textEditingController == null) {
      _textEditingController.dispose();
    }
    _focusNode.removeListener(_onChangedFocus);
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    _optionsViewFocusNode.dispose();
    _wrapperFocusNode.dispose();
    _debounceTimer?.cancel();
    _currentTrigger = null;
    _currentQuery = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) {
        final anchor = widget.optionsAlignment._toAnchor(
          widthFactor: widget.optionsWidthFactor,
        );
        final shouldShowOptions = _shouldShowOptions;

        Widget? portalFollower;
        if (shouldShowOptions && _currentTrigger != null && _currentQuery != null) {
          portalFollower = TextFieldTapRegion(
            child: _currentTrigger!.optionsViewBuilder(
              context,
              _currentQuery!,
              _textEditingController,
              _optionsViewFocusNode, 
            ),
          );
        }

        return PortalTarget(
          anchor: anchor,
          visible: shouldShowOptions,
          portalFollower: portalFollower,
          child: Focus(
            focusNode: _wrapperFocusNode, 
            onKeyEvent: (FocusNode node, KeyEvent event) { 
              if (event is KeyDownEvent) { 
                if (event.logicalKey == LogicalKeyboardKey.escape) {
                  if (_shouldShowOptions) {
                    closeOptions();
                    SemanticsService.announce("Autocomplete suggestions hidden", Directionality.of(context));
                    return KeyEventResult.handled; 
                  }
                } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                  if (_shouldShowOptions && !_optionsViewFocusNode.hasFocus) {
                    _optionsViewFocusNode.requestFocus();
                    SemanticsService.announce("Showing autocomplete suggestions. Use arrow keys to navigate.", Directionality.of(context));
                    return KeyEventResult.handled; 
                  }
                }
              }
              return KeyEventResult.ignored; 
            },
            child: widget.fieldViewBuilder(
              context,
              _textEditingController,
              _focusNode,
            ),
          ),
        );
      },
    );
  }
}

class _AutocompleteInvokedTriggerWithQuery {
  const _AutocompleteInvokedTriggerWithQuery(this.trigger, this.query);

  final AutocompleteTrigger trigger;
  final AutocompleteQuery query;
}

class _MultiTriggerAutocompleteField extends StatelessWidget {
  const _MultiTriggerAutocompleteField({
    required this.focusNode,
    required this.textEditingController,
  });

  final FocusNode focusNode;

  final TextEditingController textEditingController;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: textEditingController,
      focusNode: focusNode,
    );
  }
}
