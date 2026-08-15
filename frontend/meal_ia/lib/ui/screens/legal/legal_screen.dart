import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
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
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
            color: AppColors.primaryText,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 20,
            color: AppColors.primaryText,
          ),
          onPressed: () => Navigator.pop(context),
        ),
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
            final htmlData = md.markdownToHtml(snapshot.data!);
            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
              child: HtmlWidget(
                '<div style="text-align: left; line-height: 1.6;">$htmlData</div>',
                textStyle: TextStyle(
                  fontSize: 15.sp,
                  height: 1.6,
                  color: AppColors.secondaryText,
                ),
                customStylesBuilder: (element) {
                  if (element.localName == 'h1') {
                    return {
                      'font-size': '26px',
                      'font-weight': '800',
                      'color': '#000000', // Assuming primary text is near black
                      'line-height': '1.5',
                      'letter-spacing': '-0.5px',
                    };
                  }
                  if (element.localName == 'h2') {
                    return {
                      'font-size': '20px',
                      'font-weight': 'bold',
                      'color': '#000000',
                      'line-height': '1.5',
                      'margin-top': '24px',
                      'margin-bottom': '8px',
                    };
                  }
                  if (element.localName == 'h3') {
                    return {
                      'font-size': '18px',
                      'font-weight': '600',
                      'color': '#000000',
                      'line-height': '1.4',
                      'margin-top': '16px',
                      'margin-bottom': '8px',
                    };
                  }
                  if (element.localName == 'strong' || element.localName == 'b') {
                    return {
                      'font-weight': 'bold',
                      'color': '#000000',
                    };
                  }
                  if (element.localName == 'p' || element.localName == 'li') {
                    return {
                      'margin-bottom': '16px',
                    };
                  }
                  return null;
                },
              ),
            );
          }

          return const Center(child: Text("No se pudo cargar el documento."));
        },
      ),
    );
  }
}
