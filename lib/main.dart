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
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 1));
    model = CatmullRomModel(controller: _controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  CurveModel model;
  AnimationController _controller;

  @override
  Widget build(BuildContext context) {
    return ScopedModel<CurveModel>(
      model: model,
      child: MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            title: const Text('Curve Explorer'),
          ),
          floatingActionButton: FloatingActionButton(
            child: Icon(Icons.refresh),
            onPressed: () {
              model.reset();
            },
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
                                animation: model.controller,
                              );
                            },
                          ),
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          ScopedModelDescendant<CurveModel>(
                            builder: (context, child, model) {
                              return PlayPauseButton(
                                animation: model.controller,
                                bounce: model.bounce,
                                onPressed: (bool playing, bool bouncing) {
                                  setState(() {
                                    model.bounce = bouncing;
                                    if (playing) {
                                      model.play();
                                    } else {
                                      model.pause();
                                    }
                                  });
                                },
                              );
                            },
                          ),
                          ScopedModelDescendant<CurveModel>(
                            builder: (context, child, model) {
                              return AnimationExamples(
                                animation: CurvedAnimation(
                                  curve: model.curve,
                                  parent: model.controller,
                                ),
                              );
                            },
                          ),
                          ScopedModelDescendant<CurveModel>(builder: (context, child, model) {
                            return SliderPanel(
                              configs: <SliderConfig>[
                                SliderConfig(
                                  title: 'Duration',
                                  label: '${model.duration.inMilliseconds}ms',
                                  value: model.duration.inMilliseconds.toDouble(),
                                  min: 10,
                                  max: 5000,
                                  divisions: 100,
                                  onChanged: (double value) {
                                    setState(() {
                                      model.duration = Duration(milliseconds: value.round());
                                    });
                                  },
                                ),
                                SliderConfig(
                                  title: 'Tension',
                                  label: model.tension.toStringAsFixed(2),
                                  value: model.tension,
                                  onChanged: (double value) {
                                    setState(() {
                                      model.attemptUpdate(model.controlPoints, value);
                                    });
                                  },
                                ),
                              ],
                            );
                          }),
                        ],
                      ),
                      CodeDisplay(),
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
              Text(
                configs[index].title,
                textAlign: TextAlign.end,
              ),
              Slider(
                min: configs[index].min,
                max: configs[index].max,
                divisions: configs[index].divisions,
                value: configs[index].value,
                onChanged: configs[index].onChanged,
              ),
              Text(
                configs[index].label,
                textAlign: TextAlign.start,
              ),
            ],
          );
        }),
      ),
    );
  }
}

class CodeDisplay extends StatelessWidget {
  static const TextStyle type = TextStyle(
    color: Colors.green,
    fontFamily: 'FiraCodeBold',
    fontWeight: FontWeight.bold,
    fontSize: 12.0,
  );

  static const TextStyle value = TextStyle(
    color: Colors.black87,
    fontFamily: 'FiraCode',
    fontSize: 12.0,
  );

  static const TextStyle argument = TextStyle(
    color: Colors.blueAccent,
    fontFamily: 'FiraCodeBold',
    fontWeight: FontWeight.bold,
    fontSize: 12.0,
  );

  static const TextStyle punctuation = TextStyle(
    color: Colors.black54,
    fontFamily: 'FiraCodeLight',
    fontSize: 12.0,
  );

  @override
  Widget build(BuildContext context) {
    return ScopedModelDescendant<CurveModel>(
      builder: (context, child, model) {
        TextSpan span = TextSpan(
          children: <TextSpan>[
            TextSpan(text: '$CatmullRomCurve', style: type),
            TextSpan(text: '(<', style: punctuation),
            TextSpan(text: '$Offset', style: type),
            TextSpan(text: '>[', style: punctuation),
            ...List<TextSpan>.generate(model.controlPoints.length, (int index) {
              final Offset point = model.controlPoints[index];
              return TextSpan(children: <TextSpan>[
                TextSpan(text: 'Offset', style: type),
                TextSpan(text: '(', style: punctuation),
                TextSpan(text: '${point.dx.toStringAsFixed(2)}', style: value),
                TextSpan(text: ', ', style: punctuation),
                TextSpan(text: '${point.dy.toStringAsFixed(2)}', style: value),
                TextSpan(text: ')', style: punctuation),
                if (index != model.controlPoints.length - 1) TextSpan(text: ', ', style: punctuation),
              ]);
            }),
            TextSpan(text: '], ', style: punctuation),
            TextSpan(text: 'tension: ', style: argument),
            TextSpan(text: '${model.tension.toStringAsFixed(2)}', style: value),
            TextSpan(text: ');', style: punctuation),
          ],
        );

        return SelectableText.rich(
          span,
        );
      },
    );
  }
}
