/*
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2015 OpenLink Software
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
#include <stdlib.h>
#include <string.h>

#include <jni.h>
#include <ksrvext.h>

static JavaVM *java_vm = NULL;
static dk_mutex_t *java_vm_mutex = NULL;

static caddr_t
java_vm_create (JNIEnv ** java_vm_env)
{
  JavaVMInitArgs vm_args;
  JavaVMOption options[5];
  jint res;
  caddr_t classpath_opt = NULL;
  int inx;
  char *classpath = NULL;

  if (!classpath)
    {
      classpath=getenv ("CLASSPATH");
    }
  if (!classpath)
    {
      classpath= ".";
    }

  classpath_opt = dk_alloc_box (strlen (classpath) + 20, DV_SHORT_STRING);
  sprintf (classpath_opt, "-Djava.class.path=%s", classpath);
  options[0].optionString = classpath_opt;
  vm_args.nOptions = 1;
  vm_args.version = JNI_VERSION_1_2;
  vm_args.options = options;
  vm_args.ignoreUnrecognized = JNI_FALSE;

  res = JNI_CreateJavaVM (&java_vm, (void **) java_vm_env, &vm_args);
  if (res < 0)
    return srv_make_new_error ("42000", "JV002", "Can't create the Java VM");
  else
    return NULL;
}


static caddr_t
java_vm_attach (JNIEnv ** env)
{
  caddr_t err = NULL;

  mutex_enter (java_vm_mutex);
  *env = NULL;
  if (!java_vm)
    {
      err = java_vm_create (env);
      if (err)
	{
	  mutex_leave (java_vm_mutex);
	  return err;
	}
    }
  else
    {
      if (JNI_OK != (*java_vm)->GetEnv (java_vm, (void **) env, JNI_VERSION_1_2))
	{
	  if (0 > (*java_vm)->AttachCurrentThread (java_vm, (void **) env,
		  NULL))
	    {
	      err =
		  srv_make_new_error ("42000", "JV003",
		  "Can't attach to the java VM");
	      mutex_leave (java_vm_mutex);
	      return err;
	    }
	}
    }
  mutex_leave (java_vm_mutex);
  return err;
}

static caddr_t
java_vm_detach (void)
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
      log_debug ("Thread %p detached from the Java VM", thread_current());
      return NULL;
    }
}


static caddr_t
bif_do_something_bif (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  JNIEnv *env = NULL;
  jclass class_obj;
  jmethodID work_method_obj, cleanup_method_obj;
  jint ret;
  jvalue jargs[1];
  query_instance_t *qi = (query_instance_t *)qst;

  if (NULL != (*err_ret = java_vm_attach (&env)))
    goto finish;
  class_obj = (*env)->FindClass (env, "handler_class");

  work_method_obj =
    (*env)->GetStaticMethodID (env, class_obj, "do_bit_of_work", "()I");

  cleanup_method_obj =
    (*env)->GetStaticMethodID (env, class_obj, "cleanup_the_staff", "()V");

  while (0 < (ret = (*env)->CallStaticIntMethodA (env, class_obj, work_method_obj, jargs)))
    {
      if (qi_have_trx_error (qi))
	{
	  (*env)->CallStaticVoidMethodA (env, class_obj, cleanup_method_obj, jargs);
	  goto finish;
	}
    }
finish:
  if (env)
    {
      caddr_t err = java_vm_detach ();
      if (!*err_ret)
	*err_ret = err;
      else
	dk_free_tree (err);
    }
  qi_check_trx_error (qi, 1);
  return NULL;
}

void
bif_init_func_javavm (void)
{
  java_vm_mutex = mutex_allocate ();
  bif_define ("do_something_bif", bif_do_something_bif);
}

int
main (int argc, char *argv[])
{
  VirtuosoServerSetInitHook (bif_init_func_javavm);
  return VirtuosoServerMain (argc, argv);
}
