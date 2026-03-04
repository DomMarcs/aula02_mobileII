# Documentação Arquitetural Pós-Refatoração

## Nova Estrutura de Diretórios (Feature-First)

    lib/
      main.dart

      core/
        errors/
          app_error.dart

      features/
        todos/
          domain/
            entities/
              todo.dart
            repositories/
              todo_repository.dart

          data/
            models/
              todo_model.dart
            datasources/
              todo_remote_datasource.dart
              todo_local_datasource.dart
            repositories/
              todo_repository_impl.dart

          presentation/
            app_root.dart
            pages/
              todos_page.dart
            viewmodels/
              todo_viewmodel.dart
            widgets/
              add_todo_dialog.dart

Os diretórios legados (`models/`, `services/`, `repositories/`, `screens/`, `ui/`, `utils/`, `viewmodels/`, `widgets/`) foram preservados exclusivamente como arquivos de exportação (fachadas). O objetivo dessa decisão é garantir a retrocompatibilidade dos imports existentes enquanto a base de código consolida a migração para a abordagem feature-first.

## Fluxo de Execução e Dependências

Cadeia de execução principal da feature `todos`:

1. **Camada de Apresentação (UI)**
   - `main.dart`: Inicializa o `MultiProvider` e injeta a dependência do `TodoViewModel`.
   - `AppRoot` (`features/todos/presentation/app_root.dart`): Configura o `MaterialApp` e estabelece `TodosPage` como a rota raiz.
   - `TodosPage` (`presentation/pages/todos_page.dart`): Renderiza a interface da lista de tarefas. Atua de forma passiva, delegando as ações (`loadTodos`, `addTodo`, `toggleCompleted`) inteiramente ao ViewModel.
   - `AddTodoDialog` (`presentation/widgets/add_todo_dialog.dart`): Opera como um componente visual simples (dumb widget), responsável apenas por capturar o input de texto e devolvê-lo à página chamadora.

2. **ViewModel**
   - `TodoViewModel` (`presentation/viewmodels/todo_viewmodel.dart`): Gerencia o estado reativo da tela (`items`, `isLoading`, `errorMessage`, `lastSyncLabel`) e orquestra as regras de interação, comunicando-se com a camada de dados através da abstração `TodoRepository`.
   - É estritamente agnóstico ao Flutter: não possui conhecimento sobre `BuildContext` ou `Widgets`. A atualização da interface ocorre exclusivamente via mutação de estado e chamadas ao `notifyListeners()`.

3. **Camada de Repositório**
   - `TodoRepository` (`domain/repositories/todo_repository.dart`): Define o contrato de operações (`fetchTodos`, `addTodo`, `updateCompleted`) e estabelece o DTO de resposta `TodoFetchResult`.
   - `TodoRepositoryImpl` (`data/repositories/todo_repository_impl.dart`): Atua como orquestrador das fontes de dados (remota e local):
     - Consome a lista de tarefas via `TodoRemoteDataSource`.
     - Registra o timestamp do último sincronismo via `TodoLocalDataSource`.
     - Mapeia os objetos de transferência (`TodoModel`) para entidades de domínio (`Todo`) antes de propagá-los para o ViewModel.

4. **Fontes de Dados (DataSources)**
   - `TodoRemoteDataSource` (`data/datasources/todo_remote_datasource.dart`): Centraliza as requisições HTTP (`package:http`), configuração de endpoints e desserialização de JSON.
   - `TodoLocalDataSource` (`data/datasources/todo_local_datasource.dart`): Encapsula a lógica de persistência local utilizando `SharedPreferences` para gerenciar os metadados de sincronização.

**Direção das Dependências:**
`Apresentação (UI)` → `ViewModel` → `Interface do Repositório` → `Implementação do Repositório` → (`DataSources Remoto e Local`)

## Matriz de Responsabilidades

- **Validação de Entrada**
  - As regras de negócio para inputs do usuário (como bloquear a criação de tarefas sem título) são de responsabilidade do `TodoViewModel`.
  - A UI atua apenas como canal de transmissão de dados e exibe o estado de erro refletido pelo ViewModel.

- **Comunicação de Rede e Parsing**
  - A conversão de respostas HTTP e o parsing de JSON são atribuições exclusivas do `TodoRemoteDataSource` e do `TodoModel` (`fromJson`/`toJson`).
  - O repositório garante que a camada de domínio (e superiores) receba apenas entidades `Todo` puras, realizando a conversão do modelo de dados.

- **Persistência Local**
  - Qualquer interação com o armazenamento local (`SharedPreferences`) está isolada no `TodoLocalDataSource`.
  - O repositório atua apenas como cliente dessa classe, acionando `saveLastSync` e `getLastSync` conforme necessário.

- **Gerenciamento de Erros**
  - O `TodoRemoteDataSource` inspeciona os status codes HTTP e lança exceções específicas em caso de falhas.
  - O `TodoLocalDataSource` trata internamente falhas de leitura ou dados ausentes, retornando `null`.
  - O `TodoViewModel` intercepta as exceções propagadas pelo repositório para:
    - Atualizar a propriedade `errorMessage` com feedbacks legíveis para o usuário.
    - Executar o rollback do estado na interface (reversão otimista) caso uma operação como alternar o status da tarefa falhe no servidor.

- **Isolamento e Desacoplamento**
  - A **UI** ignora detalhes de infraestrutura. Não há acesso direto a clientes HTTP ou banco de dados; o fluxo é estritamente encaminhado ao ViewModel.
  - O **ViewModel** opera livre de dependências visuais, manipulando apenas regras de interação, a entidade `Todo` e chamadas ao repositório.
  - O **Repositório** é o único componente ciente da coexistência das fontes de dados remota e local. Essa segregação garante que a substituição de qualquer tecnologia (ex: trocar `SharedPreferences` por `Hive` ou `http` por `Dio`) não exija alterações na UI ou no ViewModel.