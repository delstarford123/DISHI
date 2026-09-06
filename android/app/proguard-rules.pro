# Rules for ML Kit Text Recognition to prevent R8 from stripping optional dependencies
-keep class com.google.mlkit.vision.text.** { *; }
-dontwarn com.google.mlkit.vision.text.**
