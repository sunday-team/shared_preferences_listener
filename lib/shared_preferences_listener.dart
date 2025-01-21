import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:convert';

class SharedPreferencesListener {
  static final SharedPreferencesListener _instance =
      SharedPreferencesListener._internal();
  factory SharedPreferencesListener() => _instance;
  SharedPreferencesListener._internal();

  SharedPreferences? _prefs;
  final Map<String, List<void Function(dynamic)>> _listeners = {};
  bool _isInitialized = false;

  Future<void> init() async {
    if (!_isInitialized) {
      _prefs = await SharedPreferences.getInstance();
      _isInitialized = true;
    }
  }

  void listenKey(String key, void Function(dynamic) listener,
      {bool returnCurrentValue = true}) {
    _listeners.putIfAbsent(key, () => []).add(listener);
    if (returnCurrentValue) {
      listener(read(key));
    }
  }

  Future<void> write<T>(String key, T value) async {
    if (value is String) {
      await _prefs?.setString(key, value);
    } else if (value is int) {
      await _prefs?.setInt(key, value);
    } else if (value is double) {
      await _prefs?.setDouble(key, value);
    } else if (value is bool) {
      await _prefs?.setBool(key, value);
    } else if (value is List || value is Map) {
      // Convert complex types to JSON string
      await _prefs?.setString(key, json.encode(value));
    } else {
      throw Exception('Unsupported type: ${value.runtimeType}');
    }
    _notifyListeners(key, value);
  }

  dynamic read(String key) {
    final value = _prefs?.get(key);
    if (value is String) {
      try {
        // Attempt to decode JSON string
        return json.decode(value);
      } catch (e) {
        // If not JSON, return original string
        return value;
      }
    }
    return value;
  }

  Future<void> remove(String key) async {
    await _prefs?.remove(key);
    _notifyListeners(key, null);
  }

  void _notifyListeners(String key, dynamic value) {
    if (value is String) {
      try {
        // Try to decode JSON before notifying listeners
        final decoded = json.decode(value);
        for (var listener in _listeners[key] ?? []) {
          listener(decoded);
        }
        return;
      } catch (_) {
        // If not JSON, continue with original value
      }
    }
    for (var listener in _listeners[key] ?? []) {
      listener(value);
    }
  }

  void dispose() {
    _listeners.clear();
  }
}
