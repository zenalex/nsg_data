sealed class Result<V, E extends Exception> {
  factory Result.ok(V value) => Ok(value);
  factory Result.error(E error) => Error(error);
}

final class Ok<V, E extends Exception> implements Result<V, E> {
  final V value;
  const Ok(this.value);
}

final class Error<V, E extends Exception> implements Result<V, E> {
  final E error;
  const Error(this.error);
}
