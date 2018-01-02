/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2018 OpenLink Software
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

#include "import_gate_virtuoso.h"
#include "sqlver.h"

#include <stdio.h>

static caddr_t
bif_plugin_sample (caddr_t * qst, caddr_t * err, state_slot_t ** args)
{
  caddr_t res = dk_alloc_box (strlen (PLAIN_PLUGIN_TYPE) + 1, DV_STRING);
  strcpy (res, PLAIN_PLUGIN_TYPE);
  return res;
}


static void
plain_plugin_connect ()
{
  bif_define ("PLAIN_PLUGIN_TEST", bif_plugin_sample);
}


static unit_version_t plugin_sample_version = {
  PLAIN_PLUGIN_TYPE,		/*!< Title of unit, filled by unit */
  DBMS_SRV_GEN_MAJOR DBMS_SRV_GEN_MINOR,	/*!< Version number, filled by unit */
  "OpenLink Software",		/*!< Plugin's developer, filled by unit */
  "sample plugin",		/*!< Any additional info, filled by unit */
  0,				/*!< Error message, filled by unit loader */
  0,				/*!< Name of file with unit's code, filled by unit loader */
  plain_plugin_connect,		/*!< Pointer to connection function, cannot be 0 */
  0,				/*!< Pointer to disconnection function, or 0 */
  0,				/*!< Pointer to activation function, or 0 */
  0,				/*!< Pointer to deactivation function, or 0 */
  &_gate
};


unit_version_t *CALLBACK
plugin_sample_check (unit_version_t * in, void *appdata)
{
  return &plugin_sample_version;
}
