/*
 *  Dksession.c
 *
 *  $Id$
 *
 *  Sessions
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

#include "Dk.h"

extern int tcpses_select (int ses_count, session_t ** reads, session_t ** writes, timeout_t * timeout);
extern int nmpses_select (int ses_count, session_t ** reads, session_t ** writes, timeout_t * timeout);


static timeout_t deftimeout = SDC_TIMEOUT;
static control_t defctrl = { SDC_BLOCKING, &deftimeout, SDC_MSGLEN };

static int get_control (control_t * ctrl, int fld, char *val, int sz);



/*##**********************************************************************\
 *
 *              session_allocate
 *
 * Function used for allocating and initializing a new session instance.
 * Use session_free for deallocating.
 * After allocation the session is in default mode.
 *
 * Input params :
 *
 *      sesclass        - session class (defines communication device)
 *
 * Output params:   - none
 *
 * Return value :
 *
 *          NULL, allocation failed
 *          !NULL, pointer to new session object
 *
 * Limitations  :   - none
 *
 * Globals used :    defctrl (default control)
 */
session_t *
session_allocate (int sesclass)
{
  session_t *ses = (session_t *) malloc (sizeof (session_t));
  timeout_t *to = (timeout_t *) malloc (sizeof (timeout_t));
  control_t *ctrl = (control_t *) malloc (sizeof (control_t));
  strsestmpfile_t *tmp_file = (strsestmpfile_t *) malloc (sizeof (strsestmpfile_t));

#if 0
  ss_assert (ses != NULL);
  ss_assert (to != NULL);
  ss_assert (ctrl != NULL);
#endif
  memset (ses, 0, sizeof (session_t));
  ctrl->ctrl_timeout = to;
  ses->ses_control = ctrl;
  ses->ses_file = tmp_file;

  ses->ses_bytes_read = 0;
  ses->ses_bytes_written = 0;
  ses->ses_status = 0;
  ses->ses_reads = 0;
  memset (tmp_file, 0, sizeof (strsestmpfile_t));

  SESSTAT_SET (ses, SST_OK);

  /* Take the default values for control fields */

  session_get_default_control (SC_BLOCKING, (char *) &(ctrl->ctrl_blocking), sizeof (ctrl->ctrl_blocking));

  session_get_default_control (SC_TIMEOUT, (char *) (ctrl->ctrl_timeout), sizeof (timeout_t));

  session_get_default_control (SC_MSGLEN, (char *) &(ctrl->ctrl_msg_length), sizeof (ctrl->ctrl_msg_length));

  /* Use device specific function for device initialization */
  ses->ses_device = device_allocate (sesclass);

/*
  IF UNKNOWN SESCLASS DO NOTHING
  ss_assert(ses->ses_device != NULL);
 */

  ses->ses_class = sesclass;

  return (ses);
}


/*##**********************************************************************\
 *
 *              session_free
 *
 * Function for deallocating session after use.
 *
 * Input params :
 *
 *      ses     - session pointer returned by session_allocate
 *
 * Output params:   - none
 *
 * Return value : SER_SUCC
 *                SER_ILLSESP
 *
 * Limitations  :   - none
 *
 * Globals used :   - none
 */
int
session_free (session_t * ses)
{
  if (ses == NULL)
    return (SER_ILLSESP);

  device_free (ses->ses_device);
  free ((char *) ses->ses_control->ctrl_timeout);
  free ((char *) ses->ses_control);
  free ((char *) ses->ses_file);
  free ((char *) ses);
  return (SER_SUCC);
}


/*##**********************************************************************\
 *
 *              tcpses_set_address
 *
 * Sets the address field of session's device according to the addrinfo
 *
 * Input params :
 *
 *      ses           -  session pointer
 *      addrinfo  -  <device dependent string>
 *
 * Output params: the address of session's device is changed
 *
 * Return value :
 *
 *      SER_SUCC     operation succeeded
 *      SER_ILLSESP  illegal session pointer, no action taken
 *      SER_ILLPRM   addrinfo could not be parsed as expected
 *
 * Limitations  : Device specific limitations ?
 *
 * Globals used : - none
 */
int
session_set_address (session_t * ses, char *addrinfo)
{
  return ((*ses->ses_device->dev_funs->dfp_set_address) (ses, addrinfo));
}


/*##**********************************************************************\
 *
 *              session_listen
 *
 * Starts the listening i.e. waiting for clients to connect.
 * Listening name (address) is taken from the session structure and must
 * be therefore set (by session_set_address()) before calling listen.
 * The mode of listening session is set according to current control fields
 * in session structure.
 *
 * Input params :
 *
 *      ses     -   session pointer
 *
 * Output params: the status of ses is updated
 *
 * Return value :
 *
 *      SER_SUCC, if successful
 *            <0, device dependent error code
 *
 * Limitations  :   Call session_set_address() first
 *
 * Globals used :   - none
 */
int
session_listen (session_t * ses)
{
  return ((*ses->ses_device->dev_funs->dfp_listen) (ses));
}


/*##**********************************************************************\
 *
 *              session_accept
 *
 * session_accept() should be called when the status of listening session
 * is SST_CONNECT_PENDING. This way the listening session accepts a new
 * connection.
 * The mode of new accepted session is set according to current values
 * in new_ses->ses_control structure.
 *
 *
 * Input params :
 *
 *      ses         - pointer to listening session
 *
 * Output params: the status of ses and new_ses is updated
 *      new_ses - pointer to new session (allocated with session_allocate)
 *
 * Return value :
 *
 *      SER_SUCC
 *            <0, device dependent error code
 *
 * Limitations  :  - none
 *
 * Globals used :  - none
 */
int
session_accept (session_t * ses, session_t * new_ses)
{
  return ((*ses->ses_device->dev_funs->dfp_accept) (ses, new_ses));
}


/*##**********************************************************************\
 *
 *              session_connect
 *
 * Connects allocated session to the specified server session.
 * The server address is specified with function tcpses_set_address.
 *
 * Input params :
 *
 *      ses     - session pointer
 *
 * Output params: the status of ses is updated
 *
 * Return value :
 *
 *      SER_SUCC, connection established
 *            <0, error code
 *
 * Limitations  :   - none
 *
 * Globals used :   - none
 */
int
session_connect (session_t * ses)
{
  return ((*ses->ses_device->dev_funs->dfp_connect) (ses));
}


/*##**********************************************************************\
 *
 *              session_disconnect
 *
 * Breaks a connection or stops listening of the session.
 *
 * Input params :
 *
 *      ses     -  session pointer
 *
 * Output params: the status of ses is updated
 *
 * Return value :
 *
 *      SER_SUCC  connection closed successfully
 *            <0, error code
 *
 * Limitations  :   - none
 *
 * Globals used :   - none
 */
int
session_disconnect (session_t * ses)
{
  return ((*ses->ses_device->dev_funs->dfp_disconnect) (ses));
}


/*##**********************************************************************\
 *
 *              session_write
 *
 * Writes data to a connected session.
 *
 * Input params :
 *
 *      ses         - session pointer
 *      buffer  - pointer to start of a memory block where data is
 *                to be copied
 *      n_bytes - size of the buf (in bytes)
 *
 * Output params:
 *      the ses_status is updated
 *      the ses_bytes_written is updated
 *
 * Return value : >0, number of bytes successfully written
 *               ==0, non-blocking write would have blocked
 *                <0, error code
 *
 * Limitations  :   - none
 *
 * Globals used :   - none
 */
int
session_write (session_t * ses, char *buffer, int n_bytes)
{
  return ((*ses->ses_device->dev_funs->dfp_write) (ses, buffer, n_bytes));
}


/*##**********************************************************************\
 *
 *              session_read
 *
 * Reads data from a connected session.
 *
 * Input params :
 *
 *
 *      ses         - session pointer
 *      buffer  - pointer to start of a memory block where received data is
 *                to be copied
 *      n_bytes - size of the buf (in bytes)
 *
 * Output params:
 *      the ses_status is updated
 *      the ses_bytes_read is updated
 *
 * Return value : >0, number of bytes successfully read
 *               ==0, non-blocking read ended because no data was available
 *                <0, error code
 *
 * Limitations  :   - none
 *
 * Globals used :   - none
 */
int
session_read (session_t * ses, char *buffer, int n_bytes)
{
  return ((*ses->ses_device->dev_funs->dfp_read) (ses, buffer, n_bytes));
}


/*##**********************************************************************\
 *
 *              session_select
 *
 *  session_select allows checking the status of multiple sessions in one
 *  operation. This is useful for processes that have to wait for
 *  several input sources at once. The reads and writes
 *  parameters are arrays of session pointers.
 *
 *  The length of all these arrays is session_count. These parameters
 *  collectively specify the selection criteria.
 *
 *  The operation returns if at least one criterion is met or the
 *  time_out is elapsed.  The reads and writes tables are
 *  all of the same length.  They may however specify different sessions
 *  and different numbers of sessions. Unused places can be set to null
 *  pointers.
 *
 *   This operation returns before the time out if:
 *
 *    1. There is input available in one or more of the sessions in the
 *       reads table.
 *
 *    2. If a session in the writes table has stopped being blocked on
 *       write. (== There is write space available again)
 *
 *    3. If there is an exception (SST_CONNECT_PENDING,
 *       SST_BROKEN_CONNECTION) on either of the tables.
 *
 * The session_select operation sets the status of each participating
 * session.
 *
 * Input params :
 *
 *      ses_count  - number of session pointers in writes and reads arrays
 *      reads      - array of reading sessions
 *      writes     - array of writing sessions
 *      timeout    - pointer to timeout_t containing timeout value
 *                   If no time out is wanted, NULL should be passed
 *
 * Output params:  the status of all sessions in arrays is updated
 *
 * Return value : >= 0, number of criteria met
 *                <  0, error code
 *
 * Limitations  :  Currently supports only one device at a time.
 *                 Going to be changed.
 *
 * Globals used :   - none
 */
int
session_select (int ses_count, session_t ** reads, session_t ** writes, timeout_t * timeout)
{
#if defined (COM_TCPIP)
  return (tcpses_select (ses_count, reads, writes, timeout));

#elif defined (COM_UDPIP)
  return (udpses_select (ses_count, reads, writes, timeout));

#elif defined (COM_NMPIPE)
  return (nmpses_select (ses_count, reads, writes, timeout));
#else

#error FIX ME
#endif
}


/*##**********************************************************************\
 *
 *              session_set_control
 *
 * Function to control session's properties
 *
 * Input params :
 *
 *      ses             - session pointer
 *      fieldtoset      - some session control (SC_ macro) value
 *      p_value     - pointer to memory area containing the new control value.
 *      size        - must equal sizeof(*p_value)
 *
 *
 *    Type of *p_value depends on fieldtoset in the following way.
 *
 *    fieldtoset     value type   p_value
 *    ------------------------------------------------------------------
 *    SC_BLOCKING       int       1=Blocking mode, 0=Non-blocking mode
 *
 *    SC_TIMEOUT     timeout_t    timeout
 *
 *    SC_MSGLEN         int       for connectionless protocols:
 *                                  - max transaction (msg) length in bytes
 *                                    (Currently not in use)
 *                                for connection oriented protocols:
 *                                  - hint for lower levels to reserve big
 *                                    enough communication buffers to achieve
 *                                    maximum performance.
 *                                    (0 = leave to OS)
 *
 * Output params: control field of ses is updated
 *
 * Return value :
 *
 *      SER_SUCC
 *      SER_ILLPRM
 *
 * Limitations  :   Currently has effect only on connected sessions.
 *                  Default settings can be used instead.
 *
 * Globals used :   - none
 */
int
session_set_control (session_t * ses, int field, char *p_value, int size)
{
  return ((*ses->ses_device->dev_funs->dfp_set_control) (ses, field, p_value, size));
}


/*##**********************************************************************\
 *
 *              session_get_control
 *
 * Copies the wanted current control value to p_value
 *
 * Input params :
 *
 *      ses             - session pointer
 *      fieldtoset      - some session control (SC_ macro) value
 *      size        - must equal sizeof(*p_value)
 *
 *      For more information on p_value, see the comment on
 *      session_set_control
 *
 * Output params:
 *      p_value     - pointer to memory area containing where the
 *                    control value is wanted to be copied.
 *
 * Return value :
 *
 *      SER_SUCC
 *      SER_ILLPRM
 *
 * Limitations  :   - none
 *
 * Globals used :   - none
 */
int
session_get_control (session_t * ses, int field, char *p_value, int size)
{
  return (get_control (ses->ses_control, field, p_value, size));
}


/*##**********************************************************************\
 *
 *              session_set_default_control
 *
 * Works as the session_set_control but updates the static control
 * structure which is used as a default control for all new allocated
 * sessions.
 *
 * Globals used :   defctrl
 *
 */
int
session_set_default_control (int field, char *p_value, int size)
{
  switch (field)
    {
    case SC_BLOCKING:
      if (size != sizeof (defctrl.ctrl_blocking))
	{
	  return (SER_ILLPRM);
	}
      else
	{
	  memcpy ((char *) &defctrl.ctrl_blocking, p_value, size);
	  return (SER_SUCC);
	}

    case SC_TIMEOUT:
      if (size != sizeof (timeout_t))
	{
	  return (SER_ILLPRM);
	}
      else
	{
	  memcpy ((char *) (defctrl.ctrl_timeout), p_value, size);
	  return (SER_SUCC);
	}

    case SC_MSGLEN:
      if (size != sizeof (defctrl.ctrl_msg_length))
	{
	  return (SER_ILLPRM);
	}
      else
	{
	  memcpy ((char *) &defctrl.ctrl_msg_length, p_value, size);
	  return (SER_SUCC);
	}

    default:
      return (SER_ILLPRM);
    }
}


/*##**********************************************************************\
 *
 *              session_get_default_control
 *
 * Works as the session_get_control but fetches the returned values
 * from a static control structure.
 * sessions.
 *
 * Globals used :   defctrl
 *
 */
int
session_get_default_control (int field, char *p_value, int size)
{
  return (get_control (&defctrl, field, p_value, size));
}


/*##**********************************************************************\
 *
 *              get_control
 *
 * Fetches the wanted control information from ct
 *
 * Input params :
 *
 *      ct          - pointer to control structure
 *      field   - wanted field
 *      size    - sizeof the data area
 *
 * Output params:
 *
 *      p_value - pointer to data area where the answer is copied
 *
 * Return value :
 *      SER_SUCC
 *      SER_ILLPRM
 *
 * Limitations  :
 *
 * Globals used :
 */
static int
get_control (control_t * ct, int field, char *p_value, int size)
{
  switch (field)
    {
    case SC_BLOCKING:
      if (size != sizeof (ct->ctrl_blocking))
	{
	  return (SER_ILLPRM);
	}
      else
	{
	  memcpy (p_value, (char *) &(ct->ctrl_blocking), size);
	  return (SER_SUCC);
	}

    case SC_TIMEOUT:
      if (size != sizeof (timeout_t))
	{
	  return (SER_ILLPRM);
	}
      else
	{
	  memcpy (p_value, (char *) (ct->ctrl_timeout), size);
	  return (SER_SUCC);
	}

    case SC_MSGLEN:
      if (size != sizeof (ct->ctrl_msg_length))
	{
	  return (SER_ILLPRM);
	}
      else
	{
	  memcpy (p_value, (char *) &(ct->ctrl_msg_length), size);
	  return (SER_SUCC);
	}

    default:
      return (SER_ILLPRM);
    }
}
