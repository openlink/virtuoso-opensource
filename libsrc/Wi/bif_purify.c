/*
 *  bif_purify.c
 *
 *  $Id$
 *
 *  Purify functions
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

#include "sqlnode.h"
#include "sqlbif.h"
#include "pure.h"


static caddr_t
bif_purify_all_leaks (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  PurifyAllLeaks ();
  return 0;
}


static caddr_t
bif_purify_new_leaks (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  PurifyNewLeaks ();
  return 0;
}


static caddr_t
bif_purify_all_in_use (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  PurifyAllInuse ();
  return 0;
}


static caddr_t
bif_purify_new_in_use (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  PurifyNewInuse ();
  return 0;
}


caddr_t
bif_purify_clear_leaks (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  PurifyClearLeaks ();
  return 0;
}


caddr_t
bif_purify_clear_in_use (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  PurifyClearInuse ();
  return 0;
}


void
bif_purify_init (void)
{
  bif_define ("purify_all_leaks", bif_purify_all_leaks);
  bif_define ("purify_new_leaks", bif_purify_new_leaks);
  bif_define ("purify_all_in_use", bif_purify_all_in_use);
  bif_define ("purify_new_in_use", bif_purify_new_in_use);
  bif_define ("purify_clear_leaks", bif_purify_clear_leaks);
  bif_define ("purify_clear_inuse", bif_purify_clear_in_use);
}
