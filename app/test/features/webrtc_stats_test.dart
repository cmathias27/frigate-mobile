import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:frigate_mobile/features/live/webrtc_live_video.dart';

void main() {
  StatsReport report(String type, Map<String, dynamic> values) =>
      StatsReport('id', type, 0, values);

  test('frames decoded come from the video inbound report', () {
    expect(
      framesDecoded([
        report('transport', {'bytesReceived': 10}),
        report('inbound-rtp', {'kind': 'audio', 'packetsReceived': 5}),
        report('inbound-rtp', {'kind': 'video', 'framesDecoded': 42}),
      ]),
      42,
    );
    expect(
      framesDecoded([
        report('inbound-rtp', {'mediaType': 'video', 'framesDecoded': 7.0}),
      ]),
      7,
    );
  });

  test('no video report: unknown', () {
    expect(
      framesDecoded([
        report('inbound-rtp', {'kind': 'audio'}),
      ]),
      isNull,
    );
    expect(framesDecoded(const []), isNull);
  });
}
