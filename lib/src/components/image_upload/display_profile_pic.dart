
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kumbha_path/src/constant/app_color.dart';

class DisplayProfile extends StatelessWidget {
  final XFile imageFile;
  final String existedImageUrl;

  const DisplayProfile({
    super.key,
    required this.imageFile,
    this.existedImageUrl = "",
  });

  bool _isValidUrl(String url) {
    return url.isNotEmpty &&
        Uri.tryParse(url)?.hasAbsolutePath == true &&
        !url.endsWith('/');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.amberAccent),
      ),
      child: CircleAvatar(
        backgroundColor: whiteColor,
        radius: 46,
        child: ClipOval(
          child: SizedBox.fromSize(
            size: const Size.fromRadius(46),
            child:
                (imageFile.path.isNotEmpty)
                    ? ClipRRect(
                      borderRadius: BorderRadius.circular(46),
                      child: Image.file(
                        File(imageFile.path),
                        height: 50,
                        width: 50,
                        fit: BoxFit.cover,
                        filterQuality: FilterQuality.high,
                      ),
                    )
                    : (_isValidUrl(existedImageUrl))
                    ? ClipRRect(
                      borderRadius: BorderRadius.circular(46),
                      child: CachedNetworkImage(
                        imageUrl: existedImageUrl,
                        height: 50,
                        width: 50,
                        fit: BoxFit.cover,
                        filterQuality: FilterQuality.high,
                        placeholder:
                            (context, url) => const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                        errorWidget:
                            (context, url, error) => const Icon(
                              Icons.person,
                              size: 50,
                              color: Colors.grey,
                            ),
                      ),
                    )
                    : const Icon(Icons.person, size: 50, color: Colors.grey),
          ),
        ),
      ),
    );
  }
}
