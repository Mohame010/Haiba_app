import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'pdf_annotation_models.dart';

class PreparedPdfDocument {
  const PreparedPdfDocument({
    required this.pdfPath,
    required this.annotationPath,
    required this.annotations,
  });

  final String pdfPath;
  final String annotationPath;
  final PdfAnnotationDocument annotations;
}

class RecentPdfDocument {
  const RecentPdfDocument({
    required this.url,
    required this.title,
    required this.cachedPath,
    required this.openedAt,
  });

  final String url;
  final String title;
  final String cachedPath;
  final DateTime openedAt;

  Map<String, dynamic> toJson() => {
    'url': url,
    'title': title,
    'cachedPath': cachedPath,
    'openedAt': openedAt.toIso8601String(),
  };

  factory RecentPdfDocument.fromJson(Map<String, dynamic> json) =>
      RecentPdfDocument(
        url: json['url']?.toString() ?? '',
        title: json['title']?.toString() ?? 'ملف PDF',
        cachedPath: json['cachedPath']?.toString() ?? '',
        openedAt:
            DateTime.tryParse(json['openedAt']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
      );
}

class PdfDocumentStore {
  const PdfDocumentStore();

  Future<PreparedPdfDocument> prepare({
    required String url,
    required String title,
    void Function(double progress)? onProgress,
  }) async {
    final directory = await _privateDirectory();
    final key = '${_safeTitle(title)}_${_stableHash(url)}';
    final annotationFile = File('${directory.path}/$key.annotations.json');
    final pdfFile = await _resolvePdf(
      url: url,
      target: File('${directory.path}/$key.pdf'),
      onProgress: onProgress,
    );
    final prepared = PreparedPdfDocument(
      pdfPath: pdfFile.path,
      annotationPath: annotationFile.path,
      annotations: await _loadAnnotations(annotationFile),
    );
    await recordRecent(
      RecentPdfDocument(
        url: url,
        title: title,
        cachedPath: pdfFile.path,
        openedAt: DateTime.now(),
      ),
    );
    return prepared;
  }

  Future<List<RecentPdfDocument>> loadRecentDocuments() async {
    final directory = await _privateDirectory();
    final source = File('${directory.path}/recent.json');
    if (!await source.exists()) return [];
    try {
      final decoded = jsonDecode(await source.readAsString());
      if (decoded is! List) return [];
      final documents = decoded
          .whereType<Map>()
          .map(
            (item) =>
                RecentPdfDocument.fromJson(Map<String, dynamic>.from(item)),
          )
          .where((item) => item.url.isNotEmpty && item.cachedPath.isNotEmpty)
          .toList();
      final available = <RecentPdfDocument>[];
      for (final document in documents) {
        if (await File(document.cachedPath).exists()) available.add(document);
      }
      available.sort((a, b) => b.openedAt.compareTo(a.openedAt));
      return available;
    } catch (_) {
      return [];
    }
  }

  Future<void> save(
    String annotationPath,
    PdfAnnotationDocument document,
  ) async {
    final target = File(annotationPath);
    final temporary = File('$annotationPath.part');
    await temporary.writeAsString(jsonEncode(document.toJson()), flush: true);
    if (await target.exists()) await target.delete();
    await temporary.rename(target.path);
  }

  Future<Directory> _privateDirectory() async {
    final support = await getApplicationSupportDirectory();
    final directory = Directory('${support.path}/offline_pdfs');
    await directory.create(recursive: true);
    return directory;
  }

  Future<File> _resolvePdf({
    required String url,
    required File target,
    void Function(double progress)? onProgress,
  }) async {
    final uri = Uri.tryParse(url);
    if (uri?.scheme == 'file') {
      final source = File.fromUri(uri!);
      if (!await source.exists()) {
        if (await target.exists() && await target.length() > 0) return target;
        throw const FileSystemException('ملف PDF غير موجود');
      }
      if (source.path == target.path) return source;
      final shouldCopy =
          !await target.exists() ||
          await target.length() != await source.length() ||
          (await source.lastModified()).isAfter(await target.lastModified());
      if (shouldCopy) await source.copy(target.path);
      return target;
    }
    if (await target.exists() && await target.length() > 0) return target;
    if (uri == null || !uri.hasScheme) {
      throw const FormatException('رابط ملف PDF غير صالح');
    }

    final request = http.Request('GET', uri);
    final response = await request.send();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException('تعذر تنزيل PDF (${response.statusCode})', uri: uri);
    }

    final partial = File('${target.path}.part');
    final sink = partial.openWrite();
    final total = response.contentLength ?? 0;
    var received = 0;
    try {
      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) onProgress?.call(received / total);
      }
      await sink.flush();
      await sink.close();
      if (await target.exists()) await target.delete();
      return await partial.rename(target.path);
    } catch (_) {
      try {
        await sink.close();
      } catch (_) {}
      if (await partial.exists()) await partial.delete();
      rethrow;
    }
  }

  Future<PdfAnnotationDocument> _loadAnnotations(File source) async {
    if (!await source.exists()) return PdfAnnotationDocument();
    try {
      final json = jsonDecode(await source.readAsString());
      if (json is Map) {
        return PdfAnnotationDocument.fromJson(Map<String, dynamic>.from(json));
      }
    } catch (_) {
      // A damaged sidecar must not prevent opening the original PDF.
    }
    return PdfAnnotationDocument();
  }

  Future<void> recordRecent(RecentPdfDocument document) async {
    final directory = await _privateDirectory();
    final target = File('${directory.path}/recent.json');
    final temporary = File('${target.path}.part');
    final recent = (await loadRecentDocuments()).toList();
    recent.removeWhere((item) => item.url == document.url);
    recent.insert(0, document);
    await temporary.writeAsString(
      jsonEncode(recent.take(20).map((item) => item.toJson()).toList()),
      flush: true,
    );
    if (await target.exists()) await target.delete();
    await temporary.rename(target.path);
  }

  Future<void> removeRecent(String url) async {
    final directory = await _privateDirectory();
    final target = File('${directory.path}/recent.json');
    final temporary = File('${target.path}.part');
    final recent = (await loadRecentDocuments()).toList();
    recent.removeWhere((item) => item.url == url);
    await temporary.writeAsString(
      jsonEncode(recent.map((item) => item.toJson()).toList()),
      flush: true,
    );
    if (await target.exists()) await target.delete();
    await temporary.rename(target.path);
  }

  String _safeTitle(String value) {
    final result = value.replaceAll(RegExp(r'[^\w\s]+'), '_').trim();
    return result.isEmpty ? 'document' : result;
  }

  String _stableHash(String value) {
    var hash = 0x811c9dc5;
    for (final unit in value.codeUnits) {
      hash = ((hash ^ unit) * 0x01000193) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }
}
