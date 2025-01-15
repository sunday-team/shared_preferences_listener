import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:convert';

/// A singleton class that listens to changes in shared preferences.
class SharedPreferencesListener {
  static final SharedPreferencesListener _instance = SharedPreferencesListener._internal();
  
  /// Factory constructor to return the singleton instance.
  factory SharedPreferencesListener() => _instance;
  
  SharedPreferencesListener._internal();

  SharedPreferences? _prefs;
  final Map<String, List<StreamController<dynamic>>> _controllers = {};
  bool _isInitialized = false;

  /// Initializes the shared preferences instance.
  Future<void> init() async {
    if (!_isInitialized) {
      _prefs = await SharedPreferences.getInstance();
      _isInitialized = true;
    }
  }

  /// Adds a listener for a specific key and returns a StreamSubscription.
  StreamSubscription<T> addListener<T>(String key, void Function(T) onData) {
    final controller = StreamController<T>.broadcast();
    _controllers.putIfAbsent(key, () => []).add(controller);
    
    // Send current value if available
    final currentValue = read(key);
    if (currentValue != null) {
      controller.add(currentValue as T);
    }
    
    return controller.stream.listen(onData);
  }

  /// Adds a typed listener for objects that can be converted from/to JSON.
  StreamSubscription<T?> addObjectListener<T>(
    String key,
    void Function(T?) onData,
    {T Function(Map<String, dynamic>)? fromJson}
  ) {
    final controller = StreamController<T?>.broadcast();
    _controllers.putIfAbsent(key, () => []).add(controller);

    // Send current value if available
    final currentValue = read(key);
    if (currentValue != null && fromJson != null) {
      try {
        final obj = fromJson(currentValue as Map<String, dynamic>);
        controller.add(obj);
      } catch (e) {
        print('Error converting object: $e');
      }
    }

    return controller.stream.listen(onData);
  }

  /// Removes all listeners for a specific key.
  void removeAllListeners(String key) {
    final controllers = _controllers[key];
    if (controllers != null) {
      for (var controller in controllers) {
        controller.close();
      }
      _controllers.remove(key);
    }
  }

  /// Sets a value with type safety using a Preference object.
  Future<void> setValue<T>(Preference<T> preference, T value) async {
    await write(preference.key, value);
  }

  /// Gets a value with type safety using a Preference object.
  T? getValue<T>(Preference<T> preference) {
    return read(preference.key) as T?;
  }

  /// Writes a value to shared preferences.
  Future<void> write<T>(String key, T value) async {
    if (!_isInitialized) await init();
    
    if (value is String) {
      await _prefs?.setString(key, value);
    } else if (value is int) {
      await _prefs?.setInt(key, value);
    } else if (value is double) {
      await _prefs?.setDouble(key, value);
    } else if (value is bool) {
      await _prefs?.setBool(key, value);
    } else if (value is List || value is Map) {
      await _prefs?.setString(key, json.encode(value));
    } else {
      throw SharedPreferencesException('Unsupported type: ${value.runtimeType}');
    }
    _notifyListeners(key, value);
  }

  /// Reads a value from shared preferences.
  dynamic read(String key) {
    if (!_isInitialized) init();
    
    final value = _prefs?.get(key);
    if (value is String) {
      try {
        return json.decode(value);
      } catch (e) {
        return value;
      }
    }
    return value;
  }

  /// Removes a value from shared preferences.
  Future<void> remove(String key) async {
    if (!_isInitialized) await init();
    await _prefs?.remove(key);
    _notifyListeners(key, null);
  }

  /// Performs multiple operations in a batch.
  Future<void> batch(void Function(SharedPreferencesListener) operations) async {
    if (!_isInitialized) await init();
    operations(this);
  }

  /// Notifies listeners of changes to a specific key.
  void _notifyListeners(String key, dynamic value) {
    final controllers = _controllers[key];
    if (controllers == null) return;

    if (value is String) {
      try {
        final decoded = json.decode(value);
        for (var controller in controllers) {
          controller.add(decoded);
        }
        return;
      } catch (_) {}
    }
    
    for (var controller in controllers) {
      controller.add(value);
    }
  }

  /// Disposes of all controllers and clears listeners.
  void dispose() {
    for (var controllers in _controllers.values) {
      for (var controller in controllers) {
        controller.close();
      }
    }
    _controllers.clear();
  }
}

/// Base class for type-safe preferences
abstract class Preference<T> {
  final String key;
  final T defaultValue;

  const Preference(this.key, {required this.defaultValue});
}

/// String preference with type safety
class StringPreference extends Preference<String> {
  const StringPreference(String key, {required String defaultValue}) 
    : super(key, defaultValue: defaultValue);
}

/// Int preference with type safety
class IntPreference extends Preference<int> {
  const IntPreference(String key, {required int defaultValue})
    : super(key, defaultValue: defaultValue);
}

/// Double preference with type safety
class DoublePreference extends Preference<double> {
  const DoublePreference(String key, {required double defaultValue})
    : super(key, defaultValue: defaultValue);
}

/// Bool preference with type safety
class BoolPreference extends Preference<bool> {
  const BoolPreference(String key, {required bool defaultValue})
    : super(key, defaultValue: defaultValue);
}

/// Custom exception for SharedPreferences operations
class SharedPreferencesException implements Exception {
  final String message;
  SharedPreferencesException(this.message);
  
  @override
  String toString() => 'SharedPreferencesException: $message';
}
