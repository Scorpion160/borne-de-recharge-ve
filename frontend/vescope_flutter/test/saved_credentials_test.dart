import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:vescope_supervisor/core/network/saved_credentials.dart';
import 'package:vescope_supervisor/ui/auth/mobile_login.dart';
import 'package:flutter/material.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  test('save, restore and erase only the VE-SCOPE credentials', () async {
    const storage = FlutterSecureStorage();
    await storage.write(key: 'unrelated', value: 'keep');
    expect(await SavedCredentials.read(), isNull);
    await SavedCredentials.save('utilisateur', 'p:a:ss');
    final saved = await SavedCredentials.read();
    expect(saved?.username, 'utilisateur');
    expect(saved?.password, 'p:a:ss');
    await SavedCredentials.clear();
    expect(await SavedCredentials.read(), isNull);
    expect(await storage.read(key: 'unrelated'), 'keep');
  });
  testWidgets('prefill masked password without automatic login, then erase', (tester) async {
    await SavedCredentials.save('test', 'secret');
    var connected = false;
    await tester.pumpWidget(MaterialApp(home: MobileLogin(onConnected: () => connected = true)));
    await tester.pumpAndSettle();
    final fields = tester.widgetList<TextField>(find.byType(TextField)).toList();
    expect(fields[0].controller!.text, 'test');
    expect(fields[1].controller!.text, 'secret');
    expect(fields[1].obscureText, isTrue);
    expect(connected, isFalse);
    await tester.ensureVisible(find.text('Effacer les identifiants'));
    await tester.tap(find.text('Effacer les identifiants'));
    await tester.pumpAndSettle();
    expect(fields[0].controller!.text, isEmpty);
    expect(fields[1].controller!.text, isEmpty);
    expect(await SavedCredentials.read(), isNull);
  });
}
