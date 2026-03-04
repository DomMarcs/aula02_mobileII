import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:todo_refatoracao_baguncado/features/todos/presentation/widgets/add_todo_dialog.dart';

void main() {
  testWidgets('AddTodoDialog returns typed text when confirming', (tester) async {
    String? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    result = await showDialog<String>(
                      context: context,
                      builder: (_) => const AddTodoDialog(),
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            );
          },
        ),
      ),
    );

    // Abre o diálogo
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    // Digita um título e confirma
    const title = 'Estudar Flutter';
    await tester.enterText(find.byType(TextField), title);
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    // O valor retornado pelo diálogo deve ser o texto digitado
    expect(result, equals(title));
  });
}
