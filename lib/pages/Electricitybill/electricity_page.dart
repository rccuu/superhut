import 'package:enhanced_future_builder/enhanced_future_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ionicons/ionicons.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/services/app_logger.dart';
import '../../utils/hut_user_api.dart';
import 'electricity_api.dart';

class ElectricityPage extends StatefulWidget {
  const ElectricityPage({super.key});

  @override
  State<ElectricityPage> createState() => _ElectricityPageState();
}

class _ElectricityPageState extends State<ElectricityPage> {
  static const double _maxRechargeAmount = 10000;
  static final RegExp _amountPattern = RegExp(r'^\d+(\.\d{1,2})?$');

  String setRoomName = "未知房间";
  String nowRoomId = '';
  String roomCount = '-';
  final ElectricityApi electricityApi = ElectricityApi();
  Map<String, dynamic> baseInfo = {};
  Map<String, dynamic> nowRoomInfo = {};
  final hutUserApi = HutUserApi();
  String balance = "-";
  bool isRoomLoading = false, isinit = false;
  bool isChargeLoading = false;
  String? roomLoadErrorMessage;
  final TextEditingController _paymentController = TextEditingController();

  @override
  void dispose() {
    _paymentController.dispose();
    super.dispose();
  }

  /// 获取余额

  @override
  void initState() {
    super.initState();
    getBalance();
  }

  Future<void> getBalance() async {
    try {
      final cardBalance = await hutUserApi.getCardBalance();
      if (!mounted) {
        return;
      }

      setState(() {
        balance = cardBalance;
      });
    } catch (error, stackTrace) {
      AppLogger.error(
        'Failed to load card balance on electricity page',
        error: error,
        stackTrace: stackTrace,
      );
      if (!mounted) {
        return;
      }

      setState(() {
        balance = '-';
      });
    }
  }

  Future<bool> getHisRoomInfo() async {
    if (isinit) {
      return true;
    }

    try {
      await electricityApi.onInit();
      final history = Map<String, dynamic>.from(
        await electricityApi.getHistory(),
      );
      final roomInfo = Map<String, dynamic>.from(
        await electricityApi.getSingleRoomInfo(history['roomid'].toString()),
      );
      if (!mounted) {
        return false;
      }

      setState(() {
        baseInfo = history;
        nowRoomInfo = roomInfo;
        setRoomName = roomInfo['roomName'].toString();
        roomCount = roomInfo['eleTail'].toString();
        nowRoomId = history['roomid'].toString();
        roomLoadErrorMessage = null;
        isinit = true;
      });
      return true;
    } catch (error, stackTrace) {
      AppLogger.error(
        'Failed to load electricity room info',
        error: error,
        stackTrace: stackTrace,
      );
      if (!mounted) {
        return false;
      }

      setState(() {
        roomLoadErrorMessage = error.toString().replaceFirst('Bad state: ', '');
      });
      return false;
    }
  }

  Future<bool> getNewRoomInfo(String roomId) async {
    final roomInfo = Map<String, dynamic>.from(
      await electricityApi.getSingleRoomInfo(roomId),
    );
    if (!mounted) {
      return false;
    }

    setState(() {
      nowRoomInfo = roomInfo;
      setRoomName = roomInfo['roomName'].toString();
      roomCount = roomInfo['eleTail'].toString();
      nowRoomId = roomId;
      roomLoadErrorMessage = null;
    });
    return true;
  }

  Future<List<dynamic>> getRoomList() async {
    return electricityApi.getRoomList();
  }

  void _showSnackBar(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
    if (!_amountPattern.hasMatch(paymentText)) {
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
    if (!_amountPattern.hasMatch(amountText)) {
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
    await Future.wait([getNewRoomInfo(roomToChargeId), getBalance()]);
    _paymentController.clear();
    _showSnackBar('电费充值成功');
    return true;
  }

  Future<void> _handleChargePressed() async {
    if (isChargeLoading) {
      return;
    }

    final payment = _paymentController.text.trim();
    final validationMessage = _validatePaymentInput(payment);
    if (validationMessage != null) {
      _showSnackBar(validationMessage);
      return;
    }

    setState(() {
      isChargeLoading = true;
    });

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
      if (mounted) {
        setState(() {
          isChargeLoading = false;
        });
      }
    }
  }

  Future<void> _handleRoomPickerPressed() async {
    if (isRoomLoading) {
      return;
    }

    setState(() {
      isRoomLoading = true;
    });

    try {
      final roomList = await getRoomList();
      if (!mounted) {
        return;
      }

      _showAllRoomBottomSheet(roomList);
    } catch (error, stackTrace) {
      AppLogger.error(
        'Failed to load electricity room list',
        error: error,
        stackTrace: stackTrace,
      );
      _showSnackBar('房间列表加载失败，请稍后重试');
    } finally {
      if (mounted) {
        setState(() {
          isRoomLoading = false;
        });
      }
    }
  }

  Future<void> _saveAlertSettings(String alertAmount) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('enableBillWarning', true);
    await prefs.setString('enableRoomId', nowRoomId);
    await prefs.setString('enableRoomName', setRoomName);
    await prefs.setDouble('enableBill', double.parse(alertAmount));
  }

  Future<void> _disableAlertSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('enableBillWarning', false);
  }

  Future<_ElectricityAlertSettings> _loadAlertSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return _ElectricityAlertSettings(
      isEnabled: prefs.getBool('enableBillWarning') ?? false,
      roomId: prefs.getString('enableRoomId') ?? '',
      roomName: prefs.getString('enableRoomName') ?? '',
      bill: prefs.getDouble('enableBill') ?? 0,
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
                future: getHisRoomInfo(),
                rememberFutureResult: true,
                whenDone: (v) {
                  if (roomLoadErrorMessage != null) {
                    return Text(
                      roomLoadErrorMessage!,
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
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    color: mutedForeground,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  setRoomName,
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
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Flexible(
                            child: Text(
                              roomCount,
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
                whenNotDone: Center(
                  child: LoadingAnimationWidget.inkDrop(
                    color: roomAccent,
                    size: 40,
                  ),
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
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                      DecimalTextInputFormatter(),
                    ],
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
                  Container(
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
                        Text(
                          '校园卡余额',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: mutedForeground,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          balance,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: cardForeground,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: isChargeLoading ? null : _handleChargePressed,
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
                              ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: colorScheme.onSecondary,
                                ),
                              )
                              : const Text('充值'),
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
              trailing:
                  isRoomLoading
                      ? LoadingAnimationWidget.inkDrop(
                        color: colorScheme.primary,
                        size: 20,
                      )
                      : Icon(
                        Icons.chevron_right,
                        color: colorScheme.onSurfaceVariant,
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
  void _showAllRoomBottomSheet(List<dynamic> roomList) {
    String searchQuery = '';

    showCupertinoModalBottomSheet(
      context: context,
      expand: false,
      backgroundColor: Colors.transparent,
      builder:
          (context) => StatefulBuilder(
            builder: (context, setState) {
              final theme = Theme.of(context);
              final colorScheme = theme.colorScheme;
              final filteredRooms =
                  roomList.whereType<Map<dynamic, dynamic>>().where((room) {
                    final name = room['acname'].toString().toLowerCase();
                    final guid = room['acguid'].toString().toLowerCase();
                    final query = searchQuery.toLowerCase();
                    return name.contains(query) || guid.contains(query);
                  }).toList();

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
                          onChanged:
                              (value) => setState(() => searchQuery = value),
                        ),
                      ),
                      SizedBox(
                        height: 400,
                        child: ListView.builder(
                          itemCount: filteredRooms.length,
                          itemBuilder: (BuildContext context, int index) {
                            final room = filteredRooms[index];
                            final roomName = room['acname'].toString();
                            final roomId = room['acguid'].toString();
                            return ListTile(
                              leading: Icon(
                                Ionicons.shapes_outline,
                                color: colorScheme.primary,
                              ),
                              title: Text(roomName),
                              subtitle: Text(
                                roomId,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                              onTap: () async {
                                Navigator.of(context).pop();
                                await getNewRoomInfo(roomId);
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
          ),
    );
  }

  //显示预警设置
  // 显示添加设备页面(底部弹窗形式)
  Future<void> _showAlertBottomSheet() async {
    final alertSettings = await _loadAlertSettings();
    if (!mounted) {
      return;
    }

    final TextEditingController deviceCodeController = TextEditingController(
      text:
          alertSettings.isEnabled && alertSettings.bill > 0
              ? alertSettings.bill.toString()
              : '',
    );
    await showCupertinoModalBottomSheet(
      context: context,
      expand: false,
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
                      TextField(
                        controller: deviceCodeController,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
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
                            final alertCount = deviceCodeController.text.trim();
                            final validationMessage = _validateAlertAmount(
                              alertCount,
                            );
                            if (validationMessage != null) {
                              _showSnackBar(validationMessage);
                              return;
                            }

                            await _saveAlertSettings(alertCount);
                            if (!sheetContext.mounted) {
                              return;
                            }

                            Navigator.of(sheetContext).pop();
                            _showSnackBar(
                              alertSettings.isEnabled ? '预警已更新' : '预警已开启',
                            );
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
                              await _disableAlertSettings();
                              if (!sheetContext.mounted) {
                                return;
                              }

                              Navigator.of(sheetContext).pop();
                              _showSnackBar('预警已关闭');
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
    deviceCodeController.dispose();
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

class DecimalTextInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final regex = RegExp(r'^(\d+)?\.?\d{0,2}');
    final String newString = regex.stringMatch(newValue.text) ?? '';
    return newString == newValue.text ? newValue : oldValue;
  }
}
