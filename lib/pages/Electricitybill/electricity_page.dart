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
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text('电费充值'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Container(
        padding: EdgeInsets.fromLTRB(12, 0, 12, 0),
        child: ListView(
          children: [
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Colors.blue.shade100,
              ),
              child: EnhancedFutureBuilder(
                future: getHisRoomInfo(),
                rememberFutureResult: true,
                whenDone: (v) {
                  if (roomLoadErrorMessage != null) {
                    return Text(roomLoadErrorMessage!);
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Text(
                                setRoomName,
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            roomCount,
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          SizedBox(width: 5),
                          Text(
                            'CNY',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w100,
                              color: Colors.black.withAlpha(150),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
                whenNotDone: Center(
                  child: LoadingAnimationWidget.inkDrop(
                    color: Theme.of(context).primaryColor,
                    size: 40,
                  ),
                ),
              ),
            ),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Colors.green.shade100,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(
                            '通过校园卡充值',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  TextField(
                    controller: _paymentController,
                    keyboardType: TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: TextStyle(fontSize: 32, color: Colors.white),
                    maxLength: 10,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                      DecimalTextInputFormatter(),
                    ],
                    decoration: InputDecoration(
                      filled: false,
                      hintText: "输入充值金额",
                      border: InputBorder.none,
                      counterText: '',
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        '校园卡余额:',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.black,
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                      Text(
                        balance,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.normal,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: _handleChargePressed,
                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.all(
                        Colors.green.shade200,
                      ),
                      foregroundColor: WidgetStateProperty.all(Colors.white),
                      shape: WidgetStateProperty.all(
                        RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                    child:
                        isChargeLoading
                            ? LoadingAnimationWidget.inkDrop(
                              color: Colors.white,
                              size: 10,
                            )
                            : Text('充值'),
                  ),
                ],
              ),
            ),
            SizedBox(height: 12),
            Container(
              margin: EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListTile(
                leading: Icon(
                  Ionicons.grid_outline,
                  color: Theme.of(context).primaryColor,
                ),
                title: Text(
                  "更改充值房间",
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                trailing:
                    isRoomLoading
                        ? LoadingAnimationWidget.inkDrop(
                          color: Theme.of(context).primaryColor,
                          size: 20,
                        )
                        : Icon(Icons.chevron_right, color: Colors.grey),
                onTap: _handleRoomPickerPressed,
              ),
            ),
            _buildFunctionItem(
              icon: Ionicons.alert_circle_outline,
              title: "电费预警",
              onTap: _showAlertBottomSheet,
            ),
          ],
        ),
      ),
    );
  }

  // 显示所有充值房间
  void _showAllRoomBottomSheet(List<dynamic> roomList) {
    String searchQuery = ""; // 搜索关键词状态

    showCupertinoModalBottomSheet(
      context: context,
      expand: false,
      backgroundColor: Colors.transparent,
      builder:
          (context) => StatefulBuilder(
            // 使用 StatefulBuilder 管理搜索状态
            builder: (context, setState) {
              // 根据搜索词过滤房间列表
              final filteredRooms =
                  roomList.whereType<Map<dynamic, dynamic>>().where((room) {
                    final name = room['acname'].toString().toLowerCase();
                    final guid = room['acguid'].toString().toLowerCase();
                    final query = searchQuery.toLowerCase();
                    return name.contains(query) || guid.contains(query);
                  }).toList();

              return Material(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(15),
                  topRight: Radius.circular(15),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 顶部拖动指示条
                      Container(
                        width: 40,
                        height: 4,
                        margin: EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),

                      // 标题
                      Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          '更改房间',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                      // 搜索框
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: '搜索房间名称或ID',
                            prefixIcon: Icon(Icons.search, size: 24),
                            filled: true,
                            fillColor: Colors.grey.withAlpha(20),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: EdgeInsets.symmetric(vertical: 14),
                          ),
                          onChanged:
                              (value) => setState(() => searchQuery = value),
                        ),
                      ),

                      // 房间列表
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
                                color: Colors.blue,
                              ),
                              title: Text(roomName),
                              //subtitle: Text(room['acguid']),
                              onTap: () async {
                                Navigator.of(context).pop();
                                await getNewRoomInfo(roomId);
                              },
                            );
                          },
                        ),
                      ),

                      SizedBox(height: 20),
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
      builder:
          (sheetContext) => Material(
            color: Theme.of(sheetContext).colorScheme.surface,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(15),
              topRight: Radius.circular(15),
            ),
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
                ),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 40,
                          height: 4,
                          margin: EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            '电费预警',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        SizedBox(height: 5),
                        // 输入框
                        TextField(
                          controller: deviceCodeController,
                          decoration: InputDecoration(
                            hintText: '输入预警金额',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.white.withAlpha(20),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            prefixIcon: Icon(
                              Ionicons.alert_circle_outline,
                              color: Colors.orange,
                            ),
                          ),
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          style: TextStyle(fontSize: 18),
                        ),
                        SizedBox(height: 20),

                        // 提交按钮
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: () async {
                              final alertCount =
                                  deviceCodeController.text.trim();
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
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              alertSettings.isEnabled ? '更改预警' : '设置预警',
                              style: TextStyle(fontSize: 18),
                            ),
                          ),
                        ),
                        Visibility(
                          visible: alertSettings.isEnabled,
                          child: Column(
                            children: [
                              Card(
                                elevation: 0,
                                color: Colors.transparent,
                                child: Container(
                                  padding: EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withAlpha(20),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      SizedBox(height: 8),
                                      Text(
                                        '目前设置：\n当房间${alertSettings.roomName}${alertSettings.roomId.isEmpty ? '' : '（${alertSettings.roomId}）'}的电费低于${alertSettings.bill}元时进行提醒',
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton(
                                  onPressed: () async {
                                    await _disableAlertSettings();
                                    if (!sheetContext.mounted) {
                                      return;
                                    }

                                    Navigator.of(sheetContext).pop();
                                    _showSnackBar('预警已关闭');
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.orange,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: Text(
                                    '关闭预警',
                                    style: TextStyle(fontSize: 18),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // 提示信息
                        SizedBox(height: 20),
                        Card(
                          elevation: 0,
                          color: Colors.transparent,
                          child: Container(
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(20),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.info_outline,
                                      color: Colors.orange,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      '温馨提示',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 8),
                                Text(
                                  '当检测到$setRoomName的电费小于预警值后，将会在进入工大盒子时进行提醒',
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
    );
    deviceCodeController.dispose();
  }

  Widget _buildFunctionItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).primaryColor),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.w500)),
        trailing: Icon(Icons.chevron_right, color: Colors.grey),
        onTap: onTap,
      ),
    );
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
