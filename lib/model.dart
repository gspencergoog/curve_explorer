// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/animation.dart';
import 'package:flutter/widgets.dart';
import 'package:scoped_model/scoped_model.dart';

enum CurveType {
  catmullRom,
}

abstract class CurveModel extends Model {
  CurveModel._();

  factory CurveModel(CurveType type) {
    switch (type) {
      case CurveType.catmullRom:
        return CatmullRomModel();
    }
    throw UnimplementedError();
  }

  List<Offset> get controlPoints;
  Set<int> get selectedPoints;
  Curve get curve;

  Size displaySize;

  /// Tries to update the curve with the given information.
  ///
  /// Returns true if successful.
  bool attemptUpdate(List<Offset> controlPoints);

  /// Adds the given point to the current selection.
  ///
  /// Returns true if the point was not already in the selection.
  bool addToSelection(int selected);

  /// Removes the given point from the current selection.
  ///
  /// Returns true if the point existed and was removed from the selection.
  bool removeFromSelection(int selected);

  static CurveModel of(BuildContext context) => ScopedModel.of<CurveModel>(context);
}

class CatmullRomModel extends CurveModel {
  CatmullRomModel({List<Offset> controlPoints, double tension})
      : selectedPoints = <int>{},
        super._() {
    curve = CatmullRomCurve(controlPoints, tension: tension);
  }

  @override
  List<Offset> get controlPoints => curve.controlPoints;

  @override
  final Set<int> selectedPoints;

  @override
  CatmullRomCurve curve;

  @override
  bool attemptUpdate(List<Offset> controlPoints, [double tension]) {
    tension ??= curve.tension;
//    List<String> reasons = <String>[];
//    bool valid = CatmullRomCurve.validateControlPoints(controlPoints, tension: tension, reasons: reasons);
//    if (!valid) {
//      print('Failed validation because:');
//      for (String reason in reasons) {
//        print('  $reason');
//      }
//      return false;
//    }
    curve = CatmullRomCurve(controlPoints, tension: tension);
    return true;
  }

  @override
  bool addToSelection(int selected) => selectedPoints.add(selected);

  @override
  bool removeFromSelection(int selected) => selectedPoints.remove(selected);
}
