String formatPakistanPhone(String input) {
  final phone = input.replaceAll(RegExp(r'[\s()-]'), '');

  if (phone.startsWith('+92')) return phone;
  if (phone.startsWith('0092')) return '+${phone.substring(2)}';
  if (phone.startsWith('03')) return '+92${phone.substring(1)}';
  if (phone.startsWith('3')) return '+92$phone';

  return phone.startsWith('+') ? phone : '+92$phone';
}
