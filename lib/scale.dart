// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class GraphScale extends LeafRenderObjectWidget {
  GraphScale({
    Key key,
    @required this.min,
    @required this.max,
    @required this.minorSteps,
    @required this.minorsPerMajor,
    @required this.baselineColor,
    @required this.majorTickColor,
    @required this.minorTickColor,
    @required this.textStyle,
    @required this.mediaQueryData,
    @required this.textDirection,
  }) : super(key: key);

  final double min;
  final double max;
  final int minorSteps;
  final int minorsPerMajor;
  final Color baselineColor;
  final Color majorTickColor;
  final Color minorTickColor;
  final TextStyle textStyle;
  final MediaQueryData mediaQueryData;
  final TextDirection textDirection;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return RenderGraphScale(
      min: min,
      max: max,
      minorSteps: minorSteps,
      minorsPerMajor: minorsPerMajor,
      baselineColor: baselineColor,
      majorTickColor: majorTickColor,
      minorTickColor: minorTickColor,
      textStyle: textStyle,
      mediaQueryData: mediaQueryData,
      textDirection: textDirection,
    );
  }

  @override
  void updateRenderObject(BuildContext context, RenderGraphScale renderObject) {
    renderObject
      ..min = min
      ..max = max
      ..minorSteps = minorSteps
      ..minorsPerMajor = minorsPerMajor
      ..baselineColor = baselineColor
      ..majorTickColor = majorTickColor
      ..minorTickColor = minorTickColor
      ..textStyle = textStyle
      ..mediaQueryData = mediaQueryData
      ..textDirection = textDirection;
  }
}

class RenderGraphScale extends RenderProxyBox with RelayoutWhenSystemFontsChangeMixin {
  RenderGraphScale({
    this.min,
    this.max,
    this.minorSteps,
    this.minorsPerMajor,
    @required this.baselineColor,
    this.majorTickColor,
    this.minorTickColor,
    TextStyle textStyle,
    TextDirection textDirection,
    MediaQueryData mediaQueryData,
  })  : _textStyle = textStyle,
        _textDirection = textDirection,
        _mediaQueryData = mediaQueryData,
        assert(baselineColor != null),
        super() {
    _updateLabelPainters();
  }

  double min;
  double max;
  int minorSteps;
  int minorsPerMajor;
  Color baselineColor;
  Color majorTickColor;
  Color minorTickColor;

  TextStyle get textStyle => _textStyle;
  TextStyle _textStyle;
  set textStyle(TextStyle textStyle) {
    _textStyle = textStyle;
    _updateLabelPainters();
    markNeedsLayout();
  }

  MediaQueryData get mediaQueryData => _mediaQueryData;
  MediaQueryData _mediaQueryData;
  set mediaQueryData(MediaQueryData value) {
    if (value == _mediaQueryData) {
      return;
    }
    _mediaQueryData = value;
    // Media query data includes the textScaleFactor, so we need to update the
    // label painter.
    _updateLabelPainters();
  }

  TextDirection get textDirection => _textDirection;
  TextDirection _textDirection;
  set textDirection(TextDirection value) {
    assert(value != null);
    if (value == _textDirection) {
      return;
    }
    _textDirection = value;
    _updateLabelPainters();
  }

  final List<TextPainter> _labelPainters = <TextPainter>[];

  void _updateLabelPainters() {
    _labelPainters.clear();
    for (int i = 0; i <= minorSteps; i += minorsPerMajor) {
      double value = (i.toDouble() / minorSteps.toDouble()) * (max - min) + min;
      bool tooClose = value != max && max - value < (0.1 * (max - min));
      _labelPainters.add(
        TextPainter()
          ..text = TextSpan(style: textStyle, text: tooClose ? '' : value.toStringAsFixed(1))
          ..textDirection = _textDirection
          ..textScaleFactor = _mediaQueryData.textScaleFactor
          ..layout(),
      );
    }
    if (minorSteps % minorsPerMajor != 0) {
      // There's an extra label needed at the end.
      double value = (max - min) + min;
      _labelPainters.add(
        TextPainter()
          ..text = TextSpan(style: textStyle, text: value.toStringAsFixed(1))
          ..textDirection = _textDirection
          ..textScaleFactor = _mediaQueryData.textScaleFactor
          ..layout(),
      );
    }

    // Changing the textDirection can result in the layout changing, because the
    // bidi algorithm might line up the glyphs differently which can result in
    // different ligatures, different shapes, etc. So we always markNeedsLayout.
    markNeedsLayout();
  }

  @override
  void systemFontsDidChange() {
    super.systemFontsDidChange();
    _updateLabelPainters();
  }

  static const _minScaleHeight = 4.0;
  static const _minBarHeight = 10.0;
  static const _scaleBarPadding = 2.0;
  static const double _minorStrokeWidth = 1.0;
  static const double _majorStrokeWidth = 2.0;

  @override
  double computeMinIntrinsicHeight(double width) {
    return _labelPainters.first.height + _minScaleHeight + _minBarHeight + 2.0 * _scaleBarPadding;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final Canvas canvas = context.canvas;
    final Paint baselinePaint = Paint()
      ..color = baselineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = _minorStrokeWidth;
    final Paint minorTickPaint = Paint()
      ..color = minorTickColor ?? baselineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = _minorStrokeWidth;
    final Paint majorTickPaint = Paint()
      ..color = majorTickColor ?? baselineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = _majorStrokeWidth;

    final scaleWidth = size.width - _labelPainters.first.width / 2.0 - _labelPainters.last.width / 2.0;
    final Rect rect = offset & size;
    final Rect scaleRect = Rect.fromLTWH(
      offset.dx + _labelPainters.first.width / 2.0,
      offset.dy + _labelPainters.first.height + _scaleBarPadding,
      scaleWidth,
      size.height - _labelPainters.first.height - _scaleBarPadding * 2.0 - _minBarHeight,
    );
    final double majorTickHeight = scaleRect.height;
    final double minorTickHeight = majorTickHeight / 2.0;

    void _paintTick(double xPos, int labelIndex, {@required bool isMajor, @required bool isLast}) {
      if (isMajor) {
        canvas.drawLine(
          Offset(xPos, scaleRect.bottom),
          Offset(xPos, scaleRect.bottom - majorTickHeight),
          majorTickPaint,
        );
        TextPainter label = isLast ? _labelPainters.last : _labelPainters[labelIndex];
        label.paint(canvas, Offset(xPos - label.width / 2.0, rect.top));
      } else {
        canvas.drawLine(
          Offset(xPos, scaleRect.bottom),
          Offset(xPos, scaleRect.bottom - minorTickHeight),
          minorTickPaint,
        );
      }
    }

    canvas.drawLine(scaleRect.bottomLeft.translate(-_majorStrokeWidth / 2.0, 0.0), scaleRect.bottomRight.translate(_majorStrokeWidth / 2.0, 0.0), baselinePaint);
    double stepSize = scaleRect.width / minorSteps.toDouble();
    switch (textDirection) {
      case TextDirection.ltr:
        for (int i = 0; i <= minorSteps; ++i) {
          final double xPos = scaleRect.left + i * stepSize;
          final int index = i ~/ minorsPerMajor;
          _paintTick(xPos, index, isMajor: i % minorsPerMajor == 0 || i == minorSteps, isLast: i == minorSteps);
        }
        break;
      case TextDirection.rtl:
        for (int i = 0; i <= minorSteps; ++i) {
          final double xPos = scaleRect.right - i * stepSize;
          final int index = i ~/ minorsPerMajor;
          _paintTick(xPos, index, isMajor: i % minorsPerMajor == 0 || i == minorSteps, isLast: i == minorSteps);
        }
        break;
    }
  }
}
