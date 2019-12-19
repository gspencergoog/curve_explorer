// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'dart:async';

import 'package:flutter/animation.dart';
import 'package:flutter/widgets.dart';
import 'package:scoped_model/scoped_model.dart';

enum CurveType {
  catmullRom,
}

abstract class CurveModel extends Model {
  CurveModel._() : selection = <int>{};

  factory CurveModel(CurveType type) {
    switch (type) {
      case CurveType.catmullRom:
        return CatmullRomModel();
    }
    throw UnimplementedError();
  }

  List<Offset> get controlPoints;
  int get hoverIndex;
  set hoverIndex(int value);
  double get tension;
  set tension(double value);
  Curve get curve;
  Duration get duration;
  set duration(Duration value);
  AnimationController get controller;
  bool get bounce;
  set bounce(bool value);

  Size displaySize = Size.zero;

  void reset();

  /// Starts the animation playing.
  void play();

  bool get playing;

  /// Stops the animation where it is.
  void pause();

  /// Tries to update the curve with the given information.
  ///
  /// Returns true if successful.
  bool attemptUpdate(List<Offset> controlPoints, double tension);

  /// The list of control point indices that are selected.
  final Set<int> selection;

  /// Returns true if the control point at `index` is selected.
  bool isSelected(int index) => selection.contains(index);

  /// Adds the given point to the current selection.
  ///
  /// Returns true if the point was not already in the selection.
  bool addToSelection(int selected) {
    if (selection.add(selected)) {
      print('Adding $selected to selection');
      notifyListeners();
      return true;
    }
    return false;
  }

  /// Clears the set of currently selected points.
  void clearSelection() {
    if (selection.isNotEmpty) {
      print('Clearing selection.');
      selection.clear();
      notifyListeners();
    }
  }

  /// Removes the given point from the current selection.
  ///
  /// Returns true if the point existed and was removed from the selection.
  bool removeFromSelection(int selected) {
    if (selection.remove(selected)) {
      print('Removing $selected from selection');
      notifyListeners();
      return true;
    }
    return false;
  }

  static CurveModel of(BuildContext context) => ScopedModel.of<CurveModel>(context);
}

class CatmullRomModel extends CurveModel {
  CatmullRomModel({
    List<Offset> controlPoints = _defaultControlPoints,
    double tension = _defaultTension,
    Duration duration = _defaultDuration,
    this.controller,
  })  : _hoveredIndex = null,
        _initialTension = tension,
        _initialControlPoints = controlPoints,
        _initialDuration = duration,
        _duration = duration,
        super._() {
    curve = CatmullRomCurve(controlPoints, tension: tension);
  }

  static const Duration _defaultDuration = Duration(seconds: 1);
  static const List<Offset> _defaultControlPoints = const <Offset>[
    Offset(0.0, 0.0),
    Offset(0.25, 0.25),
    Offset(0.5, 0.5),
    Offset(0.75, 0.75),
    Offset(1.0, 1.0),
  ];
  static const double _defaultTension = 0.0;

  final List<Offset> _initialControlPoints;
  final double _initialTension;
  final Duration _initialDuration;

  @override
  List<Offset> get controlPoints => curve.controlPoints;

  @override
  double get tension => curve.tension;
  set tension(double tension) {
    if (tension != curve.tension) {
      curve = CatmullRomCurve(controlPoints, tension: tension);
      notifyListeners();
    }
  }

  @override
  int get hoverIndex => _hoveredIndex;
  int _hoveredIndex;
  set hoverIndex(int hoveredIndex) {
    if (hoveredIndex != _hoveredIndex) {
      _hoveredIndex = hoveredIndex;
      notifyListeners();
    }
  }

  @override
  CatmullRomCurve get curve => _curve;
  CatmullRomCurve _curve;
  set curve(CatmullRomCurve curve) {
    if (curve != _curve) {
      _curve = curve;
      notifyListeners();
    }
  }

  @override
  bool attemptUpdate(List<Offset> controlPoints, [double tension]) {
    tension ??= curve.tension;
    List<String> reasons = <String>[];
    if (!CatmullRomCurve.validateControlPoints(controlPoints, tension: tension, reasons: reasons)) {
      print('Failed validation because:');
      for (String reason in reasons) {
        print('  $reason');
      }
      return false;
    }
    curve = CatmullRomCurve(controlPoints, tension: tension);
    notifyListeners();
    return true;
  }

  @override
  void reset() {
    curve = CatmullRomCurve(_initialControlPoints, tension: _initialTension);
    duration = _initialDuration;
    bounce = false;
    notifyListeners();
  }

  @override
  Duration get duration => _duration;
  Duration _duration;
  Timer setDurationTimer;
  set duration(Duration value) {
    if (value != _duration) {
      setDurationTimer?.cancel();
      _duration = value;
      controller.duration = _duration;
      setDurationTimer = Timer(
        const Duration(milliseconds: 200),
        () {
          if (playing) {
            pause();
            play();
          }
          setDurationTimer = null;
        },
      );

      notifyListeners();
    }
  }

  @override
  final AnimationController controller;

  @override
  bool get bounce => _bounce;
  bool _bounce = false;
  set bounce(bool value) {
    if (value != _bounce) {
      _bounce = value;
      if (playing) {
        pause();
        play();
      }
      notifyListeners();
    }
  }

  @override
  void pause() {
    controller.stop();
  }

  @override
  void play() {
    controller.repeat(reverse: bounce);
  }

  @override
  bool get playing => controller.isAnimating;
}
