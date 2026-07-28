# Flutter engine entry points reached reflectively.
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep line numbers so a production stack trace stays readable, and hide the
# original source file name. Without SourceFile,LineNumberTable a crash report
# loses the one thing that makes it actionable.
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile
