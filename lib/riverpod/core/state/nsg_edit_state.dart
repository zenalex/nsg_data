import 'package:flutter/foundation.dart';
import 'package:nsg_data/nsg_data_item.dart';

const Object _sentinel = Object();

class NsgEditState<T extends NsgDataItem> {
  final T? original;
  final T? draft;
  final bool isSaving;
  final bool isLoading;
  final Map<String, String> validationErrors;
  final Object? error;
  final StackTrace? stackTrace;

  NsgEditState({
    T? original,
    T? draft,
    this.isSaving = false,
    this.isLoading = false,
    Map<String, String> validationErrors = const {},
    this.error,
    this.stackTrace,
  }) : original = original?.clone() as T?,
       draft = draft?.clone() as T?,
       validationErrors = Map.unmodifiable(validationErrors);

  NsgEditState._trusted({
    required this.original,
    required this.draft,
    required this.isSaving,
    required this.isLoading,
    required this.validationErrors,
    required this.error,
    required this.stackTrace,
  });

  bool get hasDraft => draft != null;
  bool get hasError => error != null;
  bool get isDirty {
    if (original == null && draft == null) return false;
    if (original == null || draft == null) return true;
    return !draft!.isEqual(original!);
  }

  NsgEditState<T> copyWith({
    Object? original = _sentinel,
    Object? draft = _sentinel,
    bool? isSaving,
    bool? isLoading,
    Map<String, String>? validationErrors,
    Object? error = _sentinel,
    Object? stackTrace = _sentinel,
  }) {
    return NsgEditState<T>._trusted(
      original: identical(original, _sentinel)
          ? this.original
          : (original as T?)?.clone() as T?,
      draft: identical(draft, _sentinel)
          ? this.draft
          : (draft as T?)?.clone() as T?,
      isSaving: isSaving ?? this.isSaving,
      isLoading: isLoading ?? this.isLoading,
      validationErrors: Map.unmodifiable(
        validationErrors ?? this.validationErrors,
      ),
      error: identical(error, _sentinel) ? this.error : error,
      stackTrace: identical(stackTrace, _sentinel)
          ? this.stackTrace
          : stackTrace as StackTrace?,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NsgEditState<T> &&
        other.original == original &&
        other.draft == draft &&
        other.isSaving == isSaving &&
        other.isLoading == isLoading &&
        mapEquals(other.validationErrors, validationErrors) &&
        other.error == error &&
        other.stackTrace == stackTrace;
  }

  @override
  int get hashCode => Object.hash(
    original,
    draft,
    isSaving,
    isLoading,
    Object.hashAll(validationErrors.entries),
    error,
    stackTrace,
  );
}
