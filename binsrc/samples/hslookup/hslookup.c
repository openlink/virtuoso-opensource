/*
 *  
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *  
 *  Copyright (C) 1998-2013 OpenLink Software
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
#ifdef _USRDLL
#include "plugin.h"
#include "import_gate_virtuoso.h"
#define wi_inst (wi_instance_get()[0])
#else
#include <libutil.h>
#include "sqlnode.h"
#include "sqlbif.h"
#include "wi.h"
#include "Dk.h"
#endif

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#ifdef WIN32  
#include <handle.h>
#else
#include <hdl/hdl.h>
#endif

#define HDL_HS_VERSION "0.1"

caddr_t 
bif_hs_Resolve (caddr_t * qst, caddr_t * err, state_slot_t ** args)
{
  char * szMe = "HS_Resolve";
  caddr_t res = NULL;
  caddr_t handle = bif_string_arg (qst, args, 0, szMe);
#ifndef WIN32  
  HDLContext* ctx;
  HDLValue **vals;
  int ret, numVals, i, traceMessages = 0;

  ctx = HDLInitResolver();

  if (ctx == NULL) 
    sqlr_new_error ("22023", "HS001", "unable to create resolver.");

  ctx->msgFlags |= 0;
  ctx->traceMessages = traceMessages;
  ret = HDLResolve(ctx, handle, strlen(handle), NULL, 0, NULL, 0, &vals, &numVals);

  if( ret != HDL_RC_SUCCESS) 
    {
      HDLDestroyResolver(ctx);
      sqlr_new_error ("22023", "HS003", "%i: %s.", ret, HDLGetErrorString(ret));
    }
  if (vals == NULL)
    {
      HDLDestroyResolver(ctx);
      sqlr_new_error ("22023", "HS004",  "No values found.");
    }

  for (i = 0; i < numVals; i++)
    {
      HDLValue* val =  vals[i];
      if (!res && val->typeLen == 3)
	{
	  char* tmpStr = (char*) MALLOC (val->typeLen + 1);
	  unsigned int j;
	  memcpy (tmpStr, val->type, val->typeLen);
	  for (j = 0; j < val->typeLen; j++)
	    tmpStr[j] = tolower(tmpStr[j]);
	  if (!strcmp (tmpStr, "url"))
	    res = box_dv_short_nchars (val->data, val->dataLen);
	  FREE(tmpStr);
	}
    }
  HDLDestroyValueList (vals, numVals);
  HDLDestroyResolver(ctx);
#else  
  void* ctx;
  HdlValue **vals;
  int ret, numVals, i, traceMessages = 0;

  ret = HdlInitFromFile(&ctx, "root_list");

  if (ctx == NULL) 
    sqlr_new_error ("22023", "HS001", "unable to create resolver.");

  vals = HdlResolve(ctx, handle, 0, NULL, 0, NULL, &numVals, &ret);

  if (ret != HDL_RC_SUCCESS) 
    {
      HdlRelease(ctx);
      sqlr_new_error ("22023", "HS003", "%i: %s.", ret, HdlGetErrorString(ret));
    }
  if (vals == NULL)
    {
      HdlRelease(ctx);
      sqlr_new_error ("22023", "HS004",  "No values found.");
    }

  for (i = 0; i < numVals; i++)
    {
      HdlValue* val =  vals[i];
      if (!res && !strcmp (val->type, "URL"))
	{
	  res = box_dv_short_nchars (val->data, val->iDataLen);
	}
    }
  HdlFreeValueList (&vals);
  HdlRelease(ctx);
#endif  
  if (NULL == res)
    res = NEW_DB_NULL;
  return res;
}


void hs_connect (void *appdata)
{
  bif_define ("HS_Resolve", bif_hs_Resolve);
}

#ifdef _USRDLL
static unit_version_t
hs_version = {
  "HSLOOKUP",        /*!< Title of unit, filled by unit */
  HDL_HS_VERSION,      /*!< Version number, filled by unit */
  "OpenLink Software",      /*!< Plugin's developer, filled by unit */
  "Support functions for Handle System " HS_VERSION, /*!< Any additional info, filled by unit */
  0,          /*!< Error message, filled by unit loader */
  0,          /*!< Name of file with unit's code, filled by unit loader */
  hs_connect,      /*!< Pointer to connection function, cannot be 0 */
  0,          /*!< Pointer to disconnection function, or 0 */
  0,          /*!< Pointer to activation function, or 0 */
  0,          /*!< Pointer to deactivation function, or 0 */
  &_gate
};

unit_version_t *
CALLBACK hslookup_check (unit_version_t *in, void *appdata)
{
  return &hs_version;
}
#endif
