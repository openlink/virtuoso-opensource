/*  virtoledb.h
 *
 *  $Id$
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

#ifndef VIRTOLEDB_H
#define VIRTOLEDB_H

//
// Provider-specific class ids
//

// {754b2f25-3297-44a4-bd04-55eaf8cc5b18}
DEFINE_GUID(CLSID_VIRTOLEDB,
    0x754b2f25, 0x3297, 0x44a4, 0xbd, 0x04, 0x55, 0xea, 0xf8, 0xcc, 0x5b, 0x18);

// {452f0f97-f69f-4cd9-94de-bdf3ff49e3e4}
DEFINE_GUID(CLSID_VIRTOLEDB_ERROR,
    0x452f0f97, 0xf69f, 0x4cd9, 0x94, 0xde, 0xbd, 0xf3, 0xff, 0x49, 0xe3, 0xe4);

// {7bf2f14e-435d-4201-bc4d-09c9db2a93c7}
DEFINE_GUID(CLSID_VIRTOLEDB_CONNECTION_PAGE,
    0x7bf2f14e, 0x435d, 0x4201, 0xbc, 0x4d, 0x09, 0xc9, 0xdb, 0x2a, 0x93, 0xc7);

// {9d701381-30a8-44f6-bcfb-987e8e3fc0f1}
DEFINE_GUID(CLSID_VIRTOLEDB_ADVANCED_PAGE,
    0x9d701381, 0x30a8, 0x44f6, 0xbc, 0xfb, 0x98, 0x7e, 0x8e, 0x3f, 0xc0, 0xf1);

//
// Provider-specific property sets
//

// {8034c07f-b2a3-4139-933b-682f2e3dee1e}
DEFINE_GUID(DBPROPSET_VIRTUOSODBINIT,
    0x8034c07f, 0xb2a3, 0x4139, 0x93, 0x3b, 0x68, 0x2f, 0x2e, 0x3d, 0xee, 0x1e);

// {55b77c23-516c-4e35-9b1f-3a1b20408805}
DEFINE_GUID(DBPROPSET_VIRTUOSOROWSET,
    0x55b77c23, 0x516c, 0x4e35, 0x9b, 0x1f, 0x3a, 0x1b, 0x20, 0x40, 0x88, 0x05);

//
// Property ids for DBPROPSET_VIRTUOSODBINIT
//

#define VIRTPROP_INIT_ENCRYPT 1
#define VIRTPROP_AUTH_PKCS12FILE 2
#define VIRTPROP_INIT_CHARSET 3
#define VIRTPROP_INIT_DAYLIGHT 4
#define VIRTPROP_INIT_SHOWSYSTABLES 5

//
// Property ids for DBPROPSET_VIRTUOSOROWSET
//

#define VIRTPROP_PREFETCHSIZE 1
#define VIRTPROP_TXNTIMEOUT 2

#endif
