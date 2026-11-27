import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/internet_connection_mixin.dart';
import '../../domain/entities/lecture_content_entity.dart';
import '../../domain/entities/lecture_entity.dart';
import 'download_foreground_bridge.dart';

typedef DownloadProgress = void Function(double progress, String message);

class DownloadedContent {
  final String id;
  final ContentType type;
  final String title;
  final String? subtitle;
  final String localPath;
  final int sortOrder;

  const DownloadedContent({
    required this.id,
    required this.type,
    required this.title,
    this.subtitle,
    required this.localPath,
    required this.sortOrder,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'title': title,
    'subtitle': subtitle,
    'localPath': localPath,
    'sortOrder': sortOrder,
  };

  factory DownloadedContent.fromJson(Map<String, dynamic> json) {
    return DownloadedContent(
      id: json['id'] as String? ?? '',
      type: ContentType.values.firstWhere(
        (value) => value.name == json['type'],
        orElse: () => ContentType.video,
      ),
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String?,
      localPath: json['localPath'] as String? ?? '',
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
    );
  }
}

class DownloadedLecture {
  final String lectureId;
  final String title;
  final String description;
  final String subject;
  final String chapter;
  final String lessonNumber;
  final String groupId;
  final String groupTitle;
  final String groupType;
  final DateTime downloadedAt;
  final List<DownloadedContent> contents;

  const DownloadedLecture({
    required this.lectureId,
    required this.title,
    required this.description,
    required this.subject,
    required this.chapter,
    required this.lessonNumber,
    required this.groupId,
    required this.groupTitle,
    required this.groupType,
    required this.downloadedAt,
    required this.contents,
  });

  Map<String, dynamic> toJson() => {
    'lectureId': lectureId,
    'title': title,
    'description': description,
    'subject': subject,
    'chapter': chapter,
    'lessonNumber': lessonNumber,
    'groupId': groupId,
    'groupTitle': groupTitle,
    'groupType': groupType,
    'downloadedAt': downloadedAt.toIso8601String(),
    'contents': contents.map((item) => item.toJson()).toList(),
  };

  factory DownloadedLecture.fromJson(Map<String, dynamic> json) {
    return DownloadedLecture(
      lectureId: json['lectureId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      subject: json['subject'] as String? ?? '',
      chapter: json['chapter'] as String? ?? '',
      lessonNumber: json['lessonNumber'] as String? ?? '',
      groupId: json['groupId'] as String? ?? '',
      groupTitle: json['groupTitle'] as String? ?? 'دروس منفردة',
      groupType: json['groupType'] as String? ?? 'subject',
      downloadedAt:
          DateTime.tryParse(json['downloadedAt'] as String? ?? '') ??
          DateTime.now(),
      contents: (json['contents'] as List<dynamic>? ?? const [])
          .map(
            (item) => DownloadedContent.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
    );
  }
}

/// Stores offline media under the app's private support directory. Android's
/// gallery and file picker cannot index this location on a normal device.
class OfflineLectureService with InternetConnectionMixin {
  OfflineLectureService._();

  static final OfflineLectureService instance = OfflineLectureService._();
  final Set<String> _cancelledDownloads = <String>{};
  final Set<String> _activeDownloads = <String>{};
  final Map<String, Future<String>> _videoCacheJobs = {};

  String get _userId =>
      Supabase.instance.client.auth.currentUser?.id ?? 'anonymous';

  Future<Directory> _root() async {
    final support = await getApplicationSupportDirectory();
    final safeUser = _userId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final directory = Directory('${support.path}/offline_lectures/$safeUser');
    await directory.create(recursive: true);
    return directory;
  }

  Future<File> _indexFile() async => File('${(await _root()).path}/index.json');

  Future<Directory> _videoCacheDirectory(String cacheKey) async {
    final support = await getApplicationSupportDirectory();
    final safeKey = cacheKey.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final safeUser = _userId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    return Directory('${support.path}/video_cache/$safeUser/$safeKey');
  }

  Future<String?> getCachedVideoPath({
    required String cacheKey,
    required String sourceUrl,
  }) async {
    try {
      final directory = await _videoCacheDirectory(cacheKey);
      final metadata = File('${directory.path}/metadata.json');
      if (!await metadata.exists()) return null;
      final json = Map<String, dynamic>.from(
        jsonDecode(await metadata.readAsString()) as Map,
      );
      if (json['source_url'] != sourceUrl) return null;
      final localPath = json['local_path'] as String?;
      if (localPath == null ||
          FileSystemEntity.typeSync(localPath) ==
              FileSystemEntityType.notFound) {
        return null;
      }
      return localPath;
    } catch (_) {
      return null;
    }
  }

  Future<String> cacheVideo({
    required String cacheKey,
    required String sourceUrl,
  }) {
    final existing = _videoCacheJobs[cacheKey];
    if (existing != null) return existing;
    final job = _cacheVideo(cacheKey: cacheKey, sourceUrl: sourceUrl);
    _videoCacheJobs[cacheKey] = job;
    return job.whenComplete(() => _videoCacheJobs.remove(cacheKey));
  }

  Future<String> _cacheVideo({
    required String cacheKey,
    required String sourceUrl,
  }) async {
    final cached = await getCachedVideoPath(
      cacheKey: cacheKey,
      sourceUrl: sourceUrl,
    );
    if (cached != null) return cached;

    final directory = await _videoCacheDirectory(cacheKey);
    final metadata = File('${directory.path}/metadata.json');
    if (await metadata.exists()) {
      await directory.delete(recursive: true);
    }
    await directory.create(recursive: true);
    final jobId = 'video_cache_$cacheKey';
    final localPath = sourceUrl.toLowerCase().contains('.m3u8')
        ? await _downloadHls(
            sourceUrl,
            Directory('${directory.path}/hls'),
            jobId,
            (_) {},
          )
        : await _downloadFile(sourceUrl, directory, 'video', jobId, (_) {});
    await metadata.writeAsString(
      jsonEncode({'source_url': sourceUrl, 'local_path': localPath}),
      flush: true,
    );
    return localPath;
  }

  Future<List<DownloadedLecture>> getDownloads() async {
    try {
      final file = await _indexFile();
      if (!await file.exists()) return [];
      final raw = jsonDecode(await file.readAsString()) as List<dynamic>;
      final downloads = raw
          .map(
            (item) => DownloadedLecture.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .where(
            (item) => item.contents.any(
              (content) =>
                  FileSystemEntity.typeSync(content.localPath) !=
                  FileSystemEntityType.notFound,
            ),
          )
          .toList();
      downloads.sort((a, b) => b.downloadedAt.compareTo(a.downloadedAt));
      return downloads;
    } catch (_) {
      return [];
    }
  }

  Future<bool> isDownloaded(String lectureId) async =>
      (await getDownloads()).any((item) => item.lectureId == lectureId);

  Future<DownloadedLecture?> getDownloadedLecture(String lectureId) async {
    for (final item in await getDownloads()) {
      if (item.lectureId == lectureId) return item;
    }
    return null;
  }

  Future<void> downloadLecture(
    LectureEntity lecture, {
    required DownloadProgress onProgress,
  }) async {
    final root = await _root();
    final safeId = lecture.id.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final target = Directory('${root.path}/$safeId');
    await target.create(recursive: true);
    _cancelledDownloads.remove(lecture.id);
    _activeDownloads.add(lecture.id);
    await DownloadForegroundBridge.start(lecture.id, lecture.title);
    var lastNotificationProgress = -1;

    void report(double progress, String message) {
      onProgress(progress, message);
      final percent = (progress * 100).floor();
      if (percent != lastNotificationProgress) {
        lastNotificationProgress = percent;
        unawaited(
          DownloadForegroundBridge.update(lecture.id, lecture.title, progress),
        );
      }
    }

    try {
      final group = await _resolveGroup(lecture);
      final downloadable = lecture.contents
          .where(
            (item) =>
                item.fileUrl.trim().isNotEmpty &&
                item.contentType != ContentType.summary,
          )
          .toList();
      if (downloadable.isEmpty) throw StateError('لا توجد ملفات قابلة للتنزيل');

      final saved = <DownloadedContent>[];
      for (var index = 0; index < downloadable.length; index++) {
        final content = downloadable[index];
        final base = index / downloadable.length;
        final share = 1 / downloadable.length;
        _throwIfCancelled(lecture.id);
        report(base, 'جاري تنزيل ${content.title}');
        final isHls =
            content.contentType == ContentType.video &&
            content.fileUrl.toLowerCase().contains('.m3u8');
        final localPath = isHls && Platform.isIOS
            ? await DownloadForegroundBridge.downloadIosHls(
                lectureId: lecture.id,
                title: content.title,
                url: content.fileUrl,
                onProgress: (value) =>
                    report(base + value * share, content.title),
                isCancelled: () => _cancelledDownloads.contains(lecture.id),
              )
            : isHls
            ? await _downloadHls(
                content.fileUrl,
                Directory('${target.path}/video_$index'),
                lecture.id,
                (value) => report(base + value * share, content.title),
              )
            : await _downloadFile(
                content.fileUrl,
                target,
                '${content.contentType.name}_$index',
                lecture.id,
                (value) => report(base + value * share, content.title),
              );
        saved.add(
          DownloadedContent(
            id: content.id,
            type: content.contentType,
            title: content.title,
            subtitle: content.subtitle,
            localPath: localPath,
            sortOrder: content.sortOrder,
          ),
        );
      }

      final record = DownloadedLecture(
        lectureId: lecture.id,
        title: lecture.title,
        description: lecture.description,
        subject: lecture.subject,
        chapter: lecture.chapter,
        lessonNumber: lecture.lessonNumber,
        groupId: group.$1,
        groupTitle: group.$2,
        groupType: group.$3,
        downloadedAt: DateTime.now(),
        contents: saved,
      );
      final all = await getDownloads()
        ..removeWhere((item) => item.lectureId == lecture.id)
        ..insert(0, record);
      await (await _indexFile()).writeAsString(
        jsonEncode(all.map((item) => item.toJson()).toList()),
        flush: true,
      );
      report(1, 'اكتمل التنزيل');
      await DownloadForegroundBridge.complete(lecture.id, lecture.title);
    } on IosDownloadCancelledException {
      if (await target.exists()) await target.delete(recursive: true);
      await DownloadForegroundBridge.stop(lecture.id);
      rethrow;
    } on DownloadCancelledException {
      if (await target.exists()) await target.delete(recursive: true);
      await DownloadForegroundBridge.stop(lecture.id);
      rethrow;
    } catch (_) {
      // Keep partial files so a later tap resumes with HTTP Range requests.
      await DownloadForegroundBridge.stop(lecture.id);
      rethrow;
    } finally {
      _activeDownloads.remove(lecture.id);
      _cancelledDownloads.remove(lecture.id);
    }
  }

  void _throwIfCancelled(String lectureId) {
    if (_cancelledDownloads.contains(lectureId)) {
      throw const DownloadCancelledException();
    }
  }

  Future<void> cancelDownload(String lectureId) async {
    _cancelledDownloads.add(lectureId);
    await DownloadForegroundBridge.stop(lectureId);
    if (!_activeDownloads.contains(lectureId)) {
      await deleteDownload(lectureId, includePartial: true);
    }
  }

  Future<(String, String, String)> _resolveGroup(LectureEntity lecture) async {
    try {
      final row = await Supabase.instance.client
          .from('course_lectures')
          .select('course_id, courses(title)')
          .eq('lecture_id', lecture.id)
          .limit(1)
          .maybeSingle();
      if (row != null) {
        final course = row['courses'];
        final title = course is Map ? course['title'] as String? : null;
        return (
          row['course_id'] as String? ?? lecture.subject,
          title?.trim().isNotEmpty == true ? title! : lecture.subject,
          'course',
        );
      }
    } catch (_) {}
    return (lecture.subject, lecture.subject, 'subject');
  }

  Future<String> _downloadFile(
    String url,
    Directory directory,
    String name,
    String lectureId,
    void Function(double) onProgress,
  ) async {
    final uri = Uri.parse(url);
    final extension = uri.pathSegments.isEmpty
        ? '.bin'
        : _extension(uri.pathSegments.last);
    final file = File('${directory.path}/$name$extension');
    final completeMarker = File('${file.path}.complete');
    if (await file.exists() && await completeMarker.exists()) {
      onProgress(1);
      return file.path;
    }
    final client = http.Client();
    try {
      _throwIfCancelled(lectureId);
      final existingBytes = await file.exists() ? await file.length() : 0;
      final request = http.Request('GET', uri);
      if (existingBytes > 0) request.headers['Range'] = 'bytes=$existingBytes-';
      final response = await runWithInternetConnection(
        () => client.send(request),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('HTTP ${response.statusCode}', uri: uri);
      }
      final canResume = response.statusCode == HttpStatus.partialContent;
      final sink = file.openWrite(
        mode: canResume ? FileMode.append : FileMode.write,
      );
      var received = canResume ? existingBytes : 0;
      final remaining = response.contentLength ?? 0;
      final total = remaining > 0 ? received + remaining : 0;
      await for (final chunk in response.stream) {
        _throwIfCancelled(lectureId);
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) onProgress((received / total).clamp(0, 1));
      }
      await sink.flush();
      await sink.close();
      await completeMarker.writeAsString('ok', flush: true);
      onProgress(1);
      return file.path;
    } finally {
      client.close();
    }
  }

  Future<String> _downloadHls(
    String url,
    Directory directory,
    String lectureId,
    void Function(double) onProgress,
  ) async {
    await directory.create(recursive: true);
    final masterUri = Uri.parse(url);
    final master = await _getText(masterUri);

    if (master.contains('#EXT-X-STREAM-INF')) {
      final lines = master.split(RegExp(r'\r?\n'));
      final variants = <(int, String, Uri)>[];
      for (var i = 0; i < lines.length - 1; i++) {
        if (!lines[i].startsWith('#EXT-X-STREAM-INF')) continue;
        final bandwidth =
            int.tryParse(
              RegExp(r'BANDWIDTH=(\d+)').firstMatch(lines[i])?.group(1) ?? '',
            ) ??
            0;
        final next = lines[i + 1].trim();
        if (next.isNotEmpty && !next.startsWith('#')) {
          variants.add((bandwidth, lines[i].trim(), masterUri.resolve(next)));
        }
      }
      if (variants.isEmpty) throw const FormatException('HLS variant missing');
      variants.sort((a, b) => a.$1.compareTo(b.$1));
      final selected = variants.last;

      final audioMatches = RegExp(
        r'#EXT-X-MEDIA:([^\r\n]*TYPE=AUDIO[^\r\n]*)',
      ).allMatches(master).toList();
      Uri? audioUri;
      String? audioTag;
      for (final match in audioMatches) {
        final tag = match.group(0)!;
        final uriValue = RegExp(r'URI="([^"]+)"').firstMatch(tag)?.group(1);
        if (uriValue == null) continue;
        audioUri = masterUri.resolve(uriValue);
        audioTag = tag;
        if (tag.contains('DEFAULT=YES')) break;
      }

      final videoPath = await _downloadMediaPlaylist(
        selected.$3,
        Directory('${directory.path}/video'),
        lectureId,
        (value) => onProgress(value * (audioUri == null ? 1 : .82)),
      );
      if (audioUri != null && audioTag != null) {
        await _downloadMediaPlaylist(
          audioUri,
          Directory('${directory.path}/audio'),
          lectureId,
          (value) => onProgress(.82 + value * .18),
        );
        final localAudioTag = audioTag.replaceAllMapped(
          RegExp(r'URI="[^"]+"'),
          (_) => 'URI="audio/offline.m3u8"',
        );
        final localMaster = [
          '#EXTM3U',
          localAudioTag,
          selected.$2,
          'video/offline.m3u8',
        ].join('\n');
        final output = File('${directory.path}/offline.m3u8');
        await output.writeAsString(localMaster, flush: true);
        return output.path;
      }
      return videoPath;
    }

    return _downloadMediaPlaylist(
      masterUri,
      directory,
      lectureId,
      onProgress,
      playlistText: master,
    );
  }

  Future<String> _downloadMediaPlaylist(
    Uri playlistUri,
    Directory directory,
    String lectureId,
    void Function(double) onProgress, {
    String? playlistText,
  }) async {
    await directory.create(recursive: true);
    final playlist = playlistText ?? await _getText(playlistUri);
    final resources = <Uri>[];
    for (final line in playlist.split(RegExp(r'\r?\n'))) {
      final trimmed = line.trim();
      if (trimmed.isNotEmpty && !trimmed.startsWith('#')) {
        resources.add(playlistUri.resolve(trimmed));
      }
      for (final match in RegExp(r'URI="([^"]+)"').allMatches(trimmed)) {
        resources.add(playlistUri.resolve(match.group(1)!));
      }
    }
    final unique = resources.toSet().toList();
    final replacements = <String, String>{};
    var completed = 0;

    for (var start = 0; start < unique.length; start += 4) {
      _throwIfCancelled(lectureId);
      final end = (start + 4).clamp(0, unique.length);
      await Future.wait([
        for (var i = start; i < end; i++)
          () async {
            final uri = unique[i];
            final extension = _extension(uri.pathSegments.last);
            final fileName = 'part_${i.toString().padLeft(5, '0')}$extension';
            await _downloadFile(
              uri.toString(),
              directory,
              'part_${i.toString().padLeft(5, '0')}',
              lectureId,
              (_) {},
            );
            replacements[uri.toString()] = fileName;
            completed++;
            onProgress(completed / unique.length);
          }(),
      ]);
    }

    final lines = playlist.split(RegExp(r'\r?\n'));
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isNotEmpty && !line.startsWith('#')) {
        final resolved = playlistUri.resolve(line);
        lines[i] = replacements[resolved.toString()] ?? line;
      } else {
        lines[i] = line.replaceAllMapped(RegExp(r'URI="([^"]+)"'), (match) {
          final resolved = playlistUri.resolve(match.group(1)!);
          return 'URI="${replacements[resolved.toString()] ?? match.group(1)!}"';
        });
      }
    }
    final file = File('${directory.path}/offline.m3u8');
    await file.writeAsString(lines.join('\n'), flush: true);
    return file.path;
  }

  Future<String> _getText(Uri uri) async {
    final response = await runWithInternetConnection(() => http.get(uri));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException('HTTP ${response.statusCode}', uri: uri);
    }
    return utf8.decode(response.bodyBytes);
  }

  String _extension(String name) {
    final clean = name.split('?').first;
    final dot = clean.lastIndexOf('.');
    if (dot < 0 || clean.length - dot > 8) return '.bin';
    return clean.substring(dot);
  }

  Future<void> deleteDownload(
    String lectureId, {
    bool includePartial = false,
  }) async {
    final downloads = await getDownloads();
    final item = downloads
        .where((entry) => entry.lectureId == lectureId)
        .firstOrNull;
    if (item != null && Platform.isIOS) {
      for (final content in item.contents) {
        if (content.type == ContentType.video) {
          final package = Directory(content.localPath);
          if (await package.exists()) await package.delete(recursive: true);
        }
      }
    }
    final root = await _root();
    final safeId = lectureId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final lectureDirectory = Directory('${root.path}/$safeId');
    if (await lectureDirectory.exists()) {
      await lectureDirectory.delete(recursive: true);
    }
    downloads.removeWhere((entry) => entry.lectureId == lectureId);
    if (includePartial) {
      final partial = Directory('${root.path}/$safeId');
      if (await partial.exists()) await partial.delete(recursive: true);
    }
    await (await _indexFile()).writeAsString(
      jsonEncode(downloads.map((item) => item.toJson()).toList()),
      flush: true,
    );
  }
}

class DownloadCancelledException implements Exception {
  const DownloadCancelledException();

  @override
  String toString() => 'تم إلغاء التنزيل';
}
