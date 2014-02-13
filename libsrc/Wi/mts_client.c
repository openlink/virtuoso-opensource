/*
 *  mts_client.c
 *
 *  $Id$
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

#include "Dk.h"
#include "mts_client.h"
#include "odbcinc.h"
#include "Dk/Dkhashext.h"
#include "CLI.h"
#include "sql.h"
#include <plugin/dlf.h>

/* bug in xoleHlp.h */
#ifndef __cplusplus
typedef enum APPLICATIONTYPE APPLICATIONTYPE;
#endif

#include <initguid.h>
#include <txcoord.h>
#include <xolehlp.h>

#ifndef NO_IMPORT
#include "import_gate_virtuoso.h"
#endif

#define COOKIE_LEN 256
#define COOKIE_LEN_ENC COOKIE_LEN*4


/*#define MTSC_ASSERT(HR,STR) \
 if(!SUCCEEDED(HR))\
   printf("--->MTS ASSERT FAILED<---: %s HR= %x\n",STR,HR);\
 else\
   printf("--->MTS ASSERT %s PASSED\n",STR); */


#define MTSC_ASSERT(HR,STR)

id_hash_t *rmcookie_hash = 0;
dk_mutex_t *rmcookie_hash_mutex = 0;

ITransactionExportFactory *export_factory = 0;
dk_mutex_t *export_factory_mutex = 0;

typedef struct cookie_s
{
  caddr_t cookie;
  unsigned long cookie_len;
  ITransactionExport *export;
}
cookie_t;

HRESULT mts_init_export_factory ();
HRESULT mts_create_export ();

int export_mts_bin_decode (const char *encoded_str, void **array,
    unsigned long *len);

typedef HRESULT (*funcGetDtc) (char *i_pszHost, char *i_pszTmName,
    REFIID i_riid, DWORD i_dwReserved1, WORD i_wcbReserved2,
    void *i_pvReserved2, void **o_ppvObject);

#ifdef NO_IMPORT
funcGetDtc get_dtc = 0;

extern void *msdtc_plugin_gate;

void
mts_client_init ()
{
#ifdef VIRTTP
  static int mts_client_inited = 0;
  void *dll;

  if (mts_client_inited)
    return;
  else
    mts_client_inited = 1;
  dll = dlopen ("xolehlp.dll", 0);
  if (!dll)
    return;

  get_dtc = dlsym (dll, "DtcGetTransactionManagerC");

  if (!get_dtc)
    return;

  if (!msdtc_plugin)
    {
      msdtc_plugin = (msdtc_version_t *) msdtc_plugin_gate;
      /*printf ("MS DTC is detected.");
         fflush (stdout); */
    }
  rmcookie_hash_mutex = mutex_allocate ();
#endif


}
#else
#ifdef VIRTTP
funcGetDtc get_dtc = DtcGetTransactionManagerC;
#else
funcGetDtc get_dtc = NULL;
#endif
void
mts_client_init ()
{
  static int mts_client_inited = 0;
  if (mts_client_inited)
    return;
  else
    mts_client_inited = 1;
  rmcookie_hash_mutex = mutex_allocate ();
}
#endif

void
mts_get_remote_rmcookie (cli_connection_t * con, cookie_t ** rmcookie)
{
  if (!rmcookie_hash)
    {
      mutex_enter (rmcookie_hash_mutex);
      if (!rmcookie_hash)
	{
	  rmcookie_hash =
	      id_hash_allocate (1024, sizeof (caddr_t), sizeof (cookie_t),
	      strhash, strhashcmp);
	}
      mutex_leave (rmcookie_hash_mutex);
    }

  mutex_enter (rmcookie_hash_mutex);
  *rmcookie =
      (cookie_t *) id_hash_get (rmcookie_hash, (char *) &con->con_dsn);
  mutex_leave (rmcookie_hash_mutex);

  if (!*rmcookie)
    {
      SQLHSTMT stmt;
      SQLRETURN rc = SQLAllocStmt ((SQLHDBC) con, &stmt);
      if (SQL_SUCCESS == rc)
	{
	  rc = SQLExecDirect (stmt, "select mts_get_rmcookie()", SQL_NTS);
	  if (SQL_SUCCESS == rc)
	    {
	      SQLLEN cols;
	      caddr_t cookie_enc = dk_alloc (COOKIE_LEN_ENC);
	      rc = SQLBindCol (stmt, 1, SQL_C_CHAR, cookie_enc,
		  COOKIE_LEN_ENC, &cols);
	      if (SQL_SUCCESS == rc)
		{
		  rc = SQLFetch (stmt);
		  if (SQL_SUCCESS == rc)
		    {
		      *rmcookie = dk_alloc (sizeof (cookie_t));
		      memset (*rmcookie, 0, sizeof (cookie_t));
		      export_mts_bin_decode (cookie_enc,
			  &(*rmcookie)->cookie, &(*rmcookie)->cookie_len);
		      if ((*rmcookie)->cookie)
			{
			  /* GK: the key must be boxed as it can survive the close/open on the same DSN */
			  caddr_t boxed_key =
			      box_dv_short_string (con->con_dsn);
			  mts_init_export_factory ();
			  mts_create_export (*rmcookie);

			  mutex_enter (rmcookie_hash_mutex);
			  id_hash_set (rmcookie_hash,
			      (caddr_t) & boxed_key, (caddr_t) * rmcookie);
			  mutex_leave (rmcookie_hash_mutex);
			}
		      else
			{
			  dk_free (*rmcookie, -1);
			  *rmcookie = 0;
			}

		    };
		};
	      dk_free (cookie_enc, COOKIE_LEN_ENC);
	    }
	  SQLFreeStmt (stmt, SQL_DROP);
	}
    }
}

HRESULT
mts_init_export_factory ()
{
  HRESULT hr = 0;
  if (!export_factory && (NULL != get_dtc))
    {
      hr = get_dtc (0, 0,
	  (REFIID) & IID_ITransactionExportFactory, 0, 0, 0, &export_factory);
      MTSC_ASSERT (hr, "Init transaction export factory");
    }
  return hr;


}

HRESULT
mts_create_export (cookie_t * rmcookie)
{
  HRESULT hr = export_factory->lpVtbl->Create (export_factory,
      rmcookie->cookie_len,
      rmcookie->cookie,
      &rmcookie->export);
  MTSC_ASSERT (hr, "Create transaction export function");
  return hr;
}



void
export_mts_get_trx_cookie (void *_con, void *itrx, void **_cookie,
    unsigned long *cookie_len)
{
  caddr_t *cookie = (caddr_t *) _cookie;
  cookie_t *rm_cookie;
  cli_connection_t *con = (cli_connection_t *) _con;

  mts_get_remote_rmcookie (con, &rm_cookie);

  *cookie = 0;

  if (rm_cookie)
    {
      unsigned long len_used;
      HRESULT hr = rm_cookie->export->lpVtbl->Export (rm_cookie->export,
	  (IUnknown *) itrx, cookie_len);
      MTSC_ASSERT (hr, "Export marshal of transaction");

      *cookie = dk_alloc (*cookie_len);

      hr = rm_cookie->export->lpVtbl->GetTransactionCookie (rm_cookie->export,
	  (IUnknown *) itrx, *cookie_len, *cookie, &len_used);
      MTSC_ASSERT (hr, "Get transaction cookie");

      return;
    }
};


caddr_t
export_mts_bin_encode (void *bin_array, unsigned long bin_array_len)
{
  unsigned long i;
  caddr_t ret_array = dk_alloc_box (bin_array_len * 4 + 1, DV_SHORT_STRING);
  char tmp[5];

  ret_array[0] = 0;
  for (i = 0; i < bin_array_len; i++)
    {
      snprintf (tmp, sizeof (tmp), "/%03u", ((unsigned char *) bin_array)[i]);
      strcat_box_ck (ret_array, tmp);
    }
  return ret_array;
}

int
export_mts_bin_decode (const char *encoded_str, void **array,
    unsigned long *len)
{
  int str_len = (int) strlen (encoded_str);
  unsigned char *bin_array;
  unsigned char *bin_ptr;
  const char *encoded_ptr = encoded_str;
  int i = str_len / 4;
  if (!i)
    {
      return -1;
    }
  *len = i;
  bin_array = (unsigned char *) dk_alloc (str_len / 4);
  bin_ptr = bin_array;
  while (i)
    {
      if (*encoded_ptr != '/')
	{
	  dk_free (bin_array, -1);
	  *(unsigned char **) array = 0;
	  return -1;
	}
      else
	{
	  i--;
	  *bin_ptr = (unsigned char) atoi (encoded_ptr + 1);
	  bin_ptr++;
	  encoded_ptr += 4;
	}
    }
  *(unsigned char **) array = bin_array;
  return 0;
}

void
export_mts_release_trx (void *itransact)
{
  ITransaction *itrx = (ITransaction *) itransact;

  itrx->lpVtbl->Release (itrx);
}
