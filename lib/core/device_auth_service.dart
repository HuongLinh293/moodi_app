import 'package:local_auth/local_auth.dart';

class DeviceAuthService {
  final LocalAuthentication _auth = LocalAuthentication();
  Future<bool> authenticate() async {
    try {
      if (!await _auth.isDeviceSupported()) return false;
      return await _auth.authenticate(
        localizedReason: 'Xác thực để mở không gian riêng tư Moodi',
        biometricOnly: false,
        persistAcrossBackgrounding: false,
      );
    } catch (_) {
      return false;
    }
  }
}
