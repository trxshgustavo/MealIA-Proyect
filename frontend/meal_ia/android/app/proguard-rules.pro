# Flutter/Firebase specific rules
-keep class io.flutter.** { *; }
-keep class com.google.firebase.** { *; }

# Keep Stripe SDK
-keep class com.stripe.android.** { *; }

# Keep Google Sign-In
-keep class com.google.android.gms.** { *; }

# Prevent removal of annotations
-keepattributes *Annotation*

# Keep Parcelable implementations
-keep class * implements android.os.Parcelable {
  public static final android.os.Parcelable$Creator *;
}
