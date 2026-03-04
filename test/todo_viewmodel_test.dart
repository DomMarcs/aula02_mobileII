import 'package:flutter_test/flutter_test.dart';

import 'package:todo_refatoracao_baguncado/features/todos/domain/entities/todo.dart';
import 'package:todo_refatoracao_baguncado/features/todos/domain/repositories/todo_repository.dart';
import 'package:todo_refatoracao_baguncado/features/todos/presentation/viewmodels/todo_viewmodel.dart';

class _FakeTodoRepository implements TodoRepository {
  List<Todo> todosToReturn;
  String? lastSyncLabelToReturn;
  bool shouldThrowOnFetch;
  bool shouldThrowOnUpdate;

  int addCalls = 0;
  int updateCalls = 0;

  _FakeTodoRepository({
    List<Todo>? todos,
    this.lastSyncLabelToReturn,
    this.shouldThrowOnFetch = false,
    this.shouldThrowOnUpdate = false,
  }) : todosToReturn = todos ?? [];

  @override
  Future<TodoFetchResult> fetchTodos({bool forceRefresh = false}) async {
    if (shouldThrowOnFetch) {
      throw Exception('erro fetch');
    }
    return TodoFetchResult(todos: todosToReturn, lastSyncLabel: lastSyncLabelToReturn);
  }

  @override
  Future<Todo> addTodo(String title) async {
    final todo = Todo(id: todosToReturn.length + 1, title: title, completed: false);
    todosToReturn = [todo, ...todosToReturn];
    addCalls++;
    return todo;
  }

  @override
  Future<void> updateCompleted({required int id, required bool completed}) async {
    updateCalls++;
    if (shouldThrowOnUpdate) {
      throw Exception('erro update');
    }
  }
}

void main() {
  group('TodoViewModel', () {
    test('loadTodos preenche itens e lastSyncLabel em caso de sucesso', () async {
      final repo = _FakeTodoRepository(
        todos: [
          const Todo(id: 1, title: 'Teste', completed: false),
        ],
        lastSyncLabelToReturn: '2024-01-01',
      );
      final vm = TodoViewModel(repository: repo);

      expect(vm.items, isEmpty);
      expect(vm.lastSyncLabel, isNull);

      await vm.loadTodos();

      expect(vm.items.length, 1);
      expect(vm.items.first.title, 'Teste');
      expect(vm.lastSyncLabel, '2024-01-01');
      expect(vm.errorMessage, isNull);
    });

    test('addTodo com título vazio seta mensagem de erro e não chama repositório', () async {
      final repo = _FakeTodoRepository();
      final vm = TodoViewModel(repository: repo);

      await vm.addTodo('   ');

      expect(vm.errorMessage, isNotNull);
      expect(repo.addCalls, 0);
    });

    test('toggleCompleted faz rollback em caso de erro no repositório', () async {
      final initialTodo = const Todo(id: 1, title: 'Teste', completed: false);
      final repo = _FakeTodoRepository(
        todos: [initialTodo],
        shouldThrowOnUpdate: true,
      );
      final vm = TodoViewModel(repository: repo);
      vm.items.add(initialTodo);

      await vm.toggleCompleted(1, true);

      // Deve ter voltado para o valor original (false)
      expect(vm.items.first.completed, false);
      expect(vm.errorMessage, isNotNull);
      expect(repo.updateCalls, 1);
    });
  });
}

