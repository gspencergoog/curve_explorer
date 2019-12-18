// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Slider(
                        value: model.tension,
                        min: 0.0,
                        max: 1.0,
                        onChanged: (double value) {
                          setState(() {
                            model.tension = value;
                          });
                        },
                      ),
                      Expanded(
                        flex: 1,
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
  CurvePainter curvePainter;
  Offset mousePosition;
  Offset _panStart;
  int _currentDrag;

  @override
  Widget build(BuildContext context) {
    final CurveModel model = CurveModel.of(context);
    final int hoverIndex = model.hoverIndex;
    curvePainter ??= CurvePainter();

    curvePainter
      ..model = model
      ..mousePosition = mousePosition
      ..curveColor = widget.curveColor
      ..hoverColor = widget.hoverColor
      ..lineColor = widget.lineColor
      ..selectColor = widget.selectColor
      ..controlPointRadius = widget.controlPointRadius
      ..curveStrokeWidth = widget.curveStrokeWidth
      ..lineStrokeWidth = widget.lineStrokeWidth;

    return GestureDetector(
      onTap: () {
        if (hoverIndex < 1 || hoverIndex >= model.controlPoints.length - 1) {
          // Nothing movable hovered over.
          return;
        }
        if (LogicalKeyboardKey.collapseSynonyms(RawKeyboard.instance.keysPressed).contains(LogicalKeyboardKey.control)) {
          if (model.selectedPoints.contains(hoverIndex)) {
            model.removeFromSelection(hoverIndex);
          } else {
            model.addToSelection(hoverIndex);
          }
        }
      },
      onPanStart: (DragStartDetails details) {
        setState(() {
          if (hoverIndex != -1 && !model.selectedPoints.contains(hoverIndex)) {
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
        if (model.selectedPoints.isEmpty) {
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
          if (model.selectedPoints.contains(i) && i != 0 && i != currentPoints.length - 1) {
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
        child: CustomPaint(painter: curvePainter),
      ),
    );
  }
}

class CurvePainter extends CustomPainter {
  CurvePainter({
    this.model,
    this.curveColor = Colors.blueGrey,
    this.lineColor = Colors.red,
    this.hoverColor = Colors.red,
    this.selectColor = Colors.blue,
    this.curveStrokeWidth = 3.0,
    this.controlPointRadius = 4.0,
    this.mousePosition,
  });

  CurveModel model;
  Color curveColor;
  Color hoverColor;
  Color lineColor;
  Color selectColor;
  double controlPointRadius;
  double curveStrokeWidth;
  double lineStrokeWidth;
  Offset mousePosition;

  Offset transform(Offset point, Size size) {
    assert(point.dx <= 1.0 && point.dx >= 0.0);
    assert(point.dy <= 1.0 && point.dy >= 0.0);
    return Offset(point.dx * size.width, (1.0 - point.dy) * size.height);
  }

  void paintControlPolyline(Canvas canvas, Size size) {
    final Path path = Path();
    final Paint paint = Paint()
      ..color = curveColor
      ..strokeWidth = curveStrokeWidth
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    List<Offset> points = model.controlPoints.map<Offset>((Offset point) => transform(point, size)).toList();

    path.moveTo(points[0].dx, points[0].dy);
    for (int i = 1; i < model.controlPoints.length; ++i) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(path, paint);
  }

  @override
  void paintCurve(Canvas canvas, Size size) {
    if (model.displaySize != size) {
      model.displaySize = size;
    }
    final Path path = Path();
    final Paint paint = Paint()
      ..color = curveColor
      ..strokeWidth = curveStrokeWidth
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    CatmullRomCurve curve = model.curve;
    List<Curve2DSample> points = curve.valueSpline.generateSamples(
      start: curve.valueSpline.findInverse(0.0),
      end: curve.valueSpline.findInverse(1.0),
    );
    print('regen curve: ${points.length}');
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
    for (int i = 0; i < model.controlPoints.length; ++i) {
      final Offset controlPoint = model.controlPoints[i];
      _lastPoint = transform(controlPoint, size);
      if (mousePosition != null) {
        double distance = (_lastPoint - mousePosition).distance;
        if (distance < hitRadius) {
          model.hoverIndex = i;
        }
      } else {
        if (model.hoverIndex == i) {
          model.hoverIndex = null;
        }
      }
      final bool hovering = model.hoverIndex == i;
      final bool selected = model.selectedPoints.contains(i);
      final Paint paint = Paint()
        ..color = (!hovering && !selected) ? curveColor : hovering ? hoverColor : selectColor
        ..strokeWidth = curveStrokeWidth
        ..strokeJoin = StrokeJoin.round
        ..style = (hovering || selected) ? PaintingStyle.fill : PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawCircle(_lastPoint, controlPointRadius, paint);
    }
  }

  @override
  bool hitTest(Offset position) {
    final double hitRadius = controlPointRadius + 4;
    final double hitRadiusSquared = hitRadius * hitRadius;
    for (Offset point in model.controlPoints) {
      if ((position - point).distanceSquared < hitRadiusSquared) {
        return true;
      }
    }
    return false;
  }

  @override
  void paint(Canvas canvas, Size size) {
    paintCurve(canvas, size);
    paintControlPolyline(canvas, size);
    paintControlPoints(canvas, size);
  }

  @override
  bool shouldRepaint(CurvePainter oldDelegate) {
    return model.controlPoints != oldDelegate.model.controlPoints || curveColor != oldDelegate.curveColor || curveStrokeWidth != oldDelegate.curveStrokeWidth;
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

  @override
  void paint(Canvas canvas, Size size) {}

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
  Offset mousePosition;
  Offset _panStart;
  int _currentDrag;

  @override
  Widget build(BuildContext context) {
    CurveModel model = CurveModel.of(context);

    if (model.controlPoints.length != hovered.length) {
      hovered = List<bool>.generate(model.controlPoints.length, (int index) => false);
    }

    return GestureDetector(
      onTap: () {
        final int hoveredIndex = hovered.indexOf(true);
        if (hoveredIndex < 0 || hoveredIndex >= model.controlPoints.length) {
          // Nothing movable hovered over.
          return;
        }
        if (LogicalKeyboardKey.collapseSynonyms(RawKeyboard.instance.keysPressed).contains(LogicalKeyboardKey.control)) {
          if (model.selectedPoints.contains(hoveredIndex)) {
            model.removeFromSelection(hoveredIndex);
          } else {
            model.addToSelection(hoveredIndex);
          }
        }
      },
      onPanStart: (DragStartDetails details) {
        setState(() {
          final int hoveredIndex = hovered.indexOf(true);
          if (hoveredIndex != -1 && !model.selectedPoints.contains(hoveredIndex)) {
            _currentDrag = hoveredIndex;
            model.addToSelection(hoveredIndex);
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
        if (model.selectedPoints.isEmpty) {
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
          if (model.selectedPoints.contains(i) && i != 0 && i != currentPoints.length - 1) {
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
        child: Stack(
          fit: StackFit.expand,
          children: List<Widget>.generate(model.controlPoints.length, (int index) {
            final Offset point = model.controlPoints[index];
            return CustomPaint(
              painter: ControlPointPainter(
                controlPoint: point,
                index: index,
                hover: hovered,
                select: CurveModel.of(context).selectedPoints.contains(index),
                mousePosition: mousePosition,
              ),
            );
          }).toList(),
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
