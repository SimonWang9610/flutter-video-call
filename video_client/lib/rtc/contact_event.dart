class ContactEvent {
  final bool online;
  final String userid;
  final String username;

  ContactEvent({
    required this.userid,
    required this.username,
    this.online = true,
  });
}
