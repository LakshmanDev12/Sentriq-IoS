import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'vk_signature.dart';

class DeveloperDialog {
  static void show(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Developer Info",
      barrierColor: Colors.black.withOpacity(0.6),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Card(
                elevation: 20,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)),
                clipBehavior: Clip.antiAlias,
                color: const Color(0xFFF1F3F4),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Stack(
                    children: [
                      // Background Watermark
                      Positioned.fill(
                        child: Center(
                          child: Opacity(
                            opacity: 0.05,
                            child: Icon(Icons.shield_rounded, size: 300, color: const Color(0xFF5C59BB)),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Align(
                              alignment: Alignment.topRight,
                              child: IconButton(
                                onPressed: () => Navigator.pop(context),
                                icon: const Icon(Icons.close, color: Colors.grey),
                              ),
                            ),
                            const VkSignature(size: 100),
                            const SizedBox(height: 16),
                            const Text(
                              "Design, Developed, Tested and Maintained by",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                decoration: TextDecoration.none,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Material(
                              color: Colors.transparent,
                              child: ShaderMask(
                                shaderCallback: (bounds) => const LinearGradient(
                                  colors: [Color(0xFFC9545F), Color(0xFF4F80C8)],
                                ).createShader(bounds),
                                child: const Text(
                                  "Lakshmandev Vk",
                                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                              ),
                            ),
                            const SizedBox(height: 32),
                            _buildSocialButtons(context),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
          child: child,
        );
      },
    );
  }

  static Widget _buildSocialButtons(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _socialButton(
              Icons.email,
              "Mail",
              const Color(0xFFD44638),
              "mailto:vklakshmandev@gmail.com",
            ),
            _socialButton(
              Icons.open_in_new,
              "Portfolio",
              const Color(0xFF4A8DFF),
              "https://lakshmandevvk.vercel.app/",
            ),
            _socialButton(
              Icons.link,
              "LinkedIn",
              const Color(0xFF0077B5),
              "https://www.linkedin.com/in/lakshmandev-vk-bb12a127b/",
            ),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _socialButton(
              Icons.camera_alt,
              "Instagram",
              const Color(0xFFE4405F),
              "https://www.instagram.com/lakshmandev.vk/",
            ),
            const SizedBox(width: 40),
            _socialButton(
              Icons.code,
              "GitHub",
              const Color(0xFF24292E),
              "https://github.com/LakshmanDev12",
            ),
          ],
        ),
      ],
    );
  }

  static Widget _socialButton(IconData icon, String label, Color color, String url) {
    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        onTap: () async {
          final Uri uri = Uri.parse(url);
          try {
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          } catch (e) {
            debugPrint("Could not launch $url: $e");
          }
        },
        child: Column(
          children: [
            Container(
              width: 55,
              height: 55,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.05),
                    blurRadius: 10,
                    spreadRadius: 1,
                  )
                ],
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
