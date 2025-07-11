class PasswordValidator {
  const PasswordValidator(this.password, {this.valid = true, feedback})
    : feedback = !valid ? feedback : null; // Если пароль инвалиден, то присваиваем вернём feedback
  final String password;
  final bool valid;
  final String? feedback;

  PasswordValidator isLength({int? length, int? min, int? max}) {
    return PasswordValidator(password,
      valid: valid && (() {
        if (length != null && (password.length == length)) return true;
        if (min != null && !(password.length >= min)) return false;
        if (max != null && !(password.length <= max)) return false;
        return true;
      })(), // Валидатор инвалиден по условию или изначально (по предыдущим валидациям)
      feedback: feedback ?? 'The password length does not meet the requirements' // Используем самый первый feedback из цепочки валидаторов или возвращаем новое
    );
  }

  PasswordValidator hasCapitalLetters() {
    return PasswordValidator(password,
      valid: valid && RegExp(r'[A-Z]').hasMatch(password),
      feedback: feedback ?? 'The password does not contain capital letters'
    );
  }

  PasswordValidator hasLowerCaseLetters() {
    return PasswordValidator(password,
      valid: valid && RegExp(r'[a-z]').hasMatch(password),
      feedback: feedback ?? 'The password does not contain lowercase letters'
    );
  }
  
  PasswordValidator hasNumbers() {
    return PasswordValidator(password,
      valid: valid && RegExp(r'[0-9]').hasMatch(password),
      feedback: feedback ?? 'The password does not contain numbers'
    );
  }

  PasswordValidator hasSpecialCharacters() {
    return PasswordValidator(password,
      valid: valid && RegExp(r'[\!\@\#\$\%\^\&\*\(\)\_\+\-\=\[\]\{\}\;\:\"\,\.\<\>\/\?]').hasMatch(password),
      feedback: feedback ?? 'The password does not contain special characters'
    );
  }

  int get countCategories => (() {
    var count = 0;
    if (hasCapitalLetters().valid) count += 1;
    if (hasLowerCaseLetters().valid) count += 1;
    if (hasNumbers().valid) count += 1;
    if (hasSpecialCharacters().valid) count += 1;
    return count;
  })();
}

// String? checkPassword(String? value) {
//   if (value == null) return null;
//   return PasswordValidator(value)
//     .isLength(min: 8)
//     .hasCapitalLetters()
//     .hasLowerCaseLetters()
//     .hasNumbers()
//     .hasSpecialCharacters()
//     .feedback;
// }