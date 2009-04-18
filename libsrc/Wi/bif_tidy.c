/*
 *  bif_tidy.c
 *
 *  $Id$
 *
 *  Build in Functions for tidying HTML pages
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2006 OpenLink Software
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

#define OLD_TIDY

#include "libutil.h"
#include "sqlnode.h"
#include "sqlbif.h"
#include "wi.h"
#include "Dk.h"
#ifndef WIN32
#define __USE_MISC 1 /* hack for platform.h defining ulong & uint */
#endif
#ifdef OLD_TIDY
#include "html.h"
#else
#include "tidy.h"
#endif
#ifndef WIN32
#undef __USE_MISC
#endif

static dk_mutex_t *tidy_mtx;

caddr_t
bif_tidy_html (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t html_input = bif_string_arg (qst, args, 0, "tidy_html");
  caddr_t config_input = bif_string_arg (qst, args, 1, "tidy_html");
  caddr_t html_output = NULL;
  int res;
#ifdef OLD_TIDY
  tidy_io_t tidy_errout;
  tidy_errout.tio_data.lm_memblock = NULL;
  tidy_errout.tio_data.lm_length = 0;
  tidy_errout.tio_pos = 0;
  mutex_enter (tidy_mtx);
  errout = &tidy_errout;
  res = do_tidy (html_input, config_input, &html_output);
  errout = NULL;
  mutex_leave (tidy_mtx);
  if (NULL != tidy_errout.tio_data.lm_memblock)
    dk_free (tidy_errout.tio_data.lm_memblock, -1);
  if ((NULL == html_output) || (2 == res)) /* errors */
    {
      dk_free_box (html_output);
      sqlr_new_error ("42000", "HT076", "HTML Tidy failed, try tidy_list_errors(...) to get more information");
    }
#else
  TidyBuffer output = {0};
  TidyBuffer errbuf = {0};
  tidyDoc doc = tidyCreate();
  tidySetErrorBuffer (doc, &errbuf);
  res = tidyLoadConfig (doc, config_input);
  if (res >= 0)
    res = tidyParseString (doc, input);
  if (res >= 0)
    res = tidyCleanAndRepair (doc);
  if (res >= 0)
    res = tidyRunDiagnostics (doc);
  if (res > 1)
    res = ( tidyOptSetBool(tdoc, TidyForceOutput, yes) ? res : -1 );
  if (res >= 0)
    res = tidySaveBuffer(doc, &output);
  if (res >= 0)
  html_output = box_dv_short_string (output.bp);
  tidyBufFree( &output );
  tidyBufFree( &errbuf );
  tidyRelease( tdoc );
  if (res < 0)
    {
      dk_free_box (html_output);
      sqlr_error ("XTID2", "HTML Tidy failed with a severe error (%d), try tidy_list_errors(...) to get more information", res);
    }
#endif
  return html_output;
}

caddr_t
bif_tidy_list_errors (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t html_input = bif_string_arg (qst, args, 0, "tidy_list_errors");
  caddr_t config_input = bif_string_arg (qst, args, 1, "tidy_list_errors");
  caddr_t errlist;
#ifdef OLD_TIDY
  tidy_io_t tidy_errout;
  tidy_errout.tio_data.lm_memblock = NULL;
  tidy_errout.tio_data.lm_length = 0;
  tidy_errout.tio_pos = 0;
  mutex_enter (tidy_mtx);
  errout = &tidy_errout;
  do_tidy (html_input, config_input, null);
  errout = NULL;
  mutex_leave (tidy_mtx);
  if (NULL == tidy_errout.tio_data.lm_memblock)
    errlist = box_dv_short_string("");
  else
    {
      errlist = box_dv_short_nchars (tidy_errout.tio_data.lm_memblock, tidy_errout.tio_pos);
      dk_free (tidy_errout.tio_data.lm_memblock, -1);
    }
#else
  TidyBuffer errbuf = {0};
  tidyDoc doc = tidyCreate();
  tidySetErrorBuffer (doc, &errbuf);
  res = tidyLoadConfig (doc, config_input);
  if (res >= 0)
    res = tidyParseString (doc, input);
  if (res >= 0)
    res = tidyCleanAndRepair (doc);
  if (res >= 0)
    res = tidyRunDiagnostics (doc);
  if (res > 1)
    res = ( tidyOptSetBool(tdoc, TidyForceOutput, yes) ? res : -1 );
  if (res >= 0)
  errlist = box_dv_short_string (errbuf.bp);
  tidyBufFree( &errbuf );
  tidyRelease( tdoc );
  if (res < 0)
    {
      dk_free_box (html_output);
      sqlr_error ("XTID2", "HTML Tidy failed with a severe error (%d), try tidy_list_errors(...) to get more information", res);
    }
#endif
  return errlist;
}

int bif_tidy_init(void)
{
  tidy_mtx = mutex_allocate ();
  bif_define ("tidy_html", bif_tidy_html);
  bif_define ("tidy_list_errors", bif_tidy_list_errors);
  return 0;
}
