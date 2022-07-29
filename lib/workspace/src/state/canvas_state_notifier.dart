import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'
    show StateNotifier, StateNotifierProvider;
import 'package:oxidized/oxidized.dart';
import 'package:paintroid/command/command.dart';
import 'package:paintroid/core/graphic_factory.dart';

part 'canvas_state.dart';

class CanvasStateNotifier extends StateNotifier<CanvasState> {
  CanvasStateNotifier(super.state, this._commandManager, this._graphicFactory);

  final CommandManager _commandManager;
  final GraphicFactory _graphicFactory;

  void updateCanvasSize(Size newSize) => state = state.copyWith(size: newSize);

  void renderImageWithLastCommand() async {
    final recorder = _graphicFactory.createPictureRecorder();
    final canvas = _graphicFactory.createCanvasWithRecorder(recorder);
    final bounds = Rect.fromLTWH(0, 0, state.size.width, state.size.height);
    canvas.clipRect(bounds);
    if (state.lastRenderedImage != null) {
      paintImage(canvas: canvas, rect: bounds, image: state.lastRenderedImage!);
    }
    _commandManager.executeLastCommand(canvas);
    final picture = recorder.endRecording();
    final image = await picture.toImage(
        state.size.width.toInt(), state.size.height.toInt());
    state = state.copyWith(lastRenderedImage: Option.some(image));
  }

  void clearCanvas() {
    _commandManager.resetHistory();
    state = state.copyWith(lastRenderedImage: Option.none());
  }

  void renderAndReplaceImageWithCommands(Iterable<Command> commands) async {
    final recorder = _graphicFactory.createPictureRecorder();
    final canvas = _graphicFactory.createCanvasWithRecorder(recorder);
    canvas.clipRect(Rect.fromLTWH(0, 0, state.size.width, state.size.height));
    _commandManager.resetHistory(newCommands: commands);
    _commandManager.executeAllCommands(canvas);
    final picture = recorder.endRecording();
    final image = await picture.toImage(
        state.size.width.toInt(), state.size.height.toInt());
    state = state.copyWith(lastRenderedImage: Option.some(image));
  }
}