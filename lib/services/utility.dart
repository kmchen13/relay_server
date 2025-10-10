String getTimestamp() {
  final now = DateTime.now();
  final h = now.hour.toString().padLeft(2, '0');
  final m = now.minute.toString().padLeft(2, '0');
  final s = now.second.toString().padLeft(2, '0');
  final ms = now.millisecond.toString().padLeft(3, '0');
  return '[$h:$m:$s.$ms]';
}

String logHeader(String caller) {
  return "[$caller]${getTimestamp()}";
}

void wait(msTime) async {
  await Future.delayed(Duration(milliseconds: msTime), () {});
}
