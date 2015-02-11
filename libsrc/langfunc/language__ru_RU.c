/*
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
 *  
*/
#include "langfunc.h"
#include "plugin.h"


lang_handler_t lh__ru__RU = {
  "ru",			/* ISO 639 */
  "ru-RU",		/* RFC 1766 */
  &lh__xany,		/* more generic handler */
  NULL /*&lh__xftqxany*/,	/* query language handler */
  1, WORD_MAX_CHARS,	/* minimal and maximal lengths of one indexable word */
  NULL,			/* application-specific data */
  NULL,			/* lh_is_vtb_word */
  NULL,			/* lh_tocapital_word */
  NULL,			/* lh_toupper_word */
  NULL,			/* lh_tolower_word */
  NULL /*lh_normalize_word__ru__RU*/ ,
  NULL,			/* lh_count_words */
  NULL,			/* lh_iterate_words */
  NULL,			/* lh_iterate_patched_words */
#ifdef HYPHENATION_OK
  NULL			/* lh_iterate_hyppoints */
#endif
};


static
void connect__ru__RU(void *appdata)
{
  lh_load_handler(&lh__ru__RU);
}


unit_version_t plugin_version_lang__ru__RU = {
  "Russian language support",		/*!< Title of unit, filled by unit */
  "0.9",				/*!< Version number, filled by unit */
  "OpenLink Software",			/*!< Plugin's developer, filled by unit */
  "",					/*!< Any additional info, filled by unit */
  NULL,					/*!< Error message, filled by unit loader */
  NULL,					/*!< Name of file with unit's code, filled by unit loader */
  connect__ru__RU,			/*!< Pointer to connection function, cannot be NULL */
  NULL,					/*!< Pointer to disconnection function, or NULL */
  NULL,					/*!< Pointer to activation function, or NULL */
  NULL					/*!< Pointer to deactivation function, or NULL */
};

