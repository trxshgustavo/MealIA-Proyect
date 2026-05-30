import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import '../theme/app_colors.dart';

class LegalScreen extends StatelessWidget {
  final String title;
  final String mdFileName;

  const LegalScreen({super.key, required this.title, required this.mdFileName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cardBackground,
      appBar: AppBar(
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.primaryText,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppColors.primaryText),
      ),
      body: FutureBuilder<String>(
        future: rootBundle.loadString('assets/legal/$mdFileName'),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.hasData) {
            return Markdown(
              data: snapshot.data!,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              styleSheet: MarkdownStyleSheet(
                h1: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryText,
                  height: 1.5,
                  letterSpacing: -0.5,
                ),
                h2: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryText,
                  height: 1.5,
                ),
                h3: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryText,
                  height: 1.4,
                ),
                h2Padding: const EdgeInsets.only(top: 24, bottom: 8),
                h3Padding: const EdgeInsets.only(top: 16, bottom: 8),
                p: const TextStyle(
                  fontSize: 16,
                  height: 1.6,
                  color: AppColors.secondaryText,
                ),
                listBullet: const TextStyle(
                  fontSize: 16,
                  color: AppColors.secondaryText,
                ),
                strong: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryText,
                ),
                blockSpacing: 16,
              ),
            );
          }

          return const Center(child: Text("No se pudo cargar el documento."));
        },
      ),
    );
  }
}
