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

#pragma warning( disable: 4049 )  /* more than 64k source lines */

/* this ALWAYS GENERATED file contains the IIDs and CLSIDs */

/* link this file in with the server and any clients */


 /* File created by MIDL compiler version 5.03.0280 */
/* at Wed Nov 01 16:03:54 2000
 */
/* Compiler settings for D:\Program Files\Microsoft Platform SDK\Include\MailMsg.Idl:
    Os (OptLev=s), W1, Zp8, env=Win32 (32b run), ms_ext, c_ext
    error checks: allocation ref bounds_check enum stub_data 
    VC __declspec() decoration level: 
         __declspec(uuid()), __declspec(selectany), __declspec(novtable)
         DECLSPEC_UUID(), MIDL_INTERFACE()
*/
//@@MIDL_FILE_HEADING(  )

#if !defined(_M_IA64) && !defined(_M_AXP64)

#ifdef __cplusplus
extern "C"{
#endif 


#include <rpc.h>
#include <rpcndr.h>

#ifdef _MIDL_USE_GUIDDEF_

#ifndef INITGUID
#define INITGUID
#include <guiddef.h>
#undef INITGUID
#else
#include <guiddef.h>
#endif

#define MIDL_DEFINE_GUID(type,name,l,w1,w2,b1,b2,b3,b4,b5,b6,b7,b8) \
        DEFINE_GUID(name,l,w1,w2,b1,b2,b3,b4,b5,b6,b7,b8)

#else // !_MIDL_USE_GUIDDEF_

#ifndef __IID_DEFINED__
#define __IID_DEFINED__

typedef struct _IID
{
    unsigned long x;
    unsigned short s1;
    unsigned short s2;
    unsigned char  c[8];
} IID;

#endif // __IID_DEFINED__

#ifndef CLSID_DEFINED
#define CLSID_DEFINED
typedef IID CLSID;
#endif // CLSID_DEFINED

#define MIDL_DEFINE_GUID(type,name,l,w1,w2,b1,b2,b3,b4,b5,b6,b7,b8) \
        const type name = {l,w1,w2,{b1,b2,b3,b4,b5,b6,b7,b8}}

#endif !_MIDL_USE_GUIDDEF_

MIDL_DEFINE_GUID(IID, IID_IMailMsgNotify,0x0f7c3c30,0xa8ad,0x11d1,0xaa,0x91,0x00,0xaa,0x00,0x6b,0xc8,0x0b);


MIDL_DEFINE_GUID(IID, IID_IMailMsgPropertyStream,0xa44819c0,0xa7cf,0x11d1,0xaa,0x91,0x00,0xaa,0x00,0x6b,0xc8,0x0b);


MIDL_DEFINE_GUID(IID, IID_IMailMsgRecipientsBase,0xd1a97920,0xa891,0x11d1,0xaa,0x91,0x00,0xaa,0x00,0x6b,0xc8,0x0b);


MIDL_DEFINE_GUID(IID, IID_IMailMsgRecipientsAdd,0x4c28a700,0xa892,0x11d1,0xaa,0x91,0x00,0xaa,0x00,0x6b,0xc8,0x0b);


MIDL_DEFINE_GUID(IID, IID_IMailMsgRecipients,0x19507fe0,0xa892,0x11d1,0xaa,0x91,0x00,0xaa,0x00,0x6b,0xc8,0x0b);


MIDL_DEFINE_GUID(IID, IID_IMailMsgProperties,0xab95fb40,0xa34f,0x11d1,0xaa,0x8a,0x00,0xaa,0x00,0x6b,0xc8,0x0b);


MIDL_DEFINE_GUID(IID, IID_IMailMsgValidate,0x6717b03c,0x072c,0x11d3,0x94,0xff,0x00,0xc0,0x4f,0xa3,0x79,0xf1);


MIDL_DEFINE_GUID(IID, IID_IMailMsgPropertyManagement,0xa2f196c0,0xa351,0x11d1,0xaa,0x8a,0x00,0xaa,0x00,0x6b,0xc8,0x0b);


MIDL_DEFINE_GUID(IID, IID_IMailMsgEnumMessages,0xe760a840,0xc8f1,0x11d1,0x9f,0xf2,0x00,0xc0,0x4f,0xa3,0x73,0x48);


MIDL_DEFINE_GUID(IID, IID_IMailMsgStoreDriver,0x246aae60,0xacc4,0x11d1,0xaa,0x91,0x00,0xaa,0x00,0x6b,0xc8,0x0b);


MIDL_DEFINE_GUID(IID, IID_IMailMsgQueueMgmt,0xb2564d0a,0xd5a1,0x11d1,0x9f,0xf7,0x00,0xc0,0x4f,0xa3,0x73,0x48);


MIDL_DEFINE_GUID(IID, IID_ISMTPStoreDriver,0xee51588c,0xd64a,0x11d1,0x9f,0xf7,0x00,0xc0,0x4f,0xa3,0x73,0x48);


MIDL_DEFINE_GUID(IID, IID_IMailMsgBind,0x38cb448a,0xca62,0x11d1,0x9f,0xf3,0x00,0xc0,0x4f,0xa3,0x73,0x48);


MIDL_DEFINE_GUID(IID, IID_IMailMsgPropertyBag,0xd6d0509c,0xec51,0x11d1,0xaa,0x65,0x00,0xc0,0x4f,0xa3,0x5b,0x82);


MIDL_DEFINE_GUID(IID, IID_IMailMsgLoggingPropertyBag,0x4cb17416,0xec53,0x11d1,0xaa,0x65,0x00,0xc0,0x4f,0xa3,0x5b,0x82);


MIDL_DEFINE_GUID(IID, IID_IMailMsgCleanupCallback,0x951C04A1,0x29F0,0x4b8e,0x9E,0xD5,0x83,0x6C,0x73,0x76,0x60,0x51);


MIDL_DEFINE_GUID(IID, IID_IMailMsgRegisterCleanupCallback,0x00561C2F,0x5E90,0x49e5,0x9E,0x73,0x7B,0xF9,0x12,0x92,0x98,0xA0);


MIDL_DEFINE_GUID(IID, IID_ISMTPServer,0x22625594,0xd822,0x11d1,0x9f,0xf7,0x00,0xc0,0x4f,0xa3,0x73,0x48);


MIDL_DEFINE_GUID(IID, IID_ISMTPServerInternal,0x57EE6C15,0x1870,0x11d2,0xA6,0x89,0x00,0xC0,0x4F,0xA3,0x49,0x0A);


MIDL_DEFINE_GUID(IID, LIBID_MailMsgLib,0xdaf24820,0xa8b9,0x11d1,0xaa,0x91,0x00,0xaa,0x00,0x6b,0xc8,0x0b);

#undef MIDL_DEFINE_GUID

#ifdef __cplusplus
}
#endif



#endif /* !defined(_M_IA64) && !defined(_M_AXP64)*/


#pragma warning( disable: 4049 )  /* more than 64k source lines */

/* this ALWAYS GENERATED file contains the IIDs and CLSIDs */

/* link this file in with the server and any clients */


 /* File created by MIDL compiler version 5.03.0280 */
/* at Wed Nov 01 16:03:54 2000
 */
/* Compiler settings for D:\Program Files\Microsoft Platform SDK\Include\MailMsg.Idl:
    Oicf (OptLev=i2), W1, Zp8, env=Win64 (32b run,appending), ms_ext, c_ext, robust
    error checks: allocation ref bounds_check enum stub_data 
    VC __declspec() decoration level: 
         __declspec(uuid()), __declspec(selectany), __declspec(novtable)
         DECLSPEC_UUID(), MIDL_INTERFACE()
*/
//@@MIDL_FILE_HEADING(  )

#if defined(_M_IA64) || defined(_M_AXP64)

#ifdef __cplusplus
extern "C"{
#endif 


#include <rpc.h>
#include <rpcndr.h>

#ifdef _MIDL_USE_GUIDDEF_

#ifndef INITGUID
#define INITGUID
#include <guiddef.h>
#undef INITGUID
#else
#include <guiddef.h>
#endif

#define MIDL_DEFINE_GUID(type,name,l,w1,w2,b1,b2,b3,b4,b5,b6,b7,b8) \
        DEFINE_GUID(name,l,w1,w2,b1,b2,b3,b4,b5,b6,b7,b8)

#else // !_MIDL_USE_GUIDDEF_

#ifndef __IID_DEFINED__
#define __IID_DEFINED__

typedef struct _IID
{
    unsigned long x;
    unsigned short s1;
    unsigned short s2;
    unsigned char  c[8];
} IID;

#endif // __IID_DEFINED__

#ifndef CLSID_DEFINED
#define CLSID_DEFINED
typedef IID CLSID;
#endif // CLSID_DEFINED

#define MIDL_DEFINE_GUID(type,name,l,w1,w2,b1,b2,b3,b4,b5,b6,b7,b8) \
        const type name = {l,w1,w2,{b1,b2,b3,b4,b5,b6,b7,b8}}

#endif !_MIDL_USE_GUIDDEF_

MIDL_DEFINE_GUID(IID, IID_IMailMsgNotify,0x0f7c3c30,0xa8ad,0x11d1,0xaa,0x91,0x00,0xaa,0x00,0x6b,0xc8,0x0b);


MIDL_DEFINE_GUID(IID, IID_IMailMsgPropertyStream,0xa44819c0,0xa7cf,0x11d1,0xaa,0x91,0x00,0xaa,0x00,0x6b,0xc8,0x0b);


MIDL_DEFINE_GUID(IID, IID_IMailMsgRecipientsBase,0xd1a97920,0xa891,0x11d1,0xaa,0x91,0x00,0xaa,0x00,0x6b,0xc8,0x0b);


MIDL_DEFINE_GUID(IID, IID_IMailMsgRecipientsAdd,0x4c28a700,0xa892,0x11d1,0xaa,0x91,0x00,0xaa,0x00,0x6b,0xc8,0x0b);


MIDL_DEFINE_GUID(IID, IID_IMailMsgRecipients,0x19507fe0,0xa892,0x11d1,0xaa,0x91,0x00,0xaa,0x00,0x6b,0xc8,0x0b);


MIDL_DEFINE_GUID(IID, IID_IMailMsgProperties,0xab95fb40,0xa34f,0x11d1,0xaa,0x8a,0x00,0xaa,0x00,0x6b,0xc8,0x0b);


MIDL_DEFINE_GUID(IID, IID_IMailMsgValidate,0x6717b03c,0x072c,0x11d3,0x94,0xff,0x00,0xc0,0x4f,0xa3,0x79,0xf1);


MIDL_DEFINE_GUID(IID, IID_IMailMsgPropertyManagement,0xa2f196c0,0xa351,0x11d1,0xaa,0x8a,0x00,0xaa,0x00,0x6b,0xc8,0x0b);


MIDL_DEFINE_GUID(IID, IID_IMailMsgEnumMessages,0xe760a840,0xc8f1,0x11d1,0x9f,0xf2,0x00,0xc0,0x4f,0xa3,0x73,0x48);


MIDL_DEFINE_GUID(IID, IID_IMailMsgStoreDriver,0x246aae60,0xacc4,0x11d1,0xaa,0x91,0x00,0xaa,0x00,0x6b,0xc8,0x0b);


MIDL_DEFINE_GUID(IID, IID_IMailMsgQueueMgmt,0xb2564d0a,0xd5a1,0x11d1,0x9f,0xf7,0x00,0xc0,0x4f,0xa3,0x73,0x48);


MIDL_DEFINE_GUID(IID, IID_ISMTPStoreDriver,0xee51588c,0xd64a,0x11d1,0x9f,0xf7,0x00,0xc0,0x4f,0xa3,0x73,0x48);


MIDL_DEFINE_GUID(IID, IID_IMailMsgBind,0x38cb448a,0xca62,0x11d1,0x9f,0xf3,0x00,0xc0,0x4f,0xa3,0x73,0x48);


MIDL_DEFINE_GUID(IID, IID_IMailMsgPropertyBag,0xd6d0509c,0xec51,0x11d1,0xaa,0x65,0x00,0xc0,0x4f,0xa3,0x5b,0x82);


MIDL_DEFINE_GUID(IID, IID_IMailMsgLoggingPropertyBag,0x4cb17416,0xec53,0x11d1,0xaa,0x65,0x00,0xc0,0x4f,0xa3,0x5b,0x82);


MIDL_DEFINE_GUID(IID, IID_IMailMsgCleanupCallback,0x951C04A1,0x29F0,0x4b8e,0x9E,0xD5,0x83,0x6C,0x73,0x76,0x60,0x51);


MIDL_DEFINE_GUID(IID, IID_IMailMsgRegisterCleanupCallback,0x00561C2F,0x5E90,0x49e5,0x9E,0x73,0x7B,0xF9,0x12,0x92,0x98,0xA0);


MIDL_DEFINE_GUID(IID, IID_ISMTPServer,0x22625594,0xd822,0x11d1,0x9f,0xf7,0x00,0xc0,0x4f,0xa3,0x73,0x48);


MIDL_DEFINE_GUID(IID, IID_ISMTPServerInternal,0x57EE6C15,0x1870,0x11d2,0xA6,0x89,0x00,0xC0,0x4F,0xA3,0x49,0x0A);


MIDL_DEFINE_GUID(IID, LIBID_MailMsgLib,0xdaf24820,0xa8b9,0x11d1,0xaa,0x91,0x00,0xaa,0x00,0x6b,0xc8,0x0b);

#undef MIDL_DEFINE_GUID

#ifdef __cplusplus
}
#endif



#endif /* defined(_M_IA64) || defined(_M_AXP64)*/

