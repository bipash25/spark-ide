import 'package:flutter/material.dart';
import 'package:spark_ide/services/syntax/syntax_highlighter.dart';

/// A TextEditingController that applies syntax highlighting via buildTextSpan.
/// This is the standard Flutter approach - override buildTextSpan to return
/// colored spans while keeping the underlying text editable.
class HighlightedTextController extends TextEditingController {
  SyntaxHighlighter? highlighter;
  String languageId;

  /// Positions of matching brackets to highlight (pair of offsets).
  /// Set by the editor when cursor is near a bracket.
  int? bracketA;
  int? bracketB;
  Color? bracketHighlightColor;

  HighlightedTextController({
    super.text,
    this.highlighter,
    this.languageId = 'plaintext',
  });

  void updateHighlighter(SyntaxHighlighter newHighlighter, String newLanguageId) {
    highlighter = newHighlighter;
    languageId = newLanguageId;
  }

  void updateBracketMatch(int? a, int? b, Color? color) {
    bracketA = a;
    bracketB = b;
    bracketHighlightColor = color;
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    if (highlighter == null || text.isEmpty) {
      return TextSpan(text: text, style: style);
    }

    try {
      final baseSpan = highlighter!.buildTextSpan(text, languageId, style ?? const TextStyle());

      // If we have matching brackets, inject highlights
      if (bracketA != null && bracketB != null && bracketHighlightColor != null) {
        return _injectBracketHighlights(baseSpan);
      }

      return baseSpan;
    } catch (_) {
      // Fallback to plain text if highlighting fails
      return TextSpan(text: text, style: style);
    }
  }

  /// Post-process the syntax-highlighted TextSpan to add bracket highlighting.
  TextSpan _injectBracketHighlights(TextSpan root) {
    final highlightPositions = <int>{};
    if (bracketA != null) highlightPositions.add(bracketA!);
    if (bracketB != null) highlightPositions.add(bracketB!);

    if (highlightPositions.isEmpty) return root;

    final children = root.children;
    if (children == null || children.isEmpty) {
      // Single text span — split it to highlight bracket chars
      return TextSpan(
        style: root.style,
        children: _splitSpanForHighlights(root.text ?? '', 0, root.style, highlightPositions),
      );
    }

    // Walk through children spans, splitting as needed
    final newChildren = <InlineSpan>[];
    int offset = 0;

    for (final child in children) {
      if (child is TextSpan) {
        final spanText = child.text ?? '';
        final spanEnd = offset + spanText.length;

        // Check if any highlight position falls within this span
        bool hasHighlight = false;
        for (final pos in highlightPositions) {
          if (pos >= offset && pos < spanEnd) {
            hasHighlight = true;
            break;
          }
        }

        if (hasHighlight) {
          newChildren.addAll(
            _splitSpanForHighlights(spanText, offset, child.style, highlightPositions),
          );
        } else {
          newChildren.add(child);
        }

        offset = spanEnd;
      } else {
        newChildren.add(child);
      }
    }

    return TextSpan(style: root.style, children: newChildren);
  }

  List<TextSpan> _splitSpanForHighlights(
    String spanText,
    int globalOffset,
    TextStyle? spanStyle,
    Set<int> highlightPositions,
  ) {
    final result = <TextSpan>[];
    int localPos = 0;

    for (int i = 0; i < spanText.length; i++) {
      final globalPos = globalOffset + i;
      if (highlightPositions.contains(globalPos)) {
        // Add text before this highlight
        if (i > localPos) {
          result.add(TextSpan(text: spanText.substring(localPos, i), style: spanStyle));
        }
        // Add highlighted bracket
        result.add(TextSpan(
          text: spanText[i],
          style: (spanStyle ?? const TextStyle()).copyWith(
            backgroundColor: bracketHighlightColor,
            fontWeight: FontWeight.bold,
          ),
        ));
        localPos = i + 1;
      }
    }

    // Add remaining text
    if (localPos < spanText.length) {
      result.add(TextSpan(text: spanText.substring(localPos), style: spanStyle));
    }

    return result;
  }
}
