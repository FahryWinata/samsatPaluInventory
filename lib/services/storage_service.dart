import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;
import 'supabase_service.dart';

class StorageService {
  SupabaseClient get supabase => SupabaseService.client;

  /// Uploads an image to the 'assets_image' bucket.
  /// Returns the public URL of the uploaded image.
  Future<String?> uploadImage(File file) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${file.path.split(Platform.pathSeparator).last}';

      File fileToUpload = file;

      // Use FlutterImageCompress on mobile (faster, native)
      // Use pure Dart 'image' package on desktop (Windows/Linux/macOS)
      if (Platform.isAndroid || Platform.isIOS) {
        final targetPath = '${tempDir.path}/compressed_$fileName';
        var result = await FlutterImageCompress.compressAndGetFile(
          file.absolute.path,
          targetPath,
          quality: 80,
          minWidth: 1024,
          minHeight: 1024,
        );
        if (result != null) {
          fileToUpload = File(result.path);
        }
      } else {
        // Desktop: Use pure Dart 'image' package
        final bytes = await file.readAsBytes();
        img.Image? image = img.decodeImage(bytes);

        if (image != null) {
          // Resize if larger than 1024px
          if (image.width > 1024 || image.height > 1024) {
            image = img.copyResize(
              image,
              width: image.width > image.height ? 1024 : null,
              height: image.height >= image.width ? 1024 : null,
            );
          }

          // Encode as JPEG with 80% quality
          final compressedBytes = img.encodeJpg(image, quality: 80);

          // Write to temp file
          final compressedPath = '${tempDir.path}/compressed_$fileName.jpg';
          fileToUpload = await File(
            compressedPath,
          ).writeAsBytes(compressedBytes);
        }
      }

      // Upload to Supabase
      final path = 'uploads/$fileName';

      await supabase.storage
          .from('assets_image')
          .upload(
            path,
            fileToUpload,
            fileOptions: const FileOptions(
              cacheControl: '3600',
              upsert: false,
              contentType: 'image/jpeg',
            ),
          );

      // Clean up compressed file if it was created
      if (fileToUpload != file) {
        try {
          await fileToUpload.delete();
        } catch (_) {}
      }

      final publicUrl = supabase.storage
          .from('assets_image')
          .getPublicUrl(path);
      return publicUrl;
    } catch (e) {
      throw Exception('Upload failed: $e');
    }
  }

  /// Deletes an image from the 'assets_image' bucket.
  /// Takes the full public URL and extracts the storage path.
  Future<void> deleteImage(String? imageUrl) async {
    if (imageUrl == null || imageUrl.isEmpty) return;

    try {
      // Extract the path from the URL
      // URL format: https://xxx.supabase.co/storage/v1/object/public/assets_image/uploads/filename.jpg
      final uri = Uri.parse(imageUrl);
      final segments = uri.pathSegments;

      // Find 'assets_image' in the path and get everything after it
      final bucketIndex = segments.indexOf('assets_image');
      if (bucketIndex == -1 || bucketIndex >= segments.length - 1) return;

      final storagePath = segments.sublist(bucketIndex + 1).join('/');

      await supabase.storage.from('assets_image').remove([storagePath]);
    } catch (e) {
      // Log but don't throw - image deletion failure shouldn't block other operations
      // debugPrint('Error deleting image: $e');
    }
  }
}
