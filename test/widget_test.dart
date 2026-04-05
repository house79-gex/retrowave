import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:retrowave/main.dart';
import 'package:retrowave/services/device_manager.dart';

void main() {
  testWidgets('App avvia shell con navigazione', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => DeviceManager(),
        child: const RetroWaveApp(),
      ),
    );
    await tester.pump();
    expect(find.textContaining('Dispositivi'), findsWidgets);
  });
}
