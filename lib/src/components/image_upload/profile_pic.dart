
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kumbha_path/src/components/image_upload/display_profile_pic.dart';

class ProfilePic extends StatelessWidget {
  final Function takeImage;
  final XFile imageFile;
  final String existedImageUrl;

  const ProfilePic({
    super.key,
    required this.takeImage,
    required this.imageFile,
    this.existedImageUrl = "",
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            DisplayProfile(
              imageFile: imageFile,
              existedImageUrl: existedImageUrl,
            ),
            Positioned(
              top: 0,
              left: 0,
              child: GestureDetector(
                onTap: () => takeImage(context),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey.shade300, width: 1),
                  ),
                  child: const Icon(
                    Icons.add,
                    size: 18,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
          ],
        ),
      
      ],
    );
  }
}
