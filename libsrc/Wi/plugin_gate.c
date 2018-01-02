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

#include "msdtc.h"

unsigned char* export_mts_bin_encode (void *bin_array, unsigned long bin_array_len);
int export_mts_bin_decode (const char *encoded_str, void **array, unsigned long *len);
void export_mts_release_trx (void *itransact);




msdtc_version_t msdtc_sample_version = {
  {
    MSDTC_PLUGIN_TYPE,			/*!< Title of unit, filled by unit */
    "XXXX",/*!< Version number, filled by unit */
    "OpenLink Software",			/*!< Plugin's developer, filled by unit */
    "MSDTC support plugin",			/*!< Any additional info, filled by unit */
    0,					/*!< Error message, filled by unit loader */
    0,					/*!< Name of file with unit's code, filled by unit loader */
    0,			/*!< Pointer to connection function, cannot be 0 */
    0,					/*!< Pointer to disconnection function, or 0 */
    0,					/*!< Pointer to activation function, or 0 */
    0,					/*!< Pointer to deactivation function, or 0 */
    0
  },
  export_mts_get_trx_cookie,
  export_mts_bin_encode,
  export_mts_bin_decode,
  0,
  export_mts_release_trx,
  0,
  0,
  0
};

msdtc_version_t * msdtc_plugin_gate = &msdtc_sample_version;

msdtc_version_t * msdtc_plugin = 0;

