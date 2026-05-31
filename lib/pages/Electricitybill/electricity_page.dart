import 'dart:async';

import 'package:enhanced_future_builder/enhanced_future_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ionicons/ionicons.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/services/app_logger.dart';
import '../../core/ui/app_bottom_sheet.dart';
import '../../core/ui/app_loading_indicator.dart';
import '../../core/ui/app_snack_bar.dart';
import 'electricity_api.dart';

const int _asciiZero = 0x30;
const int _asciiNine = 0x39;
const int _asciiDecimalPoint = 0x2E;

typedef ElectricityBottomSheetPresenter =
    Future<T?> Function<T>({
      required BuildContext context,
      required WidgetBuilder builder,
      bool expand,
      Color? backgroundColor,
      Color? barrierColor,
      Color? transitionBackgroundColor,
      Radius? topRadius,
      BoxShadow? shadow,
    });

const electricityRoomLoadFailureMessage = '房间信息加载失败，请稍后重试';

class ElectricityPage extends StatefulWidget {
  const ElectricityPage({
    super.key,
    ElectricityApiClient? electricityApi,
    ElectricityBalanceClient? balanceClient,
    Future<SharedPreferences> Function()? loadPrefs,
    ElectricityBottomSheetPresenter? showBottomSheet,
  }) : _electricityApi = electricityApi,
       _balanceClient = balanceClient,
       _loadPrefs = loadPrefs,
       _showBottomSheet = showBottomSheet;

  final ElectricityApiClient? _electricityApi;
  final ElectricityBalanceClient? _balanceClient;
  final Future<SharedPreferences> Function()? _loadPrefs;
  final ElectricityBottomSheetPresenter? _showBottomSheet;

  @override
  State<ElectricityPage> createState() => _ElectricityPageState();
}

class _ElectricityPageState extends State<ElectricityPage> {
  static const double _maxRechargeAmount = 10000;
  static const List<TextInputFormatter> _amountInputFormatters =
      <TextInputFormatter>[DecimalTextInputFormatter()];

  String setRoomName = "未知房间";
  String nowRoomId = '';
  String roomCount = '-';
  late final ElectricityApiClient electricityApi;
  late final ElectricityBalanceClient _balanceClient;
  late final Future<bool> _initialRoomFuture;
  Map<String, dynamic> baseInfo = {};
  Map<String, dynamic> nowRoomInfo = {};
  bool isinit = false;
  bool _isAlertSheetOpening = false;
  bool _isRoomPickerSheetOpen = false;
  String? roomLoadErrorMessage;
  Future<List<dynamic>>? _roomListLoad;
  List<dynamic>? _roomListCache;
  List<dynamic>? _roomPickerItemsSource;
  List<_RoomPickerItem>? _cachedRoomPickerItems;
  int _roomInfoGeneration = 0;
  int _balanceGeneration = 0;
  late final ValueNotifier<_ElectricityRoomInfoViewState> _roomInfoNotifier =
      ValueNotifier<_ElectricityRoomInfoViewState>(
        _ElectricityRoomInfoViewState(
          roomName: setRoomName,
          roomCount: roomCount,
          errorMessage: roomLoadErrorMessage,
        ),
      );
  late final ValueNotifier<String> _balanceNotifier = ValueNotifier<String>(
    '-',
  );
  final ValueNotifier<bool> _isRoomLoadingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _isChargeLoadingNotifier = ValueNotifier<bool>(
    false,
  );
  final TextEditingController _paymentController = TextEditingController();

  @override
  void dispose() {
    _roomInfoNotifier.dispose();
    _balanceNotifier.dispose();
    _isRoomLoadingNotifier.dispose();
    _isChargeLoadingNotifier.dispose();
    _paymentController.dispose();
    super.dispose();
  }

  /// 获取余额

  @override
  void initState() {
    super.initState();
    electricityApi = widget._electricityApi ?? ElectricityApi();
    _balanceClient = widget._balanceClient ?? HutElectricityBalanceClient();
    _initialRoomFuture = getHisRoomInfo();
    getBalance();
  }

  Future<String> _loadBalance() async {
    try {
      return await _balanceClient.getCardBalance();
    } catch (error, stackTrace) {
      AppLogger.error(
        'Failed to load card balance on electricity page',
        error: error,
        stackTrace: stackTrace,
      );
      return '-';
    }
  }

  bool _applyBalance(String cardBalance) {
    if (_balanceNotifier.value == cardBalance) {
      return false;
    }

    _balanceNotifier.value = cardBalance;
    return true;
  }

  String get balance => _balanceNotifier.value;

  bool _hasSameRoomInfo(String roomId, Map<String, dynamic> roomInfo) {
    return nowRoomId == roomId &&
        setRoomName == roomInfo['roomName'].toString() &&
        roomCount == roomInfo['eleTail'].toString() &&
        roomLoadErrorMessage == null;
  }

  bool _applyRoomInfo(String roomId, Map<String, dynamic> roomInfo) {
    if (_hasSameRoomInfo(roomId, roomInfo)) {
      return false;
    }

    nowRoomInfo = roomInfo;
    setRoomName = roomInfo['roomName'].toString();
    roomCount = roomInfo['eleTail'].toString();
    nowRoomId = roomId;
    roomLoadErrorMessage = null;
    _roomInfoNotifier.value = _ElectricityRoomInfoViewState(
      roomName: setRoomName,
      roomCount: roomCount,
    );
    return true;
  }

  bool _applyRoomLoadError(String message) {
    if (roomLoadErrorMessage == message) {
      return false;
    }

    roomLoadErrorMessage = message;
    _roomInfoNotifier.value = _ElectricityRoomInfoViewState(
      roomName: setRoomName,
      roomCount: roomCount,
      errorMessage: message,
    );
    return true;
  }

  int _nextRoomInfoGeneration() {
    return ++_roomInfoGeneration;
  }

  bool _isLatestRoomInfoGeneration(int generation) {
    return mounted && generation == _roomInfoGeneration;
  }

  int _nextBalanceGeneration() {
    return ++_balanceGeneration;
  }

  bool _isLatestBalanceGeneration(int generation) {
    return mounted && generation == _balanceGeneration;
  }

  Future<void> getBalance() async {
    final generation = _nextBalanceGeneration();
    final cardBalance = await _loadBalance();
    if (!_isLatestBalanceGeneration(generation)) {
      return;
    }
    _applyBalance(cardBalance);
  }

  Future<void> _refreshRoomAndBalance(String roomId) async {
    final roomGeneration = _nextRoomInfoGeneration();
    final balanceGeneration = _nextBalanceGeneration();
    final results = await Future.wait<Object>([
      electricityApi.getSingleRoomInfo(roomId),
      _loadBalance(),
    ]);
    final shouldApplyRoom = _isLatestRoomInfoGeneration(roomGeneration);
    final shouldApplyBalance = _isLatestBalanceGeneration(balanceGeneration);
    if (!shouldApplyRoom && !shouldApplyBalance) {
      return;
    }

    final cardBalance = results[1] as String;
    final roomInfo =
        shouldApplyRoom ? Map<String, dynamic>.from(results[0] as Map) : null;
    final hasRoomChange =
        roomInfo != null && !_hasSameRoomInfo(roomId, roomInfo);
    final hasBalanceChange = shouldApplyBalance && balance != cardBalance;
    if (!hasRoomChange && !hasBalanceChange) {
      return;
    }

    if (hasRoomChange) {
      _applyRoomInfo(roomId, roomInfo);
    }
    if (hasBalanceChange) {
      _applyBalance(cardBalance);
    }
  }

  Future<bool> getHisRoomInfo() async {
    if (isinit) {
      return true;
    }

    final generation = _nextRoomInfoGeneration();
    try {
      await electricityApi.onInit();
      final history = Map<String, dynamic>.from(
        await electricityApi.getHistory(),
      );
      final roomInfo = Map<String, dynamic>.from(
        await electricityApi.getSingleRoomInfo(history['roomid'].toString()),
      );
      if (!_isLatestRoomInfoGeneration(generation)) {
        return false;
      }

      baseInfo = history;
      _applyRoomInfo(history['roomid'].toString(), roomInfo);
      isinit = true;
      return true;
    } catch (error, stackTrace) {
      AppLogger.error(
        'Failed to load electricity room info',
        error: error,
        stackTrace: stackTrace,
      );
      if (!_isLatestRoomInfoGeneration(generation)) {
        return false;
      }

      _applyRoomLoadError(electricityRoomLoadFailureMessage);
      return false;
    }
  }

  Future<bool> getNewRoomInfo(String roomId) async {
    final generation = _nextRoomInfoGeneration();
    final roomInfo = Map<String, dynamic>.from(
      await electricityApi.getSingleRoomInfo(roomId),
    );
    if (!_isLatestRoomInfoGeneration(generation)) {
      return false;
    }
    if (_hasSameRoomInfo(roomId, roomInfo)) {
      return true;
    }

    _applyRoomInfo(roomId, roomInfo);
    return true;
  }

  Future<List<dynamic>> getRoomList() async {
    final cachedRooms = _roomListCache;
    if (cachedRooms != null) {
      return cachedRooms;
    }

    final inFlight = _roomListLoad;
    if (inFlight != null) {
      return inFlight;
    }

    final load = electricityApi.getRoomList();
    _roomListLoad = load;
    try {
      final rooms = await load;
      _roomListCache = List<dynamic>.from(rooms);
      return _roomListCache!;
    } finally {
      if (identical(_roomListLoad, load)) {
        _roomListLoad = null;
      }
    }
  }

  List<_RoomPickerItem> _roomPickerItemsFor(List<dynamic> roomList) {
    final cachedItems = _cachedRoomPickerItems;
    if (cachedItems != null && identical(_roomPickerItemsSource, roomList)) {
      return cachedItems;
    }

    final items = _buildRoomPickerItems(roomList);
    _roomPickerItemsSource = roomList;
    _cachedRoomPickerItems = items;
    return items;
  }

  List<_RoomPickerItem> _buildRoomPickerItems(List<dynamic> roomList) {
    final items = <_RoomPickerItem>[];
    for (final rawRoom in roomList) {
      if (rawRoom is! Map<dynamic, dynamic>) {
        continue;
      }

      final name = rawRoom['acname'].toString();
      final id = rawRoom['acguid'].toString();
      items.add(
        _RoomPickerItem(
          name: name,
          id: id,
          normalizedName: name.toLowerCase(),
          normalizedId: id.toLowerCase(),
        ),
      );
    }
    return List<_RoomPickerItem>.unmodifiable(items);
  }

  List<_RoomPickerItem> _filterRoomPickerItems(
    List<_RoomPickerItem> roomItems,
    String query,
  ) {
    if (query.isEmpty) {
      return roomItems;
    }

    final filteredItems = <_RoomPickerItem>[];
    for (final room in roomItems) {
      if (room.normalizedName.contains(query) ||
          room.normalizedId.contains(query)) {
        filteredItems.add(room);
      }
    }
    return List<_RoomPickerItem>.unmodifiable(filteredItems);
  }

  AppSnackBarType _resolveSnackBarType(String message) {
    if (message.contains('成功') ||
        message.contains('已开启') ||
        message.contains('已更新') ||
        message.contains('已关闭')) {
      return AppSnackBarType.success;
    }
    if (message.contains('失败') ||
        message.contains('错误') ||
        message.contains('不足') ||
        message.contains('未获取')) {
      return AppSnackBarType.error;
    }
    if (message.contains('请输入') ||
        message.contains('不能为空') ||
        message.contains('必须') ||
        message.contains('最多') ||
        message.contains('不能超过') ||
        message.contains('暂未')) {
      return AppSnackBarType.warning;
    }
    return AppSnackBarType.info;
  }

  void _showSnackBar(String message) {
    if (!mounted) {
      return;
    }

    showAppSnackBar(
      context,
      message: message,
      type: _resolveSnackBarType(message),
    );
  }

  String? _validatePaymentInput(String paymentText) {
    if (paymentText.isEmpty) {
      return '充值金额不能为空';
    }

    final amount = double.tryParse(paymentText);
    if (amount == null) {
      return '请输入有效的数字格式';
    }
    if (amount <= 0) {
      return '金额必须大于0元';
    }
    if (!_hasValidAmountPrecision(paymentText)) {
      return '最多支持两位小数';
    }
    if (amount > _maxRechargeAmount) {
      return '单次充值不能超过${_maxRechargeAmount.toInt()}元';
    }

    return null;
  }

  String? _validateAlertAmount(String amountText) {
    if (amountText.isEmpty) {
      return '预警金额不能为空';
    }

    final amount = double.tryParse(amountText);
    if (amount == null) {
      return '请输入有效的预警金额';
    }
    if (amount <= 0) {
      return '预警金额必须大于0元';
    }
    if (!_hasValidAmountPrecision(amountText)) {
      return '预警金额最多支持两位小数';
    }

    return null;
  }

  Future<bool> chargeMoney(String payment) async {
    final roomToChargeName = setRoomName;
    final roomToChargeId = nowRoomId;
    final balanceAmount = double.tryParse(balance) ?? 0;
    final paymentAmount = double.tryParse(payment);

    if (paymentAmount == null) {
      _showSnackBar('请输入有效的数字格式');
      return false;
    }
    if (roomToChargeId.isEmpty) {
      _showSnackBar('暂未获取到房间信息');
      return false;
    }
    if (balanceAmount < paymentAmount) {
      _showSnackBar('余额不足');
      return false;
    }

    final firstCheck = await electricityApi.checkBeforeRecharge(roomToChargeId);
    if (!mounted) {
      return false;
    }
    if (!firstCheck) {
      _showSnackBar('充值校验失败，请稍后重试');
      return false;
    }

    await electricityApi.createOrder(roomToChargeId, payment, roomToChargeName);
    await _refreshRoomAndBalance(roomToChargeId);
    _paymentController.clear();
    _showSnackBar('电费充值成功');
    return true;
  }

  Future<void> _handleChargePressed() async {
    if (_isChargeLoadingNotifier.value) {
      return;
    }

    final payment = _paymentController.text.trim();
    final validationMessage = _validatePaymentInput(payment);
    if (validationMessage != null) {
      _showSnackBar(validationMessage);
      return;
    }

    _setChargeLoading(true);

    try {
      await chargeMoney(payment);
    } catch (error, stackTrace) {
      AppLogger.error(
        'Electricity recharge failed',
        error: error,
        stackTrace: stackTrace,
      );
      _showSnackBar('电费充值失败，请稍后重试');
    } finally {
      _setChargeLoading(false);
    }
  }

  Future<void> _handleRoomPickerPressed() async {
    if (_isRoomLoadingNotifier.value || _isRoomPickerSheetOpen) {
      return;
    }

    final cachedRoomList = _roomListCache;
    if (cachedRoomList != null) {
      unawaited(_showAllRoomBottomSheet(cachedRoomList));
      return;
    }

    _setRoomLoading(true);

    try {
      final roomList = await getRoomList();
      if (!mounted) {
        return;
      }

      unawaited(_showAllRoomBottomSheet(roomList));
    } catch (error, stackTrace) {
      AppLogger.error(
        'Failed to load electricity room list',
        error: error,
        stackTrace: stackTrace,
      );
      _showSnackBar('房间列表加载失败，请稍后重试');
    } finally {
      _setRoomLoading(false);
    }
  }

  void _setRoomLoading(bool value) {
    if (!mounted || _isRoomLoadingNotifier.value == value) {
      return;
    }

    _isRoomLoadingNotifier.value = value;
  }

  void _setChargeLoading(bool value) {
    if (!mounted || _isChargeLoadingNotifier.value == value) {
      return;
    }

    _isChargeLoadingNotifier.value = value;
  }

  Future<void> _saveAlertSettings(String alertAmount) async {
    final prefs = await (widget._loadPrefs ?? SharedPreferences.getInstance)();
    await prefs.setBool('enableBillWarning', true);
    await prefs.setString('enableRoomId', nowRoomId);
    await prefs.setString('enableRoomName', setRoomName);
    await prefs.setDouble('enableBill', double.parse(alertAmount));
  }

  Future<void> _disableAlertSettings() async {
    final prefs = await (widget._loadPrefs ?? SharedPreferences.getInstance)();
    await prefs.setBool('enableBillWarning', false);
  }

  Future<_ElectricityAlertSettings> _loadAlertSettings() async {
    final prefs = await (widget._loadPrefs ?? SharedPreferences.getInstance)();
    return _ElectricityAlertSettings(
      isEnabled: prefs.getBool('enableBillWarning') ?? false,
      roomId: prefs.getString('enableRoomId') ?? '',
      roomName: prefs.getString('enableRoomName') ?? '',
      bill: prefs.getDouble('enableBill') ?? 0,
    );
  }

  Future<T?> _showElectricityBottomSheet<T>({
    required WidgetBuilder builder,
    bool expand = false,
    Color? backgroundColor,
  }) {
    final presenter = widget._showBottomSheet ?? showAppAdaptiveBottomSheet;
    return presenter<T>(
      context: context,
      expand: expand,
      backgroundColor: backgroundColor,
      builder: builder,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final roomAccent = colorScheme.primary;
    final chargeAccent = colorScheme.secondary;
    final cardForeground = colorScheme.onSurface;
    final mutedForeground = colorScheme.onSurfaceVariant;
    final inputFillColor =
        theme.brightness == Brightness.dark
            ? colorScheme.surface.withValues(alpha: 0.76)
            : colorScheme.surfaceContainerHigh;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('电费充值'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Container(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
        child: ListView(
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: _buildSectionCardDecoration(
                context,
                accent: roomAccent,
              ),
              child: EnhancedFutureBuilder(
                future: _initialRoomFuture,
                rememberFutureResult: true,
                whenDone: (v) {
                  return ValueListenableBuilder<_ElectricityRoomInfoViewState>(
                    valueListenable: _roomInfoNotifier,
                    builder: (context, roomInfoState, _) {
                      final errorMessage = roomInfoState.errorMessage;
                      if (errorMessage != null) {
                        return Text(
                          errorMessage,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: cardForeground,
                          ),
                        );
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              _buildSectionBadge(
                                context,
                                icon: Ionicons.flash_outline,
                                accent: roomAccent,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '当前房间',
                                      style: theme.textTheme.labelLarge
                                          ?.copyWith(color: mutedForeground),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      roomInfoState.roomName,
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                            color: cardForeground,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Flexible(
                                child: Text(
                                  roomInfoState.roomCount,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.displaySmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: cardForeground,
                                    height: 1,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 5),
                                child: Text(
                                  'CNY',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.8,
                                    color: mutedForeground,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  );
                },
                whenNotDone: Center(
                  child: AppLoadingIndicator(color: roomAccent, size: 40),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: _buildSectionCardDecoration(
                context,
                accent: chargeAccent,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _buildSectionBadge(
                        context,
                        icon: Ionicons.card_outline,
                        accent: chargeAccent,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '充值方式',
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: mutedForeground,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '通过校园卡充值',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: cardForeground,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: _paymentController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    cursorColor: chargeAccent,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: cardForeground,
                    ),
                    maxLength: 10,
                    inputFormatters: _amountInputFormatters,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: inputFillColor,
                      hintText: '输入充值金额',
                      hintStyle: theme.textTheme.titleLarge?.copyWith(
                        color: mutedForeground,
                      ),
                      prefixIcon: Icon(
                        Icons.currency_yen_rounded,
                        color: chargeAccent,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: colorScheme.outlineVariant.withValues(
                            alpha: 0.72,
                          ),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: colorScheme.outlineVariant.withValues(
                            alpha: 0.72,
                          ),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: chargeAccent.withValues(alpha: 0.92),
                          width: 1.4,
                        ),
                      ),
                      counterText: '',
                    ),
                  ),
                  ValueListenableBuilder<String>(
                    valueListenable: _balanceNotifier,
                    child: Text(
                      '校园卡余额',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: mutedForeground,
                      ),
                    ),
                    builder: (context, balanceValue, label) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: inputFillColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: colorScheme.outlineVariant.withValues(
                              alpha: 0.64,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            label!,
                            const Spacer(),
                            Text(
                              balanceValue,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: cardForeground,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ValueListenableBuilder<bool>(
                      valueListenable: _isChargeLoadingNotifier,
                      child: const Text('充值'),
                      builder: (context, isChargeLoading, label) {
                        return FilledButton(
                          onPressed:
                              isChargeLoading ? null : _handleChargePressed,
                          style: FilledButton.styleFrom(
                            backgroundColor: chargeAccent,
                            foregroundColor: colorScheme.onSecondary,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child:
                              isChargeLoading
                                  ? AppLoadingIndicator(
                                    size: 20,
                                    color: colorScheme.onSecondary,
                                  )
                                  : label,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _buildActionTile(
              icon: Ionicons.grid_outline,
              title: '更改充值房间',
              onTap: _handleRoomPickerPressed,
              trailing: ValueListenableBuilder<bool>(
                valueListenable: _isRoomLoadingNotifier,
                builder: (context, isRoomLoading, _) {
                  return isRoomLoading
                      ? AppLoadingIndicator(
                        color: colorScheme.primary,
                        size: 20,
                      )
                      : Icon(
                        Icons.chevron_right,
                        color: colorScheme.onSurfaceVariant,
                      );
                },
              ),
            ),
            _buildFunctionItem(
              icon: Ionicons.alert_circle_outline,
              title: '电费预警',
              onTap: _showAlertBottomSheet,
            ),
          ],
        ),
      ),
    );
  }

  // 显示所有充值房间
  Future<void> _showAllRoomBottomSheet(List<dynamic> roomList) async {
    if (_isRoomPickerSheetOpen) {
      return;
    }

    _isRoomPickerSheetOpen = true;
    final roomItems = _roomPickerItemsFor(roomList);
    final filteredRoomItemsNotifier = ValueNotifier<List<_RoomPickerItem>>(
      roomItems,
    );
    var normalizedSearchQuery = '';

    try {
      await _showElectricityBottomSheet<void>(
        backgroundColor: Colors.transparent,
        builder: (context) {
          final theme = Theme.of(context);
          final colorScheme = theme.colorScheme;

          return Material(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      '更改房间',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: '搜索房间名称或ID',
                        prefixIcon: Icon(
                          Icons.search,
                          size: 24,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        filled: true,
                        fillColor: colorScheme.surfaceContainerHighest,
                        hintStyle: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 14,
                        ),
                      ),
                      onChanged: (value) {
                        final nextSearchQuery = value.toLowerCase();
                        if (nextSearchQuery == normalizedSearchQuery) {
                          return;
                        }

                        normalizedSearchQuery = nextSearchQuery;
                        filteredRoomItemsNotifier.value =
                            _filterRoomPickerItems(roomItems, nextSearchQuery);
                      },
                    ),
                  ),
                  SizedBox(
                    height: 400,
                    child: ValueListenableBuilder<List<_RoomPickerItem>>(
                      valueListenable: filteredRoomItemsNotifier,
                      builder: (context, filteredRoomItems, _) {
                        return ListView.builder(
                          addAutomaticKeepAlives: false,
                          itemCount: filteredRoomItems.length,
                          itemBuilder: (BuildContext context, int index) {
                            final room = filteredRoomItems[index];
                            return ListTile(
                              leading: Icon(
                                Ionicons.shapes_outline,
                                color: colorScheme.primary,
                              ),
                              title: Text(room.name),
                              subtitle: Text(
                                room.id,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                              onTap: () async {
                                Navigator.of(context).pop();
                                await getNewRoomInfo(room.id);
                              },
                            );
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        },
      );
    } finally {
      filteredRoomItemsNotifier.dispose();
      _isRoomPickerSheetOpen = false;
    }
  }

  //显示预警设置
  // 显示添加设备页面(底部弹窗形式)
  Future<void> _showAlertBottomSheet() async {
    if (_isAlertSheetOpening) {
      return;
    }

    _isAlertSheetOpening = true;
    var isUpdatingAlertSettings = false;
    try {
      final alertSettings = await _loadAlertSettings();
      if (!mounted) {
        return;
      }

      var alertAmountDraft =
          alertSettings.isEnabled && alertSettings.bill > 0
              ? alertSettings.bill.toString()
              : '';
      await _showElectricityBottomSheet(
        backgroundColor: Colors.transparent,
        builder: (sheetContext) {
          final theme = Theme.of(sheetContext);
          final colorScheme = theme.colorScheme;
          final isDark = theme.brightness == Brightness.dark;
          final panelColor =
              isDark
                  ? colorScheme.surfaceContainerHigh
                  : colorScheme.surfaceContainerLow;
          final panelBorder = colorScheme.outlineVariant.withValues(
            alpha: isDark ? 0.42 : 0.72,
          );
          final accent = colorScheme.tertiary;

          return Material(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
                ),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: colorScheme.outlineVariant,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            '电费预警',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          initialValue: alertAmountDraft,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          onChanged: (value) {
                            alertAmountDraft = value;
                          },
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          decoration: InputDecoration(
                            hintText: '输入预警金额',
                            hintStyle: theme.textTheme.titleMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                            filled: true,
                            fillColor: panelColor,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            prefixIcon: Icon(
                              Ionicons.alert_circle_outline,
                              color: accent,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: panelBorder),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: panelBorder),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: accent.withValues(alpha: 0.92),
                                width: 1.4,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: FilledButton(
                            onPressed: () async {
                              final alertCount = alertAmountDraft.trim();
                              final validationMessage = _validateAlertAmount(
                                alertCount,
                              );
                              if (validationMessage != null) {
                                _showSnackBar(validationMessage);
                                return;
                              }
                              if (isUpdatingAlertSettings) {
                                return;
                              }

                              isUpdatingAlertSettings = true;
                              try {
                                await _saveAlertSettings(alertCount);
                                if (!sheetContext.mounted) {
                                  return;
                                }

                                Navigator.of(sheetContext).pop();
                                _showSnackBar(
                                  alertSettings.isEnabled ? '预警已更新' : '预警已开启',
                                );
                              } finally {
                                isUpdatingAlertSettings = false;
                              }
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: accent,
                              foregroundColor: colorScheme.onTertiary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Text(
                              alertSettings.isEnabled ? '更改预警' : '设置预警',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: colorScheme.onTertiary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        if (alertSettings.isEnabled) ...[
                          const SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: panelColor,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: panelBorder),
                            ),
                            child: Text(
                              '目前设置：\n当房间${alertSettings.roomName}${alertSettings.roomId.isEmpty ? '' : '（${alertSettings.roomId}）'}的电费低于${alertSettings.bill}元时进行提醒',
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: OutlinedButton(
                              onPressed: () async {
                                if (isUpdatingAlertSettings) {
                                  return;
                                }

                                isUpdatingAlertSettings = true;
                                try {
                                  await _disableAlertSettings();
                                  if (!sheetContext.mounted) {
                                    return;
                                  }

                                  Navigator.of(sheetContext).pop();
                                  _showSnackBar('预警已关闭');
                                } finally {
                                  isUpdatingAlertSettings = false;
                                }
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: accent,
                                side: BorderSide(
                                  color: accent.withValues(alpha: 0.42),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: const Text('关闭预警'),
                            ),
                          ),
                        ],
                        const SizedBox(height: 18),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: panelColor,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: panelBorder),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.info_outline, color: accent),
                                  const SizedBox(width: 8),
                                  Text(
                                    '温馨提示',
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '当检测到$setRoomName的电费小于预警值后，将会在进入工大盒子时进行提醒',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );
    } finally {
      _isAlertSheetOpening = false;
    }
  }

  BoxDecoration _buildSectionCardDecoration(
    BuildContext context, {
    required Color accent,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return BoxDecoration(
      color:
          isDark
              ? colorScheme.surfaceContainerHigh
              : colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: accent.withValues(alpha: isDark ? 0.26 : 0.12)),
      boxShadow: [
        if (!isDark)
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
      ],
    );
  }

  Widget _buildSectionBadge(
    BuildContext context, {
    required IconData icon,
    required Color accent,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: isDark ? 0.22 : 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: accent.withValues(alpha: isDark ? 0.26 : 0.18),
        ),
      ),
      child: Icon(icon, color: accent, size: 20),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color:
            isDark
                ? colorScheme.surfaceContainerLow
                : colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.72),
        ),
      ),
      child: ListTile(
        leading: _buildSectionBadge(
          context,
          icon: icon,
          accent: colorScheme.primary,
        ),
        title: Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        trailing:
            trailing ??
            Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
        onTap: onTap,
      ),
    );
  }

  Widget _buildFunctionItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return _buildActionTile(icon: icon, title: title, onTap: onTap);
  }
}

class _ElectricityAlertSettings {
  const _ElectricityAlertSettings({
    required this.isEnabled,
    required this.roomId,
    required this.roomName,
    required this.bill,
  });

  final bool isEnabled;
  final String roomId;
  final String roomName;
  final double bill;
}

class _ElectricityRoomInfoViewState {
  const _ElectricityRoomInfoViewState({
    required this.roomName,
    required this.roomCount,
    this.errorMessage,
  });

  final String roomName;
  final String roomCount;
  final String? errorMessage;
}

class _RoomPickerItem {
  const _RoomPickerItem({
    required this.name,
    required this.id,
    required this.normalizedName,
    required this.normalizedId,
  });

  final String name;
  final String id;
  final String normalizedName;
  final String normalizedId;
}

bool _hasValidAmountPrecision(String value) {
  var hasDigit = false;
  var integerDigits = 0;
  var hasDecimalPoint = false;
  var decimalDigits = 0;

  for (var index = 0; index < value.length; index++) {
    final codeUnit = value.codeUnitAt(index);
    if (_isAsciiDigit(codeUnit)) {
      hasDigit = true;
      if (hasDecimalPoint) {
        decimalDigits++;
        if (decimalDigits > 2) {
          return false;
        }
      } else {
        integerDigits++;
      }
      continue;
    }

    if (codeUnit == _asciiDecimalPoint) {
      if (hasDecimalPoint) {
        return false;
      }
      hasDecimalPoint = true;
      continue;
    }

    return false;
  }

  return hasDigit &&
      integerDigits > 0 &&
      (!hasDecimalPoint || decimalDigits > 0);
}

bool _isEditableAmountPrefix(String value) {
  var hasDecimalPoint = false;
  var decimalDigits = 0;

  for (var index = 0; index < value.length; index++) {
    final codeUnit = value.codeUnitAt(index);
    if (_isAsciiDigit(codeUnit)) {
      if (hasDecimalPoint) {
        decimalDigits++;
        if (decimalDigits > 2) {
          return false;
        }
      }
      continue;
    }

    if (codeUnit == _asciiDecimalPoint) {
      if (hasDecimalPoint) {
        return false;
      }
      hasDecimalPoint = true;
      continue;
    }

    return false;
  }

  return true;
}

bool _isAsciiDigit(int codeUnit) {
  return codeUnit >= _asciiZero && codeUnit <= _asciiNine;
}

class DecimalTextInputFormatter extends TextInputFormatter {
  const DecimalTextInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return _isEditableAmountPrefix(newValue.text) ? newValue : oldValue;
  }
}
