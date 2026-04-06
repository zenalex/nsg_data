import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nsg_data/nsg_data_item.dart';
import 'package:nsg_data/riverpod/core/repository/nsg_entity_repository.dart';
import 'package:nsg_data/riverpod/core/state/nsg_edit_state.dart';

sealed class NsgEditArg {
  const NsgEditArg();
}

class NsgEditArgCreate extends NsgEditArg {
  const NsgEditArgCreate();

  @override
  bool operator ==(Object other) => other is NsgEditArgCreate;

  @override
  int get hashCode => runtimeType.hashCode;
}

class NsgEditArgExisting extends NsgEditArg {
  final String id;

  const NsgEditArgExisting(this.id);

  @override
  bool operator ==(Object other) =>
      other is NsgEditArgExisting && other.id == id;

  @override
  int get hashCode => Object.hash(runtimeType, id);
}

abstract class NsgEditNotifier<T extends NsgDataItem>
    extends AutoDisposeFamilyNotifier<NsgEditState<T>, NsgEditArg> {
  ProviderListenable<NsgEntityRepository<T>> get repositoryProvider;

  NsgEntityRepository<T> get repository => ref.read(repositoryProvider);

  @override
  NsgEditState<T> build(NsgEditArg arg) {
    Future.microtask(() async {
      if (arg is NsgEditArgCreate) {
        await create();
      } else if (arg is NsgEditArgExisting) {
        await loadById(arg.id);
      }
    });
    return NsgEditState<T>(isLoading: true);
  }

  Future<void> create() async {
    state = state.copyWith(
      isLoading: true,
      validationErrors: const {},
      error: null,
      stackTrace: null,
    );
    try {
      final draft = await repository.createDraft();
      state = state.copyWith(
        original: null,
        draft: draft,
        isLoading: false,
        isSaving: false,
        validationErrors: const {},
        error: null,
        stackTrace: null,
      );
    } catch (error, stackTrace) {
      state = state.copyWith(
        isLoading: false,
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> loadById(String id) async {
    state = state.copyWith(
      isLoading: true,
      validationErrors: const {},
      error: null,
      stackTrace: null,
    );
    try {
      final item = await repository.fetchItem(id);
      seedFromItem(item);
      state = state.copyWith(isLoading: false, error: null, stackTrace: null);
    } catch (error, stackTrace) {
      state = state.copyWith(
        isLoading: false,
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  void seedFromItem(T item) {
    state = state
        .withOriginalAndDraft(original: item, draft: item)
        .copyWith(
          isSaving: false,
          isLoading: false,
          validationErrors: const {},
          error: null,
          stackTrace: null,
        );
  }

  void setDraft(T draft) {
    state = state.withDraft(draft);
  }

  void updateDraft(T Function(T currentDraft) update) {
    final currentDraft = state.draft;
    if (currentDraft == null) return;
    state = state.withDraft(update(currentDraft), trusted: true);
  }

  Map<String, String> validate() {
    final draft = state.draft;
    if (draft == null) {
      return const {'_state': 'Draft is not initialized.'};
    }

    final result = draft.validateFieldValues();
    final validationErrors = Map<String, String>.from(result.fieldsWithError);
    if (result.errorMessage.isNotEmpty) {
      validationErrors['_form'] = result.errorMessage;
    }
    return validationErrors;
  }

  Future<T?> save() async {
    final draft = state.draft;
    if (draft == null) {
      state = state.copyWith(
        error: StateError('Draft is not initialized.'),
        stackTrace: null,
      );
      return null;
    }

    final validationErrors = validate();
    if (validationErrors.isNotEmpty) {
      state = state.copyWith(
        validationErrors: validationErrors,
        error: null,
        stackTrace: null,
      );
      return null;
    }

    state = state.copyWith(
      isSaving: true,
      validationErrors: const {},
      error: null,
      stackTrace: null,
    );

    try {
      final saved = await repository.save(draft);
      state = state
          .withOriginalAndDraft(original: saved, draft: saved)
          .copyWith(
            isSaving: false,
            isLoading: false,
            validationErrors: const {},
            error: null,
            stackTrace: null,
          );
      return saved;
    } catch (error, stackTrace) {
      state = state.copyWith(
        isSaving: false,
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  void reset() {
    state = state
        .withDraft(state.original)
        .copyWith(
          validationErrors: const {},
          error: null,
          stackTrace: null,
          isSaving: false,
          isLoading: false,
        );
  }

  void clearError() {
    state = state.copyWith(error: null, stackTrace: null);
  }
}
