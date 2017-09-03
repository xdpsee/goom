#include "net_zhuoweizhang_goom_Goom.h"
#include "goom.h"

JNIEXPORT jlong JNICALL Java_net_zhuoweizhang_goom_Goom_nativeGoomInit
  (JNIEnv *env, jclass cls, jint resx, jint resy) {
	return (jlong) goom_init ((guint32) resx, (guint32) resy);
}

JNIEXPORT void JNICALL Java_net_zhuoweizhang_goom_Goom_nativeSetResolution
  (JNIEnv *env, jclass cls, jlong plugin_info, jint resx, jint resy) {
	goom_set_resolution((PluginInfo *) plugin_info, resx, resy);
}

JNIEXPORT jint JNICALL Java_net_zhuoweizhang_goom_Goom_nativeGoomUpdate
  (JNIEnv *env, jclass cls, jlong plugin_info, jshortArray data, jint forceMode, jfloat fps, jstring songTitle, jstring message) {

	jshort *elems = (*env)->GetShortArrayElements(env, data, 0);
	const char * songTitle_native = NULL;
	if (songTitle) (*env)->GetStringUTFChars(env, songTitle, 0);
	const char * message_native = (*env)->GetStringUTFChars(env, message, 0);
	int retval = goom_update((PluginInfo *) plugin_info, elems, forceMode, fps, songTitle_native, message_native);
	(*env)->ReleaseShortArrayElements(env, data, elems, 0);
	if (songTitle) (*env)->ReleaseStringUTFChars(env, songTitle, songTitle_native);
	(*env)->ReleaseStringUTFChars(env, message, message_native);
	return retval;
}

JNIEXPORT jint JNICALL Java_net_zhuoweizhang_goom_Goom_nativeGoomSetScreenbuffer
  (JNIEnv *env, jclass cls, jlong plugin_info, jobject buffer) {
	void* bufferPointer = (*env)->GetDirectBufferAddress(env, buffer);
	return goom_set_screenbuffer((PluginInfo *) plugin_info, bufferPointer);
}

JNIEXPORT void JNICALL Java_net_zhuoweizhang_goom_Goom_nativeGoomClose
  (JNIEnv *env, jclass cls, jlong plugin_info) {
	goom_close((PluginInfo *) plugin_info);
}

