// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:scoped_model/scoped_model.dart';

import 'animation_examples.dart';
import 'curve_display.dart';
import 'graph.dart';
import 'model.dart';

// Sets a platform override for desktop to avoid exceptions. See
// https://flutter.dev/desktop#target-platform-override for more info.
// TODO(gspencergoog): Remove once TargetPlatform includes all desktop platforms.
void _enablePlatformOverrideForDesktop() {
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
    debugDefaultTargetPlatformOverride = TargetPlatform.fuchsia;
  }
}

void main() {
  _enablePlatformOverrideForDesktop();
  runApp(CurveExplorer());
}

class CurveExplorer extends StatefulWidget {
  @override
  _CurveExplorerState createState() => _CurveExplorerState();
}

class _CurveExplorerState extends State<CurveExplorer> with SingleTickerProviderStateMixin {
  static const List<Offset> _initialControlPoints = const <Offset>[
    Offset(0.0, 0.0),
    Offset(0.25, 0.25),
    Offset(0.5, 0.5),
    Offset(0.75, 0.75),
    Offset(1.0, 1.0),
  ];

  @override
  void initState() {
    super.initState();
    duration = Duration(seconds: 1);
    model = CatmullRomModel(controlPoints: _initialControlPoints, tension: 0.0);
    controller = AnimationController(vsync: this, duration: duration);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  CurveModel model;
  AnimationController controller;
  Duration duration;
  Timer setDurationTimer;

  @override
  Widget build(BuildContext context) {
    return ScopedModel<CurveModel>(
      model: model,
      child: MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            title: const Text('Curve Explorer'),
          ),
          body: Builder(
            builder: (BuildContext context) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Expanded(
                        flex: 1,
                        child: Graph(
                          minX: 0.0,
                          maxX: 1.0,
                          majorTickColor: Colors.black,
                          minorTickColor: Colors.grey,
                          textStyle: Theme.of(context).textTheme.body1,
                          child: ScopedModelDescendant<CurveModel>(
                            builder: (context, child, model) {
                              return CurveDisplay(
                                animation: controller,
                              );
                            },
                          ),
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          PlayPauseButton(
                            animation: controller,
                            onPressed: (bool playing, bool bouncing) {
                              setState(() {
                                if (!playing) {
                                  controller.stop();
                                } else {
                                  controller.repeat(reverse: bouncing);
                                }
                              });
                            },
                          ),
                          ScopedModelDescendant<CurveModel>(
                            builder: (context, child, model) {
                              return AnimationExamples(
                                animation: CurvedAnimation(
                                  curve: model.curve,
                                  parent: controller,
                                ),
                              );
                            },
                          ),
                          SliderPanel(
                            configs: <SliderConfig>[
                              SliderConfig(
                                title: 'Duration',
                                label: '${duration.inMilliseconds}ms',
                                value: duration.inMilliseconds.toDouble(),
                                min: 10,
                                max: 5000,
                                divisions: 100,
                                onChanged: (double value) {
                                  if (duration.inMilliseconds.toDouble() == value) {
                                    return;
                                  }
                                  setState(() {
                                    setDurationTimer?.cancel();
                                    duration = Duration(milliseconds: value.round());
                                    controller.duration = duration;
                                    setDurationTimer = Timer(
                                      const Duration(milliseconds: 200),
                                      () {
                                        if (controller.isAnimating) {
                                          controller.stop();
                                          controller.repeat();
                                        }
                                        setDurationTimer = null;
                                      },
                                    );
                                  });
                                },
                              ),
                              SliderConfig(
                                title: 'Tension',
                                label: model.tension.toStringAsFixed(2),
                                value: model.tension,
                                onChanged: (double value) {
                                  setState(() {
                                    if (model.attemptUpdate(model.controlPoints, value)) {
                                      model.tension = value;
                                    }
                                  });
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class SliderConfig {
  const SliderConfig({
    this.title,
    this.value,
    this.label,
    this.onChanged,
    this.min = 0.0,
    this.max = 1.0,
    this.divisions,
  });

  final String label;
  final double value;
  final String title;
  final ValueChanged<double> onChanged;
  final double min;
  final double max;
  final int divisions;
}

class SliderPanel extends StatelessWidget {
  const SliderPanel({
    Key key,
    this.configs,
  }) : super(key: key);

  final List<SliderConfig> configs;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Table(
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        columnWidths: <int, TableColumnWidth>{
          0: FlexColumnWidth(),
          1: FlexColumnWidth(2.0),
          2: FlexColumnWidth(),
        },
        children: List<TableRow>.generate(configs.length, (int index) {
          return TableRow(
            children: <Widget>[
              Text(configs[index].title, textAlign: TextAlign.end,),
              Slider(
                min: configs[index].min,
                max: configs[index].max,
                divisions: configs[index].divisions,
                value: configs[index].value,
                onChanged: configs[index].onChanged,
              ),
              Text(configs[index].label, textAlign: TextAlign.start,),
            ],
          );
        }),
      ),
    );
  }
}
