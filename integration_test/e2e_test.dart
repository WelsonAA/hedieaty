import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hedieaty/main.dart';
import 'package:integration_test/integration_test.dart';
import 'package:hedieaty/main.dart' as app;
import 'package:flutter/widgets.dart'; // Add this import for Key


void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Verify MaterialApp and route keys', (WidgetTester tester) async {
    // Launch the app
    app.main();
    await tester.pumpAndSettle(Duration(seconds: 3));
    await tester.tap(find.byKey(Key('LoginButton')));
    await tester.pumpAndSettle(Duration(seconds: 3));
    await tester.enterText(find.byKey(Key('LoginPage_EmailField')), 'george@gmail.com');
    await tester.pumpAndSettle(Duration(seconds:3));
    await tester.enterText(find.byKey(Key('LoginPage_PasswordField')), 'George@123');
    await tester.pumpAndSettle(Duration(seconds: 3));
    await tester.tap(find.byKey(Key('LoginPage_LoginButton')));
    await tester.pumpAndSettle(Duration(seconds: 3));
    print("Login Successful");
    await tester.pumpAndSettle(Duration(seconds: 3));
    await tester.tap(find.byKey(Key('HomePage_CreateEventButton')));
    await tester.pumpAndSettle(Duration(seconds: 3));
    await tester.enterText(find.byKey(Key('CreateEventPage_EventNameField')), 'Party');

    await tester.pumpAndSettle(Duration(seconds: 3));
    await tester.tap(find.byKey(Key('CreateEventPage_EventDateField')));
    await tester.pumpAndSettle(Duration(seconds: 3));

    // Select a date in the DatePicker
    await tester.tap(find.text('30')); // Simulate selecting the 15th day of the month
    await tester.pumpAndSettle(Duration(seconds: 3));

    // Confirm the selection in the DatePicker
    await tester.tap(find.text('OK')); // Adjust based on your DatePicker's confirm button
    await tester.pumpAndSettle(Duration(seconds: 3));

    await tester.pumpAndSettle(Duration(seconds: 3));
    await tester.enterText(find.byKey(Key('CreateEventPage_EventLocationField')), 'New Cairo');
    await tester.pumpAndSettle(Duration(seconds: 3));
    await tester.enterText(find.byKey(Key('CreateEventPage_EventDescriptionField')), 'Null');
    await tester.pumpAndSettle(Duration(seconds: 3));
    await tester.tap(find.byKey(Key('CreateEventPage_SaveEventButton')));
    await tester.pumpAndSettle(Duration(seconds: 3));
    print("Event Created Successful");
  });
}