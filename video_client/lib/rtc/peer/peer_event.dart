class PeerEvent {
  final bool isCalling;
  final bool canLocalPreview;
  final String? action;

  PeerEvent({
    this.isCalling = true,
    this.canLocalPreview = false,
    this.action,
  });
}
