enum PlaybackQuality {
  low('360'),
  high('720');

  const PlaybackQuality(this.apiValue);

  final String apiValue;
}
