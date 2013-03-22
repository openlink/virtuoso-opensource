/*
 *  Dksesstr.c
 *
 *  $Id$
 *
 *  String sessions
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2013 OpenLink Software
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

#include "Dk.h"
#include "libutil.h"
#include "Dksesstr.h"

char *ses_tmp_dir;

/* The string session

  The string session is a session offering the session_buffered_read/writer
  API. A string session has separate in and out buffers as well as a
  linked list of buffer elements. Each of these contains a buffer, a
  fill count and a read count.

  The string session has two modes of operation. Write and read. It needs to be
  full written before anything can be read from it.

  If the output in a string session is shorter than the out buffer no buffer
  elements are allocated. If there is more output, it is dumped into successive
  buffers linked together by the buffer_elt_t structure.

  Before a string session can be red it needs to be 'rewound' with
  the strses_rewind operation. After this no writes may be attempted.

  The following operations are available:

  strses_write - append a string to the session.
  strses_read - read a string from the session.
  strses_rewind - Initialize reading from the string session.
  strses_flush - Free all buffers and set an existing string session to be
		 reused for writing.
  strses_allocate - Make a new string session and make it  ready for writing.

  strses_free - deallocate all memory associated with a string session.

*/

long strses_file_reads = 0;
long strses_file_seeks = 0;
long strses_file_writes = 0;
long strses_file_wait_msec = 0;

long read_wides_from_utf8_file (dk_session_t * ses, long nchars, unsigned char *dest, int copy_as_utf8, unsigned char **dest_ptr_out);

OFF_T
strf_lseek (strsestmpfile_t * sesfile, OFF_T offset, int whence)
{
  OFF_T ret;
  long start_time = get_msec_real_time ();
  strses_file_seeks ++;
  if (NULL != sesfile->ses_lseek_func)
    ret = sesfile->ses_lseek_func (sesfile, offset, whence);
  else
    ret = LSEEK (sesfile->ses_file_descriptor, offset, whence);
  strses_file_wait_msec += (get_msec_real_time () - start_time);
  return ret;
}

size_t
strf_read (strsestmpfile_t * sesfile, void *buf, size_t nbyte)
{
  size_t ret;
  long start_time = get_msec_real_time ();
  strses_file_reads ++;
  if (NULL != sesfile->ses_read_func)
    ret = sesfile->ses_read_func (sesfile, buf, nbyte);
  else
    ret = read (sesfile->ses_file_descriptor, buf, nbyte);
  strses_file_wait_msec += (get_msec_real_time () - start_time);
  return ret;
}

static size_t
strf_write (strsestmpfile_t * sesfile, const void *buf, size_t nbyte)
{
  size_t ret;
  strses_file_writes ++;
  if (NULL != sesfile->ses_wrt_func)
    ret = sesfile->ses_wrt_func (sesfile, buf, nbyte);
  else
    ret = write (sesfile->ses_file_descriptor, buf, nbyte);
  return ret;
}

/*
 *  Returns a pointer to a non-full buffer
 */
static buffer_elt_t *
DBG_NAME (strdev_get_buf) (DBG_PARAMS dk_session_t * ses)
{
  buffer_elt_t *buf = ses->dks_buffer_chain_tail;
  buffer_elt_t **last_ref = &ses->dks_buffer_chain_tail;
  buffer_elt_t *new_buf;
  strdevice_t *strdev = (strdevice_t *) ses->dks_session->ses_device;

  while (buf)
    {
      if (buf->fill < DKSES_OUT_BUFFER_LENGTH && !buf->space_exausted)
	return (buf);
      last_ref = &buf->next;
      buf = buf->next;
    }

  new_buf = (buffer_elt_t *) dk_alloc (sizeof (buffer_elt_t));
  new_buf->fill = 0;
  new_buf->read = 0;
  new_buf->fill_chars = 0;
  new_buf->space_exausted = 0;
  new_buf->data = (char *) DK_ALLOC (DKSES_OUT_BUFFER_LENGTH);
  new_buf->next = NULL;
  last_ref[0] = new_buf;
  if (NULL == ses->dks_buffer_chain)
    strdev->strdev_buffer_ptr = ses->dks_buffer_chain = ses->dks_buffer_chain_tail;
  else
    ses->dks_buffer_chain_tail = new_buf;
  return (new_buf);
}


#ifdef MALLOC_DEBUG
#define strdev_get_buf(ses) dbg_strdev_get_buf (__FILE__, __LINE__, ses)
#endif

static void
strdev_free_buf (buffer_elt_t * b, caddr_t arg)
{
  dk_free (b->data, DKSES_OUT_BUFFER_LENGTH);
  dk_free (b, sizeof (buffer_elt_t));
}


/* outputs the input buffer up to the last full utf8 char boundary */
/* utf8_in : the incoming (possibly not correct) utf8 string */
/* max_utf8_chars : the max length of the utf8_in */
/* out_buf : the buffer to hold the (correctly ending) utf8 */
/* max_out_buf : the max length of the out_buf */
/* nwc : if supplied, the out param ; number of wide chars stored in the wide buf */
/* space_exausted : if supplied, the out param ; marks exit due out of output space */
/* return value : the number of utf8 bytes actually stored into the output buf */
static size_t
strdev_round_utf8_partial_string (
    const unsigned char *utf8_in,
    size_t max_utf8_chars,
    unsigned char *out_buf,
    size_t max_out_buf,
    size_t * pnwc,
    int *space_exausted)
{
  size_t written = 0;
  size_t nwc = 0;
  virt_mbstate_t ps;
  memset (&ps, 0, sizeof (ps));
  while (written < max_out_buf && max_utf8_chars)
    {
      size_t utf_char_len = virt_mbrtowc (NULL, utf8_in, max_utf8_chars, &ps);
      if (utf_char_len == (size_t) - 1)
	return (size_t) - 1;

      if (utf_char_len <= max_out_buf - written)
	{
	  memcpy (out_buf, utf8_in, utf_char_len);
	  out_buf += utf_char_len;
	  written += utf_char_len;
	  nwc++;
	}
      else
	{
	  if (space_exausted)
	    *space_exausted = 1;
	  break;
	}
      max_utf8_chars -= utf_char_len;
      utf8_in += utf_char_len;
    }
  if (written == max_out_buf && space_exausted)
    *space_exausted = 1;
  if (pnwc)
    *pnwc = nwc;
  return written;
}


int
utf8_align_memcpy (void *dst, const void *src, size_t len, size_t * pnwc, int *space_exausted)
{
  size_t ret = strdev_round_utf8_partial_string ((const unsigned char *) src, len,
      (unsigned char *) dst, len,
      pnwc,
      space_exausted);
  if (ret == (size_t) - 1)
    return -1;
  else
    return (int) ret;
}


/*##**********************************************************************
 *
 *		strdev_write
 *
 * Append a string to the string session
 * This allocates a buffer of a preset length and fills it uo to its
 * size. Higher levels will call this several times to append long strings.
 *
 * Input params :	  - The string session, the string to append
 &		       - the number of bytes to append.
 *
 * Output params:    - none
 *
 * Return value :    the number of bytes effectively added to the string session.
 *
 * Limitations  :   - The algorithm is poor, the session needs to be in write mode.
 *
 * Globals used :
 */
static int
strdev_write (session_t * ses2, char *buffer, int bytes)
{
  dk_session_t *ses = SESSION_DK_SESSION (ses2);
  int filled;
  buffer_elt_t *buf = NULL;
  long space = 0;
  strdevice_t *strdev = (strdevice_t *) ses2->ses_device;

  if (ses2->ses_file->ses_file_descriptor)
    {
      int written = 0;
      OFF_T fill;

      fill = strf_lseek (ses2->ses_file, 0, SEEK_END);
      if (fill == -1)
	{
	  SESSTAT_SET (ses2, SST_DISK_ERROR);
	  log_error ("Can't seek in file %s", ses2->ses_file->ses_temp_file_name);
	  return 0;
	}
      else
	{
	  written = strf_write (ses2->ses_file, buffer, bytes);
	  if (bytes != written)
	    {
	    report_error:
	      SESSTAT_SET (ses2, SST_DISK_ERROR);
	      log_error ("Can't write to file %s", ses2->ses_file->ses_temp_file_name);
	      return 0;
	    }
	  ses2->ses_file->ses_fd_fill = fill + written;
	  if (strdev->strdev_is_utf8)
	    {
	      virt_mbstate_t mb;
	      size_t len;
	      unsigned char *buf = (unsigned char *) buffer;
	      memset (&mb, 0, sizeof (mb));
	      len = virt_mbsnrtowcs (NULL, &buf, written, 0, &mb);
	      if (len == -1)
		goto report_error;
	      ses2->ses_file->ses_fd_fill_chars += len;
	    }
	  else
	    ses2->ses_file->ses_fd_fill_chars = ses2->ses_file->ses_fd_fill;
	}
      return written;
    }

  buf = strdev_get_buf (ses);
  space = DKSES_OUT_BUFFER_LENGTH - buf->fill;

  if (ses2->ses_file->ses_max_blocks_in_mem && buf->fill == 0 && buf->read == 0)
    {
      ses2->ses_file->ses_max_blocks_in_mem--;
      if (!ses2->ses_file->ses_max_blocks_in_mem)
	{
	  char fname[PATH_MAX + 1];
	  snprintf (fname, sizeof (fname), "%s/sesXXXXXX", ses_tmp_dir);
	  mktemp (fname);

#if defined (WIN32)
# define OPEN_FLAGS  	  O_CREAT | O_RDWR | O_BINARY | O_EXCL | O_TEMPORARY
#elif defined (FILE64)
# define OPEN_FLAGS       O_RDWR | O_CREAT | O_BINARY | O_EXCL | O_LARGEFILE
#else
# define OPEN_FLAGS       O_RDWR | O_CREAT | O_BINARY | O_EXCL
#endif

#ifdef WIN32
	  ses2->ses_file->ses_file_descriptor = _open (fname, OPEN_FLAGS, 0600);
#else
	  ses2->ses_file->ses_file_descriptor = open (fname, OPEN_FLAGS, 0600);
	  unlink (fname);
#endif
	  if (ses2->ses_file->ses_file_descriptor < 0)
	    {
	      SESSTAT_SET (ses2, SST_DISK_ERROR);
	      log_error ("Can't open file %s, error %d", fname, errno);
	      ses2->ses_file->ses_file_descriptor = 0;
	    }
	  else
	    ses2->ses_file->ses_temp_file_name = box_dv_short_string (fname);
	  ses2->ses_file->ses_fd_fill = ses2->ses_file->ses_fd_read = 0;
	}
    }

  SESSTAT_SET (ses->dks_session, SST_OK);
  if (strdev->strdev_in_read && !buf->fill && bytes >= ses->dks_out_length && !buf->read && ses2->ses_device)
    {
      buf->read = strdev->strdev_in_read;
      strdev->strdev_in_read = 0;
    }
  if (strdev->strdev_is_utf8)
    {
      size_t nwc = 0;
      int space_exausted = 0;

      filled = strdev_round_utf8_partial_string (
	    (unsigned char *) buffer,
	    bytes,
	    (unsigned char *) &buf->data[buf->fill],
	    space,
	    &nwc,
	    &space_exausted);
      if (filled == (size_t) - 1)
	{
	  SESSTAT_SET (ses2, SST_DISK_ERROR);
	  SESSTAT_CLR (ses2, SST_OK);
	  log_error ("Invalid UTF-8 data in writing utf8 into a session");
#ifndef NDEBUG
	  GPF_T;
#endif
	  return -1;
	}
      buf->space_exausted = space_exausted;
      buf->fill_chars += (int) nwc;
    }
  else
    {
      memcpy_16 (&buf->data[buf->fill], buffer, filled = MIN (bytes, space));
      buf->fill_chars += filled;
    }
  buf->fill += filled;
  return (filled);
}


/*##**********************************************************************
 *
 *		strdev_read
 *
 * Reads a string from a string session. This will read only as many bytes
 ( as are contiguously available in the string session. Higher levels will
 * call this several times to read long strings.
 *
 * Input params :	  - the string session, the target buffer, the count
 *		       - of bytes desired.
 *
 * Output params:    -
 *
 * Return value :    The number of bytes copied nto the target buffer.
 *
 * Limitations  :  The session needs to in read mode (c.f. strses_rewind)
 *
 * Globals used :
 */
static int
strdev_read (session_t * ses2, char *buffer, int bytes)
{
  dk_session_t *ses = SESSION_DK_SESSION (ses2);
  strdevice_t *strdev = (strdevice_t *) ses->dks_session->ses_device;
  /* the first data to read will be in the first element of the buffer
     chain. When the buffer chain is empty the data will be in the
     regular output buffer. */
  if (strdev->strdev_buffer_ptr)
    {
      /* take as much as needed from the first buffer */
      buffer_elt_t *buf = strdev->strdev_buffer_ptr;
      int count = MIN (buf->fill - buf->read, bytes);
      memcpy_16 (buffer, buf->data + buf->read, count);
      buf->read += count;
      if (buf->read == buf->fill)
	{
	  strdev->strdev_buffer_ptr = buf->next;
	}
      return (count);
    }
  else if (ses2->ses_file->ses_file_descriptor &&
  	   ses2->ses_file->ses_fd_read < ses2->ses_file->ses_fd_fill)
    {
      if (-1 == strf_lseek (ses2->ses_file, ses2->ses_file->ses_fd_read, SEEK_SET))
	{
	  SESSTAT_SET (ses2, SST_DISK_ERROR);
	  log_error ("Can't seek in file %s", ses2->ses_file->ses_temp_file_name);
	  return 0;
	}
      else
	{
	  int to_read = MIN (bytes, ses2->ses_file->ses_fd_fill - ses2->ses_file->ses_fd_read);
	  int readed;

	  readed = strf_read (ses2->ses_file, buffer, to_read);
	  if (readed > 0)
	    ses2->ses_file->ses_fd_read += readed;
	  else if (readed < 0)
	    {
	      log_error ("Can't read from file %s", ses2->ses_file->ses_temp_file_name);
	      SESSTAT_SET (ses2, SST_DISK_ERROR);
	    }
	  return readed;
	}
    }
  else
    {
      /* The data to be read is in the out buffer. Set the in buffer to
         be the out buffer, the read count to zero and the fill to the
         out buffer fill. Return the fill. */
      int count = MIN (ses->dks_out_fill - strdev->strdev_in_read, bytes);
      memcpy_16 (buffer, ses->dks_out_buffer + strdev->strdev_in_read, count);
      strdev->strdev_in_read += count;
      return (count);
    }
}


static int
strdev_free (device_t * dev)
{
  dk_free (dev->dev_funs, sizeof (devfuns_t));
  dk_free (dev, sizeof (strdevice_t));
  return (0);
}


#ifdef never
void
not_applicable ()
{
  printf ("Attempt to call a session function not available on string sessions");
#ifndef DLL
  fflush (stdout);
#endif
  call_exit (1);
}
#endif


/*##**********************************************************************
 *
 *		strdev_allocate
 *
 * Function used for allocating and initializing a new string output
 * session.
 *
 * Input params :	  - none
 *
 * Output params:    - none
 *
 * Return value :    pointer to new session instance
 *
 * Limitations  :
 *
 * Globals used :
 */
device_t *
DBG_NAME (strdev_allocate) (DBG_PARAMS_0)
{
  strdevice_t *strdev = (strdevice_t *) dk_alloc (sizeof (strdevice_t));
  device_t *dev = (device_t *) strdev;
  devfuns_t *devfuns = (devfuns_t *) dk_alloc (sizeof (devfuns_t));

  /* Initialize pointers */
  dev->dev_funs = devfuns;

  /* Set string session methods */
  dev->dev_funs->dfp_free = strdev_free;
#ifdef never
  dev->dev_funs->dfp_allocate = not_applicable;
  dev->dev_funs->dfp_set_address = not_applicable;
  dev->dev_funs->dfp_listen = not_applicable;
  dev->dev_funs->dfp_accept = not_applicable;
  dev->dev_funs->dfp_connect = not_applicable;
  dev->dev_funs->dfp_disconnect = not_applicable;
  dev->dev_funs->dfp_set_control = not_applicable;
#endif
  dev->dev_funs->dfp_read = strdev_read;
  dev->dev_funs->dfp_write = strdev_write;
  dev->dev_funs->dfp_flush = NULL;
  strdev->strdev_in_read = 0;
  strdev->strdev_buffer_ptr = NULL;
  strdev->strdev_is_utf8 = 0;
  return (dev);
}


#if 0
void
strses_rewind (dk_session_t * ses)
{
  /* No place you wanna be */
  GPF_T;

  /* In read mode the out buffer length serves as a count of bytes
     read from the out buffer. The out buffer fill is the length of the buffer
   */
  if (!ses->dks_in_buffer)
    {
      ses->dks_in_buffer = (char *) dk_alloc (DKSES_IN_BUFFER_LENGTH);
    }
  ses->dks_out_length = 0;
}
#endif


void
strses_map (dk_session_t * ses, void (*func) (buffer_elt_t * e, caddr_t arg), caddr_t arg)
{
  buffer_elt_t *buf = ses->dks_buffer_chain;
  buffer_elt_t *next;
  while (buf)
    {
      next = buf->next;
      func (buf, arg);
      buf = next;
    }
}


void
strses_file_map (dk_session_t * ses, void (*func) (buffer_elt_t * e, caddr_t arg), caddr_t arg)
{
  buffer_elt_t elt;
  unsigned char buffer[DKSES_IN_BUFFER_LENGTH];
  OFF_T offset;
  strsestmpfile_t *sesfile = (strsestmpfile_t *) ses->dks_session->ses_file;

  if (sesfile->ses_file_descriptor)
    {
      if (-1 == strf_lseek (sesfile, 0, SEEK_SET))
	{
	  log_error ("Can't seek in file %s", sesfile->ses_temp_file_name);
	  SESSTAT_SET (ses->dks_session, SST_DISK_ERROR);
	  return;
	}
      offset = 0;
      do
	{
	  int readbytes;

	  memset (&elt, 0, sizeof (elt));
	  elt.data = (char *) buffer;
	  readbytes = strf_read (sesfile, buffer,
		MIN (DKSES_IN_BUFFER_LENGTH, sesfile->ses_fd_fill - offset));
	  if (readbytes == -1)
	    {
	      log_error ("Can't read from file %s", sesfile->ses_temp_file_name);
	      SESSTAT_SET (ses->dks_session, SST_DISK_ERROR);
	      return;
	    }
	  elt.fill = readbytes;
	  func (&elt, arg);
	  offset += readbytes;
	}
      while (offset < sesfile->ses_fd_fill);
    }
}


void
strses_flush (dk_session_t * ses)
{
  strdevice_t *strdev = (strdevice_t *) ses->dks_session->ses_device;
  strsestmpfile_t *sesfile = (strsestmpfile_t *) ses->dks_session->ses_file;
  strses_map (ses, strdev_free_buf, NULL);
  ses->dks_buffer_chain = ses->dks_buffer_chain_tail = strdev->strdev_buffer_ptr = NULL;
  ses->dks_out_fill = strdev->strdev_in_read = 0;
  ses->dks_out_length = DKSES_OUT_BUFFER_LENGTH;
  ses->dks_bytes_sent = 0;
  ses->dks_cluster_flags = 0;
  if (ses->dks_in_buffer)
    {
      ses->dks_in_length = DKSES_OUT_BUFFER_LENGTH;
      ses->dks_in_fill = ses->dks_in_read = 0;
    }
  if (sesfile->ses_file_descriptor)
    {
      if (sesfile->ses_close_func)
	{
	  if (sesfile->ses_close_func (sesfile))
	    {
	      SESSTAT_SET (ses->dks_session, SST_DISK_ERROR);
	      log_error ("Can't close session tmp file");
	    }
	}
      else if (close (sesfile->ses_file_descriptor))
	{
	  SESSTAT_SET (ses->dks_session, SST_DISK_ERROR);
	  log_error ("Can't close session tmp file");
	}
      sesfile->ses_file_descriptor = 0;
      sesfile->ses_file_ctx = NULL;
      sesfile->ses_fd_read = 0;
      sesfile->ses_fd_fill = 0;
      sesfile->ses_fd_fill_chars = 0;
      dk_free_box (sesfile->ses_temp_file_name);
      sesfile->ses_max_blocks_in_mem = sesfile->ses_max_blocks_init;
    }
}


/*##**********************************************************************
 *
 *		strses_length
 *
 * Returns the count of bytes written this far into the string session.
 *
 * Input params :	  - The string session.
 *
 * Output params:    - none
 *
 * Return value :    The byte count.
 *
 * Limitations  :
 *
 * Globals used :
 */
int64
strses_length (dk_session_t * ses)
{
  int64 len = 0;
  buffer_elt_t *elt = ses->dks_buffer_chain;
  int fd = ses->dks_session->ses_file->ses_file_descriptor;
  while (elt)
    {
      len += elt->fill;
      elt = elt->next;
    }

  if (fd)
    {
      len += ses->dks_session->ses_file->ses_fd_fill;
    }

  return (len + ses->dks_out_fill);
}


int64
strses_chars_length (dk_session_t * ses)
{
  int64 len = 0;
  buffer_elt_t *elt = ses->dks_buffer_chain;
  int fd = ses->dks_session->ses_file->ses_file_descriptor;

  if (!strses_is_utf8 (ses))
    return strses_length (ses);

  while (elt)
    {
      len += elt->fill_chars;
      elt = elt->next;
    }

  if (fd)
    {
      len += ses->dks_session->ses_file->ses_fd_fill_chars;
    }


  if (ses->dks_out_fill)
    {
      size_t last_len;
      virt_mbstate_t mb;
      unsigned char *ptr = (unsigned char *) ses->dks_out_buffer;
      memset (&mb, 0, sizeof (mb));
      last_len = virt_mbsnrtowcs (NULL, &ptr, ses->dks_out_fill, 0, &mb);
      if (last_len != (size_t) - 1)
	len += (long) last_len;
    }
  return (len);
}


/*##**********************************************************************
 *
 *		strses_write_out
 *
 * Writes all data written into a string session into another session.
 *
 * Input params :
 *		ses    - The string session.
 *		out    - The session into which the data in the string
 *			 session is to be written.
 *
 * Output params:    - none
 *
 * Return value :
 *
 * Limitations  :
 *
 * Globals used :
 */
void
strses_write_out (dk_session_t * ses, dk_session_t * out)
{
  buffer_elt_t *elt = ses->dks_buffer_chain;
  strsestmpfile_t * ses_file = ses->dks_session->ses_file;

  while (elt)
    {
      session_flush_1 (out);
      if (0 == out->dks_out_fill)
	service_write (out, elt->data, elt->fill);
      else
      session_buffered_write (out, elt->data, elt->fill);	/* was: service_write, there was error when we have smth in buffer */
      elt = elt->next;
    }
  if (ses_file->ses_file_descriptor)
    {
      char buffer[DKSES_IN_BUFFER_LENGTH];
      size_t readed, to_read;
      OFF_T end = strf_lseek (ses_file, 0, SEEK_END);
      if (end == -1)
	{
	  log_error ("Can't seek in file %s", ses_file->ses_temp_file_name);
	  SESSTAT_SET (ses->dks_session, SST_DISK_ERROR);
	  return;
	}
      if (-1 == strf_lseek (ses_file, 0, SEEK_SET))
	{
	  log_error ("Can't seek in file %s", ses_file->ses_temp_file_name);
	  SESSTAT_SET (ses->dks_session, SST_DISK_ERROR);
	  return;
	}
      while (end)
	{
	  to_read = end < DKSES_IN_BUFFER_LENGTH ? (size_t) end : DKSES_IN_BUFFER_LENGTH;
	  readed = strf_read (ses_file, buffer, to_read);
	  if (readed != to_read)
	    log_error ("Can't read from file %s", ses_file->ses_temp_file_name);
	  if (-1 == readed)
	    {
	      SESSTAT_SET (ses->dks_session, SST_DISK_ERROR);
	    }
	  session_flush_1 (out);
	  session_buffered_write (out, buffer, to_read);
	  end = end - to_read;
	}
    }
  if (ses->dks_out_fill)
    session_buffered_write (out, ses->dks_out_buffer, ses->dks_out_fill);
}



char *
strses_elt_next (dk_session_t * ses, buffer_elt_t ** elt, int * pos_in_elt)
{
  if (!*elt)
    {
      (*pos_in_elt)++;
      return  &ses->dks_out_buffer[*pos_in_elt - 1];
    }
  if (*pos_in_elt < (*elt)->fill)
    {
      (*pos_in_elt)++;
      return ((*elt)->data + *pos_in_elt) - 1;
    }
  *elt = (*elt)->next;
  *pos_in_elt = 0;
  return  strses_elt_next (ses, elt, pos_in_elt);
}


void
strses_set_int32 (dk_session_t * ses, int64 offset, int32 val)
{
  buffer_elt_t *elt = ses->dks_buffer_chain;
  int64 pos = 0;
  while (elt)
    {
      if (offset < pos + elt->fill)
	{
	  int off_in_elt = offset - pos;
	  char * b1 = elt->data + off_in_elt;
	  char * b2, *b3, *b4;
	    off_in_elt++;
	  b2 = strses_elt_next (ses, &elt, &off_in_elt);
	  b3 = strses_elt_next (ses, &elt, &off_in_elt);
	  b4 = strses_elt_next (ses, &elt, &off_in_elt);
	  *b1 = val >> 24;
	  *b2 = val >> 16;
	  *b3 = val >> 8;
	  *b4 = val;
	  return;
	}
      pos += elt->fill;
      elt = elt->next;
    }
  if (ses->dks_out_fill + pos > offset + 3)
    {
      LONG_SET_NA (ses->dks_out_buffer + offset - pos, val);
    }
}


static unsigned char *
strses_skip_wchars (unsigned char *data, long nbytes, long ofs)
{
  virt_mbstate_t mb;
  unsigned char *data_ptr = data;

  memset (&mb, 0, sizeof (mb));
  while (ofs)
    {
      size_t sz = virt_mbrtowc (NULL, data_ptr,
	  VIRT_MB_CUR_MAX, &mb);
      if (sz == (size_t) - 1)
	return NULL;
      data_ptr += sz;
      ofs--;
    }
  return data_ptr;
}


long
strses_cp_utf8_to_utf8 (unsigned char *dest_ptr, unsigned char *src_ptr, long src_ofs, long copy_chars, void *state_data)
{
  unsigned char *src_ptr_in;
  long copied_bytes;
  virt_mbstate_t mb;

  src_ptr = strses_skip_wchars (src_ptr, copy_chars * VIRT_MB_CUR_MAX, src_ofs);
  if (!src_ptr)
    GPF_T;


  /* copy copy_chars utf8 blocks into the dest */
  src_ptr_in = src_ptr;
  memset (&mb, 0, sizeof (mb));
  while (copy_chars)
    {
      size_t sz = virt_mbrtowc (NULL, src_ptr,
	  VIRT_MB_CUR_MAX, &mb);
      if (sz == (size_t) - 1)
	GPF_T;
      memcpy (dest_ptr, src_ptr, sz);
      dest_ptr += sz;
      src_ptr += sz;
      copy_chars--;
    }

  copied_bytes = (src_ptr - src_ptr_in);
  if (state_data)
    *((long *) state_data) += copied_bytes;
  return copied_bytes;
}


void
strses_serialize (caddr_t strses_box, dk_session_t * ses)
{
  dk_session_t *strses = (dk_session_t *) strses_box;
  long len = strses_length (strses);
  long char_len = strses_chars_length (strses);
  int is_utf8 = strses_is_utf8 (strses);

  if (len < 255)
    {
      session_buffered_write_char (is_utf8 ? DV_WIDE : DV_SHORT_STRING_SERIAL, ses);
      session_buffered_write_char (len & 0xff, ses);
      strses_write_out (strses, ses);
    }
  else if (len < (long) (MAX_READ_STRING / (is_utf8 ? (2 + sizeof (wchar_t)) : 1)))
    {
      session_buffered_write_char (is_utf8 ? DV_LONG_WIDE : DV_LONG_STRING, ses);
      print_long (len, ses);
      strses_write_out (strses, ses);
    }
  else
    {
      long ofs = 0;
      char buffer[64000];
      buffer_elt_t *elt = strses->dks_buffer_chain;
      long ver = cdef_param (ses->dks_caller_id_opts, "__SQL_CLIENT_VERSION", 0);
      if (ver && ver < 2724)
	{
	  if (ses->dks_session)
	    {
	    report_read_error:
	      SESSTAT_CLR (ses->dks_session, SST_OK);
	      SESSTAT_SET (ses->dks_session, SST_BROKEN_CONNECTION);
	      ses->dks_to_close = 1;
	      call_disconnect_callback_func (ses);
	      if (ses->dks_session->ses_class != SESCLASS_STRING &&
	      	  SESSION_SCH_DATA (ses) &&
		  SESSION_SCH_DATA (ses)->sio_write_fail_on)
		longjmp_splice (&SESSION_SCH_DATA (ses)->sio_write_broken_context, 1);
	    }
	  return;
	}
      /* WIRE PROTO: the tag */
      session_buffered_write_char (DV_STRING_SESSION, ses);
      /* WIRE PROTO: flags : b1 = is utf8 */
      session_buffered_write_char (is_utf8 ? 1 : 0, ses);
      while (elt)
	{
	  session_buffered_write_char (DV_LONG_STRING, ses);
	  print_long (elt->fill, ses);
	  session_buffered_write (ses, elt->data, elt->fill);
	  ofs += elt->fill_chars;
	  elt = elt->next;
	}
      while (ofs < char_len)
	{
	  int to_read_chars = MIN (((int) sizeof (buffer)) / (is_utf8 ? VIRT_MB_CUR_MAX : 1), char_len - ofs);
	  long copied_bytes;
	  if (is_utf8)
	    {
	      long copied_utf8_bytes = 0;
	      if (0 != strses_get_part_1 (strses, buffer, ofs, to_read_chars,
		    (copy_func_ptr_t) strses_cp_utf8_to_utf8, &copied_utf8_bytes))
		goto report_read_error;
	      copied_bytes = copied_utf8_bytes;
	    }
	  else
	    {
	      if (0 != strses_get_part (strses, buffer, ofs, to_read_chars))
		goto report_read_error;
	      copied_bytes = to_read_chars;
	    }
	  /* WIRE PROTO: i-th segment */
	  session_buffered_write_char (DV_LONG_STRING, ses);
	  print_long (copied_bytes, ses);
	  session_buffered_write (ses, buffer, copied_bytes);
	  ofs += to_read_chars;
	}

      /* WIRE PROTO: zero len terminating string */
      session_buffered_write_char (DV_SHORT_STRING_SERIAL, ses);
      session_buffered_write_char (0, ses);
    }
}


caddr_t
strses_deserialize (dk_session_t * session, dtp_t macro)
{
  unsigned char flags;
  dk_session_t *strses;

  MARSH_CHECK_BOX (strses = strses_allocate ());

#if 0
  /* 10M in mem */
  strses_enable_paging (strses, 1024 * 1024 * 10);
#endif

  /* WIRE PROTO: flags */
  flags = session_buffered_read_char (session);
  strses_set_utf8 (strses, flags & 0x1);

  while (1)
    {
      caddr_t str;

      /* WIRE PROTO: i-th segment */
      str = (caddr_t) scan_session_boxing (session);

      if (str && DV_TYPE_OF (str) != DV_STRING)
	{					 /* being paranoid is a good thing */
	  dk_free_tree (str);
	  sr_report_future_error (session, "", "Invalid data type of the incoming session segment");
	  str = NULL;
	}

      if (!str)
	dk_free_tree ((box_t) strses);

      MARSH_CHECK_BOX (str);

      /* WIRE PROTO: zero len terminating string */
      if (box_length (str) == 1)
	{
	  dk_free_box (str);
	  break;
	}

      session_buffered_write (strses, str, box_length (str) - 1);

      dk_free_box (str);
    }
  return (caddr_t) strses;
}

/* a bit dangerous : buffer must have space for whole session length */
void
strses_to_array (dk_session_t * ses, char *buffer)
{
  strsestmpfile_t * ses_file = ses->dks_session->ses_file;

  buffer_elt_t *elt = ses->dks_buffer_chain;
  while (elt)
    {
      memcpy_16 (buffer, elt->data, elt->fill);
      buffer += elt->fill;
      elt = elt->next;
    }

  if (ses_file->ses_file_descriptor)
    {
      OFF_T rc, end = strf_lseek (ses_file, 0, SEEK_END);
      if (end == -1)
	{
	  log_error ("Can't seek in file %s", ses_file->ses_temp_file_name);
	  SESSTAT_SET (ses->dks_session, SST_DISK_ERROR);
	  return;
	}
      if (-1 == strf_lseek (ses_file, 0, SEEK_SET))
	{
	  log_error ("Can't seek in file %s", ses_file->ses_temp_file_name);
	  SESSTAT_SET (ses->dks_session, SST_DISK_ERROR);
	  return;
	}
      rc = strf_read (ses_file, buffer, end);
      if (rc != end)
	log_error ("Can't read from file %s", ses_file->ses_temp_file_name);
      if (rc == -1)
	SESSTAT_SET (ses->dks_session, SST_DISK_ERROR);
      buffer += end;
    }
  memcpy_16 (buffer, ses->dks_out_buffer, ses->dks_out_fill);
}


size_t
strses_fragment_to_array (dk_session_t * ses, char *buffer, size_t fragment_offset, size_t fragment_size)
{
  strsestmpfile_t * ses_file = ses->dks_session->ses_file;
  buffer_elt_t *elt;
  size_t tail_size = fragment_size;
  for (elt = ses->dks_buffer_chain; elt && tail_size; elt = elt->next)
    {
      size_t cut_sz = elt->fill;
      char *data = elt->data;
      if (fragment_offset)
	{
	  if (cut_sz <= fragment_offset)
	    {
	      fragment_offset -= cut_sz;
	      continue;
	    }
	  data += fragment_offset;
	  cut_sz -= fragment_offset;
	  fragment_offset = 0;
	}
      if (cut_sz > tail_size)
	cut_sz = tail_size;
      memcpy_16 (buffer, data, cut_sz);
      tail_size -= cut_sz;
      buffer += cut_sz;
    }
  if (ses_file->ses_file_descriptor && tail_size)
    {
      OFF_T rc, cut_sz = tail_size; /* if file is stream e.g. gzip, then we try to uncompress bytes number which is asked */
      if (!ses_file->ses_fd_is_stream) /* if it is regular file, we seek at the end */
	{
	  cut_sz = strf_lseek (ses_file, 0, SEEK_END);
	  if (cut_sz < 0 && !ses_file->ses_fd_is_stream)
	    {
	      log_error ("Can't seek in file %s", ses_file->ses_temp_file_name);
	  SESSTAT_SET (ses->dks_session, SST_DISK_ERROR);
	  return 0;
	}
	}
      if ((unsigned) cut_sz <= fragment_offset)
	{
	  fragment_offset -= cut_sz;
	  goto end_of_file_read;
	}
      if (-1 == strf_lseek (ses_file, fragment_offset, SEEK_SET))
	{
	  log_error ("Can't seek in file %s", ses_file->ses_temp_file_name);
	  SESSTAT_SET (ses->dks_session, SST_DISK_ERROR);
	  return 0;
	}
      cut_sz -= fragment_offset;
      fragment_offset = 0;
      if ((unsigned) cut_sz > tail_size)
	cut_sz = tail_size;
      rc = strf_read (ses_file, buffer, cut_sz);
      if (rc != cut_sz)
	log_error ("Can't read from file %s", ses_file->ses_temp_file_name);
      if (rc == -1)
	SESSTAT_SET (ses->dks_session, SST_DISK_ERROR);
      tail_size -= cut_sz;
      buffer += cut_sz;
    }

end_of_file_read:
  if (tail_size)
    {
      size_t cut_sz = ses->dks_out_fill;
      char *data = ses->dks_out_buffer;
      if (cut_sz <= fragment_offset)
	return 0;
      data += fragment_offset;
      cut_sz -= fragment_offset;
      if (cut_sz > tail_size)
	cut_sz = tail_size;
      memcpy_16 (buffer, data, cut_sz);
      tail_size -= cut_sz;
    }
  return fragment_size - tail_size;
}


void
strses_enable_paging (dk_session_t * ses, int max_bytes_in_mem)
{
  int parts = max_bytes_in_mem / DKSES_IN_BUFFER_LENGTH;
  ses->dks_session->ses_file->ses_max_blocks_in_mem = parts ? parts : 1;
  ses->dks_session->ses_file->ses_max_blocks_init = parts ? parts : 1;
  if (!ses->dks_in_buffer)
    {
      ses->dks_in_buffer = (char *) dk_alloc (DKSES_OUT_BUFFER_LENGTH);
      ses->dks_in_length = DKSES_OUT_BUFFER_LENGTH;
    }
}


caddr_t
DBG_NAME (strses_string) (DBG_PARAMS dk_session_t * ses)
{
  int64 len = strses_length (ses);
  caddr_t box;
  if (NULL == (box = DBG_NAME (dk_alloc_box) (DBG_ARGS len + 1, DV_LONG_STRING)))
    return NULL;
  strses_to_array (ses, box);
  box[len] = 0;
  return box;
}


caddr_t
DBG_NAME (strses_wide_string) (DBG_PARAMS dk_session_t * ses)
{
  int64 len = strses_length (ses);
  caddr_t box;
  if (NULL == (box = DBG_NAME (dk_alloc_box) (DBG_ARGS len + sizeof (wchar_t), DV_WIDE)))
    return NULL;
  strses_to_array (ses, box);
  ((wchar_t *)(box+len))[0] = 0;
  return box;
}


caddr_t
t_strses_string (dk_session_t * ses)
{
  int64 len = strses_length (ses);
  caddr_t box;
  box = t_alloc_box (len + 1, DV_LONG_STRING);
  strses_to_array (ses, box);
  box[len] = 0;
  return box;
}


void
strses_free (dk_session_t * ses)
{
  dk_free_box ((box_t) ses);
}


int
strses_destroy (dk_session_t * ses)
{
#ifndef NDEBUG
  if (0 >= ses->dks_refcount)
    GPF_T1 ("Invalid dks_refcount in strses_destroy()");
#endif
  ses->dks_refcount--;
  if (ses->dks_refcount)
    return 1;
  strses_flush (ses);
  dk_free (ses->dks_out_buffer, ses->dks_out_length);
  if (ses->dks_in_buffer)
    dk_free (ses->dks_in_buffer, ses->dks_in_length);
  dk_free (SESSION_SCH_DATA (ses), sizeof (scheduler_io_data_t));
  session_free (ses->dks_session);
  return 0;
}


long
strses_get_part_1 (dk_session_t * ses, void *buf2, int64 starting_ofs, long nbytes, copy_func_ptr_t cpf, void *state_data)
{
  unsigned char *buffer = (unsigned char *) buf2;
  long copybytes;
  buffer_elt_t *elt = ses->dks_buffer_chain;
  strsestmpfile_t * ses_file = ses->dks_session->ses_file;

  while (elt && nbytes)
    {
      if (elt->fill_chars > starting_ofs)
	{
	  long dest_copybytes;
	  dest_copybytes = copybytes = MIN (elt->fill_chars - starting_ofs, nbytes);

	  if (cpf)
	    dest_copybytes = cpf (buffer, elt->data, starting_ofs, copybytes, state_data);
	  else
	    memcpy_16 (buffer, elt->data + starting_ofs, copybytes);
	  buffer += dest_copybytes;
	  nbytes -= copybytes;
	  starting_ofs = 0;
	}
      else
	starting_ofs -= elt->fill_chars;
      elt = elt->next;
    }

  if (ses_file->ses_file_descriptor && nbytes)
    {
      if (ses_file->ses_fd_fill_chars > starting_ofs)
	{
	  if (strses_is_utf8 (ses))
	    {
	      int readed;
	      OFF_T skipchars;
	      unsigned char *buf2_out = buffer;

	      if (ses_file->ses_fd_curr_char_pos > starting_ofs ||
	          ses_file->ses_fd_curr_char_pos == 0)
		{				 /* if the file ptr is behind the requested one start from the beginning */
		  if (-1 == strf_lseek (ses_file, 0, SEEK_SET))
		    {
		      log_error ("Can't seek in file %s", ses_file->ses_temp_file_name);
		      SESSTAT_SET (ses->dks_session, SST_DISK_ERROR);
		      return 0;
		    }
		  skipchars = starting_ofs;
		  ses_file->ses_fd_curr_char_pos = 0;
		}
	      else
		skipchars = starting_ofs - ses_file->ses_fd_curr_char_pos;

	      /* now skip the skipchars */
	      if (-1 == read_wides_from_utf8_file (ses, skipchars, NULL, 0, NULL))
		{
		  ses->dks_session->ses_file->ses_fd_curr_char_pos = 0;
		  return 0;
		}
	      ses->dks_session->ses_file->ses_fd_curr_char_pos += skipchars;

	      /* it's time to read the actual data */
	      readed = read_wides_from_utf8_file (ses, nbytes, buffer, 1, &buf2_out);
	      if (-1 == readed)
		{
		  ses->dks_session->ses_file->ses_fd_curr_char_pos = 0;
		  return 0;
		}
	      ses->dks_session->ses_file->ses_fd_curr_char_pos += nbytes;

	      if (state_data)
		*((long *) state_data) += buf2_out - buffer;
	      buffer = buf2_out;
	      nbytes = readed;
	      starting_ofs = 0;
	    }
	  else
	    {
	      size_t readed;
	      size_t dest_readed;
	      if (-1 == strf_lseek (ses_file, starting_ofs, SEEK_SET))
		{
		  log_error ("Can't seek in file %s", ses_file->ses_temp_file_name);
		  SESSTAT_SET (ses->dks_session, SST_DISK_ERROR);
		  return 0;
		}
	      if (cpf)
		{
		  long src_n_bytes = nbytes;
		  unsigned char src_buffer[64000];
		  long dest_copybytes;
		  dest_readed = 0;
		  do
		    {
		      long to_read = MIN (sizeof (buffer), src_n_bytes);
		      readed = strf_read (ses_file, src_buffer, to_read);
		      if (readed == -1)
			break;
		      dest_copybytes = cpf (buffer + dest_readed, src_buffer, 0, readed, state_data);
		      dest_readed += dest_copybytes;
		      src_n_bytes -= readed;
		    }
		  while (src_n_bytes);
		}
	      else
		readed = strf_read (ses_file, buffer, nbytes);
	      if (readed == -1)
		{
		  SESSTAT_SET (ses->dks_session, SST_DISK_ERROR);
		  log_error ("Can't read from file %s", ses_file->ses_temp_file_name);
		  return 0;
		}
	      buffer += readed;
	      nbytes -= readed;
	      starting_ofs = 0;
	    }
	}
      else
	starting_ofs -= ses->dks_session->ses_file->ses_fd_fill_chars;
    }

  if (nbytes && ses->dks_out_fill)
    {
      long dest_copybytes;
      long last_len_chars;

      if (strses_is_utf8 (ses))
	{
	  virt_mbstate_t mb;
	  unsigned char *ptr = (unsigned char *) ses->dks_out_buffer;
	  memset (&mb, 0, sizeof (mb));
	  last_len_chars = virt_mbsnrtowcs (NULL, &ptr, ses->dks_out_fill, 0, &mb);
	  if (last_len_chars == (size_t) - 1)
	    GPF_T;
	}
      else
	last_len_chars = ses->dks_out_fill;

      if (last_len_chars > starting_ofs)
	{
	  dest_copybytes = copybytes = MIN (last_len_chars - starting_ofs, nbytes);
	  if (cpf)
	    dest_copybytes = cpf (buffer, ses->dks_out_buffer, starting_ofs, copybytes, state_data);
	  else
	    memcpy_16 (buffer, ses->dks_out_buffer + starting_ofs, copybytes);
	  buffer += dest_copybytes;
	  nbytes -= copybytes;
	}
    }


  return nbytes;
}


long
strses_get_part (dk_session_t * ses, void *buf2, int64 starting_ofs, long nbytes)
{
  return strses_get_part_1 (ses, buf2, starting_ofs, nbytes, NULL, NULL);
}


long
read_wides_from_utf8_file (
    dk_session_t * ses,
    long nchars,
    unsigned char *dest,
    int copy_as_utf8,
    unsigned char **dest_ptr_out)
{
  unsigned char src_buffer[64000];
  virt_mbstate_t mb;

  memset (&mb, 0, sizeof (mb));
  while (nchars)
    {
      long to_read_bytes = MIN (sizeof (src_buffer), nchars * VIRT_MB_CUR_MAX);
      long readed;
      unsigned char *data_ptr = &src_buffer[0];
      size_t converted;

      /* read a buffer full */
      readed = strf_read (ses->dks_session->ses_file, src_buffer, to_read_bytes);
      if (-1 == readed)
	{
	  log_error ("Can't read in file %s", ses->dks_session->ses_file->ses_temp_file_name);
	  SESSTAT_SET (ses->dks_session, SST_DISK_ERROR);
	  return -1;
	}
      else if (0 == readed)
	break;

      if (copy_as_utf8)
	{
	  unsigned char *dest_ptr = dest;
	  virt_mbstate_t mb;

	  memset (&mb, 0, sizeof (mb));

	  while (nchars && (dest_ptr - dest) < readed)
	    {
	      size_t sz = virt_mbrtowc (NULL, data_ptr,
		  VIRT_MB_CUR_MAX, &mb);
	      if (sz == (size_t) - 1)
		{
		  log_error ("Invalid utf-8 data in file %s", ses->dks_session->ses_file->ses_temp_file_name);
		  SESSTAT_SET (ses->dks_session, SST_DISK_ERROR);
		  return -1;
		}
	      memcpy_16 (dest_ptr, data_ptr, sz);
	      dest_ptr += sz;
	      data_ptr += sz;
	      nchars--;
	    }
	  if (dest_ptr_out)
	    *dest_ptr_out = dest_ptr;
	}
      else
	{
	  converted = virt_mbsnrtowcs ((wchar_t *) dest, &data_ptr, readed, nchars, &mb);
	  if (converted == (size_t) - 1)
	    {
	      log_error ("Invalid utf-8 data in file %s", ses->dks_session->ses_file->ses_temp_file_name);
	      SESSTAT_SET (ses->dks_session, SST_DISK_ERROR);
	      return -1;
	    }
	  nchars = (long) converted;
	}

      if (data_ptr - &src_buffer[0] < readed)
	{					 /* there are some bytes left unconverted, unwind them for the next go */
	  if (-1 == strf_lseek (ses->dks_session->ses_file, -(readed - (data_ptr - &src_buffer[0])), SEEK_CUR))
	    {
	      log_error ("Can't seek in file %s", ses->dks_session->ses_file->ses_temp_file_name);
	      SESSTAT_SET (ses->dks_session, SST_DISK_ERROR);
	      return -1;
	    }
	}
    }
  return nchars;
}


long
strses_get_wide_part (dk_session_t * ses, wchar_t * buf, long starting_ofs, long nchars)
{
  buffer_elt_t *elt = ses->dks_buffer_chain;
  int fd = ses->dks_session->ses_file->ses_file_descriptor;
  virt_mbstate_t mb;

  while (elt && nchars)
    {
      if (elt->fill_chars > starting_ofs)
	{
	  long copychars = MIN (elt->fill_chars - starting_ofs, nchars);
	  unsigned char *data_ptr;

	  /* skip starting_ofs wide chars */
	  data_ptr = strses_skip_wchars ((unsigned char *) elt->data, elt->fill, starting_ofs);
	  if (!data_ptr)
	    return 0;

	  /* get the copychars worth of wides into the buffer */
	  if (virt_mbsnrtowcs (buf, &data_ptr,
		elt->fill - (data_ptr - (unsigned char *) elt->data), copychars, &mb) == (size_t) -1)
	    return 0;

	  buf += copychars;
	  nchars -= copychars;
	  starting_ofs = 0;
	}
      else
	starting_ofs -= elt->fill_chars;
      elt = elt->next;
    }

  if (fd && nchars)
    {
      if (ses->dks_session->ses_file->ses_fd_fill_chars > starting_ofs)
	{
	  size_t readed;
	  OFF_T skipchars;
	  if (ses->dks_session->ses_file->ses_fd_curr_char_pos > starting_ofs ||
	      ses->dks_session->ses_file->ses_fd_curr_char_pos == 0)
	    {					 /* if the file ptr is behind the requested one start from the begining */
	      if (-1 == strf_lseek (ses->dks_session->ses_file, 0, SEEK_SET))
		{
		  log_error ("Can't seek in file %s", ses->dks_session->ses_file->ses_temp_file_name);
		  SESSTAT_SET (ses->dks_session, SST_DISK_ERROR);
		  return 0;
		}
	      skipchars = starting_ofs;
	      ses->dks_session->ses_file->ses_fd_curr_char_pos = 0;
	    }
	  else
	    skipchars = starting_ofs - ses->dks_session->ses_file->ses_fd_curr_char_pos;

	  /* now skip the skipchars */
	  if (-1 == read_wides_from_utf8_file (ses, skipchars, NULL, 0, NULL))
	    {
	      ses->dks_session->ses_file->ses_fd_curr_char_pos = 0;
	      return 0;
	    }
	  ses->dks_session->ses_file->ses_fd_curr_char_pos += skipchars;

	  /* it's time to read the actual data */
	  readed = read_wides_from_utf8_file (ses, nchars, (unsigned char *) buf, 0, NULL);
	  if (-1 == readed)
	    {
	      ses->dks_session->ses_file->ses_fd_curr_char_pos = 0;
	      return 0;
	    }
	  ses->dks_session->ses_file->ses_fd_curr_char_pos += nchars;

	  buf += (nchars - readed);
	  nchars = readed;
	  starting_ofs = 0;
	}
      else
	starting_ofs -= ses->dks_session->ses_file->ses_fd_fill_chars;
    }

  if (nchars)
    {
      unsigned char *data_ptr = (unsigned char *) ses->dks_out_buffer, *data_ptr_start;
      long converted = 0;

      memset (&mb, 0, sizeof (mb));
      /* skip starting_ofs wide chars */
      data_ptr_start = strses_skip_wchars (data_ptr, ses->dks_out_fill, starting_ofs);
      if (!data_ptr_start)
	return 0;

      if ((data_ptr - data_ptr_start) < ses->dks_out_fill)
	{
	  /* get the copychars worth of wides into the buffer */
	  if ((converted = virt_mbsnrtowcs (buf, &data_ptr_start,
	  	ses->dks_out_fill - (data_ptr - data_ptr_start), nchars, &mb) == (size_t) - 1))
	    return 0;
	}

      buf += converted;
      nchars -= converted;
    }

  return nchars;
}


void
strses_set_utf8 (dk_session_t * ses, int is_utf8)
{
  if (ses->dks_session->ses_class == SESCLASS_STRING)
    ((strdevice_t *) (ses->dks_session->ses_device))->strdev_is_utf8 = is_utf8 ? 1 : 0;
}


int
strses_is_utf8 (dk_session_t * ses)
{
  return ses->dks_session->ses_class == SESCLASS_STRING &&
  	 ((strdevice_t *) (ses->dks_session->ses_device))->strdev_is_utf8 ? 1 : 0;
}


dk_session_t *
DBG_NAME (strses_allocate) (DBG_PARAMS_0)
{
  dk_session_t *dk_ses = (dk_session_t *) DBG_NAME (dk_alloc_box_zero) (DBG_ARGS sizeof (dk_session_t),
      DV_STRING_SESSION);
  session_t *ses = session_allocate (SESCLASS_STRING);

  /*memset (dk_ses, 0, sizeof (dk_session_t)); */

  SESSION_SCH_DATA (dk_ses) = (scheduler_io_data_t *) DBG_NAME (dk_alloc) (DBG_ARGS sizeof (scheduler_io_data_t));
  memset (SESSION_SCH_DATA (dk_ses), 0, sizeof (scheduler_io_data_t));

  ses->ses_client_data = (void *) dk_ses;
  if (!ses->ses_device)
    ses->ses_device = DBG_NAME (strdev_allocate) (DBG_ARGS_0);

  dk_ses->dks_session = ses;
  SESSION_DK_SESSION (ses) = dk_ses;		 /* two way link. */

  dk_ses->dks_out_buffer = (char *) DBG_NAME (dk_alloc) (DBG_ARGS DKSES_OUT_BUFFER_LENGTH);
  dk_ses->dks_out_length = DKSES_OUT_BUFFER_LENGTH;
/* No need, we have dk_alloc_box_zero above
  dk_ses->dks_out_fill = 0;

  dk_ses->dks_in_buffer = NULL;
  dk_ses->dks_in_fill = 0;
  dk_ses->dks_in_read = 0;

  dk_ses->dks_buffer_chain = NULL;
*/
  dk_ses->dks_refcount = 1;
  return (dk_ses);
}


/*##**********************************************************************
 *
 *		strdev_ws_chunked_write
 *
 * Implementation of the HTTP chunked protocol
 *
 * Input params :	  - The string session, the string to append
 &		       - the number of bytes to append.
 *
 * Output params:    - none
 *
 * Return value :    the number of bytes effectively added to the string session.
 *
 * Limitations  :   - The algorithm is poor, the session needs to be in write mode.
 *
 * Globals used :
 */
static int
strdev_ws_chunked_write (session_t * ses2, char *buffer, int bytes)
{
  dk_session_t *ses = SESSION_DK_SESSION (ses2);
  strdevice_t *strdev = (strdevice_t *) ses->dks_session->ses_device;
  dk_session_t *http_ses = (dk_session_t *) ses->dks_fixed_thread;
  int filled;
  buffer_elt_t *buf = ses->dks_buffer_chain_tail;
  long space;


  if (!buf)
    buf = strdev_get_buf (ses);

  space = DKSES_OUT_BUFFER_LENGTH - buf->fill;

  SESSTAT_SET (ses->dks_session, SST_OK);
  if (strdev->strdev_in_read && !buf->fill && bytes >= ses->dks_out_length && !buf->read && ses2->ses_device)
    {
      buf->read = strdev->strdev_in_read;
      strdev->strdev_in_read = 0;
    }
  memcpy_16 (&buf->data[buf->fill], buffer, filled = MIN (bytes, space));
  buf->fill += filled;

  if (buf->fill == DKSES_OUT_BUFFER_LENGTH)
    {
#ifndef NDEBUG
      if (SESSION_SCH_DATA (http_ses)->sio_write_fail_on)
	GPF_T;
#endif
      CATCH_WRITE_FAIL (http_ses)
      {
	char tmp[20];
	snprintf (tmp, sizeof (tmp), "%x\r\n", DKSES_OUT_BUFFER_LENGTH);
	SES_PRINT (http_ses, tmp);
	session_buffered_write (http_ses, buf->data, DKSES_OUT_BUFFER_LENGTH);
	SES_PRINT (http_ses, "\r\n");
	buf->fill = 0;
	session_flush_1 (http_ses);

      }
      FAILED
      {
	filled = bytes;
      }
      END_WRITE_FAIL (http_ses);
    }

  return (filled);
}


int
strses_is_ws_chunked_output (dk_session_t * ses)
{
  return (ses->dks_session->ses_device->dev_funs->dfp_write == strdev_ws_chunked_write);
}


void
strses_ws_chunked_state_set (dk_session_t * ses, dk_session_t * http_ses)
{
  ses->dks_session->ses_device->dev_funs->dfp_write = strdev_ws_chunked_write;
  ses->dks_fixed_thread = (du_thread_t *) http_ses;
}


void
strses_ws_chunked_state_reset (dk_session_t * ses)
{
  ses->dks_session->ses_device->dev_funs->dfp_write = strdev_write;
  ses->dks_fixed_thread = NULL;
}


#ifdef MALLOC_DEBUG
#undef strses_allocate
dk_session_t *
strses_allocate (void)
{
  return dbg_strses_allocate (__FILE__, __LINE__);
}


#undef strses_string
caddr_t
strses_string (dk_session_t * ses)
{
  return dbg_strses_string (__FILE__, __LINE__, ses);
}


#undef strses_wide_string
caddr_t
strses_wide_string (dk_session_t * ses)
{
  return dbg_strses_wide_string (__FILE__, __LINE__, ses);
}
#endif

caddr_t
strses_fake_copy (caddr_t orig)
{
  dk_session_t *orig_ses = (dk_session_t *) orig;
#ifndef NDEBUG
  if (0 >= orig_ses->dks_refcount)
    GPF_T1 ("Invalid dks_refcount in strses_fake_copy()");
#endif
  orig_ses->dks_refcount += 1;
  return orig;
}


caddr_t
strses_mp_copy (mem_pool_t * mp, caddr_t box)
{
  strses_fake_copy (box);
  dk_set_push (&mp->mp_trash, (void *) box);
  return box;
}


void
strses_mem_initalize (void)
{
  dk_mem_hooks_2 (DV_STRING_SESSION, strses_fake_copy, (box_destr_f) strses_destroy, 1, strses_mp_copy);
}


void
strses_readtable_initialize (void)
{
  macro_char_func *rt = get_readtable ();
  PrpcSetWriter (DV_STRING_SESSION, (ses_write_func) strses_serialize);
  rt[DV_STRING_SESSION] = (macro_char_func) strses_deserialize;
}
