class Validators {
  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Enter a valid email address';
    }
    return null;
  }

  static String? validatePin(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'PIN is required';
    }
    if (value.length != 4) {
      return 'PIN must be exactly 4 digits';
    }
    if (int.tryParse(value) == null) {
      return 'PIN must contain only numbers';
    }
    return null;
  }
  
  static String? validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '\$fieldName is required';
    }
    return null;
  }
}
