///Состояния редактирования объекта
///create - создан на клиенте, на сервере не сохранен
///fill - существует (загружен или сохранен после создания) на сервере
enum NsgDataItemState { unknown, create, edit, fill }

///Состояния жизненного цикла объекта
///create - создан на клиенте, на сервере не сохранен
///fill - существует (загружен или сохранен после создания) на сервере
enum NsgDataItemDocState {
  created,
  saved,
  marked,
  unknown3,
  template,
  unknown5,
  unknown6,
  unknown7,
  handled,
  unknown9,
  unknown10,
  unknown11,
  unknown12,
  unknown13,
  unknown14,
  unknown15,
  predefined
}
