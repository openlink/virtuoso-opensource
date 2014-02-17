/*
 *  Dksesinp.c
 *
 *  $Id$
 *
 *  In-process sessions
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2014 OpenLink Software
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

#ifdef HAVE_CONFIG_H
#include <config.h>
#endif
#ifdef INPROCESS_CLIENT

#include "Dk.h"
#include "Dksesstr.h"
#if defined(_MSC_VER) && defined(_DEBUG)
# include <crtdbg.h>
#endif


static int
inpses_dummy (session_t * ses)
{
  return SER_SUCC;
}


dk_session_t *
inpses_allocate (void)
{
  dk_session_t *dk_ses = strses_allocate ();
  session_t *ses = dk_ses->dks_session;

  SESSION_SCH_DATA (dk_ses)->sio_is_served = -1;
  ses->ses_device->dev_funs->dfp_disconnect = inpses_dummy;

  dk_ses->dks_mtx = mutex_allocate ();

  return dk_ses;
}


/*
 * Checks to see if the session contains any unread data.
 */
int
inpses_unread_data (dk_session_t * ses)
{
  strdevice_t *strdev = (strdevice_t *) ses->dks_session->ses_device;
  if (strdev->strdev_buffer_ptr)
    {
      buffer_elt_t *buf = strdev->strdev_buffer_ptr;
      return buf->read < buf->fill;
    }
  else
    {
      return strdev->strdev_in_read < ses->dks_out_fill;
    }
}


#if defined(_MSC_VER) && defined(_DEBUG)

static void
inpdev_verify_buf (buffer_elt_t * b, caddr_t arg)
{
  _ASSERTE (_CrtIsValidHeapPointer (b));
  _ASSERTE (_CrtIsValidHeapPointer (b->data));
}


void
inpses_verify (dk_session_t * ses)
{
  _ASSERTE (_CrtCheckMemory ());
  strses_map ((strdevice_t *) ses->dks_session->ses_device, inpdev_verify_buf, NULL);
}
#endif /* defined(_MSC_VER) && defined(_DEBUG) */


#endif /* INPROCESS_CLIENT */
