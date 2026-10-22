import 'package:shared_preferences/shared_preferences.dart';

/// 宿舍热水默认设备的本机存储键。
const String hotWaterDefaultDeviceKey = 'hot_water_default_device';

/// 默认（固定）设备的存储抽象。
///
/// 按设备号（`poscode`）保存，不按列表下标：设备列表顺序由服务端下发，
/// 每次刷新都可能变化，下标跨会话不稳定。
abstract class HotWaterDevicePreferenceStore {
  /// 读取保存的默认设备号；未设置时返回空串。
  Future<String> readDefaultDeviceCode();

  /// 保存默认设备号；传空串表示清除默认设备。
  Future<void> writeDefaultDeviceCode(String deviceCode);
}

class SharedPreferencesHotWaterDevicePreferenceStore
    implements HotWaterDevicePreferenceStore {
  SharedPreferencesHotWaterDevicePreferenceStore([
    Future<SharedPreferences>? preferences,
  ]) : _preferences = preferences;

  final Future<SharedPreferences>? _preferences;

  Future<SharedPreferences> _resolvePreferences() {
    return _preferences ?? SharedPreferences.getInstance();
  }

  @override
  Future<String> readDefaultDeviceCode() async {
    try {
      final prefs = await _resolvePreferences();
      return prefs.getString(hotWaterDefaultDeviceKey) ?? '';
    } catch (_) {
      // 读取失败按「无默认设备」处理，不阻塞页面加载。
      return '';
    }
  }

  @override
  Future<void> writeDefaultDeviceCode(String deviceCode) async {
    final prefs = await _resolvePreferences();
    if (deviceCode.isEmpty) {
      await prefs.remove(hotWaterDefaultDeviceKey);
      return;
    }
    await prefs.setString(hotWaterDefaultDeviceKey, deviceCode);
  }
}
