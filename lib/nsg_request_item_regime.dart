///Режимы загрузки данных с сервера
enum NsgRequestItemRegime {
  ///Загрузка списка данных (например, для отображения в форме списка)
  loadList,

  ///Обновление одного или нескольки элементов (например, для загрузки таб. частей для отображения на форме элемента)
  updateItem
}
