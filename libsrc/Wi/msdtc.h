/*
 *  hosting.h
 *
 *  $Id$
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

#ifndef __MSDTC_PLUGIN_H__
#define __MSDTC_PLUGIN_H__ 1

#include <plugin.h>

#define MTS_BUFSIZ 1024

/* completely stolen from hosting.h. thanks, George :) */

typedef void (*typeof__mts_get_trx_cookie) (void * con, void *i_trx, void **cookie,
    unsigned long *cookie_len ) ;
typedef void* (*typeof__mts_bin_encode) (void *bin_array, unsigned long bin_array_len);

typedef int (*typeof__mts_bin_decode) (const char *encoded_str, void **array,
    unsigned long *len);
typedef void (*typeof__mts_client_init) ();


typedef void (*typeof__mts_release_trx)(void * itran);
typedef int (*typeof__mts_recover) (void * recovery_data);
typedef void (*typeof__mts_bif_init) ();
typedef void * (*typeof__mts_trx_allocate)();





typedef struct msdtc_version_s
{
  unit_version_t hv_pversion;
  /* mts_client.h */
  typeof__mts_get_trx_cookie hv_get_trx_cookie;
  typeof__mts_bin_encode hv_bin_encode;
  typeof__mts_bin_decode hv_bin_decode;
  typeof__mts_client_init hv_client_init;
  typeof__mts_release_trx hv_release_trx;
  typeof__mts_recover hv_recover;
  typeof__mts_bif_init hv_bif_init;
  typeof__mts_trx_allocate hv_trx_allocate;

  /* mts.h */
} msdtc_version_t;

/* mts.h */
#define MSDTC_GET_TRX_COOKIE "virtm_mts_get_trx_cookie"
#define MSDTC_BIN_ENCODE "virtm_mts_bin_encode"
#define MSDTC_BIN_DECODE "virtm_mts_bin_decode"
#define MSDTC_CLIENT_INIT "virtm_mts_client_init"
#define MSDTC_RELEASE_TRX "virtm_mts_release_trx"
#define MSDTC_RECOVER "virtm_mts_recover"
#define MSDTC_BIF_INIT "virtm_mts_bif_init"
#define MSDTC_TRX_ALLOCATE "virtrm_mts_trx_allocate"

extern int vd_use_mts;

#ifndef _USRDLL
extern msdtc_version_t * msdtc_plugin;
#define MSDTC_IS_LOADED (msdtc_plugin)

#define mts_get_trx_cookie (msdtc_plugin->hv_get_trx_cookie)
#define mts_bin_encode (msdtc_plugin->hv_bin_encode)
#define mts_bin_decode (msdtc_plugin->hv_bin_decode)
/* #define mts_client_init (msdtc_plugin->hv_client_init) */
#define mts_release_trx (msdtc_plugin->hv_release_trx)
#define mts_recover (msdtc_plugin->hv_recover)
#define mts_bif_init (msdtc_plugin->hv_bif_init)
#define mts_trx_allocate (msdtc_plugin->hv_trx_allocate)
#endif

void
export_mts_get_trx_cookie (void * _con, void *itrx, void ** cookie,
    unsigned long *cookie_len);

#ifndef EXE_IMPORT
#ifdef NO_IMPORT
#define EXE_IMPORT(type, func, sign)
#else
#define EXE_IMPORT(type, func, sign) \
    type export_##func sign
#endif
#endif
#endif
