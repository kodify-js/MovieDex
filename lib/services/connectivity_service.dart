import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  static final ConnectivityService instance = ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  final StreamController<bool> _connectionStatusController =
      StreamController<bool>.broadcast();

  Stream<bool> get connectionStatus => _connectionStatusController.stream;
  bool _hasConnection = true;

  ConnectivityService._internal() {
    _initConnectivity();
    _connectivity.onConnectivityChanged.listen(_updateConnectionStatus);
  }

  Future<void> _initConnectivity() async {
    try {
      var status = await _connectivity.checkConnectivity();
      _updateConnectionStatus(status);
    } catch (e) {
      _connectionStatusController.add(false);
      _hasConnection = false;
    }
  }

  void _updateConnectionStatus(ConnectivityResult result) {
    bool isConnected = result != ConnectivityResult.none;
    _hasConnection = isConnected;
    _connectionStatusController.add(isConnected);
  }

  bool get hasConnection => _hasConnection;

  Future<bool> checkConnection() async {
    try {
      var status = await _connectivity.checkConnectivity();
      _updateConnectionStatus(status);
      return _hasConnection;
    } catch (e) {
      return false;
    }
  }

  void dispose() {
    _connectionStatusController.close();
  }
}
