/*
 *  Dkses2.h
 *
 *  $Id$
 *
 *  Upper layer sessions
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

#include "Dk.h"

static int
unfreeze_thread_read (dk_session_t * ses)
{
  SESSION_SCH_DATA (ses)->sio_random_read_ready_action = NULL;

  if (!SESSION_SCH_DATA (ses)->sio_default_read_ready_action)
    remove_from_served_sessions (ses);

  semaphore_leave (SESSION_SCH_DATA (ses)->sio_reading_thread->thr_sem);

  return 0;
}


static int
unfreeze_thread_write (dk_session_t * ses)
{
  SESSION_SCH_DATA (ses)->sio_random_write_ready_action = NULL;

  /* in a direct io situation the session is not in the served set */
  if (SESSION_SCH_DATA (ses)->sio_random_read_ready_action == NULL &&
      SESSION_SCH_DATA (ses)->sio_default_read_ready_action == NULL)
    {
      /* if there is no other action on the session, remove it  from served sessions. */
      remove_from_served_sessions (ses);
    }

  ss_dprintf_4 (("Write in thread %p resumed.", (void *) (SESSION_SCH_DATA (ses)->sio_writing_thread)));

  semaphore_leave (SESSION_SCH_DATA (ses)->sio_writing_thread->thr_sem);
  return 0;
}


static void
freeze_thread_write (dk_session_t * ses)
{
  USE_GLOBAL
  SESSION_SCH_DATA (ses)->sio_random_write_ready_action = unfreeze_thread_write;
  SESSION_SCH_DATA (ses)->sio_writing_thread = current_process;
  add_to_served_sessions (ses);

  ss_dprintf_4 (("Write on Thread %p blocked.", (void *) current_process));

  semaphore_enter (current_process->thr_sem);
}


/*
 * Used as random read ready action when a session is being
 * directly read by a thread other than the server thread
 */
void
random_read_ready_while_direct_io (void)
{
  PROCESS_ALLOW_SCHEDULE ();
}


int
service_write (dk_session_t * ses, char *buffer, int bytes)
{
  USE_GLOBAL
  int last_written = 0;
  int rc;

  DBG_CHECK_WRITE_FAIL (ses);
  if (!ses->dks_session)
    {
      longjmp_splice (&SESSION_SCH_DATA (ses)->sio_write_broken_context, 1);
    }
  while (bytes > 0)
    {
      without_scheduling_tic ();
      rc = session_write (ses->dks_session, &(buffer[last_written]), bytes);
      restore_scheduling_tic ();
      if (rc == 0)
	PROCESS_ALLOW_SCHEDULE ();
      if (rc > 0)
	{
	  bytes = bytes - rc;
	  last_written = last_written + rc;
	}
      if (rc < 0)
	{
	  if (SESSTAT_W_ISSET (ses->dks_session, SST_INTERRUPTED))
	    {
	      PROCESS_ALLOW_SCHEDULE ();
	    }
	  else if (SESSTAT_W_ISSET (ses->dks_session, SST_BLOCK_ON_WRITE))
	    {
	      if (!_thread_sched_preempt)
		freeze_thread_write (ses);
	      else
		{
		  timeout_t tv = { 100, 0 };
		  if (ses->dks_write_block_timeout.to_sec > 0)
		    tv.to_sec = ses->dks_write_block_timeout.to_sec;
		retry:
		  tcpses_is_write_ready (ses->dks_session, &tv);
		  if (SESSTAT_W_ISSET (ses->dks_session, SST_TIMED_OUT))
		    {
		      scheduler_io_data_t * sio = SESSION_SCH_DATA (ses);
		      if (sio->sio_w_timeout_hook && sio->sio_w_timeout_hook (ses))
			{
			  SESSTAT_W_CLR (ses->dks_session, SST_TIMED_OUT);
			  goto retry;
			}
		      SESSTAT_W_SET (ses->dks_session, SST_BROKEN_CONNECTION);
		      longjmp_splice (&SESSION_SCH_DATA (ses)->sio_write_broken_context, 1);
		    }
		}
	    }
	  else
	    {
	      ses->dks_bytes_sent += last_written;
	      ss_dprintf_2 (("Unrecognized I/O error rc=%d errno=%d  in service_write", rc, errno));
	      SESSTAT_W_CLR (ses->dks_session, SST_OK);
	      SESSTAT_W_SET (ses->dks_session, SST_BROKEN_CONNECTION);
	      longjmp_splice (&SESSION_SCH_DATA (ses)->sio_write_broken_context, 1);
	    }
	}
    }
  ses->dks_bytes_sent += last_written;
  return 0;
}


/*##**********************************************************************

 *              session_flush
 *
 * This writes out the data in the session's output buffer. This operation
 * does not make sense for a string output session. Therefore check.
 *
 * Assumes that caller holds dks_mtx.
 *
 * Input params :        - dk_session
 *
 * Output params:    -
 *
 * Return value :    SER_SUCC if write was successful.
 *                   SER_FAIL if not. If failed the status of the
 *                      session is set accordingly.
 *
 * Limitations  :
 *
 * Globals used :    default controls
 */
int
session_flush_1 (dk_session_t * ses)
{
  if (!ses->dks_session || (ses->dks_session->ses_class == SESCLASS_STRING && !ses->dks_session->ses_file->ses_file_descriptor))
    return (SER_SUCC);
  if (ses->dks_out_fill)
    {
      int rc = service_write (ses, ses->dks_out_buffer, ses->dks_out_fill);
      ses->dks_out_fill = 0;
      return (rc);
    }
  return (SER_SUCC);
}


int
session_flush (dk_session_t * session)
{
  int ret = SER_SUCC;
  if (NULL != session->dks_mtx)
    mutex_enter (session->dks_mtx);
  CATCH_WRITE_FAIL (session)
  {
    session_flush_1 (session);
    ret = SER_SUCC;
  }
  FAILED
  {
    ret = SER_FAIL;
  }
  END_WRITE_FAIL (session);
  if (NULL != session->dks_mtx)
    mutex_leave (session->dks_mtx);
  return (ret);
}


/*##**********************************************************************

 *              session_buffered_write
 *
 * This adds the string to the output buffer. The output buffer
 * if flushed if needed.
 *
 * Input params :        - session
 *                         pointer to string to write
 *                         bytes to write
 *
 * Output params:    -
 *
 * Return value :    SER_SUCC if write was successful.
 *                   SER_FAIL if not. If failed the status of the
 *                      session is set accordingly.
 *
 * Limitations  :
 *
 * Globals used :    default controls
 */
int
session_buffered_write (dk_session_t * ses, const char *buffer, size_t _length)
{
  int length = (int) _length;
  DBG_CHECK_WRITE_FAIL (ses);

  /* will the string fit ? */
  if (length <= ses->dks_out_length - ses->dks_out_fill)
    {
      memcpy (&ses->dks_out_buffer[ses->dks_out_fill], buffer, length);
      ses->dks_out_fill = ses->dks_out_fill + length;
    }
  else
    {
      /* fill the buffer, write out and write the rest in one call */
      int written;
      if (!ses->dks_session)
	{
	  ses->dks_out_fill = ses->dks_out_length;
	  return 0;
	}

      if (strses_is_utf8 (ses))
	{
	  written = utf8_align_memcpy (&ses->dks_out_buffer[ses->dks_out_fill], buffer,
		ses->dks_out_length - ses->dks_out_fill, NULL, NULL);
	  if (written == -1)
	    {
	      SESSTAT_CLR (ses->dks_session, SST_OK);
	      SESSTAT_SET (ses->dks_session, SST_BROKEN_CONNECTION);
	      longjmp_splice (&SESSION_SCH_DATA (ses)->sio_write_broken_context, 1);
	    }
	  service_write (ses, ses->dks_out_buffer, ses->dks_out_fill + written);
	}
      else
	{
	  memcpy (&ses->dks_out_buffer[ses->dks_out_fill], buffer,
		written = ses->dks_out_length - ses->dks_out_fill);
	  service_write (ses, ses->dks_out_buffer, ses->dks_out_length);
	}
      if (length - written > ses->dks_out_length)
	{
	  service_write (ses, (char *) &buffer[written], length - written);
	  ses->dks_out_fill = 0;
	}
      else
	{
	  memcpy (ses->dks_out_buffer, &buffer[written], length - written);
	  ses->dks_out_fill = length - written;
	}
    }
  if (ses->dks_session && ses->dks_session->ses_file && ses->dks_session->ses_file->ses_file_descriptor)
    session_flush_1 (ses);
  return 0;
}


#if 0
void
session_buffered_write_char (unsigned char ch, dk_session_t * ses)
{
  if (ses->dks_out_fill >= ses->dks_out_length)
    {
      if (!ses->dks_session)
	return;
      service_write (ses, ses->dks_out_buffer, ses->dks_out_fill);
      ses->dks_out_buffer[0] = ch;
      ses->dks_out_fill = 1;
    }
  else
    {
      ses->dks_out_buffer[ses->dks_out_fill] = ch;
      ses->dks_out_fill++;
    }
}


#else

void
session_buffered_write_char (int c, dk_session_t * ses)
{
  dtp_t ch = (dtp_t) c;

  if (ses->dks_out_fill >= ses->dks_out_length)
    {
      if (!ses->dks_session)
	return;
      service_write (ses, ses->dks_out_buffer, ses->dks_out_fill);
      ses->dks_out_buffer[0] = ch;
      ses->dks_out_fill = 1;
    }
  else
    ses->dks_out_buffer[ses->dks_out_fill++] = ch;
}
#endif


/*
   service_read ()

   Used to read from a session. Handles scheduling
   if the session would block.

   Used for reading from a service thread. If the read would block,
   put the thread to wait. When the scheduling cycle sees input on this
   session the random_input_ready_action is called.
   This wakes up this thread and schedules it for execution on the next
   round

   The need_all argument controls whether this function may return after reading
   fewer than the requested number of bytes. This function always reads at
   least 1 byte.

   If the calling thread is the scheduling thread and io would block, this
   allows schedule and recursively blocks on all pending i/o.
   If the calling thread is some other thread, this disables
   the thread and tells the scheduler to resume this when the input is ready.

   Returns the number of bytes read.
 */
int
service_read (dk_session_t * ses, char *buffer, int req_bytes, int need_all)
{
  USE_GLOBAL
  int last_read = 0;
  int bytes = req_bytes;
  du_thread_t *cur_proc;	/* mty NEW */
  int rc;

  DBG_CHECK_READ_FAIL (ses);

  while (bytes > 0)
    {
      without_scheduling_tic ();
      if (!ses->dks_is_read_select_ready && ses->dks_session && ses->dks_session->ses_class != SESCLASS_STRING)
	{
	  tcpses_is_read_ready (ses->dks_session, &ses->dks_read_block_timeout);
	  if (DKSESSTAT_ISSET (ses, SST_TIMED_OUT))
	    rc = -1;
	  else
	    rc = session_read (ses->dks_session, &(buffer[last_read]), bytes);
	}
      else
	{
	  if (!ses->dks_session)
	    longjmp_splice (&(SESSION_SCH_DATA (ses)->sio_read_broken_context), 1);

	  rc = session_read (ses->dks_session, &(buffer[last_read]), bytes);
	}
      ses->dks_is_read_select_ready = 0;
      restore_scheduling_tic ();

      if (rc == 0)
	PROCESS_ALLOW_SCHEDULE ();
      else if (rc > 0)
	{
	  bytes = bytes - rc;
	  last_read = last_read + rc;
	  if (!need_all)
	    {
	      ses->dks_bytes_received += last_read;
	      return (last_read);
	    }
	}
      if (rc <= 0)
	{
	  if (SESSTAT_ISSET (ses->dks_session, SST_INTERRUPTED))
	    {
	      PROCESS_ALLOW_SCHEDULE ();
	    }
	  else if (SESSTAT_ISSET (ses->dks_session, SST_BLOCK_ON_READ))
	    {
	      /* would block. suspend thread */

	      cur_proc = current_process;	 /* mty NEW */
	      if (!PROCESS_TO_DK_THREAD (cur_proc))
		{
		  /* We have a block on a server thread. We recognize it
		   * because a server thread is not associated to a request.
		   * The read would block the server thread. Run others and
		   * do a recursive check_inputs to resume other threads that
		   * may now be ready for i/o. Do a timeout round to unblock
		   * threads waiting on timed-out futures if the select times
		   * out. Finally retry read.
		   */
		  int rc2;
		  PROCESS_ALLOW_SCHEDULE ();
		  rc2 = check_inputs (PASS_G & atomic_timeout, 1);
		  if (rc2 == 0)
		    timeout_round (PASS_G ses);
		}
	      else
		{
		  SESSION_SCH_DATA (ses)->sio_random_read_ready_action = unfreeze_thread_read;
		  SESSION_SCH_DATA (ses)->sio_reading_thread = cur_proc;
		  add_to_served_sessions (ses);
		  semaphore_enter (cur_proc->thr_sem);
		}
	    }
	  else if (1 ||				 /* ?? */
	      SESSTAT_ISSET (ses->dks_session, SST_TIMED_OUT) || SESSTAT_ISSET (ses->dks_session, SST_BROKEN_CONNECTION))
	    {
	      SESSTAT_CLR (ses->dks_session, SST_OK);
	      SESSTAT_SET (ses->dks_session, SST_BROKEN_CONNECTION);

	      longjmp_splice (&(SESSION_SCH_DATA (ses)->sio_read_broken_context), 1);
	    }
	  else
	    {
	      ses->dks_bytes_received += last_read;

	      ss_dprintf_2 (("Unrecognized I/O error rc=%d errno=%d in service_read.", rc, errno));
	      longjmp_splice (&(SESSION_SCH_DATA (ses)->sio_read_broken_context), 1);
	    }
	}
    }
  ses->dks_bytes_received += last_read;
  return (last_read);
}


/*##**********************************************************************

 *              session_buffered_read
 *
 * If input buffer contains enough data, copies the data into the buffer
 * Else :
 * 1) if we want more than a buffer full, we read straight into the target.
 * 2) if we want less, we fill the buffer until there is enough and then copy
 * the data into the target and leave whatever else was read in the buffer.
 * I/O errors are handled in service_read. This always returns successfully.
 *
 * Input params :        - session, buffer, byte count.
 *
 * Output params:    - buffer, session updated
 *
 * Return value :    bytes read.
 *
 * Limitations  :
 *
 * Globals used :    default controls
 */
int
session_buffered_read (dk_session_t * ses, char *buffer, int req_bytes)
{
  if (ses->dks_in_fill - ses->dks_in_read >= req_bytes)
    {
      memcpy (buffer, &ses->dks_in_buffer[ses->dks_in_read], req_bytes);
      ses->dks_in_read = ses->dks_in_read + req_bytes;
      return (req_bytes);
    }
  else
    {
      int bytes_read = 0;
      int bytes_from_previous;

      /* Move the stuff in the buffer to target.
         If there's more than a buffer full needed, read into the target
         if less, fill the buffer. */
      memcpy (buffer, &ses->dks_in_buffer[ses->dks_in_read],
	    bytes_from_previous = bytes_read = ses->dks_in_fill - ses->dks_in_read);
      ses->dks_in_read = ses->dks_in_fill;
      if (req_bytes > ses->dks_in_length)
	{
	  int rc = service_read (ses, &buffer[bytes_read],
	      req_bytes - bytes_read, 1);
	  if (rc < 0)
	    return (rc);
	  else
	    return (req_bytes);
	}
      else
	{
	  int rc;
	  int bytes_to_fill = ses->dks_in_length;
	  int bytes_filled = 0;

	  while (1)
	    {
	      rc = service_read (ses, &ses->dks_in_buffer[bytes_filled], bytes_to_fill, 0);
	      if (rc > 0)
		{
		  bytes_read = bytes_read + rc;
		  bytes_filled = bytes_filled + rc;
		  bytes_to_fill = bytes_to_fill - rc;
		  if (bytes_read >= req_bytes)
		    {
		      ses->dks_in_fill = bytes_filled;
		      ses->dks_in_read = req_bytes - bytes_from_previous;
		      memcpy (&buffer[bytes_from_previous], ses->dks_in_buffer, ses->dks_in_read);
		      return (req_bytes);
		    }
		}
	      else
		{
		  return (rc);
		}
	    }
	}
    }
}


/*##**********************************************************************

 *              session_buffered_read_char
 *
 * Reads one character fro the session's input buffer. If buffer empty
 * fills buffer.
 *
 * Input params :
 *
 *      ses     session to read.
 *
 * Output params: - none
 *
 * Return value : character read.
 *
 *
 * Limitations  :
 *
 *
 * Globals used : - none
 */
dtp_t
session_buffered_read_char (dk_session_t * ses)
{
#if 0
  dtp_t c;
  if (ses->dks_in_read < ses->dks_in_fill)
    return (dtp_t) ses->dks_in_buffer[ses->dks_in_read++];

  session_buffered_read (ses, &c, (size_t) 1);
  return c;
#else
  char c;
  int point = ses->dks_in_read;

  DBG_CHECK_READ_FAIL (ses);
  if (point < ses->dks_in_fill)
    {
      ses->dks_in_read = point + 1;
      return (ses->dks_in_buffer[point]);
    }
  else
    {
      session_buffered_read (ses, &c, 1);
      return (c);
    }
#endif
}
