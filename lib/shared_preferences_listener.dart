library;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:convert';

import 'package:sunday_core/Print/print.dart';

/// A singleton class that listens to changes in shared preferences.
class SharedPreferencesListener {
  static final SharedPreferencesListener _instance = SharedPreferencesListener._internal();
  
  /// Factory constructor to return the singleton instance.
  factory SharedPreferencesListener() => _instance;
  
  SharedPreferencesListener._internal();

  SharedPreferences? _prefs;
  final Map<String, List<StreamController<dynamic>>> _controllers = {};
  bool _isInitialized = false;

  /// Initializes the shared preferences instance if not already initialized.
  Future<void> init() async {
    if (!_isInitialized) {
      _prefs = await SharedPreferences.getInstance();
      _isInitialized = true;
    }
  }

  /// Adds a listener for changes to a specific key.
  /// 
  /// The listener will be notified with the current value if available.
  /// 
  /// - Parameters:
  ///   - key: The key to listen for changes.
  ///   - onData: The callback to be invoked when the value changes.
  /// 
  /// - Returns: A [StreamSubscription] that can be used to cancel the listener.
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
  /// 
  /// The listener will be notified with the current value if available.
  /// 
  /// - Parameters:
  ///   - key: The key to listen for changes.
  ///   - onData: The callback to be invoked when the value changes.
  ///   - fromJson: A function to convert the JSON map to the desired object type.
  /// 
  /// - Returns: A [StreamSubscription] that can be used to cancel the listener.
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
        sundayPrint('Error converting object: $e');
      }
    }

    return controller.stream.listen(onData);
  }

  /// Removes all listeners for a specific key.
  /// 
  /// - Parameters:
  ///   - key: The key for which to remove all listeners.
  void removeAllListeners(String key) {
    final controllers = _controllers[key];
    if (controllers != null) {
      for (var controller in controllers) {
        controller.close();
      }
      _controllers.remove(key);
    }
  }

  /// Sets a value with type safety using a [Preference] object.
  /// 
  /// - Parameters:
  ///   - preference: The [Preference] object containing the key and default value.
  ///   - value: The value to set.
  Future<void> setValue<T>(Preference<T> preference, T value) async {
    await write(preference.key, value);
  }

  /// Gets a value with type safety using a [Preference] object.
  /// 
  /// - Parameters:
  ///   - preference: The [Preference] object containing the key and default value.
  /// 
  /// - Returns: The value associated with the key, or the default value if not found.
  T? getValue<T>(Preference<T> preference) {
    return read(preference.key) as T?;
  }

  /// Writes a value to shared preferences.
  /// 
  /// - Parameters:
  ///   - key: The key to associate with the value.
  ///   - value: The value to write.
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
  /// 
  /// - Parameters:
  ///   - key: The key associated with the value.
  /// 
  /// - Returns: The value associated with the key, or null if not found.
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
  /// 
  /// - Parameters:
  ///   - key: The key associated with the value to remove.
  Future<void> remove(String key) async {
    if (!_isInitialized) await init();
    await _prefs?.remove(key);
    _notifyListeners(key, null);
  }

  /// Performs multiple operations in a batch.
  /// 
  /// - Parameters:
  ///   - operations: A function that performs the operations.
  Future<void> batch(void Function(SharedPreferencesListener) operations) async {
    if (!_isInitialized) await init();
    operations(this);
  }

  /// Notifies listeners of changes to a specific key.
  /// 
  /// - Parameters:
  ///   - key: The key associated with the value that changed.
  ///   - value: The new value.
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

  /// Listens for changes to a specific key and returns a stream of values.
  /// 
  /// - Parameters:
  ///   - key: The key to listen for changes.
  /// 
  /// - Returns: A [Stream] of values associated with the key.
  Stream<dynamic> listenKey(String key) {
    final controller = StreamController<dynamic>.broadcast();
    _controllers.putIfAbsent(key, () => []).add(controller);
    
    // Send current value if available
    final currentValue = read(key);
    if (currentValue != null) {
      controller.add(currentValue);
    }
    
    return controller.stream;
  }
}

/// Base class for type-safe preferences.
///
/// This class provides a structure for defining preferences with a specific type.
/// It holds a key and a default value for the preference.
abstract class Preference<T> {
  /// The key associated with the preference.
  final String key;

  /// The default value for the preference.
  final T defaultValue;

  /// Constructs a [Preference] with the given [key] and [defaultValue].
  const Preference(this.key, {required this.defaultValue});
}

/// String preference with type safety.
///
/// This class represents a preference with a `String` type.
class StringPreference extends Preference<String> {
  /// Constructs a [StringPreference] with the given [key] and [defaultValue].
  const StringPreference(super.key, {required super.defaultValue});
}

/// Int preference with type safety.
///
/// This class represents a preference with an `int` type.
class IntPreference extends Preference<int> {
  /// Constructs an [IntPreference] with the given [key] and [defaultValue].
  const IntPreference(super.key, {required super.defaultValue});
}

/// Double preference with type safety.
///
/// This class represents a preference with a `double` type.
class DoublePreference extends Preference<double> {
  /// Constructs a [DoublePreference] with the given [key] and [defaultValue].
  const DoublePreference(super.key, {required super.defaultValue});
}

/// Bool preference with type safety.
///
/// This class represents a preference with a `bool` type.
class BoolPreference extends Preference<bool> {
  /// Constructs a [BoolPreference] with the given [key] and [defaultValue].
  const BoolPreference(super.key, {required super.defaultValue});
}

/// Custom exception for SharedPreferences operations.
///
/// This exception is thrown when an error occurs during SharedPreferences operations.
class SharedPreferencesException implements Exception {
  /// The error message associated with the exception.
  final String message;

  /// Constructs a [SharedPreferencesException] with the given [message].
  SharedPreferencesException(this.message);
  
  @override
  String toString() => 'SharedPreferencesException: $message';
}
