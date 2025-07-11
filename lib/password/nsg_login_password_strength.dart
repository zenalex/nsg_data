import 'package:flutter/material.dart';

enum PasswordStrength {
  veryWeak, weak, medium, strong, veryStrong
}

Color passwordStrengthColor(PasswordStrength value) {
  switch (value) {
    case PasswordStrength.veryWeak:
      return Colors.red;
    case PasswordStrength.weak:
      return Colors.orange;
    case PasswordStrength.medium:
      return Colors.yellow;
    case PasswordStrength.strong:
      return Colors.green;
    case PasswordStrength.veryStrong:
      return Colors.greenAccent;
  }
}

String passwordStrengthMessage(PasswordStrength value) {
  switch (value) {
    case PasswordStrength.veryWeak:
      return 'Very weak';
    case PasswordStrength.weak:
      return 'Weak';
    case PasswordStrength.medium:
      return 'Medium';
    case PasswordStrength.strong:
      return 'Strong';
    case PasswordStrength.veryStrong:
      return 'Very strong';
  }
}

Iterable<Color> passwordStrengthColors = PasswordStrength.values.map((value) => passwordStrengthColor(value));
Iterable<String> passwordStrengthMessages = PasswordStrength.values.map((value) => passwordStrengthMessage(value));

// PasswordStrength checkPasswordStrength(String password) {
//   var pwdValid = PasswordValidator(password);
//   if (pwdValid.isLength(max: 7).valid) return PasswordStrength.veryWeak;
//   if (pwdValid.isLength(min: 12).valid && pwdValid.countCategories == 4) return PasswordStrength.veryStrong;
//   if (pwdValid.isLength(min: 10).valid && pwdValid.countCategories == 4) return PasswordStrength.strong;
//   if (pwdValid.isLength(min: 8).valid && pwdValid.countCategories == 3) return PasswordStrength.medium;
//   if (pwdValid.isLength(min: 8).valid && pwdValid.countCategories < 3) return PasswordStrength.weak;
//   return PasswordStrength.weak;
// } 