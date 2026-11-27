String normalizeNovelWord(String word) => word
    .replaceAll('\u2019', "'")
    .trim()
    .toLowerCase()
    .replaceAll(RegExp(r"[^a-z0-9'-]"), '');
