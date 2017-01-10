/*
 *  tpcctrx.c
 *
 *  $Id$
 *
 *  TPC-C Transactions
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

#ifdef WIN32
#include <windows.h>
#include <sqlext.h>

#endif
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <memory.h>
#ifdef UNIX
# include <sys/time.h>
# include <unistd.h>
#endif

#include <oci.h>
#include "odbcinc.h"
#include "timeacct.h"
#include "tpcc.h"


#define OL_MAX 20
#define OL_PARS 3
#define NO_PARS 5

#define DEADLOCK_1            60
#define DEADLOCK_2            99
#define DEADLOCK_3            104



extern char dbms[40];

extern SDWORD local_w_id;

extern timer_account_t new_order_ta;
extern timer_account_t payment_ta;
extern timer_account_t delivery_ta;
extern timer_account_t slevel_ta;
extern timer_account_t ostat_ta;



typedef struct olsstruct
{
  int ol_no[OL_MAX];
  long ol_i_id[OL_MAX];
  long ol_qty[OL_MAX];
  long ol_supply_w_id[OL_MAX];
  char ol_data[OL_MAX][24];
}
olines_t;

int rnd_district ();
int make_supply_w_id ();
long NURand (int a, int x, int y);
void MakeNumberString (int sz, int sz2, char *str);

long checkerr (OCIError *, sword);
static OCISvcCtx *svchp;
static OCIEnv *envhp;
static OCIError *errhp;
static OCIServer *srvhp;
OCISession *authp = (OCISession *) 0;

extern char dbms[40];		/*Global db name */

extern SDWORD local_w_id; /*= 1;*/
extern SDWORD n_ware;	  /*= 1;*/

static OCIStmt *new_order_stmt;
static OCIStmt *ostat_stmt;
static OCIStmt *delivery_stmt;
static OCIStmt *payment_stmt;
static OCIStmt *slevel_stmt;


/*
 * Stored PL/SQL procedure must be presented as:
 * "BEGIN
 *   procedure_name(:arg_1,...,:arg_n)
 * END;"
 */

static text *new_order_text = (text *) "begin \
new_order_proc(:w_id, :d_id, :c_id, :ol_cnt, :all_local, \
        :i_id1, :s_w_id1, :qty1, \
        :i_id2, :s_w_id2, :qty2, \
        :i_id3, :s_w_id3, :qty3, \
        :i_id4, :s_w_id4, :qty4, \
        :i_id5, :s_w_id5, :qty5, \
        :i_id6, :s_w_id6, :qty6, \
        :i_id7, :s_w_id7, :qty7, \
        :i_id8, :s_w_id8, :qty8, \
        :i_id9, :s_w_id9, :qty9, \
        :i_id10, :s_w_id10, :qty10 ); \
	end;";

static text *ostat_text = \
    "begin ostat(:w_id, :d_id, :c_c_id, :c_c_last); end;";

static text *delivery_text = "begin delivery (:w_id, :o_carrier_id); end;";

static text *payment_text = \
    "begin payment(:w_id, :c_w_id, :h_amount, :d_id, :c_d_id, :c_c_id, :c_c_last); end;";

static text *slevel_text = "begin slevel(:w_id, :d_id, :threshold); end;";


/*---------------------------------------------------------------------*/
/* Allocate all required bind handles                                  */
/*---------------------------------------------------------------------*/

sword
alloc_bind_handle (OCIStmt * stmthp, OCIBind * bndhp[], int nbinds)
{
  int i;
  /*
   * This function allocates the specified number of bind handles
   * from the given statement handle.
   */
  for (i = 0; i < nbinds; i++)
    bndhp[i] = (OCIBind *) 0;
  return OCI_SUCCESS;
}



void
login (HENV * henv, HDBC * hdbc, char *argv_, char *dbms, int dbms_sz,
    HSTMT * misc_stmt, char *uid, char *pwd)
{
  char ver [1000];
  if (OCIInitialize ((ub4) OCI_OBJECT, (dvoid *) 0,
	  (dvoid * (*)(dvoid *, size_t)) 0,
	  (dvoid * (*)(dvoid *, dvoid *, size_t)) 0,
	  (void (*)(dvoid *, dvoid *)) 0))
    {
      (void) printf ("FAILED: OCIInitialize()\n");
      exit (-1);
    }
  (void) OCIEnvInit ((OCIEnv **) & envhp, OCI_DEFAULT, (size_t) 0, (dvoid **) 0);

      (void) OCIHandleAlloc ((dvoid *) envhp, (dvoid **) & errhp,
      OCI_HTYPE_ERROR, (size_t) 0, (dvoid **) 0);
  /* server contexts */
  (void) OCIHandleAlloc ((dvoid *) envhp, (dvoid **) & srvhp, OCI_HTYPE_SERVER,
      (size_t) 0, (dvoid **) 0);

  (void) OCIHandleAlloc ((dvoid *) envhp, (dvoid **) & svchp, OCI_HTYPE_SVCCTX,
      (size_t) 0, (dvoid **) 0);

  (void) OCIServerAttach (srvhp, errhp, (text *) argv_, strlen (argv_), 0);
  /*(void) OCIServerAttach (srvhp, errhp, (text *) "", strlen (""), 0);*/
  /* set attribute server context in the service context */
  (void) OCIAttrSet ((dvoid *) svchp, OCI_HTYPE_SVCCTX, (dvoid *) srvhp, (ub4) 0,
      OCI_ATTR_SERVER, (OCIError *) errhp);

  (void) OCIHandleAlloc ((dvoid *) envhp, (dvoid **) & authp, (ub4) OCI_HTYPE_SESSION,
      (size_t) 0, (dvoid **) 0);

  (void) OCIAttrSet ((dvoid *) authp, (ub4) OCI_HTYPE_SESSION,
      (dvoid *) uid, (ub4) strlen ((char *) uid),
      (ub4) OCI_ATTR_USERNAME, errhp);

  (void) OCIAttrSet ((dvoid *) authp, (ub4) OCI_HTYPE_SESSION,
      (dvoid *) pwd, (ub4) strlen ((char *) pwd),
      (ub4) OCI_ATTR_PASSWORD, errhp);

  if (checkerr (errhp, OCISessionBegin (svchp, errhp, authp, OCI_CRED_RDBMS,
	      (ub4) OCI_DEFAULT)))
    exit (-1);

  OCIServerVersion ((dvoid *) srvhp, errhp, ver, (ub4) (sizeof (ver)), OCI_HTYPE_SERVER);

  (void) OCIAttrSet ((dvoid *) svchp, (ub4) OCI_HTYPE_SVCCTX,
      (dvoid *) authp, (ub4) 0, (ub4) OCI_ATTR_SESSION, errhp);
  strcpy (dbms, "Oracle");
  printf ("Connected to %s\n", ver);
}				/* End login */

/* Macro definitions */

/* Integer */
#define IBINDL(stmt, bndp, nPos, nValue) \
 checkerr(errhp,OCIBindByPos(stmt, &bndp, errhp, nPos,\
           (dvoid *) &nValue, (sword) sizeof(nValue),SQLT_INT,\
           (dvoid *) 0, (ub2 *) 0, (ub2 *) 0, (ub4) 0, (ub4 *) 0, OCI_DEFAULT));

/* Array of integer */
#define IBINDL_ARRAY(stmt, bndp, nPos, nValue) \
 checkerr(errhp,OCIBindByPos(stmt, &bndp, errhp, nPos,\
           (dvoid *) &nValue, (sword) sizeof(nValue),SQLT_INT,\
           (dvoid *) 0, (ub2 *) 0, (ub2 *) 0, (ub4) 0, (ub4 *) 0, OCI_DEFAULT)); \
 checkerr(errhp, OCIBindArrayOfStruct(bndp, errhp, sizeof(nValue),0,0,0));


/* String zero-terminated */
#define IBINDS(stmt, bndp, nPos, szValue) \
 checkerr(errhp,OCIBindByPos(stmt, &bndp, errhp, nPos,\
           (dvoid *) szValue, (sword) sizeof(szValue),SQLT_STR,\
           (dvoid *) 0, (ub2 *) 0, (ub2 *) 0, (ub4) 0, (ub4 *) 0, OCI_DEFAULT));

#define IBINDS_ARRAY(stmt, bndp, nPos, szArray) \
 checkerr(errhp,OCIBindByPos(stmt, &bndp, errhp, nPos,\
           (dvoid *) szArray, (sword) sizeof(szArray[0]),SQLT_STR,\
           (dvoid *) 0, (ub2 *) 0, (ub2 *) 0, (ub4) 0, (ub4 *) 0, OCI_DEFAULT));\
 checkerr(errhp, OCIBindArrayOfStruct(bndp, errhp, sizeof(szArray[0]),0,0,0));

/* Float */
#define IBINDF(stmt, bndp, nPos, lValue) \
 checkerr(errhp,OCIBindByPos(stmt, &bndp, errhp, nPos,\
           (dvoid *) &lValue, (sword) sizeof(lValue), SQLT_FLT,\
           (dvoid *) 0, (ub2 *) 0, (ub2 *) 0, (ub4) 0, (ub4 *) 0, OCI_DEFAULT));

#define IBINDF_ARRAY(stmt, bndp, nPos, lValue) \
 checkerr(errhp,OCIBindByPos(stmt, &bndp, errhp, nPos,\
           (dvoid *) &lValue, (sword) sizeof(lValue), SQLT_FLT,\
           (dvoid *) 0, (ub2 *) 0, (ub2 *) 0, (ub4) 0, (ub4 *) 0, OCI_DEFAULT)); \
 checkerr(errhp, OCIBindArrayOfStruct(bndp, errhp, sizeof(lValue),0,0,0));

/* Statement initializing */
#define INIT_STMT(stmt, sttext) \
	 checkerr(errhp,OCIHandleAlloc( (dvoid *) envhp, (dvoid **) &stmt,\
		          OCI_HTYPE_STMT, (size_t) 0, (dvoid **) 0));\
   checkerr(errhp,OCIStmtPrepare(stmt, errhp, sttext, \
                        (ub4) strlen((char *) sttext), \
                        (ub4) OCI_NTV_SYNTAX,(ub4) OCI_DEFAULT));

#define FREE_STMT(stmt) checkerr(errhp, OCIHandleFree ((dvoid *) stmt, OCI_HTYPE_STMT));

#define IF_DEADLOCK_OR_ERR_GO(rc, err_tag, deadlock_tag) \
  if (rc == DEADLOCK_1 || rc == DEADLOCK_2 || rc == DEADLOCK_3 ) \
    goto deadlock_tag; \
  else \
    goto err_tag;

/* End of macro definitions */

void
new_order ()
{
  long rc;
  int n;
  static struct timeval tv;
  static olines_t ols;
  static int i;
  static long d_id;
  static long w_id;
  static long c_id;
  static char c_last[100];
  static long ol_cnt;
  static long all_local;
  OCIBind *bndhp[35];
  w_id = local_w_id;
  d_id = rnd_district ();
  c_id = random_c_id ();
  ol_cnt = 10;
  all_local = 1;
  memset (c_last, 0, sizeof (c_last));
  gettimestamp (&tv);

  for (i = 0; i < 10; i++)
    {
      ols.ol_i_id[i] = random_i_id ();
      ols.ol_qty[i] = 5;
      ols.ol_supply_w_id[i] = make_supply_w_id ();
      ols.ol_no[i] = i + 1;
      MakeAlphaString (23, 23, ols.ol_data[i]);
    }

deadlock_no:

  if (!new_order_stmt)
    {
      INIT_STMT (new_order_stmt, new_order_text);
      alloc_bind_handle (new_order_stmt, bndhp, 35);
      IBINDL (new_order_stmt, bndhp[0], 1, w_id);
      IBINDL (new_order_stmt, bndhp[1], 2, d_id);
      IBINDL (new_order_stmt, bndhp[2], 3, c_id);
      IBINDL (new_order_stmt, bndhp[3], 4, ol_cnt);
      IBINDL (new_order_stmt, bndhp[4], 5, all_local);
      for (n = 0; n < 10; n++)
	{
	  IBINDL (new_order_stmt, bndhp[(NO_PARS + (n * OL_PARS))],
	      (NO_PARS + 1 + (n * OL_PARS)), ols.ol_i_id[n]);
	  IBINDL (new_order_stmt, bndhp[(NO_PARS + 1 + (n * OL_PARS))],
	      (NO_PARS + 2 + (n * OL_PARS)), ols.ol_supply_w_id[n]);
	  IBINDL (new_order_stmt, bndhp[(NO_PARS + 2 + (n * OL_PARS))],
	      (NO_PARS + 3 + (n * OL_PARS)), ols.ol_qty[n]);
	}
    }

  ta_enter (&new_order_ta);

  /* Begin auto-commit transaction */
  rc =
      checkerr (errhp, OCIStmtExecute (svchp, new_order_stmt, errhp, (ub4) 1,
	 (ub4) 0, (CONST OCISnapshot *) NULL, (OCISnapshot *) NULL,
	  OCI_COMMIT_ON_SUCCESS));

  IF_DEADLOCK_OR_ERR_GO (rc, err, deadlock_no);

err:
  ta_leave (&new_order_ta);

  return;
}				/* end new_order */




void
payment ()
{
  long rc;
  long w_id = local_w_id;
  long d_id = RandomNumber (1, DIST_PER_WARE);
  long c_id = random_c_id ();
  char c_last[50];
  float amount = 100.00;
  OCIBind *bndhp[7];

  strcpy (c_last, "");

deadlock_pay:

  if (!payment_stmt)
    {
      INIT_STMT (payment_stmt, payment_text);
      alloc_bind_handle (payment_stmt, bndhp, 7);
    }
  if (RandomNumber (0, 100) < 60)
    {
      c_id = 0;
      Lastname (RandomNumber (0, 999), c_last);
    }
  IBINDL (payment_stmt, bndhp[0], 1, w_id);
  IBINDL (payment_stmt, bndhp[1], 2, w_id);
  IBINDF (payment_stmt, bndhp[2], 3, amount);
  IBINDL (payment_stmt, bndhp[3], 4, d_id);
  IBINDL (payment_stmt, bndhp[4], 5, d_id);
  IBINDL (payment_stmt, bndhp[5], 6, c_id);
  IBINDS (payment_stmt, bndhp[6], 7, c_last);

  ta_enter (&payment_ta);

  rc =
      checkerr (errhp, OCIStmtExecute (svchp, payment_stmt, errhp, (ub4) 1,
	 (ub4) 0, (CONST OCISnapshot *) NULL, (OCISnapshot *) NULL,
	  OCI_COMMIT_ON_SUCCESS));

  IF_DEADLOCK_OR_ERR_GO (rc, err, deadlock_pay);

err:
  ta_leave (&payment_ta);
}				/* end payment */




void
delivery_1 (long w_id, long d_id)
{
  long carrier_id = 13;
  long rc;
  OCIBind *bndhp[3];

deadlock_del1:
  if (!delivery_stmt)
    {
      INIT_STMT (delivery_stmt, delivery_text);
      alloc_bind_handle (delivery_stmt, bndhp, 3);
    }

  IBINDL (delivery_stmt, bndhp[0], 1, w_id);
  IBINDL (delivery_stmt, bndhp[1], 2, carrier_id);

  rc =
      checkerr (errhp, OCIStmtExecute (svchp, delivery_stmt, errhp, (ub4) 1,
	 (ub4) 0, (CONST OCISnapshot *) NULL, (OCISnapshot *) NULL,
	  OCI_COMMIT_ON_SUCCESS));

  IF_DEADLOCK_OR_ERR_GO (rc, err, deadlock_del1);

err:;
}				/* end delivery_1 */




void
slevel ()
{
  long rc;
  long w_id = local_w_id;
  long d_id = RandomNumber (1, DIST_PER_WARE);
  long threshold = 20;
  OCIBind *bndhp[4];

deadlock_sl:

  if (!slevel_stmt)
    {
      INIT_STMT (slevel_stmt, slevel_text);
      alloc_bind_handle (slevel_stmt, bndhp, 4);
    }
  IBINDL (slevel_stmt, bndhp[0], 1, w_id);
  IBINDL (slevel_stmt, bndhp[1], 2, d_id);
  IBINDL (slevel_stmt, bndhp[2], 3, threshold);


  ta_enter (&slevel_ta);

  rc =
      checkerr (errhp, OCIStmtExecute (svchp, slevel_stmt, errhp, (ub4) 1,
	 (ub4) 0, (CONST OCISnapshot *) NULL, (OCISnapshot *) NULL,
	  OCI_COMMIT_ON_SUCCESS));

  IF_DEADLOCK_OR_ERR_GO (rc, err, deadlock_sl);

err:
  ta_leave (&slevel_ta);
}				/* end slevel */




void
ostat ()
{
  long rc;
  long w_id = local_w_id;
  long d_id = RandomNumber (1, DIST_PER_WARE);
  long c_id = random_c_id ();
  char c_last[50];
  OCIBind *bndhp[4];

  memset (c_last, 0, sizeof (c_last));
deadlock_os:
  if (!ostat_stmt)
    {
      INIT_STMT (ostat_stmt, ostat_text);
      alloc_bind_handle (ostat_stmt, bndhp, 4);
    }
  if (RandomNumber (0, 100) < 60)
    {
      c_id = 0;
      Lastname (RandomNumber (0, 999), c_last);
    }
  IBINDL (ostat_stmt, bndhp[0], 1, w_id);
  IBINDL (ostat_stmt, bndhp[1], 2, d_id);
  IBINDL (ostat_stmt, bndhp[2], 3, c_id);
  IBINDS (ostat_stmt, bndhp[3], 4, c_last);

  ta_enter (&ostat_ta);

  rc =
      checkerr (errhp, OCIStmtExecute (svchp, ostat_stmt, errhp, (ub4) 1,
	 (ub4) 0, (CONST OCISnapshot *) NULL, (OCISnapshot *) NULL,
	  OCI_COMMIT_ON_SUCCESS));

  IF_DEADLOCK_OR_ERR_GO (rc, err, deadlock_os);

err:
  ta_leave (&ostat_ta);
}				/* end ostat */



long
checkerr (OCIError * errhp, sword status)
{
  text errbuf[512];
  sb4 errcode = 0;

  switch (status)
    {
    case OCI_SUCCESS:
      break;
    case OCI_SUCCESS_WITH_INFO:
      (void) printf ("Error - OCI_SUCCESS_WITH_INFO\n");
      break;
    case OCI_NEED_DATA:
      (void) printf ("Error - OCI_NEED_DATA\n");
      break;
    case OCI_NO_DATA:
      (void) printf ("Error - OCI_NODATA\n");
      break;
    case OCI_ERROR:
      (void) OCIErrorGet ((dvoid *) errhp, (ub4) 1, (text *) NULL, &errcode,
	  errbuf, (ub4) sizeof (errbuf), OCI_HTYPE_ERROR);
      (void) printf ("Error - %.*s\n", 512, errbuf);
      break;
    case OCI_INVALID_HANDLE:
      (void) printf ("Error - OCI_INVALID_HANDLE\n");
      break;
    case OCI_STILL_EXECUTING:
      (void) printf ("Error - OCI_STILL_EXECUTE\n");
      break;
    case OCI_CONTINUE:
      (void) printf ("Error - OCI_CONTINUE\n");
      break;
    default:
      break;
    }
  return errcode;
}

void
logoff ()
{
  if (errhp)
    (void) OCIServerDetach (srvhp, errhp, OCI_DEFAULT);
  if (srvhp)
    checkerr (errhp, OCIHandleFree ((dvoid *) srvhp, OCI_HTYPE_SERVER));
  if (svchp)
    (void) OCIHandleFree ((dvoid *) svchp, OCI_HTYPE_SVCCTX);
  if (errhp)
    (void) OCIHandleFree ((dvoid *) errhp, OCI_HTYPE_ERROR);
  return;
}

/*
* Load tables
*/
void LoadItems ();
void LoadWare ();
void LoadCust ();
void LoadOrd ();
void Stock (long w_id_from, long w_id_to);
void District (long w_id);
void Customer (long, long);
void Orders (long d_id, long w_id);

extern char timestamp_array[BATCH_SIZE][20];
extern long count_ware;


/* Global Variables */
extern int i;
extern int option_debug;	/* 1 if generating debug output    */
int rc;


#define CHECK_BATCH(stmt, fill)  \
  if (fill >= BATCH_SIZE - 1) \
    { \
    if (checkerr(errhp, OCIStmtExecute(svchp, stmt, errhp, (ub4) BATCH_SIZE, (ub4) 0, \
        (CONST OCISnapshot *) NULL, (OCISnapshot *) NULL, OCI_COMMIT_ON_SUCCESS ))) exit(-1); \
        fill = 0; \
        } \
      else \
        fill++;

#define FLUSH_BATCH(stmt, fill)  \
  if (fill > 0) \
    { \
      if (checkerr(errhp, OCIStmtExecute(svchp, stmt, errhp, (ub4) fill, (ub4) 0, \
        (CONST OCISnapshot *) NULL, (OCISnapshot *) NULL, OCI_COMMIT_ON_SUCCESS ))) exit(-1); \
        fill = 0; \
    };


extern SDWORD sql_timelen_array[BATCH_SIZE];


void
LoadItems ()
{
  long i;
  int fill = 0;
  long i_id_1;
  static int i_id[BATCH_SIZE];
  static text i_name[BATCH_SIZE][24];
  static float i_price[BATCH_SIZE];
  static text i_data[BATCH_SIZE][50];
  OCIBind *bndhp[4];
  OCIStmt *item_stmt;
  int idatasiz;
  static short orig[MAXITEMS];
  long pos;

  INIT_STMT (item_stmt,
      "insert into item (i_id, i_name, i_price, i_data) values (:i_id, :i_name, :i_price, :i_data)");
  alloc_bind_handle (item_stmt, bndhp, 4);

  IBINDL_ARRAY (item_stmt, bndhp[0], 1, i_id[0]);
  IBINDS_ARRAY (item_stmt, bndhp[1], 2, i_name);
  IBINDF_ARRAY (item_stmt, bndhp[2], 3, i_price[0]);
  IBINDS_ARRAY (item_stmt, bndhp[3], 4, i_data);

#if defined (GUI)
  log (0, "Loading ITEM");
#else
  printf ("Loading ITEM\n");
#endif

  for (i = 0; i < MAXITEMS / 10; i++)
    orig[i] = 0;

#if 1
  for (i = 0; i < MAXITEMS / 10; i++)
    {
      do
	{
	  pos = RandomNumber (0L, MAXITEMS);
	}
      while (orig[pos]);
      orig[pos] = 1;
    }
#endif

#if defined (GUI)
  set_progress_max (MAXITEMS);
#endif
  for (i_id_1 = 1; i_id_1 <= MAXITEMS; i_id_1++)
    {

      /* Generate Item Data */
      i_id[fill] = i_id_1;
      MakeAlphaString (14, 24, i_name[fill]);
      i_price[fill] = ((float) RandomNumber (100L, 10000L)) / 100.0;
      idatasiz = MakeAlphaString (26, 50, i_data[fill]);
      if (orig[i_id_1])
	{
	  pos = RandomNumber (0L, idatasiz - 8);
	  i_data[fill][pos] = 'o';
	  i_data[fill][pos + 1] = 'r';
	  i_data[fill][pos + 2] = 'i';
	  i_data[fill][pos + 3] = 'g';
	  i_data[fill][pos + 4] = 'i';
	  i_data[fill][pos + 5] = 'n';
	  i_data[fill][pos + 6] = 'a';
	  i_data[fill][pos + 7] = 'l';
	}

      CHECK_BATCH (item_stmt, fill);

      if (!(i_id_1 % 100))
	{
#if defined (GUI)
	  progress (i_id_1);
#else
	  printf ("%6ld\r", i_id_1);
	  fflush (stdout);
#endif
	}
    }
#if defined (GUI)
  progress_done ();
#endif

  FLUSH_BATCH (item_stmt, fill);
  FREE_STMT (item_stmt);
  /* printf ("ITEM loaded.\n"); */

  return;
}


void
LoadWare ()
{
  long w_id;
  text w_name[10];
  text w_street_1[20];
  text w_street_2[20];
  text w_city[20];
  text w_state[2];
  text w_zip[9];
  float w_tax;
  float w_ytd;
  OCIBind *bndhp[9];
  OCIStmt *ware_stmt;

  INIT_STMT (ware_stmt,
      "insert into warehouse (w_id, w_name,"
      "    w_street_1, w_street_2, w_city, w_state, w_zip, w_tax, w_ytd)"
      "  values (:w_id, :w_name, :w_street_1, :w_street_2, :w_city, :w_state, :w_zip, :w_tax , :w_ytd)");
  alloc_bind_handle (ware_stmt, bndhp, 9);

  IBINDL (ware_stmt, bndhp[0], 1, w_id);
  IBINDS (ware_stmt, bndhp[1], 2, w_name);
  IBINDS (ware_stmt, bndhp[2], 3, w_street_1);
  IBINDS (ware_stmt, bndhp[3], 4, w_street_2);
  IBINDS (ware_stmt, bndhp[4], 5, w_city);
  IBINDS (ware_stmt, bndhp[5], 6, w_state);
  IBINDS (ware_stmt, bndhp[6], 7, w_zip);
  IBINDF (ware_stmt, bndhp[7], 8, w_tax);
  IBINDF (ware_stmt, bndhp[8], 9, w_ytd);

#if defined (GUI)
  log (0, "Loading WAREHOUSE");
#else
  printf ("Loading WAREHOUSE\n");
#endif
  for (w_id = 1; w_id <= count_ware; w_id++)
    {
      /* Generate Warehouse Data */
      MakeAlphaString (6, 10, w_name);
      MakeAddress (w_street_1, w_street_2, w_city, w_state, w_zip);
      w_tax = ((float) RandomNumber (10L, 20L)) / 100.0;
      w_ytd = 3000000.00;

      if (option_debug)
#if defined (GUI)
	log (0, "WID = %ld, Name= %16s, Tax = %5.2f", w_id, w_name, w_tax);
#else
	printf ("WID = %ld, Name= %16s, Tax = %5.2f\n", w_id, w_name, w_tax);
#endif


      rc =
	  checkerr (errhp, OCIStmtExecute (svchp, ware_stmt, errhp, (ub4) 1,
	     (ub4) 0, (CONST OCISnapshot *) NULL, (OCISnapshot *) NULL,
	      OCI_COMMIT_ON_SUCCESS));


      if (rc)
	exit (-1);

      /** Make Rows associated with Warehouse **/
      District (w_id);
    }
  Stock (1, count_ware);

  return;
}


void
LoadCust ()
{
  long w_id;
  long d_id;

  for (w_id = 1L; w_id <= count_ware; w_id++)
    for (d_id = 1L; d_id <= DIST_PER_WARE; d_id++)
      Customer (d_id, w_id);
  checkerr (errhp, OCITransCommit (svchp, errhp, OCI_DEFAULT));
  return;
}


void
LoadOrd ()
{
  long w_id;
  long d_id;

  for (w_id = 1L; w_id <= count_ware; w_id++)
    for (d_id = 1L; d_id <= DIST_PER_WARE; d_id++)
      Orders (d_id, w_id);
  checkerr (errhp, OCITransCommit (svchp, errhp, OCI_DEFAULT));
  return;
}


void
Stock (long w_id_from, long w_id_to)
{
  long w_id;
  long s_i_id_1;
  static int s_i_id[BATCH_SIZE];
  static int s_w_id[BATCH_SIZE];
  static int s_quantity[BATCH_SIZE];
  static text s_dist_01[BATCH_SIZE][24];
  static text s_dist_02[BATCH_SIZE][24];
  static text s_dist_03[BATCH_SIZE][24];
  static text s_dist_04[BATCH_SIZE][24];
  static text s_dist_05[BATCH_SIZE][24];
  static text s_dist_06[BATCH_SIZE][24];
  static text s_dist_07[BATCH_SIZE][24];
  static text s_dist_08[BATCH_SIZE][24];
  static text s_dist_09[BATCH_SIZE][24];
  static text s_dist_10[BATCH_SIZE][24];
  static text s_data[BATCH_SIZE][50];

  int fill = 0;
  int sdatasiz;
  long orig[MAXITEMS];
  long pos;
  int i;
  OCIBind *bndhp[14];
  OCIStmt *stock_stmt;

  INIT_STMT (stock_stmt, "insert into stock \
         (s_i_id, s_w_id, s_quantity, \
      s_dist_01, s_dist_02, s_dist_03, s_dist_04, s_dist_05,\
      s_dist_06, s_dist_07, s_dist_08, s_dist_09, s_dist_10, \
      s_data, s_ytd, s_cnt_order, s_cnt_remote) \
      VALUES (:s_i_id, :s_w_id, :s_quantity, :s_dist_01, :s_dist_02, :s_dist_03,\
       :s_dist_04, :s_dist_05, :s_dist_06, :s_dist_07, :s_dist_08, :s_dist_09, \
       :s_dist_10, :s_data, 0,0,0)");
  alloc_bind_handle (stock_stmt, bndhp, 14);

  IBINDL_ARRAY (stock_stmt, bndhp[0], 1, s_i_id[0]);
  IBINDL_ARRAY (stock_stmt, bndhp[1], 2, s_w_id[0]);
  IBINDL_ARRAY (stock_stmt, bndhp[2], 3, s_quantity[0]);
  IBINDS_ARRAY (stock_stmt, bndhp[3], 4, s_dist_01);
  IBINDS_ARRAY (stock_stmt, bndhp[4], 5, s_dist_02);
  IBINDS_ARRAY (stock_stmt, bndhp[5], 6, s_dist_03);
  IBINDS_ARRAY (stock_stmt, bndhp[6], 7, s_dist_04);
  IBINDS_ARRAY (stock_stmt, bndhp[7], 8, s_dist_05);
  IBINDS_ARRAY (stock_stmt, bndhp[8], 9, s_dist_06);
  IBINDS_ARRAY (stock_stmt, bndhp[9], 10, s_dist_07);
  IBINDS_ARRAY (stock_stmt, bndhp[10], 11, s_dist_08);
  IBINDS_ARRAY (stock_stmt, bndhp[11], 12, s_dist_09);
  IBINDS_ARRAY (stock_stmt, bndhp[12], 13, s_dist_10);
  IBINDS_ARRAY (stock_stmt, bndhp[13], 14, s_data);

#if defined (GUI)
  log (0, "Loading STOCK for Wid=%ld-%ld", w_id_from, w_id_to);
  set_progress_max (MAXITEMS);
#else
  printf ("Loading STOCK for Wid=%ld-%ld\n", w_id_from, w_id_to);
#endif

  for (i = 0; i < MAXITEMS / 10; i++)
    orig[i] = 0;
  for (i = 0; i < MAXITEMS / 10; i++)
    {
      do
	{
	  pos = RandomNumber (0L, MAXITEMS);
	}
      while (orig[pos]);
      orig[pos] = 1;
    }

  for (w_id = w_id_from; w_id <= w_id_to; w_id++)
    {
      for (s_i_id_1 = 1; s_i_id_1 <= MAXITEMS; s_i_id_1++)
	{
	  if (s_i_id_1 % 100 == 0)
	    {
#if defined (GUI)
	      progress (s_i_id_1);
#else
	      printf ("%6ld\r", s_i_id_1);
	      fflush (stdout);
#endif
	    }
	  /* Generate Stock Data */
	  s_i_id[fill] = s_i_id_1;
	  s_w_id[fill] = w_id;
	  s_quantity[fill] = RandomNumber (10L, 100L);
	  MakeAlphaString (24, 24, s_dist_01[fill]);
	  MakeAlphaString (24, 24, s_dist_02[fill]);
	  MakeAlphaString (24, 24, s_dist_03[fill]);
	  MakeAlphaString (24, 24, s_dist_04[fill]);
	  MakeAlphaString (24, 24, s_dist_05[fill]);
	  MakeAlphaString (24, 24, s_dist_06[fill]);
	  MakeAlphaString (24, 24, s_dist_07[fill]);
	  MakeAlphaString (24, 24, s_dist_08[fill]);
	  MakeAlphaString (24, 24, s_dist_09[fill]);
	  MakeAlphaString (24, 24, s_dist_10[fill]);

	  sdatasiz = MakeAlphaString (26, 50, s_data[fill]);

	  if (orig[s_i_id_1])
	    {
	      pos = RandomNumber (0L, sdatasiz - 8);
	      s_data[fill][pos] = 'o';
	      s_data[fill][pos + 1] = 'r';
	      s_data[fill][pos + 2] = 'i';
	      s_data[fill][pos + 3] = 'g';
	      s_data[fill][pos + 4] = 'i';
	      s_data[fill][pos + 5] = 'n';
	      s_data[fill][pos + 6] = 'a';
	      s_data[fill][pos + 7] = 'l';
	    }

	  CHECK_BATCH (stock_stmt, fill);
	}
    }
#if defined (GUI)
  progress_done ();
#endif
  FLUSH_BATCH (stock_stmt, fill);
  FREE_STMT (stock_stmt);

  /* printf ("STOCK loaded.\n"); */
  return;
}


void
District (long w_id)
{
  long d_id;
  long d_w_id;
  char d_name[10];
  char d_street_1[20];
  char d_street_2[20];
  char d_city[20];
  char d_state[2];
  char d_zip[9];
  float d_tax;
  float d_ytd;
  long d_next_o_id;
  OCIBind *bndhp[11];
  OCIStmt *dist_stmt;
  INIT_STMT (dist_stmt, "insert into district \
       (d_id, d_w_id, d_name, \
      d_street_1, d_street_2, d_city, d_state, d_zip, \
      d_tax, d_ytd, d_next_o_id) \
      values (:d_id, :d_w_id, :d_name, :d_street_1, :d_street_2, \
      :d_city, :d_state, :d_zip, :d_tax, :d_ytd, :d_next_o_id)");
  alloc_bind_handle (dist_stmt, bndhp, 11);
  IBINDL (dist_stmt, bndhp[0], 1, d_id);
  IBINDL (dist_stmt, bndhp[1], 2, d_w_id);
  IBINDS (dist_stmt, bndhp[2], 3, d_name);
  IBINDS (dist_stmt, bndhp[3], 4, d_street_1);
  IBINDS (dist_stmt, bndhp[4], 5, d_street_2);
  IBINDS (dist_stmt, bndhp[5], 6, d_city);
  IBINDS (dist_stmt, bndhp[6], 7, d_state);
  IBINDS (dist_stmt, bndhp[7], 8, d_zip);
  IBINDF (dist_stmt, bndhp[8], 9, d_tax);
  IBINDF (dist_stmt, bndhp[9], 10, d_ytd);
  IBINDL (dist_stmt, bndhp[10], 11, d_next_o_id);

#if defined (GUI)
  log (0, "Loading DISTRICT");
#else
  printf ("Loading DISTRICT\n");
#endif

  d_w_id = w_id;
  d_ytd = 300000.0;
  d_next_o_id = 3001L;
  for (d_id = 1; d_id <= DIST_PER_WARE; d_id++)
    {
      /* Generate District Data */
      MakeAlphaString (6, 10, d_name);
      MakeAddress (d_street_1, d_street_2, d_city, d_state, d_zip);
      d_tax = ((float) RandomNumber (10L, 20L)) / 100.0;

      if (checkerr (errhp, OCIStmtExecute (svchp, dist_stmt, errhp, (ub4) 1,
		  (ub4) 0, (CONST OCISnapshot *) NULL, (OCISnapshot *) NULL,
		  OCI_COMMIT_ON_SUCCESS))) exit (-1);



      if (option_debug)
#if defined (GUI)
	log (0, "DID = %ld, WID = %ld, Name = %10s, Tax = %5.2f",
	    d_id, d_w_id, d_name, d_tax);
#else
	printf ("DID = %ld, WID = %ld, Name = %10s, Tax = %5.2f\n",
	    d_id, d_w_id, d_name, d_tax);
#endif
    }
  checkerr (errhp, OCITransCommit (svchp, errhp, OCI_DEFAULT));
  /* printf ("DISTRICT loaded.\n"); */

  return;
}


void
Customer (long d_id_1, long w_id_1)
{
  long c_id_1;
  static int w_id[BATCH_SIZE];
  static int c_id[BATCH_SIZE];
  static int c_d_id[BATCH_SIZE];
  static int c_w_id[BATCH_SIZE];
  static text c_first[BATCH_SIZE][17];
  static text c_middle[BATCH_SIZE][3];
  static text c_last[BATCH_SIZE][17];
  static text c_street_1[BATCH_SIZE][21];
  static text c_street_2[BATCH_SIZE][21];
  static text c_city[BATCH_SIZE][21];
  static text c_state[BATCH_SIZE][3];
  static text c_zip[BATCH_SIZE][10];
  static text c_phone[BATCH_SIZE][17];
  static text c_credit[BATCH_SIZE][3];	/*initial 0's */
  static float c_credit_lim[BATCH_SIZE];
  static float c_discount[BATCH_SIZE];
  static float c_balance[BATCH_SIZE];
  static text c_data_1[BATCH_SIZE][251];
  static text c_data_2[BATCH_SIZE][251];
  static float h_amount[BATCH_SIZE];
  static text h_data[BATCH_SIZE][25];

  int fill = 0, h_fill = 0;
  OCIBind *cbndhp[18];
  OCIStmt *cs_stmt;

  OCIBind *hbndhp[7];
  OCIStmt *h_stmt;


  INIT_STMT (cs_stmt, "insert into customer (c_id, c_d_id, c_w_id,\
      c_first, c_middle, c_last, \
      c_street_1, c_street_2, c_city, c_state, c_zip,\
      c_phone, c_since, c_credit, \
      c_credit_lim, c_discount, c_balance, c_data_1, c_data_2,\
      c_ytd_payment, c_cnt_payment, c_cnt_delivery) \
      values (:c_id,:c_d_id, :c_w_id, :c_first, :c_middle, :c_last,\
      :c_street_1, :c_street_2, :c_city, :c_state,   :c_zip, :c_phone ,sysdate,\
      :c_credit, :c_credit_lim, :c_discount, :c_balance, :c_data_1, :c_data_2,\
      10.0, 1, 0)");
  alloc_bind_handle (cs_stmt, cbndhp, 18);
  IBINDL_ARRAY (cs_stmt, cbndhp[0], 1, c_id[0]);
  IBINDL_ARRAY (cs_stmt, cbndhp[1], 2, c_d_id[0]);
  IBINDL_ARRAY (cs_stmt, cbndhp[2], 3, c_w_id[0]);
  IBINDS_ARRAY (cs_stmt, cbndhp[3], 4, c_first);
  IBINDS_ARRAY (cs_stmt, cbndhp[4], 5, c_middle);
  IBINDS_ARRAY (cs_stmt, cbndhp[5], 6, c_last);
  IBINDS_ARRAY (cs_stmt, cbndhp[6], 7, c_street_1);
  IBINDS_ARRAY (cs_stmt, cbndhp[7], 8, c_street_2);
  IBINDS_ARRAY (cs_stmt, cbndhp[8], 9, c_city);
  IBINDS_ARRAY (cs_stmt, cbndhp[9], 10, c_state);
  IBINDS_ARRAY (cs_stmt, cbndhp[10], 11, c_zip);
  IBINDS_ARRAY (cs_stmt, cbndhp[11], 12, c_phone);
  IBINDS_ARRAY (cs_stmt, cbndhp[12], 13, c_credit);
  IBINDF_ARRAY (cs_stmt, cbndhp[13], 14, c_credit_lim[0]);
  IBINDF_ARRAY (cs_stmt, cbndhp[14], 15, c_discount[0]);
  IBINDF_ARRAY (cs_stmt, cbndhp[15], 16, c_balance[0]);
  IBINDS_ARRAY (cs_stmt, cbndhp[16], 17, c_data_1);
  IBINDS_ARRAY (cs_stmt, cbndhp[17], 18, c_data_2);

  INIT_STMT (h_stmt,
      "insert into history ("
      "  h_c_id, h_c_d_id, h_c_w_id, h_w_id, h_d_id, h_date, h_amount, h_data)"
      "values (:h_c_id, :h_c_d_id, :h_c_w_id, :h_w_id,  :h_d_id, sysdate, :h_amount, :h_data)");

  alloc_bind_handle (h_stmt, hbndhp, 7);

  IBINDL_ARRAY (h_stmt, hbndhp[0], 1, c_id[0]);
  IBINDL_ARRAY (h_stmt, hbndhp[1], 2, c_d_id[0]);
  IBINDL_ARRAY (h_stmt, hbndhp[2], 3, c_w_id[0]);
  IBINDL_ARRAY (h_stmt, hbndhp[3], 4, c_w_id[0]);
  IBINDL_ARRAY (h_stmt, hbndhp[4], 5, c_d_id[0]);
  IBINDF_ARRAY (h_stmt, hbndhp[5], 6, h_amount[0]);
  IBINDS_ARRAY (h_stmt, hbndhp[6], 7, h_data);

#if defined (GUI)
  log (0, "Loading CUSTOMER for DID=%ld, WID=%ld", d_id_1, w_id_1);
#else
  printf ("Loading CUSTOMER for DID=%ld, WID=%ld\n", d_id_1, w_id_1);
#endif

  for (c_id_1 = 1; c_id_1 <= CUST_PER_DIST; c_id_1++)
    {
      /* Generate Customer Data */
      w_id[fill] = w_id_1;
      c_id[fill] = c_id_1;
      c_d_id[fill] = d_id_1;
      c_w_id[fill] = w_id_1;

      MakeAlphaString (8, 15, c_first[fill]);
      MakeAlphaString (240, 240, c_data_1[fill]);
      MakeAlphaString (240, 240, c_data_2[fill]);
      c_middle[fill][0] = 'J';
      c_middle[fill][1] = 0;
      memset (c_last[fill], 0, 17);
      if (c_id_1 <= 1000)
	Lastname (c_id_1 - 1, c_last[fill]);
      else
	Lastname (NURand (255, 0, 999), c_last[fill]);
      MakeAddress (c_street_1[fill], c_street_2[fill],
	  c_city[fill], c_state[fill], c_zip[fill]);
      MakeNumberString (16, 16, c_phone[fill]);
      if (RandomNumber (0L, 1L))
	c_credit[fill][0] = 'G';
      else
	c_credit[fill][0] = 'B';
      c_credit[fill][1] = 'C';
      c_credit_lim[fill] = 500;
      c_discount[fill] = ((float) RandomNumber (0L, 50L)) / 100.0;
      c_balance[fill] = 10.0;
      CHECK_BATCH (cs_stmt, fill);

      gettimestamp (timestamp_array[h_fill]);
      h_amount[h_fill] = 10.0;
      MakeAlphaString (12, 24, h_data[h_fill]);

      CHECK_BATCH (h_stmt, h_fill);
    }
  FLUSH_BATCH (cs_stmt, fill);
  FLUSH_BATCH (h_stmt, h_fill);

  /* printf ("CUSTOMER loaded.\n"); */

  return;
}


void
Orders (long d_id, long w_id)
{
  int ol_1;
  int o_id_1;
  static int o_id[BATCH_SIZE];
  static int o_c_id[BATCH_SIZE];
  static int o_d_id[BATCH_SIZE];
  static int o_w_id[BATCH_SIZE];
  static int o_carrier_id[BATCH_SIZE];
  static int o_ol_cnt[BATCH_SIZE];
  static int ol[BATCH_SIZE];
  static int ol_i_id[BATCH_SIZE];
  static int ol_supply_w_id[BATCH_SIZE];
  static int ol_quantity[BATCH_SIZE];
  static int ol_amount[BATCH_SIZE];
  static text ol_dist_info[BATCH_SIZE][24];
  static int ol_o_id[BATCH_SIZE];
  static int ol_o_d_id[BATCH_SIZE];
  static int ol_o_w_id[BATCH_SIZE];
  int fill = 0, ol_fill = 0;
  int _d_id_ = 0;
  static int no_o_id;
  static int no_w_id;
  static int no_d_id;

  OCIBind *o_bndhp[6];
  OCIStmt *o_stmt;

  OCIBind *no_bndhp[3];
  OCIStmt *no_stmt;

  OCIBind *ol_bndhp[9];
  OCIStmt *ol_stmt;

  _d_id_ = d_id;

  INIT_STMT (o_stmt,
      "insert into "
      " orders (o_id, o_c_id, o_d_id, o_w_id, "
      "o_entry_d, o_carrier_id, o_ol_cnt, o_all_local)"
      "values (:o_id, :o_c_id, :o_d_id, :o_w_id,  sysdate, :o_carrier_id, :o_ol_cnt, 1)");
  alloc_bind_handle (o_stmt, o_bndhp, 6);
  IBINDL_ARRAY (o_stmt, o_bndhp[0], 1, o_id[0]);
  IBINDL_ARRAY (o_stmt, o_bndhp[1], 2, o_c_id[0]);
  IBINDL_ARRAY (o_stmt, o_bndhp[2], 3, o_d_id[0]);
  IBINDL_ARRAY (o_stmt, o_bndhp[3], 4, o_w_id[0]);
  IBINDL_ARRAY (o_stmt, o_bndhp[4], 5, o_carrier_id[0]);
  IBINDL_ARRAY (o_stmt, o_bndhp[5], 6, o_ol_cnt[0]);

  INIT_STMT (ol_stmt, "insert into \
      order_line (ol_o_id, ol_d_id, ol_w_id, ol_number, \
      ol_i_id, ol_supply_w_id, ol_quantity, ol_amount, \
      ol_dist_info, ol_delivery_d) \
      values (:ol_o_id, :ol_d_id, :ol_w_id, :ol_number, :ol_i_id,\
      :ol_supply_w_id, :ol_quantity, :ol_amount, :ol_dist_info,  NULL)");
  alloc_bind_handle (ol_stmt, ol_bndhp, 9);

  IBINDL_ARRAY (ol_stmt, ol_bndhp[0], 1, ol_o_id[0]);
  IBINDL_ARRAY (ol_stmt, ol_bndhp[1], 2, ol_o_d_id[0]);
  IBINDL_ARRAY (ol_stmt, ol_bndhp[2], 3, ol_o_w_id[0]);
  IBINDL_ARRAY (ol_stmt, ol_bndhp[3], 4, ol[0]);
  IBINDL_ARRAY (ol_stmt, ol_bndhp[4], 5, ol_i_id[0]);
  IBINDL_ARRAY (ol_stmt, ol_bndhp[5], 6, ol_supply_w_id[0]);
  IBINDL_ARRAY (ol_stmt, ol_bndhp[6], 7, ol_quantity[0]);
  IBINDL_ARRAY (ol_stmt, ol_bndhp[7], 8, ol_amount[0]);
  IBINDS_ARRAY (ol_stmt, ol_bndhp[8], 9, ol_dist_info);

  INIT_STMT (no_stmt,
      "insert into new_order (no_o_id, no_d_id, no_w_id) values (:no_o_id, :no_d_id, :no_w_id)");
  alloc_bind_handle (no_stmt, no_bndhp, 3);
  IBINDL (no_stmt, no_bndhp[0], 1, no_o_id);
  IBINDL (no_stmt, no_bndhp[1], 2, no_d_id);
  IBINDL (no_stmt, no_bndhp[2], 3, no_w_id);

#if defined (GUI)
  log (0, "Loading ORDERS for D=%ld, W= %ld", d_id, w_id);
  set_progress_max (ORD_PER_DIST);
#else
  printf ("Loading ORDERS for D=%ld, W= %ld\n", d_id, w_id);
#endif

  for (o_id_1 = 1; o_id_1 <= ORD_PER_DIST; o_id_1++)
    {
      /* Generate Order Data */
      o_id[fill] = o_id_1;
      o_d_id[fill] = d_id;
      o_w_id[fill] = w_id;
      o_c_id[fill] = RandomNumber (1, CUST_PER_DIST);	/* GetPermutation(); */
      o_carrier_id[fill] = RandomNumber (1L, 10L);
      o_ol_cnt[fill] = RandomNumber (5L, 15L);

      /* the last 900 orders have not been delivered */
      if (o_id_1 > ORD_PER_DIST - 900)
	{
	  no_o_id = o_id_1;
	  no_d_id = _d_id_;
	  no_w_id = o_w_id[fill];
	  if (checkerr (errhp, OCIStmtExecute (svchp, no_stmt, errhp, (ub4) 1,
		      (ub4) 0, (CONST OCISnapshot *) NULL,
		      (OCISnapshot *) NULL, OCI_COMMIT_ON_SUCCESS)))
	    {
	      exit (-1);
	    }

	}

      /* Generate Order Line Data */
      for (ol_1 = 1; ol_1 <= o_ol_cnt[fill]; ol_1++)
	{
	  ol[ol_fill] = ol_1;
	  ol[ol_fill] = ol_1;
	  ol_o_id[ol_fill] = o_id[fill];
	  ol_o_d_id[ol_fill] = o_d_id[fill];
	  ol_o_w_id[ol_fill] = o_w_id[fill];
	  ol_i_id[ol_fill] = RandomNumber (1L, MAXITEMS);
	  ol_supply_w_id[ol_fill] = o_w_id[fill];
	  ol_quantity[ol_fill] = 5;
	  ol_amount[ol_fill] = 0.0;

	  MakeAlphaString (24, 24, ol_dist_info[ol_fill]);

	  CHECK_BATCH (ol_stmt, ol_fill);
	}
      CHECK_BATCH (o_stmt, fill);

      if (!(o_id_1 % 100))
	{
#if defined (GUI)
	  progress (o_id_1);
#else
	  printf ("%6ld\r", (long)o_id_1);
	  fflush (stdout);
#endif
	}
    }
#if defined (GUI)
  progress_done ();
#endif

  FLUSH_BATCH (o_stmt, fill);
  FLUSH_BATCH (ol_stmt, ol_fill);

  FREE_STMT (o_stmt);
  FREE_STMT (ol_stmt);
  /* printf ("ORDERS loaded.\n"); */

  return;
}

void
remove_old_orders (int nCount)
{
  OCIStmt *remove_stmt;
  OCIBind *bndhp = (OCIBind *) 0;
  INIT_STMT (remove_stmt, "begin oldord(:nCount); end;");
  IBINDL (remove_stmt, bndhp, 1, nCount);
  if (checkerr (errhp, OCIStmtExecute (svchp, remove_stmt, errhp, (ub4) 1,
	      (ub4) 0, (CONST OCISnapshot *) NULL, (OCISnapshot *) NULL,
	      OCI_COMMIT_ON_SUCCESS)))
    {
      exit (-1);
    }

}

void
scrap_log ()
{
  OCIStmt *chk_stmt;
  INIT_STMT (chk_stmt, "alter system checkpoint");
  if (checkerr (errhp, OCIStmtExecute (svchp, chk_stmt, errhp, (ub4) 1,
	      (ub4) 0, (CONST OCISnapshot *) NULL, (OCISnapshot *) NULL,
	      OCI_COMMIT_ON_SUCCESS)))
    {
      exit (-1);
    }

}
