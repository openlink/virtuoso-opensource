/*
 *  
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *  
 *  Copyright (C) 1998-2016 OpenLink Software
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
#include "plugin.h"
#include "langfunc.h"
#ifdef _MSC_VER
#include "import_plugin_lang25.h"
#endif

extern void connect__enUK(void *appdata);

static
void lang25_connect(void *appdata)
{
  connect__enUK(appdata);
}

unit_version_t lang25_version = {
  "Extended language support",		/*!< Title of unit, filled by unit */
  "2.5",				/*!< Version number, filled by unit */
  "OpenLink Software",			/*!< Plugin's developer, filled by unit */
  "",					/*!< Any additional info, filled by unit */
  NULL,					/*!< Error message, filled by unit loader */
  NULL,					/*!< Name of file with unit's code, filled by unit loader */
  lang25_connect,			/*!< Pointer to connection function, cannot be NULL */
  NULL,					/*!< Pointer to disconnection function, or NULL */
  NULL,					/*!< Pointer to activation function, or NULL */
  NULL,					/*!< Pointer to deactivation function, or NULL */
#ifdef _MSC_VER
  &_gate
#else
  NULL
#endif
};

#ifdef WIN32
__declspec(dllexport)
#endif
unit_version_t * CALLBACK lang25_check (unit_version_t *dock_info, void *appdata)
{
  return &lang25_version;
}

#ifdef WIN32
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
#endif

