import 'package:material_ui/material_ui.dart';

import 'pdf_viewer/pdf_editor_screen.dart';

/// Public entry point shared by online and downloaded lecture resources.
class PdfViewerModal extends StatelessWidget {
  const PdfViewerModal({super.key, required this.pdfUrl, required this.title});

  final String pdfUrl;
  final String title;

  @override
  Widget build(BuildContext context) =>
      PdfEditorScreen(pdfUrl: pdfUrl, title: title);
}
