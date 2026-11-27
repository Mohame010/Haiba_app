import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import '../../../novels/data/ambient_crossfade_player.dart';
import '../../../novels/data/novel_ambience_service.dart';

const _studyPlaybackChannel = MethodChannel('q360education/novel_playback');

class StudyAmbienceMixer extends StatefulWidget {
  const StudyAmbienceMixer({super.key});

  @override
  State<StudyAmbienceMixer> createState() => _StudyAmbienceMixerState();
}

class _StudyAmbienceMixerState extends State<StudyAmbienceMixer> {
  final _service = NovelAmbienceService();
  final Map<NovelAmbientSound, AmbientCrossfadePlayer> _players = {};
  final Set<NovelAmbientSound> _activeSounds = {};
  final Set<NovelAmbientSound> _cachedSounds = {};
  final Set<NovelAmbientSound> _downloadingSounds = {};
  final Map<NovelAmbientSound, double> _volumes = {
    for (final sound in NovelAmbientSound.values) sound: .35,
  };
  bool _expanded = false;
  Offset _position = const Offset(16, 75);
  bool _hasCustomPosition = false;

  List<NovelAmbientSound> get _sounds => NovelAmbientSound.values
      .where(
        (sound) =>
            sound != NovelAmbientSound.none && sound != NovelAmbientSound.mix,
      )
      .toList(growable: false);

  @override
  void initState() {
    super.initState();
    _checkCachedSounds();
  }

  Future<void> _checkCachedSounds() async {
    for (final sound in _sounds) {
      final cached = await _service.isCached(sound);
      if (cached && mounted) {
        setState(() {
          _cachedSounds.add(sound);
        });
      }
    }
  }

  @override
  void dispose() {
    unawaited(_disposePlayers());
    super.dispose();
  }

  Future<void> _disposePlayers() async {
    for (final player in _players.values) {
      await player.dispose();
    }
    if (Platform.isAndroid) {
      try {
        await _studyPlaybackChannel.invokeMethod<void>('stop');
      } on PlatformException {
        // The PDF is closing, so there is no useful UI for this failure.
      }
    }
  }

  Future<void> _syncBackgroundPlayback() async {
    if (!Platform.isAndroid) return;
    try {
      await _studyPlaybackChannel.invokeMethod<void>(
        _activeSounds.isEmpty ? 'stop' : 'start',
        _activeSounds.isEmpty ? null : const {'title': 'أصوات خلفية للمذاكرة'},
      );
    } on PlatformException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر تفعيل الصوت في الخلفية')),
        );
      }
    }
  }

  Future<void> _toggleSound(NovelAmbientSound sound) async {
    if (_activeSounds.contains(sound)) {
      setState(() {
        _activeSounds.remove(sound);
      });
      await _players[sound]?.stop();
      await _syncBackgroundPlayback();
      return;
    }

    if (!_cachedSounds.contains(sound)) {
      final isCached = await _service.isCached(sound);
      if (!isCached) {
        await _downloadSound(sound);
        if (!_cachedSounds.contains(sound)) return;
      } else {
        setState(() {
          _cachedSounds.add(sound);
        });
      }
    }

    try {
      final path = await _service.createFile(sound);
      final player = _players.putIfAbsent(sound, AmbientCrossfadePlayer.new);
      await player.play(path, volume: _volumes[sound] ?? .35);
      if (!mounted) return;
      setState(() {
        _activeSounds.add(sound);
      });
      await _syncBackgroundPlayback();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر تشغيل ${sound.label}: $error')),
        );
      }
    }
  }

  Future<void> _downloadSound(NovelAmbientSound sound) async {
    if (_downloadingSounds.contains(sound)) return;
    setState(() {
      _downloadingSounds.add(sound);
    });

    try {
      await _service.downloadFromStorage(sound);
      if (!mounted) return;
      setState(() {
        _cachedSounds.add(sound);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم تحميل ${sound.label} بنجاح')),
      );
      if (_activeSounds.contains(sound)) {
        final path = await _service.createFile(sound);
        final player = _players.putIfAbsent(sound, AmbientCrossfadePlayer.new);
        await player.play(path, volume: _volumes[sound] ?? .35);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر تحميل ${sound.label}: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _downloadingSounds.remove(sound);
        });
      } else {
        _downloadingSounds.remove(sound);
      }
    }
  }

  Future<void> _setVolume(NovelAmbientSound sound, double value) async {
    final volume = value.clamp(0.0, 1.0).toDouble();
    setState(() {
      _volumes[sound] = volume;
    });
    await _players[sound]?.setVolume(volume);
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final width = _expanded
        ? (screenSize.width - 24).clamp(260.0, 330.0)
        : 54.0;
    final height = _expanded ? 400.0 : 54.0;

    final defaultLeft = screenSize.width - width - 14.0;
    final currentLeft = (_hasCustomPosition ? _position.dx : defaultLeft)
        .clamp(10.0, math.max(10.0, screenSize.width - width - 10.0))
        .toDouble();
    final currentTop = (_hasCustomPosition ? _position.dy : 75.0)
        .clamp(10.0, math.max(10.0, screenSize.height - height - 20.0))
        .toDouble();

    if (!_expanded) {
      return Positioned(
        left: currentLeft,
        top: currentTop,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanUpdate: (details) {
            setState(() {
              _hasCustomPosition = true;
              _position = Offset(
                currentLeft + details.delta.dx,
                currentTop + details.delta.dy,
              );
            });
          },
          child: Material(
            color: Colors.white.withValues(alpha: .96),
            elevation: 8,
            shadowColor: Colors.black38,
            shape: const CircleBorder(),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                IconButton(
                  tooltip: 'أصوات الخلفية (اسحب لتحريك الأيقونة)',
                  onPressed: () => setState(() => _expanded = true),
                  icon: Icon(
                    _activeSounds.isNotEmpty
                        ? Icons.graphic_eq_rounded
                        : Icons.surround_sound_rounded,
                    color: _activeSounds.isNotEmpty
                        ? const Color(0xFF6D28D9)
                        : const Color(0xFF475569),
                  ),
                ),
                if (_activeSounds.isNotEmpty)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      width: 11,
                      height: 11,
                      decoration: BoxDecoration(
                        color: const Color(0xFF22C55E),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x6622C55E),
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return Positioned(
      left: currentLeft,
      top: currentTop,
      width: width,
      child: Material(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: .96),
        elevation: 10,
        shadowColor: Colors.black26,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 8, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanUpdate: (details) {
                  setState(() {
                    _hasCustomPosition = true;
                    _position = Offset(
                      currentLeft + details.delta.dx,
                      currentTop + details.delta.dy,
                    );
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.drag_indicator_rounded,
                        color: Colors.black38,
                        size: 20,
                      ),
                      const SizedBox(width: 4),
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Icon(
                            _activeSounds.isNotEmpty
                                ? Icons.graphic_eq_rounded
                                : Icons.surround_sound_rounded,
                            color: const Color(0xFF6D28D9),
                            size: 22,
                          ),
                          if (_activeSounds.isNotEmpty)
                            Positioned(
                              top: -2,
                              right: -2,
                              child: Container(
                                width: 9,
                                height: 9,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF22C55E),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 1.5,
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x6622C55E),
                                      blurRadius: 3,
                                      spreadRadius: .5,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'أصوات الخلفية',
                        style: TextStyle(
                          fontFamily: 'IBM',
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                      if (_activeSounds.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF22C55E),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${_activeSounds.length} شغال',
                                style: const TextStyle(
                                  color: Color(0xFF16A34A),
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: 'IBM',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const Spacer(),
                      IconButton(
                        tooltip: 'تصغير',
                        onPressed: () => setState(() => _expanded = false),
                        icon: const Icon(Icons.remove_rounded),
                      ),
                    ],
                  ),
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 380),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _sounds.length,
                  separatorBuilder: (_, _) => const Divider(height: 6),
                  itemBuilder: (context, index) {
                    final sound = _sounds[index];
                    final active = _activeSounds.contains(sound);
                    final cached = _cachedSounds.contains(sound);
                    final downloading = _downloadingSounds.contains(sound);
                    final volume = _volumes[sound] ?? .35;

                    return Column(
                      children: [
                        Row(
                          children: [
                            Icon(
                              active
                                  ? Icons.graphic_eq_rounded
                                  : Icons.volume_off_outlined,
                              size: 21,
                              color: active
                                  ? const Color(0xFF22C55E)
                                  : const Color(0xFF94A3B8),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${sound.label} • ${active ? 'شغال' : 'متوقف'}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: 'IBM',
                                  fontSize: 13,
                                  fontWeight: active
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: active
                                      ? const Color(0xFF1E293B)
                                      : const Color(0xFF64748B),
                                ),
                              ),
                            ),
                            if (downloading)
                              const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox.square(
                                  dimension: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFF6D28D9),
                                  ),
                                ),
                              )
                            else if (!cached)
                              IconButton(
                                tooltip: 'تحميل ${sound.label}',
                                onPressed: () => _downloadSound(sound),
                                icon: const Icon(
                                  Icons.download_for_offline_outlined,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            Switch(
                              value: active,
                              activeColor: const Color(0xFF6D28D9),
                              onChanged: downloading
                                  ? null
                                  : (_) => _toggleSound(sound),
                            ),
                          ],
                        ),
                        if (active)
                          Padding(
                            padding: const EdgeInsets.only(top: 2, bottom: 4),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.volume_down_rounded,
                                  size: 20,
                                  color: Color(0xFF6D28D9),
                                ),
                                Expanded(
                                  child: Slider(
                                    value: volume.clamp(0.0, 1.0),
                                    onChanged: (value) =>
                                        _setVolume(sound, value),
                                    activeColor: const Color(0xFF6D28D9),
                                    inactiveColor: const Color(0xFFE2E8F0),
                                  ),
                                ),
                                SizedBox(
                                  width: 38,
                                  child: Text(
                                    '${(volume * 100).round()}%',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      fontFamily: 'IBM',
                                      color: Color(0xFF475569),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
