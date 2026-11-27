import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/helpers/app_logger.dart';

enum NovelAmbientSound {
  none,
  rain,
  birds,
  birdsAlt,
  water,
  sea,
  fire,
  angel,
  mix,
}

extension NovelAmbientSoundLabel on NovelAmbientSound {
  String get label => switch (this) {
    NovelAmbientSound.none => 'بدون صوت',
    NovelAmbientSound.rain => 'صوت المطر',
    NovelAmbientSound.birds => 'صوت العصافير',
    NovelAmbientSound.birdsAlt => 'صوت عصافير ٢',
    NovelAmbientSound.water => 'صوت المياه',
    NovelAmbientSound.sea => 'صوت البحر',
    NovelAmbientSound.fire => 'صوت النار',
    NovelAmbientSound.angel => 'صوت ملائكي',
    NovelAmbientSound.mix => 'مزيج أصوات الطبيعة',
  };
}

class NovelAmbienceService {
  static const bucket = 'novel-ambience';

  Future<bool> isCached(NovelAmbientSound sound) async {
    if (sound == NovelAmbientSound.none) return true;
    final file = await _cacheFile(sound);
    return file.exists();
  }

  Future<String> downloadFromStorage(NovelAmbientSound sound) async {
    if (sound == NovelAmbientSound.none) {
      throw ArgumentError.value(sound, 'sound');
    }
    final file = await _cacheFile(sound);
    if (await file.exists()) {
      AppLogger.log(
        'Ambient cache hit: sound=${sound.name}, file=${file.path}',
        name: 'NOVEL_AMBIENCE',
      );
      return file.path;
    }

    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    final storagePath = await _storagePathFor(sound);
    AppLogger.log(
      'Ambient download start: bucket=$bucket, path=$storagePath, '
      'sound=${sound.name}, userId=${userId ?? '<anonymous>'}',
      name: 'NOVEL_AMBIENCE',
    );

    try {
      final bytes = await client.storage.from(bucket).download(storagePath);
      await file.writeAsBytes(bytes, flush: true);
      AppLogger.log(
        'Ambient download success: bucket=$bucket, path=$storagePath, '
        'bytes=${bytes.length}, cache=${file.path}',
        name: 'NOVEL_AMBIENCE',
      );
      return file.path;
    } catch (error, stackTrace) {
      AppLogger.log(
        'Ambient download failed: bucket=$bucket, path=$storagePath, '
        'sound=${sound.name}, userId=${userId ?? '<anonymous>'}',
        name: 'NOVEL_AMBIENCE',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<String> _storagePathFor(NovelAmbientSound sound) async {
    final category = switch (sound) {
      NovelAmbientSound.birdsAlt => 'birds',
      _ => sound.name,
    };
    final order = sound == NovelAmbientSound.birdsAlt ? 1 : 0;
    try {
      final rows = await Supabase.instance.client
          .from('novel_ambience_tracks')
          .select('storage_path,title,category,sort_order')
          .eq('category', category)
          .eq('is_active', true)
          .order('sort_order')
          .range(order, order);
      final row = rows.isNotEmpty
          ? Map<String, dynamic>.from(rows.first as Map)
          : null;
      final configured = row?['storage_path']?.toString();
      if (configured != null && configured.trim().isNotEmpty) {
        final path = configured.trim().replaceFirst(RegExp(r'^/+'), '');
        final normalized = path.startsWith('$bucket/')
            ? path.substring(bucket.length + 1)
            : path;
        AppLogger.log(
          'Ambient row resolved: category=$category, order=$order, '
          'title=${row?['title']}, storage_path=$normalized',
          name: 'NOVEL_AMBIENCE',
        );
        return normalized;
      }
      AppLogger.log(
        'No active ambient row found: category=$category, order=$order. '
        'Using fallback path.',
        name: 'NOVEL_AMBIENCE',
      );
    } catch (error, stackTrace) {
      AppLogger.log(
        'Ambient table lookup failed: table=novel_ambience_tracks, '
        'category=$category, order=$order. Using fallback path.',
        name: 'NOVEL_AMBIENCE',
        error: error,
        stackTrace: stackTrace,
      );
    }
    return sound == NovelAmbientSound.birdsAlt
        ? 'birds_2.wav'
        : '${sound.name}.wav';
  }

  Future<String> createFile(NovelAmbientSound sound) async {
    if (sound == NovelAmbientSound.none) {
      throw ArgumentError.value(sound, 'sound', 'لا يوجد ملف لصوت الصمت.');
    }
    final file = await _cacheFile(sound);
    if (!await file.exists()) {
      throw StateError('هذا الصوت غير محمّل بعد. اضغط زر التحميل أولًا.');
    }
    return file.path;
  }

  Future<File> _cacheFile(NovelAmbientSound sound) async {
    final directory = await getApplicationSupportDirectory();
    final cache = Directory(
      '${directory.path}${Platform.pathSeparator}novel_ambience_cache',
    );
    await cache.create(recursive: true);
    final fileName = sound == NovelAmbientSound.birdsAlt
        ? 'birds_2'
        : sound.name;
    return File('${cache.path}${Platform.pathSeparator}$fileName.wav');
  }
}

Uint8List _buildWave(NovelAmbientSound sound) {
  const sampleRate = 16000;
  const sampleCount = sampleRate * 12;
  final random = Random(1401 + sound.index);
  final samples = Float32List(sampleCount);
  final birdCalls = <(int, int, double, double)>[];
  if (sound == NovelAmbientSound.birds ||
      sound == NovelAmbientSound.birdsAlt ||
      sound == NovelAmbientSound.mix) {
    var start = 0;
    while (start < sampleCount) {
      start += sampleRate ~/ 3 + random.nextInt(sampleRate * 2);
      final duration = sampleRate ~/ 10 + random.nextInt(sampleRate ~/ 5);
      birdCalls.add((
        start,
        min(start + duration, sampleCount),
        1800 + random.nextDouble() * 1500,
        2100 + random.nextDouble() * 1800,
      ));
    }
  }

  var lowNoise = 0.0;
  var brownNoise = 0.0;
  var crackle = 0.0;
  var birdIndex = 0;
  for (var index = 0; index < sampleCount; index++) {
    final noise = random.nextDouble() * 2 - 1;
    lowNoise = lowNoise * .96 + noise * .04;
    brownNoise = (brownNoise + noise * .015).clamp(-1, 1);
    if (random.nextDouble() < .0008) crackle = .65;
    crackle *= .995;
    final time = index / sampleRate;
    final waves = .25 + .75 * (1 + sin(2 * pi * time / 8)) / 2;
    var chirp = 0.0;
    while (birdIndex < birdCalls.length && index >= birdCalls[birdIndex].$2) {
      birdIndex++;
    }
    if (birdIndex < birdCalls.length) {
      final call = birdCalls[birdIndex];
      if (index >= call.$1 && index < call.$2) {
        final elapsed = (index - call.$1) / sampleRate;
        final duration = (call.$2 - call.$1) / sampleRate;
        final phase =
            2 *
            pi *
            (call.$3 * elapsed +
                .5 * (call.$4 - call.$3) * elapsed * elapsed / duration);
        chirp = sin(phase) * sin(pi * elapsed / duration) * .28;
      }
    }

    final rain = lowNoise * .22 + (noise.abs() > .997 ? noise * .14 : 0);
    final water = brownNoise * .34 + lowNoise * .12;
    final sea = (brownNoise * .42 + lowNoise * .2) * waves;
    final fire = lowNoise * .19 + crackle;
    final sample = switch (sound) {
      NovelAmbientSound.rain => rain,
      NovelAmbientSound.birds => chirp + lowNoise * .025,
      NovelAmbientSound.birdsAlt => chirp * .8 + lowNoise * .02,
      NovelAmbientSound.water => water,
      NovelAmbientSound.sea => sea,
      NovelAmbientSound.fire => fire,
      NovelAmbientSound.angel => lowNoise * .02,
      NovelAmbientSound.mix =>
        rain * .35 + chirp * .6 + water * .25 + sea * .25 + fire * .25,
      NovelAmbientSound.none => 0.0,
    };
    samples[index] = sample.clamp(-.95, .95);
  }

  final dataLength = sampleCount * 2;
  final bytes = Uint8List(44 + dataLength);
  final header = ByteData.sublistView(bytes);
  void writeAscii(int offset, String value) {
    for (var index = 0; index < value.length; index++) {
      bytes[offset + index] = value.codeUnitAt(index);
    }
  }

  writeAscii(0, 'RIFF');
  header.setUint32(4, 36 + dataLength, Endian.little);
  writeAscii(8, 'WAVE');
  writeAscii(12, 'fmt ');
  header.setUint32(16, 16, Endian.little);
  header.setUint16(20, 1, Endian.little);
  header.setUint16(22, 1, Endian.little);
  header.setUint32(24, sampleRate, Endian.little);
  header.setUint32(28, sampleRate * 2, Endian.little);
  header.setUint16(32, 2, Endian.little);
  header.setUint16(34, 16, Endian.little);
  writeAscii(36, 'data');
  header.setUint32(40, dataLength, Endian.little);
  for (var index = 0; index < sampleCount; index++) {
    header.setInt16(
      44 + index * 2,
      (samples[index] * 32767).round(),
      Endian.little,
    );
  }
  return bytes;
}
