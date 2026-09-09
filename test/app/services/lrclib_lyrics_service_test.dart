import 'package:flutter_test/flutter_test.dart';
import 'package:listenfy/app/services/lrclib_lyrics_service.dart';

void main() {
  group('LrclibLyricsResult.parseLrc', () {
    test('parses multiple timestamps and ignores metadata lines', () {
      final cues = LrclibLyricsResult.parseLrc('''
[ar:Artist]
[00:01.20][00:03.40]Repeated line
[01:02.005]Final line
''');

      expect(cues, hasLength(3));
      expect(cues[0].startMs, 1200);
      expect(cues[1].startMs, 3400);
      expect(cues[0].text, 'Repeated line');
      expect(cues[2].startMs, 62005);
      expect(cues[2].text, 'Final line');
    });
  });
}
