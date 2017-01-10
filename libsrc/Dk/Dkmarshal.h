/*
 *  Dkmarshal.h
 *
 *  $Id$
 *
 *  Marshalling on top of sessions
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2017 OpenLink Software
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

#ifndef _DKMARSHAL_H
#define _DKMARSHAL_H

typedef void *(*macro_char_func) (dk_session_t * session, dtp_t macro);
typedef int (*ses_write_func) (void *obj, dk_session_t * session);

/* Rename */
#define print_object(OBJ,SES,I1,I2)	print_object2 (OBJ, SES)

/* nmarsh.c */
ptrlong read_short_int (dk_session_t * session);
ptrlong read_long (dk_session_t * session);
boxint read_int64 (dk_session_t * ses);
short read_short (dk_session_t * ses);
float read_float (dk_session_t * session);
double read_double (dk_session_t * session);
void *read_object (dk_session_t * session);
void *read_object_boxing (dk_session_t * session);
void init_readtable (void);
void *PrpcReadObject (dk_session_t * session);
macro_char_func *get_readtable (void);
void *scan_session (dk_session_t * session);
void *scan_session_boxing (dk_session_t * session);
void print_long (long l, dk_session_t * session);
void print_int64 (boxint n, dk_session_t * session);
void print_int64_no_tag (boxint n, dk_session_t * session);
void print_int (boxint n, dk_session_t * session);
void print_float (float f, dk_session_t * session);
void print_double (double v, dk_session_t * session);
void print_raw_float (float f, dk_session_t * session);
void print_raw_double (double f, dk_session_t * session);
void dks_array_head (dk_session_t * session, long n_elements, dtp_t type);
void print_string (char *string, dk_session_t * session);
void print_ref_box (char *string, dk_session_t * session);
void print_object2 (void *object, dk_session_t * session);
int srv_write_in_session (void *object, dk_session_t * session, int flush);
int PrpcWriteObject (dk_session_t * session, void *object);
void PrpcSetWriter (dtp_t dtp, ses_write_func f);
int64 read_int (dk_session_t *session);
extern ses_write_func int64_serialize_client_f;

void *box_read_error (dk_session_t * session, dtp_t dtp);

#define MAX_READ_STRING 10000000
#define MARSH_CHECK_LENGTH(length) \
  if ((length) > MAX_READ_STRING || (length) < 0) \
    { \
      sr_report_future_error (session, "", "Box length too large"); \
      CHECK_READ_FAIL (session); \
      if (session->dks_session) \
        { \
	  SESSTAT_SET (session->dks_session, SST_BROKEN_CONNECTION); \
	} \
      longjmp_splice (&(SESSION_SCH_DATA (session)->sio_read_broken_context), 1); \
      return 0; /* dummy */ \
    }

#define MARSH_CHECK_BOX(thing) \
  if (!(thing)) \
    { \
      sr_report_future_error (session, "", "Can't allocate memory for the incoming data"); \
      CHECK_READ_FAIL (session); \
      if (session->dks_session) \
        { \
	  SESSTAT_SET (session->dks_session, SST_BROKEN_CONNECTION); \
	} \
      longjmp_splice (&(SESSION_SCH_DATA (session)->sio_read_broken_context), 1); \
      return 0; /* dummy */ \
    }


extern int (*box_flags_serial_test_hook) (dk_session_t * ses);

#endif
