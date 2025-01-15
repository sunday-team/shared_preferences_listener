# Shared Preferences Listener

A powerful Flutter plugin that extends SharedPreferences with reactive capabilities, allowing you to listen for changes in preference values across your app. Perfect for state management, settings synchronization, and real-time preference updates.

## Features

- Listen to changes in SharedPreferences values
- Type-safe preference access
- Automatic value change notifications
- All standard SharedPreferences functionality
- Custom object support via JSON serialization
- Efficient memory management
- Batch operations support

## Installation

Add this to your package's pubspec.yaml file:

```yaml
dependencies:
  shared_preferences_listener: ^0.0.1
```

## Usage

### Basic Usage:

```dart
import 'package:shared_preferences_listener/shared_preferences_listener.dart';

// Initialize the listener
final prefs = SharedPreferencesListener();

// Listen to changes
final subscription = prefs.addListener('counter', (value) {
  print('Counter changed to: $value');
});

// Update value
await prefs.setInt('counter', 42);

// Later, when done listening
subscription.cancel();
```

### Type-safe Preferences:

```dart
// Define type-safe preference keys
final counterPref = IntPreference('counter', defaultValue: 0);
final themePref = StringPreference('theme', defaultValue: 'light');

// Use with type safety
await prefs.setValue(counterPref, 10);
await prefs.setValue(themePref, 'dark');

// Get values with correct types
final count = prefs.getValue(counterPref); // Returns int
final theme = prefs.getValue(themePref); // Returns String
```

### Custom Objects:

```dart
class User {
  final String name;
  final int age;
  
  User(this.name, this.age);
  
  factory User.fromJson(Map<String, dynamic> json) => User(
    json['name'] as String,
    json['age'] as int,
  );
  
  Map<String, dynamic> toJson() => {
    'name': name,
    'age': age,
  };
}

// Store custom objects
final user = User('John', 30);
await prefs.setObject('user', user);

// Listen to object changes
prefs.addObjectListener<User>('user', (User? user) {
  print('User updated: ${user?.name}');
});
```

### Batch Operations:

```dart
await prefs.batch((batch) {
  batch.setString('name', 'John');
  batch.setInt('age', 30);
  batch.setBool('isAdmin', true);
});
```

### Multiple Listeners:

```dart
// Add multiple listeners
final sub1 = prefs.addListener('theme', (value) => print('Theme: $value'));
final sub2 = prefs.addListener('theme', (value) => print('Also theme: $value'));

// Remove specific listener
sub1.cancel();

// Or remove all listeners for a key
prefs.removeAllListeners('theme');
```

## Advanced Usage

### Preference Groups:

```dart
// Group related preferences
class UserPreferences {
  static final name = StringPreference('user.name', defaultValue: '');
  static final age = IntPreference('user.age', defaultValue: 0);
  static final isAdmin = BoolPreference('user.isAdmin', defaultValue: false);
}

// Use grouped preferences
await prefs.setValue(UserPreferences.name, 'John');
await prefs.setValue(UserPreferences.age, 30);
```

### Error Handling:

```dart
try {
  await prefs.setInt('counter', 42);
} on SharedPreferencesException catch (e) {
  print('Failed to save preference: ${e.message}');
}
```

## Requirements

- Flutter >= 3.3.0
- Dart SDK >= 3.7.0

## Additional Information

- API Documentation: [https://pub.dev/documentation/shared_preferences_listener/latest/](https://pub.dev/documentation/shared_preferences_listener/latest/)
- GitHub Repository: [https://github.com/sunday-team/shared_preferences_listener](https://github.com/sunday-team/shared_preferences_listener)
- Issue Tracker: [https://github.com/sunday-team/shared_preferences_listener/issues](https://github.com/sunday-team/shared_preferences_listener/issues)

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request. For major changes, please open an issue first to discuss what you would like to change.

## License

This project is licensed under the MIT License - see the LICENSE file for details.
