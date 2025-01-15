import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:convert';

// Example usage:
/*
void main() async {
  // Initialize the listener
  final prefs = SharedPreferencesListener();

  // Add a listener for a specific key
  prefs.listenKey('api-key', (value) {
    print('API key changed to: $value'); 
  });

  // Write some values
  await prefs.write('api-key', 'sk-1234567890');  // Prints: API key changed to: sk-1234567890
  await prefs.write('model', 'gpt-4');
  await prefs.write('temperature', 0.7);
  await prefs.write('stream', true);

  // Read values
  String? apiKey = prefs.read('api-key');     // Returns 'sk-1234567890'
  String? model = prefs.read('model');        // Returns 'gpt-4'
  double? temp = prefs.read('temperature');   // Returns 0.7
  bool? isStream = prefs.read('stream');      // Returns true

  // Remove a value
  await prefs.remove('api-key');  // Prints: API key changed to: null

  // Clean up when done
  prefs.dispose();
}
*/

/// A singleton class that listens to changes in shared preferences.
class SharedPreferencesListener {
  static final SharedPreferencesListener _instance =
      SharedPreferencesListener._internal();
  
  /// Factory constructor to return the singleton instance.
  factory SharedPreferencesListener() => _instance;
  
  SharedPreferencesListener._internal();

  SharedPreferences? _prefs;
  final Map<String, List<void Function(dynamic)>> _listeners = {};
  bool _isInitialized = false;

  /// Initializes the shared preferences instance.
  Future<void> init() async {
    if (!_isInitialized) {
      _prefs = await SharedPreferences.getInstance();
      _isInitialized = true;
    }
  }

  /// Adds a listener for a specific key.
  void listenKey(String key, void Function(dynamic) listener,
      {bool returnCurrentValue = true}) {
    _listeners.putIfAbsent(key, () => []).add(listener);
    // Notify the listener with the current value if requested
    if (returnCurrentValue) {
      listener(read(key));
    }
  }

  /// Writes a value to shared preferences.
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
    _notifyListeners(key, value); // Notify listeners of the change
  }

  /// Reads a value from shared preferences.
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

  /// Removes a value from shared preferences.
  Future<void> remove(String key) async {
    await _prefs?.remove(key);
    _notifyListeners(key, null); // Notify listeners of the removal
  }

  /// Notifies listeners of changes to a specific key.
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

  /// Disposes of the listener and clears all listeners.
  void dispose() {
    _listeners.clear(); // Clear listeners when done
  }
}
