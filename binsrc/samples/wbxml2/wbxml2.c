/*
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
 *
*/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#include "wbxml.h"

#ifdef _USRDLL
#include "plugin.h"
#ifdef CALLBACK
#undef CALLBACK
#endif
#include "import_gate_virtuoso.h"
#define wi_inst (wi_instance_get()[0])
#else
#include <libutil.h>
#include "sqlnode.h"
#include "sqlbif.h"
#include "wi.h"
#include "Dk.h"
#endif

#define WBMXL2_VERSION "0.9"

caddr_t
bif_wbxml2xml (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t in = bif_arg (qst, args, 0, "wbxml2xml");
  caddr_t ret_xml = NULL;
  WBXMLError ret = WBXML_OK;
  WB_UTINY *wbxml = NULL, *xml = NULL;
  WB_LONG wbxml_len = 0;
  WB_ULONG  xml_len;
  WBXMLGenXMLParams params;
  long box_in_len = box_length (in);

  /* Init Default Parameters */
  params.lang = WBXML_LANG_UNKNOWN;
  params.gen_type = WBXML_GEN_XML_INDENT;
  params.indent = 1;
  params.keep_ignorable_ws = FALSE;

  wbxml_len =  box_in_len - 1;
  wbxml = wbxml_realloc(wbxml, wbxml_len);
  memcpy(wbxml, in, wbxml_len);

  ret = wbxml_conv_wbxml2xml_withlen (wbxml, wbxml_len, &xml, &xml_len, &params);

  if (ret != WBXML_OK)
    {
      sqlr_new_error ("23000", "WBXML", "%.150s", wbxml_errors_string(ret));
      goto end;
    }

  ret_xml = box_dv_short_string ((const char *)xml);

end:
  wbxml_free(wbxml);
  wbxml_free(xml);
  return ret_xml ? ret_xml : dk_alloc_box (0, DV_DB_NULL);
}
;


caddr_t
bif_xml2wbxml (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t in = bif_arg (qst, args, 0, "xml2wbxml");
  caddr_t ret_wbxml = NULL;
  WBXMLError ret = WBXML_OK;
  WB_UTINY *wbxml = NULL, *xml = NULL;
  WB_ULONG wbxml_len = 0;
  WBXMLGenWBXMLParams params;
  long box_in_len = box_length (in) - 1;

  xml = wbxml_realloc(xml, box_in_len);
  memcpy(xml, in, box_in_len);

  /* Init Default Parameters */
  params.wbxml_version = WBXML_VERSION_12;
  params.use_strtbl = FALSE;
  params.keep_ignorable_ws = FALSE;

  ret = wbxml_conv_xml2wbxml_withlen(xml, box_in_len, &wbxml, &wbxml_len, &params);

  if (ret != WBXML_OK)
    {
      sqlr_new_error ("23000", "WBXML", "%.150s", wbxml_errors_string(ret));
      goto end;
    }

  ret_wbxml = dk_alloc_box (wbxml_len + 1, DV_SHORT_STRING);
  memcpy (ret_wbxml, wbxml, wbxml_len + 1);

end:
  wbxml_free(wbxml);
  wbxml_free(xml);
  return ret_wbxml ? ret_wbxml : dk_alloc_box (0, DV_DB_NULL);
}
;


void wbmxl2_connect (void *appdata)
{
  bif_define ("WBXML2XML", bif_wbxml2xml);
  bif_define ("XML2WBXML", bif_xml2wbxml);
}

#ifdef _USRDLL
static unit_version_t
wbxml2_version = {
  "WBXML2",        /*!< Title of unit, filled by unit */
  WBMXL2_VERSION,      /*!< Version number, filled by unit */
  "OpenLink Software",      /*!< Plugin's developer, filled by unit */
  "Support functions for WBXML2 " WBXML_LIB_VERSION " Library", /*!< Any additional info, filled by unit */
  0,          /*!< Error message, filled by unit loader */
  0,          /*!< Name of file with unit's code, filled by unit loader */
  wbmxl2_connect,      /*!< Pointer to connection function, cannot be 0 */
  0,          /*!< Pointer to disconnection function, or 0 */
  0,          /*!< Pointer to activation function, or 0 */
  0,          /*!< Pointer to deactivation function, or 0 */
  &_gate
}
;

unit_version_t *
CALLBACK wbxml2_check (unit_version_t *in, void *appdata)
{
  return &wbxml2_version;
}
#endif
