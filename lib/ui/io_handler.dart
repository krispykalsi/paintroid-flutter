import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_styled_toast/flutter_styled_toast.dart';
import 'package:fpdart/fpdart.dart' show TaskEither, Unit;
import 'package:paintroid/command/command.dart' show CommandManager;
import 'package:paintroid/core/failure.dart';
import 'package:paintroid/io/io.dart';
import 'package:paintroid/io/src/entity/image_location.dart';
import 'package:paintroid/io/src/usecase/load_image_from_file_manager.dart';
import 'package:paintroid/workspace/workspace.dart';

class IOHandler {
  final Ref ref;

  const IOHandler(this.ref);

  static final provider = Provider((ref) => IOHandler(ref));

  Future<void> loadImage(ImageLocation location) async {
    switch (location) {
      case ImageLocation.photos:
        await _loadFromPhotos();
        break;
      case ImageLocation.files:
        await _loadFromFiles();
        break;
    }
  }

  Future<void> _loadFromPhotos() async {
    final loadImage = ref.read(LoadImageFromPhotoLibrary.provider);
    final result = await loadImage.prepareTask().run();
    result.fold(
      (failure) {
        if (failure != LoadImageFailure.userCancelled) {
          showToast(failure.message);
        }
      },
      (img) async {
        ref.read(CanvasState.provider.notifier).clearCanvas();
        ref.read(WorkspaceState.provider.notifier).setBackgroundImage(img);
      },
    );
  }

  Future<void> _loadFromFiles() async {
    final loadImage = ref.read(LoadImageFromFileManager.provider);
    final result = await loadImage.prepareTask().run();
    result.fold(
      (failure) {
        if (failure != LoadImageFailure.userCancelled) {
          showToast(failure.message);
        }
      },
      (imageFromFile) async {
        ref.read(CanvasState.provider.notifier).clearCanvas();
        final workspaceNotifier = ref.read(WorkspaceState.provider.notifier);
        imageFromFile.rasterImage == null
            ? workspaceNotifier.clearBackgroundImageAndResetDimensions()
            : workspaceNotifier.setBackgroundImage(imageFromFile.rasterImage!);
        if (imageFromFile.catrobatImage != null) {
          final commands = imageFromFile.catrobatImage!.commands;
          ref
              .read(CanvasState.provider.notifier)
              .renderAndReplaceImageWithCommands(commands);
        }
      },
    );
  }

  Future<void> saveImage(ImageMetaData imageData) async {
    if (imageData is JpgMetaData || imageData is PngMetaData) {
      await _saveAsRasterImage(imageData);
    } else if (imageData is CatrobatImageMetaData) {
      await _saveAsCatrobatImage(imageData);
    }
  }

  Future<void> _saveAsRasterImage(ImageMetaData imageData) async {
    final image = await ref
        .read(RenderImageForExport.provider)
        .call(keepTransparency: imageData.format != ImageFormat.jpg);
    final saveAsRasterImage = ref.read(SaveAsRasterImage.provider);
    late final TaskEither<Failure, Unit> task;
    if (imageData is JpgMetaData) {
      task = saveAsRasterImage.prepareTaskForJpg(imageData, image);
    } else if (imageData is PngMetaData) {
      task = saveAsRasterImage.prepareTaskForPng(imageData, image);
    }
    (await task.run()).fold(
      (failure) => showToast(failure.message),
      (_) => showToast("Saved to Photos"),
    );
  }

  Future<void> _saveAsCatrobatImage(CatrobatImageMetaData imageData) async {
    final commands = ref.read(CommandManager.provider).history;
    final backgroundImage = ref.read(WorkspaceState.provider).backgroundImage;
    final imageService = ref.read(IImageService.provider);
    Uint8List? bytes;
    if (backgroundImage != null) {
      final result = await imageService.export(backgroundImage).run();
      bytes = result.fold(
        (failure) {
          showToast(failure.message);
          return null;
        },
        (imageBytes) => imageBytes,
      );
      if (bytes == null) return;
    }
    final catrobatImage = CatrobatImage(commands, bytes);
    final saveAsCatrobatImage = ref.read(SaveAsCatrobatImage.provider);
    final result =
        await saveAsCatrobatImage.prepareTask(imageData, catrobatImage).run();
    result.fold(
      (failure) => showToast(failure.message),
      (file) => showToast("Saved successfully"),
    );
  }
}
