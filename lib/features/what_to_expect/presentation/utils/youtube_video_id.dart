String? youtubeVideoId(String url) {
  final uri = Uri.tryParse(url.trim());
  if (uri == null) return null;
  final host = uri.host.toLowerCase().replaceFirst('www.', '');
  if (host == 'youtu.be' && uri.pathSegments.isNotEmpty) {
    return _validId(uri.pathSegments.first);
  }
  if (host == 'youtube.com' ||
      host == 'm.youtube.com' ||
      host == 'youtube-nocookie.com') {
    if (uri.queryParameters['v'] case final id?) return _validId(id);
    final segments = uri.pathSegments;
    if (segments.length >= 2 &&
        const {'shorts', 'embed', 'live'}.contains(segments.first)) {
      return _validId(segments[1]);
    }
  }
  return null;
}

String? _validId(String value) {
  final clean = value.trim();
  return RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(clean) ? clean : null;
}
