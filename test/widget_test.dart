import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:z_chat/widgets/avatar_widget.dart';

import 'package:provider/provider.dart';
import 'package:z_chat/theme/theme_provider.dart';

void main() {
  testWidgets('AvatarWidget smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<ThemeProvider>(
        create: (_) => ThemeProvider(),
        child: const MaterialApp(
          home: Scaffold(
            body: Center(
              child: AvatarWidget(
                displayName: 'Zack Walker',
                size: 50,
                isOnline: true,
              ),
            ),
          ),
        ),
      ),
    );

    // Initials should be rendered ('ZW' for Zack Walker)
    expect(find.text('ZW'), findsOneWidget);
  });
}
