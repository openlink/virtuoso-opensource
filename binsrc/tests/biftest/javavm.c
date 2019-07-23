/*
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2019 OpenLink Software
 *
 *  This project is free software; you can redistribute it and/or modify it
 *  under the terms of the GNU General Public License as published by the
 *  Free Software Foundation; only version 2 of the License, dated June 1991.
 *
 *  This program is distributed in the hope that it will be useful, but
 *  WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
 *  General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License along
 *  with this program; if not, write to the Free Software Foundation, Inc.,
 *  51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA
 *
 */

#include <stdio.h>
#include <string.h>
#include <ctype.h>
#include <stdlib.h>
#include <string.h>
#ifndef WIN32
#include <locale.h>
#endif

#include <Dk.h>
#include "libutil.h"
#include "sqlnode.h"
#include "sqlfn.h"
#include "sqlpar.h"
#include "security.h"
#include <util/fnmatch.h>
#include "statuslog.h"
#include "sqlcmps.h"
#include "sqlintrp.h"
#include "sqltype.h"
#include "sqltype_c.h"
#include "sqlbif.h"
#include "sqlo.h"
#include "sqlpfn.h"
#include "sql3.h"
#include "arith.h"
#include "srvmultibyte.h"

#undef isp_schema
#define isp_schema(x) isp_schema_1(x)
#include <jni.h>

#if defined (JNI_VERSION_1_6)
#define V_JNI_VERSION JNI_VERSION_1_6
#else
#define V_JNI_VERSION JNI_VERSION_1_2
#endif
/* #define DEBUG */

void VirtuosoServerSetInitHook (void (*hook) (void));
int VirtuosoServerMain (int argc, char **argv);
void dt_to_parts (char *dt, int *year, int *month, int *day, int *hour,
    int *minute, int *second, int *fraction);
void dt_from_parts (char *dt, int year, int month, int day, int hour,
    int minute, int second, int fraction, int tz);
typedef void (*ddl_init_hook_t) (client_connection_t *cli);
extern ddl_init_hook_t
set_ddl_init_hook (ddl_init_hook_t new_ddl_init_hook);
int virtuoso_cfg_getstring (char *section, char * key, char **pret);
char * get_java_classpath (void);
void build_set_special_server_model (const char *new_model);
static caddr_t udt_jvm_instance_allocate (JNIEnv *env, jobject new_obj, sql_class_t *udt);

#ifdef WIN32
#define vsnprintf _vsnprintf
#endif
/* #define AUTO_DETACH */

static sql_class_t *java_unk_object = NULL;
static JavaVM *java_vm = NULL;
static dk_mutex_t *java_vm_mutex = NULL;
int new_thr = 0;

extern char *virt_class_loader_ur;
extern char *virt_class_loader_r;
extern char *virt_access_granter;
extern char *virt_helper;
int uudecode_base64(char * src, char * end);
extern char *bpel_adaptor;
extern int uudecode_base64(char * src, char * end);
extern caddr_t bpel_get_var_by_dump (const char * my_name, const char * my_part,
				const char * my_query, const char * my_vars,
				const char* xmlnss);
extern caddr_t bpel_set_var_by_dump (const char * my_name, const char * my_part,
				const char * my_query, const char * my_val,
				const char * my_vars, const char* my_xmlnss);



jclass class_loader_ur = NULL;
jclass class_loader_r = NULL;
jclass access_granter = NULL;
jclass virt_helper_class = NULL;

jclass Class_class = 0;
jclass Object_class = 0;
jclass Throwable_class = 0;
jclass GregorianCal_class = 0;
jclass Date_class = 0;
jmethodID virt_helper_init = 0;
jmethodID virt_helper_set_unresticted_perms = 0;
jmethodID virt_helper_set_resticted_perms = 0;
jmethodID virt_helper_set_access_granter = 0;
jmethodID virt_helper_serialize = 0;
jmethodID Object_toString_id = 0;
jmethodID Throwable_getMessage_id = 0;
jmethodID Throwable_printStackTrace_id = 0;
jmethodID virt_helper_deserialize = 0;
jmethodID Class_getName_id = 0;
jmethodID GregorianCal_init_id = 0;
jmethodID GregorianCal_getTime_id = 0;
jmethodID getYear_id = 0;
jmethodID getMonth_id = 0;
jmethodID getDate_id = 0;
jmethodID getHours_id = 0;
jmethodID getMinutes_id = 0;
jmethodID getSeconds_id = 0;
jmethodID getTimezoneOffset_id = 0;

int sand_box = 1;

static caddr_t java_exception_text (JNIEnv * env);
#define IF_JAVA_ERR_GO(env,label,err) \
	if ((*env)->ExceptionCheck (env)) \
	  { \
	    caddr_t java_text = java_exception_text (env); \
            if (java_text) \
              { \
		err = srv_make_new_error ("42000", "JV001", "Java exception occurred : %.500s", java_text); \
		dk_free_box (java_text); \
		goto label; \
	      } \
	  }

#define GET_METHOD_ID(env, cls_id, mtd_id, name, sig, finish, err) \
  mtd_id = (*env)->GetMethodID (env, cls_id, name, sig); \
  IF_JAVA_ERR_GO (env, finish, err); \
  if (!mtd_id) \
    { \
      err = (caddr_t) srv_make_new_error ("42000", "SRXXX", "No java method %.200s %200s", name, sig); \
      goto finish; \
    }

#define GET_STATIC_METHOD_ID(env, cls_id, mtd_id, name, sig, finish, err) \
  mtd_id = (*env)->GetStaticMethodID (env, cls_id, name, \
      sig); \
  IF_JAVA_ERR_GO (env, finish, err); \
  if (!mtd_id) \
    { \
      err = (caddr_t) srv_make_new_error ("42000", "SRXXX", "No static java method %.200s %200s", name, sig); \
      goto finish; \
    }

#define GET_CLASS_ID(env, cls_id, name, finish, err) \
  cls_id = (*env)->FindClass (env, name); \
  IF_JAVA_ERR_GO (env, finish, err); \
  if (!cls_id) \
    { \
      err = (caddr_t) srv_make_new_error ("42000", "SRXXX", "No java class %.200s", name); \
      goto finish; \
    }

#if 1
#define UDT_JVM_I_OBJECT(box) ((jobject) ((caddr_t *)(box))[1])
#define UDT_JVM_I_OBJECT_SET(box,obj) ((caddr_t *)box)[1] = (caddr_t) (*env)->NewGlobalRef (env, (obj))
#else
static jobject
UDT_JVM_I_OBJECT (caddr_t box)
{
  jobject ret;
  ret = (jobject) ((caddr_t *)box)[1];
  return ret;
}

static void
_UDT_JVM_I_OBJECT_SET (JNIEnv *env, caddr_t box, jobject obj)
{
  jobject ret = (*env)->NewGlobalRef (env, obj);
  caddr_t ret1 = (caddr_t)ret;
  ((caddr_t *)box)[1] = ret1;
}
#define UDT_JVM_I_OBJECT_SET(box,obj) _UDT_JVM_I_OBJECT_SET(env,box,obj)
#endif

static caddr_t java_vm_attach (JNIEnv ** env, int create_if_not, caddr_t classpath, caddr_t *opts);
#ifndef AUTO_DETACH
#define java_vm_detach() NULL
static caddr_t java_vm_real_detach (void);
#else
static caddr_t java_vm_detach (void);
#endif
static caddr_t java_exception_text (JNIEnv * env);

#define DV_EXTENSION_OBJ 251
typedef struct extension_obj_s
{
  ptrlong exo_type;
  jobject exo_object;
}
extension_obj_t;

#define DVEXT_JAVA_OBJECT 1

#define IS_JAVA_OBJ(box) \
	(DV_TYPE_OF (box) == DV_EXTENSION_OBJ && \
	 ((extension_obj_t *)(box))->exo_type == DVEXT_JAVA_OBJECT)

#define MAKE_JAVA_ARRAY(Type,jvvar,value,java_name) \
        (*env)->New##Type##Array (env, BOX_ELEMENTS (value)); \
	      for (inx = 0; inx < (int) BOX_ELEMENTS (value); inx++) \
		{ \
		  err = java_dv_to_jvalue (qst, env, ((caddr_t *)value)[inx], java_name, &jelt); \
		  if (err) \
		    { \
		      (*env)->DeleteLocalRef (env, array); \
		      return err; \
		    } \
		  (*env)->Set##Type##ArrayRegion (env, array, inx, 1, &jelt.jvvar); \
		}


#define PUSH_FRAME(env,num) \
        if (env) \
 	  (*env)->PushLocalFrame (env, num)

#define POP_FRAME(env,obj) \
        if (env) \
	  { \
	    if (0 && IS_JAVA_OBJ (obj)) \
	      (*env)->PopLocalFrame (env, ((extension_obj_t *)(obj))->exo_object); \
	    else \
	      (*env)->PopLocalFrame (env, NULL); \
	  }

jint JNICALL
java_vfprintf (FILE * fo, const char *format, va_list args)
{
  char buffer[1000];
  int ret = vsnprintf (buffer, sizeof (buffer), format, args);
  log_info ("Java VM : %.1000s", buffer);
  return ret > sizeof (buffer) ? sizeof (buffer) : ret;
}

void JNICALL
java_abort (void)
{
  log_info ("java VM aborted");
  /* GPF_T; Causes infinite loop in Win32. Dies perfectly without GPF. */
}

void JNICALL
java_exit (jint status)
{
  log_info ("Java VM exited (code %d)", status);
  call_exit_outline (status);
}


static int
dv_extension_obj_serialize (void *b, dk_session_t * session)
{
  int done = 0;
  if (IS_JAVA_OBJ (b))
    {
      extension_obj_t *obj = (extension_obj_t *) b;
      JNIEnv *env;
      caddr_t err = NULL;
      if (NULL == (err = java_vm_attach (&env, 0, NULL, NULL)) && env != NULL)
	{
	  jobject str;

	  str = (*env)->CallObjectMethod (env, obj->exo_object, Object_toString_id);

	  if (str)
	    {
	      char *utf8_chars;
	      int utf8_chars_len;

	      utf8_chars_len = (*env)->GetStringUTFLength (env, str);
	      if (utf8_chars_len > 256)
		{
		  session_buffered_write_char (DV_WIDE, session);
		  session_buffered_write_char ((char) utf8_chars_len,
		      session);
		}
	      else
		{
		  session_buffered_write_char (DV_LONG_WIDE, session);
		  print_long ((long) utf8_chars_len, session);
		}
	      utf8_chars =
		  (char *) (*env)->GetStringUTFChars (env, str, NULL);
	      session_buffered_write (session, utf8_chars, utf8_chars_len);
	      (*env)->ReleaseStringUTFChars (env, str, utf8_chars);
	      done = 1;
	    }
	  dk_free_tree (err);
	  err = java_vm_detach ();

	}
      else
	dk_free_tree (err);
    }
  if (!done)
    {
      session_buffered_write_char (DV_WIDE, session);
      session_buffered_write_char ((char) 0, session);
    }
  return 0;
}


static caddr_t
java_object_dv_alloc (JNIEnv * env, jobject obj)
{
  caddr_t ret = dk_alloc_box (sizeof (extension_obj_t), DV_EXTENSION_OBJ);

  PrpcSetWriter (DV_EXTENSION_OBJ, dv_extension_obj_serialize);

  ((extension_obj_t *) ret)->exo_type = DVEXT_JAVA_OBJECT;
  ((extension_obj_t *) ret)->exo_object = (*env)->NewGlobalRef (env, obj);
  return ret;
}


static int
java_object_dv_free (caddr_t box)
{
  if (IS_JAVA_OBJ (box))
    {
      extension_obj_t *obj = (extension_obj_t *) box;
      JNIEnv *env;
      caddr_t err = NULL;
      if (NULL == (err = java_vm_attach (&env, 1, NULL, NULL)))
	{
	  (*env)->DeleteGlobalRef (env,
	      ((extension_obj_t *) obj)->exo_object);
	  err = java_vm_detach ();
	}
      else
	dk_free_tree (err);
    }
  return 0;
}


static caddr_t
dv_extension_obj_copy (caddr_t b)
{
  if (IS_JAVA_OBJ (b))
    {
      extension_obj_t *obj = (extension_obj_t *) b;
      JNIEnv *env;
      caddr_t err;
      if (NULL == (err = java_vm_attach (&env, 1, NULL, NULL)))
	{
	  caddr_t ret = java_object_dv_alloc (env, obj->exo_object);
	  err = java_vm_detach ();
	  return ret;
	}
      else
	dk_free_tree (err);
    }
  return NULL;
}


#if 1

static caddr_t *
get_virt_vm_opts ()
{
  dk_set_t opts_set = NULL;
  char *val;
  int n_opt;
  char vm_name_buf[100];
  for (n_opt = 1; ; n_opt++)
    {
      sprintf (vm_name_buf, "JavaVMOption%d", n_opt);
      if (-1 == virtuoso_cfg_getstring ("Parameters", vm_name_buf, &val))
	break;
      dk_set_push (&opts_set, box_dv_short_string (val));
      dk_set_push (&opts_set, NULL);
    }
  if (opts_set)
    return (caddr_t *) list_to_array (dk_set_nreverse (opts_set));
  else
    return NULL;
}

#ifdef WIN32
static HMODULE jvm_mod = NULL;
typedef jint (*JNI_CreateJavaVM_t) (JavaVM **pvm, void **penv, void *args);
static JNI_CreateJavaVM_t my_JNI_CreateJavaVM = NULL;
#endif

jobject virt_thr_group = NULL;


static int
jvm_activate_access_granter (int granter_mode)
{
  JNIEnv *env = NULL;
  caddr_t err = NULL;
  jobject inst = 0;

  if (!sand_box)
    return 0;

  if (new_thr)
    return 1;

/*log_info (" jvm_activate_access_granter = %i ", granter_mode); */

  if (NULL != (err = java_vm_attach (&env, 1, NULL, NULL)))
    {
      err = (caddr_t) 1;
      goto finish;
    }

  PUSH_FRAME(env, 200);
  inst = (*env)->NewObject (env, virt_helper_class, virt_helper_init);
  IF_JAVA_ERR_GO (env, finish, err);

  if (granter_mode)
    (*env)->CallVoidMethod (env, inst, virt_helper_set_unresticted_perms);
  else
    (*env)->CallVoidMethod (env, inst, virt_helper_set_resticted_perms);

  IF_JAVA_ERR_GO (env, finish, err);

finish:
  POP_FRAME (env, NULL);
  if (env)
    {
      caddr_t err1 = java_vm_detach ();
      if (!err)
	err = err1;
      else
	dk_free_tree (err1);
    }
  if (err)
    {
      if (ARRAYP (err))
	log_error ("JAVA Security error : [%s] [%s]", ERR_STATE(err), ERR_MESSAGE (err));
      else
	log_error ("JAVA Security error : unknown");
      dk_free_tree (err);
      err = NULL;
    }

  return 0;
}


static void
set_virt_access_granter_to_jvm ()
{
  JNIEnv *env = NULL;
  caddr_t err = NULL;
  long blen, len;
  caddr_t buf;

  if (NULL != (err = java_vm_attach (&env, 1, NULL, NULL)))
    exit (1);

  blen = strlen (virt_access_granter);
  buf = dk_alloc_box(blen, DV_BIN);
  memcpy (buf, virt_access_granter, blen);
  len = uudecode_base64(buf, buf + blen);

  access_granter = (*env)->DefineClass(env, "__virt_access_granter", NULL, buf, len - 1);
}


static void
set_virt_class_loader_r_to_jvm ()
{
  JNIEnv *env = NULL;
  caddr_t err = NULL;
  long blen, len;
  caddr_t buf;

  blen = strlen (virt_class_loader_r);
  buf = dk_alloc_box(blen, DV_BIN);
  memcpy (buf, virt_class_loader_r, blen);
  len = uudecode_base64(buf, buf + blen);

  if (NULL != (err = java_vm_attach (&env, 1, NULL, NULL)))
    exit (1);

  class_loader_r = (*env)->DefineClass(env, "__virt_class_loader_r", NULL, buf, len - 1);
}

/* BEGIN:
   BPEL stuff
*/

/*
 * Class:     BpelVarsAdaptor
 * Method:    set_var_data
 * Signature: (Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;Ljava/lang/Object;Ljava/lang/String;Ljava/lang/String;)Ljava/lang/String
 */
JNIEXPORT jobject JNICALL Java_BpelVarsAdaptor_set_1var_1data
  (JNIEnv * env, jobject jobj, jstring name, jstring part, jstring query, jobject val, jstring vars, jstring xmlnss)
{
  jobject jb;
  jboolean iscopy;
  const char * my_name = (*env)->GetStringUTFChars(env, name, &iscopy);
  const char * my_part = (*env)->GetStringUTFChars(env, part, &iscopy);
  const char * my_query = (*env)->GetStringUTFChars(env, query, &iscopy);
  const char * my_vars = (*env)->GetStringUTFChars(env, vars, &iscopy);
  const char * my_xmlnss = (*env)->GetStringUTFChars(env, xmlnss, &iscopy);
  const char * my_val = (*env)->GetStringUTFChars(env, val, &iscopy);


  caddr_t res = bpel_set_var_by_dump (my_name, my_part, my_query, my_val, my_vars, my_xmlnss);

  (*env)->ReleaseStringUTFChars(env, name, my_name);
  (*env)->ReleaseStringUTFChars(env, part, my_part);
  (*env)->ReleaseStringUTFChars(env, query, my_query);
  (*env)->ReleaseStringUTFChars(env, vars, my_vars);
  (*env)->ReleaseStringUTFChars(env, vars, my_xmlnss);
  (*env)->ReleaseStringUTFChars(env, val, my_val);
  jb=(*env)->NewStringUTF(env, res);
  dk_free_box (res);
  return jb;
}

/*
 * Class:     BpelVarsAdaptor
 * Method:    get_var_data
 * Signature: (Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;)Ljava/lang/Object;
 */
JNIEXPORT jobject JNICALL Java_BpelVarsAdaptor_get_1var_1data
  (JNIEnv * env, jobject jobj, jstring name, jstring part, jstring query, jstring vars, jstring xmlnss)
{
  jboolean iscopy;
  const char * my_name = (*env)->GetStringUTFChars(env, name, &iscopy);
  const char * my_part = (*env)->GetStringUTFChars(env, part, &iscopy);
  const char * my_query = (*env)->GetStringUTFChars(env, query, &iscopy);
  const char * my_vars = (*env)->GetStringUTFChars(env, vars, &iscopy);
  const char * my_xmlnss = (*env)->GetStringUTFChars(env, xmlnss, &iscopy);
  jbyteArray jb;

  caddr_t res = bpel_get_var_by_dump (my_name, my_part, my_query, my_vars, my_xmlnss);

  (*env)->ReleaseStringUTFChars(env, name, my_name);
  (*env)->ReleaseStringUTFChars(env, part, my_part);
  (*env)->ReleaseStringUTFChars(env, query, my_query);
  (*env)->ReleaseStringUTFChars(env, vars, my_vars);
  (*env)->ReleaseStringUTFChars(env, vars, my_xmlnss);
  jb=(*env)->NewStringUTF(env, res);
  dk_free_box (res);
  return jb;
}

JNINativeMethod  bpel_adaptor_methods[] = {
  { "set_var_data",
    "(Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;Ljava/lang/Object;Ljava/lang/String;Ljava/lang/String;)Ljava/lang/String;",
    Java_BpelVarsAdaptor_set_1var_1data
  },
  { "get_var_data",
    "(Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;)Ljava/lang/Object;",
    Java_BpelVarsAdaptor_get_1var_1data
  }
};

static void
set_bpel_classes_to_jvm ()
{
  JNIEnv *env = NULL;
  caddr_t err = NULL;
  jclass bpel_vars_adaptor = NULL;
  long blen, len;
  caddr_t buf;

  if (NULL != (err = java_vm_attach (&env, 1, NULL, NULL)))
    exit (1);

  blen = strlen (bpel_adaptor);
  buf = dk_alloc_box(blen, DV_BIN);
  memcpy (buf, bpel_adaptor, blen);
  len = uudecode_base64(buf, buf + blen);

  bpel_vars_adaptor = (*env)->DefineClass(env, "BpelVarsAdaptor", NULL, buf, len - 1);
  if (0 != (*env)->RegisterNatives (env,
			    bpel_vars_adaptor,
			    bpel_adaptor_methods,
			    sizeof (bpel_adaptor_methods)/sizeof (JNINativeMethod)))
    log_error ("JAVA startup error : could not register native methods");

}

/* END:
   BPEL stuff
*/

static void
set_virt_class_loader_ur_to_jvm ()
{
  JNIEnv *env = NULL;
  caddr_t err = NULL;
  long blen, len;
  caddr_t buf;

  blen = strlen (virt_class_loader_ur);
  buf = dk_alloc_box(blen, DV_BIN);
  memcpy (buf, virt_class_loader_ur, blen);
  len = uudecode_base64(buf, buf + blen);

  if (NULL != (err = java_vm_attach (&env, 1, NULL, NULL)))
    exit (1);

  class_loader_ur = (*env)->DefineClass(env, "__virt_class_loader_ur", NULL, buf, len - 1);
}

static void
set_help_class_to_jvm ()
{
  JNIEnv *env = NULL;
  caddr_t err = NULL;
  long blen, len;
  caddr_t buf;
  jclass loaderClass;
  jmethodID loaderMID;
  jobject loaderObj;

  blen = strlen (virt_helper);
  buf = dk_alloc_box(blen, DV_BIN);
  memcpy (buf, virt_helper, blen);
  len = uudecode_base64(buf, buf + blen);

  if (NULL != (err = java_vm_attach (&env, 1, NULL, NULL)))
    exit (1);

  PUSH_FRAME(env, 200);
  GET_CLASS_ID (env, loaderClass, "java/lang/ClassLoader", finish, err);
  GET_STATIC_METHOD_ID (env, loaderClass, loaderMID, "getSystemClassLoader", "()Ljava/lang/ClassLoader;", finish, err);
  loaderObj = (*env)->CallStaticObjectMethod(env, loaderClass, loaderMID);
  IF_JAVA_ERR_GO(env,finish,err);

  GET_CLASS_ID (env, Object_class, "java/lang/Object", finish, err);
  GET_CLASS_ID (env, Class_class, "java/lang/Class", finish, err);
  GET_CLASS_ID (env, Throwable_class, "java/lang/Throwable", finish, err);
  GET_CLASS_ID (env, GregorianCal_class, "java/util/GregorianCalendar", finish, err);
  GET_CLASS_ID (env, Date_class, "java/util/Date", finish, err);
  GET_METHOD_ID (env, Object_class, Object_toString_id, "toString", "()Ljava/lang/String;", finish, err);
  GET_METHOD_ID (env, Class_class, Class_getName_id, "getName", "()Ljava/lang/String;", finish, err);
  GET_METHOD_ID (env, Throwable_class, Throwable_getMessage_id, "getMessage", "()Ljava/lang/String;", finish, err);
  GET_METHOD_ID (env, Throwable_class, Throwable_printStackTrace_id, "printStackTrace", "()V", finish, err);
  GET_METHOD_ID (env, GregorianCal_class, GregorianCal_init_id, "<init>", "(IIIIII)V", finish, err);
  GET_METHOD_ID (env, GregorianCal_class, GregorianCal_getTime_id, "getTime", "()Ljava/util/Date;", finish, err);
  GET_METHOD_ID (env, Date_class, getYear_id, "getYear", "()I", finish, err);
  GET_METHOD_ID (env, Date_class, getMonth_id, "getMonth", "()I", finish, err);
  GET_METHOD_ID (env, Date_class, getDate_id, "getDate", "()I", finish, err);
  GET_METHOD_ID (env, Date_class, getHours_id, "getHours", "()I", finish, err);
  GET_METHOD_ID (env, Date_class, getMinutes_id, "getMinutes", "()I", finish, err);
  GET_METHOD_ID (env, Date_class, getSeconds_id, "getSeconds", "()I", finish, err);
  GET_METHOD_ID (env, Date_class, getTimezoneOffset_id, "getTimezoneOffset", "()I", finish, err);

  virt_helper_class = (*env)->DefineClass(env, "__virt_helper", loaderObj, buf, len - 1);
  IF_JAVA_ERR_GO(env,finish,err);

  GET_METHOD_ID (env, virt_helper_class, virt_helper_init, "<init>", "()V", finish, err);
  GET_METHOD_ID (env, virt_helper_class, virt_helper_set_unresticted_perms, "set_unresticted_perms", "()V", finish, err);
  GET_METHOD_ID (env, virt_helper_class, virt_helper_set_resticted_perms, "set_resticted_perms", "()V", finish, err);
  GET_METHOD_ID (env, virt_helper_class, virt_helper_set_access_granter, "set_access_granter", "()V", finish, err);
  GET_METHOD_ID (env, virt_helper_class, virt_helper_serialize, "serialize", "(Ljava/lang/Object;)[B", finish, err);
  GET_METHOD_ID (env, virt_helper_class, virt_helper_deserialize, "deserialize", "([B)Ljava/lang/Object;", finish, err);


finish:

  if (env)
    {
      caddr_t err1 = java_vm_detach ();
      if (!err)
	err = err1;
      else
	dk_free_tree (err1);
    }
  if (err)
    {
      if (ARRAYP (err))
	log_error ("JAVA startup error : [%s] [%s]", ERR_STATE(err), ERR_MESSAGE (err));
      else
	log_error ("JAVA startup error : unknown");
      dk_free_tree (err);
      err = NULL;
    }
}

static int
jvm_set_access_granter ()
{
  JNIEnv *env = NULL;
  caddr_t err = NULL;
  jobject inst = 0;


  if (NULL != (err = java_vm_attach (&env, 1, NULL, NULL)))
    {
      err = (caddr_t) 1;
      goto finish;
    }

  PUSH_FRAME(env, 200);
  inst = (*env)->NewObject (env, virt_helper_class, virt_helper_init);
  IF_JAVA_ERR_GO (env, finish, err);
  if (!inst)
    {
      err = (caddr_t)1;
      goto finish;
    }
  (*env)->CallVoidMethod (env, inst, virt_helper_set_access_granter);
  IF_JAVA_ERR_GO (env, finish, err);

finish:
  POP_FRAME (env, NULL);
  if (env)
    {
      caddr_t err1 = java_vm_detach ();
      if (!err)
	err = err1;
      else
	dk_free_tree (err1);
    }
  if (err)
    {
      if (ARRAYP (err))
	log_error ("JAVA Security error : [%s] [%s]", ERR_STATE(err), ERR_MESSAGE (err));
      else
	log_error ("JAVA Security error : unknown");
      dk_free_tree (err);
      err = NULL;
    }

  return 0;
}


static caddr_t
java_vm_create (JNIEnv ** java_vm_env, caddr_t classpath, caddr_t *opts)
{

  JavaVMInitArgs vm_args;
  JavaVMOption options[1000];
  jint res;
  caddr_t classpath_opt = NULL;
  int inx;

  if (!classpath)
    virtuoso_cfg_getstring ("Parameters", "JavaClasspath", &classpath);
  if (!classpath)
    {
      classpath=getenv ("CLASSPATH");
    }
  if (!classpath)
    {
      classpath= ".";
    }

  if (classpath)
    {
      classpath_opt = dk_alloc_box (strlen (classpath) + 20, DV_SHORT_STRING);
      sprintf (classpath_opt, "-Djava.class.path=%s", classpath);
    }
  options[0].optionString = "vfprintf";
  options[0].extraInfo = java_vfprintf;
  options[1].optionString = "abort";
  options[1].extraInfo = java_abort;
  options[2].optionString = "exit";
  options[2].extraInfo = java_exit;
  options[3].optionString = classpath_opt;
  vm_args.nOptions = 4;
  if (!opts)
    opts = get_virt_vm_opts ();
  if (opts)
    {
      if (DV_TYPE_OF (opts) != DV_ARRAY_OF_POINTER ||
	  BOX_ELEMENTS (opts) % 2 != 0 ||
	  BOX_ELEMENTS (opts) >= sizeof (options) / sizeof (JavaVMOption) - 4)
	return srv_make_new_error ("22023", "JVXXX", "Wrong type of VM options");

      for (inx = 0; inx < sizeof (options) / sizeof (JavaVMOption) && inx < BOX_ELEMENTS (opts); inx += 2)
	{
	  if (!DV_STRINGP (opts[inx]))
	    return srv_make_new_error ("22023", "JVXXX", "Wrong VM option name type for opt %d", inx/2 + 1);
	  if (strcmp (opts[inx], "vfprintf") &&
	      strcmp (opts[inx], "abort") &&
	      strcmp (opts[inx], "exit"))
	    {
	      options[4 + inx / 2].optionString = opts[inx];
	      options[4 + inx / 2].extraInfo = opts[inx + 1];
	      vm_args.nOptions++;
	    }
	}
    }

  vm_args.version = V_JNI_VERSION;
  vm_args.options = options;
  vm_args.ignoreUnrecognized = JNI_FALSE;

#if defined (WIN32) && defined (JAVA_DYNLOAD)
  res = 0;
  if (!jvm_mod)
    {
      jvm_mod = LoadLibrary ("jvm.dll");
      if (!jvm_mod)
	res = -1;
      else
	my_JNI_CreateJavaVM = (JNI_CreateJavaVM_t) GetProcAddress (jvm_mod, "JNI_CreateJavaVM");
    }
  if (my_JNI_CreateJavaVM)
    res = my_JNI_CreateJavaVM (&java_vm, (void **) java_vm_env, &vm_args);
  else
    res = -1;
#else
  res = JNI_CreateJavaVM (&java_vm, (void **) java_vm_env, &vm_args);
#endif
  /* log_error ("JavaVM created: %x", java_vm); */

  if (res < 0)
    return srv_make_new_error ("42000", "JV002", "Can't create the Java VM");
  else
    return NULL;
}
#else
static caddr_t
java_vm_create (JNIEnv ** java_vm_env, caddr_t classpath)
{
  JDK1_1InitArgs vm_args;
  jint res;

  vm_args.version = 0x00010001;
  JNI_GetDefaultJavaVMInitArgs(&vm_args);
  vm_args.vfprintf = java_vfprintf;
  vm_args.exit = java_exit;
  vm_args.abort = java_abort;
  if (classpath)
    vm_args.classpath = classpath;
  else
    vm_args.classpath = ".";

  res = JNI_CreateJavaVM (&java_vm, (void **) java_vm_env, &vm_args);
  if (res < 0)
    return srv_make_new_error ("42000", "JV002", "Can't create the Java VM");
  else
    return NULL;
}
#endif

int is_sec = 0;

static caddr_t
java_vm_attach (JNIEnv ** env, int create_if_not, caddr_t classpath, caddr_t *opts)
{
  caddr_t err = NULL;

  mutex_enter (java_vm_mutex);
  *env = NULL;
  if (DV_STRINGP (classpath) && java_vm)
    {
      err = srv_make_new_error ("22023", "SRXXX",
	  "Java VM allready initialized. "
	  "Classpath supplied cannot be set.");
      return err;
    }
  if (!java_vm
#ifndef AUTO_DETACH
      && create_if_not
#endif
      )
    {
      err = java_vm_create (env, classpath, opts);
      if (err)
	{
	  mutex_leave (java_vm_mutex);
	  return err;
	}
#ifdef DEBUG
      log_debug ("Java VM created and thread %p attached to it", thread_current());
#endif
    }
  else
    {
#if 1
#ifndef AUTO_DETACH
      if (JNI_OK != (*java_vm)->GetEnv (java_vm, (void **) env,
	      V_JNI_VERSION) && create_if_not)
#endif
	{
#endif
	  if (0 > (*java_vm)->AttachCurrentThread (java_vm, (void **) env, NULL))
	    {
	      err =
		  srv_make_new_error ("42000", "JV003",
		  "Can't attach to the java VM");
	      mutex_leave (java_vm_mutex);
	      return err;
	    }
#ifdef DEBUG
	  log_debug ("Thread %p attached to the Java VM", thread_current());
#endif
	}
#if 1
    }
#endif
  mutex_leave (java_vm_mutex);

  return err;
}


#ifdef AUTO_DETACH
static caddr_t
java_vm_detach (void)
#else
static caddr_t
java_vm_real_detach (void)
#endif
{
  jint rc;

  mutex_enter (java_vm_mutex);
  rc = (*java_vm)->DetachCurrentThread (java_vm);
  mutex_leave (java_vm_mutex);
  if (rc < 0)
    return srv_make_new_error ("42000", "JV004",
	"Can't dettach from the java VM");
  else
    {
#ifdef DEBUG
      log_debug ("Thread %p detached from the Java VM", thread_current());
#endif
      return NULL;
    }
}


static caddr_t
java_exception_text (JNIEnv * env)
{
  caddr_t ret = NULL;
  jthrowable exception;

  exception = (*env)->ExceptionOccurred (env);
  (*env)->ExceptionClear (env);
  if (exception != NULL)
    {
      jclass exception_class;
      jobject msg, class_name;
      const char *msg_text, *class_name_text;
      int msg_text_len, class_name_text_len = 0;
      char buffer[1510];
      caddr_t err = NULL;

#ifdef DEBUG
     (*env)->ExceptionDescribe (env);
#endif
      exception_class = (*env)->GetObjectClass (env, exception);
      if (!exception_class)
	goto unknown;

      (*env)->CallObjectMethod (env, exception, Throwable_printStackTrace_id);
      msg = (*env)->CallObjectMethod (env, exception, Throwable_getMessage_id);

      class_name = (*env)->CallObjectMethod (env, exception_class, Class_getName_id);

      if (!class_name)
	goto unknown;

      if (msg)
	{
	  msg_text_len = (*env)->GetStringUTFLength (env, msg);
	  msg_text = (*env)->GetStringUTFChars (env, msg, NULL);
	}
      class_name_text_len = (*env)->GetStringUTFLength (env, class_name);
      class_name_text = (*env)->GetStringUTFChars (env, class_name, NULL);

      buffer[0] = 0;
      if (class_name_text_len)
	strncat (buffer, class_name_text, class_name_text_len > 300 ? 300 : class_name_text_len);
      strcat (buffer, " : ");
      if (msg_text_len)
	strncat (buffer, msg_text, msg_text_len > 1200 ? 1200 : msg_text_len);
      ret = box_dv_short_string (buffer);
      if (msg)
	(*env)->ReleaseStringUTFChars (env, msg, msg_text);
      (*env)->ReleaseStringUTFChars (env, class_name, class_name_text);
      return ret;

    unknown:
      dk_free_tree (err);
      return box_dv_short_string ("<unknown java exception>");
    }
  return NULL;
}


static caddr_t
escape_class_name (caddr_t name)
{
  if (DV_STRINGP (name))
    {
      caddr_t ret = box_dv_short_string (name);
      char *dot;
      while (NULL != (dot = strchr (ret, '.')))
	{
	  *dot = '/';
	}
      return ret;
    }
  else
    return NULL;
}


static caddr_t
java_dv_to_jvalue (caddr_t * qst, JNIEnv * env, caddr_t value,
    char *java_name, jvalue * ret)
{
  caddr_t err = NULL, val;
  int java_name_len = strlen (java_name);

  if (DV_TYPE_OF (value) == DV_DB_NULL)
    {
      if (ret)
	ret->l = NULL;
    }
  else if (java_name_len == 1)
    {
      switch (toupper (java_name[0]))
	{
	case 'Z':		/* boolean */
	  if (DV_TYPE_OF (value) == DV_ARRAY_OF_POINTER &&
	    BOX_ELEMENTS (value) == 2 &&
	    DV_TYPE_OF (((caddr_t *)value)[0]) == DV_COMPOSITE &&
	    DV_TYPE_OF (((caddr_t *)value)[1]) == DV_LONG_INT) /* the SOAP boolean */
	    val = ((caddr_t *)value)[1];
	  else
	    val = box_cast_to (qst, value, DV_TYPE_OF (value), DV_SHORT_INT,
		NUMERIC_MAX_PRECISION, NUMERIC_MAX_SCALE, &err);
	  if (err)
	    return err;
	  if (ret)
	    ret->z = unbox (val) ? JNI_TRUE : JNI_FALSE;
	  dk_free_box (val);

	case 'B':		/* byte */
	  val = box_cast_to (qst, value, DV_TYPE_OF (value), DV_SHORT_INT,
	      NUMERIC_MAX_PRECISION, NUMERIC_MAX_SCALE, &err);
	  if (err)
	    return err;
	  if (ret)
	    ret->b = (jbyte) unbox (val);
	  dk_free_box (val);

	case 'C':		/* char */
	  val = box_cast_to (qst, value, DV_TYPE_OF (value), DV_SHORT_INT,
	      NUMERIC_MAX_PRECISION, NUMERIC_MAX_SCALE, &err);
	  if (err)
	    return err;
	  if (ret)
	    ret->c = (jchar) unbox (val);
	  dk_free_box (val);

	case 'S':		/* short */
	  val = box_cast_to (qst, value, DV_TYPE_OF (value), DV_SHORT_INT,
	      NUMERIC_MAX_PRECISION, NUMERIC_MAX_SCALE, &err);
	  if (err)
	    return err;
	  if (ret)
	    ret->s = (jshort) unbox (val);
	  dk_free_box (val);
	  break;

	case 'I':
	  val = box_cast_to (qst, value, DV_TYPE_OF (value), DV_LONG_INT,
	      NUMERIC_MAX_PRECISION, NUMERIC_MAX_SCALE, &err);
	  if (err)
	    return err;
	  if (ret)
	    ret->i = (jint) unbox (val);
	  dk_free_box (val);
	  break;

	case 'J':
	  val = box_cast_to (qst, value, DV_TYPE_OF (value), DV_LONG_INT,
	      NUMERIC_MAX_PRECISION, NUMERIC_MAX_SCALE, &err);
	  if (err)
	    return err;
	  if (ret)
	    ret->j = (jlong) unbox (val);
	  dk_free_box (val);
	  break;

	case 'F':
	  val = box_cast_to (qst, value, DV_TYPE_OF (value), DV_SINGLE_FLOAT,
	      NUMERIC_MAX_PRECISION, NUMERIC_MAX_SCALE, &err);
	  if (err)
	    return err;
	  if (ret)
	    ret->f = (jfloat) unbox_float (val);
	  dk_free_box (val);
	  break;

	case 'D':
	  val = box_cast_to (qst, value, DV_TYPE_OF (value), DV_DOUBLE_FLOAT,
	      NUMERIC_MAX_PRECISION, NUMERIC_MAX_SCALE, &err);
	  if (err)
	    return err;
	  if (ret)
	    ret->d = (jdouble) unbox_double (val);
	  dk_free_box (val);
	  break;

	default:
	  return srv_make_new_error ("22023", "JV005",
	      "Invalid java JNI type");
	}
    }
  else if (java_name_len > 1 && java_name[0] == '['
      && ((java_name[1] == 'B' && DV_TYPE_OF (value) == DV_BIN) ||
	  DV_TYPE_OF (value) == DV_ARRAY_OF_POINTER
	))
    {
      jarray array;
      jvalue jelt;
      int inx;

      switch (java_name[1])
	{
	case 'Z':		/* boolean */
	  array = MAKE_JAVA_ARRAY (Boolean, z, value, java_name + 1);
	  if (ret)
	    ret->l = array;
	  break;
	case 'B':		/* byte */
	  if (DV_TYPE_OF (value) == DV_BIN)
	    {
	      array = (*env)->NewByteArray (env, box_length (value));
	      (*env)->SetByteArrayRegion (env, array, 0, box_length (value), value);
	    }
	  else
	    {
	      array = MAKE_JAVA_ARRAY (Byte, b, value, java_name + 1);
	    }
	  if (ret)
	    ret->l = array;
	  break;
	case 'C':		/* char */
	  array = MAKE_JAVA_ARRAY (Char, c, value, java_name + 1);
	  if (ret)
	    ret->l = array;
	  break;
	case 'S':		/* short */
	  array = MAKE_JAVA_ARRAY (Short, s, value, java_name + 1);
	  if (ret)
	    ret->l = array;
	  break;
	case 'I':
	  array = MAKE_JAVA_ARRAY (Int, i, value, java_name + 1);
	  if (ret)
	    ret->l = array;
	  break;
	case 'J':
	  array = MAKE_JAVA_ARRAY (Long, j, value, java_name + 1);
	  if (ret)
	    ret->l = array;
	  break;
	case 'F':
	  array = MAKE_JAVA_ARRAY (Float, f, value, java_name + 1);
	  if (ret)
	    ret->l = array;
	  break;
	case 'D':
	  array = MAKE_JAVA_ARRAY (Double, d, value, java_name + 1);
	  if (ret)
	    ret->l = array;
	  break;
	case 'L':
	case '[':
	  if (BOX_ELEMENTS (value) > 0)
	    {
	      err =
		  java_dv_to_jvalue (qst, env, ((caddr_t *) value)[0],
		      java_name + 1, &jelt);
	      if (err)
		return err;
	      array =
		  (*env)->NewObjectArray (env, BOX_ELEMENTS (value),
					  (*env)->GetObjectClass (env, jelt.l), NULL);
	      (*env)->SetObjectArrayElement (env, array, 0, jelt.l);
	      for (inx = 1; inx < (int) BOX_ELEMENTS (value); inx++)
		{
		  err =
		      java_dv_to_jvalue (qst, env, ((caddr_t *) value)[inx],
			  java_name + 1, &jelt);
		  if (err)
		    {
		      (*env)->DeleteLocalRef (env, array);
		      return err;
		    }
		  (*env)->SetObjectArrayElement (env, array, inx, jelt.l);
		}
	    }
	  else
	    {
	      jclass cls = NULL;
	      cls = (*env)->FindClass (env, java_name + 1);
	      array =
		  (*env)->NewObjectArray (env, BOX_ELEMENTS (value),
					  cls, NULL);
	    }
	  if (ret)
	    ret->l = array;
	  break;
	default:
	  return srv_make_new_error ("22023", "JV006", "Unknown array type");
	}
    }
  else if (!strcmp (java_name, "Ljava/lang/String;") && !IS_JAVA_OBJ (value) && DV_TYPE_OF (value) != DV_OBJECT)
    {
      char *utf8_string;
      val = box_cast_to (qst, value, DV_TYPE_OF (value), DV_WIDE,
	  NUMERIC_MAX_PRECISION, NUMERIC_MAX_SCALE, &err);
      if (err)
	return err;
      utf8_string =
	  box_wide_as_utf8_char (val,
	  (box_length (val) - sizeof (wchar_t)) / sizeof (wchar_t),
	  DV_SHORT_STRING);
      dk_free_box (val);

      if (ret)
	ret->l = (*env)->NewStringUTF (env, utf8_string);
      dk_free_box (utf8_string);
    }
  else if (!strcmp (java_name, "Ljava/util/Date;") && !IS_JAVA_OBJ (value) && DV_TYPE_OF (value) != DV_OBJECT)
    {
      val = box_cast_to (qst, value, DV_TYPE_OF (value), DV_DATETIME,
	  NUMERIC_MAX_PRECISION, NUMERIC_MAX_SCALE, &err);
      if (err)
	return err;

      if (ret)
	{
	  int year, month, day, hour, minute, second;

	  dt_to_parts (val, &year, &month, &day, &hour, &minute, &second, NULL);
	  ret->l = (*env)->NewObject (env, GregorianCal_class, GregorianCal_init_id,
	      year, month - 1, day, hour, minute, second);
	  ret->l = (*env)->CallObjectMethod (env, GregorianCal_class, GregorianCal_getTime_id, NULL);

	}
      dk_free_box (val);
    }
  else if (IS_JAVA_OBJ (value))
    {
      if (ret)
	ret->l = ((extension_obj_t *) value)->exo_object;
    }
  else if (DV_TYPE_OF (value) == DV_OBJECT)
    {
      sql_class_t *udt = UDT_I_CLASS (value);
      if ((udt && udt->scl_ext_lang != UDT_LANG_JAVA) ||
	  (!udt && BOX_ELEMENTS (value) < 2))
	return srv_make_new_error ("22023", "JVXXX", "Invalid user defined type instance supplied");
      if (ret)
	ret->l = UDT_JVM_I_OBJECT (value);
    }
  else
    return srv_make_new_error ("22023", "JV007", "Invalid PL value supplied");
  return NULL;

  return err;
}


static sql_class_t *
udt_find_class_for_java_instance (JNIEnv *env, jobject java_obj, sql_class_t *target_udt,
    client_connection_t *cli)
{
  id_casemode_hash_iterator_t hit;
  sql_class_t **pudt = NULL;
  sql_class_t *curr_best_udt = NULL;

  id_casemode_hash_iterator (&hit, isp_schema(NULL)->sc_name_to_object[sc_to_type]);
  while (id_casemode_hit_next (&hit, (char **) &pudt))
    {
      sql_class_t *udt = *pudt;
      if (udt && udt->scl_ext_lang == UDT_LANG_JAVA && udt->scl_ext_name &&
	  (!target_udt || udt_instance_of (udt, target_udt)) &&
	  (!cli || !casemode_strcmp (cli->cli_qualifier, udt->scl_qualifier)))
	{
	  caddr_t class_name = escape_class_name (udt->scl_ext_name);
	  jclass cls = (*env)->FindClass (env, class_name);
	  dk_free_box (class_name);
	  if (cls && JNI_TRUE == (*env)->IsInstanceOf (env, java_obj, cls))
	    {
	      if (!curr_best_udt || udt_instance_of (udt, curr_best_udt))
		curr_best_udt = udt;
	    }
	}
    }
  return curr_best_udt;
}

static caddr_t
java_jvalue_to_dv (JNIEnv * env, char *java_name, jvalue * jret,
    caddr_t * err_ret, int do_udt, sql_class_t *target_udt, client_connection_t *cli)
{
  caddr_t ret = NULL;
  char *utf8_chars;
  int utf8_chars_len;
  int java_name_len = strlen (java_name);
  if (java_name_len == 1)
    {
      switch (toupper (java_name[0]))
	{
	case 'Z':		/* boolean */
	  ret = box_num ((ptrlong) (jret->z == JNI_TRUE ? 1 : 0));
	  break;

	case 'B':		/* byte */
	  ret = box_num ((ptrlong) jret->b);
	  break;

	case 'C':		/* char */
	  ret = box_num ((ptrlong) jret->c);
	  break;

	case 'S':		/* char */
	  ret = box_num ((ptrlong) jret->s);
	  break;

	case 'I':		/* int */
	  ret = box_num ((ptrlong) jret->i);
	  break;

	case 'J':		/* long */
	  ret = box_num ((ptrlong) jret->j);
	  break;

	case 'F':		/* float */
	  ret = box_float (jret->f);
	  break;

	case 'D':		/* double */
	  ret = box_double (jret->d);
	  break;
	case 'V':		/* void */
	  break;
	default:
	  *err_ret =
	      srv_make_new_error ("22023", "JV008", "Invalid java JNI type");
	}
    }
  else if (java_name_len > 1 && java_name[0] == '[')
    {
      jarray array;
      int n_elements, inx;

      if (jret->l == NULL)
	{
	  ret = dk_alloc_box (0, DV_DB_NULL);
	  return ret;
	}
      else
	array = jret->l;

      n_elements = (*env)->GetArrayLength (env, array);

      if (java_name[1] == 'B')
	{
	  ret = dk_alloc_box (n_elements, DV_BIN);
	  (*env)->GetByteArrayRegion (env, array, 0, n_elements, ret);
	  goto array_done;
	}

      ret =
	  dk_alloc_box (n_elements * sizeof (caddr_t *), DV_ARRAY_OF_POINTER);
      memset (ret, 0, n_elements * sizeof (caddr_t *));

      for (inx = 0; inx < n_elements; inx++)
	{
	  jvalue jval;

	  switch (java_name[1])
	    {
	    case 'Z':		/* boolean */
	      (*env)->GetBooleanArrayRegion (env, array, inx, 1, &jval.z);
	      break;
	    case 'B':		/* byte */
	      (*env)->GetByteArrayRegion (env, array, inx, 1, &jval.b);
	      break;
	    case 'C':		/* char */
	      (*env)->GetCharArrayRegion (env, array, inx, 1, &jval.c);
	      break;
	    case 'S':		/* short */
	      (*env)->GetShortArrayRegion (env, array, inx, 1, &jval.s);
	      break;
	    case 'I':
	      (*env)->GetIntArrayRegion (env, array, inx, 1, &jval.i);
	      break;
	    case 'J':
	      (*env)->GetLongArrayRegion (env, array, inx, 1, &jval.j);
	      break;
	    case 'F':
	      (*env)->GetFloatArrayRegion (env, array, inx, 1, &jval.f);
	      break;
	    case 'D':
	      (*env)->GetDoubleArrayRegion (env, array, inx, 1, &jval.d);
	      break;
	    case 'L':
	    case '[':
	      jval.l = (*env)->GetObjectArrayElement (env, array, inx);
	      break;
	    default:
	      *err_ret =
		  srv_make_new_error ("23023", "JV009", "Invalid array type");
	      dk_free_tree (ret);
	      return NULL;
	    }
	  ((caddr_t *) ret)[inx] =
	      java_jvalue_to_dv (env, java_name + 1, &jval, err_ret, do_udt, NULL, cli);
	  if (*err_ret)
	    {
	      dk_free_tree (ret);
	      return NULL;
	    }
	}
array_done:;
    }
  else if (!strcmp (java_name, "Ljava/lang/String;"))
    {
      if (jret->l == NULL)
	{
	  ret = dk_alloc_box (0, DV_DB_NULL);
	  return ret;
	}
      utf8_chars_len = (*env)->GetStringUTFLength (env, jret->l);
      utf8_chars = (char *) (*env)->GetStringUTFChars (env, jret->l, NULL);
      if (0 == utf8_chars_len)
	ret = box_wide_char_string (utf8_chars, 0);
      else
	{
	  caddr_t temp = box_varchar_string (utf8_chars, utf8_chars_len,
	      DV_SHORT_STRING);
	  ret =
	      box_utf8_as_wide_char (utf8_chars, NULL, utf8_chars_len, 0);
	  dk_free_box (temp);
	}
      (*env)->ReleaseStringUTFChars (env, jret->l, utf8_chars);
    }
  else if (!strcmp (java_name, "Ljava/util/Date;"))
    {
      if (jret->l == NULL)
	{
	  ret = dk_alloc_box (0, DV_DB_NULL);
	  return ret;
	}
      ret = dk_alloc_box (DT_LENGTH, DV_DATETIME);
      dt_from_parts (ret,
	  (*env)->CallIntMethod (env, jret->l, getYear_id) + 1900,
	  (*env)->CallIntMethod (env, jret->l, getMonth_id) + 1,
	  (*env)->CallIntMethod (env, jret->l, getDate_id),
	  (*env)->CallIntMethod (env, jret->l, getHours_id),
	  (*env)->CallIntMethod (env, jret->l, getMinutes_id),
	  (*env)->CallIntMethod (env, jret->l, getSeconds_id),
	  0, (*env)->CallIntMethod (env, jret->l, getTimezoneOffset_id) * -1);
      return ret;
    }
  else
    {
      if (jret->l == NULL)
	{
	  ret = dk_alloc_box (0, DV_DB_NULL);
	  return ret;
	}
      if (do_udt)
	{
	  sql_class_t *udt;
	  udt =	udt_find_class_for_java_instance (env, jret->l, target_udt, cli);
	  if (!udt && target_udt)
	    udt = udt_find_class_for_java_instance (env, jret->l, NULL, cli);
	  if (!udt)
	    {
	      udt = java_unk_object;
	    }
	  ret = udt_jvm_instance_allocate (env, jret->l, udt);
	}
      if (!ret)
	ret = java_object_dv_alloc (env, jret->l);
    }
  return ret;
}


static jvalue
java_method_call (JNIEnv * env, char *java_name, jobject instance_obj,
    jobject class_obj, jmethodID method_obj, jvalue * args)
{
  jvalue jret;
  int java_name_len = strlen (java_name);
  if (java_name_len == 1)
    {
      switch (toupper (java_name[0]))
	{
	case 'Z':		/* boolean */
	  if (!instance_obj)
	    jret.z =
		(*env)->CallStaticBooleanMethodA (env, class_obj, method_obj,
		args);
	  else
	    jret.z =
		(*env)->CallBooleanMethodA (env, instance_obj, method_obj,
		args);
	  break;

	case 'B':		/* byte */
	  if (!instance_obj)
	    jret.b =
		(*env)->CallStaticByteMethodA (env, class_obj, method_obj,
		args);
	  else
	    jret.b =
		(*env)->CallByteMethodA (env, instance_obj, method_obj, args);
	  break;

	case 'C':		/* char */
	  if (!instance_obj)
	    jret.c =
		(*env)->CallStaticCharMethodA (env, class_obj, method_obj,
		args);
	  else
	    jret.c =
		(*env)->CallCharMethodA (env, instance_obj, method_obj, args);
	  break;

	case 'S':		/* char */
	  if (!instance_obj)
	    jret.s =
		(*env)->CallStaticShortMethodA (env, class_obj, method_obj,
		args);
	  else
	    jret.s =
		(*env)->CallShortMethodA (env, instance_obj, method_obj,
		args);
	  break;

	case 'I':		/* int */
	  if (!instance_obj)
	    jret.i =
		(*env)->CallStaticIntMethodA (env, class_obj, method_obj,
		args);
	  else
	    jret.i =
		(*env)->CallIntMethodA (env, instance_obj, method_obj, args);
	  break;

	case 'J':		/* long */
	  if (!instance_obj)
	    jret.j =
		(*env)->CallStaticLongMethodA (env, class_obj, method_obj,
		args);
	  else
	    jret.j =
		(*env)->CallLongMethodA (env, instance_obj, method_obj, args);
	  break;

	case 'F':		/* float */
	  if (!instance_obj)
	    jret.f =
		(*env)->CallStaticFloatMethodA (env, class_obj, method_obj,
		args);
	  else
	    jret.f =
		(*env)->CallFloatMethodA (env, instance_obj, method_obj,
		args);
	  break;

	case 'D':		/* double */
	  if (!instance_obj)
	    jret.d =
		(*env)->CallStaticDoubleMethodA (env, class_obj, method_obj,
		args);
	  else
	    jret.d =
		(*env)->CallDoubleMethodA (env, instance_obj, method_obj,
		args);
	  break;

	case 'V':		/* void */
	  if (!instance_obj)
	    (*env)->CallStaticVoidMethodA (env, class_obj, method_obj, args);
	  else
	    (*env)->CallVoidMethodA (env, instance_obj, method_obj, args);
	  jret.l = NULL;
	  break;
	}
    }
  else
    {
      if (!instance_obj)
	jret.l =
	    (*env)->CallStaticObjectMethodA (env, class_obj, method_obj,
	    args);
      else
	jret.l =
	    (*env)->CallObjectMethodA (env, instance_obj, method_obj, args);
    }
  return jret;
}


static void
java_get_field (JNIEnv * env, char *java_name,
    jobject instance_obj, jobject class_obj, jfieldID field_obj, jvalue *jret)
{
  int java_name_len = strlen (java_name);
  if (java_name_len == 1)
    {
      switch (toupper (java_name[0]))
	{
	case 'Z':		/* boolean */
	  if (!instance_obj)
	    jret->z =
		(*env)->GetStaticBooleanField (env, class_obj, field_obj);
	  else
	    jret->z = (*env)->GetBooleanField (env, instance_obj, field_obj);
	  break;

	case 'B':		/* byte */
	  if (!instance_obj)
	    jret->b = (*env)->GetStaticByteField (env, class_obj, field_obj);
	  else
	    jret->b = (*env)->GetByteField (env, instance_obj, field_obj);
	  break;

	case 'C':		/* char */
	  if (!instance_obj)
	    jret->c = (*env)->GetStaticCharField (env, class_obj, field_obj);
	  else
	    jret->c = (*env)->GetCharField (env, instance_obj, field_obj);
	  break;

	case 'S':		/* short */
	  if (!instance_obj)
	    jret->s = (*env)->GetStaticShortField (env, class_obj, field_obj);
	  else
	    jret->s = (*env)->GetShortField (env, instance_obj, field_obj);
	  break;

	case 'I':		/* integer */
	  if (!instance_obj)
	    jret->i = (*env)->GetStaticIntField (env, class_obj, field_obj);
	  else
	    jret->i = (*env)->GetIntField (env, instance_obj, field_obj);
	  break;

	case 'J':		/* long */
	  if (!instance_obj)
	    jret->j = (*env)->GetStaticLongField (env, class_obj, field_obj);
	  else
	    jret->j = (*env)->GetLongField (env, instance_obj, field_obj);
	  break;

	case 'F':		/* float */
	  if (!instance_obj)
	    jret->f = (*env)->GetStaticFloatField (env, class_obj, field_obj);
	  else
	    jret->f = (*env)->GetFloatField (env, instance_obj, field_obj);
	  break;

	case 'D':		/* double */
	  if (!instance_obj)
	    jret->d = (*env)->GetStaticDoubleField (env, class_obj, field_obj);
	  else
	    jret->d = (*env)->GetDoubleField (env, instance_obj, field_obj);
	  break;
	}
    }
  else
    {
      if (!instance_obj)
	jret->l = (*env)->GetStaticObjectField (env, class_obj, field_obj);
      else
	jret->l = (*env)->GetObjectField (env, instance_obj, field_obj);
    }
}


static caddr_t
java_set_field (JNIEnv * env, char *java_name,
    jobject instance_obj, jobject class_obj, jfieldID field_obj,
    jvalue * value)
{
  caddr_t err = NULL;
  int java_name_len = strlen (java_name);

  if (java_name_len == 1)
    {
      switch (toupper (java_name[0]))
	{
	case 'Z':		/* boolean */
	  if (!instance_obj)
	    (*env)->SetStaticBooleanField (env, class_obj, field_obj,
		value->z);
	  else
	    (*env)->SetBooleanField (env, instance_obj, field_obj, value->z);
	  break;

	case 'B':		/* byte */
	  if (!instance_obj)
	    (*env)->SetStaticByteField (env, class_obj, field_obj, value->b);
	  else
	    (*env)->SetByteField (env, instance_obj, field_obj, value->b);
	  break;

	case 'C':		/* byte */
	  if (!instance_obj)
	    (*env)->SetStaticCharField (env, class_obj, field_obj, value->c);
	  else
	    (*env)->SetCharField (env, instance_obj, field_obj, value->c);
	  break;

	case 'S':		/* short */
	  if (!instance_obj)
	    (*env)->SetStaticShortField (env, class_obj, field_obj, value->s);
	  else
	    (*env)->SetShortField (env, instance_obj, field_obj, value->s);
	  break;

	case 'I':		/* short */
	  if (!instance_obj)
	    (*env)->SetStaticIntField (env, class_obj, field_obj, value->i);
	  else
	    (*env)->SetIntField (env, instance_obj, field_obj, value->i);
	  break;

	case 'J':		/* long */
	  if (!instance_obj)
	    (*env)->SetStaticLongField (env, class_obj, field_obj, value->j);
	  else
	    (*env)->SetLongField (env, instance_obj, field_obj, value->j);
	  break;

	case 'F':		/* float */
	  if (!instance_obj)
	    (*env)->SetStaticFloatField (env, class_obj, field_obj, value->f);
	  else
	    (*env)->SetFloatField (env, instance_obj, field_obj, value->f);
	  break;

	case 'D':		/* double */
	  if (!instance_obj)
	    (*env)->SetStaticDoubleField (env, class_obj, field_obj,
		value->d);
	  else
	    (*env)->SetDoubleField (env, instance_obj, field_obj, value->d);
	  break;
	}
    }
  else
    {
      if (!instance_obj)
	(*env)->SetStaticObjectField (env, class_obj, field_obj, value->l);
      else
	(*env)->SetObjectField (env, instance_obj, field_obj, value->l);
    }
  IF_JAVA_ERR_GO (env, done, err);
done:
  return err;
}


static caddr_t
java_dv_to_sig (dtp_t dtp)
{
  switch (dtp)
    {
    case DV_SHORT_INT:
      return "S";
    case DV_LONG_INT:
      return "I";
    case DV_SINGLE_FLOAT:
      return "F";
    case DV_DOUBLE_FLOAT:
      return "D";
    case DV_SHORT_STRING:
    case DV_WIDE:
    case DV_LONG_WIDE:
      return "Ljava/lang/String;";
    case DV_DATETIME:
    case DV_TIMESTAMP:
      return "Ljava/util/Date;";
    case DV_BIN:
      return "[B";
    }
  return NULL;
}

/* BIFs */

/*
static int
java_load_class (JNIEnv *env, caddr_t name, caddr_t bytes, caddr_t *err_ret)
{
  jclass class, class_loader_class;
  jvalue jargs[1];
  jclass ClassLoader_class = 0;
  jmethodID ClassLoader_getSystemClassLoader_id = 0;
  jmethodID ClassLoader_resolveClass_id = 0;

  GET_CLASS_ID (env, ClassLoader_class, "java/lang/ClassLoader", finish, *err_ret);
  GET_STATIC_METHOD_ID (env, ClassLoader_class, ClassLoader_getSystemClassLoader_id, "getSystemClassLoader", "()Ljava/lang/ClassLoader;", finish, *err_ret);
  GET_METHOD_ID (env, ClassLoader_class, ClassLoader_resolveClass_id, "resolveClass", "(Ljava/lang/Class;)V", finish, *err_ret);
  class_loader_class = (*env)->CallStaticObjectMethod (env, ClassLoader_class,
      ClassLoader_getSystemClassLoader_id, NULL);
  IF_JAVA_ERR_GO (env, finish, *err_ret);
  if (!class_loader_class)
    goto finish;
  class =
      (*env)->DefineClass (env, name, class_loader_class, (jbyte *) bytes,
      box_length (bytes) - 1);

  IF_JAVA_ERR_GO (env, finish, *err_ret);
  if (class == NULL)
    {
      *err_ret =
	  srv_make_new_error ("42000", "JV010",
	      "Class definition for %.200s failed", name);
      goto finish;
    }
  jargs[0].l = class;
  (*env)->CallVoidMethod (env, class_loader_class, ClassLoader_resolveClass_id, jargs);
  IF_JAVA_ERR_GO (env, finish, *err_ret);
  return 1;
finish:
  return 0;
}
*/

static caddr_t
bif_java_load_class (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  JNIEnv *env = NULL;
  caddr_t err = NULL;
  jvalue jret;
  caddr_t ret = NULL;
  caddr_t name = escape_class_name (bif_string_or_null_arg (qst, args, 0,
	  "java_load_class"));
  /*caddr_t bytes = bif_string_arg (qst, args, 1, "java_load_class");*/

  IO_SECT(qst);

  if (NULL != (err = java_vm_attach (&env, 1, NULL, NULL)))
    goto finish;

  PUSH_FRAME (env, 200);
  jret.l = (*env)->FindClass (env, name);
  IF_JAVA_ERR_GO (env, finish, *err_ret);
  ret = java_object_dv_alloc (env, jret.l);
#if 0
  java_load_class (env, name, bytes, &err);
#endif
finish:
  dk_free_box (name);
  POP_FRAME (env, NULL);
  if (env)
    {
      caddr_t err_d = NULL;
      err_d = java_vm_detach ();
      if (err)
	dk_free_tree (err_d);
      else
	err = err_d;
    }
  END_IO_SECT (err_ret);
  if (err)
    {
      if (*err_ret)
	dk_free_tree (*err_ret);
      *err_ret = err;
    }
  if (*err_ret)
    {
      dk_free_tree (ret);
      ret = NULL;
    }
  return ret;
}

static caddr_t
bif_java_call_method (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  JNIEnv *env = NULL;
  caddr_t ret = NULL;
  caddr_t class_name =
      escape_class_name (bif_string_or_null_arg (qst, args, 0,
	  "java_call_method"));
  jobject instance_obj = (jobject) bif_arg (qst, args, 1, "java_call_method");
  caddr_t method_name = bif_string_arg (qst, args, 2, "java_call_method");
  caddr_t method_ret_name =
      escape_class_name (bif_string_arg (qst, args, 3, "java_call_method"));
  query_instance_t *qi = (query_instance_t *)qst;
  client_connection_t *cli = qi->qi_client;
  int n_args = BOX_ELEMENTS (args) - 4, inx;

  jclass class_obj;
  jmethodID method_obj;
  jvalue *jargs = NULL, jret;
  char method_sig[4096];

  IO_SECT(qst);

  jvm_activate_access_granter (1);

  if (NULL != (*err_ret = java_vm_attach (&env, 1, NULL, NULL)))
    goto finish;

  if (!IS_JAVA_OBJ (instance_obj))
    instance_obj = NULL;
  else
    instance_obj = ((extension_obj_t *) instance_obj)->exo_object;


  PUSH_FRAME (env, 200);
  class_obj = (*env)->FindClass (env, class_name);
  IF_JAVA_ERR_GO (env, finish, *err_ret);
  if (class_obj == NULL)
    {
      *err_ret =
	  srv_make_new_error ("42000", "JV011",
	  "Class '%.100s' definition not found", class_name);
      goto finish;
    }

  if (instance_obj && JNI_TRUE != (*env)->IsInstanceOf (env, instance_obj, class_obj))
    {
      *err_ret = srv_make_new_error ("42000", "JV012",
	  "The object supplied is not an instance of %.100s", class_name);
      goto finish;
    }

  strcpy (method_sig, "(");
  if (n_args)
    {
      jargs =
	  (jvalue *) dk_alloc_box (sizeof (jvalue) * n_args, DV_LONG_STRING);
      for (inx = 0; inx < n_args; inx++)
	{
	  caddr_t value = bif_arg (qst, args, inx + 4, "java_call_method");
	  caddr_t sig = NULL;
	  if (DV_TYPE_OF (value) == DV_ARRAY_OF_POINTER
	      && BOX_ELEMENTS (value) == 2)
	    {
	      sig = ((caddr_t *) value)[0];
	      value = ((caddr_t *) value)[1];
	    }
	  else if (NULL == (sig = java_dv_to_sig (DV_TYPE_OF (value))))
	    {
	      *err_ret =
		  srv_make_new_error ("42000", "JV013",
		  "Unsupported type in parameter %d of java_call_method",
		  inx);
	      goto finish;
	    }

/*	  if (inx)
	    strcat (method_sig, ", ");*/
	  strcat (method_sig, sig);
	  if (NULL != (*err_ret = java_dv_to_jvalue (qst, env, value, sig,
		      &(jargs[inx]))))
	    {
	      goto finish;
	    }
	}
    }
  strcat (method_sig, ")");
  strcat (method_sig, method_ret_name);

  if (!instance_obj)
    method_obj =
	(*env)->GetStaticMethodID (env, class_obj, method_name, method_sig);
  else
    method_obj =
	(*env)->GetMethodID (env, class_obj, method_name, method_sig);
  IF_JAVA_ERR_GO (env, finish, *err_ret);
  if (method_obj == NULL)
    {
      *err_ret =
	  srv_make_new_error ("42000", "JV014",
	  "No method '%.100s' (sig : '%.100s') in class '%.100s'", method_name, method_sig, class_name);
      goto finish;
    }

  jret = java_method_call (env, method_ret_name, instance_obj, class_obj,
      method_obj, jargs);
  IF_JAVA_ERR_GO (env, finish, *err_ret);
  ret = java_jvalue_to_dv (env, method_ret_name, &jret, err_ret, 0, NULL, cli);
  if (*err_ret)
    goto finish;
  IF_JAVA_ERR_GO (env, finish, *err_ret);
  if (n_args)
    {
      for (inx = 0; inx < n_args; inx++)
	{
	  if (ssl_is_settable (args[inx + 4]))
	    {
	      caddr_t value = bif_arg (qst, args, inx + 4, "java_call_method");
	      caddr_t sig = NULL;
	      if (DV_TYPE_OF (value) == DV_ARRAY_OF_POINTER
		  && BOX_ELEMENTS (value) == 2)
		{
		  sig = ((caddr_t *) value)[0];
		  value = ((caddr_t *) value)[1];
		}
	      else if (NULL == (sig = java_dv_to_sig (DV_TYPE_OF (value))))
		{
		  *err_ret =
		      srv_make_new_error ("42000", "JV013",
			  "Unsupported type in parameter %d of java_call_method",
			  inx);
		  goto finish;
		}
	      if (sig && strlen (sig) > 0 && (sig[0] == '[' || sig[0] == 'L'))
		{
		  caddr_t retp = java_jvalue_to_dv (env, sig, &(jargs[inx]), err_ret, 0, NULL, cli);
		  if (*err_ret)
		    goto finish;
		  qst_set (qst, args[inx + 4], retp);
		}
	    }
	}
    }
finish:
  dk_free_box (class_name);
  dk_free_box (method_ret_name);
  dk_free_box (jargs);
  POP_FRAME (env, ret);
  if (env)
    {
      caddr_t err = java_vm_detach ();
      if (!*err_ret)
	*err_ret = err;
      else
	dk_free_tree (err);
    }
  if (*err_ret)
    {
      dk_free_tree (ret);
      ret = NULL;
    }
  END_IO_SECT (err_ret);
  if (*err_ret)
    {
      dk_free_tree (ret);
      ret = NULL;
    }
  return ret;
}


static caddr_t
bif_java_get_property (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  JNIEnv *env = NULL;
  caddr_t ret = NULL;
  caddr_t class_name =
      escape_class_name (bif_string_or_null_arg (qst, args, 0,
	  "java_get_property"));
  jobject instance_obj =
      (jobject) bif_arg (qst, args, 1, "java_get_property");
  caddr_t field_name = bif_string_arg (qst, args, 2, "java_get_property");
  caddr_t field_ret_name =
      escape_class_name (bif_string_arg (qst, args, 3, "java_get_property"));
  query_instance_t *qi = (query_instance_t *)qst;
  client_connection_t *cli = qi->qi_client;

  jclass class_obj;
  jfieldID field_obj;
  jvalue jret;

  IO_SECT(qst);

  if (NULL != (*err_ret = java_vm_attach (&env, 1, NULL, NULL)))
    goto finish;

  PUSH_FRAME (env, 200);
  if (!IS_JAVA_OBJ (instance_obj))
    instance_obj = NULL;
  else
    instance_obj = ((extension_obj_t *) instance_obj)->exo_object;

  class_obj = (*env)->FindClass (env, class_name);
  IF_JAVA_ERR_GO (env, finish, *err_ret);
  if (class_obj == NULL)
    {
      *err_ret =
	  srv_make_new_error ("42000", "JV015",
	  "Class '%.100s' definition not found", class_name);
      goto finish;
    }

  if (instance_obj && JNI_TRUE != (*env)->IsInstanceOf (env, instance_obj, class_obj))
    {
      *err_ret = srv_make_new_error ("42000", "JV016",
	  "The object supplied is not an instance of %.100s", class_name);
      goto finish;
    }


  if (!instance_obj)
    field_obj =
	(*env)->GetStaticFieldID (env, class_obj, field_name, field_ret_name);
  else
    field_obj =
	(*env)->GetFieldID (env, class_obj, field_name, field_ret_name);
  IF_JAVA_ERR_GO (env, finish, *err_ret);
  if (field_obj == NULL)
    {
      *err_ret =
	  srv_make_new_error ("42000", "JV017",
	  "No field '%.100s' (sig : '%.100s') in class '%.100s'", field_name, field_ret_name, class_name);
      goto finish;
    }

  java_get_field (env, field_ret_name, instance_obj, class_obj,
      field_obj, &jret);
  ret = java_jvalue_to_dv (env, field_ret_name, &jret, err_ret, 0, NULL, cli);
  if (*err_ret)
    goto finish;
  IF_JAVA_ERR_GO (env, finish, *err_ret);

finish:
  dk_free_box (class_name);
  dk_free_box (field_ret_name);
  POP_FRAME (env, ret);
  if (env)
    {
      caddr_t err = java_vm_detach ();
      if (!*err_ret)
	*err_ret = err;
      else
	dk_free_tree (err);
    }
  if (*err_ret)
    {
      dk_free_tree (ret);
      ret = NULL;
    }
  END_IO_SECT (err_ret);
  if (*err_ret)
    {
      dk_free_tree (ret);
      ret = NULL;
    }
  return ret;
}


static caddr_t
bif_java_set_property (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  JNIEnv *env = NULL;
  caddr_t ret = NULL;
  caddr_t class_name =
      escape_class_name (bif_string_or_null_arg (qst, args, 0,
	  "java_set_property"));
  jobject instance_obj =
      (jobject) bif_arg (qst, args, 1, "java_set_property");
  caddr_t field_name = bif_string_arg (qst, args, 2, "java_set_property");
  caddr_t field_ret_name =
      escape_class_name (bif_string_arg (qst, args, 3, "java_set_property"));
  caddr_t field_value = bif_arg (qst, args, 4, "java_set_property");

  jclass class_obj;
  jfieldID field_obj;
  jvalue jv;

  IO_SECT(qst);

  if (NULL != (*err_ret = java_vm_attach (&env, 1, NULL, NULL)))
    goto finish;

  if (!IS_JAVA_OBJ (instance_obj))
    instance_obj = NULL;
  else
    instance_obj = ((extension_obj_t *) instance_obj)->exo_object;

  PUSH_FRAME (env, 200);
  class_obj = (*env)->FindClass (env, class_name);
  IF_JAVA_ERR_GO (env, finish, *err_ret);
  if (class_obj == NULL)
    {
      *err_ret =
	  srv_make_new_error ("42000", "JV018",
	  "Class '%.100s' definition not found", class_name);
      goto finish;
    }

  if (instance_obj && JNI_TRUE != (*env)->IsInstanceOf (env, instance_obj, class_obj))
    {
      *err_ret = srv_make_new_error ("42000", "JV019",
	  "The object supplied is not an instance of %.100s", class_name);
      goto finish;
    }

  if (!instance_obj)
    field_obj =
	(*env)->GetStaticFieldID (env, class_obj, field_name, field_ret_name);
  else
    field_obj =
	(*env)->GetFieldID (env, class_obj, field_name, field_ret_name);
  IF_JAVA_ERR_GO (env, finish, *err_ret);
  if (field_obj == NULL)
    {
      *err_ret =
	  srv_make_new_error ("42000", "JV020",
	  "No field '%.100s' (sig : '%.100s') in class '%.100s'", field_name, field_ret_name, class_name);
      goto finish;
    }

  if (NULL != (*err_ret =
	  java_dv_to_jvalue (qst, env, field_value, field_ret_name, &jv)))
    goto finish;

  if (NULL != (*err_ret = java_set_field (env, field_ret_name, instance_obj,
	      class_obj, field_obj, &jv)))
    goto finish;
  IF_JAVA_ERR_GO (env, finish, *err_ret);

finish:
  POP_FRAME (env, ret);
  if (env)
    {
      caddr_t err = java_vm_detach ();
      if (!*err_ret)
	*err_ret = err;
      else
	dk_free_tree (err);
    }
  if (*err_ret)
    {
      dk_free_tree (ret);
      ret = NULL;
    }
  END_IO_SECT (err_ret);
  if (*err_ret)
    {
      dk_free_tree (ret);
      ret = NULL;
    }
  return ret;
}


static caddr_t
bif_java_new_object (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  JNIEnv *env = NULL;
  caddr_t ret = NULL;
  caddr_t class_name =
      escape_class_name (bif_string_or_null_arg (qst, args, 0,
	  "java_new_method"));
  int n_args = BOX_ELEMENTS (args) - 1, inx;

  jclass class_obj;
  jobject new_obj;
  jmethodID method_obj;
  jvalue *jargs = NULL;
  char method_sig[4096];

  IO_SECT(qst);

  if (NULL != (*err_ret = java_vm_attach (&env, 1, NULL, NULL)))
    goto finish;

  PUSH_FRAME (env, 200);
  class_obj = (*env)->FindClass (env, class_name);
  IF_JAVA_ERR_GO (env, finish, *err_ret);
  if (class_obj == NULL)
    {
      *err_ret =
	  srv_make_new_error ("42000", "JV021",
	  "Class '%.100s' definition not found", class_name);
      goto finish;
    }

  strcpy (method_sig, "(");
  if (n_args)
    {
      jargs =
	  (jvalue *) dk_alloc_box (sizeof (jvalue) * n_args, DV_LONG_STRING);
      for (inx = 0; inx < n_args; inx++)
	{
	  caddr_t value = bif_arg (qst, args, inx + 1, "java_call_method");
	  caddr_t sig = NULL;

	  if (DV_TYPE_OF (value) == DV_ARRAY_OF_POINTER
	      && BOX_ELEMENTS (value) == 2)
	    {
	      sig = ((caddr_t *) value)[0];
	      value = ((caddr_t *) value)[1];
	    }
	  else if (NULL == (sig = java_dv_to_sig (DV_TYPE_OF (value))))
	    {
	      *err_ret =
		  srv_make_new_error ("42000", "JV022",
		  "Unsupported type in parameter %d of java_call_method",
		  inx);
	      goto finish;
	    }

/*	  if (inx)
	    strcat (method_sig, ", ");*/
	  strcat (method_sig, sig);
	  if (NULL != (*err_ret =
		  java_dv_to_jvalue (qst, env, value, sig, &(jargs[inx]))))
	    {
	      goto finish;
	    }
	}
    }
  strcat (method_sig, ")V");

  method_obj = (*env)->GetMethodID (env, class_obj, "<init>", method_sig);
  IF_JAVA_ERR_GO (env, finish, *err_ret);
  if (method_obj == NULL)
    {
      *err_ret =
	  srv_make_new_error ("42000", "JV023",
	  "No constructor (sig : '%.100s') in class '%.100s'", method_sig, class_name);
      goto finish;
    }

  new_obj = (*env)->NewObjectA (env, class_obj, method_obj, jargs);
  IF_JAVA_ERR_GO (env, finish, *err_ret);

  ret = java_object_dv_alloc (env, new_obj);

finish:
  dk_free_box (class_name);
  dk_free_box (jargs);
  POP_FRAME (env, ret);
  if (env)
    {
      caddr_t err = java_vm_detach ();
      if (!*err_ret)
	*err_ret = err;
      else
	dk_free_tree (err);
    }
  if (*err_ret)
    {
      dk_free_tree (ret);
      ret = NULL;
    }
  END_IO_SECT (err_ret);
  if (*err_ret)
    {
      dk_free_tree (ret);
      ret = NULL;
    }
  return ret;
}


static caddr_t
bif_java_vm_attach (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t classpath = bif_string_or_null_arg (qst, args, 0, "java_vm_attach");
  JNIEnv *env;
  caddr_t *opts = NULL;
  if (BOX_ELEMENTS (args) > 1)
    opts = (caddr_t *)bif_array_or_null_arg (qst, args, 1, "java_vm_attach");

  IO_SECT(qst);
  *err_ret = java_vm_attach (&env, 1, classpath, opts);
  END_IO_SECT (err_ret);
  return NULL;
}


static caddr_t
bif_java_vm_detach (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  IO_SECT(qst);
#ifndef AUTO_DETACH
  *err_ret = java_vm_real_detach ();
#endif
  END_IO_SECT (err_ret);
  return NULL;
}

static caddr_t
bif_bit_and (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  long x1 = bif_long_arg (qst, args, 0, "bit_and");
  long x2 = bif_long_arg (qst, args, 1, "bit_and");
  return box_num (x1 & x2);
}


static caddr_t
bif_bit_or (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  long x1 = bif_long_arg (qst, args, 0, "bit_or");
  long x2 = bif_long_arg (qst, args, 1, "bit_or");
  return box_num (x1 | x2);
}

static caddr_t
bif_java_bpel_adaptor_class (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return box_dv_short_string (bpel_adaptor);
}


/* sql types interface */
static caddr_t
udt_jvm_instantiate_class_inner (caddr_t * qst, sql_class_t * udt, sql_method_t *mtd,
    state_slot_t ** args, int n_args, caddr_t *err_ret)
{
  JNIEnv *env = NULL;
  caddr_t ret = NULL;
  caddr_t class_name = escape_class_name (udt->scl_ext_name);
  int inx;
  jclass class_obj;
  jobject new_obj;
  jmethodID method_obj;
  jvalue *jargs = NULL;
  char method_sig[4096];
/*
  args = &(args[1]);
  n_args -= 1;
*/
  if (NULL != (*err_ret = java_vm_attach (&env, 1, NULL, NULL)))
    goto finish;

  PUSH_FRAME (env, 200);
  class_obj = (*env)->FindClass (env, class_name);
  IF_JAVA_ERR_GO (env, finish, *err_ret);
  if (class_obj == NULL)
    {
      *err_ret =
	  srv_make_new_error ("42000", "JV021",
	  "Class '%.100s' definition not found", class_name);
      goto finish;
    }

  strcpy (method_sig, "(");
  if (n_args)
    {
      jargs = (jvalue *) dk_alloc_box (sizeof (jvalue) * n_args, DV_LONG_STRING);
      for (inx = 0; inx < n_args; inx++)
	{
	  caddr_t value = qst_get (qst, args[inx]);
	  caddr_t sig = NULL;

	  if (mtd && mtd->scm_param_ext_types[inx])
	    {
	      sig = mtd->scm_param_ext_types[inx];
	    }
	  else if (NULL == (sig = java_dv_to_sig (DV_TYPE_OF (value))))
	    {
	      *err_ret =
		  srv_make_new_error ("42000", "JV022",
		  "Unsupported type in parameter %d of java_instantiate_class",
		  inx);
	      goto finish;
	    }

/*	  if (inx)
	    strcat (method_sig, ", ");*/
	  strcat (method_sig, sig);
	  if (NULL != (*err_ret =
		  java_dv_to_jvalue (qst, env, value, sig, &(jargs[inx]))))
	    {
	      goto finish;
	    }
	}
    }
  strcat (method_sig, ")V");

  method_obj = (*env)->GetMethodID (env, class_obj, "<init>", method_sig);
  IF_JAVA_ERR_GO (env, finish, *err_ret);
  if (method_obj == NULL)
    {
      *err_ret =
	  srv_make_new_error ("42000", "JV023",
	  "No constructor (sig : '%.100s') in class '%.100s'", method_sig, class_name);
      goto finish;
    }

  new_obj = (*env)->NewObjectA (env, class_obj, method_obj, jargs);
  IF_JAVA_ERR_GO (env, finish, *err_ret);

  ret = udt_jvm_instance_allocate (env, new_obj, udt);

finish:
  dk_free_box (class_name);
  dk_free_box (jargs);
  POP_FRAME (env, ret);
  if (env)
    {
      caddr_t err = java_vm_detach ();
      if (!*err_ret)
	*err_ret = err;
      else
	dk_free_tree (err);
    }
  if (*err_ret)
    {
      dk_free_tree (ret);
      ret = NULL;
    }
  return ret;
}

static caddr_t
udt_jvm_instantiate_class (caddr_t * qst, sql_class_t * udt, sql_method_t *mtd,
    state_slot_t ** args, int n_args)
{
  caddr_t ret = NULL;
  caddr_t err = NULL;

  if (qst)
    {
      IO_SECT (qst);
      ret = udt_jvm_instantiate_class_inner (qst, udt, mtd, args, n_args, &err);
      END_IO_SECT (&err);
    }
  else
    {
      ret = udt_jvm_instantiate_class_inner (qst, udt, mtd, args, n_args, &err);
    }

  if (err)
    {
      dk_free_tree (ret);
      sqlr_resignal (err);
    }
  ret = ret ? ret : dk_alloc_box (0, DV_DB_NULL);
  return ret;
}

static caddr_t
udt_jvm_instance_allocate (JNIEnv *env, jobject new_obj, sql_class_t *udt)
{
  caddr_t ret = dk_alloc_box_zero (sizeof (caddr_t) * 2, DV_OBJECT);

  UDT_I_CLASS (ret) = udt;
  UDT_JVM_I_OBJECT_SET (ret, new_obj);
  return ret;
}

static caddr_t
udt_jvm_instance_copy (caddr_t box)
{
  JNIEnv *env;
  caddr_t err = NULL;
  if (NULL == (err = java_vm_attach (&env, 1, NULL, NULL)))
    {
      caddr_t ret = udt_jvm_instance_allocate (env, UDT_JVM_I_OBJECT (box), UDT_I_CLASS (box));
      err = java_vm_detach ();
      return ret;
    }
  else
    {
      dk_free_tree (err);
      return dk_alloc_box (0, DV_DB_NULL);
    }
}


static void
udt_jvm_instance_free (caddr_t * box)
{
  JNIEnv *env;
  caddr_t err = NULL;
  if (NULL == (err = java_vm_attach (&env, 1, NULL, NULL)))
    {
      (*env)->DeleteGlobalRef (env, UDT_JVM_I_OBJECT ((caddr_t) box));
      err = java_vm_detach ();
    }
  else
    dk_free_tree (err);
}


static caddr_t
udt_jvm_sqt_to_jsig (sql_type_t *sqt)
{
  caddr_t ret = box_dv_short_string (java_dv_to_sig (sqt->sqt_dtp));
  if (!ret && DV_OBJECT == sqt->sqt_dtp && sqt->sqt_class
      && sqt->sqt_class->scl_ext_lang == UDT_LANG_JAVA)
    {
      char *dot;
      ret = dk_alloc_box (box_length (sqt->sqt_class->scl_ext_name) + 2, DV_SHORT_STRING);
      sprintf (ret, "L%s;", sqt->sqt_class->scl_ext_name);
      while (NULL != (dot = strchr (ret, '.')))
	{
	  *dot = '/';
	}
    }
  return ret;
}

static caddr_t
udt_jvm_internal_member_observer_inner (caddr_t *qst, sql_class_t *udt, caddr_t udi,
    caddr_t ext_name, caddr_t ext_type, sql_type_t *sqt, caddr_t *err_ret)
{
  JNIEnv *env = NULL;
  caddr_t ret = NULL;
  caddr_t class_name = udt ? escape_class_name (udt->scl_ext_name) : NULL;
  jobject instance_obj = udi ? UDT_JVM_I_OBJECT (udi) : NULL;
  caddr_t field_name = ext_name;
  caddr_t field_ret_name = NULL;
  query_instance_t *qi = (query_instance_t *)qst;
  client_connection_t *cli = qi ? qi->qi_client : GET_IMMEDIATE_CLIENT_OR_NULL;

  jclass class_obj;
  jfieldID field_obj;
  jvalue jret;

  if (ext_type)
    field_ret_name = box_dv_short_string (ext_type);
  else
    field_ret_name = udt_jvm_sqt_to_jsig (sqt);
  if (!field_ret_name)
    {
      *err_ret = srv_make_new_error ("22023", "JVXXX", "Unsupported field type");
      goto finish;
    }

  if (NULL != (*err_ret = java_vm_attach (&env, 1, NULL, NULL)))
    goto finish;

  PUSH_FRAME (env, 200);

  class_obj = (*env)->FindClass (env, class_name);
  IF_JAVA_ERR_GO (env, finish, *err_ret);
  if (class_obj == NULL)
    {
      *err_ret =
	  srv_make_new_error ("42000", "JV015",
	      "Class '%.100s' definition not found", class_name);
      goto finish;
    }

  if (instance_obj && JNI_TRUE != (*env)->IsInstanceOf (env, instance_obj, class_obj))
    {
      *err_ret = srv_make_new_error ("42000", "JV016",
	  "The object supplied is not an instance of %.100s", class_name);
      goto finish;
    }


  if (!instance_obj)
    field_obj =
	(*env)->GetStaticFieldID (env, class_obj, field_name, field_ret_name);
  else
    field_obj =
	(*env)->GetFieldID (env, class_obj, field_name, field_ret_name);
  IF_JAVA_ERR_GO (env, finish, *err_ret);
  if (field_obj == NULL)
    {
      *err_ret =
	  srv_make_new_error ("42000", "JV017",
	  "No field '%.100s' (sig : '%.100s') in class '%.100s'", field_name, field_ret_name, class_name);
      goto finish;
    }

  java_get_field (env, field_ret_name, instance_obj, class_obj,
      field_obj, &jret);
  ret = java_jvalue_to_dv (env, field_ret_name, &jret, err_ret, 1, sqt->sqt_class, cli);
  if (*err_ret)
    goto finish;
  IF_JAVA_ERR_GO (env, finish, *err_ret);

finish:
  dk_free_box (class_name);
  dk_free_box (field_ret_name);
  POP_FRAME (env, ret);
  if (env)
    {
      caddr_t err = java_vm_detach ();
      if (!*err_ret)
	*err_ret = err;
      else
	dk_free_tree (err);
    }
  if (*err_ret)
    {
      dk_free_tree (ret);
      ret = NULL;
    }
  return ret;
}

static caddr_t
udt_jvm_internal_member_observer (caddr_t *qst, sql_class_t *udt, caddr_t udi,
    caddr_t ext_name, caddr_t ext_type, sql_type_t *sqt)
{
  caddr_t err = NULL;
  caddr_t ret = NULL;
  if (qst)
    {
      IO_SECT(qst);
      ret = udt_jvm_internal_member_observer_inner (qst, udt, udi, ext_name, ext_type, sqt, &err);
      END_IO_SECT (&err);
    }
  else
    {
      ret = udt_jvm_internal_member_observer_inner (qst, udt, udi, ext_name, ext_type, sqt, &err);
    }
  if (err)
    {
      dk_free_tree (ret);
      sqlr_resignal (err);
    }
  return ret;
}

static caddr_t
udt_jvm_member_observer (caddr_t *qst, caddr_t udi, sql_field_t *fld, int member_inx)
{
  return udt_jvm_internal_member_observer (qst, UDT_I_CLASS (udi), udi,
      fld->sfl_ext_name ? fld->sfl_ext_name : fld->sfl_name, fld->sfl_ext_type, & (fld->sfl_sqt));
}


static caddr_t
udt_jvm_member_mutator_inner (caddr_t *qst, caddr_t udi, sql_field_t *fld, int member_inx, caddr_t new_val, caddr_t *err_ret)
{
  JNIEnv *env = NULL;
  caddr_t ret = udi;
  sql_class_t *udt;
  caddr_t class_name;
  jobject instance_obj;
  caddr_t field_name;
  caddr_t field_ret_name = NULL;
  caddr_t field_value = new_val;

  jclass class_obj;
  jfieldID field_obj;
  jvalue jv;


  udt = UDT_I_CLASS (udi);

  class_name = escape_class_name (udt->scl_ext_name);
  instance_obj = UDT_JVM_I_OBJECT (udi);
  field_name = fld->sfl_ext_name ? fld->sfl_ext_name : fld->sfl_name;

  if (fld->sfl_ext_type)
    field_ret_name = box_dv_short_string (fld->sfl_ext_type);
  else
    field_ret_name = udt_jvm_sqt_to_jsig (& (fld->sfl_sqt));
  if (!field_ret_name)
    {
      *err_ret = srv_make_new_error ("22023", "JVXXX", "Unsupported field type");
      goto finish;
    }

  if (NULL != (*err_ret = java_vm_attach (&env, 1, NULL, NULL)))
    goto finish;

  PUSH_FRAME (env, 200);
  class_obj = (*env)->FindClass (env, class_name);
  IF_JAVA_ERR_GO (env, finish, *err_ret);
  if (class_obj == NULL)
    {
      *err_ret =
	  srv_make_new_error ("42000", "JV018",
	  "Class '%.100s' definition not found", class_name);
      goto finish;
    }

  if (instance_obj && JNI_TRUE != (*env)->IsInstanceOf (env, instance_obj, class_obj))
    {
      *err_ret = srv_make_new_error ("42000", "JV019",
	  "The object supplied is not an instance of %.100s", class_name);
      goto finish;
    }

  if (!instance_obj)
    field_obj =
	(*env)->GetStaticFieldID (env, class_obj, field_name, field_ret_name);
  else
    field_obj =
	(*env)->GetFieldID (env, class_obj, field_name, field_ret_name);
  IF_JAVA_ERR_GO (env, finish, *err_ret);
  if (field_obj == NULL)
    {
      *err_ret =
	  srv_make_new_error ("42000", "JV020",
	  "No field '%.100s' (sig : '%.100s') in class '%.100s'", field_name, field_ret_name, class_name);
      goto finish;
    }

  if (NULL != (*err_ret =
	  java_dv_to_jvalue (qst, env, field_value, field_ret_name, &jv)))
    goto finish;

  if (NULL != (*err_ret = java_set_field (env, field_ret_name, instance_obj,
	      class_obj, field_obj, &jv)))
    goto finish;
  IF_JAVA_ERR_GO (env, finish, *err_ret);

finish:
  dk_free_box (class_name);
  POP_FRAME (env, NULL);
  if (env)
    {
      caddr_t err = java_vm_detach ();
      if (!*err_ret)
	*err_ret = err;
      else
	dk_free_tree (err);
    }
  if (*err_ret)
    {
      dk_free_tree (ret);
      ret = NULL;
    }
  return ret;
}

static caddr_t
udt_jvm_member_mutator (caddr_t *qst, caddr_t udi, sql_field_t *fld, int member_inx, caddr_t new_val)
{
  caddr_t err = NULL, ret = NULL;

  if (qst)
    {
      IO_SECT(qst);
      ret = udt_jvm_member_mutator_inner (qst, udi, fld, member_inx, new_val, &err);
      END_IO_SECT (&err);
    }
  else
    {
      ret = udt_jvm_member_mutator_inner (qst, udi, fld, member_inx, new_val, &err);
    }

  if (err)
    {
      dk_free_tree (ret);
      sqlr_resignal (err);
    }
  return ret;
}

static caddr_t
udt_jvm_method_call (caddr_t *qst, sql_class_t *udt, caddr_t udi,
    sql_method_t *mtd, state_slot_t **args, int n_args)
{
  JNIEnv *env = NULL;
  caddr_t ret = NULL;
  caddr_t class_name = udt->scl_ext_name;
  jobject instance_obj = udi ? UDT_JVM_I_OBJECT (udi) : NULL;
  caddr_t method_name = mtd->scm_ext_name ? mtd->scm_ext_name : mtd->scm_name;
  caddr_t method_ret_name = NULL;
  int inx;
  caddr_t err = NULL, *err_ret = &err;
  caddr_t sig2 = NULL;
  query_instance_t *qi = (query_instance_t *)qst;
  client_connection_t *cli = qi ? qi->qi_client : GET_IMMEDIATE_CLIENT_OR_NULL;

  jclass class_obj;
  jmethodID method_obj;
  jvalue *jargs = NULL, jret;
  char method_sig[4096];

  IO_SECT(qst);

  jvm_activate_access_granter (udt->scl_sec_unrestricted);

/*  fprintf (stderr, "udt_jvm_method_call (udt:%s, udi:%s, mtd:%s begin i:%p", udt->scl_name,
      udi ? UDT_I_CLASS (udi)->scl_name : "<NULL>", mtd->scm_name, instance_obj);*/
  if (mtd->scm_type == UDT_METHOD_STATIC && method_name[0] == 0 && strlen (method_name + 1) > 0)
    {
      ret = udt_jvm_internal_member_observer (qst, udt, NULL, method_name + 1,
	  mtd->scm_ext_type, & (mtd->scm_signature[0]));
      goto endcall;
    }
  class_name = escape_class_name (udt->scl_ext_name);
  if (mtd->scm_type != UDT_METHOD_STATIC)
    {
      args = &(args[1]);
      n_args -= 1;
    }
  if (mtd->scm_ext_type)
    method_ret_name = box_dv_short_string (mtd->scm_ext_type);
  else
    method_ret_name = udt_jvm_sqt_to_jsig (& (mtd->scm_signature[0]));
  if (!method_ret_name)
    {
      *err_ret = srv_make_new_error ("22023", "JVXXX", "Unsupported method return type");
      goto finish;
    }

  if (NULL != (*err_ret = java_vm_attach (&env, 1, NULL, NULL)))
    goto finish;

  PUSH_FRAME (env, 200);
  class_obj = (*env)->FindClass (env, class_name);
  IF_JAVA_ERR_GO (env, finish, *err_ret);
  if (class_obj == NULL)
    {
      *err_ret =
	  srv_make_new_error ("42000", "JV011",
	  "Class '%.100s' definition not found", class_name);
      goto finish;
    }

  if (instance_obj && JNI_TRUE != (*env)->IsInstanceOf (env, instance_obj, class_obj))
    {
      *err_ret = srv_make_new_error ("42000", "JV012",
	  "The object supplied is not an instance of %.100s", class_name);
      goto finish;
    }

  strcpy (method_sig, "(");
  if (n_args)
    {
      jargs =
	  (jvalue *) dk_alloc_box (sizeof (jvalue) * n_args, DV_LONG_STRING);
      for (inx = 0; inx < n_args; inx++)
	{
	  caddr_t value = qst_get (qst, args[inx]);
	  caddr_t sig = NULL;
	  if (mtd->scm_param_ext_types[inx])
	    {
	      sig = mtd->scm_param_ext_types[inx];
	    }
	  if (!sig && mtd->scm_signature[inx + 1].sqt_class &&
	      mtd->scm_signature[inx + 1].sqt_class->scl_ext_lang == UDT_LANG_JAVA &&
	      mtd->scm_signature[inx + 1].sqt_class->scl_ext_name)
	    {
	      char *ptr;
	      sig2 = sig = dk_alloc_box (box_length (
		    mtd->scm_signature[inx + 1].sqt_class->scl_ext_name) + 2, DV_SHORT_STRING);
	      sprintf (sig, "L%s;",
		  mtd->scm_signature[inx + 1].sqt_class->scl_ext_name);
	      while (NULL != (ptr = strchr (sig, '.')))
		*ptr = '/';
	    }
	  if (!sig)
	    sig = java_dv_to_sig (mtd->scm_signature[inx + 1].sqt_dtp);
	  if (!sig)
	    sig = java_dv_to_sig (DV_TYPE_OF (value));
	  if (!sig)
	    {
	      *err_ret =
		  srv_make_new_error ("42000", "JV013",
		  "Unsupported type in parameter %d of java_call_method",
		  inx);
	      goto finish;
	    }

/*	  if (inx)
	    strcat (method_sig, ", "); */
	  strcat (method_sig, sig);
	  dk_free_box (sig2);
	  sig2 = NULL;
	  if (NULL != (*err_ret = java_dv_to_jvalue (qst, env, value, sig,
		      &(jargs[inx]))))
	    {
	      goto finish;
	    }
	}
    }
  strcat (method_sig, ")");
  strcat (method_sig, method_ret_name);

  if (!instance_obj)
    method_obj =
	(*env)->GetStaticMethodID (env, class_obj, method_name, method_sig);
  else
    method_obj =
	(*env)->GetMethodID (env, class_obj, method_name, method_sig);
  IF_JAVA_ERR_GO (env, finish, *err_ret);
  if (method_obj == NULL)
    {
      *err_ret =
	  srv_make_new_error ("42000", "JV014",
	  "No method '%.100s' (sig : '%.100s') in class '%.100s'", method_name, method_sig, class_name);
      goto finish;
    }

  jret = java_method_call (env, method_ret_name, instance_obj, class_obj,
      method_obj, jargs);
  IF_JAVA_ERR_GO (env, finish, *err_ret);
  if (n_args)
    {
      for (inx = 0; inx < n_args; inx++)
	{
	  if (ssl_is_settable (args[inx]))
	    {
	      char *sig = NULL;
	      if (!sig && mtd->scm_param_ext_types[inx])
		sig = mtd->scm_param_ext_types[inx];
	      if (!sig && mtd->scm_signature[inx + 1].sqt_class &&
		  mtd->scm_signature[inx + 1].sqt_class->scl_ext_lang == UDT_LANG_JAVA &&
		  mtd->scm_signature[inx + 1].sqt_class->scl_ext_name)
		{
		  char *ptr;
		  sig2 = sig = dk_alloc_box (box_length (
			mtd->scm_signature[inx + 1].sqt_class->scl_ext_name) + 2, DV_SHORT_STRING);
		  sprintf (sig, "L%s;",
		      mtd->scm_signature[inx + 1].sqt_class->scl_ext_name);
		  while (NULL != (ptr = strchr (sig, '.')))
		    *ptr = '/';
		}
	      if (!sig)
		sig = java_dv_to_sig (DV_TYPE_OF (qst_get (qst, args[inx])));
	      if (sig && strlen (sig) > 0 && (sig[0] == '[' || sig[0] == 'L'))
		{
		  caddr_t retp = java_jvalue_to_dv (env, sig, &(jargs[inx]), err_ret, 1,
		      args[inx]->ssl_sqt.sqt_class, cli);
		  dk_free_box (sig2);
		  sig2 = NULL;
		  if (*err_ret)
		    goto finish;
		  qst_set (qst, args[inx], retp);
		}
	    }
	}
    }
  ret = java_jvalue_to_dv (env, method_ret_name, &jret, err_ret, 1, mtd->scm_signature[0].sqt_class, cli);
  if (*err_ret)
    goto finish;
  IF_JAVA_ERR_GO (env, finish, *err_ret);
finish:
  jvm_activate_access_granter (1);
  dk_free_box (sig2);
  dk_free_box (jargs);
  dk_free_box (class_name);
  dk_free_box (method_ret_name);
  POP_FRAME (env, ret);
  if (env)
    {
      caddr_t err = java_vm_detach ();
      if (!*err_ret)
	*err_ret = err;
      else
	{
	  dk_free_tree (err);
	}
      err = NULL;
    }
  if (*err_ret)
    {
      dk_free_tree (ret);
      ret = NULL;
    }
endcall:
  END_IO_SECT (err_ret);
  if (err)
    {
      dk_free_tree (ret);
      sqlr_resignal (err);
    }
  return ret;
}



static int
udt_jvm_serialize (caddr_t udi, dk_session_t * session)
{
  jobject obj = UDT_JVM_I_OBJECT (udi);
  JNIEnv *env = NULL;
  caddr_t err = NULL;
  jobject byte_array_output = 0;
  jvalue jargs[1], jret;
  int length, write_ofs;
  unsigned char bytes[PAGE_DATA_SZ];

  if (NULL != (err = java_vm_attach (&env, 1, NULL, NULL)))
    {
      err = (caddr_t) 1;
      goto finish;
    }

  PUSH_FRAME(env, 200);


  byte_array_output = (*env)->NewObjectA (env, virt_helper_class, virt_helper_init, jargs);
  IF_JAVA_ERR_GO (env, finish, err);
  if (!byte_array_output)
    {
      err = (caddr_t)1;
      goto finish;
    }
  jargs[0].l = obj;
  jret.l = (*env)->CallObjectMethodA (env, byte_array_output, virt_helper_serialize, jargs);
  IF_JAVA_ERR_GO (env, finish, err);
  if (!jret.l)
    {
      err = (caddr_t)1;
      goto finish;
    }
  length = (*env)->GetArrayLength (env, jret.l);
  IF_JAVA_ERR_GO (env, finish, err);

  if (length < 256)
    {
      session_buffered_write_char (DV_BIN, session);
      session_buffered_write_char ((char) length, session);
    }
  else
    {
      session_buffered_write_char (DV_LONG_BIN, session);
      print_long ((long) length, session);
    }

  for (write_ofs = 0; write_ofs < length; )
    {
      int read_len = (length - write_ofs) > sizeof (bytes) ? sizeof (bytes) : length - write_ofs;
      (*env)->GetByteArrayRegion (env, jret.l, write_ofs, read_len, bytes);
      session_buffered_write (session, bytes, read_len);
      write_ofs += read_len;
    }

finish:
  POP_FRAME (env, NULL);
  if (env)
    {
      caddr_t err1 = java_vm_detach ();
      if (!err)
	err = err1;
      else
	dk_free_tree (err1);
    }
  if (err)
    {
      session_buffered_write_char (DV_DB_NULL, session);
      if (ARRAYP (err))
	log_error ("JAVA Serialization error : [%s] [%s]", ERR_STATE(err), ERR_MESSAGE (err));
      else
	log_error ("JAVA Serialization error : unknown");
      dk_free_tree (err);
      err = NULL;
    }
  return 0;
}

static void *
udt_jvm_deserialize (dk_session_t * session, dtp_t dtp, sql_class_t *udt)
{
  jclass obj_class = NULL;
  JNIEnv *env = NULL;
  caddr_t err = NULL;
  caddr_t ret;
  caddr_t class_name = udt ? escape_class_name (udt->scl_ext_name) : NULL;
  jvalue jargs[1];
  jobject byte_array_input;

  ret = scan_session_boxing (session);
  if (DV_TYPE_OF (ret) != DV_BIN)
    goto finish;

  if (NULL != (err = java_vm_attach (&env, 1, NULL, NULL)))
    goto finish;

  PUSH_FRAME(env, 200);
  if (class_name)
    {
      GET_CLASS_ID (env, obj_class, class_name, finish, err);
    }

  jargs[0].l = (*env)->NewByteArray (env, box_length (ret));
  (*env)->SetByteArrayRegion (env, jargs[0].l, 0, box_length (ret), ret);

  byte_array_input = (*env)->NewObjectA (env, virt_helper_class, virt_helper_init, jargs);
  IF_JAVA_ERR_GO (env, finish, err);
  if (!byte_array_input)
    {
      err = (caddr_t)1;
      goto finish;
    }

  jargs[0].l = (*env)->CallObjectMethodA (env, byte_array_input, virt_helper_deserialize, jargs);

  IF_JAVA_ERR_GO (env, finish, err);
  if (!jargs[0].l)
    {
      err = (caddr_t)1;
      goto finish;
    }

  if (udt && JNI_TRUE != (*env)->IsInstanceOf (env, jargs[0].l, obj_class))
    {
      jclass ret_obj_cls = (*env)->GetObjectClass (env, jargs[0].l);
      caddr_t val;

      jargs[0].l = (*env)->CallObjectMethod (env, ret_obj_cls, Class_getName_id, NULL);
      val = java_jvalue_to_dv (env, "Ljava/lang/String;", &(jargs[0]), &err, 0, NULL, NULL);
      dk_free_box (val);
      goto finish;
    }

  dk_free_box (ret);
  if (!udt)
    {
      udt = udt_find_class_for_java_instance (env, jargs[0].l, NULL, NULL);
      if (!udt)
	udt = java_unk_object;
    }
  ret = udt_jvm_instance_allocate (env, jargs[0].l, udt);

finish:
  dk_free_box (class_name);
  POP_FRAME (env, NULL);
  if (env)
    err = java_vm_detach ();
  if (err)
    {
      session_buffered_write_char (DV_DB_NULL, session);
      if (ARRAYP (err))
	log_error ("JAVA deserialization error : [%s] [%s]", ERR_STATE(err), ERR_MESSAGE (err));
      else
	log_error ("JAVA deserialization error : unknown");
      dk_free_tree (err);
      err = NULL;
    }
  return ret;
}

/* END: sql types interface */
void ddl_type_changed (query_instance_t * qi, char *full_type_name, sql_class_t *udt, caddr_t tree);
static void (*old_ddl_hook) (client_connection_t *cli) = NULL;

static void get_java_ids ()
{
}

extern void sqls_define_javavm (client_connection_t *cli);
extern void sqls_define_xslt (client_connection_t *cli);
static void
javavm_ddl_hook (client_connection_t *cli)
{
  if (old_ddl_hook)
    old_ddl_hook (cli);

  get_java_ids ();
  java_unk_object = udt_alloc_class_def ("DB.DBA.UNKNOWN_JAVA_HOSTED_OBJECT");
  java_unk_object->scl_ext_lang = UDT_LANG_JAVA;
  sqls_define_javavm (cli);
  if (!old_ddl_hook)
    sqls_define_xslt (cli);
}

#if defined (JNI_VERSION_1_6)
#define JAVAVM_VERSION "1.6"
#elif defined (JDK1_5)
#define JAVAVM_VERSION "1.5"
#elif defined (JDK1_4)
#define JAVAVM_VERSION "1.4"
#elif defined (JDK1_3)
#define JAVAVM_VERSION "1.3"
#elif defined (JDK1_2)
#define JAVAVM_VERSION "1.2"
#elif defined (JDK1_1)
#define JAVAVM_VERSION "1.1"
#else
#define JAVAVM_VERSION "<unknown version>"
#endif

char *
javavm_version_string ()
{
  return JAVAVM_VERSION;
}

void
bif_init_func_javavm (void)
{
  caddr_t sand_box_opt = NULL;
  sql_class_imp_t *imp_map = get_imp_map_ptr (UDT_LANG_JAVA);
  log_info ("Hosting Java VM %s", JAVAVM_VERSION);
  java_vm_mutex = mutex_allocate ();
  dk_mem_hooks (DV_EXTENSION_OBJ, dv_extension_obj_copy, java_object_dv_free, 0);

  bif_define ("java_load_class", bif_java_load_class);
  bif_define ("java_new_object", bif_java_new_object);
  bif_define ("java_call_method", bif_java_call_method);
  bif_define ("java_get_property", bif_java_get_property);
  bif_define ("java_set_property", bif_java_set_property);
  bif_define ("java_vm_attach", bif_java_vm_attach);
  bif_define ("java_vm_detach", bif_java_vm_detach);

#if 0
  bif_define_typed ("bit_and", bif_bit_and, &bt_integer);
  bif_define_typed ("bit_or", bif_bit_or, &bt_integer);
#endif

  bif_define ("java_bpel_adaptor_class", bif_java_bpel_adaptor_class);

  imp_map->scli_instantiate_class = udt_jvm_instantiate_class;
  imp_map->scli_instance_copy = udt_jvm_instance_copy;
  imp_map->scli_instance_free = udt_jvm_instance_free;
  imp_map->scli_member_observer = udt_jvm_member_observer;
  imp_map->scli_member_mutator = udt_jvm_member_mutator;
  imp_map->scli_method_call = udt_jvm_method_call;
  imp_map->scli_serialize = udt_jvm_serialize;
  imp_map->scli_deserialize = udt_jvm_deserialize;

  old_ddl_hook = set_ddl_init_hook (javavm_ddl_hook);

  if (virtuoso_cfg_getstring ("Parameters", "JavaSandBox", &sand_box_opt) == -1)
    sand_box = 1;
  else if (!strcmp (sand_box_opt, "0"))
    sand_box = 0;

  if (sand_box)
    {
      set_virt_class_loader_r_to_jvm ();
      set_virt_access_granter_to_jvm ();
      set_virt_class_loader_ur_to_jvm ();
      set_help_class_to_jvm ();
      jvm_set_access_granter ();
    }
  set_bpel_classes_to_jvm ();
#ifndef WIN32
  setlocale (LC_ALL, "C");
#endif
}

#ifndef ONLY_JAVAVM
int
main (int argc, char *argv[])
{
  static char brand_buffer[200];
#ifdef MALLOC_DEBUG
  dbg_malloc_enable ();
#endif
  sprintf (brand_buffer, "Java VM %s", javavm_version_string ());
  build_set_special_server_model (brand_buffer);
  VirtuosoServerSetInitHook (bif_init_func_javavm);
  return VirtuosoServerMain (argc, argv);
}
#endif

