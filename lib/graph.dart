// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class Graph extends StatelessWidget {
  Graph({
    Key key,
    this.minX = 0.0,
    this.maxX = 1.0,
    this.minY = -0.5,
    this.maxY = 1.5,
    this.stepsX = 10,
    this.stepsY = 15,
    this.majorTickColor = Colors.black,
    this.minorTickColor = Colors.grey,
    @required this.textStyle,
    this.child,
  }) : super(key: key);

  final Widget child;
  final double minX;
  final double maxX;
  final double minY;
  final double maxY;
  final int stepsX;
  final int stepsY;
  final TextStyle textStyle;
  final Color majorTickColor;
  final Color minorTickColor;

  static const double _horizontalScaleHeight = 35;
  static const double _verticalScaleWidth = 38;
  static const int precision = 1;

  TextPainter _createLabel(String label, TextDirection textDirection, MediaQueryData mediaQueryData) {
    return TextPainter()
      ..text = TextSpan(style: textStyle, text: label)
      ..textDirection = textDirection
      ..textScaleFactor = mediaQueryData.textScaleFactor
      ..layout();
  }

  @override
  Widget build(BuildContext context) {
    TextDirection textDirection = Directionality.of(context);
    MediaQueryData mediaQueryData = MediaQuery.of(context);
    TextPainter minXLabel = _createLabel(minX.toStringAsFixed(precision), textDirection, mediaQueryData);
    TextPainter maxXLabel = _createLabel(maxX.toStringAsFixed(precision), textDirection, mediaQueryData);
    TextPainter minYLabel = _createLabel(minY.toStringAsFixed(precision), textDirection, mediaQueryData);
    TextPainter maxYLabel = _createLabel(maxY.toStringAsFixed(precision), textDirection, mediaQueryData);
    final double avgYLabelHeight = (maxYLabel.height + minYLabel.height) / 2.0;
    return Stack(
      children: <Widget>[
        Padding(
          padding: EdgeInsets.only(
            left: _verticalScaleWidth + minYLabel.width / 2.0,
            bottom: _horizontalScaleHeight + minXLabel.height + avgYLabelHeight/2.0,
            top: avgYLabelHeight * 1.5,
            right: maxXLabel.width / 2.0,
          ),
          child: child,
        ),
        Positioned(
          bottom: _horizontalScaleHeight,
          top: 0,
          left: 0,
          width: _verticalScaleWidth,
          child: CustomPaint(
            painter: VerticalScalePainter(
              min: minY,
              max: maxY,
              steps: stepsY,
              majorTickColor: majorTickColor,
              minorTickColor: minorTickColor,
              textStyle: textStyle,
              textDirection: textDirection,
              mediaQueryData: mediaQueryData,
            ),
          ),
        ),
        Positioned(
          left: _verticalScaleWidth,
          right: 0,
          bottom: 0,
          height: _horizontalScaleHeight,
          child: CustomPaint(
            painter: HorizontalScalePainter(
              min: minX,
              max: maxX,
              steps: stepsX,
              majorTickColor: majorTickColor,
              minorTickColor: minorTickColor,
              textStyle: textStyle,
              textDirection: textDirection,
              mediaQueryData: mediaQueryData,
            ),
          ),
        ),
      ],
    );
  }
}

class HorizontalScalePainter extends CustomPainter {
  HorizontalScalePainter({
    Listenable repaint,
    @required this.min,
    @required this.max,
    @required this.steps,
    @required this.majorTickColor,
    @required this.minorTickColor,
    @required this.textStyle,
    @required this.mediaQueryData,
    @required this.textDirection,
  })  : assert(max != null),
        assert(min != null),
        assert(steps != null),
        assert(textStyle != null),
        assert(majorTickColor != null),
        assert(minorTickColor != null),
        super(repaint: repaint);

  final double min;
  final double max;
  final int steps;
  final TextStyle textStyle;
  final Color majorTickColor;
  final Color minorTickColor;
  final TextDirection textDirection;
  final MediaQueryData mediaQueryData;

  static const int _minorsPerMajor = 4;
  static const int _labelPrecision = 1;
  static const double _scaleTextPadding = 4;
  static const double _minorStrokeWidth = 1.0;
  static const double _majorStrokeWidth = 2.0;

  final List<TextPainter> _labelPainters = <TextPainter>[];

  TextPainter _createLabel(String label) {
    return TextPainter()
      ..text = TextSpan(style: textStyle, text: label)
      ..textDirection = textDirection
      ..textScaleFactor = mediaQueryData.textScaleFactor
      ..layout();
  }

  void _updateLabelPainters(double scaleWidth) {
    _labelPainters.clear();
    final double range = max - min;
    for (int i = 0; i <= steps; ++i) {
      double t = i.toDouble() / steps.toDouble();
      double value = t * range + min;
      TextPainter label = _createLabel(value.toStringAsFixed(_labelPrecision));
      _labelPainters.add(label);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    _updateLabelPainters(size.width);
    final int minorSteps = steps * _minorsPerMajor;

    final Paint baselinePaint = Paint()
      ..color = majorTickColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = _minorStrokeWidth;
    final Paint minorTickPaint = Paint()
      ..color = minorTickColor ?? majorTickColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = _minorStrokeWidth;
    final Paint majorTickPaint = Paint()
      ..color = majorTickColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = _majorStrokeWidth;

    final scaleWidth = size.width - _labelPainters.first.width / 2.0 - _labelPainters.last.width / 2.0;
    final Rect rect = Offset.zero & size;
    final Rect scaleRect = Rect.fromLTWH(
      _labelPainters.first.width / 2.0,
      0,
      scaleWidth,
      size.height - _labelPainters.first.height - _scaleTextPadding,
    );
    final double majorTickHeight = scaleRect.height;
    final double minorTickHeight = majorTickHeight / 2.0;

    double _paintTick(double xPos, int labelIndex, {@required bool isMajor, @required double lastLabel}) {
      if (isMajor) {
        canvas.drawLine(
          Offset(xPos, scaleRect.top),
          Offset(xPos, scaleRect.top + majorTickHeight),
          majorTickPaint,
        );
        TextPainter label = _labelPainters[labelIndex];
        final Offset labelPos = Offset(xPos - label.width / 2.0, rect.bottom - label.height);
        if (labelPos.dx > lastLabel) {
          label.paint(canvas, labelPos);
          return labelPos.dx + label.width;
        } else {
          return lastLabel;
        }
      } else {
        canvas.drawLine(
          Offset(xPos, scaleRect.top),
          Offset(xPos, scaleRect.top + minorTickHeight),
          minorTickPaint,
        );
        return lastLabel;
      }
    }

    canvas.drawLine(scaleRect.topLeft.translate(_majorStrokeWidth / 2.0, 0.0), scaleRect.topRight.translate(_majorStrokeWidth / 2.0, 0.0), baselinePaint);
    double stepSize = scaleRect.width / minorSteps.toDouble();
    double lastLabel = -double.infinity;
    switch (textDirection) {
      case TextDirection.ltr:
        for (int i = 0; i <= minorSteps; ++i) {
          final double xPos = scaleRect.left + i * stepSize;
          final int index = i ~/ _minorsPerMajor;
          lastLabel = _paintTick(xPos, index, isMajor: i % _minorsPerMajor == 0 || i == minorSteps, lastLabel: lastLabel);
        }
        break;
      case TextDirection.rtl:
        for (int i = 0; i <= minorSteps; ++i) {
          final double xPos = scaleRect.right - i * stepSize;
          final int index = i ~/ _minorsPerMajor;
          lastLabel = _paintTick(xPos, index, isMajor: i % _minorsPerMajor == 0 || i == minorSteps, lastLabel: lastLabel);
        }
        break;
    }
  }

  @override
  bool shouldRepaint(HorizontalScalePainter oldDelegate) {
    return min != oldDelegate.min ||
        max != oldDelegate.max ||
        steps != oldDelegate.steps ||
        textStyle != oldDelegate.textStyle ||
        majorTickColor != oldDelegate.majorTickColor ||
        minorTickColor != oldDelegate.minorTickColor;
  }
}

class VerticalScalePainter extends CustomPainter {
  VerticalScalePainter({
    Listenable repaint,
    @required this.min,
    @required this.max,
    @required this.steps,
    @required this.majorTickColor,
    @required this.minorTickColor,
    @required this.textStyle,
    @required this.mediaQueryData,
    @required this.textDirection,
  })  : assert(max != null),
        assert(min != null),
        assert(steps != null),
        assert(textStyle != null),
        assert(majorTickColor != null),
        assert(minorTickColor != null),
        super(repaint: repaint);

  final double min;
  final double max;
  final int steps;
  final TextStyle textStyle;
  final Color majorTickColor;
  final Color minorTickColor;
  final TextDirection textDirection;
  final MediaQueryData mediaQueryData;

  static const int _minorsPerMajor = 4;
  static const int _labelPrecision = 1;
  static const double _scaleTextPadding = 4;
  static const double _minorStrokeWidth = 1.0;
  static const double _majorStrokeWidth = 2.0;

  final List<TextPainter> _labelPainters = <TextPainter>[];

  TextPainter _createLabel(String label) {
    return TextPainter()
      ..text = TextSpan(style: textStyle, text: label)
      ..textDirection = textDirection
      ..textScaleFactor = mediaQueryData.textScaleFactor
      ..layout();
  }

  void _updateLabelPainters(double scaleWidth) {
    _labelPainters.clear();
    final double range = max - min;
    for (int i = 0; i <= steps; ++i) {
      double t = i.toDouble() / steps.toDouble();
      double value = t * range + min;
      TextPainter label = _createLabel(value.toStringAsFixed(_labelPrecision));
      _labelPainters.add(label);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    _updateLabelPainters(size.width);
    final int minorSteps = steps * _minorsPerMajor;

    final Paint baselinePaint = Paint()
      ..color = majorTickColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = _minorStrokeWidth;
    final Paint minorTickPaint = Paint()
      ..color = minorTickColor ?? majorTickColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = _minorStrokeWidth;
    final Paint majorTickPaint = Paint()
      ..color = majorTickColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = _majorStrokeWidth;

    final scaleHeight = size.height - _labelPainters.first.height / 2.0 - _labelPainters.last.height / 2.0;
    final Rect rect = Offset.zero & size;
    final Rect scaleRect = Rect.fromLTWH(
      _labelPainters.first.width + _scaleTextPadding,
      _labelPainters.first.height / 2.0,
      size.width - _labelPainters.first.width - _scaleTextPadding,
      scaleHeight,
    );
    final double majorTickWidth = scaleRect.width;
    final double minorTickWidth = majorTickWidth / 2.0;

    double _paintTick(double yPos, int labelIndex, {@required bool isMajor, @required double lastLabel}) {
      if (isMajor) {
        canvas.drawLine(
          Offset(scaleRect.right - majorTickWidth, yPos),
          Offset(scaleRect.right, yPos),
          majorTickPaint,
        );
        TextPainter label = _labelPainters[labelIndex];
        final Offset labelPos = Offset(rect.left, yPos - label.height / 2.0);
        if (labelPos.dy < lastLabel) {
          label.paint(canvas, labelPos);
          return labelPos.dy - label.height;
        } else {
          return lastLabel;
        }
      } else {
        canvas.drawLine(
          Offset(scaleRect.right - minorTickWidth, yPos),
          Offset(scaleRect.right, yPos),
          minorTickPaint,
        );
        return lastLabel;
      }
    }

    canvas.drawLine(scaleRect.topRight.translate(-_majorStrokeWidth / 2.0, 0.0), scaleRect.bottomRight.translate(-_majorStrokeWidth / 2.0, 0.0), baselinePaint);
    double stepSize = scaleRect.height / minorSteps.toDouble();
    double lastLabel = double.infinity;
    for (int i = 0; i <= minorSteps; ++i) {
      final double yPos = scaleRect.bottom - i * stepSize;
      final int index = i ~/ _minorsPerMajor;
      lastLabel = _paintTick(yPos, index, isMajor: i % _minorsPerMajor == 0 || i == minorSteps, lastLabel: lastLabel);
    }
  }

  @override
  bool shouldRepaint(VerticalScalePainter oldDelegate) {
    return min != oldDelegate.min ||
        max != oldDelegate.max ||
        steps != oldDelegate.steps ||
        textStyle != oldDelegate.textStyle ||
        majorTickColor != oldDelegate.majorTickColor ||
        minorTickColor != oldDelegate.minorTickColor;
  }
}
