import 'package:flutter/services.dart';

/// TextInputFormatter that handles:
/// - Auto-closing brackets and quotes: ( [ { " ' `
/// - Skipping over closing brackets/quotes when typed
/// - Auto-deleting matching bracket/quote pair on backspace
/// - Auto-indentation on Enter (maintains indent, extra indent after {)
class AutoEditFormatter extends TextInputFormatter {
  final bool autoCloseBrackets;
  final int tabSize;
  final bool insertSpaces;

  static const _bracketPairs = {
    '(': ')',
    '[': ']',
    '{': '}',
  };

  static const _quotePairs = {
    '"': '"',
    "'": "'",
    '`': '`',
  };

  static const _allPairs = {
    '(': ')',
    '[': ']',
    '{': '}',
    '"': '"',
    "'": "'",
    '`': '`',
  };

  static const _closingBrackets = {')', ']', '}'};

  AutoEditFormatter({
    this.autoCloseBrackets = true,
    this.tabSize = 4,
    this.insertSpaces = true,
  });

  String get _indent => insertSpaces ? ' ' * tabSize : '\t';

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final oldText = oldValue.text;
    final newText = newValue.text;
    final diff = newText.length - oldText.length;

    // Single character inserted
    if (diff == 1 && newValue.selection.isCollapsed) {
      final cursorPos = newValue.selection.baseOffset;
      if (cursorPos < 1) return newValue;

      final insertedChar = newText[cursorPos - 1];

      // Auto-indent on Enter
      if (insertedChar == '\n') {
        return _handleNewline(oldValue, newValue) ?? newValue;
      }

      if (!autoCloseBrackets) return newValue;

      // Skip over closing bracket/quote
      final skipResult = _handleSkipOver(oldValue, insertedChar);
      if (skipResult != null) return skipResult;

      // Auto-close bracket
      if (_bracketPairs.containsKey(insertedChar)) {
        return _autoClose(newValue, _bracketPairs[insertedChar]!);
      }

      // Auto-close quote (only if not preceded by a word character)
      if (_quotePairs.containsKey(insertedChar)) {
        final charBeforeInsert = cursorPos >= 2 ? newText[cursorPos - 2] : '';
        if (!_isWordChar(charBeforeInsert)) {
          return _autoClose(newValue, _quotePairs[insertedChar]!);
        }
      }
    }

    // Single character deleted (backspace) — auto-delete matching pair
    if (diff == -1 && autoCloseBrackets && newValue.selection.isCollapsed) {
      final result = _handleAutoDelete(oldValue, newValue);
      if (result != null) return result;
    }

    return newValue;
  }

  /// Handle auto-indentation when Enter is pressed.
  TextEditingValue? _handleNewline(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final oldText = oldValue.text;
    final newText = newValue.text;
    final cursorPos = newValue.selection.baseOffset;
    final cursorInOld = oldValue.selection.baseOffset;

    // Find the current line's indentation in old text
    final lineStart = _findLineStart(oldText, cursorInOld);
    final lineText = oldText.substring(lineStart, cursorInOld);
    final currentIndent = _getLeadingWhitespace(lineText);

    // Character before cursor in old text
    final charBefore =
        cursorInOld > 0 ? oldText[cursorInOld - 1] : '';
    // Character after cursor in old text
    final charAfter =
        cursorInOld < oldText.length ? oldText[cursorInOld] : '';

    // Opening + closing bracket pair around cursor → split onto lines
    if ((charBefore == '{' && charAfter == '}') ||
        (charBefore == '(' && charAfter == ')') ||
        (charBefore == '[' && charAfter == ']')) {
      final extraIndent = currentIndent + _indent;
      final insertText = '$extraIndent\n$currentIndent';
      final before = newText.substring(0, cursorPos);
      final after = newText.substring(cursorPos);
      return TextEditingValue(
        text: '$before$insertText$after',
        selection: TextSelection.collapsed(
          offset: cursorPos + extraIndent.length,
        ),
      );
    }

    // After opening bracket → extra indent
    if (charBefore == '{' || charBefore == '(' || charBefore == '[') {
      final extraIndent = currentIndent + _indent;
      final before = newText.substring(0, cursorPos);
      final after = newText.substring(cursorPos);
      return TextEditingValue(
        text: '$before$extraIndent$after',
        selection: TextSelection.collapsed(
          offset: cursorPos + extraIndent.length,
        ),
      );
    }

    // Maintain current indentation
    if (currentIndent.isNotEmpty) {
      final before = newText.substring(0, cursorPos);
      final after = newText.substring(cursorPos);
      return TextEditingValue(
        text: '$before$currentIndent$after',
        selection: TextSelection.collapsed(
          offset: cursorPos + currentIndent.length,
        ),
      );
    }

    return null;
  }

  /// Skip over a closing bracket/quote instead of inserting a duplicate.
  TextEditingValue? _handleSkipOver(
    TextEditingValue oldValue,
    String insertedChar,
  ) {
    final oldText = oldValue.text;
    final cursorInOld = oldValue.selection.baseOffset;

    if (cursorInOld >= oldText.length) return null;
    if (oldText[cursorInOld] != insertedChar) return null;

    // Skip for closing brackets
    if (_closingBrackets.contains(insertedChar)) {
      return TextEditingValue(
        text: oldText,
        selection: TextSelection.collapsed(offset: cursorInOld + 1),
      );
    }

    // Skip for closing quotes
    if (_quotePairs.containsKey(insertedChar)) {
      return TextEditingValue(
        text: oldText,
        selection: TextSelection.collapsed(offset: cursorInOld + 1),
      );
    }

    return null;
  }

  /// Insert the closing character after the cursor.
  TextEditingValue _autoClose(TextEditingValue value, String closing) {
    final text = value.text;
    final cursorPos = value.selection.baseOffset;
    final newText =
        text.substring(0, cursorPos) + closing + text.substring(cursorPos);
    return TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: cursorPos),
    );
  }

  /// When backspace deletes an opening bracket/quote, also delete the matching
  /// closing one if it is immediately adjacent.
  TextEditingValue? _handleAutoDelete(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final oldText = oldValue.text;
    final cursorInOld = oldValue.selection.baseOffset;

    if (cursorInOld < 1 || cursorInOld > oldText.length) return null;

    final deletedChar = oldText[cursorInOld - 1];
    if (!_allPairs.containsKey(deletedChar)) return null;

    final expectedClosing = _allPairs[deletedChar]!;

    if (cursorInOld < oldText.length &&
        oldText[cursorInOld] == expectedClosing) {
      // Delete both the opening and closing characters
      final newText = oldText.substring(0, cursorInOld - 1) +
          oldText.substring(cursorInOld + 1);
      return TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: cursorInOld - 1),
      );
    }

    return null;
  }

  bool _isWordChar(String ch) {
    if (ch.isEmpty) return false;
    final code = ch.codeUnitAt(0);
    return (code >= 48 && code <= 57) || // 0-9
        (code >= 65 && code <= 90) || // A-Z
        (code >= 97 && code <= 122) || // a-z
        code == 95; // _
  }

  int _findLineStart(String text, int offset) {
    if (offset <= 0) return 0;
    final clampedOffset = offset.clamp(0, text.length);
    final lastNewline = text.lastIndexOf('\n', clampedOffset - 1);
    return lastNewline == -1 ? 0 : lastNewline + 1;
  }

  String _getLeadingWhitespace(String line) {
    final buffer = StringBuffer();
    for (int i = 0; i < line.length; i++) {
      if (line[i] == ' ' || line[i] == '\t') {
        buffer.write(line[i]);
      } else {
        break;
      }
    }
    return buffer.toString();
  }
}
