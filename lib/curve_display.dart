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
  });

  final Color curveColor;
  final Color hoverColor;
  final Color lineColor;
  final Color selectColor;
  final double controlPointRadius;
  final double curveStrokeWidth;
  final double lineStrokeWidth;

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
            print('tapped $hoverIndex');
            if (hoverIndex == null) {
              // Nothing hovered over, so just clear the selection.
              print('clearing selection');
              model.clearSelection();
              setState(() {
                _selection = <int>{};
              });
            }
            if (LogicalKeyboardKey.collapseSynonyms(RawKeyboard.instance.keysPressed).contains(LogicalKeyboardKey.control)) {
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
                final Offset newPosition = currentPoints[i] + parametricDelta;
                newPoints.add(newPosition);
              } else {
                newPoints.add(currentPoints[i]);
              }
            }
            if (model.attemptUpdate(newPoints)) {
              setState(() {
                _panStart = _panStart + delta;
              });
            }
          },
          child: Builder(
            builder: (BuildContext context) {
//              print('Rebuilding CurvePainter');
              return CustomPaint(
                painter: CurvePainter(
                  mousePosition: mousePosition,
                  curveColor: widget.curveColor,
                  pointHoverColor: widget.hoverColor,
                  lineColor: widget.lineColor,
                  pointSelectColor: widget.selectColor,
                  controlPointRadius: widget.controlPointRadius,
                  curveStrokeWidth: widget.curveStrokeWidth,
                  lineStrokeWidth: widget.lineStrokeWidth,
                  tension: _tension,
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
    this.pointColor = Colors.red,
    this.pointHoverColor = Colors.red,
    this.pointSelectColor = Colors.blue,
    this.curveStrokeWidth = 3.0,
    this.lineStrokeWidth = 1.0,
    this.controlPointRadius = 4.0,
  });

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
  Color pointHoverColor;
  Color pointSelectColor;
  Color pointColor;
  double controlPointRadius;
  double curveStrokeWidth;
  double lineStrokeWidth;
  Size _lastSize;

  Offset transform(Offset point, Size size) {
    double x = point.dx.clamp(0.0, 1.0);
    double y = point.dy.clamp(0.0, 1.0);
    return Offset(x * size.width, (1.0 - y) * size.height);
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
    _lastSize = size;
    graphSizeChanged?.call(size);

    paintCurve(canvas, size);
    paintControlPolyline(canvas, size);
    paintControlPoints(canvas, size);
  }

//  @override
//  bool hitTest(Offset position) {
//    final double hitRadius = controlPointRadius + 4;
//    final double hitRadiusSquared = hitRadius * hitRadius;
//    for (Offset point in controlPoints) {
//      if ((position - transform(point, _lastSize)).distanceSquared < hitRadiusSquared) {
//        return true;
//      }
//    }
//    return false;
//  }

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
      'lineStrokeWidth': lineStrokeWidth != oldDelegate.lineStrokeWidth
    };
    if (reasons.values.contains(true)) {
      for (String reason in reasons.keys) {
        if (reasons[reason] && reason != 'mousePosition') {
          print('Repainting: $reason changed.');
        }
      }
    }
    return reasons.values.contains(true);
  }
}
