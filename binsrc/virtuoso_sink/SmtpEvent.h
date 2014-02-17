/*
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
 *  
*/

#pragma warning( disable: 4049 )  /* more than 64k source lines */

/* this ALWAYS GENERATED file contains the definitions for the interfaces */


 /* File created by MIDL compiler version 5.03.0280 */
/* at Mon Nov 06 14:26:24 2000
 */
/* Compiler settings for D:\Program Files\Microsoft Platform SDK\Include\SmtpEvent.Idl:
    Os (OptLev=s), W1, Zp8, env=Win32 (32b run), ms_ext, c_ext
    error checks: allocation ref bounds_check enum stub_data 
    VC __declspec() decoration level: 
         __declspec(uuid()), __declspec(selectany), __declspec(novtable)
         DECLSPEC_UUID(), MIDL_INTERFACE()
*/
//@@MIDL_FILE_HEADING(  )


/* verify that the <rpcndr.h> version is high enough to compile this file*/
#ifndef __REQUIRED_RPCNDR_H_VERSION__
#define __REQUIRED_RPCNDR_H_VERSION__ 440
#endif

#include "rpc.h"
#include "rpcndr.h"

#ifndef __RPCNDR_H_VERSION__
#error this stub requires an updated version of <rpcndr.h>
#endif // __RPCNDR_H_VERSION__

#ifndef COM_NO_WINDOWS_H
#include "windows.h"
#include "ole2.h"
#endif /*COM_NO_WINDOWS_H*/

#ifndef __SmtpEvent_h__
#define __SmtpEvent_h__

/* Forward Declarations */ 

#ifndef __ISmtpInCommandContext_FWD_DEFINED__
#define __ISmtpInCommandContext_FWD_DEFINED__
typedef interface ISmtpInCommandContext ISmtpInCommandContext;
#endif 	/* __ISmtpInCommandContext_FWD_DEFINED__ */


#ifndef __ISmtpInCallbackContext_FWD_DEFINED__
#define __ISmtpInCallbackContext_FWD_DEFINED__
typedef interface ISmtpInCallbackContext ISmtpInCallbackContext;
#endif 	/* __ISmtpInCallbackContext_FWD_DEFINED__ */


#ifndef __ISmtpOutCommandContext_FWD_DEFINED__
#define __ISmtpOutCommandContext_FWD_DEFINED__
typedef interface ISmtpOutCommandContext ISmtpOutCommandContext;
#endif 	/* __ISmtpOutCommandContext_FWD_DEFINED__ */


#ifndef __ISmtpServerResponseContext_FWD_DEFINED__
#define __ISmtpServerResponseContext_FWD_DEFINED__
typedef interface ISmtpServerResponseContext ISmtpServerResponseContext;
#endif 	/* __ISmtpServerResponseContext_FWD_DEFINED__ */


#ifndef __ISmtpInCommandSink_FWD_DEFINED__
#define __ISmtpInCommandSink_FWD_DEFINED__
typedef interface ISmtpInCommandSink ISmtpInCommandSink;
#endif 	/* __ISmtpInCommandSink_FWD_DEFINED__ */


#ifndef __ISmtpOutCommandSink_FWD_DEFINED__
#define __ISmtpOutCommandSink_FWD_DEFINED__
typedef interface ISmtpOutCommandSink ISmtpOutCommandSink;
#endif 	/* __ISmtpOutCommandSink_FWD_DEFINED__ */


#ifndef __ISmtpServerResponseSink_FWD_DEFINED__
#define __ISmtpServerResponseSink_FWD_DEFINED__
typedef interface ISmtpServerResponseSink ISmtpServerResponseSink;
#endif 	/* __ISmtpServerResponseSink_FWD_DEFINED__ */


#ifndef __ISmtpInCallbackSink_FWD_DEFINED__
#define __ISmtpInCallbackSink_FWD_DEFINED__
typedef interface ISmtpInCallbackSink ISmtpInCallbackSink;
#endif 	/* __ISmtpInCallbackSink_FWD_DEFINED__ */


#ifndef __IMailTransportNotify_FWD_DEFINED__
#define __IMailTransportNotify_FWD_DEFINED__
typedef interface IMailTransportNotify IMailTransportNotify;
#endif 	/* __IMailTransportNotify_FWD_DEFINED__ */


#ifndef __IMailTransportSubmission_FWD_DEFINED__
#define __IMailTransportSubmission_FWD_DEFINED__
typedef interface IMailTransportSubmission IMailTransportSubmission;
#endif 	/* __IMailTransportSubmission_FWD_DEFINED__ */


#ifndef __IMailTransportOnPreCategorize_FWD_DEFINED__
#define __IMailTransportOnPreCategorize_FWD_DEFINED__
typedef interface IMailTransportOnPreCategorize IMailTransportOnPreCategorize;
#endif 	/* __IMailTransportOnPreCategorize_FWD_DEFINED__ */


#ifndef __IMailTransportOnPostCategorize_FWD_DEFINED__
#define __IMailTransportOnPostCategorize_FWD_DEFINED__
typedef interface IMailTransportOnPostCategorize IMailTransportOnPostCategorize;
#endif 	/* __IMailTransportOnPostCategorize_FWD_DEFINED__ */


#ifndef __IMailTransportRouterReset_FWD_DEFINED__
#define __IMailTransportRouterReset_FWD_DEFINED__
typedef interface IMailTransportRouterReset IMailTransportRouterReset;
#endif 	/* __IMailTransportRouterReset_FWD_DEFINED__ */


#ifndef __IMailTransportSetRouterReset_FWD_DEFINED__
#define __IMailTransportSetRouterReset_FWD_DEFINED__
typedef interface IMailTransportSetRouterReset IMailTransportSetRouterReset;
#endif 	/* __IMailTransportSetRouterReset_FWD_DEFINED__ */


#ifndef __IMessageRouter_FWD_DEFINED__
#define __IMessageRouter_FWD_DEFINED__
typedef interface IMessageRouter IMessageRouter;
#endif 	/* __IMessageRouter_FWD_DEFINED__ */


#ifndef __IMailTransportRouterSetLinkState_FWD_DEFINED__
#define __IMailTransportRouterSetLinkState_FWD_DEFINED__
typedef interface IMailTransportRouterSetLinkState IMailTransportRouterSetLinkState;
#endif 	/* __IMailTransportRouterSetLinkState_FWD_DEFINED__ */


#ifndef __IMessageRouterLinkStateNotification_FWD_DEFINED__
#define __IMessageRouterLinkStateNotification_FWD_DEFINED__
typedef interface IMessageRouterLinkStateNotification IMessageRouterLinkStateNotification;
#endif 	/* __IMessageRouterLinkStateNotification_FWD_DEFINED__ */


#ifndef __IMailTransportRoutingEngine_FWD_DEFINED__
#define __IMailTransportRoutingEngine_FWD_DEFINED__
typedef interface IMailTransportRoutingEngine IMailTransportRoutingEngine;
#endif 	/* __IMailTransportRoutingEngine_FWD_DEFINED__ */


#ifndef __IMsgTrackLog_FWD_DEFINED__
#define __IMsgTrackLog_FWD_DEFINED__
typedef interface IMsgTrackLog IMsgTrackLog;
#endif 	/* __IMsgTrackLog_FWD_DEFINED__ */


#ifndef __IDnsResolverRecord_FWD_DEFINED__
#define __IDnsResolverRecord_FWD_DEFINED__
typedef interface IDnsResolverRecord IDnsResolverRecord;
#endif 	/* __IDnsResolverRecord_FWD_DEFINED__ */


#ifndef __IDnsResolverRecordSink_FWD_DEFINED__
#define __IDnsResolverRecordSink_FWD_DEFINED__
typedef interface IDnsResolverRecordSink IDnsResolverRecordSink;
#endif 	/* __IDnsResolverRecordSink_FWD_DEFINED__ */


#ifndef __ISmtpMaxMsgSize_FWD_DEFINED__
#define __ISmtpMaxMsgSize_FWD_DEFINED__
typedef interface ISmtpMaxMsgSize ISmtpMaxMsgSize;
#endif 	/* __ISmtpMaxMsgSize_FWD_DEFINED__ */


#ifndef __ICategorizerProperties_FWD_DEFINED__
#define __ICategorizerProperties_FWD_DEFINED__
typedef interface ICategorizerProperties ICategorizerProperties;
#endif 	/* __ICategorizerProperties_FWD_DEFINED__ */


#ifndef __ICategorizerParameters_FWD_DEFINED__
#define __ICategorizerParameters_FWD_DEFINED__
typedef interface ICategorizerParameters ICategorizerParameters;
#endif 	/* __ICategorizerParameters_FWD_DEFINED__ */


#ifndef __ICategorizerQueries_FWD_DEFINED__
#define __ICategorizerQueries_FWD_DEFINED__
typedef interface ICategorizerQueries ICategorizerQueries;
#endif 	/* __ICategorizerQueries_FWD_DEFINED__ */


#ifndef __ICategorizerMailMsgs_FWD_DEFINED__
#define __ICategorizerMailMsgs_FWD_DEFINED__
typedef interface ICategorizerMailMsgs ICategorizerMailMsgs;
#endif 	/* __ICategorizerMailMsgs_FWD_DEFINED__ */


#ifndef __ICategorizerItemAttributes_FWD_DEFINED__
#define __ICategorizerItemAttributes_FWD_DEFINED__
typedef interface ICategorizerItemAttributes ICategorizerItemAttributes;
#endif 	/* __ICategorizerItemAttributes_FWD_DEFINED__ */


#ifndef __ICategorizerItemRawAttributes_FWD_DEFINED__
#define __ICategorizerItemRawAttributes_FWD_DEFINED__
typedef interface ICategorizerItemRawAttributes ICategorizerItemRawAttributes;
#endif 	/* __ICategorizerItemRawAttributes_FWD_DEFINED__ */


#ifndef __ICategorizerItem_FWD_DEFINED__
#define __ICategorizerItem_FWD_DEFINED__
typedef interface ICategorizerItem ICategorizerItem;
#endif 	/* __ICategorizerItem_FWD_DEFINED__ */


#ifndef __ICategorizerAsyncContext_FWD_DEFINED__
#define __ICategorizerAsyncContext_FWD_DEFINED__
typedef interface ICategorizerAsyncContext ICategorizerAsyncContext;
#endif 	/* __ICategorizerAsyncContext_FWD_DEFINED__ */


#ifndef __ICategorizerListResolve_FWD_DEFINED__
#define __ICategorizerListResolve_FWD_DEFINED__
typedef interface ICategorizerListResolve ICategorizerListResolve;
#endif 	/* __ICategorizerListResolve_FWD_DEFINED__ */


#ifndef __IMailTransportCategorize_FWD_DEFINED__
#define __IMailTransportCategorize_FWD_DEFINED__
typedef interface IMailTransportCategorize IMailTransportCategorize;
#endif 	/* __IMailTransportCategorize_FWD_DEFINED__ */


#ifndef __ISMTPCategorizer_FWD_DEFINED__
#define __ISMTPCategorizer_FWD_DEFINED__
typedef interface ISMTPCategorizer ISMTPCategorizer;
#endif 	/* __ISMTPCategorizer_FWD_DEFINED__ */


#ifndef __ISMTPCategorizerCompletion_FWD_DEFINED__
#define __ISMTPCategorizerCompletion_FWD_DEFINED__
typedef interface ISMTPCategorizerCompletion ISMTPCategorizerCompletion;
#endif 	/* __ISMTPCategorizerCompletion_FWD_DEFINED__ */


#ifndef __ISMTPCategorizerDLCompletion_FWD_DEFINED__
#define __ISMTPCategorizerDLCompletion_FWD_DEFINED__
typedef interface ISMTPCategorizerDLCompletion ISMTPCategorizerDLCompletion;
#endif 	/* __ISMTPCategorizerDLCompletion_FWD_DEFINED__ */


#ifndef __ICategorizerDomainInfo_FWD_DEFINED__
#define __ICategorizerDomainInfo_FWD_DEFINED__
typedef interface ICategorizerDomainInfo ICategorizerDomainInfo;
#endif 	/* __ICategorizerDomainInfo_FWD_DEFINED__ */


/* header files for imported files */
#include "unknwn.h"
#include "ocidl.h"
#include "mailmsg.h"

#ifdef __cplusplus
extern "C"{
#endif 

void __RPC_FAR * __RPC_USER MIDL_user_allocate(size_t);
void __RPC_USER MIDL_user_free( void __RPC_FAR * ); 

/* interface __MIDL_itf_SmtpEvent_0000 */
/* [local] */ 

#ifndef __SMTPEVENT_H__
#define __SMTPEVENT_H__
//
// Define sink return codes
//
#define EXPE_S_CONSUMED              0x00000002
//
// Define well-known status codes
//
#define EXPE_SUCCESS                 0x00000000
#define EXPE_NOT_PIPELINED           0x00000000
#define EXPE_PIPELINED               0x00000001
#define EXPE_REPEAT_COMMAND          0x00000002
#define EXPE_BLOB_READY              0x00000004
#define EXPE_BLOB_DONE               0x00000008
#define EXPE_DROP_SESSION            0x00010000
#define EXPE_CHANGE_STATE            0x00020000
#define EXPE_TRANSIENT_FAILURE       0x00040000
#define EXPE_COMPLETE_FAILURE        0x00080000
#define EXPE_UNHANDLED                       0xffffffff
//
// Define constants for next states
//
typedef enum _PE_STATES
{
     PE_STATE_DEFAULT = 0,
     PE_STATE_SESSION_START,
     PE_STATE_MESSAGE_START,
     PE_STATE_PER_RECIPIENT,
     PE_STATE_DATA_OR_BDAT,
     PE_STATE_SESSION_END,
     PE_STATE_MAX_STATES = PE_STATE_SESSION_END

} PE_STATES;
//
// Define macros for checking SMTP return code classes
//
#define IsSmtpPreliminarySuccess(x)          ((((x) % 100) == 1)?TRUE:FALSE)
#define IsSmtpCompleteSuccess(x)                     ((((x) % 100) == 2)?TRUE:FALSE)
#define IsSmtpIntermediateSuccess(x)         ((((x) % 100) == 3)?TRUE:FALSE)
#define IsSmtpTransientFailure(x)            ((((x) % 100) == 4)?TRUE:FALSE)
#define IsSmtpCompleteFailure(x)                     ((((x) % 100) == 5)?TRUE:FALSE)
//
// Define well known IServer property IDs
//
#define PE_ISERVID_DW_INSTANCE               0
#define PE_ISERVID_SZ_DEFAULTDOMAIN          1
#define PE_ISERVID_DW_CATENABLE              2
#define PE_ISERVID_DW_CATFLAGS               3
#define PE_ISERVID_DW_CATPORT                4
#define PE_ISERVID_SZ_CATUSER                5
#define PE_ISERVID_SZ_CATSCHEMA              6
#define PE_ISERVID_SZ_CATBINDTYPE            7
#define PE_ISERVID_SZ_CATPASSWORD            8
#define PE_ISERVID_SZ_CATDOMAIN              9
#define PE_ISERVID_SZ_CATNAMINGCONTEXT      10
#define PE_ISERVID_SZ_CATDSTYPE             11
#define PE_ISERVID_SZ_CATDSHOST             12



extern RPC_IF_HANDLE __MIDL_itf_SmtpEvent_0000_v0_0_c_ifspec;
extern RPC_IF_HANDLE __MIDL_itf_SmtpEvent_0000_v0_0_s_ifspec;

#ifndef __ISmtpInCommandContext_INTERFACE_DEFINED__
#define __ISmtpInCommandContext_INTERFACE_DEFINED__

/* interface ISmtpInCommandContext */
/* [unique][helpstring][uuid][local][object] */ 


EXTERN_C const IID IID_ISmtpInCommandContext;

#if defined(__cplusplus) && !defined(CINTERFACE)
    
    MIDL_INTERFACE("5F15C533-E90E-11D1-8852-00C04FA35B86")
    ISmtpInCommandContext : public IUnknown
    {
    public:
        virtual HRESULT STDMETHODCALLTYPE QueryCommand( 
            /* [size_is][out] */ LPSTR pszCommand,
            /* [out][in] */ DWORD __RPC_FAR *pdwSize) = 0;
        
        virtual HRESULT STDMETHODCALLTYPE QueryCommandKeyword( 
            /* [size_is][out] */ LPSTR pszKeyword,
            /* [out][in] */ DWORD __RPC_FAR *pdwSize) = 0;
        
        virtual HRESULT STDMETHODCALLTYPE QueryNativeResponse( 
            /* [size_is][out] */ LPSTR pszNativeResponse,
            /* [out][in] */ DWORD __RPC_FAR *pdwSize) = 0;
        
        virtual HRESULT STDMETHODCALLTYPE QueryResponse( 
            /* [size_is][out] */ LPSTR pszResponse,
            /* [out][in] */ DWORD __RPC_FAR *pdwSize) = 0;
        
        virtual HRESULT STDMETHODCALLTYPE QueryCommandSize( 
            /* [out] */ DWORD __RPC_FAR *pdwSize) = 0;
        
        virtual HRESULT STDMETHODCALLTYPE QueryCommandKeywordSize( 
            /* [out] */ DWORD __RPC_FAR *pdwSize) = 0;
        
        virtual HRESULT STDMETHODCALLTYPE QueryNativeResponseSize( 
            /* [out] */ DWORD __RPC_FAR *pdwSize) = 0;
        
        virtual HRESULT STDMETHODCALLTYPE QueryResponseSize( 
            /* [out] */ DWORD __RPC_FAR *pdwSize) = 0;
        
        virtual HRESULT STDMETHODCALLTYPE QueryCommandStatus( 
            /* [out] */ DWORD __RPC_FAR *pdwCommandStatus) = 0;
        
        virtual HRESULT STDMETHODCALLTYPE QuerySmtpStatusCode( 
            /* [out] */ DWORD __RPC_FAR *pdwSmtpStatus) = 0;
        
        virtual HRESULT STDMETHODCALLTYPE QueryProtocolErrorFlag( 
            /* [out] */ BOOL __RPC_FAR *pfProtocolError) = 0;
        
        virtual HRESULT STDMETHODCALLTYPE SetResponse( 
            /* [string][in] */ LPSTR pszResponse,
            /* [in] */ DWORD dwSize) = 0;
        
        virtual HRESULT STDMETHODCALLTYPE AppendResponse( 
            /* [string][in] */ LPSTR pszResponse,
            /* [in] */ DWORD dwSize) = 0;
        
        virtual HRESULT STDMETHODCALLTYPE SetNativeResponse( 
            /* [string][in] */ LPSTR pszNativeResponse,
            /* [in] */ DWORD dwSize) = 0;
        
        virtual HRESULT STDMETHODCALLTYPE AppendNativeResponse( 
            /* [string][in] */ LPSTR pszNativeResponse,
            /* [in] */ DWORD dwSize) = 0;
        
        virtual HRESULT STDMETHODCALLTYPE SetCommandStatus( 
            /* [in] */ DWORD dwCommandStatus) = 0;
        
        virtual HRESULT STDMETHODCALLTYPE SetSmtpStatusCode( 
            /* [in] */ DWORD dwSmtpStatus) = 0;
        
        virtual HRESULT STDMETHODCALLTYPE SetProtocolErrorFlag( 
            /* [in] */ BOOL fProtocolError) = 0;
        
        virtual HRESULT STDMETHODCALLTYPE NotifyAsyncCompletion( 
            /* [in] */ HRESULT hrResult) = 0;
        
        virtual HRESULT STDMETHODCALLTYPE SetCallback( 
            /* [in] */ ISmtpInCallbackSink __RPC_FAR *pICallback) = 0;
        
    };
    
#else 	/* C style interface */

    typedef struct ISmtpInCommandContextVtbl
    {
        BEGIN_INTERFACE
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *QueryInterface )( 
            ISmtpInCommandContext __RPC_FAR * This,
            /* [in] */ REFIID riid,
            /* [iid_is][out] */ void __RPC_FAR *__RPC_FAR *ppvObject);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *AddRef )( 
            ISmtpInCommandContext __RPC_FAR * This);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *Release )( 
            ISmtpInCommandContext __RPC_FAR * This);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *QueryCommand )( 
            ISmtpInCommandContext __RPC_FAR * This,
            /* [size_is][out] */ LPSTR pszCommand,
            /* [out][in] */ DWORD __RPC_FAR *pdwSize);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *QueryCommandKeyword )( 
            ISmtpInCommandContext __RPC_FAR * This,
            /* [size_is][out] */ LPSTR pszKeyword,
            /* [out][in] */ DWORD __RPC_FAR *pdwSize);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *QueryNativeResponse )( 
            ISmtpInCommandContext __RPC_FAR * This,
            /* [size_is][out] */ LPSTR pszNativeResponse,
            /* [out][in] */ DWORD __RPC_FAR *pdwSize);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *QueryResponse )( 
            ISmtpInCommandContext __RPC_FAR * This,
            /* [size_is][out] */ LPSTR pszResponse,
            /* [out][in] */ DWORD __RPC_FAR *pdwSize);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *QueryCommandSize )( 
            ISmtpInCommandContext __RPC_FAR * This,
            /* [out] */ DWORD __RPC_FAR *pdwSize);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *QueryCommandKeywordSize )( 
            ISmtpInCommandContext __RPC_FAR * This,
            /* [out] */ DWORD __RPC_FAR *pdwSize);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *QueryNativeResponseSize )( 
            ISmtpInCommandContext __RPC_FAR * This,
            /* [out] */ DWORD __RPC_FAR *pdwSize);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *QueryResponseSize )( 
            ISmtpInCommandContext __RPC_FAR * This,
            /* [out] */ DWORD __RPC_FAR *pdwSize);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *QueryCommandStatus )( 
            ISmtpInCommandContext __RPC_FAR * This,
            /* [out] */ DWORD __RPC_FAR *pdwCommandStatus);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *QuerySmtpStatusCode )( 
            ISmtpInCommandContext __RPC_FAR * This,
            /* [out] */ DWORD __RPC_FAR *pdwSmtpStatus);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *QueryProtocolErrorFlag )( 
            ISmtpInCommandContext __RPC_FAR * This,
            /* [out] */ BOOL __RPC_FAR *pfProtocolError);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *SetResponse )( 
            ISmtpInCommandContext __RPC_FAR * This,
            /* [string][in] */ LPSTR pszResponse,
            /* [in] */ DWORD dwSize);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *AppendResponse )( 
            ISmtpInCommandContext __RPC_FAR * This,
            /* [string][in] */ LPSTR pszResponse,
            /* [in] */ DWORD dwSize);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *SetNativeResponse )( 
            ISmtpInCommandContext __RPC_FAR * This,
            /* [string][in] */ LPSTR pszNativeResponse,
            /* [in] */ DWORD dwSize);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *AppendNativeResponse )( 
            ISmtpInCommandContext __RPC_FAR * This,
            /* [string][in] */ LPSTR pszNativeResponse,
            /* [in] */ DWORD dwSize);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *SetCommandStatus )( 
            ISmtpInCommandContext __RPC_FAR * This,
            /* [in] */ DWORD dwCommandStatus);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *SetSmtpStatusCode )( 
            ISmtpInCommandContext __RPC_FAR * This,
            /* [in] */ DWORD dwSmtpStatus);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *SetProtocolErrorFlag )( 
            ISmtpInCommandContext __RPC_FAR * This,
            /* [in] */ BOOL fProtocolError);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *NotifyAsyncCompletion )( 
            ISmtpInCommandContext __RPC_FAR * This,
            /* [in] */ HRESULT hrResult);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *SetCallback )( 
            ISmtpInCommandContext __RPC_FAR * This,
            /* [in] */ ISmtpInCallbackSink __RPC_FAR *pICallback);
        
        END_INTERFACE
    } ISmtpInCommandContextVtbl;

    interface ISmtpInCommandContext
    {
        CONST_VTBL struct ISmtpInCommandContextVtbl __RPC_FAR *lpVtbl;
    };

    

#ifdef COBJMACROS


#define ISmtpInCommandContext_QueryInterface(This,riid,ppvObject)	\
    (This)->lpVtbl -> QueryInterface(This,riid,ppvObject)

#define ISmtpInCommandContext_AddRef(This)	\
    (This)->lpVtbl -> AddRef(This)

#define ISmtpInCommandContext_Release(This)	\
    (This)->lpVtbl -> Release(This)


#define ISmtpInCommandContext_QueryCommand(This,pszCommand,pdwSize)	\
    (This)->lpVtbl -> QueryCommand(This,pszCommand,pdwSize)

#define ISmtpInCommandContext_QueryCommandKeyword(This,pszKeyword,pdwSize)	\
    (This)->lpVtbl -> QueryCommandKeyword(This,pszKeyword,pdwSize)

#define ISmtpInCommandContext_QueryNativeResponse(This,pszNativeResponse,pdwSize)	\
    (This)->lpVtbl -> QueryNativeResponse(This,pszNativeResponse,pdwSize)

#define ISmtpInCommandContext_QueryResponse(This,pszResponse,pdwSize)	\
    (This)->lpVtbl -> QueryResponse(This,pszResponse,pdwSize)

#define ISmtpInCommandContext_QueryCommandSize(This,pdwSize)	\
    (This)->lpVtbl -> QueryCommandSize(This,pdwSize)

#define ISmtpInCommandContext_QueryCommandKeywordSize(This,pdwSize)	\
    (This)->lpVtbl -> QueryCommandKeywordSize(This,pdwSize)

#define ISmtpInCommandContext_QueryNativeResponseSize(This,pdwSize)	\
    (This)->lpVtbl -> QueryNativeResponseSize(This,pdwSize)

#define ISmtpInCommandContext_QueryResponseSize(This,pdwSize)	\
    (This)->lpVtbl -> QueryResponseSize(This,pdwSize)

#define ISmtpInCommandContext_QueryCommandStatus(This,pdwCommandStatus)	\
    (This)->lpVtbl -> QueryCommandStatus(This,pdwCommandStatus)

#define ISmtpInCommandContext_QuerySmtpStatusCode(This,pdwSmtpStatus)	\
    (This)->lpVtbl -> QuerySmtpStatusCode(This,pdwSmtpStatus)

#define ISmtpInCommandContext_QueryProtocolErrorFlag(This,pfProtocolError)	\
    (This)->lpVtbl -> QueryProtocolErrorFlag(This,pfProtocolError)

#define ISmtpInCommandContext_SetResponse(This,pszResponse,dwSize)	\
    (This)->lpVtbl -> SetResponse(This,pszResponse,dwSize)

#define ISmtpInCommandContext_AppendResponse(This,pszResponse,dwSize)	\
    (This)->lpVtbl -> AppendResponse(This,pszResponse,dwSize)

#define ISmtpInCommandContext_SetNativeResponse(This,pszNativeResponse,dwSize)	\
    (This)->lpVtbl -> SetNativeResponse(This,pszNativeResponse,dwSize)

#define ISmtpInCommandContext_AppendNativeResponse(This,pszNativeResponse,dwSize)	\
    (This)->lpVtbl -> AppendNativeResponse(This,pszNativeResponse,dwSize)

#define ISmtpInCommandContext_SetCommandStatus(This,dwCommandStatus)	\
    (This)->lpVtbl -> SetCommandStatus(This,dwCommandStatus)

#define ISmtpInCommandContext_SetSmtpStatusCode(This,dwSmtpStatus)	\
    (This)->lpVtbl -> SetSmtpStatusCode(This,dwSmtpStatus)

#define ISmtpInCommandContext_SetProtocolErrorFlag(This,fProtocolError)	\
    (This)->lpVtbl -> SetProtocolErrorFlag(This,fProtocolError)

#define ISmtpInCommandContext_NotifyAsyncCompletion(This,hrResult)	\
    (This)->lpVtbl -> NotifyAsyncCompletion(This,hrResult)

#define ISmtpInCommandContext_SetCallback(This,pICallback)	\
    (This)->lpVtbl -> SetCallback(This,pICallback)

#endif /* COBJMACROS */


#endif 	/* C style interface */



HRESULT STDMETHODCALLTYPE ISmtpInCommandContext_QueryCommand_Proxy( 
    ISmtpInCommandContext __RPC_FAR * This,
    /* [size_is][out] */ LPSTR pszCommand,
    /* [out][in] */ DWORD __RPC_FAR *pdwSize);


void __RPC_STUB ISmtpInCommandContext_QueryCommand_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


HRESULT STDMETHODCALLTYPE ISmtpInCommandContext_QueryCommandKeyword_Proxy( 
    ISmtpInCommandContext __RPC_FAR * This,
    /* [size_is][out] */ LPSTR pszKeyword,
    /* [out][in] */ DWORD __RPC_FAR *pdwSize);


void __RPC_STUB ISmtpInCommandContext_QueryCommandKeyword_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


HRESULT STDMETHODCALLTYPE ISmtpInCommandContext_QueryNativeResponse_Proxy( 
    ISmtpInCommandContext __RPC_FAR * This,
    /* [size_is][out] */ LPSTR pszNativeResponse,
    /* [out][in] */ DWORD __RPC_FAR *pdwSize);


void __RPC_STUB ISmtpInCommandContext_QueryNativeResponse_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


HRESULT STDMETHODCALLTYPE ISmtpInCommandContext_QueryResponse_Proxy( 
    ISmtpInCommandContext __RPC_FAR * This,
    /* [size_is][out] */ LPSTR pszResponse,
    /* [out][in] */ DWORD __RPC_FAR *pdwSize);


void __RPC_STUB ISmtpInCommandContext_QueryResponse_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


HRESULT STDMETHODCALLTYPE ISmtpInCommandContext_QueryCommandSize_Proxy( 
    ISmtpInCommandContext __RPC_FAR * This,
    /* [out] */ DWORD __RPC_FAR *pdwSize);


void __RPC_STUB ISmtpInCommandContext_QueryCommandSize_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


HRESULT STDMETHODCALLTYPE ISmtpInCommandContext_QueryCommandKeywordSize_Proxy( 
    ISmtpInCommandContext __RPC_FAR * This,
    /* [out] */ DWORD __RPC_FAR *pdwSize);


void __RPC_STUB ISmtpInCommandContext_QueryCommandKeywordSize_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


HRESULT STDMETHODCALLTYPE ISmtpInCommandContext_QueryNativeResponseSize_Proxy( 
    ISmtpInCommandContext __RPC_FAR * This,
    /* [out] */ DWORD __RPC_FAR *pdwSize);


void __RPC_STUB ISmtpInCommandContext_QueryNativeResponseSize_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


HRESULT STDMETHODCALLTYPE ISmtpInCommandContext_QueryResponseSize_Proxy( 
    ISmtpInCommandContext __RPC_FAR * This,
    /* [out] */ DWORD __RPC_FAR *pdwSize);


void __RPC_STUB ISmtpInCommandContext_QueryResponseSize_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


HRESULT STDMETHODCALLTYPE ISmtpInCommandContext_QueryCommandStatus_Proxy( 
    ISmtpInCommandContext __RPC_FAR * This,
    /* [out] */ DWORD __RPC_FAR *pdwCommandStatus);


void __RPC_STUB ISmtpInCommandContext_QueryCommandStatus_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


HRESULT STDMETHODCALLTYPE ISmtpInCommandContext_QuerySmtpStatusCode_Proxy( 
    ISmtpInCommandContext __RPC_FAR * This,
    /* [out] */ DWORD __RPC_FAR *pdwSmtpStatus);


void __RPC_STUB ISmtpInCommandContext_QuerySmtpStatusCode_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


HRESULT STDMETHODCALLTYPE ISmtpInCommandContext_QueryProtocolErrorFlag_Proxy( 
    ISmtpInCommandContext __RPC_FAR * This,
    /* [out] */ BOOL __RPC_FAR *pfProtocolError);


void __RPC_STUB ISmtpInCommandContext_QueryProtocolErrorFlag_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


HRESULT STDMETHODCALLTYPE ISmtpInCommandContext_SetResponse_Proxy( 
    ISmtpInCommandContext __RPC_FAR * This,
    /* [string][in] */ LPSTR pszResponse,
    /* [in] */ DWORD dwSize);


void __RPC_STUB ISmtpInCommandContext_SetResponse_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


HRESULT STDMETHODCALLTYPE ISmtpInCommandContext_AppendResponse_Proxy( 
    ISmtpInCommandContext __RPC_FAR * This,
    /* [string][in] */ LPSTR pszResponse,
    /* [in] */ DWORD dwSize);


void __RPC_STUB ISmtpInCommandContext_AppendResponse_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


HRESULT STDMETHODCALLTYPE ISmtpInCommandContext_SetNativeResponse_Proxy( 
    ISmtpInCommandContext __RPC_FAR * This,
    /* [string][in] */ LPSTR pszNativeResponse,
    /* [in] */ DWORD dwSize);


void __RPC_STUB ISmtpInCommandContext_SetNativeResponse_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


HRESULT STDMETHODCALLTYPE ISmtpInCommandContext_AppendNativeResponse_Proxy( 
    ISmtpInCommandContext __RPC_FAR * This,
    /* [string][in] */ LPSTR pszNativeResponse,
    /* [in] */ DWORD dwSize);


void __RPC_STUB ISmtpInCommandContext_AppendNativeResponse_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


HRESULT STDMETHODCALLTYPE ISmtpInCommandContext_SetCommandStatus_Proxy( 
    ISmtpInCommandContext __RPC_FAR * This,
    /* [in] */ DWORD dwCommandStatus);


void __RPC_STUB ISmtpInCommandContext_SetCommandStatus_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


HRESULT STDMETHODCALLTYPE ISmtpInCommandContext_SetSmtpStatusCode_Proxy( 
    ISmtpInCommandContext __RPC_FAR * This,
    /* [in] */ DWORD dwSmtpStatus);


void __RPC_STUB ISmtpInCommandContext_SetSmtpStatusCode_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


HRESULT STDMETHODCALLTYPE ISmtpInCommandContext_SetProtocolErrorFlag_Proxy( 
    ISmtpInCommandContext __RPC_FAR * This,
    /* [in] */ BOOL fProtocolError);


void __RPC_STUB ISmtpInCommandContext_SetProtocolErrorFlag_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


HRESULT STDMETHODCALLTYPE ISmtpInCommandContext_NotifyAsyncCompletion_Proxy( 
    ISmtpInCommandContext __RPC_FAR * This,
    /* [in] */ HRESULT hrResult);


void __RPC_STUB ISmtpInCommandContext_NotifyAsyncCompletion_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


HRESULT STDMETHODCALLTYPE ISmtpInCommandContext_SetCallback_Proxy( 
    ISmtpInCommandContext __RPC_FAR * This,
    /* [in] */ ISmtpInCallbackSink __RPC_FAR *pICallback);


void __RPC_STUB ISmtpInCommandContext_SetCallback_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);



#endif 	/* __ISmtpInCommandContext_INTERFACE_DEFINED__ */


#ifndef __ISmtpInCallbackContext_INTERFACE_DEFINED__
#define __ISmtpInCallbackContext_INTERFACE_DEFINED__

/* interface ISmtpInCallbackContext */
/* [unique][helpstring][uuid][local][object] */ 


EXTERN_C const IID IID_ISmtpInCallbackContext;

#if defined(__cplusplus) && !defined(CINTERFACE)
    
    MIDL_INTERFACE("5e4fc9da-3e3b-11d3-88f1-00c04fa35b86")
    ISmtpInCallbackContext : public IUnknown
    {
    public:
        virtual HRESULT STDMETHODCALLTYPE QueryBlob( 
            /* [out] */ BYTE __RPC_FAR *__RPC_FAR *ppbBlob,
            /* [out][in] */ DWORD __RPC_FAR *pdwSize) = 0;
        
        virtual HRESULT STDMETHODCALLTYPE QueryBlobSize( 
            /* [out] */ DWORD __RPC_FAR *pdwSize) = 0;
        
        virtual HRESULT STDMETHODCALLTYPE SetResponse( 
            /* [string][in] */ LPSTR pszResponse,
            /* [in] */ DWORD dwSize) = 0;
        
        virtual HRESULT STDMETHODCALLTYPE AppendResponse( 
            /* [string][in] */ LPSTR pszResponse,
            /* [in] */ DWORD dwSize) = 0;
        
        virtual HRESULT STDMETHODCALLTYPE SetCommandStatus( 
            /* [in] */ DWORD dwCommandStatus) = 0;
        
        virtual HRESULT STDMETHODCALLTYPE SetSmtpStatusCode( 
            /* [in] */ DWORD dwSmtpStatus) = 0;
        
    };
    
#else 	/* C style interface */

    typedef struct ISmtpInCallbackContextVtbl
    {
        BEGIN_INTERFACE
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *QueryInterface )( 
            ISmtpInCallbackContext __RPC_FAR * This,
            /* [in] */ REFIID riid,
            /* [iid_is][out] */ void __RPC_FAR *__RPC_FAR *ppvObject);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *AddRef )( 
            ISmtpInCallbackContext __RPC_FAR * This);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *Release )( 
            ISmtpInCallbackContext __RPC_FAR * This);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *QueryBlob )( 
            ISmtpInCallbackContext __RPC_FAR * This,
            /* [out] */ BYTE __RPC_FAR *__RPC_FAR *ppbBlob,
            /* [out][in] */ DWORD __RPC_FAR *pdwSize);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *QueryBlobSize )( 
            ISmtpInCallbackContext __RPC_FAR * This,
            /* [out] */ DWORD __RPC_FAR *pdwSize);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *SetResponse )( 
            ISmtpInCallbackContext __RPC_FAR * This,
            /* [string][in] */ LPSTR pszResponse,
            /* [in] */ DWORD dwSize);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *AppendResponse )( 
            ISmtpInCallbackContext __RPC_FAR * This,
            /* [string][in] */ LPSTR pszResponse,
            /* [in] */ DWORD dwSize);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *SetCommandStatus )( 
            ISmtpInCallbackContext __RPC_FAR * This,
            /* [in] */ DWORD dwCommandStatus);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *SetSmtpStatusCode )( 
            ISmtpInCallbackContext __RPC_FAR * This,
            /* [in] */ DWORD dwSmtpStatus);
        
        END_INTERFACE
    } ISmtpInCallbackContextVtbl;

    interface ISmtpInCallbackContext
    {
        CONST_VTBL struct ISmtpInCallbackContextVtbl __RPC_FAR *lpVtbl;
    };

    

#ifdef COBJMACROS


#define ISmtpInCallbackContext_QueryInterface(This,riid,ppvObject)	\
    (This)->lpVtbl -> QueryInterface(This,riid,ppvObject)

#define ISmtpInCallbackContext_AddRef(This)	\
    (This)->lpVtbl -> AddRef(This)

#define ISmtpInCallbackContext_Release(This)	\
    (This)->lpVtbl -> Release(This)


#define ISmtpInCallbackContext_QueryBlob(This,ppbBlob,pdwSize)	\
    (This)->lpVtbl -> QueryBlob(This,ppbBlob,pdwSize)

#define ISmtpInCallbackContext_QueryBlobSize(This,pdwSize)	\
    (This)->lpVtbl -> QueryBlobSize(This,pdwSize)

#define ISmtpInCallbackContext_SetResponse(This,pszResponse,dwSize)	\
    (This)->lpVtbl -> SetResponse(This,pszResponse,dwSize)

#define ISmtpInCallbackContext_AppendResponse(This,pszResponse,dwSize)	\
    (This)->lpVtbl -> AppendResponse(This,pszResponse,dwSize)

#define ISmtpInCallbackContext_SetCommandStatus(This,dwCommandStatus)	\
    (This)->lpVtbl -> SetCommandStatus(This,dwCommandStatus)

#define ISmtpInCallbackContext_SetSmtpStatusCode(This,dwSmtpStatus)	\
    (This)->lpVtbl -> SetSmtpStatusCode(This,dwSmtpStatus)

#endif /* COBJMACROS */


#endif 	/* C style interface */



HRESULT STDMETHODCALLTYPE ISmtpInCallbackContext_QueryBlob_Proxy( 
    ISmtpInCallbackContext __RPC_FAR * This,
    /* [out] */ BYTE __RPC_FAR *__RPC_FAR *ppbBlob,
    /* [out][in] */ DWORD __RPC_FAR *pdwSize);


void __RPC_STUB ISmtpInCallbackContext_QueryBlob_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


HRESULT STDMETHODCALLTYPE ISmtpInCallbackContext_QueryBlobSize_Proxy( 
    ISmtpInCallbackContext __RPC_FAR * This,
    /* [out] */ DWORD __RPC_FAR *pdwSize);


void __RPC_STUB ISmtpInCallbackContext_QueryBlobSize_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


HRESULT STDMETHODCALLTYPE ISmtpInCallbackContext_SetResponse_Proxy( 
    ISmtpInCallbackContext __RPC_FAR * This,
    /* [string][in] */ LPSTR pszResponse,
    /* [in] */ DWORD dwSize);


void __RPC_STUB ISmtpInCallbackContext_SetResponse_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


HRESULT STDMETHODCALLTYPE ISmtpInCallbackContext_AppendResponse_Proxy( 
    ISmtpInCallbackContext __RPC_FAR * This,
    /* [string][in] */ LPSTR pszResponse,
    /* [in] */ DWORD dwSize);


void __RPC_STUB ISmtpInCallbackContext_AppendResponse_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


HRESULT STDMETHODCALLTYPE ISmtpInCallbackContext_SetCommandStatus_Proxy( 
    ISmtpInCallbackContext __RPC_FAR * This,
    /* [in] */ DWORD dwCommandStatus);


void __RPC_STUB ISmtpInCallbackContext_SetCommandStatus_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


HRESULT STDMETHODCALLTYPE ISmtpInCallbackContext_SetSmtpStatusCode_Proxy( 
    ISmtpInCallbackContext __RPC_FAR * This,
    /* [in] */ DWORD dwSmtpStatus);


void __RPC_STUB ISmtpInCallbackContext_SetSmtpStatusCode_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);



#endif 	/* __ISmtpInCallbackContext_INTERFACE_DEFINED__ */


#ifndef __ISmtpOutCommandContext_INTERFACE_DEFINED__
#define __ISmtpOutCommandContext_INTERFACE_DEFINED__

/* interface ISmtpOutCommandContext */
/* [unique][helpstring][uuid][local][object] */ 


EXTERN_C const IID IID_ISmtpOutCommandContext;

#if defined(__cplusplus) && !defined(CINTERFACE)
    
    MIDL_INTERFACE("c849b5f2-0a80-11d2-aa67-00c04fa35b82")
    ISmtpOutCommandContext : public IUnknown
    {
    public:
        virtual HRESULT STDMETHODCALLTYPE QueryCommand( 
            /* [size_is][out] */ LPSTR pszCommand,
            /* [out][in] */ DWORD __RPC_FAR *pdwSize) = 0;
        
        virtual HRESULT STDMETHODCALLTYPE QueryCommandKeyword( 
            /* [size_is][out] */ LPSTR pszKeyword,
            /* [out][in] */ DWORD __RPC_FAR *pdwSize) = 0;
        
        virtual HRESULT STDMETHODCALLTYPE QueryNativeCommand( 
            /* [size_is][out] */ LPSTR pszNativeCommand,
            /* [out][in] */ DWORD __RPC_FAR *pdwSize) = 0;
        
        virtual HRESULT STDMETHODCALLTYPE QueryCommandSize( 
            /* [out] */ DWORD __RPC_FAR *pdwSize) = 0;
        
        virtual HRESULT STDMETHODCALLTYPE QueryCommandKeywordSize( 
            /* [out] */ DWORD __RPC_FAR *pdwSize) = 0;
        
        virtual HRESULT STDMETHODCALLTYPE QueryNativeCommandSize( 
            /* [out] */ DWORD __RPC_FAR *pdwSize) = 0;
        
        virtual HRESULT STDMETHODCALLTYPE QueryCurrentRecipientIndex( 
            /* [out] */ DWORD __RPC_FAR *pdwRecipientIndex) = 0;
        
        virtual HRESULT STDMETHODCALLTYPE QueryCommandStatus( 
            /* [out] */ DWORD __RPC_FAR *pdwCommandStatus) = 0;
        
        virtual HRESULT STDMETHODCALLTYPE SetCommand( 
            /* [string][in] */ LPSTR szCommand,
            /* [in] */ DWORD dwSize) = 0;
        
        virtual HRESULT STDMETHODCALLTYPE AppendCommand( 
            /* [string][in] */ LPSTR szCommand,
            /* [in] */ DWORD dwSize) = 0;
        
        virtual HRESULT STDMETHODCALLTYPE SetCommandStatus( 
            /* [in] */ DWORD dwCommandStatus) = 0;
        
        virtual HRESULT STDMETHODCALLTYPE NotifyAsyncCompletion( 
            /* [in] */ HRESULT hrResult) = 0;
        
        virtual HRESULT STDMETHODCALLTYPE SetBlob( 
            /* [in] */ BYTE __RPC_FAR *pbBlob,
            /* [in] */ DWORD dwSize) = 0;
        
    };
    
#else 	/* C style interface */

    typedef struct ISmtpOutCommandContextVtbl
    {
        BEGIN_INTERFACE
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *QueryInterface )( 
            ISmtpOutCommandContext __RPC_FAR * This,
            /* [in] */ REFIID riid,
            /* [iid_is][out] */ void __RPC_FAR *__RPC_FAR *ppvObject);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *AddRef )( 
            ISmtpOutCommandContext __RPC_FAR * This);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *Release )( 
            ISmtpOutCommandContext __RPC_FAR * This);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *QueryCommand )( 
            ISmtpOutCommandContext __RPC_FAR * This,
            /* [size_is][out] */ LPSTR pszCommand,
            /* [out][in] */ DWORD __RPC_FAR *pdwSize);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *QueryCommandKeyword )( 
            ISmtpOutCommandContext __RPC_FAR * This,
            /* [size_is][out] */ LPSTR pszKeyword,
            /* [out][in] */ DWORD __RPC_FAR *pdwSize);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *QueryNativeCommand )( 
            ISmtpOutCommandContext __RPC_FAR * This,
            /* [size_is][out] */ LPSTR pszNativeCommand,
            /* [out][in] */ DWORD __RPC_FAR *pdwSize);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *QueryCommandSize )( 
            ISmtpOutCommandContext __RPC_FAR * This,
            /* [out] */ DWORD __RPC_FAR *pdwSize);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *QueryCommandKeywordSize )( 
            ISmtpOutCommandContext __RPC_FAR * This,
            /* [out] */ DWORD __RPC_FAR *pdwSize);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *QueryNativeCommandSize )( 
            ISmtpOutCommandContext __RPC_FAR * This,
            /* [out] */ DWORD __RPC_FAR *pdwSize);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *QueryCurrentRecipientIndex )( 
            ISmtpOutCommandContext __RPC_FAR * This,
            /* [out] */ DWORD __RPC_FAR *pdwRecipientIndex);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *QueryCommandStatus )( 
            ISmtpOutCommandContext __RPC_FAR * This,
            /* [out] */ DWORD __RPC_FAR *pdwCommandStatus);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *SetCommand )( 
            ISmtpOutCommandContext __RPC_FAR * This,
            /* [string][in] */ LPSTR szCommand,
            /* [in] */ DWORD dwSize);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *AppendCommand )( 
            ISmtpOutCommandContext __RPC_FAR * This,
            /* [string][in] */ LPSTR szCommand,
            /* [in] */ DWORD dwSize);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *SetCommandStatus )( 
            ISmtpOutCommandContext __RPC_FAR * This,
            /* [in] */ DWORD dwCommandStatus);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *NotifyAsyncCompletion )( 
            ISmtpOutCommandContext __RPC_FAR * This,
            /* [in] */ HRESULT hrResult);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *SetBlob )( 
            ISmtpOutCommandContext __RPC_FAR * This,
            /* [in] */ BYTE __RPC_FAR *pbBlob,
            /* [in] */ DWORD dwSize);
        
        END_INTERFACE
    } ISmtpOutCommandContextVtbl;

    interface ISmtpOutCommandContext
    {
        CONST_VTBL struct ISmtpOutCommandContextVtbl __RPC_FAR *lpVtbl;
    };

    

#ifdef COBJMACROS


#define ISmtpOutCommandContext_QueryInterface(This,riid,ppvObject)	\
    (This)->lpVtbl -> QueryInterface(This,riid,ppvObject)

#define ISmtpOutCommandContext_AddRef(This)	\
    (This)->lpVtbl -> AddRef(This)

#define ISmtpOutCommandContext_Release(This)	\
    (This)->lpVtbl -> Release(This)


#define ISmtpOutCommandContext_QueryCommand(This,pszCommand,pdwSize)	\
    (This)->lpVtbl -> QueryCommand(This,pszCommand,pdwSize)

#define ISmtpOutCommandContext_QueryCommandKeyword(This,pszKeyword,pdwSize)	\
    (This)->lpVtbl -> QueryCommandKeyword(This,pszKeyword,pdwSize)

#define ISmtpOutCommandContext_QueryNativeCommand(This,pszNativeCommand,pdwSize)	\
    (This)->lpVtbl -> QueryNativeCommand(This,pszNativeCommand,pdwSize)

#define ISmtpOutCommandContext_QueryCommandSize(This,pdwSize)	\
    (This)->lpVtbl -> QueryCommandSize(This,pdwSize)

#define ISmtpOutCommandContext_QueryCommandKeywordSize(This,pdwSize)	\
    (This)->lpVtbl -> QueryCommandKeywordSize(This,pdwSize)

#define ISmtpOutCommandContext_QueryNativeCommandSize(This,pdwSize)	\
    (This)->lpVtbl -> QueryNativeCommandSize(This,pdwSize)

#define ISmtpOutCommandContext_QueryCurrentRecipientIndex(This,pdwRecipientIndex)	\
    (This)->lpVtbl -> QueryCurrentRecipientIndex(This,pdwRecipientIndex)

#define ISmtpOutCommandContext_QueryCommandStatus(This,pdwCommandStatus)	\
    (This)->lpVtbl -> QueryCommandStatus(This,pdwCommandStatus)

#define ISmtpOutCommandContext_SetCommand(This,szCommand,dwSize)	\
    (This)->lpVtbl -> SetCommand(This,szCommand,dwSize)

#define ISmtpOutCommandContext_AppendCommand(This,szCommand,dwSize)	\
    (This)->lpVtbl -> AppendCommand(This,szCommand,dwSize)

#define ISmtpOutCommandContext_SetCommandStatus(This,dwCommandStatus)	\
    (This)->lpVtbl -> SetCommandStatus(This,dwCommandStatus)

#define ISmtpOutCommandContext_NotifyAsyncCompletion(This,hrResult)	\
    (This)->lpVtbl -> NotifyAsyncCompletion(This,hrResult)

#define ISmtpOutCommandContext_SetBlob(This,pbBlob,dwSize)	\
    (This)->lpVtbl -> SetBlob(This,pbBlob,dwSize)

#endif /* COBJMACROS */


#endif 	/* C style interface */



HRESULT STDMETHODCALLTYPE ISmtpOutCommandContext_QueryCommand_Proxy( 
    ISmtpOutCommandContext __RPC_FAR * This,
    /* [size_is][out] */ LPSTR pszCommand,
    /* [out][in] */ DWORD __RPC_FAR *pdwSize);


void __RPC_STUB ISmtpOutCommandContext_QueryCommand_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


HRESULT STDMETHODCALLTYPE ISmtpOutCommandContext_QueryCommandKeyword_Proxy( 
    ISmtpOutCommandContext __RPC_FAR * This,
    /* [size_is][out] */ LPSTR pszKeyword,
    /* [out][in] */ DWORD __RPC_FAR *pdwSize);


void __RPC_STUB ISmtpOutCommandContext_QueryCommandKeyword_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


HRESULT STDMETHODCALLTYPE ISmtpOutCommandContext_QueryNativeCommand_Proxy( 
    ISmtpOutCommandContext __RPC_FAR * This,
    /* [size_is][out] */ LPSTR pszNativeCommand,
    /* [out][in] */ DWORD __RPC_FAR *pdwSize);


void __RPC_STUB ISmtpOutCommandContext_QueryNativeCommand_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


HRESULT STDMETHODCALLTYPE ISmtpOutCommandContext_QueryCommandSize_Proxy( 
    ISmtpOutCommandContext __RPC_FAR * This,
    /* [out] */ DWORD __RPC_FAR *pdwSize);


void __RPC_STUB ISmtpOutCommandContext_QueryCommandSize_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


HRESULT STDMETHODCALLTYPE ISmtpOutCommandContext_QueryCommandKeywordSize_Proxy( 
    ISmtpOutCommandContext __RPC_FAR * This,
    /* [out] */ DWORD __RPC_FAR *pdwSize);


void __RPC_STUB ISmtpOutCommandContext_QueryCommandKeywordSize_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


HRESULT STDMETHODCALLTYPE ISmtpOutCommandContext_QueryNativeCommandSize_Proxy( 
    ISmtpOutCommandContext __RPC_FAR * This,
    /* [out] */ DWORD __RPC_FAR *pdwSize);


void __RPC_STUB ISmtpOutCommandContext_QueryNativeCommandSize_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


HRESULT STDMETHODCALLTYPE ISmtpOutCommandContext_QueryCurrentRecipientIndex_Proxy( 
    ISmtpOutCommandContext __RPC_FAR * This,
    /* [out] */ DWORD __RPC_FAR *pdwRecipientIndex);


void __RPC_STUB ISmtpOutCommandContext_QueryCurrentRecipientIndex_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


HRESULT STDMETHODCALLTYPE ISmtpOutCommandContext_QueryCommandStatus_Proxy( 
    ISmtpOutCommandContext __RPC_FAR * This,
    /* [out] */ DWORD __RPC_FAR *pdwCommandStatus);


void __RPC_STUB ISmtpOutCommandContext_QueryCommandStatus_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


HRESULT STDMETHODCALLTYPE ISmtpOutCommandContext_SetCommand_Proxy( 
    ISmtpOutCommandContext __RPC_FAR * This,
    /* [string][in] */ LPSTR szCommand,
    /* [in] */ DWORD dwSize);


void __RPC_STUB ISmtpOutCommandContext_SetCommand_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


HRESULT STDMETHODCALLTYPE ISmtpOutCommandContext_AppendCommand_Proxy( 
    ISmtpOutCommandContext __RPC_FAR * This,
    /* [string][in] */ LPSTR szCommand,
    /* [in] */ DWORD dwSize);


void __RPC_STUB ISmtpOutCommandContext_AppendCommand_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


HRESULT STDMETHODCALLTYPE ISmtpOutCommandContext_SetCommandStatus_Proxy( 
    ISmtpOutCommandContext __RPC_FAR * This,
    /* [in] */ DWORD dwCommandStatus);


void __RPC_STUB ISmtpOutCommandContext_SetCommandStatus_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


HRESULT STDMETHODCALLTYPE ISmtpOutCommandContext_NotifyAsyncCompletion_Proxy( 
    ISmtpOutCommandContext __RPC_FAR * This,
    /* [in] */ HRESULT hrResult);


void __RPC_STUB ISmtpOutCommandContext_NotifyAsyncCompletion_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


HRESULT STDMETHODCALLTYPE ISmtpOutCommandContext_SetBlob_Proxy( 
    ISmtpOutCommandContext __RPC_FAR * This,
    /* [in] */ BYTE __RPC_FAR *pbBlob,
    /* [in] */ DWORD dwSize);


void __RPC_STUB ISmtpOutCommandContext_SetBlob_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);



#endif 	/* __ISmtpOutCommandContext_INTERFACE_DEFINED__ */


#ifndef __ISmtpServerResponseContext_INTERFACE_DEFINED__
#define __ISmtpServerResponseContext_INTERFACE_DEFINED__

/* interface ISmtpServerResponseContext */
/* [unique][helpstring][uuid][local][object] */ 


EXTERN_C const IID IID_ISmtpServerResponseContext;

#if defined(__cplusplus) && !defined(CINTERFACE)
    
    MIDL_INTERFACE("e38f9ad2-0a82-11d2-aa67-00c04fa35b82")
    ISmtpServerResponseContext : public IUnknown
    {
    public:
        virtual HRESULT STDMETHODCALLTYPE QueryCommand( 
            /* [size_is][out] */ LPSTR pszCommand,
            /* [out][in] */ DWORD __RPC_FAR *pdwSize) = 0;
        
        virtual HRESULT STDMETHODCALLTYPE QueryCommandKeyword( 
            /* [size_is][out] */ LPSTR pszKeyword,
            /* [out][in] */ DWORD __RPC_FAR *pdwSize) = 0;
        
        virtual HRESULT STDMETHODCALLTYPE QueryResponse( 
            /* [size_is][out] */ LPSTR pszResponse,
            /* [out][in] */ DWORD __RPC_FAR *pdwSize) = 0;
        
        virtual HRESULT STDMETHODCALLTYPE QueryCommandSize( 
            /* [out] */ DWORD __RPC_FAR *pdwSize) = 0;
        
        virtual HRESULT STDMETHODCALLTYPE QueryCommandKeywordSize( 
            /* [out] */ DWORD __RPC_FAR *pdwSize) = 0;
        
        virtual HRESULT STDMETHODCALLTYPE QueryResponseSize( 
            /* [out] */ DWORD __RPC_FAR *pdwSize) = 0;
        
        virtual HRESULT STDMETHODCALLTYPE QuerySmtpStatusCode( 
            /* [out] */ DWORD __RPC_FAR *pdwSmtpStatus) = 0;
        
        virtual HRESULT STDMETHODCALLTYPE QueryResponseStatus( 
            /* [out] */ DWORD __RPC_FAR *pdwResponseStatus) = 0;
        
        virtual HRESULT STDMETHODCALLTYPE QueryPipelinedFlag( 
            /* [out] */ BOOL __RPC_FAR *pfResponseIsPipelined) = 0;
        
        virtual HRESULT STDMETHODCALLTYPE QueryNextEventState( 
            /* [out] */ DWORD __RPC_FAR *pdwNextState) = 0;
        
        virtual HRESULT STDMETHODCALLTYPE SetResponseStatus( 
            /* [in] */ DWORD dwResponseStatus) = 0;
        
        virtual HRESULT STDMETHODCALLTYPE SetNextEventState( 
            /* [in] */ DWORD dwNextState) = 0;
        
        virtual HRESULT STDMETHODCALLTYPE NotifyAsyncCompletion( 
            /* [in] */ HRESULT hrResult) = 0;
        
    };
    
#else 	/* C style interface */

    typedef struct ISmtpServerResponseContextVtbl
    {
        BEGIN_INTERFACE
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *QueryInterface )( 
            ISmtpServerResponseContext __RPC_FAR * This,
            /* [in] */ REFIID riid,
            /* [iid_is][out] */ void __RPC_FAR *__RPC_FAR *ppvObject);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *AddRef )( 
            ISmtpServerResponseContext __RPC_FAR * This);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *Release )( 
            ISmtpServerResponseContext __RPC_FAR * This);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *QueryCommand )( 
            ISmtpServerResponseContext __RPC_FAR * This,
            /* [size_is][out] */ LPSTR pszCommand,
            /* [out][in] */ DWORD __RPC_FAR *pdwSize);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *QueryCommandKeyword )( 
            ISmtpServerResponseContext __RPC_FAR * This,
            /* [size_is][out] */ LPSTR pszKeyword,
            /* [out][in] */ DWORD __RPC_FAR *pdwSize);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *QueryResponse )( 
            ISmtpServerResponseContext __RPC_FAR * This,
            /* [size_is][out] */ LPSTR pszResponse,
            /* [out][in] */ DWORD __RPC_FAR *pdwSize);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *QueryCommandSize )( 
            ISmtpServerResponseContext __RPC_FAR * This,
            /* [out] */ DWORD __RPC_FAR *pdwSize);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *QueryCommandKeywordSize )( 
            ISmtpServerResponseContext __RPC_FAR * This,
            /* [out] */ DWORD __RPC_FAR *pdwSize);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *QueryResponseSize )( 
            ISmtpServerResponseContext __RPC_FAR * This,
            /* [out] */ DWORD __RPC_FAR *pdwSize);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *QuerySmtpStatusCode )( 
            ISmtpServerResponseContext __RPC_FAR * This,
            /* [out] */ DWORD __RPC_FAR *pdwSmtpStatus);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *QueryResponseStatus )( 
            ISmtpServerResponseContext __RPC_FAR * This,
            /* [out] */ DWORD __RPC_FAR *pdwResponseStatus);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *QueryPipelinedFlag )( 
            ISmtpServerResponseContext __RPC_FAR * This,
            /* [out] */ BOOL __RPC_FAR *pfResponseIsPipelined);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *QueryNextEventState )( 
            ISmtpServerResponseContext __RPC_FAR * This,
            /* [out] */ DWORD __RPC_FAR *pdwNextState);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *SetResponseStatus )( 
            ISmtpServerResponseContext __RPC_FAR * This,
            /* [in] */ DWORD dwResponseStatus);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *SetNextEventState )( 
            ISmtpServerResponseContext __RPC_FAR * This,
            /* [in] */ DWORD dwNextState);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *NotifyAsyncCompletion )( 
            ISmtpServerResponseContext __RPC_FAR * This,
            /* [in] */ HRESULT hrResult);
        
        END_INTERFACE
    } ISmtpServerResponseContextVtbl;

    interface ISmtpServerResponseContext
    {
        CONST_VTBL struct ISmtpServerResponseContextVtbl __RPC_FAR *lpVtbl;
    };

    

#ifdef COBJMACROS


#define ISmtpServerResponseContext_QueryInterface(This,riid,ppvObject)	\
    (This)->lpVtbl -> QueryInterface(This,riid,ppvObject)

#define ISmtpServerResponseContext_AddRef(This)	\
    (This)->lpVtbl -> AddRef(This)

#define ISmtpServerResponseContext_Release(This)	\
    (This)->lpVtbl -> Release(This)


#define ISmtpServerResponseContext_QueryCommand(This,pszCommand,pdwSize)	\
    (This)->lpVtbl -> QueryCommand(This,pszCommand,pdwSize)

#define ISmtpServerResponseContext_QueryCommandKeyword(This,pszKeyword,pdwSize)	\
    (This)->lpVtbl -> QueryCommandKeyword(This,pszKeyword,pdwSize)

#define ISmtpServerResponseContext_QueryResponse(This,pszResponse,pdwSize)	\
    (This)->lpVtbl -> QueryResponse(This,pszResponse,pdwSize)

#define ISmtpServerResponseContext_QueryCommandSize(This,pdwSize)	\
    (This)->lpVtbl -> QueryCommandSize(This,pdwSize)

#define ISmtpServerResponseContext_QueryCommandKeywordSize(This,pdwSize)	\
    (This)->lpVtbl -> QueryCommandKeywordSize(This,pdwSize)

#define ISmtpServerResponseContext_QueryResponseSize(This,pdwSize)	\
    (This)->lpVtbl -> QueryResponseSize(This,pdwSize)

#define ISmtpServerResponseContext_QuerySmtpStatusCode(This,pdwSmtpStatus)	\
    (This)->lpVtbl -> QuerySmtpStatusCode(This,pdwSmtpStatus)

#define ISmtpServerResponseContext_QueryResponseStatus(This,pdwResponseStatus)	\
    (This)->lpVtbl -> QueryResponseStatus(This,pdwResponseStatus)

#define ISmtpServerResponseContext_QueryPipelinedFlag(This,pfResponseIsPipelined)	\
    (This)->lpVtbl -> QueryPipelinedFlag(This,pfResponseIsPipelined)

#define ISmtpServerResponseContext_QueryNextEventState(This,pdwNextState)	\
    (This)->lpVtbl -> QueryNextEventState(This,pdwNextState)

#define ISmtpServerResponseContext_SetResponseStatus(This,dwResponseStatus)	\
    (This)->lpVtbl -> SetResponseStatus(This,dwResponseStatus)

#define ISmtpServerResponseContext_SetNextEventState(This,dwNextState)	\
    (This)->lpVtbl -> SetNextEventState(This,dwNextState)

#define ISmtpServerResponseContext_NotifyAsyncCompletion(This,hrResult)	\
    (This)->lpVtbl -> NotifyAsyncCompletion(This,hrResult)

#endif /* COBJMACROS */


#endif 	/* C style interface */



HRESULT STDMETHODCALLTYPE ISmtpServerResponseContext_QueryCommand_Proxy( 
    ISmtpServerResponseContext __RPC_FAR * This,
    /* [size_is][out] */ LPSTR pszCommand,
    /* [out][in] */ DWORD __RPC_FAR *pdwSize);


void __RPC_STUB ISmtpServerResponseContext_QueryCommand_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


HRESULT STDMETHODCALLTYPE ISmtpServerResponseContext_QueryCommandKeyword_Proxy( 
    ISmtpServerResponseContext __RPC_FAR * This,
    /* [size_is][out] */ LPSTR pszKeyword,
    /* [out][in] */ DWORD __RPC_FAR *pdwSize);


void __RPC_STUB ISmtpServerResponseContext_QueryCommandKeyword_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


HRESULT STDMETHODCALLTYPE ISmtpServerResponseContext_QueryResponse_Proxy( 
    ISmtpServerResponseContext __RPC_FAR * This,
    /* [size_is][out] */ LPSTR pszResponse,
    /* [out][in] */ DWORD __RPC_FAR *pdwSize);


void __RPC_STUB ISmtpServerResponseContext_QueryResponse_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


HRESULT STDMETHODCALLTYPE ISmtpServerResponseContext_QueryCommandSize_Proxy( 
    ISmtpServerResponseContext __RPC_FAR * This,
    /* [out] */ DWORD __RPC_FAR *pdwSize);


void __RPC_STUB ISmtpServerResponseContext_QueryCommandSize_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


HRESULT STDMETHODCALLTYPE ISmtpServerResponseContext_QueryCommandKeywordSize_Proxy( 
    ISmtpServerResponseContext __RPC_FAR * This,
    /* [out] */ DWORD __RPC_FAR *pdwSize);


void __RPC_STUB ISmtpServerResponseContext_QueryCommandKeywordSize_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


HRESULT STDMETHODCALLTYPE ISmtpServerResponseContext_QueryResponseSize_Proxy( 
    ISmtpServerResponseContext __RPC_FAR * This,
    /* [out] */ DWORD __RPC_FAR *pdwSize);


void __RPC_STUB ISmtpServerResponseContext_QueryResponseSize_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


HRESULT STDMETHODCALLTYPE ISmtpServerResponseContext_QuerySmtpStatusCode_Proxy( 
    ISmtpServerResponseContext __RPC_FAR * This,
    /* [out] */ DWORD __RPC_FAR *pdwSmtpStatus);


void __RPC_STUB ISmtpServerResponseContext_QuerySmtpStatusCode_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


HRESULT STDMETHODCALLTYPE ISmtpServerResponseContext_QueryResponseStatus_Proxy( 
    ISmtpServerResponseContext __RPC_FAR * This,
    /* [out] */ DWORD __RPC_FAR *pdwResponseStatus);


void __RPC_STUB ISmtpServerResponseContext_QueryResponseStatus_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


HRESULT STDMETHODCALLTYPE ISmtpServerResponseContext_QueryPipelinedFlag_Proxy( 
    ISmtpServerResponseContext __RPC_FAR * This,
    /* [out] */ BOOL __RPC_FAR *pfResponseIsPipelined);


void __RPC_STUB ISmtpServerResponseContext_QueryPipelinedFlag_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


HRESULT STDMETHODCALLTYPE ISmtpServerResponseContext_QueryNextEventState_Proxy( 
    ISmtpServerResponseContext __RPC_FAR * This,
    /* [out] */ DWORD __RPC_FAR *pdwNextState);


void __RPC_STUB ISmtpServerResponseContext_QueryNextEventState_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


HRESULT STDMETHODCALLTYPE ISmtpServerResponseContext_SetResponseStatus_Proxy( 
    ISmtpServerResponseContext __RPC_FAR * This,
    /* [in] */ DWORD dwResponseStatus);


void __RPC_STUB ISmtpServerResponseContext_SetResponseStatus_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


HRESULT STDMETHODCALLTYPE ISmtpServerResponseContext_SetNextEventState_Proxy( 
    ISmtpServerResponseContext __RPC_FAR * This,
    /* [in] */ DWORD dwNextState);


void __RPC_STUB ISmtpServerResponseContext_SetNextEventState_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


HRESULT STDMETHODCALLTYPE ISmtpServerResponseContext_NotifyAsyncCompletion_Proxy( 
    ISmtpServerResponseContext __RPC_FAR * This,
    /* [in] */ HRESULT hrResult);


void __RPC_STUB ISmtpServerResponseContext_NotifyAsyncCompletion_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);



#endif 	/* __ISmtpServerResponseContext_INTERFACE_DEFINED__ */


#ifndef __ISmtpInCommandSink_INTERFACE_DEFINED__
#define __ISmtpInCommandSink_INTERFACE_DEFINED__

/* interface ISmtpInCommandSink */
/* [unique][helpstring][uuid][object] */ 


EXTERN_C const IID IID_ISmtpInCommandSink;

#if defined(__cplusplus) && !defined(CINTERFACE)
    
    MIDL_INTERFACE("b2d42a0e-0d5f-11d2-aa68-00c04fa35b82")
    ISmtpInCommandSink : public IUnknown
    {
    public:
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE OnSmtpInCommand( 
            /* [in] */ IUnknown __RPC_FAR *pServer,
            /* [in] */ IUnknown __RPC_FAR *pSession,
            /* [in] */ IMailMsgProperties __RPC_FAR *pMsg,
            /* [in] */ ISmtpInCommandContext __RPC_FAR *pContext) = 0;
        
    };
    
#else 	/* C style interface */

    typedef struct ISmtpInCommandSinkVtbl
    {
        BEGIN_INTERFACE
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *QueryInterface )( 
            ISmtpInCommandSink __RPC_FAR * This,
            /* [in] */ REFIID riid,
            /* [iid_is][out] */ void __RPC_FAR *__RPC_FAR *ppvObject);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *AddRef )( 
            ISmtpInCommandSink __RPC_FAR * This);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *Release )( 
            ISmtpInCommandSink __RPC_FAR * This);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *OnSmtpInCommand )( 
            ISmtpInCommandSink __RPC_FAR * This,
            /* [in] */ IUnknown __RPC_FAR *pServer,
            /* [in] */ IUnknown __RPC_FAR *pSession,
            /* [in] */ IMailMsgProperties __RPC_FAR *pMsg,
            /* [in] */ ISmtpInCommandContext __RPC_FAR *pContext);
        
        END_INTERFACE
    } ISmtpInCommandSinkVtbl;

    interface ISmtpInCommandSink
    {
        CONST_VTBL struct ISmtpInCommandSinkVtbl __RPC_FAR *lpVtbl;
    };

    

#ifdef COBJMACROS


#define ISmtpInCommandSink_QueryInterface(This,riid,ppvObject)	\
    (This)->lpVtbl -> QueryInterface(This,riid,ppvObject)

#define ISmtpInCommandSink_AddRef(This)	\
    (This)->lpVtbl -> AddRef(This)

#define ISmtpInCommandSink_Release(This)	\
    (This)->lpVtbl -> Release(This)


#define ISmtpInCommandSink_OnSmtpInCommand(This,pServer,pSession,pMsg,pContext)	\
    (This)->lpVtbl -> OnSmtpInCommand(This,pServer,pSession,pMsg,pContext)

#endif /* COBJMACROS */


#endif 	/* C style interface */



/* [helpstring] */ HRESULT STDMETHODCALLTYPE ISmtpInCommandSink_OnSmtpInCommand_Proxy( 
    ISmtpInCommandSink __RPC_FAR * This,
    /* [in] */ IUnknown __RPC_FAR *pServer,
    /* [in] */ IUnknown __RPC_FAR *pSession,
    /* [in] */ IMailMsgProperties __RPC_FAR *pMsg,
    /* [in] */ ISmtpInCommandContext __RPC_FAR *pContext);


void __RPC_STUB ISmtpInCommandSink_OnSmtpInCommand_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);



#endif 	/* __ISmtpInCommandSink_INTERFACE_DEFINED__ */


#ifndef __ISmtpOutCommandSink_INTERFACE_DEFINED__
#define __ISmtpOutCommandSink_INTERFACE_DEFINED__

/* interface ISmtpOutCommandSink */
/* [unique][helpstring][uuid][object] */ 


EXTERN_C const IID IID_ISmtpOutCommandSink;

#if defined(__cplusplus) && !defined(CINTERFACE)
    
    MIDL_INTERFACE("cfdbb9b0-0ca0-11d2-aa68-00c04fa35b82")
    ISmtpOutCommandSink : public IUnknown
    {
    public:
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE OnSmtpOutCommand( 
            /* [in] */ IUnknown __RPC_FAR *pServer,
            /* [in] */ IUnknown __RPC_FAR *pSession,
            /* [in] */ IMailMsgProperties __RPC_FAR *pMsg,
            /* [in] */ ISmtpOutCommandContext __RPC_FAR *pContext) = 0;
        
    };
    
#else 	/* C style interface */

    typedef struct ISmtpOutCommandSinkVtbl
    {
        BEGIN_INTERFACE
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *QueryInterface )( 
            ISmtpOutCommandSink __RPC_FAR * This,
            /* [in] */ REFIID riid,
            /* [iid_is][out] */ void __RPC_FAR *__RPC_FAR *ppvObject);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *AddRef )( 
            ISmtpOutCommandSink __RPC_FAR * This);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *Release )( 
            ISmtpOutCommandSink __RPC_FAR * This);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *OnSmtpOutCommand )( 
            ISmtpOutCommandSink __RPC_FAR * This,
            /* [in] */ IUnknown __RPC_FAR *pServer,
            /* [in] */ IUnknown __RPC_FAR *pSession,
            /* [in] */ IMailMsgProperties __RPC_FAR *pMsg,
            /* [in] */ ISmtpOutCommandContext __RPC_FAR *pContext);
        
        END_INTERFACE
    } ISmtpOutCommandSinkVtbl;

    interface ISmtpOutCommandSink
    {
        CONST_VTBL struct ISmtpOutCommandSinkVtbl __RPC_FAR *lpVtbl;
    };

    

#ifdef COBJMACROS


#define ISmtpOutCommandSink_QueryInterface(This,riid,ppvObject)	\
    (This)->lpVtbl -> QueryInterface(This,riid,ppvObject)

#define ISmtpOutCommandSink_AddRef(This)	\
    (This)->lpVtbl -> AddRef(This)

#define ISmtpOutCommandSink_Release(This)	\
    (This)->lpVtbl -> Release(This)


#define ISmtpOutCommandSink_OnSmtpOutCommand(This,pServer,pSession,pMsg,pContext)	\
    (This)->lpVtbl -> OnSmtpOutCommand(This,pServer,pSession,pMsg,pContext)

#endif /* COBJMACROS */


#endif 	/* C style interface */



/* [helpstring] */ HRESULT STDMETHODCALLTYPE ISmtpOutCommandSink_OnSmtpOutCommand_Proxy( 
    ISmtpOutCommandSink __RPC_FAR * This,
    /* [in] */ IUnknown __RPC_FAR *pServer,
    /* [in] */ IUnknown __RPC_FAR *pSession,
    /* [in] */ IMailMsgProperties __RPC_FAR *pMsg,
    /* [in] */ ISmtpOutCommandContext __RPC_FAR *pContext);


void __RPC_STUB ISmtpOutCommandSink_OnSmtpOutCommand_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);



#endif 	/* __ISmtpOutCommandSink_INTERFACE_DEFINED__ */


#ifndef __ISmtpServerResponseSink_INTERFACE_DEFINED__
#define __ISmtpServerResponseSink_INTERFACE_DEFINED__

/* interface ISmtpServerResponseSink */
/* [unique][helpstring][uuid][object] */ 


EXTERN_C const IID IID_ISmtpServerResponseSink;

#if defined(__cplusplus) && !defined(CINTERFACE)
    
    MIDL_INTERFACE("d7e10222-0ca1-11d2-aa68-00c04fa35b82")
    ISmtpServerResponseSink : public IUnknown
    {
    public:
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE OnSmtpServerResponse( 
            /* [in] */ IUnknown __RPC_FAR *pServer,
            /* [in] */ IUnknown __RPC_FAR *pSession,
            /* [in] */ IMailMsgProperties __RPC_FAR *pMsg,
            /* [in] */ ISmtpServerResponseContext __RPC_FAR *pContext) = 0;
        
    };
    
#else 	/* C style interface */

    typedef struct ISmtpServerResponseSinkVtbl
    {
        BEGIN_INTERFACE
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *QueryInterface )( 
            ISmtpServerResponseSink __RPC_FAR * This,
            /* [in] */ REFIID riid,
            /* [iid_is][out] */ void __RPC_FAR *__RPC_FAR *ppvObject);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *AddRef )( 
            ISmtpServerResponseSink __RPC_FAR * This);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *Release )( 
            ISmtpServerResponseSink __RPC_FAR * This);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *OnSmtpServerResponse )( 
            ISmtpServerResponseSink __RPC_FAR * This,
            /* [in] */ IUnknown __RPC_FAR *pServer,
            /* [in] */ IUnknown __RPC_FAR *pSession,
            /* [in] */ IMailMsgProperties __RPC_FAR *pMsg,
            /* [in] */ ISmtpServerResponseContext __RPC_FAR *pContext);
        
        END_INTERFACE
    } ISmtpServerResponseSinkVtbl;

    interface ISmtpServerResponseSink
    {
        CONST_VTBL struct ISmtpServerResponseSinkVtbl __RPC_FAR *lpVtbl;
    };

    

#ifdef COBJMACROS


#define ISmtpServerResponseSink_QueryInterface(This,riid,ppvObject)	\
    (This)->lpVtbl -> QueryInterface(This,riid,ppvObject)

#define ISmtpServerResponseSink_AddRef(This)	\
    (This)->lpVtbl -> AddRef(This)

#define ISmtpServerResponseSink_Release(This)	\
    (This)->lpVtbl -> Release(This)


#define ISmtpServerResponseSink_OnSmtpServerResponse(This,pServer,pSession,pMsg,pContext)	\
    (This)->lpVtbl -> OnSmtpServerResponse(This,pServer,pSession,pMsg,pContext)

#endif /* COBJMACROS */


#endif 	/* C style interface */



/* [helpstring] */ HRESULT STDMETHODCALLTYPE ISmtpServerResponseSink_OnSmtpServerResponse_Proxy( 
    ISmtpServerResponseSink __RPC_FAR * This,
    /* [in] */ IUnknown __RPC_FAR *pServer,
    /* [in] */ IUnknown __RPC_FAR *pSession,
    /* [in] */ IMailMsgProperties __RPC_FAR *pMsg,
    /* [in] */ ISmtpServerResponseContext __RPC_FAR *pContext);


void __RPC_STUB ISmtpServerResponseSink_OnSmtpServerResponse_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);



#endif 	/* __ISmtpServerResponseSink_INTERFACE_DEFINED__ */


#ifndef __ISmtpInCallbackSink_INTERFACE_DEFINED__
#define __ISmtpInCallbackSink_INTERFACE_DEFINED__

/* interface ISmtpInCallbackSink */
/* [unique][helpstring][uuid][object] */ 


EXTERN_C const IID IID_ISmtpInCallbackSink;

#if defined(__cplusplus) && !defined(CINTERFACE)
    
    MIDL_INTERFACE("0012b624-3e3c-11d3-88f1-00c04fa35b86")
    ISmtpInCallbackSink : public IUnknown
    {
    public:
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE OnSmtpInCallback( 
            /* [in] */ IUnknown __RPC_FAR *pServer,
            /* [in] */ IUnknown __RPC_FAR *pSession,
            /* [in] */ IMailMsgProperties __RPC_FAR *pMsg,
            /* [in] */ ISmtpInCallbackContext __RPC_FAR *pContext) = 0;
        
    };
    
#else 	/* C style interface */

    typedef struct ISmtpInCallbackSinkVtbl
    {
        BEGIN_INTERFACE
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *QueryInterface )( 
            ISmtpInCallbackSink __RPC_FAR * This,
            /* [in] */ REFIID riid,
            /* [iid_is][out] */ void __RPC_FAR *__RPC_FAR *ppvObject);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *AddRef )( 
            ISmtpInCallbackSink __RPC_FAR * This);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *Release )( 
            ISmtpInCallbackSink __RPC_FAR * This);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *OnSmtpInCallback )( 
            ISmtpInCallbackSink __RPC_FAR * This,
            /* [in] */ IUnknown __RPC_FAR *pServer,
            /* [in] */ IUnknown __RPC_FAR *pSession,
            /* [in] */ IMailMsgProperties __RPC_FAR *pMsg,
            /* [in] */ ISmtpInCallbackContext __RPC_FAR *pContext);
        
        END_INTERFACE
    } ISmtpInCallbackSinkVtbl;

    interface ISmtpInCallbackSink
    {
        CONST_VTBL struct ISmtpInCallbackSinkVtbl __RPC_FAR *lpVtbl;
    };

    

#ifdef COBJMACROS


#define ISmtpInCallbackSink_QueryInterface(This,riid,ppvObject)	\
    (This)->lpVtbl -> QueryInterface(This,riid,ppvObject)

#define ISmtpInCallbackSink_AddRef(This)	\
    (This)->lpVtbl -> AddRef(This)

#define ISmtpInCallbackSink_Release(This)	\
    (This)->lpVtbl -> Release(This)


#define ISmtpInCallbackSink_OnSmtpInCallback(This,pServer,pSession,pMsg,pContext)	\
    (This)->lpVtbl -> OnSmtpInCallback(This,pServer,pSession,pMsg,pContext)

#endif /* COBJMACROS */


#endif 	/* C style interface */



/* [helpstring] */ HRESULT STDMETHODCALLTYPE ISmtpInCallbackSink_OnSmtpInCallback_Proxy( 
    ISmtpInCallbackSink __RPC_FAR * This,
    /* [in] */ IUnknown __RPC_FAR *pServer,
    /* [in] */ IUnknown __RPC_FAR *pSession,
    /* [in] */ IMailMsgProperties __RPC_FAR *pMsg,
    /* [in] */ ISmtpInCallbackContext __RPC_FAR *pContext);


void __RPC_STUB ISmtpInCallbackSink_OnSmtpInCallback_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);



#endif 	/* __ISmtpInCallbackSink_INTERFACE_DEFINED__ */


/* interface __MIDL_itf_SmtpEvent_0274 */
/* [local] */ 

#define SMTP_TRANSPORT_DEFAULT_PRIORITY 16384


extern RPC_IF_HANDLE __MIDL_itf_SmtpEvent_0274_v0_0_c_ifspec;
extern RPC_IF_HANDLE __MIDL_itf_SmtpEvent_0274_v0_0_s_ifspec;

#ifndef __IMailTransportNotify_INTERFACE_DEFINED__
#define __IMailTransportNotify_INTERFACE_DEFINED__

/* interface IMailTransportNotify */
/* [unique][helpstring][uuid][object] */ 


EXTERN_C const IID IID_IMailTransportNotify;

#if defined(__cplusplus) && !defined(CINTERFACE)
    
    MIDL_INTERFACE("6E1CAA77-FCD4-11d1-9DF9-00C04FA322BA")
    IMailTransportNotify : public IUnknown
    {
    public:
        virtual /* [local] */ HRESULT STDMETHODCALLTYPE Notify( 
            /* [in] */ HRESULT hrCompletion,
            /* [in] */ PVOID pvContext) = 0;
        
    };
    
#else 	/* C style interface */

    typedef struct IMailTransportNotifyVtbl
    {
        BEGIN_INTERFACE
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *QueryInterface )( 
            IMailTransportNotify __RPC_FAR * This,
            /* [in] */ REFIID riid,
            /* [iid_is][out] */ void __RPC_FAR *__RPC_FAR *ppvObject);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *AddRef )( 
            IMailTransportNotify __RPC_FAR * This);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *Release )( 
            IMailTransportNotify __RPC_FAR * This);
        
        /* [local] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *Notify )( 
            IMailTransportNotify __RPC_FAR * This,
            /* [in] */ HRESULT hrCompletion,
            /* [in] */ PVOID pvContext);
        
        END_INTERFACE
    } IMailTransportNotifyVtbl;

    interface IMailTransportNotify
    {
        CONST_VTBL struct IMailTransportNotifyVtbl __RPC_FAR *lpVtbl;
    };

    

#ifdef COBJMACROS


#define IMailTransportNotify_QueryInterface(This,riid,ppvObject)	\
    (This)->lpVtbl -> QueryInterface(This,riid,ppvObject)

#define IMailTransportNotify_AddRef(This)	\
    (This)->lpVtbl -> AddRef(This)

#define IMailTransportNotify_Release(This)	\
    (This)->lpVtbl -> Release(This)


#define IMailTransportNotify_Notify(This,hrCompletion,pvContext)	\
    (This)->lpVtbl -> Notify(This,hrCompletion,pvContext)

#endif /* COBJMACROS */


#endif 	/* C style interface */



/* [local] */ HRESULT STDMETHODCALLTYPE IMailTransportNotify_Notify_Proxy( 
    IMailTransportNotify __RPC_FAR * This,
    /* [in] */ HRESULT hrCompletion,
    /* [in] */ PVOID pvContext);


void __RPC_STUB IMailTransportNotify_Notify_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);



#endif 	/* __IMailTransportNotify_INTERFACE_DEFINED__ */


#ifndef __IMailTransportSubmission_INTERFACE_DEFINED__
#define __IMailTransportSubmission_INTERFACE_DEFINED__

/* interface IMailTransportSubmission */
/* [unique][helpstring][uuid][object] */ 


EXTERN_C const IID IID_IMailTransportSubmission;

#if defined(__cplusplus) && !defined(CINTERFACE)
    
    MIDL_INTERFACE("CE681916-FF14-11d1-9DFB-00C04FA322BA")
    IMailTransportSubmission : public IUnknown
    {
    public:
        virtual /* [local] */ HRESULT STDMETHODCALLTYPE OnMessageSubmission( 
            /* [in] */ IMailMsgProperties __RPC_FAR *pIMailMsg,
            /* [in] */ IMailTransportNotify __RPC_FAR *pINotify,
            /* [in] */ PVOID pvNotifyContext) = 0;
        
    };
    
#else 	/* C style interface */

    typedef struct IMailTransportSubmissionVtbl
    {
        BEGIN_INTERFACE
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *QueryInterface )( 
            IMailTransportSubmission __RPC_FAR * This,
            /* [in] */ REFIID riid,
            /* [iid_is][out] */ void __RPC_FAR *__RPC_FAR *ppvObject);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *AddRef )( 
            IMailTransportSubmission __RPC_FAR * This);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *Release )( 
            IMailTransportSubmission __RPC_FAR * This);
        
        /* [local] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *OnMessageSubmission )( 
            IMailTransportSubmission __RPC_FAR * This,
            /* [in] */ IMailMsgProperties __RPC_FAR *pIMailMsg,
            /* [in] */ IMailTransportNotify __RPC_FAR *pINotify,
            /* [in] */ PVOID pvNotifyContext);
        
        END_INTERFACE
    } IMailTransportSubmissionVtbl;

    interface IMailTransportSubmission
    {
        CONST_VTBL struct IMailTransportSubmissionVtbl __RPC_FAR *lpVtbl;
    };

    

#ifdef COBJMACROS


#define IMailTransportSubmission_QueryInterface(This,riid,ppvObject)	\
    (This)->lpVtbl -> QueryInterface(This,riid,ppvObject)

#define IMailTransportSubmission_AddRef(This)	\
    (This)->lpVtbl -> AddRef(This)

#define IMailTransportSubmission_Release(This)	\
    (This)->lpVtbl -> Release(This)


#define IMailTransportSubmission_OnMessageSubmission(This,pIMailMsg,pINotify,pvNotifyContext)	\
    (This)->lpVtbl -> OnMessageSubmission(This,pIMailMsg,pINotify,pvNotifyContext)

#endif /* COBJMACROS */


#endif 	/* C style interface */



/* [local] */ HRESULT STDMETHODCALLTYPE IMailTransportSubmission_OnMessageSubmission_Proxy( 
    IMailTransportSubmission __RPC_FAR * This,
    /* [in] */ IMailMsgProperties __RPC_FAR *pIMailMsg,
    /* [in] */ IMailTransportNotify __RPC_FAR *pINotify,
    /* [in] */ PVOID pvNotifyContext);


void __RPC_STUB IMailTransportSubmission_OnMessageSubmission_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);



#endif 	/* __IMailTransportSubmission_INTERFACE_DEFINED__ */


#ifndef __IMailTransportOnPreCategorize_INTERFACE_DEFINED__
#define __IMailTransportOnPreCategorize_INTERFACE_DEFINED__

/* interface IMailTransportOnPreCategorize */
/* [unique][helpstring][uuid][object] */ 


EXTERN_C const IID IID_IMailTransportOnPreCategorize;

#if defined(__cplusplus) && !defined(CINTERFACE)
    
    MIDL_INTERFACE("A3ACFB0E-83FF-11d2-9E14-00C04FA322BA")
    IMailTransportOnPreCategorize : public IUnknown
    {
    public:
        virtual /* [local] */ HRESULT STDMETHODCALLTYPE OnSyncMessagePreCategorize( 
            /* [in] */ IMailMsgProperties __RPC_FAR *pIMailMsg,
            /* [in] */ IMailTransportNotify __RPC_FAR *pINotify,
            /* [in] */ PVOID pvNotifyContext) = 0;
        
    };
    
#else 	/* C style interface */

    typedef struct IMailTransportOnPreCategorizeVtbl
    {
        BEGIN_INTERFACE
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *QueryInterface )( 
            IMailTransportOnPreCategorize __RPC_FAR * This,
            /* [in] */ REFIID riid,
            /* [iid_is][out] */ void __RPC_FAR *__RPC_FAR *ppvObject);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *AddRef )( 
            IMailTransportOnPreCategorize __RPC_FAR * This);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *Release )( 
            IMailTransportOnPreCategorize __RPC_FAR * This);
        
        /* [local] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *OnSyncMessagePreCategorize )( 
            IMailTransportOnPreCategorize __RPC_FAR * This,
            /* [in] */ IMailMsgProperties __RPC_FAR *pIMailMsg,
            /* [in] */ IMailTransportNotify __RPC_FAR *pINotify,
            /* [in] */ PVOID pvNotifyContext);
        
        END_INTERFACE
    } IMailTransportOnPreCategorizeVtbl;

    interface IMailTransportOnPreCategorize
    {
        CONST_VTBL struct IMailTransportOnPreCategorizeVtbl __RPC_FAR *lpVtbl;
    };

    

#ifdef COBJMACROS


#define IMailTransportOnPreCategorize_QueryInterface(This,riid,ppvObject)	\
    (This)->lpVtbl -> QueryInterface(This,riid,ppvObject)

#define IMailTransportOnPreCategorize_AddRef(This)	\
    (This)->lpVtbl -> AddRef(This)

#define IMailTransportOnPreCategorize_Release(This)	\
    (This)->lpVtbl -> Release(This)


#define IMailTransportOnPreCategorize_OnSyncMessagePreCategorize(This,pIMailMsg,pINotify,pvNotifyContext)	\
    (This)->lpVtbl -> OnSyncMessagePreCategorize(This,pIMailMsg,pINotify,pvNotifyContext)

#endif /* COBJMACROS */


#endif 	/* C style interface */



/* [local] */ HRESULT STDMETHODCALLTYPE IMailTransportOnPreCategorize_OnSyncMessagePreCategorize_Proxy( 
    IMailTransportOnPreCategorize __RPC_FAR * This,
    /* [in] */ IMailMsgProperties __RPC_FAR *pIMailMsg,
    /* [in] */ IMailTransportNotify __RPC_FAR *pINotify,
    /* [in] */ PVOID pvNotifyContext);


void __RPC_STUB IMailTransportOnPreCategorize_OnSyncMessagePreCategorize_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);



#endif 	/* __IMailTransportOnPreCategorize_INTERFACE_DEFINED__ */


#ifndef __IMailTransportOnPostCategorize_INTERFACE_DEFINED__
#define __IMailTransportOnPostCategorize_INTERFACE_DEFINED__

/* interface IMailTransportOnPostCategorize */
/* [unique][helpstring][uuid][object] */ 


EXTERN_C const IID IID_IMailTransportOnPostCategorize;

#if defined(__cplusplus) && !defined(CINTERFACE)
    
    MIDL_INTERFACE("76719653-05A6-11d2-9DFD-00C04FA322BA")
    IMailTransportOnPostCategorize : public IUnknown
    {
    public:
        virtual /* [local] */ HRESULT STDMETHODCALLTYPE OnMessagePostCategorize( 
            /* [in] */ IMailMsgProperties __RPC_FAR *pIMailMsg,
            /* [in] */ IMailTransportNotify __RPC_FAR *pINotify,
            /* [in] */ PVOID pvNotifyContext) = 0;
        
    };
    
#else 	/* C style interface */

    typedef struct IMailTransportOnPostCategorizeVtbl
    {
        BEGIN_INTERFACE
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *QueryInterface )( 
            IMailTransportOnPostCategorize __RPC_FAR * This,
            /* [in] */ REFIID riid,
            /* [iid_is][out] */ void __RPC_FAR *__RPC_FAR *ppvObject);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *AddRef )( 
            IMailTransportOnPostCategorize __RPC_FAR * This);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *Release )( 
            IMailTransportOnPostCategorize __RPC_FAR * This);
        
        /* [local] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *OnMessagePostCategorize )( 
            IMailTransportOnPostCategorize __RPC_FAR * This,
            /* [in] */ IMailMsgProperties __RPC_FAR *pIMailMsg,
            /* [in] */ IMailTransportNotify __RPC_FAR *pINotify,
            /* [in] */ PVOID pvNotifyContext);
        
        END_INTERFACE
    } IMailTransportOnPostCategorizeVtbl;

    interface IMailTransportOnPostCategorize
    {
        CONST_VTBL struct IMailTransportOnPostCategorizeVtbl __RPC_FAR *lpVtbl;
    };

    

#ifdef COBJMACROS


#define IMailTransportOnPostCategorize_QueryInterface(This,riid,ppvObject)	\
    (This)->lpVtbl -> QueryInterface(This,riid,ppvObject)

#define IMailTransportOnPostCategorize_AddRef(This)	\
    (This)->lpVtbl -> AddRef(This)

#define IMailTransportOnPostCategorize_Release(This)	\
    (This)->lpVtbl -> Release(This)


#define IMailTransportOnPostCategorize_OnMessagePostCategorize(This,pIMailMsg,pINotify,pvNotifyContext)	\
    (This)->lpVtbl -> OnMessagePostCategorize(This,pIMailMsg,pINotify,pvNotifyContext)

#endif /* COBJMACROS */


#endif 	/* C style interface */



/* [local] */ HRESULT STDMETHODCALLTYPE IMailTransportOnPostCategorize_OnMessagePostCategorize_Proxy( 
    IMailTransportOnPostCategorize __RPC_FAR * This,
    /* [in] */ IMailMsgProperties __RPC_FAR *pIMailMsg,
    /* [in] */ IMailTransportNotify __RPC_FAR *pINotify,
    /* [in] */ PVOID pvNotifyContext);


void __RPC_STUB IMailTransportOnPostCategorize_OnMessagePostCategorize_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);



#endif 	/* __IMailTransportOnPostCategorize_INTERFACE_DEFINED__ */


/* interface __MIDL_itf_SmtpEvent_0278 */
/* [local] */ 

#define RESET_NEXT_HOPS         0
#define RESET_MESSAGE_TYPES     1


extern RPC_IF_HANDLE __MIDL_itf_SmtpEvent_0278_v0_0_c_ifspec;
extern RPC_IF_HANDLE __MIDL_itf_SmtpEvent_0278_v0_0_s_ifspec;

#ifndef __IMailTransportRouterReset_INTERFACE_DEFINED__
#define __IMailTransportRouterReset_INTERFACE_DEFINED__

/* interface IMailTransportRouterReset */
/* [unique][helpstring][uuid][object] */ 


EXTERN_C const IID IID_IMailTransportRouterReset;

#if defined(__cplusplus) && !defined(CINTERFACE)
    
    MIDL_INTERFACE("A928AD12-1610-11d2-9E02-00C04FA322BA")
    IMailTransportRouterReset : public IUnknown
    {
    public:
        virtual HRESULT STDMETHODCALLTYPE ResetRoutes( 
            /* [in] */ DWORD dwResetType) = 0;
        
    };
    
#else 	/* C style interface */

    typedef struct IMailTransportRouterResetVtbl
    {
        BEGIN_INTERFACE
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *QueryInterface )( 
            IMailTransportRouterReset __RPC_FAR * This,
            /* [in] */ REFIID riid,
            /* [iid_is][out] */ void __RPC_FAR *__RPC_FAR *ppvObject);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *AddRef )( 
            IMailTransportRouterReset __RPC_FAR * This);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *Release )( 
            IMailTransportRouterReset __RPC_FAR * This);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *ResetRoutes )( 
            IMailTransportRouterReset __RPC_FAR * This,
            /* [in] */ DWORD dwResetType);
        
        END_INTERFACE
    } IMailTransportRouterResetVtbl;

    interface IMailTransportRouterReset
    {
        CONST_VTBL struct IMailTransportRouterResetVtbl __RPC_FAR *lpVtbl;
    };

    

#ifdef COBJMACROS


#define IMailTransportRouterReset_QueryInterface(This,riid,ppvObject)	\
    (This)->lpVtbl -> QueryInterface(This,riid,ppvObject)

#define IMailTransportRouterReset_AddRef(This)	\
    (This)->lpVtbl -> AddRef(This)

#define IMailTransportRouterReset_Release(This)	\
    (This)->lpVtbl -> Release(This)


#define IMailTransportRouterReset_ResetRoutes(This,dwResetType)	\
    (This)->lpVtbl -> ResetRoutes(This,dwResetType)

#endif /* COBJMACROS */


#endif 	/* C style interface */



HRESULT STDMETHODCALLTYPE IMailTransportRouterReset_ResetRoutes_Proxy( 
    IMailTransportRouterReset __RPC_FAR * This,
    /* [in] */ DWORD dwResetType);


void __RPC_STUB IMailTransportRouterReset_ResetRoutes_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);



#endif 	/* __IMailTransportRouterReset_INTERFACE_DEFINED__ */


#ifndef __IMailTransportSetRouterReset_INTERFACE_DEFINED__
#define __IMailTransportSetRouterReset_INTERFACE_DEFINED__

/* interface IMailTransportSetRouterReset */
/* [unique][helpstring][uuid][object] */ 


EXTERN_C const IID IID_IMailTransportSetRouterReset;

#if defined(__cplusplus) && !defined(CINTERFACE)
    
    MIDL_INTERFACE("A928AD11-1610-11d2-9E02-00C04FA322BA")
    IMailTransportSetRouterReset : public IUnknown
    {
    public:
        virtual HRESULT STDMETHODCALLTYPE RegisterResetInterface( 
            /* [in] */ DWORD dwVirtualServerID,
            /* [in] */ IMailTransportRouterReset __RPC_FAR *pIRouterReset) = 0;
        
    };
    
#else 	/* C style interface */

    typedef struct IMailTransportSetRouterResetVtbl
    {
        BEGIN_INTERFACE
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *QueryInterface )( 
            IMailTransportSetRouterReset __RPC_FAR * This,
            /* [in] */ REFIID riid,
            /* [iid_is][out] */ void __RPC_FAR *__RPC_FAR *ppvObject);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *AddRef )( 
            IMailTransportSetRouterReset __RPC_FAR * This);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *Release )( 
            IMailTransportSetRouterReset __RPC_FAR * This);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *RegisterResetInterface )( 
            IMailTransportSetRouterReset __RPC_FAR * This,
            /* [in] */ DWORD dwVirtualServerID,
            /* [in] */ IMailTransportRouterReset __RPC_FAR *pIRouterReset);
        
        END_INTERFACE
    } IMailTransportSetRouterResetVtbl;

    interface IMailTransportSetRouterReset
    {
        CONST_VTBL struct IMailTransportSetRouterResetVtbl __RPC_FAR *lpVtbl;
    };

    

#ifdef COBJMACROS


#define IMailTransportSetRouterReset_QueryInterface(This,riid,ppvObject)	\
    (This)->lpVtbl -> QueryInterface(This,riid,ppvObject)

#define IMailTransportSetRouterReset_AddRef(This)	\
    (This)->lpVtbl -> AddRef(This)

#define IMailTransportSetRouterReset_Release(This)	\
    (This)->lpVtbl -> Release(This)


#define IMailTransportSetRouterReset_RegisterResetInterface(This,dwVirtualServerID,pIRouterReset)	\
    (This)->lpVtbl -> RegisterResetInterface(This,dwVirtualServerID,pIRouterReset)

#endif /* COBJMACROS */


#endif 	/* C style interface */



HRESULT STDMETHODCALLTYPE IMailTransportSetRouterReset_RegisterResetInterface_Proxy( 
    IMailTransportSetRouterReset __RPC_FAR * This,
    /* [in] */ DWORD dwVirtualServerID,
    /* [in] */ IMailTransportRouterReset __RPC_FAR *pIRouterReset);


void __RPC_STUB IMailTransportSetRouterReset_RegisterResetInterface_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);



#endif 	/* __IMailTransportSetRouterReset_INTERFACE_DEFINED__ */


#ifndef __IMessageRouter_INTERFACE_DEFINED__
#define __IMessageRouter_INTERFACE_DEFINED__

/* interface IMessageRouter */
/* [unique][helpstring][uuid][object] */ 


EXTERN_C const IID IID_IMessageRouter;

#if defined(__cplusplus) && !defined(CINTERFACE)
    
    MIDL_INTERFACE("A928AD14-1610-11d2-9E02-00C04FA322BA")
    IMessageRouter : public IUnknown
    {
    public:
        virtual /* [local] */ GUID STDMETHODCALLTYPE GetTransportSinkID( void) = 0;
        
        virtual HRESULT STDMETHODCALLTYPE GetMessageType( 
            /* [in] */ IMailMsgProperties __RPC_FAR *pIMailMsg,
            /* [out] */ DWORD __RPC_FAR *pdwMessageType) = 0;
        
        virtual HRESULT STDMETHODCALLTYPE ReleaseMessageType( 
            /* [in] */ DWORD dwMessageType,
            /* [in] */ DWORD dwReleaseCount) = 0;
        
        virtual /* [local] */ HRESULT STDMETHODCALLTYPE GetNextHop( 
            /* [in] */ LPSTR pszDestinationAddressType,
            /* [in] */ LPSTR pszDestinationAddress,
            /* [in] */ DWORD dwMessageType,
            /* [out] */ LPSTR __RPC_FAR *ppszRouteAddressType,
            /* [out] */ LPSTR __RPC_FAR *ppszRouteAddress,
            /* [out] */ DWORD __RPC_FAR *pdwScheduleID,
            /* [out] */ LPSTR __RPC_FAR *ppszRouteAddressClass,
            /* [out] */ LPSTR __RPC_FAR *ppszConnectorName,
            /* [out] */ DWORD __RPC_FAR *pdwNextHopType) = 0;
        
        virtual /* [local] */ HRESULT STDMETHODCALLTYPE GetNextHopFree( 
            /* [in] */ LPSTR pszDestinationAddressType,
            /* [in] */ LPSTR pszDestinationAddress,
            /* [in] */ LPSTR pszConnectorName,
            /* [in] */ LPSTR pszRouteAddressType,
            /* [in] */ LPSTR pszRouteAddress,
            /* [in] */ LPSTR pszRouteAddressClass) = 0;
        
        virtual HRESULT STDMETHODCALLTYPE ConnectionFailed( 
            /* [string][in] */ LPSTR pszConnectorName) = 0;
        
    };
    
#else 	/* C style interface */

    typedef struct IMessageRouterVtbl
    {
        BEGIN_INTERFACE
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *QueryInterface )( 
            IMessageRouter __RPC_FAR * This,
            /* [in] */ REFIID riid,
            /* [iid_is][out] */ void __RPC_FAR *__RPC_FAR *ppvObject);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *AddRef )( 
            IMessageRouter __RPC_FAR * This);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *Release )( 
            IMessageRouter __RPC_FAR * This);
        
        /* [local] */ GUID ( STDMETHODCALLTYPE __RPC_FAR *GetTransportSinkID )( 
            IMessageRouter __RPC_FAR * This);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetMessageType )( 
            IMessageRouter __RPC_FAR * This,
            /* [in] */ IMailMsgProperties __RPC_FAR *pIMailMsg,
            /* [out] */ DWORD __RPC_FAR *pdwMessageType);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *ReleaseMessageType )( 
            IMessageRouter __RPC_FAR * This,
            /* [in] */ DWORD dwMessageType,
            /* [in] */ DWORD dwReleaseCount);
        
        /* [local] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetNextHop )( 
            IMessageRouter __RPC_FAR * This,
            /* [in] */ LPSTR pszDestinationAddressType,
            /* [in] */ LPSTR pszDestinationAddress,
            /* [in] */ DWORD dwMessageType,
            /* [out] */ LPSTR __RPC_FAR *ppszRouteAddressType,
            /* [out] */ LPSTR __RPC_FAR *ppszRouteAddress,
            /* [out] */ DWORD __RPC_FAR *pdwScheduleID,
            /* [out] */ LPSTR __RPC_FAR *ppszRouteAddressClass,
            /* [out] */ LPSTR __RPC_FAR *ppszConnectorName,
            /* [out] */ DWORD __RPC_FAR *pdwNextHopType);
        
        /* [local] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetNextHopFree )( 
            IMessageRouter __RPC_FAR * This,
            /* [in] */ LPSTR pszDestinationAddressType,
            /* [in] */ LPSTR pszDestinationAddress,
            /* [in] */ LPSTR pszConnectorName,
            /* [in] */ LPSTR pszRouteAddressType,
            /* [in] */ LPSTR pszRouteAddress,
            /* [in] */ LPSTR pszRouteAddressClass);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *ConnectionFailed )( 
            IMessageRouter __RPC_FAR * This,
            /* [string][in] */ LPSTR pszConnectorName);
        
        END_INTERFACE
    } IMessageRouterVtbl;

    interface IMessageRouter
    {
        CONST_VTBL struct IMessageRouterVtbl __RPC_FAR *lpVtbl;
    };

    

#ifdef COBJMACROS


#define IMessageRouter_QueryInterface(This,riid,ppvObject)	\
    (This)->lpVtbl -> QueryInterface(This,riid,ppvObject)

#define IMessageRouter_AddRef(This)	\
    (This)->lpVtbl -> AddRef(This)

#define IMessageRouter_Release(This)	\
    (This)->lpVtbl -> Release(This)


#define IMessageRouter_GetTransportSinkID(This)	\
    (This)->lpVtbl -> GetTransportSinkID(This)

#define IMessageRouter_GetMessageType(This,pIMailMsg,pdwMessageType)	\
    (This)->lpVtbl -> GetMessageType(This,pIMailMsg,pdwMessageType)

#define IMessageRouter_ReleaseMessageType(This,dwMessageType,dwReleaseCount)	\
    (This)->lpVtbl -> ReleaseMessageType(This,dwMessageType,dwReleaseCount)

#define IMessageRouter_GetNextHop(This,pszDestinationAddressType,pszDestinationAddress,dwMessageType,ppszRouteAddressType,ppszRouteAddress,pdwScheduleID,ppszRouteAddressClass,ppszConnectorName,pdwNextHopType)	\
    (This)->lpVtbl -> GetNextHop(This,pszDestinationAddressType,pszDestinationAddress,dwMessageType,ppszRouteAddressType,ppszRouteAddress,pdwScheduleID,ppszRouteAddressClass,ppszConnectorName,pdwNextHopType)

#define IMessageRouter_GetNextHopFree(This,pszDestinationAddressType,pszDestinationAddress,pszConnectorName,pszRouteAddressType,pszRouteAddress,pszRouteAddressClass)	\
    (This)->lpVtbl -> GetNextHopFree(This,pszDestinationAddressType,pszDestinationAddress,pszConnectorName,pszRouteAddressType,pszRouteAddress,pszRouteAddressClass)

#define IMessageRouter_ConnectionFailed(This,pszConnectorName)	\
    (This)->lpVtbl -> ConnectionFailed(This,pszConnectorName)

#endif /* COBJMACROS */


#endif 	/* C style interface */



/* [local] */ GUID STDMETHODCALLTYPE IMessageRouter_GetTransportSinkID_Proxy( 
    IMessageRouter __RPC_FAR * This);


void __RPC_STUB IMessageRouter_GetTransportSinkID_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


HRESULT STDMETHODCALLTYPE IMessageRouter_GetMessageType_Proxy( 
    IMessageRouter __RPC_FAR * This,
    /* [in] */ IMailMsgProperties __RPC_FAR *pIMailMsg,
    /* [out] */ DWORD __RPC_FAR *pdwMessageType);


void __RPC_STUB IMessageRouter_GetMessageType_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


HRESULT STDMETHODCALLTYPE IMessageRouter_ReleaseMessageType_Proxy( 
    IMessageRouter __RPC_FAR * This,
    /* [in] */ DWORD dwMessageType,
    /* [in] */ DWORD dwReleaseCount);


void __RPC_STUB IMessageRouter_ReleaseMessageType_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [local] */ HRESULT STDMETHODCALLTYPE IMessageRouter_GetNextHop_Proxy( 
    IMessageRouter __RPC_FAR * This,
    /* [in] */ LPSTR pszDestinationAddressType,
    /* [in] */ LPSTR pszDestinationAddress,
    /* [in] */ DWORD dwMessageType,
    /* [out] */ LPSTR __RPC_FAR *ppszRouteAddressType,
    /* [out] */ LPSTR __RPC_FAR *ppszRouteAddress,
    /* [out] */ DWORD __RPC_FAR *pdwScheduleID,
    /* [out] */ LPSTR __RPC_FAR *ppszRouteAddressClass,
    /* [out] */ LPSTR __RPC_FAR *ppszConnectorName,
    /* [out] */ DWORD __RPC_FAR *pdwNextHopType);


void __RPC_STUB IMessageRouter_GetNextHop_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [local] */ HRESULT STDMETHODCALLTYPE IMessageRouter_GetNextHopFree_Proxy( 
    IMessageRouter __RPC_FAR * This,
    /* [in] */ LPSTR pszDestinationAddressType,
    /* [in] */ LPSTR pszDestinationAddress,
    /* [in] */ LPSTR pszConnectorName,
    /* [in] */ LPSTR pszRouteAddressType,
    /* [in] */ LPSTR pszRouteAddress,
    /* [in] */ LPSTR pszRouteAddressClass);


void __RPC_STUB IMessageRouter_GetNextHopFree_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


HRESULT STDMETHODCALLTYPE IMessageRouter_ConnectionFailed_Proxy( 
    IMessageRouter __RPC_FAR * This,
    /* [string][in] */ LPSTR pszConnectorName);


void __RPC_STUB IMessageRouter_ConnectionFailed_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);



#endif 	/* __IMessageRouter_INTERFACE_DEFINED__ */


/* interface __MIDL_itf_SmtpEvent_0281 */
/* [local] */ 

#define	MTI_ROUTING_ADDRESS_TYPE_NULL	( 0 )

#define	MTI_ROUTING_ADDRESS_TYPE_SMTP	( "SMTP" )

#define	MTI_ROUTING_ADDRESS_TYPE_X400	( "X400" )

#define	MTI_ROUTING_ADDRESS_TYPE_X500	( "X500" )

typedef /* [public][v1_enum] */ 
enum __MIDL___MIDL_itf_SmtpEvent_0281_0001
    {	MTI_NEXT_HOP_TYPE_SAME_VIRTUAL_SERVER	= 0,
	MTI_NEXT_HOP_TYPE_REMOTE	= MTI_NEXT_HOP_TYPE_SAME_VIRTUAL_SERVER + 1,
	MTI_NEXT_HOP_TYPE_RESERVED	= MTI_NEXT_HOP_TYPE_REMOTE + 1,
	MTI_NEXT_HOP_TYPE_UNREACHABLE	= MTI_NEXT_HOP_TYPE_RESERVED + 1,
	MTI_NEXT_HOP_TYPE_CURRENTLY_UNREACHABLE	= MTI_NEXT_HOP_TYPE_UNREACHABLE + 1
    }	MTI_NEXT_HOP_TYPE;

typedef /* [v1_enum] */ enum __MIDL___MIDL_itf_SmtpEvent_0281_0001 __RPC_FAR *PMTI_NEXT_HOP_TYPE;



extern RPC_IF_HANDLE __MIDL_itf_SmtpEvent_0281_v0_0_c_ifspec;
extern RPC_IF_HANDLE __MIDL_itf_SmtpEvent_0281_v0_0_s_ifspec;

#ifndef __IMailTransportRouterSetLinkState_INTERFACE_DEFINED__
#define __IMailTransportRouterSetLinkState_INTERFACE_DEFINED__

/* interface IMailTransportRouterSetLinkState */
/* [unique][helpstring][uuid][object] */ 


EXTERN_C const IID IID_IMailTransportRouterSetLinkState;

#if defined(__cplusplus) && !defined(CINTERFACE)
    
    MIDL_INTERFACE("B870CE28-A755-11d2-A6A9-00C04FA3490A")
    IMailTransportRouterSetLinkState : public IUnknown
    {
    public:
        virtual HRESULT STDMETHODCALLTYPE SetLinkState( 
            /* [in] */ LPSTR szLinkDomainName,
            /* [in] */ GUID guidRouterGUID,
            /* [in] */ DWORD dwScheduleID,
            /* [in] */ LPSTR szConnectorName,
            /* [in] */ DWORD dwSetLinkState,
            /* [in] */ DWORD dwUnsetLinkState,
            /* [in] */ FILETIME __RPC_FAR *pftNextScheduled,
            /* [in] */ IMessageRouter __RPC_FAR *pMessageRouter) = 0;
        
    };
    
#else 	/* C style interface */

    typedef struct IMailTransportRouterSetLinkStateVtbl
    {
        BEGIN_INTERFACE
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *QueryInterface )( 
            IMailTransportRouterSetLinkState __RPC_FAR * This,
            /* [in] */ REFIID riid,
            /* [iid_is][out] */ void __RPC_FAR *__RPC_FAR *ppvObject);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *AddRef )( 
            IMailTransportRouterSetLinkState __RPC_FAR * This);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *Release )( 
            IMailTransportRouterSetLinkState __RPC_FAR * This);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *SetLinkState )( 
            IMailTransportRouterSetLinkState __RPC_FAR * This,
            /* [in] */ LPSTR szLinkDomainName,
            /* [in] */ GUID guidRouterGUID,
            /* [in] */ DWORD dwScheduleID,
            /* [in] */ LPSTR szConnectorName,
            /* [in] */ DWORD dwSetLinkState,
            /* [in] */ DWORD dwUnsetLinkState,
            /* [in] */ FILETIME __RPC_FAR *pftNextScheduled,
            /* [in] */ IMessageRouter __RPC_FAR *pMessageRouter);
        
        END_INTERFACE
    } IMailTransportRouterSetLinkStateVtbl;

    interface IMailTransportRouterSetLinkState
    {
        CONST_VTBL struct IMailTransportRouterSetLinkStateVtbl __RPC_FAR *lpVtbl;
    };

    

#ifdef COBJMACROS


#define IMailTransportRouterSetLinkState_QueryInterface(This,riid,ppvObject)	\
    (This)->lpVtbl -> QueryInterface(This,riid,ppvObject)

#define IMailTransportRouterSetLinkState_AddRef(This)	\
    (This)->lpVtbl -> AddRef(This)

#define IMailTransportRouterSetLinkState_Release(This)	\
    (This)->lpVtbl -> Release(This)


#define IMailTransportRouterSetLinkState_SetLinkState(This,szLinkDomainName,guidRouterGUID,dwScheduleID,szConnectorName,dwSetLinkState,dwUnsetLinkState,pftNextScheduled,pMessageRouter)	\
    (This)->lpVtbl -> SetLinkState(This,szLinkDomainName,guidRouterGUID,dwScheduleID,szConnectorName,dwSetLinkState,dwUnsetLinkState,pftNextScheduled,pMessageRouter)

#endif /* COBJMACROS */


#endif 	/* C style interface */



HRESULT STDMETHODCALLTYPE IMailTransportRouterSetLinkState_SetLinkState_Proxy( 
    IMailTransportRouterSetLinkState __RPC_FAR * This,
    /* [in] */ LPSTR szLinkDomainName,
    /* [in] */ GUID guidRouterGUID,
    /* [in] */ DWORD dwScheduleID,
    /* [in] */ LPSTR szConnectorName,
    /* [in] */ DWORD dwSetLinkState,
    /* [in] */ DWORD dwUnsetLinkState,
    /* [in] */ FILETIME __RPC_FAR *pftNextScheduled,
    /* [in] */ IMessageRouter __RPC_FAR *pMessageRouter);


void __RPC_STUB IMailTransportRouterSetLinkState_SetLinkState_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);



#endif 	/* __IMailTransportRouterSetLinkState_INTERFACE_DEFINED__ */


#ifndef __IMessageRouterLinkStateNotification_INTERFACE_DEFINED__
#define __IMessageRouterLinkStateNotification_INTERFACE_DEFINED__

/* interface IMessageRouterLinkStateNotification */
/* [unique][helpstring][uuid][object] */ 


EXTERN_C const IID IID_IMessageRouterLinkStateNotification;

#if defined(__cplusplus) && !defined(CINTERFACE)
    
    MIDL_INTERFACE("B870CE29-A755-11d2-A6A9-00C04FA3490A")
    IMessageRouterLinkStateNotification : public IUnknown
    {
    public:
        virtual HRESULT STDMETHODCALLTYPE LinkStateNotify( 
            /* [in] */ LPSTR szLinkDomainName,
            /* [in] */ GUID guidRouterGUID,
            /* [in] */ DWORD dwScheduleID,
            /* [in] */ LPSTR szConnectorName,
            /* [in] */ DWORD dwLinkState,
            /* [in] */ DWORD cConsecutiveFailures,
            /* [out][in] */ FILETIME __RPC_FAR *pftNextScheduled,
            /* [out] */ DWORD __RPC_FAR *pdwSetLinkState,
            /* [out] */ DWORD __RPC_FAR *pdwUnsetLinkState) = 0;
        
    };
    
#else 	/* C style interface */

    typedef struct IMessageRouterLinkStateNotificationVtbl
    {
        BEGIN_INTERFACE
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *QueryInterface )( 
            IMessageRouterLinkStateNotification __RPC_FAR * This,
            /* [in] */ REFIID riid,
            /* [iid_is][out] */ void __RPC_FAR *__RPC_FAR *ppvObject);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *AddRef )( 
            IMessageRouterLinkStateNotification __RPC_FAR * This);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *Release )( 
            IMessageRouterLinkStateNotification __RPC_FAR * This);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *LinkStateNotify )( 
            IMessageRouterLinkStateNotification __RPC_FAR * This,
            /* [in] */ LPSTR szLinkDomainName,
            /* [in] */ GUID guidRouterGUID,
            /* [in] */ DWORD dwScheduleID,
            /* [in] */ LPSTR szConnectorName,
            /* [in] */ DWORD dwLinkState,
            /* [in] */ DWORD cConsecutiveFailures,
            /* [out][in] */ FILETIME __RPC_FAR *pftNextScheduled,
            /* [out] */ DWORD __RPC_FAR *pdwSetLinkState,
            /* [out] */ DWORD __RPC_FAR *pdwUnsetLinkState);
        
        END_INTERFACE
    } IMessageRouterLinkStateNotificationVtbl;

    interface IMessageRouterLinkStateNotification
    {
        CONST_VTBL struct IMessageRouterLinkStateNotificationVtbl __RPC_FAR *lpVtbl;
    };

    

#ifdef COBJMACROS


#define IMessageRouterLinkStateNotification_QueryInterface(This,riid,ppvObject)	\
    (This)->lpVtbl -> QueryInterface(This,riid,ppvObject)

#define IMessageRouterLinkStateNotification_AddRef(This)	\
    (This)->lpVtbl -> AddRef(This)

#define IMessageRouterLinkStateNotification_Release(This)	\
    (This)->lpVtbl -> Release(This)


#define IMessageRouterLinkStateNotification_LinkStateNotify(This,szLinkDomainName,guidRouterGUID,dwScheduleID,szConnectorName,dwLinkState,cConsecutiveFailures,pftNextScheduled,pdwSetLinkState,pdwUnsetLinkState)	\
    (This)->lpVtbl -> LinkStateNotify(This,szLinkDomainName,guidRouterGUID,dwScheduleID,szConnectorName,dwLinkState,cConsecutiveFailures,pftNextScheduled,pdwSetLinkState,pdwUnsetLinkState)

#endif /* COBJMACROS */


#endif 	/* C style interface */



HRESULT STDMETHODCALLTYPE IMessageRouterLinkStateNotification_LinkStateNotify_Proxy( 
    IMessageRouterLinkStateNotification __RPC_FAR * This,
    /* [in] */ LPSTR szLinkDomainName,
    /* [in] */ GUID guidRouterGUID,
    /* [in] */ DWORD dwScheduleID,
    /* [in] */ LPSTR szConnectorName,
    /* [in] */ DWORD dwLinkState,
    /* [in] */ DWORD cConsecutiveFailures,
    /* [out][in] */ FILETIME __RPC_FAR *pftNextScheduled,
    /* [out] */ DWORD __RPC_FAR *pdwSetLinkState,
    /* [out] */ DWORD __RPC_FAR *pdwUnsetLinkState);


void __RPC_STUB IMessageRouterLinkStateNotification_LinkStateNotify_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);



#endif 	/* __IMessageRouterLinkStateNotification_INTERFACE_DEFINED__ */


/* interface __MIDL_itf_SmtpEvent_0283 */
/* [local] */ 

typedef /* [public][v1_enum] */ 
enum __MIDL___MIDL_itf_SmtpEvent_0283_0001
    {	LINK_STATE_NO_ACTION	= 0,
	LINK_STATE_RETRY_ENABLED	= 0x1,
	LINK_STATE_SCHED_ENABLED	= 0x2,
	LINK_STATE_CMD_ENABLED	= 0x4,
	LINK_STATE_ADMIN_HALT	= 0x8,
	LINK_STATE_ADMIN_FORCE_CONN	= 0x10,
	LINK_STATE_CONNECT_IF_NO_MSGS	= 0x20,
	LINK_STATE_DO_NOT_DELETE	= 0x40,
	LINK_STATE_CREATE_IF_NECESSARY	= 0x80,
	LINK_STATE_LINK_NO_LONGER_USED	= 0x100,
	LINK_STATE_RESERVED	= 0xffff0000
    }	eLinkStateFlags;

#define ROUTER_E_NOTINTERESTED   MAKE_HRESULT(SEVERITY_ERROR,FACILITY_ITF,0x1000)


extern RPC_IF_HANDLE __MIDL_itf_SmtpEvent_0283_v0_0_c_ifspec;
extern RPC_IF_HANDLE __MIDL_itf_SmtpEvent_0283_v0_0_s_ifspec;

#ifndef __IMailTransportRoutingEngine_INTERFACE_DEFINED__
#define __IMailTransportRoutingEngine_INTERFACE_DEFINED__

/* interface IMailTransportRoutingEngine */
/* [unique][helpstring][uuid][object] */ 


EXTERN_C const IID IID_IMailTransportRoutingEngine;

#if defined(__cplusplus) && !defined(CINTERFACE)
    
    MIDL_INTERFACE("A928AD13-1610-11d2-9E02-00C04FA322BA")
    IMailTransportRoutingEngine : public IUnknown
    {
    public:
        virtual /* [local] */ HRESULT STDMETHODCALLTYPE GetMessageRouter( 
            /* [in] */ IMailMsgProperties __RPC_FAR *pIMailMsg,
            /* [in] */ IMessageRouter __RPC_FAR *pICurrentMessageRouter,
            /* [out] */ IMessageRouter __RPC_FAR *__RPC_FAR *ppIMessageRouter) = 0;
        
    };
    
#else 	/* C style interface */

    typedef struct IMailTransportRoutingEngineVtbl
    {
        BEGIN_INTERFACE
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *QueryInterface )( 
            IMailTransportRoutingEngine __RPC_FAR * This,
            /* [in] */ REFIID riid,
            /* [iid_is][out] */ void __RPC_FAR *__RPC_FAR *ppvObject);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *AddRef )( 
            IMailTransportRoutingEngine __RPC_FAR * This);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *Release )( 
            IMailTransportRoutingEngine __RPC_FAR * This);
        
        /* [local] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetMessageRouter )( 
            IMailTransportRoutingEngine __RPC_FAR * This,
            /* [in] */ IMailMsgProperties __RPC_FAR *pIMailMsg,
            /* [in] */ IMessageRouter __RPC_FAR *pICurrentMessageRouter,
            /* [out] */ IMessageRouter __RPC_FAR *__RPC_FAR *ppIMessageRouter);
        
        END_INTERFACE
    } IMailTransportRoutingEngineVtbl;

    interface IMailTransportRoutingEngine
    {
        CONST_VTBL struct IMailTransportRoutingEngineVtbl __RPC_FAR *lpVtbl;
    };

    

#ifdef COBJMACROS


#define IMailTransportRoutingEngine_QueryInterface(This,riid,ppvObject)	\
    (This)->lpVtbl -> QueryInterface(This,riid,ppvObject)

#define IMailTransportRoutingEngine_AddRef(This)	\
    (This)->lpVtbl -> AddRef(This)

#define IMailTransportRoutingEngine_Release(This)	\
    (This)->lpVtbl -> Release(This)


#define IMailTransportRoutingEngine_GetMessageRouter(This,pIMailMsg,pICurrentMessageRouter,ppIMessageRouter)	\
    (This)->lpVtbl -> GetMessageRouter(This,pIMailMsg,pICurrentMessageRouter,ppIMessageRouter)

#endif /* COBJMACROS */


#endif 	/* C style interface */



/* [local] */ HRESULT STDMETHODCALLTYPE IMailTransportRoutingEngine_GetMessageRouter_Proxy( 
    IMailTransportRoutingEngine __RPC_FAR * This,
    /* [in] */ IMailMsgProperties __RPC_FAR *pIMailMsg,
    /* [in] */ IMessageRouter __RPC_FAR *pICurrentMessageRouter,
    /* [out] */ IMessageRouter __RPC_FAR *__RPC_FAR *ppIMessageRouter);


void __RPC_STUB IMailTransportRoutingEngine_GetMessageRouter_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);



#endif 	/* __IMailTransportRoutingEngine_INTERFACE_DEFINED__ */


/* interface __MIDL_itf_SmtpEvent_0284 */
/* [local] */ 

#define MTE_QUEUED_OUTBOUND         1010
#define MTE_TRANSFERRED_OUTBOUND    1011
#define MTE_RECEIVED_INBOUND        1012
#define MTE_TRANSFERRED_INBOUND     1013
#define MTE_MESSAGE_REROUTED        1014
#define MTE_REPORT_TRANSFERRED_IN   1015
#define MTE_REPORT_TRANSFERRED_OUT  1016
#define MTE_REPORT_GENERATED        1017
#define MTE_REPORT_ABSORBED         1018
#define MTE_SUBMIT_MESSAGE_TO_AQ    1019
#define MTE_BEGIN_OUTBOUND_TRANSFER 1020
#define MTE_BADMAIL                 1021
#define MTE_AQ_FAILURE              1022
#define MTE_LOCAL_DELIVERY          1023
#define MTE_SUBMIT_MESSAGE_TO_CAT   1024
#define MTE_BEGIN_SUBMIT_MESSAGE    1025
#define MTE_AQ_FAILED_MESSAGE       1026
#define MTE_NDR_ALL                 1030
#define MTE_END_OUTBOUND_TRANSFER   1031


extern RPC_IF_HANDLE __MIDL_itf_SmtpEvent_0284_v0_0_c_ifspec;
extern RPC_IF_HANDLE __MIDL_itf_SmtpEvent_0284_v0_0_s_ifspec;

#ifndef __IMsgTrackLog_INTERFACE_DEFINED__
#define __IMsgTrackLog_INTERFACE_DEFINED__

/* interface IMsgTrackLog */
/* [uuid][unique][object][local][helpstring] */ 


EXTERN_C const IID IID_IMsgTrackLog;

#if defined(__cplusplus) && !defined(CINTERFACE)
    
    MIDL_INTERFACE("1bc3580e-7e4f-11d2-94f4-00C04f79f1d6")
    IMsgTrackLog : public IUnknown
    {
    public:
        virtual HRESULT STDMETHODCALLTYPE OnSyncLogMsgTrackInfo( 
            /* [in] */ IUnknown __RPC_FAR *pIServer,
            /* [in] */ IMailMsgProperties __RPC_FAR *pIMailMsgProp,
            /* [in] */ LPMSG_TRACK_INFO pMsgTrackInfo) = 0;
        
    };
    
#else 	/* C style interface */

    typedef struct IMsgTrackLogVtbl
    {
        BEGIN_INTERFACE
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *QueryInterface )( 
            IMsgTrackLog __RPC_FAR * This,
            /* [in] */ REFIID riid,
            /* [iid_is][out] */ void __RPC_FAR *__RPC_FAR *ppvObject);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *AddRef )( 
            IMsgTrackLog __RPC_FAR * This);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *Release )( 
            IMsgTrackLog __RPC_FAR * This);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *OnSyncLogMsgTrackInfo )( 
            IMsgTrackLog __RPC_FAR * This,
            /* [in] */ IUnknown __RPC_FAR *pIServer,
            /* [in] */ IMailMsgProperties __RPC_FAR *pIMailMsgProp,
            /* [in] */ LPMSG_TRACK_INFO pMsgTrackInfo);
        
        END_INTERFACE
    } IMsgTrackLogVtbl;

    interface IMsgTrackLog
    {
        CONST_VTBL struct IMsgTrackLogVtbl __RPC_FAR *lpVtbl;
    };

    

#ifdef COBJMACROS


#define IMsgTrackLog_QueryInterface(This,riid,ppvObject)	\
    (This)->lpVtbl -> QueryInterface(This,riid,ppvObject)

#define IMsgTrackLog_AddRef(This)	\
    (This)->lpVtbl -> AddRef(This)

#define IMsgTrackLog_Release(This)	\
    (This)->lpVtbl -> Release(This)


#define IMsgTrackLog_OnSyncLogMsgTrackInfo(This,pIServer,pIMailMsgProp,pMsgTrackInfo)	\
    (This)->lpVtbl -> OnSyncLogMsgTrackInfo(This,pIServer,pIMailMsgProp,pMsgTrackInfo)

#endif /* COBJMACROS */


#endif 	/* C style interface */



HRESULT STDMETHODCALLTYPE IMsgTrackLog_OnSyncLogMsgTrackInfo_Proxy( 
    IMsgTrackLog __RPC_FAR * This,
    /* [in] */ IUnknown __RPC_FAR *pIServer,
    /* [in] */ IMailMsgProperties __RPC_FAR *pIMailMsgProp,
    /* [in] */ LPMSG_TRACK_INFO pMsgTrackInfo);


void __RPC_STUB IMsgTrackLog_OnSyncLogMsgTrackInfo_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);



#endif 	/* __IMsgTrackLog_INTERFACE_DEFINED__ */


#ifndef __IDnsResolverRecord_INTERFACE_DEFINED__
#define __IDnsResolverRecord_INTERFACE_DEFINED__

/* interface IDnsResolverRecord */
/* [uuid][unique][object][local][helpstring] */ 


EXTERN_C const IID IID_IDnsResolverRecord;

#if defined(__cplusplus) && !defined(CINTERFACE)
    
    MIDL_INTERFACE("e5b89c52-8e0b-11d2-94f6-00C04f79f1d6")
    IDnsResolverRecord : public IUnknown
    {
    public:
        virtual HRESULT STDMETHODCALLTYPE GetItem( 
            /* [in] */ ULONG cIndex,
            /* [out] */ LPSTR __RPC_FAR *ppszHostName,
            /* [out] */ DWORD __RPC_FAR *pAddr) = 0;
        
        virtual HRESULT STDMETHODCALLTYPE Count( 
            /* [out] */ DWORD __RPC_FAR *pcRecords) = 0;
        
    };
    
#else 	/* C style interface */

    typedef struct IDnsResolverRecordVtbl
    {
        BEGIN_INTERFACE
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *QueryInterface )( 
            IDnsResolverRecord __RPC_FAR * This,
            /* [in] */ REFIID riid,
            /* [iid_is][out] */ void __RPC_FAR *__RPC_FAR *ppvObject);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *AddRef )( 
            IDnsResolverRecord __RPC_FAR * This);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *Release )( 
            IDnsResolverRecord __RPC_FAR * This);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetItem )( 
            IDnsResolverRecord __RPC_FAR * This,
            /* [in] */ ULONG cIndex,
            /* [out] */ LPSTR __RPC_FAR *ppszHostName,
            /* [out] */ DWORD __RPC_FAR *pAddr);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *Count )( 
            IDnsResolverRecord __RPC_FAR * This,
            /* [out] */ DWORD __RPC_FAR *pcRecords);
        
        END_INTERFACE
    } IDnsResolverRecordVtbl;

    interface IDnsResolverRecord
    {
        CONST_VTBL struct IDnsResolverRecordVtbl __RPC_FAR *lpVtbl;
    };

    

#ifdef COBJMACROS


#define IDnsResolverRecord_QueryInterface(This,riid,ppvObject)	\
    (This)->lpVtbl -> QueryInterface(This,riid,ppvObject)

#define IDnsResolverRecord_AddRef(This)	\
    (This)->lpVtbl -> AddRef(This)

#define IDnsResolverRecord_Release(This)	\
    (This)->lpVtbl -> Release(This)


#define IDnsResolverRecord_GetItem(This,cIndex,ppszHostName,pAddr)	\
    (This)->lpVtbl -> GetItem(This,cIndex,ppszHostName,pAddr)

#define IDnsResolverRecord_Count(This,pcRecords)	\
    (This)->lpVtbl -> Count(This,pcRecords)

#endif /* COBJMACROS */


#endif 	/* C style interface */



HRESULT STDMETHODCALLTYPE IDnsResolverRecord_GetItem_Proxy( 
    IDnsResolverRecord __RPC_FAR * This,
    /* [in] */ ULONG cIndex,
    /* [out] */ LPSTR __RPC_FAR *ppszHostName,
    /* [out] */ DWORD __RPC_FAR *pAddr);


void __RPC_STUB IDnsResolverRecord_GetItem_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


HRESULT STDMETHODCALLTYPE IDnsResolverRecord_Count_Proxy( 
    IDnsResolverRecord __RPC_FAR * This,
    /* [out] */ DWORD __RPC_FAR *pcRecords);


void __RPC_STUB IDnsResolverRecord_Count_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);



#endif 	/* __IDnsResolverRecord_INTERFACE_DEFINED__ */


#ifndef __IDnsResolverRecordSink_INTERFACE_DEFINED__
#define __IDnsResolverRecordSink_INTERFACE_DEFINED__

/* interface IDnsResolverRecordSink */
/* [uuid][unique][object][local][helpstring] */ 


EXTERN_C const IID IID_IDnsResolverRecordSink;

#if defined(__cplusplus) && !defined(CINTERFACE)
    
    MIDL_INTERFACE("d95a4d0c-8e06-11d2-94f6-00C04f79f1d6")
    IDnsResolverRecordSink : public IUnknown
    {
    public:
        virtual HRESULT STDMETHODCALLTYPE OnSyncGetResolverRecord( 
            /* [in] */ LPSTR pszHostName,
            /* [in] */ LPSTR pszInstanceFQDN,
            /* [in] */ DWORD dwVirtualServerId,
            /* [out] */ IDnsResolverRecord __RPC_FAR *__RPC_FAR *ppDnsResolverRecord) = 0;
        
    };
    
#else 	/* C style interface */

    typedef struct IDnsResolverRecordSinkVtbl
    {
        BEGIN_INTERFACE
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *QueryInterface )( 
            IDnsResolverRecordSink __RPC_FAR * This,
            /* [in] */ REFIID riid,
            /* [iid_is][out] */ void __RPC_FAR *__RPC_FAR *ppvObject);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *AddRef )( 
            IDnsResolverRecordSink __RPC_FAR * This);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *Release )( 
            IDnsResolverRecordSink __RPC_FAR * This);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *OnSyncGetResolverRecord )( 
            IDnsResolverRecordSink __RPC_FAR * This,
            /* [in] */ LPSTR pszHostName,
            /* [in] */ LPSTR pszInstanceFQDN,
            /* [in] */ DWORD dwVirtualServerId,
            /* [out] */ IDnsResolverRecord __RPC_FAR *__RPC_FAR *ppDnsResolverRecord);
        
        END_INTERFACE
    } IDnsResolverRecordSinkVtbl;

    interface IDnsResolverRecordSink
    {
        CONST_VTBL struct IDnsResolverRecordSinkVtbl __RPC_FAR *lpVtbl;
    };

    

#ifdef COBJMACROS


#define IDnsResolverRecordSink_QueryInterface(This,riid,ppvObject)	\
    (This)->lpVtbl -> QueryInterface(This,riid,ppvObject)

#define IDnsResolverRecordSink_AddRef(This)	\
    (This)->lpVtbl -> AddRef(This)

#define IDnsResolverRecordSink_Release(This)	\
    (This)->lpVtbl -> Release(This)


#define IDnsResolverRecordSink_OnSyncGetResolverRecord(This,pszHostName,pszInstanceFQDN,dwVirtualServerId,ppDnsResolverRecord)	\
    (This)->lpVtbl -> OnSyncGetResolverRecord(This,pszHostName,pszInstanceFQDN,dwVirtualServerId,ppDnsResolverRecord)

#endif /* COBJMACROS */


#endif 	/* C style interface */



HRESULT STDMETHODCALLTYPE IDnsResolverRecordSink_OnSyncGetResolverRecord_Proxy( 
    IDnsResolverRecordSink __RPC_FAR * This,
    /* [in] */ LPSTR pszHostName,
    /* [in] */ LPSTR pszInstanceFQDN,
    /* [in] */ DWORD dwVirtualServerId,
    /* [out] */ IDnsResolverRecord __RPC_FAR *__RPC_FAR *ppDnsResolverRecord);


void __RPC_STUB IDnsResolverRecordSink_OnSyncGetResolverRecord_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);



#endif 	/* __IDnsResolverRecordSink_INTERFACE_DEFINED__ */


#ifndef __ISmtpMaxMsgSize_INTERFACE_DEFINED__
#define __ISmtpMaxMsgSize_INTERFACE_DEFINED__

/* interface ISmtpMaxMsgSize */
/* [uuid][unique][object][local][helpstring] */ 


EXTERN_C const IID IID_ISmtpMaxMsgSize;

#if defined(__cplusplus) && !defined(CINTERFACE)
    
    MIDL_INTERFACE("b997f192-a67d-11d2-94f7-00C04f79f1d6")
    ISmtpMaxMsgSize : public IUnknown
    {
    public:
        virtual HRESULT STDMETHODCALLTYPE OnSyncMaxMsgSize( 
            /* [in] */ IUnknown __RPC_FAR *pIUnknown,
            /* [in] */ IMailMsgProperties __RPC_FAR *pIMailMsgProp,
            /* [out] */ BOOL __RPC_FAR *pfShouldImposeLimit) = 0;
        
    };
    
#else 	/* C style interface */

    typedef struct ISmtpMaxMsgSizeVtbl
    {
        BEGIN_INTERFACE
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *QueryInterface )( 
            ISmtpMaxMsgSize __RPC_FAR * This,
            /* [in] */ REFIID riid,
            /* [iid_is][out] */ void __RPC_FAR *__RPC_FAR *ppvObject);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *AddRef )( 
            ISmtpMaxMsgSize __RPC_FAR * This);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *Release )( 
            ISmtpMaxMsgSize __RPC_FAR * This);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *OnSyncMaxMsgSize )( 
            ISmtpMaxMsgSize __RPC_FAR * This,
            /* [in] */ IUnknown __RPC_FAR *pIUnknown,
            /* [in] */ IMailMsgProperties __RPC_FAR *pIMailMsgProp,
            /* [out] */ BOOL __RPC_FAR *pfShouldImposeLimit);
        
        END_INTERFACE
    } ISmtpMaxMsgSizeVtbl;

    interface ISmtpMaxMsgSize
    {
        CONST_VTBL struct ISmtpMaxMsgSizeVtbl __RPC_FAR *lpVtbl;
    };

    

#ifdef COBJMACROS


#define ISmtpMaxMsgSize_QueryInterface(This,riid,ppvObject)	\
    (This)->lpVtbl -> QueryInterface(This,riid,ppvObject)

#define ISmtpMaxMsgSize_AddRef(This)	\
    (This)->lpVtbl -> AddRef(This)

#define ISmtpMaxMsgSize_Release(This)	\
    (This)->lpVtbl -> Release(This)


#define ISmtpMaxMsgSize_OnSyncMaxMsgSize(This,pIUnknown,pIMailMsgProp,pfShouldImposeLimit)	\
    (This)->lpVtbl -> OnSyncMaxMsgSize(This,pIUnknown,pIMailMsgProp,pfShouldImposeLimit)

#endif /* COBJMACROS */


#endif 	/* C style interface */



HRESULT STDMETHODCALLTYPE ISmtpMaxMsgSize_OnSyncMaxMsgSize_Proxy( 
    ISmtpMaxMsgSize __RPC_FAR * This,
    /* [in] */ IUnknown __RPC_FAR *pIUnknown,
    /* [in] */ IMailMsgProperties __RPC_FAR *pIMailMsgProp,
    /* [out] */ BOOL __RPC_FAR *pfShouldImposeLimit);


void __RPC_STUB ISmtpMaxMsgSize_OnSyncMaxMsgSize_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);



#endif 	/* __ISmtpMaxMsgSize_INTERFACE_DEFINED__ */


/* interface __MIDL_itf_SmtpEvent_0288 */
/* [local] */ 









typedef /* [public][v1_enum] */ 
enum __MIDL___MIDL_itf_SmtpEvent_0288_0001
    {	CCAT_CONFIG_INFO_FLAGS	= 0x1,
	CCAT_CONFIG_INFO_ROUTINGTYPE	= 0x2,
	CCAT_CONFIG_INFO_BINDDOMAIN	= 0x4,
	CCAT_CONFIG_INFO_USER	= 0x8,
	CCAT_CONFIG_INFO_PASSWORD	= 0x10,
	CCAT_CONFIG_INFO_BINDTYPE	= 0x20,
	CCAT_CONFIG_INFO_SCHEMATYPE	= 0x40,
	CCAT_CONFIG_INFO_HOST	= 0x80,
	CCAT_CONFIG_INFO_NAMINGCONTEXT	= 0x100,
	CCAT_CONFIG_INFO_DEFAULTDOMAIN	= 0x200,
	CCAT_CONFIG_INFO_PORT	= 0x400,
	CCAT_CONFIG_INFO_ISMTPSERVER	= 0x800,
	CCAT_CONFIG_INFO_IDOMAININFO	= 0x1000,
	CCAT_CONFIG_INFO_ENABLE	= 0x2000,
	CCAT_CONFIG_INFO_DEFAULT	= 0x4000,
	CCAT_CONFIG_INFO_VSID	= 0x8000,
	CCAT_CONFIG_INFO_ALL	= 0xffff
    }	eCatConfigInfoFlags;

typedef struct _tagCCatConfigInfo
    {
    DWORD dwCCatConfigInfoFlags;
    DWORD dwEnable;
    DWORD dwCatFlags;
    LPSTR pszRoutingType;
    LPSTR pszBindDomain;
    LPSTR pszUser;
    LPSTR pszPassword;
    LPSTR pszBindType;
    LPSTR pszSchemaType;
    LPSTR pszHost;
    LPSTR pszNamingContext;
    LPSTR pszDefaultDomain;
    DWORD dwPort;
    ISMTPServer __RPC_FAR *pISMTPServer;
    ICategorizerDomainInfo __RPC_FAR *pIDomainInfo;
    DWORD dwVirtualServerID;
    }	CCATCONFIGINFO;

typedef struct _tagCCatConfigInfo __RPC_FAR *PCCATCONFIGINFO;

typedef /* [v1_enum] */ 
enum _CAT_ADDRESS_TYPE
    {	CAT_SMTP	= 0,
	CAT_X500	= 1,
	CAT_X400	= 2,
	CAT_DN	= 3,
	CAT_LEGACYEXDN	= 4,
	CAT_CUSTOMTYPE	= 5,
	CAT_UNKNOWNTYPE	= 6
    }	CAT_ADDRESS_TYPE;



extern RPC_IF_HANDLE __MIDL_itf_SmtpEvent_0288_v0_0_c_ifspec;
extern RPC_IF_HANDLE __MIDL_itf_SmtpEvent_0288_v0_0_s_ifspec;

#ifndef __ICategorizerProperties_INTERFACE_DEFINED__
#define __ICategorizerProperties_INTERFACE_DEFINED__

/* interface ICategorizerProperties */
/* [unique][helpstring][uuid][object][local] */ 


EXTERN_C const IID IID_ICategorizerProperties;

#if defined(__cplusplus) && !defined(CINTERFACE)
    
    MIDL_INTERFACE("96BF3199-79D8-11d2-9E11-00C04FA322BA")
    ICategorizerProperties : public IUnknown
    {
    public:
        virtual HRESULT STDMETHODCALLTYPE GetStringA( 
            /* [in] */ DWORD dwPropId,
            /* [in] */ DWORD dwcchValue,
            /* [size_is][out] */ LPSTR pszValue) = 0;
        
        virtual HRESULT STDMETHODCALLTYPE PutStringA( 
            /* [in] */ DWORD dwPropId,
            /* [unique][in] */ LPSTR pszValue) = 0;
        
        virtual HRESULT STDMETHODCALLTYPE GetDWORD( 
            /* [in] */ DWORD dwPropId,
            /* [out] */ DWORD __RPC_FAR *pdwValue) = 0;
        
        virtual HRESULT STDMETHODCALLTYPE PutDWORD( 
            /* [in] */ DWORD dwPropId,
            /* [in] */ DWORD dwValue) = 0;
        
        virtual HRESULT STDMETHODCALLTYPE GetHRESULT( 
            /* [in] */ DWORD dwPropId,
            /* [out] */ HRESULT __RPC_FAR *phrValue) = 0;
        
        virtual HRESULT STDMETHODCALLTYPE PutHRESULT( 
            /* [in] */ DWORD dwPropId,
            /* [in] */ HRESULT hrValue) = 0;
        
        virtual HRESULT STDMETHODCALLTYPE GetBool( 
            /* [in] */ DWORD dwPropId,
            /* [out] */ BOOL __RPC_FAR *pfValue) = 0;
        
        virtual HRESULT STDMETHODCALLTYPE PutBool( 
            /* [in] */ DWORD dwPropId,
            /* [in] */ BOOL fValue) = 0;
        
        virtual HRESULT STDMETHODCALLTYPE GetPVoid( 
            /* [in] */ DWORD dwPropId,
            /* [out] */ PVOID __RPC_FAR *pvValue) = 0;
        
        virtual HRESULT STDMETHODCALLTYPE PutPVoid( 
            /* [in] */ DWORD dwPropId,
            /* [in] */ PVOID pvValue) = 0;
        
        virtual HRESULT STDMETHODCALLTYPE GetIUnknown( 
            /* [in] */ DWORD dwPropId,
            /* [out] */ IUnknown __RPC_FAR *__RPC_FAR *pUnknown) = 0;
        
        virtual HRESULT STDMETHODCALLTYPE PutIUnknown( 
            /* [in] */ DWORD dwPropId,
            /* [in] */ IUnknown __RPC_FAR *pUnknown) = 0;
        
        virtual HRESULT STDMETHODCALLTYPE GetIMailMsgProperties( 
            /* [in] */ DWORD dwPropId,
            /* [out] */ IMailMsgProperties __RPC_FAR *__RPC_FAR *ppIMsg) = 0;
        
        virtual HRESULT STDMETHODCALLTYPE PutIMailMsgProperties( 
            /* [in] */ DWORD dwPropId,
            /* [in] */ IMailMsgProperties __RPC_FAR *pIMsg) = 0;
        
        virtual HRESULT STDMETHODCALLTYPE GetIMailMsgRecipientsAdd( 
            /* [in] */ DWORD dwPropId,
            /* [out] */ IMailMsgRecipientsAdd __RPC_FAR *__RPC_FAR *ppIMsgRecipientsAdd) = 0;
        
        virtual HRESULT STDMETHODCALLTYPE PutIMailMsgRecipientsAdd( 
            /* [in] */ DWORD dwPropId,
            /* [in] */ IMailMsgRecipientsAdd __RPC_FAR *pIMsgRecipientsAdd) = 0;
        
        virtual HRESULT STDMETHODCALLTYPE GetICategorizerItemAttributes( 
            /* [in] */ DWORD dwPropId,
            /* [out] */ ICategorizerItemAttributes __RPC_FAR *__RPC_FAR *ppICategorizerItemAttributes) = 0;
        
        virtual HRESULT STDMETHODCALLTYPE PutICategorizerItemAttributes( 
            /* [in] */ DWORD dwPropId,
            /* [in] */ ICategorizerItemAttributes __RPC_FAR *pICategorizerItemAttributes) = 0;
        
        virtual HRESULT STDMETHODCALLTYPE GetICategorizerListResolve( 
            /* [in] */ DWORD dwPropId,
            /* [out] */ ICategorizerListResolve __RPC_FAR *__RPC_FAR *ppICategorizerListResolve) = 0;
        
        virtual HRESULT STDMETHODCALLTYPE PutICategorizerListResolve( 
            /* [in] */ DWORD dwPropId,
            /* [in] */ ICategorizerListResolve __RPC_FAR *pICategorizerListResolve) = 0;
        
        virtual HRESULT STDMETHODCALLTYPE GetICategorizerMailMsgs( 
            /* [in] */ DWORD dwPropId,
            /* [out] */ ICategorizerMailMsgs __RPC_FAR *__RPC_FAR *ppICategorizerMailMsgs) = 0;
        
        virtual HRESULT STDMETHODCALLTYPE PutICategorizerMailMsgs( 
            /* [in] */ DWORD dwPropId,
            /* [in] */ ICategorizerMailMsgs __RPC_FAR *pICategorizerMailMsgs) = 0;
        
        virtual HRESULT STDMETHODCALLTYPE GetICategorizerItem( 
            /* [in] */ DWORD dwPropId,
            /* [out] */ ICategorizerItem __RPC_FAR *__RPC_FAR *ppICategorizerItem) = 0;
        
        virtual HRESULT STDMETHODCALLTYPE PutICategorizerItem( 
            /* [in] */ DWORD dwPropId,
            /* [in] */ ICategorizerItem __RPC_FAR *pICategorizerItem) = 0;
        
        virtual HRESULT STDMETHODCALLTYPE UnSetPropId( 
            /* [in] */ DWORD dwPropId) = 0;
        
    };
    
#else 	/* C style interface */

    typedef struct ICategorizerPropertiesVtbl
    {
        BEGIN_INTERFACE
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *QueryInterface )( 
            ICategorizerProperties __RPC_FAR * This,
            /* [in] */ REFIID riid,
            /* [iid_is][out] */ void __RPC_FAR *__RPC_FAR *ppvObject);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *AddRef )( 
            ICategorizerProperties __RPC_FAR * This);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *Release )( 
            ICategorizerProperties __RPC_FAR * This);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetStringA )( 
            ICategorizerProperties __RPC_FAR * This,
            /* [in] */ DWORD dwPropId,
            /* [in] */ DWORD dwcchValue,
            /* [size_is][out] */ LPSTR pszValue);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *PutStringA )( 
            ICategorizerProperties __RPC_FAR * This,
            /* [in] */ DWORD dwPropId,
            /* [unique][in] */ LPSTR pszValue);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetDWORD )( 
            ICategorizerProperties __RPC_FAR * This,
            /* [in] */ DWORD dwPropId,
            /* [out] */ DWORD __RPC_FAR *pdwValue);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *PutDWORD )( 
            ICategorizerProperties __RPC_FAR * This,
            /* [in] */ DWORD dwPropId,
            /* [in] */ DWORD dwValue);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetHRESULT )( 
            ICategorizerProperties __RPC_FAR * This,
            /* [in] */ DWORD dwPropId,
            /* [out] */ HRESULT __RPC_FAR *phrValue);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *PutHRESULT )( 
            ICategorizerProperties __RPC_FAR * This,
            /* [in] */ DWORD dwPropId,
            /* [in] */ HRESULT hrValue);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetBool )( 
            ICategorizerProperties __RPC_FAR * This,
            /* [in] */ DWORD dwPropId,
            /* [out] */ BOOL __RPC_FAR *pfValue);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *PutBool )( 
            ICategorizerProperties __RPC_FAR * This,
            /* [in] */ DWORD dwPropId,
            /* [in] */ BOOL fValue);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetPVoid )( 
            ICategorizerProperties __RPC_FAR * This,
            /* [in] */ DWORD dwPropId,
            /* [out] */ PVOID __RPC_FAR *pvValue);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *PutPVoid )( 
            ICategorizerProperties __RPC_FAR * This,
            /* [in] */ DWORD dwPropId,
            /* [in] */ PVOID pvValue);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetIUnknown )( 
            ICategorizerProperties __RPC_FAR * This,
            /* [in] */ DWORD dwPropId,
            /* [out] */ IUnknown __RPC_FAR *__RPC_FAR *pUnknown);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *PutIUnknown )( 
            ICategorizerProperties __RPC_FAR * This,
            /* [in] */ DWORD dwPropId,
            /* [in] */ IUnknown __RPC_FAR *pUnknown);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetIMailMsgProperties )( 
            ICategorizerProperties __RPC_FAR * This,
            /* [in] */ DWORD dwPropId,
            /* [out] */ IMailMsgProperties __RPC_FAR *__RPC_FAR *ppIMsg);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *PutIMailMsgProperties )( 
            ICategorizerProperties __RPC_FAR * This,
            /* [in] */ DWORD dwPropId,
            /* [in] */ IMailMsgProperties __RPC_FAR *pIMsg);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetIMailMsgRecipientsAdd )( 
            ICategorizerProperties __RPC_FAR * This,
            /* [in] */ DWORD dwPropId,
            /* [out] */ IMailMsgRecipientsAdd __RPC_FAR *__RPC_FAR *ppIMsgRecipientsAdd);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *PutIMailMsgRecipientsAdd )( 
            ICategorizerProperties __RPC_FAR * This,
            /* [in] */ DWORD dwPropId,
            /* [in] */ IMailMsgRecipientsAdd __RPC_FAR *pIMsgRecipientsAdd);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetICategorizerItemAttributes )( 
            ICategorizerProperties __RPC_FAR * This,
            /* [in] */ DWORD dwPropId,
            /* [out] */ ICategorizerItemAttributes __RPC_FAR *__RPC_FAR *ppICategorizerItemAttributes);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *PutICategorizerItemAttributes )( 
            ICategorizerProperties __RPC_FAR * This,
            /* [in] */ DWORD dwPropId,
            /* [in] */ ICategorizerItemAttributes __RPC_FAR *pICategorizerItemAttributes);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetICategorizerListResolve )( 
            ICategorizerProperties __RPC_FAR * This,
            /* [in] */ DWORD dwPropId,
            /* [out] */ ICategorizerListResolve __RPC_FAR *__RPC_FAR *ppICategorizerListResolve);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *PutICategorizerListResolve )( 
            ICategorizerProperties __RPC_FAR * This,
            /* [in] */ DWORD dwPropId,
            /* [in] */ ICategorizerListResolve __RPC_FAR *pICategorizerListResolve);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetICategorizerMailMsgs )( 
            ICategorizerProperties __RPC_FAR * This,
            /* [in] */ DWORD dwPropId,
            /* [out] */ ICategorizerMailMsgs __RPC_FAR *__RPC_FAR *ppICategorizerMailMsgs);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *PutICategorizerMailMsgs )( 
            ICategorizerProperties __RPC_FAR * This,
            /* [in] */ DWORD dwPropId,
            /* [in] */ ICategorizerMailMsgs __RPC_FAR *pICategorizerMailMsgs);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetICategorizerItem )( 
            ICategorizerProperties __RPC_FAR * This,
            /* [in] */ DWORD dwPropId,
            /* [out] */ ICategorizerItem __RPC_FAR *__RPC_FAR *ppICategorizerItem);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *PutICategorizerItem )( 
            ICategorizerProperties __RPC_FAR * This,
            /* [in] */ DWORD dwPropId,
            /* [in] */ ICategorizerItem __RPC_FAR *pICategorizerItem);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *UnSetPropId )( 
            ICategorizerProperties __RPC_FAR * This,
            /* [in] */ DWORD dwPropId);
        
        END_INTERFACE
    } ICategorizerPropertiesVtbl;

    interface ICategorizerProperties
    {
        CONST_VTBL struct ICategorizerPropertiesVtbl __RPC_FAR *lpVtbl;
    };

    

#ifdef COBJMACROS


#define ICategorizerProperties_QueryInterface(This,riid,ppvObject)	\
    (This)->lpVtbl -> QueryInterface(This,riid,ppvObject)

#define ICategorizerProperties_AddRef(This)	\
    (This)->lpVtbl -> AddRef(This)

#define ICategorizerProperties_Release(This)	\
    (This)->lpVtbl -> Release(This)


#define ICategorizerProperties_GetStringA(This,dwPropId,dwcchValue,pszValue)	\
    (This)->lpVtbl -> GetStringA(This,dwPropId,dwcchValue,pszValue)

#define ICategorizerProperties_PutStringA(This,dwPropId,pszValue)	\
    (This)->lpVtbl -> PutStringA(This,dwPropId,pszValue)

#define ICategorizerProperties_GetDWORD(This,dwPropId,pdwValue)	\
    (This)->lpVtbl -> GetDWORD(This,dwPropId,pdwValue)

#define ICategorizerProperties_PutDWORD(This,dwPropId,dwValue)	\
    (This)->lpVtbl -> PutDWORD(This,dwPropId,dwValue)

#define ICategorizerProperties_GetHRESULT(This,dwPropId,phrValue)	\
    (This)->lpVtbl -> GetHRESULT(This,dwPropId,phrValue)

#define ICategorizerProperties_PutHRESULT(This,dwPropId,hrValue)	\
    (This)->lpVtbl -> PutHRESULT(This,dwPropId,hrValue)

#define ICategorizerProperties_GetBool(This,dwPropId,pfValue)	\
    (This)->lpVtbl -> GetBool(This,dwPropId,pfValue)

#define ICategorizerProperties_PutBool(This,dwPropId,fValue)	\
    (This)->lpVtbl -> PutBool(This,dwPropId,fValue)

#define ICategorizerProperties_GetPVoid(This,dwPropId,pvValue)	\
    (This)->lpVtbl -> GetPVoid(This,dwPropId,pvValue)

#define ICategorizerProperties_PutPVoid(This,dwPropId,pvValue)	\
    (This)->lpVtbl -> PutPVoid(This,dwPropId,pvValue)

#define ICategorizerProperties_GetIUnknown(This,dwPropId,pUnknown)	\
    (This)->lpVtbl -> GetIUnknown(This,dwPropId,pUnknown)

#define ICategorizerProperties_PutIUnknown(This,dwPropId,pUnknown)	\
    (This)->lpVtbl -> PutIUnknown(This,dwPropId,pUnknown)

#define ICategorizerProperties_GetIMailMsgProperties(This,dwPropId,ppIMsg)	\
    (This)->lpVtbl -> GetIMailMsgProperties(This,dwPropId,ppIMsg)

#define ICategorizerProperties_PutIMailMsgProperties(This,dwPropId,pIMsg)	\
    (This)->lpVtbl -> PutIMailMsgProperties(This,dwPropId,pIMsg)

#define ICategorizerProperties_GetIMailMsgRecipientsAdd(This,dwPropId,ppIMsgRecipientsAdd)	\
    (This)->lpVtbl -> GetIMailMsgRecipientsAdd(This,dwPropId,ppIMsgRecipientsAdd)

#define ICategorizerProperties_PutIMailMsgRecipientsAdd(This,dwPropId,pIMsgRecipientsAdd)	\
    (This)->lpVtbl -> PutIMailMsgRecipientsAdd(This,dwPropId,pIMsgRecipientsAdd)

#define ICategorizerProperties_GetICategorizerItemAttributes(This,dwPropId,ppICategorizerItemAttributes)	\
    (This)->lpVtbl -> GetICategorizerItemAttributes(This,dwPropId,ppICategorizerItemAttributes)

#define ICategorizerProperties_PutICategorizerItemAttributes(This,dwPropId,pICategorizerItemAttributes)	\
    (This)->lpVtbl -> PutICategorizerItemAttributes(This,dwPropId,pICategorizerItemAttributes)

#define ICategorizerProperties_GetICategorizerListResolve(This,dwPropId,ppICategorizerListResolve)	\
    (This)->lpVtbl -> GetICategorizerListResolve(This,dwPropId,ppICategorizerListResolve)

#define ICategorizerProperties_PutICategorizerListResolve(This,dwPropId,pICategorizerListResolve)	\
    (This)->lpVtbl -> PutICategorizerListResolve(This,dwPropId,pICategorizerListResolve)

#define ICategorizerProperties_GetICategorizerMailMsgs(This,dwPropId,ppICategorizerMailMsgs)	\
    (This)->lpVtbl -> GetICategorizerMailMsgs(This,dwPropId,ppICategorizerMailMsgs)

#define ICategorizerProperties_PutICategorizerMailMsgs(This,dwPropId,pICategorizerMailMsgs)	\
    (This)->lpVtbl -> PutICategorizerMailMsgs(This,dwPropId,pICategorizerMailMsgs)

#define ICategorizerProperties_GetICategorizerItem(This,dwPropId,ppICategorizerItem)	\
    (This)->lpVtbl -> GetICategorizerItem(This,dwPropId,ppICategorizerItem)

#define ICategorizerProperties_PutICategorizerItem(This,dwPropId,pICategorizerItem)	\
    (This)->lpVtbl -> PutICategorizerItem(This,dwPropId,pICategorizerItem)

#define ICategorizerProperties_UnSetPropId(This,dwPropId)	\
    (This)->lpVtbl -> UnSetPropId(This,dwPropId)

#endif /* COBJMACROS */


#endif 	/* C style interface */



HRESULT STDMETHODCALLTYPE ICategorizerProperties_GetStringA_Proxy( 
    ICategorizerProperties __RPC_FAR * This,
    /* [in] */ DWORD dwPropId,
    /* [in] */ DWORD dwcchValue,
    /* [size_is][out] */ LPSTR pszValue);


void __RPC_STUB ICategorizerProperties_GetStringA_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


HRESULT STDMETHODCALLTYPE ICategorizerProperties_PutStringA_Proxy( 
    ICategorizerProperties __RPC_FAR * This,
    /* [in] */ DWORD dwPropId,
    /* [unique][in] */ LPSTR pszValue);


void __RPC_STUB ICategorizerProperties_PutStringA_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


HRESULT STDMETHODCALLTYPE ICategorizerProperties_GetDWORD_Proxy( 
    ICategorizerProperties __RPC_FAR * This,
    /* [in] */ DWORD dwPropId,
    /* [out] */ DWORD __RPC_FAR *pdwValue);


void __RPC_STUB ICategorizerProperties_GetDWORD_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


HRESULT STDMETHODCALLTYPE ICategorizerProperties_PutDWORD_Proxy( 
    ICategorizerProperties __RPC_FAR * This,
    /* [in] */ DWORD dwPropId,
    /* [in] */ DWORD dwValue);


void __RPC_STUB ICategorizerProperties_PutDWORD_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


HRESULT STDMETHODCALLTYPE ICategorizerProperties_GetHRESULT_Proxy( 
    ICategorizerProperties __RPC_FAR * This,
    /* [in] */ DWORD dwPropId,
    /* [out] */ HRESULT __RPC_FAR *phrValue);


void __RPC_STUB ICategorizerProperties_GetHRESULT_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


HRESULT STDMETHODCALLTYPE ICategorizerProperties_PutHRESULT_Proxy( 
    ICategorizerProperties __RPC_FAR * This,
    /* [in] */ DWORD dwPropId,
    /* [in] */ HRESULT hrValue);


void __RPC_STUB ICategorizerProperties_PutHRESULT_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


HRESULT STDMETHODCALLTYPE ICategorizerProperties_GetBool_Proxy( 
    ICategorizerProperties __RPC_FAR * This,
    /* [in] */ DWORD dwPropId,
    /* [out] */ BOOL __RPC_FAR *pfValue);


void __RPC_STUB ICategorizerProperties_GetBool_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


HRESULT STDMETHODCALLTYPE ICategorizerProperties_PutBool_Proxy( 
    ICategorizerProperties __RPC_FAR * This,
    /* [in] */ DWORD dwPropId,
    /* [in] */ BOOL fValue);


void __RPC_STUB ICategorizerProperties_PutBool_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


HRESULT STDMETHODCALLTYPE ICategorizerProperties_GetPVoid_Proxy( 
    ICategorizerProperties __RPC_FAR * This,
    /* [in] */ DWORD dwPropId,
    /* [out] */ PVOID __RPC_FAR *pvValue);


void __RPC_STUB ICategorizerProperties_GetPVoid_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


HRESULT STDMETHODCALLTYPE ICategorizerProperties_PutPVoid_Proxy( 
    ICategorizerProperties __RPC_FAR * This,
    /* [in] */ DWORD dwPropId,
    /* [in] */ PVOID pvValue);


void __RPC_STUB ICategorizerProperties_PutPVoid_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


HRESULT STDMETHODCALLTYPE ICategorizerProperties_GetIUnknown_Proxy( 
    ICategorizerProperties __RPC_FAR * This,
    /* [in] */ DWORD dwPropId,
    /* [out] */ IUnknown __RPC_FAR *__RPC_FAR *pUnknown);


void __RPC_STUB ICategorizerProperties_GetIUnknown_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


HRESULT STDMETHODCALLTYPE ICategorizerProperties_PutIUnknown_Proxy( 
    ICategorizerProperties __RPC_FAR * This,
    /* [in] */ DWORD dwPropId,
    /* [in] */ IUnknown __RPC_FAR *pUnknown);


void __RPC_STUB ICategorizerProperties_PutIUnknown_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


HRESULT STDMETHODCALLTYPE ICategorizerProperties_GetIMailMsgProperties_Proxy( 
    ICategorizerProperties __RPC_FAR * This,
    /* [in] */ DWORD dwPropId,
    /* [out] */ IMailMsgProperties __RPC_FAR *__RPC_FAR *ppIMsg);


void __RPC_STUB ICategorizerProperties_GetIMailMsgProperties_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


HRESULT STDMETHODCALLTYPE ICategorizerProperties_PutIMailMsgProperties_Proxy( 
    ICategorizerProperties __RPC_FAR * This,
    /* [in] */ DWORD dwPropId,
    /* [in] */ IMailMsgProperties __RPC_FAR *pIMsg);


void __RPC_STUB ICategorizerProperties_PutIMailMsgProperties_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


HRESULT STDMETHODCALLTYPE ICategorizerProperties_GetIMailMsgRecipientsAdd_Proxy( 
    ICategorizerProperties __RPC_FAR * This,
    /* [in] */ DWORD dwPropId,
    /* [out] */ IMailMsgRecipientsAdd __RPC_FAR *__RPC_FAR *ppIMsgRecipientsAdd);


void __RPC_STUB ICategorizerProperties_GetIMailMsgRecipientsAdd_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


HRESULT STDMETHODCALLTYPE ICategorizerProperties_PutIMailMsgRecipientsAdd_Proxy( 
    ICategorizerProperties __RPC_FAR * This,
    /* [in] */ DWORD dwPropId,
    /* [in] */ IMailMsgRecipientsAdd __RPC_FAR *pIMsgRecipientsAdd);


void __RPC_STUB ICategorizerProperties_PutIMailMsgRecipientsAdd_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


HRESULT STDMETHODCALLTYPE ICategorizerProperties_GetICategorizerItemAttributes_Proxy( 
    ICategorizerProperties __RPC_FAR * This,
    /* [in] */ DWORD dwPropId,
    /* [out] */ ICategorizerItemAttributes __RPC_FAR *__RPC_FAR *ppICategorizerItemAttributes);


void __RPC_STUB ICategorizerProperties_GetICategorizerItemAttributes_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


HRESULT STDMETHODCALLTYPE ICategorizerProperties_PutICategorizerItemAttributes_Proxy( 
    ICategorizerProperties __RPC_FAR * This,
    /* [in] */ DWORD dwPropId,
    /* [in] */ ICategorizerItemAttributes __RPC_FAR *pICategorizerItemAttributes);


void __RPC_STUB ICategorizerProperties_PutICategorizerItemAttributes_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


HRESULT STDMETHODCALLTYPE ICategorizerProperties_GetICategorizerListResolve_Proxy( 
    ICategorizerProperties __RPC_FAR * This,
    /* [in] */ DWORD dwPropId,
    /* [out] */ ICategorizerListResolve __RPC_FAR *__RPC_FAR *ppICategorizerListResolve);


void __RPC_STUB ICategorizerProperties_GetICategorizerListResolve_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


HRESULT STDMETHODCALLTYPE ICategorizerProperties_PutICategorizerListResolve_Proxy( 
    ICategorizerProperties __RPC_FAR * This,
    /* [in] */ DWORD dwPropId,
    /* [in] */ ICategorizerListResolve __RPC_FAR *pICategorizerListResolve);


void __RPC_STUB ICategorizerProperties_PutICategorizerListResolve_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


HRESULT STDMETHODCALLTYPE ICategorizerProperties_GetICategorizerMailMsgs_Proxy( 
    ICategorizerProperties __RPC_FAR * This,
    /* [in] */ DWORD dwPropId,
    /* [out] */ ICategorizerMailMsgs __RPC_FAR *__RPC_FAR *ppICategorizerMailMsgs);


void __RPC_STUB ICategorizerProperties_GetICategorizerMailMsgs_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


HRESULT STDMETHODCALLTYPE ICategorizerProperties_PutICategorizerMailMsgs_Proxy( 
    ICategorizerProperties __RPC_FAR * This,
    /* [in] */ DWORD dwPropId,
    /* [in] */ ICategorizerMailMsgs __RPC_FAR *pICategorizerMailMsgs);


void __RPC_STUB ICategorizerProperties_PutICategorizerMailMsgs_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


HRESULT STDMETHODCALLTYPE ICategorizerProperties_GetICategorizerItem_Proxy( 
    ICategorizerProperties __RPC_FAR * This,
    /* [in] */ DWORD dwPropId,
    /* [out] */ ICategorizerItem __RPC_FAR *__RPC_FAR *ppICategorizerItem);


void __RPC_STUB ICategorizerProperties_GetICategorizerItem_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


HRESULT STDMETHODCALLTYPE ICategorizerProperties_PutICategorizerItem_Proxy( 
    ICategorizerProperties __RPC_FAR * This,
    /* [in] */ DWORD dwPropId,
    /* [in] */ ICategorizerItem __RPC_FAR *pICategorizerItem);


void __RPC_STUB ICategorizerProperties_PutICategorizerItem_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


HRESULT STDMETHODCALLTYPE ICategorizerProperties_UnSetPropId_Proxy( 
    ICategorizerProperties __RPC_FAR * This,
    /* [in] */ DWORD dwPropId);


void __RPC_STUB ICategorizerProperties_UnSetPropId_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);



#endif 	/* __ICategorizerProperties_INTERFACE_DEFINED__ */


/* interface __MIDL_itf_SmtpEvent_0289 */
/* [local] */ 

typedef /* [public][v1_enum] */ 
enum __MIDL___MIDL_itf_SmtpEvent_0289_0001
    {	DSPARAMETER_LDAPHOST	= 0,
	DSPARAMETER_LDAPBINDTYPE	= DSPARAMETER_LDAPHOST + 1,
	DSPARAMETER_LDAPDOMAIN	= DSPARAMETER_LDAPBINDTYPE + 1,
	DSPARAMETER_LDAPACCOUNT	= DSPARAMETER_LDAPDOMAIN + 1,
	DSPARAMETER_LDAPPASSWORD	= DSPARAMETER_LDAPACCOUNT + 1,
	DSPARAMETER_LDAPNAMINGCONTEXT	= DSPARAMETER_LDAPPASSWORD + 1,
	DSPARAMETER_LDAPPORT	= DSPARAMETER_LDAPNAMINGCONTEXT + 1,
	DSPARAMETER_BATCHINGLIMIT	= DSPARAMETER_LDAPPORT + 1,
	DSPARAMETER_SEARCHATTRIBUTE_SMTP	= DSPARAMETER_BATCHINGLIMIT + 1,
	DSPARAMETER_SEARCHFILTER_SMTP	= DSPARAMETER_SEARCHATTRIBUTE_SMTP + 1,
	DSPARAMETER_SEARCHATTRIBUTE_X500	= DSPARAMETER_SEARCHFILTER_SMTP + 1,
	DSPARAMETER_SEARCHFILTER_X500	= DSPARAMETER_SEARCHATTRIBUTE_X500 + 1,
	DSPARAMETER_SEARCHATTRIBUTE_X400	= DSPARAMETER_SEARCHFILTER_X500 + 1,
	DSPARAMETER_SEARCHFILTER_X400	= DSPARAMETER_SEARCHATTRIBUTE_X400 + 1,
	DSPARAMETER_SEARCHATTRIBUTE_LEGACYEXDN	= DSPARAMETER_SEARCHFILTER_X400 + 1,
	DSPARAMETER_SEARCHFILTER_LEGACYEXDN	= DSPARAMETER_SEARCHATTRIBUTE_LEGACYEXDN + 1,
	DSPARAMETER_SEARCHATTRIBUTE_RDN	= DSPARAMETER_SEARCHFILTER_LEGACYEXDN + 1,
	DSPARAMETER_SEARCHFILTER_RDN	= DSPARAMETER_SEARCHATTRIBUTE_RDN + 1,
	DSPARAMETER_SEARCHATTRIBUTE_DN	= DSPARAMETER_SEARCHFILTER_RDN + 1,
	DSPARAMETER_SEARCHFILTER_DN	= DSPARAMETER_SEARCHATTRIBUTE_DN + 1,
	DSPARAMETER_SEARCHATTRIBUTE_FOREIGNADDRESS	= DSPARAMETER_SEARCHFILTER_DN + 1,
	DSPARAMETER_SEARCHFILTER_FOREIGNADDRESS	= DSPARAMETER_SEARCHATTRIBUTE_FOREIGNADDRESS + 1,
	DSPARAMETER_ATTRIBUTE_OBJECTCLASS	= DSPARAMETER_SEARCHFILTER_FOREIGNADDRESS + 1,
	DSPARAMETER_ATTRIBUTE_DEFAULT_SMTP	= DSPARAMETER_ATTRIBUTE_OBJECTCLASS + 1,
	DSPARAMETER_ATTRIBUTE_DEFAULT_X500	= DSPARAMETER_ATTRIBUTE_DEFAULT_SMTP + 1,
	DSPARAMETER_ATTRIBUTE_DEFAULT_X400	= DSPARAMETER_ATTRIBUTE_DEFAULT_X500 + 1,
	DSPARAMETER_ATTRIBUTE_DEFAULT_DN	= DSPARAMETER_ATTRIBUTE_DEFAULT_X400 + 1,
	DSPARAMETER_ATTRIBUTE_DEFAULT_LEGACYEXDN	= DSPARAMETER_ATTRIBUTE_DEFAULT_DN + 1,
	DSPARAMETER_ATTRIBUTE_FORWARD_SMTP	= DSPARAMETER_ATTRIBUTE_DEFAULT_LEGACYEXDN + 1,
	DSPARAMETER_ATTRIBUTE_DL_MEMBERS	= DSPARAMETER_ATTRIBUTE_FORWARD_SMTP + 1,
	DSPARAMETER_ATTRIBUTE_DL_DYNAMICFILTER	= DSPARAMETER_ATTRIBUTE_DL_MEMBERS + 1,
	DSPARAMETER_ATTRIBUTE_DL_DYNAMICBASEDN	= DSPARAMETER_ATTRIBUTE_DL_DYNAMICFILTER + 1,
	DSPARAMETER_OBJECTCLASS_USER	= DSPARAMETER_ATTRIBUTE_DL_DYNAMICBASEDN + 1,
	DSPARAMETER_OBJECTCLASS_DL_X500	= DSPARAMETER_OBJECTCLASS_USER + 1,
	DSPARAMETER_OBJECTCLASS_DL_SMTP	= DSPARAMETER_OBJECTCLASS_DL_X500 + 1,
	DSPARAMETER_OBJECTCLASS_DL_DYNAMIC	= DSPARAMETER_OBJECTCLASS_DL_SMTP + 1,
	DSPARAMETER_ENDENUMMESS	= DSPARAMETER_OBJECTCLASS_DL_DYNAMIC + 1,
	DSPARAMETER_INVALID	= DSPARAMETER_ENDENUMMESS + 1
    }	eDSPARAMETER;



extern RPC_IF_HANDLE __MIDL_itf_SmtpEvent_0289_v0_0_c_ifspec;
extern RPC_IF_HANDLE __MIDL_itf_SmtpEvent_0289_v0_0_s_ifspec;

#ifndef __ICategorizerParameters_INTERFACE_DEFINED__
#define __ICategorizerParameters_INTERFACE_DEFINED__

/* interface ICategorizerParameters */
/* [unique][helpstring][uuid][local][object] */ 


EXTERN_C const IID IID_ICategorizerParameters;

#if defined(__cplusplus) && !defined(CINTERFACE)
    
    MIDL_INTERFACE("86F9DA7B-EB6E-11d1-9DF3-00C04FA322BA")
    ICategorizerParameters : public IUnknown
    {
    public:
        virtual HRESULT STDMETHODCALLTYPE GetDSParameterA( 
            /* [in] */ DWORD dwDSParameter,
            /* [out] */ LPSTR __RPC_FAR *ppszValue) = 0;
        
        virtual HRESULT STDMETHODCALLTYPE SetDSParameterA( 
            /* [in] */ DWORD dwDSParameter,
            /* [unique][in] */ LPCSTR pszValue) = 0;
        
        virtual HRESULT STDMETHODCALLTYPE RequestAttributeA( 
            /* [unique][in] */ LPCSTR pszName) = 0;
        
        virtual HRESULT STDMETHODCALLTYPE GetAllAttributes( 
            /* [out] */ LPSTR __RPC_FAR *__RPC_FAR *prgszAllAttributes) = 0;
        
        virtual HRESULT STDMETHODCALLTYPE ReserveICatItemPropIds( 
            /* [in] */ DWORD dwNumPropIdsRequested,
            /* [out] */ DWORD __RPC_FAR *pdwBeginningPropId) = 0;
        
        virtual HRESULT STDMETHODCALLTYPE ReserveICatListResolvePropIds( 
            /* [in] */ DWORD dwNumPropIdsRequested,
            /* [out] */ DWORD __RPC_FAR *pdwBeginningPropId) = 0;
        
        virtual HRESULT STDMETHODCALLTYPE GetCCatConfigInfo( 
            /* [out] */ PCCATCONFIGINFO __RPC_FAR *ppCCatConfigInfo) = 0;
        
    };
    
#else 	/* C style interface */

    typedef struct ICategorizerParametersVtbl
    {
        BEGIN_INTERFACE
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *QueryInterface )( 
            ICategorizerParameters __RPC_FAR * This,
            /* [in] */ REFIID riid,
            /* [iid_is][out] */ void __RPC_FAR *__RPC_FAR *ppvObject);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *AddRef )( 
            ICategorizerParameters __RPC_FAR * This);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *Release )( 
            ICategorizerParameters __RPC_FAR * This);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetDSParameterA )( 
            ICategorizerParameters __RPC_FAR * This,
            /* [in] */ DWORD dwDSParameter,
            /* [out] */ LPSTR __RPC_FAR *ppszValue);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *SetDSParameterA )( 
            ICategorizerParameters __RPC_FAR * This,
            /* [in] */ DWORD dwDSParameter,
            /* [unique][in] */ LPCSTR pszValue);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *RequestAttributeA )( 
            ICategorizerParameters __RPC_FAR * This,
            /* [unique][in] */ LPCSTR pszName);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetAllAttributes )( 
            ICategorizerParameters __RPC_FAR * This,
            /* [out] */ LPSTR __RPC_FAR *__RPC_FAR *prgszAllAttributes);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *ReserveICatItemPropIds )( 
            ICategorizerParameters __RPC_FAR * This,
            /* [in] */ DWORD dwNumPropIdsRequested,
            /* [out] */ DWORD __RPC_FAR *pdwBeginningPropId);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *ReserveICatListResolvePropIds )( 
            ICategorizerParameters __RPC_FAR * This,
            /* [in] */ DWORD dwNumPropIdsRequested,
            /* [out] */ DWORD __RPC_FAR *pdwBeginningPropId);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetCCatConfigInfo )( 
            ICategorizerParameters __RPC_FAR * This,
            /* [out] */ PCCATCONFIGINFO __RPC_FAR *ppCCatConfigInfo);
        
        END_INTERFACE
    } ICategorizerParametersVtbl;

    interface ICategorizerParameters
    {
        CONST_VTBL struct ICategorizerParametersVtbl __RPC_FAR *lpVtbl;
    };

    

#ifdef COBJMACROS


#define ICategorizerParameters_QueryInterface(This,riid,ppvObject)	\
    (This)->lpVtbl -> QueryInterface(This,riid,ppvObject)

#define ICategorizerParameters_AddRef(This)	\
    (This)->lpVtbl -> AddRef(This)

#define ICategorizerParameters_Release(This)	\
    (This)->lpVtbl -> Release(This)


#define ICategorizerParameters_GetDSParameterA(This,dwDSParameter,ppszValue)	\
    (This)->lpVtbl -> GetDSParameterA(This,dwDSParameter,ppszValue)

#define ICategorizerParameters_SetDSParameterA(This,dwDSParameter,pszValue)	\
    (This)->lpVtbl -> SetDSParameterA(This,dwDSParameter,pszValue)

#define ICategorizerParameters_RequestAttributeA(This,pszName)	\
    (This)->lpVtbl -> RequestAttributeA(This,pszName)

#define ICategorizerParameters_GetAllAttributes(This,prgszAllAttributes)	\
    (This)->lpVtbl -> GetAllAttributes(This,prgszAllAttributes)

#define ICategorizerParameters_ReserveICatItemPropIds(This,dwNumPropIdsRequested,pdwBeginningPropId)	\
    (This)->lpVtbl -> ReserveICatItemPropIds(This,dwNumPropIdsRequested,pdwBeginningPropId)

#define ICategorizerParameters_ReserveICatListResolvePropIds(This,dwNumPropIdsRequested,pdwBeginningPropId)	\
    (This)->lpVtbl -> ReserveICatListResolvePropIds(This,dwNumPropIdsRequested,pdwBeginningPropId)

#define ICategorizerParameters_GetCCatConfigInfo(This,ppCCatConfigInfo)	\
    (This)->lpVtbl -> GetCCatConfigInfo(This,ppCCatConfigInfo)

#endif /* COBJMACROS */


#endif 	/* C style interface */



HRESULT STDMETHODCALLTYPE ICategorizerParameters_GetDSParameterA_Proxy( 
    ICategorizerParameters __RPC_FAR * This,
    /* [in] */ DWORD dwDSParameter,
    /* [out] */ LPSTR __RPC_FAR *ppszValue);


void __RPC_STUB ICategorizerParameters_GetDSParameterA_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


HRESULT STDMETHODCALLTYPE ICategorizerParameters_SetDSParameterA_Proxy( 
    ICategorizerParameters __RPC_FAR * This,
    /* [in] */ DWORD dwDSParameter,
    /* [unique][in] */ LPCSTR pszValue);


void __RPC_STUB ICategorizerParameters_SetDSParameterA_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


HRESULT STDMETHODCALLTYPE ICategorizerParameters_RequestAttributeA_Proxy( 
    ICategorizerParameters __RPC_FAR * This,
    /* [unique][in] */ LPCSTR pszName);


void __RPC_STUB ICategorizerParameters_RequestAttributeA_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


HRESULT STDMETHODCALLTYPE ICategorizerParameters_GetAllAttributes_Proxy( 
    ICategorizerParameters __RPC_FAR * This,
    /* [out] */ LPSTR __RPC_FAR *__RPC_FAR *prgszAllAttributes);


void __RPC_STUB ICategorizerParameters_GetAllAttributes_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


HRESULT STDMETHODCALLTYPE ICategorizerParameters_ReserveICatItemPropIds_Proxy( 
    ICategorizerParameters __RPC_FAR * This,
    /* [in] */ DWORD dwNumPropIdsRequested,
    /* [out] */ DWORD __RPC_FAR *pdwBeginningPropId);


void __RPC_STUB ICategorizerParameters_ReserveICatItemPropIds_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


HRESULT STDMETHODCALLTYPE ICategorizerParameters_ReserveICatListResolvePropIds_Proxy( 
    ICategorizerParameters __RPC_FAR * This,
    /* [in] */ DWORD dwNumPropIdsRequested,
    /* [out] */ DWORD __RPC_FAR *pdwBeginningPropId);


void __RPC_STUB ICategorizerParameters_ReserveICatListResolvePropIds_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


HRESULT STDMETHODCALLTYPE ICategorizerParameters_GetCCatConfigInfo_Proxy( 
    ICategorizerParameters __RPC_FAR * This,
    /* [out] */ PCCATCONFIGINFO __RPC_FAR *ppCCatConfigInfo);


void __RPC_STUB ICategorizerParameters_GetCCatConfigInfo_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);



#endif 	/* __ICategorizerParameters_INTERFACE_DEFINED__ */


#ifndef __ICategorizerQueries_INTERFACE_DEFINED__
#define __ICategorizerQueries_INTERFACE_DEFINED__

/* interface ICategorizerQueries */
/* [unique][helpstring][uuid][object] */ 


EXTERN_C const IID IID_ICategorizerQueries;

#if defined(__cplusplus) && !defined(CINTERFACE)
    
    MIDL_INTERFACE("86F9DA7D-EB6E-11d1-9DF3-00C04FA322BA")
    ICategorizerQueries : public IUnknown
    {
    public:
        virtual HRESULT STDMETHODCALLTYPE SetQueryString( 
            /* [unique][in] */ LPSTR pszQueryString) = 0;
        
        virtual HRESULT STDMETHODCALLTYPE GetQueryString( 
            /* [out] */ LPSTR __RPC_FAR *ppszQueryString) = 0;
        
    };
    
#else 	/* C style interface */

    typedef struct ICategorizerQueriesVtbl
    {
        BEGIN_INTERFACE
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *QueryInterface )( 
            ICategorizerQueries __RPC_FAR * This,
            /* [in] */ REFIID riid,
            /* [iid_is][out] */ void __RPC_FAR *__RPC_FAR *ppvObject);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *AddRef )( 
            ICategorizerQueries __RPC_FAR * This);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *Release )( 
            ICategorizerQueries __RPC_FAR * This);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *SetQueryString )( 
            ICategorizerQueries __RPC_FAR * This,
            /* [unique][in] */ LPSTR pszQueryString);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetQueryString )( 
            ICategorizerQueries __RPC_FAR * This,
            /* [out] */ LPSTR __RPC_FAR *ppszQueryString);
        
        END_INTERFACE
    } ICategorizerQueriesVtbl;

    interface ICategorizerQueries
    {
        CONST_VTBL struct ICategorizerQueriesVtbl __RPC_FAR *lpVtbl;
    };

    

#ifdef COBJMACROS


#define ICategorizerQueries_QueryInterface(This,riid,ppvObject)	\
    (This)->lpVtbl -> QueryInterface(This,riid,ppvObject)

#define ICategorizerQueries_AddRef(This)	\
    (This)->lpVtbl -> AddRef(This)

#define ICategorizerQueries_Release(This)	\
    (This)->lpVtbl -> Release(This)


#define ICategorizerQueries_SetQueryString(This,pszQueryString)	\
    (This)->lpVtbl -> SetQueryString(This,pszQueryString)

#define ICategorizerQueries_GetQueryString(This,ppszQueryString)	\
    (This)->lpVtbl -> GetQueryString(This,ppszQueryString)

#endif /* COBJMACROS */


#endif 	/* C style interface */



HRESULT STDMETHODCALLTYPE ICategorizerQueries_SetQueryString_Proxy( 
    ICategorizerQueries __RPC_FAR * This,
    /* [unique][in] */ LPSTR pszQueryString);


void __RPC_STUB ICategorizerQueries_SetQueryString_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


HRESULT STDMETHODCALLTYPE ICategorizerQueries_GetQueryString_Proxy( 
    ICategorizerQueries __RPC_FAR * This,
    /* [out] */ LPSTR __RPC_FAR *ppszQueryString);


void __RPC_STUB ICategorizerQueries_GetQueryString_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);



#endif 	/* __ICategorizerQueries_INTERFACE_DEFINED__ */


/* interface __MIDL_itf_SmtpEvent_0291 */
/* [local] */ 

typedef PVOID CATMAILMSG_ENUMERATOR;

typedef PVOID __RPC_FAR *PCATMAILMSG_ENUMERATOR;



extern RPC_IF_HANDLE __MIDL_itf_SmtpEvent_0291_v0_0_c_ifspec;
extern RPC_IF_HANDLE __MIDL_itf_SmtpEvent_0291_v0_0_s_ifspec;

#ifndef __ICategorizerMailMsgs_INTERFACE_DEFINED__
#define __ICategorizerMailMsgs_INTERFACE_DEFINED__

/* interface ICategorizerMailMsgs */
/* [unique][helpstring][uuid][local][object] */ 


EXTERN_C const IID IID_ICategorizerMailMsgs;

#if defined(__cplusplus) && !defined(CINTERFACE)
    
    MIDL_INTERFACE("86F9DA80-EB6E-11d1-9DF3-00C04FA322BA")
    ICategorizerMailMsgs : public IUnknown
    {
    public:
        virtual HRESULT STDMETHODCALLTYPE GetMailMsg( 
            /* [in] */ DWORD dwFlags,
            /* [out] */ IMailMsgProperties __RPC_FAR *__RPC_FAR *ppIMailMsgProperties,
            /* [out] */ IMailMsgRecipientsAdd __RPC_FAR *__RPC_FAR *ppIMailMsgRecipientsAdd,
            /* [out] */ BOOL __RPC_FAR *pfCreated) = 0;
        
        virtual HRESULT STDMETHODCALLTYPE ReBindMailMsg( 
            /* [in] */ DWORD dwFlags,
            /* [in] */ IUnknown __RPC_FAR *pStoreDriver) = 0;
        
        virtual HRESULT STDMETHODCALLTYPE BeginMailMsgEnumeration( 
            /* [in] */ PCATMAILMSG_ENUMERATOR penumerator) = 0;
        
        virtual HRESULT STDMETHODCALLTYPE GetNextMailMsg( 
            /* [in] */ PCATMAILMSG_ENUMERATOR penumerator,
            /* [out] */ DWORD __RPC_FAR *pdwFlags,
            /* [out] */ IMailMsgProperties __RPC_FAR *__RPC_FAR *ppIMailMsgProperties,
            /* [out] */ IMailMsgRecipientsAdd __RPC_FAR *__RPC_FAR *ppIMailMsgRecipientsAdd) = 0;
        
        virtual HRESULT STDMETHODCALLTYPE EndMailMsgEnumeration( 
            /* [in] */ PCATMAILMSG_ENUMERATOR penumerator) = 0;
        
    };
    
#else 	/* C style interface */

    typedef struct ICategorizerMailMsgsVtbl
    {
        BEGIN_INTERFACE
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *QueryInterface )( 
            ICategorizerMailMsgs __RPC_FAR * This,
            /* [in] */ REFIID riid,
            /* [iid_is][out] */ void __RPC_FAR *__RPC_FAR *ppvObject);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *AddRef )( 
            ICategorizerMailMsgs __RPC_FAR * This);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *Release )( 
            ICategorizerMailMsgs __RPC_FAR * This);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetMailMsg )( 
            ICategorizerMailMsgs __RPC_FAR * This,
            /* [in] */ DWORD dwFlags,
            /* [out] */ IMailMsgProperties __RPC_FAR *__RPC_FAR *ppIMailMsgProperties,
            /* [out] */ IMailMsgRecipientsAdd __RPC_FAR *__RPC_FAR *ppIMailMsgRecipientsAdd,
            /* [out] */ BOOL __RPC_FAR *pfCreated);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *ReBindMailMsg )( 
            ICategorizerMailMsgs __RPC_FAR * This,
            /* [in] */ DWORD dwFlags,
            /* [in] */ IUnknown __RPC_FAR *pStoreDriver);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *BeginMailMsgEnumeration )( 
            ICategorizerMailMsgs __RPC_FAR * This,
            /* [in] */ PCATMAILMSG_ENUMERATOR penumerator);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetNextMailMsg )( 
            ICategorizerMailMsgs __RPC_FAR * This,
            /* [in] */ PCATMAILMSG_ENUMERATOR penumerator,
            /* [out] */ DWORD __RPC_FAR *pdwFlags,
            /* [out] */ IMailMsgProperties __RPC_FAR *__RPC_FAR *ppIMailMsgProperties,
            /* [out] */ IMailMsgRecipientsAdd __RPC_FAR *__RPC_FAR *ppIMailMsgRecipientsAdd);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *EndMailMsgEnumeration )( 
            ICategorizerMailMsgs __RPC_FAR * This,
            /* [in] */ PCATMAILMSG_ENUMERATOR penumerator);
        
        END_INTERFACE
    } ICategorizerMailMsgsVtbl;

    interface ICategorizerMailMsgs
    {
        CONST_VTBL struct ICategorizerMailMsgsVtbl __RPC_FAR *lpVtbl;
    };

    

#ifdef COBJMACROS


#define ICategorizerMailMsgs_QueryInterface(This,riid,ppvObject)	\
    (This)->lpVtbl -> QueryInterface(This,riid,ppvObject)

#define ICategorizerMailMsgs_AddRef(This)	\
    (This)->lpVtbl -> AddRef(This)

#define ICategorizerMailMsgs_Release(This)	\
    (This)->lpVtbl -> Release(This)


#define ICategorizerMailMsgs_GetMailMsg(This,dwFlags,ppIMailMsgProperties,ppIMailMsgRecipientsAdd,pfCreated)	\
    (This)->lpVtbl -> GetMailMsg(This,dwFlags,ppIMailMsgProperties,ppIMailMsgRecipientsAdd,pfCreated)

#define ICategorizerMailMsgs_ReBindMailMsg(This,dwFlags,pStoreDriver)	\
    (This)->lpVtbl -> ReBindMailMsg(This,dwFlags,pStoreDriver)

#define ICategorizerMailMsgs_BeginMailMsgEnumeration(This,penumerator)	\
    (This)->lpVtbl -> BeginMailMsgEnumeration(This,penumerator)

#define ICategorizerMailMsgs_GetNextMailMsg(This,penumerator,pdwFlags,ppIMailMsgProperties,ppIMailMsgRecipientsAdd)	\
    (This)->lpVtbl -> GetNextMailMsg(This,penumerator,pdwFlags,ppIMailMsgProperties,ppIMailMsgRecipientsAdd)

#define ICategorizerMailMsgs_EndMailMsgEnumeration(This,penumerator)	\
    (This)->lpVtbl -> EndMailMsgEnumeration(This,penumerator)

#endif /* COBJMACROS */


#endif 	/* C style interface */



HRESULT STDMETHODCALLTYPE ICategorizerMailMsgs_GetMailMsg_Proxy( 
    ICategorizerMailMsgs __RPC_FAR * This,
    /* [in] */ DWORD dwFlags,
    /* [out] */ IMailMsgProperties __RPC_FAR *__RPC_FAR *ppIMailMsgProperties,
    /* [out] */ IMailMsgRecipientsAdd __RPC_FAR *__RPC_FAR *ppIMailMsgRecipientsAdd,
    /* [out] */ BOOL __RPC_FAR *pfCreated);


void __RPC_STUB ICategorizerMailMsgs_GetMailMsg_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


HRESULT STDMETHODCALLTYPE ICategorizerMailMsgs_ReBindMailMsg_Proxy( 
    ICategorizerMailMsgs __RPC_FAR * This,
    /* [in] */ DWORD dwFlags,
    /* [in] */ IUnknown __RPC_FAR *pStoreDriver);


void __RPC_STUB ICategorizerMailMsgs_ReBindMailMsg_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


HRESULT STDMETHODCALLTYPE ICategorizerMailMsgs_BeginMailMsgEnumeration_Proxy( 
    ICategorizerMailMsgs __RPC_FAR * This,
    /* [in] */ PCATMAILMSG_ENUMERATOR penumerator);


void __RPC_STUB ICategorizerMailMsgs_BeginMailMsgEnumeration_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


HRESULT STDMETHODCALLTYPE ICategorizerMailMsgs_GetNextMailMsg_Proxy( 
    ICategorizerMailMsgs __RPC_FAR * This,
    /* [in] */ PCATMAILMSG_ENUMERATOR penumerator,
    /* [out] */ DWORD __RPC_FAR *pdwFlags,
    /* [out] */ IMailMsgProperties __RPC_FAR *__RPC_FAR *ppIMailMsgProperties,
    /* [out] */ IMailMsgRecipientsAdd __RPC_FAR *__RPC_FAR *ppIMailMsgRecipientsAdd);


void __RPC_STUB ICategorizerMailMsgs_GetNextMailMsg_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


HRESULT STDMETHODCALLTYPE ICategorizerMailMsgs_EndMailMsgEnumeration_Proxy( 
    ICategorizerMailMsgs __RPC_FAR * This,
    /* [in] */ PCATMAILMSG_ENUMERATOR penumerator);


void __RPC_STUB ICategorizerMailMsgs_EndMailMsgEnumeration_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);



#endif 	/* __ICategorizerMailMsgs_INTERFACE_DEFINED__ */


/* interface __MIDL_itf_SmtpEvent_0292 */
/* [local] */ 

typedef struct _tagAttributeEnumerator
    {
    PVOID pvBase;
    PVOID pvCurrent;
    PVOID pvContext;
    }	ATTRIBUTE_ENUMERATOR;

typedef struct _tagAttributeEnumerator __RPC_FAR *PATTRIBUTE_ENUMERATOR;



extern RPC_IF_HANDLE __MIDL_itf_SmtpEvent_0292_v0_0_c_ifspec;
extern RPC_IF_HANDLE __MIDL_itf_SmtpEvent_0292_v0_0_s_ifspec;

#ifndef __ICategorizerItemAttributes_INTERFACE_DEFINED__
#define __ICategorizerItemAttributes_INTERFACE_DEFINED__

/* interface ICategorizerItemAttributes */
/* [unique][helpstring][uuid][object] */ 


EXTERN_C const IID IID_ICategorizerItemAttributes;

#if defined(__cplusplus) && !defined(CINTERFACE)
    
    MIDL_INTERFACE("86F9DA7F-EB6E-11d1-9DF3-00C04FA322BA")
    ICategorizerItemAttributes : public IUnknown
    {
    public:
        virtual /* [local] */ HRESULT STDMETHODCALLTYPE BeginAttributeEnumeration( 
            /* [unique][in] */ LPCSTR pszAttributeName,
            /* [in] */ PATTRIBUTE_ENUMERATOR penumerator) = 0;
        
        virtual /* [local] */ HRESULT STDMETHODCALLTYPE GetNextAttributeValue( 
            /* [in] */ PATTRIBUTE_ENUMERATOR penumerator,
            /* [out] */ LPSTR __RPC_FAR *ppszAttributeValue) = 0;
        
        virtual /* [local] */ HRESULT STDMETHODCALLTYPE RewindAttributeEnumeration( 
            /* [in] */ PATTRIBUTE_ENUMERATOR penumerator) = 0;
        
        virtual /* [local] */ HRESULT STDMETHODCALLTYPE EndAttributeEnumeration( 
            /* [in] */ PATTRIBUTE_ENUMERATOR penumerator) = 0;
        
        virtual /* [local] */ HRESULT STDMETHODCALLTYPE BeginAttributeNameEnumeration( 
            /* [in] */ PATTRIBUTE_ENUMERATOR penumerator) = 0;
        
        virtual /* [local] */ HRESULT STDMETHODCALLTYPE GetNextAttributeName( 
            /* [in] */ PATTRIBUTE_ENUMERATOR penumerator,
            /* [out] */ LPSTR __RPC_FAR *ppszAttributeName) = 0;
        
        virtual /* [local] */ HRESULT STDMETHODCALLTYPE EndAttributeNameEnumeration( 
            /* [in] */ PATTRIBUTE_ENUMERATOR penumerator) = 0;
        
        virtual /* [local] */ GUID STDMETHODCALLTYPE GetTransportSinkID( void) = 0;
        
        virtual /* [local] */ HRESULT STDMETHODCALLTYPE AggregateAttributes( 
            /* [in] */ ICategorizerItemAttributes __RPC_FAR *pICatItemAttr) = 0;
        
        virtual /* [local] */ HRESULT STDMETHODCALLTYPE GetAllAttributeValues( 
            /* [unique][in] */ LPCSTR pszAttributeName,
            /* [in] */ PATTRIBUTE_ENUMERATOR penumerator,
            /* [out] */ LPSTR __RPC_FAR *__RPC_FAR *prgpszAttributeValues) = 0;
        
        virtual /* [local] */ HRESULT STDMETHODCALLTYPE ReleaseAllAttributeValues( 
            /* [in] */ PATTRIBUTE_ENUMERATOR penumerator) = 0;
        
        virtual /* [local] */ HRESULT STDMETHODCALLTYPE CountAttributeValues( 
            /* [in] */ PATTRIBUTE_ENUMERATOR penumerator,
            /* [out] */ DWORD __RPC_FAR *pdwCount) = 0;
        
    };
    
#else 	/* C style interface */

    typedef struct ICategorizerItemAttributesVtbl
    {
        BEGIN_INTERFACE
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *QueryInterface )( 
            ICategorizerItemAttributes __RPC_FAR * This,
            /* [in] */ REFIID riid,
            /* [iid_is][out] */ void __RPC_FAR *__RPC_FAR *ppvObject);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *AddRef )( 
            ICategorizerItemAttributes __RPC_FAR * This);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *Release )( 
            ICategorizerItemAttributes __RPC_FAR * This);
        
        /* [local] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *BeginAttributeEnumeration )( 
            ICategorizerItemAttributes __RPC_FAR * This,
            /* [unique][in] */ LPCSTR pszAttributeName,
            /* [in] */ PATTRIBUTE_ENUMERATOR penumerator);
        
        /* [local] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetNextAttributeValue )( 
            ICategorizerItemAttributes __RPC_FAR * This,
            /* [in] */ PATTRIBUTE_ENUMERATOR penumerator,
            /* [out] */ LPSTR __RPC_FAR *ppszAttributeValue);
        
        /* [local] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *RewindAttributeEnumeration )( 
            ICategorizerItemAttributes __RPC_FAR * This,
            /* [in] */ PATTRIBUTE_ENUMERATOR penumerator);
        
        /* [local] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *EndAttributeEnumeration )( 
            ICategorizerItemAttributes __RPC_FAR * This,
            /* [in] */ PATTRIBUTE_ENUMERATOR penumerator);
        
        /* [local] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *BeginAttributeNameEnumeration )( 
            ICategorizerItemAttributes __RPC_FAR * This,
            /* [in] */ PATTRIBUTE_ENUMERATOR penumerator);
        
        /* [local] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetNextAttributeName )( 
            ICategorizerItemAttributes __RPC_FAR * This,
            /* [in] */ PATTRIBUTE_ENUMERATOR penumerator,
            /* [out] */ LPSTR __RPC_FAR *ppszAttributeName);
        
        /* [local] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *EndAttributeNameEnumeration )( 
            ICategorizerItemAttributes __RPC_FAR * This,
            /* [in] */ PATTRIBUTE_ENUMERATOR penumerator);
        
        /* [local] */ GUID ( STDMETHODCALLTYPE __RPC_FAR *GetTransportSinkID )( 
            ICategorizerItemAttributes __RPC_FAR * This);
        
        /* [local] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *AggregateAttributes )( 
            ICategorizerItemAttributes __RPC_FAR * This,
            /* [in] */ ICategorizerItemAttributes __RPC_FAR *pICatItemAttr);
        
        /* [local] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetAllAttributeValues )( 
            ICategorizerItemAttributes __RPC_FAR * This,
            /* [unique][in] */ LPCSTR pszAttributeName,
            /* [in] */ PATTRIBUTE_ENUMERATOR penumerator,
            /* [out] */ LPSTR __RPC_FAR *__RPC_FAR *prgpszAttributeValues);
        
        /* [local] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *ReleaseAllAttributeValues )( 
            ICategorizerItemAttributes __RPC_FAR * This,
            /* [in] */ PATTRIBUTE_ENUMERATOR penumerator);
        
        /* [local] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *CountAttributeValues )( 
            ICategorizerItemAttributes __RPC_FAR * This,
            /* [in] */ PATTRIBUTE_ENUMERATOR penumerator,
            /* [out] */ DWORD __RPC_FAR *pdwCount);
        
        END_INTERFACE
    } ICategorizerItemAttributesVtbl;

    interface ICategorizerItemAttributes
    {
        CONST_VTBL struct ICategorizerItemAttributesVtbl __RPC_FAR *lpVtbl;
    };

    

#ifdef COBJMACROS


#define ICategorizerItemAttributes_QueryInterface(This,riid,ppvObject)	\
    (This)->lpVtbl -> QueryInterface(This,riid,ppvObject)

#define ICategorizerItemAttributes_AddRef(This)	\
    (This)->lpVtbl -> AddRef(This)

#define ICategorizerItemAttributes_Release(This)	\
    (This)->lpVtbl -> Release(This)


#define ICategorizerItemAttributes_BeginAttributeEnumeration(This,pszAttributeName,penumerator)	\
    (This)->lpVtbl -> BeginAttributeEnumeration(This,pszAttributeName,penumerator)

#define ICategorizerItemAttributes_GetNextAttributeValue(This,penumerator,ppszAttributeValue)	\
    (This)->lpVtbl -> GetNextAttributeValue(This,penumerator,ppszAttributeValue)

#define ICategorizerItemAttributes_RewindAttributeEnumeration(This,penumerator)	\
    (This)->lpVtbl -> RewindAttributeEnumeration(This,penumerator)

#define ICategorizerItemAttributes_EndAttributeEnumeration(This,penumerator)	\
    (This)->lpVtbl -> EndAttributeEnumeration(This,penumerator)

#define ICategorizerItemAttributes_BeginAttributeNameEnumeration(This,penumerator)	\
    (This)->lpVtbl -> BeginAttributeNameEnumeration(This,penumerator)

#define ICategorizerItemAttributes_GetNextAttributeName(This,penumerator,ppszAttributeName)	\
    (This)->lpVtbl -> GetNextAttributeName(This,penumerator,ppszAttributeName)

#define ICategorizerItemAttributes_EndAttributeNameEnumeration(This,penumerator)	\
    (This)->lpVtbl -> EndAttributeNameEnumeration(This,penumerator)

#define ICategorizerItemAttributes_GetTransportSinkID(This)	\
    (This)->lpVtbl -> GetTransportSinkID(This)

#define ICategorizerItemAttributes_AggregateAttributes(This,pICatItemAttr)	\
    (This)->lpVtbl -> AggregateAttributes(This,pICatItemAttr)

#define ICategorizerItemAttributes_GetAllAttributeValues(This,pszAttributeName,penumerator,prgpszAttributeValues)	\
    (This)->lpVtbl -> GetAllAttributeValues(This,pszAttributeName,penumerator,prgpszAttributeValues)

#define ICategorizerItemAttributes_ReleaseAllAttributeValues(This,penumerator)	\
    (This)->lpVtbl -> ReleaseAllAttributeValues(This,penumerator)

#define ICategorizerItemAttributes_CountAttributeValues(This,penumerator,pdwCount)	\
    (This)->lpVtbl -> CountAttributeValues(This,penumerator,pdwCount)

#endif /* COBJMACROS */


#endif 	/* C style interface */



/* [local] */ HRESULT STDMETHODCALLTYPE ICategorizerItemAttributes_BeginAttributeEnumeration_Proxy( 
    ICategorizerItemAttributes __RPC_FAR * This,
    /* [unique][in] */ LPCSTR pszAttributeName,
    /* [in] */ PATTRIBUTE_ENUMERATOR penumerator);


void __RPC_STUB ICategorizerItemAttributes_BeginAttributeEnumeration_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [local] */ HRESULT STDMETHODCALLTYPE ICategorizerItemAttributes_GetNextAttributeValue_Proxy( 
    ICategorizerItemAttributes __RPC_FAR * This,
    /* [in] */ PATTRIBUTE_ENUMERATOR penumerator,
    /* [out] */ LPSTR __RPC_FAR *ppszAttributeValue);


void __RPC_STUB ICategorizerItemAttributes_GetNextAttributeValue_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [local] */ HRESULT STDMETHODCALLTYPE ICategorizerItemAttributes_RewindAttributeEnumeration_Proxy( 
    ICategorizerItemAttributes __RPC_FAR * This,
    /* [in] */ PATTRIBUTE_ENUMERATOR penumerator);


void __RPC_STUB ICategorizerItemAttributes_RewindAttributeEnumeration_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [local] */ HRESULT STDMETHODCALLTYPE ICategorizerItemAttributes_EndAttributeEnumeration_Proxy( 
    ICategorizerItemAttributes __RPC_FAR * This,
    /* [in] */ PATTRIBUTE_ENUMERATOR penumerator);


void __RPC_STUB ICategorizerItemAttributes_EndAttributeEnumeration_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [local] */ HRESULT STDMETHODCALLTYPE ICategorizerItemAttributes_BeginAttributeNameEnumeration_Proxy( 
    ICategorizerItemAttributes __RPC_FAR * This,
    /* [in] */ PATTRIBUTE_ENUMERATOR penumerator);


void __RPC_STUB ICategorizerItemAttributes_BeginAttributeNameEnumeration_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [local] */ HRESULT STDMETHODCALLTYPE ICategorizerItemAttributes_GetNextAttributeName_Proxy( 
    ICategorizerItemAttributes __RPC_FAR * This,
    /* [in] */ PATTRIBUTE_ENUMERATOR penumerator,
    /* [out] */ LPSTR __RPC_FAR *ppszAttributeName);


void __RPC_STUB ICategorizerItemAttributes_GetNextAttributeName_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [local] */ HRESULT STDMETHODCALLTYPE ICategorizerItemAttributes_EndAttributeNameEnumeration_Proxy( 
    ICategorizerItemAttributes __RPC_FAR * This,
    /* [in] */ PATTRIBUTE_ENUMERATOR penumerator);


void __RPC_STUB ICategorizerItemAttributes_EndAttributeNameEnumeration_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [local] */ GUID STDMETHODCALLTYPE ICategorizerItemAttributes_GetTransportSinkID_Proxy( 
    ICategorizerItemAttributes __RPC_FAR * This);


void __RPC_STUB ICategorizerItemAttributes_GetTransportSinkID_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [local] */ HRESULT STDMETHODCALLTYPE ICategorizerItemAttributes_AggregateAttributes_Proxy( 
    ICategorizerItemAttributes __RPC_FAR * This,
    /* [in] */ ICategorizerItemAttributes __RPC_FAR *pICatItemAttr);


void __RPC_STUB ICategorizerItemAttributes_AggregateAttributes_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [local] */ HRESULT STDMETHODCALLTYPE ICategorizerItemAttributes_GetAllAttributeValues_Proxy( 
    ICategorizerItemAttributes __RPC_FAR * This,
    /* [unique][in] */ LPCSTR pszAttributeName,
    /* [in] */ PATTRIBUTE_ENUMERATOR penumerator,
    /* [out] */ LPSTR __RPC_FAR *__RPC_FAR *prgpszAttributeValues);


void __RPC_STUB ICategorizerItemAttributes_GetAllAttributeValues_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [local] */ HRESULT STDMETHODCALLTYPE ICategorizerItemAttributes_ReleaseAllAttributeValues_Proxy( 
    ICategorizerItemAttributes __RPC_FAR * This,
    /* [in] */ PATTRIBUTE_ENUMERATOR penumerator);


void __RPC_STUB ICategorizerItemAttributes_ReleaseAllAttributeValues_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [local] */ HRESULT STDMETHODCALLTYPE ICategorizerItemAttributes_CountAttributeValues_Proxy( 
    ICategorizerItemAttributes __RPC_FAR * This,
    /* [in] */ PATTRIBUTE_ENUMERATOR penumerator,
    /* [out] */ DWORD __RPC_FAR *pdwCount);


void __RPC_STUB ICategorizerItemAttributes_CountAttributeValues_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);



#endif 	/* __ICategorizerItemAttributes_INTERFACE_DEFINED__ */


#ifndef __ICategorizerItemRawAttributes_INTERFACE_DEFINED__
#define __ICategorizerItemRawAttributes_INTERFACE_DEFINED__

/* interface ICategorizerItemRawAttributes */
/* [unique][helpstring][uuid][object] */ 


EXTERN_C const IID IID_ICategorizerItemRawAttributes;

#if defined(__cplusplus) && !defined(CINTERFACE)
    
    MIDL_INTERFACE("34C3D389-8FA7-11d2-9E16-00C04FA322BA")
    ICategorizerItemRawAttributes : public IUnknown
    {
    public:
        virtual /* [local] */ HRESULT STDMETHODCALLTYPE BeginRawAttributeEnumeration( 
            /* [unique][in] */ LPCSTR pszAttributeName,
            /* [in] */ PATTRIBUTE_ENUMERATOR penumerator) = 0;
        
        virtual /* [local] */ HRESULT STDMETHODCALLTYPE GetNextRawAttributeValue( 
            /* [in] */ PATTRIBUTE_ENUMERATOR penumerator,
            /* [out] */ DWORD __RPC_FAR *pdwcb,
            /* [out] */ LPVOID __RPC_FAR *pvAttributeValue) = 0;
        
        virtual /* [local] */ HRESULT STDMETHODCALLTYPE RewindRawAttributeEnumeration( 
            /* [in] */ PATTRIBUTE_ENUMERATOR penumerator) = 0;
        
        virtual /* [local] */ HRESULT STDMETHODCALLTYPE EndRawAttributeEnumeration( 
            /* [in] */ PATTRIBUTE_ENUMERATOR penumerator) = 0;
        
        virtual /* [local] */ HRESULT STDMETHODCALLTYPE CountRawAttributeValues( 
            /* [in] */ PATTRIBUTE_ENUMERATOR penumerator,
            /* [out] */ DWORD __RPC_FAR *pdwCount) = 0;
        
    };
    
#else 	/* C style interface */

    typedef struct ICategorizerItemRawAttributesVtbl
    {
        BEGIN_INTERFACE
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *QueryInterface )( 
            ICategorizerItemRawAttributes __RPC_FAR * This,
            /* [in] */ REFIID riid,
            /* [iid_is][out] */ void __RPC_FAR *__RPC_FAR *ppvObject);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *AddRef )( 
            ICategorizerItemRawAttributes __RPC_FAR * This);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *Release )( 
            ICategorizerItemRawAttributes __RPC_FAR * This);
        
        /* [local] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *BeginRawAttributeEnumeration )( 
            ICategorizerItemRawAttributes __RPC_FAR * This,
            /* [unique][in] */ LPCSTR pszAttributeName,
            /* [in] */ PATTRIBUTE_ENUMERATOR penumerator);
        
        /* [local] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetNextRawAttributeValue )( 
            ICategorizerItemRawAttributes __RPC_FAR * This,
            /* [in] */ PATTRIBUTE_ENUMERATOR penumerator,
            /* [out] */ DWORD __RPC_FAR *pdwcb,
            /* [out] */ LPVOID __RPC_FAR *pvAttributeValue);
        
        /* [local] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *RewindRawAttributeEnumeration )( 
            ICategorizerItemRawAttributes __RPC_FAR * This,
            /* [in] */ PATTRIBUTE_ENUMERATOR penumerator);
        
        /* [local] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *EndRawAttributeEnumeration )( 
            ICategorizerItemRawAttributes __RPC_FAR * This,
            /* [in] */ PATTRIBUTE_ENUMERATOR penumerator);
        
        /* [local] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *CountRawAttributeValues )( 
            ICategorizerItemRawAttributes __RPC_FAR * This,
            /* [in] */ PATTRIBUTE_ENUMERATOR penumerator,
            /* [out] */ DWORD __RPC_FAR *pdwCount);
        
        END_INTERFACE
    } ICategorizerItemRawAttributesVtbl;

    interface ICategorizerItemRawAttributes
    {
        CONST_VTBL struct ICategorizerItemRawAttributesVtbl __RPC_FAR *lpVtbl;
    };

    

#ifdef COBJMACROS


#define ICategorizerItemRawAttributes_QueryInterface(This,riid,ppvObject)	\
    (This)->lpVtbl -> QueryInterface(This,riid,ppvObject)

#define ICategorizerItemRawAttributes_AddRef(This)	\
    (This)->lpVtbl -> AddRef(This)

#define ICategorizerItemRawAttributes_Release(This)	\
    (This)->lpVtbl -> Release(This)


#define ICategorizerItemRawAttributes_BeginRawAttributeEnumeration(This,pszAttributeName,penumerator)	\
    (This)->lpVtbl -> BeginRawAttributeEnumeration(This,pszAttributeName,penumerator)

#define ICategorizerItemRawAttributes_GetNextRawAttributeValue(This,penumerator,pdwcb,pvAttributeValue)	\
    (This)->lpVtbl -> GetNextRawAttributeValue(This,penumerator,pdwcb,pvAttributeValue)

#define ICategorizerItemRawAttributes_RewindRawAttributeEnumeration(This,penumerator)	\
    (This)->lpVtbl -> RewindRawAttributeEnumeration(This,penumerator)

#define ICategorizerItemRawAttributes_EndRawAttributeEnumeration(This,penumerator)	\
    (This)->lpVtbl -> EndRawAttributeEnumeration(This,penumerator)

#define ICategorizerItemRawAttributes_CountRawAttributeValues(This,penumerator,pdwCount)	\
    (This)->lpVtbl -> CountRawAttributeValues(This,penumerator,pdwCount)

#endif /* COBJMACROS */


#endif 	/* C style interface */



/* [local] */ HRESULT STDMETHODCALLTYPE ICategorizerItemRawAttributes_BeginRawAttributeEnumeration_Proxy( 
    ICategorizerItemRawAttributes __RPC_FAR * This,
    /* [unique][in] */ LPCSTR pszAttributeName,
    /* [in] */ PATTRIBUTE_ENUMERATOR penumerator);


void __RPC_STUB ICategorizerItemRawAttributes_BeginRawAttributeEnumeration_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [local] */ HRESULT STDMETHODCALLTYPE ICategorizerItemRawAttributes_GetNextRawAttributeValue_Proxy( 
    ICategorizerItemRawAttributes __RPC_FAR * This,
    /* [in] */ PATTRIBUTE_ENUMERATOR penumerator,
    /* [out] */ DWORD __RPC_FAR *pdwcb,
    /* [out] */ LPVOID __RPC_FAR *pvAttributeValue);


void __RPC_STUB ICategorizerItemRawAttributes_GetNextRawAttributeValue_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [local] */ HRESULT STDMETHODCALLTYPE ICategorizerItemRawAttributes_RewindRawAttributeEnumeration_Proxy( 
    ICategorizerItemRawAttributes __RPC_FAR * This,
    /* [in] */ PATTRIBUTE_ENUMERATOR penumerator);


void __RPC_STUB ICategorizerItemRawAttributes_RewindRawAttributeEnumeration_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [local] */ HRESULT STDMETHODCALLTYPE ICategorizerItemRawAttributes_EndRawAttributeEnumeration_Proxy( 
    ICategorizerItemRawAttributes __RPC_FAR * This,
    /* [in] */ PATTRIBUTE_ENUMERATOR penumerator);


void __RPC_STUB ICategorizerItemRawAttributes_EndRawAttributeEnumeration_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [local] */ HRESULT STDMETHODCALLTYPE ICategorizerItemRawAttributes_CountRawAttributeValues_Proxy( 
    ICategorizerItemRawAttributes __RPC_FAR * This,
    /* [in] */ PATTRIBUTE_ENUMERATOR penumerator,
    /* [out] */ DWORD __RPC_FAR *pdwCount);


void __RPC_STUB ICategorizerItemRawAttributes_CountRawAttributeValues_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);



#endif 	/* __ICategorizerItemRawAttributes_INTERFACE_DEFINED__ */


/* interface __MIDL_itf_SmtpEvent_0294 */
/* [local] */ 

typedef /* [public][v1_enum] */ 
enum __MIDL___MIDL_itf_SmtpEvent_0294_0001
    {	ICATEGORIZERITEM_SOURCETYPE	= 0,
	ICATEGORIZERITEM_LDAPQUERYSTRING	= ICATEGORIZERITEM_SOURCETYPE + 1,
	ICATEGORIZERITEM_DISTINGUISHINGATTRIBUTE	= ICATEGORIZERITEM_LDAPQUERYSTRING + 1,
	ICATEGORIZERITEM_DISTINGUISHINGATTRIBUTEVALUE	= ICATEGORIZERITEM_DISTINGUISHINGATTRIBUTE + 1,
	ICATEGORIZERITEM_IMAILMSGPROPERTIES	= ICATEGORIZERITEM_DISTINGUISHINGATTRIBUTEVALUE + 1,
	ICATEGORIZERITEM_IMAILMSGRECIPIENTSADD	= ICATEGORIZERITEM_IMAILMSGPROPERTIES + 1,
	ICATEGORIZERITEM_IMAILMSGRECIPIENTSADDINDEX	= ICATEGORIZERITEM_IMAILMSGRECIPIENTSADD + 1,
	ICATEGORIZERITEM_FPRIMARY	= ICATEGORIZERITEM_IMAILMSGRECIPIENTSADDINDEX + 1,
	ICATEGORIZERITEM_PARENT	= ICATEGORIZERITEM_FPRIMARY + 1,
	ICATEGORIZERITEM_ICATEGORIZERITEMATTRIBUTES	= ICATEGORIZERITEM_PARENT + 1,
	ICATEGORIZERITEM_HRSTATUS	= ICATEGORIZERITEM_ICATEGORIZERITEMATTRIBUTES + 1,
	ICATEGORIZERITEM_ICATEGORIZERLISTRESOLVE	= ICATEGORIZERITEM_HRSTATUS + 1,
	ICATEGORIZERITEM_ICATEGORIZERMAILMSGS	= ICATEGORIZERITEM_ICATEGORIZERLISTRESOLVE + 1,
	ICATEGORIZERITEM_HRNDRREASON	= ICATEGORIZERITEM_ICATEGORIZERMAILMSGS + 1,
	ICATEGORIZERITEM_DWLEVEL	= ICATEGORIZERITEM_HRNDRREASON + 1,
	ICATEGORIZERITEM_ENDENUMMESS	= ICATEGORIZERITEM_DWLEVEL + 1
    }	eICATEGORIZERITEMPROPID;

typedef /* [public][public][v1_enum] */ 
enum __MIDL___MIDL_itf_SmtpEvent_0294_0002
    {	SOURCE_SENDER	= 0,
	SOURCE_RECIPIENT	= SOURCE_SENDER + 1,
	SOURCE_VERIFY	= SOURCE_RECIPIENT + 1
    }	eSourceType;



extern RPC_IF_HANDLE __MIDL_itf_SmtpEvent_0294_v0_0_c_ifspec;
extern RPC_IF_HANDLE __MIDL_itf_SmtpEvent_0294_v0_0_s_ifspec;

#ifndef __ICategorizerItem_INTERFACE_DEFINED__
#define __ICategorizerItem_INTERFACE_DEFINED__

/* interface ICategorizerItem */
/* [unique][helpstring][uuid][object][local] */ 


EXTERN_C const IID IID_ICategorizerItem;

#if defined(__cplusplus) && !defined(CINTERFACE)
    
    MIDL_INTERFACE("86F9DA7C-EB6E-11d1-9DF3-00C04FA322BA")
    ICategorizerItem : public ICategorizerProperties
    {
    public:
    };
    
#else 	/* C style interface */

    typedef struct ICategorizerItemVtbl
    {
        BEGIN_INTERFACE
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *QueryInterface )( 
            ICategorizerItem __RPC_FAR * This,
            /* [in] */ REFIID riid,
            /* [iid_is][out] */ void __RPC_FAR *__RPC_FAR *ppvObject);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *AddRef )( 
            ICategorizerItem __RPC_FAR * This);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *Release )( 
            ICategorizerItem __RPC_FAR * This);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetStringA )( 
            ICategorizerItem __RPC_FAR * This,
            /* [in] */ DWORD dwPropId,
            /* [in] */ DWORD dwcchValue,
            /* [size_is][out] */ LPSTR pszValue);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *PutStringA )( 
            ICategorizerItem __RPC_FAR * This,
            /* [in] */ DWORD dwPropId,
            /* [unique][in] */ LPSTR pszValue);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetDWORD )( 
            ICategorizerItem __RPC_FAR * This,
            /* [in] */ DWORD dwPropId,
            /* [out] */ DWORD __RPC_FAR *pdwValue);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *PutDWORD )( 
            ICategorizerItem __RPC_FAR * This,
            /* [in] */ DWORD dwPropId,
            /* [in] */ DWORD dwValue);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetHRESULT )( 
            ICategorizerItem __RPC_FAR * This,
            /* [in] */ DWORD dwPropId,
            /* [out] */ HRESULT __RPC_FAR *phrValue);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *PutHRESULT )( 
            ICategorizerItem __RPC_FAR * This,
            /* [in] */ DWORD dwPropId,
            /* [in] */ HRESULT hrValue);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetBool )( 
            ICategorizerItem __RPC_FAR * This,
            /* [in] */ DWORD dwPropId,
            /* [out] */ BOOL __RPC_FAR *pfValue);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *PutBool )( 
            ICategorizerItem __RPC_FAR * This,
            /* [in] */ DWORD dwPropId,
            /* [in] */ BOOL fValue);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetPVoid )( 
            ICategorizerItem __RPC_FAR * This,
            /* [in] */ DWORD dwPropId,
            /* [out] */ PVOID __RPC_FAR *pvValue);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *PutPVoid )( 
            ICategorizerItem __RPC_FAR * This,
            /* [in] */ DWORD dwPropId,
            /* [in] */ PVOID pvValue);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetIUnknown )( 
            ICategorizerItem __RPC_FAR * This,
            /* [in] */ DWORD dwPropId,
            /* [out] */ IUnknown __RPC_FAR *__RPC_FAR *pUnknown);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *PutIUnknown )( 
            ICategorizerItem __RPC_FAR * This,
            /* [in] */ DWORD dwPropId,
            /* [in] */ IUnknown __RPC_FAR *pUnknown);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetIMailMsgProperties )( 
            ICategorizerItem __RPC_FAR * This,
            /* [in] */ DWORD dwPropId,
            /* [out] */ IMailMsgProperties __RPC_FAR *__RPC_FAR *ppIMsg);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *PutIMailMsgProperties )( 
            ICategorizerItem __RPC_FAR * This,
            /* [in] */ DWORD dwPropId,
            /* [in] */ IMailMsgProperties __RPC_FAR *pIMsg);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetIMailMsgRecipientsAdd )( 
            ICategorizerItem __RPC_FAR * This,
            /* [in] */ DWORD dwPropId,
            /* [out] */ IMailMsgRecipientsAdd __RPC_FAR *__RPC_FAR *ppIMsgRecipientsAdd);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *PutIMailMsgRecipientsAdd )( 
            ICategorizerItem __RPC_FAR * This,
            /* [in] */ DWORD dwPropId,
            /* [in] */ IMailMsgRecipientsAdd __RPC_FAR *pIMsgRecipientsAdd);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetICategorizerItemAttributes )( 
            ICategorizerItem __RPC_FAR * This,
            /* [in] */ DWORD dwPropId,
            /* [out] */ ICategorizerItemAttributes __RPC_FAR *__RPC_FAR *ppICategorizerItemAttributes);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *PutICategorizerItemAttributes )( 
            ICategorizerItem __RPC_FAR * This,
            /* [in] */ DWORD dwPropId,
            /* [in] */ ICategorizerItemAttributes __RPC_FAR *pICategorizerItemAttributes);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetICategorizerListResolve )( 
            ICategorizerItem __RPC_FAR * This,
            /* [in] */ DWORD dwPropId,
            /* [out] */ ICategorizerListResolve __RPC_FAR *__RPC_FAR *ppICategorizerListResolve);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *PutICategorizerListResolve )( 
            ICategorizerItem __RPC_FAR * This,
            /* [in] */ DWORD dwPropId,
            /* [in] */ ICategorizerListResolve __RPC_FAR *pICategorizerListResolve);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetICategorizerMailMsgs )( 
            ICategorizerItem __RPC_FAR * This,
            /* [in] */ DWORD dwPropId,
            /* [out] */ ICategorizerMailMsgs __RPC_FAR *__RPC_FAR *ppICategorizerMailMsgs);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *PutICategorizerMailMsgs )( 
            ICategorizerItem __RPC_FAR * This,
            /* [in] */ DWORD dwPropId,
            /* [in] */ ICategorizerMailMsgs __RPC_FAR *pICategorizerMailMsgs);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetICategorizerItem )( 
            ICategorizerItem __RPC_FAR * This,
            /* [in] */ DWORD dwPropId,
            /* [out] */ ICategorizerItem __RPC_FAR *__RPC_FAR *ppICategorizerItem);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *PutICategorizerItem )( 
            ICategorizerItem __RPC_FAR * This,
            /* [in] */ DWORD dwPropId,
            /* [in] */ ICategorizerItem __RPC_FAR *pICategorizerItem);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *UnSetPropId )( 
            ICategorizerItem __RPC_FAR * This,
            /* [in] */ DWORD dwPropId);
        
        END_INTERFACE
    } ICategorizerItemVtbl;

    interface ICategorizerItem
    {
        CONST_VTBL struct ICategorizerItemVtbl __RPC_FAR *lpVtbl;
    };

    

#ifdef COBJMACROS


#define ICategorizerItem_QueryInterface(This,riid,ppvObject)	\
    (This)->lpVtbl -> QueryInterface(This,riid,ppvObject)

#define ICategorizerItem_AddRef(This)	\
    (This)->lpVtbl -> AddRef(This)

#define ICategorizerItem_Release(This)	\
    (This)->lpVtbl -> Release(This)


#define ICategorizerItem_GetStringA(This,dwPropId,dwcchValue,pszValue)	\
    (This)->lpVtbl -> GetStringA(This,dwPropId,dwcchValue,pszValue)

#define ICategorizerItem_PutStringA(This,dwPropId,pszValue)	\
    (This)->lpVtbl -> PutStringA(This,dwPropId,pszValue)

#define ICategorizerItem_GetDWORD(This,dwPropId,pdwValue)	\
    (This)->lpVtbl -> GetDWORD(This,dwPropId,pdwValue)

#define ICategorizerItem_PutDWORD(This,dwPropId,dwValue)	\
    (This)->lpVtbl -> PutDWORD(This,dwPropId,dwValue)

#define ICategorizerItem_GetHRESULT(This,dwPropId,phrValue)	\
    (This)->lpVtbl -> GetHRESULT(This,dwPropId,phrValue)

#define ICategorizerItem_PutHRESULT(This,dwPropId,hrValue)	\
    (This)->lpVtbl -> PutHRESULT(This,dwPropId,hrValue)

#define ICategorizerItem_GetBool(This,dwPropId,pfValue)	\
    (This)->lpVtbl -> GetBool(This,dwPropId,pfValue)

#define ICategorizerItem_PutBool(This,dwPropId,fValue)	\
    (This)->lpVtbl -> PutBool(This,dwPropId,fValue)

#define ICategorizerItem_GetPVoid(This,dwPropId,pvValue)	\
    (This)->lpVtbl -> GetPVoid(This,dwPropId,pvValue)

#define ICategorizerItem_PutPVoid(This,dwPropId,pvValue)	\
    (This)->lpVtbl -> PutPVoid(This,dwPropId,pvValue)

#define ICategorizerItem_GetIUnknown(This,dwPropId,pUnknown)	\
    (This)->lpVtbl -> GetIUnknown(This,dwPropId,pUnknown)

#define ICategorizerItem_PutIUnknown(This,dwPropId,pUnknown)	\
    (This)->lpVtbl -> PutIUnknown(This,dwPropId,pUnknown)

#define ICategorizerItem_GetIMailMsgProperties(This,dwPropId,ppIMsg)	\
    (This)->lpVtbl -> GetIMailMsgProperties(This,dwPropId,ppIMsg)

#define ICategorizerItem_PutIMailMsgProperties(This,dwPropId,pIMsg)	\
    (This)->lpVtbl -> PutIMailMsgProperties(This,dwPropId,pIMsg)

#define ICategorizerItem_GetIMailMsgRecipientsAdd(This,dwPropId,ppIMsgRecipientsAdd)	\
    (This)->lpVtbl -> GetIMailMsgRecipientsAdd(This,dwPropId,ppIMsgRecipientsAdd)

#define ICategorizerItem_PutIMailMsgRecipientsAdd(This,dwPropId,pIMsgRecipientsAdd)	\
    (This)->lpVtbl -> PutIMailMsgRecipientsAdd(This,dwPropId,pIMsgRecipientsAdd)

#define ICategorizerItem_GetICategorizerItemAttributes(This,dwPropId,ppICategorizerItemAttributes)	\
    (This)->lpVtbl -> GetICategorizerItemAttributes(This,dwPropId,ppICategorizerItemAttributes)

#define ICategorizerItem_PutICategorizerItemAttributes(This,dwPropId,pICategorizerItemAttributes)	\
    (This)->lpVtbl -> PutICategorizerItemAttributes(This,dwPropId,pICategorizerItemAttributes)

#define ICategorizerItem_GetICategorizerListResolve(This,dwPropId,ppICategorizerListResolve)	\
    (This)->lpVtbl -> GetICategorizerListResolve(This,dwPropId,ppICategorizerListResolve)

#define ICategorizerItem_PutICategorizerListResolve(This,dwPropId,pICategorizerListResolve)	\
    (This)->lpVtbl -> PutICategorizerListResolve(This,dwPropId,pICategorizerListResolve)

#define ICategorizerItem_GetICategorizerMailMsgs(This,dwPropId,ppICategorizerMailMsgs)	\
    (This)->lpVtbl -> GetICategorizerMailMsgs(This,dwPropId,ppICategorizerMailMsgs)

#define ICategorizerItem_PutICategorizerMailMsgs(This,dwPropId,pICategorizerMailMsgs)	\
    (This)->lpVtbl -> PutICategorizerMailMsgs(This,dwPropId,pICategorizerMailMsgs)

#define ICategorizerItem_GetICategorizerItem(This,dwPropId,ppICategorizerItem)	\
    (This)->lpVtbl -> GetICategorizerItem(This,dwPropId,ppICategorizerItem)

#define ICategorizerItem_PutICategorizerItem(This,dwPropId,pICategorizerItem)	\
    (This)->lpVtbl -> PutICategorizerItem(This,dwPropId,pICategorizerItem)

#define ICategorizerItem_UnSetPropId(This,dwPropId)	\
    (This)->lpVtbl -> UnSetPropId(This,dwPropId)


#endif /* COBJMACROS */


#endif 	/* C style interface */




#endif 	/* __ICategorizerItem_INTERFACE_DEFINED__ */


#ifndef __ICategorizerAsyncContext_INTERFACE_DEFINED__
#define __ICategorizerAsyncContext_INTERFACE_DEFINED__

/* interface ICategorizerAsyncContext */
/* [unique][helpstring][uuid][object] */ 


EXTERN_C const IID IID_ICategorizerAsyncContext;

#if defined(__cplusplus) && !defined(CINTERFACE)
    
    MIDL_INTERFACE("86F9DA7E-EB6E-11d1-9DF3-00C04FA322BA")
    ICategorizerAsyncContext : public IUnknown
    {
    public:
        virtual /* [local] */ HRESULT STDMETHODCALLTYPE CompleteQuery( 
            /* [in] */ PVOID pvQueryContext,
            /* [in] */ HRESULT hrResolutionStatus,
            /* [in] */ DWORD dwcResults,
            /* [size_is][in] */ ICategorizerItemAttributes __RPC_FAR *__RPC_FAR *rgpItemAttributes,
            /* [in] */ BOOL fFinalCompletion) = 0;
        
    };
    
#else 	/* C style interface */

    typedef struct ICategorizerAsyncContextVtbl
    {
        BEGIN_INTERFACE
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *QueryInterface )( 
            ICategorizerAsyncContext __RPC_FAR * This,
            /* [in] */ REFIID riid,
            /* [iid_is][out] */ void __RPC_FAR *__RPC_FAR *ppvObject);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *AddRef )( 
            ICategorizerAsyncContext __RPC_FAR * This);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *Release )( 
            ICategorizerAsyncContext __RPC_FAR * This);
        
        /* [local] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *CompleteQuery )( 
            ICategorizerAsyncContext __RPC_FAR * This,
            /* [in] */ PVOID pvQueryContext,
            /* [in] */ HRESULT hrResolutionStatus,
            /* [in] */ DWORD dwcResults,
            /* [size_is][in] */ ICategorizerItemAttributes __RPC_FAR *__RPC_FAR *rgpItemAttributes,
            /* [in] */ BOOL fFinalCompletion);
        
        END_INTERFACE
    } ICategorizerAsyncContextVtbl;

    interface ICategorizerAsyncContext
    {
        CONST_VTBL struct ICategorizerAsyncContextVtbl __RPC_FAR *lpVtbl;
    };

    

#ifdef COBJMACROS


#define ICategorizerAsyncContext_QueryInterface(This,riid,ppvObject)	\
    (This)->lpVtbl -> QueryInterface(This,riid,ppvObject)

#define ICategorizerAsyncContext_AddRef(This)	\
    (This)->lpVtbl -> AddRef(This)

#define ICategorizerAsyncContext_Release(This)	\
    (This)->lpVtbl -> Release(This)


#define ICategorizerAsyncContext_CompleteQuery(This,pvQueryContext,hrResolutionStatus,dwcResults,rgpItemAttributes,fFinalCompletion)	\
    (This)->lpVtbl -> CompleteQuery(This,pvQueryContext,hrResolutionStatus,dwcResults,rgpItemAttributes,fFinalCompletion)

#endif /* COBJMACROS */


#endif 	/* C style interface */



/* [local] */ HRESULT STDMETHODCALLTYPE ICategorizerAsyncContext_CompleteQuery_Proxy( 
    ICategorizerAsyncContext __RPC_FAR * This,
    /* [in] */ PVOID pvQueryContext,
    /* [in] */ HRESULT hrResolutionStatus,
    /* [in] */ DWORD dwcResults,
    /* [size_is][in] */ ICategorizerItemAttributes __RPC_FAR *__RPC_FAR *rgpItemAttributes,
    /* [in] */ BOOL fFinalCompletion);


void __RPC_STUB ICategorizerAsyncContext_CompleteQuery_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);



#endif 	/* __ICategorizerAsyncContext_INTERFACE_DEFINED__ */


#ifndef __ICategorizerListResolve_INTERFACE_DEFINED__
#define __ICategorizerListResolve_INTERFACE_DEFINED__

/* interface ICategorizerListResolve */
/* [unique][helpstring][uuid][object] */ 


EXTERN_C const IID IID_ICategorizerListResolve;

#if defined(__cplusplus) && !defined(CINTERFACE)
    
    MIDL_INTERFACE("960252A4-0A3A-11d2-9E00-00C04FA322BA")
    ICategorizerListResolve : public IUnknown
    {
    public:
        virtual /* [local] */ HRESULT STDMETHODCALLTYPE AllocICategorizerItem( 
            /* [in] */ eSourceType SourceType,
            /* [out] */ ICategorizerItem __RPC_FAR *__RPC_FAR *ppICatItem) = 0;
        
        virtual /* [local] */ HRESULT STDMETHODCALLTYPE ResolveICategorizerItem( 
            /* [in] */ ICategorizerItem __RPC_FAR *pICatItem) = 0;
        
        virtual /* [local] */ HRESULT STDMETHODCALLTYPE SetListResolveStatus( 
            /* [in] */ HRESULT hrStatus) = 0;
        
        virtual /* [local] */ HRESULT STDMETHODCALLTYPE GetListResolveStatus( 
            /* [out] */ HRESULT __RPC_FAR *phrStatus) = 0;
        
    };
    
#else 	/* C style interface */

    typedef struct ICategorizerListResolveVtbl
    {
        BEGIN_INTERFACE
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *QueryInterface )( 
            ICategorizerListResolve __RPC_FAR * This,
            /* [in] */ REFIID riid,
            /* [iid_is][out] */ void __RPC_FAR *__RPC_FAR *ppvObject);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *AddRef )( 
            ICategorizerListResolve __RPC_FAR * This);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *Release )( 
            ICategorizerListResolve __RPC_FAR * This);
        
        /* [local] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *AllocICategorizerItem )( 
            ICategorizerListResolve __RPC_FAR * This,
            /* [in] */ eSourceType SourceType,
            /* [out] */ ICategorizerItem __RPC_FAR *__RPC_FAR *ppICatItem);
        
        /* [local] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *ResolveICategorizerItem )( 
            ICategorizerListResolve __RPC_FAR * This,
            /* [in] */ ICategorizerItem __RPC_FAR *pICatItem);
        
        /* [local] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *SetListResolveStatus )( 
            ICategorizerListResolve __RPC_FAR * This,
            /* [in] */ HRESULT hrStatus);
        
        /* [local] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetListResolveStatus )( 
            ICategorizerListResolve __RPC_FAR * This,
            /* [out] */ HRESULT __RPC_FAR *phrStatus);
        
        END_INTERFACE
    } ICategorizerListResolveVtbl;

    interface ICategorizerListResolve
    {
        CONST_VTBL struct ICategorizerListResolveVtbl __RPC_FAR *lpVtbl;
    };

    

#ifdef COBJMACROS


#define ICategorizerListResolve_QueryInterface(This,riid,ppvObject)	\
    (This)->lpVtbl -> QueryInterface(This,riid,ppvObject)

#define ICategorizerListResolve_AddRef(This)	\
    (This)->lpVtbl -> AddRef(This)

#define ICategorizerListResolve_Release(This)	\
    (This)->lpVtbl -> Release(This)


#define ICategorizerListResolve_AllocICategorizerItem(This,SourceType,ppICatItem)	\
    (This)->lpVtbl -> AllocICategorizerItem(This,SourceType,ppICatItem)

#define ICategorizerListResolve_ResolveICategorizerItem(This,pICatItem)	\
    (This)->lpVtbl -> ResolveICategorizerItem(This,pICatItem)

#define ICategorizerListResolve_SetListResolveStatus(This,hrStatus)	\
    (This)->lpVtbl -> SetListResolveStatus(This,hrStatus)

#define ICategorizerListResolve_GetListResolveStatus(This,phrStatus)	\
    (This)->lpVtbl -> GetListResolveStatus(This,phrStatus)

#endif /* COBJMACROS */


#endif 	/* C style interface */



/* [local] */ HRESULT STDMETHODCALLTYPE ICategorizerListResolve_AllocICategorizerItem_Proxy( 
    ICategorizerListResolve __RPC_FAR * This,
    /* [in] */ eSourceType SourceType,
    /* [out] */ ICategorizerItem __RPC_FAR *__RPC_FAR *ppICatItem);


void __RPC_STUB ICategorizerListResolve_AllocICategorizerItem_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [local] */ HRESULT STDMETHODCALLTYPE ICategorizerListResolve_ResolveICategorizerItem_Proxy( 
    ICategorizerListResolve __RPC_FAR * This,
    /* [in] */ ICategorizerItem __RPC_FAR *pICatItem);


void __RPC_STUB ICategorizerListResolve_ResolveICategorizerItem_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [local] */ HRESULT STDMETHODCALLTYPE ICategorizerListResolve_SetListResolveStatus_Proxy( 
    ICategorizerListResolve __RPC_FAR * This,
    /* [in] */ HRESULT hrStatus);


void __RPC_STUB ICategorizerListResolve_SetListResolveStatus_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [local] */ HRESULT STDMETHODCALLTYPE ICategorizerListResolve_GetListResolveStatus_Proxy( 
    ICategorizerListResolve __RPC_FAR * This,
    /* [out] */ HRESULT __RPC_FAR *phrStatus);


void __RPC_STUB ICategorizerListResolve_GetListResolveStatus_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);



#endif 	/* __ICategorizerListResolve_INTERFACE_DEFINED__ */


#ifndef __IMailTransportCategorize_INTERFACE_DEFINED__
#define __IMailTransportCategorize_INTERFACE_DEFINED__

/* interface IMailTransportCategorize */
/* [unique][helpstring][uuid][object] */ 


EXTERN_C const IID IID_IMailTransportCategorize;

#if defined(__cplusplus) && !defined(CINTERFACE)
    
    MIDL_INTERFACE("86F9DA7A-EB6E-11d1-9DF3-00C04FA322BA")
    IMailTransportCategorize : public IUnknown
    {
    public:
        virtual HRESULT STDMETHODCALLTYPE Register( 
            /* [in] */ ICategorizerParameters __RPC_FAR *__MIDL_0011) = 0;
        
        virtual /* [local] */ HRESULT STDMETHODCALLTYPE BeginMessageCategorization( 
            /* [in] */ ICategorizerMailMsgs __RPC_FAR *__MIDL_0012) = 0;
        
        virtual /* [local] */ HRESULT STDMETHODCALLTYPE EndMessageCategorization( 
            /* [in] */ ICategorizerMailMsgs __RPC_FAR *__MIDL_0013,
            /* [in] */ HRESULT hrCatStatus) = 0;
        
        virtual /* [local] */ HRESULT STDMETHODCALLTYPE BuildQuery( 
            /* [in] */ ICategorizerParameters __RPC_FAR *__MIDL_0014,
            /* [in] */ ICategorizerItem __RPC_FAR *__MIDL_0015) = 0;
        
        virtual /* [local] */ HRESULT STDMETHODCALLTYPE BuildQueries( 
            /* [in] */ ICategorizerParameters __RPC_FAR *__MIDL_0016,
            /* [in] */ DWORD dwcAddresses,
            /* [size_is][in] */ ICategorizerItem __RPC_FAR *__RPC_FAR *rgpICategorizerItems,
            /* [in] */ ICategorizerQueries __RPC_FAR *__MIDL_0017) = 0;
        
        virtual /* [local] */ HRESULT STDMETHODCALLTYPE SendQuery( 
            /* [in] */ ICategorizerParameters __RPC_FAR *__MIDL_0018,
            /* [in] */ ICategorizerQueries __RPC_FAR *__MIDL_0019,
            /* [in] */ ICategorizerAsyncContext __RPC_FAR *__MIDL_0020,
            /* [in] */ PVOID pvQueryContext) = 0;
        
        virtual /* [local] */ HRESULT STDMETHODCALLTYPE SortQueryResult( 
            /* [in] */ ICategorizerParameters __RPC_FAR *__MIDL_0021,
            /* [in] */ HRESULT hrResolutionStatus,
            /* [in] */ DWORD dwcAddresses,
            /* [size_is][in] */ ICategorizerItem __RPC_FAR *__RPC_FAR *rgpICategorizerItems,
            /* [in] */ DWORD dwcResults,
            /* [size_is][in] */ ICategorizerItemAttributes __RPC_FAR *__RPC_FAR *rgpICategorizerItemAttributes) = 0;
        
        virtual /* [local] */ HRESULT STDMETHODCALLTYPE ProcessItem( 
            /* [in] */ ICategorizerParameters __RPC_FAR *__MIDL_0022,
            /* [in] */ ICategorizerItem __RPC_FAR *__MIDL_0023) = 0;
        
        virtual /* [local] */ HRESULT STDMETHODCALLTYPE ExpandItem( 
            /* [in] */ ICategorizerParameters __RPC_FAR *__MIDL_0024,
            /* [in] */ ICategorizerItem __RPC_FAR *__MIDL_0025,
            /* [in] */ IMailTransportNotify __RPC_FAR *__MIDL_0026,
            /* [in] */ PVOID __MIDL_0027) = 0;
        
        virtual /* [local] */ HRESULT STDMETHODCALLTYPE CompleteItem( 
            /* [in] */ ICategorizerParameters __RPC_FAR *__MIDL_0028,
            /* [in] */ ICategorizerItem __RPC_FAR *__MIDL_0029) = 0;
        
    };
    
#else 	/* C style interface */

    typedef struct IMailTransportCategorizeVtbl
    {
        BEGIN_INTERFACE
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *QueryInterface )( 
            IMailTransportCategorize __RPC_FAR * This,
            /* [in] */ REFIID riid,
            /* [iid_is][out] */ void __RPC_FAR *__RPC_FAR *ppvObject);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *AddRef )( 
            IMailTransportCategorize __RPC_FAR * This);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *Release )( 
            IMailTransportCategorize __RPC_FAR * This);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *Register )( 
            IMailTransportCategorize __RPC_FAR * This,
            /* [in] */ ICategorizerParameters __RPC_FAR *__MIDL_0011);
        
        /* [local] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *BeginMessageCategorization )( 
            IMailTransportCategorize __RPC_FAR * This,
            /* [in] */ ICategorizerMailMsgs __RPC_FAR *__MIDL_0012);
        
        /* [local] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *EndMessageCategorization )( 
            IMailTransportCategorize __RPC_FAR * This,
            /* [in] */ ICategorizerMailMsgs __RPC_FAR *__MIDL_0013,
            /* [in] */ HRESULT hrCatStatus);
        
        /* [local] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *BuildQuery )( 
            IMailTransportCategorize __RPC_FAR * This,
            /* [in] */ ICategorizerParameters __RPC_FAR *__MIDL_0014,
            /* [in] */ ICategorizerItem __RPC_FAR *__MIDL_0015);
        
        /* [local] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *BuildQueries )( 
            IMailTransportCategorize __RPC_FAR * This,
            /* [in] */ ICategorizerParameters __RPC_FAR *__MIDL_0016,
            /* [in] */ DWORD dwcAddresses,
            /* [size_is][in] */ ICategorizerItem __RPC_FAR *__RPC_FAR *rgpICategorizerItems,
            /* [in] */ ICategorizerQueries __RPC_FAR *__MIDL_0017);
        
        /* [local] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *SendQuery )( 
            IMailTransportCategorize __RPC_FAR * This,
            /* [in] */ ICategorizerParameters __RPC_FAR *__MIDL_0018,
            /* [in] */ ICategorizerQueries __RPC_FAR *__MIDL_0019,
            /* [in] */ ICategorizerAsyncContext __RPC_FAR *__MIDL_0020,
            /* [in] */ PVOID pvQueryContext);
        
        /* [local] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *SortQueryResult )( 
            IMailTransportCategorize __RPC_FAR * This,
            /* [in] */ ICategorizerParameters __RPC_FAR *__MIDL_0021,
            /* [in] */ HRESULT hrResolutionStatus,
            /* [in] */ DWORD dwcAddresses,
            /* [size_is][in] */ ICategorizerItem __RPC_FAR *__RPC_FAR *rgpICategorizerItems,
            /* [in] */ DWORD dwcResults,
            /* [size_is][in] */ ICategorizerItemAttributes __RPC_FAR *__RPC_FAR *rgpICategorizerItemAttributes);
        
        /* [local] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *ProcessItem )( 
            IMailTransportCategorize __RPC_FAR * This,
            /* [in] */ ICategorizerParameters __RPC_FAR *__MIDL_0022,
            /* [in] */ ICategorizerItem __RPC_FAR *__MIDL_0023);
        
        /* [local] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *ExpandItem )( 
            IMailTransportCategorize __RPC_FAR * This,
            /* [in] */ ICategorizerParameters __RPC_FAR *__MIDL_0024,
            /* [in] */ ICategorizerItem __RPC_FAR *__MIDL_0025,
            /* [in] */ IMailTransportNotify __RPC_FAR *__MIDL_0026,
            /* [in] */ PVOID __MIDL_0027);
        
        /* [local] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *CompleteItem )( 
            IMailTransportCategorize __RPC_FAR * This,
            /* [in] */ ICategorizerParameters __RPC_FAR *__MIDL_0028,
            /* [in] */ ICategorizerItem __RPC_FAR *__MIDL_0029);
        
        END_INTERFACE
    } IMailTransportCategorizeVtbl;

    interface IMailTransportCategorize
    {
        CONST_VTBL struct IMailTransportCategorizeVtbl __RPC_FAR *lpVtbl;
    };

    

#ifdef COBJMACROS


#define IMailTransportCategorize_QueryInterface(This,riid,ppvObject)	\
    (This)->lpVtbl -> QueryInterface(This,riid,ppvObject)

#define IMailTransportCategorize_AddRef(This)	\
    (This)->lpVtbl -> AddRef(This)

#define IMailTransportCategorize_Release(This)	\
    (This)->lpVtbl -> Release(This)


#define IMailTransportCategorize_Register(This,__MIDL_0011)	\
    (This)->lpVtbl -> Register(This,__MIDL_0011)

#define IMailTransportCategorize_BeginMessageCategorization(This,__MIDL_0012)	\
    (This)->lpVtbl -> BeginMessageCategorization(This,__MIDL_0012)

#define IMailTransportCategorize_EndMessageCategorization(This,__MIDL_0013,hrCatStatus)	\
    (This)->lpVtbl -> EndMessageCategorization(This,__MIDL_0013,hrCatStatus)

#define IMailTransportCategorize_BuildQuery(This,__MIDL_0014,__MIDL_0015)	\
    (This)->lpVtbl -> BuildQuery(This,__MIDL_0014,__MIDL_0015)

#define IMailTransportCategorize_BuildQueries(This,__MIDL_0016,dwcAddresses,rgpICategorizerItems,__MIDL_0017)	\
    (This)->lpVtbl -> BuildQueries(This,__MIDL_0016,dwcAddresses,rgpICategorizerItems,__MIDL_0017)

#define IMailTransportCategorize_SendQuery(This,__MIDL_0018,__MIDL_0019,__MIDL_0020,pvQueryContext)	\
    (This)->lpVtbl -> SendQuery(This,__MIDL_0018,__MIDL_0019,__MIDL_0020,pvQueryContext)

#define IMailTransportCategorize_SortQueryResult(This,__MIDL_0021,hrResolutionStatus,dwcAddresses,rgpICategorizerItems,dwcResults,rgpICategorizerItemAttributes)	\
    (This)->lpVtbl -> SortQueryResult(This,__MIDL_0021,hrResolutionStatus,dwcAddresses,rgpICategorizerItems,dwcResults,rgpICategorizerItemAttributes)

#define IMailTransportCategorize_ProcessItem(This,__MIDL_0022,__MIDL_0023)	\
    (This)->lpVtbl -> ProcessItem(This,__MIDL_0022,__MIDL_0023)

#define IMailTransportCategorize_ExpandItem(This,__MIDL_0024,__MIDL_0025,__MIDL_0026,__MIDL_0027)	\
    (This)->lpVtbl -> ExpandItem(This,__MIDL_0024,__MIDL_0025,__MIDL_0026,__MIDL_0027)

#define IMailTransportCategorize_CompleteItem(This,__MIDL_0028,__MIDL_0029)	\
    (This)->lpVtbl -> CompleteItem(This,__MIDL_0028,__MIDL_0029)

#endif /* COBJMACROS */


#endif 	/* C style interface */



HRESULT STDMETHODCALLTYPE IMailTransportCategorize_Register_Proxy( 
    IMailTransportCategorize __RPC_FAR * This,
    /* [in] */ ICategorizerParameters __RPC_FAR *__MIDL_0011);


void __RPC_STUB IMailTransportCategorize_Register_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [local] */ HRESULT STDMETHODCALLTYPE IMailTransportCategorize_BeginMessageCategorization_Proxy( 
    IMailTransportCategorize __RPC_FAR * This,
    /* [in] */ ICategorizerMailMsgs __RPC_FAR *__MIDL_0012);


void __RPC_STUB IMailTransportCategorize_BeginMessageCategorization_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [local] */ HRESULT STDMETHODCALLTYPE IMailTransportCategorize_EndMessageCategorization_Proxy( 
    IMailTransportCategorize __RPC_FAR * This,
    /* [in] */ ICategorizerMailMsgs __RPC_FAR *__MIDL_0013,
    /* [in] */ HRESULT hrCatStatus);


void __RPC_STUB IMailTransportCategorize_EndMessageCategorization_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [local] */ HRESULT STDMETHODCALLTYPE IMailTransportCategorize_BuildQuery_Proxy( 
    IMailTransportCategorize __RPC_FAR * This,
    /* [in] */ ICategorizerParameters __RPC_FAR *__MIDL_0014,
    /* [in] */ ICategorizerItem __RPC_FAR *__MIDL_0015);


void __RPC_STUB IMailTransportCategorize_BuildQuery_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [local] */ HRESULT STDMETHODCALLTYPE IMailTransportCategorize_BuildQueries_Proxy( 
    IMailTransportCategorize __RPC_FAR * This,
    /* [in] */ ICategorizerParameters __RPC_FAR *__MIDL_0016,
    /* [in] */ DWORD dwcAddresses,
    /* [size_is][in] */ ICategorizerItem __RPC_FAR *__RPC_FAR *rgpICategorizerItems,
    /* [in] */ ICategorizerQueries __RPC_FAR *__MIDL_0017);


void __RPC_STUB IMailTransportCategorize_BuildQueries_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [local] */ HRESULT STDMETHODCALLTYPE IMailTransportCategorize_SendQuery_Proxy( 
    IMailTransportCategorize __RPC_FAR * This,
    /* [in] */ ICategorizerParameters __RPC_FAR *__MIDL_0018,
    /* [in] */ ICategorizerQueries __RPC_FAR *__MIDL_0019,
    /* [in] */ ICategorizerAsyncContext __RPC_FAR *__MIDL_0020,
    /* [in] */ PVOID pvQueryContext);


void __RPC_STUB IMailTransportCategorize_SendQuery_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [local] */ HRESULT STDMETHODCALLTYPE IMailTransportCategorize_SortQueryResult_Proxy( 
    IMailTransportCategorize __RPC_FAR * This,
    /* [in] */ ICategorizerParameters __RPC_FAR *__MIDL_0021,
    /* [in] */ HRESULT hrResolutionStatus,
    /* [in] */ DWORD dwcAddresses,
    /* [size_is][in] */ ICategorizerItem __RPC_FAR *__RPC_FAR *rgpICategorizerItems,
    /* [in] */ DWORD dwcResults,
    /* [size_is][in] */ ICategorizerItemAttributes __RPC_FAR *__RPC_FAR *rgpICategorizerItemAttributes);


void __RPC_STUB IMailTransportCategorize_SortQueryResult_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [local] */ HRESULT STDMETHODCALLTYPE IMailTransportCategorize_ProcessItem_Proxy( 
    IMailTransportCategorize __RPC_FAR * This,
    /* [in] */ ICategorizerParameters __RPC_FAR *__MIDL_0022,
    /* [in] */ ICategorizerItem __RPC_FAR *__MIDL_0023);


void __RPC_STUB IMailTransportCategorize_ProcessItem_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [local] */ HRESULT STDMETHODCALLTYPE IMailTransportCategorize_ExpandItem_Proxy( 
    IMailTransportCategorize __RPC_FAR * This,
    /* [in] */ ICategorizerParameters __RPC_FAR *__MIDL_0024,
    /* [in] */ ICategorizerItem __RPC_FAR *__MIDL_0025,
    /* [in] */ IMailTransportNotify __RPC_FAR *__MIDL_0026,
    /* [in] */ PVOID __MIDL_0027);


void __RPC_STUB IMailTransportCategorize_ExpandItem_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [local] */ HRESULT STDMETHODCALLTYPE IMailTransportCategorize_CompleteItem_Proxy( 
    IMailTransportCategorize __RPC_FAR * This,
    /* [in] */ ICategorizerParameters __RPC_FAR *__MIDL_0028,
    /* [in] */ ICategorizerItem __RPC_FAR *__MIDL_0029);


void __RPC_STUB IMailTransportCategorize_CompleteItem_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);



#endif 	/* __IMailTransportCategorize_INTERFACE_DEFINED__ */


#ifndef __ISMTPCategorizer_INTERFACE_DEFINED__
#define __ISMTPCategorizer_INTERFACE_DEFINED__

/* interface ISMTPCategorizer */
/* [unique][helpstring][uuid][local][object] */ 


EXTERN_C const IID IID_ISMTPCategorizer;

#if defined(__cplusplus) && !defined(CINTERFACE)
    
    MIDL_INTERFACE("B23C35B8-9219-11d2-9E17-00C04FA322BA")
    ISMTPCategorizer : public IUnknown
    {
    public:
        virtual HRESULT STDMETHODCALLTYPE ChangeConfig( 
            /* [in] */ PCCATCONFIGINFO pConfigInfo) = 0;
        
        virtual HRESULT STDMETHODCALLTYPE CatMsg( 
            /* [in] */ IUnknown __RPC_FAR *pMsg,
            /* [in] */ ISMTPCategorizerCompletion __RPC_FAR *pICompletion,
            /* [in] */ LPVOID pContext) = 0;
        
        virtual HRESULT STDMETHODCALLTYPE CatDLMsg( 
            /* [in] */ IUnknown __RPC_FAR *pMsg,
            /* [in] */ ISMTPCategorizerDLCompletion __RPC_FAR *pICompletion,
            /* [in] */ LPVOID pContext,
            /* [in] */ BOOL fMatchOnly,
            /* [in] */ CAT_ADDRESS_TYPE CAType,
            /* [in] */ LPSTR pszAddress) = 0;
        
        virtual HRESULT STDMETHODCALLTYPE CatCancel( void) = 0;
        
    };
    
#else 	/* C style interface */

    typedef struct ISMTPCategorizerVtbl
    {
        BEGIN_INTERFACE
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *QueryInterface )( 
            ISMTPCategorizer __RPC_FAR * This,
            /* [in] */ REFIID riid,
            /* [iid_is][out] */ void __RPC_FAR *__RPC_FAR *ppvObject);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *AddRef )( 
            ISMTPCategorizer __RPC_FAR * This);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *Release )( 
            ISMTPCategorizer __RPC_FAR * This);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *ChangeConfig )( 
            ISMTPCategorizer __RPC_FAR * This,
            /* [in] */ PCCATCONFIGINFO pConfigInfo);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *CatMsg )( 
            ISMTPCategorizer __RPC_FAR * This,
            /* [in] */ IUnknown __RPC_FAR *pMsg,
            /* [in] */ ISMTPCategorizerCompletion __RPC_FAR *pICompletion,
            /* [in] */ LPVOID pContext);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *CatDLMsg )( 
            ISMTPCategorizer __RPC_FAR * This,
            /* [in] */ IUnknown __RPC_FAR *pMsg,
            /* [in] */ ISMTPCategorizerDLCompletion __RPC_FAR *pICompletion,
            /* [in] */ LPVOID pContext,
            /* [in] */ BOOL fMatchOnly,
            /* [in] */ CAT_ADDRESS_TYPE CAType,
            /* [in] */ LPSTR pszAddress);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *CatCancel )( 
            ISMTPCategorizer __RPC_FAR * This);
        
        END_INTERFACE
    } ISMTPCategorizerVtbl;

    interface ISMTPCategorizer
    {
        CONST_VTBL struct ISMTPCategorizerVtbl __RPC_FAR *lpVtbl;
    };

    

#ifdef COBJMACROS


#define ISMTPCategorizer_QueryInterface(This,riid,ppvObject)	\
    (This)->lpVtbl -> QueryInterface(This,riid,ppvObject)

#define ISMTPCategorizer_AddRef(This)	\
    (This)->lpVtbl -> AddRef(This)

#define ISMTPCategorizer_Release(This)	\
    (This)->lpVtbl -> Release(This)


#define ISMTPCategorizer_ChangeConfig(This,pConfigInfo)	\
    (This)->lpVtbl -> ChangeConfig(This,pConfigInfo)

#define ISMTPCategorizer_CatMsg(This,pMsg,pICompletion,pContext)	\
    (This)->lpVtbl -> CatMsg(This,pMsg,pICompletion,pContext)

#define ISMTPCategorizer_CatDLMsg(This,pMsg,pICompletion,pContext,fMatchOnly,CAType,pszAddress)	\
    (This)->lpVtbl -> CatDLMsg(This,pMsg,pICompletion,pContext,fMatchOnly,CAType,pszAddress)

#define ISMTPCategorizer_CatCancel(This)	\
    (This)->lpVtbl -> CatCancel(This)

#endif /* COBJMACROS */


#endif 	/* C style interface */



HRESULT STDMETHODCALLTYPE ISMTPCategorizer_ChangeConfig_Proxy( 
    ISMTPCategorizer __RPC_FAR * This,
    /* [in] */ PCCATCONFIGINFO pConfigInfo);


void __RPC_STUB ISMTPCategorizer_ChangeConfig_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


HRESULT STDMETHODCALLTYPE ISMTPCategorizer_CatMsg_Proxy( 
    ISMTPCategorizer __RPC_FAR * This,
    /* [in] */ IUnknown __RPC_FAR *pMsg,
    /* [in] */ ISMTPCategorizerCompletion __RPC_FAR *pICompletion,
    /* [in] */ LPVOID pContext);


void __RPC_STUB ISMTPCategorizer_CatMsg_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


HRESULT STDMETHODCALLTYPE ISMTPCategorizer_CatDLMsg_Proxy( 
    ISMTPCategorizer __RPC_FAR * This,
    /* [in] */ IUnknown __RPC_FAR *pMsg,
    /* [in] */ ISMTPCategorizerDLCompletion __RPC_FAR *pICompletion,
    /* [in] */ LPVOID pContext,
    /* [in] */ BOOL fMatchOnly,
    /* [in] */ CAT_ADDRESS_TYPE CAType,
    /* [in] */ LPSTR pszAddress);


void __RPC_STUB ISMTPCategorizer_CatDLMsg_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


HRESULT STDMETHODCALLTYPE ISMTPCategorizer_CatCancel_Proxy( 
    ISMTPCategorizer __RPC_FAR * This);


void __RPC_STUB ISMTPCategorizer_CatCancel_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);



#endif 	/* __ISMTPCategorizer_INTERFACE_DEFINED__ */


#ifndef __ISMTPCategorizerCompletion_INTERFACE_DEFINED__
#define __ISMTPCategorizerCompletion_INTERFACE_DEFINED__

/* interface ISMTPCategorizerCompletion */
/* [unique][helpstring][uuid][local][object] */ 


EXTERN_C const IID IID_ISMTPCategorizerCompletion;

#if defined(__cplusplus) && !defined(CINTERFACE)
    
    MIDL_INTERFACE("B23C35B9-9219-11d2-9E17-00C04FA322BA")
    ISMTPCategorizerCompletion : public IUnknown
    {
    public:
        virtual HRESULT STDMETHODCALLTYPE CatCompletion( 
            HRESULT hr,
            PVOID pContext,
            IUnknown __RPC_FAR *pImsg,
            IUnknown __RPC_FAR *__RPC_FAR *rgpImsg) = 0;
        
    };
    
#else 	/* C style interface */

    typedef struct ISMTPCategorizerCompletionVtbl
    {
        BEGIN_INTERFACE
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *QueryInterface )( 
            ISMTPCategorizerCompletion __RPC_FAR * This,
            /* [in] */ REFIID riid,
            /* [iid_is][out] */ void __RPC_FAR *__RPC_FAR *ppvObject);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *AddRef )( 
            ISMTPCategorizerCompletion __RPC_FAR * This);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *Release )( 
            ISMTPCategorizerCompletion __RPC_FAR * This);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *CatCompletion )( 
            ISMTPCategorizerCompletion __RPC_FAR * This,
            HRESULT hr,
            PVOID pContext,
            IUnknown __RPC_FAR *pImsg,
            IUnknown __RPC_FAR *__RPC_FAR *rgpImsg);
        
        END_INTERFACE
    } ISMTPCategorizerCompletionVtbl;

    interface ISMTPCategorizerCompletion
    {
        CONST_VTBL struct ISMTPCategorizerCompletionVtbl __RPC_FAR *lpVtbl;
    };

    

#ifdef COBJMACROS


#define ISMTPCategorizerCompletion_QueryInterface(This,riid,ppvObject)	\
    (This)->lpVtbl -> QueryInterface(This,riid,ppvObject)

#define ISMTPCategorizerCompletion_AddRef(This)	\
    (This)->lpVtbl -> AddRef(This)

#define ISMTPCategorizerCompletion_Release(This)	\
    (This)->lpVtbl -> Release(This)


#define ISMTPCategorizerCompletion_CatCompletion(This,hr,pContext,pImsg,rgpImsg)	\
    (This)->lpVtbl -> CatCompletion(This,hr,pContext,pImsg,rgpImsg)

#endif /* COBJMACROS */


#endif 	/* C style interface */



HRESULT STDMETHODCALLTYPE ISMTPCategorizerCompletion_CatCompletion_Proxy( 
    ISMTPCategorizerCompletion __RPC_FAR * This,
    HRESULT hr,
    PVOID pContext,
    IUnknown __RPC_FAR *pImsg,
    IUnknown __RPC_FAR *__RPC_FAR *rgpImsg);


void __RPC_STUB ISMTPCategorizerCompletion_CatCompletion_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);



#endif 	/* __ISMTPCategorizerCompletion_INTERFACE_DEFINED__ */


#ifndef __ISMTPCategorizerDLCompletion_INTERFACE_DEFINED__
#define __ISMTPCategorizerDLCompletion_INTERFACE_DEFINED__

/* interface ISMTPCategorizerDLCompletion */
/* [unique][helpstring][uuid][local][object] */ 


EXTERN_C const IID IID_ISMTPCategorizerDLCompletion;

#if defined(__cplusplus) && !defined(CINTERFACE)
    
    MIDL_INTERFACE("B23C35BA-9219-11d2-9E17-00C04FA322BA")
    ISMTPCategorizerDLCompletion : public IUnknown
    {
    public:
        virtual HRESULT STDMETHODCALLTYPE CatDLCompletion( 
            HRESULT hr,
            PVOID pContext,
            IUnknown __RPC_FAR *pImsg,
            BOOL fMatch) = 0;
        
    };
    
#else 	/* C style interface */

    typedef struct ISMTPCategorizerDLCompletionVtbl
    {
        BEGIN_INTERFACE
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *QueryInterface )( 
            ISMTPCategorizerDLCompletion __RPC_FAR * This,
            /* [in] */ REFIID riid,
            /* [iid_is][out] */ void __RPC_FAR *__RPC_FAR *ppvObject);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *AddRef )( 
            ISMTPCategorizerDLCompletion __RPC_FAR * This);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *Release )( 
            ISMTPCategorizerDLCompletion __RPC_FAR * This);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *CatDLCompletion )( 
            ISMTPCategorizerDLCompletion __RPC_FAR * This,
            HRESULT hr,
            PVOID pContext,
            IUnknown __RPC_FAR *pImsg,
            BOOL fMatch);
        
        END_INTERFACE
    } ISMTPCategorizerDLCompletionVtbl;

    interface ISMTPCategorizerDLCompletion
    {
        CONST_VTBL struct ISMTPCategorizerDLCompletionVtbl __RPC_FAR *lpVtbl;
    };

    

#ifdef COBJMACROS


#define ISMTPCategorizerDLCompletion_QueryInterface(This,riid,ppvObject)	\
    (This)->lpVtbl -> QueryInterface(This,riid,ppvObject)

#define ISMTPCategorizerDLCompletion_AddRef(This)	\
    (This)->lpVtbl -> AddRef(This)

#define ISMTPCategorizerDLCompletion_Release(This)	\
    (This)->lpVtbl -> Release(This)


#define ISMTPCategorizerDLCompletion_CatDLCompletion(This,hr,pContext,pImsg,fMatch)	\
    (This)->lpVtbl -> CatDLCompletion(This,hr,pContext,pImsg,fMatch)

#endif /* COBJMACROS */


#endif 	/* C style interface */



HRESULT STDMETHODCALLTYPE ISMTPCategorizerDLCompletion_CatDLCompletion_Proxy( 
    ISMTPCategorizerDLCompletion __RPC_FAR * This,
    HRESULT hr,
    PVOID pContext,
    IUnknown __RPC_FAR *pImsg,
    BOOL fMatch);


void __RPC_STUB ISMTPCategorizerDLCompletion_CatDLCompletion_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);



#endif 	/* __ISMTPCategorizerDLCompletion_INTERFACE_DEFINED__ */


/* interface __MIDL_itf_SmtpEvent_0301 */
/* [local] */ 

typedef /* [public][v1_enum] */ 
enum __MIDL___MIDL_itf_SmtpEvent_0301_0001
    {	DOMAIN_INFO_REMOTE	= 0,
	DOMAIN_INFO_USE_SSL	= 0x1,
	DOMAIN_INFO_SEND_TURN	= 0x2,
	DOMAIN_INFO_SEND_ETRN	= 0x4,
	DOMAIN_INFO_USE_NTLM	= 0x8,
	DOMAIN_INFO_USE_PLAINTEXT	= 0x10,
	DOMAIN_INFO_USE_DPA	= 0x20,
	DOMAIN_INFO_USE_KERBEROS	= 0x40,
	DOMAIN_INFO_USE_CHUNKING	= 0x80,
	DOMAIN_INFO_DISABLE_CHUNKING	= 0x100,
	DOMAIN_INFO_DISABLE_BMIME	= 0x200,
	DOMAIN_INFO_DISABLE_DSN	= 0x400,
	DOMAIN_INFO_DISABLE_PIPELINE	= 0x800,
	DOMAIN_INFO_USE_HELO	= 0x1000,
	DOMAIN_INFO_TURN_ONLY	= 0x10000,
	DOMAIN_INFO_ETRN_ONLY	= 0x20000,
	DOMAIN_INFO_LOCAL_DROP	= 0x40000,
	DOMAIN_INFO_LOCAL_MAILBOX	= 0x80000,
	DOMAIN_INFO_REMOTE_SMARTHOST	= 0x100000,
	DOMAIN_INFO_IP_RELAY	= 0x200000,
	DOMAIN_INFO_AUTH_RELAY	= 0x400000,
	DOMAIN_INFO_DOMAIN_RELAY	= 0x800000,
	DOMAIN_INFO_ALIAS	= 0x1000000
    }	eDomainInfoFlags;



extern RPC_IF_HANDLE __MIDL_itf_SmtpEvent_0301_v0_0_c_ifspec;
extern RPC_IF_HANDLE __MIDL_itf_SmtpEvent_0301_v0_0_s_ifspec;

#ifndef __ICategorizerDomainInfo_INTERFACE_DEFINED__
#define __ICategorizerDomainInfo_INTERFACE_DEFINED__

/* interface ICategorizerDomainInfo */
/* [unique][helpstring][uuid][local][object] */ 


EXTERN_C const IID IID_ICategorizerDomainInfo;

#if defined(__cplusplus) && !defined(CINTERFACE)
    
    MIDL_INTERFACE("E210EDC6-F27D-481f-9DFC-1CA840905FD9")
    ICategorizerDomainInfo : public IUnknown
    {
    public:
        virtual HRESULT STDMETHODCALLTYPE GetDomainInfoFlags( 
            /* [string][in] */ LPSTR szDomainName,
            /* [out] */ DWORD __RPC_FAR *pdwDomainInfoFlags) = 0;
        
    };
    
#else 	/* C style interface */

    typedef struct ICategorizerDomainInfoVtbl
    {
        BEGIN_INTERFACE
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *QueryInterface )( 
            ICategorizerDomainInfo __RPC_FAR * This,
            /* [in] */ REFIID riid,
            /* [iid_is][out] */ void __RPC_FAR *__RPC_FAR *ppvObject);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *AddRef )( 
            ICategorizerDomainInfo __RPC_FAR * This);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *Release )( 
            ICategorizerDomainInfo __RPC_FAR * This);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetDomainInfoFlags )( 
            ICategorizerDomainInfo __RPC_FAR * This,
            /* [string][in] */ LPSTR szDomainName,
            /* [out] */ DWORD __RPC_FAR *pdwDomainInfoFlags);
        
        END_INTERFACE
    } ICategorizerDomainInfoVtbl;

    interface ICategorizerDomainInfo
    {
        CONST_VTBL struct ICategorizerDomainInfoVtbl __RPC_FAR *lpVtbl;
    };

    

#ifdef COBJMACROS


#define ICategorizerDomainInfo_QueryInterface(This,riid,ppvObject)	\
    (This)->lpVtbl -> QueryInterface(This,riid,ppvObject)

#define ICategorizerDomainInfo_AddRef(This)	\
    (This)->lpVtbl -> AddRef(This)

#define ICategorizerDomainInfo_Release(This)	\
    (This)->lpVtbl -> Release(This)


#define ICategorizerDomainInfo_GetDomainInfoFlags(This,szDomainName,pdwDomainInfoFlags)	\
    (This)->lpVtbl -> GetDomainInfoFlags(This,szDomainName,pdwDomainInfoFlags)

#endif /* COBJMACROS */


#endif 	/* C style interface */



HRESULT STDMETHODCALLTYPE ICategorizerDomainInfo_GetDomainInfoFlags_Proxy( 
    ICategorizerDomainInfo __RPC_FAR * This,
    /* [string][in] */ LPSTR szDomainName,
    /* [out] */ DWORD __RPC_FAR *pdwDomainInfoFlags);


void __RPC_STUB ICategorizerDomainInfo_GetDomainInfoFlags_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);



#endif 	/* __ICategorizerDomainInfo_INTERFACE_DEFINED__ */


/* interface __MIDL_itf_SmtpEvent_0302 */
/* [local] */ 

#endif //__SMTPEVENT_H__


extern RPC_IF_HANDLE __MIDL_itf_SmtpEvent_0302_v0_0_c_ifspec;
extern RPC_IF_HANDLE __MIDL_itf_SmtpEvent_0302_v0_0_s_ifspec;

/* Additional Prototypes for ALL interfaces */

/* end of Additional Prototypes */

#ifdef __cplusplus
}
#endif

#endif


