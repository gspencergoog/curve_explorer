// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';
import 'dart:math' as math;

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
    return ScopedModelDescendant<CurveModel>(
      builder: (context, child, model) => CustomPaint(
        painter: CurvePainter(context: context),
      ),
    );
  }
}

class CurvePainter extends CustomPainter {
  const CurvePainter({this.context, this.resolution = 100, this.color = Colors.blueGrey, this.strokeWidth = 3.0}) : assert(resolution != null);

  final BuildContext context;
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

    CatmullRomCurve curve = model.curve;
    List<Offset> points = curve.valueSpline.generateSamples(
      start: curve.valueSpline.findInverse(0.0),
      end: curve.valueSpline.findInverse(1.0),
    );
    for (int i = 0; i < points.length; ++i) {
      Offset point = points[i];
      if (i == 0) {
        path.moveTo(point.dx * size.width, (1.0 - point.dy) * size.height);
      } else {
        path.lineTo(point.dx * size.width, (1.0 - point.dy) * size.height);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CurvePainter oldDelegate) {
    return resolution != oldDelegate.resolution || color != oldDelegate.color || strokeWidth != oldDelegate.strokeWidth;
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
    return ScopedModelDescendant<CurveModel>(
      builder: (context, child, model) => CustomPaint(
        painter: ControlPolylinePainter(curveModel: model),
      ),
    );
  }
}

class ControlPolylinePainter extends CustomPainter {
  const ControlPolylinePainter({
    this.curveModel,
    this.color = Colors.red,
    this.strokeWidth = 1.0,
  })  : assert(curveModel != null),
        assert(color != null),
        assert(strokeWidth != null);

  final CurveModel curveModel;
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

    List<Offset> points = curveModel.controlPoints.map<Offset>((Offset point) => transform(point, size)).toList();

    path.moveTo(points[0].dx, points[0].dy);
    for (int i = 1; i < curveModel.controlPoints.length; ++i) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(ControlPolylinePainter oldDelegate) {
    return curveModel != oldDelegate.curveModel || color != oldDelegate.color || strokeWidth != oldDelegate.strokeWidth;
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

    if (curveModel.controlPoints.length != hovered.length) {
      hovered = List<bool>.generate(curveModel.controlPoints.length, (int index) => false);
    }

    return GestureDetector(
      onTap: () {
        final int hoveredIndex = hovered.indexOf(true);
        if (hoveredIndex < 0 || hoveredIndex >= curveModel.controlPoints.length) {
          // Nothing movable hovered over.
          return;
        }
        if (curveModel.selectedPoints.contains(hoveredIndex)) {
          curveModel.removeFromSelection(hoveredIndex);
        } else {
          curveModel.addToSelection(hoveredIndex);
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
        if (curveModel.selectedPoints.isEmpty) {
          return;
        }
        setState(() {
          final List<Offset> currentPoints = curveModel.controlPoints.toList();
          final List<Offset> newPoints = <Offset>[];
          final Offset delta = details.localPosition - _panStart;
          final Offset parametricDelta = Offset(
            delta.dx / curveModel.displaySize.width,
            -delta.dy / curveModel.displaySize.height,
          );
//          print('Dragging: ${details.localPosition - _panStart} (${parametricDelta.dx.toStringAsFixed(2)}, ${parametricDelta.dy.toStringAsFixed(2)}) ${curveModel.selectedPoints}');
          for (int i = 1; i < currentPoints.length - 1; ++i) {
            if (curveModel.selectedPoints.contains(i)) {
              final Offset newPosition = currentPoints[i] + parametricDelta;
//              print('Moving from ${currentPoints[i]} to $newPosition ($i)');
              newPoints.add(newPosition);
            } else {
              newPoints.add(currentPoints[i]);
            }
          }
          bool updated = curveModel.attemptUpdate(<Offset>[Offset.zero, ...newPoints, const Offset(1.0, 1.0)]);
          if (updated) {
            _panStart = _panStart + delta;
          }
//          print('Updated model: $updated $newPoints');
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
            ...List<Widget>.generate(curveModel.controlPoints.length, (int index) {
              final Offset point = curveModel.controlPoints[index];
              return CustomPaint(
                painter: ControlPointPainter(
                  controlPoint: point,
                  index: index,
                  hover: hovered,
                  select: CurveModel.of(context).selectedPoints.contains(index),
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

  double get hitRadius => radius + 4;

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
