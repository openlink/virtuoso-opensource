/*
 *  Dkmarshal.c
 *
 *  $Id$
 *
 *  Marshalling on top of sessions
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

#include "Dk.h"

#if defined (UNIX) && !defined (WORDS_BIGENDIAN)
# include <netinet/in.h>	/* for ntohl, htonl */
#endif

#if defined (i386) || \
    defined (_WIN64) || \
    defined (_M_IX86) || \
    defined (_M_ALPHA) || \
    defined (mc68000) || \
    defined (sparc) || \
    defined (__x86_64) || \
    defined (__alpha) || \
    defined (__powerpc) || \
    defined (mips) || \
    defined (__OS2__) || \
    defined (_IBMR2)
# define _IEEE_FLOATS
#elif defined (OPL_SOURCE)
# include <librpc.h>
#else
# include <rpc/types.h>
# include <rpc/xdr.h>
#endif

static macro_char_func readtable[256];
static ses_write_func writetable[256];

#if 1
/*** INLINE THIS ! */
#define session_buffered_write_char INLINE_session_wc
static DK_INLINE void
session_buffered_write_char (int c, dk_session_t * ses)
{
  dtp_t ch = (dtp_t) c;

  if (ses->dks_out_fill >= ses->dks_out_length)
    {
      service_write (ses, ses->dks_out_buffer, ses->dks_out_fill);
      ses->dks_out_buffer[0] = ch;
      ses->dks_out_fill = 1;
    }
  else
    ses->dks_out_buffer[ses->dks_out_fill++] = ch;
}
#endif


ptrlong
read_short_int (dk_session_t *session)
{
  return (int) (signed char) session_buffered_read_char (session);
}


ptrlong
read_long (dk_session_t *session)
{
  uint32 res;
  session_buffered_read (session, (caddr_t) &res, sizeof (res));
#ifdef WORDS_BIGENDIAN
  return (long) (int32) res;
#else
  return (long) (int32) ntohl (res);
#endif
}


boxint
read_int64 (dk_session_t *session)
{
  union {
    int64 n64;
    struct {
      int32 n1;
      int32 n2;
    } n32;
  } num;
#if WORDS_BIGENDIAN
  num.n32.n1 = read_long (session);
  num.n32.n2 = read_long (session);
#else
  num.n32.n2 = read_long (session);
  num.n32.n1 = read_long (session);
#endif
  return num.n64;
}


void *
box_read_int64 (dk_session_t * ses, dtp_t dtp)
{
  return (void *) box_num (read_int64 (ses));
}


float
read_float (dk_session_t *session)
{
#ifdef _IEEE_FLOATS
# ifdef WORDS_BIGENDIAN
  /* ieee numbers, big endian */
  float res;

  session_buffered_read (session, (caddr_t) &res, sizeof (res));
  return res;

# else /* WORDS_BIGENDIAN */
  /* ieee numbers, little endian */
  union
    {
      uint32 l;
      float f;
    } ds;
  ds.l = read_long (session);
  return ds.f;
# endif

#else /* _IEEE_FLOATS */
  /* unusual numbers */
  unsigned char buf[4];
  float res;
  XDR x;

  session_buffered_read (session, (char *) buf, sizeof (buf));
  xdrmem_create (&x, (caddr_t) buf, sizeof (buf), XDR_DECODE);
  xdr_float (&x, &res);
  return res;
#endif
}


double
read_double (dk_session_t *session)
{
#ifdef _IEEE_FLOATS
# ifdef WORDS_BIGENDIAN
  /* ieee numbers, big endian */
  double res;

  session_buffered_read (session, (caddr_t) &res, sizeof (res));
  return res;

# else /* WORDS_BIGENDIAN */
  /* ieee numbers, little endian */
  union
    {
      uint32 l[2];
      double d;
    } ds;
  ds.l[1] = read_long (session);
  ds.l[0] = read_long (session);
  return ds.d;
# endif

#else /* _IEEE_FLOATS */
  /* unusual numbers */
  unsigned char buf[8];
  double res;
  XDR x;

  session_buffered_read (session, (char *) buf, sizeof (buf));
  xdrmem_create (&x, (caddr_t) buf, sizeof (buf), XDR_DECODE);
  xdr_double (&x, &res);
  return res;
#endif
}


/*
 *  read_object (dk_session_t *session)
 *
 *  The top-level function for reading objects.
 *  This sets the exception context to resume when the session is broken.
 */
void *
read_object (dk_session_t *session)
{
  void volatile * res = NULL;

  /* if the session does not have scheduler data just read it, don't
     bother to make a jump context. This is the case for string
     inputs, for instance. */
  if (!SESSION_SCH_DATA (session))
    return (scan_session_boxing (session));

  CATCH_READ_FAIL (session)
  {
    res = scan_session_boxing (session);
  }
  FAILED
  {
    res = NULL;
  }
  END_READ_FAIL (session);

  return (void *)res;
}


static void *
box_read_db_null (dk_session_t *session, dtp_t dtp)
{
  caddr_t ret;
  MARSH_CHECK_BOX (ret = dk_try_alloc_box (0, DV_DB_NULL));
  return ret;
}


static void *
box_read_short_string (dk_session_t *session, dtp_t dtp)
{
  int length = (int) session_buffered_read_char (session);
  char *string;

  MARSH_CHECK_BOX (string = (char *) dk_try_alloc_box (length + 1, DV_SHORT_STRING));
  session_buffered_read (session, string, length);
  string[length] = 0;
  return (void *) string;
}


static void *
box_read_long_string (dk_session_t *session, dtp_t dtp)
{
  size_t length = (size_t) read_long (session);
  char *string;
  MARSH_CHECK_LENGTH (length);
  MARSH_CHECK_BOX (string = (char *) dk_try_alloc_box (length + 1, DV_LONG_STRING));
  session_buffered_read (session, string, (int) length);
  string[length] = 0;
  return (void *) string;
}


#ifndef O12
static void *
box_read_ref_box (dk_session_t *session, dtp_t dtp)
{
  size_t length = session_buffered_read_char (session);
  char *string;
  MARSH_CHECK_BOX (string = (char *) dk_try_alloc_box (length, dtp));
  session_buffered_read (session, string, (int) length);
  return (void *) string;
}
#endif

static void *
box_read_short_cont_string (dk_session_t *session, dtp_t dtp)
{
  dtp_t length = session_buffered_read_char (session);
  unsigned char *string;
  MARSH_CHECK_BOX (string = (unsigned char *) dk_try_alloc_box (length + 2, DV_SHORT_CONT_STRING));
  string[0] = DV_SHORT_CONT_STRING;
  string[1] = length;
  session_buffered_read (session, (char *) (string + 2), (int) length);
  return (void *) string;
}


static void *
box_read_long_cont_string (dk_session_t *session, dtp_t dtp)
{
  size_t length = (size_t) read_long (session);
  unsigned char *string;
  unsigned char *p;

  MARSH_CHECK_LENGTH (length + 5);
  MARSH_CHECK_BOX (string = (unsigned char *) dk_try_alloc_box (length + 5, DV_LONG_CONT_STRING));
  p = string;
  *p++ = DV_LONG_CONT_STRING;
  *p++ = (unsigned char) (length >> 24);
  *p++ = (unsigned char) (length >> 16);
  *p++ = (unsigned char) (length >> 8);
  *p++ = (unsigned char) (length & 0xff);
  session_buffered_read (session, (char *) p, (int) length);
  return (void *) string;
}


long
read_int (dk_session_t *session)
{
  if (session_buffered_read_char (session) == DV_SHORT_INT)
    return read_short_int (session);
  return read_long (session);
}


/*
 * box_read_array
 *
 * allocate and read the contents of an array.
 * If the array is an array of pointers, use scan_session_boxing
 * so that possible numbers get boxed when appropriate.
 */
static void *
box_read_array (dk_session_t *session, dtp_t dtp)
{
  size_t count = (size_t) read_int (session);
  void **array;
  size_t n;

  MARSH_CHECK_LENGTH (count * sizeof (void *));
  MARSH_CHECK_BOX (array = (void **) dk_try_alloc_box (sizeof (void *) * count, dtp));
  for (n = 0; n < count; n++)
    array[n] = scan_session_boxing (session);

  return (void *) array;
}


static void *
box_read_array_of_double (dk_session_t *session, dtp_t dtp)
{
  size_t count = (size_t) read_int (session);
  double *array;
  size_t n;

  MARSH_CHECK_LENGTH (count * sizeof (double));
  MARSH_CHECK_BOX (array = (double *) dk_try_alloc_box (sizeof (double) * count, dtp));
  for (n = 0; n < count; n++)
    array[n] = read_double (session);

  return (void *) array;
}


static void *
box_read_array_of_float (dk_session_t *session, dtp_t dtp)
{
  size_t count = (size_t) read_int (session);
  float *array;
  size_t n;

  MARSH_CHECK_LENGTH (count * sizeof (float));
  MARSH_CHECK_BOX (array = (float *) dk_try_alloc_box (sizeof (float) * count, dtp));
  for (n = 0; n < count; n++)
    array[n] = read_float (session);

  return (void *) array;
}


static void *
box_read_packed_array_of_long (dk_session_t *session, dtp_t dtp)
{
  size_t count = (size_t) read_int (session);
  ptrlong *array;
  size_t n;

  MARSH_CHECK_LENGTH (count * sizeof (ptrlong));
  MARSH_CHECK_BOX (array = (ptrlong *) dk_try_alloc_box (sizeof (ptrlong) * count, dtp));

  for (n = 0; n < count; n++)
    array[n] = read_int (session);

  return (void *) array;
}


static void *
box_read_array_of_long (dk_session_t *session, dtp_t dtp)
{
  size_t count = (size_t) read_int (session);
  ptrlong *array;
  size_t n;

  MARSH_CHECK_LENGTH (count * sizeof (ptrlong));
  MARSH_CHECK_BOX (array = (ptrlong *) dk_try_alloc_box (sizeof (ptrlong) * count, dtp));
  for (n = 0; n < count; n++)
    array[n] = read_long (session);

  return (void *) array;
}


static void *
imm_read_null (dk_session_t *session, dtp_t dtp)
{
  return NULL;
}


static void *
imm_read_short_int (dk_session_t *session, dtp_t dtp)
{
  return (void *) (ptrlong) read_short_int (session);
}


static void *
imm_read_long (dk_session_t *session, dtp_t dtp)
{
  return (void *)(ptrlong) read_long (session);
}


static void *
imm_read_char (dk_session_t *session, dtp_t dtp)
{
  /* triple cast is probably too suspicious */
  return (void *) (ptrlong) (signed char) session_buffered_read_char (session);
}


static void *
imm_read_float (dk_session_t *session, dtp_t dtp)
{
  float f = read_float (session);
  return *(void **)&f;
}


void *
box_read_error (dk_session_t *session, dtp_t dtp)
{
  /*assert (session->dks_read_fail_on); */
  CHECK_READ_FAIL (session);

#ifdef DEBUG
  fprintf (stderr, "\n Undefined macro character 0x%x, closing connection. ", dtp);
#endif

  /* SESSTAT_SET (session, SST_BROKEN_CONNECTION); */
  /* SESSTAT_CLR (session, SST_OK); */
  if (session->dks_session)
    {				/* could be a string input */
      char temp[30];
      snprintf (temp, sizeof (temp), "Bad incoming tag %u", (unsigned) dtp);
      sr_report_future_error (session, "", temp);
      SESSTAT_SET (session->dks_session, SST_BROKEN_CONNECTION);
    }

  /* longjmp_splice (&session->dks_read_broken_context, 1); */
  longjmp_splice (&(SESSION_SCH_DATA (session)->sio_read_broken_context), 1);

  return NULL;
}


/*
 *  Set up the readtable
 */
void
init_readtable (void)
{
  int i;

  for (i = 0; i < 256; i++)
    if (NULL == readtable[i])
      readtable[i] = box_read_error;

  readtable[DV_NULL] = imm_read_null;
  readtable[DV_SHORT_INT] = imm_read_short_int;
  readtable[DV_LONG_INT] = imm_read_long;
  readtable[DV_INT64] = box_read_int64;
  readtable[DV_CHARACTER] = imm_read_char;
  readtable[DV_SINGLE_FLOAT] = imm_read_float;

/*
 * XXX cannot work - sizeof (double) == 8 , scan_session returns void *
  readtable[DV_DOUBLE_FLOAT] = read_double;
 */

  readtable[DV_SHORT_STRING_SERIAL] = box_read_short_string;
  readtable[DV_LONG_STRING] = box_read_long_string;

  readtable[DV_SHORT_CONT_STRING] = box_read_short_cont_string;
  readtable[DV_LONG_CONT_STRING] = box_read_long_cont_string;

  readtable[DV_LIST_OF_POINTER] = box_read_array;
  readtable[DV_ARRAY_OF_POINTER] = box_read_array;
  readtable[DV_ARRAY_OF_XQVAL] = box_read_array;
  readtable[DV_XTREE_HEAD] = box_read_array;
  readtable[DV_XTREE_NODE] = box_read_array;

  readtable[DV_ARRAY_OF_LONG_PACKED] = box_read_packed_array_of_long;
  readtable[DV_ARRAY_OF_LONG] = box_read_array_of_long;
  readtable[DV_ARRAY_OF_FLOAT] = box_read_array_of_float;
  readtable[DV_ARRAY_OF_DOUBLE] = box_read_array_of_double;

  readtable[DV_DB_NULL] = box_read_db_null;
#ifndef O12
  readtable[DV_G_REF_CLASS] = box_read_ref_box;
  readtable[DV_G_REF] = box_read_ref_box;
#endif
  strses_readtable_initialize ();
}


void *
PrpcReadObject (dk_session_t *session)
{
  return read_object (session);
}


macro_char_func *
get_readtable (void)
{
  return readtable;
}


/*##**********************************************************************

 *              scan_session, scan_session_boxing
 *
 * Reads the complete serial representation of data from the session.
 * Returns the data.
 * Reads the data type character and invokes the corresponding function
 * to read the datum. scan_session_boxing is similar, but creates a box
 * if the item read was a number that could be confused with a pointer.
 *
 * Input params :
 *
 *      session     - the session
 *
 * Output params: - none
 *
 * Return value :  The object read
 *
 *
 * Limitations  :
 *  *
 * Globals used : - readtable
 */
void *
scan_session (dk_session_t *session)
{
  dtp_t next_char;

  next_char = session_buffered_read_char (session);
  return (*readtable[next_char]) (session, next_char);
}


/*
 *  Like scan_session, but allocates a box if needed
 */
void *
scan_session_boxing (dk_session_t *session)
{
  dtp_t next_char;
  void *result;

  next_char = session_buffered_read_char (session);

  if (next_char == DV_SINGLE_FLOAT)
    {
      float d = read_float (session);
      float *box;

      MARSH_CHECK_BOX (box = (float *) dk_try_alloc_box (sizeof (float), DV_SINGLE_FLOAT));
      *box = d;
      return (box_t) box;
    }

  if (next_char == DV_DOUBLE_FLOAT)
    {
      double d = read_double (session);
      double *box;

      MARSH_CHECK_BOX (box = (double *) dk_try_alloc_box (sizeof (double), DV_DOUBLE_FLOAT));
      *box = d;
      return (box_t) box;
    }

  result = (*readtable[next_char]) (session, next_char);

  if (next_char == DV_LONG_INT || next_char == DV_SHORT_INT)
    {
      boxint *box;
      if (!IS_POINTER (result))
	return (void *) (ptrlong) result;
      MARSH_CHECK_BOX (box = (boxint *) dk_try_alloc_box (sizeof (boxint), DV_LONG_INT));
      *box = (boxint)(ptrlong) result;
      result = box;
    }

  return result;
}


static void
print_raw_float (float f, dk_session_t *session)
{
#ifdef _IEEE_FLOATS
# ifdef WORDS_BIGENDIAN
  /* ieee numbers, big endian */
  session_buffered_write (session, (caddr_t) &f, sizeof (float));

# else /* WORDS_BIGENDIAN */
  /* ieee numbers, little endian */
  union
    {
      uint32 l;
      float f;
    } ds;
  ds.f = f;
  print_long ((long) ds.l, session);
# endif

#else /* _IEEE_FLOATS */
  /* unusual numbers */
  unsigned char buf[4];
  XDR x;

  xdrmem_create (&x, (char *) buf, sizeof (buf), XDR_ENCODE);
  xdr_float (&x, &f);
  session_buffered_write (session, (char *) buf, sizeof (buf));
#endif
}


static void
print_raw_double (double d, dk_session_t *session)
{
#ifdef _IEEE_FLOATS
# ifdef WORDS_BIGENDIAN
  /* ieee numbers, big endian */
  session_buffered_write (session, (caddr_t) &d, sizeof (double));

# else /* WORDS_BIGENDIAN */
  /* ieee numbers, little endian */
  union
    {
      uint32 l[2];
      double d;
    } ds;
  ds.d = d;
  print_long ((long) ds.l[1], session);
  print_long ((long) ds.l[0], session);
# endif

#else /* _IEEE_FLOATS */
  /* unusual numbers */
  unsigned char buf[8];
  XDR x;

  xdrmem_create (&x, (char *) buf, sizeof (buf), XDR_ENCODE);
  xdr_double (&x, &d);
  session_buffered_write (session, (char *) buf, sizeof (buf));
#endif
}


void
print_long (long l, dk_session_t *session)
{
#ifdef WORDS_BIGENDIAN
  uint32 value = (uint32) l;
#else
  uint32 value = (uint32) htonl ((uint32) l);
#endif
  session_buffered_write (session, (caddr_t) &value, sizeof (value));
}


void
print_int64 (boxint n, dk_session_t *session)
{
  union {
    int64 n64;
    struct {
      int32 n1;
      int32 n2;
    } n32;
  } num;
  session_buffered_write_char (DV_INT64, session);
  num.n64 = n;
#if WORDS_BIGENDIAN
  print_long (num.n32.n1, session);
  print_long (num.n32.n2, session);
#else
  print_long (num.n32.n2, session);
  print_long (num.n32.n1, session);
#endif
}

ses_write_func int64_serialize_client_f;

void
print_int (boxint n, dk_session_t *session)
{
  if ((n > -128) && (n < 128))
    {
      session_buffered_write_char (DV_SHORT_INT, session);
      session_buffered_write_char ((char) n, session);
    }
  else if (n >= (int64) INT32_MIN && n <= (int64) INT32_MAX)
    {
      session_buffered_write_char (DV_LONG_INT, session);
      print_long (n, session);
    }
  else
    {
      if (int64_serialize_client_f)
	{
	  (*int64_serialize_client_f) ((caddr_t)&n, session);
	}
      else
	print_int64 (n, session);
    }
}


void
print_float (float f, dk_session_t *session)
{
  session_buffered_write_char (DV_SINGLE_FLOAT, session);
  print_raw_float (f, session);
}


void
print_double (double v, dk_session_t *session)
{
  session_buffered_write_char (DV_DOUBLE_FLOAT, session);
  print_raw_double (v, session);
}


void
dks_array_head (dk_session_t *session, long n_elements, dtp_t type)
{
  session_buffered_write_char (type, session);
  print_int (n_elements, session);
}


void
print_string (char *string, dk_session_t *session)
{
  /* There will be a zero at the end. Do not send the zero. */
  size_t length = box_length (string) - 1;
  if (length < 256)
    {
      session_buffered_write_char (DV_SHORT_STRING_SERIAL, session);
      session_buffered_write_char ((char) length, session);
    }
  else
    {
      session_buffered_write_char (DV_STRING, session);
      print_long ((long) length, session);
    }
  session_buffered_write (session, string, length);
}


void
print_ref_box (char *string, dk_session_t *session)
{
  /* There will be a zero at the end. Do not send the zero. */
  size_t length = box_length (string);
  if (length < 256)
    {
      session_buffered_write_char (box_tag (string), session);
      session_buffered_write_char ((char) length, session);
      session_buffered_write (session, string, length);
    }
  else
    GPF_T;			/* Ref box over 255 bytes */
}


/* print_object2 (box, session)
 *
 * This prints the serial representation of box into the session.
 * Box must be something allocated with dk_alloc_box(). If it is an array of
 * pointers, the items referred to by the pointers must also be boxes
 * allocated by dk_alloc_box. Printing proceeds recursively until all
 * the data reached has been printed. Strong or weak cycles are not
 * detected.
 */

void
print_object2 (void *object, dk_session_t *session)
{
  if (object == NULL)
    session_buffered_write_char (DV_NULL, session);

  else if (!IS_BOX_POINTER (object))
    print_int ((long) (ptrlong) object, session);

  else
    {
      dtp_t tag = box_tag (object);
      size_t length;

      switch (tag)
	{
	case DV_ARRAY_OF_POINTER: case DV_LIST_OF_POINTER: case DV_ARRAY_OF_XQVAL: case DV_XTREE_HEAD: case DV_XTREE_NODE:
	  {
	    void **valptr = (void **) object;
	    length = box_length (object) / sizeof (void *);
	    session_buffered_write_char (tag, session);
	    print_int ((long) length, session);
	    while (length--)
	      {
		void *elt = *valptr++;
		if (IS_POINTER (elt))
		  print_object2 (elt, session);
		else
		  print_int ((long) (ptrlong) elt, session);
	      }
	  }
	  break;

	case DV_ARRAY_OF_LONG:
	  {
	    ptrlong *valptr = (ptrlong *) object;
	    length = box_length (object) / sizeof (ptrlong);
	    session_buffered_write_char (DV_ARRAY_OF_LONG, session);
	    print_int ((long) length, session);
	    while (length--)
	      print_long ((long) *valptr++, session);
	  }
	  break;

	case DV_ARRAY_OF_LONG_PACKED:
	  {
	    ptrlong *valptr = (ptrlong *) object;
	    length = box_length (object) / sizeof (ptrlong);
	    session_buffered_write_char (DV_ARRAY_OF_LONG_PACKED, session);
	    print_int ((long) length, session);
	    while (length--)
	      print_int ((long) *valptr++, session);
	  }
	  break;

	case DV_ARRAY_OF_DOUBLE:
	  {
	    double *valptr = (double *) object;
	    length = box_length (object) / sizeof (double);
	    session_buffered_write_char (DV_ARRAY_OF_DOUBLE, session);
	    print_int ((long) length, session);
	    while (length--)
	      print_raw_double (*valptr++, session);
	  }
	  break;

	case DV_ARRAY_OF_FLOAT:
	  {
	    float *valptr = (float *) object;
	    length = box_length (object) / sizeof (float);
	    session_buffered_write_char (DV_ARRAY_OF_FLOAT, session);
	    print_int ((long) length, session);
	    while (length--)
	      print_raw_float (*valptr++, session);
	  }
	  break;

	case DV_LONG_INT:
	  print_int (*(boxint *)object, session);
	  break;

	case DV_STRING:
	case DV_C_STRING:
	case DV_UNAME:
	  print_string ((char *) object, session);
	  break;
#ifndef O12
	case DV_G_REF_CLASS:
	case DV_G_REF:
	  print_ref_box (object, session);
	  break;
#endif
	case DV_SINGLE_FLOAT:
	  print_float (*(float *) object, session);
	  break;

	case DV_DOUBLE_FLOAT:
	  print_double (*(double *) object, session);
	  break;

	case DV_DB_NULL:
	  session_buffered_write_char (DV_DB_NULL, session);
	  break;

	case DV_SHORT_CONT_STRING:
	case DV_LONG_CONT_STRING:
	  session_buffered_write (session, (char *) object, box_length (object));
	  break;

	default:
	  {
	    ses_write_func f = writetable[tag];
	    if (f)
	      {
		(*f) (object, session);
		return;
	      }
#ifdef NDEBUG
	    CHECK_WRITE_FAIL (session);
	    if (session->dks_session)
	      {				/* could be a string input */
		char temp[30];
		snprintf (temp, sizeof (temp), "Bad outgoing tag %u", (unsigned) tag);
		sr_report_future_error (session, "", temp);
		SESSTAT_SET (session->dks_session, SST_BROKEN_CONNECTION);
	      }
	    longjmp_splice (&(SESSION_SCH_DATA (session)->sio_write_broken_context), 1);
#else
	    GPF_T1 ("Bad tag in print_object");
#endif
	  }
	}
    }
}


/*##**********************************************************************

 *              srv_write_in_session
 *
 * This is the entry point for serializing data.  This accepts a tagged box
 * or Distributed Objects object and sends it through the session. This
 * reserves the session for the write and establishes a context where a failed
 * write may abort.
 *
 * Input params :
 *
 *      session     - the session
 *
 * Output params: The session status is set.
 *
 * Return value :
 *
 *      SER_SUCC   Normal return.
 *      SER_FAIL   The write jumped to the error context.
 *
 * Limitations  :
 *
 * Globals used : none
 */
int
srv_write_in_session (void *object, dk_session_t *session, int flush)
{
  int ret;
  if (!session)
    return SER_SUCC;
  mutex_enter (session->dks_mtx);
  CATCH_WRITE_FAIL (session)
  {
    print_object2 (object, session);
    if (flush)
      session_flush_1 (session);
    ret = SER_SUCC;
  }
  FAILED
  {
    ret = SER_FAIL;
  }
  END_WRITE_FAIL (session);
  mutex_leave (session->dks_mtx);

  return ret;
}


int
PrpcWriteObject (dk_session_t *session, void *object)
{
  return srv_write_in_session (object, session, 1);
}


void
PrpcSetWriter (dtp_t dtp, ses_write_func f)
{
  writetable[dtp] = f;
}
