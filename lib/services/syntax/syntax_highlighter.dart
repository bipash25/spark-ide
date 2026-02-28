import 'package:flutter/material.dart';
import 'package:spark_ide/core/theme/spark_theme.dart';

/// Simple keyword-based syntax highlighter
/// This provides immediate highlighting without requiring TextMate grammars.
/// A full TextMate grammar engine can be added later for richer support.
class SyntaxHighlighter {
  final TokenColors tokenColors;

  const SyntaxHighlighter(this.tokenColors);

  /// Build highlighted text spans for a line of code
  List<TextSpan> highlight(String line, String languageId) {
    final rules = _getRules(languageId);
    if (rules.isEmpty) {
      return [TextSpan(text: line)];
    }

    final spans = <TextSpan>[];
    final matches = <_Match>[];

    // Find all matches for all rules
    for (final rule in rules) {
      for (final match in rule.pattern.allMatches(line)) {
        matches.add(_Match(
          start: match.start,
          end: match.end,
          text: match.group(0)!,
          color: rule.color,
        ));
      }
    }

    // Sort by position, longest match first for overlaps
    matches.sort((a, b) {
      final cmp = a.start.compareTo(b.start);
      return cmp != 0 ? cmp : b.end.compareTo(a.end);
    });

    // Build non-overlapping spans
    int pos = 0;
    for (final match in matches) {
      if (match.start < pos) continue; // Skip overlapping

      // Add plain text before match
      if (match.start > pos) {
        spans.add(TextSpan(text: line.substring(pos, match.start)));
      }

      // Add highlighted text
      spans.add(TextSpan(
        text: match.text,
        style: TextStyle(color: match.color),
      ));

      pos = match.end;
    }

    // Add remaining text
    if (pos < line.length) {
      spans.add(TextSpan(text: line.substring(pos)));
    }

    if (spans.isEmpty) {
      spans.add(TextSpan(text: line));
    }

    return spans;
  }

  /// Build a full TextSpan for entire content
  TextSpan buildTextSpan(String content, String languageId, TextStyle baseStyle) {
    final lines = content.split('\n');
    final spans = <TextSpan>[];

    for (int i = 0; i < lines.length; i++) {
      if (i > 0) spans.add(const TextSpan(text: '\n'));
      spans.addAll(highlight(lines[i], languageId));
    }

    return TextSpan(style: baseStyle, children: spans);
  }

  List<_HighlightRule> _getRules(String languageId) {
    switch (languageId) {
      case 'python':
        return _pythonRules;
      case 'javascript':
      case 'javascriptreact':
        return _jsRules;
      case 'typescript':
      case 'typescriptreact':
        return _tsRules;
      case 'html':
        return _htmlRules;
      case 'css':
      case 'scss':
      case 'sass':
      case 'less':
        return _cssRules;
      case 'c':
      case 'cpp':
        return _cppRules;
      case 'java':
        return _javaRules;
      case 'dart':
        return _dartRules;
      case 'json':
        return _jsonRules;
      case 'sql':
        return _sqlRules;
      case 'go':
        return _goRules;
      case 'rust':
        return _rustRules;
      case 'markdown':
        return _markdownRules;
      case 'yaml':
        return _yamlRules;
      case 'shellscript':
        return _shellRules;
      default:
        return _genericRules;
    }
  }

  // Common patterns
  RegExp get _stringDoubleQuote => RegExp(r'"(?:[^"\\]|\\.)*"');
  RegExp get _stringSingleQuote => RegExp(r"'(?:[^'\\]|\\.)*'");
  RegExp get _templateString => RegExp(r'`(?:[^`\\]|\\.)*`');
  RegExp get _numberLiteral => RegExp(r'\b(?:0x[0-9a-fA-F]+|0b[01]+|0o[0-7]+|\d+\.?\d*(?:[eE][+-]?\d+)?)\b');
  RegExp get _singleLineComment => RegExp(r'//.*$');
  RegExp get _hashComment => RegExp(r'#.*$');

  List<_HighlightRule> get _genericRules => [
    _HighlightRule(_singleLineComment, tokenColors.comment),
    _HighlightRule(_hashComment, tokenColors.comment),
    _HighlightRule(_stringDoubleQuote, tokenColors.string),
    _HighlightRule(_stringSingleQuote, tokenColors.string),
    _HighlightRule(_numberLiteral, tokenColors.number),
  ];

  List<_HighlightRule> get _pythonRules => [
    _HighlightRule(_hashComment, tokenColors.comment),
    _HighlightRule(RegExp(r'"""[\s\S]*?"""|' "'''[\\s\\S]*?'''"), tokenColors.string),
    _HighlightRule(_stringDoubleQuote, tokenColors.string),
    _HighlightRule(_stringSingleQuote, tokenColors.string),
    _HighlightRule(RegExp(r'\bf"[^"]*"'), tokenColors.string),
    _HighlightRule(RegExp(r"\bf'[^']*'"), tokenColors.string),
    _HighlightRule(RegExp(r'\b(?:def|class|return|if|elif|else|for|while|import|from|as|try|except|finally|with|yield|lambda|pass|break|continue|raise|del|global|nonlocal|assert|async|await|in|not|and|or|is)\b'), tokenColors.keyword),
    _HighlightRule(RegExp(r'\b(?:True|False|None)\b'), tokenColors.constant),
    _HighlightRule(RegExp(r'\b(?:int|float|str|bool|list|dict|tuple|set|bytes|type|object)\b'), tokenColors.type),
    _HighlightRule(RegExp(r'\b(?:print|len|range|enumerate|zip|map|filter|sorted|reversed|input|open|super|isinstance|issubclass|hasattr|getattr|setattr|delattr)\b'), tokenColors.builtin),
    _HighlightRule(RegExp(r'@\w+'), tokenColors.decorator),
    _HighlightRule(RegExp(r'(?<=def\s)\w+'), tokenColors.function),
    _HighlightRule(RegExp(r'(?<=class\s)\w+'), tokenColors.className),
    _HighlightRule(_numberLiteral, tokenColors.number),
    _HighlightRule(RegExp(r'self'), tokenColors.parameter),
  ];

  List<_HighlightRule> get _jsRules => [
    _HighlightRule(_singleLineComment, tokenColors.comment),
    _HighlightRule(_templateString, tokenColors.string),
    _HighlightRule(_stringDoubleQuote, tokenColors.string),
    _HighlightRule(_stringSingleQuote, tokenColors.string),
    _HighlightRule(RegExp(r'\b(?:function|return|if|else|for|while|do|switch|case|break|continue|var|let|const|class|extends|new|this|super|import|export|default|from|try|catch|finally|throw|typeof|instanceof|in|of|async|await|yield|delete|void)\b'), tokenColors.keyword),
    _HighlightRule(RegExp(r'\b(?:true|false|null|undefined|NaN|Infinity)\b'), tokenColors.constant),
    _HighlightRule(RegExp(r'\b(?:console|window|document|Math|JSON|Array|Object|String|Number|Boolean|Date|RegExp|Map|Set|Promise|Error)\b'), tokenColors.type),
    _HighlightRule(RegExp(r'=>'), tokenColors.keyword),
    _HighlightRule(RegExp(r'(?<=function\s)\w+'), tokenColors.function),
    _HighlightRule(_numberLiteral, tokenColors.number),
  ];

  List<_HighlightRule> get _tsRules => [
    ..._jsRules,
    _HighlightRule(RegExp(r'\b(?:interface|type|enum|implements|abstract|readonly|private|protected|public|static|override|declare|namespace|module|keyof|infer|extends|never|unknown|any)\b'), tokenColors.keyword),
    _HighlightRule(RegExp(r'(?<=:\s*)\w+'), tokenColors.type),
  ];

  List<_HighlightRule> get _htmlRules => [
    _HighlightRule(RegExp(r'<!--[\s\S]*?-->'), tokenColors.comment),
    _HighlightRule(RegExp(r'</?[a-zA-Z][\w-]*'), tokenColors.tag),
    _HighlightRule(RegExp(r'/?>'), tokenColors.tag),
    _HighlightRule(RegExp(r'\b[\w-]+(?==)'), tokenColors.attribute),
    _HighlightRule(_stringDoubleQuote, tokenColors.string),
    _HighlightRule(_stringSingleQuote, tokenColors.string),
    _HighlightRule(RegExp(r'&\w+;'), tokenColors.constant),
  ];

  List<_HighlightRule> get _cssRules => [
    _HighlightRule(RegExp(r'/\*[\s\S]*?\*/'), tokenColors.comment),
    _HighlightRule(_singleLineComment, tokenColors.comment),
    _HighlightRule(_stringDoubleQuote, tokenColors.string),
    _HighlightRule(_stringSingleQuote, tokenColors.string),
    _HighlightRule(RegExp(r'[.#][\w-]+'), tokenColors.tag),
    _HighlightRule(RegExp(r'[\w-]+(?=\s*:)'), tokenColors.property),
    _HighlightRule(RegExp(r'@\w+'), tokenColors.keyword),
    _HighlightRule(RegExp(r'\b(?:px|em|rem|vh|vw|%|s|ms|deg|fr)\b'), tokenColors.number),
    _HighlightRule(_numberLiteral, tokenColors.number),
    _HighlightRule(RegExp(r'#[0-9a-fA-F]{3,8}\b'), tokenColors.constant),
    _HighlightRule(RegExp(r'\b(?:important|inherit|initial|unset|none|auto|block|inline|flex|grid|absolute|relative|fixed|sticky)\b'), tokenColors.constant),
  ];

  List<_HighlightRule> get _cppRules => [
    _HighlightRule(_singleLineComment, tokenColors.comment),
    _HighlightRule(_stringDoubleQuote, tokenColors.string),
    _HighlightRule(_stringSingleQuote, tokenColors.string),
    _HighlightRule(RegExp(r'#\s*(?:include|define|ifndef|ifdef|endif|if|else|elif|undef|pragma)\b.*$'), tokenColors.macro),
    _HighlightRule(RegExp(r'\b(?:if|else|for|while|do|switch|case|break|continue|return|goto|sizeof|typedef|struct|union|enum|class|public|private|protected|virtual|override|const|static|extern|inline|volatile|register|auto|namespace|using|template|typename|new|delete|try|catch|throw|operator|friend|this)\b'), tokenColors.keyword),
    _HighlightRule(RegExp(r'\b(?:int|float|double|char|void|bool|long|short|unsigned|signed|size_t|string|vector|map|set|list|array|pair|tuple|nullptr_t|auto)\b'), tokenColors.type),
    _HighlightRule(RegExp(r'\b(?:true|false|nullptr|NULL|EOF)\b'), tokenColors.constant),
    _HighlightRule(RegExp(r'\b(?:std|cout|cin|cerr|endl|printf|scanf|malloc|free|sizeof)\b'), tokenColors.builtin),
    _HighlightRule(RegExp(r'<[\w./]+>'), tokenColors.string),
    _HighlightRule(_numberLiteral, tokenColors.number),
  ];

  List<_HighlightRule> get _javaRules => [
    _HighlightRule(_singleLineComment, tokenColors.comment),
    _HighlightRule(_stringDoubleQuote, tokenColors.string),
    _HighlightRule(_stringSingleQuote, tokenColors.string),
    _HighlightRule(RegExp(r'\b(?:if|else|for|while|do|switch|case|break|continue|return|class|interface|extends|implements|abstract|final|static|public|private|protected|new|this|super|try|catch|finally|throw|throws|import|package|instanceof|synchronized|volatile|transient|native|strictfp|default|enum|assert|void)\b'), tokenColors.keyword),
    _HighlightRule(RegExp(r'\b(?:int|float|double|char|boolean|long|short|byte|String|Integer|Float|Double|Boolean|List|Map|Set|Array|Object|Class|System|Scanner|Exception)\b'), tokenColors.type),
    _HighlightRule(RegExp(r'\b(?:true|false|null)\b'), tokenColors.constant),
    _HighlightRule(RegExp(r'@\w+'), tokenColors.decorator),
    _HighlightRule(_numberLiteral, tokenColors.number),
  ];

  List<_HighlightRule> get _dartRules => [
    _HighlightRule(_singleLineComment, tokenColors.comment),
    _HighlightRule(RegExp(r'///.*$'), tokenColors.comment),
    _HighlightRule(_stringDoubleQuote, tokenColors.string),
    _HighlightRule(_stringSingleQuote, tokenColors.string),
    _HighlightRule(RegExp(r"\b(?:if|else|for|while|do|switch|case|break|continue|return|class|extends|implements|abstract|final|const|static|new|this|super|try|catch|finally|throw|rethrow|import|export|library|part|typedef|mixin|with|enum|assert|async|await|yield|sync|late|required|covariant|extension|external|factory|get|set|operator|show|hide|on|is|as|in)\b"), tokenColors.keyword),
    _HighlightRule(RegExp(r'\b(?:int|double|num|String|bool|List|Map|Set|Future|Stream|dynamic|void|var|Object|Function|Type|Null|Never|Iterable|Duration|DateTime|RegExp|Uri)\b'), tokenColors.type),
    _HighlightRule(RegExp(r'\b(?:true|false|null)\b'), tokenColors.constant),
    _HighlightRule(RegExp(r'@\w+'), tokenColors.decorator),
    _HighlightRule(RegExp(r'\$\{[^}]+\}|\$\w+'), tokenColors.variable),
    _HighlightRule(_numberLiteral, tokenColors.number),
  ];

  List<_HighlightRule> get _jsonRules => [
    _HighlightRule(RegExp(r'"[^"]*"(?=\s*:)'), tokenColors.property),
    _HighlightRule(_stringDoubleQuote, tokenColors.string),
    _HighlightRule(RegExp(r'\b(?:true|false|null)\b'), tokenColors.constant),
    _HighlightRule(_numberLiteral, tokenColors.number),
  ];

  List<_HighlightRule> get _sqlRules => [
    _HighlightRule(RegExp(r'--.*$'), tokenColors.comment),
    _HighlightRule(_stringDoubleQuote, tokenColors.string),
    _HighlightRule(_stringSingleQuote, tokenColors.string),
    _HighlightRule(RegExp(r'\b(?:SELECT|FROM|WHERE|INSERT|UPDATE|DELETE|CREATE|DROP|ALTER|TABLE|INTO|VALUES|SET|JOIN|LEFT|RIGHT|INNER|OUTER|ON|AND|OR|NOT|IN|IS|NULL|AS|ORDER|BY|GROUP|HAVING|LIMIT|OFFSET|UNION|ALL|DISTINCT|EXISTS|BETWEEN|LIKE|INDEX|PRIMARY|KEY|FOREIGN|REFERENCES|CONSTRAINT|DEFAULT|CHECK|UNIQUE|VIEW|TRIGGER|PROCEDURE|FUNCTION|BEGIN|END|IF|ELSE|THEN|CASE|WHEN|DECLARE|CURSOR|FETCH|GRANT|REVOKE|COMMIT|ROLLBACK|SAVEPOINT|CASCADE|DATABASE|SCHEMA|USE|SHOW|DESCRIBE|EXPLAIN|COUNT|SUM|AVG|MIN|MAX)\b', caseSensitive: false), tokenColors.keyword),
    _HighlightRule(RegExp(r'\b(?:INT|INTEGER|BIGINT|SMALLINT|TINYINT|FLOAT|DOUBLE|DECIMAL|NUMERIC|CHAR|VARCHAR|TEXT|BLOB|DATE|TIME|DATETIME|TIMESTAMP|BOOLEAN|BOOL|SERIAL|AUTO_INCREMENT)\b', caseSensitive: false), tokenColors.type),
    _HighlightRule(_numberLiteral, tokenColors.number),
  ];

  List<_HighlightRule> get _goRules => [
    _HighlightRule(_singleLineComment, tokenColors.comment),
    _HighlightRule(_stringDoubleQuote, tokenColors.string),
    _HighlightRule(_stringSingleQuote, tokenColors.string),
    _HighlightRule(_templateString, tokenColors.string),
    _HighlightRule(RegExp(r'\b(?:func|return|if|else|for|range|switch|case|break|continue|default|var|const|type|struct|interface|map|chan|go|defer|select|package|import|fallthrough|goto)\b'), tokenColors.keyword),
    _HighlightRule(RegExp(r'\b(?:int|int8|int16|int32|int64|uint|uint8|uint16|uint32|uint64|float32|float64|complex64|complex128|string|bool|byte|rune|error|any)\b'), tokenColors.type),
    _HighlightRule(RegExp(r'\b(?:true|false|nil|iota)\b'), tokenColors.constant),
    _HighlightRule(RegExp(r'\b(?:fmt|os|io|log|net|http|json|strings|strconv|math|time|sync|context|errors)\b'), tokenColors.namespace),
    _HighlightRule(_numberLiteral, tokenColors.number),
  ];

  List<_HighlightRule> get _rustRules => [
    _HighlightRule(_singleLineComment, tokenColors.comment),
    _HighlightRule(_stringDoubleQuote, tokenColors.string),
    _HighlightRule(RegExp(r"\b(?:fn|let|mut|const|static|if|else|for|while|loop|match|return|break|continue|struct|enum|impl|trait|type|use|mod|pub|crate|super|self|Self|as|in|ref|move|async|await|unsafe|extern|where|dyn|macro_rules)\b"), tokenColors.keyword),
    _HighlightRule(RegExp(r'\b(?:i8|i16|i32|i64|i128|isize|u8|u16|u32|u64|u128|usize|f32|f64|bool|char|str|String|Vec|Box|Option|Result|HashMap|HashSet|Rc|Arc|Cell|RefCell)\b'), tokenColors.type),
    _HighlightRule(RegExp(r'\b(?:true|false|None|Some|Ok|Err)\b'), tokenColors.constant),
    _HighlightRule(RegExp(r'\b(?:println|print|eprintln|eprint|format|vec|todo|unimplemented|unreachable|panic|assert|assert_eq|assert_ne|dbg|cfg|derive)\b!?'), tokenColors.macro),
    _HighlightRule(RegExp(r"'[a-z]\w*"), tokenColors.label),
    _HighlightRule(_numberLiteral, tokenColors.number),
  ];

  List<_HighlightRule> get _markdownRules => [
    _HighlightRule(RegExp(r'^#{1,6}\s.*$', multiLine: true), tokenColors.keyword),
    _HighlightRule(RegExp(r'\*\*[^*]+\*\*'), tokenColors.keyword),
    _HighlightRule(RegExp(r'\*[^*]+\*'), tokenColors.variable),
    _HighlightRule(RegExp(r'`[^`]+`'), tokenColors.string),
    _HighlightRule(RegExp(r'```[\s\S]*?```'), tokenColors.string),
    _HighlightRule(RegExp(r'\[([^\]]+)\]\([^)]+\)'), tokenColors.function),
    _HighlightRule(RegExp(r'^[-*+]\s', multiLine: true), tokenColors.punctuation),
    _HighlightRule(RegExp(r'^\d+\.\s', multiLine: true), tokenColors.number),
    _HighlightRule(RegExp(r'^>\s.*$', multiLine: true), tokenColors.comment),
  ];

  List<_HighlightRule> get _yamlRules => [
    _HighlightRule(_hashComment, tokenColors.comment),
    _HighlightRule(RegExp(r'^[\w][\w.-]*(?=\s*:)', multiLine: true), tokenColors.property),
    _HighlightRule(_stringDoubleQuote, tokenColors.string),
    _HighlightRule(_stringSingleQuote, tokenColors.string),
    _HighlightRule(RegExp(r'\b(?:true|false|null|yes|no|on|off)\b', caseSensitive: false), tokenColors.constant),
    _HighlightRule(_numberLiteral, tokenColors.number),
    _HighlightRule(RegExp(r'[|>][-+]?'), tokenColors.operator),
  ];

  List<_HighlightRule> get _shellRules => [
    _HighlightRule(_hashComment, tokenColors.comment),
    _HighlightRule(_stringDoubleQuote, tokenColors.string),
    _HighlightRule(_stringSingleQuote, tokenColors.string),
    _HighlightRule(RegExp(r'\b(?:if|then|else|elif|fi|for|while|do|done|case|esac|in|function|return|local|export|source|alias|unalias|set|unset|shift|exit|trap|eval|exec|readonly)\b'), tokenColors.keyword),
    _HighlightRule(RegExp(r'\b(?:echo|printf|read|cd|ls|pwd|mkdir|rm|cp|mv|cat|grep|find|sed|awk|sort|uniq|wc|head|tail|chmod|chown|kill|ps|top|curl|wget|tar|gzip|ssh|scp|git|docker|npm|pip|python|node|make|gcc|g\+\+)\b'), tokenColors.builtin),
    _HighlightRule(RegExp(r'\$\{?\w+\}?'), tokenColors.variable),
    _HighlightRule(RegExp(r'\$\([^)]+\)'), tokenColors.variable),
    _HighlightRule(_numberLiteral, tokenColors.number),
  ];
}

class _HighlightRule {
  final RegExp pattern;
  final Color color;

  const _HighlightRule(this.pattern, this.color);
}

class _Match {
  final int start;
  final int end;
  final String text;
  final Color color;

  const _Match({
    required this.start,
    required this.end,
    required this.text,
    required this.color,
  });
}
