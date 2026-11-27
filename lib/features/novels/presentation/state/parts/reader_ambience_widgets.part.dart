part of '../novel_reader_state.dart';

extension _ReaderAmbienceWidgets on NovelReaderState {
  Widget _buildAmbientMixerOverlay() => ValueListenableBuilder<Offset>(
    valueListenable: _mixerPosition,
    builder: (context, position, child) {
      final size = MediaQuery.sizeOf(context);
      final width = _ambiencePanelVisible
          ? math.min(330.0, size.width - 24)
          : 54.0;
      final left = position.dx
          .clamp(12.0, math.max(12.0, size.width - width - 12))
          .toDouble();
      final top = position.dy
          .clamp(
            12.0,
            math.max(12.0, size.height - (_ambiencePanelVisible ? 520 : 54)),
          )
          .toDouble();
      final sounds = NovelAmbientSound.values
          .where(
            (sound) =>
                sound != NovelAmbientSound.none &&
                sound != NovelAmbientSound.mix,
          )
          .toList();

      if (!_ambiencePanelVisible) {
        return Positioned(
          left: left,
          top: top,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanUpdate: (details) => _moveMixer(details.delta),
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
                    onPressed: () =>
                        _updateState(() => _ambiencePanelVisible = true),
                    icon: Icon(
                      _activeAmbienceSounds.isNotEmpty
                          ? Icons.graphic_eq_rounded
                          : Icons.surround_sound_rounded,
                      color: _activeAmbienceSounds.isNotEmpty
                          ? const Color(0xFF6D28D9)
                          : const Color(0xFF475569),
                    ),
                  ),
                  if (_activeAmbienceSounds.isNotEmpty)
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
        left: left,
        top: top,
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
                  onPanUpdate: (details) => _moveMixer(details.delta),
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
                              _activeAmbienceSounds.isNotEmpty
                                  ? Icons.graphic_eq_rounded
                                  : Icons.surround_sound_rounded,
                              color: const Color(0xFF6D28D9),
                              size: 22,
                            ),
                            if (_activeAmbienceSounds.isNotEmpty)
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
                        if (_activeAmbienceSounds.isNotEmpty) ...[
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
                                  '${_activeAmbienceSounds.length} شغال',
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
                          onPressed: () =>
                              _updateState(() => _ambiencePanelVisible = false),
                          icon: const Icon(Icons.remove_rounded),
                        ),
                      ],
                    ),
                  ),
                ),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: math.min(
                      400.0,
                      math.max(160.0, size.height - 160),
                    ),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: sounds.length,
                    separatorBuilder: (_, _) => const Divider(height: 6),
                    itemBuilder: (context, index) {
                      final sound = sounds[index];
                      final active = _activeAmbienceSounds.contains(sound);
                      final volume = _ambienceVolumes[sound] ?? .35;
                      return FutureBuilder<bool>(
                        future: _ambience.isCached(sound),
                        builder: (context, snapshot) {
                          final cached = snapshot.data == true;
                          final downloading = _downloadingAmbienceSounds
                              .contains(sound);
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
                                      onPressed: () =>
                                          unawaited(_downloadAmbience(sound)),
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
                                        : (_) => unawaited(
                                            _selectAmbience(sound),
                                          ),
                                  ),
                                ],
                              ),
                              if (active)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    top: 2,
                                    bottom: 4,
                                  ),
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
                                              _setAmbienceVolume(sound, value),
                                          activeColor: const Color(0xFF6D28D9),
                                          inactiveColor: const Color(
                                            0xFFE2E8F0,
                                          ),
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
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
