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

/* this ALWAYS GENERATED file contains the proxy stub code */


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

#if !defined(_M_IA64) && !defined(_M_AXP64)

/* verify that the <rpcproxy.h> version is high enough to compile this file*/
#ifndef __REDQ_RPCPROXY_H_VERSION__
#define __REQUIRED_RPCPROXY_H_VERSION__ 440
#endif


#include "rpcproxy.h"
#ifndef __RPCPROXY_H_VERSION__
#error this stub requires an updated version of <rpcproxy.h>
#endif // __RPCPROXY_H_VERSION__


#include "SmtpEvent.h"

#define TYPE_FORMAT_STRING_SIZE   251                               
#define PROC_FORMAT_STRING_SIZE   185                               
#define TRANSMIT_AS_TABLE_SIZE    0            
#define WIRE_MARSHAL_TABLE_SIZE   0            

typedef struct _MIDL_TYPE_FORMAT_STRING
    {
    short          Pad;
    unsigned char  Format[ TYPE_FORMAT_STRING_SIZE ];
    } MIDL_TYPE_FORMAT_STRING;

typedef struct _MIDL_PROC_FORMAT_STRING
    {
    short          Pad;
    unsigned char  Format[ PROC_FORMAT_STRING_SIZE ];
    } MIDL_PROC_FORMAT_STRING;


extern const MIDL_TYPE_FORMAT_STRING __MIDL_TypeFormatString;
extern const MIDL_PROC_FORMAT_STRING __MIDL_ProcFormatString;


/* Standard interface: __MIDL_itf_SmtpEvent_0000, ver. 0.0,
   GUID={0x00000000,0x0000,0x0000,{0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00}} */


/* Object interface: IUnknown, ver. 0.0,
   GUID={0x00000000,0x0000,0x0000,{0xC0,0x00,0x00,0x00,0x00,0x00,0x00,0x46}} */


/* Object interface: ISmtpInCommandContext, ver. 0.0,
   GUID={0x5F15C533,0xE90E,0x11D1,{0x88,0x52,0x00,0xC0,0x4F,0xA3,0x5B,0x86}} */


/* Object interface: ISmtpInCallbackContext, ver. 0.0,
   GUID={0x5e4fc9da,0x3e3b,0x11d3,{0x88,0xf1,0x00,0xc0,0x4f,0xa3,0x5b,0x86}} */


/* Object interface: ISmtpOutCommandContext, ver. 0.0,
   GUID={0xc849b5f2,0x0a80,0x11d2,{0xaa,0x67,0x00,0xc0,0x4f,0xa3,0x5b,0x82}} */


/* Object interface: ISmtpServerResponseContext, ver. 0.0,
   GUID={0xe38f9ad2,0x0a82,0x11d2,{0xaa,0x67,0x00,0xc0,0x4f,0xa3,0x5b,0x82}} */


/* Object interface: ISmtpInCommandSink, ver. 0.0,
   GUID={0xb2d42a0e,0x0d5f,0x11d2,{0xaa,0x68,0x00,0xc0,0x4f,0xa3,0x5b,0x82}} */


extern const MIDL_STUB_DESC Object_StubDesc;


#pragma code_seg(".orpc")

/* [helpstring] */ HRESULT STDMETHODCALLTYPE ISmtpInCommandSink_OnSmtpInCommand_Proxy( 
    ISmtpInCommandSink __RPC_FAR * This,
    /* [in] */ IUnknown __RPC_FAR *pServer,
    /* [in] */ IUnknown __RPC_FAR *pSession,
    /* [in] */ IMailMsgProperties __RPC_FAR *pMsg,
    /* [in] */ ISmtpInCommandContext __RPC_FAR *pContext)
{

    HRESULT _RetVal;
    
    RPC_MESSAGE _RpcMessage;
    
    MIDL_STUB_MESSAGE _StubMsg;
    
    RpcTryExcept
        {
        NdrProxyInitialize(
                      ( void __RPC_FAR *  )This,
                      ( PRPC_MESSAGE  )&_RpcMessage,
                      ( PMIDL_STUB_MESSAGE  )&_StubMsg,
                      ( PMIDL_STUB_DESC  )&Object_StubDesc,
                      3);
        
        
        
        RpcTryFinally
            {
            
            _StubMsg.BufferLength = 0U + 0U + 0U + 0U;
            NdrInterfacePointerBufferSize( (PMIDL_STUB_MESSAGE) &_StubMsg,
                                           (unsigned char __RPC_FAR *)pServer,
                                           (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[2] );
            
            NdrInterfacePointerBufferSize( (PMIDL_STUB_MESSAGE) &_StubMsg,
                                           (unsigned char __RPC_FAR *)pSession,
                                           (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[2] );
            
            NdrInterfacePointerBufferSize( (PMIDL_STUB_MESSAGE) &_StubMsg,
                                           (unsigned char __RPC_FAR *)pMsg,
                                           (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[20] );
            
            NdrInterfacePointerBufferSize( (PMIDL_STUB_MESSAGE) &_StubMsg,
                                           (unsigned char __RPC_FAR *)pContext,
                                           (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[38] );
            
            NdrProxyGetBuffer(This, &_StubMsg);
            NdrInterfacePointerMarshall( (PMIDL_STUB_MESSAGE)& _StubMsg,
                                         (unsigned char __RPC_FAR *)pServer,
                                         (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[2] );
            
            NdrInterfacePointerMarshall( (PMIDL_STUB_MESSAGE)& _StubMsg,
                                         (unsigned char __RPC_FAR *)pSession,
                                         (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[2] );
            
            NdrInterfacePointerMarshall( (PMIDL_STUB_MESSAGE)& _StubMsg,
                                         (unsigned char __RPC_FAR *)pMsg,
                                         (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[20] );
            
            NdrInterfacePointerMarshall( (PMIDL_STUB_MESSAGE)& _StubMsg,
                                         (unsigned char __RPC_FAR *)pContext,
                                         (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[38] );
            
            NdrProxySendReceive(This, &_StubMsg);
            
            if ( (_RpcMessage.DataRepresentation & 0X0000FFFFUL) != NDR_LOCAL_DATA_REPRESENTATION )
                NdrConvert( (PMIDL_STUB_MESSAGE) &_StubMsg, (PFORMAT_STRING) &__MIDL_ProcFormatString.Format[0] );
            
            _RetVal = *(( HRESULT __RPC_FAR * )_StubMsg.Buffer)++;
            
            }
        RpcFinally
            {
            NdrProxyFreeBuffer(This, &_StubMsg);
            
            }
        RpcEndFinally
        
        }
    RpcExcept(_StubMsg.dwStubPhase != PROXY_SENDRECEIVE)
        {
        _RetVal = NdrProxyErrorHandler(RpcExceptionCode());
        }
    RpcEndExcept
    return _RetVal;
}

void __RPC_STUB ISmtpInCommandSink_OnSmtpInCommand_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase)
{
    HRESULT _RetVal;
    MIDL_STUB_MESSAGE _StubMsg;
    ISmtpInCommandContext __RPC_FAR *pContext;
    IMailMsgProperties __RPC_FAR *pMsg;
    IUnknown __RPC_FAR *pServer;
    IUnknown __RPC_FAR *pSession;
    
NdrStubInitialize(
                     _pRpcMessage,
                     &_StubMsg,
                     &Object_StubDesc,
                     _pRpcChannelBuffer);
    pServer = 0;
    pSession = 0;
    pMsg = 0;
    pContext = 0;
    RpcTryFinally
        {
        if ( (_pRpcMessage->DataRepresentation & 0X0000FFFFUL) != NDR_LOCAL_DATA_REPRESENTATION )
            NdrConvert( (PMIDL_STUB_MESSAGE) &_StubMsg, (PFORMAT_STRING) &__MIDL_ProcFormatString.Format[0] );
        
        NdrInterfacePointerUnmarshall( (PMIDL_STUB_MESSAGE) &_StubMsg,
                                       (unsigned char __RPC_FAR * __RPC_FAR *)&pServer,
                                       (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[2],
                                       (unsigned char)0 );
        
        NdrInterfacePointerUnmarshall( (PMIDL_STUB_MESSAGE) &_StubMsg,
                                       (unsigned char __RPC_FAR * __RPC_FAR *)&pSession,
                                       (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[2],
                                       (unsigned char)0 );
        
        NdrInterfacePointerUnmarshall( (PMIDL_STUB_MESSAGE) &_StubMsg,
                                       (unsigned char __RPC_FAR * __RPC_FAR *)&pMsg,
                                       (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[20],
                                       (unsigned char)0 );
        
        NdrInterfacePointerUnmarshall( (PMIDL_STUB_MESSAGE) &_StubMsg,
                                       (unsigned char __RPC_FAR * __RPC_FAR *)&pContext,
                                       (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[38],
                                       (unsigned char)0 );
        
        
        *_pdwStubPhase = STUB_CALL_SERVER;
        _RetVal = (((ISmtpInCommandSink*) ((CStdStubBuffer *)This)->pvServerObject)->lpVtbl) -> OnSmtpInCommand(
                   (ISmtpInCommandSink *) ((CStdStubBuffer *)This)->pvServerObject,
                   pServer,
                   pSession,
                   pMsg,
                   pContext);
        
        *_pdwStubPhase = STUB_MARSHAL;
        
        _StubMsg.BufferLength = 4U;
        NdrStubGetBuffer(This, _pRpcChannelBuffer, &_StubMsg);
        *(( HRESULT __RPC_FAR * )_StubMsg.Buffer)++ = _RetVal;
        
        }
    RpcFinally
        {
        NdrInterfacePointerFree( &_StubMsg,
                                 (unsigned char __RPC_FAR *)pServer,
                                 &__MIDL_TypeFormatString.Format[2] );
        
        NdrInterfacePointerFree( &_StubMsg,
                                 (unsigned char __RPC_FAR *)pSession,
                                 &__MIDL_TypeFormatString.Format[2] );
        
        NdrInterfacePointerFree( &_StubMsg,
                                 (unsigned char __RPC_FAR *)pMsg,
                                 &__MIDL_TypeFormatString.Format[20] );
        
        NdrInterfacePointerFree( &_StubMsg,
                                 (unsigned char __RPC_FAR *)pContext,
                                 &__MIDL_TypeFormatString.Format[38] );
        
        }
    RpcEndFinally
    _pRpcMessage->BufferLength = 
        (unsigned int)(_StubMsg.Buffer - (unsigned char __RPC_FAR *)_pRpcMessage->Buffer);
    
}

const CINTERFACE_PROXY_VTABLE(4) _ISmtpInCommandSinkProxyVtbl = 
{
    &IID_ISmtpInCommandSink,
    IUnknown_QueryInterface_Proxy,
    IUnknown_AddRef_Proxy,
    IUnknown_Release_Proxy ,
    ISmtpInCommandSink_OnSmtpInCommand_Proxy
};


static const PRPC_STUB_FUNCTION ISmtpInCommandSink_table[] =
{
    ISmtpInCommandSink_OnSmtpInCommand_Stub
};

const CInterfaceStubVtbl _ISmtpInCommandSinkStubVtbl =
{
    &IID_ISmtpInCommandSink,
    0,
    4,
    &ISmtpInCommandSink_table[-3],
    CStdStubBuffer_METHODS
};


/* Object interface: ISmtpOutCommandSink, ver. 0.0,
   GUID={0xcfdbb9b0,0x0ca0,0x11d2,{0xaa,0x68,0x00,0xc0,0x4f,0xa3,0x5b,0x82}} */


extern const MIDL_STUB_DESC Object_StubDesc;


#pragma code_seg(".orpc")

/* [helpstring] */ HRESULT STDMETHODCALLTYPE ISmtpOutCommandSink_OnSmtpOutCommand_Proxy( 
    ISmtpOutCommandSink __RPC_FAR * This,
    /* [in] */ IUnknown __RPC_FAR *pServer,
    /* [in] */ IUnknown __RPC_FAR *pSession,
    /* [in] */ IMailMsgProperties __RPC_FAR *pMsg,
    /* [in] */ ISmtpOutCommandContext __RPC_FAR *pContext)
{

    HRESULT _RetVal;
    
    RPC_MESSAGE _RpcMessage;
    
    MIDL_STUB_MESSAGE _StubMsg;
    
    RpcTryExcept
        {
        NdrProxyInitialize(
                      ( void __RPC_FAR *  )This,
                      ( PRPC_MESSAGE  )&_RpcMessage,
                      ( PMIDL_STUB_MESSAGE  )&_StubMsg,
                      ( PMIDL_STUB_DESC  )&Object_StubDesc,
                      3);
        
        
        
        RpcTryFinally
            {
            
            _StubMsg.BufferLength = 0U + 0U + 0U + 0U;
            NdrInterfacePointerBufferSize( (PMIDL_STUB_MESSAGE) &_StubMsg,
                                           (unsigned char __RPC_FAR *)pServer,
                                           (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[56] );
            
            NdrInterfacePointerBufferSize( (PMIDL_STUB_MESSAGE) &_StubMsg,
                                           (unsigned char __RPC_FAR *)pSession,
                                           (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[56] );
            
            NdrInterfacePointerBufferSize( (PMIDL_STUB_MESSAGE) &_StubMsg,
                                           (unsigned char __RPC_FAR *)pMsg,
                                           (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[74] );
            
            NdrInterfacePointerBufferSize( (PMIDL_STUB_MESSAGE) &_StubMsg,
                                           (unsigned char __RPC_FAR *)pContext,
                                           (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[92] );
            
            NdrProxyGetBuffer(This, &_StubMsg);
            NdrInterfacePointerMarshall( (PMIDL_STUB_MESSAGE)& _StubMsg,
                                         (unsigned char __RPC_FAR *)pServer,
                                         (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[56] );
            
            NdrInterfacePointerMarshall( (PMIDL_STUB_MESSAGE)& _StubMsg,
                                         (unsigned char __RPC_FAR *)pSession,
                                         (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[56] );
            
            NdrInterfacePointerMarshall( (PMIDL_STUB_MESSAGE)& _StubMsg,
                                         (unsigned char __RPC_FAR *)pMsg,
                                         (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[74] );
            
            NdrInterfacePointerMarshall( (PMIDL_STUB_MESSAGE)& _StubMsg,
                                         (unsigned char __RPC_FAR *)pContext,
                                         (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[92] );
            
            NdrProxySendReceive(This, &_StubMsg);
            
            if ( (_RpcMessage.DataRepresentation & 0X0000FFFFUL) != NDR_LOCAL_DATA_REPRESENTATION )
                NdrConvert( (PMIDL_STUB_MESSAGE) &_StubMsg, (PFORMAT_STRING) &__MIDL_ProcFormatString.Format[18] );
            
            _RetVal = *(( HRESULT __RPC_FAR * )_StubMsg.Buffer)++;
            
            }
        RpcFinally
            {
            NdrProxyFreeBuffer(This, &_StubMsg);
            
            }
        RpcEndFinally
        
        }
    RpcExcept(_StubMsg.dwStubPhase != PROXY_SENDRECEIVE)
        {
        _RetVal = NdrProxyErrorHandler(RpcExceptionCode());
        }
    RpcEndExcept
    return _RetVal;
}

void __RPC_STUB ISmtpOutCommandSink_OnSmtpOutCommand_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase)
{
    HRESULT _RetVal;
    MIDL_STUB_MESSAGE _StubMsg;
    ISmtpOutCommandContext __RPC_FAR *pContext;
    IMailMsgProperties __RPC_FAR *pMsg;
    IUnknown __RPC_FAR *pServer;
    IUnknown __RPC_FAR *pSession;
    
NdrStubInitialize(
                     _pRpcMessage,
                     &_StubMsg,
                     &Object_StubDesc,
                     _pRpcChannelBuffer);
    pServer = 0;
    pSession = 0;
    pMsg = 0;
    pContext = 0;
    RpcTryFinally
        {
        if ( (_pRpcMessage->DataRepresentation & 0X0000FFFFUL) != NDR_LOCAL_DATA_REPRESENTATION )
            NdrConvert( (PMIDL_STUB_MESSAGE) &_StubMsg, (PFORMAT_STRING) &__MIDL_ProcFormatString.Format[18] );
        
        NdrInterfacePointerUnmarshall( (PMIDL_STUB_MESSAGE) &_StubMsg,
                                       (unsigned char __RPC_FAR * __RPC_FAR *)&pServer,
                                       (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[56],
                                       (unsigned char)0 );
        
        NdrInterfacePointerUnmarshall( (PMIDL_STUB_MESSAGE) &_StubMsg,
                                       (unsigned char __RPC_FAR * __RPC_FAR *)&pSession,
                                       (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[56],
                                       (unsigned char)0 );
        
        NdrInterfacePointerUnmarshall( (PMIDL_STUB_MESSAGE) &_StubMsg,
                                       (unsigned char __RPC_FAR * __RPC_FAR *)&pMsg,
                                       (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[74],
                                       (unsigned char)0 );
        
        NdrInterfacePointerUnmarshall( (PMIDL_STUB_MESSAGE) &_StubMsg,
                                       (unsigned char __RPC_FAR * __RPC_FAR *)&pContext,
                                       (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[92],
                                       (unsigned char)0 );
        
        
        *_pdwStubPhase = STUB_CALL_SERVER;
        _RetVal = (((ISmtpOutCommandSink*) ((CStdStubBuffer *)This)->pvServerObject)->lpVtbl) -> OnSmtpOutCommand(
                    (ISmtpOutCommandSink *) ((CStdStubBuffer *)This)->pvServerObject,
                    pServer,
                    pSession,
                    pMsg,
                    pContext);
        
        *_pdwStubPhase = STUB_MARSHAL;
        
        _StubMsg.BufferLength = 4U;
        NdrStubGetBuffer(This, _pRpcChannelBuffer, &_StubMsg);
        *(( HRESULT __RPC_FAR * )_StubMsg.Buffer)++ = _RetVal;
        
        }
    RpcFinally
        {
        NdrInterfacePointerFree( &_StubMsg,
                                 (unsigned char __RPC_FAR *)pServer,
                                 &__MIDL_TypeFormatString.Format[56] );
        
        NdrInterfacePointerFree( &_StubMsg,
                                 (unsigned char __RPC_FAR *)pSession,
                                 &__MIDL_TypeFormatString.Format[56] );
        
        NdrInterfacePointerFree( &_StubMsg,
                                 (unsigned char __RPC_FAR *)pMsg,
                                 &__MIDL_TypeFormatString.Format[74] );
        
        NdrInterfacePointerFree( &_StubMsg,
                                 (unsigned char __RPC_FAR *)pContext,
                                 &__MIDL_TypeFormatString.Format[92] );
        
        }
    RpcEndFinally
    _pRpcMessage->BufferLength = 
        (unsigned int)(_StubMsg.Buffer - (unsigned char __RPC_FAR *)_pRpcMessage->Buffer);
    
}

const CINTERFACE_PROXY_VTABLE(4) _ISmtpOutCommandSinkProxyVtbl = 
{
    &IID_ISmtpOutCommandSink,
    IUnknown_QueryInterface_Proxy,
    IUnknown_AddRef_Proxy,
    IUnknown_Release_Proxy ,
    ISmtpOutCommandSink_OnSmtpOutCommand_Proxy
};


static const PRPC_STUB_FUNCTION ISmtpOutCommandSink_table[] =
{
    ISmtpOutCommandSink_OnSmtpOutCommand_Stub
};

const CInterfaceStubVtbl _ISmtpOutCommandSinkStubVtbl =
{
    &IID_ISmtpOutCommandSink,
    0,
    4,
    &ISmtpOutCommandSink_table[-3],
    CStdStubBuffer_METHODS
};


/* Object interface: ISmtpServerResponseSink, ver. 0.0,
   GUID={0xd7e10222,0x0ca1,0x11d2,{0xaa,0x68,0x00,0xc0,0x4f,0xa3,0x5b,0x82}} */


extern const MIDL_STUB_DESC Object_StubDesc;


#pragma code_seg(".orpc")

/* [helpstring] */ HRESULT STDMETHODCALLTYPE ISmtpServerResponseSink_OnSmtpServerResponse_Proxy( 
    ISmtpServerResponseSink __RPC_FAR * This,
    /* [in] */ IUnknown __RPC_FAR *pServer,
    /* [in] */ IUnknown __RPC_FAR *pSession,
    /* [in] */ IMailMsgProperties __RPC_FAR *pMsg,
    /* [in] */ ISmtpServerResponseContext __RPC_FAR *pContext)
{

    HRESULT _RetVal;
    
    RPC_MESSAGE _RpcMessage;
    
    MIDL_STUB_MESSAGE _StubMsg;
    
    RpcTryExcept
        {
        NdrProxyInitialize(
                      ( void __RPC_FAR *  )This,
                      ( PRPC_MESSAGE  )&_RpcMessage,
                      ( PMIDL_STUB_MESSAGE  )&_StubMsg,
                      ( PMIDL_STUB_DESC  )&Object_StubDesc,
                      3);
        
        
        
        RpcTryFinally
            {
            
            _StubMsg.BufferLength = 0U + 0U + 0U + 0U;
            NdrInterfacePointerBufferSize( (PMIDL_STUB_MESSAGE) &_StubMsg,
                                           (unsigned char __RPC_FAR *)pServer,
                                           (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[56] );
            
            NdrInterfacePointerBufferSize( (PMIDL_STUB_MESSAGE) &_StubMsg,
                                           (unsigned char __RPC_FAR *)pSession,
                                           (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[56] );
            
            NdrInterfacePointerBufferSize( (PMIDL_STUB_MESSAGE) &_StubMsg,
                                           (unsigned char __RPC_FAR *)pMsg,
                                           (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[74] );
            
            NdrInterfacePointerBufferSize( (PMIDL_STUB_MESSAGE) &_StubMsg,
                                           (unsigned char __RPC_FAR *)pContext,
                                           (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[110] );
            
            NdrProxyGetBuffer(This, &_StubMsg);
            NdrInterfacePointerMarshall( (PMIDL_STUB_MESSAGE)& _StubMsg,
                                         (unsigned char __RPC_FAR *)pServer,
                                         (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[56] );
            
            NdrInterfacePointerMarshall( (PMIDL_STUB_MESSAGE)& _StubMsg,
                                         (unsigned char __RPC_FAR *)pSession,
                                         (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[56] );
            
            NdrInterfacePointerMarshall( (PMIDL_STUB_MESSAGE)& _StubMsg,
                                         (unsigned char __RPC_FAR *)pMsg,
                                         (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[74] );
            
            NdrInterfacePointerMarshall( (PMIDL_STUB_MESSAGE)& _StubMsg,
                                         (unsigned char __RPC_FAR *)pContext,
                                         (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[110] );
            
            NdrProxySendReceive(This, &_StubMsg);
            
            if ( (_RpcMessage.DataRepresentation & 0X0000FFFFUL) != NDR_LOCAL_DATA_REPRESENTATION )
                NdrConvert( (PMIDL_STUB_MESSAGE) &_StubMsg, (PFORMAT_STRING) &__MIDL_ProcFormatString.Format[36] );
            
            _RetVal = *(( HRESULT __RPC_FAR * )_StubMsg.Buffer)++;
            
            }
        RpcFinally
            {
            NdrProxyFreeBuffer(This, &_StubMsg);
            
            }
        RpcEndFinally
        
        }
    RpcExcept(_StubMsg.dwStubPhase != PROXY_SENDRECEIVE)
        {
        _RetVal = NdrProxyErrorHandler(RpcExceptionCode());
        }
    RpcEndExcept
    return _RetVal;
}

void __RPC_STUB ISmtpServerResponseSink_OnSmtpServerResponse_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase)
{
    HRESULT _RetVal;
    MIDL_STUB_MESSAGE _StubMsg;
    ISmtpServerResponseContext __RPC_FAR *pContext;
    IMailMsgProperties __RPC_FAR *pMsg;
    IUnknown __RPC_FAR *pServer;
    IUnknown __RPC_FAR *pSession;
    
NdrStubInitialize(
                     _pRpcMessage,
                     &_StubMsg,
                     &Object_StubDesc,
                     _pRpcChannelBuffer);
    pServer = 0;
    pSession = 0;
    pMsg = 0;
    pContext = 0;
    RpcTryFinally
        {
        if ( (_pRpcMessage->DataRepresentation & 0X0000FFFFUL) != NDR_LOCAL_DATA_REPRESENTATION )
            NdrConvert( (PMIDL_STUB_MESSAGE) &_StubMsg, (PFORMAT_STRING) &__MIDL_ProcFormatString.Format[36] );
        
        NdrInterfacePointerUnmarshall( (PMIDL_STUB_MESSAGE) &_StubMsg,
                                       (unsigned char __RPC_FAR * __RPC_FAR *)&pServer,
                                       (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[56],
                                       (unsigned char)0 );
        
        NdrInterfacePointerUnmarshall( (PMIDL_STUB_MESSAGE) &_StubMsg,
                                       (unsigned char __RPC_FAR * __RPC_FAR *)&pSession,
                                       (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[56],
                                       (unsigned char)0 );
        
        NdrInterfacePointerUnmarshall( (PMIDL_STUB_MESSAGE) &_StubMsg,
                                       (unsigned char __RPC_FAR * __RPC_FAR *)&pMsg,
                                       (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[74],
                                       (unsigned char)0 );
        
        NdrInterfacePointerUnmarshall( (PMIDL_STUB_MESSAGE) &_StubMsg,
                                       (unsigned char __RPC_FAR * __RPC_FAR *)&pContext,
                                       (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[110],
                                       (unsigned char)0 );
        
        
        *_pdwStubPhase = STUB_CALL_SERVER;
        _RetVal = (((ISmtpServerResponseSink*) ((CStdStubBuffer *)This)->pvServerObject)->lpVtbl) -> OnSmtpServerResponse(
                        (ISmtpServerResponseSink *) ((CStdStubBuffer *)This)->pvServerObject,
                        pServer,
                        pSession,
                        pMsg,
                        pContext);
        
        *_pdwStubPhase = STUB_MARSHAL;
        
        _StubMsg.BufferLength = 4U;
        NdrStubGetBuffer(This, _pRpcChannelBuffer, &_StubMsg);
        *(( HRESULT __RPC_FAR * )_StubMsg.Buffer)++ = _RetVal;
        
        }
    RpcFinally
        {
        NdrInterfacePointerFree( &_StubMsg,
                                 (unsigned char __RPC_FAR *)pServer,
                                 &__MIDL_TypeFormatString.Format[56] );
        
        NdrInterfacePointerFree( &_StubMsg,
                                 (unsigned char __RPC_FAR *)pSession,
                                 &__MIDL_TypeFormatString.Format[56] );
        
        NdrInterfacePointerFree( &_StubMsg,
                                 (unsigned char __RPC_FAR *)pMsg,
                                 &__MIDL_TypeFormatString.Format[74] );
        
        NdrInterfacePointerFree( &_StubMsg,
                                 (unsigned char __RPC_FAR *)pContext,
                                 &__MIDL_TypeFormatString.Format[110] );
        
        }
    RpcEndFinally
    _pRpcMessage->BufferLength = 
        (unsigned int)(_StubMsg.Buffer - (unsigned char __RPC_FAR *)_pRpcMessage->Buffer);
    
}

const CINTERFACE_PROXY_VTABLE(4) _ISmtpServerResponseSinkProxyVtbl = 
{
    &IID_ISmtpServerResponseSink,
    IUnknown_QueryInterface_Proxy,
    IUnknown_AddRef_Proxy,
    IUnknown_Release_Proxy ,
    ISmtpServerResponseSink_OnSmtpServerResponse_Proxy
};


static const PRPC_STUB_FUNCTION ISmtpServerResponseSink_table[] =
{
    ISmtpServerResponseSink_OnSmtpServerResponse_Stub
};

const CInterfaceStubVtbl _ISmtpServerResponseSinkStubVtbl =
{
    &IID_ISmtpServerResponseSink,
    0,
    4,
    &ISmtpServerResponseSink_table[-3],
    CStdStubBuffer_METHODS
};


/* Object interface: ISmtpInCallbackSink, ver. 0.0,
   GUID={0x0012b624,0x3e3c,0x11d3,{0x88,0xf1,0x00,0xc0,0x4f,0xa3,0x5b,0x86}} */


extern const MIDL_STUB_DESC Object_StubDesc;


#pragma code_seg(".orpc")

/* [helpstring] */ HRESULT STDMETHODCALLTYPE ISmtpInCallbackSink_OnSmtpInCallback_Proxy( 
    ISmtpInCallbackSink __RPC_FAR * This,
    /* [in] */ IUnknown __RPC_FAR *pServer,
    /* [in] */ IUnknown __RPC_FAR *pSession,
    /* [in] */ IMailMsgProperties __RPC_FAR *pMsg,
    /* [in] */ ISmtpInCallbackContext __RPC_FAR *pContext)
{

    HRESULT _RetVal;
    
    RPC_MESSAGE _RpcMessage;
    
    MIDL_STUB_MESSAGE _StubMsg;
    
    RpcTryExcept
        {
        NdrProxyInitialize(
                      ( void __RPC_FAR *  )This,
                      ( PRPC_MESSAGE  )&_RpcMessage,
                      ( PMIDL_STUB_MESSAGE  )&_StubMsg,
                      ( PMIDL_STUB_DESC  )&Object_StubDesc,
                      3);
        
        
        
        RpcTryFinally
            {
            
            _StubMsg.BufferLength = 0U + 0U + 0U + 0U;
            NdrInterfacePointerBufferSize( (PMIDL_STUB_MESSAGE) &_StubMsg,
                                           (unsigned char __RPC_FAR *)pServer,
                                           (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[56] );
            
            NdrInterfacePointerBufferSize( (PMIDL_STUB_MESSAGE) &_StubMsg,
                                           (unsigned char __RPC_FAR *)pSession,
                                           (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[56] );
            
            NdrInterfacePointerBufferSize( (PMIDL_STUB_MESSAGE) &_StubMsg,
                                           (unsigned char __RPC_FAR *)pMsg,
                                           (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[74] );
            
            NdrInterfacePointerBufferSize( (PMIDL_STUB_MESSAGE) &_StubMsg,
                                           (unsigned char __RPC_FAR *)pContext,
                                           (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[128] );
            
            NdrProxyGetBuffer(This, &_StubMsg);
            NdrInterfacePointerMarshall( (PMIDL_STUB_MESSAGE)& _StubMsg,
                                         (unsigned char __RPC_FAR *)pServer,
                                         (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[56] );
            
            NdrInterfacePointerMarshall( (PMIDL_STUB_MESSAGE)& _StubMsg,
                                         (unsigned char __RPC_FAR *)pSession,
                                         (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[56] );
            
            NdrInterfacePointerMarshall( (PMIDL_STUB_MESSAGE)& _StubMsg,
                                         (unsigned char __RPC_FAR *)pMsg,
                                         (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[74] );
            
            NdrInterfacePointerMarshall( (PMIDL_STUB_MESSAGE)& _StubMsg,
                                         (unsigned char __RPC_FAR *)pContext,
                                         (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[128] );
            
            NdrProxySendReceive(This, &_StubMsg);
            
            if ( (_RpcMessage.DataRepresentation & 0X0000FFFFUL) != NDR_LOCAL_DATA_REPRESENTATION )
                NdrConvert( (PMIDL_STUB_MESSAGE) &_StubMsg, (PFORMAT_STRING) &__MIDL_ProcFormatString.Format[54] );
            
            _RetVal = *(( HRESULT __RPC_FAR * )_StubMsg.Buffer)++;
            
            }
        RpcFinally
            {
            NdrProxyFreeBuffer(This, &_StubMsg);
            
            }
        RpcEndFinally
        
        }
    RpcExcept(_StubMsg.dwStubPhase != PROXY_SENDRECEIVE)
        {
        _RetVal = NdrProxyErrorHandler(RpcExceptionCode());
        }
    RpcEndExcept
    return _RetVal;
}

void __RPC_STUB ISmtpInCallbackSink_OnSmtpInCallback_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase)
{
    HRESULT _RetVal;
    MIDL_STUB_MESSAGE _StubMsg;
    ISmtpInCallbackContext __RPC_FAR *pContext;
    IMailMsgProperties __RPC_FAR *pMsg;
    IUnknown __RPC_FAR *pServer;
    IUnknown __RPC_FAR *pSession;
    
NdrStubInitialize(
                     _pRpcMessage,
                     &_StubMsg,
                     &Object_StubDesc,
                     _pRpcChannelBuffer);
    pServer = 0;
    pSession = 0;
    pMsg = 0;
    pContext = 0;
    RpcTryFinally
        {
        if ( (_pRpcMessage->DataRepresentation & 0X0000FFFFUL) != NDR_LOCAL_DATA_REPRESENTATION )
            NdrConvert( (PMIDL_STUB_MESSAGE) &_StubMsg, (PFORMAT_STRING) &__MIDL_ProcFormatString.Format[54] );
        
        NdrInterfacePointerUnmarshall( (PMIDL_STUB_MESSAGE) &_StubMsg,
                                       (unsigned char __RPC_FAR * __RPC_FAR *)&pServer,
                                       (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[56],
                                       (unsigned char)0 );
        
        NdrInterfacePointerUnmarshall( (PMIDL_STUB_MESSAGE) &_StubMsg,
                                       (unsigned char __RPC_FAR * __RPC_FAR *)&pSession,
                                       (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[56],
                                       (unsigned char)0 );
        
        NdrInterfacePointerUnmarshall( (PMIDL_STUB_MESSAGE) &_StubMsg,
                                       (unsigned char __RPC_FAR * __RPC_FAR *)&pMsg,
                                       (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[74],
                                       (unsigned char)0 );
        
        NdrInterfacePointerUnmarshall( (PMIDL_STUB_MESSAGE) &_StubMsg,
                                       (unsigned char __RPC_FAR * __RPC_FAR *)&pContext,
                                       (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[128],
                                       (unsigned char)0 );
        
        
        *_pdwStubPhase = STUB_CALL_SERVER;
        _RetVal = (((ISmtpInCallbackSink*) ((CStdStubBuffer *)This)->pvServerObject)->lpVtbl) -> OnSmtpInCallback(
                    (ISmtpInCallbackSink *) ((CStdStubBuffer *)This)->pvServerObject,
                    pServer,
                    pSession,
                    pMsg,
                    pContext);
        
        *_pdwStubPhase = STUB_MARSHAL;
        
        _StubMsg.BufferLength = 4U;
        NdrStubGetBuffer(This, _pRpcChannelBuffer, &_StubMsg);
        *(( HRESULT __RPC_FAR * )_StubMsg.Buffer)++ = _RetVal;
        
        }
    RpcFinally
        {
        NdrInterfacePointerFree( &_StubMsg,
                                 (unsigned char __RPC_FAR *)pServer,
                                 &__MIDL_TypeFormatString.Format[56] );
        
        NdrInterfacePointerFree( &_StubMsg,
                                 (unsigned char __RPC_FAR *)pSession,
                                 &__MIDL_TypeFormatString.Format[56] );
        
        NdrInterfacePointerFree( &_StubMsg,
                                 (unsigned char __RPC_FAR *)pMsg,
                                 &__MIDL_TypeFormatString.Format[74] );
        
        NdrInterfacePointerFree( &_StubMsg,
                                 (unsigned char __RPC_FAR *)pContext,
                                 &__MIDL_TypeFormatString.Format[128] );
        
        }
    RpcEndFinally
    _pRpcMessage->BufferLength = 
        (unsigned int)(_StubMsg.Buffer - (unsigned char __RPC_FAR *)_pRpcMessage->Buffer);
    
}

const CINTERFACE_PROXY_VTABLE(4) _ISmtpInCallbackSinkProxyVtbl = 
{
    &IID_ISmtpInCallbackSink,
    IUnknown_QueryInterface_Proxy,
    IUnknown_AddRef_Proxy,
    IUnknown_Release_Proxy ,
    ISmtpInCallbackSink_OnSmtpInCallback_Proxy
};


static const PRPC_STUB_FUNCTION ISmtpInCallbackSink_table[] =
{
    ISmtpInCallbackSink_OnSmtpInCallback_Stub
};

const CInterfaceStubVtbl _ISmtpInCallbackSinkStubVtbl =
{
    &IID_ISmtpInCallbackSink,
    0,
    4,
    &ISmtpInCallbackSink_table[-3],
    CStdStubBuffer_METHODS
};


/* Standard interface: __MIDL_itf_SmtpEvent_0274, ver. 0.0,
   GUID={0x00000000,0x0000,0x0000,{0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00}} */


/* Object interface: IMailTransportNotify, ver. 0.0,
   GUID={0x6E1CAA77,0xFCD4,0x11d1,{0x9D,0xF9,0x00,0xC0,0x4F,0xA3,0x22,0xBA}} */


extern const MIDL_STUB_DESC Object_StubDesc;


#pragma code_seg(".orpc")
const CINTERFACE_PROXY_VTABLE(4) _IMailTransportNotifyProxyVtbl = 
{
    &IID_IMailTransportNotify,
    IUnknown_QueryInterface_Proxy,
    IUnknown_AddRef_Proxy,
    IUnknown_Release_Proxy ,
    0 /* IMailTransportNotify_Notify_Proxy */
};


static const PRPC_STUB_FUNCTION IMailTransportNotify_table[] =
{
    STUB_FORWARDING_FUNCTION
};

const CInterfaceStubVtbl _IMailTransportNotifyStubVtbl =
{
    &IID_IMailTransportNotify,
    0,
    4,
    &IMailTransportNotify_table[-3],
    CStdStubBuffer_METHODS
};


/* Object interface: IMailTransportSubmission, ver. 0.0,
   GUID={0xCE681916,0xFF14,0x11d1,{0x9D,0xFB,0x00,0xC0,0x4F,0xA3,0x22,0xBA}} */


extern const MIDL_STUB_DESC Object_StubDesc;


#pragma code_seg(".orpc")
const CINTERFACE_PROXY_VTABLE(4) _IMailTransportSubmissionProxyVtbl = 
{
    &IID_IMailTransportSubmission,
    IUnknown_QueryInterface_Proxy,
    IUnknown_AddRef_Proxy,
    IUnknown_Release_Proxy ,
    0 /* IMailTransportSubmission_OnMessageSubmission_Proxy */
};


static const PRPC_STUB_FUNCTION IMailTransportSubmission_table[] =
{
    STUB_FORWARDING_FUNCTION
};

const CInterfaceStubVtbl _IMailTransportSubmissionStubVtbl =
{
    &IID_IMailTransportSubmission,
    0,
    4,
    &IMailTransportSubmission_table[-3],
    CStdStubBuffer_METHODS
};


/* Object interface: IMailTransportOnPreCategorize, ver. 0.0,
   GUID={0xA3ACFB0E,0x83FF,0x11d2,{0x9E,0x14,0x00,0xC0,0x4F,0xA3,0x22,0xBA}} */


extern const MIDL_STUB_DESC Object_StubDesc;


#pragma code_seg(".orpc")
const CINTERFACE_PROXY_VTABLE(4) _IMailTransportOnPreCategorizeProxyVtbl = 
{
    &IID_IMailTransportOnPreCategorize,
    IUnknown_QueryInterface_Proxy,
    IUnknown_AddRef_Proxy,
    IUnknown_Release_Proxy ,
    0 /* IMailTransportOnPreCategorize_OnSyncMessagePreCategorize_Proxy */
};


static const PRPC_STUB_FUNCTION IMailTransportOnPreCategorize_table[] =
{
    STUB_FORWARDING_FUNCTION
};

const CInterfaceStubVtbl _IMailTransportOnPreCategorizeStubVtbl =
{
    &IID_IMailTransportOnPreCategorize,
    0,
    4,
    &IMailTransportOnPreCategorize_table[-3],
    CStdStubBuffer_METHODS
};


/* Object interface: IMailTransportOnPostCategorize, ver. 0.0,
   GUID={0x76719653,0x05A6,0x11d2,{0x9D,0xFD,0x00,0xC0,0x4F,0xA3,0x22,0xBA}} */


extern const MIDL_STUB_DESC Object_StubDesc;


#pragma code_seg(".orpc")
const CINTERFACE_PROXY_VTABLE(4) _IMailTransportOnPostCategorizeProxyVtbl = 
{
    &IID_IMailTransportOnPostCategorize,
    IUnknown_QueryInterface_Proxy,
    IUnknown_AddRef_Proxy,
    IUnknown_Release_Proxy ,
    0 /* IMailTransportOnPostCategorize_OnMessagePostCategorize_Proxy */
};


static const PRPC_STUB_FUNCTION IMailTransportOnPostCategorize_table[] =
{
    STUB_FORWARDING_FUNCTION
};

const CInterfaceStubVtbl _IMailTransportOnPostCategorizeStubVtbl =
{
    &IID_IMailTransportOnPostCategorize,
    0,
    4,
    &IMailTransportOnPostCategorize_table[-3],
    CStdStubBuffer_METHODS
};


/* Standard interface: __MIDL_itf_SmtpEvent_0278, ver. 0.0,
   GUID={0x00000000,0x0000,0x0000,{0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00}} */


/* Object interface: IMailTransportRouterReset, ver. 0.0,
   GUID={0xA928AD12,0x1610,0x11d2,{0x9E,0x02,0x00,0xC0,0x4F,0xA3,0x22,0xBA}} */


extern const MIDL_STUB_DESC Object_StubDesc;


#pragma code_seg(".orpc")

HRESULT STDMETHODCALLTYPE IMailTransportRouterReset_ResetRoutes_Proxy( 
    IMailTransportRouterReset __RPC_FAR * This,
    /* [in] */ DWORD dwResetType)
{

    HRESULT _RetVal;
    
    RPC_MESSAGE _RpcMessage;
    
    MIDL_STUB_MESSAGE _StubMsg;
    
    RpcTryExcept
        {
        NdrProxyInitialize(
                      ( void __RPC_FAR *  )This,
                      ( PRPC_MESSAGE  )&_RpcMessage,
                      ( PMIDL_STUB_MESSAGE  )&_StubMsg,
                      ( PMIDL_STUB_DESC  )&Object_StubDesc,
                      3);
        
        
        
        RpcTryFinally
            {
            
            _StubMsg.BufferLength = 4U;
            NdrProxyGetBuffer(This, &_StubMsg);
            *(( DWORD __RPC_FAR * )_StubMsg.Buffer)++ = dwResetType;
            
            NdrProxySendReceive(This, &_StubMsg);
            
            if ( (_RpcMessage.DataRepresentation & 0X0000FFFFUL) != NDR_LOCAL_DATA_REPRESENTATION )
                NdrConvert( (PMIDL_STUB_MESSAGE) &_StubMsg, (PFORMAT_STRING) &__MIDL_ProcFormatString.Format[72] );
            
            _RetVal = *(( HRESULT __RPC_FAR * )_StubMsg.Buffer)++;
            
            }
        RpcFinally
            {
            NdrProxyFreeBuffer(This, &_StubMsg);
            
            }
        RpcEndFinally
        
        }
    RpcExcept(_StubMsg.dwStubPhase != PROXY_SENDRECEIVE)
        {
        _RetVal = NdrProxyErrorHandler(RpcExceptionCode());
        }
    RpcEndExcept
    return _RetVal;
}

void __RPC_STUB IMailTransportRouterReset_ResetRoutes_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase)
{
    HRESULT _RetVal;
    MIDL_STUB_MESSAGE _StubMsg;
    DWORD dwResetType;
    
NdrStubInitialize(
                     _pRpcMessage,
                     &_StubMsg,
                     &Object_StubDesc,
                     _pRpcChannelBuffer);
    RpcTryFinally
        {
        if ( (_pRpcMessage->DataRepresentation & 0X0000FFFFUL) != NDR_LOCAL_DATA_REPRESENTATION )
            NdrConvert( (PMIDL_STUB_MESSAGE) &_StubMsg, (PFORMAT_STRING) &__MIDL_ProcFormatString.Format[72] );
        
        dwResetType = *(( DWORD __RPC_FAR * )_StubMsg.Buffer)++;
        
        
        *_pdwStubPhase = STUB_CALL_SERVER;
        _RetVal = (((IMailTransportRouterReset*) ((CStdStubBuffer *)This)->pvServerObject)->lpVtbl) -> ResetRoutes((IMailTransportRouterReset *) ((CStdStubBuffer *)This)->pvServerObject,dwResetType);
        
        *_pdwStubPhase = STUB_MARSHAL;
        
        _StubMsg.BufferLength = 4U;
        NdrStubGetBuffer(This, _pRpcChannelBuffer, &_StubMsg);
        *(( HRESULT __RPC_FAR * )_StubMsg.Buffer)++ = _RetVal;
        
        }
    RpcFinally
        {
        }
    RpcEndFinally
    _pRpcMessage->BufferLength = 
        (unsigned int)(_StubMsg.Buffer - (unsigned char __RPC_FAR *)_pRpcMessage->Buffer);
    
}

const CINTERFACE_PROXY_VTABLE(4) _IMailTransportRouterResetProxyVtbl = 
{
    &IID_IMailTransportRouterReset,
    IUnknown_QueryInterface_Proxy,
    IUnknown_AddRef_Proxy,
    IUnknown_Release_Proxy ,
    IMailTransportRouterReset_ResetRoutes_Proxy
};


static const PRPC_STUB_FUNCTION IMailTransportRouterReset_table[] =
{
    IMailTransportRouterReset_ResetRoutes_Stub
};

const CInterfaceStubVtbl _IMailTransportRouterResetStubVtbl =
{
    &IID_IMailTransportRouterReset,
    0,
    4,
    &IMailTransportRouterReset_table[-3],
    CStdStubBuffer_METHODS
};


/* Object interface: IMailTransportSetRouterReset, ver. 0.0,
   GUID={0xA928AD11,0x1610,0x11d2,{0x9E,0x02,0x00,0xC0,0x4F,0xA3,0x22,0xBA}} */


extern const MIDL_STUB_DESC Object_StubDesc;


#pragma code_seg(".orpc")

HRESULT STDMETHODCALLTYPE IMailTransportSetRouterReset_RegisterResetInterface_Proxy( 
    IMailTransportSetRouterReset __RPC_FAR * This,
    /* [in] */ DWORD dwVirtualServerID,
    /* [in] */ IMailTransportRouterReset __RPC_FAR *pIRouterReset)
{

    HRESULT _RetVal;
    
    RPC_MESSAGE _RpcMessage;
    
    MIDL_STUB_MESSAGE _StubMsg;
    
    RpcTryExcept
        {
        NdrProxyInitialize(
                      ( void __RPC_FAR *  )This,
                      ( PRPC_MESSAGE  )&_RpcMessage,
                      ( PMIDL_STUB_MESSAGE  )&_StubMsg,
                      ( PMIDL_STUB_DESC  )&Object_StubDesc,
                      3);
        
        
        
        RpcTryFinally
            {
            
            _StubMsg.BufferLength = 4U + 0U;
            NdrInterfacePointerBufferSize( (PMIDL_STUB_MESSAGE) &_StubMsg,
                                           (unsigned char __RPC_FAR *)pIRouterReset,
                                           (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[146] );
            
            NdrProxyGetBuffer(This, &_StubMsg);
            *(( DWORD __RPC_FAR * )_StubMsg.Buffer)++ = dwVirtualServerID;
            
            NdrInterfacePointerMarshall( (PMIDL_STUB_MESSAGE)& _StubMsg,
                                         (unsigned char __RPC_FAR *)pIRouterReset,
                                         (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[146] );
            
            NdrProxySendReceive(This, &_StubMsg);
            
            if ( (_RpcMessage.DataRepresentation & 0X0000FFFFUL) != NDR_LOCAL_DATA_REPRESENTATION )
                NdrConvert( (PMIDL_STUB_MESSAGE) &_StubMsg, (PFORMAT_STRING) &__MIDL_ProcFormatString.Format[76] );
            
            _RetVal = *(( HRESULT __RPC_FAR * )_StubMsg.Buffer)++;
            
            }
        RpcFinally
            {
            NdrProxyFreeBuffer(This, &_StubMsg);
            
            }
        RpcEndFinally
        
        }
    RpcExcept(_StubMsg.dwStubPhase != PROXY_SENDRECEIVE)
        {
        _RetVal = NdrProxyErrorHandler(RpcExceptionCode());
        }
    RpcEndExcept
    return _RetVal;
}

void __RPC_STUB IMailTransportSetRouterReset_RegisterResetInterface_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase)
{
    HRESULT _RetVal;
    MIDL_STUB_MESSAGE _StubMsg;
    DWORD dwVirtualServerID;
    IMailTransportRouterReset __RPC_FAR *pIRouterReset;
    
NdrStubInitialize(
                     _pRpcMessage,
                     &_StubMsg,
                     &Object_StubDesc,
                     _pRpcChannelBuffer);
    pIRouterReset = 0;
    RpcTryFinally
        {
        if ( (_pRpcMessage->DataRepresentation & 0X0000FFFFUL) != NDR_LOCAL_DATA_REPRESENTATION )
            NdrConvert( (PMIDL_STUB_MESSAGE) &_StubMsg, (PFORMAT_STRING) &__MIDL_ProcFormatString.Format[76] );
        
        dwVirtualServerID = *(( DWORD __RPC_FAR * )_StubMsg.Buffer)++;
        
        NdrInterfacePointerUnmarshall( (PMIDL_STUB_MESSAGE) &_StubMsg,
                                       (unsigned char __RPC_FAR * __RPC_FAR *)&pIRouterReset,
                                       (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[146],
                                       (unsigned char)0 );
        
        
        *_pdwStubPhase = STUB_CALL_SERVER;
        _RetVal = (((IMailTransportSetRouterReset*) ((CStdStubBuffer *)This)->pvServerObject)->lpVtbl) -> RegisterResetInterface(
                          (IMailTransportSetRouterReset *) ((CStdStubBuffer *)This)->pvServerObject,
                          dwVirtualServerID,
                          pIRouterReset);
        
        *_pdwStubPhase = STUB_MARSHAL;
        
        _StubMsg.BufferLength = 4U;
        NdrStubGetBuffer(This, _pRpcChannelBuffer, &_StubMsg);
        *(( HRESULT __RPC_FAR * )_StubMsg.Buffer)++ = _RetVal;
        
        }
    RpcFinally
        {
        NdrInterfacePointerFree( &_StubMsg,
                                 (unsigned char __RPC_FAR *)pIRouterReset,
                                 &__MIDL_TypeFormatString.Format[146] );
        
        }
    RpcEndFinally
    _pRpcMessage->BufferLength = 
        (unsigned int)(_StubMsg.Buffer - (unsigned char __RPC_FAR *)_pRpcMessage->Buffer);
    
}

const CINTERFACE_PROXY_VTABLE(4) _IMailTransportSetRouterResetProxyVtbl = 
{
    &IID_IMailTransportSetRouterReset,
    IUnknown_QueryInterface_Proxy,
    IUnknown_AddRef_Proxy,
    IUnknown_Release_Proxy ,
    IMailTransportSetRouterReset_RegisterResetInterface_Proxy
};


static const PRPC_STUB_FUNCTION IMailTransportSetRouterReset_table[] =
{
    IMailTransportSetRouterReset_RegisterResetInterface_Stub
};

const CInterfaceStubVtbl _IMailTransportSetRouterResetStubVtbl =
{
    &IID_IMailTransportSetRouterReset,
    0,
    4,
    &IMailTransportSetRouterReset_table[-3],
    CStdStubBuffer_METHODS
};


/* Object interface: IMessageRouter, ver. 0.0,
   GUID={0xA928AD14,0x1610,0x11d2,{0x9E,0x02,0x00,0xC0,0x4F,0xA3,0x22,0xBA}} */


extern const MIDL_STUB_DESC Object_StubDesc;


#pragma code_seg(".orpc")

HRESULT STDMETHODCALLTYPE IMessageRouter_GetMessageType_Proxy( 
    IMessageRouter __RPC_FAR * This,
    /* [in] */ IMailMsgProperties __RPC_FAR *pIMailMsg,
    /* [out] */ DWORD __RPC_FAR *pdwMessageType)
{

    HRESULT _RetVal;
    
    RPC_MESSAGE _RpcMessage;
    
    MIDL_STUB_MESSAGE _StubMsg;
    
    RpcTryExcept
        {
        NdrProxyInitialize(
                      ( void __RPC_FAR *  )This,
                      ( PRPC_MESSAGE  )&_RpcMessage,
                      ( PMIDL_STUB_MESSAGE  )&_StubMsg,
                      ( PMIDL_STUB_DESC  )&Object_StubDesc,
                      4);
        
        
        
        if(!pdwMessageType)
            {
            RpcRaiseException(RPC_X_NULL_REF_POINTER);
            }
        RpcTryFinally
            {
            
            _StubMsg.BufferLength = 0U;
            NdrInterfacePointerBufferSize( (PMIDL_STUB_MESSAGE) &_StubMsg,
                                           (unsigned char __RPC_FAR *)pIMailMsg,
                                           (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[74] );
            
            NdrProxyGetBuffer(This, &_StubMsg);
            NdrInterfacePointerMarshall( (PMIDL_STUB_MESSAGE)& _StubMsg,
                                         (unsigned char __RPC_FAR *)pIMailMsg,
                                         (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[74] );
            
            NdrProxySendReceive(This, &_StubMsg);
            
            if ( (_RpcMessage.DataRepresentation & 0X0000FFFFUL) != NDR_LOCAL_DATA_REPRESENTATION )
                NdrConvert( (PMIDL_STUB_MESSAGE) &_StubMsg, (PFORMAT_STRING) &__MIDL_ProcFormatString.Format[84] );
            
            *pdwMessageType = *(( DWORD __RPC_FAR * )_StubMsg.Buffer)++;
            
            _RetVal = *(( HRESULT __RPC_FAR * )_StubMsg.Buffer)++;
            
            }
        RpcFinally
            {
            NdrProxyFreeBuffer(This, &_StubMsg);
            
            }
        RpcEndFinally
        
        }
    RpcExcept(_StubMsg.dwStubPhase != PROXY_SENDRECEIVE)
        {
        NdrClearOutParameters(
                         ( PMIDL_STUB_MESSAGE  )&_StubMsg,
                         ( PFORMAT_STRING  )&__MIDL_TypeFormatString.Format[164],
                         ( void __RPC_FAR * )pdwMessageType);
        _RetVal = NdrProxyErrorHandler(RpcExceptionCode());
        }
    RpcEndExcept
    return _RetVal;
}

void __RPC_STUB IMessageRouter_GetMessageType_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase)
{
    DWORD _M0;
    HRESULT _RetVal;
    MIDL_STUB_MESSAGE _StubMsg;
    IMailMsgProperties __RPC_FAR *pIMailMsg;
    DWORD __RPC_FAR *pdwMessageType;
    
NdrStubInitialize(
                     _pRpcMessage,
                     &_StubMsg,
                     &Object_StubDesc,
                     _pRpcChannelBuffer);
    pIMailMsg = 0;
    ( DWORD __RPC_FAR * )pdwMessageType = 0;
    RpcTryFinally
        {
        if ( (_pRpcMessage->DataRepresentation & 0X0000FFFFUL) != NDR_LOCAL_DATA_REPRESENTATION )
            NdrConvert( (PMIDL_STUB_MESSAGE) &_StubMsg, (PFORMAT_STRING) &__MIDL_ProcFormatString.Format[84] );
        
        NdrInterfacePointerUnmarshall( (PMIDL_STUB_MESSAGE) &_StubMsg,
                                       (unsigned char __RPC_FAR * __RPC_FAR *)&pIMailMsg,
                                       (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[74],
                                       (unsigned char)0 );
        
        pdwMessageType = &_M0;
        
        *_pdwStubPhase = STUB_CALL_SERVER;
        _RetVal = (((IMessageRouter*) ((CStdStubBuffer *)This)->pvServerObject)->lpVtbl) -> GetMessageType(
                  (IMessageRouter *) ((CStdStubBuffer *)This)->pvServerObject,
                  pIMailMsg,
                  pdwMessageType);
        
        *_pdwStubPhase = STUB_MARSHAL;
        
        _StubMsg.BufferLength = 4U + 4U;
        NdrStubGetBuffer(This, _pRpcChannelBuffer, &_StubMsg);
        *(( DWORD __RPC_FAR * )_StubMsg.Buffer)++ = *pdwMessageType;
        
        *(( HRESULT __RPC_FAR * )_StubMsg.Buffer)++ = _RetVal;
        
        }
    RpcFinally
        {
        NdrInterfacePointerFree( &_StubMsg,
                                 (unsigned char __RPC_FAR *)pIMailMsg,
                                 &__MIDL_TypeFormatString.Format[74] );
        
        }
    RpcEndFinally
    _pRpcMessage->BufferLength = 
        (unsigned int)(_StubMsg.Buffer - (unsigned char __RPC_FAR *)_pRpcMessage->Buffer);
    
}


HRESULT STDMETHODCALLTYPE IMessageRouter_ReleaseMessageType_Proxy( 
    IMessageRouter __RPC_FAR * This,
    /* [in] */ DWORD dwMessageType,
    /* [in] */ DWORD dwReleaseCount)
{

    HRESULT _RetVal;
    
    RPC_MESSAGE _RpcMessage;
    
    MIDL_STUB_MESSAGE _StubMsg;
    
    RpcTryExcept
        {
        NdrProxyInitialize(
                      ( void __RPC_FAR *  )This,
                      ( PRPC_MESSAGE  )&_RpcMessage,
                      ( PMIDL_STUB_MESSAGE  )&_StubMsg,
                      ( PMIDL_STUB_DESC  )&Object_StubDesc,
                      5);
        
        
        
        RpcTryFinally
            {
            
            _StubMsg.BufferLength = 4U + 4U;
            NdrProxyGetBuffer(This, &_StubMsg);
            *(( DWORD __RPC_FAR * )_StubMsg.Buffer)++ = dwMessageType;
            
            *(( DWORD __RPC_FAR * )_StubMsg.Buffer)++ = dwReleaseCount;
            
            NdrProxySendReceive(This, &_StubMsg);
            
            if ( (_RpcMessage.DataRepresentation & 0X0000FFFFUL) != NDR_LOCAL_DATA_REPRESENTATION )
                NdrConvert( (PMIDL_STUB_MESSAGE) &_StubMsg, (PFORMAT_STRING) &__MIDL_ProcFormatString.Format[94] );
            
            _RetVal = *(( HRESULT __RPC_FAR * )_StubMsg.Buffer)++;
            
            }
        RpcFinally
            {
            NdrProxyFreeBuffer(This, &_StubMsg);
            
            }
        RpcEndFinally
        
        }
    RpcExcept(_StubMsg.dwStubPhase != PROXY_SENDRECEIVE)
        {
        _RetVal = NdrProxyErrorHandler(RpcExceptionCode());
        }
    RpcEndExcept
    return _RetVal;
}

void __RPC_STUB IMessageRouter_ReleaseMessageType_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase)
{
    HRESULT _RetVal;
    MIDL_STUB_MESSAGE _StubMsg;
    DWORD dwMessageType;
    DWORD dwReleaseCount;
    
NdrStubInitialize(
                     _pRpcMessage,
                     &_StubMsg,
                     &Object_StubDesc,
                     _pRpcChannelBuffer);
    RpcTryFinally
        {
        if ( (_pRpcMessage->DataRepresentation & 0X0000FFFFUL) != NDR_LOCAL_DATA_REPRESENTATION )
            NdrConvert( (PMIDL_STUB_MESSAGE) &_StubMsg, (PFORMAT_STRING) &__MIDL_ProcFormatString.Format[94] );
        
        dwMessageType = *(( DWORD __RPC_FAR * )_StubMsg.Buffer)++;
        
        dwReleaseCount = *(( DWORD __RPC_FAR * )_StubMsg.Buffer)++;
        
        
        *_pdwStubPhase = STUB_CALL_SERVER;
        _RetVal = (((IMessageRouter*) ((CStdStubBuffer *)This)->pvServerObject)->lpVtbl) -> ReleaseMessageType(
                      (IMessageRouter *) ((CStdStubBuffer *)This)->pvServerObject,
                      dwMessageType,
                      dwReleaseCount);
        
        *_pdwStubPhase = STUB_MARSHAL;
        
        _StubMsg.BufferLength = 4U;
        NdrStubGetBuffer(This, _pRpcChannelBuffer, &_StubMsg);
        *(( HRESULT __RPC_FAR * )_StubMsg.Buffer)++ = _RetVal;
        
        }
    RpcFinally
        {
        }
    RpcEndFinally
    _pRpcMessage->BufferLength = 
        (unsigned int)(_StubMsg.Buffer - (unsigned char __RPC_FAR *)_pRpcMessage->Buffer);
    
}


HRESULT STDMETHODCALLTYPE IMessageRouter_ConnectionFailed_Proxy( 
    IMessageRouter __RPC_FAR * This,
    /* [string][in] */ LPSTR pszConnectorName)
{

    HRESULT _RetVal;
    
    RPC_MESSAGE _RpcMessage;
    
    MIDL_STUB_MESSAGE _StubMsg;
    
    RpcTryExcept
        {
        NdrProxyInitialize(
                      ( void __RPC_FAR *  )This,
                      ( PRPC_MESSAGE  )&_RpcMessage,
                      ( PMIDL_STUB_MESSAGE  )&_StubMsg,
                      ( PMIDL_STUB_DESC  )&Object_StubDesc,
                      8);
        
        
        
        if(!pszConnectorName)
            {
            RpcRaiseException(RPC_X_NULL_REF_POINTER);
            }
        RpcTryFinally
            {
            
            _StubMsg.BufferLength = 12U;
            NdrConformantStringBufferSize( (PMIDL_STUB_MESSAGE) &_StubMsg,
                                           (unsigned char __RPC_FAR *)pszConnectorName,
                                           (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[170] );
            
            NdrProxyGetBuffer(This, &_StubMsg);
            NdrConformantStringMarshall( (PMIDL_STUB_MESSAGE)& _StubMsg,
                                         (unsigned char __RPC_FAR *)pszConnectorName,
                                         (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[170] );
            
            NdrProxySendReceive(This, &_StubMsg);
            
            if ( (_RpcMessage.DataRepresentation & 0X0000FFFFUL) != NDR_LOCAL_DATA_REPRESENTATION )
                NdrConvert( (PMIDL_STUB_MESSAGE) &_StubMsg, (PFORMAT_STRING) &__MIDL_ProcFormatString.Format[100] );
            
            _RetVal = *(( HRESULT __RPC_FAR * )_StubMsg.Buffer)++;
            
            }
        RpcFinally
            {
            NdrProxyFreeBuffer(This, &_StubMsg);
            
            }
        RpcEndFinally
        
        }
    RpcExcept(_StubMsg.dwStubPhase != PROXY_SENDRECEIVE)
        {
        _RetVal = NdrProxyErrorHandler(RpcExceptionCode());
        }
    RpcEndExcept
    return _RetVal;
}

void __RPC_STUB IMessageRouter_ConnectionFailed_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase)
{
    HRESULT _RetVal;
    MIDL_STUB_MESSAGE _StubMsg;
    LPSTR pszConnectorName;
    
NdrStubInitialize(
                     _pRpcMessage,
                     &_StubMsg,
                     &Object_StubDesc,
                     _pRpcChannelBuffer);
    ( LPSTR  )pszConnectorName = 0;
    RpcTryFinally
        {
        if ( (_pRpcMessage->DataRepresentation & 0X0000FFFFUL) != NDR_LOCAL_DATA_REPRESENTATION )
            NdrConvert( (PMIDL_STUB_MESSAGE) &_StubMsg, (PFORMAT_STRING) &__MIDL_ProcFormatString.Format[100] );
        
        NdrConformantStringUnmarshall( (PMIDL_STUB_MESSAGE) &_StubMsg,
                                       (unsigned char __RPC_FAR * __RPC_FAR *)&pszConnectorName,
                                       (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[170],
                                       (unsigned char)0 );
        
        
        *_pdwStubPhase = STUB_CALL_SERVER;
        _RetVal = (((IMessageRouter*) ((CStdStubBuffer *)This)->pvServerObject)->lpVtbl) -> ConnectionFailed((IMessageRouter *) ((CStdStubBuffer *)This)->pvServerObject,pszConnectorName);
        
        *_pdwStubPhase = STUB_MARSHAL;
        
        _StubMsg.BufferLength = 4U;
        _StubMsg.BufferLength += 16;
        
        NdrStubGetBuffer(This, _pRpcChannelBuffer, &_StubMsg);
        *(( HRESULT __RPC_FAR * )_StubMsg.Buffer)++ = _RetVal;
        
        }
    RpcFinally
        {
        }
    RpcEndFinally
    _pRpcMessage->BufferLength = 
        (unsigned int)(_StubMsg.Buffer - (unsigned char __RPC_FAR *)_pRpcMessage->Buffer);
    
}

const CINTERFACE_PROXY_VTABLE(9) _IMessageRouterProxyVtbl = 
{
    &IID_IMessageRouter,
    IUnknown_QueryInterface_Proxy,
    IUnknown_AddRef_Proxy,
    IUnknown_Release_Proxy ,
    0 /* IMessageRouter_GetTransportSinkID_Proxy */ ,
    IMessageRouter_GetMessageType_Proxy ,
    IMessageRouter_ReleaseMessageType_Proxy ,
    0 /* IMessageRouter_GetNextHop_Proxy */ ,
    0 /* IMessageRouter_GetNextHopFree_Proxy */ ,
    IMessageRouter_ConnectionFailed_Proxy
};


static const PRPC_STUB_FUNCTION IMessageRouter_table[] =
{
    STUB_FORWARDING_FUNCTION,
    IMessageRouter_GetMessageType_Stub,
    IMessageRouter_ReleaseMessageType_Stub,
    STUB_FORWARDING_FUNCTION,
    STUB_FORWARDING_FUNCTION,
    IMessageRouter_ConnectionFailed_Stub
};

const CInterfaceStubVtbl _IMessageRouterStubVtbl =
{
    &IID_IMessageRouter,
    0,
    9,
    &IMessageRouter_table[-3],
    CStdStubBuffer_METHODS
};


/* Standard interface: __MIDL_itf_SmtpEvent_0281, ver. 0.0,
   GUID={0x00000000,0x0000,0x0000,{0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00}} */


/* Object interface: IMailTransportRouterSetLinkState, ver. 0.0,
   GUID={0xB870CE28,0xA755,0x11d2,{0xA6,0xA9,0x00,0xC0,0x4F,0xA3,0x49,0x0A}} */


extern const MIDL_STUB_DESC Object_StubDesc;


#pragma code_seg(".orpc")

HRESULT STDMETHODCALLTYPE IMailTransportRouterSetLinkState_SetLinkState_Proxy( 
    IMailTransportRouterSetLinkState __RPC_FAR * This,
    /* [in] */ LPSTR szLinkDomainName,
    /* [in] */ GUID guidRouterGUID,
    /* [in] */ DWORD dwScheduleID,
    /* [in] */ LPSTR szConnectorName,
    /* [in] */ DWORD dwSetLinkState,
    /* [in] */ DWORD dwUnsetLinkState,
    /* [in] */ FILETIME __RPC_FAR *pftNextScheduled,
    /* [in] */ IMessageRouter __RPC_FAR *pMessageRouter)
{

    HRESULT _RetVal;
    
    RPC_MESSAGE _RpcMessage;
    
    MIDL_STUB_MESSAGE _StubMsg;
    
    RpcTryExcept
        {
        NdrProxyInitialize(
                      ( void __RPC_FAR *  )This,
                      ( PRPC_MESSAGE  )&_RpcMessage,
                      ( PMIDL_STUB_MESSAGE  )&_StubMsg,
                      ( PMIDL_STUB_DESC  )&Object_StubDesc,
                      3);
        
        
        
        if(!szLinkDomainName)
            {
            RpcRaiseException(RPC_X_NULL_REF_POINTER);
            }
        if(!szConnectorName)
            {
            RpcRaiseException(RPC_X_NULL_REF_POINTER);
            }
        if(!pftNextScheduled)
            {
            RpcRaiseException(RPC_X_NULL_REF_POINTER);
            }
        RpcTryFinally
            {
            
            _StubMsg.BufferLength = 12U + 7U + 11U + 13U + 11U + 7U + 4U + 0U;
            NdrConformantStringBufferSize( (PMIDL_STUB_MESSAGE) &_StubMsg,
                                           (unsigned char __RPC_FAR *)szLinkDomainName,
                                           (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[170] );
            
            NdrSimpleStructBufferSize( (PMIDL_STUB_MESSAGE) &_StubMsg,
                                       (unsigned char __RPC_FAR *)&guidRouterGUID,
                                       (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[178] );
            
            NdrConformantStringBufferSize( (PMIDL_STUB_MESSAGE) &_StubMsg,
                                           (unsigned char __RPC_FAR *)szConnectorName,
                                           (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[170] );
            
            NdrSimpleStructBufferSize( (PMIDL_STUB_MESSAGE) &_StubMsg,
                                       (unsigned char __RPC_FAR *)pftNextScheduled,
                                       (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[194] );
            
            NdrInterfacePointerBufferSize( (PMIDL_STUB_MESSAGE) &_StubMsg,
                                           (unsigned char __RPC_FAR *)pMessageRouter,
                                           (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[202] );
            
            NdrProxyGetBuffer(This, &_StubMsg);
            NdrConformantStringMarshall( (PMIDL_STUB_MESSAGE)& _StubMsg,
                                         (unsigned char __RPC_FAR *)szLinkDomainName,
                                         (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[170] );
            
            NdrSimpleStructMarshall( (PMIDL_STUB_MESSAGE)& _StubMsg,
                                     (unsigned char __RPC_FAR *)&guidRouterGUID,
                                     (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[178] );
            
            *(( DWORD __RPC_FAR * )_StubMsg.Buffer)++ = dwScheduleID;
            
            NdrConformantStringMarshall( (PMIDL_STUB_MESSAGE)& _StubMsg,
                                         (unsigned char __RPC_FAR *)szConnectorName,
                                         (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[170] );
            
            _StubMsg.Buffer = (unsigned char __RPC_FAR *)(((long)_StubMsg.Buffer + 3) & ~ 0x3);
            *(( DWORD __RPC_FAR * )_StubMsg.Buffer)++ = dwSetLinkState;
            
            *(( DWORD __RPC_FAR * )_StubMsg.Buffer)++ = dwUnsetLinkState;
            
            NdrSimpleStructMarshall( (PMIDL_STUB_MESSAGE)& _StubMsg,
                                     (unsigned char __RPC_FAR *)pftNextScheduled,
                                     (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[194] );
            
            NdrInterfacePointerMarshall( (PMIDL_STUB_MESSAGE)& _StubMsg,
                                         (unsigned char __RPC_FAR *)pMessageRouter,
                                         (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[202] );
            
            NdrProxySendReceive(This, &_StubMsg);
            
            if ( (_RpcMessage.DataRepresentation & 0X0000FFFFUL) != NDR_LOCAL_DATA_REPRESENTATION )
                NdrConvert( (PMIDL_STUB_MESSAGE) &_StubMsg, (PFORMAT_STRING) &__MIDL_ProcFormatString.Format[106] );
            
            _RetVal = *(( HRESULT __RPC_FAR * )_StubMsg.Buffer)++;
            
            }
        RpcFinally
            {
            NdrProxyFreeBuffer(This, &_StubMsg);
            
            }
        RpcEndFinally
        
        }
    RpcExcept(_StubMsg.dwStubPhase != PROXY_SENDRECEIVE)
        {
        _RetVal = NdrProxyErrorHandler(RpcExceptionCode());
        }
    RpcEndExcept
    return _RetVal;
}

void __RPC_STUB IMailTransportRouterSetLinkState_SetLinkState_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase)
{
    HRESULT _RetVal;
    MIDL_STUB_MESSAGE _StubMsg;
    void __RPC_FAR *_p_guidRouterGUID;
    DWORD dwScheduleID;
    DWORD dwSetLinkState;
    DWORD dwUnsetLinkState;
    GUID guidRouterGUID;
    IMessageRouter __RPC_FAR *pMessageRouter;
    FILETIME __RPC_FAR *pftNextScheduled;
    LPSTR szConnectorName;
    LPSTR szLinkDomainName;
    
NdrStubInitialize(
                     _pRpcMessage,
                     &_StubMsg,
                     &Object_StubDesc,
                     _pRpcChannelBuffer);
    ( LPSTR  )szLinkDomainName = 0;
    _p_guidRouterGUID = &guidRouterGUID;
    MIDL_memset(
               _p_guidRouterGUID,
               0,
               sizeof( GUID  ));
    ( LPSTR  )szConnectorName = 0;
    ( FILETIME __RPC_FAR * )pftNextScheduled = 0;
    pMessageRouter = 0;
    RpcTryFinally
        {
        if ( (_pRpcMessage->DataRepresentation & 0X0000FFFFUL) != NDR_LOCAL_DATA_REPRESENTATION )
            NdrConvert( (PMIDL_STUB_MESSAGE) &_StubMsg, (PFORMAT_STRING) &__MIDL_ProcFormatString.Format[106] );
        
        NdrConformantStringUnmarshall( (PMIDL_STUB_MESSAGE) &_StubMsg,
                                       (unsigned char __RPC_FAR * __RPC_FAR *)&szLinkDomainName,
                                       (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[170],
                                       (unsigned char)0 );
        
        NdrSimpleStructUnmarshall( (PMIDL_STUB_MESSAGE) &_StubMsg,
                                   (unsigned char __RPC_FAR * __RPC_FAR *)&_p_guidRouterGUID,
                                   (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[178],
                                   (unsigned char)0 );
        
        dwScheduleID = *(( DWORD __RPC_FAR * )_StubMsg.Buffer)++;
        
        NdrConformantStringUnmarshall( (PMIDL_STUB_MESSAGE) &_StubMsg,
                                       (unsigned char __RPC_FAR * __RPC_FAR *)&szConnectorName,
                                       (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[170],
                                       (unsigned char)0 );
        
        _StubMsg.Buffer = (unsigned char __RPC_FAR *)(((long)_StubMsg.Buffer + 3) & ~ 0x3);
        dwSetLinkState = *(( DWORD __RPC_FAR * )_StubMsg.Buffer)++;
        
        dwUnsetLinkState = *(( DWORD __RPC_FAR * )_StubMsg.Buffer)++;
        
        NdrSimpleStructUnmarshall( (PMIDL_STUB_MESSAGE) &_StubMsg,
                                   (unsigned char __RPC_FAR * __RPC_FAR *)&pftNextScheduled,
                                   (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[194],
                                   (unsigned char)0 );
        
        NdrInterfacePointerUnmarshall( (PMIDL_STUB_MESSAGE) &_StubMsg,
                                       (unsigned char __RPC_FAR * __RPC_FAR *)&pMessageRouter,
                                       (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[202],
                                       (unsigned char)0 );
        
        
        *_pdwStubPhase = STUB_CALL_SERVER;
        _RetVal = (((IMailTransportRouterSetLinkState*) ((CStdStubBuffer *)This)->pvServerObject)->lpVtbl) -> SetLinkState(
                (IMailTransportRouterSetLinkState *) ((CStdStubBuffer *)This)->pvServerObject,
                szLinkDomainName,
                guidRouterGUID,
                dwScheduleID,
                szConnectorName,
                dwSetLinkState,
                dwUnsetLinkState,
                pftNextScheduled,
                pMessageRouter);
        
        *_pdwStubPhase = STUB_MARSHAL;
        
        _StubMsg.BufferLength = 4U;
        _StubMsg.BufferLength += 16;
        
        NdrStubGetBuffer(This, _pRpcChannelBuffer, &_StubMsg);
        *(( HRESULT __RPC_FAR * )_StubMsg.Buffer)++ = _RetVal;
        
        }
    RpcFinally
        {
        NdrInterfacePointerFree( &_StubMsg,
                                 (unsigned char __RPC_FAR *)pMessageRouter,
                                 &__MIDL_TypeFormatString.Format[202] );
        
        }
    RpcEndFinally
    _pRpcMessage->BufferLength = 
        (unsigned int)(_StubMsg.Buffer - (unsigned char __RPC_FAR *)_pRpcMessage->Buffer);
    
}

const CINTERFACE_PROXY_VTABLE(4) _IMailTransportRouterSetLinkStateProxyVtbl = 
{
    &IID_IMailTransportRouterSetLinkState,
    IUnknown_QueryInterface_Proxy,
    IUnknown_AddRef_Proxy,
    IUnknown_Release_Proxy ,
    IMailTransportRouterSetLinkState_SetLinkState_Proxy
};


static const PRPC_STUB_FUNCTION IMailTransportRouterSetLinkState_table[] =
{
    IMailTransportRouterSetLinkState_SetLinkState_Stub
};

const CInterfaceStubVtbl _IMailTransportRouterSetLinkStateStubVtbl =
{
    &IID_IMailTransportRouterSetLinkState,
    0,
    4,
    &IMailTransportRouterSetLinkState_table[-3],
    CStdStubBuffer_METHODS
};


/* Object interface: IMessageRouterLinkStateNotification, ver. 0.0,
   GUID={0xB870CE29,0xA755,0x11d2,{0xA6,0xA9,0x00,0xC0,0x4F,0xA3,0x49,0x0A}} */


extern const MIDL_STUB_DESC Object_StubDesc;


#pragma code_seg(".orpc")

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
    /* [out] */ DWORD __RPC_FAR *pdwUnsetLinkState)
{

    HRESULT _RetVal;
    
    RPC_MESSAGE _RpcMessage;
    
    MIDL_STUB_MESSAGE _StubMsg;
    
    RpcTryExcept
        {
        NdrProxyInitialize(
                      ( void __RPC_FAR *  )This,
                      ( PRPC_MESSAGE  )&_RpcMessage,
                      ( PMIDL_STUB_MESSAGE  )&_StubMsg,
                      ( PMIDL_STUB_DESC  )&Object_StubDesc,
                      3);
        
        
        
        if(!szLinkDomainName)
            {
            RpcRaiseException(RPC_X_NULL_REF_POINTER);
            }
        if(!szConnectorName)
            {
            RpcRaiseException(RPC_X_NULL_REF_POINTER);
            }
        if(!pftNextScheduled)
            {
            RpcRaiseException(RPC_X_NULL_REF_POINTER);
            }
        if(!pdwSetLinkState)
            {
            RpcRaiseException(RPC_X_NULL_REF_POINTER);
            }
        if(!pdwUnsetLinkState)
            {
            RpcRaiseException(RPC_X_NULL_REF_POINTER);
            }
        RpcTryFinally
            {
            
            _StubMsg.BufferLength = 12U + 7U + 11U + 13U + 11U + 7U + 4U;
            NdrConformantStringBufferSize( (PMIDL_STUB_MESSAGE) &_StubMsg,
                                           (unsigned char __RPC_FAR *)szLinkDomainName,
                                           (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[170] );
            
            NdrSimpleStructBufferSize( (PMIDL_STUB_MESSAGE) &_StubMsg,
                                       (unsigned char __RPC_FAR *)&guidRouterGUID,
                                       (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[178] );
            
            NdrConformantStringBufferSize( (PMIDL_STUB_MESSAGE) &_StubMsg,
                                           (unsigned char __RPC_FAR *)szConnectorName,
                                           (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[170] );
            
            NdrSimpleStructBufferSize( (PMIDL_STUB_MESSAGE) &_StubMsg,
                                       (unsigned char __RPC_FAR *)pftNextScheduled,
                                       (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[194] );
            
            NdrProxyGetBuffer(This, &_StubMsg);
            NdrConformantStringMarshall( (PMIDL_STUB_MESSAGE)& _StubMsg,
                                         (unsigned char __RPC_FAR *)szLinkDomainName,
                                         (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[170] );
            
            NdrSimpleStructMarshall( (PMIDL_STUB_MESSAGE)& _StubMsg,
                                     (unsigned char __RPC_FAR *)&guidRouterGUID,
                                     (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[178] );
            
            *(( DWORD __RPC_FAR * )_StubMsg.Buffer)++ = dwScheduleID;
            
            NdrConformantStringMarshall( (PMIDL_STUB_MESSAGE)& _StubMsg,
                                         (unsigned char __RPC_FAR *)szConnectorName,
                                         (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[170] );
            
            _StubMsg.Buffer = (unsigned char __RPC_FAR *)(((long)_StubMsg.Buffer + 3) & ~ 0x3);
            *(( DWORD __RPC_FAR * )_StubMsg.Buffer)++ = dwLinkState;
            
            *(( DWORD __RPC_FAR * )_StubMsg.Buffer)++ = cConsecutiveFailures;
            
            NdrSimpleStructMarshall( (PMIDL_STUB_MESSAGE)& _StubMsg,
                                     (unsigned char __RPC_FAR *)pftNextScheduled,
                                     (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[194] );
            
            NdrProxySendReceive(This, &_StubMsg);
            
            if ( (_RpcMessage.DataRepresentation & 0X0000FFFFUL) != NDR_LOCAL_DATA_REPRESENTATION )
                NdrConvert( (PMIDL_STUB_MESSAGE) &_StubMsg, (PFORMAT_STRING) &__MIDL_ProcFormatString.Format[134] );
            
            NdrSimpleStructUnmarshall( (PMIDL_STUB_MESSAGE) &_StubMsg,
                                       (unsigned char __RPC_FAR * __RPC_FAR *)&pftNextScheduled,
                                       (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[194],
                                       (unsigned char)0 );
            
            *pdwSetLinkState = *(( DWORD __RPC_FAR * )_StubMsg.Buffer)++;
            
            *pdwUnsetLinkState = *(( DWORD __RPC_FAR * )_StubMsg.Buffer)++;
            
            _RetVal = *(( HRESULT __RPC_FAR * )_StubMsg.Buffer)++;
            
            }
        RpcFinally
            {
            NdrProxyFreeBuffer(This, &_StubMsg);
            
            }
        RpcEndFinally
        
        }
    RpcExcept(_StubMsg.dwStubPhase != PROXY_SENDRECEIVE)
        {
        NdrClearOutParameters(
                         ( PMIDL_STUB_MESSAGE  )&_StubMsg,
                         ( PFORMAT_STRING  )&__MIDL_TypeFormatString.Format[190],
                         ( void __RPC_FAR * )pftNextScheduled);
        NdrClearOutParameters(
                         ( PMIDL_STUB_MESSAGE  )&_StubMsg,
                         ( PFORMAT_STRING  )&__MIDL_TypeFormatString.Format[164],
                         ( void __RPC_FAR * )pdwSetLinkState);
        NdrClearOutParameters(
                         ( PMIDL_STUB_MESSAGE  )&_StubMsg,
                         ( PFORMAT_STRING  )&__MIDL_TypeFormatString.Format[164],
                         ( void __RPC_FAR * )pdwUnsetLinkState);
        _RetVal = NdrProxyErrorHandler(RpcExceptionCode());
        }
    RpcEndExcept
    return _RetVal;
}

void __RPC_STUB IMessageRouterLinkStateNotification_LinkStateNotify_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase)
{
    DWORD _M11;
    DWORD _M12;
    HRESULT _RetVal;
    MIDL_STUB_MESSAGE _StubMsg;
    void __RPC_FAR *_p_guidRouterGUID;
    DWORD cConsecutiveFailures;
    DWORD dwLinkState;
    DWORD dwScheduleID;
    GUID guidRouterGUID;
    DWORD __RPC_FAR *pdwSetLinkState;
    DWORD __RPC_FAR *pdwUnsetLinkState;
    FILETIME __RPC_FAR *pftNextScheduled;
    LPSTR szConnectorName;
    LPSTR szLinkDomainName;
    
NdrStubInitialize(
                     _pRpcMessage,
                     &_StubMsg,
                     &Object_StubDesc,
                     _pRpcChannelBuffer);
    ( LPSTR  )szLinkDomainName = 0;
    _p_guidRouterGUID = &guidRouterGUID;
    MIDL_memset(
               _p_guidRouterGUID,
               0,
               sizeof( GUID  ));
    ( LPSTR  )szConnectorName = 0;
    ( FILETIME __RPC_FAR * )pftNextScheduled = 0;
    ( DWORD __RPC_FAR * )pdwSetLinkState = 0;
    ( DWORD __RPC_FAR * )pdwUnsetLinkState = 0;
    RpcTryFinally
        {
        if ( (_pRpcMessage->DataRepresentation & 0X0000FFFFUL) != NDR_LOCAL_DATA_REPRESENTATION )
            NdrConvert( (PMIDL_STUB_MESSAGE) &_StubMsg, (PFORMAT_STRING) &__MIDL_ProcFormatString.Format[134] );
        
        NdrConformantStringUnmarshall( (PMIDL_STUB_MESSAGE) &_StubMsg,
                                       (unsigned char __RPC_FAR * __RPC_FAR *)&szLinkDomainName,
                                       (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[170],
                                       (unsigned char)0 );
        
        NdrSimpleStructUnmarshall( (PMIDL_STUB_MESSAGE) &_StubMsg,
                                   (unsigned char __RPC_FAR * __RPC_FAR *)&_p_guidRouterGUID,
                                   (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[178],
                                   (unsigned char)0 );
        
        dwScheduleID = *(( DWORD __RPC_FAR * )_StubMsg.Buffer)++;
        
        NdrConformantStringUnmarshall( (PMIDL_STUB_MESSAGE) &_StubMsg,
                                       (unsigned char __RPC_FAR * __RPC_FAR *)&szConnectorName,
                                       (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[170],
                                       (unsigned char)0 );
        
        _StubMsg.Buffer = (unsigned char __RPC_FAR *)(((long)_StubMsg.Buffer + 3) & ~ 0x3);
        dwLinkState = *(( DWORD __RPC_FAR * )_StubMsg.Buffer)++;
        
        cConsecutiveFailures = *(( DWORD __RPC_FAR * )_StubMsg.Buffer)++;
        
        NdrSimpleStructUnmarshall( (PMIDL_STUB_MESSAGE) &_StubMsg,
                                   (unsigned char __RPC_FAR * __RPC_FAR *)&pftNextScheduled,
                                   (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[194],
                                   (unsigned char)0 );
        
        pdwSetLinkState = &_M11;
        pdwUnsetLinkState = &_M12;
        
        *_pdwStubPhase = STUB_CALL_SERVER;
        _RetVal = (((IMessageRouterLinkStateNotification*) ((CStdStubBuffer *)This)->pvServerObject)->lpVtbl) -> LinkStateNotify(
                   (IMessageRouterLinkStateNotification *) ((CStdStubBuffer *)This)->pvServerObject,
                   szLinkDomainName,
                   guidRouterGUID,
                   dwScheduleID,
                   szConnectorName,
                   dwLinkState,
                   cConsecutiveFailures,
                   pftNextScheduled,
                   pdwSetLinkState,
                   pdwUnsetLinkState);
        
        *_pdwStubPhase = STUB_MARSHAL;
        
        _StubMsg.BufferLength = 0U + 11U + 7U + 7U;
        NdrSimpleStructBufferSize( (PMIDL_STUB_MESSAGE) &_StubMsg,
                                   (unsigned char __RPC_FAR *)pftNextScheduled,
                                   (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[194] );
        
        _StubMsg.BufferLength += 16;
        
        NdrStubGetBuffer(This, _pRpcChannelBuffer, &_StubMsg);
        NdrSimpleStructMarshall( (PMIDL_STUB_MESSAGE)& _StubMsg,
                                 (unsigned char __RPC_FAR *)pftNextScheduled,
                                 (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[194] );
        
        *(( DWORD __RPC_FAR * )_StubMsg.Buffer)++ = *pdwSetLinkState;
        
        *(( DWORD __RPC_FAR * )_StubMsg.Buffer)++ = *pdwUnsetLinkState;
        
        *(( HRESULT __RPC_FAR * )_StubMsg.Buffer)++ = _RetVal;
        
        }
    RpcFinally
        {
        }
    RpcEndFinally
    _pRpcMessage->BufferLength = 
        (unsigned int)(_StubMsg.Buffer - (unsigned char __RPC_FAR *)_pRpcMessage->Buffer);
    
}

const CINTERFACE_PROXY_VTABLE(4) _IMessageRouterLinkStateNotificationProxyVtbl = 
{
    &IID_IMessageRouterLinkStateNotification,
    IUnknown_QueryInterface_Proxy,
    IUnknown_AddRef_Proxy,
    IUnknown_Release_Proxy ,
    IMessageRouterLinkStateNotification_LinkStateNotify_Proxy
};


static const PRPC_STUB_FUNCTION IMessageRouterLinkStateNotification_table[] =
{
    IMessageRouterLinkStateNotification_LinkStateNotify_Stub
};

const CInterfaceStubVtbl _IMessageRouterLinkStateNotificationStubVtbl =
{
    &IID_IMessageRouterLinkStateNotification,
    0,
    4,
    &IMessageRouterLinkStateNotification_table[-3],
    CStdStubBuffer_METHODS
};


/* Standard interface: __MIDL_itf_SmtpEvent_0283, ver. 0.0,
   GUID={0x00000000,0x0000,0x0000,{0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00}} */


/* Object interface: IMailTransportRoutingEngine, ver. 0.0,
   GUID={0xA928AD13,0x1610,0x11d2,{0x9E,0x02,0x00,0xC0,0x4F,0xA3,0x22,0xBA}} */


extern const MIDL_STUB_DESC Object_StubDesc;


#pragma code_seg(".orpc")
const CINTERFACE_PROXY_VTABLE(4) _IMailTransportRoutingEngineProxyVtbl = 
{
    &IID_IMailTransportRoutingEngine,
    IUnknown_QueryInterface_Proxy,
    IUnknown_AddRef_Proxy,
    IUnknown_Release_Proxy ,
    0 /* IMailTransportRoutingEngine_GetMessageRouter_Proxy */
};


static const PRPC_STUB_FUNCTION IMailTransportRoutingEngine_table[] =
{
    STUB_FORWARDING_FUNCTION
};

const CInterfaceStubVtbl _IMailTransportRoutingEngineStubVtbl =
{
    &IID_IMailTransportRoutingEngine,
    0,
    4,
    &IMailTransportRoutingEngine_table[-3],
    CStdStubBuffer_METHODS
};


/* Standard interface: __MIDL_itf_SmtpEvent_0284, ver. 0.0,
   GUID={0x00000000,0x0000,0x0000,{0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00}} */


/* Object interface: IMsgTrackLog, ver. 0.0,
   GUID={0x1bc3580e,0x7e4f,0x11d2,{0x94,0xf4,0x00,0xC0,0x4f,0x79,0xf1,0xd6}} */


/* Object interface: IDnsResolverRecord, ver. 0.0,
   GUID={0xe5b89c52,0x8e0b,0x11d2,{0x94,0xf6,0x00,0xC0,0x4f,0x79,0xf1,0xd6}} */


/* Object interface: IDnsResolverRecordSink, ver. 0.0,
   GUID={0xd95a4d0c,0x8e06,0x11d2,{0x94,0xf6,0x00,0xC0,0x4f,0x79,0xf1,0xd6}} */


/* Object interface: ISmtpMaxMsgSize, ver. 0.0,
   GUID={0xb997f192,0xa67d,0x11d2,{0x94,0xf7,0x00,0xC0,0x4f,0x79,0xf1,0xd6}} */


/* Standard interface: __MIDL_itf_SmtpEvent_0288, ver. 0.0,
   GUID={0x00000000,0x0000,0x0000,{0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00}} */


/* Object interface: ICategorizerProperties, ver. 0.0,
   GUID={0x96BF3199,0x79D8,0x11d2,{0x9E,0x11,0x00,0xC0,0x4F,0xA3,0x22,0xBA}} */


/* Standard interface: __MIDL_itf_SmtpEvent_0289, ver. 0.0,
   GUID={0x00000000,0x0000,0x0000,{0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00}} */


/* Object interface: ICategorizerParameters, ver. 0.0,
   GUID={0x86F9DA7B,0xEB6E,0x11d1,{0x9D,0xF3,0x00,0xC0,0x4F,0xA3,0x22,0xBA}} */


/* Object interface: ICategorizerQueries, ver. 0.0,
   GUID={0x86F9DA7D,0xEB6E,0x11d1,{0x9D,0xF3,0x00,0xC0,0x4F,0xA3,0x22,0xBA}} */


extern const MIDL_STUB_DESC Object_StubDesc;


#pragma code_seg(".orpc")

HRESULT STDMETHODCALLTYPE ICategorizerQueries_SetQueryString_Proxy( 
    ICategorizerQueries __RPC_FAR * This,
    /* [unique][in] */ LPSTR pszQueryString)
{

    HRESULT _RetVal;
    
    RPC_MESSAGE _RpcMessage;
    
    MIDL_STUB_MESSAGE _StubMsg;
    
    RpcTryExcept
        {
        NdrProxyInitialize(
                      ( void __RPC_FAR *  )This,
                      ( PRPC_MESSAGE  )&_RpcMessage,
                      ( PMIDL_STUB_MESSAGE  )&_StubMsg,
                      ( PMIDL_STUB_DESC  )&Object_StubDesc,
                      3);
        
        
        
        RpcTryFinally
            {
            
            _StubMsg.BufferLength = 16U;
            NdrPointerBufferSize( (PMIDL_STUB_MESSAGE) &_StubMsg,
                                  (unsigned char __RPC_FAR *)pszQueryString,
                                  (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[220] );
            
            NdrProxyGetBuffer(This, &_StubMsg);
            NdrPointerMarshall( (PMIDL_STUB_MESSAGE)& _StubMsg,
                                (unsigned char __RPC_FAR *)pszQueryString,
                                (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[220] );
            
            NdrProxySendReceive(This, &_StubMsg);
            
            if ( (_RpcMessage.DataRepresentation & 0X0000FFFFUL) != NDR_LOCAL_DATA_REPRESENTATION )
                NdrConvert( (PMIDL_STUB_MESSAGE) &_StubMsg, (PFORMAT_STRING) &__MIDL_ProcFormatString.Format[166] );
            
            _RetVal = *(( HRESULT __RPC_FAR * )_StubMsg.Buffer)++;
            
            }
        RpcFinally
            {
            NdrProxyFreeBuffer(This, &_StubMsg);
            
            }
        RpcEndFinally
        
        }
    RpcExcept(_StubMsg.dwStubPhase != PROXY_SENDRECEIVE)
        {
        _RetVal = NdrProxyErrorHandler(RpcExceptionCode());
        }
    RpcEndExcept
    return _RetVal;
}

void __RPC_STUB ICategorizerQueries_SetQueryString_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase)
{
    HRESULT _RetVal;
    MIDL_STUB_MESSAGE _StubMsg;
    LPSTR pszQueryString;
    
NdrStubInitialize(
                     _pRpcMessage,
                     &_StubMsg,
                     &Object_StubDesc,
                     _pRpcChannelBuffer);
    ( LPSTR  )pszQueryString = 0;
    RpcTryFinally
        {
        if ( (_pRpcMessage->DataRepresentation & 0X0000FFFFUL) != NDR_LOCAL_DATA_REPRESENTATION )
            NdrConvert( (PMIDL_STUB_MESSAGE) &_StubMsg, (PFORMAT_STRING) &__MIDL_ProcFormatString.Format[166] );
        
        NdrPointerUnmarshall( (PMIDL_STUB_MESSAGE) &_StubMsg,
                              (unsigned char __RPC_FAR * __RPC_FAR *)&pszQueryString,
                              (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[220],
                              (unsigned char)0 );
        
        
        *_pdwStubPhase = STUB_CALL_SERVER;
        _RetVal = (((ICategorizerQueries*) ((CStdStubBuffer *)This)->pvServerObject)->lpVtbl) -> SetQueryString((ICategorizerQueries *) ((CStdStubBuffer *)This)->pvServerObject,pszQueryString);
        
        *_pdwStubPhase = STUB_MARSHAL;
        
        _StubMsg.BufferLength = 4U;
        _StubMsg.BufferLength += 16;
        
        NdrStubGetBuffer(This, _pRpcChannelBuffer, &_StubMsg);
        *(( HRESULT __RPC_FAR * )_StubMsg.Buffer)++ = _RetVal;
        
        }
    RpcFinally
        {
        }
    RpcEndFinally
    _pRpcMessage->BufferLength = 
        (unsigned int)(_StubMsg.Buffer - (unsigned char __RPC_FAR *)_pRpcMessage->Buffer);
    
}


HRESULT STDMETHODCALLTYPE ICategorizerQueries_GetQueryString_Proxy( 
    ICategorizerQueries __RPC_FAR * This,
    /* [out] */ LPSTR __RPC_FAR *ppszQueryString)
{

    HRESULT _RetVal;
    
    RPC_MESSAGE _RpcMessage;
    
    MIDL_STUB_MESSAGE _StubMsg;
    
    if(ppszQueryString)
        {
        *ppszQueryString = 0;
        }
    RpcTryExcept
        {
        NdrProxyInitialize(
                      ( void __RPC_FAR *  )This,
                      ( PRPC_MESSAGE  )&_RpcMessage,
                      ( PMIDL_STUB_MESSAGE  )&_StubMsg,
                      ( PMIDL_STUB_DESC  )&Object_StubDesc,
                      4);
        
        
        
        if(!ppszQueryString)
            {
            RpcRaiseException(RPC_X_NULL_REF_POINTER);
            }
        RpcTryFinally
            {
            
            _StubMsg.BufferLength = 0U;
            NdrProxyGetBuffer(This, &_StubMsg);
            NdrProxySendReceive(This, &_StubMsg);
            
            if ( (_RpcMessage.DataRepresentation & 0X0000FFFFUL) != NDR_LOCAL_DATA_REPRESENTATION )
                NdrConvert( (PMIDL_STUB_MESSAGE) &_StubMsg, (PFORMAT_STRING) &__MIDL_ProcFormatString.Format[172] );
            
            NdrPointerUnmarshall( (PMIDL_STUB_MESSAGE) &_StubMsg,
                                  (unsigned char __RPC_FAR * __RPC_FAR *)&ppszQueryString,
                                  (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[224],
                                  (unsigned char)0 );
            
            _StubMsg.Buffer = (unsigned char __RPC_FAR *)(((long)_StubMsg.Buffer + 3) & ~ 0x3);
            _RetVal = *(( HRESULT __RPC_FAR * )_StubMsg.Buffer)++;
            
            }
        RpcFinally
            {
            NdrProxyFreeBuffer(This, &_StubMsg);
            
            }
        RpcEndFinally
        
        }
    RpcExcept(_StubMsg.dwStubPhase != PROXY_SENDRECEIVE)
        {
        NdrClearOutParameters(
                         ( PMIDL_STUB_MESSAGE  )&_StubMsg,
                         ( PFORMAT_STRING  )&__MIDL_TypeFormatString.Format[224],
                         ( void __RPC_FAR * )ppszQueryString);
        _RetVal = NdrProxyErrorHandler(RpcExceptionCode());
        }
    RpcEndExcept
    return _RetVal;
}

void __RPC_STUB ICategorizerQueries_GetQueryString_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase)
{
    LPSTR _M17;
    HRESULT _RetVal;
    MIDL_STUB_MESSAGE _StubMsg;
    LPSTR __RPC_FAR *ppszQueryString;
    
NdrStubInitialize(
                     _pRpcMessage,
                     &_StubMsg,
                     &Object_StubDesc,
                     _pRpcChannelBuffer);
    ( LPSTR __RPC_FAR * )ppszQueryString = 0;
    RpcTryFinally
        {
        ppszQueryString = &_M17;
        _M17 = 0;
        
        *_pdwStubPhase = STUB_CALL_SERVER;
        _RetVal = (((ICategorizerQueries*) ((CStdStubBuffer *)This)->pvServerObject)->lpVtbl) -> GetQueryString((ICategorizerQueries *) ((CStdStubBuffer *)This)->pvServerObject,ppszQueryString);
        
        *_pdwStubPhase = STUB_MARSHAL;
        
        _StubMsg.BufferLength = 16U + 11U;
        NdrPointerBufferSize( (PMIDL_STUB_MESSAGE) &_StubMsg,
                              (unsigned char __RPC_FAR *)ppszQueryString,
                              (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[224] );
        
        _StubMsg.BufferLength += 16;
        
        NdrStubGetBuffer(This, _pRpcChannelBuffer, &_StubMsg);
        NdrPointerMarshall( (PMIDL_STUB_MESSAGE)& _StubMsg,
                            (unsigned char __RPC_FAR *)ppszQueryString,
                            (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[224] );
        
        _StubMsg.Buffer = (unsigned char __RPC_FAR *)(((long)_StubMsg.Buffer + 3) & ~ 0x3);
        *(( HRESULT __RPC_FAR * )_StubMsg.Buffer)++ = _RetVal;
        
        }
    RpcFinally
        {
        NdrPointerFree( &_StubMsg,
                        (unsigned char __RPC_FAR *)ppszQueryString,
                        &__MIDL_TypeFormatString.Format[224] );
        
        }
    RpcEndFinally
    _pRpcMessage->BufferLength = 
        (unsigned int)(_StubMsg.Buffer - (unsigned char __RPC_FAR *)_pRpcMessage->Buffer);
    
}

const CINTERFACE_PROXY_VTABLE(5) _ICategorizerQueriesProxyVtbl = 
{
    &IID_ICategorizerQueries,
    IUnknown_QueryInterface_Proxy,
    IUnknown_AddRef_Proxy,
    IUnknown_Release_Proxy ,
    ICategorizerQueries_SetQueryString_Proxy ,
    ICategorizerQueries_GetQueryString_Proxy
};


static const PRPC_STUB_FUNCTION ICategorizerQueries_table[] =
{
    ICategorizerQueries_SetQueryString_Stub,
    ICategorizerQueries_GetQueryString_Stub
};

const CInterfaceStubVtbl _ICategorizerQueriesStubVtbl =
{
    &IID_ICategorizerQueries,
    0,
    5,
    &ICategorizerQueries_table[-3],
    CStdStubBuffer_METHODS
};


/* Standard interface: __MIDL_itf_SmtpEvent_0291, ver. 0.0,
   GUID={0x00000000,0x0000,0x0000,{0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00}} */


/* Object interface: ICategorizerMailMsgs, ver. 0.0,
   GUID={0x86F9DA80,0xEB6E,0x11d1,{0x9D,0xF3,0x00,0xC0,0x4F,0xA3,0x22,0xBA}} */


/* Standard interface: __MIDL_itf_SmtpEvent_0292, ver. 0.0,
   GUID={0x00000000,0x0000,0x0000,{0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00}} */


/* Object interface: ICategorizerItemAttributes, ver. 0.0,
   GUID={0x86F9DA7F,0xEB6E,0x11d1,{0x9D,0xF3,0x00,0xC0,0x4F,0xA3,0x22,0xBA}} */


extern const MIDL_STUB_DESC Object_StubDesc;


#pragma code_seg(".orpc")
const CINTERFACE_PROXY_VTABLE(15) _ICategorizerItemAttributesProxyVtbl = 
{
    &IID_ICategorizerItemAttributes,
    IUnknown_QueryInterface_Proxy,
    IUnknown_AddRef_Proxy,
    IUnknown_Release_Proxy ,
    0 /* ICategorizerItemAttributes_BeginAttributeEnumeration_Proxy */ ,
    0 /* ICategorizerItemAttributes_GetNextAttributeValue_Proxy */ ,
    0 /* ICategorizerItemAttributes_RewindAttributeEnumeration_Proxy */ ,
    0 /* ICategorizerItemAttributes_EndAttributeEnumeration_Proxy */ ,
    0 /* ICategorizerItemAttributes_BeginAttributeNameEnumeration_Proxy */ ,
    0 /* ICategorizerItemAttributes_GetNextAttributeName_Proxy */ ,
    0 /* ICategorizerItemAttributes_EndAttributeNameEnumeration_Proxy */ ,
    0 /* ICategorizerItemAttributes_GetTransportSinkID_Proxy */ ,
    0 /* ICategorizerItemAttributes_AggregateAttributes_Proxy */ ,
    0 /* ICategorizerItemAttributes_GetAllAttributeValues_Proxy */ ,
    0 /* ICategorizerItemAttributes_ReleaseAllAttributeValues_Proxy */ ,
    0 /* ICategorizerItemAttributes_CountAttributeValues_Proxy */
};


static const PRPC_STUB_FUNCTION ICategorizerItemAttributes_table[] =
{
    STUB_FORWARDING_FUNCTION,
    STUB_FORWARDING_FUNCTION,
    STUB_FORWARDING_FUNCTION,
    STUB_FORWARDING_FUNCTION,
    STUB_FORWARDING_FUNCTION,
    STUB_FORWARDING_FUNCTION,
    STUB_FORWARDING_FUNCTION,
    STUB_FORWARDING_FUNCTION,
    STUB_FORWARDING_FUNCTION,
    STUB_FORWARDING_FUNCTION,
    STUB_FORWARDING_FUNCTION,
    STUB_FORWARDING_FUNCTION
};

const CInterfaceStubVtbl _ICategorizerItemAttributesStubVtbl =
{
    &IID_ICategorizerItemAttributes,
    0,
    15,
    &ICategorizerItemAttributes_table[-3],
    CStdStubBuffer_METHODS
};


/* Object interface: ICategorizerItemRawAttributes, ver. 0.0,
   GUID={0x34C3D389,0x8FA7,0x11d2,{0x9E,0x16,0x00,0xC0,0x4F,0xA3,0x22,0xBA}} */


extern const MIDL_STUB_DESC Object_StubDesc;


#pragma code_seg(".orpc")
const CINTERFACE_PROXY_VTABLE(8) _ICategorizerItemRawAttributesProxyVtbl = 
{
    &IID_ICategorizerItemRawAttributes,
    IUnknown_QueryInterface_Proxy,
    IUnknown_AddRef_Proxy,
    IUnknown_Release_Proxy ,
    0 /* ICategorizerItemRawAttributes_BeginRawAttributeEnumeration_Proxy */ ,
    0 /* ICategorizerItemRawAttributes_GetNextRawAttributeValue_Proxy */ ,
    0 /* ICategorizerItemRawAttributes_RewindRawAttributeEnumeration_Proxy */ ,
    0 /* ICategorizerItemRawAttributes_EndRawAttributeEnumeration_Proxy */ ,
    0 /* ICategorizerItemRawAttributes_CountRawAttributeValues_Proxy */
};


static const PRPC_STUB_FUNCTION ICategorizerItemRawAttributes_table[] =
{
    STUB_FORWARDING_FUNCTION,
    STUB_FORWARDING_FUNCTION,
    STUB_FORWARDING_FUNCTION,
    STUB_FORWARDING_FUNCTION,
    STUB_FORWARDING_FUNCTION
};

const CInterfaceStubVtbl _ICategorizerItemRawAttributesStubVtbl =
{
    &IID_ICategorizerItemRawAttributes,
    0,
    8,
    &ICategorizerItemRawAttributes_table[-3],
    CStdStubBuffer_METHODS
};


/* Standard interface: __MIDL_itf_SmtpEvent_0294, ver. 0.0,
   GUID={0x00000000,0x0000,0x0000,{0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00}} */


/* Object interface: ICategorizerItem, ver. 0.0,
   GUID={0x86F9DA7C,0xEB6E,0x11d1,{0x9D,0xF3,0x00,0xC0,0x4F,0xA3,0x22,0xBA}} */


/* Object interface: ICategorizerAsyncContext, ver. 0.0,
   GUID={0x86F9DA7E,0xEB6E,0x11d1,{0x9D,0xF3,0x00,0xC0,0x4F,0xA3,0x22,0xBA}} */


extern const MIDL_STUB_DESC Object_StubDesc;


#pragma code_seg(".orpc")
const CINTERFACE_PROXY_VTABLE(4) _ICategorizerAsyncContextProxyVtbl = 
{
    &IID_ICategorizerAsyncContext,
    IUnknown_QueryInterface_Proxy,
    IUnknown_AddRef_Proxy,
    IUnknown_Release_Proxy ,
    0 /* ICategorizerAsyncContext_CompleteQuery_Proxy */
};


static const PRPC_STUB_FUNCTION ICategorizerAsyncContext_table[] =
{
    STUB_FORWARDING_FUNCTION
};

const CInterfaceStubVtbl _ICategorizerAsyncContextStubVtbl =
{
    &IID_ICategorizerAsyncContext,
    0,
    4,
    &ICategorizerAsyncContext_table[-3],
    CStdStubBuffer_METHODS
};


/* Object interface: ICategorizerListResolve, ver. 0.0,
   GUID={0x960252A4,0x0A3A,0x11d2,{0x9E,0x00,0x00,0xC0,0x4F,0xA3,0x22,0xBA}} */


extern const MIDL_STUB_DESC Object_StubDesc;


#pragma code_seg(".orpc")
const CINTERFACE_PROXY_VTABLE(7) _ICategorizerListResolveProxyVtbl = 
{
    &IID_ICategorizerListResolve,
    IUnknown_QueryInterface_Proxy,
    IUnknown_AddRef_Proxy,
    IUnknown_Release_Proxy ,
    0 /* ICategorizerListResolve_AllocICategorizerItem_Proxy */ ,
    0 /* ICategorizerListResolve_ResolveICategorizerItem_Proxy */ ,
    0 /* ICategorizerListResolve_SetListResolveStatus_Proxy */ ,
    0 /* ICategorizerListResolve_GetListResolveStatus_Proxy */
};


static const PRPC_STUB_FUNCTION ICategorizerListResolve_table[] =
{
    STUB_FORWARDING_FUNCTION,
    STUB_FORWARDING_FUNCTION,
    STUB_FORWARDING_FUNCTION,
    STUB_FORWARDING_FUNCTION
};

const CInterfaceStubVtbl _ICategorizerListResolveStubVtbl =
{
    &IID_ICategorizerListResolve,
    0,
    7,
    &ICategorizerListResolve_table[-3],
    CStdStubBuffer_METHODS
};


/* Object interface: IMailTransportCategorize, ver. 0.0,
   GUID={0x86F9DA7A,0xEB6E,0x11d1,{0x9D,0xF3,0x00,0xC0,0x4F,0xA3,0x22,0xBA}} */


extern const MIDL_STUB_DESC Object_StubDesc;


#pragma code_seg(".orpc")

HRESULT STDMETHODCALLTYPE IMailTransportCategorize_Register_Proxy( 
    IMailTransportCategorize __RPC_FAR * This,
    /* [in] */ ICategorizerParameters __RPC_FAR *__MIDL_0011)
{

    HRESULT _RetVal;
    
    RPC_MESSAGE _RpcMessage;
    
    MIDL_STUB_MESSAGE _StubMsg;
    
    RpcTryExcept
        {
        NdrProxyInitialize(
                      ( void __RPC_FAR *  )This,
                      ( PRPC_MESSAGE  )&_RpcMessage,
                      ( PMIDL_STUB_MESSAGE  )&_StubMsg,
                      ( PMIDL_STUB_DESC  )&Object_StubDesc,
                      3);
        
        
        
        RpcTryFinally
            {
            
            _StubMsg.BufferLength = 0U;
            NdrInterfacePointerBufferSize( (PMIDL_STUB_MESSAGE) &_StubMsg,
                                           (unsigned char __RPC_FAR *)__MIDL_0011,
                                           (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[232] );
            
            NdrProxyGetBuffer(This, &_StubMsg);
            NdrInterfacePointerMarshall( (PMIDL_STUB_MESSAGE)& _StubMsg,
                                         (unsigned char __RPC_FAR *)__MIDL_0011,
                                         (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[232] );
            
            NdrProxySendReceive(This, &_StubMsg);
            
            if ( (_RpcMessage.DataRepresentation & 0X0000FFFFUL) != NDR_LOCAL_DATA_REPRESENTATION )
                NdrConvert( (PMIDL_STUB_MESSAGE) &_StubMsg, (PFORMAT_STRING) &__MIDL_ProcFormatString.Format[178] );
            
            _RetVal = *(( HRESULT __RPC_FAR * )_StubMsg.Buffer)++;
            
            }
        RpcFinally
            {
            NdrProxyFreeBuffer(This, &_StubMsg);
            
            }
        RpcEndFinally
        
        }
    RpcExcept(_StubMsg.dwStubPhase != PROXY_SENDRECEIVE)
        {
        _RetVal = NdrProxyErrorHandler(RpcExceptionCode());
        }
    RpcEndExcept
    return _RetVal;
}

void __RPC_STUB IMailTransportCategorize_Register_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase)
{
    HRESULT _RetVal;
    MIDL_STUB_MESSAGE _StubMsg;
    ICategorizerParameters __RPC_FAR *__MIDL_0011;
    
NdrStubInitialize(
                     _pRpcMessage,
                     &_StubMsg,
                     &Object_StubDesc,
                     _pRpcChannelBuffer);
    __MIDL_0011 = 0;
    RpcTryFinally
        {
        if ( (_pRpcMessage->DataRepresentation & 0X0000FFFFUL) != NDR_LOCAL_DATA_REPRESENTATION )
            NdrConvert( (PMIDL_STUB_MESSAGE) &_StubMsg, (PFORMAT_STRING) &__MIDL_ProcFormatString.Format[178] );
        
        NdrInterfacePointerUnmarshall( (PMIDL_STUB_MESSAGE) &_StubMsg,
                                       (unsigned char __RPC_FAR * __RPC_FAR *)&__MIDL_0011,
                                       (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[232],
                                       (unsigned char)0 );
        
        
        *_pdwStubPhase = STUB_CALL_SERVER;
        _RetVal = (((IMailTransportCategorize*) ((CStdStubBuffer *)This)->pvServerObject)->lpVtbl) -> Register((IMailTransportCategorize *) ((CStdStubBuffer *)This)->pvServerObject,__MIDL_0011);
        
        *_pdwStubPhase = STUB_MARSHAL;
        
        _StubMsg.BufferLength = 4U;
        NdrStubGetBuffer(This, _pRpcChannelBuffer, &_StubMsg);
        *(( HRESULT __RPC_FAR * )_StubMsg.Buffer)++ = _RetVal;
        
        }
    RpcFinally
        {
        NdrInterfacePointerFree( &_StubMsg,
                                 (unsigned char __RPC_FAR *)__MIDL_0011,
                                 &__MIDL_TypeFormatString.Format[232] );
        
        }
    RpcEndFinally
    _pRpcMessage->BufferLength = 
        (unsigned int)(_StubMsg.Buffer - (unsigned char __RPC_FAR *)_pRpcMessage->Buffer);
    
}

const CINTERFACE_PROXY_VTABLE(13) _IMailTransportCategorizeProxyVtbl = 
{
    &IID_IMailTransportCategorize,
    IUnknown_QueryInterface_Proxy,
    IUnknown_AddRef_Proxy,
    IUnknown_Release_Proxy ,
    IMailTransportCategorize_Register_Proxy ,
    0 /* IMailTransportCategorize_BeginMessageCategorization_Proxy */ ,
    0 /* IMailTransportCategorize_EndMessageCategorization_Proxy */ ,
    0 /* IMailTransportCategorize_BuildQuery_Proxy */ ,
    0 /* IMailTransportCategorize_BuildQueries_Proxy */ ,
    0 /* IMailTransportCategorize_SendQuery_Proxy */ ,
    0 /* IMailTransportCategorize_SortQueryResult_Proxy */ ,
    0 /* IMailTransportCategorize_ProcessItem_Proxy */ ,
    0 /* IMailTransportCategorize_ExpandItem_Proxy */ ,
    0 /* IMailTransportCategorize_CompleteItem_Proxy */
};


static const PRPC_STUB_FUNCTION IMailTransportCategorize_table[] =
{
    IMailTransportCategorize_Register_Stub,
    STUB_FORWARDING_FUNCTION,
    STUB_FORWARDING_FUNCTION,
    STUB_FORWARDING_FUNCTION,
    STUB_FORWARDING_FUNCTION,
    STUB_FORWARDING_FUNCTION,
    STUB_FORWARDING_FUNCTION,
    STUB_FORWARDING_FUNCTION,
    STUB_FORWARDING_FUNCTION,
    STUB_FORWARDING_FUNCTION
};

const CInterfaceStubVtbl _IMailTransportCategorizeStubVtbl =
{
    &IID_IMailTransportCategorize,
    0,
    13,
    &IMailTransportCategorize_table[-3],
    CStdStubBuffer_METHODS
};


/* Object interface: ISMTPCategorizer, ver. 0.0,
   GUID={0xB23C35B8,0x9219,0x11d2,{0x9E,0x17,0x00,0xC0,0x4F,0xA3,0x22,0xBA}} */


/* Object interface: ISMTPCategorizerCompletion, ver. 0.0,
   GUID={0xB23C35B9,0x9219,0x11d2,{0x9E,0x17,0x00,0xC0,0x4F,0xA3,0x22,0xBA}} */


/* Object interface: ISMTPCategorizerDLCompletion, ver. 0.0,
   GUID={0xB23C35BA,0x9219,0x11d2,{0x9E,0x17,0x00,0xC0,0x4F,0xA3,0x22,0xBA}} */


/* Standard interface: __MIDL_itf_SmtpEvent_0301, ver. 0.0,
   GUID={0x00000000,0x0000,0x0000,{0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00}} */


/* Object interface: ICategorizerDomainInfo, ver. 0.0,
   GUID={0xE210EDC6,0xF27D,0x481f,{0x9D,0xFC,0x1C,0xA8,0x40,0x90,0x5F,0xD9}} */


/* Standard interface: __MIDL_itf_SmtpEvent_0302, ver. 0.0,
   GUID={0x00000000,0x0000,0x0000,{0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00}} */


static const MIDL_STUB_DESC Object_StubDesc = 
    {
    0,
    NdrOleAllocate,
    NdrOleFree,
    0,
    0,
    0,
    0,
    0,
    __MIDL_TypeFormatString.Format,
    1, /* -error bounds_check flag */
    0x10001, /* Ndr library version */
    0,
    0x5030118, /* MIDL Version 5.3.280 */
    0,
    0,
    0,  /* notify & notify_flag routine table */
    0x1, /* MIDL flag */
    0,  /* Reserved3 */
    0,  /* Reserved4 */
    0   /* Reserved5 */
    };

#pragma data_seg(".rdata")

#if !defined(__RPC_WIN32__)
#error  Invalid build platform for this stub.
#endif

static const MIDL_PROC_FORMAT_STRING __MIDL_ProcFormatString =
    {
        0,
        {
			
			0x4d,		/* FC_IN_PARAM */
#ifndef _ALPHA_
			0x1,		/* x86, MIPS & PPC stack size = 1 */
#else
			0x2,		/* Alpha stack size = 2 */
#endif
/*  2 */	NdrFcShort( 0x2 ),	/* Type Offset=2 */
/*  4 */	
			0x4d,		/* FC_IN_PARAM */
#ifndef _ALPHA_
			0x1,		/* x86, MIPS & PPC stack size = 1 */
#else
			0x2,		/* Alpha stack size = 2 */
#endif
/*  6 */	NdrFcShort( 0x2 ),	/* Type Offset=2 */
/*  8 */	
			0x4d,		/* FC_IN_PARAM */
#ifndef _ALPHA_
			0x1,		/* x86, MIPS & PPC stack size = 1 */
#else
			0x2,		/* Alpha stack size = 2 */
#endif
/* 10 */	NdrFcShort( 0x14 ),	/* Type Offset=20 */
/* 12 */	
			0x4d,		/* FC_IN_PARAM */
#ifndef _ALPHA_
			0x1,		/* x86, MIPS & PPC stack size = 1 */
#else
			0x2,		/* Alpha stack size = 2 */
#endif
/* 14 */	NdrFcShort( 0x26 ),	/* Type Offset=38 */
/* 16 */	0x53,		/* FC_RETURN_PARAM_BASETYPE */
			0x8,		/* FC_LONG */
/* 18 */	
			0x4d,		/* FC_IN_PARAM */
#ifndef _ALPHA_
			0x1,		/* x86, MIPS & PPC stack size = 1 */
#else
			0x2,		/* Alpha stack size = 2 */
#endif
/* 20 */	NdrFcShort( 0x38 ),	/* Type Offset=56 */
/* 22 */	
			0x4d,		/* FC_IN_PARAM */
#ifndef _ALPHA_
			0x1,		/* x86, MIPS & PPC stack size = 1 */
#else
			0x2,		/* Alpha stack size = 2 */
#endif
/* 24 */	NdrFcShort( 0x38 ),	/* Type Offset=56 */
/* 26 */	
			0x4d,		/* FC_IN_PARAM */
#ifndef _ALPHA_
			0x1,		/* x86, MIPS & PPC stack size = 1 */
#else
			0x2,		/* Alpha stack size = 2 */
#endif
/* 28 */	NdrFcShort( 0x4a ),	/* Type Offset=74 */
/* 30 */	
			0x4d,		/* FC_IN_PARAM */
#ifndef _ALPHA_
			0x1,		/* x86, MIPS & PPC stack size = 1 */
#else
			0x2,		/* Alpha stack size = 2 */
#endif
/* 32 */	NdrFcShort( 0x5c ),	/* Type Offset=92 */
/* 34 */	0x53,		/* FC_RETURN_PARAM_BASETYPE */
			0x8,		/* FC_LONG */
/* 36 */	
			0x4d,		/* FC_IN_PARAM */
#ifndef _ALPHA_
			0x1,		/* x86, MIPS & PPC stack size = 1 */
#else
			0x2,		/* Alpha stack size = 2 */
#endif
/* 38 */	NdrFcShort( 0x38 ),	/* Type Offset=56 */
/* 40 */	
			0x4d,		/* FC_IN_PARAM */
#ifndef _ALPHA_
			0x1,		/* x86, MIPS & PPC stack size = 1 */
#else
			0x2,		/* Alpha stack size = 2 */
#endif
/* 42 */	NdrFcShort( 0x38 ),	/* Type Offset=56 */
/* 44 */	
			0x4d,		/* FC_IN_PARAM */
#ifndef _ALPHA_
			0x1,		/* x86, MIPS & PPC stack size = 1 */
#else
			0x2,		/* Alpha stack size = 2 */
#endif
/* 46 */	NdrFcShort( 0x4a ),	/* Type Offset=74 */
/* 48 */	
			0x4d,		/* FC_IN_PARAM */
#ifndef _ALPHA_
			0x1,		/* x86, MIPS & PPC stack size = 1 */
#else
			0x2,		/* Alpha stack size = 2 */
#endif
/* 50 */	NdrFcShort( 0x6e ),	/* Type Offset=110 */
/* 52 */	0x53,		/* FC_RETURN_PARAM_BASETYPE */
			0x8,		/* FC_LONG */
/* 54 */	
			0x4d,		/* FC_IN_PARAM */
#ifndef _ALPHA_
			0x1,		/* x86, MIPS & PPC stack size = 1 */
#else
			0x2,		/* Alpha stack size = 2 */
#endif
/* 56 */	NdrFcShort( 0x38 ),	/* Type Offset=56 */
/* 58 */	
			0x4d,		/* FC_IN_PARAM */
#ifndef _ALPHA_
			0x1,		/* x86, MIPS & PPC stack size = 1 */
#else
			0x2,		/* Alpha stack size = 2 */
#endif
/* 60 */	NdrFcShort( 0x38 ),	/* Type Offset=56 */
/* 62 */	
			0x4d,		/* FC_IN_PARAM */
#ifndef _ALPHA_
			0x1,		/* x86, MIPS & PPC stack size = 1 */
#else
			0x2,		/* Alpha stack size = 2 */
#endif
/* 64 */	NdrFcShort( 0x4a ),	/* Type Offset=74 */
/* 66 */	
			0x4d,		/* FC_IN_PARAM */
#ifndef _ALPHA_
			0x1,		/* x86, MIPS & PPC stack size = 1 */
#else
			0x2,		/* Alpha stack size = 2 */
#endif
/* 68 */	NdrFcShort( 0x80 ),	/* Type Offset=128 */
/* 70 */	0x53,		/* FC_RETURN_PARAM_BASETYPE */
			0x8,		/* FC_LONG */
/* 72 */	0x4e,		/* FC_IN_PARAM_BASETYPE */
			0x8,		/* FC_LONG */
/* 74 */	0x53,		/* FC_RETURN_PARAM_BASETYPE */
			0x8,		/* FC_LONG */
/* 76 */	0x4e,		/* FC_IN_PARAM_BASETYPE */
			0x8,		/* FC_LONG */
/* 78 */	
			0x4d,		/* FC_IN_PARAM */
#ifndef _ALPHA_
			0x1,		/* x86, MIPS & PPC stack size = 1 */
#else
			0x2,		/* Alpha stack size = 2 */
#endif
/* 80 */	NdrFcShort( 0x92 ),	/* Type Offset=146 */
/* 82 */	0x53,		/* FC_RETURN_PARAM_BASETYPE */
			0x8,		/* FC_LONG */
/* 84 */	
			0x4d,		/* FC_IN_PARAM */
#ifndef _ALPHA_
			0x1,		/* x86, MIPS & PPC stack size = 1 */
#else
			0x2,		/* Alpha stack size = 2 */
#endif
/* 86 */	NdrFcShort( 0x4a ),	/* Type Offset=74 */
/* 88 */	
			0x51,		/* FC_OUT_PARAM */
#ifndef _ALPHA_
			0x1,		/* x86, MIPS & PPC stack size = 1 */
#else
			0x2,		/* Alpha stack size = 2 */
#endif
/* 90 */	NdrFcShort( 0xa4 ),	/* Type Offset=164 */
/* 92 */	0x53,		/* FC_RETURN_PARAM_BASETYPE */
			0x8,		/* FC_LONG */
/* 94 */	0x4e,		/* FC_IN_PARAM_BASETYPE */
			0x8,		/* FC_LONG */
/* 96 */	0x4e,		/* FC_IN_PARAM_BASETYPE */
			0x8,		/* FC_LONG */
/* 98 */	0x53,		/* FC_RETURN_PARAM_BASETYPE */
			0x8,		/* FC_LONG */
/* 100 */	
			0x4d,		/* FC_IN_PARAM */
#ifndef _ALPHA_
			0x1,		/* x86, MIPS & PPC stack size = 1 */
#else
			0x2,		/* Alpha stack size = 2 */
#endif
/* 102 */	NdrFcShort( 0xa8 ),	/* Type Offset=168 */
/* 104 */	0x53,		/* FC_RETURN_PARAM_BASETYPE */
			0x8,		/* FC_LONG */
/* 106 */	
			0x4d,		/* FC_IN_PARAM */
#ifndef _ALPHA_
			0x1,		/* x86, MIPS & PPC stack size = 1 */
#else
			0x2,		/* Alpha stack size = 2 */
#endif
/* 108 */	NdrFcShort( 0xa8 ),	/* Type Offset=168 */
/* 110 */	
			0x4d,		/* FC_IN_PARAM */
			0x4,		/* x86, alpha, MIPS & PPC stack size = 4 */
/* 112 */	NdrFcShort( 0xb2 ),	/* Type Offset=178 */
/* 114 */	0x4e,		/* FC_IN_PARAM_BASETYPE */
			0x8,		/* FC_LONG */
/* 116 */	
			0x4d,		/* FC_IN_PARAM */
#ifndef _ALPHA_
			0x1,		/* x86, MIPS & PPC stack size = 1 */
#else
			0x2,		/* Alpha stack size = 2 */
#endif
/* 118 */	NdrFcShort( 0xa8 ),	/* Type Offset=168 */
/* 120 */	0x4e,		/* FC_IN_PARAM_BASETYPE */
			0x8,		/* FC_LONG */
/* 122 */	0x4e,		/* FC_IN_PARAM_BASETYPE */
			0x8,		/* FC_LONG */
/* 124 */	
			0x4d,		/* FC_IN_PARAM */
#ifndef _ALPHA_
			0x1,		/* x86, MIPS & PPC stack size = 1 */
#else
			0x2,		/* Alpha stack size = 2 */
#endif
/* 126 */	NdrFcShort( 0xbe ),	/* Type Offset=190 */
/* 128 */	
			0x4d,		/* FC_IN_PARAM */
#ifndef _ALPHA_
			0x1,		/* x86, MIPS & PPC stack size = 1 */
#else
			0x2,		/* Alpha stack size = 2 */
#endif
/* 130 */	NdrFcShort( 0xca ),	/* Type Offset=202 */
/* 132 */	0x53,		/* FC_RETURN_PARAM_BASETYPE */
			0x8,		/* FC_LONG */
/* 134 */	
			0x4d,		/* FC_IN_PARAM */
#ifndef _ALPHA_
			0x1,		/* x86, MIPS & PPC stack size = 1 */
#else
			0x2,		/* Alpha stack size = 2 */
#endif
/* 136 */	NdrFcShort( 0xa8 ),	/* Type Offset=168 */
/* 138 */	
			0x4d,		/* FC_IN_PARAM */
			0x4,		/* x86, alpha, MIPS & PPC stack size = 4 */
/* 140 */	NdrFcShort( 0xb2 ),	/* Type Offset=178 */
/* 142 */	0x4e,		/* FC_IN_PARAM_BASETYPE */
			0x8,		/* FC_LONG */
/* 144 */	
			0x4d,		/* FC_IN_PARAM */
#ifndef _ALPHA_
			0x1,		/* x86, MIPS & PPC stack size = 1 */
#else
			0x2,		/* Alpha stack size = 2 */
#endif
/* 146 */	NdrFcShort( 0xa8 ),	/* Type Offset=168 */
/* 148 */	0x4e,		/* FC_IN_PARAM_BASETYPE */
			0x8,		/* FC_LONG */
/* 150 */	0x4e,		/* FC_IN_PARAM_BASETYPE */
			0x8,		/* FC_LONG */
/* 152 */	
			0x50,		/* FC_IN_OUT_PARAM */
#ifndef _ALPHA_
			0x1,		/* x86, MIPS & PPC stack size = 1 */
#else
			0x2,		/* Alpha stack size = 2 */
#endif
/* 154 */	NdrFcShort( 0xbe ),	/* Type Offset=190 */
/* 156 */	
			0x51,		/* FC_OUT_PARAM */
#ifndef _ALPHA_
			0x1,		/* x86, MIPS & PPC stack size = 1 */
#else
			0x2,		/* Alpha stack size = 2 */
#endif
/* 158 */	NdrFcShort( 0xa4 ),	/* Type Offset=164 */
/* 160 */	
			0x51,		/* FC_OUT_PARAM */
#ifndef _ALPHA_
			0x1,		/* x86, MIPS & PPC stack size = 1 */
#else
			0x2,		/* Alpha stack size = 2 */
#endif
/* 162 */	NdrFcShort( 0xa4 ),	/* Type Offset=164 */
/* 164 */	0x53,		/* FC_RETURN_PARAM_BASETYPE */
			0x8,		/* FC_LONG */
/* 166 */	
			0x4d,		/* FC_IN_PARAM */
#ifndef _ALPHA_
			0x1,		/* x86, MIPS & PPC stack size = 1 */
#else
			0x2,		/* Alpha stack size = 2 */
#endif
/* 168 */	NdrFcShort( 0xdc ),	/* Type Offset=220 */
/* 170 */	0x53,		/* FC_RETURN_PARAM_BASETYPE */
			0x8,		/* FC_LONG */
/* 172 */	
			0x51,		/* FC_OUT_PARAM */
#ifndef _ALPHA_
			0x1,		/* x86, MIPS & PPC stack size = 1 */
#else
			0x2,		/* Alpha stack size = 2 */
#endif
/* 174 */	NdrFcShort( 0xe0 ),	/* Type Offset=224 */
/* 176 */	0x53,		/* FC_RETURN_PARAM_BASETYPE */
			0x8,		/* FC_LONG */
/* 178 */	
			0x4d,		/* FC_IN_PARAM */
#ifndef _ALPHA_
			0x1,		/* x86, MIPS & PPC stack size = 1 */
#else
			0x2,		/* Alpha stack size = 2 */
#endif
/* 180 */	NdrFcShort( 0xe8 ),	/* Type Offset=232 */
/* 182 */	0x53,		/* FC_RETURN_PARAM_BASETYPE */
			0x8,		/* FC_LONG */

			0x0
        }
    };

static const MIDL_TYPE_FORMAT_STRING __MIDL_TypeFormatString =
    {
        0,
        {
			NdrFcShort( 0x0 ),	/* 0 */
/*  2 */	
			0x2f,		/* FC_IP */
			0x5a,		/* FC_CONSTANT_IID */
/*  4 */	NdrFcLong( 0x0 ),	/* 0 */
/*  8 */	NdrFcShort( 0x0 ),	/* 0 */
/* 10 */	NdrFcShort( 0x0 ),	/* 0 */
/* 12 */	0xc0,		/* 192 */
			0x0,		/* 0 */
/* 14 */	0x0,		/* 0 */
			0x0,		/* 0 */
/* 16 */	0x0,		/* 0 */
			0x0,		/* 0 */
/* 18 */	0x0,		/* 0 */
			0x46,		/* 70 */
/* 20 */	
			0x2f,		/* FC_IP */
			0x5a,		/* FC_CONSTANT_IID */
/* 22 */	NdrFcLong( 0xab95fb40 ),	/* -1416234176 */
/* 26 */	NdrFcShort( 0xa34f ),	/* -23729 */
/* 28 */	NdrFcShort( 0x11d1 ),	/* 4561 */
/* 30 */	0xaa,		/* 170 */
			0x8a,		/* 138 */
/* 32 */	0x0,		/* 0 */
			0xaa,		/* 170 */
/* 34 */	0x0,		/* 0 */
			0x6b,		/* 107 */
/* 36 */	0xc8,		/* 200 */
			0xb,		/* 11 */
/* 38 */	
			0x2f,		/* FC_IP */
			0x5a,		/* FC_CONSTANT_IID */
/* 40 */	NdrFcLong( 0x5f15c533 ),	/* 1595262259 */
/* 44 */	NdrFcShort( 0xe90e ),	/* -5874 */
/* 46 */	NdrFcShort( 0x11d1 ),	/* 4561 */
/* 48 */	0x88,		/* 136 */
			0x52,		/* 82 */
/* 50 */	0x0,		/* 0 */
			0xc0,		/* 192 */
/* 52 */	0x4f,		/* 79 */
			0xa3,		/* 163 */
/* 54 */	0x5b,		/* 91 */
			0x86,		/* 134 */
/* 56 */	
			0x2f,		/* FC_IP */
			0x5a,		/* FC_CONSTANT_IID */
/* 58 */	NdrFcLong( 0x0 ),	/* 0 */
/* 62 */	NdrFcShort( 0x0 ),	/* 0 */
/* 64 */	NdrFcShort( 0x0 ),	/* 0 */
/* 66 */	0xc0,		/* 192 */
			0x0,		/* 0 */
/* 68 */	0x0,		/* 0 */
			0x0,		/* 0 */
/* 70 */	0x0,		/* 0 */
			0x0,		/* 0 */
/* 72 */	0x0,		/* 0 */
			0x46,		/* 70 */
/* 74 */	
			0x2f,		/* FC_IP */
			0x5a,		/* FC_CONSTANT_IID */
/* 76 */	NdrFcLong( 0xab95fb40 ),	/* -1416234176 */
/* 80 */	NdrFcShort( 0xa34f ),	/* -23729 */
/* 82 */	NdrFcShort( 0x11d1 ),	/* 4561 */
/* 84 */	0xaa,		/* 170 */
			0x8a,		/* 138 */
/* 86 */	0x0,		/* 0 */
			0xaa,		/* 170 */
/* 88 */	0x0,		/* 0 */
			0x6b,		/* 107 */
/* 90 */	0xc8,		/* 200 */
			0xb,		/* 11 */
/* 92 */	
			0x2f,		/* FC_IP */
			0x5a,		/* FC_CONSTANT_IID */
/* 94 */	NdrFcLong( 0xc849b5f2 ),	/* -934693390 */
/* 98 */	NdrFcShort( 0xa80 ),	/* 2688 */
/* 100 */	NdrFcShort( 0x11d2 ),	/* 4562 */
/* 102 */	0xaa,		/* 170 */
			0x67,		/* 103 */
/* 104 */	0x0,		/* 0 */
			0xc0,		/* 192 */
/* 106 */	0x4f,		/* 79 */
			0xa3,		/* 163 */
/* 108 */	0x5b,		/* 91 */
			0x82,		/* 130 */
/* 110 */	
			0x2f,		/* FC_IP */
			0x5a,		/* FC_CONSTANT_IID */
/* 112 */	NdrFcLong( 0xe38f9ad2 ),	/* -477127982 */
/* 116 */	NdrFcShort( 0xa82 ),	/* 2690 */
/* 118 */	NdrFcShort( 0x11d2 ),	/* 4562 */
/* 120 */	0xaa,		/* 170 */
			0x67,		/* 103 */
/* 122 */	0x0,		/* 0 */
			0xc0,		/* 192 */
/* 124 */	0x4f,		/* 79 */
			0xa3,		/* 163 */
/* 126 */	0x5b,		/* 91 */
			0x82,		/* 130 */
/* 128 */	
			0x2f,		/* FC_IP */
			0x5a,		/* FC_CONSTANT_IID */
/* 130 */	NdrFcLong( 0x5e4fc9da ),	/* 1582287322 */
/* 134 */	NdrFcShort( 0x3e3b ),	/* 15931 */
/* 136 */	NdrFcShort( 0x11d3 ),	/* 4563 */
/* 138 */	0x88,		/* 136 */
			0xf1,		/* 241 */
/* 140 */	0x0,		/* 0 */
			0xc0,		/* 192 */
/* 142 */	0x4f,		/* 79 */
			0xa3,		/* 163 */
/* 144 */	0x5b,		/* 91 */
			0x86,		/* 134 */
/* 146 */	
			0x2f,		/* FC_IP */
			0x5a,		/* FC_CONSTANT_IID */
/* 148 */	NdrFcLong( 0xa928ad12 ),	/* -1456952046 */
/* 152 */	NdrFcShort( 0x1610 ),	/* 5648 */
/* 154 */	NdrFcShort( 0x11d2 ),	/* 4562 */
/* 156 */	0x9e,		/* 158 */
			0x2,		/* 2 */
/* 158 */	0x0,		/* 0 */
			0xc0,		/* 192 */
/* 160 */	0x4f,		/* 79 */
			0xa3,		/* 163 */
/* 162 */	0x22,		/* 34 */
			0xba,		/* 186 */
/* 164 */	
			0x11, 0xc,	/* FC_RP [alloced_on_stack] [simple_pointer] */
/* 166 */	0x8,		/* FC_LONG */
			0x5c,		/* FC_PAD */
/* 168 */	
			0x11, 0x8,	/* FC_RP [simple_pointer] */
/* 170 */	
			0x22,		/* FC_C_CSTRING */
			0x5c,		/* FC_PAD */
/* 172 */	
			0x1d,		/* FC_SMFARRAY */
			0x0,		/* 0 */
/* 174 */	NdrFcShort( 0x8 ),	/* 8 */
/* 176 */	0x2,		/* FC_CHAR */
			0x5b,		/* FC_END */
/* 178 */	
			0x15,		/* FC_STRUCT */
			0x3,		/* 3 */
/* 180 */	NdrFcShort( 0x10 ),	/* 16 */
/* 182 */	0x8,		/* FC_LONG */
			0x6,		/* FC_SHORT */
/* 184 */	0x6,		/* FC_SHORT */
			0x4c,		/* FC_EMBEDDED_COMPLEX */
/* 186 */	0x0,		/* 0 */
			NdrFcShort( 0xfffffff1 ),	/* Offset= -15 (172) */
			0x5b,		/* FC_END */
/* 190 */	
			0x11, 0x0,	/* FC_RP */
/* 192 */	NdrFcShort( 0x2 ),	/* Offset= 2 (194) */
/* 194 */	
			0x15,		/* FC_STRUCT */
			0x3,		/* 3 */
/* 196 */	NdrFcShort( 0x8 ),	/* 8 */
/* 198 */	0x8,		/* FC_LONG */
			0x8,		/* FC_LONG */
/* 200 */	0x5c,		/* FC_PAD */
			0x5b,		/* FC_END */
/* 202 */	
			0x2f,		/* FC_IP */
			0x5a,		/* FC_CONSTANT_IID */
/* 204 */	NdrFcLong( 0xa928ad14 ),	/* -1456952044 */
/* 208 */	NdrFcShort( 0x1610 ),	/* 5648 */
/* 210 */	NdrFcShort( 0x11d2 ),	/* 4562 */
/* 212 */	0x9e,		/* 158 */
			0x2,		/* 2 */
/* 214 */	0x0,		/* 0 */
			0xc0,		/* 192 */
/* 216 */	0x4f,		/* 79 */
			0xa3,		/* 163 */
/* 218 */	0x22,		/* 34 */
			0xba,		/* 186 */
/* 220 */	
			0x12, 0x8,	/* FC_UP [simple_pointer] */
/* 222 */	
			0x22,		/* FC_C_CSTRING */
			0x5c,		/* FC_PAD */
/* 224 */	
			0x11, 0x14,	/* FC_RP [alloced_on_stack] [pointer_deref] */
/* 226 */	NdrFcShort( 0x2 ),	/* Offset= 2 (228) */
/* 228 */	
			0x13, 0x8,	/* FC_OP [simple_pointer] */
/* 230 */	
			0x22,		/* FC_C_CSTRING */
			0x5c,		/* FC_PAD */
/* 232 */	
			0x2f,		/* FC_IP */
			0x5a,		/* FC_CONSTANT_IID */
/* 234 */	NdrFcLong( 0x86f9da7b ),	/* -2030445957 */
/* 238 */	NdrFcShort( 0xeb6e ),	/* -5266 */
/* 240 */	NdrFcShort( 0x11d1 ),	/* 4561 */
/* 242 */	0x9d,		/* 157 */
			0xf3,		/* 243 */
/* 244 */	0x0,		/* 0 */
			0xc0,		/* 192 */
/* 246 */	0x4f,		/* 79 */
			0xa3,		/* 163 */
/* 248 */	0x22,		/* 34 */
			0xba,		/* 186 */

			0x0
        }
    };

const CInterfaceProxyVtbl * _SmtpEvent_ProxyVtblList[] = 
{
    ( CInterfaceProxyVtbl *) &_ISmtpInCommandSinkProxyVtbl,
    ( CInterfaceProxyVtbl *) &_IMailTransportOnPreCategorizeProxyVtbl,
    ( CInterfaceProxyVtbl *) &_IMailTransportSetRouterResetProxyVtbl,
    ( CInterfaceProxyVtbl *) &_IMailTransportRouterResetProxyVtbl,
    ( CInterfaceProxyVtbl *) &_IMailTransportRoutingEngineProxyVtbl,
    ( CInterfaceProxyVtbl *) &_IMessageRouterProxyVtbl,
    ( CInterfaceProxyVtbl *) &_IMailTransportSubmissionProxyVtbl,
    ( CInterfaceProxyVtbl *) &_ISmtpServerResponseSinkProxyVtbl,
    ( CInterfaceProxyVtbl *) &_ISmtpInCallbackSinkProxyVtbl,
    ( CInterfaceProxyVtbl *) &_IMailTransportRouterSetLinkStateProxyVtbl,
    ( CInterfaceProxyVtbl *) &_IMessageRouterLinkStateNotificationProxyVtbl,
    ( CInterfaceProxyVtbl *) &_IMailTransportOnPostCategorizeProxyVtbl,
    ( CInterfaceProxyVtbl *) &_IMailTransportNotifyProxyVtbl,
    ( CInterfaceProxyVtbl *) &_IMailTransportCategorizeProxyVtbl,
    ( CInterfaceProxyVtbl *) &_ICategorizerQueriesProxyVtbl,
    ( CInterfaceProxyVtbl *) &_ICategorizerAsyncContextProxyVtbl,
    ( CInterfaceProxyVtbl *) &_ICategorizerItemAttributesProxyVtbl,
    ( CInterfaceProxyVtbl *) &_ICategorizerItemRawAttributesProxyVtbl,
    ( CInterfaceProxyVtbl *) &_ICategorizerListResolveProxyVtbl,
    ( CInterfaceProxyVtbl *) &_ISmtpOutCommandSinkProxyVtbl,
    0
};

const CInterfaceStubVtbl * _SmtpEvent_StubVtblList[] = 
{
    ( CInterfaceStubVtbl *) &_ISmtpInCommandSinkStubVtbl,
    ( CInterfaceStubVtbl *) &_IMailTransportOnPreCategorizeStubVtbl,
    ( CInterfaceStubVtbl *) &_IMailTransportSetRouterResetStubVtbl,
    ( CInterfaceStubVtbl *) &_IMailTransportRouterResetStubVtbl,
    ( CInterfaceStubVtbl *) &_IMailTransportRoutingEngineStubVtbl,
    ( CInterfaceStubVtbl *) &_IMessageRouterStubVtbl,
    ( CInterfaceStubVtbl *) &_IMailTransportSubmissionStubVtbl,
    ( CInterfaceStubVtbl *) &_ISmtpServerResponseSinkStubVtbl,
    ( CInterfaceStubVtbl *) &_ISmtpInCallbackSinkStubVtbl,
    ( CInterfaceStubVtbl *) &_IMailTransportRouterSetLinkStateStubVtbl,
    ( CInterfaceStubVtbl *) &_IMessageRouterLinkStateNotificationStubVtbl,
    ( CInterfaceStubVtbl *) &_IMailTransportOnPostCategorizeStubVtbl,
    ( CInterfaceStubVtbl *) &_IMailTransportNotifyStubVtbl,
    ( CInterfaceStubVtbl *) &_IMailTransportCategorizeStubVtbl,
    ( CInterfaceStubVtbl *) &_ICategorizerQueriesStubVtbl,
    ( CInterfaceStubVtbl *) &_ICategorizerAsyncContextStubVtbl,
    ( CInterfaceStubVtbl *) &_ICategorizerItemAttributesStubVtbl,
    ( CInterfaceStubVtbl *) &_ICategorizerItemRawAttributesStubVtbl,
    ( CInterfaceStubVtbl *) &_ICategorizerListResolveStubVtbl,
    ( CInterfaceStubVtbl *) &_ISmtpOutCommandSinkStubVtbl,
    0
};

PCInterfaceName const _SmtpEvent_InterfaceNamesList[] = 
{
    "ISmtpInCommandSink",
    "IMailTransportOnPreCategorize",
    "IMailTransportSetRouterReset",
    "IMailTransportRouterReset",
    "IMailTransportRoutingEngine",
    "IMessageRouter",
    "IMailTransportSubmission",
    "ISmtpServerResponseSink",
    "ISmtpInCallbackSink",
    "IMailTransportRouterSetLinkState",
    "IMessageRouterLinkStateNotification",
    "IMailTransportOnPostCategorize",
    "IMailTransportNotify",
    "IMailTransportCategorize",
    "ICategorizerQueries",
    "ICategorizerAsyncContext",
    "ICategorizerItemAttributes",
    "ICategorizerItemRawAttributes",
    "ICategorizerListResolve",
    "ISmtpOutCommandSink",
    0
};


#define _SmtpEvent_CHECK_IID(n)	IID_GENERIC_CHECK_IID( _SmtpEvent, pIID, n)

int __stdcall _SmtpEvent_IID_Lookup( const IID * pIID, int * pIndex )
{
    IID_BS_LOOKUP_SETUP

    IID_BS_LOOKUP_INITIAL_TEST( _SmtpEvent, 20, 16 )
    IID_BS_LOOKUP_NEXT_TEST( _SmtpEvent, 8 )
    IID_BS_LOOKUP_NEXT_TEST( _SmtpEvent, 4 )
    IID_BS_LOOKUP_NEXT_TEST( _SmtpEvent, 2 )
    IID_BS_LOOKUP_NEXT_TEST( _SmtpEvent, 1 )
    IID_BS_LOOKUP_RETURN_RESULT( _SmtpEvent, 20, *pIndex )
    
}

const ExtendedProxyFileInfo SmtpEvent_ProxyFileInfo = 
{
    (PCInterfaceProxyVtblList *) & _SmtpEvent_ProxyVtblList,
    (PCInterfaceStubVtblList *) & _SmtpEvent_StubVtblList,
    (const PCInterfaceName * ) & _SmtpEvent_InterfaceNamesList,
    0, // no delegation
    & _SmtpEvent_IID_Lookup, 
    20,
    1,
    0, /* table of [async_uuid] interfaces */
    0, /* Filler1 */
    0, /* Filler2 */
    0  /* Filler3 */
};


#endif /* !defined(_M_IA64) && !defined(_M_AXP64)*/


#pragma warning( disable: 4049 )  /* more than 64k source lines */

/* this ALWAYS GENERATED file contains the proxy stub code */


 /* File created by MIDL compiler version 5.03.0280 */
/* at Mon Nov 06 14:26:24 2000
 */
/* Compiler settings for D:\Program Files\Microsoft Platform SDK\Include\SmtpEvent.Idl:
    Oicf (OptLev=i2), W1, Zp8, env=Win64 (32b run,appending), ms_ext, c_ext, robust
    error checks: allocation ref bounds_check enum stub_data 
    VC __declspec() decoration level: 
         __declspec(uuid()), __declspec(selectany), __declspec(novtable)
         DECLSPEC_UUID(), MIDL_INTERFACE()
*/
//@@MIDL_FILE_HEADING(  )

#if defined(_M_IA64) || defined(_M_AXP64)
#define USE_STUBLESS_PROXY


/* verify that the <rpcproxy.h> version is high enough to compile this file*/
#ifndef __REDQ_RPCPROXY_H_VERSION__
#define __REQUIRED_RPCPROXY_H_VERSION__ 475
#endif


#include "rpcproxy.h"
#ifndef __RPCPROXY_H_VERSION__
#error this stub requires an updated version of <rpcproxy.h>
#endif // __RPCPROXY_H_VERSION__


#include "SmtpEvent.h"

#define TYPE_FORMAT_STRING_SIZE   251                               
#define PROC_FORMAT_STRING_SIZE   713                               
#define TRANSMIT_AS_TABLE_SIZE    0            
#define WIRE_MARSHAL_TABLE_SIZE   0            

typedef struct _MIDL_TYPE_FORMAT_STRING
    {
    short          Pad;
    unsigned char  Format[ TYPE_FORMAT_STRING_SIZE ];
    } MIDL_TYPE_FORMAT_STRING;

typedef struct _MIDL_PROC_FORMAT_STRING
    {
    short          Pad;
    unsigned char  Format[ PROC_FORMAT_STRING_SIZE ];
    } MIDL_PROC_FORMAT_STRING;


extern const MIDL_TYPE_FORMAT_STRING __MIDL_TypeFormatString;
extern const MIDL_PROC_FORMAT_STRING __MIDL_ProcFormatString;


/* Standard interface: __MIDL_itf_SmtpEvent_0000, ver. 0.0,
   GUID={0x00000000,0x0000,0x0000,{0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00}} */


/* Object interface: IUnknown, ver. 0.0,
   GUID={0x00000000,0x0000,0x0000,{0xC0,0x00,0x00,0x00,0x00,0x00,0x00,0x46}} */


/* Object interface: ISmtpInCommandContext, ver. 0.0,
   GUID={0x5F15C533,0xE90E,0x11D1,{0x88,0x52,0x00,0xC0,0x4F,0xA3,0x5B,0x86}} */


/* Object interface: ISmtpInCallbackContext, ver. 0.0,
   GUID={0x5e4fc9da,0x3e3b,0x11d3,{0x88,0xf1,0x00,0xc0,0x4f,0xa3,0x5b,0x86}} */


/* Object interface: ISmtpOutCommandContext, ver. 0.0,
   GUID={0xc849b5f2,0x0a80,0x11d2,{0xaa,0x67,0x00,0xc0,0x4f,0xa3,0x5b,0x82}} */


/* Object interface: ISmtpServerResponseContext, ver. 0.0,
   GUID={0xe38f9ad2,0x0a82,0x11d2,{0xaa,0x67,0x00,0xc0,0x4f,0xa3,0x5b,0x82}} */


/* Object interface: ISmtpInCommandSink, ver. 0.0,
   GUID={0xb2d42a0e,0x0d5f,0x11d2,{0xaa,0x68,0x00,0xc0,0x4f,0xa3,0x5b,0x82}} */


extern const MIDL_STUB_DESC Object_StubDesc;


extern const MIDL_SERVER_INFO ISmtpInCommandSink_ServerInfo;

#pragma code_seg(".orpc")
static const unsigned short ISmtpInCommandSink_FormatStringOffsetTable[] = 
    {
    0
    };

static const MIDL_SERVER_INFO ISmtpInCommandSink_ServerInfo = 
    {
    &Object_StubDesc,
    0,
    __MIDL_ProcFormatString.Format,
    &ISmtpInCommandSink_FormatStringOffsetTable[-3],
    0,
    0,
    0,
    0
    };

static const MIDL_STUBLESS_PROXY_INFO ISmtpInCommandSink_ProxyInfo =
    {
    &Object_StubDesc,
    __MIDL_ProcFormatString.Format,
    &ISmtpInCommandSink_FormatStringOffsetTable[-3],
    0,
    0,
    0
    };

CINTERFACE_PROXY_VTABLE(4) _ISmtpInCommandSinkProxyVtbl = 
{
    &ISmtpInCommandSink_ProxyInfo,
    &IID_ISmtpInCommandSink,
    IUnknown_QueryInterface_Proxy,
    IUnknown_AddRef_Proxy,
    IUnknown_Release_Proxy ,
    (void *)-1 /* ISmtpInCommandSink::OnSmtpInCommand */
};

const CInterfaceStubVtbl _ISmtpInCommandSinkStubVtbl =
{
    &IID_ISmtpInCommandSink,
    &ISmtpInCommandSink_ServerInfo,
    4,
    0, /* pure interpreted */
    CStdStubBuffer_METHODS
};


/* Object interface: ISmtpOutCommandSink, ver. 0.0,
   GUID={0xcfdbb9b0,0x0ca0,0x11d2,{0xaa,0x68,0x00,0xc0,0x4f,0xa3,0x5b,0x82}} */


extern const MIDL_STUB_DESC Object_StubDesc;


extern const MIDL_SERVER_INFO ISmtpOutCommandSink_ServerInfo;

#pragma code_seg(".orpc")
static const unsigned short ISmtpOutCommandSink_FormatStringOffsetTable[] = 
    {
    56
    };

static const MIDL_SERVER_INFO ISmtpOutCommandSink_ServerInfo = 
    {
    &Object_StubDesc,
    0,
    __MIDL_ProcFormatString.Format,
    &ISmtpOutCommandSink_FormatStringOffsetTable[-3],
    0,
    0,
    0,
    0
    };

static const MIDL_STUBLESS_PROXY_INFO ISmtpOutCommandSink_ProxyInfo =
    {
    &Object_StubDesc,
    __MIDL_ProcFormatString.Format,
    &ISmtpOutCommandSink_FormatStringOffsetTable[-3],
    0,
    0,
    0
    };

CINTERFACE_PROXY_VTABLE(4) _ISmtpOutCommandSinkProxyVtbl = 
{
    &ISmtpOutCommandSink_ProxyInfo,
    &IID_ISmtpOutCommandSink,
    IUnknown_QueryInterface_Proxy,
    IUnknown_AddRef_Proxy,
    IUnknown_Release_Proxy ,
    (void *)-1 /* ISmtpOutCommandSink::OnSmtpOutCommand */
};

const CInterfaceStubVtbl _ISmtpOutCommandSinkStubVtbl =
{
    &IID_ISmtpOutCommandSink,
    &ISmtpOutCommandSink_ServerInfo,
    4,
    0, /* pure interpreted */
    CStdStubBuffer_METHODS
};


/* Object interface: ISmtpServerResponseSink, ver. 0.0,
   GUID={0xd7e10222,0x0ca1,0x11d2,{0xaa,0x68,0x00,0xc0,0x4f,0xa3,0x5b,0x82}} */


extern const MIDL_STUB_DESC Object_StubDesc;


extern const MIDL_SERVER_INFO ISmtpServerResponseSink_ServerInfo;

#pragma code_seg(".orpc")
static const unsigned short ISmtpServerResponseSink_FormatStringOffsetTable[] = 
    {
    112
    };

static const MIDL_SERVER_INFO ISmtpServerResponseSink_ServerInfo = 
    {
    &Object_StubDesc,
    0,
    __MIDL_ProcFormatString.Format,
    &ISmtpServerResponseSink_FormatStringOffsetTable[-3],
    0,
    0,
    0,
    0
    };

static const MIDL_STUBLESS_PROXY_INFO ISmtpServerResponseSink_ProxyInfo =
    {
    &Object_StubDesc,
    __MIDL_ProcFormatString.Format,
    &ISmtpServerResponseSink_FormatStringOffsetTable[-3],
    0,
    0,
    0
    };

CINTERFACE_PROXY_VTABLE(4) _ISmtpServerResponseSinkProxyVtbl = 
{
    &ISmtpServerResponseSink_ProxyInfo,
    &IID_ISmtpServerResponseSink,
    IUnknown_QueryInterface_Proxy,
    IUnknown_AddRef_Proxy,
    IUnknown_Release_Proxy ,
    (void *)-1 /* ISmtpServerResponseSink::OnSmtpServerResponse */
};

const CInterfaceStubVtbl _ISmtpServerResponseSinkStubVtbl =
{
    &IID_ISmtpServerResponseSink,
    &ISmtpServerResponseSink_ServerInfo,
    4,
    0, /* pure interpreted */
    CStdStubBuffer_METHODS
};


/* Object interface: ISmtpInCallbackSink, ver. 0.0,
   GUID={0x0012b624,0x3e3c,0x11d3,{0x88,0xf1,0x00,0xc0,0x4f,0xa3,0x5b,0x86}} */


extern const MIDL_STUB_DESC Object_StubDesc;


extern const MIDL_SERVER_INFO ISmtpInCallbackSink_ServerInfo;

#pragma code_seg(".orpc")
static const unsigned short ISmtpInCallbackSink_FormatStringOffsetTable[] = 
    {
    168
    };

static const MIDL_SERVER_INFO ISmtpInCallbackSink_ServerInfo = 
    {
    &Object_StubDesc,
    0,
    __MIDL_ProcFormatString.Format,
    &ISmtpInCallbackSink_FormatStringOffsetTable[-3],
    0,
    0,
    0,
    0
    };

static const MIDL_STUBLESS_PROXY_INFO ISmtpInCallbackSink_ProxyInfo =
    {
    &Object_StubDesc,
    __MIDL_ProcFormatString.Format,
    &ISmtpInCallbackSink_FormatStringOffsetTable[-3],
    0,
    0,
    0
    };

CINTERFACE_PROXY_VTABLE(4) _ISmtpInCallbackSinkProxyVtbl = 
{
    &ISmtpInCallbackSink_ProxyInfo,
    &IID_ISmtpInCallbackSink,
    IUnknown_QueryInterface_Proxy,
    IUnknown_AddRef_Proxy,
    IUnknown_Release_Proxy ,
    (void *)-1 /* ISmtpInCallbackSink::OnSmtpInCallback */
};

const CInterfaceStubVtbl _ISmtpInCallbackSinkStubVtbl =
{
    &IID_ISmtpInCallbackSink,
    &ISmtpInCallbackSink_ServerInfo,
    4,
    0, /* pure interpreted */
    CStdStubBuffer_METHODS
};


/* Standard interface: __MIDL_itf_SmtpEvent_0274, ver. 0.0,
   GUID={0x00000000,0x0000,0x0000,{0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00}} */


/* Object interface: IMailTransportNotify, ver. 0.0,
   GUID={0x6E1CAA77,0xFCD4,0x11d1,{0x9D,0xF9,0x00,0xC0,0x4F,0xA3,0x22,0xBA}} */


extern const MIDL_STUB_DESC Object_StubDesc;


extern const MIDL_SERVER_INFO IMailTransportNotify_ServerInfo;

#pragma code_seg(".orpc")
static const unsigned short IMailTransportNotify_FormatStringOffsetTable[] = 
    {
    (unsigned short) -1
    };

static const MIDL_SERVER_INFO IMailTransportNotify_ServerInfo = 
    {
    &Object_StubDesc,
    0,
    __MIDL_ProcFormatString.Format,
    &IMailTransportNotify_FormatStringOffsetTable[-3],
    0,
    0,
    0,
    0
    };

static const MIDL_STUBLESS_PROXY_INFO IMailTransportNotify_ProxyInfo =
    {
    &Object_StubDesc,
    __MIDL_ProcFormatString.Format,
    &IMailTransportNotify_FormatStringOffsetTable[-3],
    0,
    0,
    0
    };

CINTERFACE_PROXY_VTABLE(4) _IMailTransportNotifyProxyVtbl = 
{
    &IMailTransportNotify_ProxyInfo,
    &IID_IMailTransportNotify,
    IUnknown_QueryInterface_Proxy,
    IUnknown_AddRef_Proxy,
    IUnknown_Release_Proxy ,
    0 /* (void *)-1 /* IMailTransportNotify::Notify */
};

const CInterfaceStubVtbl _IMailTransportNotifyStubVtbl =
{
    &IID_IMailTransportNotify,
    &IMailTransportNotify_ServerInfo,
    4,
    0, /* pure interpreted */
    CStdStubBuffer_METHODS
};


/* Object interface: IMailTransportSubmission, ver. 0.0,
   GUID={0xCE681916,0xFF14,0x11d1,{0x9D,0xFB,0x00,0xC0,0x4F,0xA3,0x22,0xBA}} */


extern const MIDL_STUB_DESC Object_StubDesc;


extern const MIDL_SERVER_INFO IMailTransportSubmission_ServerInfo;

#pragma code_seg(".orpc")
static const unsigned short IMailTransportSubmission_FormatStringOffsetTable[] = 
    {
    (unsigned short) -1
    };

static const MIDL_SERVER_INFO IMailTransportSubmission_ServerInfo = 
    {
    &Object_StubDesc,
    0,
    __MIDL_ProcFormatString.Format,
    &IMailTransportSubmission_FormatStringOffsetTable[-3],
    0,
    0,
    0,
    0
    };

static const MIDL_STUBLESS_PROXY_INFO IMailTransportSubmission_ProxyInfo =
    {
    &Object_StubDesc,
    __MIDL_ProcFormatString.Format,
    &IMailTransportSubmission_FormatStringOffsetTable[-3],
    0,
    0,
    0
    };

CINTERFACE_PROXY_VTABLE(4) _IMailTransportSubmissionProxyVtbl = 
{
    &IMailTransportSubmission_ProxyInfo,
    &IID_IMailTransportSubmission,
    IUnknown_QueryInterface_Proxy,
    IUnknown_AddRef_Proxy,
    IUnknown_Release_Proxy ,
    0 /* (void *)-1 /* IMailTransportSubmission::OnMessageSubmission */
};

const CInterfaceStubVtbl _IMailTransportSubmissionStubVtbl =
{
    &IID_IMailTransportSubmission,
    &IMailTransportSubmission_ServerInfo,
    4,
    0, /* pure interpreted */
    CStdStubBuffer_METHODS
};


/* Object interface: IMailTransportOnPreCategorize, ver. 0.0,
   GUID={0xA3ACFB0E,0x83FF,0x11d2,{0x9E,0x14,0x00,0xC0,0x4F,0xA3,0x22,0xBA}} */


extern const MIDL_STUB_DESC Object_StubDesc;


extern const MIDL_SERVER_INFO IMailTransportOnPreCategorize_ServerInfo;

#pragma code_seg(".orpc")
static const unsigned short IMailTransportOnPreCategorize_FormatStringOffsetTable[] = 
    {
    (unsigned short) -1
    };

static const MIDL_SERVER_INFO IMailTransportOnPreCategorize_ServerInfo = 
    {
    &Object_StubDesc,
    0,
    __MIDL_ProcFormatString.Format,
    &IMailTransportOnPreCategorize_FormatStringOffsetTable[-3],
    0,
    0,
    0,
    0
    };

static const MIDL_STUBLESS_PROXY_INFO IMailTransportOnPreCategorize_ProxyInfo =
    {
    &Object_StubDesc,
    __MIDL_ProcFormatString.Format,
    &IMailTransportOnPreCategorize_FormatStringOffsetTable[-3],
    0,
    0,
    0
    };

CINTERFACE_PROXY_VTABLE(4) _IMailTransportOnPreCategorizeProxyVtbl = 
{
    &IMailTransportOnPreCategorize_ProxyInfo,
    &IID_IMailTransportOnPreCategorize,
    IUnknown_QueryInterface_Proxy,
    IUnknown_AddRef_Proxy,
    IUnknown_Release_Proxy ,
    0 /* (void *)-1 /* IMailTransportOnPreCategorize::OnSyncMessagePreCategorize */
};

const CInterfaceStubVtbl _IMailTransportOnPreCategorizeStubVtbl =
{
    &IID_IMailTransportOnPreCategorize,
    &IMailTransportOnPreCategorize_ServerInfo,
    4,
    0, /* pure interpreted */
    CStdStubBuffer_METHODS
};


/* Object interface: IMailTransportOnPostCategorize, ver. 0.0,
   GUID={0x76719653,0x05A6,0x11d2,{0x9D,0xFD,0x00,0xC0,0x4F,0xA3,0x22,0xBA}} */


extern const MIDL_STUB_DESC Object_StubDesc;


extern const MIDL_SERVER_INFO IMailTransportOnPostCategorize_ServerInfo;

#pragma code_seg(".orpc")
static const unsigned short IMailTransportOnPostCategorize_FormatStringOffsetTable[] = 
    {
    (unsigned short) -1
    };

static const MIDL_SERVER_INFO IMailTransportOnPostCategorize_ServerInfo = 
    {
    &Object_StubDesc,
    0,
    __MIDL_ProcFormatString.Format,
    &IMailTransportOnPostCategorize_FormatStringOffsetTable[-3],
    0,
    0,
    0,
    0
    };

static const MIDL_STUBLESS_PROXY_INFO IMailTransportOnPostCategorize_ProxyInfo =
    {
    &Object_StubDesc,
    __MIDL_ProcFormatString.Format,
    &IMailTransportOnPostCategorize_FormatStringOffsetTable[-3],
    0,
    0,
    0
    };

CINTERFACE_PROXY_VTABLE(4) _IMailTransportOnPostCategorizeProxyVtbl = 
{
    &IMailTransportOnPostCategorize_ProxyInfo,
    &IID_IMailTransportOnPostCategorize,
    IUnknown_QueryInterface_Proxy,
    IUnknown_AddRef_Proxy,
    IUnknown_Release_Proxy ,
    0 /* (void *)-1 /* IMailTransportOnPostCategorize::OnMessagePostCategorize */
};

const CInterfaceStubVtbl _IMailTransportOnPostCategorizeStubVtbl =
{
    &IID_IMailTransportOnPostCategorize,
    &IMailTransportOnPostCategorize_ServerInfo,
    4,
    0, /* pure interpreted */
    CStdStubBuffer_METHODS
};


/* Standard interface: __MIDL_itf_SmtpEvent_0278, ver. 0.0,
   GUID={0x00000000,0x0000,0x0000,{0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00}} */


/* Object interface: IMailTransportRouterReset, ver. 0.0,
   GUID={0xA928AD12,0x1610,0x11d2,{0x9E,0x02,0x00,0xC0,0x4F,0xA3,0x22,0xBA}} */


extern const MIDL_STUB_DESC Object_StubDesc;


extern const MIDL_SERVER_INFO IMailTransportRouterReset_ServerInfo;

#pragma code_seg(".orpc")
static const unsigned short IMailTransportRouterReset_FormatStringOffsetTable[] = 
    {
    224
    };

static const MIDL_SERVER_INFO IMailTransportRouterReset_ServerInfo = 
    {
    &Object_StubDesc,
    0,
    __MIDL_ProcFormatString.Format,
    &IMailTransportRouterReset_FormatStringOffsetTable[-3],
    0,
    0,
    0,
    0
    };

static const MIDL_STUBLESS_PROXY_INFO IMailTransportRouterReset_ProxyInfo =
    {
    &Object_StubDesc,
    __MIDL_ProcFormatString.Format,
    &IMailTransportRouterReset_FormatStringOffsetTable[-3],
    0,
    0,
    0
    };

CINTERFACE_PROXY_VTABLE(4) _IMailTransportRouterResetProxyVtbl = 
{
    &IMailTransportRouterReset_ProxyInfo,
    &IID_IMailTransportRouterReset,
    IUnknown_QueryInterface_Proxy,
    IUnknown_AddRef_Proxy,
    IUnknown_Release_Proxy ,
    (void *)-1 /* IMailTransportRouterReset::ResetRoutes */
};

const CInterfaceStubVtbl _IMailTransportRouterResetStubVtbl =
{
    &IID_IMailTransportRouterReset,
    &IMailTransportRouterReset_ServerInfo,
    4,
    0, /* pure interpreted */
    CStdStubBuffer_METHODS
};


/* Object interface: IMailTransportSetRouterReset, ver. 0.0,
   GUID={0xA928AD11,0x1610,0x11d2,{0x9E,0x02,0x00,0xC0,0x4F,0xA3,0x22,0xBA}} */


extern const MIDL_STUB_DESC Object_StubDesc;


extern const MIDL_SERVER_INFO IMailTransportSetRouterReset_ServerInfo;

#pragma code_seg(".orpc")
static const unsigned short IMailTransportSetRouterReset_FormatStringOffsetTable[] = 
    {
    262
    };

static const MIDL_SERVER_INFO IMailTransportSetRouterReset_ServerInfo = 
    {
    &Object_StubDesc,
    0,
    __MIDL_ProcFormatString.Format,
    &IMailTransportSetRouterReset_FormatStringOffsetTable[-3],
    0,
    0,
    0,
    0
    };

static const MIDL_STUBLESS_PROXY_INFO IMailTransportSetRouterReset_ProxyInfo =
    {
    &Object_StubDesc,
    __MIDL_ProcFormatString.Format,
    &IMailTransportSetRouterReset_FormatStringOffsetTable[-3],
    0,
    0,
    0
    };

CINTERFACE_PROXY_VTABLE(4) _IMailTransportSetRouterResetProxyVtbl = 
{
    &IMailTransportSetRouterReset_ProxyInfo,
    &IID_IMailTransportSetRouterReset,
    IUnknown_QueryInterface_Proxy,
    IUnknown_AddRef_Proxy,
    IUnknown_Release_Proxy ,
    (void *)-1 /* IMailTransportSetRouterReset::RegisterResetInterface */
};

const CInterfaceStubVtbl _IMailTransportSetRouterResetStubVtbl =
{
    &IID_IMailTransportSetRouterReset,
    &IMailTransportSetRouterReset_ServerInfo,
    4,
    0, /* pure interpreted */
    CStdStubBuffer_METHODS
};


/* Object interface: IMessageRouter, ver. 0.0,
   GUID={0xA928AD14,0x1610,0x11d2,{0x9E,0x02,0x00,0xC0,0x4F,0xA3,0x22,0xBA}} */


extern const MIDL_STUB_DESC Object_StubDesc;


extern const MIDL_SERVER_INFO IMessageRouter_ServerInfo;

#pragma code_seg(".orpc")
static const unsigned short IMessageRouter_FormatStringOffsetTable[] = 
    {
    (unsigned short) -1,
    306,
    350,
    (unsigned short) -1,
    (unsigned short) -1,
    394
    };

static const MIDL_SERVER_INFO IMessageRouter_ServerInfo = 
    {
    &Object_StubDesc,
    0,
    __MIDL_ProcFormatString.Format,
    &IMessageRouter_FormatStringOffsetTable[-3],
    0,
    0,
    0,
    0
    };

static const MIDL_STUBLESS_PROXY_INFO IMessageRouter_ProxyInfo =
    {
    &Object_StubDesc,
    __MIDL_ProcFormatString.Format,
    &IMessageRouter_FormatStringOffsetTable[-3],
    0,
    0,
    0
    };

CINTERFACE_PROXY_VTABLE(9) _IMessageRouterProxyVtbl = 
{
    &IMessageRouter_ProxyInfo,
    &IID_IMessageRouter,
    IUnknown_QueryInterface_Proxy,
    IUnknown_AddRef_Proxy,
    IUnknown_Release_Proxy ,
    0 /* IMessageRouter_GetTransportSinkID_Proxy */ ,
    (void *)-1 /* IMessageRouter::GetMessageType */ ,
    (void *)-1 /* IMessageRouter::ReleaseMessageType */ ,
    0 /* (void *)-1 /* IMessageRouter::GetNextHop */ ,
    0 /* (void *)-1 /* IMessageRouter::GetNextHopFree */ ,
    (void *)-1 /* IMessageRouter::ConnectionFailed */
};


static const PRPC_STUB_FUNCTION IMessageRouter_table[] =
{
    STUB_FORWARDING_FUNCTION,
    NdrStubCall2,
    NdrStubCall2,
    STUB_FORWARDING_FUNCTION,
    STUB_FORWARDING_FUNCTION,
    NdrStubCall2
};

const CInterfaceStubVtbl _IMessageRouterStubVtbl =
{
    &IID_IMessageRouter,
    &IMessageRouter_ServerInfo,
    9,
    &IMessageRouter_table[-3],
    CStdStubBuffer_METHODS
};


/* Standard interface: __MIDL_itf_SmtpEvent_0281, ver. 0.0,
   GUID={0x00000000,0x0000,0x0000,{0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00}} */


/* Object interface: IMailTransportRouterSetLinkState, ver. 0.0,
   GUID={0xB870CE28,0xA755,0x11d2,{0xA6,0xA9,0x00,0xC0,0x4F,0xA3,0x49,0x0A}} */


extern const MIDL_STUB_DESC Object_StubDesc;


extern const MIDL_SERVER_INFO IMailTransportRouterSetLinkState_ServerInfo;

#pragma code_seg(".orpc")
static const unsigned short IMailTransportRouterSetLinkState_FormatStringOffsetTable[] = 
    {
    432
    };

static const MIDL_SERVER_INFO IMailTransportRouterSetLinkState_ServerInfo = 
    {
    &Object_StubDesc,
    0,
    __MIDL_ProcFormatString.Format,
    &IMailTransportRouterSetLinkState_FormatStringOffsetTable[-3],
    0,
    0,
    0,
    0
    };

static const MIDL_STUBLESS_PROXY_INFO IMailTransportRouterSetLinkState_ProxyInfo =
    {
    &Object_StubDesc,
    __MIDL_ProcFormatString.Format,
    &IMailTransportRouterSetLinkState_FormatStringOffsetTable[-3],
    0,
    0,
    0
    };

CINTERFACE_PROXY_VTABLE(4) _IMailTransportRouterSetLinkStateProxyVtbl = 
{
    &IMailTransportRouterSetLinkState_ProxyInfo,
    &IID_IMailTransportRouterSetLinkState,
    IUnknown_QueryInterface_Proxy,
    IUnknown_AddRef_Proxy,
    IUnknown_Release_Proxy ,
    (void *)-1 /* IMailTransportRouterSetLinkState::SetLinkState */
};

const CInterfaceStubVtbl _IMailTransportRouterSetLinkStateStubVtbl =
{
    &IID_IMailTransportRouterSetLinkState,
    &IMailTransportRouterSetLinkState_ServerInfo,
    4,
    0, /* pure interpreted */
    CStdStubBuffer_METHODS
};


/* Object interface: IMessageRouterLinkStateNotification, ver. 0.0,
   GUID={0xB870CE29,0xA755,0x11d2,{0xA6,0xA9,0x00,0xC0,0x4F,0xA3,0x49,0x0A}} */


extern const MIDL_STUB_DESC Object_StubDesc;


extern const MIDL_SERVER_INFO IMessageRouterLinkStateNotification_ServerInfo;

#pragma code_seg(".orpc")
static const unsigned short IMessageRouterLinkStateNotification_FormatStringOffsetTable[] = 
    {
    512
    };

static const MIDL_SERVER_INFO IMessageRouterLinkStateNotification_ServerInfo = 
    {
    &Object_StubDesc,
    0,
    __MIDL_ProcFormatString.Format,
    &IMessageRouterLinkStateNotification_FormatStringOffsetTable[-3],
    0,
    0,
    0,
    0
    };

static const MIDL_STUBLESS_PROXY_INFO IMessageRouterLinkStateNotification_ProxyInfo =
    {
    &Object_StubDesc,
    __MIDL_ProcFormatString.Format,
    &IMessageRouterLinkStateNotification_FormatStringOffsetTable[-3],
    0,
    0,
    0
    };

CINTERFACE_PROXY_VTABLE(4) _IMessageRouterLinkStateNotificationProxyVtbl = 
{
    &IMessageRouterLinkStateNotification_ProxyInfo,
    &IID_IMessageRouterLinkStateNotification,
    IUnknown_QueryInterface_Proxy,
    IUnknown_AddRef_Proxy,
    IUnknown_Release_Proxy ,
    (void *)-1 /* IMessageRouterLinkStateNotification::LinkStateNotify */
};

const CInterfaceStubVtbl _IMessageRouterLinkStateNotificationStubVtbl =
{
    &IID_IMessageRouterLinkStateNotification,
    &IMessageRouterLinkStateNotification_ServerInfo,
    4,
    0, /* pure interpreted */
    CStdStubBuffer_METHODS
};


/* Standard interface: __MIDL_itf_SmtpEvent_0283, ver. 0.0,
   GUID={0x00000000,0x0000,0x0000,{0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00}} */


/* Object interface: IMailTransportRoutingEngine, ver. 0.0,
   GUID={0xA928AD13,0x1610,0x11d2,{0x9E,0x02,0x00,0xC0,0x4F,0xA3,0x22,0xBA}} */


extern const MIDL_STUB_DESC Object_StubDesc;


extern const MIDL_SERVER_INFO IMailTransportRoutingEngine_ServerInfo;

#pragma code_seg(".orpc")
static const unsigned short IMailTransportRoutingEngine_FormatStringOffsetTable[] = 
    {
    (unsigned short) -1
    };

static const MIDL_SERVER_INFO IMailTransportRoutingEngine_ServerInfo = 
    {
    &Object_StubDesc,
    0,
    __MIDL_ProcFormatString.Format,
    &IMailTransportRoutingEngine_FormatStringOffsetTable[-3],
    0,
    0,
    0,
    0
    };

static const MIDL_STUBLESS_PROXY_INFO IMailTransportRoutingEngine_ProxyInfo =
    {
    &Object_StubDesc,
    __MIDL_ProcFormatString.Format,
    &IMailTransportRoutingEngine_FormatStringOffsetTable[-3],
    0,
    0,
    0
    };

CINTERFACE_PROXY_VTABLE(4) _IMailTransportRoutingEngineProxyVtbl = 
{
    &IMailTransportRoutingEngine_ProxyInfo,
    &IID_IMailTransportRoutingEngine,
    IUnknown_QueryInterface_Proxy,
    IUnknown_AddRef_Proxy,
    IUnknown_Release_Proxy ,
    0 /* (void *)-1 /* IMailTransportRoutingEngine::GetMessageRouter */
};

const CInterfaceStubVtbl _IMailTransportRoutingEngineStubVtbl =
{
    &IID_IMailTransportRoutingEngine,
    &IMailTransportRoutingEngine_ServerInfo,
    4,
    0, /* pure interpreted */
    CStdStubBuffer_METHODS
};


/* Standard interface: __MIDL_itf_SmtpEvent_0284, ver. 0.0,
   GUID={0x00000000,0x0000,0x0000,{0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00}} */


/* Object interface: IMsgTrackLog, ver. 0.0,
   GUID={0x1bc3580e,0x7e4f,0x11d2,{0x94,0xf4,0x00,0xC0,0x4f,0x79,0xf1,0xd6}} */


/* Object interface: IDnsResolverRecord, ver. 0.0,
   GUID={0xe5b89c52,0x8e0b,0x11d2,{0x94,0xf6,0x00,0xC0,0x4f,0x79,0xf1,0xd6}} */


/* Object interface: IDnsResolverRecordSink, ver. 0.0,
   GUID={0xd95a4d0c,0x8e06,0x11d2,{0x94,0xf6,0x00,0xC0,0x4f,0x79,0xf1,0xd6}} */


/* Object interface: ISmtpMaxMsgSize, ver. 0.0,
   GUID={0xb997f192,0xa67d,0x11d2,{0x94,0xf7,0x00,0xC0,0x4f,0x79,0xf1,0xd6}} */


/* Standard interface: __MIDL_itf_SmtpEvent_0288, ver. 0.0,
   GUID={0x00000000,0x0000,0x0000,{0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00}} */


/* Object interface: ICategorizerProperties, ver. 0.0,
   GUID={0x96BF3199,0x79D8,0x11d2,{0x9E,0x11,0x00,0xC0,0x4F,0xA3,0x22,0xBA}} */


/* Standard interface: __MIDL_itf_SmtpEvent_0289, ver. 0.0,
   GUID={0x00000000,0x0000,0x0000,{0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00}} */


/* Object interface: ICategorizerParameters, ver. 0.0,
   GUID={0x86F9DA7B,0xEB6E,0x11d1,{0x9D,0xF3,0x00,0xC0,0x4F,0xA3,0x22,0xBA}} */


/* Object interface: ICategorizerQueries, ver. 0.0,
   GUID={0x86F9DA7D,0xEB6E,0x11d1,{0x9D,0xF3,0x00,0xC0,0x4F,0xA3,0x22,0xBA}} */


extern const MIDL_STUB_DESC Object_StubDesc;


extern const MIDL_SERVER_INFO ICategorizerQueries_ServerInfo;

#pragma code_seg(".orpc")
static const unsigned short ICategorizerQueries_FormatStringOffsetTable[] = 
    {
    598,
    636
    };

static const MIDL_SERVER_INFO ICategorizerQueries_ServerInfo = 
    {
    &Object_StubDesc,
    0,
    __MIDL_ProcFormatString.Format,
    &ICategorizerQueries_FormatStringOffsetTable[-3],
    0,
    0,
    0,
    0
    };

static const MIDL_STUBLESS_PROXY_INFO ICategorizerQueries_ProxyInfo =
    {
    &Object_StubDesc,
    __MIDL_ProcFormatString.Format,
    &ICategorizerQueries_FormatStringOffsetTable[-3],
    0,
    0,
    0
    };

CINTERFACE_PROXY_VTABLE(5) _ICategorizerQueriesProxyVtbl = 
{
    &ICategorizerQueries_ProxyInfo,
    &IID_ICategorizerQueries,
    IUnknown_QueryInterface_Proxy,
    IUnknown_AddRef_Proxy,
    IUnknown_Release_Proxy ,
    (void *)-1 /* ICategorizerQueries::SetQueryString */ ,
    (void *)-1 /* ICategorizerQueries::GetQueryString */
};

const CInterfaceStubVtbl _ICategorizerQueriesStubVtbl =
{
    &IID_ICategorizerQueries,
    &ICategorizerQueries_ServerInfo,
    5,
    0, /* pure interpreted */
    CStdStubBuffer_METHODS
};


/* Standard interface: __MIDL_itf_SmtpEvent_0291, ver. 0.0,
   GUID={0x00000000,0x0000,0x0000,{0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00}} */


/* Object interface: ICategorizerMailMsgs, ver. 0.0,
   GUID={0x86F9DA80,0xEB6E,0x11d1,{0x9D,0xF3,0x00,0xC0,0x4F,0xA3,0x22,0xBA}} */


/* Standard interface: __MIDL_itf_SmtpEvent_0292, ver. 0.0,
   GUID={0x00000000,0x0000,0x0000,{0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00}} */


/* Object interface: ICategorizerItemAttributes, ver. 0.0,
   GUID={0x86F9DA7F,0xEB6E,0x11d1,{0x9D,0xF3,0x00,0xC0,0x4F,0xA3,0x22,0xBA}} */


extern const MIDL_STUB_DESC Object_StubDesc;


extern const MIDL_SERVER_INFO ICategorizerItemAttributes_ServerInfo;

#pragma code_seg(".orpc")
static const unsigned short ICategorizerItemAttributes_FormatStringOffsetTable[] = 
    {
    (unsigned short) -1,
    (unsigned short) -1,
    (unsigned short) -1,
    (unsigned short) -1,
    (unsigned short) -1,
    (unsigned short) -1,
    (unsigned short) -1,
    (unsigned short) -1,
    (unsigned short) -1,
    (unsigned short) -1,
    (unsigned short) -1,
    (unsigned short) -1
    };

static const MIDL_SERVER_INFO ICategorizerItemAttributes_ServerInfo = 
    {
    &Object_StubDesc,
    0,
    __MIDL_ProcFormatString.Format,
    &ICategorizerItemAttributes_FormatStringOffsetTable[-3],
    0,
    0,
    0,
    0
    };

static const MIDL_STUBLESS_PROXY_INFO ICategorizerItemAttributes_ProxyInfo =
    {
    &Object_StubDesc,
    __MIDL_ProcFormatString.Format,
    &ICategorizerItemAttributes_FormatStringOffsetTable[-3],
    0,
    0,
    0
    };

CINTERFACE_PROXY_VTABLE(15) _ICategorizerItemAttributesProxyVtbl = 
{
    &ICategorizerItemAttributes_ProxyInfo,
    &IID_ICategorizerItemAttributes,
    IUnknown_QueryInterface_Proxy,
    IUnknown_AddRef_Proxy,
    IUnknown_Release_Proxy ,
    0 /* (void *)-1 /* ICategorizerItemAttributes::BeginAttributeEnumeration */ ,
    0 /* (void *)-1 /* ICategorizerItemAttributes::GetNextAttributeValue */ ,
    0 /* (void *)-1 /* ICategorizerItemAttributes::RewindAttributeEnumeration */ ,
    0 /* (void *)-1 /* ICategorizerItemAttributes::EndAttributeEnumeration */ ,
    0 /* (void *)-1 /* ICategorizerItemAttributes::BeginAttributeNameEnumeration */ ,
    0 /* (void *)-1 /* ICategorizerItemAttributes::GetNextAttributeName */ ,
    0 /* (void *)-1 /* ICategorizerItemAttributes::EndAttributeNameEnumeration */ ,
    0 /* ICategorizerItemAttributes_GetTransportSinkID_Proxy */ ,
    0 /* (void *)-1 /* ICategorizerItemAttributes::AggregateAttributes */ ,
    0 /* (void *)-1 /* ICategorizerItemAttributes::GetAllAttributeValues */ ,
    0 /* (void *)-1 /* ICategorizerItemAttributes::ReleaseAllAttributeValues */ ,
    0 /* (void *)-1 /* ICategorizerItemAttributes::CountAttributeValues */
};


static const PRPC_STUB_FUNCTION ICategorizerItemAttributes_table[] =
{
    STUB_FORWARDING_FUNCTION,
    STUB_FORWARDING_FUNCTION,
    STUB_FORWARDING_FUNCTION,
    STUB_FORWARDING_FUNCTION,
    STUB_FORWARDING_FUNCTION,
    STUB_FORWARDING_FUNCTION,
    STUB_FORWARDING_FUNCTION,
    STUB_FORWARDING_FUNCTION,
    STUB_FORWARDING_FUNCTION,
    STUB_FORWARDING_FUNCTION,
    STUB_FORWARDING_FUNCTION,
    STUB_FORWARDING_FUNCTION
};

const CInterfaceStubVtbl _ICategorizerItemAttributesStubVtbl =
{
    &IID_ICategorizerItemAttributes,
    &ICategorizerItemAttributes_ServerInfo,
    15,
    &ICategorizerItemAttributes_table[-3],
    CStdStubBuffer_METHODS
};


/* Object interface: ICategorizerItemRawAttributes, ver. 0.0,
   GUID={0x34C3D389,0x8FA7,0x11d2,{0x9E,0x16,0x00,0xC0,0x4F,0xA3,0x22,0xBA}} */


extern const MIDL_STUB_DESC Object_StubDesc;


extern const MIDL_SERVER_INFO ICategorizerItemRawAttributes_ServerInfo;

#pragma code_seg(".orpc")
static const unsigned short ICategorizerItemRawAttributes_FormatStringOffsetTable[] = 
    {
    (unsigned short) -1,
    (unsigned short) -1,
    (unsigned short) -1,
    (unsigned short) -1,
    (unsigned short) -1
    };

static const MIDL_SERVER_INFO ICategorizerItemRawAttributes_ServerInfo = 
    {
    &Object_StubDesc,
    0,
    __MIDL_ProcFormatString.Format,
    &ICategorizerItemRawAttributes_FormatStringOffsetTable[-3],
    0,
    0,
    0,
    0
    };

static const MIDL_STUBLESS_PROXY_INFO ICategorizerItemRawAttributes_ProxyInfo =
    {
    &Object_StubDesc,
    __MIDL_ProcFormatString.Format,
    &ICategorizerItemRawAttributes_FormatStringOffsetTable[-3],
    0,
    0,
    0
    };

CINTERFACE_PROXY_VTABLE(8) _ICategorizerItemRawAttributesProxyVtbl = 
{
    &ICategorizerItemRawAttributes_ProxyInfo,
    &IID_ICategorizerItemRawAttributes,
    IUnknown_QueryInterface_Proxy,
    IUnknown_AddRef_Proxy,
    IUnknown_Release_Proxy ,
    0 /* (void *)-1 /* ICategorizerItemRawAttributes::BeginRawAttributeEnumeration */ ,
    0 /* (void *)-1 /* ICategorizerItemRawAttributes::GetNextRawAttributeValue */ ,
    0 /* (void *)-1 /* ICategorizerItemRawAttributes::RewindRawAttributeEnumeration */ ,
    0 /* (void *)-1 /* ICategorizerItemRawAttributes::EndRawAttributeEnumeration */ ,
    0 /* (void *)-1 /* ICategorizerItemRawAttributes::CountRawAttributeValues */
};

const CInterfaceStubVtbl _ICategorizerItemRawAttributesStubVtbl =
{
    &IID_ICategorizerItemRawAttributes,
    &ICategorizerItemRawAttributes_ServerInfo,
    8,
    0, /* pure interpreted */
    CStdStubBuffer_METHODS
};


/* Standard interface: __MIDL_itf_SmtpEvent_0294, ver. 0.0,
   GUID={0x00000000,0x0000,0x0000,{0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00}} */


/* Object interface: ICategorizerItem, ver. 0.0,
   GUID={0x86F9DA7C,0xEB6E,0x11d1,{0x9D,0xF3,0x00,0xC0,0x4F,0xA3,0x22,0xBA}} */


/* Object interface: ICategorizerAsyncContext, ver. 0.0,
   GUID={0x86F9DA7E,0xEB6E,0x11d1,{0x9D,0xF3,0x00,0xC0,0x4F,0xA3,0x22,0xBA}} */


extern const MIDL_STUB_DESC Object_StubDesc;


extern const MIDL_SERVER_INFO ICategorizerAsyncContext_ServerInfo;

#pragma code_seg(".orpc")
static const unsigned short ICategorizerAsyncContext_FormatStringOffsetTable[] = 
    {
    (unsigned short) -1
    };

static const MIDL_SERVER_INFO ICategorizerAsyncContext_ServerInfo = 
    {
    &Object_StubDesc,
    0,
    __MIDL_ProcFormatString.Format,
    &ICategorizerAsyncContext_FormatStringOffsetTable[-3],
    0,
    0,
    0,
    0
    };

static const MIDL_STUBLESS_PROXY_INFO ICategorizerAsyncContext_ProxyInfo =
    {
    &Object_StubDesc,
    __MIDL_ProcFormatString.Format,
    &ICategorizerAsyncContext_FormatStringOffsetTable[-3],
    0,
    0,
    0
    };

CINTERFACE_PROXY_VTABLE(4) _ICategorizerAsyncContextProxyVtbl = 
{
    &ICategorizerAsyncContext_ProxyInfo,
    &IID_ICategorizerAsyncContext,
    IUnknown_QueryInterface_Proxy,
    IUnknown_AddRef_Proxy,
    IUnknown_Release_Proxy ,
    0 /* (void *)-1 /* ICategorizerAsyncContext::CompleteQuery */
};

const CInterfaceStubVtbl _ICategorizerAsyncContextStubVtbl =
{
    &IID_ICategorizerAsyncContext,
    &ICategorizerAsyncContext_ServerInfo,
    4,
    0, /* pure interpreted */
    CStdStubBuffer_METHODS
};


/* Object interface: ICategorizerListResolve, ver. 0.0,
   GUID={0x960252A4,0x0A3A,0x11d2,{0x9E,0x00,0x00,0xC0,0x4F,0xA3,0x22,0xBA}} */


extern const MIDL_STUB_DESC Object_StubDesc;


extern const MIDL_SERVER_INFO ICategorizerListResolve_ServerInfo;

#pragma code_seg(".orpc")
static const unsigned short ICategorizerListResolve_FormatStringOffsetTable[] = 
    {
    (unsigned short) -1,
    (unsigned short) -1,
    (unsigned short) -1,
    (unsigned short) -1
    };

static const MIDL_SERVER_INFO ICategorizerListResolve_ServerInfo = 
    {
    &Object_StubDesc,
    0,
    __MIDL_ProcFormatString.Format,
    &ICategorizerListResolve_FormatStringOffsetTable[-3],
    0,
    0,
    0,
    0
    };

static const MIDL_STUBLESS_PROXY_INFO ICategorizerListResolve_ProxyInfo =
    {
    &Object_StubDesc,
    __MIDL_ProcFormatString.Format,
    &ICategorizerListResolve_FormatStringOffsetTable[-3],
    0,
    0,
    0
    };

CINTERFACE_PROXY_VTABLE(7) _ICategorizerListResolveProxyVtbl = 
{
    &ICategorizerListResolve_ProxyInfo,
    &IID_ICategorizerListResolve,
    IUnknown_QueryInterface_Proxy,
    IUnknown_AddRef_Proxy,
    IUnknown_Release_Proxy ,
    0 /* (void *)-1 /* ICategorizerListResolve::AllocICategorizerItem */ ,
    0 /* (void *)-1 /* ICategorizerListResolve::ResolveICategorizerItem */ ,
    0 /* (void *)-1 /* ICategorizerListResolve::SetListResolveStatus */ ,
    0 /* (void *)-1 /* ICategorizerListResolve::GetListResolveStatus */
};

const CInterfaceStubVtbl _ICategorizerListResolveStubVtbl =
{
    &IID_ICategorizerListResolve,
    &ICategorizerListResolve_ServerInfo,
    7,
    0, /* pure interpreted */
    CStdStubBuffer_METHODS
};


/* Object interface: IMailTransportCategorize, ver. 0.0,
   GUID={0x86F9DA7A,0xEB6E,0x11d1,{0x9D,0xF3,0x00,0xC0,0x4F,0xA3,0x22,0xBA}} */


extern const MIDL_STUB_DESC Object_StubDesc;


extern const MIDL_SERVER_INFO IMailTransportCategorize_ServerInfo;

#pragma code_seg(".orpc")
static const unsigned short IMailTransportCategorize_FormatStringOffsetTable[] = 
    {
    674,
    (unsigned short) -1,
    (unsigned short) -1,
    (unsigned short) -1,
    (unsigned short) -1,
    (unsigned short) -1,
    (unsigned short) -1,
    (unsigned short) -1,
    (unsigned short) -1,
    (unsigned short) -1
    };

static const MIDL_SERVER_INFO IMailTransportCategorize_ServerInfo = 
    {
    &Object_StubDesc,
    0,
    __MIDL_ProcFormatString.Format,
    &IMailTransportCategorize_FormatStringOffsetTable[-3],
    0,
    0,
    0,
    0
    };

static const MIDL_STUBLESS_PROXY_INFO IMailTransportCategorize_ProxyInfo =
    {
    &Object_StubDesc,
    __MIDL_ProcFormatString.Format,
    &IMailTransportCategorize_FormatStringOffsetTable[-3],
    0,
    0,
    0
    };

CINTERFACE_PROXY_VTABLE(13) _IMailTransportCategorizeProxyVtbl = 
{
    &IMailTransportCategorize_ProxyInfo,
    &IID_IMailTransportCategorize,
    IUnknown_QueryInterface_Proxy,
    IUnknown_AddRef_Proxy,
    IUnknown_Release_Proxy ,
    (void *)-1 /* IMailTransportCategorize::Register */ ,
    0 /* (void *)-1 /* IMailTransportCategorize::BeginMessageCategorization */ ,
    0 /* (void *)-1 /* IMailTransportCategorize::EndMessageCategorization */ ,
    0 /* (void *)-1 /* IMailTransportCategorize::BuildQuery */ ,
    0 /* (void *)-1 /* IMailTransportCategorize::BuildQueries */ ,
    0 /* (void *)-1 /* IMailTransportCategorize::SendQuery */ ,
    0 /* (void *)-1 /* IMailTransportCategorize::SortQueryResult */ ,
    0 /* (void *)-1 /* IMailTransportCategorize::ProcessItem */ ,
    0 /* (void *)-1 /* IMailTransportCategorize::ExpandItem */ ,
    0 /* (void *)-1 /* IMailTransportCategorize::CompleteItem */
};

const CInterfaceStubVtbl _IMailTransportCategorizeStubVtbl =
{
    &IID_IMailTransportCategorize,
    &IMailTransportCategorize_ServerInfo,
    13,
    0, /* pure interpreted */
    CStdStubBuffer_METHODS
};


/* Object interface: ISMTPCategorizer, ver. 0.0,
   GUID={0xB23C35B8,0x9219,0x11d2,{0x9E,0x17,0x00,0xC0,0x4F,0xA3,0x22,0xBA}} */


/* Object interface: ISMTPCategorizerCompletion, ver. 0.0,
   GUID={0xB23C35B9,0x9219,0x11d2,{0x9E,0x17,0x00,0xC0,0x4F,0xA3,0x22,0xBA}} */


/* Object interface: ISMTPCategorizerDLCompletion, ver. 0.0,
   GUID={0xB23C35BA,0x9219,0x11d2,{0x9E,0x17,0x00,0xC0,0x4F,0xA3,0x22,0xBA}} */


/* Standard interface: __MIDL_itf_SmtpEvent_0301, ver. 0.0,
   GUID={0x00000000,0x0000,0x0000,{0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00}} */


/* Object interface: ICategorizerDomainInfo, ver. 0.0,
   GUID={0xE210EDC6,0xF27D,0x481f,{0x9D,0xFC,0x1C,0xA8,0x40,0x90,0x5F,0xD9}} */


/* Standard interface: __MIDL_itf_SmtpEvent_0302, ver. 0.0,
   GUID={0x00000000,0x0000,0x0000,{0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00}} */


static const MIDL_STUB_DESC Object_StubDesc = 
    {
    0,
    NdrOleAllocate,
    NdrOleFree,
    0,
    0,
    0,
    0,
    0,
    __MIDL_TypeFormatString.Format,
    1, /* -error bounds_check flag */
    0x50002, /* Ndr library version */
    0,
    0x5030118, /* MIDL Version 5.3.280 */
    0,
    0,
    0,  /* notify & notify_flag routine table */
    0x1, /* MIDL flag */
    0,  /* Reserved3 */
    0,  /* Reserved4 */
    0   /* Reserved5 */
    };

#pragma data_seg(".rdata")

#if !defined(__RPC_WIN64__)
#error  Invalid build platform for this stub.
#endif

static const MIDL_PROC_FORMAT_STRING __MIDL_ProcFormatString =
    {
        0,
        {

	/* Procedure OnSmtpInCommand */

			0x33,		/* FC_AUTO_HANDLE */
			0x6c,		/* Old Flags:  object, Oi2 */
/*  2 */	NdrFcLong( 0x0 ),	/* 0 */
/*  6 */	NdrFcShort( 0x3 ),	/* 3 */
/*  8 */	NdrFcShort( 0x30 ),	/* ia64, axp64 Stack size/offset = 48 */
/* 10 */	NdrFcShort( 0x0 ),	/* 0 */
/* 12 */	NdrFcShort( 0x8 ),	/* 8 */
/* 14 */	0x46,		/* Oi2 Flags:  clt must size, has return, has ext, */
			0x5,		/* 5 */
/* 16 */	0xa,		/* 10 */
			0x1,		/* Ext Flags:  new corr desc, */
/* 18 */	NdrFcShort( 0x0 ),	/* 0 */
/* 20 */	NdrFcShort( 0x0 ),	/* 0 */
/* 22 */	NdrFcShort( 0x0 ),	/* 0 */
/* 24 */	NdrFcShort( 0x0 ),	/* 0 */

	/* Parameter pServer */

/* 26 */	NdrFcShort( 0xb ),	/* Flags:  must size, must free, in, */
/* 28 */	NdrFcShort( 0x8 ),	/* ia64, axp64 Stack size/offset = 8 */
/* 30 */	NdrFcShort( 0x2 ),	/* Type Offset=2 */

	/* Parameter pSession */

/* 32 */	NdrFcShort( 0xb ),	/* Flags:  must size, must free, in, */
/* 34 */	NdrFcShort( 0x10 ),	/* ia64, axp64 Stack size/offset = 16 */
/* 36 */	NdrFcShort( 0x2 ),	/* Type Offset=2 */

	/* Parameter pMsg */

/* 38 */	NdrFcShort( 0xb ),	/* Flags:  must size, must free, in, */
/* 40 */	NdrFcShort( 0x18 ),	/* ia64, axp64 Stack size/offset = 24 */
/* 42 */	NdrFcShort( 0x14 ),	/* Type Offset=20 */

	/* Parameter pContext */

/* 44 */	NdrFcShort( 0xb ),	/* Flags:  must size, must free, in, */
/* 46 */	NdrFcShort( 0x20 ),	/* ia64, axp64 Stack size/offset = 32 */
/* 48 */	NdrFcShort( 0x26 ),	/* Type Offset=38 */

	/* Return value */

/* 50 */	NdrFcShort( 0x70 ),	/* Flags:  out, return, base type, */
/* 52 */	NdrFcShort( 0x28 ),	/* ia64, axp64 Stack size/offset = 40 */
/* 54 */	0x8,		/* FC_LONG */
			0x0,		/* 0 */

	/* Procedure OnSmtpOutCommand */

/* 56 */	0x33,		/* FC_AUTO_HANDLE */
			0x6c,		/* Old Flags:  object, Oi2 */
/* 58 */	NdrFcLong( 0x0 ),	/* 0 */
/* 62 */	NdrFcShort( 0x3 ),	/* 3 */
/* 64 */	NdrFcShort( 0x30 ),	/* ia64, axp64 Stack size/offset = 48 */
/* 66 */	NdrFcShort( 0x0 ),	/* 0 */
/* 68 */	NdrFcShort( 0x8 ),	/* 8 */
/* 70 */	0x46,		/* Oi2 Flags:  clt must size, has return, has ext, */
			0x5,		/* 5 */
/* 72 */	0xa,		/* 10 */
			0x1,		/* Ext Flags:  new corr desc, */
/* 74 */	NdrFcShort( 0x0 ),	/* 0 */
/* 76 */	NdrFcShort( 0x0 ),	/* 0 */
/* 78 */	NdrFcShort( 0x0 ),	/* 0 */
/* 80 */	NdrFcShort( 0x0 ),	/* 0 */

	/* Parameter pServer */

/* 82 */	NdrFcShort( 0xb ),	/* Flags:  must size, must free, in, */
/* 84 */	NdrFcShort( 0x8 ),	/* ia64, axp64 Stack size/offset = 8 */
/* 86 */	NdrFcShort( 0x38 ),	/* Type Offset=56 */

	/* Parameter pSession */

/* 88 */	NdrFcShort( 0xb ),	/* Flags:  must size, must free, in, */
/* 90 */	NdrFcShort( 0x10 ),	/* ia64, axp64 Stack size/offset = 16 */
/* 92 */	NdrFcShort( 0x38 ),	/* Type Offset=56 */

	/* Parameter pMsg */

/* 94 */	NdrFcShort( 0xb ),	/* Flags:  must size, must free, in, */
/* 96 */	NdrFcShort( 0x18 ),	/* ia64, axp64 Stack size/offset = 24 */
/* 98 */	NdrFcShort( 0x4a ),	/* Type Offset=74 */

	/* Parameter pContext */

/* 100 */	NdrFcShort( 0xb ),	/* Flags:  must size, must free, in, */
/* 102 */	NdrFcShort( 0x20 ),	/* ia64, axp64 Stack size/offset = 32 */
/* 104 */	NdrFcShort( 0x5c ),	/* Type Offset=92 */

	/* Return value */

/* 106 */	NdrFcShort( 0x70 ),	/* Flags:  out, return, base type, */
/* 108 */	NdrFcShort( 0x28 ),	/* ia64, axp64 Stack size/offset = 40 */
/* 110 */	0x8,		/* FC_LONG */
			0x0,		/* 0 */

	/* Procedure OnSmtpServerResponse */

/* 112 */	0x33,		/* FC_AUTO_HANDLE */
			0x6c,		/* Old Flags:  object, Oi2 */
/* 114 */	NdrFcLong( 0x0 ),	/* 0 */
/* 118 */	NdrFcShort( 0x3 ),	/* 3 */
/* 120 */	NdrFcShort( 0x30 ),	/* ia64, axp64 Stack size/offset = 48 */
/* 122 */	NdrFcShort( 0x0 ),	/* 0 */
/* 124 */	NdrFcShort( 0x8 ),	/* 8 */
/* 126 */	0x46,		/* Oi2 Flags:  clt must size, has return, has ext, */
			0x5,		/* 5 */
/* 128 */	0xa,		/* 10 */
			0x1,		/* Ext Flags:  new corr desc, */
/* 130 */	NdrFcShort( 0x0 ),	/* 0 */
/* 132 */	NdrFcShort( 0x0 ),	/* 0 */
/* 134 */	NdrFcShort( 0x0 ),	/* 0 */
/* 136 */	NdrFcShort( 0x0 ),	/* 0 */

	/* Parameter pServer */

/* 138 */	NdrFcShort( 0xb ),	/* Flags:  must size, must free, in, */
/* 140 */	NdrFcShort( 0x8 ),	/* ia64, axp64 Stack size/offset = 8 */
/* 142 */	NdrFcShort( 0x38 ),	/* Type Offset=56 */

	/* Parameter pSession */

/* 144 */	NdrFcShort( 0xb ),	/* Flags:  must size, must free, in, */
/* 146 */	NdrFcShort( 0x10 ),	/* ia64, axp64 Stack size/offset = 16 */
/* 148 */	NdrFcShort( 0x38 ),	/* Type Offset=56 */

	/* Parameter pMsg */

/* 150 */	NdrFcShort( 0xb ),	/* Flags:  must size, must free, in, */
/* 152 */	NdrFcShort( 0x18 ),	/* ia64, axp64 Stack size/offset = 24 */
/* 154 */	NdrFcShort( 0x4a ),	/* Type Offset=74 */

	/* Parameter pContext */

/* 156 */	NdrFcShort( 0xb ),	/* Flags:  must size, must free, in, */
/* 158 */	NdrFcShort( 0x20 ),	/* ia64, axp64 Stack size/offset = 32 */
/* 160 */	NdrFcShort( 0x6e ),	/* Type Offset=110 */

	/* Return value */

/* 162 */	NdrFcShort( 0x70 ),	/* Flags:  out, return, base type, */
/* 164 */	NdrFcShort( 0x28 ),	/* ia64, axp64 Stack size/offset = 40 */
/* 166 */	0x8,		/* FC_LONG */
			0x0,		/* 0 */

	/* Procedure OnSmtpInCallback */

/* 168 */	0x33,		/* FC_AUTO_HANDLE */
			0x6c,		/* Old Flags:  object, Oi2 */
/* 170 */	NdrFcLong( 0x0 ),	/* 0 */
/* 174 */	NdrFcShort( 0x3 ),	/* 3 */
/* 176 */	NdrFcShort( 0x30 ),	/* ia64, axp64 Stack size/offset = 48 */
/* 178 */	NdrFcShort( 0x0 ),	/* 0 */
/* 180 */	NdrFcShort( 0x8 ),	/* 8 */
/* 182 */	0x46,		/* Oi2 Flags:  clt must size, has return, has ext, */
			0x5,		/* 5 */
/* 184 */	0xa,		/* 10 */
			0x1,		/* Ext Flags:  new corr desc, */
/* 186 */	NdrFcShort( 0x0 ),	/* 0 */
/* 188 */	NdrFcShort( 0x0 ),	/* 0 */
/* 190 */	NdrFcShort( 0x0 ),	/* 0 */
/* 192 */	NdrFcShort( 0x0 ),	/* 0 */

	/* Parameter pServer */

/* 194 */	NdrFcShort( 0xb ),	/* Flags:  must size, must free, in, */
/* 196 */	NdrFcShort( 0x8 ),	/* ia64, axp64 Stack size/offset = 8 */
/* 198 */	NdrFcShort( 0x38 ),	/* Type Offset=56 */

	/* Parameter pSession */

/* 200 */	NdrFcShort( 0xb ),	/* Flags:  must size, must free, in, */
/* 202 */	NdrFcShort( 0x10 ),	/* ia64, axp64 Stack size/offset = 16 */
/* 204 */	NdrFcShort( 0x38 ),	/* Type Offset=56 */

	/* Parameter pMsg */

/* 206 */	NdrFcShort( 0xb ),	/* Flags:  must size, must free, in, */
/* 208 */	NdrFcShort( 0x18 ),	/* ia64, axp64 Stack size/offset = 24 */
/* 210 */	NdrFcShort( 0x4a ),	/* Type Offset=74 */

	/* Parameter pContext */

/* 212 */	NdrFcShort( 0xb ),	/* Flags:  must size, must free, in, */
/* 214 */	NdrFcShort( 0x20 ),	/* ia64, axp64 Stack size/offset = 32 */
/* 216 */	NdrFcShort( 0x80 ),	/* Type Offset=128 */

	/* Return value */

/* 218 */	NdrFcShort( 0x70 ),	/* Flags:  out, return, base type, */
/* 220 */	NdrFcShort( 0x28 ),	/* ia64, axp64 Stack size/offset = 40 */
/* 222 */	0x8,		/* FC_LONG */
			0x0,		/* 0 */

	/* Procedure ResetRoutes */

/* 224 */	0x33,		/* FC_AUTO_HANDLE */
			0x6c,		/* Old Flags:  object, Oi2 */
/* 226 */	NdrFcLong( 0x0 ),	/* 0 */
/* 230 */	NdrFcShort( 0x3 ),	/* 3 */
/* 232 */	NdrFcShort( 0x18 ),	/* ia64, axp64 Stack size/offset = 24 */
/* 234 */	NdrFcShort( 0x8 ),	/* 8 */
/* 236 */	NdrFcShort( 0x8 ),	/* 8 */
/* 238 */	0x44,		/* Oi2 Flags:  has return, has ext, */
			0x2,		/* 2 */
/* 240 */	0xa,		/* 10 */
			0x1,		/* Ext Flags:  new corr desc, */
/* 242 */	NdrFcShort( 0x0 ),	/* 0 */
/* 244 */	NdrFcShort( 0x0 ),	/* 0 */
/* 246 */	NdrFcShort( 0x0 ),	/* 0 */
/* 248 */	NdrFcShort( 0x0 ),	/* 0 */

	/* Parameter dwResetType */

/* 250 */	NdrFcShort( 0x48 ),	/* Flags:  in, base type, */
/* 252 */	NdrFcShort( 0x8 ),	/* ia64, axp64 Stack size/offset = 8 */
/* 254 */	0x8,		/* FC_LONG */
			0x0,		/* 0 */

	/* Return value */

/* 256 */	NdrFcShort( 0x70 ),	/* Flags:  out, return, base type, */
/* 258 */	NdrFcShort( 0x10 ),	/* ia64, axp64 Stack size/offset = 16 */
/* 260 */	0x8,		/* FC_LONG */
			0x0,		/* 0 */

	/* Procedure RegisterResetInterface */

/* 262 */	0x33,		/* FC_AUTO_HANDLE */
			0x6c,		/* Old Flags:  object, Oi2 */
/* 264 */	NdrFcLong( 0x0 ),	/* 0 */
/* 268 */	NdrFcShort( 0x3 ),	/* 3 */
/* 270 */	NdrFcShort( 0x20 ),	/* ia64, axp64 Stack size/offset = 32 */
/* 272 */	NdrFcShort( 0x8 ),	/* 8 */
/* 274 */	NdrFcShort( 0x8 ),	/* 8 */
/* 276 */	0x46,		/* Oi2 Flags:  clt must size, has return, has ext, */
			0x3,		/* 3 */
/* 278 */	0xa,		/* 10 */
			0x1,		/* Ext Flags:  new corr desc, */
/* 280 */	NdrFcShort( 0x0 ),	/* 0 */
/* 282 */	NdrFcShort( 0x0 ),	/* 0 */
/* 284 */	NdrFcShort( 0x0 ),	/* 0 */
/* 286 */	NdrFcShort( 0x0 ),	/* 0 */

	/* Parameter dwVirtualServerID */

/* 288 */	NdrFcShort( 0x48 ),	/* Flags:  in, base type, */
/* 290 */	NdrFcShort( 0x8 ),	/* ia64, axp64 Stack size/offset = 8 */
/* 292 */	0x8,		/* FC_LONG */
			0x0,		/* 0 */

	/* Parameter pIRouterReset */

/* 294 */	NdrFcShort( 0xb ),	/* Flags:  must size, must free, in, */
/* 296 */	NdrFcShort( 0x10 ),	/* ia64, axp64 Stack size/offset = 16 */
/* 298 */	NdrFcShort( 0x92 ),	/* Type Offset=146 */

	/* Return value */

/* 300 */	NdrFcShort( 0x70 ),	/* Flags:  out, return, base type, */
/* 302 */	NdrFcShort( 0x18 ),	/* ia64, axp64 Stack size/offset = 24 */
/* 304 */	0x8,		/* FC_LONG */
			0x0,		/* 0 */

	/* Procedure GetMessageType */

/* 306 */	0x33,		/* FC_AUTO_HANDLE */
			0x6c,		/* Old Flags:  object, Oi2 */
/* 308 */	NdrFcLong( 0x0 ),	/* 0 */
/* 312 */	NdrFcShort( 0x4 ),	/* 4 */
/* 314 */	NdrFcShort( 0x20 ),	/* ia64, axp64 Stack size/offset = 32 */
/* 316 */	NdrFcShort( 0x0 ),	/* 0 */
/* 318 */	NdrFcShort( 0x10 ),	/* 16 */
/* 320 */	0x46,		/* Oi2 Flags:  clt must size, has return, has ext, */
			0x3,		/* 3 */
/* 322 */	0xa,		/* 10 */
			0x1,		/* Ext Flags:  new corr desc, */
/* 324 */	NdrFcShort( 0x0 ),	/* 0 */
/* 326 */	NdrFcShort( 0x0 ),	/* 0 */
/* 328 */	NdrFcShort( 0x0 ),	/* 0 */
/* 330 */	NdrFcShort( 0x0 ),	/* 0 */

	/* Parameter pIMailMsg */

/* 332 */	NdrFcShort( 0xb ),	/* Flags:  must size, must free, in, */
/* 334 */	NdrFcShort( 0x8 ),	/* ia64, axp64 Stack size/offset = 8 */
/* 336 */	NdrFcShort( 0x4a ),	/* Type Offset=74 */

	/* Parameter pdwMessageType */

/* 338 */	NdrFcShort( 0x2150 ),	/* Flags:  out, base type, simple ref, srv alloc size=8 */
/* 340 */	NdrFcShort( 0x10 ),	/* ia64, axp64 Stack size/offset = 16 */
/* 342 */	0x8,		/* FC_LONG */
			0x0,		/* 0 */

	/* Return value */

/* 344 */	NdrFcShort( 0x70 ),	/* Flags:  out, return, base type, */
/* 346 */	NdrFcShort( 0x18 ),	/* ia64, axp64 Stack size/offset = 24 */
/* 348 */	0x8,		/* FC_LONG */
			0x0,		/* 0 */

	/* Procedure ReleaseMessageType */

/* 350 */	0x33,		/* FC_AUTO_HANDLE */
			0x6c,		/* Old Flags:  object, Oi2 */
/* 352 */	NdrFcLong( 0x0 ),	/* 0 */
/* 356 */	NdrFcShort( 0x5 ),	/* 5 */
/* 358 */	NdrFcShort( 0x20 ),	/* ia64, axp64 Stack size/offset = 32 */
/* 360 */	NdrFcShort( 0x10 ),	/* 16 */
/* 362 */	NdrFcShort( 0x8 ),	/* 8 */
/* 364 */	0x44,		/* Oi2 Flags:  has return, has ext, */
			0x3,		/* 3 */
/* 366 */	0xa,		/* 10 */
			0x1,		/* Ext Flags:  new corr desc, */
/* 368 */	NdrFcShort( 0x0 ),	/* 0 */
/* 370 */	NdrFcShort( 0x0 ),	/* 0 */
/* 372 */	NdrFcShort( 0x0 ),	/* 0 */
/* 374 */	NdrFcShort( 0x0 ),	/* 0 */

	/* Parameter dwMessageType */

/* 376 */	NdrFcShort( 0x48 ),	/* Flags:  in, base type, */
/* 378 */	NdrFcShort( 0x8 ),	/* ia64, axp64 Stack size/offset = 8 */
/* 380 */	0x8,		/* FC_LONG */
			0x0,		/* 0 */

	/* Parameter dwReleaseCount */

/* 382 */	NdrFcShort( 0x48 ),	/* Flags:  in, base type, */
/* 384 */	NdrFcShort( 0x10 ),	/* ia64, axp64 Stack size/offset = 16 */
/* 386 */	0x8,		/* FC_LONG */
			0x0,		/* 0 */

	/* Return value */

/* 388 */	NdrFcShort( 0x70 ),	/* Flags:  out, return, base type, */
/* 390 */	NdrFcShort( 0x18 ),	/* ia64, axp64 Stack size/offset = 24 */
/* 392 */	0x8,		/* FC_LONG */
			0x0,		/* 0 */

	/* Procedure ConnectionFailed */

/* 394 */	0x33,		/* FC_AUTO_HANDLE */
			0x6c,		/* Old Flags:  object, Oi2 */
/* 396 */	NdrFcLong( 0x0 ),	/* 0 */
/* 400 */	NdrFcShort( 0x8 ),	/* 8 */
/* 402 */	NdrFcShort( 0x18 ),	/* ia64, axp64 Stack size/offset = 24 */
/* 404 */	NdrFcShort( 0x0 ),	/* 0 */
/* 406 */	NdrFcShort( 0x8 ),	/* 8 */
/* 408 */	0x46,		/* Oi2 Flags:  clt must size, has return, has ext, */
			0x2,		/* 2 */
/* 410 */	0xa,		/* 10 */
			0x1,		/* Ext Flags:  new corr desc, */
/* 412 */	NdrFcShort( 0x0 ),	/* 0 */
/* 414 */	NdrFcShort( 0x0 ),	/* 0 */
/* 416 */	NdrFcShort( 0x0 ),	/* 0 */
/* 418 */	NdrFcShort( 0x0 ),	/* 0 */

	/* Parameter pszConnectorName */

/* 420 */	NdrFcShort( 0x10b ),	/* Flags:  must size, must free, in, simple ref, */
/* 422 */	NdrFcShort( 0x8 ),	/* ia64, axp64 Stack size/offset = 8 */
/* 424 */	NdrFcShort( 0xaa ),	/* Type Offset=170 */

	/* Return value */

/* 426 */	NdrFcShort( 0x70 ),	/* Flags:  out, return, base type, */
/* 428 */	NdrFcShort( 0x10 ),	/* ia64, axp64 Stack size/offset = 16 */
/* 430 */	0x8,		/* FC_LONG */
			0x0,		/* 0 */

	/* Procedure SetLinkState */

/* 432 */	0x33,		/* FC_AUTO_HANDLE */
			0x6c,		/* Old Flags:  object, Oi2 */
/* 434 */	NdrFcLong( 0x0 ),	/* 0 */
/* 438 */	NdrFcShort( 0x3 ),	/* 3 */
/* 440 */	NdrFcShort( 0x58 ),	/* ia64, axp64 Stack size/offset = 88 */
/* 442 */	NdrFcShort( 0x48 ),	/* 72 */
/* 444 */	NdrFcShort( 0x8 ),	/* 8 */
/* 446 */	0x46,		/* Oi2 Flags:  clt must size, has return, has ext, */
			0x9,		/* 9 */
/* 448 */	0xa,		/* 10 */
			0x1,		/* Ext Flags:  new corr desc, */
/* 450 */	NdrFcShort( 0x0 ),	/* 0 */
/* 452 */	NdrFcShort( 0x0 ),	/* 0 */
/* 454 */	NdrFcShort( 0x0 ),	/* 0 */
/* 456 */	NdrFcShort( 0x0 ),	/* 0 */

	/* Parameter szLinkDomainName */

/* 458 */	NdrFcShort( 0x10b ),	/* Flags:  must size, must free, in, simple ref, */
/* 460 */	NdrFcShort( 0x8 ),	/* ia64, axp64 Stack size/offset = 8 */
/* 462 */	NdrFcShort( 0xaa ),	/* Type Offset=170 */

	/* Parameter guidRouterGUID */

/* 464 */	NdrFcShort( 0x8a ),	/* Flags:  must free, in, by val, */
/* 466 */	NdrFcShort( 0x10 ),	/* ia64, axp64 Stack size/offset = 16 */
/* 468 */	NdrFcShort( 0xb2 ),	/* Type Offset=178 */

	/* Parameter dwScheduleID */

/* 470 */	NdrFcShort( 0x48 ),	/* Flags:  in, base type, */
/* 472 */	NdrFcShort( 0x20 ),	/* ia64, axp64 Stack size/offset = 32 */
/* 474 */	0x8,		/* FC_LONG */
			0x0,		/* 0 */

	/* Parameter szConnectorName */

/* 476 */	NdrFcShort( 0x10b ),	/* Flags:  must size, must free, in, simple ref, */
/* 478 */	NdrFcShort( 0x28 ),	/* ia64, axp64 Stack size/offset = 40 */
/* 480 */	NdrFcShort( 0xaa ),	/* Type Offset=170 */

	/* Parameter dwSetLinkState */

/* 482 */	NdrFcShort( 0x48 ),	/* Flags:  in, base type, */
/* 484 */	NdrFcShort( 0x30 ),	/* ia64, axp64 Stack size/offset = 48 */
/* 486 */	0x8,		/* FC_LONG */
			0x0,		/* 0 */

	/* Parameter dwUnsetLinkState */

/* 488 */	NdrFcShort( 0x48 ),	/* Flags:  in, base type, */
/* 490 */	NdrFcShort( 0x38 ),	/* ia64, axp64 Stack size/offset = 56 */
/* 492 */	0x8,		/* FC_LONG */
			0x0,		/* 0 */

	/* Parameter pftNextScheduled */

/* 494 */	NdrFcShort( 0x10a ),	/* Flags:  must free, in, simple ref, */
/* 496 */	NdrFcShort( 0x40 ),	/* ia64, axp64 Stack size/offset = 64 */
/* 498 */	NdrFcShort( 0xc2 ),	/* Type Offset=194 */

	/* Parameter pMessageRouter */

/* 500 */	NdrFcShort( 0xb ),	/* Flags:  must size, must free, in, */
/* 502 */	NdrFcShort( 0x48 ),	/* ia64, axp64 Stack size/offset = 72 */
/* 504 */	NdrFcShort( 0xca ),	/* Type Offset=202 */

	/* Return value */

/* 506 */	NdrFcShort( 0x70 ),	/* Flags:  out, return, base type, */
/* 508 */	NdrFcShort( 0x50 ),	/* ia64, axp64 Stack size/offset = 80 */
/* 510 */	0x8,		/* FC_LONG */
			0x0,		/* 0 */

	/* Procedure LinkStateNotify */

/* 512 */	0x33,		/* FC_AUTO_HANDLE */
			0x6c,		/* Old Flags:  object, Oi2 */
/* 514 */	NdrFcLong( 0x0 ),	/* 0 */
/* 518 */	NdrFcShort( 0x3 ),	/* 3 */
/* 520 */	NdrFcShort( 0x60 ),	/* ia64, axp64 Stack size/offset = 96 */
/* 522 */	NdrFcShort( 0x48 ),	/* 72 */
/* 524 */	NdrFcShort( 0x28 ),	/* 40 */
/* 526 */	0x46,		/* Oi2 Flags:  clt must size, has return, has ext, */
			0xa,		/* 10 */
/* 528 */	0xa,		/* 10 */
			0x1,		/* Ext Flags:  new corr desc, */
/* 530 */	NdrFcShort( 0x0 ),	/* 0 */
/* 532 */	NdrFcShort( 0x0 ),	/* 0 */
/* 534 */	NdrFcShort( 0x0 ),	/* 0 */
/* 536 */	NdrFcShort( 0x0 ),	/* 0 */

	/* Parameter szLinkDomainName */

/* 538 */	NdrFcShort( 0x10b ),	/* Flags:  must size, must free, in, simple ref, */
/* 540 */	NdrFcShort( 0x8 ),	/* ia64, axp64 Stack size/offset = 8 */
/* 542 */	NdrFcShort( 0xaa ),	/* Type Offset=170 */

	/* Parameter guidRouterGUID */

/* 544 */	NdrFcShort( 0x8a ),	/* Flags:  must free, in, by val, */
/* 546 */	NdrFcShort( 0x10 ),	/* ia64, axp64 Stack size/offset = 16 */
/* 548 */	NdrFcShort( 0xb2 ),	/* Type Offset=178 */

	/* Parameter dwScheduleID */

/* 550 */	NdrFcShort( 0x48 ),	/* Flags:  in, base type, */
/* 552 */	NdrFcShort( 0x20 ),	/* ia64, axp64 Stack size/offset = 32 */
/* 554 */	0x8,		/* FC_LONG */
			0x0,		/* 0 */

	/* Parameter szConnectorName */

/* 556 */	NdrFcShort( 0x10b ),	/* Flags:  must size, must free, in, simple ref, */
/* 558 */	NdrFcShort( 0x28 ),	/* ia64, axp64 Stack size/offset = 40 */
/* 560 */	NdrFcShort( 0xaa ),	/* Type Offset=170 */

	/* Parameter dwLinkState */

/* 562 */	NdrFcShort( 0x48 ),	/* Flags:  in, base type, */
/* 564 */	NdrFcShort( 0x30 ),	/* ia64, axp64 Stack size/offset = 48 */
/* 566 */	0x8,		/* FC_LONG */
			0x0,		/* 0 */

	/* Parameter cConsecutiveFailures */

/* 568 */	NdrFcShort( 0x48 ),	/* Flags:  in, base type, */
/* 570 */	NdrFcShort( 0x38 ),	/* ia64, axp64 Stack size/offset = 56 */
/* 572 */	0x8,		/* FC_LONG */
			0x0,		/* 0 */

	/* Parameter pftNextScheduled */

/* 574 */	NdrFcShort( 0x11a ),	/* Flags:  must free, in, out, simple ref, */
/* 576 */	NdrFcShort( 0x40 ),	/* ia64, axp64 Stack size/offset = 64 */
/* 578 */	NdrFcShort( 0xc2 ),	/* Type Offset=194 */

	/* Parameter pdwSetLinkState */

/* 580 */	NdrFcShort( 0x2150 ),	/* Flags:  out, base type, simple ref, srv alloc size=8 */
/* 582 */	NdrFcShort( 0x48 ),	/* ia64, axp64 Stack size/offset = 72 */
/* 584 */	0x8,		/* FC_LONG */
			0x0,		/* 0 */

	/* Parameter pdwUnsetLinkState */

/* 586 */	NdrFcShort( 0x2150 ),	/* Flags:  out, base type, simple ref, srv alloc size=8 */
/* 588 */	NdrFcShort( 0x50 ),	/* ia64, axp64 Stack size/offset = 80 */
/* 590 */	0x8,		/* FC_LONG */
			0x0,		/* 0 */

	/* Return value */

/* 592 */	NdrFcShort( 0x70 ),	/* Flags:  out, return, base type, */
/* 594 */	NdrFcShort( 0x58 ),	/* ia64, axp64 Stack size/offset = 88 */
/* 596 */	0x8,		/* FC_LONG */
			0x0,		/* 0 */

	/* Procedure SetQueryString */

/* 598 */	0x33,		/* FC_AUTO_HANDLE */
			0x6c,		/* Old Flags:  object, Oi2 */
/* 600 */	NdrFcLong( 0x0 ),	/* 0 */
/* 604 */	NdrFcShort( 0x3 ),	/* 3 */
/* 606 */	NdrFcShort( 0x18 ),	/* ia64, axp64 Stack size/offset = 24 */
/* 608 */	NdrFcShort( 0x0 ),	/* 0 */
/* 610 */	NdrFcShort( 0x8 ),	/* 8 */
/* 612 */	0x46,		/* Oi2 Flags:  clt must size, has return, has ext, */
			0x2,		/* 2 */
/* 614 */	0xa,		/* 10 */
			0x1,		/* Ext Flags:  new corr desc, */
/* 616 */	NdrFcShort( 0x0 ),	/* 0 */
/* 618 */	NdrFcShort( 0x0 ),	/* 0 */
/* 620 */	NdrFcShort( 0x0 ),	/* 0 */
/* 622 */	NdrFcShort( 0x0 ),	/* 0 */

	/* Parameter pszQueryString */

/* 624 */	NdrFcShort( 0xb ),	/* Flags:  must size, must free, in, */
/* 626 */	NdrFcShort( 0x8 ),	/* ia64, axp64 Stack size/offset = 8 */
/* 628 */	NdrFcShort( 0xdc ),	/* Type Offset=220 */

	/* Return value */

/* 630 */	NdrFcShort( 0x70 ),	/* Flags:  out, return, base type, */
/* 632 */	NdrFcShort( 0x10 ),	/* ia64, axp64 Stack size/offset = 16 */
/* 634 */	0x8,		/* FC_LONG */
			0x0,		/* 0 */

	/* Procedure GetQueryString */

/* 636 */	0x33,		/* FC_AUTO_HANDLE */
			0x6c,		/* Old Flags:  object, Oi2 */
/* 638 */	NdrFcLong( 0x0 ),	/* 0 */
/* 642 */	NdrFcShort( 0x4 ),	/* 4 */
/* 644 */	NdrFcShort( 0x18 ),	/* ia64, axp64 Stack size/offset = 24 */
/* 646 */	NdrFcShort( 0x0 ),	/* 0 */
/* 648 */	NdrFcShort( 0x8 ),	/* 8 */
/* 650 */	0x45,		/* Oi2 Flags:  srv must size, has return, has ext, */
			0x2,		/* 2 */
/* 652 */	0xa,		/* 10 */
			0x1,		/* Ext Flags:  new corr desc, */
/* 654 */	NdrFcShort( 0x0 ),	/* 0 */
/* 656 */	NdrFcShort( 0x0 ),	/* 0 */
/* 658 */	NdrFcShort( 0x0 ),	/* 0 */
/* 660 */	NdrFcShort( 0x0 ),	/* 0 */

	/* Parameter ppszQueryString */

/* 662 */	NdrFcShort( 0x2013 ),	/* Flags:  must size, must free, out, srv alloc size=8 */
/* 664 */	NdrFcShort( 0x8 ),	/* ia64, axp64 Stack size/offset = 8 */
/* 666 */	NdrFcShort( 0xe0 ),	/* Type Offset=224 */

	/* Return value */

/* 668 */	NdrFcShort( 0x70 ),	/* Flags:  out, return, base type, */
/* 670 */	NdrFcShort( 0x10 ),	/* ia64, axp64 Stack size/offset = 16 */
/* 672 */	0x8,		/* FC_LONG */
			0x0,		/* 0 */

	/* Procedure Register */

/* 674 */	0x33,		/* FC_AUTO_HANDLE */
			0x6c,		/* Old Flags:  object, Oi2 */
/* 676 */	NdrFcLong( 0x0 ),	/* 0 */
/* 680 */	NdrFcShort( 0x3 ),	/* 3 */
/* 682 */	NdrFcShort( 0x18 ),	/* ia64, axp64 Stack size/offset = 24 */
/* 684 */	NdrFcShort( 0x0 ),	/* 0 */
/* 686 */	NdrFcShort( 0x8 ),	/* 8 */
/* 688 */	0x46,		/* Oi2 Flags:  clt must size, has return, has ext, */
			0x2,		/* 2 */
/* 690 */	0xa,		/* 10 */
			0x1,		/* Ext Flags:  new corr desc, */
/* 692 */	NdrFcShort( 0x0 ),	/* 0 */
/* 694 */	NdrFcShort( 0x0 ),	/* 0 */
/* 696 */	NdrFcShort( 0x0 ),	/* 0 */
/* 698 */	NdrFcShort( 0x0 ),	/* 0 */

	/* Parameter __MIDL_0011 */

/* 700 */	NdrFcShort( 0xb ),	/* Flags:  must size, must free, in, */
/* 702 */	NdrFcShort( 0x8 ),	/* ia64, axp64 Stack size/offset = 8 */
/* 704 */	NdrFcShort( 0xe8 ),	/* Type Offset=232 */

	/* Return value */

/* 706 */	NdrFcShort( 0x70 ),	/* Flags:  out, return, base type, */
/* 708 */	NdrFcShort( 0x10 ),	/* ia64, axp64 Stack size/offset = 16 */
/* 710 */	0x8,		/* FC_LONG */
			0x0,		/* 0 */

			0x0
        }
    };

static const MIDL_TYPE_FORMAT_STRING __MIDL_TypeFormatString =
    {
        0,
        {
			NdrFcShort( 0x0 ),	/* 0 */
/*  2 */	
			0x2f,		/* FC_IP */
			0x5a,		/* FC_CONSTANT_IID */
/*  4 */	NdrFcLong( 0x0 ),	/* 0 */
/*  8 */	NdrFcShort( 0x0 ),	/* 0 */
/* 10 */	NdrFcShort( 0x0 ),	/* 0 */
/* 12 */	0xc0,		/* 192 */
			0x0,		/* 0 */
/* 14 */	0x0,		/* 0 */
			0x0,		/* 0 */
/* 16 */	0x0,		/* 0 */
			0x0,		/* 0 */
/* 18 */	0x0,		/* 0 */
			0x46,		/* 70 */
/* 20 */	
			0x2f,		/* FC_IP */
			0x5a,		/* FC_CONSTANT_IID */
/* 22 */	NdrFcLong( 0xab95fb40 ),	/* -1416234176 */
/* 26 */	NdrFcShort( 0xa34f ),	/* -23729 */
/* 28 */	NdrFcShort( 0x11d1 ),	/* 4561 */
/* 30 */	0xaa,		/* 170 */
			0x8a,		/* 138 */
/* 32 */	0x0,		/* 0 */
			0xaa,		/* 170 */
/* 34 */	0x0,		/* 0 */
			0x6b,		/* 107 */
/* 36 */	0xc8,		/* 200 */
			0xb,		/* 11 */
/* 38 */	
			0x2f,		/* FC_IP */
			0x5a,		/* FC_CONSTANT_IID */
/* 40 */	NdrFcLong( 0x5f15c533 ),	/* 1595262259 */
/* 44 */	NdrFcShort( 0xe90e ),	/* -5874 */
/* 46 */	NdrFcShort( 0x11d1 ),	/* 4561 */
/* 48 */	0x88,		/* 136 */
			0x52,		/* 82 */
/* 50 */	0x0,		/* 0 */
			0xc0,		/* 192 */
/* 52 */	0x4f,		/* 79 */
			0xa3,		/* 163 */
/* 54 */	0x5b,		/* 91 */
			0x86,		/* 134 */
/* 56 */	
			0x2f,		/* FC_IP */
			0x5a,		/* FC_CONSTANT_IID */
/* 58 */	NdrFcLong( 0x0 ),	/* 0 */
/* 62 */	NdrFcShort( 0x0 ),	/* 0 */
/* 64 */	NdrFcShort( 0x0 ),	/* 0 */
/* 66 */	0xc0,		/* 192 */
			0x0,		/* 0 */
/* 68 */	0x0,		/* 0 */
			0x0,		/* 0 */
/* 70 */	0x0,		/* 0 */
			0x0,		/* 0 */
/* 72 */	0x0,		/* 0 */
			0x46,		/* 70 */
/* 74 */	
			0x2f,		/* FC_IP */
			0x5a,		/* FC_CONSTANT_IID */
/* 76 */	NdrFcLong( 0xab95fb40 ),	/* -1416234176 */
/* 80 */	NdrFcShort( 0xa34f ),	/* -23729 */
/* 82 */	NdrFcShort( 0x11d1 ),	/* 4561 */
/* 84 */	0xaa,		/* 170 */
			0x8a,		/* 138 */
/* 86 */	0x0,		/* 0 */
			0xaa,		/* 170 */
/* 88 */	0x0,		/* 0 */
			0x6b,		/* 107 */
/* 90 */	0xc8,		/* 200 */
			0xb,		/* 11 */
/* 92 */	
			0x2f,		/* FC_IP */
			0x5a,		/* FC_CONSTANT_IID */
/* 94 */	NdrFcLong( 0xc849b5f2 ),	/* -934693390 */
/* 98 */	NdrFcShort( 0xa80 ),	/* 2688 */
/* 100 */	NdrFcShort( 0x11d2 ),	/* 4562 */
/* 102 */	0xaa,		/* 170 */
			0x67,		/* 103 */
/* 104 */	0x0,		/* 0 */
			0xc0,		/* 192 */
/* 106 */	0x4f,		/* 79 */
			0xa3,		/* 163 */
/* 108 */	0x5b,		/* 91 */
			0x82,		/* 130 */
/* 110 */	
			0x2f,		/* FC_IP */
			0x5a,		/* FC_CONSTANT_IID */
/* 112 */	NdrFcLong( 0xe38f9ad2 ),	/* -477127982 */
/* 116 */	NdrFcShort( 0xa82 ),	/* 2690 */
/* 118 */	NdrFcShort( 0x11d2 ),	/* 4562 */
/* 120 */	0xaa,		/* 170 */
			0x67,		/* 103 */
/* 122 */	0x0,		/* 0 */
			0xc0,		/* 192 */
/* 124 */	0x4f,		/* 79 */
			0xa3,		/* 163 */
/* 126 */	0x5b,		/* 91 */
			0x82,		/* 130 */
/* 128 */	
			0x2f,		/* FC_IP */
			0x5a,		/* FC_CONSTANT_IID */
/* 130 */	NdrFcLong( 0x5e4fc9da ),	/* 1582287322 */
/* 134 */	NdrFcShort( 0x3e3b ),	/* 15931 */
/* 136 */	NdrFcShort( 0x11d3 ),	/* 4563 */
/* 138 */	0x88,		/* 136 */
			0xf1,		/* 241 */
/* 140 */	0x0,		/* 0 */
			0xc0,		/* 192 */
/* 142 */	0x4f,		/* 79 */
			0xa3,		/* 163 */
/* 144 */	0x5b,		/* 91 */
			0x86,		/* 134 */
/* 146 */	
			0x2f,		/* FC_IP */
			0x5a,		/* FC_CONSTANT_IID */
/* 148 */	NdrFcLong( 0xa928ad12 ),	/* -1456952046 */
/* 152 */	NdrFcShort( 0x1610 ),	/* 5648 */
/* 154 */	NdrFcShort( 0x11d2 ),	/* 4562 */
/* 156 */	0x9e,		/* 158 */
			0x2,		/* 2 */
/* 158 */	0x0,		/* 0 */
			0xc0,		/* 192 */
/* 160 */	0x4f,		/* 79 */
			0xa3,		/* 163 */
/* 162 */	0x22,		/* 34 */
			0xba,		/* 186 */
/* 164 */	
			0x11, 0xc,	/* FC_RP [alloced_on_stack] [simple_pointer] */
/* 166 */	0x8,		/* FC_LONG */
			0x5c,		/* FC_PAD */
/* 168 */	
			0x11, 0x8,	/* FC_RP [simple_pointer] */
/* 170 */	
			0x22,		/* FC_C_CSTRING */
			0x5c,		/* FC_PAD */
/* 172 */	
			0x1d,		/* FC_SMFARRAY */
			0x0,		/* 0 */
/* 174 */	NdrFcShort( 0x8 ),	/* 8 */
/* 176 */	0x2,		/* FC_CHAR */
			0x5b,		/* FC_END */
/* 178 */	
			0x15,		/* FC_STRUCT */
			0x3,		/* 3 */
/* 180 */	NdrFcShort( 0x10 ),	/* 16 */
/* 182 */	0x8,		/* FC_LONG */
			0x6,		/* FC_SHORT */
/* 184 */	0x6,		/* FC_SHORT */
			0x4c,		/* FC_EMBEDDED_COMPLEX */
/* 186 */	0x0,		/* 0 */
			NdrFcShort( 0xfffffff1 ),	/* Offset= -15 (172) */
			0x5b,		/* FC_END */
/* 190 */	
			0x11, 0x0,	/* FC_RP */
/* 192 */	NdrFcShort( 0x2 ),	/* Offset= 2 (194) */
/* 194 */	
			0x15,		/* FC_STRUCT */
			0x3,		/* 3 */
/* 196 */	NdrFcShort( 0x8 ),	/* 8 */
/* 198 */	0x8,		/* FC_LONG */
			0x8,		/* FC_LONG */
/* 200 */	0x5c,		/* FC_PAD */
			0x5b,		/* FC_END */
/* 202 */	
			0x2f,		/* FC_IP */
			0x5a,		/* FC_CONSTANT_IID */
/* 204 */	NdrFcLong( 0xa928ad14 ),	/* -1456952044 */
/* 208 */	NdrFcShort( 0x1610 ),	/* 5648 */
/* 210 */	NdrFcShort( 0x11d2 ),	/* 4562 */
/* 212 */	0x9e,		/* 158 */
			0x2,		/* 2 */
/* 214 */	0x0,		/* 0 */
			0xc0,		/* 192 */
/* 216 */	0x4f,		/* 79 */
			0xa3,		/* 163 */
/* 218 */	0x22,		/* 34 */
			0xba,		/* 186 */
/* 220 */	
			0x12, 0x8,	/* FC_UP [simple_pointer] */
/* 222 */	
			0x22,		/* FC_C_CSTRING */
			0x5c,		/* FC_PAD */
/* 224 */	
			0x11, 0x14,	/* FC_RP [alloced_on_stack] [pointer_deref] */
/* 226 */	NdrFcShort( 0x2 ),	/* Offset= 2 (228) */
/* 228 */	
			0x13, 0x8,	/* FC_OP [simple_pointer] */
/* 230 */	
			0x22,		/* FC_C_CSTRING */
			0x5c,		/* FC_PAD */
/* 232 */	
			0x2f,		/* FC_IP */
			0x5a,		/* FC_CONSTANT_IID */
/* 234 */	NdrFcLong( 0x86f9da7b ),	/* -2030445957 */
/* 238 */	NdrFcShort( 0xeb6e ),	/* -5266 */
/* 240 */	NdrFcShort( 0x11d1 ),	/* 4561 */
/* 242 */	0x9d,		/* 157 */
			0xf3,		/* 243 */
/* 244 */	0x0,		/* 0 */
			0xc0,		/* 192 */
/* 246 */	0x4f,		/* 79 */
			0xa3,		/* 163 */
/* 248 */	0x22,		/* 34 */
			0xba,		/* 186 */

			0x0
        }
    };

const CInterfaceProxyVtbl * _SmtpEvent_ProxyVtblList[] = 
{
    ( CInterfaceProxyVtbl *) &_ISmtpInCommandSinkProxyVtbl,
    ( CInterfaceProxyVtbl *) &_IMailTransportOnPreCategorizeProxyVtbl,
    ( CInterfaceProxyVtbl *) &_IMailTransportSetRouterResetProxyVtbl,
    ( CInterfaceProxyVtbl *) &_IMailTransportRouterResetProxyVtbl,
    ( CInterfaceProxyVtbl *) &_IMailTransportRoutingEngineProxyVtbl,
    ( CInterfaceProxyVtbl *) &_IMessageRouterProxyVtbl,
    ( CInterfaceProxyVtbl *) &_IMailTransportSubmissionProxyVtbl,
    ( CInterfaceProxyVtbl *) &_ISmtpServerResponseSinkProxyVtbl,
    ( CInterfaceProxyVtbl *) &_ISmtpInCallbackSinkProxyVtbl,
    ( CInterfaceProxyVtbl *) &_IMailTransportRouterSetLinkStateProxyVtbl,
    ( CInterfaceProxyVtbl *) &_IMessageRouterLinkStateNotificationProxyVtbl,
    ( CInterfaceProxyVtbl *) &_IMailTransportOnPostCategorizeProxyVtbl,
    ( CInterfaceProxyVtbl *) &_IMailTransportNotifyProxyVtbl,
    ( CInterfaceProxyVtbl *) &_IMailTransportCategorizeProxyVtbl,
    ( CInterfaceProxyVtbl *) &_ICategorizerQueriesProxyVtbl,
    ( CInterfaceProxyVtbl *) &_ICategorizerAsyncContextProxyVtbl,
    ( CInterfaceProxyVtbl *) &_ICategorizerItemAttributesProxyVtbl,
    ( CInterfaceProxyVtbl *) &_ICategorizerItemRawAttributesProxyVtbl,
    ( CInterfaceProxyVtbl *) &_ICategorizerListResolveProxyVtbl,
    ( CInterfaceProxyVtbl *) &_ISmtpOutCommandSinkProxyVtbl,
    0
};

const CInterfaceStubVtbl * _SmtpEvent_StubVtblList[] = 
{
    ( CInterfaceStubVtbl *) &_ISmtpInCommandSinkStubVtbl,
    ( CInterfaceStubVtbl *) &_IMailTransportOnPreCategorizeStubVtbl,
    ( CInterfaceStubVtbl *) &_IMailTransportSetRouterResetStubVtbl,
    ( CInterfaceStubVtbl *) &_IMailTransportRouterResetStubVtbl,
    ( CInterfaceStubVtbl *) &_IMailTransportRoutingEngineStubVtbl,
    ( CInterfaceStubVtbl *) &_IMessageRouterStubVtbl,
    ( CInterfaceStubVtbl *) &_IMailTransportSubmissionStubVtbl,
    ( CInterfaceStubVtbl *) &_ISmtpServerResponseSinkStubVtbl,
    ( CInterfaceStubVtbl *) &_ISmtpInCallbackSinkStubVtbl,
    ( CInterfaceStubVtbl *) &_IMailTransportRouterSetLinkStateStubVtbl,
    ( CInterfaceStubVtbl *) &_IMessageRouterLinkStateNotificationStubVtbl,
    ( CInterfaceStubVtbl *) &_IMailTransportOnPostCategorizeStubVtbl,
    ( CInterfaceStubVtbl *) &_IMailTransportNotifyStubVtbl,
    ( CInterfaceStubVtbl *) &_IMailTransportCategorizeStubVtbl,
    ( CInterfaceStubVtbl *) &_ICategorizerQueriesStubVtbl,
    ( CInterfaceStubVtbl *) &_ICategorizerAsyncContextStubVtbl,
    ( CInterfaceStubVtbl *) &_ICategorizerItemAttributesStubVtbl,
    ( CInterfaceStubVtbl *) &_ICategorizerItemRawAttributesStubVtbl,
    ( CInterfaceStubVtbl *) &_ICategorizerListResolveStubVtbl,
    ( CInterfaceStubVtbl *) &_ISmtpOutCommandSinkStubVtbl,
    0
};

PCInterfaceName const _SmtpEvent_InterfaceNamesList[] = 
{
    "ISmtpInCommandSink",
    "IMailTransportOnPreCategorize",
    "IMailTransportSetRouterReset",
    "IMailTransportRouterReset",
    "IMailTransportRoutingEngine",
    "IMessageRouter",
    "IMailTransportSubmission",
    "ISmtpServerResponseSink",
    "ISmtpInCallbackSink",
    "IMailTransportRouterSetLinkState",
    "IMessageRouterLinkStateNotification",
    "IMailTransportOnPostCategorize",
    "IMailTransportNotify",
    "IMailTransportCategorize",
    "ICategorizerQueries",
    "ICategorizerAsyncContext",
    "ICategorizerItemAttributes",
    "ICategorizerItemRawAttributes",
    "ICategorizerListResolve",
    "ISmtpOutCommandSink",
    0
};


#define _SmtpEvent_CHECK_IID(n)	IID_GENERIC_CHECK_IID( _SmtpEvent, pIID, n)

int __stdcall _SmtpEvent_IID_Lookup( const IID * pIID, int * pIndex )
{
    IID_BS_LOOKUP_SETUP

    IID_BS_LOOKUP_INITIAL_TEST( _SmtpEvent, 20, 16 )
    IID_BS_LOOKUP_NEXT_TEST( _SmtpEvent, 8 )
    IID_BS_LOOKUP_NEXT_TEST( _SmtpEvent, 4 )
    IID_BS_LOOKUP_NEXT_TEST( _SmtpEvent, 2 )
    IID_BS_LOOKUP_NEXT_TEST( _SmtpEvent, 1 )
    IID_BS_LOOKUP_RETURN_RESULT( _SmtpEvent, 20, *pIndex )
    
}

const ExtendedProxyFileInfo SmtpEvent_ProxyFileInfo = 
{
    (PCInterfaceProxyVtblList *) & _SmtpEvent_ProxyVtblList,
    (PCInterfaceStubVtblList *) & _SmtpEvent_StubVtblList,
    (const PCInterfaceName * ) & _SmtpEvent_InterfaceNamesList,
    0, // no delegation
    & _SmtpEvent_IID_Lookup, 
    20,
    2,
    0, /* table of [async_uuid] interfaces */
    0, /* Filler1 */
    0, /* Filler2 */
    0  /* Filler3 */
};


#endif /* defined(_M_IA64) || defined(_M_AXP64)*/

