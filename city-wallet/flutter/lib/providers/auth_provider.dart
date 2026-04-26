import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService _api;
  final StorageService _storage;

  User? _user;
  bool _loading = false;
  String? _error;

  AuthProvider(this._api, this._storage);

  User? get user => _user;
  bool get isLoggedIn => _user != null;
  bool get loading => _loading;
  String? get error => _error;

  Future<void> loadFromStorage() async {
    _user = await _storage.getUser();
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final data = await _api.login(email, password);
      await _storage.saveToken(data['token']);
      final user = User.fromJson(data);
      await _storage.saveUser(user);
      _user = user;
      return true;
    } catch (e) {
      _error = _parseError(e);
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> register(String name, String email, String password, String role) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final data = await _api.register(name, email, password, role);
      await _storage.saveToken(data['token']);
      final user = User.fromJson(data);
      await _storage.saveUser(user);
      _user = user;
      return true;
    } catch (e) {
      _error = _parseError(e);
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await _storage.clearAll();
    _user = null;
    notifyListeners();
  }

  String _parseError(Object e) {
    if (e is Exception) return e.toString().replaceAll('Exception: ', '');
    return 'Something went wrong';
  }
}
