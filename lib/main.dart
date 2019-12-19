// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

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
    model = CatmullRomModel(controlPoints: _initialControlPoints, tension: 0.0);
    controller = AnimationController(vsync: this, duration: const Duration(seconds: 5));
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  CurveModel model;
  AnimationController controller;

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
              return Focus(
                autofocus: true,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Slider(
                          value: model.tension,
                          min: 0.0,
                          max: 1.0,
                          onChanged: (double value) {
                            setState(() {
                              if (model.attemptUpdate(model.controlPoints, value)) {
                                model.tension = value;
                              }
                            });
                          },
                        ),
                        Expanded(
                          flex: 1,
                          child: Graph(
                            minX: 0.0,
                            maxX: 1.0,
                            majorTickColor: Colors.black,
                            minorTickColor: Colors.grey,
                            textStyle: Theme.of(context).textTheme.body1,
                            child: CurveDisplay(),
                          ),
                        ),
                        Row(
                          children: <Widget>[
                            PlayPauseButton(
                              animation: controller,
                              onPressed: () {
                                setState(() {
                                  if (controller.isAnimating) {
                                    controller.stop();
                                  } else {
                                    controller.forward();
                                  }
                                });
                              },
                            ),
                            AnimationExamples(animation: controller),
                          ],
                        ),
                      ],
                    ),
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
