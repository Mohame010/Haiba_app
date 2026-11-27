List<String> splitNovelSentences(String text) {
  const sentencePunctuation = '.!?؟';
  final sentences = <String>[];
  var start = 0;

  void addSentence(int end) {
    final sentence = text.substring(start, end).trim();
    if (sentence.isNotEmpty) sentences.add(sentence);
  }

  for (var index = 0; index < text.length; index++) {
    final character = text[index];
    if (character == '\n') {
      addSentence(index);
      start = index + 1;
      continue;
    }

    if (!sentencePunctuation.contains(character)) continue;
    var boundaryEnd = index + 1;
    // English dialogue commonly stores the closing quote after the full stop:
    // `... sunset.” Lina ...`. Treat that quote as part of the sentence.
    while (
        boundaryEnd < text.length &&
        '”"’\'»)]}'.contains(text[boundaryEnd])) {
      boundaryEnd++;
    }
    if (boundaryEnd < text.length &&
        text[boundaryEnd].trim().isNotEmpty) {
      continue;
    }

    // Keep quoted dialogue attribution together: `“Is this the key?” Sami asks.`
    if (boundaryEnd > index + 1 &&
        (character == '?' || character == '!') &&
        _hasDialogueAttribution(text, boundaryEnd)) {
      continue;
    }

    addSentence(boundaryEnd);
    index = boundaryEnd;
    while (index < text.length && text[index].trim().isEmpty) {
      index++;
    }
    start = index;
    index--;
  }

  addSentence(text.length);
  return sentences;
}

bool _hasDialogueAttribution(String text, int start) {
  final remainder = text.substring(start).trimLeft();
  return RegExp(
    r"^[A-Za-z][A-Za-z'-]*\s+(asks|asked|says|said|answers|answered|replies|replied|whispers|whispered)\b",
  ).hasMatch(remainder);
}

List<(String, String)> alignNovelText(String english, String arabic) {
  final englishSentences = splitNovelSentences(english);
  final arabicSentences = splitNovelSentences(arabic);

  if (arabicSentences.isEmpty) {
    return [for (final sentence in englishSentences) (sentence, '')];
  }

  // Prefer explicit line boundaries. This is the format used by the novel
  // seed and it remains reliable when punctuation differs between languages.
  final englishLines = _paragraphs(english);
  final arabicLines = _paragraphs(arabic);
  if (englishLines.length <= 1 || arabicLines.length <= 1) {
    // Some legacy rows stored the whole chapter in one line. When quoted
    // punctuation gives us an unambiguous sentence boundary, keep the
    // translations paired instead of attaching Lina's sentence to the note.
    if (englishSentences.length == arabicSentences.length &&
        english.contains(RegExp(r'[”»]'))) {
      return [
        for (var index = 0; index < englishSentences.length; index++)
          (englishSentences[index], arabicSentences[index]),
      ];
    }
    return [for (final sentence in englishSentences) (sentence, '')];
  }
  if (englishLines.length > 1 && englishLines.length == arabicLines.length) {
    return [
      for (var index = 0; index < englishLines.length; index++)
        (englishLines[index], arabicLines[index]),
    ];
  }

  // Do not hide every translation because one sentence is missing or has a
  // different punctuation mark. Pair what is available and leave only the
  // unmatched sentence empty.
  return [
    for (var index = 0; index < englishSentences.length; index++)
      (
        englishSentences[index],
        index < arabicSentences.length ? arabicSentences[index] : '',
      ),
  ];
}

List<String> _paragraphs(String text) => text
    .split('\n')
    .map((paragraph) => paragraph.trim())
    .where((paragraph) => paragraph.isNotEmpty)
    .toList();
