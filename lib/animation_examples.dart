// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;

import 'package:flutter/animation.dart';
import 'package:flutter/material.dart';

/// A sample tile that shows the effect of a curve on translation.
class TranslateSampleTile extends StatelessWidget {
  const TranslateSampleTile({
    Key key,
    this.animation,
    this.name,
  }) : super(key: key);

  static const double blockHeight = blockWidth * 2.0/3.0;
  static const double blockWidth = containerSize * 0.6;
  static const double containerSize = 70.0;

  final Animation<double> animation;
  final String name;

  Widget mutate({Widget child}) {
    return new Transform.translate(
      offset: new Offset(0.0, 13.0 - animation.value * 26.0),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    const BorderRadius outerRadius = BorderRadius.all(
      Radius.circular(8.0),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.all(6.0),
          child: ClipRRect(
            borderRadius: outerRadius,
            child: new Container(
              width: containerSize,
              height: containerSize,
              alignment: Alignment.center,
              padding: const EdgeInsets.all(4.0),
              decoration: new BoxDecoration(
                borderRadius: outerRadius,
                border: new Border.all(
                  color: Colors.black45,
                  width: 1.0,
                ),
              ),
              child: mutate(
                child: new Container(
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.all(
                      Radius.circular(4.0),
                    ),
                  ),
                  width: blockWidth,
                  height: blockHeight,
                ),
              ),
            ),
          ),
        ),
        new Text(
          name,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.body2.copyWith(
                color: Colors.black,
                fontSize: 12.0,
              ),
        ),
      ],
    );
  }
}

/// A sample tile that shows the effect of a curve on rotation.
class RotateSampleTile extends TranslateSampleTile {
  const RotateSampleTile({Key key, Animation<double> animation, String name})
      : super(
          key: key,
          animation: animation,
          name: name,
        );

  @override
  Widget mutate({Widget child}) {
    return new Transform.rotate(
      angle: animation.value * math.pi / 2.0,
      alignment: Alignment.center,
      child: child,
    );
  }
}

/// A sample tile that shows the effect of a curve on scale.
class ScaleSampleTile extends TranslateSampleTile {
  const ScaleSampleTile({Key key, Animation<double> animation, String name})
      : super(
          key: key,
          animation: animation,
          name: name,
        );

  @override
  Widget mutate({Widget child}) {
    return new Transform.scale(
      scale: math.max(animation.value, 0.0),
      child: child,
    );
  }
}

/// A sample tile that shows the effect of a curve on opacity.
class OpacitySampleTile extends TranslateSampleTile {
  const OpacitySampleTile({Key key, Animation<double> animation, String name})
      : super(
          key: key,
          animation: animation,
          name: name,
        );

  @override
  Widget mutate({Widget child}) {
    return new Opacity(opacity: animation.value.clamp(0.0, 1.0), child: child);
  }
}

class AnimationExamples extends StatelessWidget {
  const AnimationExamples({Key key, @required this.animation}) : super(key: key);

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (BuildContext context, Widget child) {
        return Container(
          constraints: new BoxConstraints.tight(const Size(350.0, 200.0)),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              new TranslateSampleTile(animation: animation, name: 'translation'),
              new RotateSampleTile(animation: animation, name: 'rotation'),
              new ScaleSampleTile(animation: animation, name: 'scale'),
              new OpacitySampleTile(animation: animation, name: 'opacity'),
            ],
          ),
        );
      },
    );
  }
}

typedef PlayPauseOnPressed = void Function(bool, bool);

class PlayPauseButton extends StatefulWidget {
  const PlayPauseButton({
    Key key,
    this.animation,
    this.onPressed,
    this.bounce,
  }) : super(key: key);

  final AnimationController animation;
  final PlayPauseOnPressed onPressed;
  final bool bounce;

  @override
  _PlayPauseButtonState createState() => _PlayPauseButtonState();
}

class _PlayPauseButtonState extends State<PlayPauseButton> {
  bool playing = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        AnimatedBuilder(
          animation: widget.animation,
          builder: (BuildContext context, Widget child) {
            return IconButton(
              autofocus: true,
              iconSize: 50.0,
              icon: Icon(widget.animation.isAnimating ? Icons.pause : Icons.play_arrow),
              onPressed: () {
                setState(() {
                  playing = !playing;
                  widget.onPressed(playing, widget.bounce);
                });
              },
            );
          },
        ),
        Row(
          children: <Widget>[
            Icon(Icons.repeat),
            Switch(value: widget.bounce, onChanged: (bool value) {
              setState(() {
                widget.onPressed(playing, !widget.bounce);
              });
            },),
          ],
        ),
      ],
    );
  }
}
