import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Persisted session data — workspace path, open tabs, active index, layout.
class SessionData {
  final String? workspacePath;
  final List<SessionTab> openTabs;
  final int activeTabIndex;
  final double sidebarWidth;
  final double bottomPanelHeight;
  final bool sidebarVisible;
  final bool bottomPanelVisible;

  const SessionData({
    this.workspacePath,
    this.openTabs = const [],
    this.activeTabIndex = -1,
    this.sidebarWidth = 260.0,
    this.bottomPanelHeight = 200.0,
    this.sidebarVisible = true,
    this.bottomPanelVisible = false,
  });

  Map<String, dynamic> toJson() => {
        'workspacePath': workspacePath,
        'openTabs': openTabs.map((t) => t.toJson()).toList(),
        'activeTabIndex': activeTabIndex,
        'sidebarWidth': sidebarWidth,
        'bottomPanelHeight': bottomPanelHeight,
        'sidebarVisible': sidebarVisible,
        'bottomPanelVisible': bottomPanelVisible,
      };

  factory SessionData.fromJson(Map<String, dynamic> json) {
    return SessionData(
      workspacePath: json['workspacePath'] as String?,
      openTabs: (json['openTabs'] as List<dynamic>?)
              ?.map((e) => SessionTab.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      activeTabIndex: json['activeTabIndex'] as int? ?? -1,
      sidebarWidth: (json['sidebarWidth'] as num?)?.toDouble() ?? 260.0,
      bottomPanelHeight:
          (json['bottomPanelHeight'] as num?)?.toDouble() ?? 200.0,
      sidebarVisible: json['sidebarVisible'] as bool? ?? true,
      bottomPanelVisible: json['bottomPanelVisible'] as bool? ?? false,
    );
  }
}

/// Minimal tab info for session persistence (file path + name only).
/// Content is NOT persisted — it's re-read from disk on restore.
class SessionTab {
  final String filePath;
  final String fileName;

  const SessionTab({required this.filePath, required this.fileName});

  Map<String, dynamic> toJson() => {
        'filePath': filePath,
        'fileName': fileName,
      };

  factory SessionTab.fromJson(Map<String, dynamic> json) {
    return SessionTab(
      filePath: json['filePath'] as String? ?? '',
      fileName: json['fileName'] as String? ?? '',
    );
  }
}

/// Service for saving and restoring IDE session state.
class SessionService {
  static const _key = 'session_data';

  final SharedPreferences _prefs;

  SessionService(this._prefs);

  /// Load persisted session, or return empty session if none.
  SessionData load() {
    final raw = _prefs.getString(_key);
    if (raw == null) return const SessionData();
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return SessionData.fromJson(json);
    } catch (_) {
      return const SessionData();
    }
  }

  /// Save session to SharedPreferences.
  void save(SessionData data) {
    final raw = jsonEncode(data.toJson());
    _prefs.setString(_key, raw);
  }

  /// Clear saved session.
  void clear() {
    _prefs.remove(_key);
  }
}
