
#pragma warning( disable: 4049 )  /* more than 64k source lines */

/* this ALWAYS GENERATED file contains the definitions for the interfaces */


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

#ifndef __MailMsg_h__
#define __MailMsg_h__

/* Forward Declarations */ 

#ifndef __IMailMsgNotify_FWD_DEFINED__
#define __IMailMsgNotify_FWD_DEFINED__
typedef interface IMailMsgNotify IMailMsgNotify;
#endif 	/* __IMailMsgNotify_FWD_DEFINED__ */


#ifndef __IMailMsgPropertyStream_FWD_DEFINED__
#define __IMailMsgPropertyStream_FWD_DEFINED__
typedef interface IMailMsgPropertyStream IMailMsgPropertyStream;
#endif 	/* __IMailMsgPropertyStream_FWD_DEFINED__ */


#ifndef __IMailMsgRecipientsBase_FWD_DEFINED__
#define __IMailMsgRecipientsBase_FWD_DEFINED__
typedef interface IMailMsgRecipientsBase IMailMsgRecipientsBase;
#endif 	/* __IMailMsgRecipientsBase_FWD_DEFINED__ */


#ifndef __IMailMsgRecipientsAdd_FWD_DEFINED__
#define __IMailMsgRecipientsAdd_FWD_DEFINED__
typedef interface IMailMsgRecipientsAdd IMailMsgRecipientsAdd;
#endif 	/* __IMailMsgRecipientsAdd_FWD_DEFINED__ */


#ifndef __IMailMsgRecipients_FWD_DEFINED__
#define __IMailMsgRecipients_FWD_DEFINED__
typedef interface IMailMsgRecipients IMailMsgRecipients;
#endif 	/* __IMailMsgRecipients_FWD_DEFINED__ */


#ifndef __IMailMsgProperties_FWD_DEFINED__
#define __IMailMsgProperties_FWD_DEFINED__
typedef interface IMailMsgProperties IMailMsgProperties;
#endif 	/* __IMailMsgProperties_FWD_DEFINED__ */


#ifndef __IMailMsgValidate_FWD_DEFINED__
#define __IMailMsgValidate_FWD_DEFINED__
typedef interface IMailMsgValidate IMailMsgValidate;
#endif 	/* __IMailMsgValidate_FWD_DEFINED__ */


#ifndef __IMailMsgPropertyManagement_FWD_DEFINED__
#define __IMailMsgPropertyManagement_FWD_DEFINED__
typedef interface IMailMsgPropertyManagement IMailMsgPropertyManagement;
#endif 	/* __IMailMsgPropertyManagement_FWD_DEFINED__ */


#ifndef __IMailMsgEnumMessages_FWD_DEFINED__
#define __IMailMsgEnumMessages_FWD_DEFINED__
typedef interface IMailMsgEnumMessages IMailMsgEnumMessages;
#endif 	/* __IMailMsgEnumMessages_FWD_DEFINED__ */


#ifndef __IMailMsgStoreDriver_FWD_DEFINED__
#define __IMailMsgStoreDriver_FWD_DEFINED__
typedef interface IMailMsgStoreDriver IMailMsgStoreDriver;
#endif 	/* __IMailMsgStoreDriver_FWD_DEFINED__ */


#ifndef __IMailMsgQueueMgmt_FWD_DEFINED__
#define __IMailMsgQueueMgmt_FWD_DEFINED__
typedef interface IMailMsgQueueMgmt IMailMsgQueueMgmt;
#endif 	/* __IMailMsgQueueMgmt_FWD_DEFINED__ */


#ifndef __ISMTPStoreDriver_FWD_DEFINED__
#define __ISMTPStoreDriver_FWD_DEFINED__
typedef interface ISMTPStoreDriver ISMTPStoreDriver;
#endif 	/* __ISMTPStoreDriver_FWD_DEFINED__ */


#ifndef __IMailMsgBind_FWD_DEFINED__
#define __IMailMsgBind_FWD_DEFINED__
typedef interface IMailMsgBind IMailMsgBind;
#endif 	/* __IMailMsgBind_FWD_DEFINED__ */


#ifndef __IMailMsgPropertyBag_FWD_DEFINED__
#define __IMailMsgPropertyBag_FWD_DEFINED__
typedef interface IMailMsgPropertyBag IMailMsgPropertyBag;
#endif 	/* __IMailMsgPropertyBag_FWD_DEFINED__ */


#ifndef __IMailMsgLoggingPropertyBag_FWD_DEFINED__
#define __IMailMsgLoggingPropertyBag_FWD_DEFINED__
typedef interface IMailMsgLoggingPropertyBag IMailMsgLoggingPropertyBag;
#endif 	/* __IMailMsgLoggingPropertyBag_FWD_DEFINED__ */


#ifndef __IMailMsgCleanupCallback_FWD_DEFINED__
#define __IMailMsgCleanupCallback_FWD_DEFINED__
typedef interface IMailMsgCleanupCallback IMailMsgCleanupCallback;
#endif 	/* __IMailMsgCleanupCallback_FWD_DEFINED__ */


#ifndef __IMailMsgRegisterCleanupCallback_FWD_DEFINED__
#define __IMailMsgRegisterCleanupCallback_FWD_DEFINED__
typedef interface IMailMsgRegisterCleanupCallback IMailMsgRegisterCleanupCallback;
#endif 	/* __IMailMsgRegisterCleanupCallback_FWD_DEFINED__ */


#ifndef __ISMTPServer_FWD_DEFINED__
#define __ISMTPServer_FWD_DEFINED__
typedef interface ISMTPServer ISMTPServer;
#endif 	/* __ISMTPServer_FWD_DEFINED__ */


#ifndef __ISMTPServerInternal_FWD_DEFINED__
#define __ISMTPServerInternal_FWD_DEFINED__
typedef interface ISMTPServerInternal ISMTPServerInternal;
#endif 	/* __ISMTPServerInternal_FWD_DEFINED__ */


/* header files for imported files */
#include "oaidl.h"
#include "ocidl.h"

#ifdef __cplusplus
extern "C"{
#endif 

void __RPC_FAR * __RPC_USER MIDL_user_allocate(size_t);
void __RPC_USER MIDL_user_free( void __RPC_FAR * ); 

/* interface __MIDL_itf_MailMsg_0000 */
/* [local] */ 

/*++

Copyright (c) 1996 - 1999  Microsoft Corporation

Module Name:

     mailmsg.idl / mailmsg.h

Abstract:

     This module contains definitions for the COM interfaces for
     the Mail Message Object.

Author:

     Don Dumitru     (dondu@microsoft.com)

Revision History:

     dondu   2/24/98         created

--*/
#ifdef MIDL_PASS
typedef struct _FIO_CONTEXT
    {
    DWORD m_dwTempHack;
    DWORD m_dwSignature;
    HANDLE m_hFile;
    }	FIO_CONTEXT;

typedef struct _FIO_CONTEXT __RPC_FAR *PFIO_CONTEXT;

#endif
#include <filehc.h>
typedef struct _RECIPIENT_FILTER_CONTEXT
    {
    DWORD dwCurrentDomain;
    DWORD dwCurrentRecipientIndex;
    DWORD dwRecipientsLeftInDomain;
    DWORD dwNextDomain;
    DWORD dwFilterMask;
    DWORD dwFilterFlags;
    }	RECIPIENT_FILTER_CONTEXT;

typedef struct _RECIPIENT_FILTER_CONTEXT __RPC_FAR *LPRECIPIENT_FILTER_CONTEXT;

#define FLAG_FAIL_IF_SOURCE_DOMAIN_LINKED        0x00000001
#define FLAG_FAIL_IF_NEXT_DOMAIN_LINKED          0x00000002
#define FLAG_OVERWRITE_EXISTING_LINKS            0x00000004
#define FLAG_SET_FIRST_DOMAIN                    0x00000008
#define ADDRTYPE_SMTP 0
#define ADDRTYPE_X400 1
#define ADDRTYPE_X500 2
#define ADDRTYPE_LEGACY_EX_DN 3
#define ADDRTYPE_OTHER 4
#define MAILMSG_S_PENDING    MAKE_HRESULT(SEVERITY_SUCCESS,FACILITY_NT_BIT,STATUS_PENDING)
#define MAILMSG_E_DUPLICATE  HRESULT_FROM_WIN32(ERROR_FILE_EXISTS)
#define MAILMSG_E_PROPNOTFOUND  STG_E_UNKNOWN
#define MAILTRANSPORT_S_PENDING MAILMSG_S_PENDING
#define STOREDRV_E_RETRY   MAKE_HRESULT(SEVERITY_ERROR,FACILITY_ITF,ERROR_RETRY)
#define MAILMSG_AMF_MUSTCREATE    0x00000001
#define SMTP_INIT_VSERVER_STARTUP    0x00000001
#define SMTP_TERM_VSERVER_SHUTDOWN    0x00000002
#define SMTP_INIT_BINDING_CHANGE        0x00000003
#define SMTP_TERM_BINDING_CHANGE        0x00000004
#define MAILMSG_GETPROPS_COMPLETE    0x00000001
#define MAILMSG_GETPROPS_INCREMENTAL    0x00000002
#define MAILMSG_GETPROPS_CLEAR_DIRTY    0x00000004


extern RPC_IF_HANDLE __MIDL_itf_MailMsg_0000_v0_0_c_ifspec;
extern RPC_IF_HANDLE __MIDL_itf_MailMsg_0000_v0_0_s_ifspec;

#ifndef __IMailMsgNotify_INTERFACE_DEFINED__
#define __IMailMsgNotify_INTERFACE_DEFINED__

/* interface IMailMsgNotify */
/* [uuid][unique][object][helpstring] */ 


EXTERN_C const IID IID_IMailMsgNotify;

#if defined(__cplusplus) && !defined(CINTERFACE)
    
    MIDL_INTERFACE("0f7c3c30-a8ad-11d1-aa91-00aa006bc80b")
    IMailMsgNotify : public IUnknown
    {
    public:
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE Notify( 
            /* [in] */ HRESULT hrRes) = 0;
        
    };
    
#else 	/* C style interface */

    typedef struct IMailMsgNotifyVtbl
    {
        BEGIN_INTERFACE
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *QueryInterface )( 
            IMailMsgNotify __RPC_FAR * This,
            /* [in] */ REFIID riid,
            /* [iid_is][out] */ void __RPC_FAR *__RPC_FAR *ppvObject);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *AddRef )( 
            IMailMsgNotify __RPC_FAR * This);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *Release )( 
            IMailMsgNotify __RPC_FAR * This);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *Notify )( 
            IMailMsgNotify __RPC_FAR * This,
            /* [in] */ HRESULT hrRes);
        
        END_INTERFACE
    } IMailMsgNotifyVtbl;

    interface IMailMsgNotify
    {
        CONST_VTBL struct IMailMsgNotifyVtbl __RPC_FAR *lpVtbl;
    };

    

#ifdef COBJMACROS


#define IMailMsgNotify_QueryInterface(This,riid,ppvObject)	\
    (This)->lpVtbl -> QueryInterface(This,riid,ppvObject)

#define IMailMsgNotify_AddRef(This)	\
    (This)->lpVtbl -> AddRef(This)

#define IMailMsgNotify_Release(This)	\
    (This)->lpVtbl -> Release(This)


#define IMailMsgNotify_Notify(This,hrRes)	\
    (This)->lpVtbl -> Notify(This,hrRes)

#endif /* COBJMACROS */


#endif 	/* C style interface */



/* [helpstring] */ HRESULT STDMETHODCALLTYPE IMailMsgNotify_Notify_Proxy( 
    IMailMsgNotify __RPC_FAR * This,
    /* [in] */ HRESULT hrRes);


void __RPC_STUB IMailMsgNotify_Notify_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);



#endif 	/* __IMailMsgNotify_INTERFACE_DEFINED__ */


/* interface __MIDL_itf_MailMsg_0244 */
/* [local] */ 




extern RPC_IF_HANDLE __MIDL_itf_MailMsg_0244_v0_0_c_ifspec;
extern RPC_IF_HANDLE __MIDL_itf_MailMsg_0244_v0_0_s_ifspec;

#ifndef __IMailMsgPropertyStream_INTERFACE_DEFINED__
#define __IMailMsgPropertyStream_INTERFACE_DEFINED__

/* interface IMailMsgPropertyStream */
/* [uuid][unique][object][local][helpstring] */ 


EXTERN_C const IID IID_IMailMsgPropertyStream;

#if defined(__cplusplus) && !defined(CINTERFACE)
    
    MIDL_INTERFACE("a44819c0-a7cf-11d1-aa91-00aa006bc80b")
    IMailMsgPropertyStream : public IUnknown
    {
    public:
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE GetSize( 
            /* [in] */ IMailMsgProperties __RPC_FAR *pMsg,
            /* [out] */ DWORD __RPC_FAR *pdwSize,
            /* [unique][in] */ IMailMsgNotify __RPC_FAR *pNotify) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE ReadBlocks( 
            /* [in] */ IMailMsgProperties __RPC_FAR *pMsg,
            /* [in] */ DWORD dwCount,
            /* [unique][length_is][size_is][in] */ DWORD __RPC_FAR *pdwOffset,
            /* [unique][length_is][size_is][in] */ DWORD __RPC_FAR *pdwLength,
            /* [size_is][out] */ BYTE __RPC_FAR *__RPC_FAR *ppbBlock,
            /* [unique][in] */ IMailMsgNotify __RPC_FAR *pNotify) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE WriteBlocks( 
            /* [in] */ IMailMsgProperties __RPC_FAR *pMsg,
            /* [in] */ DWORD dwCount,
            /* [unique][length_is][size_is][in] */ DWORD __RPC_FAR *pdwOffset,
            /* [unique][length_is][size_is][in] */ DWORD __RPC_FAR *pdwLength,
            /* [size_is][in] */ BYTE __RPC_FAR *__RPC_FAR *ppbBlock,
            /* [unique][in] */ IMailMsgNotify __RPC_FAR *pNotify) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE StartWriteBlocks( 
            /* [in] */ IMailMsgProperties __RPC_FAR *pMsg,
            /* [in] */ DWORD dwBlocksToWrite,
            /* [in] */ DWORD dwTotalBytesToWrite) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE EndWriteBlocks( 
            /* [in] */ IMailMsgProperties __RPC_FAR *pMsg) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE CancelWriteBlocks( 
            /* [in] */ IMailMsgProperties __RPC_FAR *pMsg) = 0;
        
    };
    
#else 	/* C style interface */

    typedef struct IMailMsgPropertyStreamVtbl
    {
        BEGIN_INTERFACE
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *QueryInterface )( 
            IMailMsgPropertyStream __RPC_FAR * This,
            /* [in] */ REFIID riid,
            /* [iid_is][out] */ void __RPC_FAR *__RPC_FAR *ppvObject);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *AddRef )( 
            IMailMsgPropertyStream __RPC_FAR * This);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *Release )( 
            IMailMsgPropertyStream __RPC_FAR * This);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetSize )( 
            IMailMsgPropertyStream __RPC_FAR * This,
            /* [in] */ IMailMsgProperties __RPC_FAR *pMsg,
            /* [out] */ DWORD __RPC_FAR *pdwSize,
            /* [unique][in] */ IMailMsgNotify __RPC_FAR *pNotify);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *ReadBlocks )( 
            IMailMsgPropertyStream __RPC_FAR * This,
            /* [in] */ IMailMsgProperties __RPC_FAR *pMsg,
            /* [in] */ DWORD dwCount,
            /* [unique][length_is][size_is][in] */ DWORD __RPC_FAR *pdwOffset,
            /* [unique][length_is][size_is][in] */ DWORD __RPC_FAR *pdwLength,
            /* [size_is][out] */ BYTE __RPC_FAR *__RPC_FAR *ppbBlock,
            /* [unique][in] */ IMailMsgNotify __RPC_FAR *pNotify);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *WriteBlocks )( 
            IMailMsgPropertyStream __RPC_FAR * This,
            /* [in] */ IMailMsgProperties __RPC_FAR *pMsg,
            /* [in] */ DWORD dwCount,
            /* [unique][length_is][size_is][in] */ DWORD __RPC_FAR *pdwOffset,
            /* [unique][length_is][size_is][in] */ DWORD __RPC_FAR *pdwLength,
            /* [size_is][in] */ BYTE __RPC_FAR *__RPC_FAR *ppbBlock,
            /* [unique][in] */ IMailMsgNotify __RPC_FAR *pNotify);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *StartWriteBlocks )( 
            IMailMsgPropertyStream __RPC_FAR * This,
            /* [in] */ IMailMsgProperties __RPC_FAR *pMsg,
            /* [in] */ DWORD dwBlocksToWrite,
            /* [in] */ DWORD dwTotalBytesToWrite);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *EndWriteBlocks )( 
            IMailMsgPropertyStream __RPC_FAR * This,
            /* [in] */ IMailMsgProperties __RPC_FAR *pMsg);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *CancelWriteBlocks )( 
            IMailMsgPropertyStream __RPC_FAR * This,
            /* [in] */ IMailMsgProperties __RPC_FAR *pMsg);
        
        END_INTERFACE
    } IMailMsgPropertyStreamVtbl;

    interface IMailMsgPropertyStream
    {
        CONST_VTBL struct IMailMsgPropertyStreamVtbl __RPC_FAR *lpVtbl;
    };

    

#ifdef COBJMACROS


#define IMailMsgPropertyStream_QueryInterface(This,riid,ppvObject)	\
    (This)->lpVtbl -> QueryInterface(This,riid,ppvObject)

#define IMailMsgPropertyStream_AddRef(This)	\
    (This)->lpVtbl -> AddRef(This)

#define IMailMsgPropertyStream_Release(This)	\
    (This)->lpVtbl -> Release(This)


#define IMailMsgPropertyStream_GetSize(This,pMsg,pdwSize,pNotify)	\
    (This)->lpVtbl -> GetSize(This,pMsg,pdwSize,pNotify)

#define IMailMsgPropertyStream_ReadBlocks(This,pMsg,dwCount,pdwOffset,pdwLength,ppbBlock,pNotify)	\
    (This)->lpVtbl -> ReadBlocks(This,pMsg,dwCount,pdwOffset,pdwLength,ppbBlock,pNotify)

#define IMailMsgPropertyStream_WriteBlocks(This,pMsg,dwCount,pdwOffset,pdwLength,ppbBlock,pNotify)	\
    (This)->lpVtbl -> WriteBlocks(This,pMsg,dwCount,pdwOffset,pdwLength,ppbBlock,pNotify)

#define IMailMsgPropertyStream_StartWriteBlocks(This,pMsg,dwBlocksToWrite,dwTotalBytesToWrite)	\
    (This)->lpVtbl -> StartWriteBlocks(This,pMsg,dwBlocksToWrite,dwTotalBytesToWrite)

#define IMailMsgPropertyStream_EndWriteBlocks(This,pMsg)	\
    (This)->lpVtbl -> EndWriteBlocks(This,pMsg)

#define IMailMsgPropertyStream_CancelWriteBlocks(This,pMsg)	\
    (This)->lpVtbl -> CancelWriteBlocks(This,pMsg)

#endif /* COBJMACROS */


#endif 	/* C style interface */



/* [helpstring] */ HRESULT STDMETHODCALLTYPE IMailMsgPropertyStream_GetSize_Proxy( 
    IMailMsgPropertyStream __RPC_FAR * This,
    /* [in] */ IMailMsgProperties __RPC_FAR *pMsg,
    /* [out] */ DWORD __RPC_FAR *pdwSize,
    /* [unique][in] */ IMailMsgNotify __RPC_FAR *pNotify);


void __RPC_STUB IMailMsgPropertyStream_GetSize_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IMailMsgPropertyStream_ReadBlocks_Proxy( 
    IMailMsgPropertyStream __RPC_FAR * This,
    /* [in] */ IMailMsgProperties __RPC_FAR *pMsg,
    /* [in] */ DWORD dwCount,
    /* [unique][length_is][size_is][in] */ DWORD __RPC_FAR *pdwOffset,
    /* [unique][length_is][size_is][in] */ DWORD __RPC_FAR *pdwLength,
    /* [size_is][out] */ BYTE __RPC_FAR *__RPC_FAR *ppbBlock,
    /* [unique][in] */ IMailMsgNotify __RPC_FAR *pNotify);


void __RPC_STUB IMailMsgPropertyStream_ReadBlocks_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IMailMsgPropertyStream_WriteBlocks_Proxy( 
    IMailMsgPropertyStream __RPC_FAR * This,
    /* [in] */ IMailMsgProperties __RPC_FAR *pMsg,
    /* [in] */ DWORD dwCount,
    /* [unique][length_is][size_is][in] */ DWORD __RPC_FAR *pdwOffset,
    /* [unique][length_is][size_is][in] */ DWORD __RPC_FAR *pdwLength,
    /* [size_is][in] */ BYTE __RPC_FAR *__RPC_FAR *ppbBlock,
    /* [unique][in] */ IMailMsgNotify __RPC_FAR *pNotify);


void __RPC_STUB IMailMsgPropertyStream_WriteBlocks_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IMailMsgPropertyStream_StartWriteBlocks_Proxy( 
    IMailMsgPropertyStream __RPC_FAR * This,
    /* [in] */ IMailMsgProperties __RPC_FAR *pMsg,
    /* [in] */ DWORD dwBlocksToWrite,
    /* [in] */ DWORD dwTotalBytesToWrite);


void __RPC_STUB IMailMsgPropertyStream_StartWriteBlocks_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IMailMsgPropertyStream_EndWriteBlocks_Proxy( 
    IMailMsgPropertyStream __RPC_FAR * This,
    /* [in] */ IMailMsgProperties __RPC_FAR *pMsg);


void __RPC_STUB IMailMsgPropertyStream_EndWriteBlocks_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IMailMsgPropertyStream_CancelWriteBlocks_Proxy( 
    IMailMsgPropertyStream __RPC_FAR * This,
    /* [in] */ IMailMsgProperties __RPC_FAR *pMsg);


void __RPC_STUB IMailMsgPropertyStream_CancelWriteBlocks_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);



#endif 	/* __IMailMsgPropertyStream_INTERFACE_DEFINED__ */


#ifndef __IMailMsgRecipientsBase_INTERFACE_DEFINED__
#define __IMailMsgRecipientsBase_INTERFACE_DEFINED__

/* interface IMailMsgRecipientsBase */
/* [uuid][unique][object][helpstring] */ 


EXTERN_C const IID IID_IMailMsgRecipientsBase;

#if defined(__cplusplus) && !defined(CINTERFACE)
    
    MIDL_INTERFACE("d1a97920-a891-11d1-aa91-00aa006bc80b")
    IMailMsgRecipientsBase : public IUnknown
    {
    public:
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE Count( 
            /* [out] */ DWORD __RPC_FAR *pdwCount) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE Item( 
            /* [in] */ DWORD dwIndex,
            /* [in] */ DWORD dwWhichName,
            /* [in] */ DWORD cchLength,
            /* [size_is][out] */ LPSTR pszName) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE PutProperty( 
            /* [in] */ DWORD dwIndex,
            /* [in] */ DWORD dwPropID,
            /* [in] */ DWORD cbLength,
            /* [unique][length_is][size_is][in] */ BYTE __RPC_FAR *pbValue) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE GetProperty( 
            /* [in] */ DWORD dwIndex,
            /* [in] */ DWORD dwPropID,
            /* [in] */ DWORD cbLength,
            /* [out] */ DWORD __RPC_FAR *pcbLength,
            /* [length_is][size_is][out] */ BYTE __RPC_FAR *pbValue) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE PutStringA( 
            /* [in] */ DWORD dwIndex,
            /* [in] */ DWORD dwPropID,
            /* [unique][in] */ LPCSTR pszValue) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE GetStringA( 
            /* [in] */ DWORD dwIndex,
            /* [in] */ DWORD dwPropID,
            /* [in] */ DWORD cchLength,
            /* [size_is][out] */ LPSTR pszValue) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE PutStringW( 
            /* [in] */ DWORD dwIndex,
            /* [in] */ DWORD dwPropID,
            /* [unique][in] */ LPCWSTR pszValue) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE GetStringW( 
            /* [in] */ DWORD dwIndex,
            /* [in] */ DWORD dwPropID,
            /* [in] */ DWORD cchLength,
            /* [size_is][out] */ LPWSTR pszValue) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE PutDWORD( 
            /* [in] */ DWORD dwIndex,
            /* [in] */ DWORD dwPropID,
            /* [in] */ DWORD dwValue) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE GetDWORD( 
            /* [in] */ DWORD dwIndex,
            /* [in] */ DWORD dwPropID,
            /* [out] */ DWORD __RPC_FAR *pdwValue) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE PutBool( 
            /* [in] */ DWORD dwIndex,
            /* [in] */ DWORD dwPropID,
            /* [in] */ DWORD dwValue) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE GetBool( 
            /* [in] */ DWORD dwIndex,
            /* [in] */ DWORD dwPropID,
            /* [out] */ DWORD __RPC_FAR *pdwValue) = 0;
        
    };
    
#else 	/* C style interface */

    typedef struct IMailMsgRecipientsBaseVtbl
    {
        BEGIN_INTERFACE
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *QueryInterface )( 
            IMailMsgRecipientsBase __RPC_FAR * This,
            /* [in] */ REFIID riid,
            /* [iid_is][out] */ void __RPC_FAR *__RPC_FAR *ppvObject);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *AddRef )( 
            IMailMsgRecipientsBase __RPC_FAR * This);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *Release )( 
            IMailMsgRecipientsBase __RPC_FAR * This);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *Count )( 
            IMailMsgRecipientsBase __RPC_FAR * This,
            /* [out] */ DWORD __RPC_FAR *pdwCount);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *Item )( 
            IMailMsgRecipientsBase __RPC_FAR * This,
            /* [in] */ DWORD dwIndex,
            /* [in] */ DWORD dwWhichName,
            /* [in] */ DWORD cchLength,
            /* [size_is][out] */ LPSTR pszName);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *PutProperty )( 
            IMailMsgRecipientsBase __RPC_FAR * This,
            /* [in] */ DWORD dwIndex,
            /* [in] */ DWORD dwPropID,
            /* [in] */ DWORD cbLength,
            /* [unique][length_is][size_is][in] */ BYTE __RPC_FAR *pbValue);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetProperty )( 
            IMailMsgRecipientsBase __RPC_FAR * This,
            /* [in] */ DWORD dwIndex,
            /* [in] */ DWORD dwPropID,
            /* [in] */ DWORD cbLength,
            /* [out] */ DWORD __RPC_FAR *pcbLength,
            /* [length_is][size_is][out] */ BYTE __RPC_FAR *pbValue);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *PutStringA )( 
            IMailMsgRecipientsBase __RPC_FAR * This,
            /* [in] */ DWORD dwIndex,
            /* [in] */ DWORD dwPropID,
            /* [unique][in] */ LPCSTR pszValue);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetStringA )( 
            IMailMsgRecipientsBase __RPC_FAR * This,
            /* [in] */ DWORD dwIndex,
            /* [in] */ DWORD dwPropID,
            /* [in] */ DWORD cchLength,
            /* [size_is][out] */ LPSTR pszValue);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *PutStringW )( 
            IMailMsgRecipientsBase __RPC_FAR * This,
            /* [in] */ DWORD dwIndex,
            /* [in] */ DWORD dwPropID,
            /* [unique][in] */ LPCWSTR pszValue);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetStringW )( 
            IMailMsgRecipientsBase __RPC_FAR * This,
            /* [in] */ DWORD dwIndex,
            /* [in] */ DWORD dwPropID,
            /* [in] */ DWORD cchLength,
            /* [size_is][out] */ LPWSTR pszValue);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *PutDWORD )( 
            IMailMsgRecipientsBase __RPC_FAR * This,
            /* [in] */ DWORD dwIndex,
            /* [in] */ DWORD dwPropID,
            /* [in] */ DWORD dwValue);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetDWORD )( 
            IMailMsgRecipientsBase __RPC_FAR * This,
            /* [in] */ DWORD dwIndex,
            /* [in] */ DWORD dwPropID,
            /* [out] */ DWORD __RPC_FAR *pdwValue);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *PutBool )( 
            IMailMsgRecipientsBase __RPC_FAR * This,
            /* [in] */ DWORD dwIndex,
            /* [in] */ DWORD dwPropID,
            /* [in] */ DWORD dwValue);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetBool )( 
            IMailMsgRecipientsBase __RPC_FAR * This,
            /* [in] */ DWORD dwIndex,
            /* [in] */ DWORD dwPropID,
            /* [out] */ DWORD __RPC_FAR *pdwValue);
        
        END_INTERFACE
    } IMailMsgRecipientsBaseVtbl;

    interface IMailMsgRecipientsBase
    {
        CONST_VTBL struct IMailMsgRecipientsBaseVtbl __RPC_FAR *lpVtbl;
    };

    

#ifdef COBJMACROS


#define IMailMsgRecipientsBase_QueryInterface(This,riid,ppvObject)	\
    (This)->lpVtbl -> QueryInterface(This,riid,ppvObject)

#define IMailMsgRecipientsBase_AddRef(This)	\
    (This)->lpVtbl -> AddRef(This)

#define IMailMsgRecipientsBase_Release(This)	\
    (This)->lpVtbl -> Release(This)


#define IMailMsgRecipientsBase_Count(This,pdwCount)	\
    (This)->lpVtbl -> Count(This,pdwCount)

#define IMailMsgRecipientsBase_Item(This,dwIndex,dwWhichName,cchLength,pszName)	\
    (This)->lpVtbl -> Item(This,dwIndex,dwWhichName,cchLength,pszName)

#define IMailMsgRecipientsBase_PutProperty(This,dwIndex,dwPropID,cbLength,pbValue)	\
    (This)->lpVtbl -> PutProperty(This,dwIndex,dwPropID,cbLength,pbValue)

#define IMailMsgRecipientsBase_GetProperty(This,dwIndex,dwPropID,cbLength,pcbLength,pbValue)	\
    (This)->lpVtbl -> GetProperty(This,dwIndex,dwPropID,cbLength,pcbLength,pbValue)

#define IMailMsgRecipientsBase_PutStringA(This,dwIndex,dwPropID,pszValue)	\
    (This)->lpVtbl -> PutStringA(This,dwIndex,dwPropID,pszValue)

#define IMailMsgRecipientsBase_GetStringA(This,dwIndex,dwPropID,cchLength,pszValue)	\
    (This)->lpVtbl -> GetStringA(This,dwIndex,dwPropID,cchLength,pszValue)

#define IMailMsgRecipientsBase_PutStringW(This,dwIndex,dwPropID,pszValue)	\
    (This)->lpVtbl -> PutStringW(This,dwIndex,dwPropID,pszValue)

#define IMailMsgRecipientsBase_GetStringW(This,dwIndex,dwPropID,cchLength,pszValue)	\
    (This)->lpVtbl -> GetStringW(This,dwIndex,dwPropID,cchLength,pszValue)

#define IMailMsgRecipientsBase_PutDWORD(This,dwIndex,dwPropID,dwValue)	\
    (This)->lpVtbl -> PutDWORD(This,dwIndex,dwPropID,dwValue)

#define IMailMsgRecipientsBase_GetDWORD(This,dwIndex,dwPropID,pdwValue)	\
    (This)->lpVtbl -> GetDWORD(This,dwIndex,dwPropID,pdwValue)

#define IMailMsgRecipientsBase_PutBool(This,dwIndex,dwPropID,dwValue)	\
    (This)->lpVtbl -> PutBool(This,dwIndex,dwPropID,dwValue)

#define IMailMsgRecipientsBase_GetBool(This,dwIndex,dwPropID,pdwValue)	\
    (This)->lpVtbl -> GetBool(This,dwIndex,dwPropID,pdwValue)

#endif /* COBJMACROS */


#endif 	/* C style interface */



/* [helpstring] */ HRESULT STDMETHODCALLTYPE IMailMsgRecipientsBase_Count_Proxy( 
    IMailMsgRecipientsBase __RPC_FAR * This,
    /* [out] */ DWORD __RPC_FAR *pdwCount);


void __RPC_STUB IMailMsgRecipientsBase_Count_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IMailMsgRecipientsBase_Item_Proxy( 
    IMailMsgRecipientsBase __RPC_FAR * This,
    /* [in] */ DWORD dwIndex,
    /* [in] */ DWORD dwWhichName,
    /* [in] */ DWORD cchLength,
    /* [size_is][out] */ LPSTR pszName);


void __RPC_STUB IMailMsgRecipientsBase_Item_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IMailMsgRecipientsBase_PutProperty_Proxy( 
    IMailMsgRecipientsBase __RPC_FAR * This,
    /* [in] */ DWORD dwIndex,
    /* [in] */ DWORD dwPropID,
    /* [in] */ DWORD cbLength,
    /* [unique][length_is][size_is][in] */ BYTE __RPC_FAR *pbValue);


void __RPC_STUB IMailMsgRecipientsBase_PutProperty_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IMailMsgRecipientsBase_GetProperty_Proxy( 
    IMailMsgRecipientsBase __RPC_FAR * This,
    /* [in] */ DWORD dwIndex,
    /* [in] */ DWORD dwPropID,
    /* [in] */ DWORD cbLength,
    /* [out] */ DWORD __RPC_FAR *pcbLength,
    /* [length_is][size_is][out] */ BYTE __RPC_FAR *pbValue);


void __RPC_STUB IMailMsgRecipientsBase_GetProperty_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IMailMsgRecipientsBase_PutStringA_Proxy( 
    IMailMsgRecipientsBase __RPC_FAR * This,
    /* [in] */ DWORD dwIndex,
    /* [in] */ DWORD dwPropID,
    /* [unique][in] */ LPCSTR pszValue);


void __RPC_STUB IMailMsgRecipientsBase_PutStringA_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IMailMsgRecipientsBase_GetStringA_Proxy( 
    IMailMsgRecipientsBase __RPC_FAR * This,
    /* [in] */ DWORD dwIndex,
    /* [in] */ DWORD dwPropID,
    /* [in] */ DWORD cchLength,
    /* [size_is][out] */ LPSTR pszValue);


void __RPC_STUB IMailMsgRecipientsBase_GetStringA_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IMailMsgRecipientsBase_PutStringW_Proxy( 
    IMailMsgRecipientsBase __RPC_FAR * This,
    /* [in] */ DWORD dwIndex,
    /* [in] */ DWORD dwPropID,
    /* [unique][in] */ LPCWSTR pszValue);


void __RPC_STUB IMailMsgRecipientsBase_PutStringW_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IMailMsgRecipientsBase_GetStringW_Proxy( 
    IMailMsgRecipientsBase __RPC_FAR * This,
    /* [in] */ DWORD dwIndex,
    /* [in] */ DWORD dwPropID,
    /* [in] */ DWORD cchLength,
    /* [size_is][out] */ LPWSTR pszValue);


void __RPC_STUB IMailMsgRecipientsBase_GetStringW_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IMailMsgRecipientsBase_PutDWORD_Proxy( 
    IMailMsgRecipientsBase __RPC_FAR * This,
    /* [in] */ DWORD dwIndex,
    /* [in] */ DWORD dwPropID,
    /* [in] */ DWORD dwValue);


void __RPC_STUB IMailMsgRecipientsBase_PutDWORD_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IMailMsgRecipientsBase_GetDWORD_Proxy( 
    IMailMsgRecipientsBase __RPC_FAR * This,
    /* [in] */ DWORD dwIndex,
    /* [in] */ DWORD dwPropID,
    /* [out] */ DWORD __RPC_FAR *pdwValue);


void __RPC_STUB IMailMsgRecipientsBase_GetDWORD_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IMailMsgRecipientsBase_PutBool_Proxy( 
    IMailMsgRecipientsBase __RPC_FAR * This,
    /* [in] */ DWORD dwIndex,
    /* [in] */ DWORD dwPropID,
    /* [in] */ DWORD dwValue);


void __RPC_STUB IMailMsgRecipientsBase_PutBool_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IMailMsgRecipientsBase_GetBool_Proxy( 
    IMailMsgRecipientsBase __RPC_FAR * This,
    /* [in] */ DWORD dwIndex,
    /* [in] */ DWORD dwPropID,
    /* [out] */ DWORD __RPC_FAR *pdwValue);


void __RPC_STUB IMailMsgRecipientsBase_GetBool_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);



#endif 	/* __IMailMsgRecipientsBase_INTERFACE_DEFINED__ */


#ifndef __IMailMsgRecipientsAdd_INTERFACE_DEFINED__
#define __IMailMsgRecipientsAdd_INTERFACE_DEFINED__

/* interface IMailMsgRecipientsAdd */
/* [uuid][unique][object][helpstring] */ 


EXTERN_C const IID IID_IMailMsgRecipientsAdd;

#if defined(__cplusplus) && !defined(CINTERFACE)
    
    MIDL_INTERFACE("4c28a700-a892-11d1-aa91-00aa006bc80b")
    IMailMsgRecipientsAdd : public IMailMsgRecipientsBase
    {
    public:
        virtual /* [local][helpstring] */ HRESULT STDMETHODCALLTYPE AddPrimary( 
            /* [in] */ DWORD dwCount,
            /* [size_is][in] */ LPCSTR __RPC_FAR *ppszNames,
            /* [size_is][in] */ DWORD __RPC_FAR *pdwPropIDs,
            /* [out] */ DWORD __RPC_FAR *pdwIndex,
            /* [unique][in] */ IMailMsgRecipientsBase __RPC_FAR *pFrom,
            /* [in] */ DWORD dwFrom) = 0;
        
        virtual /* [local][helpstring] */ HRESULT STDMETHODCALLTYPE AddSecondary( 
            /* [in] */ DWORD dwCount,
            /* [size_is][in] */ LPCSTR __RPC_FAR *ppszNames,
            /* [size_is][in] */ DWORD __RPC_FAR *pdwPropIDs,
            /* [out] */ DWORD __RPC_FAR *pdwIndex,
            /* [unique][in] */ IMailMsgRecipientsBase __RPC_FAR *pFrom,
            /* [in] */ DWORD dwFrom) = 0;
        
    };
    
#else 	/* C style interface */

    typedef struct IMailMsgRecipientsAddVtbl
    {
        BEGIN_INTERFACE
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *QueryInterface )( 
            IMailMsgRecipientsAdd __RPC_FAR * This,
            /* [in] */ REFIID riid,
            /* [iid_is][out] */ void __RPC_FAR *__RPC_FAR *ppvObject);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *AddRef )( 
            IMailMsgRecipientsAdd __RPC_FAR * This);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *Release )( 
            IMailMsgRecipientsAdd __RPC_FAR * This);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *Count )( 
            IMailMsgRecipientsAdd __RPC_FAR * This,
            /* [out] */ DWORD __RPC_FAR *pdwCount);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *Item )( 
            IMailMsgRecipientsAdd __RPC_FAR * This,
            /* [in] */ DWORD dwIndex,
            /* [in] */ DWORD dwWhichName,
            /* [in] */ DWORD cchLength,
            /* [size_is][out] */ LPSTR pszName);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *PutProperty )( 
            IMailMsgRecipientsAdd __RPC_FAR * This,
            /* [in] */ DWORD dwIndex,
            /* [in] */ DWORD dwPropID,
            /* [in] */ DWORD cbLength,
            /* [unique][length_is][size_is][in] */ BYTE __RPC_FAR *pbValue);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetProperty )( 
            IMailMsgRecipientsAdd __RPC_FAR * This,
            /* [in] */ DWORD dwIndex,
            /* [in] */ DWORD dwPropID,
            /* [in] */ DWORD cbLength,
            /* [out] */ DWORD __RPC_FAR *pcbLength,
            /* [length_is][size_is][out] */ BYTE __RPC_FAR *pbValue);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *PutStringA )( 
            IMailMsgRecipientsAdd __RPC_FAR * This,
            /* [in] */ DWORD dwIndex,
            /* [in] */ DWORD dwPropID,
            /* [unique][in] */ LPCSTR pszValue);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetStringA )( 
            IMailMsgRecipientsAdd __RPC_FAR * This,
            /* [in] */ DWORD dwIndex,
            /* [in] */ DWORD dwPropID,
            /* [in] */ DWORD cchLength,
            /* [size_is][out] */ LPSTR pszValue);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *PutStringW )( 
            IMailMsgRecipientsAdd __RPC_FAR * This,
            /* [in] */ DWORD dwIndex,
            /* [in] */ DWORD dwPropID,
            /* [unique][in] */ LPCWSTR pszValue);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetStringW )( 
            IMailMsgRecipientsAdd __RPC_FAR * This,
            /* [in] */ DWORD dwIndex,
            /* [in] */ DWORD dwPropID,
            /* [in] */ DWORD cchLength,
            /* [size_is][out] */ LPWSTR pszValue);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *PutDWORD )( 
            IMailMsgRecipientsAdd __RPC_FAR * This,
            /* [in] */ DWORD dwIndex,
            /* [in] */ DWORD dwPropID,
            /* [in] */ DWORD dwValue);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetDWORD )( 
            IMailMsgRecipientsAdd __RPC_FAR * This,
            /* [in] */ DWORD dwIndex,
            /* [in] */ DWORD dwPropID,
            /* [out] */ DWORD __RPC_FAR *pdwValue);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *PutBool )( 
            IMailMsgRecipientsAdd __RPC_FAR * This,
            /* [in] */ DWORD dwIndex,
            /* [in] */ DWORD dwPropID,
            /* [in] */ DWORD dwValue);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetBool )( 
            IMailMsgRecipientsAdd __RPC_FAR * This,
            /* [in] */ DWORD dwIndex,
            /* [in] */ DWORD dwPropID,
            /* [out] */ DWORD __RPC_FAR *pdwValue);
        
        /* [local][helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *AddPrimary )( 
            IMailMsgRecipientsAdd __RPC_FAR * This,
            /* [in] */ DWORD dwCount,
            /* [size_is][in] */ LPCSTR __RPC_FAR *ppszNames,
            /* [size_is][in] */ DWORD __RPC_FAR *pdwPropIDs,
            /* [out] */ DWORD __RPC_FAR *pdwIndex,
            /* [unique][in] */ IMailMsgRecipientsBase __RPC_FAR *pFrom,
            /* [in] */ DWORD dwFrom);
        
        /* [local][helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *AddSecondary )( 
            IMailMsgRecipientsAdd __RPC_FAR * This,
            /* [in] */ DWORD dwCount,
            /* [size_is][in] */ LPCSTR __RPC_FAR *ppszNames,
            /* [size_is][in] */ DWORD __RPC_FAR *pdwPropIDs,
            /* [out] */ DWORD __RPC_FAR *pdwIndex,
            /* [unique][in] */ IMailMsgRecipientsBase __RPC_FAR *pFrom,
            /* [in] */ DWORD dwFrom);
        
        END_INTERFACE
    } IMailMsgRecipientsAddVtbl;

    interface IMailMsgRecipientsAdd
    {
        CONST_VTBL struct IMailMsgRecipientsAddVtbl __RPC_FAR *lpVtbl;
    };

    

#ifdef COBJMACROS


#define IMailMsgRecipientsAdd_QueryInterface(This,riid,ppvObject)	\
    (This)->lpVtbl -> QueryInterface(This,riid,ppvObject)

#define IMailMsgRecipientsAdd_AddRef(This)	\
    (This)->lpVtbl -> AddRef(This)

#define IMailMsgRecipientsAdd_Release(This)	\
    (This)->lpVtbl -> Release(This)


#define IMailMsgRecipientsAdd_Count(This,pdwCount)	\
    (This)->lpVtbl -> Count(This,pdwCount)

#define IMailMsgRecipientsAdd_Item(This,dwIndex,dwWhichName,cchLength,pszName)	\
    (This)->lpVtbl -> Item(This,dwIndex,dwWhichName,cchLength,pszName)

#define IMailMsgRecipientsAdd_PutProperty(This,dwIndex,dwPropID,cbLength,pbValue)	\
    (This)->lpVtbl -> PutProperty(This,dwIndex,dwPropID,cbLength,pbValue)

#define IMailMsgRecipientsAdd_GetProperty(This,dwIndex,dwPropID,cbLength,pcbLength,pbValue)	\
    (This)->lpVtbl -> GetProperty(This,dwIndex,dwPropID,cbLength,pcbLength,pbValue)

#define IMailMsgRecipientsAdd_PutStringA(This,dwIndex,dwPropID,pszValue)	\
    (This)->lpVtbl -> PutStringA(This,dwIndex,dwPropID,pszValue)

#define IMailMsgRecipientsAdd_GetStringA(This,dwIndex,dwPropID,cchLength,pszValue)	\
    (This)->lpVtbl -> GetStringA(This,dwIndex,dwPropID,cchLength,pszValue)

#define IMailMsgRecipientsAdd_PutStringW(This,dwIndex,dwPropID,pszValue)	\
    (This)->lpVtbl -> PutStringW(This,dwIndex,dwPropID,pszValue)

#define IMailMsgRecipientsAdd_GetStringW(This,dwIndex,dwPropID,cchLength,pszValue)	\
    (This)->lpVtbl -> GetStringW(This,dwIndex,dwPropID,cchLength,pszValue)

#define IMailMsgRecipientsAdd_PutDWORD(This,dwIndex,dwPropID,dwValue)	\
    (This)->lpVtbl -> PutDWORD(This,dwIndex,dwPropID,dwValue)

#define IMailMsgRecipientsAdd_GetDWORD(This,dwIndex,dwPropID,pdwValue)	\
    (This)->lpVtbl -> GetDWORD(This,dwIndex,dwPropID,pdwValue)

#define IMailMsgRecipientsAdd_PutBool(This,dwIndex,dwPropID,dwValue)	\
    (This)->lpVtbl -> PutBool(This,dwIndex,dwPropID,dwValue)

#define IMailMsgRecipientsAdd_GetBool(This,dwIndex,dwPropID,pdwValue)	\
    (This)->lpVtbl -> GetBool(This,dwIndex,dwPropID,pdwValue)


#define IMailMsgRecipientsAdd_AddPrimary(This,dwCount,ppszNames,pdwPropIDs,pdwIndex,pFrom,dwFrom)	\
    (This)->lpVtbl -> AddPrimary(This,dwCount,ppszNames,pdwPropIDs,pdwIndex,pFrom,dwFrom)

#define IMailMsgRecipientsAdd_AddSecondary(This,dwCount,ppszNames,pdwPropIDs,pdwIndex,pFrom,dwFrom)	\
    (This)->lpVtbl -> AddSecondary(This,dwCount,ppszNames,pdwPropIDs,pdwIndex,pFrom,dwFrom)

#endif /* COBJMACROS */


#endif 	/* C style interface */



/* [local][helpstring] */ HRESULT STDMETHODCALLTYPE IMailMsgRecipientsAdd_AddPrimary_Proxy( 
    IMailMsgRecipientsAdd __RPC_FAR * This,
    /* [in] */ DWORD dwCount,
    /* [size_is][in] */ LPCSTR __RPC_FAR *ppszNames,
    /* [size_is][in] */ DWORD __RPC_FAR *pdwPropIDs,
    /* [out] */ DWORD __RPC_FAR *pdwIndex,
    /* [unique][in] */ IMailMsgRecipientsBase __RPC_FAR *pFrom,
    /* [in] */ DWORD dwFrom);


void __RPC_STUB IMailMsgRecipientsAdd_AddPrimary_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [local][helpstring] */ HRESULT STDMETHODCALLTYPE IMailMsgRecipientsAdd_AddSecondary_Proxy( 
    IMailMsgRecipientsAdd __RPC_FAR * This,
    /* [in] */ DWORD dwCount,
    /* [size_is][in] */ LPCSTR __RPC_FAR *ppszNames,
    /* [size_is][in] */ DWORD __RPC_FAR *pdwPropIDs,
    /* [out] */ DWORD __RPC_FAR *pdwIndex,
    /* [unique][in] */ IMailMsgRecipientsBase __RPC_FAR *pFrom,
    /* [in] */ DWORD dwFrom);


void __RPC_STUB IMailMsgRecipientsAdd_AddSecondary_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);



#endif 	/* __IMailMsgRecipientsAdd_INTERFACE_DEFINED__ */


#ifndef __IMailMsgRecipients_INTERFACE_DEFINED__
#define __IMailMsgRecipients_INTERFACE_DEFINED__

/* interface IMailMsgRecipients */
/* [uuid][unique][object][helpstring] */ 


EXTERN_C const IID IID_IMailMsgRecipients;

#if defined(__cplusplus) && !defined(CINTERFACE)
    
    MIDL_INTERFACE("19507fe0-a892-11d1-aa91-00aa006bc80b")
    IMailMsgRecipients : public IMailMsgRecipientsBase
    {
    public:
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE Commit( 
            /* [in] */ DWORD dwIndex,
            /* [unique][in] */ IMailMsgNotify __RPC_FAR *pNotify) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE DomainCount( 
            /* [out] */ DWORD __RPC_FAR *pdwCount) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE DomainItem( 
            /* [in] */ DWORD dwIndex,
            /* [in] */ DWORD cchLength,
            /* [size_is][out] */ LPSTR pszDomain,
            /* [out] */ DWORD __RPC_FAR *pdwRecipientIndex,
            /* [out] */ DWORD __RPC_FAR *pdwRecipientCount) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE AllocNewList( 
            /* [out] */ IMailMsgRecipientsAdd __RPC_FAR *__RPC_FAR *ppNewList) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE WriteList( 
            /* [unique][in] */ IMailMsgRecipientsAdd __RPC_FAR *pNewList) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE SetNextDomain( 
            /* [in] */ DWORD dwDomainIndex,
            /* [in] */ DWORD dwNextDomainIndex,
            /* [in] */ DWORD dwFlags) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE InitializeRecipientFilterContext( 
            /* [unique][in] */ LPRECIPIENT_FILTER_CONTEXT pContext,
            /* [in] */ DWORD dwStartingDomain,
            /* [in] */ DWORD dwFilterFlags,
            /* [in] */ DWORD dwFilterMask) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE TerminateRecipientFilterContext( 
            /* [unique][in] */ LPRECIPIENT_FILTER_CONTEXT pContext) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE GetNextRecipient( 
            /* [unique][in] */ LPRECIPIENT_FILTER_CONTEXT pContext,
            /* [out] */ DWORD __RPC_FAR *pdwRecipientIndex) = 0;
        
    };
    
#else 	/* C style interface */

    typedef struct IMailMsgRecipientsVtbl
    {
        BEGIN_INTERFACE
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *QueryInterface )( 
            IMailMsgRecipients __RPC_FAR * This,
            /* [in] */ REFIID riid,
            /* [iid_is][out] */ void __RPC_FAR *__RPC_FAR *ppvObject);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *AddRef )( 
            IMailMsgRecipients __RPC_FAR * This);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *Release )( 
            IMailMsgRecipients __RPC_FAR * This);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *Count )( 
            IMailMsgRecipients __RPC_FAR * This,
            /* [out] */ DWORD __RPC_FAR *pdwCount);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *Item )( 
            IMailMsgRecipients __RPC_FAR * This,
            /* [in] */ DWORD dwIndex,
            /* [in] */ DWORD dwWhichName,
            /* [in] */ DWORD cchLength,
            /* [size_is][out] */ LPSTR pszName);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *PutProperty )( 
            IMailMsgRecipients __RPC_FAR * This,
            /* [in] */ DWORD dwIndex,
            /* [in] */ DWORD dwPropID,
            /* [in] */ DWORD cbLength,
            /* [unique][length_is][size_is][in] */ BYTE __RPC_FAR *pbValue);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetProperty )( 
            IMailMsgRecipients __RPC_FAR * This,
            /* [in] */ DWORD dwIndex,
            /* [in] */ DWORD dwPropID,
            /* [in] */ DWORD cbLength,
            /* [out] */ DWORD __RPC_FAR *pcbLength,
            /* [length_is][size_is][out] */ BYTE __RPC_FAR *pbValue);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *PutStringA )( 
            IMailMsgRecipients __RPC_FAR * This,
            /* [in] */ DWORD dwIndex,
            /* [in] */ DWORD dwPropID,
            /* [unique][in] */ LPCSTR pszValue);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetStringA )( 
            IMailMsgRecipients __RPC_FAR * This,
            /* [in] */ DWORD dwIndex,
            /* [in] */ DWORD dwPropID,
            /* [in] */ DWORD cchLength,
            /* [size_is][out] */ LPSTR pszValue);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *PutStringW )( 
            IMailMsgRecipients __RPC_FAR * This,
            /* [in] */ DWORD dwIndex,
            /* [in] */ DWORD dwPropID,
            /* [unique][in] */ LPCWSTR pszValue);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetStringW )( 
            IMailMsgRecipients __RPC_FAR * This,
            /* [in] */ DWORD dwIndex,
            /* [in] */ DWORD dwPropID,
            /* [in] */ DWORD cchLength,
            /* [size_is][out] */ LPWSTR pszValue);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *PutDWORD )( 
            IMailMsgRecipients __RPC_FAR * This,
            /* [in] */ DWORD dwIndex,
            /* [in] */ DWORD dwPropID,
            /* [in] */ DWORD dwValue);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetDWORD )( 
            IMailMsgRecipients __RPC_FAR * This,
            /* [in] */ DWORD dwIndex,
            /* [in] */ DWORD dwPropID,
            /* [out] */ DWORD __RPC_FAR *pdwValue);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *PutBool )( 
            IMailMsgRecipients __RPC_FAR * This,
            /* [in] */ DWORD dwIndex,
            /* [in] */ DWORD dwPropID,
            /* [in] */ DWORD dwValue);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetBool )( 
            IMailMsgRecipients __RPC_FAR * This,
            /* [in] */ DWORD dwIndex,
            /* [in] */ DWORD dwPropID,
            /* [out] */ DWORD __RPC_FAR *pdwValue);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *Commit )( 
            IMailMsgRecipients __RPC_FAR * This,
            /* [in] */ DWORD dwIndex,
            /* [unique][in] */ IMailMsgNotify __RPC_FAR *pNotify);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *DomainCount )( 
            IMailMsgRecipients __RPC_FAR * This,
            /* [out] */ DWORD __RPC_FAR *pdwCount);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *DomainItem )( 
            IMailMsgRecipients __RPC_FAR * This,
            /* [in] */ DWORD dwIndex,
            /* [in] */ DWORD cchLength,
            /* [size_is][out] */ LPSTR pszDomain,
            /* [out] */ DWORD __RPC_FAR *pdwRecipientIndex,
            /* [out] */ DWORD __RPC_FAR *pdwRecipientCount);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *AllocNewList )( 
            IMailMsgRecipients __RPC_FAR * This,
            /* [out] */ IMailMsgRecipientsAdd __RPC_FAR *__RPC_FAR *ppNewList);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *WriteList )( 
            IMailMsgRecipients __RPC_FAR * This,
            /* [unique][in] */ IMailMsgRecipientsAdd __RPC_FAR *pNewList);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *SetNextDomain )( 
            IMailMsgRecipients __RPC_FAR * This,
            /* [in] */ DWORD dwDomainIndex,
            /* [in] */ DWORD dwNextDomainIndex,
            /* [in] */ DWORD dwFlags);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *InitializeRecipientFilterContext )( 
            IMailMsgRecipients __RPC_FAR * This,
            /* [unique][in] */ LPRECIPIENT_FILTER_CONTEXT pContext,
            /* [in] */ DWORD dwStartingDomain,
            /* [in] */ DWORD dwFilterFlags,
            /* [in] */ DWORD dwFilterMask);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *TerminateRecipientFilterContext )( 
            IMailMsgRecipients __RPC_FAR * This,
            /* [unique][in] */ LPRECIPIENT_FILTER_CONTEXT pContext);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetNextRecipient )( 
            IMailMsgRecipients __RPC_FAR * This,
            /* [unique][in] */ LPRECIPIENT_FILTER_CONTEXT pContext,
            /* [out] */ DWORD __RPC_FAR *pdwRecipientIndex);
        
        END_INTERFACE
    } IMailMsgRecipientsVtbl;

    interface IMailMsgRecipients
    {
        CONST_VTBL struct IMailMsgRecipientsVtbl __RPC_FAR *lpVtbl;
    };

    

#ifdef COBJMACROS


#define IMailMsgRecipients_QueryInterface(This,riid,ppvObject)	\
    (This)->lpVtbl -> QueryInterface(This,riid,ppvObject)

#define IMailMsgRecipients_AddRef(This)	\
    (This)->lpVtbl -> AddRef(This)

#define IMailMsgRecipients_Release(This)	\
    (This)->lpVtbl -> Release(This)


#define IMailMsgRecipients_Count(This,pdwCount)	\
    (This)->lpVtbl -> Count(This,pdwCount)

#define IMailMsgRecipients_Item(This,dwIndex,dwWhichName,cchLength,pszName)	\
    (This)->lpVtbl -> Item(This,dwIndex,dwWhichName,cchLength,pszName)

#define IMailMsgRecipients_PutProperty(This,dwIndex,dwPropID,cbLength,pbValue)	\
    (This)->lpVtbl -> PutProperty(This,dwIndex,dwPropID,cbLength,pbValue)

#define IMailMsgRecipients_GetProperty(This,dwIndex,dwPropID,cbLength,pcbLength,pbValue)	\
    (This)->lpVtbl -> GetProperty(This,dwIndex,dwPropID,cbLength,pcbLength,pbValue)

#define IMailMsgRecipients_PutStringA(This,dwIndex,dwPropID,pszValue)	\
    (This)->lpVtbl -> PutStringA(This,dwIndex,dwPropID,pszValue)

#define IMailMsgRecipients_GetStringA(This,dwIndex,dwPropID,cchLength,pszValue)	\
    (This)->lpVtbl -> GetStringA(This,dwIndex,dwPropID,cchLength,pszValue)

#define IMailMsgRecipients_PutStringW(This,dwIndex,dwPropID,pszValue)	\
    (This)->lpVtbl -> PutStringW(This,dwIndex,dwPropID,pszValue)

#define IMailMsgRecipients_GetStringW(This,dwIndex,dwPropID,cchLength,pszValue)	\
    (This)->lpVtbl -> GetStringW(This,dwIndex,dwPropID,cchLength,pszValue)

#define IMailMsgRecipients_PutDWORD(This,dwIndex,dwPropID,dwValue)	\
    (This)->lpVtbl -> PutDWORD(This,dwIndex,dwPropID,dwValue)

#define IMailMsgRecipients_GetDWORD(This,dwIndex,dwPropID,pdwValue)	\
    (This)->lpVtbl -> GetDWORD(This,dwIndex,dwPropID,pdwValue)

#define IMailMsgRecipients_PutBool(This,dwIndex,dwPropID,dwValue)	\
    (This)->lpVtbl -> PutBool(This,dwIndex,dwPropID,dwValue)

#define IMailMsgRecipients_GetBool(This,dwIndex,dwPropID,pdwValue)	\
    (This)->lpVtbl -> GetBool(This,dwIndex,dwPropID,pdwValue)


#define IMailMsgRecipients_Commit(This,dwIndex,pNotify)	\
    (This)->lpVtbl -> Commit(This,dwIndex,pNotify)

#define IMailMsgRecipients_DomainCount(This,pdwCount)	\
    (This)->lpVtbl -> DomainCount(This,pdwCount)

#define IMailMsgRecipients_DomainItem(This,dwIndex,cchLength,pszDomain,pdwRecipientIndex,pdwRecipientCount)	\
    (This)->lpVtbl -> DomainItem(This,dwIndex,cchLength,pszDomain,pdwRecipientIndex,pdwRecipientCount)

#define IMailMsgRecipients_AllocNewList(This,ppNewList)	\
    (This)->lpVtbl -> AllocNewList(This,ppNewList)

#define IMailMsgRecipients_WriteList(This,pNewList)	\
    (This)->lpVtbl -> WriteList(This,pNewList)

#define IMailMsgRecipients_SetNextDomain(This,dwDomainIndex,dwNextDomainIndex,dwFlags)	\
    (This)->lpVtbl -> SetNextDomain(This,dwDomainIndex,dwNextDomainIndex,dwFlags)

#define IMailMsgRecipients_InitializeRecipientFilterContext(This,pContext,dwStartingDomain,dwFilterFlags,dwFilterMask)	\
    (This)->lpVtbl -> InitializeRecipientFilterContext(This,pContext,dwStartingDomain,dwFilterFlags,dwFilterMask)

#define IMailMsgRecipients_TerminateRecipientFilterContext(This,pContext)	\
    (This)->lpVtbl -> TerminateRecipientFilterContext(This,pContext)

#define IMailMsgRecipients_GetNextRecipient(This,pContext,pdwRecipientIndex)	\
    (This)->lpVtbl -> GetNextRecipient(This,pContext,pdwRecipientIndex)

#endif /* COBJMACROS */


#endif 	/* C style interface */



/* [helpstring] */ HRESULT STDMETHODCALLTYPE IMailMsgRecipients_Commit_Proxy( 
    IMailMsgRecipients __RPC_FAR * This,
    /* [in] */ DWORD dwIndex,
    /* [unique][in] */ IMailMsgNotify __RPC_FAR *pNotify);


void __RPC_STUB IMailMsgRecipients_Commit_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IMailMsgRecipients_DomainCount_Proxy( 
    IMailMsgRecipients __RPC_FAR * This,
    /* [out] */ DWORD __RPC_FAR *pdwCount);


void __RPC_STUB IMailMsgRecipients_DomainCount_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IMailMsgRecipients_DomainItem_Proxy( 
    IMailMsgRecipients __RPC_FAR * This,
    /* [in] */ DWORD dwIndex,
    /* [in] */ DWORD cchLength,
    /* [size_is][out] */ LPSTR pszDomain,
    /* [out] */ DWORD __RPC_FAR *pdwRecipientIndex,
    /* [out] */ DWORD __RPC_FAR *pdwRecipientCount);


void __RPC_STUB IMailMsgRecipients_DomainItem_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IMailMsgRecipients_AllocNewList_Proxy( 
    IMailMsgRecipients __RPC_FAR * This,
    /* [out] */ IMailMsgRecipientsAdd __RPC_FAR *__RPC_FAR *ppNewList);


void __RPC_STUB IMailMsgRecipients_AllocNewList_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IMailMsgRecipients_WriteList_Proxy( 
    IMailMsgRecipients __RPC_FAR * This,
    /* [unique][in] */ IMailMsgRecipientsAdd __RPC_FAR *pNewList);


void __RPC_STUB IMailMsgRecipients_WriteList_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IMailMsgRecipients_SetNextDomain_Proxy( 
    IMailMsgRecipients __RPC_FAR * This,
    /* [in] */ DWORD dwDomainIndex,
    /* [in] */ DWORD dwNextDomainIndex,
    /* [in] */ DWORD dwFlags);


void __RPC_STUB IMailMsgRecipients_SetNextDomain_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IMailMsgRecipients_InitializeRecipientFilterContext_Proxy( 
    IMailMsgRecipients __RPC_FAR * This,
    /* [unique][in] */ LPRECIPIENT_FILTER_CONTEXT pContext,
    /* [in] */ DWORD dwStartingDomain,
    /* [in] */ DWORD dwFilterFlags,
    /* [in] */ DWORD dwFilterMask);


void __RPC_STUB IMailMsgRecipients_InitializeRecipientFilterContext_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IMailMsgRecipients_TerminateRecipientFilterContext_Proxy( 
    IMailMsgRecipients __RPC_FAR * This,
    /* [unique][in] */ LPRECIPIENT_FILTER_CONTEXT pContext);


void __RPC_STUB IMailMsgRecipients_TerminateRecipientFilterContext_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IMailMsgRecipients_GetNextRecipient_Proxy( 
    IMailMsgRecipients __RPC_FAR * This,
    /* [unique][in] */ LPRECIPIENT_FILTER_CONTEXT pContext,
    /* [out] */ DWORD __RPC_FAR *pdwRecipientIndex);


void __RPC_STUB IMailMsgRecipients_GetNextRecipient_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);



#endif 	/* __IMailMsgRecipients_INTERFACE_DEFINED__ */


#ifndef __IMailMsgProperties_INTERFACE_DEFINED__
#define __IMailMsgProperties_INTERFACE_DEFINED__

/* interface IMailMsgProperties */
/* [uuid][unique][object][local][helpstring] */ 


EXTERN_C const IID IID_IMailMsgProperties;

#if defined(__cplusplus) && !defined(CINTERFACE)
    
    MIDL_INTERFACE("ab95fb40-a34f-11d1-aa8a-00aa006bc80b")
    IMailMsgProperties : public IUnknown
    {
    public:
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE PutProperty( 
            /* [in] */ DWORD dwPropID,
            /* [in] */ DWORD cbLength,
            /* [unique][length_is][size_is][in] */ BYTE __RPC_FAR *pbValue) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE GetProperty( 
            /* [in] */ DWORD dwPropID,
            /* [in] */ DWORD cbLength,
            /* [out] */ DWORD __RPC_FAR *pcbLength,
            /* [length_is][size_is][out] */ BYTE __RPC_FAR *pbValue) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE Commit( 
            /* [unique][in] */ IMailMsgNotify __RPC_FAR *pNotify) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE PutStringA( 
            /* [in] */ DWORD dwPropID,
            /* [unique][in] */ LPCSTR pszValue) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE GetStringA( 
            /* [in] */ DWORD dwPropID,
            /* [in] */ DWORD cchLength,
            /* [size_is][out] */ LPSTR pszValue) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE PutStringW( 
            /* [in] */ DWORD dwPropID,
            /* [unique][in] */ LPCWSTR pszValue) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE GetStringW( 
            /* [in] */ DWORD dwPropID,
            /* [in] */ DWORD cchLength,
            /* [size_is][out] */ LPWSTR pszValue) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE PutDWORD( 
            /* [in] */ DWORD dwPropID,
            /* [in] */ DWORD dwValue) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE GetDWORD( 
            /* [in] */ DWORD dwPropID,
            /* [out] */ DWORD __RPC_FAR *pdwValue) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE PutBool( 
            /* [in] */ DWORD dwPropID,
            /* [in] */ DWORD bValue) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE GetBool( 
            /* [in] */ DWORD dwPropID,
            /* [out] */ DWORD __RPC_FAR *pbValue) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE GetContentSize( 
            /* [out] */ DWORD __RPC_FAR *pdwSize,
            /* [unique][in] */ IMailMsgNotify __RPC_FAR *pNotify) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE ReadContent( 
            /* [in] */ DWORD dwOffset,
            /* [in] */ DWORD dwLength,
            /* [out] */ DWORD __RPC_FAR *pdwLength,
            /* [length_is][size_is][out] */ BYTE __RPC_FAR *pbBlock,
            /* [in] */ IMailMsgNotify __RPC_FAR *pNotify) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE WriteContent( 
            /* [in] */ DWORD dwOffset,
            /* [in] */ DWORD dwLength,
            /* [out] */ DWORD __RPC_FAR *pdwLength,
            /* [length_is][size_is][out] */ BYTE __RPC_FAR *pbBlock,
            /* [in] */ IMailMsgNotify __RPC_FAR *pNotify) = 0;
        
        virtual /* [local][helpstring] */ HRESULT STDMETHODCALLTYPE CopyContentToFile( 
            /* [in] */ PFIO_CONTEXT pFIOCopy,
            /* [unique][in] */ IMailMsgNotify __RPC_FAR *pNotify) = 0;
        
        virtual /* [local][helpstring] */ HRESULT STDMETHODCALLTYPE CopyContentToFileEx( 
            /* [in] */ PFIO_CONTEXT pFIOCopy,
            /* [in] */ BOOL fDotStuffed,
            /* [unique][in] */ IMailMsgNotify __RPC_FAR *pNotify) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE ForkForRecipients( 
            /* [unique][out] */ IMailMsgProperties __RPC_FAR *__RPC_FAR *ppNewMessage,
            /* [unique][out] */ IMailMsgRecipientsAdd __RPC_FAR *__RPC_FAR *ppRecipients) = 0;
        
        virtual /* [local][helpstring] */ HRESULT STDMETHODCALLTYPE CopyContentToFileAtOffset( 
            /* [in] */ PFIO_CONTEXT pFIOCopy,
            /* [in] */ DWORD dwOffset,
            /* [unique][in] */ IMailMsgNotify __RPC_FAR *pNotify) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE RebindAfterFork( 
            /* [in] */ IMailMsgProperties __RPC_FAR *pOriginalMsg,
            /* [in] */ IUnknown __RPC_FAR *pStoreDriver) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE SetContentSize( 
            /* [in] */ DWORD dwSize,
            /* [unique][in] */ IMailMsgNotify __RPC_FAR *pNotify) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE MapContent( 
            /* [in] */ BOOL fWrite,
            /* [in] */ BYTE __RPC_FAR *__RPC_FAR *ppbContent,
            /* [in] */ DWORD __RPC_FAR *pcContent) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE UnmapContent( 
            /* [in] */ BYTE __RPC_FAR *pbContent) = 0;
        
    };
    
#else 	/* C style interface */

    typedef struct IMailMsgPropertiesVtbl
    {
        BEGIN_INTERFACE
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *QueryInterface )( 
            IMailMsgProperties __RPC_FAR * This,
            /* [in] */ REFIID riid,
            /* [iid_is][out] */ void __RPC_FAR *__RPC_FAR *ppvObject);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *AddRef )( 
            IMailMsgProperties __RPC_FAR * This);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *Release )( 
            IMailMsgProperties __RPC_FAR * This);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *PutProperty )( 
            IMailMsgProperties __RPC_FAR * This,
            /* [in] */ DWORD dwPropID,
            /* [in] */ DWORD cbLength,
            /* [unique][length_is][size_is][in] */ BYTE __RPC_FAR *pbValue);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetProperty )( 
            IMailMsgProperties __RPC_FAR * This,
            /* [in] */ DWORD dwPropID,
            /* [in] */ DWORD cbLength,
            /* [out] */ DWORD __RPC_FAR *pcbLength,
            /* [length_is][size_is][out] */ BYTE __RPC_FAR *pbValue);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *Commit )( 
            IMailMsgProperties __RPC_FAR * This,
            /* [unique][in] */ IMailMsgNotify __RPC_FAR *pNotify);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *PutStringA )( 
            IMailMsgProperties __RPC_FAR * This,
            /* [in] */ DWORD dwPropID,
            /* [unique][in] */ LPCSTR pszValue);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetStringA )( 
            IMailMsgProperties __RPC_FAR * This,
            /* [in] */ DWORD dwPropID,
            /* [in] */ DWORD cchLength,
            /* [size_is][out] */ LPSTR pszValue);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *PutStringW )( 
            IMailMsgProperties __RPC_FAR * This,
            /* [in] */ DWORD dwPropID,
            /* [unique][in] */ LPCWSTR pszValue);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetStringW )( 
            IMailMsgProperties __RPC_FAR * This,
            /* [in] */ DWORD dwPropID,
            /* [in] */ DWORD cchLength,
            /* [size_is][out] */ LPWSTR pszValue);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *PutDWORD )( 
            IMailMsgProperties __RPC_FAR * This,
            /* [in] */ DWORD dwPropID,
            /* [in] */ DWORD dwValue);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetDWORD )( 
            IMailMsgProperties __RPC_FAR * This,
            /* [in] */ DWORD dwPropID,
            /* [out] */ DWORD __RPC_FAR *pdwValue);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *PutBool )( 
            IMailMsgProperties __RPC_FAR * This,
            /* [in] */ DWORD dwPropID,
            /* [in] */ DWORD bValue);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetBool )( 
            IMailMsgProperties __RPC_FAR * This,
            /* [in] */ DWORD dwPropID,
            /* [out] */ DWORD __RPC_FAR *pbValue);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetContentSize )( 
            IMailMsgProperties __RPC_FAR * This,
            /* [out] */ DWORD __RPC_FAR *pdwSize,
            /* [unique][in] */ IMailMsgNotify __RPC_FAR *pNotify);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *ReadContent )( 
            IMailMsgProperties __RPC_FAR * This,
            /* [in] */ DWORD dwOffset,
            /* [in] */ DWORD dwLength,
            /* [out] */ DWORD __RPC_FAR *pdwLength,
            /* [length_is][size_is][out] */ BYTE __RPC_FAR *pbBlock,
            /* [in] */ IMailMsgNotify __RPC_FAR *pNotify);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *WriteContent )( 
            IMailMsgProperties __RPC_FAR * This,
            /* [in] */ DWORD dwOffset,
            /* [in] */ DWORD dwLength,
            /* [out] */ DWORD __RPC_FAR *pdwLength,
            /* [length_is][size_is][out] */ BYTE __RPC_FAR *pbBlock,
            /* [in] */ IMailMsgNotify __RPC_FAR *pNotify);
        
        /* [local][helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *CopyContentToFile )( 
            IMailMsgProperties __RPC_FAR * This,
            /* [in] */ PFIO_CONTEXT pFIOCopy,
            /* [unique][in] */ IMailMsgNotify __RPC_FAR *pNotify);
        
        /* [local][helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *CopyContentToFileEx )( 
            IMailMsgProperties __RPC_FAR * This,
            /* [in] */ PFIO_CONTEXT pFIOCopy,
            /* [in] */ BOOL fDotStuffed,
            /* [unique][in] */ IMailMsgNotify __RPC_FAR *pNotify);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *ForkForRecipients )( 
            IMailMsgProperties __RPC_FAR * This,
            /* [unique][out] */ IMailMsgProperties __RPC_FAR *__RPC_FAR *ppNewMessage,
            /* [unique][out] */ IMailMsgRecipientsAdd __RPC_FAR *__RPC_FAR *ppRecipients);
        
        /* [local][helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *CopyContentToFileAtOffset )( 
            IMailMsgProperties __RPC_FAR * This,
            /* [in] */ PFIO_CONTEXT pFIOCopy,
            /* [in] */ DWORD dwOffset,
            /* [unique][in] */ IMailMsgNotify __RPC_FAR *pNotify);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *RebindAfterFork )( 
            IMailMsgProperties __RPC_FAR * This,
            /* [in] */ IMailMsgProperties __RPC_FAR *pOriginalMsg,
            /* [in] */ IUnknown __RPC_FAR *pStoreDriver);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *SetContentSize )( 
            IMailMsgProperties __RPC_FAR * This,
            /* [in] */ DWORD dwSize,
            /* [unique][in] */ IMailMsgNotify __RPC_FAR *pNotify);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *MapContent )( 
            IMailMsgProperties __RPC_FAR * This,
            /* [in] */ BOOL fWrite,
            /* [in] */ BYTE __RPC_FAR *__RPC_FAR *ppbContent,
            /* [in] */ DWORD __RPC_FAR *pcContent);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *UnmapContent )( 
            IMailMsgProperties __RPC_FAR * This,
            /* [in] */ BYTE __RPC_FAR *pbContent);
        
        END_INTERFACE
    } IMailMsgPropertiesVtbl;

    interface IMailMsgProperties
    {
        CONST_VTBL struct IMailMsgPropertiesVtbl __RPC_FAR *lpVtbl;
    };

    

#ifdef COBJMACROS


#define IMailMsgProperties_QueryInterface(This,riid,ppvObject)	\
    (This)->lpVtbl -> QueryInterface(This,riid,ppvObject)

#define IMailMsgProperties_AddRef(This)	\
    (This)->lpVtbl -> AddRef(This)

#define IMailMsgProperties_Release(This)	\
    (This)->lpVtbl -> Release(This)


#define IMailMsgProperties_PutProperty(This,dwPropID,cbLength,pbValue)	\
    (This)->lpVtbl -> PutProperty(This,dwPropID,cbLength,pbValue)

#define IMailMsgProperties_GetProperty(This,dwPropID,cbLength,pcbLength,pbValue)	\
    (This)->lpVtbl -> GetProperty(This,dwPropID,cbLength,pcbLength,pbValue)

#define IMailMsgProperties_Commit(This,pNotify)	\
    (This)->lpVtbl -> Commit(This,pNotify)

#define IMailMsgProperties_PutStringA(This,dwPropID,pszValue)	\
    (This)->lpVtbl -> PutStringA(This,dwPropID,pszValue)

#define IMailMsgProperties_GetStringA(This,dwPropID,cchLength,pszValue)	\
    (This)->lpVtbl -> GetStringA(This,dwPropID,cchLength,pszValue)

#define IMailMsgProperties_PutStringW(This,dwPropID,pszValue)	\
    (This)->lpVtbl -> PutStringW(This,dwPropID,pszValue)

#define IMailMsgProperties_GetStringW(This,dwPropID,cchLength,pszValue)	\
    (This)->lpVtbl -> GetStringW(This,dwPropID,cchLength,pszValue)

#define IMailMsgProperties_PutDWORD(This,dwPropID,dwValue)	\
    (This)->lpVtbl -> PutDWORD(This,dwPropID,dwValue)

#define IMailMsgProperties_GetDWORD(This,dwPropID,pdwValue)	\
    (This)->lpVtbl -> GetDWORD(This,dwPropID,pdwValue)

#define IMailMsgProperties_PutBool(This,dwPropID,bValue)	\
    (This)->lpVtbl -> PutBool(This,dwPropID,bValue)

#define IMailMsgProperties_GetBool(This,dwPropID,pbValue)	\
    (This)->lpVtbl -> GetBool(This,dwPropID,pbValue)

#define IMailMsgProperties_GetContentSize(This,pdwSize,pNotify)	\
    (This)->lpVtbl -> GetContentSize(This,pdwSize,pNotify)

#define IMailMsgProperties_ReadContent(This,dwOffset,dwLength,pdwLength,pbBlock,pNotify)	\
    (This)->lpVtbl -> ReadContent(This,dwOffset,dwLength,pdwLength,pbBlock,pNotify)

#define IMailMsgProperties_WriteContent(This,dwOffset,dwLength,pdwLength,pbBlock,pNotify)	\
    (This)->lpVtbl -> WriteContent(This,dwOffset,dwLength,pdwLength,pbBlock,pNotify)

#define IMailMsgProperties_CopyContentToFile(This,pFIOCopy,pNotify)	\
    (This)->lpVtbl -> CopyContentToFile(This,pFIOCopy,pNotify)

#define IMailMsgProperties_CopyContentToFileEx(This,pFIOCopy,fDotStuffed,pNotify)	\
    (This)->lpVtbl -> CopyContentToFileEx(This,pFIOCopy,fDotStuffed,pNotify)

#define IMailMsgProperties_ForkForRecipients(This,ppNewMessage,ppRecipients)	\
    (This)->lpVtbl -> ForkForRecipients(This,ppNewMessage,ppRecipients)

#define IMailMsgProperties_CopyContentToFileAtOffset(This,pFIOCopy,dwOffset,pNotify)	\
    (This)->lpVtbl -> CopyContentToFileAtOffset(This,pFIOCopy,dwOffset,pNotify)

#define IMailMsgProperties_RebindAfterFork(This,pOriginalMsg,pStoreDriver)	\
    (This)->lpVtbl -> RebindAfterFork(This,pOriginalMsg,pStoreDriver)

#define IMailMsgProperties_SetContentSize(This,dwSize,pNotify)	\
    (This)->lpVtbl -> SetContentSize(This,dwSize,pNotify)

#define IMailMsgProperties_MapContent(This,fWrite,ppbContent,pcContent)	\
    (This)->lpVtbl -> MapContent(This,fWrite,ppbContent,pcContent)

#define IMailMsgProperties_UnmapContent(This,pbContent)	\
    (This)->lpVtbl -> UnmapContent(This,pbContent)

#endif /* COBJMACROS */


#endif 	/* C style interface */



/* [helpstring] */ HRESULT STDMETHODCALLTYPE IMailMsgProperties_PutProperty_Proxy( 
    IMailMsgProperties __RPC_FAR * This,
    /* [in] */ DWORD dwPropID,
    /* [in] */ DWORD cbLength,
    /* [unique][length_is][size_is][in] */ BYTE __RPC_FAR *pbValue);


void __RPC_STUB IMailMsgProperties_PutProperty_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IMailMsgProperties_GetProperty_Proxy( 
    IMailMsgProperties __RPC_FAR * This,
    /* [in] */ DWORD dwPropID,
    /* [in] */ DWORD cbLength,
    /* [out] */ DWORD __RPC_FAR *pcbLength,
    /* [length_is][size_is][out] */ BYTE __RPC_FAR *pbValue);


void __RPC_STUB IMailMsgProperties_GetProperty_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IMailMsgProperties_Commit_Proxy( 
    IMailMsgProperties __RPC_FAR * This,
    /* [unique][in] */ IMailMsgNotify __RPC_FAR *pNotify);


void __RPC_STUB IMailMsgProperties_Commit_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IMailMsgProperties_PutStringA_Proxy( 
    IMailMsgProperties __RPC_FAR * This,
    /* [in] */ DWORD dwPropID,
    /* [unique][in] */ LPCSTR pszValue);


void __RPC_STUB IMailMsgProperties_PutStringA_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IMailMsgProperties_GetStringA_Proxy( 
    IMailMsgProperties __RPC_FAR * This,
    /* [in] */ DWORD dwPropID,
    /* [in] */ DWORD cchLength,
    /* [size_is][out] */ LPSTR pszValue);


void __RPC_STUB IMailMsgProperties_GetStringA_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IMailMsgProperties_PutStringW_Proxy( 
    IMailMsgProperties __RPC_FAR * This,
    /* [in] */ DWORD dwPropID,
    /* [unique][in] */ LPCWSTR pszValue);


void __RPC_STUB IMailMsgProperties_PutStringW_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IMailMsgProperties_GetStringW_Proxy( 
    IMailMsgProperties __RPC_FAR * This,
    /* [in] */ DWORD dwPropID,
    /* [in] */ DWORD cchLength,
    /* [size_is][out] */ LPWSTR pszValue);


void __RPC_STUB IMailMsgProperties_GetStringW_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IMailMsgProperties_PutDWORD_Proxy( 
    IMailMsgProperties __RPC_FAR * This,
    /* [in] */ DWORD dwPropID,
    /* [in] */ DWORD dwValue);


void __RPC_STUB IMailMsgProperties_PutDWORD_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IMailMsgProperties_GetDWORD_Proxy( 
    IMailMsgProperties __RPC_FAR * This,
    /* [in] */ DWORD dwPropID,
    /* [out] */ DWORD __RPC_FAR *pdwValue);


void __RPC_STUB IMailMsgProperties_GetDWORD_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IMailMsgProperties_PutBool_Proxy( 
    IMailMsgProperties __RPC_FAR * This,
    /* [in] */ DWORD dwPropID,
    /* [in] */ DWORD bValue);


void __RPC_STUB IMailMsgProperties_PutBool_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IMailMsgProperties_GetBool_Proxy( 
    IMailMsgProperties __RPC_FAR * This,
    /* [in] */ DWORD dwPropID,
    /* [out] */ DWORD __RPC_FAR *pbValue);


void __RPC_STUB IMailMsgProperties_GetBool_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IMailMsgProperties_GetContentSize_Proxy( 
    IMailMsgProperties __RPC_FAR * This,
    /* [out] */ DWORD __RPC_FAR *pdwSize,
    /* [unique][in] */ IMailMsgNotify __RPC_FAR *pNotify);


void __RPC_STUB IMailMsgProperties_GetContentSize_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IMailMsgProperties_ReadContent_Proxy( 
    IMailMsgProperties __RPC_FAR * This,
    /* [in] */ DWORD dwOffset,
    /* [in] */ DWORD dwLength,
    /* [out] */ DWORD __RPC_FAR *pdwLength,
    /* [length_is][size_is][out] */ BYTE __RPC_FAR *pbBlock,
    /* [in] */ IMailMsgNotify __RPC_FAR *pNotify);


void __RPC_STUB IMailMsgProperties_ReadContent_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IMailMsgProperties_WriteContent_Proxy( 
    IMailMsgProperties __RPC_FAR * This,
    /* [in] */ DWORD dwOffset,
    /* [in] */ DWORD dwLength,
    /* [out] */ DWORD __RPC_FAR *pdwLength,
    /* [length_is][size_is][out] */ BYTE __RPC_FAR *pbBlock,
    /* [in] */ IMailMsgNotify __RPC_FAR *pNotify);


void __RPC_STUB IMailMsgProperties_WriteContent_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [local][helpstring] */ HRESULT STDMETHODCALLTYPE IMailMsgProperties_CopyContentToFile_Proxy( 
    IMailMsgProperties __RPC_FAR * This,
    /* [in] */ PFIO_CONTEXT pFIOCopy,
    /* [unique][in] */ IMailMsgNotify __RPC_FAR *pNotify);


void __RPC_STUB IMailMsgProperties_CopyContentToFile_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [local][helpstring] */ HRESULT STDMETHODCALLTYPE IMailMsgProperties_CopyContentToFileEx_Proxy( 
    IMailMsgProperties __RPC_FAR * This,
    /* [in] */ PFIO_CONTEXT pFIOCopy,
    /* [in] */ BOOL fDotStuffed,
    /* [unique][in] */ IMailMsgNotify __RPC_FAR *pNotify);


void __RPC_STUB IMailMsgProperties_CopyContentToFileEx_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IMailMsgProperties_ForkForRecipients_Proxy( 
    IMailMsgProperties __RPC_FAR * This,
    /* [unique][out] */ IMailMsgProperties __RPC_FAR *__RPC_FAR *ppNewMessage,
    /* [unique][out] */ IMailMsgRecipientsAdd __RPC_FAR *__RPC_FAR *ppRecipients);


void __RPC_STUB IMailMsgProperties_ForkForRecipients_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [local][helpstring] */ HRESULT STDMETHODCALLTYPE IMailMsgProperties_CopyContentToFileAtOffset_Proxy( 
    IMailMsgProperties __RPC_FAR * This,
    /* [in] */ PFIO_CONTEXT pFIOCopy,
    /* [in] */ DWORD dwOffset,
    /* [unique][in] */ IMailMsgNotify __RPC_FAR *pNotify);


void __RPC_STUB IMailMsgProperties_CopyContentToFileAtOffset_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IMailMsgProperties_RebindAfterFork_Proxy( 
    IMailMsgProperties __RPC_FAR * This,
    /* [in] */ IMailMsgProperties __RPC_FAR *pOriginalMsg,
    /* [in] */ IUnknown __RPC_FAR *pStoreDriver);


void __RPC_STUB IMailMsgProperties_RebindAfterFork_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IMailMsgProperties_SetContentSize_Proxy( 
    IMailMsgProperties __RPC_FAR * This,
    /* [in] */ DWORD dwSize,
    /* [unique][in] */ IMailMsgNotify __RPC_FAR *pNotify);


void __RPC_STUB IMailMsgProperties_SetContentSize_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IMailMsgProperties_MapContent_Proxy( 
    IMailMsgProperties __RPC_FAR * This,
    /* [in] */ BOOL fWrite,
    /* [in] */ BYTE __RPC_FAR *__RPC_FAR *ppbContent,
    /* [in] */ DWORD __RPC_FAR *pcContent);


void __RPC_STUB IMailMsgProperties_MapContent_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IMailMsgProperties_UnmapContent_Proxy( 
    IMailMsgProperties __RPC_FAR * This,
    /* [in] */ BYTE __RPC_FAR *pbContent);


void __RPC_STUB IMailMsgProperties_UnmapContent_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);



#endif 	/* __IMailMsgProperties_INTERFACE_DEFINED__ */


#ifndef __IMailMsgValidate_INTERFACE_DEFINED__
#define __IMailMsgValidate_INTERFACE_DEFINED__

/* interface IMailMsgValidate */
/* [uuid][unique][object][local][helpstring] */ 


EXTERN_C const IID IID_IMailMsgValidate;

#if defined(__cplusplus) && !defined(CINTERFACE)
    
    MIDL_INTERFACE("6717b03c-072c-11d3-94ff-00c04fa379f1")
    IMailMsgValidate : public IUnknown
    {
    public:
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE ValidateStream( 
            /* [in] */ IMailMsgPropertyStream __RPC_FAR *pStream) = 0;
        
    };
    
#else 	/* C style interface */

    typedef struct IMailMsgValidateVtbl
    {
        BEGIN_INTERFACE
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *QueryInterface )( 
            IMailMsgValidate __RPC_FAR * This,
            /* [in] */ REFIID riid,
            /* [iid_is][out] */ void __RPC_FAR *__RPC_FAR *ppvObject);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *AddRef )( 
            IMailMsgValidate __RPC_FAR * This);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *Release )( 
            IMailMsgValidate __RPC_FAR * This);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *ValidateStream )( 
            IMailMsgValidate __RPC_FAR * This,
            /* [in] */ IMailMsgPropertyStream __RPC_FAR *pStream);
        
        END_INTERFACE
    } IMailMsgValidateVtbl;

    interface IMailMsgValidate
    {
        CONST_VTBL struct IMailMsgValidateVtbl __RPC_FAR *lpVtbl;
    };

    

#ifdef COBJMACROS


#define IMailMsgValidate_QueryInterface(This,riid,ppvObject)	\
    (This)->lpVtbl -> QueryInterface(This,riid,ppvObject)

#define IMailMsgValidate_AddRef(This)	\
    (This)->lpVtbl -> AddRef(This)

#define IMailMsgValidate_Release(This)	\
    (This)->lpVtbl -> Release(This)


#define IMailMsgValidate_ValidateStream(This,pStream)	\
    (This)->lpVtbl -> ValidateStream(This,pStream)

#endif /* COBJMACROS */


#endif 	/* C style interface */



/* [helpstring] */ HRESULT STDMETHODCALLTYPE IMailMsgValidate_ValidateStream_Proxy( 
    IMailMsgValidate __RPC_FAR * This,
    /* [in] */ IMailMsgPropertyStream __RPC_FAR *pStream);


void __RPC_STUB IMailMsgValidate_ValidateStream_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);



#endif 	/* __IMailMsgValidate_INTERFACE_DEFINED__ */


#ifndef __IMailMsgPropertyManagement_INTERFACE_DEFINED__
#define __IMailMsgPropertyManagement_INTERFACE_DEFINED__

/* interface IMailMsgPropertyManagement */
/* [uuid][unique][object][helpstring] */ 


EXTERN_C const IID IID_IMailMsgPropertyManagement;

#if defined(__cplusplus) && !defined(CINTERFACE)
    
    MIDL_INTERFACE("a2f196c0-a351-11d1-aa8a-00aa006bc80b")
    IMailMsgPropertyManagement : public IUnknown
    {
    public:
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE AllocPropIDRange( 
            /* [in] */ REFGUID rguid,
            /* [in] */ DWORD cCount,
            /* [out] */ DWORD __RPC_FAR *pdwStart) = 0;
        
    };
    
#else 	/* C style interface */

    typedef struct IMailMsgPropertyManagementVtbl
    {
        BEGIN_INTERFACE
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *QueryInterface )( 
            IMailMsgPropertyManagement __RPC_FAR * This,
            /* [in] */ REFIID riid,
            /* [iid_is][out] */ void __RPC_FAR *__RPC_FAR *ppvObject);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *AddRef )( 
            IMailMsgPropertyManagement __RPC_FAR * This);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *Release )( 
            IMailMsgPropertyManagement __RPC_FAR * This);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *AllocPropIDRange )( 
            IMailMsgPropertyManagement __RPC_FAR * This,
            /* [in] */ REFGUID rguid,
            /* [in] */ DWORD cCount,
            /* [out] */ DWORD __RPC_FAR *pdwStart);
        
        END_INTERFACE
    } IMailMsgPropertyManagementVtbl;

    interface IMailMsgPropertyManagement
    {
        CONST_VTBL struct IMailMsgPropertyManagementVtbl __RPC_FAR *lpVtbl;
    };

    

#ifdef COBJMACROS


#define IMailMsgPropertyManagement_QueryInterface(This,riid,ppvObject)	\
    (This)->lpVtbl -> QueryInterface(This,riid,ppvObject)

#define IMailMsgPropertyManagement_AddRef(This)	\
    (This)->lpVtbl -> AddRef(This)

#define IMailMsgPropertyManagement_Release(This)	\
    (This)->lpVtbl -> Release(This)


#define IMailMsgPropertyManagement_AllocPropIDRange(This,rguid,cCount,pdwStart)	\
    (This)->lpVtbl -> AllocPropIDRange(This,rguid,cCount,pdwStart)

#endif /* COBJMACROS */


#endif 	/* C style interface */



/* [helpstring] */ HRESULT STDMETHODCALLTYPE IMailMsgPropertyManagement_AllocPropIDRange_Proxy( 
    IMailMsgPropertyManagement __RPC_FAR * This,
    /* [in] */ REFGUID rguid,
    /* [in] */ DWORD cCount,
    /* [out] */ DWORD __RPC_FAR *pdwStart);


void __RPC_STUB IMailMsgPropertyManagement_AllocPropIDRange_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);



#endif 	/* __IMailMsgPropertyManagement_INTERFACE_DEFINED__ */


#ifndef __IMailMsgEnumMessages_INTERFACE_DEFINED__
#define __IMailMsgEnumMessages_INTERFACE_DEFINED__

/* interface IMailMsgEnumMessages */
/* [uuid][unique][object][local][helpstring] */ 


EXTERN_C const IID IID_IMailMsgEnumMessages;

#if defined(__cplusplus) && !defined(CINTERFACE)
    
    MIDL_INTERFACE("e760a840-c8f1-11d1-9ff2-00c04fa37348")
    IMailMsgEnumMessages : public IUnknown
    {
    public:
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE Next( 
            /* [unique][in] */ IMailMsgProperties __RPC_FAR *pMsg,
            /* [out] */ IMailMsgPropertyStream __RPC_FAR *__RPC_FAR *ppStream,
            /* [out] */ PFIO_CONTEXT __RPC_FAR *ppFIOContentFile,
            /* [unique][in] */ IMailMsgNotify __RPC_FAR *pNotify) = 0;
        
    };
    
#else 	/* C style interface */

    typedef struct IMailMsgEnumMessagesVtbl
    {
        BEGIN_INTERFACE
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *QueryInterface )( 
            IMailMsgEnumMessages __RPC_FAR * This,
            /* [in] */ REFIID riid,
            /* [iid_is][out] */ void __RPC_FAR *__RPC_FAR *ppvObject);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *AddRef )( 
            IMailMsgEnumMessages __RPC_FAR * This);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *Release )( 
            IMailMsgEnumMessages __RPC_FAR * This);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *Next )( 
            IMailMsgEnumMessages __RPC_FAR * This,
            /* [unique][in] */ IMailMsgProperties __RPC_FAR *pMsg,
            /* [out] */ IMailMsgPropertyStream __RPC_FAR *__RPC_FAR *ppStream,
            /* [out] */ PFIO_CONTEXT __RPC_FAR *ppFIOContentFile,
            /* [unique][in] */ IMailMsgNotify __RPC_FAR *pNotify);
        
        END_INTERFACE
    } IMailMsgEnumMessagesVtbl;

    interface IMailMsgEnumMessages
    {
        CONST_VTBL struct IMailMsgEnumMessagesVtbl __RPC_FAR *lpVtbl;
    };

    

#ifdef COBJMACROS


#define IMailMsgEnumMessages_QueryInterface(This,riid,ppvObject)	\
    (This)->lpVtbl -> QueryInterface(This,riid,ppvObject)

#define IMailMsgEnumMessages_AddRef(This)	\
    (This)->lpVtbl -> AddRef(This)

#define IMailMsgEnumMessages_Release(This)	\
    (This)->lpVtbl -> Release(This)


#define IMailMsgEnumMessages_Next(This,pMsg,ppStream,ppFIOContentFile,pNotify)	\
    (This)->lpVtbl -> Next(This,pMsg,ppStream,ppFIOContentFile,pNotify)

#endif /* COBJMACROS */


#endif 	/* C style interface */



/* [helpstring] */ HRESULT STDMETHODCALLTYPE IMailMsgEnumMessages_Next_Proxy( 
    IMailMsgEnumMessages __RPC_FAR * This,
    /* [unique][in] */ IMailMsgProperties __RPC_FAR *pMsg,
    /* [out] */ IMailMsgPropertyStream __RPC_FAR *__RPC_FAR *ppStream,
    /* [out] */ PFIO_CONTEXT __RPC_FAR *ppFIOContentFile,
    /* [unique][in] */ IMailMsgNotify __RPC_FAR *pNotify);


void __RPC_STUB IMailMsgEnumMessages_Next_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);



#endif 	/* __IMailMsgEnumMessages_INTERFACE_DEFINED__ */


#ifndef __IMailMsgStoreDriver_INTERFACE_DEFINED__
#define __IMailMsgStoreDriver_INTERFACE_DEFINED__

/* interface IMailMsgStoreDriver */
/* [uuid][unique][object][local][helpstring] */ 


EXTERN_C const IID IID_IMailMsgStoreDriver;

#if defined(__cplusplus) && !defined(CINTERFACE)
    
    MIDL_INTERFACE("246aae60-acc4-11d1-aa91-00aa006bc80b")
    IMailMsgStoreDriver : public IUnknown
    {
    public:
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE AllocMessage( 
            /* [unique][in] */ IMailMsgProperties __RPC_FAR *pMsg,
            /* [in] */ DWORD dwFlags,
            /* [out] */ IMailMsgPropertyStream __RPC_FAR *__RPC_FAR *ppStream,
            /* [out] */ PFIO_CONTEXT __RPC_FAR *ppFIOContentFile,
            /* [unique][in] */ IMailMsgNotify __RPC_FAR *pNotify) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE EnumMessages( 
            /* [out] */ IMailMsgEnumMessages __RPC_FAR *__RPC_FAR *ppEnum) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE ReOpen( 
            /* [in] */ IMailMsgProperties __RPC_FAR *pMsg,
            /* [out] */ IMailMsgPropertyStream __RPC_FAR *__RPC_FAR *ppStream,
            /* [out] */ PFIO_CONTEXT __RPC_FAR *ppFIOContentFile,
            /* [unique][in] */ IMailMsgNotify __RPC_FAR *pNotify) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE Delete( 
            /* [in] */ IMailMsgProperties __RPC_FAR *pMsg,
            /* [unique][in] */ IMailMsgNotify __RPC_FAR *pNotify) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE CloseContentFile( 
            /* [in] */ IMailMsgProperties __RPC_FAR *pMsg,
            /* [in] */ PFIO_CONTEXT pFIOContentFile) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE ReAllocMessage( 
            /* [in] */ IMailMsgProperties __RPC_FAR *pOriginalMsg,
            /* [in] */ IMailMsgProperties __RPC_FAR *pNewMsg,
            /* [out] */ IMailMsgPropertyStream __RPC_FAR *__RPC_FAR *ppStream,
            /* [out] */ PFIO_CONTEXT __RPC_FAR *ppFIOContentFile,
            /* [unique][in] */ IMailMsgNotify __RPC_FAR *pNotify) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE SupportWriteContent( void) = 0;
        
    };
    
#else 	/* C style interface */

    typedef struct IMailMsgStoreDriverVtbl
    {
        BEGIN_INTERFACE
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *QueryInterface )( 
            IMailMsgStoreDriver __RPC_FAR * This,
            /* [in] */ REFIID riid,
            /* [iid_is][out] */ void __RPC_FAR *__RPC_FAR *ppvObject);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *AddRef )( 
            IMailMsgStoreDriver __RPC_FAR * This);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *Release )( 
            IMailMsgStoreDriver __RPC_FAR * This);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *AllocMessage )( 
            IMailMsgStoreDriver __RPC_FAR * This,
            /* [unique][in] */ IMailMsgProperties __RPC_FAR *pMsg,
            /* [in] */ DWORD dwFlags,
            /* [out] */ IMailMsgPropertyStream __RPC_FAR *__RPC_FAR *ppStream,
            /* [out] */ PFIO_CONTEXT __RPC_FAR *ppFIOContentFile,
            /* [unique][in] */ IMailMsgNotify __RPC_FAR *pNotify);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *EnumMessages )( 
            IMailMsgStoreDriver __RPC_FAR * This,
            /* [out] */ IMailMsgEnumMessages __RPC_FAR *__RPC_FAR *ppEnum);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *ReOpen )( 
            IMailMsgStoreDriver __RPC_FAR * This,
            /* [in] */ IMailMsgProperties __RPC_FAR *pMsg,
            /* [out] */ IMailMsgPropertyStream __RPC_FAR *__RPC_FAR *ppStream,
            /* [out] */ PFIO_CONTEXT __RPC_FAR *ppFIOContentFile,
            /* [unique][in] */ IMailMsgNotify __RPC_FAR *pNotify);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *Delete )( 
            IMailMsgStoreDriver __RPC_FAR * This,
            /* [in] */ IMailMsgProperties __RPC_FAR *pMsg,
            /* [unique][in] */ IMailMsgNotify __RPC_FAR *pNotify);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *CloseContentFile )( 
            IMailMsgStoreDriver __RPC_FAR * This,
            /* [in] */ IMailMsgProperties __RPC_FAR *pMsg,
            /* [in] */ PFIO_CONTEXT pFIOContentFile);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *ReAllocMessage )( 
            IMailMsgStoreDriver __RPC_FAR * This,
            /* [in] */ IMailMsgProperties __RPC_FAR *pOriginalMsg,
            /* [in] */ IMailMsgProperties __RPC_FAR *pNewMsg,
            /* [out] */ IMailMsgPropertyStream __RPC_FAR *__RPC_FAR *ppStream,
            /* [out] */ PFIO_CONTEXT __RPC_FAR *ppFIOContentFile,
            /* [unique][in] */ IMailMsgNotify __RPC_FAR *pNotify);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *SupportWriteContent )( 
            IMailMsgStoreDriver __RPC_FAR * This);
        
        END_INTERFACE
    } IMailMsgStoreDriverVtbl;

    interface IMailMsgStoreDriver
    {
        CONST_VTBL struct IMailMsgStoreDriverVtbl __RPC_FAR *lpVtbl;
    };

    

#ifdef COBJMACROS


#define IMailMsgStoreDriver_QueryInterface(This,riid,ppvObject)	\
    (This)->lpVtbl -> QueryInterface(This,riid,ppvObject)

#define IMailMsgStoreDriver_AddRef(This)	\
    (This)->lpVtbl -> AddRef(This)

#define IMailMsgStoreDriver_Release(This)	\
    (This)->lpVtbl -> Release(This)


#define IMailMsgStoreDriver_AllocMessage(This,pMsg,dwFlags,ppStream,ppFIOContentFile,pNotify)	\
    (This)->lpVtbl -> AllocMessage(This,pMsg,dwFlags,ppStream,ppFIOContentFile,pNotify)

#define IMailMsgStoreDriver_EnumMessages(This,ppEnum)	\
    (This)->lpVtbl -> EnumMessages(This,ppEnum)

#define IMailMsgStoreDriver_ReOpen(This,pMsg,ppStream,ppFIOContentFile,pNotify)	\
    (This)->lpVtbl -> ReOpen(This,pMsg,ppStream,ppFIOContentFile,pNotify)

#define IMailMsgStoreDriver_Delete(This,pMsg,pNotify)	\
    (This)->lpVtbl -> Delete(This,pMsg,pNotify)

#define IMailMsgStoreDriver_CloseContentFile(This,pMsg,pFIOContentFile)	\
    (This)->lpVtbl -> CloseContentFile(This,pMsg,pFIOContentFile)

#define IMailMsgStoreDriver_ReAllocMessage(This,pOriginalMsg,pNewMsg,ppStream,ppFIOContentFile,pNotify)	\
    (This)->lpVtbl -> ReAllocMessage(This,pOriginalMsg,pNewMsg,ppStream,ppFIOContentFile,pNotify)

#define IMailMsgStoreDriver_SupportWriteContent(This)	\
    (This)->lpVtbl -> SupportWriteContent(This)

#endif /* COBJMACROS */


#endif 	/* C style interface */



/* [helpstring] */ HRESULT STDMETHODCALLTYPE IMailMsgStoreDriver_AllocMessage_Proxy( 
    IMailMsgStoreDriver __RPC_FAR * This,
    /* [unique][in] */ IMailMsgProperties __RPC_FAR *pMsg,
    /* [in] */ DWORD dwFlags,
    /* [out] */ IMailMsgPropertyStream __RPC_FAR *__RPC_FAR *ppStream,
    /* [out] */ PFIO_CONTEXT __RPC_FAR *ppFIOContentFile,
    /* [unique][in] */ IMailMsgNotify __RPC_FAR *pNotify);


void __RPC_STUB IMailMsgStoreDriver_AllocMessage_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IMailMsgStoreDriver_EnumMessages_Proxy( 
    IMailMsgStoreDriver __RPC_FAR * This,
    /* [out] */ IMailMsgEnumMessages __RPC_FAR *__RPC_FAR *ppEnum);


void __RPC_STUB IMailMsgStoreDriver_EnumMessages_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IMailMsgStoreDriver_ReOpen_Proxy( 
    IMailMsgStoreDriver __RPC_FAR * This,
    /* [in] */ IMailMsgProperties __RPC_FAR *pMsg,
    /* [out] */ IMailMsgPropertyStream __RPC_FAR *__RPC_FAR *ppStream,
    /* [out] */ PFIO_CONTEXT __RPC_FAR *ppFIOContentFile,
    /* [unique][in] */ IMailMsgNotify __RPC_FAR *pNotify);


void __RPC_STUB IMailMsgStoreDriver_ReOpen_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IMailMsgStoreDriver_Delete_Proxy( 
    IMailMsgStoreDriver __RPC_FAR * This,
    /* [in] */ IMailMsgProperties __RPC_FAR *pMsg,
    /* [unique][in] */ IMailMsgNotify __RPC_FAR *pNotify);


void __RPC_STUB IMailMsgStoreDriver_Delete_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IMailMsgStoreDriver_CloseContentFile_Proxy( 
    IMailMsgStoreDriver __RPC_FAR * This,
    /* [in] */ IMailMsgProperties __RPC_FAR *pMsg,
    /* [in] */ PFIO_CONTEXT pFIOContentFile);


void __RPC_STUB IMailMsgStoreDriver_CloseContentFile_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IMailMsgStoreDriver_ReAllocMessage_Proxy( 
    IMailMsgStoreDriver __RPC_FAR * This,
    /* [in] */ IMailMsgProperties __RPC_FAR *pOriginalMsg,
    /* [in] */ IMailMsgProperties __RPC_FAR *pNewMsg,
    /* [out] */ IMailMsgPropertyStream __RPC_FAR *__RPC_FAR *ppStream,
    /* [out] */ PFIO_CONTEXT __RPC_FAR *ppFIOContentFile,
    /* [unique][in] */ IMailMsgNotify __RPC_FAR *pNotify);


void __RPC_STUB IMailMsgStoreDriver_ReAllocMessage_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IMailMsgStoreDriver_SupportWriteContent_Proxy( 
    IMailMsgStoreDriver __RPC_FAR * This);


void __RPC_STUB IMailMsgStoreDriver_SupportWriteContent_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);



#endif 	/* __IMailMsgStoreDriver_INTERFACE_DEFINED__ */


#ifndef __IMailMsgQueueMgmt_INTERFACE_DEFINED__
#define __IMailMsgQueueMgmt_INTERFACE_DEFINED__

/* interface IMailMsgQueueMgmt */
/* [uuid][unique][object][helpstring] */ 


EXTERN_C const IID IID_IMailMsgQueueMgmt;

#if defined(__cplusplus) && !defined(CINTERFACE)
    
    MIDL_INTERFACE("b2564d0a-d5a1-11d1-9ff7-00c04fa37348")
    IMailMsgQueueMgmt : public IUnknown
    {
    public:
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE AddUsage( void) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE ReleaseUsage( void) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE SetRecipientCount( 
            /* [in] */ DWORD dwCount) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE GetRecipientCount( 
            /* [out] */ DWORD __RPC_FAR *pdwCount) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE DecrementRecipientCount( 
            /* [in] */ DWORD dwDecrement) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE IncrementRecipientCount( 
            /* [in] */ DWORD dwIncrement) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE Delete( 
            /* [unique][in] */ IMailMsgNotify __RPC_FAR *pNotify) = 0;
        
    };
    
#else 	/* C style interface */

    typedef struct IMailMsgQueueMgmtVtbl
    {
        BEGIN_INTERFACE
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *QueryInterface )( 
            IMailMsgQueueMgmt __RPC_FAR * This,
            /* [in] */ REFIID riid,
            /* [iid_is][out] */ void __RPC_FAR *__RPC_FAR *ppvObject);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *AddRef )( 
            IMailMsgQueueMgmt __RPC_FAR * This);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *Release )( 
            IMailMsgQueueMgmt __RPC_FAR * This);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *AddUsage )( 
            IMailMsgQueueMgmt __RPC_FAR * This);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *ReleaseUsage )( 
            IMailMsgQueueMgmt __RPC_FAR * This);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *SetRecipientCount )( 
            IMailMsgQueueMgmt __RPC_FAR * This,
            /* [in] */ DWORD dwCount);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetRecipientCount )( 
            IMailMsgQueueMgmt __RPC_FAR * This,
            /* [out] */ DWORD __RPC_FAR *pdwCount);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *DecrementRecipientCount )( 
            IMailMsgQueueMgmt __RPC_FAR * This,
            /* [in] */ DWORD dwDecrement);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *IncrementRecipientCount )( 
            IMailMsgQueueMgmt __RPC_FAR * This,
            /* [in] */ DWORD dwIncrement);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *Delete )( 
            IMailMsgQueueMgmt __RPC_FAR * This,
            /* [unique][in] */ IMailMsgNotify __RPC_FAR *pNotify);
        
        END_INTERFACE
    } IMailMsgQueueMgmtVtbl;

    interface IMailMsgQueueMgmt
    {
        CONST_VTBL struct IMailMsgQueueMgmtVtbl __RPC_FAR *lpVtbl;
    };

    

#ifdef COBJMACROS


#define IMailMsgQueueMgmt_QueryInterface(This,riid,ppvObject)	\
    (This)->lpVtbl -> QueryInterface(This,riid,ppvObject)

#define IMailMsgQueueMgmt_AddRef(This)	\
    (This)->lpVtbl -> AddRef(This)

#define IMailMsgQueueMgmt_Release(This)	\
    (This)->lpVtbl -> Release(This)


#define IMailMsgQueueMgmt_AddUsage(This)	\
    (This)->lpVtbl -> AddUsage(This)

#define IMailMsgQueueMgmt_ReleaseUsage(This)	\
    (This)->lpVtbl -> ReleaseUsage(This)

#define IMailMsgQueueMgmt_SetRecipientCount(This,dwCount)	\
    (This)->lpVtbl -> SetRecipientCount(This,dwCount)

#define IMailMsgQueueMgmt_GetRecipientCount(This,pdwCount)	\
    (This)->lpVtbl -> GetRecipientCount(This,pdwCount)

#define IMailMsgQueueMgmt_DecrementRecipientCount(This,dwDecrement)	\
    (This)->lpVtbl -> DecrementRecipientCount(This,dwDecrement)

#define IMailMsgQueueMgmt_IncrementRecipientCount(This,dwIncrement)	\
    (This)->lpVtbl -> IncrementRecipientCount(This,dwIncrement)

#define IMailMsgQueueMgmt_Delete(This,pNotify)	\
    (This)->lpVtbl -> Delete(This,pNotify)

#endif /* COBJMACROS */


#endif 	/* C style interface */



/* [helpstring] */ HRESULT STDMETHODCALLTYPE IMailMsgQueueMgmt_AddUsage_Proxy( 
    IMailMsgQueueMgmt __RPC_FAR * This);


void __RPC_STUB IMailMsgQueueMgmt_AddUsage_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IMailMsgQueueMgmt_ReleaseUsage_Proxy( 
    IMailMsgQueueMgmt __RPC_FAR * This);


void __RPC_STUB IMailMsgQueueMgmt_ReleaseUsage_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IMailMsgQueueMgmt_SetRecipientCount_Proxy( 
    IMailMsgQueueMgmt __RPC_FAR * This,
    /* [in] */ DWORD dwCount);


void __RPC_STUB IMailMsgQueueMgmt_SetRecipientCount_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IMailMsgQueueMgmt_GetRecipientCount_Proxy( 
    IMailMsgQueueMgmt __RPC_FAR * This,
    /* [out] */ DWORD __RPC_FAR *pdwCount);


void __RPC_STUB IMailMsgQueueMgmt_GetRecipientCount_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IMailMsgQueueMgmt_DecrementRecipientCount_Proxy( 
    IMailMsgQueueMgmt __RPC_FAR * This,
    /* [in] */ DWORD dwDecrement);


void __RPC_STUB IMailMsgQueueMgmt_DecrementRecipientCount_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IMailMsgQueueMgmt_IncrementRecipientCount_Proxy( 
    IMailMsgQueueMgmt __RPC_FAR * This,
    /* [in] */ DWORD dwIncrement);


void __RPC_STUB IMailMsgQueueMgmt_IncrementRecipientCount_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IMailMsgQueueMgmt_Delete_Proxy( 
    IMailMsgQueueMgmt __RPC_FAR * This,
    /* [unique][in] */ IMailMsgNotify __RPC_FAR *pNotify);


void __RPC_STUB IMailMsgQueueMgmt_Delete_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);



#endif 	/* __IMailMsgQueueMgmt_INTERFACE_DEFINED__ */


#ifndef __ISMTPStoreDriver_INTERFACE_DEFINED__
#define __ISMTPStoreDriver_INTERFACE_DEFINED__

/* interface ISMTPStoreDriver */
/* [uuid][unique][object][local][helpstring] */ 


EXTERN_C const IID IID_ISMTPStoreDriver;

#if defined(__cplusplus) && !defined(CINTERFACE)
    
    MIDL_INTERFACE("ee51588c-d64a-11d1-9ff7-00c04fa37348")
    ISMTPStoreDriver : public IUnknown
    {
    public:
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE Init( 
            /* [in] */ DWORD dwInstance,
            /* [unique][in] */ IUnknown __RPC_FAR *pBinding,
            /* [in] */ IUnknown __RPC_FAR *pServer,
            /* [in] */ DWORD dwReason,
            /* [out] */ IUnknown __RPC_FAR *__RPC_FAR *ppStoreDriver) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE PrepareForShutdown( 
            /* [in] */ DWORD dwReason) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE Shutdown( 
            /* [in] */ DWORD dwReason) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE LocalDelivery( 
            /* [in] */ IMailMsgProperties __RPC_FAR *pMsg,
            /* [in] */ DWORD dwRecipCount,
            /* [size_is][in] */ DWORD __RPC_FAR *pdwRecipIndexes,
            /* [unique][in] */ IMailMsgNotify __RPC_FAR *pNotify) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE EnumerateAndSubmitMessages( 
            /* [unique][in] */ IMailMsgNotify __RPC_FAR *pNotify) = 0;
        
    };
    
#else 	/* C style interface */

    typedef struct ISMTPStoreDriverVtbl
    {
        BEGIN_INTERFACE
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *QueryInterface )( 
            ISMTPStoreDriver __RPC_FAR * This,
            /* [in] */ REFIID riid,
            /* [iid_is][out] */ void __RPC_FAR *__RPC_FAR *ppvObject);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *AddRef )( 
            ISMTPStoreDriver __RPC_FAR * This);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *Release )( 
            ISMTPStoreDriver __RPC_FAR * This);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *Init )( 
            ISMTPStoreDriver __RPC_FAR * This,
            /* [in] */ DWORD dwInstance,
            /* [unique][in] */ IUnknown __RPC_FAR *pBinding,
            /* [in] */ IUnknown __RPC_FAR *pServer,
            /* [in] */ DWORD dwReason,
            /* [out] */ IUnknown __RPC_FAR *__RPC_FAR *ppStoreDriver);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *PrepareForShutdown )( 
            ISMTPStoreDriver __RPC_FAR * This,
            /* [in] */ DWORD dwReason);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *Shutdown )( 
            ISMTPStoreDriver __RPC_FAR * This,
            /* [in] */ DWORD dwReason);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *LocalDelivery )( 
            ISMTPStoreDriver __RPC_FAR * This,
            /* [in] */ IMailMsgProperties __RPC_FAR *pMsg,
            /* [in] */ DWORD dwRecipCount,
            /* [size_is][in] */ DWORD __RPC_FAR *pdwRecipIndexes,
            /* [unique][in] */ IMailMsgNotify __RPC_FAR *pNotify);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *EnumerateAndSubmitMessages )( 
            ISMTPStoreDriver __RPC_FAR * This,
            /* [unique][in] */ IMailMsgNotify __RPC_FAR *pNotify);
        
        END_INTERFACE
    } ISMTPStoreDriverVtbl;

    interface ISMTPStoreDriver
    {
        CONST_VTBL struct ISMTPStoreDriverVtbl __RPC_FAR *lpVtbl;
    };

    

#ifdef COBJMACROS


#define ISMTPStoreDriver_QueryInterface(This,riid,ppvObject)	\
    (This)->lpVtbl -> QueryInterface(This,riid,ppvObject)

#define ISMTPStoreDriver_AddRef(This)	\
    (This)->lpVtbl -> AddRef(This)

#define ISMTPStoreDriver_Release(This)	\
    (This)->lpVtbl -> Release(This)


#define ISMTPStoreDriver_Init(This,dwInstance,pBinding,pServer,dwReason,ppStoreDriver)	\
    (This)->lpVtbl -> Init(This,dwInstance,pBinding,pServer,dwReason,ppStoreDriver)

#define ISMTPStoreDriver_PrepareForShutdown(This,dwReason)	\
    (This)->lpVtbl -> PrepareForShutdown(This,dwReason)

#define ISMTPStoreDriver_Shutdown(This,dwReason)	\
    (This)->lpVtbl -> Shutdown(This,dwReason)

#define ISMTPStoreDriver_LocalDelivery(This,pMsg,dwRecipCount,pdwRecipIndexes,pNotify)	\
    (This)->lpVtbl -> LocalDelivery(This,pMsg,dwRecipCount,pdwRecipIndexes,pNotify)

#define ISMTPStoreDriver_EnumerateAndSubmitMessages(This,pNotify)	\
    (This)->lpVtbl -> EnumerateAndSubmitMessages(This,pNotify)

#endif /* COBJMACROS */


#endif 	/* C style interface */



/* [helpstring] */ HRESULT STDMETHODCALLTYPE ISMTPStoreDriver_Init_Proxy( 
    ISMTPStoreDriver __RPC_FAR * This,
    /* [in] */ DWORD dwInstance,
    /* [unique][in] */ IUnknown __RPC_FAR *pBinding,
    /* [in] */ IUnknown __RPC_FAR *pServer,
    /* [in] */ DWORD dwReason,
    /* [out] */ IUnknown __RPC_FAR *__RPC_FAR *ppStoreDriver);


void __RPC_STUB ISMTPStoreDriver_Init_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE ISMTPStoreDriver_PrepareForShutdown_Proxy( 
    ISMTPStoreDriver __RPC_FAR * This,
    /* [in] */ DWORD dwReason);


void __RPC_STUB ISMTPStoreDriver_PrepareForShutdown_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE ISMTPStoreDriver_Shutdown_Proxy( 
    ISMTPStoreDriver __RPC_FAR * This,
    /* [in] */ DWORD dwReason);


void __RPC_STUB ISMTPStoreDriver_Shutdown_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE ISMTPStoreDriver_LocalDelivery_Proxy( 
    ISMTPStoreDriver __RPC_FAR * This,
    /* [in] */ IMailMsgProperties __RPC_FAR *pMsg,
    /* [in] */ DWORD dwRecipCount,
    /* [size_is][in] */ DWORD __RPC_FAR *pdwRecipIndexes,
    /* [unique][in] */ IMailMsgNotify __RPC_FAR *pNotify);


void __RPC_STUB ISMTPStoreDriver_LocalDelivery_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE ISMTPStoreDriver_EnumerateAndSubmitMessages_Proxy( 
    ISMTPStoreDriver __RPC_FAR * This,
    /* [unique][in] */ IMailMsgNotify __RPC_FAR *pNotify);


void __RPC_STUB ISMTPStoreDriver_EnumerateAndSubmitMessages_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);



#endif 	/* __ISMTPStoreDriver_INTERFACE_DEFINED__ */


#ifndef __IMailMsgBind_INTERFACE_DEFINED__
#define __IMailMsgBind_INTERFACE_DEFINED__

/* interface IMailMsgBind */
/* [uuid][unique][object][local][helpstring] */ 


EXTERN_C const IID IID_IMailMsgBind;

#if defined(__cplusplus) && !defined(CINTERFACE)
    
    MIDL_INTERFACE("38cb448a-ca62-11d1-9ff3-00c04fa37348")
    IMailMsgBind : public IUnknown
    {
    public:
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE BindToStore( 
            /* [in] */ IMailMsgPropertyStream __RPC_FAR *pStream,
            /* [in] */ IMailMsgStoreDriver __RPC_FAR *pStore,
            /* [in] */ PFIO_CONTEXT pFIOContentFile) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE GetBinding( 
            /* [out] */ PFIO_CONTEXT __RPC_FAR *ppFIOContentFile,
            /* [unique][in] */ IMailMsgNotify __RPC_FAR *pNotify) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE ReleaseContext( void) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE GetProperties( 
            /* [in] */ IMailMsgPropertyStream __RPC_FAR *pStream,
            /* [in] */ DWORD dwFlags,
            /* [unique][in] */ IMailMsgNotify __RPC_FAR *pNotify) = 0;
        
    };
    
#else 	/* C style interface */

    typedef struct IMailMsgBindVtbl
    {
        BEGIN_INTERFACE
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *QueryInterface )( 
            IMailMsgBind __RPC_FAR * This,
            /* [in] */ REFIID riid,
            /* [iid_is][out] */ void __RPC_FAR *__RPC_FAR *ppvObject);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *AddRef )( 
            IMailMsgBind __RPC_FAR * This);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *Release )( 
            IMailMsgBind __RPC_FAR * This);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *BindToStore )( 
            IMailMsgBind __RPC_FAR * This,
            /* [in] */ IMailMsgPropertyStream __RPC_FAR *pStream,
            /* [in] */ IMailMsgStoreDriver __RPC_FAR *pStore,
            /* [in] */ PFIO_CONTEXT pFIOContentFile);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetBinding )( 
            IMailMsgBind __RPC_FAR * This,
            /* [out] */ PFIO_CONTEXT __RPC_FAR *ppFIOContentFile,
            /* [unique][in] */ IMailMsgNotify __RPC_FAR *pNotify);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *ReleaseContext )( 
            IMailMsgBind __RPC_FAR * This);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetProperties )( 
            IMailMsgBind __RPC_FAR * This,
            /* [in] */ IMailMsgPropertyStream __RPC_FAR *pStream,
            /* [in] */ DWORD dwFlags,
            /* [unique][in] */ IMailMsgNotify __RPC_FAR *pNotify);
        
        END_INTERFACE
    } IMailMsgBindVtbl;

    interface IMailMsgBind
    {
        CONST_VTBL struct IMailMsgBindVtbl __RPC_FAR *lpVtbl;
    };

    

#ifdef COBJMACROS


#define IMailMsgBind_QueryInterface(This,riid,ppvObject)	\
    (This)->lpVtbl -> QueryInterface(This,riid,ppvObject)

#define IMailMsgBind_AddRef(This)	\
    (This)->lpVtbl -> AddRef(This)

#define IMailMsgBind_Release(This)	\
    (This)->lpVtbl -> Release(This)


#define IMailMsgBind_BindToStore(This,pStream,pStore,pFIOContentFile)	\
    (This)->lpVtbl -> BindToStore(This,pStream,pStore,pFIOContentFile)

#define IMailMsgBind_GetBinding(This,ppFIOContentFile,pNotify)	\
    (This)->lpVtbl -> GetBinding(This,ppFIOContentFile,pNotify)

#define IMailMsgBind_ReleaseContext(This)	\
    (This)->lpVtbl -> ReleaseContext(This)

#define IMailMsgBind_GetProperties(This,pStream,dwFlags,pNotify)	\
    (This)->lpVtbl -> GetProperties(This,pStream,dwFlags,pNotify)

#endif /* COBJMACROS */


#endif 	/* C style interface */



/* [helpstring] */ HRESULT STDMETHODCALLTYPE IMailMsgBind_BindToStore_Proxy( 
    IMailMsgBind __RPC_FAR * This,
    /* [in] */ IMailMsgPropertyStream __RPC_FAR *pStream,
    /* [in] */ IMailMsgStoreDriver __RPC_FAR *pStore,
    /* [in] */ PFIO_CONTEXT pFIOContentFile);


void __RPC_STUB IMailMsgBind_BindToStore_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IMailMsgBind_GetBinding_Proxy( 
    IMailMsgBind __RPC_FAR * This,
    /* [out] */ PFIO_CONTEXT __RPC_FAR *ppFIOContentFile,
    /* [unique][in] */ IMailMsgNotify __RPC_FAR *pNotify);


void __RPC_STUB IMailMsgBind_GetBinding_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IMailMsgBind_ReleaseContext_Proxy( 
    IMailMsgBind __RPC_FAR * This);


void __RPC_STUB IMailMsgBind_ReleaseContext_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IMailMsgBind_GetProperties_Proxy( 
    IMailMsgBind __RPC_FAR * This,
    /* [in] */ IMailMsgPropertyStream __RPC_FAR *pStream,
    /* [in] */ DWORD dwFlags,
    /* [unique][in] */ IMailMsgNotify __RPC_FAR *pNotify);


void __RPC_STUB IMailMsgBind_GetProperties_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);



#endif 	/* __IMailMsgBind_INTERFACE_DEFINED__ */


#ifndef __IMailMsgPropertyBag_INTERFACE_DEFINED__
#define __IMailMsgPropertyBag_INTERFACE_DEFINED__

/* interface IMailMsgPropertyBag */
/* [uuid][unique][object][local][helpstring] */ 


EXTERN_C const IID IID_IMailMsgPropertyBag;

#if defined(__cplusplus) && !defined(CINTERFACE)
    
    MIDL_INTERFACE("d6d0509c-ec51-11d1-aa65-00c04fa35b82")
    IMailMsgPropertyBag : public IUnknown
    {
    public:
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE PutProperty( 
            /* [in] */ DWORD dwPropID,
            /* [in] */ DWORD cbLength,
            /* [unique][length_is][size_is][in] */ BYTE __RPC_FAR *pbValue) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE GetProperty( 
            /* [in] */ DWORD dwPropID,
            /* [in] */ DWORD cbLength,
            /* [out] */ DWORD __RPC_FAR *pcbLength,
            /* [length_is][size_is][out] */ BYTE __RPC_FAR *pbValue) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE PutStringA( 
            /* [in] */ DWORD dwPropID,
            /* [unique][in] */ LPCSTR pszValue) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE GetStringA( 
            /* [in] */ DWORD dwPropID,
            /* [in] */ DWORD cchLength,
            /* [size_is][out] */ LPSTR pszValue) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE PutStringW( 
            /* [in] */ DWORD dwPropID,
            /* [unique][in] */ LPCWSTR pszValue) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE GetStringW( 
            /* [in] */ DWORD dwPropID,
            /* [in] */ DWORD cchLength,
            /* [size_is][out] */ LPWSTR pszValue) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE PutDWORD( 
            /* [in] */ DWORD dwPropID,
            /* [in] */ DWORD dwValue) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE GetDWORD( 
            /* [in] */ DWORD dwPropID,
            /* [out] */ DWORD __RPC_FAR *pdwValue) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE PutBool( 
            /* [in] */ DWORD dwPropID,
            /* [in] */ DWORD bValue) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE GetBool( 
            /* [in] */ DWORD dwPropID,
            /* [out] */ DWORD __RPC_FAR *pbValue) = 0;
        
    };
    
#else 	/* C style interface */

    typedef struct IMailMsgPropertyBagVtbl
    {
        BEGIN_INTERFACE
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *QueryInterface )( 
            IMailMsgPropertyBag __RPC_FAR * This,
            /* [in] */ REFIID riid,
            /* [iid_is][out] */ void __RPC_FAR *__RPC_FAR *ppvObject);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *AddRef )( 
            IMailMsgPropertyBag __RPC_FAR * This);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *Release )( 
            IMailMsgPropertyBag __RPC_FAR * This);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *PutProperty )( 
            IMailMsgPropertyBag __RPC_FAR * This,
            /* [in] */ DWORD dwPropID,
            /* [in] */ DWORD cbLength,
            /* [unique][length_is][size_is][in] */ BYTE __RPC_FAR *pbValue);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetProperty )( 
            IMailMsgPropertyBag __RPC_FAR * This,
            /* [in] */ DWORD dwPropID,
            /* [in] */ DWORD cbLength,
            /* [out] */ DWORD __RPC_FAR *pcbLength,
            /* [length_is][size_is][out] */ BYTE __RPC_FAR *pbValue);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *PutStringA )( 
            IMailMsgPropertyBag __RPC_FAR * This,
            /* [in] */ DWORD dwPropID,
            /* [unique][in] */ LPCSTR pszValue);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetStringA )( 
            IMailMsgPropertyBag __RPC_FAR * This,
            /* [in] */ DWORD dwPropID,
            /* [in] */ DWORD cchLength,
            /* [size_is][out] */ LPSTR pszValue);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *PutStringW )( 
            IMailMsgPropertyBag __RPC_FAR * This,
            /* [in] */ DWORD dwPropID,
            /* [unique][in] */ LPCWSTR pszValue);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetStringW )( 
            IMailMsgPropertyBag __RPC_FAR * This,
            /* [in] */ DWORD dwPropID,
            /* [in] */ DWORD cchLength,
            /* [size_is][out] */ LPWSTR pszValue);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *PutDWORD )( 
            IMailMsgPropertyBag __RPC_FAR * This,
            /* [in] */ DWORD dwPropID,
            /* [in] */ DWORD dwValue);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetDWORD )( 
            IMailMsgPropertyBag __RPC_FAR * This,
            /* [in] */ DWORD dwPropID,
            /* [out] */ DWORD __RPC_FAR *pdwValue);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *PutBool )( 
            IMailMsgPropertyBag __RPC_FAR * This,
            /* [in] */ DWORD dwPropID,
            /* [in] */ DWORD bValue);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetBool )( 
            IMailMsgPropertyBag __RPC_FAR * This,
            /* [in] */ DWORD dwPropID,
            /* [out] */ DWORD __RPC_FAR *pbValue);
        
        END_INTERFACE
    } IMailMsgPropertyBagVtbl;

    interface IMailMsgPropertyBag
    {
        CONST_VTBL struct IMailMsgPropertyBagVtbl __RPC_FAR *lpVtbl;
    };

    

#ifdef COBJMACROS


#define IMailMsgPropertyBag_QueryInterface(This,riid,ppvObject)	\
    (This)->lpVtbl -> QueryInterface(This,riid,ppvObject)

#define IMailMsgPropertyBag_AddRef(This)	\
    (This)->lpVtbl -> AddRef(This)

#define IMailMsgPropertyBag_Release(This)	\
    (This)->lpVtbl -> Release(This)


#define IMailMsgPropertyBag_PutProperty(This,dwPropID,cbLength,pbValue)	\
    (This)->lpVtbl -> PutProperty(This,dwPropID,cbLength,pbValue)

#define IMailMsgPropertyBag_GetProperty(This,dwPropID,cbLength,pcbLength,pbValue)	\
    (This)->lpVtbl -> GetProperty(This,dwPropID,cbLength,pcbLength,pbValue)

#define IMailMsgPropertyBag_PutStringA(This,dwPropID,pszValue)	\
    (This)->lpVtbl -> PutStringA(This,dwPropID,pszValue)

#define IMailMsgPropertyBag_GetStringA(This,dwPropID,cchLength,pszValue)	\
    (This)->lpVtbl -> GetStringA(This,dwPropID,cchLength,pszValue)

#define IMailMsgPropertyBag_PutStringW(This,dwPropID,pszValue)	\
    (This)->lpVtbl -> PutStringW(This,dwPropID,pszValue)

#define IMailMsgPropertyBag_GetStringW(This,dwPropID,cchLength,pszValue)	\
    (This)->lpVtbl -> GetStringW(This,dwPropID,cchLength,pszValue)

#define IMailMsgPropertyBag_PutDWORD(This,dwPropID,dwValue)	\
    (This)->lpVtbl -> PutDWORD(This,dwPropID,dwValue)

#define IMailMsgPropertyBag_GetDWORD(This,dwPropID,pdwValue)	\
    (This)->lpVtbl -> GetDWORD(This,dwPropID,pdwValue)

#define IMailMsgPropertyBag_PutBool(This,dwPropID,bValue)	\
    (This)->lpVtbl -> PutBool(This,dwPropID,bValue)

#define IMailMsgPropertyBag_GetBool(This,dwPropID,pbValue)	\
    (This)->lpVtbl -> GetBool(This,dwPropID,pbValue)

#endif /* COBJMACROS */


#endif 	/* C style interface */



/* [helpstring] */ HRESULT STDMETHODCALLTYPE IMailMsgPropertyBag_PutProperty_Proxy( 
    IMailMsgPropertyBag __RPC_FAR * This,
    /* [in] */ DWORD dwPropID,
    /* [in] */ DWORD cbLength,
    /* [unique][length_is][size_is][in] */ BYTE __RPC_FAR *pbValue);


void __RPC_STUB IMailMsgPropertyBag_PutProperty_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IMailMsgPropertyBag_GetProperty_Proxy( 
    IMailMsgPropertyBag __RPC_FAR * This,
    /* [in] */ DWORD dwPropID,
    /* [in] */ DWORD cbLength,
    /* [out] */ DWORD __RPC_FAR *pcbLength,
    /* [length_is][size_is][out] */ BYTE __RPC_FAR *pbValue);


void __RPC_STUB IMailMsgPropertyBag_GetProperty_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IMailMsgPropertyBag_PutStringA_Proxy( 
    IMailMsgPropertyBag __RPC_FAR * This,
    /* [in] */ DWORD dwPropID,
    /* [unique][in] */ LPCSTR pszValue);


void __RPC_STUB IMailMsgPropertyBag_PutStringA_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IMailMsgPropertyBag_GetStringA_Proxy( 
    IMailMsgPropertyBag __RPC_FAR * This,
    /* [in] */ DWORD dwPropID,
    /* [in] */ DWORD cchLength,
    /* [size_is][out] */ LPSTR pszValue);


void __RPC_STUB IMailMsgPropertyBag_GetStringA_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IMailMsgPropertyBag_PutStringW_Proxy( 
    IMailMsgPropertyBag __RPC_FAR * This,
    /* [in] */ DWORD dwPropID,
    /* [unique][in] */ LPCWSTR pszValue);


void __RPC_STUB IMailMsgPropertyBag_PutStringW_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IMailMsgPropertyBag_GetStringW_Proxy( 
    IMailMsgPropertyBag __RPC_FAR * This,
    /* [in] */ DWORD dwPropID,
    /* [in] */ DWORD cchLength,
    /* [size_is][out] */ LPWSTR pszValue);


void __RPC_STUB IMailMsgPropertyBag_GetStringW_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IMailMsgPropertyBag_PutDWORD_Proxy( 
    IMailMsgPropertyBag __RPC_FAR * This,
    /* [in] */ DWORD dwPropID,
    /* [in] */ DWORD dwValue);


void __RPC_STUB IMailMsgPropertyBag_PutDWORD_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IMailMsgPropertyBag_GetDWORD_Proxy( 
    IMailMsgPropertyBag __RPC_FAR * This,
    /* [in] */ DWORD dwPropID,
    /* [out] */ DWORD __RPC_FAR *pdwValue);


void __RPC_STUB IMailMsgPropertyBag_GetDWORD_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IMailMsgPropertyBag_PutBool_Proxy( 
    IMailMsgPropertyBag __RPC_FAR * This,
    /* [in] */ DWORD dwPropID,
    /* [in] */ DWORD bValue);


void __RPC_STUB IMailMsgPropertyBag_PutBool_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IMailMsgPropertyBag_GetBool_Proxy( 
    IMailMsgPropertyBag __RPC_FAR * This,
    /* [in] */ DWORD dwPropID,
    /* [out] */ DWORD __RPC_FAR *pbValue);


void __RPC_STUB IMailMsgPropertyBag_GetBool_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);



#endif 	/* __IMailMsgPropertyBag_INTERFACE_DEFINED__ */


#ifndef __IMailMsgLoggingPropertyBag_INTERFACE_DEFINED__
#define __IMailMsgLoggingPropertyBag_INTERFACE_DEFINED__

/* interface IMailMsgLoggingPropertyBag */
/* [uuid][unique][object][local][helpstring] */ 


EXTERN_C const IID IID_IMailMsgLoggingPropertyBag;

#if defined(__cplusplus) && !defined(CINTERFACE)
    
    MIDL_INTERFACE("4cb17416-ec53-11d1-aa65-00c04fa35b82")
    IMailMsgLoggingPropertyBag : public IMailMsgPropertyBag
    {
    public:
        virtual HRESULT STDMETHODCALLTYPE WriteToLog( 
            /* [in] */ LPCSTR pszClientHostName,
            /* [in] */ LPCSTR pszClientUserName,
            /* [in] */ LPCSTR pszServerAddress,
            /* [in] */ LPCSTR pszOperation,
            /* [in] */ LPCSTR pszTarget,
            /* [in] */ LPCSTR pszParameters,
            /* [in] */ LPCSTR pszVersion,
            /* [in] */ DWORD dwBytesSent,
            /* [in] */ DWORD dwBytesReceived,
            /* [in] */ DWORD dwProcessingTimeMS,
            /* [in] */ DWORD dwWin32Status,
            /* [in] */ DWORD dwProtocolStatus,
            /* [in] */ DWORD dwPort,
            /* [in] */ LPCSTR pszHTTPHeader) = 0;
        
    };
    
#else 	/* C style interface */

    typedef struct IMailMsgLoggingPropertyBagVtbl
    {
        BEGIN_INTERFACE
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *QueryInterface )( 
            IMailMsgLoggingPropertyBag __RPC_FAR * This,
            /* [in] */ REFIID riid,
            /* [iid_is][out] */ void __RPC_FAR *__RPC_FAR *ppvObject);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *AddRef )( 
            IMailMsgLoggingPropertyBag __RPC_FAR * This);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *Release )( 
            IMailMsgLoggingPropertyBag __RPC_FAR * This);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *PutProperty )( 
            IMailMsgLoggingPropertyBag __RPC_FAR * This,
            /* [in] */ DWORD dwPropID,
            /* [in] */ DWORD cbLength,
            /* [unique][length_is][size_is][in] */ BYTE __RPC_FAR *pbValue);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetProperty )( 
            IMailMsgLoggingPropertyBag __RPC_FAR * This,
            /* [in] */ DWORD dwPropID,
            /* [in] */ DWORD cbLength,
            /* [out] */ DWORD __RPC_FAR *pcbLength,
            /* [length_is][size_is][out] */ BYTE __RPC_FAR *pbValue);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *PutStringA )( 
            IMailMsgLoggingPropertyBag __RPC_FAR * This,
            /* [in] */ DWORD dwPropID,
            /* [unique][in] */ LPCSTR pszValue);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetStringA )( 
            IMailMsgLoggingPropertyBag __RPC_FAR * This,
            /* [in] */ DWORD dwPropID,
            /* [in] */ DWORD cchLength,
            /* [size_is][out] */ LPSTR pszValue);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *PutStringW )( 
            IMailMsgLoggingPropertyBag __RPC_FAR * This,
            /* [in] */ DWORD dwPropID,
            /* [unique][in] */ LPCWSTR pszValue);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetStringW )( 
            IMailMsgLoggingPropertyBag __RPC_FAR * This,
            /* [in] */ DWORD dwPropID,
            /* [in] */ DWORD cchLength,
            /* [size_is][out] */ LPWSTR pszValue);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *PutDWORD )( 
            IMailMsgLoggingPropertyBag __RPC_FAR * This,
            /* [in] */ DWORD dwPropID,
            /* [in] */ DWORD dwValue);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetDWORD )( 
            IMailMsgLoggingPropertyBag __RPC_FAR * This,
            /* [in] */ DWORD dwPropID,
            /* [out] */ DWORD __RPC_FAR *pdwValue);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *PutBool )( 
            IMailMsgLoggingPropertyBag __RPC_FAR * This,
            /* [in] */ DWORD dwPropID,
            /* [in] */ DWORD bValue);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetBool )( 
            IMailMsgLoggingPropertyBag __RPC_FAR * This,
            /* [in] */ DWORD dwPropID,
            /* [out] */ DWORD __RPC_FAR *pbValue);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *WriteToLog )( 
            IMailMsgLoggingPropertyBag __RPC_FAR * This,
            /* [in] */ LPCSTR pszClientHostName,
            /* [in] */ LPCSTR pszClientUserName,
            /* [in] */ LPCSTR pszServerAddress,
            /* [in] */ LPCSTR pszOperation,
            /* [in] */ LPCSTR pszTarget,
            /* [in] */ LPCSTR pszParameters,
            /* [in] */ LPCSTR pszVersion,
            /* [in] */ DWORD dwBytesSent,
            /* [in] */ DWORD dwBytesReceived,
            /* [in] */ DWORD dwProcessingTimeMS,
            /* [in] */ DWORD dwWin32Status,
            /* [in] */ DWORD dwProtocolStatus,
            /* [in] */ DWORD dwPort,
            /* [in] */ LPCSTR pszHTTPHeader);
        
        END_INTERFACE
    } IMailMsgLoggingPropertyBagVtbl;

    interface IMailMsgLoggingPropertyBag
    {
        CONST_VTBL struct IMailMsgLoggingPropertyBagVtbl __RPC_FAR *lpVtbl;
    };

    

#ifdef COBJMACROS


#define IMailMsgLoggingPropertyBag_QueryInterface(This,riid,ppvObject)	\
    (This)->lpVtbl -> QueryInterface(This,riid,ppvObject)

#define IMailMsgLoggingPropertyBag_AddRef(This)	\
    (This)->lpVtbl -> AddRef(This)

#define IMailMsgLoggingPropertyBag_Release(This)	\
    (This)->lpVtbl -> Release(This)


#define IMailMsgLoggingPropertyBag_PutProperty(This,dwPropID,cbLength,pbValue)	\
    (This)->lpVtbl -> PutProperty(This,dwPropID,cbLength,pbValue)

#define IMailMsgLoggingPropertyBag_GetProperty(This,dwPropID,cbLength,pcbLength,pbValue)	\
    (This)->lpVtbl -> GetProperty(This,dwPropID,cbLength,pcbLength,pbValue)

#define IMailMsgLoggingPropertyBag_PutStringA(This,dwPropID,pszValue)	\
    (This)->lpVtbl -> PutStringA(This,dwPropID,pszValue)

#define IMailMsgLoggingPropertyBag_GetStringA(This,dwPropID,cchLength,pszValue)	\
    (This)->lpVtbl -> GetStringA(This,dwPropID,cchLength,pszValue)

#define IMailMsgLoggingPropertyBag_PutStringW(This,dwPropID,pszValue)	\
    (This)->lpVtbl -> PutStringW(This,dwPropID,pszValue)

#define IMailMsgLoggingPropertyBag_GetStringW(This,dwPropID,cchLength,pszValue)	\
    (This)->lpVtbl -> GetStringW(This,dwPropID,cchLength,pszValue)

#define IMailMsgLoggingPropertyBag_PutDWORD(This,dwPropID,dwValue)	\
    (This)->lpVtbl -> PutDWORD(This,dwPropID,dwValue)

#define IMailMsgLoggingPropertyBag_GetDWORD(This,dwPropID,pdwValue)	\
    (This)->lpVtbl -> GetDWORD(This,dwPropID,pdwValue)

#define IMailMsgLoggingPropertyBag_PutBool(This,dwPropID,bValue)	\
    (This)->lpVtbl -> PutBool(This,dwPropID,bValue)

#define IMailMsgLoggingPropertyBag_GetBool(This,dwPropID,pbValue)	\
    (This)->lpVtbl -> GetBool(This,dwPropID,pbValue)


#define IMailMsgLoggingPropertyBag_WriteToLog(This,pszClientHostName,pszClientUserName,pszServerAddress,pszOperation,pszTarget,pszParameters,pszVersion,dwBytesSent,dwBytesReceived,dwProcessingTimeMS,dwWin32Status,dwProtocolStatus,dwPort,pszHTTPHeader)	\
    (This)->lpVtbl -> WriteToLog(This,pszClientHostName,pszClientUserName,pszServerAddress,pszOperation,pszTarget,pszParameters,pszVersion,dwBytesSent,dwBytesReceived,dwProcessingTimeMS,dwWin32Status,dwProtocolStatus,dwPort,pszHTTPHeader)

#endif /* COBJMACROS */


#endif 	/* C style interface */



HRESULT STDMETHODCALLTYPE IMailMsgLoggingPropertyBag_WriteToLog_Proxy( 
    IMailMsgLoggingPropertyBag __RPC_FAR * This,
    /* [in] */ LPCSTR pszClientHostName,
    /* [in] */ LPCSTR pszClientUserName,
    /* [in] */ LPCSTR pszServerAddress,
    /* [in] */ LPCSTR pszOperation,
    /* [in] */ LPCSTR pszTarget,
    /* [in] */ LPCSTR pszParameters,
    /* [in] */ LPCSTR pszVersion,
    /* [in] */ DWORD dwBytesSent,
    /* [in] */ DWORD dwBytesReceived,
    /* [in] */ DWORD dwProcessingTimeMS,
    /* [in] */ DWORD dwWin32Status,
    /* [in] */ DWORD dwProtocolStatus,
    /* [in] */ DWORD dwPort,
    /* [in] */ LPCSTR pszHTTPHeader);


void __RPC_STUB IMailMsgLoggingPropertyBag_WriteToLog_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);



#endif 	/* __IMailMsgLoggingPropertyBag_INTERFACE_DEFINED__ */


#ifndef __IMailMsgCleanupCallback_INTERFACE_DEFINED__
#define __IMailMsgCleanupCallback_INTERFACE_DEFINED__

/* interface IMailMsgCleanupCallback */
/* [uuid][unique][object][local][helpstring] */ 


EXTERN_C const IID IID_IMailMsgCleanupCallback;

#if defined(__cplusplus) && !defined(CINTERFACE)
    
    MIDL_INTERFACE("951C04A1-29F0-4b8e-9ED5-836C73766051")
    IMailMsgCleanupCallback : public IUnknown
    {
    public:
        virtual HRESULT STDMETHODCALLTYPE CleanupCallback( 
            /* [in] */ IUnknown __RPC_FAR *pObject,
            /* [in] */ PVOID pvContext) = 0;
        
    };
    
#else 	/* C style interface */

    typedef struct IMailMsgCleanupCallbackVtbl
    {
        BEGIN_INTERFACE
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *QueryInterface )( 
            IMailMsgCleanupCallback __RPC_FAR * This,
            /* [in] */ REFIID riid,
            /* [iid_is][out] */ void __RPC_FAR *__RPC_FAR *ppvObject);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *AddRef )( 
            IMailMsgCleanupCallback __RPC_FAR * This);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *Release )( 
            IMailMsgCleanupCallback __RPC_FAR * This);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *CleanupCallback )( 
            IMailMsgCleanupCallback __RPC_FAR * This,
            /* [in] */ IUnknown __RPC_FAR *pObject,
            /* [in] */ PVOID pvContext);
        
        END_INTERFACE
    } IMailMsgCleanupCallbackVtbl;

    interface IMailMsgCleanupCallback
    {
        CONST_VTBL struct IMailMsgCleanupCallbackVtbl __RPC_FAR *lpVtbl;
    };

    

#ifdef COBJMACROS


#define IMailMsgCleanupCallback_QueryInterface(This,riid,ppvObject)	\
    (This)->lpVtbl -> QueryInterface(This,riid,ppvObject)

#define IMailMsgCleanupCallback_AddRef(This)	\
    (This)->lpVtbl -> AddRef(This)

#define IMailMsgCleanupCallback_Release(This)	\
    (This)->lpVtbl -> Release(This)


#define IMailMsgCleanupCallback_CleanupCallback(This,pObject,pvContext)	\
    (This)->lpVtbl -> CleanupCallback(This,pObject,pvContext)

#endif /* COBJMACROS */


#endif 	/* C style interface */



HRESULT STDMETHODCALLTYPE IMailMsgCleanupCallback_CleanupCallback_Proxy( 
    IMailMsgCleanupCallback __RPC_FAR * This,
    /* [in] */ IUnknown __RPC_FAR *pObject,
    /* [in] */ PVOID pvContext);


void __RPC_STUB IMailMsgCleanupCallback_CleanupCallback_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);



#endif 	/* __IMailMsgCleanupCallback_INTERFACE_DEFINED__ */


#ifndef __IMailMsgRegisterCleanupCallback_INTERFACE_DEFINED__
#define __IMailMsgRegisterCleanupCallback_INTERFACE_DEFINED__

/* interface IMailMsgRegisterCleanupCallback */
/* [uuid][unique][object][local][helpstring] */ 


EXTERN_C const IID IID_IMailMsgRegisterCleanupCallback;

#if defined(__cplusplus) && !defined(CINTERFACE)
    
    MIDL_INTERFACE("00561C2F-5E90-49e5-9E73-7BF9129298A0")
    IMailMsgRegisterCleanupCallback : public IUnknown
    {
    public:
        virtual HRESULT STDMETHODCALLTYPE RegisterCleanupCallback( 
            /* [in] */ IMailMsgCleanupCallback __RPC_FAR *pICallback,
            /* [in] */ PVOID pvContext) = 0;
        
    };
    
#else 	/* C style interface */

    typedef struct IMailMsgRegisterCleanupCallbackVtbl
    {
        BEGIN_INTERFACE
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *QueryInterface )( 
            IMailMsgRegisterCleanupCallback __RPC_FAR * This,
            /* [in] */ REFIID riid,
            /* [iid_is][out] */ void __RPC_FAR *__RPC_FAR *ppvObject);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *AddRef )( 
            IMailMsgRegisterCleanupCallback __RPC_FAR * This);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *Release )( 
            IMailMsgRegisterCleanupCallback __RPC_FAR * This);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *RegisterCleanupCallback )( 
            IMailMsgRegisterCleanupCallback __RPC_FAR * This,
            /* [in] */ IMailMsgCleanupCallback __RPC_FAR *pICallback,
            /* [in] */ PVOID pvContext);
        
        END_INTERFACE
    } IMailMsgRegisterCleanupCallbackVtbl;

    interface IMailMsgRegisterCleanupCallback
    {
        CONST_VTBL struct IMailMsgRegisterCleanupCallbackVtbl __RPC_FAR *lpVtbl;
    };

    

#ifdef COBJMACROS


#define IMailMsgRegisterCleanupCallback_QueryInterface(This,riid,ppvObject)	\
    (This)->lpVtbl -> QueryInterface(This,riid,ppvObject)

#define IMailMsgRegisterCleanupCallback_AddRef(This)	\
    (This)->lpVtbl -> AddRef(This)

#define IMailMsgRegisterCleanupCallback_Release(This)	\
    (This)->lpVtbl -> Release(This)


#define IMailMsgRegisterCleanupCallback_RegisterCleanupCallback(This,pICallback,pvContext)	\
    (This)->lpVtbl -> RegisterCleanupCallback(This,pICallback,pvContext)

#endif /* COBJMACROS */


#endif 	/* C style interface */



HRESULT STDMETHODCALLTYPE IMailMsgRegisterCleanupCallback_RegisterCleanupCallback_Proxy( 
    IMailMsgRegisterCleanupCallback __RPC_FAR * This,
    /* [in] */ IMailMsgCleanupCallback __RPC_FAR *pICallback,
    /* [in] */ PVOID pvContext);


void __RPC_STUB IMailMsgRegisterCleanupCallback_RegisterCleanupCallback_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);



#endif 	/* __IMailMsgRegisterCleanupCallback_INTERFACE_DEFINED__ */


/* interface __MIDL_itf_MailMsg_0260 */
/* [local] */ 

typedef struct _MSG_TRACK_INFO
    {
    LPSTR pszClientIp;
    LPSTR pszClientName;
    LPSTR pszPartnerName;
    LPSTR pszServerIp;
    LPSTR pszServerName;
    LPSTR pszRecipientAddress;
    LPSTR pszSenderAddress;
    DWORD dwEventId;
    LPSTR pszMessageId;
    DWORD dwPriority;
    DWORD dwRcptReportStatus;
    DWORD cbMessageSize;
    DWORD cRcpts;
    DWORD dwTimeTaken;
    DWORD dwEncryption;
    LPSTR pszVersion;
    LPSTR pszLinkMsgId;
    LPSTR pszSubject;
    }	MSG_TRACK_INFO;

typedef struct _MSG_TRACK_INFO __RPC_FAR *LPMSG_TRACK_INFO;

typedef struct _EVENT_LOG_INFO
    {
    DWORD dwEventId;
    DWORD dwErrorCode;
    LPSTR pszEventLogMsg;
    }	EVENT_LOG_INFO;

typedef struct _EVENT_LOG_INFO __RPC_FAR *LPEVENT_LOG_INFO;



extern RPC_IF_HANDLE __MIDL_itf_MailMsg_0260_v0_0_c_ifspec;
extern RPC_IF_HANDLE __MIDL_itf_MailMsg_0260_v0_0_s_ifspec;

#ifndef __ISMTPServer_INTERFACE_DEFINED__
#define __ISMTPServer_INTERFACE_DEFINED__

/* interface ISMTPServer */
/* [uuid][unique][object][local][helpstring] */ 


EXTERN_C const IID IID_ISMTPServer;

#if defined(__cplusplus) && !defined(CINTERFACE)
    
    MIDL_INTERFACE("22625594-d822-11d1-9ff7-00c04fa37348")
    ISMTPServer : public IUnknown
    {
    public:
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE AllocMessage( 
            /* [out] */ IMailMsgProperties __RPC_FAR *__RPC_FAR *ppMsg) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE SubmitMessage( 
            /* [in] */ IMailMsgProperties __RPC_FAR *pMsg) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE TriggerLocalDelivery( 
            /* [in] */ IMailMsgProperties __RPC_FAR *pMsg,
            DWORD dwRecipientCount,
            DWORD __RPC_FAR *pdwRecipIndexes) = 0;
        
        virtual HRESULT STDMETHODCALLTYPE ReadMetabaseString( 
            /* [in] */ DWORD MetabaseId,
            /* [length_is][size_is][out][in] */ unsigned char __RPC_FAR *Buffer,
            /* [out][in] */ DWORD __RPC_FAR *BufferSize,
            /* [in] */ BOOL fSecure) = 0;
        
        virtual HRESULT STDMETHODCALLTYPE ReadMetabaseDword( 
            /* [in] */ DWORD MetabaseId,
            /* [out] */ DWORD __RPC_FAR *dwValue) = 0;
        
        virtual HRESULT STDMETHODCALLTYPE ServerStartHintFunction( void) = 0;
        
        virtual HRESULT STDMETHODCALLTYPE ServerStopHintFunction( void) = 0;
        
        virtual HRESULT STDMETHODCALLTYPE TriggerServerEvent( 
            /* [in] */ DWORD dwEventID,
            /* [in] */ PVOID pvContext) = 0;
        
        virtual HRESULT STDMETHODCALLTYPE WriteLog( 
            /* [in] */ LPMSG_TRACK_INFO pMsgTrackInfo,
            /* [in] */ IMailMsgProperties __RPC_FAR *pMsg,
            /* [in] */ LPEVENT_LOG_INFO pEventLogInfo,
            /* [in] */ LPSTR pszProtocolLog) = 0;
        
        virtual HRESULT STDMETHODCALLTYPE ReadMetabaseData( 
            /* [in] */ DWORD MetabaseId,
            /* [length_is][size_is][out][in] */ BYTE __RPC_FAR *Buffer,
            /* [out][in] */ DWORD __RPC_FAR *BufferSize) = 0;
        
    };
    
#else 	/* C style interface */

    typedef struct ISMTPServerVtbl
    {
        BEGIN_INTERFACE
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *QueryInterface )( 
            ISMTPServer __RPC_FAR * This,
            /* [in] */ REFIID riid,
            /* [iid_is][out] */ void __RPC_FAR *__RPC_FAR *ppvObject);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *AddRef )( 
            ISMTPServer __RPC_FAR * This);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *Release )( 
            ISMTPServer __RPC_FAR * This);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *AllocMessage )( 
            ISMTPServer __RPC_FAR * This,
            /* [out] */ IMailMsgProperties __RPC_FAR *__RPC_FAR *ppMsg);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *SubmitMessage )( 
            ISMTPServer __RPC_FAR * This,
            /* [in] */ IMailMsgProperties __RPC_FAR *pMsg);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *TriggerLocalDelivery )( 
            ISMTPServer __RPC_FAR * This,
            /* [in] */ IMailMsgProperties __RPC_FAR *pMsg,
            DWORD dwRecipientCount,
            DWORD __RPC_FAR *pdwRecipIndexes);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *ReadMetabaseString )( 
            ISMTPServer __RPC_FAR * This,
            /* [in] */ DWORD MetabaseId,
            /* [length_is][size_is][out][in] */ unsigned char __RPC_FAR *Buffer,
            /* [out][in] */ DWORD __RPC_FAR *BufferSize,
            /* [in] */ BOOL fSecure);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *ReadMetabaseDword )( 
            ISMTPServer __RPC_FAR * This,
            /* [in] */ DWORD MetabaseId,
            /* [out] */ DWORD __RPC_FAR *dwValue);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *ServerStartHintFunction )( 
            ISMTPServer __RPC_FAR * This);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *ServerStopHintFunction )( 
            ISMTPServer __RPC_FAR * This);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *TriggerServerEvent )( 
            ISMTPServer __RPC_FAR * This,
            /* [in] */ DWORD dwEventID,
            /* [in] */ PVOID pvContext);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *WriteLog )( 
            ISMTPServer __RPC_FAR * This,
            /* [in] */ LPMSG_TRACK_INFO pMsgTrackInfo,
            /* [in] */ IMailMsgProperties __RPC_FAR *pMsg,
            /* [in] */ LPEVENT_LOG_INFO pEventLogInfo,
            /* [in] */ LPSTR pszProtocolLog);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *ReadMetabaseData )( 
            ISMTPServer __RPC_FAR * This,
            /* [in] */ DWORD MetabaseId,
            /* [length_is][size_is][out][in] */ BYTE __RPC_FAR *Buffer,
            /* [out][in] */ DWORD __RPC_FAR *BufferSize);
        
        END_INTERFACE
    } ISMTPServerVtbl;

    interface ISMTPServer
    {
        CONST_VTBL struct ISMTPServerVtbl __RPC_FAR *lpVtbl;
    };

    

#ifdef COBJMACROS


#define ISMTPServer_QueryInterface(This,riid,ppvObject)	\
    (This)->lpVtbl -> QueryInterface(This,riid,ppvObject)

#define ISMTPServer_AddRef(This)	\
    (This)->lpVtbl -> AddRef(This)

#define ISMTPServer_Release(This)	\
    (This)->lpVtbl -> Release(This)


#define ISMTPServer_AllocMessage(This,ppMsg)	\
    (This)->lpVtbl -> AllocMessage(This,ppMsg)

#define ISMTPServer_SubmitMessage(This,pMsg)	\
    (This)->lpVtbl -> SubmitMessage(This,pMsg)

#define ISMTPServer_TriggerLocalDelivery(This,pMsg,dwRecipientCount,pdwRecipIndexes)	\
    (This)->lpVtbl -> TriggerLocalDelivery(This,pMsg,dwRecipientCount,pdwRecipIndexes)

#define ISMTPServer_ReadMetabaseString(This,MetabaseId,Buffer,BufferSize,fSecure)	\
    (This)->lpVtbl -> ReadMetabaseString(This,MetabaseId,Buffer,BufferSize,fSecure)

#define ISMTPServer_ReadMetabaseDword(This,MetabaseId,dwValue)	\
    (This)->lpVtbl -> ReadMetabaseDword(This,MetabaseId,dwValue)

#define ISMTPServer_ServerStartHintFunction(This)	\
    (This)->lpVtbl -> ServerStartHintFunction(This)

#define ISMTPServer_ServerStopHintFunction(This)	\
    (This)->lpVtbl -> ServerStopHintFunction(This)

#define ISMTPServer_TriggerServerEvent(This,dwEventID,pvContext)	\
    (This)->lpVtbl -> TriggerServerEvent(This,dwEventID,pvContext)

#define ISMTPServer_WriteLog(This,pMsgTrackInfo,pMsg,pEventLogInfo,pszProtocolLog)	\
    (This)->lpVtbl -> WriteLog(This,pMsgTrackInfo,pMsg,pEventLogInfo,pszProtocolLog)

#define ISMTPServer_ReadMetabaseData(This,MetabaseId,Buffer,BufferSize)	\
    (This)->lpVtbl -> ReadMetabaseData(This,MetabaseId,Buffer,BufferSize)

#endif /* COBJMACROS */


#endif 	/* C style interface */



/* [helpstring] */ HRESULT STDMETHODCALLTYPE ISMTPServer_AllocMessage_Proxy( 
    ISMTPServer __RPC_FAR * This,
    /* [out] */ IMailMsgProperties __RPC_FAR *__RPC_FAR *ppMsg);


void __RPC_STUB ISMTPServer_AllocMessage_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE ISMTPServer_SubmitMessage_Proxy( 
    ISMTPServer __RPC_FAR * This,
    /* [in] */ IMailMsgProperties __RPC_FAR *pMsg);


void __RPC_STUB ISMTPServer_SubmitMessage_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE ISMTPServer_TriggerLocalDelivery_Proxy( 
    ISMTPServer __RPC_FAR * This,
    /* [in] */ IMailMsgProperties __RPC_FAR *pMsg,
    DWORD dwRecipientCount,
    DWORD __RPC_FAR *pdwRecipIndexes);


void __RPC_STUB ISMTPServer_TriggerLocalDelivery_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


HRESULT STDMETHODCALLTYPE ISMTPServer_ReadMetabaseString_Proxy( 
    ISMTPServer __RPC_FAR * This,
    /* [in] */ DWORD MetabaseId,
    /* [length_is][size_is][out][in] */ unsigned char __RPC_FAR *Buffer,
    /* [out][in] */ DWORD __RPC_FAR *BufferSize,
    /* [in] */ BOOL fSecure);


void __RPC_STUB ISMTPServer_ReadMetabaseString_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


HRESULT STDMETHODCALLTYPE ISMTPServer_ReadMetabaseDword_Proxy( 
    ISMTPServer __RPC_FAR * This,
    /* [in] */ DWORD MetabaseId,
    /* [out] */ DWORD __RPC_FAR *dwValue);


void __RPC_STUB ISMTPServer_ReadMetabaseDword_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


HRESULT STDMETHODCALLTYPE ISMTPServer_ServerStartHintFunction_Proxy( 
    ISMTPServer __RPC_FAR * This);


void __RPC_STUB ISMTPServer_ServerStartHintFunction_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


HRESULT STDMETHODCALLTYPE ISMTPServer_ServerStopHintFunction_Proxy( 
    ISMTPServer __RPC_FAR * This);


void __RPC_STUB ISMTPServer_ServerStopHintFunction_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


HRESULT STDMETHODCALLTYPE ISMTPServer_TriggerServerEvent_Proxy( 
    ISMTPServer __RPC_FAR * This,
    /* [in] */ DWORD dwEventID,
    /* [in] */ PVOID pvContext);


void __RPC_STUB ISMTPServer_TriggerServerEvent_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


HRESULT STDMETHODCALLTYPE ISMTPServer_WriteLog_Proxy( 
    ISMTPServer __RPC_FAR * This,
    /* [in] */ LPMSG_TRACK_INFO pMsgTrackInfo,
    /* [in] */ IMailMsgProperties __RPC_FAR *pMsg,
    /* [in] */ LPEVENT_LOG_INFO pEventLogInfo,
    /* [in] */ LPSTR pszProtocolLog);


void __RPC_STUB ISMTPServer_WriteLog_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


HRESULT STDMETHODCALLTYPE ISMTPServer_ReadMetabaseData_Proxy( 
    ISMTPServer __RPC_FAR * This,
    /* [in] */ DWORD MetabaseId,
    /* [length_is][size_is][out][in] */ BYTE __RPC_FAR *Buffer,
    /* [out][in] */ DWORD __RPC_FAR *BufferSize);


void __RPC_STUB ISMTPServer_ReadMetabaseData_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);



#endif 	/* __ISMTPServer_INTERFACE_DEFINED__ */


#ifndef __ISMTPServerInternal_INTERFACE_DEFINED__
#define __ISMTPServerInternal_INTERFACE_DEFINED__

/* interface ISMTPServerInternal */
/* [uuid][unique][object][local][helpstring] */ 


EXTERN_C const IID IID_ISMTPServerInternal;

#if defined(__cplusplus) && !defined(CINTERFACE)
    
    MIDL_INTERFACE("57EE6C15-1870-11d2-A689-00C04FA3490A")
    ISMTPServerInternal : public ISMTPServer
    {
    public:
        virtual HRESULT STDMETHODCALLTYPE AllocBoundMessage( 
            /* [out] */ IMailMsgProperties __RPC_FAR *__RPC_FAR *ppMsg,
            /* [out] */ PFIO_CONTEXT __RPC_FAR *phContent) = 0;
        
    };
    
#else 	/* C style interface */

    typedef struct ISMTPServerInternalVtbl
    {
        BEGIN_INTERFACE
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *QueryInterface )( 
            ISMTPServerInternal __RPC_FAR * This,
            /* [in] */ REFIID riid,
            /* [iid_is][out] */ void __RPC_FAR *__RPC_FAR *ppvObject);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *AddRef )( 
            ISMTPServerInternal __RPC_FAR * This);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *Release )( 
            ISMTPServerInternal __RPC_FAR * This);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *AllocMessage )( 
            ISMTPServerInternal __RPC_FAR * This,
            /* [out] */ IMailMsgProperties __RPC_FAR *__RPC_FAR *ppMsg);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *SubmitMessage )( 
            ISMTPServerInternal __RPC_FAR * This,
            /* [in] */ IMailMsgProperties __RPC_FAR *pMsg);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *TriggerLocalDelivery )( 
            ISMTPServerInternal __RPC_FAR * This,
            /* [in] */ IMailMsgProperties __RPC_FAR *pMsg,
            DWORD dwRecipientCount,
            DWORD __RPC_FAR *pdwRecipIndexes);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *ReadMetabaseString )( 
            ISMTPServerInternal __RPC_FAR * This,
            /* [in] */ DWORD MetabaseId,
            /* [length_is][size_is][out][in] */ unsigned char __RPC_FAR *Buffer,
            /* [out][in] */ DWORD __RPC_FAR *BufferSize,
            /* [in] */ BOOL fSecure);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *ReadMetabaseDword )( 
            ISMTPServerInternal __RPC_FAR * This,
            /* [in] */ DWORD MetabaseId,
            /* [out] */ DWORD __RPC_FAR *dwValue);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *ServerStartHintFunction )( 
            ISMTPServerInternal __RPC_FAR * This);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *ServerStopHintFunction )( 
            ISMTPServerInternal __RPC_FAR * This);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *TriggerServerEvent )( 
            ISMTPServerInternal __RPC_FAR * This,
            /* [in] */ DWORD dwEventID,
            /* [in] */ PVOID pvContext);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *WriteLog )( 
            ISMTPServerInternal __RPC_FAR * This,
            /* [in] */ LPMSG_TRACK_INFO pMsgTrackInfo,
            /* [in] */ IMailMsgProperties __RPC_FAR *pMsg,
            /* [in] */ LPEVENT_LOG_INFO pEventLogInfo,
            /* [in] */ LPSTR pszProtocolLog);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *ReadMetabaseData )( 
            ISMTPServerInternal __RPC_FAR * This,
            /* [in] */ DWORD MetabaseId,
            /* [length_is][size_is][out][in] */ BYTE __RPC_FAR *Buffer,
            /* [out][in] */ DWORD __RPC_FAR *BufferSize);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *AllocBoundMessage )( 
            ISMTPServerInternal __RPC_FAR * This,
            /* [out] */ IMailMsgProperties __RPC_FAR *__RPC_FAR *ppMsg,
            /* [out] */ PFIO_CONTEXT __RPC_FAR *phContent);
        
        END_INTERFACE
    } ISMTPServerInternalVtbl;

    interface ISMTPServerInternal
    {
        CONST_VTBL struct ISMTPServerInternalVtbl __RPC_FAR *lpVtbl;
    };

    

#ifdef COBJMACROS


#define ISMTPServerInternal_QueryInterface(This,riid,ppvObject)	\
    (This)->lpVtbl -> QueryInterface(This,riid,ppvObject)

#define ISMTPServerInternal_AddRef(This)	\
    (This)->lpVtbl -> AddRef(This)

#define ISMTPServerInternal_Release(This)	\
    (This)->lpVtbl -> Release(This)


#define ISMTPServerInternal_AllocMessage(This,ppMsg)	\
    (This)->lpVtbl -> AllocMessage(This,ppMsg)

#define ISMTPServerInternal_SubmitMessage(This,pMsg)	\
    (This)->lpVtbl -> SubmitMessage(This,pMsg)

#define ISMTPServerInternal_TriggerLocalDelivery(This,pMsg,dwRecipientCount,pdwRecipIndexes)	\
    (This)->lpVtbl -> TriggerLocalDelivery(This,pMsg,dwRecipientCount,pdwRecipIndexes)

#define ISMTPServerInternal_ReadMetabaseString(This,MetabaseId,Buffer,BufferSize,fSecure)	\
    (This)->lpVtbl -> ReadMetabaseString(This,MetabaseId,Buffer,BufferSize,fSecure)

#define ISMTPServerInternal_ReadMetabaseDword(This,MetabaseId,dwValue)	\
    (This)->lpVtbl -> ReadMetabaseDword(This,MetabaseId,dwValue)

#define ISMTPServerInternal_ServerStartHintFunction(This)	\
    (This)->lpVtbl -> ServerStartHintFunction(This)

#define ISMTPServerInternal_ServerStopHintFunction(This)	\
    (This)->lpVtbl -> ServerStopHintFunction(This)

#define ISMTPServerInternal_TriggerServerEvent(This,dwEventID,pvContext)	\
    (This)->lpVtbl -> TriggerServerEvent(This,dwEventID,pvContext)

#define ISMTPServerInternal_WriteLog(This,pMsgTrackInfo,pMsg,pEventLogInfo,pszProtocolLog)	\
    (This)->lpVtbl -> WriteLog(This,pMsgTrackInfo,pMsg,pEventLogInfo,pszProtocolLog)

#define ISMTPServerInternal_ReadMetabaseData(This,MetabaseId,Buffer,BufferSize)	\
    (This)->lpVtbl -> ReadMetabaseData(This,MetabaseId,Buffer,BufferSize)


#define ISMTPServerInternal_AllocBoundMessage(This,ppMsg,phContent)	\
    (This)->lpVtbl -> AllocBoundMessage(This,ppMsg,phContent)

#endif /* COBJMACROS */


#endif 	/* C style interface */



HRESULT STDMETHODCALLTYPE ISMTPServerInternal_AllocBoundMessage_Proxy( 
    ISMTPServerInternal __RPC_FAR * This,
    /* [out] */ IMailMsgProperties __RPC_FAR *__RPC_FAR *ppMsg,
    /* [out] */ PFIO_CONTEXT __RPC_FAR *phContent);


void __RPC_STUB ISMTPServerInternal_AllocBoundMessage_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);



#endif 	/* __ISMTPServerInternal_INTERFACE_DEFINED__ */



#ifndef __MailMsgLib_LIBRARY_DEFINED__
#define __MailMsgLib_LIBRARY_DEFINED__

/* library MailMsgLib */
/* [version][uuid][helpstring] */ 


EXTERN_C const IID LIBID_MailMsgLib;
#endif /* __MailMsgLib_LIBRARY_DEFINED__ */

/* Additional Prototypes for ALL interfaces */

/* end of Additional Prototypes */

#ifdef __cplusplus
}
#endif

#endif


