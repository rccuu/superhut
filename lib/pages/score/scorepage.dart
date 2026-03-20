import 'dart:async';

import 'package:enhanced_future_builder/enhanced_future_builder.dart';
import 'package:flutter/material.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:superhut/pages/score/logic.dart';

import '../../core/services/app_logger.dart';

class ScorePage extends StatefulWidget {
  const ScorePage({super.key});

  @override
  State<ScorePage> createState() => _ScorePageState();
}

class _ScorePageState extends State<ScorePage> {
  List<String> semesterId = [];
  String nowSemesterId = "all";
  List<Score> scoreList = [];
  String zxf = '-';
  String zxfjd = '-';
  String pjjd = '-';
  String selectedId = "all";
  bool first = true;
  String? _errorMessage;
  final Map<String, ScoreLoadResult> _scoreCache = <String, ScoreLoadResult>{};
  bool _isSemesterProbeStarted = false;

  void _showLoadingDialog() {
    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (context) {
        return PopScope(
          canPop: false,
          child: Dialog(
            backgroundColor: Colors.transparent,
            child: LoadingAnimationWidget.inkDrop(
              color: Theme.of(context).primaryColor,
              size: 40,
            ),
          ),
        );
      },
    );
  }

  void _applyScoreData(ScoreLoadResult scoreData, {String? semesterId}) {
    setState(() {
      if (semesterId != null) {
        selectedId = semesterId;
      }
      scoreList = scoreData.achievement;
      zxf = scoreData.yxzxf;
      zxfjd = scoreData.zxfjd;
      pjjd = scoreData.pjxfjd;
      _errorMessage = scoreData.errorMessage;
    });
  }

  Future<void> _refreshScoresForSelection(String semesterId) async {
    final cached = _scoreCache[semesterId];
    if (cached != null) {
      _applyScoreData(cached, semesterId: semesterId);
      return;
    }

    final navigator = Navigator.of(context);
    _showLoadingDialog();

    final scoreData = await _loadScoreForSemester(semesterId);
    if (!mounted) {
      return;
    }

    navigator.pop(true);
    _applyScoreData(scoreData, semesterId: semesterId);
  }

  Future<ScoreLoadResult> _loadScoreForSemester(String semesterId) async {
    final cached = _scoreCache[semesterId];
    if (cached != null) {
      return cached;
    }

    final scoreData = await getScore(semesterId == "all" ? "" : semesterId);
    _scoreCache[semesterId] = scoreData;
    return scoreData;
  }

  Future<List<String>> _filterSemestersWithScores(
    List<String> semesterIds,
  ) async {
    final availableSemesterIds = <String>[];

    for (final semester in semesterIds) {
      final scoreData = await _loadScoreForSemester(semester);
      if (scoreData.errorMessage != null) {
        AppLogger.debug(
          'Failed to probe score data for semester $semester, keeping full semester list.',
        );
        return semesterIds;
      }
      if (scoreData.achievement.isNotEmpty) {
        availableSemesterIds.add(semester);
      }
    }

    return availableSemesterIds;
  }

  Future<void> _probeAvailableSemesters(List<String> semesterIds) async {
    if (_isSemesterProbeStarted) {
      return;
    }
    _isSemesterProbeStarted = true;

    final filteredSemesterIds = await _filterSemestersWithScores(semesterIds);
    if (!mounted) {
      return;
    }

    final shouldResetSelection =
        selectedId != "all" && !filteredSemesterIds.contains(selectedId);

    setState(() {
      semesterId = filteredSemesterIds;
      if (shouldResetSelection) {
        selectedId = "all";
      }
    });

    if (!shouldResetSelection) {
      return;
    }

    final allScoreData = await _loadScoreForSemester("all");
    if (!mounted) {
      return;
    }
    _applyScoreData(allScoreData, semesterId: "all");
  }

  Future<void> getTimeList() async {
    if (first) {
      final timeData = await semesterIdfc();
      if (!mounted) {
        return;
      }
      setState(() {
        semesterId = timeData.idList;
        nowSemesterId = timeData.nowId.isEmpty ? "all" : timeData.nowId;
        _errorMessage = timeData.errorMessage;
        selectedId = "all";
      });
      if (timeData.errorMessage != null) {
        first = false;
        return;
      }

      final scoreData = await _loadScoreForSemester("all");
      if (!mounted) {
        return;
      }

      _applyScoreData(scoreData, semesterId: "all");
      unawaited(_probeAvailableSemesters(timeData.idList));
      first = false;
    } else {
      return;
    }
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return EnhancedFutureBuilder(
      future: getTimeList(),
      rememberFutureResult: true,
      whenDone: (da) {
        return Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surface,
          appBar: AppBar(
            title: Text("成绩查询"),
            actions: [
              DropdownButton(
                onChanged: (v) async {
                  final targetSemesterId = v.toString();
                  setState(() {
                    selectedId = targetSemesterId;
                  });
                  await _refreshScoresForSelection(targetSemesterId);
                },
                borderRadius: BorderRadius.circular(10),
                menuWidth: 150,
                alignment: Alignment.centerRight,
                enableFeedback: true,
                isExpanded: false,
                value: selectedId,
                underline: Container(height: 0),
                items: [
                  DropdownMenuItem(value: "all", child: Text("全部")),
                  ...semesterId.map(
                    (e) => DropdownMenuItem(value: e, child: Text(e)),
                  ),
                ],
              ),
            ],
          ),
          body: Container(
            margin: EdgeInsets.only(left: 10, right: 10),
            child: ListView(
              children: [
                _buildTopCard(),
                const SizedBox(height: 10),
                if (_errorMessage != null)
                  Center(child: Text(_errorMessage!))
                else if (scoreList.isEmpty)
                  Center(
                    child: Text(selectedId == "all" ? "暂未查询到成绩记录" : "当前学期没有成绩"),
                  )
                else
                  ...List.generate(scoreList.length, (index) {
                    final score = scoreList[index];
                    return Card.filled(
                      color: Theme.of(context).colorScheme.surfaceContainer,
                      child: Padding(
                        padding: EdgeInsets.all(10),
                        child: Flex(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          direction: Axis.horizontal,
                          children: [
                            Expanded(
                              flex: 10,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    score.courseName,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color:
                                          Theme.of(
                                            context,
                                          ).colorScheme.onSurface,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      Chip(
                                        label: Text(
                                          score.courseNature,
                                          style: TextStyle(fontSize: 12),
                                        ),
                                        backgroundColor:
                                            Theme.of(
                                              context,
                                            ).colorScheme.surface,
                                        padding: EdgeInsets.symmetric(
                                          vertical: 0,
                                          horizontal: 0,
                                        ),
                                      ),
                                      SizedBox(width: 5),
                                      Chip(
                                        label: Text(
                                          "绩点:${score.gradePoints}",
                                          style: TextStyle(fontSize: 12),
                                        ),
                                        backgroundColor:
                                            Theme.of(
                                              context,
                                            ).colorScheme.surface,
                                        padding: EdgeInsets.symmetric(
                                          vertical: 0,
                                          horizontal: 0,
                                        ),
                                      ),
                                      SizedBox(width: 5),
                                      Chip(
                                        label: Text(
                                          "学分:${score.credit}",
                                          style: TextStyle(fontSize: 12),
                                        ),
                                        backgroundColor:
                                            Theme.of(
                                              context,
                                            ).colorScheme.surface,
                                        padding: EdgeInsets.symmetric(
                                          vertical: 0,
                                          horizontal: 0,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Padding(
                                padding: EdgeInsets.only(right: 10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      score.fraction,
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color:
                                            Theme.of(
                                              context,
                                            ).colorScheme.onSurface,
                                      ),
                                    ),
                                    Text(
                                      score.state,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color:
                                            Theme.of(
                                              context,
                                            ).colorScheme.onSurface,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ),
        );
      },
      whenNotDone: Scaffold(
        appBar: AppBar(title: Text("成绩查询")),
        body: Center(
          child: LoadingAnimationWidget.inkDrop(
            color: Theme.of(context).primaryColor,
            size: 40,
          ),
        ),
      ),
    );
  }

  Widget _buildTopCard() {
    final colorScheme = Theme.of(context).colorScheme;
    final titleColor = colorScheme.onSurface;
    final labelColor = colorScheme.onSurfaceVariant;
    final valueColor = colorScheme.onSurface;

    return Card.filled(
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 10, 20, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "成绩汇总",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: titleColor,
              ),
            ),
            SizedBox(height: 10),
            Flex(
              direction: Axis.horizontal,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Text("已修总学分", style: TextStyle(color: labelColor)),
                      Text(
                        zxf,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: valueColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text("总学分绩点", style: TextStyle(color: labelColor)),
                      Text(
                        zxfjd,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: valueColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text("平均学分绩点", style: TextStyle(color: labelColor)),
                      Text(
                        pjjd,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: valueColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
