import 'dart:async';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_portal/flutter_portal.dart';
import 'package:multi_trigger_autocomplete/multi_trigger_autocomplete.dart';

/// The type of the Autocomplete callback which returns the widget that
/// contains the input [TextField] or [TextFormField].
///
/// See also:
///
///   * [RawAutocomplete.fieldViewBuilder], which is of this type.
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
  /// Create an instance of StreamAutocomplete.
  ///
  /// [displayStringForOption], [optionsBuilder] and [optionsViewBuilder] must
  /// not be null.
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
  late final FocusNode _wrapperFocusNode;
  late final FocusNode _optionsViewFocusNode;
  late VoidCallback _fieldNodeFocusListener;
  FocusOnKeyEventCallback? _originalExternalFocusNodeOnKeyEvent;

  AutocompleteQuery? _currentQuery;
  AutocompleteTrigger? _currentTrigger;

  bool _hideOptions = false;
  String _lastFieldText = '';

  bool get _shouldShowOptions {
    return !_hideOptions &&
        (_focusNode.hasFocus || _optionsViewFocusNode.hasFocus) &&
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

    closeOptions();
  }

  void closeOptions() {
    final prevQuery = _currentQuery;
    if (prevQuery == null /*|| prevTrigger == null*/) return; // Already closed if no query

    _currentQuery = null;
    _currentTrigger = null;
    if (mounted) {
      setState(() {});
    }
    _focusNode.requestFocus();
  }

  void showOptions(
      AutocompleteQuery query,
      AutocompleteTrigger trigger,
      ) {
    final prevQuery = _currentQuery;

    bool werePreviouslyHiddenOrDifferent = _currentQuery == null || _currentQuery != query || _currentTrigger != trigger;

    _currentQuery = query;
    _currentTrigger = trigger;
    _hideOptions = false;

    if (mounted) {
      setState(() {});
    }
    if (werePreviouslyHiddenOrDifferent && _shouldShowOptions && !_optionsViewFocusNode.hasFocus) {
      SemanticsService.announce("Autocomplete suggestions available. Press Arrow Down to navigate.", Directionality.of(context));
    }
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
      if (!mounted) return;
      final textEditingValue = _textEditingController.value;

      if (textEditingValue.text == _lastFieldText && _currentQuery != null) return; // No change and options already potentially visible

      _hideOptions = false;
      _lastFieldText = textEditingValue.text;

      if (textEditingValue.text.isEmpty) {
        if (_currentQuery != null) closeOptions(); // Close if options were visible
        return;
      }

      final triggerWithQuery = _getInvokedTriggerWithQuery(textEditingValue);

      if (triggerWithQuery == null) {
        if (_currentQuery != null) closeOptions(); // Close if options were visible for a previous trigger
        return;
      }

      final trigger = triggerWithQuery.trigger;
      final query = triggerWithQuery.query;
      showOptions(query, trigger);
    });
  }

  void _onChangedFocus() {
    if (!mounted) return;
    debugPrint("MultiTriggerAutocompleteState: _onChangedFocus (for _focusNode), _focusNode.hasFocus: ${_focusNode.hasFocus}");

    if (!_focusNode.hasFocus && !_optionsViewFocusNode.hasFocus) {
      _hideOptions = true;
      if (_currentQuery != null) {
        closeOptions();
      } else if (mounted) {
        setState(() {});
      }
    } else if (_focusNode.hasFocus) {
      _hideOptions = false;
      final textEditingValue = _textEditingController.value;
      if(textEditingValue.text.isNotEmpty) {
        final triggerWithQuery = _getInvokedTriggerWithQuery(textEditingValue);
        if (triggerWithQuery != null) {
          showOptions(triggerWithQuery.query, triggerWithQuery.trigger);
        } else {
          if (_currentQuery != null) closeOptions();
        }
      } else {
        if (_currentQuery != null) closeOptions();
      }
    }
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
      _textEditingController = TextEditingController.fromValue(_textEditingController.value); // Create new internal from old's value
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
      _focusNode = FocusNode(debugLabel: 'AutocompleteTextField-Internal');
    } else {
      _focusNode.removeListener(_onChangedFocus);
      _focusNode = current;
    }
    _focusNode.addListener(_onChangedFocus);
    _focusNode.addListener(() {
      if(mounted) {
        debugPrint("Text field focus node (_focusNode) hasFocus: ${_focusNode.hasFocus}");
      }
    });
  }

  @override
  void initState() {
    super.initState();

    _fieldNodeFocusListener = () {
      if (mounted) {
        debugPrint("Text field focus node (_focusNode) hasFocus: ${_focusNode.hasFocus}");
      }
    };

    _textEditingController = widget.textEditingController ??
        TextEditingController.fromValue(widget.initialValue ?? TextEditingValue.empty);
    _textEditingController.addListener(_onChangedField);

    if (widget.focusNode == null) {
      // Internal FocusNode
      _focusNode = FocusNode(debugLabel: 'AutocompleteTextField-Internal');
      _focusNode.onKeyEvent = _handleTextFieldFocusKeyEvent;
    } else {
      // External FocusNode
      _focusNode = widget.focusNode!;
      _originalExternalFocusNodeOnKeyEvent = _focusNode.onKeyEvent;
      _focusNode.onKeyEvent = (node, event) {
        final ourResult = _handleTextFieldFocusKeyEvent(node, event);
        if (ourResult == KeyEventResult.handled) {
          return KeyEventResult.handled;
        }
        // If our handler ignored it, call the original external handler, if any
        return _originalExternalFocusNodeOnKeyEvent?.call(node, event) ?? KeyEventResult.ignored;
      };
    }
    _focusNode.addListener(_onChangedFocus);
    _focusNode.addListener(_fieldNodeFocusListener);

    _wrapperFocusNode = FocusNode(debugLabel: 'MultiTriggerAutocomplete-Wrapper');
    _optionsViewFocusNode = FocusNode(debugLabel: 'MultiTriggerAutocomplete-OptionsView');

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _textEditingController.text.isNotEmpty) {
        final triggerWithQuery = _getInvokedTriggerWithQuery(_textEditingController.value);
        if (triggerWithQuery != null) {
          showOptions(triggerWithQuery.query, triggerWithQuery.trigger);
        }
      }
    });
  }

  // In /Users/mlavercombe/.pub-cache/git/multi_trigger_autocomplete-97eac80579d32437450d4ca7a950a76334fbabee/lib/src/multi_trigger_autocomplete.dart
// Inside the MultiTriggerAutocompleteState class:

  @override
  void didUpdateWidget(MultiTriggerAutocomplete oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Update TextEditingController
    _updateTextEditingController(
      oldWidget.textEditingController,
      widget.textEditingController,
    );

    // Update FocusNode and its onKeyEvent handler
    if (oldWidget.focusNode != widget.focusNode) {
      // --- Clean up the old _focusNode ---
      _focusNode.removeListener(_onChangedFocus);
      _focusNode.removeListener(_fieldNodeFocusListener); // Assuming _fieldNodeFocusListener is still relevant

      if (oldWidget.focusNode == null) {
        // The old _focusNode was internal
        _focusNode.onKeyEvent = null; // Clear our handler
        _focusNode.dispose();         // Dispose it
      } else {
        // The old _focusNode was external, restore its original onKeyEvent
        // This assumes _focusNode at this point refers to oldWidget.focusNode
        oldWidget.focusNode!.onKeyEvent = _originalExternalFocusNodeOnKeyEvent;
      }

      // --- Set up the new _focusNode ---
      if (widget.focusNode == null) {
        // New _focusNode is internal
        _focusNode = FocusNode(debugLabel: 'AutocompleteTextField-Internal-Updated');
        _focusNode.onKeyEvent = _handleTextFieldFocusKeyEvent;
        _originalExternalFocusNodeOnKeyEvent = null; // No original for internal nodes
      } else {
        // New _focusNode is external
        _focusNode = widget.focusNode!;
        _originalExternalFocusNodeOnKeyEvent = _focusNode.onKeyEvent; // Store new original
        _focusNode.onKeyEvent = (node, event) {
          final ourResult = _handleTextFieldFocusKeyEvent(node, event);
          if (ourResult == KeyEventResult.handled) {
            return KeyEventResult.handled;
          }
          // If our handler ignored it, call the original external handler, if any
          return _originalExternalFocusNodeOnKeyEvent?.call(node, event) ?? KeyEventResult.ignored;
        };
      }
      _focusNode.addListener(_onChangedFocus);
      _focusNode.addListener(_fieldNodeFocusListener); // Assuming _fieldNodeFocusListener is still relevant
    }

    // Handle initialValue changes when textEditingController is not externally provided
    if (widget.initialValue != oldWidget.initialValue && widget.textEditingController == null) {
      _textEditingController.value = widget.initialValue ?? TextEditingValue.empty;

      // This logic seems to re-evaluate options based on the new initialValue.
      // It might be correct, or might need adjustment depending on desired behavior.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _textEditingController.text.isNotEmpty) {
          final triggerWithQuery = _getInvokedTriggerWithQuery(_textEditingController.value);
          if (triggerWithQuery != null) {
            showOptions(triggerWithQuery.query, triggerWithQuery.trigger);
          } else {
            if (_currentQuery != null) closeOptions();
          }
        } else if (mounted && _textEditingController.text.isEmpty && _currentQuery != null) {
          closeOptions();
        }
      });
    }
  }

  @override
  void dispose() {
    _textEditingController.removeListener(_onChangedField);
    if (widget.textEditingController == null) {
      _textEditingController.dispose();
    }
    _focusNode.removeListener(_onChangedFocus);
    _focusNode.removeListener(_fieldNodeFocusListener);
    if (widget.focusNode == null) {
      _focusNode.onKeyEvent = null;
      _focusNode.dispose();
    } else {
      _focusNode.onKeyEvent = _originalExternalFocusNodeOnKeyEvent;
    }
    _debounceTimer?.cancel();_wrapperFocusNode.dispose();
    _optionsViewFocusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleWrapperFocusKeyEvents(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    if (_shouldShowOptions) {
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        debugPrint("MultiTriggerAutocompleteState: Escape detected on _wrapperFocusNode. Closing options.");
        closeOptions();
        SemanticsService.announce("Autocomplete suggestions hidden.", Directionality.of(context));
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        debugPrint("MultiTriggerAutocompleteState: ArrowDown on _wrapperFocusNode. Trying to move to options...");
        if (_focusNode.hasFocus) {
          _focusNode.unfocus(disposition: UnfocusDisposition.scope);
        }
        _optionsViewFocusNode.requestFocus();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    } else {
      debugPrint("MultiTriggerAutocompleteState: Key event on _wrapperFocusNode while _shouldShowOptions is false. ""_focusNode.hasFocus: ${_focusNode.hasFocus}. Event: ${event.logicalKey}. ""This wrapper is ignoring the event to allow default child handling.");
      return KeyEventResult.ignored;
    }
  }

  KeyEventResult _handleTextFieldFocusKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.space) {
      if (!node.hasPrimaryFocus) {
        // The TextFormField's FocusNode (node, which is _focusNode) is active
        // but NOT the primary focused widget in the application.
        // This implies another widget (e.g., a toolbar button in fieldViewBuilder) has primary focus.
        // By returning "handled", we prevent the TextFormField from processing this Enter/Space
        // for text input, allowing the event to be received by the widget that *does* have primary focus.
        debugPrint("MTAState._handleTextFieldFocusKeyEvent: Enter/Space on non-primary _focusNode ('${node.debugLabel}'). HANDLED (to prevent text field processing).");
        return KeyEventResult.handled;
      }
    }
    // If _focusNode has primary focus, or it's any other key,
    // let the TextFormField process it normally by "ignoring" the event at this FocusNode level.
    debugPrint("MTAState._handleTextFieldFocusKeyEvent: Other key or _focusNode ('${node.debugLabel}') is primary. IGNORING (letting TextField process).");
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final bool shouldActuallyShowOptionsInPortal = _shouldShowOptions;

    return PopScope(
      canPop: !shouldActuallyShowOptionsInPortal,
        onPopInvoked: (bool didPop) {
        if (didPop) {
          return;
        }
        if (shouldActuallyShowOptionsInPortal) {
          debugPrint("PopScope: Pop prevented by autocomplete options. Closing options.");
          closeOptions();
        }
      },
      child:  PortalTarget(
        anchor: widget.optionsAlignment._toAnchor(
          widthFactor: widget.optionsWidthFactor,
        ),
        visible: shouldActuallyShowOptionsInPortal,
        portalFollower: shouldActuallyShowOptionsInPortal && _currentTrigger != null && _currentQuery != null
            ? TextFieldTapRegion(
          child: _currentTrigger!.optionsViewBuilder(
            context,
            _currentQuery!,
            _textEditingController,
            _optionsViewFocusNode,
            this,
          ),
        )
            : null,
        child: Focus(
          focusNode: _wrapperFocusNode,
          onKeyEvent: _handleWrapperFocusKeyEvents,
          child: widget.fieldViewBuilder(
            context,
            _textEditingController,
            _focusNode,
          ),
        ),
      )
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
    Key? key,
    required this.focusNode,
    required this.textEditingController,
  }) : super(key: key);

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
