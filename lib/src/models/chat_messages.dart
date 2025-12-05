class ChatMessage {
  final String text;
  final bool isGuru; // true = Guru AI, false = user

  ChatMessage({
    required this.text,
    required this.isGuru,
  });
}
