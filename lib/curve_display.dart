// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'model.dart';

class CurveDisplay extends StatefulWidget {
  const CurveDisplay({
    this.curveColor = Colors.blueGrey,
    this.lineColor = Colors.red,
    this.hoverColor = Colors.red,
    this.selectColor = Colors.blue,
    this.curveStrokeWidth = 3.0,
    this.controlPointRadius = 4.0,
    this.lineStrokeWidth = 1.0,
    this.minY = -0.5,
    this.maxY = 1.5,
    this.animation = const AlwaysStoppedAnimation<double>(0.0),
  });

  final Color curveColor;
  final Color hoverColor;
  final Color lineColor;
  final Color selectColor;
  final double controlPointRadius;
  final double curveStrokeWidth;
  final double lineStrokeWidth;
  final double minY;
  final double maxY;
  final Animation<double> animation;

  @override
  _CurveDisplayState createState() => _CurveDisplayState();
}

class _CurveDisplayState extends State<CurveDisplay> {
  Offset mousePosition;
  Offset _panStart;
  int _currentDrag;
  List<Offset> _controlPoints;
  Set<int> _selection;
  double _tension;
  List<Curve2DSample> _points;

  @override
  Widget build(BuildContext context) {
    final CurveModel model = CurveModel.of(context);
    if (model.controlPoints != _controlPoints || model.tension != _tension) {
      _controlPoints = model.controlPoints;
      _tension = model.tension;
      CatmullRomSpline spline = (model.curve as CatmullRomCurve).valueSpline;
      _points = spline.generateSamples(
        start: spline.findInverse(0.0),
        end: spline.findInverse(1.0),
      );
    }
    _selection ??= <int>{};
    if (model.selection.difference(_selection).isNotEmpty) {
      _selection = Set<int>.from(model.selection);
    }
    if (model.selection.isEmpty != _selection.isEmpty) {
      _selection = <int>{};
    }
    final int hoverIndex = model.hoverIndex;
    return ConstrainedBox(
      constraints: BoxConstraints.expand(),
      child: MouseRegion(
        onEnter: (PointerEnterEvent event) {
          setState(() {
            mousePosition = event.localPosition;
          });
        },
        onHover: (PointerHoverEvent event) {
          setState(() {
            mousePosition = event.localPosition;
          });
        },
        onExit: (PointerExitEvent event) {
          setState(() {
            mousePosition = null;
          });
        },
        child: GestureDetector(
          onTap: () {
            final Set<LogicalKeyboardKey> pressed = LogicalKeyboardKey.collapseSynonyms(RawKeyboard.instance.keysPressed);
            print('tapped $hoverIndex $pressed');
            if (hoverIndex == null) {
              // Nothing hovered over, so just clear the selection.
              print('clearing selection');
              model.clearSelection();
              setState(() {
                _selection = <int>{};
              });
            }
            if (pressed.contains(LogicalKeyboardKey.control)) {
              if (model.isSelected(hoverIndex)) {
                model.removeFromSelection(hoverIndex);
              } else {
                model.addToSelection(hoverIndex);
              }
            }
          },
          onPanStart: (DragStartDetails details) {
            setState(() {
              if (hoverIndex != -1 && !model.isSelected(hoverIndex)) {
                _currentDrag = hoverIndex;
                model.addToSelection(hoverIndex);
              }
              _panStart = details.localPosition;
            });
          },
          onPanEnd: (DragEndDetails details) {
            setState(() {
              if (_currentDrag != null) {
                model.removeFromSelection(_currentDrag);
                _currentDrag = null;
              }
              _panStart = null;
            });
          },
          onPanUpdate: (DragUpdateDetails details) {
            if (model.selection.isEmpty) {
              return;
            }
            final List<Offset> currentPoints = model.controlPoints;
            final List<Offset> newPoints = <Offset>[];
            final Offset delta = details.localPosition - _panStart;
            final Offset parametricDelta = Offset(
              delta.dx / model.displaySize.width,
              -delta.dy / model.displaySize.height,
            );
            for (int i = 0; i < currentPoints.length; ++i) {
              if (model.isSelected(i) && i != 0 && i != currentPoints.length - 1) {
                final Offset newPosition = Offset(
                  currentPoints[i].dx + parametricDelta.dx,
                  currentPoints[i].dy + (parametricDelta.dy * (widget.maxY - widget.minY)),
                );
                newPoints.add(newPosition);
              } else {
                newPoints.add(currentPoints[i]);
              }
            }
            if (model.attemptUpdate(newPoints, _tension)) {
              setState(() {
                _panStart = _panStart + delta;
              });
            }
          },
          child: AnimatedBuilder(
            animation: widget.animation,
            builder: (BuildContext context, Widget child) {
              return CustomPaint(
                painter: CurvePainter(
                  model: model,
                  mousePosition: mousePosition,
                  curveColor: widget.curveColor,
                  pointHoverColor: widget.hoverColor,
                  lineColor: widget.lineColor,
                  pointSelectColor: widget.selectColor,
                  controlPointRadius: widget.controlPointRadius,
                  curveStrokeWidth: widget.curveStrokeWidth,
                  lineStrokeWidth: widget.lineStrokeWidth,
                  tension: _tension,
                  yGrid: <double>{0.0, 1.0},
                  hoverChanged: (int value) {
                    return model.hoverIndex = value;
                  },
                  hoverIndex: model.hoverIndex,
                  graphSizeChanged: (Size value) {
                    if (value != model.displaySize) {
                      model.displaySize = value;
                    }
                  },
                  controlPoints: _controlPoints,
                  selectedPoints: _selection,
                  points: _points,
                  minY: widget.minY,
                  maxY: widget.maxY,
                  animation: widget.animation,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class CurvePainter extends CustomPainter {
  CurvePainter({
    @required this.model,
    @required this.points,
    @required this.controlPoints,
    @required this.tension,
    @required this.selectedPoints,
    @required this.graphSizeChanged,
    @required this.hoverChanged,
    @required this.hoverIndex,
    @required this.mousePosition,
    this.curveColor = Colors.blueGrey,
    this.lineColor = Colors.red,
    this.gridColor = Colors.black12,
    this.pointColor = Colors.red,
    this.pointHoverColor = Colors.red,
    this.pointSelectColor = Colors.blue,
    this.curveStrokeWidth = 3.0,
    this.lineStrokeWidth = 1.0,
    this.controlPointRadius = 4.0,
    this.minY = -0.5,
    this.maxY = 1.5,
    this.yGrid = const <double>{},
    this.animation,
  });

  CurveModel model;
  List<Curve2DSample> points;
  List<Offset> controlPoints;
  double tension;
  Set<int> selectedPoints;
  ValueChanged<Size> graphSizeChanged;
  ValueChanged<int> hoverChanged;
  int hoverIndex;
  Offset mousePosition;
  Color curveColor;
  Color lineColor;
  Color gridColor;
  Color pointHoverColor;
  Color pointSelectColor;
  Color pointColor;
  double controlPointRadius;
  double curveStrokeWidth;
  double lineStrokeWidth;
  double minY;
  double maxY;
  Set<double> yGrid;
  Animation<double> animation;

  double _lastAnimation = 0.0;

  Offset transform(Offset point, Size size) {
    double x = point.dx.clamp(0.0, 1.0);
    double y = point.dy.clamp(minY, maxY);
    return Offset(x * size.width, (1.0 - ((y - minY) / (maxY - minY))) * size.height);
  }

  void paintControlPolyline(Canvas canvas, Size size) {
    final Path path = Path();
    final Paint paint = Paint()
      ..color = lineColor
      ..strokeWidth = lineStrokeWidth
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

  void paintCurve(Canvas canvas, Size size) {
    final Path path = Path();
    final Paint paint = Paint()
      ..color = curveColor
      ..strokeWidth = curveStrokeWidth
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < points.length; ++i) {
      Offset point = transform(points[i].value, size);
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    canvas.drawPath(path, paint);
  }

  void paintGridLines(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = gridColor
      ..strokeWidth = lineStrokeWidth
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (double location in yGrid) {
      final Offset start = Offset(0.0, location);
      final Offset end = Offset(1.0, location);
      canvas.drawLine(transform(start, size), transform(end,size), paint);
    }
  }

  void paintAnimation(Canvas canvas, Size size) {
    switch( animation.status) {
      case AnimationStatus.forward:
      case AnimationStatus.reverse:
        break;
    case AnimationStatus.dismissed:
      case AnimationStatus.completed:
        // Don't draw animation indicator when paused.
        return;
        break;
    }
    final Paint paint = Paint()
      ..color = gridColor
      ..strokeWidth = curveStrokeWidth
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final double x = animation.value;
    final double y = model.curve.transform(x);
    final Offset point = transform(Offset(x, y), size);
    final Offset yAxis = transform(Offset(0.0, y), size);
    final Offset xAxis = transform(Offset(x, 0.0), size);
    canvas.drawLine(yAxis, point, paint);
    canvas.drawLine(xAxis, point, paint);
  }

  void paintControlPoints(Canvas canvas, Size size) {
    final double hitRadius = controlPointRadius + 4;
    final double hitRadiusSquared = hitRadius * hitRadius;
    for (int i = 0; i < controlPoints.length; ++i) {
      final Offset controlPoint = controlPoints[i];
      final Offset lastPoint = transform(controlPoint, size);
      final bool hovering = hoverIndex == i;
      if (mousePosition != null) {
        double distanceSquared = (lastPoint - mousePosition).distanceSquared;
        if (distanceSquared < hitRadiusSquared) {
          if (!hovering && i > 0 && i < controlPoints.length - 1) {
            hoverChanged(i);
          }
        } else if (hovering) {
          hoverChanged(null);
        }
      } else {
        hoverChanged(null);
      }
      final bool selected = selectedPoints.contains(i);
      final Paint paint = Paint()
        ..color = (!hovering && !selected) ? pointColor : hovering ? pointHoverColor : pointSelectColor
        ..strokeWidth = lineStrokeWidth
        ..strokeJoin = StrokeJoin.round
        ..style = (hovering || selected) ? PaintingStyle.fill : PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawCircle(lastPoint, controlPointRadius, paint);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    graphSizeChanged?.call(size);
    _lastAnimation = animation.value;

    paintAnimation(canvas, size);
    paintCurve(canvas, size);
    paintControlPolyline(canvas, size);
    paintControlPoints(canvas, size);
    paintGridLines(canvas, size);
  }

  @override
  bool shouldRepaint(CurvePainter oldDelegate) {
    Map<String, bool> reasons = <String, bool>{
      'mousePosition': mousePosition != oldDelegate.mousePosition,
      'points': points != oldDelegate.points,
      'controlPoints': controlPoints != oldDelegate.controlPoints,
      'tension': tension != oldDelegate.tension,
      'selectedPoints': selectedPoints != oldDelegate.selectedPoints,
      'hoverIndex': hoverIndex != oldDelegate.hoverIndex,
      'curveColor': curveColor != oldDelegate.curveColor,
      'pointHoverColor': pointHoverColor != oldDelegate.pointHoverColor,
      'lineColor': lineColor != oldDelegate.lineColor,
      'pointSelectColor': pointSelectColor != oldDelegate.pointSelectColor,
      'controlPointRadius': controlPointRadius != oldDelegate.controlPointRadius,
      'curveStrokeWidth': curveStrokeWidth != oldDelegate.curveStrokeWidth,
      'lineStrokeWidth': lineStrokeWidth != oldDelegate.lineStrokeWidth,
      'animation': animation.value != oldDelegate._lastAnimation,
    };
//    if (reasons.values.contains(true)) {
//      for (String reason in reasons.keys) {
//        if (reasons[reason] && reason != 'mousePosition') {
//          print('Repainting: $reason changed.');
//        }
//      }
//    }
    return reasons.values.contains(true);
  }
}
