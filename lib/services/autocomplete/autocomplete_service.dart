/// Word-based auto-complete service.
///
/// Extracts identifier-like words from the current document and combines them
/// with language keywords to produce completion suggestions.
class AutoCompleteService {
  /// Minimum prefix length before showing suggestions
  static const int minPrefixLength = 2;

  /// Maximum number of suggestions to show
  static const int maxSuggestions = 12;

  /// Extract the word being typed at the cursor position.
  /// Returns null if the cursor is not at the end of a word.
  static String? getCurrentPrefix(String text, int cursorOffset) {
    if (cursorOffset <= 0 || cursorOffset > text.length) return null;

    // Walk backwards from cursor to find word start
    int start = cursorOffset;
    while (start > 0) {
      final ch = text[start - 1];
      if (_isIdentChar(ch)) {
        start--;
      } else {
        break;
      }
    }

    if (start == cursorOffset) return null;

    final prefix = text.substring(start, cursorOffset);
    if (prefix.length < minPrefixLength) return null;

    return prefix;
  }

  /// Get the start offset of the current prefix word
  static int getPrefixStart(String text, int cursorOffset) {
    int start = cursorOffset;
    while (start > 0 && _isIdentChar(text[start - 1])) {
      start--;
    }
    return start;
  }

  /// Build a list of completion suggestions for [prefix] from document words
  /// and language keywords.
  static List<CompletionItem> getSuggestions({
    required String text,
    required String prefix,
    required String languageId,
    required int cursorOffset,
  }) {
    final lowerPrefix = prefix.toLowerCase();
    final seen = <String>{};
    final results = <CompletionItem>[];

    // 1. Language keywords (higher priority)
    final keywords = _getKeywords(languageId);
    for (final kw in keywords) {
      if (kw.toLowerCase().startsWith(lowerPrefix) && kw != prefix) {
        if (seen.add(kw)) {
          results.add(CompletionItem(
            label: kw,
            kind: CompletionKind.keyword,
          ));
        }
      }
    }

    // 2. Words from the document
    final words = _extractWords(text);
    for (final word in words) {
      if (word.toLowerCase().startsWith(lowerPrefix) && word != prefix) {
        if (seen.add(word)) {
          results.add(CompletionItem(
            label: word,
            kind: CompletionKind.word,
          ));
        }
      }
    }

    // Sort: keywords first, then alphabetically
    results.sort((a, b) {
      if (a.kind != b.kind) {
        return a.kind == CompletionKind.keyword ? -1 : 1;
      }
      return a.label.toLowerCase().compareTo(b.label.toLowerCase());
    });

    if (results.length > maxSuggestions) {
      return results.sublist(0, maxSuggestions);
    }
    return results;
  }

  /// Extract unique identifier-like words from text
  static Set<String> _extractWords(String text) {
    final wordPattern = RegExp(r'[a-zA-Z_]\w{1,}');
    final matches = wordPattern.allMatches(text);
    return matches.map((m) => m.group(0)!).toSet();
  }

  static bool _isIdentChar(String ch) {
    final c = ch.codeUnitAt(0);
    return (c >= 65 && c <= 90) ||  // A-Z
        (c >= 97 && c <= 122) ||    // a-z
        (c >= 48 && c <= 57) ||     // 0-9
        c == 95;                     // _
  }

  /// Get language keywords for completion
  static List<String> _getKeywords(String languageId) {
    switch (languageId) {
      case 'python':
        return _pythonKeywords;
      case 'javascript':
      case 'javascriptreact':
        return _jsKeywords;
      case 'typescript':
      case 'typescriptreact':
        return _tsKeywords;
      case 'html':
        return _htmlKeywords;
      case 'css':
      case 'scss':
      case 'sass':
      case 'less':
        return _cssKeywords;
      case 'c':
      case 'cpp':
        return _cppKeywords;
      case 'java':
        return _javaKeywords;
      case 'dart':
        return _dartKeywords;
      case 'sql':
        return _sqlKeywords;
      case 'go':
        return _goKeywords;
      case 'rust':
        return _rustKeywords;
      case 'shellscript':
        return _shellKeywords;
      default:
        return const [];
    }
  }

  static const _pythonKeywords = [
    'False', 'None', 'True', 'and', 'as', 'assert', 'async', 'await',
    'break', 'class', 'continue', 'def', 'del', 'elif', 'else', 'except',
    'finally', 'for', 'from', 'global', 'if', 'import', 'in', 'is',
    'lambda', 'nonlocal', 'not', 'or', 'pass', 'raise', 'return', 'try',
    'while', 'with', 'yield',
    // Builtins
    'print', 'len', 'range', 'enumerate', 'zip', 'map', 'filter',
    'sorted', 'reversed', 'input', 'open', 'super', 'isinstance',
    'issubclass', 'hasattr', 'getattr', 'setattr', 'delattr',
    'int', 'float', 'str', 'bool', 'list', 'dict', 'tuple', 'set',
    'bytes', 'type', 'object', 'self', '__init__', '__str__', '__repr__',
  ];

  static const _jsKeywords = [
    'async', 'await', 'break', 'case', 'catch', 'class', 'const',
    'continue', 'debugger', 'default', 'delete', 'do', 'else', 'export',
    'extends', 'false', 'finally', 'for', 'from', 'function', 'if',
    'import', 'in', 'instanceof', 'let', 'new', 'null', 'of', 'return',
    'super', 'switch', 'this', 'throw', 'true', 'try', 'typeof',
    'undefined', 'var', 'void', 'while', 'yield',
    // Common globals
    'console', 'document', 'window', 'Math', 'JSON', 'Array', 'Object',
    'String', 'Number', 'Boolean', 'Date', 'RegExp', 'Map', 'Set',
    'Promise', 'Error', 'setTimeout', 'setInterval', 'clearTimeout',
    'clearInterval', 'parseInt', 'parseFloat', 'isNaN', 'isFinite',
    'addEventListener', 'removeEventListener', 'querySelector',
    'querySelectorAll', 'getElementById', 'createElement',
    'appendChild', 'removeChild', 'innerHTML', 'textContent',
    'classList', 'setAttribute', 'getAttribute', 'forEach',
    'map', 'filter', 'reduce', 'find', 'findIndex', 'includes',
    'push', 'pop', 'shift', 'unshift', 'splice', 'slice', 'concat',
    'join', 'split', 'replace', 'match', 'test', 'toString',
    'require', 'module', 'exports',
  ];

  static const _tsKeywords = [
    ..._jsKeywords,
    'abstract', 'any', 'as', 'boolean', 'declare', 'enum', 'implements',
    'infer', 'interface', 'keyof', 'module', 'namespace', 'never',
    'number', 'override', 'private', 'protected', 'public', 'readonly',
    'static', 'string', 'type', 'unknown', 'where',
  ];

  static const _htmlKeywords = [
    'html', 'head', 'body', 'title', 'meta', 'link', 'script', 'style',
    'div', 'span', 'section', 'article', 'header', 'footer', 'nav',
    'main', 'aside', 'form', 'input', 'button', 'select', 'option',
    'textarea', 'label', 'table', 'thead', 'tbody', 'tfoot', 'tr', 'th',
    'td', 'ul', 'ol', 'li', 'img', 'video', 'audio', 'canvas', 'svg',
    'iframe', 'class', 'id', 'src', 'href', 'alt', 'type', 'value',
    'name', 'placeholder', 'action', 'method', 'target', 'rel',
    'charset', 'content', 'viewport', 'width', 'height',
  ];

  static const _cssKeywords = [
    'display', 'position', 'width', 'height', 'margin', 'padding',
    'border', 'background', 'color', 'font', 'text', 'flex', 'grid',
    'align', 'justify', 'overflow', 'opacity', 'transform', 'transition',
    'animation', 'z-index', 'box-shadow', 'border-radius',
    'none', 'auto', 'block', 'inline', 'flex', 'grid', 'absolute',
    'relative', 'fixed', 'sticky', 'inherit', 'initial', 'unset',
    'important', 'media', 'keyframes', 'import', 'charset',
    'hover', 'active', 'focus', 'visited', 'first-child', 'last-child',
    'nth-child', 'before', 'after', 'root', 'not',
  ];

  static const _cppKeywords = [
    'auto', 'break', 'case', 'catch', 'class', 'const', 'constexpr',
    'continue', 'default', 'delete', 'do', 'else', 'enum', 'extern',
    'false', 'for', 'friend', 'goto', 'if', 'inline', 'namespace',
    'new', 'noexcept', 'nullptr', 'operator', 'override', 'private',
    'protected', 'public', 'register', 'return', 'sizeof', 'static',
    'static_cast', 'dynamic_cast', 'reinterpret_cast', 'const_cast',
    'struct', 'switch', 'template', 'this', 'throw', 'true', 'try',
    'typedef', 'typename', 'union', 'using', 'virtual', 'void',
    'volatile', 'while',
    // Types
    'int', 'float', 'double', 'char', 'bool', 'long', 'short',
    'unsigned', 'signed', 'size_t', 'string', 'vector', 'map', 'set',
    'list', 'array', 'pair', 'tuple', 'unique_ptr', 'shared_ptr',
    // Common
    'std', 'cout', 'cin', 'cerr', 'endl', 'printf', 'scanf',
    'malloc', 'free', 'sizeof', 'include', 'define', 'ifndef',
    'ifdef', 'endif', 'pragma',
  ];

  static const _javaKeywords = [
    'abstract', 'assert', 'boolean', 'break', 'byte', 'case', 'catch',
    'char', 'class', 'const', 'continue', 'default', 'do', 'double',
    'else', 'enum', 'extends', 'false', 'final', 'finally', 'float',
    'for', 'goto', 'if', 'implements', 'import', 'instanceof', 'int',
    'interface', 'long', 'native', 'new', 'null', 'package', 'private',
    'protected', 'public', 'return', 'short', 'static', 'strictfp',
    'super', 'switch', 'synchronized', 'this', 'throw', 'throws',
    'transient', 'true', 'try', 'void', 'volatile', 'while',
    'String', 'Integer', 'Float', 'Double', 'Boolean', 'List', 'Map',
    'Set', 'Array', 'Object', 'Class', 'System', 'Scanner', 'Exception',
    'Override', 'Deprecated', 'SuppressWarnings',
  ];

  static const _dartKeywords = [
    'abstract', 'as', 'assert', 'async', 'await', 'break', 'case',
    'catch', 'class', 'const', 'continue', 'covariant', 'default',
    'deferred', 'do', 'dynamic', 'else', 'enum', 'export', 'extends',
    'extension', 'external', 'factory', 'false', 'final', 'finally',
    'for', 'Function', 'get', 'hide', 'if', 'implements', 'import',
    'in', 'interface', 'is', 'late', 'library', 'mixin', 'new', 'null',
    'on', 'operator', 'part', 'required', 'rethrow', 'return', 'set',
    'show', 'static', 'super', 'switch', 'sync', 'this', 'throw',
    'true', 'try', 'typedef', 'var', 'void', 'while', 'with', 'yield',
    // Types
    'int', 'double', 'num', 'String', 'bool', 'List', 'Map', 'Set',
    'Future', 'Stream', 'Object', 'Type', 'Null', 'Never', 'Iterable',
    'Duration', 'DateTime', 'RegExp', 'Uri',
    // Common Flutter
    'Widget', 'StatelessWidget', 'StatefulWidget', 'State',
    'BuildContext', 'Key', 'Container', 'Row', 'Column', 'Text',
    'Scaffold', 'AppBar', 'Icon', 'IconButton', 'TextButton',
    'ElevatedButton', 'TextField', 'Padding', 'Center', 'Expanded',
    'SizedBox', 'ListView', 'GridView', 'Stack', 'Positioned',
    'Navigator', 'MaterialApp', 'Theme', 'Color', 'EdgeInsets',
    'BoxDecoration', 'BorderRadius', 'TextStyle', 'FontWeight',
    'MainAxisAlignment', 'CrossAxisAlignment', 'Alignment',
    'setState', 'initState', 'dispose', 'build', 'override',
    'mounted', 'context', 'debugPrint',
  ];

  static const _sqlKeywords = [
    'SELECT', 'FROM', 'WHERE', 'INSERT', 'INTO', 'VALUES', 'UPDATE',
    'SET', 'DELETE', 'CREATE', 'TABLE', 'DROP', 'ALTER', 'ADD',
    'COLUMN', 'INDEX', 'PRIMARY', 'KEY', 'FOREIGN', 'REFERENCES',
    'JOIN', 'LEFT', 'RIGHT', 'INNER', 'OUTER', 'FULL', 'CROSS', 'ON',
    'AND', 'OR', 'NOT', 'IN', 'IS', 'NULL', 'AS', 'ORDER', 'BY',
    'GROUP', 'HAVING', 'LIMIT', 'OFFSET', 'UNION', 'ALL', 'DISTINCT',
    'EXISTS', 'BETWEEN', 'LIKE', 'CASE', 'WHEN', 'THEN', 'ELSE', 'END',
    'COUNT', 'SUM', 'AVG', 'MIN', 'MAX', 'CAST', 'COALESCE',
    'INT', 'INTEGER', 'BIGINT', 'FLOAT', 'DOUBLE', 'DECIMAL',
    'VARCHAR', 'CHAR', 'TEXT', 'BOOLEAN', 'DATE', 'TIMESTAMP',
    'DATABASE', 'SCHEMA', 'USE', 'SHOW', 'DESCRIBE', 'EXPLAIN',
    'GRANT', 'REVOKE', 'COMMIT', 'ROLLBACK', 'BEGIN', 'TRANSACTION',
    'CONSTRAINT', 'UNIQUE', 'DEFAULT', 'CHECK', 'CASCADE',
    'AUTO_INCREMENT', 'SERIAL', 'IF', 'PROCEDURE', 'FUNCTION',
    'TRIGGER', 'VIEW', 'DECLARE', 'CURSOR',
  ];

  static const _goKeywords = [
    'break', 'case', 'chan', 'const', 'continue', 'default', 'defer',
    'else', 'fallthrough', 'for', 'func', 'go', 'goto', 'if', 'import',
    'interface', 'map', 'package', 'range', 'return', 'select', 'struct',
    'switch', 'type', 'var',
    // Types
    'bool', 'byte', 'complex64', 'complex128', 'error', 'float32',
    'float64', 'int', 'int8', 'int16', 'int32', 'int64', 'rune',
    'string', 'uint', 'uint8', 'uint16', 'uint32', 'uint64', 'uintptr',
    'any',
    // Builtins
    'append', 'cap', 'close', 'copy', 'delete', 'len', 'make', 'new',
    'panic', 'print', 'println', 'recover',
    // Constants
    'true', 'false', 'nil', 'iota',
    // Common packages
    'fmt', 'os', 'io', 'log', 'net', 'http', 'json', 'strings',
    'strconv', 'math', 'time', 'sync', 'context', 'errors', 'testing',
    'reflect', 'sort', 'regexp', 'bufio', 'bytes', 'path', 'filepath',
  ];

  static const _rustKeywords = [
    'as', 'async', 'await', 'break', 'const', 'continue', 'crate',
    'dyn', 'else', 'enum', 'extern', 'false', 'fn', 'for', 'if',
    'impl', 'in', 'let', 'loop', 'match', 'mod', 'move', 'mut',
    'pub', 'ref', 'return', 'self', 'Self', 'static', 'struct', 'super',
    'trait', 'true', 'type', 'unsafe', 'use', 'where', 'while',
    'macro_rules',
    // Types
    'bool', 'char', 'f32', 'f64', 'i8', 'i16', 'i32', 'i64', 'i128',
    'isize', 'str', 'u8', 'u16', 'u32', 'u64', 'u128', 'usize',
    'String', 'Vec', 'Box', 'Option', 'Result', 'HashMap', 'HashSet',
    'Rc', 'Arc', 'Cell', 'RefCell',
    // Constants
    'None', 'Some', 'Ok', 'Err',
    // Common macros
    'println', 'print', 'eprintln', 'eprint', 'format', 'vec',
    'todo', 'unimplemented', 'unreachable', 'panic', 'assert',
    'assert_eq', 'assert_ne', 'dbg', 'cfg', 'derive',
  ];

  static const _shellKeywords = [
    'if', 'then', 'else', 'elif', 'fi', 'for', 'while', 'do', 'done',
    'case', 'esac', 'in', 'function', 'return', 'local', 'export',
    'source', 'alias', 'unalias', 'set', 'unset', 'shift', 'exit',
    'trap', 'eval', 'exec', 'readonly',
    // Common commands
    'echo', 'printf', 'read', 'cd', 'ls', 'pwd', 'mkdir', 'rm', 'cp',
    'mv', 'cat', 'grep', 'find', 'sed', 'awk', 'sort', 'uniq', 'wc',
    'head', 'tail', 'chmod', 'chown', 'kill', 'ps', 'curl', 'wget',
    'tar', 'gzip', 'ssh', 'scp', 'git', 'docker', 'npm', 'pip',
    'python', 'node', 'make', 'gcc',
  ];
}

/// A single completion suggestion
class CompletionItem {
  final String label;
  final CompletionKind kind;
  final String? detail;
  final String? insertText;

  const CompletionItem({
    required this.label,
    required this.kind,
    this.detail,
    this.insertText,
  });

  /// The text to actually insert (falls back to label)
  String get textToInsert => insertText ?? label;
}

/// The kind of a completion item
enum CompletionKind {
  keyword,
  word,
  // LSP kinds
  function,
  variable,
  field,
  property,
  method,
  classKind,
  interfaceKind,
  module,
  snippet,
  text,
  value,
  enumKind,
  constant,
  typeParameter,
  lspOther,
}

/// Map LSP CompletionItemKind (int) to our CompletionKind
CompletionKind lspKindToCompletionKind(int? kind) {
  switch (kind) {
    case 1:
      return CompletionKind.text;
    case 2:
      return CompletionKind.method;
    case 3:
      return CompletionKind.function;
    case 4:
      return CompletionKind.function; // Constructor
    case 5:
      return CompletionKind.field;
    case 6:
      return CompletionKind.variable;
    case 7:
      return CompletionKind.classKind;
    case 8:
      return CompletionKind.interfaceKind;
    case 9:
      return CompletionKind.module;
    case 10:
      return CompletionKind.property;
    case 13:
      return CompletionKind.enumKind;
    case 14:
      return CompletionKind.keyword;
    case 15:
      return CompletionKind.snippet;
    case 16:
      return CompletionKind.value;
    case 21:
      return CompletionKind.constant;
    case 25:
      return CompletionKind.typeParameter;
    default:
      return CompletionKind.lspOther;
  }
}

/// Short label for each completion kind (shown in popup badge)
String completionKindLabel(CompletionKind kind) {
  switch (kind) {
    case CompletionKind.keyword:
      return 'K';
    case CompletionKind.word:
      return 'W';
    case CompletionKind.function:
      return 'F';
    case CompletionKind.variable:
      return 'V';
    case CompletionKind.field:
      return 'F';
    case CompletionKind.property:
      return 'P';
    case CompletionKind.method:
      return 'M';
    case CompletionKind.classKind:
      return 'C';
    case CompletionKind.interfaceKind:
      return 'I';
    case CompletionKind.module:
      return 'Mod';
    case CompletionKind.snippet:
      return 'S';
    case CompletionKind.text:
      return 'T';
    case CompletionKind.value:
      return 'V';
    case CompletionKind.enumKind:
      return 'E';
    case CompletionKind.constant:
      return 'C';
    case CompletionKind.typeParameter:
      return 'T';
    case CompletionKind.lspOther:
      return 'L';
  }
}

/// Descriptive name for each completion kind (shown at right of popup)
String completionKindDescription(CompletionKind kind) {
  switch (kind) {
    case CompletionKind.keyword:
      return 'keyword';
    case CompletionKind.word:
      return 'word';
    case CompletionKind.function:
      return 'function';
    case CompletionKind.variable:
      return 'variable';
    case CompletionKind.field:
      return 'field';
    case CompletionKind.property:
      return 'property';
    case CompletionKind.method:
      return 'method';
    case CompletionKind.classKind:
      return 'class';
    case CompletionKind.interfaceKind:
      return 'interface';
    case CompletionKind.module:
      return 'module';
    case CompletionKind.snippet:
      return 'snippet';
    case CompletionKind.text:
      return 'text';
    case CompletionKind.value:
      return 'value';
    case CompletionKind.enumKind:
      return 'enum';
    case CompletionKind.constant:
      return 'constant';
    case CompletionKind.typeParameter:
      return 'type param';
    case CompletionKind.lspOther:
      return 'lsp';
  }
}
