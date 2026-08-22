///Оценка стойкости пароля.
///
///Здесь намеренно только сам перечислимый тип — без цветов и подписей: слой
///данных не должен знать о представлении. Цвета и тексты для индикатора живут
///в пакете `nsg_login` (`password_strength_ui.dart`).
enum PasswordStrength { veryWeak, weak, medium, strong, veryStrong }
