/*
 *  blobs.c
 *
 *  $Id$
 *
 *  BLOBS test
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

#include <stdio.h>
#include <memory.h>
#include <stdlib.h>
#include <string.h>

#ifdef UNIX
#include <sys/time.h>
#endif

#include "libutil.h"
#if defined (WIN32) | defined (WINDOWS)
#include <windows.h>
#endif

#include "odbcinc.h"
#include "timeacct.h"
#include "odbcuti.h"


int messages_off = 0;
int quiet = 0;

HDBC hdbc;
HENV henv;
HSTMT b_stmt;

long read_msecs;
long write_msecs;
long read_bytes;
long write_bytes;


char *dd_stmt_text =
" create table BLOBS (ROW_NO integer, B1 long varchar, B2 long varbinary, B3 long nvarchar, B4 long varbinary, "
"                 primary key (ROW_NO))\n"
"alter index BLOBS on BLOBS partition (ROW_NO int)";


void
check_dd ()
{
  HSTMT ck_stmt;

  SQLAllocStmt (hdbc, &ck_stmt);

  SQLTables (ck_stmt, (UCHAR *) "%", SQL_NTS, (UCHAR *) "%", SQL_NTS,
      (UCHAR *) "BLOBS", SQL_NTS, (UCHAR *) "TABLE", SQL_NTS);

  if (SQL_SUCCESS != SQLFetch (ck_stmt))
    {
      SQLFreeStmt (ck_stmt, SQL_CLOSE);
      SQLExecDirect (ck_stmt, (UCHAR *) dd_stmt_text, SQL_NTS);
    }
  SQLFreeStmt (ck_stmt, SQL_DROP);
  SQLTransact (henv, hdbc, SQL_COMMIT);
}


void
print_error (HSTMT e1, HSTMT e2, HSTMT e3)
{
  SWORD len;
  char state[10];
  char message[1000];
  SQLError (e1, e2, e3, (UCHAR *) state, NULL,
      (UCHAR *) &message, sizeof (message), &len);
  printf ("\n*** Error %s: %s\n", state, message);
  if (0 == strcmp (state, "08S01"))
    exit (-1);
}

void
del_blobs ()
{
  IF_ERR_EXIT (b_stmt,
      SQLExecDirect (b_stmt, (UCHAR *) "delete from BLOBS", SQL_NTS));
  IF_CERR_EXIT (hdbc,
      SQLTransact (henv, hdbc, SQL_COMMIT));
}


unsigned
incremental_tridgell32 (unsigned char *data, unsigned char *data_end, unsigned initial_tridgell32)
{
  unsigned t32_lo = (initial_tridgell32 & 0xFFFF), t32_hi = (initial_tridgell32 >> 16);
  unsigned char *tail;
  for (tail = data; tail < data_end; tail++)
   {
     t32_lo += tail[0];
     t32_hi += t32_lo;
   }
  return ((t32_hi << 16) | (t32_lo & 0xFFFF));
}

void
fill_test_wchar_t_buffer (wchar_t *buffer, int buf_length_in_symbols, long row_no, const char *col_name, int fragment_offset, unsigned *tridgell32_acc)
{
  static wchar_t pattern[] = L"0123456789 wide char blob with unicoded Cyrillic: \"\x41e\x43d \x434\x43e\x431\x430\x432\x438\x43b \x43a\x430\x440\x442\x43e\x448\x43a\x438,...\" ";
  static wchar_t thousand_pattern[] = L" THE THIRD CLOSING BRACE IS THE LAST CHAR OF A WHOLE THOUSAND: o123456789o123456789o123456789o123456789o123456]]]";
  size_t pattern_bytes = sizeof (pattern) - sizeof (wchar_t);
  size_t thousand_pattern_bytes = sizeof (thousand_pattern) - sizeof (wchar_t);
  wchar_t *tail = buffer, *buffer_end = (buffer + buf_length_in_symbols);
  unsigned char label_buf[100], *label_tail;
  while (tail < buffer_end - pattern_bytes / sizeof(wchar_t))
    {
      memcpy (tail, pattern, pattern_bytes);
      tail += pattern_bytes / sizeof (wchar_t);
    }
  if (tail < buffer_end)
    memcpy (tail, pattern, buffer_end - tail);
  for (tail = buffer + 1000 - (fragment_offset % 1000) - (thousand_pattern_bytes / sizeof (wchar_t)); tail < buffer_end; tail += 1000)
    {
      int bytes_to_fit = ((tail <= buffer_end - (thousand_pattern_bytes / sizeof (wchar_t))) ? thousand_pattern_bytes : ((buffer_end - tail) * sizeof (wchar_t)));
      if (tail >= buffer)
        memcpy (tail, thousand_pattern, bytes_to_fit);
      else
        memcpy (buffer, thousand_pattern + (buffer - tail), bytes_to_fit - (buffer - tail) * sizeof (wchar_t));
    }
  snprintf ((char *)label_buf, sizeof (label_buf), "[ Row #%ld, Column %s, offset %d ]", row_no, col_name, fragment_offset);
  label_tail = label_buf;
  tail = buffer;
  while ('\0' != label_tail[0]) (tail++)[0] = (label_tail++)[0];
  tridgell32_acc[0] = incremental_tridgell32 ((unsigned char *)buffer, (unsigned char *)buffer_end, tridgell32_acc[0]);
}

void
fill_test_char_buffer (unsigned char *buffer, int buf_length_in_symbols, long row_no, const char *col_name, int fragment_offset, unsigned *tridgell32_acc)
{
  static unsigned char pattern[] = "0123456789 single-byte char blob with UTF-8 Cyrillic: \"РћРЅ РґРѕР±Р°РІРёР» РєР°СЂС‚РѕС€РєРё,...\" and Windows-1251 Cyrillic: \"Он добавил картошки,...\" ";
  size_t pattern_bytes = sizeof (pattern) - sizeof (unsigned char);
  unsigned char *tail = (unsigned char *)buffer, *buffer_end = (unsigned char *)(buffer + buf_length_in_symbols);
  unsigned char label_buf[100];
  while (tail < buffer_end - pattern_bytes)
    {
      memcpy (tail, pattern, pattern_bytes);
      tail += pattern_bytes;
    }
  if (tail < buffer_end)
    memcpy (tail, pattern, buffer_end - tail);
  snprintf ((char *)label_buf, sizeof (label_buf), "[ Row #%ld, Column %s, offset %d ]", row_no, col_name, fragment_offset);
  memcpy (buffer, label_buf, strlen ((char *)label_buf));
  tridgell32_acc[0] = incremental_tridgell32 ((unsigned char *)buffer, buffer_end, tridgell32_acc[0]);
}

void
hexencode_chars_to_bin (unsigned char *bin_buffer, unsigned char *buffer, size_t buffer_bytes)
{
  int idx;
  for (idx = 0; idx < buffer_bytes; idx++)
    {
      bin_buffer[idx * 2] = "0123456789ABCDEF"[buffer[idx] >> 4];
      bin_buffer[idx * 2 + 1] = "0123456789ABCDEF"[buffer[idx] & 0xF];
    }
}

void
fill_test_bin_buffer (unsigned char *buffer, int buf_length_in_symbols, long row_no, const char *col_name, int fragment_offset, unsigned *tridgell32_acc)
{
  static unsigned char pattern[] = "0123456789 bin blob with UTF-8 Cyrillic: \"РћРЅ РґРѕР±Р°РІРёР» РєР°СЂС‚РѕС€РєРё,...\" and Windows-1251 Cyrillic: \"Он добавил картошки,...\" ";
  static unsigned char bin_pattern[sizeof (pattern)*2];
  static int bin_pattern_inited = 0;
  size_t pattern_bytes = (sizeof (pattern) - sizeof (unsigned char)), bin_pattern_bytes = pattern_bytes * 2;
  unsigned char *tail = (unsigned char *)buffer, *buffer_end = (unsigned char *)(buffer + buf_length_in_symbols);
  unsigned char label_buf[100];
  if (!bin_pattern_inited)
    {
      hexencode_chars_to_bin (bin_pattern, pattern, pattern_bytes);
      bin_pattern_inited = 1;
    }
  while (tail < buffer_end - bin_pattern_bytes)
    {
      memcpy (tail, bin_pattern, bin_pattern_bytes);
      tail += bin_pattern_bytes;
    }
  if (tail < buffer_end)
    memcpy (tail, bin_pattern, buffer_end - tail);
  snprintf ((char *)label_buf, sizeof (label_buf), "[ Row #%ld, Column %s, offset %d ]", row_no, col_name, fragment_offset);
  hexencode_chars_to_bin (buffer, label_buf, strlen ((char *)label_buf));
  tridgell32_acc[0] = incremental_tridgell32 ((unsigned char *)buffer, buffer_end, tridgell32_acc[0]);
}

#define BLOCK_SYMBOLS 10000
HSTMT test_insert_stmt;
HSTMT test_update_stmt;

typedef struct known_checksum_s {
  long kc_row_no;
  const char *kc_col_name;
  int kc_length_in_symbols;
  unsigned kc_tridgell32;
} known_checksum_t;

known_checksum_t known_checksums[1000];
int known_checksum_count = 0;

int
recall_checksum (long row_no, const char *col_name, int length_in_symbols, unsigned *tridgell32_ret)
{
  known_checksum_t *iter, *end = known_checksums + known_checksum_count;
  for (iter = known_checksums; iter < end; iter++)
    {
      if (iter->kc_row_no != row_no) continue;
      if (iter->kc_length_in_symbols != length_in_symbols) continue;
      if (strcmp (iter->kc_col_name, col_name)) continue;
      tridgell32_ret[0] = iter->kc_tridgell32;
      return 1;
    }
  return 0;
}

void
verify_checksum (long row_no, const char *col_name, int length_in_symbols, unsigned tridgell32, long new_row_no, const char *timing)
{
  unsigned old_t32 = 0;
  if (recall_checksum (row_no, col_name, length_in_symbols, &old_t32))
    {
      if (old_t32 != tridgell32)
        printf ("*** FAILED: Checksum for ROW_NO %ld column %s, length %d symbols: expected value is %u actual in ROW_NO %ld is %u, %s\n", row_no, col_name, length_in_symbols, old_t32, new_row_no, tridgell32, timing);
      else
        printf ("PASSED: Checksum for ROW_NO %ld column %s, length %d symbols: expected value is %u actual in ROW_NO %ld %u, %s\n", row_no, col_name, length_in_symbols, old_t32, new_row_no, tridgell32, timing);
      return;
    }
  printf ("*** FAILED: Checksum for ROW_NO %ld column %s, length %d symbols: value is %u in ROW_NO %ld, %s, but it was never remembered\n", row_no, col_name, length_in_symbols, tridgell32, new_row_no, timing);
}

void
store_checksum (long row_no, const char *col_name, int length_in_symbols, unsigned tridgell32)
{
  known_checksum_t *new_kc;
  unsigned old_t32 = 0;
  if (recall_checksum (row_no, col_name, length_in_symbols, &old_t32))
    {
      if (old_t32 != tridgell32)
        printf ("*** FAILED: Checksum for ROW_NO %ld column %s, length %d symbols: it was %u now %u, weird\n", row_no, col_name, length_in_symbols, old_t32, tridgell32);
      return;
    }
  if (known_checksum_count >= (sizeof (known_checksums) / sizeof (known_checksums[0])))
    {
      printf ("*** FAILED: internal error in %s: please increase size of known_checksums array\n", __FILE__);
      return;
    }
  new_kc = known_checksums + known_checksum_count++;
  new_kc->kc_row_no = row_no;
  new_kc->kc_col_name = col_name;
  new_kc->kc_length_in_symbols = length_in_symbols;
  new_kc->kc_tridgell32 = tridgell32;
}


void
ins_or_upd_blob (long row_no, int n_blocks, int is_update)
{
  long w_start;
  long rc, n_param, c;
  SQLLEN B1_len = SQL_DATA_AT_EXEC, B2_len = SQL_DATA_AT_EXEC, B3_len = SQL_DATA_AT_EXEC, B4_len = SQL_DATA_AT_EXEC;
  HSTMT stmt;
  unsigned B1_t32 = 0, B2_t32 = 0, B3_t32 = 0, B4_t32 = 0;
  if (!test_insert_stmt)
    INIT_STMT (hdbc, test_insert_stmt, "insert into BLOBS (B1, B2, B3, B4, ROW_NO) values (?,?,?,?,?)");
  if (!test_update_stmt)
    INIT_STMT (hdbc, test_update_stmt, "update BLOBS set B1 = ?, B2 = ?, B3 = ?, B4 = ? where ROW_NO = ?");
  stmt = (is_update ? test_update_stmt : test_insert_stmt);
  IF_ERR (stmt, SQLSetParam (stmt, 1, SQL_C_CHAR	, SQL_LONGVARCHAR	, 10, 0, (void *) 1L, &B1_len));
  IF_ERR (stmt, SQLSetParam (stmt, 2, SQL_C_BINARY	, SQL_LONGVARBINARY	, 10, 0, (void *) 2L, &B2_len));
  IF_ERR (stmt, SQLSetParam (stmt, 3, SQL_C_WCHAR	, SQL_WLONGVARCHAR	, 10, 0, (void *) 3L, &B3_len));
  IF_ERR (stmt, SQLSetParam (stmt, 4, SQL_C_CHAR	, SQL_LONGVARBINARY	, 10, 0, (void *) 4L, &B4_len));
  IBINDL (stmt, 5, row_no);

  w_start = get_msec_count ();
  rc = SQLExecute (stmt);
  IF_ERR_GO (stmt, err, rc);
  rc = SQLParamData (stmt, (void **) &n_param);
  while (rc == SQL_NEED_DATA)
    {
      char blob_fname[128];
      FILE *blob_f;
      snprintf (blob_fname, sizeof (blob_fname), "blobs_row_%ld_B%d_%ld_ORIG.bin", row_no, (int)n_param, (long)n_blocks * BLOCK_SYMBOLS);
      blob_f = fopen (blob_fname, "wb");
      switch (n_param)
	{
	case 1:
	  B1_t32 = 0;
	  for (c = 0; c < n_blocks; c++)
	    {
	      unsigned char temp[BLOCK_SYMBOLS];
	      fill_test_char_buffer (temp, BLOCK_SYMBOLS, row_no, "B1", c * BLOCK_SYMBOLS, &B1_t32);
              fwrite (temp, sizeof (temp), 1, blob_f);
	      IF_ERR_GO (stmt, i_err_1,
		  SQLPutData (stmt, temp, sizeof (temp)));
	      write_bytes += sizeof (temp);
	    }
i_err_1:
          store_checksum (row_no, "B1", n_blocks * BLOCK_SYMBOLS, B1_t32);
	  break;

	case 2:
	  B2_t32 = 0;
	  for (c = 0; c < n_blocks; c++)
	    {
	      unsigned char temp[BLOCK_SYMBOLS];
	      fill_test_char_buffer (temp, BLOCK_SYMBOLS, row_no, "B2", c * BLOCK_SYMBOLS, &B2_t32);
              fwrite (temp, sizeof (temp), 1, blob_f);
	      IF_ERR_GO (stmt, i_err_2,
		  SQLPutData (stmt, temp, sizeof (temp)));
	      write_bytes += sizeof (temp);
	    }
i_err_2:
          store_checksum (row_no, "B2", n_blocks * BLOCK_SYMBOLS, B2_t32);
	  break;

	case 3:
	  B3_t32 = 0;
	  for (c = 0; c < n_blocks; c++)
	    {
	      wchar_t wtemp[BLOCK_SYMBOLS];
	      fill_test_wchar_t_buffer (wtemp, BLOCK_SYMBOLS, row_no, "B3", c * BLOCK_SYMBOLS, &B3_t32);
              fwrite (wtemp, sizeof (wtemp), 1, blob_f);
	      IF_ERR_GO (stmt, i_err_3,
		  SQLPutData (stmt, wtemp, sizeof (wtemp)));
	      write_bytes += sizeof (wtemp);
	    }
i_err_3:
          store_checksum (row_no, "B3", n_blocks * BLOCK_SYMBOLS, B3_t32);
	  break;

	case 4:
	  B4_t32 = 0;
	  for (c = 0; c < n_blocks; c++)
	    {
	      unsigned char btemp[BLOCK_SYMBOLS*2];
	      fill_test_bin_buffer (btemp, BLOCK_SYMBOLS*2, row_no, "B4", c * BLOCK_SYMBOLS, &B4_t32);
              fwrite (btemp, sizeof (btemp), 1, blob_f);
	      IF_ERR_GO (stmt, i_err_4,
		  SQLPutData (stmt, btemp, sizeof (btemp)));
	      write_bytes += sizeof (btemp);
	    }
i_err_4:
          store_checksum (row_no, "B4", n_blocks * BLOCK_SYMBOLS, B4_t32);
	  break;
	default:
	  printf ("*** FAILED: Bad param number %ld asked by SQLParamData.\n", n_param);
          break;
	}
      fclose (blob_f);
      rc = SQLParamData (stmt, (void **) &n_param);
    }

  IF_ERR_GO (stmt, err, rc);
  write_msecs += get_msec_count () - w_start;
  if (is_update)
    printf ("Update BLOBS, ROW_NO=%ld, checksums=%u,%u,%u,%u\n", row_no, B1_t32, B2_t32, B3_t32, B4_t32);
  else
    printf ("Insert into BLOBS, ROW_NO=%ld, checksums=%u,%u,%u,%u\n", row_no, B1_t32, B2_t32, B3_t32, B4_t32);
  return;
err:
  if (is_update)
    printf ("*** FAILED: Update BLOBS, ROW_NO=%ld, ERROR\n", row_no);
  else
    printf ("*** FAILED: Insert into BLOBS, ROW_NO=%ld, ERROR\n", row_no);
}

void
ins_blob (long row_no, int n_blocks)
{
  ins_or_upd_blob (row_no, n_blocks, 0);
}

void
upd_blob (long row_no, int n_blocks)
{
  ins_or_upd_blob (row_no, n_blocks, 1);
}

void
copy_blob (long from, long to)
{
  long rc;
  static HSTMT cp_stmt;

  if (!cp_stmt)
    {
      INIT_STMT (hdbc, cp_stmt,
	  "insert into BLOBS (ROW_NO, B1, B2, B3, B4) "
	  "  select ?, B1, B2, B3, B4 from BLOBS where ROW_NO = ?");
    }
  IBINDL (cp_stmt, 1, to);
  IBINDL (cp_stmt, 2, from);

  rc = SQLExecute (cp_stmt);
  IF_ERR_GO (cp_stmt, err, rc);
  return;

err:;
}

int
check_blob_col (HSTMT stmt, long orig_row_no, const char *col_name, int n_col, int n_col_of_len, long expect_symbols, long expect_bytes, int bytes_per_source_char, int ctype, long new_row_no, const char *timing)
{
  char res[9001];
  char sample[101];
  RETCODE rc;
  long r_start = get_msec_count ();
  long total = 0;
  long col_length_from_server;
  SQLLEN get_batch = 400;
  SQLLEN init_len;
  SQLLEN rec_len;
  unsigned tridgell32 = 0;
  int usable_batch_len;
  char blob_fname[128];
  FILE *blob_f;
  snprintf (blob_fname, sizeof(blob_fname), "blobs_row_%ld_B%d_%ld_in_%ld_%s.bin", orig_row_no, n_col, expect_symbols, new_row_no, timing);
  blob_f = fopen (blob_fname, "wb");
  strcpy (res, "\n*** FAILED: unset res in check_blob_col()!\n");
  strcpy (sample, "\n*** FAILED: unset sample in check_blob_col()!\n");
  if (0 < n_col_of_len)
    {
      SQLLEN res_l_len;
      rc = SQLGetData (stmt, n_col_of_len, SQL_C_LONG, &col_length_from_server, sizeof (col_length_from_server), &res_l_len);
      if (rc == SQL_ERROR)
        {
          IF_ERR_GO (stmt, err_l, rc);
err_l:
          printf ("*** FAILED: ROW_NO %ld, column %s: SQL_ERROR on SQLGetData() for length\n", new_row_no, col_name);
          return 0;
        }
    }
  for (;;)
    {
      int rec_bytes_of_data;
      rc = SQLGetData (stmt, n_col, ctype, res, get_batch, &rec_len);
      /* printf ("SQLGetData() set rec_len=%ld at ccheck_blob_col() with ROW_NO %ld, column %s, expected %ld bytes %ld symbols\n", (long)rec_len, new_row_no, col_name, expect_bytes, expect_symbols); */
      if (rc == SQL_ERROR)
        {
          IF_ERR_GO (stmt, err1, rc);
err1:
          printf ("*** FAILED: ROW_NO %ld, column %s: SQL_ERROR on SQLGetData() for string value\n", new_row_no, col_name);
          return 0;
        }
      if (rc != SQL_SUCCESS && rc != SQL_SUCCESS_WITH_INFO)
        {
          break;
        }
      if (rec_len == SQL_NULL_DATA)
	{
	  total = 0;
	  break;
	}
      if (SQL_C_CHAR == ctype)
        usable_batch_len = (((get_batch-1) / bytes_per_source_char) * bytes_per_source_char);
      else if (SQL_C_WCHAR == ctype)
        usable_batch_len = get_batch - sizeof (wchar_t);
      else
        usable_batch_len = get_batch;
      rec_bytes_of_data = rec_len > usable_batch_len ? usable_batch_len : rec_len;
      fwrite (res, rec_bytes_of_data, 1, blob_f);
      if (0 == total)
        {
          int ctr;
          memcpy (sample, res, sizeof (sample));
          for (ctr = 0; ((ctr < (sizeof(sample)-1)) && (ctr < rec_bytes_of_data)); ctr++)
            if ('\0' == sample[ctr]) sample[ctr] = '_';
          sample[sizeof(sample)-1] = '\0';
        }
      total += rec_bytes_of_data;
      tridgell32 = incremental_tridgell32 ((unsigned char *)res, (unsigned char *)res + rec_bytes_of_data, tridgell32);
      get_batch = (SQL_C_WCHAR == ctype ?
	  ((long)(sizeof (res) / sizeof (wchar_t))) * sizeof (wchar_t) :
	  sizeof (res));
    }
  fclose (blob_f);
  if (ctype == SQL_C_WCHAR)
    {
      if (total % sizeof (wchar_t))
	printf ("*** FAILED: ROW_NO %ld, column %s: %ld received bytes not at wchar_t boundary; length()=%ld, tridgell32=%u, sample=\"%s\".\n", new_row_no, col_name, total, col_length_from_server, tridgell32, sample);
      if (total != expect_bytes)
	printf ("*** FAILED: ");
      printf ("ROW_NO %ld, column %s: Received %ld bytes (%ld wide chars), wanted %ld (%ld wide chars); length()=%ld, tridgell32=%u, sample=\"%s\".\n",
        new_row_no, col_name, 
        total, total / sizeof (wchar_t),
        expect_bytes, expect_bytes / sizeof (wchar_t),
        col_length_from_server, tridgell32, sample );
    }
  else
    {
      if (total != expect_bytes)
        printf ("*** FAILED: ");
      printf ("ROW_NO %ld, column %s: Received %ld bytes, wanted %ld; length()=%ld, tridgell32=%u, sample=\"%s\".\n", new_row_no, col_name, total, expect_bytes, col_length_from_server, tridgell32, sample);
    }
  verify_checksum (orig_row_no, col_name, expect_symbols, tridgell32, new_row_no, timing);
  read_msecs += get_msec_count () - r_start;
  read_bytes += total;
  SQLGetData (stmt, n_col, SQL_C_CHAR, res, 10, &init_len);
  SQLGetData (stmt, n_col, SQL_C_CHAR, res, 10, &init_len);
  return 1;
}


void
read_bound_blobs ()
{
  SQLLEN len1, len2, len3, len4, len_row_no, len_len_b1, len_len_b2, len_len_b3, len_len_b4;
  char temp[100];
  char wtemp[100];
  wchar_t wtemp3[100];
  char wtemp4[100];
  char buf_row_no [sizeof (long)], buf_len_b1 [sizeof (long)], buf_len_b2 [sizeof (long)], buf_len_b3 [sizeof (long)], buf_len_b4 [sizeof (long)];
  HSTMT st;

  SQLAllocStmt (hdbc, &st);
  IF_ERR_GO (st, err,
      SQLExecDirect (st, (UCHAR *) "select B1, B2, B3, B4, ROW_NO, length(B1), length(B2), length(B3), length(B4) from BLOBS", SQL_NTS));
  SQLBindCol (st, 1, SQL_C_CHAR, temp, sizeof (temp), &len1);
  SQLBindCol (st, 2, SQL_C_BINARY, wtemp, sizeof (wtemp), &len2);
  SQLBindCol (st, 3, SQL_C_WCHAR, wtemp3, sizeof (wtemp3), &len3);
  SQLBindCol (st, 4, SQL_C_CHAR, wtemp4, sizeof (wtemp4), &len4);
  SQLBindCol (st, 5, SQL_C_LONG, buf_row_no, sizeof (buf_row_no), &len_row_no);
  SQLBindCol (st, 6, SQL_C_LONG, buf_len_b1, sizeof (buf_len_b1), &len_len_b1);
  SQLBindCol (st, 7, SQL_C_LONG, buf_len_b2, sizeof (buf_len_b2), &len_len_b2);
  SQLBindCol (st, 8, SQL_C_LONG, buf_len_b3, sizeof (buf_len_b3), &len_len_b3);
  SQLBindCol (st, 9, SQL_C_LONG, buf_len_b4, sizeof (buf_len_b4), &len_len_b4);
  for (;;)
    {
      long fetched_row_no, fetched_len_b1, fetched_len_b2, fetched_len_b3, fetched_len_b4;
      RETCODE rc = SQLFetch (st);
      if (rc == SQL_NO_DATA_FOUND)
	break;
      fetched_row_no = ((long *)buf_row_no)[0];
      fetched_len_b1 = ((long *)buf_len_b1)[0];
      fetched_len_b2 = ((long *)buf_len_b2)[0];
      fetched_len_b3 = ((long *)buf_len_b3)[0];
      fetched_len_b4 = ((long *)buf_len_b4)[0];
      if (rc == SQL_ERROR)
	{
	  IF_ERR_GO (st, err, rc);
	}
      temp[99] = 0;
      wtemp[99] = 0;
      wtemp4[99] = 0;
      printf ("ROW_NO %ld Bound clob  server length() %ld client bound len %ld  %s\n"	, fetched_row_no, fetched_len_b1, (long) len1, temp);
      printf ("ROW_NO %ld Bound blob  server length() %ld client bound len %ld  %s\n"	, fetched_row_no, fetched_len_b2, (long) len2, wtemp);
      printf ("ROW_NO %ld Bound nlob  server length() %ld client bound len %ld\n"	, fetched_row_no, fetched_len_b3, (long) len3);
      printf ("ROW_NO %ld Bound cblob server length() %ld client bound len %ld  %s\n"	, fetched_row_no, fetched_len_b4, (long) len4, wtemp4);
    }

err:
  SQLFreeStmt (st, SQL_DROP);
}


void
sel_blob (long orig_row_no, long new_row_no, int expect_n_blocks, const char *timing)
{
  RETCODE rc;
  static HSTMT sel_stmt;
  if (!sel_stmt)
    {
      INIT_STMT (hdbc, sel_stmt,
	  "select B1, B2, B3, B4, length(B1), length(B2), length(B3), length(B4) from BLOBS where ROW_NO = ?");
    }

  IBINDL (sel_stmt, 1, new_row_no);
  IF_ERR_GO (sel_stmt, err, SQLExecute (sel_stmt));
  rc = SQLFetch (sel_stmt);

  if (rc == SQL_SUCCESS || rc == SQL_SUCCESS_WITH_INFO)
    {
      printf ("PASSED: select for ROW_NO %ld\n", new_row_no);
      check_blob_col (sel_stmt, orig_row_no, "B1", 1, 5, expect_n_blocks * 10000, expect_n_blocks * 10000, sizeof (char), SQL_C_CHAR, new_row_no, timing);
      check_blob_col (sel_stmt, orig_row_no, "B2", 2, 6, expect_n_blocks * 10000, expect_n_blocks * 10000,  sizeof (char), SQL_C_BINARY, new_row_no, timing);
      check_blob_col (sel_stmt, orig_row_no, "B3", 3, 7, expect_n_blocks * 10000, expect_n_blocks * 10000 * sizeof (wchar_t), sizeof (wchar_t), SQL_C_WCHAR, new_row_no, timing);
      check_blob_col (sel_stmt, orig_row_no, "B4", 4, 8, expect_n_blocks * 10000, (expect_n_blocks * 10000 * 2), 2*sizeof (char), SQL_C_CHAR, new_row_no, timing);
    }

err:;
  SQLFreeStmt (sel_stmt, SQL_CLOSE);
}


#define MAX_INIT_STATEMENTS 52
char *init_texts[MAX_INIT_STATEMENTS + 2] = { NULL };
int it_index = 0;


char *
is_init_SQL_statement (char **argv, int nth_arg)
{
  if (!strnicmp (argv[nth_arg], "INIT=", 5))
    {
      if (it_index < MAX_INIT_STATEMENTS)
	return (init_texts[it_index++] = (argv[nth_arg] + 5));

      printf ("*** FAILED: %s: More than max. %d allowed initial statements (%s)\n",
	  argv[0], MAX_INIT_STATEMENTS, argv[nth_arg]);
      exit (1);
    }
  else
    {
      return NULL;
    }
}


void
tb_array ()
{
  int rc;
  long nth;
  SQLULEN n_rows = 0;
  SQLLEN dae[2] = {SQL_DATA_AT_EXEC, SQL_DATA_AT_EXEC};
  HSTMT stmt;

  SQLSetConnectOption (hdbc, SQL_AUTOCOMMIT, 1);
  INIT_STMT (hdbc, stmt, "insert into BLOBS (ROW_NO, B1, B2) values (?, ?, ?)");

  SQLParamOptions (stmt, 2, &n_rows);
  SQLSetParam (stmt, 1, SQL_C_CHAR, SQL_INTEGER, 4, 0, NULL, dae);
  SQLSetParam (stmt, 2, SQL_C_CHAR, SQL_LONGVARCHAR, 4, 0, (void*) 100L, dae);
  SQLSetParam (stmt, 3, SQL_C_CHAR, SQL_LONGVARBINARY, 4, 0, (void*) 200L, dae);

  rc = SQLExecute (stmt);
  if (rc == SQL_NEED_DATA)
    {
      rc = SQLParamData (stmt, (void **) &nth);
      while (rc == SQL_NEED_DATA)
	{
	  switch (nth)
	    {
	    case 0:
	      SQLPutData (stmt, (PTR) "4", SQL_NTS);
	      SQLPutData (stmt, (PTR) "0", 1);
	      break;
	    case 4:
	      SQLPutData (stmt, (PTR) "5", SQL_NTS);
	      SQLPutData (stmt, (PTR) "0", 1);
	      break;

	    case 100:
	      SQLPutData (stmt, (PTR) "B1, row 40", SQL_NTS);
	      break;
	    case 104:
	      SQLPutData (stmt, (PTR) "B1, row 50", SQL_NTS);
	      break;

	    case 200:
	      SQLPutData (stmt, (PTR) "B2, row 40", SQL_NTS);
	      break;

	    case 204:
	      SQLPutData (stmt, (PTR) "B2, row 50", SQL_NTS);
	      break;
	    }
	  rc = SQLParamData (stmt, (void **) &nth);
	}
      IF_ERR_GO (stmt, err, rc);
    }
 err: ;
}


int
main (int argc, char **argv)
{
  char *uid = "dba", *pwd = "dba";
  int opt_ind;
  int row_ctr;

  if (argc < 2)
    {
      printf ("Usage. blobs host:port [user [password]] "
	  "[\"INIT=initial SQL statement\"] ...\n");
      exit (1);
    }

  opt_ind = 2;

back2:
  if (argc > opt_ind)
    {
      if (is_init_SQL_statement (argv, opt_ind))
	{
	  opt_ind++;
	  goto back2;
	}
      uid = argv[opt_ind];
      opt_ind++;
    }

back3:
  if (argc > opt_ind)
    {
      if (is_init_SQL_statement (argv, opt_ind))
	{
	  opt_ind++;
	  goto back3;
	}
      pwd = argv[opt_ind];
      opt_ind++;
    }

back_rest:
  if (argc > opt_ind) /* Init statement(s) given after username and password? */
    {
      if (is_init_SQL_statement (argv, opt_ind))
	{
	  opt_ind++;
	  goto back_rest;
	}
    }

  SQLAllocEnv (&henv);
  SQLAllocConnect (henv, &hdbc);

  if (SQL_ERROR == SQLConnect (hdbc, (UCHAR *) argv[1], SQL_NTS,
	  (UCHAR *) uid, SQL_NTS, (UCHAR *) pwd, SQL_NTS))
    {
      print_error (SQL_NULL_HENV, hdbc, SQL_NULL_HSTMT);
      exit (1);
    }

  SQLSetConnectOption (hdbc, SQL_AUTOCOMMIT, 0);

  if (it_index)	/* User gave one or more initialization statements? */
    {		/* e.g. "USE kublbm" with MS SQL server benchmark test */
      HSTMT init_stmt;
      int i = 0;
      SQLAllocStmt (hdbc, &init_stmt);
      while (i < it_index)
	{
	  IF_ERR (init_stmt,
	      SQLExecDirect (init_stmt, (UCHAR *) init_texts[i++], SQL_NTS));
	  SQLFreeStmt (init_stmt, SQL_CLOSE);
	}
      SQLFreeStmt (init_stmt, SQL_DROP);
    }

  check_dd ();


  /* tb_array (); */
  SQLAllocStmt (hdbc, &b_stmt);
/*
  sel_blob (1, 50);
  sel_blob (2, 50);
*/
  del_blobs ();
  ins_blob (1, 2);
  SQLTransact (henv, hdbc, SQL_COMMIT);
  sel_blob (1, 1, 2, "after ins_blob (1,2)");
  upd_blob (1, 14);
  sel_blob (1, 1, 14, "after upd_blob (1, 14)");
  upd_blob (1, 5);
  sel_blob (1, 1, 5, "after upd_blob (1, 5)");
  upd_blob (1, 50);
  sel_blob (1, 1, 50, "after upd_blob (1, 50)");
  copy_blob (1, 2);
  sel_blob (1, 2, 50, "after copy_blob (1, 2)");

  IF_CERR_GO (hdbc, err, SQLTransact (henv, hdbc, SQL_COMMIT));
  sel_blob (1, 1, 50, "after upd_blob (1, 50) and commit");
  sel_blob (1, 2, 50, "after copy_blob (1, 2) and commit");
  upd_blob (1, 12);
  sel_blob (1, 1, 12, "after upd_blob (1, 12)");
  SQLTransact (henv, hdbc, SQL_ROLLBACK);
  sel_blob (1, 1, 50, "after upd_blob (1, 50) and commit, then upd_blob (1, 12) rolled back");
/*
  for (row_ctr = 0; row_ctr < 100; row_ctr++)
    {
      int r_no = 100 + ((row_ctr * 4093) % 100);
      ins_blob (r_no, 1);
    }
  for (row_ctr = 0; row_ctr < 100; row_ctr++)
    {
      int r_no = 100 + ((row_ctr * 4093) % 100);
      sel_blob (r_no, r_no, 1, "after numerous inserts");
    }
  IF_CERR_GO (hdbc, err, SQLTransact (henv, hdbc, SQL_COMMIT));
  for (row_ctr = 0; row_ctr < 100; row_ctr++)
    {
      int r_no = 100 + ((row_ctr * 4093) % 100);
      sel_blob (r_no, r_no, 1, "after numerous inserts, committed");
    }
*/
  read_bound_blobs ();
  SQLSetConnectOption (hdbc, SQL_AUTOCOMMIT, 1);
  read_bound_blobs ();
  sel_blob (1, 1, 50, "after all reads of all blobs");

  printf ("\nRead: %ld KB/s, %ld b,  %ld msec\nWrite %ld KB/s, %ld b, %ld msec\n",
      ((read_bytes / read_msecs) * 1000) / 1024, read_bytes, read_msecs,
      ((write_bytes / write_msecs) * 1000) / 1024, write_bytes, write_msecs);


  exit (0);

err:;
  return 1;
}
