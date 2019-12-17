// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:scoped_model/scoped_model.dart';

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

class _CurveExplorerState extends State<CurveExplorer> {
  static const List<Offset> _initialControlPoints = const <Offset>[
    Offset(0.2, 0.25),
    Offset(0.33, 0.25),
    Offset(0.5, 1.0),
    Offset(0.8, 0.75),
  ];

  @override
  void initState() {
    super.initState();
    model = CatmullRomModel(controlPoints: _initialControlPoints, tension: 0.0);
  }

  CurveModel model;

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
              CurveModel curveModel = CurveModel.of(context);
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Graph(
                    min: 0.0,
                    max: 1.0,
                    majorTickColor: Colors.black,
                    minorTickColor: Colors.grey,
                    textStyle: Theme.of(context).textTheme.body1,
                    child: Stack(
                      fit: StackFit.expand,
                      children: <Widget>[
                        CurveDisplay(),
                        Positioned(child: ControlPolylineDisplay()),
                        Positioned(child: ControlPointDisplay()),
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

class CurveDisplay extends StatelessWidget {
  const CurveDisplay();

  @override
  Widget build(BuildContext context) {
    CurveModel curveModel = CurveModel.of(context);
    return CustomPaint(
      painter: CurvePainter(context: context, curve: curveModel.curve),
    );
  }
}

class CurvePainter extends CustomPainter {
  const CurvePainter({this.context, this.curve, this.resolution = 100, this.color = Colors.blueGrey, this.strokeWidth = 3.0})
      : assert(curve != null),
        assert(resolution != null);

  final BuildContext context;
  final Curve curve;
  final int resolution;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    CurveModel model = CurveModel.of(context);
    if (model.displaySize != size) {
      model.displaySize = size;
    }
    final Path path = Path();
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i <= resolution; ++i) {
      double t = i / resolution;
      double value = curve.transform(t);
      if (i == 0) {
        path.moveTo(t * size.width, (1.0 - value) * size.height);
      } else {
        path.lineTo(t * size.width, (1.0 - value) * size.height);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CurvePainter oldDelegate) {
    return curve != oldDelegate.curve || resolution != oldDelegate.resolution || color != oldDelegate.color || strokeWidth != oldDelegate.strokeWidth;
  }
}

class ControlPolylineDisplay extends StatefulWidget {
  const ControlPolylineDisplay();

  @override
  _ControlPolylineDisplayState createState() => _ControlPolylineDisplayState();
}

class _ControlPolylineDisplayState extends State<ControlPolylineDisplay> {
  Offset mousePosition;

  @override
  Widget build(BuildContext context) {
    CurveModel curveModel = CurveModel.of(context);
    return CustomPaint(
      painter: ControlPolylinePainter(
        controlPoints: <Offset>[
          Offset.zero,
          ...curveModel.controlPoints,
          const Offset(1.0, 1.0),
        ],
      ),
    );
  }
}

class ControlPolylinePainter extends CustomPainter {
  const ControlPolylinePainter({
    this.controlPoints,
    this.color = Colors.red,
    this.strokeWidth = 1.0,
  })  : assert(controlPoints != null),
        assert(color != null),
        assert(strokeWidth != null);

  final List<Offset> controlPoints;
  final Color color;
  final double strokeWidth;

  Offset transform(Offset point, Size size) {
    assert(point.dx <= 1.0 && point.dx >= 0.0);
    assert(point.dy <= 1.0 && point.dy >= 0.0);
    return Offset(point.dx * size.width, (1.0 - point.dy) * size.height);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final Path path = Path();
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    List<Offset> points = controlPoints.map<Offset>((Offset point) => transform(point, size)).toList();

    path.moveTo(points[0].dx, points[0].dy);
    for (int i = 1; i < controlPoints.length; ++i) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(ControlPolylinePainter oldDelegate) {
    return controlPoints != oldDelegate.controlPoints || color != oldDelegate.color || strokeWidth != oldDelegate.strokeWidth;
  }
}

class ControlPointDisplay extends StatefulWidget {
  const ControlPointDisplay();

  @override
  _ControlPointDisplayState createState() => _ControlPointDisplayState();
}

class _ControlPointDisplayState extends State<ControlPointDisplay> {
  List<bool> hovered = <bool>[];
  Offset lastMousePosition;
  Offset _panStart;

  @override
  Widget build(BuildContext context) {
    CurveModel curveModel = CurveModel.of(context);
    List<Offset> points = <Offset>[
      Offset.zero,
      ...curveModel.controlPoints,
      const Offset(1.0, 1.0),
    ];

    if (points.length != hovered.length) {
      hovered = List<bool>.generate(points.length, (int index) => false);
    }

    return GestureDetector(
      onTap: () {
        final int hoveredIndex = hovered.indexOf(true);
        print('hovered.length ${hovered.length} controls.length ${curveModel.controlPoints.length}');
        if (hoveredIndex == -1) {
          // Nothing hovered over.
          return;
        }
        final Offset controlPoint = points[hoveredIndex];
        if (curveModel.selectedPoints.contains(controlPoint)) {
          curveModel.removeFromSelection(controlPoint);
        } else {
          curveModel.addToSelection(controlPoint);
        }
      },
      onPanStart: (DragStartDetails details) {
        setState(() {
          _panStart = details.localPosition;
        });
      },
      onPanEnd: (DragEndDetails details) {
        setState(() {
          _panStart = null;
        });
      },
      onPanUpdate: (DragUpdateDetails details) {
        print('Dragging: $details');
        if (curveModel.selectedPoints.isEmpty) {
          return;
        }
        setState(() {
          final List<Offset> currentPoints = points.toList();
          final List<Offset> newPoints = <Offset>[];
          final Offset delta = details.localPosition - _panStart;
          final Offset parametricDelta = Offset(
            delta.dx / curveModel.displaySize.width,
            -delta.dy / curveModel.displaySize.height,
          );
          for (int i = 1; i < currentPoints.length - 1; ++i) {
            if (curveModel.selectedPoints.contains(currentPoints[i])) {
              newPoints.add(currentPoints[i] + parametricDelta);
            } else {
              newPoints.add(currentPoints[i]);
            }
          }
          bool updated = curveModel.attemptUpdate(newPoints);
          print('Updated model: $updated $newPoints');
        });
      },
      child: MouseRegion(
        onEnter: (PointerEnterEvent event) {
          setState(() {
            lastMousePosition = event.localPosition;
          });
        },
        onHover: (PointerHoverEvent event) {
          setState(() {
            lastMousePosition = event.localPosition;
          });
        },
        onExit: (PointerExitEvent event) {
          setState(() {
            lastMousePosition = null;
          });
        },
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            ...List<Widget>.generate(points.length, (int index) {
              final Offset point = points[index];
              return CustomPaint(
                painter: ControlPointPainter(
                  controlPoint: point,
                  index: index,
                  hover: hovered,
                  select: CurveModel.of(context).selectedPoints.contains(point),
                  mousePosition: lastMousePosition,
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
}

class ControlPointPainter extends CustomPainter {
  ControlPointPainter({
    this.controlPoint,
    this.color = Colors.red,
    this.hoverColor = Colors.red,
    this.selectColor = Colors.blue,
    this.strokeWidth = 1.0,
    this.radius = 4.0,
    this.hover,
    this.index,
    this.select = false,
    this.mousePosition,
  })  : assert(controlPoint != null),
        assert(color != null),
        assert(hoverColor != null),
        assert(selectColor != null),
        assert(strokeWidth != null),
        assert(radius != null),
        assert(hover != null),
        assert(select != null);

  final Offset controlPoint;
  final Color color;
  final Color hoverColor;
  final Color selectColor;
  final double strokeWidth;
  final double radius;
  final List<bool> hover;
  final bool select;
  final int index;
  Offset _lastPoint;
  final Offset mousePosition;

  Offset transform(Offset point, Size size) {
    assert(point.dx <= 1.0 && point.dx >= 0.0);
    assert(point.dy <= 1.0 && point.dy >= 0.0);
    return Offset(point.dx * size.width, (1.0 - point.dy) * size.height);
  }

  double get hitRadius => radius + 2;

  @override
  void paint(Canvas canvas, Size size) {
    _lastPoint = transform(controlPoint, size);
    if (mousePosition != null) {
      double distance = (_lastPoint - mousePosition).distance;
      hover[index] = distance < hitRadius;
    } else {
      hover[index] = false;
    }
    final Paint paint = Paint()
      ..color = (!hover[index] && !select) ? color : hover[index] ? hoverColor : selectColor
      ..strokeWidth = strokeWidth
      ..strokeJoin = StrokeJoin.round
      ..style = (hover[index] || select) ? PaintingStyle.fill : PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(_lastPoint, radius, paint);
  }

  @override
  bool hitTest(Offset position) {
    return (position - _lastPoint).distanceSquared < hitRadius * hitRadius;
  }

  @override
  bool shouldRepaint(ControlPointPainter oldDelegate) {
    return controlPoint != oldDelegate.controlPoint ||
        color != oldDelegate.color ||
        color != oldDelegate.hoverColor ||
        color != oldDelegate.selectColor ||
        select != oldDelegate.select ||
        hover != oldDelegate.hover ||
        strokeWidth != oldDelegate.strokeWidth;
  }
}
