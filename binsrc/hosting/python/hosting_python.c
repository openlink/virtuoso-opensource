/*
 *  hosting_python.c
 *
 *  $Id$
 *
 *  Virtuoso Python hosting plugin
 *  
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *  
 *  Copyright (C) 1998-2006 OpenLink Software
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
 *  
*/

#include <stdio.h>
#include <stdarg.h>
#ifdef _POSIX_C_SOURCE
#undef _POSIX_C_SOURCE
#endif
#ifdef _XOPEN_SOURCE
#undef _XOPEN_SOURCE
#endif
#if defined (_DEBUG) && defined (WIN32)
/* ActiveState Python has some weird "feature"
 * that will automatically include refs to
 * wrong lib if that _DEBUG is defined
 */
#undef _DEBUG
#endif
#include <Python.h>
#if (PY_MAJOR_VERSION > 2) || (PY_MAJOR_VERSION == 2 && PY_MINOR_VERSION > 2)
#undef PACKAGE_NAME
#undef PACKAGE_STRING
#undef PACKAGE_TARNAME
#undef PACKAGE_VERSION
#endif
#include <hosting.h>
#include <sqlver.h>

#ifndef WITH_THREAD
#error Python should be compiled to use threads. Check that WITH_THREAD is defined
#endif

#define SET_ERR(str) \
      { \
	if (err && max_len > 0) \
	  { \
	    strncpy (err, str, max_len); \
	    err[max_len] = 0; \
	  } \
      }

static int
log_debug (char *format, ...)
{
  va_list ap;
  int rc;

  va_start (ap, format);
  fprintf (stderr, "HOSTING_PYTHON:");
  rc = vfprintf (stderr, format, ap);
  fprintf (stderr, "\n");
  va_end (ap);
  return rc;
}


#define VIRT_HANDLER_NAME "__virt_handler"

#include "virt_handler.c"

static void
define_virtuoso_module (PyInterpreterState *interp)
{
  PyObject *modules = interp->modules;
  PyObject *builtin_module;
  PyObject *code_obj;

  builtin_module = PyDict_GetItemString(modules, "__builtin__");

  code_obj = PyObject_CallMethod (builtin_module, "compile", "sss", virt_handler, "<string>", "exec");

  PyImport_ExecCodeModule (VIRT_HANDLER_NAME, code_obj);
  Py_DECREF (code_obj);
}


static PyInterpreterState *
start_python_interpreter (char *err, int max_len)
{
  PyInterpreterState *interp = NULL;
  PyThreadState *tstate;
  /*log_debug ("start_python_interpreter");*/

  PyEval_AcquireLock();
  tstate = Py_NewInterpreter ();
  define_virtuoso_module (tstate->interp);

  if (!tstate)
    {
      SET_ERR ("Unable to start the Python interpretter");
    }
  else
    interp = tstate->interp;
  PyThreadState_Clear (tstate);
  PyEval_ReleaseThread(tstate);
  PyThreadState_Delete (tstate);
  return interp;
}


static PyThreadState *
init_python_thread (PyInterpreterState *istate, char *err, int max_len)
{
  PyThreadState * tstate = PyThreadState_New(istate);

  if (!tstate)
    {
      SET_ERR ("Unbale to make a thread state");
      return NULL;
    }
  PyEval_AcquireThread(tstate);

  return tstate;
}


static void
done_python_thread (void)
{
  PyThreadState *tstate = PyThreadState_Get();

  PyThreadState_Clear (tstate);
  PyEval_ReleaseThread(tstate);
  PyThreadState_Delete (tstate);
}


static void
stop_python_interpreter (PyInterpreterState *interp)
{
  PyThreadState * tstate;
  if (NULL != (tstate = init_python_thread (interp, NULL, 0)))
    {
      Py_EndInterpreter (tstate);
      PyEval_ReleaseLock ();
    }
}


static void
hosting_python_connect (void *x)
{
  /*log_debug ("hosting_python_connect");*/
}

static hosting_version_t
hosting_python_version = {
    {
      HOSTING_TITLE,			/*!< Title of unit, filled by unit */
      DBMS_SRV_GEN_MAJOR DBMS_SRV_GEN_MINOR,/*!< Version number, filled by unit */
      "OpenLink Software",			/*!< Plugin's developer, filled by unit */
      "Python hosting plugin",			/*!< Any additional info, filled by unit */
      NULL,					/*!< Error message, filled by unit loader */
      NULL,					/*!< Name of file with unit's code, filled by unit loader */
      hosting_python_connect,		/*!< Pointer to connection function, cannot be NULL */
      NULL,					/*!< Pointer to disconnection function, or NULL */
      NULL,					/*!< Pointer to activation function, or NULL */
      NULL,					/*!< Pointer to deactivation function, or NULL */
      NULL
    },
    NULL, NULL, NULL, NULL, NULL,
    NULL
};


void *
virtm_client_attach (char *err, int max_err_len)
{
  PyInterpreterState *interp = start_python_interpreter (err, max_err_len);
  /*log_debug ("virtm_client_attach");*/
  return interp;
}


unit_version_t*
hosting_python_check (unit_version_t *in, void *appdata)
{
  static char *args[2];
  void *dll;

  args[0] = "py";
  args[1] = NULL;
  hosting_python_version.hv_extensions = args;

  Py_Initialize ();
  PyEval_InitThreads();
  PyEval_SaveThread();
  /*log_debug ("hosting_python_check");*/
  return &hosting_python_version.hv_pversion;
}


void
virtm_client_detach (void *cli)
{
  PyInterpreterState *interp = (PyInterpreterState *) cli;
  /*log_debug ("virtm_client_detach");*/
  if (interp)
    {
      stop_python_interpreter (interp);
    }
}


void *
virtm_client_clone (void *cli, char *err, int max_err_len)
{
  return NULL;
}


void
virtm_client_free (void *cli)
{
  free (cli);
}


static PyObject *
virtm_make_python_dict (const char **options, int n_options)
{
  PyObject *dict = PyDict_New ();
  int inx;

  if (options)
    {
      for (inx = 0; inx < n_options; inx += 2)
	PyDict_SetItemString (dict, (char *) options [inx], PyString_FromString (options [inx + 1]));
    }

  return dict;
}


char *
virtm_http_handler (void *cli, char *err, int max_len,
      const char *base_uri, const char *content,
      const char *params, const char **lines, int n_lines,
      char **head_ret, const char **options, int n_options, char **diag_ret, int compile_only)
{
  PyInterpreterState *interp = (PyInterpreterState *) cli;
  char *retval = NULL;
  PyObject *virt_handler_module, *py_retval = NULL;
  /*log_debug ("virtm_http_handler");*/

  if (diag_ret)
    *diag_ret = NULL;

  if (compile_only)
    return NULL;

  if (!interp)
    {
      SET_ERR ("client not attached to the interface");
      return NULL;
    }

  if (!init_python_thread (interp, err, max_len))
    return NULL;

  /* get the virt handler module */
  virt_handler_module = PyDict_GetItemString (interp->modules, VIRT_HANDLER_NAME);
  if (virt_handler_module)
    {
      if (content)
	{
	  PyObject *obj[6];
	  int inx;

	  py_retval = PyObject_CallMethodObjArgs (virt_handler_module,
	      obj[0] = PyString_FromString ("call_string"),
	      obj[1] = PyString_FromString (base_uri),
	      obj[2] = PyString_FromString (content),
	      obj[3] = virtm_make_python_dict (options, n_options),
	      obj[4] = PyString_FromString (params),
	      obj[5] = PyString_FromString (""),
	      NULL);
	  for (inx = 0; inx < (sizeof (obj) / sizeof (PyObject *)); inx++)
	    {
	      Py_XDECREF (obj[inx]);
	    }
	}
      else
	{
	  PyObject *obj[5];
	  int inx;
	  memset (obj, 0, sizeof (obj));

	  py_retval = PyObject_CallMethodObjArgs (virt_handler_module,
	      obj[0] = PyString_FromString ("call_file"),
	      obj[1] = PyString_FromString (base_uri),
	      obj[2] = virtm_make_python_dict (options, n_options),
	      params ? (obj[3] = PyString_FromString (params)) : Py_None,
	      obj[4] = PyString_FromString (""),
	      NULL);
	  for (inx = 0; inx < (sizeof (obj) / sizeof (PyObject *)); inx++)
	    {
	      Py_XDECREF (obj[inx]);
	    }
	}
    }
  else
    {
      SET_ERR ("No __virt_handler module defined");
    }

  if (py_retval && PyTuple_Check (py_retval) && PyTuple_Size (py_retval) >= 3)
    {
      PyObject *item;
      char *sitem;
      int size;

      item = PyTuple_GetItem (py_retval, 2);
      if (item && diag_ret && PyString_Check (item) && 0 == PyString_AsStringAndSize (item, &sitem, &size))
	{
	  if (size && sitem)
	    {
	      /*log_debug ("ret[2]=diag_ret=[%s]\n", sitem);*/
	      *diag_ret = malloc (size + 1);
	      strncpy (*diag_ret, sitem, size);
	      (*diag_ret)[size] = 0;
	    }
	  else
	    *diag_ret = NULL;
	}

      item = PyTuple_GetItem (py_retval, 1);
      if (item && head_ret && PyString_Check (item) && 0 == PyString_AsStringAndSize (item, &sitem, &size))
	{
	  if (size && sitem)
	    {
	      /*log_debug ("ret[1]=head_ret=[%s]\n", sitem);*/
	      *head_ret = malloc (size + 1);
	      strncpy (*head_ret, sitem, size);
	      (*head_ret)[size] = 0;
	    }
	  else
	    *head_ret = NULL;
	}

      item = PyTuple_GetItem (py_retval, 0);
      if (item && PyString_Check (item) && 0 == PyString_AsStringAndSize (item, &sitem, &size))
	{
	  if (size && sitem)
	    {
	      /*log_debug ("ret[0]=retval=[%s]\n", sitem);*/
	      retval = malloc (size + 1);
	      strncpy (retval, sitem, size);
	      retval[size] = 0;
	    }
	}
      if (PyTuple_Size (py_retval) > 3)
	{
	  char buffer[512];
	  strcpy (buffer, "python runtime exception ");

	  item = PyTuple_GetItem (py_retval, 3);
	  if (item && PyString_Check (item) && 0 == PyString_AsStringAndSize (item, &sitem, &size))
	    {
	      /*log_debug ("arr[3]=[%s]\n", sitem);*/
	      strncat (buffer, sitem, sizeof (buffer) - strlen (buffer) - 1);
	    }
	  SET_ERR (buffer);
	}
    }

  Py_XDECREF (py_retval);

  if (PyErr_Occurred ())
    {
      SET_ERR ("Unknown python error occurred");
      PyErr_Print ();
    }
  done_python_thread ();
  return retval;
}
