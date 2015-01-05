/*
 *  $Id$
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

#include <sqlver.h>
#include "plugin.h"
#include <stdio.h>
#include "msdtc.h"
#include "import_gate_virtuoso.h"

#include "mts.h"
#include "mts_client.h"

static void
msdtc_plugin_connect ()
{
  ;
}

void _mts_bif_init ();

void export_mts_release_trx (void * itransact);
void export_mts_client_init ();

static msdtc_version_t
msdtc_sample_version = {
  {
    MSDTC_PLUGIN_TYPE,			/*!< Title of unit, filled by unit */
    DBMS_SRV_GEN_MAJOR DBMS_SRV_GEN_MINOR,/*!< Version number, filled by unit */
    "OpenLink Software",			/*!< Plugin's developer, filled by unit */
    "MSDTC support plugin",			/*!< Any additional info, filled by unit */
    0,					/*!< Error message, filled by unit loader */
    0,					/*!< Name of file with unit's code, filled by unit loader */
    msdtc_plugin_connect,			/*!< Pointer to connection function, cannot be 0 */
    0,					/*!< Pointer to disconnection function, or 0 */
    0,					/*!< Pointer to activation function, or 0 */
    0,					/*!< Pointer to deactivation function, or 0 */
    &_gate
  },
  export_mts_get_trx_cookie,
  export_mts_bin_encode,
  export_mts_bin_decode,
  0,
  export_mts_release_trx,
  export_mts_recover,
  export_mts_bif_init,
  export_mts_trx_allocate
};


unit_version_t *
CALLBACK msdtc_sample_check (unit_version_t *in, void *appdata)
{
  if (!mts_check())
    {
      return 0;
    }
  return &msdtc_sample_version;
}

BOOL APIENTRY DllMain( HANDLE hModule,
                       DWORD  ul_reason_for_call,
                       LPVOID lpReserved
                                         )
{
    switch (ul_reason_for_call)
        {
                case DLL_PROCESS_ATTACH:
                case DLL_THREAD_ATTACH:
                case DLL_THREAD_DETACH:
                case DLL_PROCESS_DETACH:
                        break;
    }
    return TRUE;
}

#ifdef MALLOC_DEBUG
int
gpf_notice (const char * file, int line, const char * text)
{
  if (text)
    fprintf (stderr, "GPF: %s:%d %s\n", file, line, text);
  else
    fprintf (stderr, "GPF: %s:%d internal error\n", file, line);
  fflush (stderr);
  *(long*)-1 = -1;
  call_exit (1);
  return 0;
}
void (*process_exit_hook) (int);
#endif
