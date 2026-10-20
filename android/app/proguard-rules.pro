# shared_preferences_android uses generated JNI suspend bindings. JNI 1.1.0's
# kotlin.dart also resolves these exact coroutine bridge names at runtime;
# its consumer rules only keep com.github.dart_lang.jni classes.
-keep interface kotlin.coroutines.Continuation {
    void resumeWith(java.lang.Object);
}
-keep enum kotlin.coroutines.intrinsics.CoroutineSingletons
-keep class kotlin.coroutines.intrinsics.IntrinsicsKt
-keep class kotlin.coroutines.intrinsics.IntrinsicsKt__IntrinsicsKt {
    public static java.lang.Object getCOROUTINE_SUSPENDED();
}
-keep class kotlin.Result {
    java.lang.Object value;
}
-keep class kotlin.Result$Failure {
    <init>(java.lang.Throwable);
    java.lang.Throwable exception;
}
-keep class kotlin.Unit {
    public static kotlin.Unit INSTANCE;
}
