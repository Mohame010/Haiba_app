import 'package:material_ui/material_ui.dart';

import '../state/novel_reader_state.dart';

class NovelReaderScreen extends StatefulWidget {
  const NovelReaderScreen({super.key, required this.novelId});

  final String novelId;

  @override
  State<NovelReaderScreen> createState() => NovelReaderState();
}
