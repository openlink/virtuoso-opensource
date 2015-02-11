/*
 *  ruby_io.c
 *
 *  $Id$
 *
 *  Virtuoso Ruby hosting plugin IO handlers
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
 *  
*/
#include "hosting_ruby.h"

VALUE vrb_module;
VALUE vrb_request;
VALUE vrb_err_request;

RUBY_EXTERN VALUE rb_stdin;
RUBY_EXTERN VALUE rb_stdout;
RUBY_EXTERN VALUE rb_stderr;

/* the data part of the request ruby object : used to track the progress of reading/writing */
typedef struct vrb_io_data_s
{
  vrb_request_t *elt;
  int read_max;
  int readed;
  VALUE headers;
  VALUE body;
  int html_mode;
  int headers_over;
} vrb_io_data_t;

static vrb_io_data_t *
vrb_get_req_data (VALUE obj)
{
  vrb_io_data_t *data;
  Check_Type (obj, T_DATA);
  data = (vrb_io_data_t *) RDATA (obj)->data;
  if (!data)
    rb_raise (rb_eArgError, "Destroyed content");
  return data;
}

/* variable length args */
static VALUE
vrb_request_read (int argc, VALUE * argv, VALUE self)
{
  VALUE length, ret;
  int len = 0;
  vrb_io_data_t *data = vrb_get_req_data (self);
  rb_scan_args (argc, argv, "01", &length);

  if (!data->elt)
    return Qnil;

  if (NIL_P (length))
    {				/* omitted */
      len = data->read_max - data->readed;
    }
  else
    {
      len = NUM2INT (length);
      if (len < 0)
	rb_raise (rb_eArgError, "negative length %d given", len);
      len =
	  len <
	  (data->read_max - data->readed) ? len : (data->read_max -
	  data->readed);
    }
  ret = rb_tainted_str_new (data->elt->params + data->readed, len);
  data->readed += len;
  return ret;
}

static VALUE
vrb_request_readlines (int argc, VALUE * argv, VALUE self)
{
  VALUE file_name = Qnil, sep = Qnil, ret = Qnil;
  if (argc > 0)
    rb_scan_args (argc, argv, "1", &file_name);
  if (argc > 1)
    rb_scan_args (argc, argv, "2", &sep);

  if (!NIL_P (file_name))
    {
      FILE *fi;
      char file_name_buffer[2048];
      size_t total;
      VALUE str;

      sprintf (file_name_buffer, "%.*s", (int) RSTRING (file_name)->len,
	  RSTRING (file_name)->ptr);
      if (NIL_P (sep))
	rb_raise (rb_eArgError, "no sep given");

      fi = fopen (file_name_buffer, "rt");
      if (!fi)
	rb_raise (rb_eArgError, "Can't open file %s", file_name_buffer);
      str = rb_tainted_str_new ("", 0);
      total = 0;
      while (!feof (fi) && !ferror (fi) && total <= 1000000)
	{
	  int readed =
	      fread (file_name_buffer, 1, sizeof (file_name_buffer), fi);
	  if (readed)
	    rb_str_cat (str, file_name_buffer, readed);
	  total += readed;
	}
      if (ferror (fi))
	{
	  fclose (fi);
	  rb_raise (rb_eArgError, "Error reading the file %s",
	      file_name_buffer);
	  rb_gc_mark (str);
	  str = Qnil;
	}
      fclose (fi);
      if (total >= 1000000)
	{
	  rb_raise (rb_eArgError,
	      "The file %s is longer than the max allowed size of 1M",
	      file_name_buffer);
	  rb_gc_mark (str);
	  str = Qnil;
	}
      sprintf (file_name_buffer, "%.*s", (int) RSTRING (sep)->len,
	  RSTRING (sep)->ptr);
      ret = rb_str_split (str, file_name_buffer);
      rb_gc_mark (str);
    }
  else
    {				/* the in buffer split in lines */
      VALUE str;
      vrb_io_data_t *data = vrb_get_req_data (self);
      str =
	  rb_tainted_str_new (data->elt->params + data->readed,
	  data->read_max - data->readed);
      ret = rb_str_split (str, "\n");
      rb_gc_mark (str);
    }
  return ret;
}

static VALUE
vrb_request_write (int argc, VALUE * argv, VALUE self)
{
  vrb_io_data_t *data = vrb_get_req_data (self);
  VALUE str;

  rb_scan_args (argc, argv, "01", &str);
  str = rb_obj_as_string (str);

  vrb_fprintf ((stderr, "WRITE: (%.*s)\n", (int) RSTRING (str)->len,
	  RSTRING (str)->ptr));

  if (data->html_mode && !data->headers_over)
    {
      VALUE parts;
#ifdef VRB_DEBUG
      char *str_str, *headers_str, *body_str;
      int len = 0;
#endif

#ifdef VRB_DEBUG
      str_str = RSTRING (str)->ptr;
      headers_str = RSTRING (data->headers)->ptr;
      body_str = RSTRING (data->body)->ptr;
#endif
      rb_str_cat (data->headers, RSTRING (str)->ptr, RSTRING (str)->len);
      vrb_fprintf ((stderr,
	      "WRITE: new_headers : (%.*s)\n",
	      (int) RSTRING (data->headers)->len,
	      RSTRING (data->headers)->ptr));
      parts = rb_str_split (data->headers, "\r\n\r\n");

#ifdef VRB_DEBUG
      len = RARRAY (parts)->len;
#endif
      vrb_fprintf ((stderr, "WRITE: len : (%d)\n", len));

      if (RARRAY (parts)->len < 2)
	{
	  parts = rb_str_split (data->headers, "\n\n");
#ifdef VRB_DEBUG
	  len = RARRAY (parts)->len;
#endif
	  vrb_fprintf ((stderr, "WRITE: len2 : (%d)\n", len));

	}
      if (RARRAY (parts)->len > 1)
	{
	  data->headers_over = 1;
	  rb_gc_mark (data->headers);
	  rb_gc_mark (data->body);
	  data->headers = RARRAY (parts)->ptr[0];
	  data->body = RARRAY (parts)->ptr[1];
	}
    }
  else
    rb_str_cat (data->body, RSTRING (str)->ptr, RSTRING (str)->len);
  return Qnil;
}


static void
vrb_request_mark (vrb_io_data_t * data)
{
  /* when the GC hits */
  rb_gc_mark (data->headers);
  rb_gc_mark (data->body);
}


static void
vrb_init_io_data (vrb_io_data_t * data)
{
  data->elt = NULL;
  data->read_max = 0;
  data->readed = 0;
  data->headers = rb_tainted_str_new ("", 0);
  data->body = rb_tainted_str_new ("", 0);
  data->headers_over = 0;
  data->html_mode = 0;
}

static char *
vrb_alloc_from_ruby_str (VALUE data)
{
  char *ret = NULL;
  if (RSTRING (data)->len > 0)
    {
      ret = (char *) malloc (RSTRING (data)->len + 1);
      memcpy (ret, RSTRING (data)->ptr, RSTRING (data)->len);
      ret[RSTRING (data)->len] = 0;
    }
  return ret;
}


void
vrb_load_file_protect (const char *file, int *state)
{
  rb_protect ((VALUE (*)())rb_load_file, (VALUE) file, state);
  if (!*state)
    *state = ruby_exec ();
}

/* tl request functions */
void
vrb_virt_start_request (vrb_request_t * elt)
{
  vrb_io_data_t *data = vrb_get_req_data (vrb_request);
  vrb_io_data_t *err_data = vrb_get_req_data (vrb_err_request);

  vrb_request_mark (data);
  vrb_request_mark (err_data);
  vrb_init_io_data (data);
  vrb_init_io_data (err_data);

  data->elt = elt;
  data->read_max = elt->params ? strlen (elt->params) : 0;
  data->html_mode = elt->html_mode;

  rb_stdin = vrb_request;
  rb_stdout = vrb_request;
  rb_stderr = vrb_err_request;
}

void
vrb_virt_flush_request ()
{
  vrb_io_data_t *data = vrb_get_req_data (vrb_request);
  vrb_io_data_t *err_data = vrb_get_req_data (vrb_err_request);

  rb_stdin = vrb_request;
  rb_stdout = vrb_request;
  rb_stderr = vrb_err_request;

  if (!data->elt)
    return;

  if (data->elt->head_ret)
    *(data->elt->head_ret) = vrb_alloc_from_ruby_str (data->headers);

  data->elt->retval = vrb_alloc_from_ruby_str (data->body);

  if (data->elt->diag_ret)
    *(data->elt->diag_ret) = vrb_alloc_from_ruby_str (err_data->body);
}

void
vrb_init_virt_request ()
{
  vrb_io_data_t *data = NULL;
  vrb_io_data_t *err_data = NULL;

  /* define the Request class */
  VALUE vrb_request_class =
      rb_define_class_under (vrb_module, "Request", rb_cObject);
  rb_undef_method (CLASS_OF (vrb_request_class), "new");

  rb_define_method (vrb_request_class, "read", vrb_request_read, -1);
  rb_define_method (vrb_request_class, "write", vrb_request_write, -1);
  rb_define_method (vrb_request_class, "readlines", vrb_request_readlines,
      -1);

  /* instantiate a global instance of the Request class */
  vrb_request = Data_Make_Struct (vrb_request_class, vrb_io_data_t,
      vrb_request_mark, free, data);
  /* instantiate a global instance of the Request class for stderr */
  vrb_err_request = Data_Make_Struct (vrb_request_class, vrb_io_data_t,
      vrb_request_mark, free, err_data);

  vrb_init_io_data (data);
  vrb_init_io_data (err_data);

  rb_stdin = vrb_request;
  rb_stdout = vrb_request;
  rb_stderr = vrb_err_request;
}

static VALUE
vrb_server_version (VALUE self)
{
  return rb_str_new2 (DBMS_SRV_GEN_MAJOR DBMS_SRV_GEN_MINOR);
}

void
vrb_init_virt_code ()
{
  vrb_request = Qnil;
  vrb_err_request = Qnil;
  rb_global_variable (&vrb_request);
  rb_global_variable (&vrb_err_request);

  vrb_module = rb_define_module ("Virtuoso");
  rb_define_module_function (vrb_module, "server_version", vrb_server_version,
      0);

  vrb_init_virt_request ();
}
