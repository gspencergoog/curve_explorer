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

  Size displaySize = Size.zero;

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
  CatmullRomModel({List<Offset> controlPoints, double tension})
      : _hoveredIndex = null,
        super._() {
    curve = CatmullRomCurve(controlPoints, tension: tension);
  }

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

}
