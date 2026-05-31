import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../generated/assets.dart';
import '../../core/ui/app_snack_bar.dart';
import 'command.dart';

class HutLoginPage extends StatefulWidget {
  const HutLoginPage({super.key, this.command});

  final HutLoginCommand? command;

  @override
  State<HutLoginPage> createState() => _HutLoginPageState();
}

class _HutLoginPageState extends State<HutLoginPage> {
  final TextEditingController _userNoController = TextEditingController();
  final TextEditingController _pwdController = TextEditingController();
  late final HutLoginCommand _command;

  @override
  void initState() {
    super.initState();
    _command = widget.command ?? HutLoginCommand();
  }

  @override
  void dispose() {
    _userNoController.dispose();
    _pwdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).cardColor,
      resizeToAvoidBottomInset: true,
      body: Padding(
        padding: const EdgeInsets.all(0),
        child: Stack(
          children: [
            Container(
              width: 1000,
              height: 400,
              color: Theme.of(context).secondaryHeaderColor,
              padding: EdgeInsets.only(top: 200, right: 20, left: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "智慧工大登录",
                    style: TextStyle(
                      fontSize: 35,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  Text(
                    "使用智慧工大账号继续",
                    style: TextStyle(
                      // fontSize: 35,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                ],
              ),
            ),
            MediaQuery.removePadding(
              context: context,
              removeTop: true,
              child: ListView(
                children: [
                  Container(
                    margin: EdgeInsets.only(top: 200),
                    child: Stack(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(20),
                              topRight: Radius.circular(20),
                            ),
                          ),
                          margin: EdgeInsets.only(top: 100),
                          padding: EdgeInsets.only(
                            top: 40,
                            right: 20,
                            left: 20,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "账号登录",
                                style: TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).primaryColor,
                                ),
                              ),
                              SizedBox(height: 10),
                              Container(
                                width: 400,
                                padding: EdgeInsets.fromLTRB(10, 0, 10, 0),
                                //      margin: EdgeInsets.only(left: 5,right: 5),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(15),
                                  color: Theme.of(context).highlightColor,
                                ),
                                child: TextField(
                                  keyboardType: TextInputType.number,
                                  style: TextStyle(fontSize: 18),
                                  maxLength: 13,
                                  decoration: InputDecoration(
                                    filled: false,
                                    hintText: "学号/手机号",
                                    border: InputBorder.none,
                                    counterText: '',
                                  ),
                                  controller: _userNoController,
                                ),
                              ),
                              SizedBox(height: 10),
                              Container(
                                width: 400,
                                padding: EdgeInsets.fromLTRB(10, 0, 10, 0),
                                //      margin: EdgeInsets.only(left: 5,right: 5),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(15),
                                  color: Theme.of(context).highlightColor,
                                ),
                                child: Flex(
                                  direction: Axis.horizontal,
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        style: TextStyle(fontSize: 18),
                                        maxLength: 40,
                                        decoration: InputDecoration(
                                          filled: false,
                                          hintText: "密码",
                                          border: InputBorder.none,
                                          counterText: '',
                                        ),
                                        controller: _pwdController,
                                        obscureText: false,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 20),
                              Flex(
                                direction: Axis.horizontal,
                                children: [
                                  Expanded(
                                    child: FilledButton(
                                      onPressed: () {
                                        if (_userNoController.text.isEmpty ||
                                            _pwdController.text.isEmpty) {
                                          showAppSnackBar(
                                            context,
                                            message: '请输入学号/手机号和密码',
                                            type: AppSnackBarType.warning,
                                          );
                                          return;
                                        }
                                        //SendMessageCode(context, _userNoController.text, _pwdController.text);
                                        unawaited(
                                          _command.loginToHuT(
                                            _userNoController.text,
                                            _pwdController.text,
                                            context,
                                          ),
                                        );
                                      },
                                      child: const Text('登录并继续'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.only(right: 20),
                          alignment: Alignment.topRight,
                          margin: EdgeInsets.only(top: 0),
                          child: SvgPicture.asset(
                            Assets.illustrationLogin,
                            width: 150,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
