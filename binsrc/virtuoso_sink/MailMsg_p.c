/*
 *  
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *  
 *  Copyright (C) 1998-2019 OpenLink Software
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

/* verify that the <rpcproxy.h> version is high enough to compile this file*/
#ifndef __REDQ_RPCPROXY_H_VERSION__
#define __REQUIRED_RPCPROXY_H_VERSION__ 440
#endif


#include "rpcproxy.h"
#ifndef __RPCPROXY_H_VERSION__
#error this stub requires an updated version of <rpcproxy.h>
#endif // __RPCPROXY_H_VERSION__


#include "MailMsg.h"

#define TYPE_FORMAT_STRING_SIZE   169                               
#define PROC_FORMAT_STRING_SIZE   199                               
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


/* Standard interface: __MIDL_itf_MailMsg_0000, ver. 0.0,
   GUID={0x00000000,0x0000,0x0000,{0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00}} */


/* Object interface: IUnknown, ver. 0.0,
   GUID={0x00000000,0x0000,0x0000,{0xC0,0x00,0x00,0x00,0x00,0x00,0x00,0x46}} */


/* Object interface: IMailMsgNotify, ver. 0.0,
   GUID={0x0f7c3c30,0xa8ad,0x11d1,{0xaa,0x91,0x00,0xaa,0x00,0x6b,0xc8,0x0b}} */


extern const MIDL_STUB_DESC Object_StubDesc;


#pragma code_seg(".orpc")

/* [helpstring] */ HRESULT STDMETHODCALLTYPE IMailMsgNotify_Notify_Proxy( 
    IMailMsgNotify __RPC_FAR * This,
    /* [in] */ HRESULT hrRes)
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
            *(( HRESULT __RPC_FAR * )_StubMsg.Buffer)++ = hrRes;
            
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

void __RPC_STUB IMailMsgNotify_Notify_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase)
{
    HRESULT _RetVal;
    MIDL_STUB_MESSAGE _StubMsg;
    HRESULT hrRes;
    
NdrStubInitialize(
                     _pRpcMessage,
                     &_StubMsg,
                     &Object_StubDesc,
                     _pRpcChannelBuffer);
    RpcTryFinally
        {
        if ( (_pRpcMessage->DataRepresentation & 0X0000FFFFUL) != NDR_LOCAL_DATA_REPRESENTATION )
            NdrConvert( (PMIDL_STUB_MESSAGE) &_StubMsg, (PFORMAT_STRING) &__MIDL_ProcFormatString.Format[0] );
        
        hrRes = *(( HRESULT __RPC_FAR * )_StubMsg.Buffer)++;
        
        
        *_pdwStubPhase = STUB_CALL_SERVER;
        _RetVal = (((IMailMsgNotify*) ((CStdStubBuffer *)This)->pvServerObject)->lpVtbl) -> Notify((IMailMsgNotify *) ((CStdStubBuffer *)This)->pvServerObject,hrRes);
        
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

const CINTERFACE_PROXY_VTABLE(4) _IMailMsgNotifyProxyVtbl = 
{
    &IID_IMailMsgNotify,
    IUnknown_QueryInterface_Proxy,
    IUnknown_AddRef_Proxy,
    IUnknown_Release_Proxy ,
    IMailMsgNotify_Notify_Proxy
};


static const PRPC_STUB_FUNCTION IMailMsgNotify_table[] =
{
    IMailMsgNotify_Notify_Stub
};

const CInterfaceStubVtbl _IMailMsgNotifyStubVtbl =
{
    &IID_IMailMsgNotify,
    0,
    4,
    &IMailMsgNotify_table[-3],
    CStdStubBuffer_METHODS
};


/* Standard interface: __MIDL_itf_MailMsg_0244, ver. 0.0,
   GUID={0x00000000,0x0000,0x0000,{0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00}} */


/* Object interface: IMailMsgPropertyStream, ver. 0.0,
   GUID={0xa44819c0,0xa7cf,0x11d1,{0xaa,0x91,0x00,0xaa,0x00,0x6b,0xc8,0x0b}} */


/* Object interface: IMailMsgRecipientsBase, ver. 0.0,
   GUID={0xd1a97920,0xa891,0x11d1,{0xaa,0x91,0x00,0xaa,0x00,0x6b,0xc8,0x0b}} */


extern const MIDL_STUB_DESC Object_StubDesc;


#pragma code_seg(".orpc")

/* [helpstring] */ HRESULT STDMETHODCALLTYPE IMailMsgRecipientsBase_Count_Proxy( 
    IMailMsgRecipientsBase __RPC_FAR * This,
    /* [out] */ DWORD __RPC_FAR *pdwCount)
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
        
        
        
        if(!pdwCount)
            {
            RpcRaiseException(RPC_X_NULL_REF_POINTER);
            }
        RpcTryFinally
            {
            
            _StubMsg.BufferLength = 0U;
            NdrProxyGetBuffer(This, &_StubMsg);
            NdrProxySendReceive(This, &_StubMsg);
            
            if ( (_RpcMessage.DataRepresentation & 0X0000FFFFUL) != NDR_LOCAL_DATA_REPRESENTATION )
                NdrConvert( (PMIDL_STUB_MESSAGE) &_StubMsg, (PFORMAT_STRING) &__MIDL_ProcFormatString.Format[4] );
            
            *pdwCount = *(( DWORD __RPC_FAR * )_StubMsg.Buffer)++;
            
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
                         ( PFORMAT_STRING  )&__MIDL_TypeFormatString.Format[2],
                         ( void __RPC_FAR * )pdwCount);
        _RetVal = NdrProxyErrorHandler(RpcExceptionCode());
        }
    RpcEndExcept
    return _RetVal;
}

void __RPC_STUB IMailMsgRecipientsBase_Count_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase)
{
    DWORD _M0;
    HRESULT _RetVal;
    MIDL_STUB_MESSAGE _StubMsg;
    DWORD __RPC_FAR *pdwCount;
    
NdrStubInitialize(
                     _pRpcMessage,
                     &_StubMsg,
                     &Object_StubDesc,
                     _pRpcChannelBuffer);
    ( DWORD __RPC_FAR * )pdwCount = 0;
    RpcTryFinally
        {
        pdwCount = &_M0;
        
        *_pdwStubPhase = STUB_CALL_SERVER;
        _RetVal = (((IMailMsgRecipientsBase*) ((CStdStubBuffer *)This)->pvServerObject)->lpVtbl) -> Count((IMailMsgRecipientsBase *) ((CStdStubBuffer *)This)->pvServerObject,pdwCount);
        
        *_pdwStubPhase = STUB_MARSHAL;
        
        _StubMsg.BufferLength = 4U + 4U;
        NdrStubGetBuffer(This, _pRpcChannelBuffer, &_StubMsg);
        *(( DWORD __RPC_FAR * )_StubMsg.Buffer)++ = *pdwCount;
        
        *(( HRESULT __RPC_FAR * )_StubMsg.Buffer)++ = _RetVal;
        
        }
    RpcFinally
        {
        }
    RpcEndFinally
    _pRpcMessage->BufferLength = 
        (unsigned int)(_StubMsg.Buffer - (unsigned char __RPC_FAR *)_pRpcMessage->Buffer);
    
}


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IMailMsgRecipientsBase_Item_Proxy( 
    IMailMsgRecipientsBase __RPC_FAR * This,
    /* [in] */ DWORD dwIndex,
    /* [in] */ DWORD dwWhichName,
    /* [in] */ DWORD cchLength,
    /* [size_is][out] */ LPSTR pszName)
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
        
        
        
        if(!pszName)
            {
            RpcRaiseException(RPC_X_NULL_REF_POINTER);
            }
        RpcTryFinally
            {
            
            _StubMsg.BufferLength = 4U + 4U + 4U;
            NdrProxyGetBuffer(This, &_StubMsg);
            *(( DWORD __RPC_FAR * )_StubMsg.Buffer)++ = dwIndex;
            
            *(( DWORD __RPC_FAR * )_StubMsg.Buffer)++ = dwWhichName;
            
            *(( DWORD __RPC_FAR * )_StubMsg.Buffer)++ = cchLength;
            
            NdrProxySendReceive(This, &_StubMsg);
            
            if ( (_RpcMessage.DataRepresentation & 0X0000FFFFUL) != NDR_LOCAL_DATA_REPRESENTATION )
                NdrConvert( (PMIDL_STUB_MESSAGE) &_StubMsg, (PFORMAT_STRING) &__MIDL_ProcFormatString.Format[10] );
            
            NdrConformantStringUnmarshall( (PMIDL_STUB_MESSAGE) &_StubMsg,
                                           (unsigned char __RPC_FAR * __RPC_FAR *)&pszName,
                                           (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[10],
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
        _StubMsg.MaxCount = ( unsigned long  )cchLength;
        
        NdrClearOutParameters(
                         ( PMIDL_STUB_MESSAGE  )&_StubMsg,
                         ( PFORMAT_STRING  )&__MIDL_TypeFormatString.Format[6],
                         ( void __RPC_FAR * )pszName);
        _RetVal = NdrProxyErrorHandler(RpcExceptionCode());
        }
    RpcEndExcept
    return _RetVal;
}

void __RPC_STUB IMailMsgRecipientsBase_Item_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase)
{
    HRESULT _RetVal;
    MIDL_STUB_MESSAGE _StubMsg;
    DWORD cchLength;
    DWORD dwIndex;
    DWORD dwWhichName;
    LPSTR pszName;
    
NdrStubInitialize(
                     _pRpcMessage,
                     &_StubMsg,
                     &Object_StubDesc,
                     _pRpcChannelBuffer);
    ( LPSTR  )pszName = 0;
    RpcTryFinally
        {
        if ( (_pRpcMessage->DataRepresentation & 0X0000FFFFUL) != NDR_LOCAL_DATA_REPRESENTATION )
            NdrConvert( (PMIDL_STUB_MESSAGE) &_StubMsg, (PFORMAT_STRING) &__MIDL_ProcFormatString.Format[10] );
        
        dwIndex = *(( DWORD __RPC_FAR * )_StubMsg.Buffer)++;
        
        dwWhichName = *(( DWORD __RPC_FAR * )_StubMsg.Buffer)++;
        
        cchLength = *(( DWORD __RPC_FAR * )_StubMsg.Buffer)++;
        
        pszName = NdrAllocate(&_StubMsg,cchLength * 1);
        
        *_pdwStubPhase = STUB_CALL_SERVER;
        _RetVal = (((IMailMsgRecipientsBase*) ((CStdStubBuffer *)This)->pvServerObject)->lpVtbl) -> Item(
        (IMailMsgRecipientsBase *) ((CStdStubBuffer *)This)->pvServerObject,
        dwIndex,
        dwWhichName,
        cchLength,
        pszName);
        
        *_pdwStubPhase = STUB_MARSHAL;
        
        _StubMsg.BufferLength = 12U + 11U;
        _StubMsg.MaxCount = ( unsigned long  )cchLength;
        
        NdrConformantStringBufferSize( (PMIDL_STUB_MESSAGE) &_StubMsg,
                                       (unsigned char __RPC_FAR *)pszName,
                                       (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[10] );
        
        _StubMsg.BufferLength += 16;
        
        NdrStubGetBuffer(This, _pRpcChannelBuffer, &_StubMsg);
        _StubMsg.MaxCount = ( unsigned long  )cchLength;
        
        NdrConformantStringMarshall( (PMIDL_STUB_MESSAGE)& _StubMsg,
                                     (unsigned char __RPC_FAR *)pszName,
                                     (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[10] );
        
        _StubMsg.Buffer = (unsigned char __RPC_FAR *)(((long)_StubMsg.Buffer + 3) & ~ 0x3);
        *(( HRESULT __RPC_FAR * )_StubMsg.Buffer)++ = _RetVal;
        
        }
    RpcFinally
        {
        _StubMsg.MaxCount = ( unsigned long  )cchLength;
        
        NdrPointerFree( &_StubMsg,
                        (unsigned char __RPC_FAR *)pszName,
                        &__MIDL_TypeFormatString.Format[6] );
        
        }
    RpcEndFinally
    _pRpcMessage->BufferLength = 
        (unsigned int)(_StubMsg.Buffer - (unsigned char __RPC_FAR *)_pRpcMessage->Buffer);
    
}


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IMailMsgRecipientsBase_PutProperty_Proxy( 
    IMailMsgRecipientsBase __RPC_FAR * This,
    /* [in] */ DWORD dwIndex,
    /* [in] */ DWORD dwPropID,
    /* [in] */ DWORD cbLength,
    /* [unique][length_is][size_is][in] */ BYTE __RPC_FAR *pbValue)
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
            
            _StubMsg.BufferLength = 4U + 4U + 4U + 16U;
            _StubMsg.MaxCount = ( unsigned long  )cbLength;
            _StubMsg.Offset = ( unsigned long  )0;
            _StubMsg.ActualCount = ( unsigned long  )cbLength;
            
            NdrPointerBufferSize( (PMIDL_STUB_MESSAGE) &_StubMsg,
                                  (unsigned char __RPC_FAR *)pbValue,
                                  (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[16] );
            
            NdrProxyGetBuffer(This, &_StubMsg);
            *(( DWORD __RPC_FAR * )_StubMsg.Buffer)++ = dwIndex;
            
            *(( DWORD __RPC_FAR * )_StubMsg.Buffer)++ = dwPropID;
            
            *(( DWORD __RPC_FAR * )_StubMsg.Buffer)++ = cbLength;
            
            _StubMsg.MaxCount = ( unsigned long  )cbLength;
            _StubMsg.Offset = ( unsigned long  )0;
            _StubMsg.ActualCount = ( unsigned long  )cbLength;
            
            NdrPointerMarshall( (PMIDL_STUB_MESSAGE)& _StubMsg,
                                (unsigned char __RPC_FAR *)pbValue,
                                (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[16] );
            
            NdrProxySendReceive(This, &_StubMsg);
            
            if ( (_RpcMessage.DataRepresentation & 0X0000FFFFUL) != NDR_LOCAL_DATA_REPRESENTATION )
                NdrConvert( (PMIDL_STUB_MESSAGE) &_StubMsg, (PFORMAT_STRING) &__MIDL_ProcFormatString.Format[22] );
            
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

void __RPC_STUB IMailMsgRecipientsBase_PutProperty_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase)
{
    HRESULT _RetVal;
    MIDL_STUB_MESSAGE _StubMsg;
    DWORD cbLength;
    DWORD dwIndex;
    DWORD dwPropID;
    BYTE __RPC_FAR *pbValue;
    
NdrStubInitialize(
                     _pRpcMessage,
                     &_StubMsg,
                     &Object_StubDesc,
                     _pRpcChannelBuffer);
    ( BYTE __RPC_FAR * )pbValue = 0;
    RpcTryFinally
        {
        if ( (_pRpcMessage->DataRepresentation & 0X0000FFFFUL) != NDR_LOCAL_DATA_REPRESENTATION )
            NdrConvert( (PMIDL_STUB_MESSAGE) &_StubMsg, (PFORMAT_STRING) &__MIDL_ProcFormatString.Format[22] );
        
        dwIndex = *(( DWORD __RPC_FAR * )_StubMsg.Buffer)++;
        
        dwPropID = *(( DWORD __RPC_FAR * )_StubMsg.Buffer)++;
        
        cbLength = *(( DWORD __RPC_FAR * )_StubMsg.Buffer)++;
        
        NdrPointerUnmarshall( (PMIDL_STUB_MESSAGE) &_StubMsg,
                              (unsigned char __RPC_FAR * __RPC_FAR *)&pbValue,
                              (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[16],
                              (unsigned char)0 );
        
        
        *_pdwStubPhase = STUB_CALL_SERVER;
        _RetVal = (((IMailMsgRecipientsBase*) ((CStdStubBuffer *)This)->pvServerObject)->lpVtbl) -> PutProperty(
               (IMailMsgRecipientsBase *) ((CStdStubBuffer *)This)->pvServerObject,
               dwIndex,
               dwPropID,
               cbLength,
               pbValue);
        
        *_pdwStubPhase = STUB_MARSHAL;
        
        _StubMsg.BufferLength = 4U;
        _StubMsg.BufferLength += 16;
        
        NdrStubGetBuffer(This, _pRpcChannelBuffer, &_StubMsg);
        *(( HRESULT __RPC_FAR * )_StubMsg.Buffer)++ = _RetVal;
        
        }
    RpcFinally
        {
        _StubMsg.MaxCount = ( unsigned long  )cbLength;
        _StubMsg.Offset = ( unsigned long  )0;
        _StubMsg.ActualCount = ( unsigned long  )cbLength;
        
        NdrPointerFree( &_StubMsg,
                        (unsigned char __RPC_FAR *)pbValue,
                        &__MIDL_TypeFormatString.Format[16] );
        
        }
    RpcEndFinally
    _pRpcMessage->BufferLength = 
        (unsigned int)(_StubMsg.Buffer - (unsigned char __RPC_FAR *)_pRpcMessage->Buffer);
    
}


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IMailMsgRecipientsBase_GetProperty_Proxy( 
    IMailMsgRecipientsBase __RPC_FAR * This,
    /* [in] */ DWORD dwIndex,
    /* [in] */ DWORD dwPropID,
    /* [in] */ DWORD cbLength,
    /* [out] */ DWORD __RPC_FAR *pcbLength,
    /* [length_is][size_is][out] */ BYTE __RPC_FAR *pbValue)
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
                      6);
        
        
        
        if(!pcbLength)
            {
            RpcRaiseException(RPC_X_NULL_REF_POINTER);
            }
        if(!pbValue)
            {
            RpcRaiseException(RPC_X_NULL_REF_POINTER);
            }
        RpcTryFinally
            {
            
            _StubMsg.BufferLength = 4U + 4U + 4U;
            NdrProxyGetBuffer(This, &_StubMsg);
            *(( DWORD __RPC_FAR * )_StubMsg.Buffer)++ = dwIndex;
            
            *(( DWORD __RPC_FAR * )_StubMsg.Buffer)++ = dwPropID;
            
            *(( DWORD __RPC_FAR * )_StubMsg.Buffer)++ = cbLength;
            
            NdrProxySendReceive(This, &_StubMsg);
            
            if ( (_RpcMessage.DataRepresentation & 0X0000FFFFUL) != NDR_LOCAL_DATA_REPRESENTATION )
                NdrConvert( (PMIDL_STUB_MESSAGE) &_StubMsg, (PFORMAT_STRING) &__MIDL_ProcFormatString.Format[34] );
            
            *pcbLength = *(( DWORD __RPC_FAR * )_StubMsg.Buffer)++;
            
            NdrConformantVaryingArrayUnmarshall( (PMIDL_STUB_MESSAGE) &_StubMsg,
                                                 (unsigned char __RPC_FAR * __RPC_FAR *)&pbValue,
                                                 (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[38],
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
                         ( PFORMAT_STRING  )&__MIDL_TypeFormatString.Format[2],
                         ( void __RPC_FAR * )pcbLength);
        _StubMsg.MaxCount = ( unsigned long  )cbLength;
        _StubMsg.Offset = 0;
        _StubMsg.ActualCount = _StubMsg.MaxCount;
        
        NdrClearOutParameters(
                         ( PMIDL_STUB_MESSAGE  )&_StubMsg,
                         ( PFORMAT_STRING  )&__MIDL_TypeFormatString.Format[34],
                         ( void __RPC_FAR * )pbValue);
        _RetVal = NdrProxyErrorHandler(RpcExceptionCode());
        }
    RpcEndExcept
    return _RetVal;
}

void __RPC_STUB IMailMsgRecipientsBase_GetProperty_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase)
{
    DWORD _M9;
    HRESULT _RetVal;
    MIDL_STUB_MESSAGE _StubMsg;
    DWORD cbLength;
    DWORD dwIndex;
    DWORD dwPropID;
    BYTE __RPC_FAR *pbValue;
    DWORD __RPC_FAR *pcbLength;
    
NdrStubInitialize(
                     _pRpcMessage,
                     &_StubMsg,
                     &Object_StubDesc,
                     _pRpcChannelBuffer);
    ( DWORD __RPC_FAR * )pcbLength = 0;
    ( BYTE __RPC_FAR * )pbValue = 0;
    RpcTryFinally
        {
        if ( (_pRpcMessage->DataRepresentation & 0X0000FFFFUL) != NDR_LOCAL_DATA_REPRESENTATION )
            NdrConvert( (PMIDL_STUB_MESSAGE) &_StubMsg, (PFORMAT_STRING) &__MIDL_ProcFormatString.Format[34] );
        
        dwIndex = *(( DWORD __RPC_FAR * )_StubMsg.Buffer)++;
        
        dwPropID = *(( DWORD __RPC_FAR * )_StubMsg.Buffer)++;
        
        cbLength = *(( DWORD __RPC_FAR * )_StubMsg.Buffer)++;
        
        pcbLength = &_M9;
        pbValue = NdrAllocate(&_StubMsg,cbLength * 1);
        
        *_pdwStubPhase = STUB_CALL_SERVER;
        _RetVal = (((IMailMsgRecipientsBase*) ((CStdStubBuffer *)This)->pvServerObject)->lpVtbl) -> GetProperty(
               (IMailMsgRecipientsBase *) ((CStdStubBuffer *)This)->pvServerObject,
               dwIndex,
               dwPropID,
               cbLength,
               pcbLength,
               pbValue);
        
        *_pdwStubPhase = STUB_MARSHAL;
        
        _StubMsg.BufferLength = 4U + 12U + 11U;
        _StubMsg.MaxCount = ( unsigned long  )cbLength;
        _StubMsg.Offset = ( unsigned long  )0;
        _StubMsg.ActualCount = ( unsigned long  )(pcbLength ? *pcbLength : 0);
        
        NdrConformantVaryingArrayBufferSize( (PMIDL_STUB_MESSAGE) &_StubMsg,
                                             (unsigned char __RPC_FAR *)pbValue,
                                             (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[38] );
        
        _StubMsg.BufferLength += 16;
        
        NdrStubGetBuffer(This, _pRpcChannelBuffer, &_StubMsg);
        *(( DWORD __RPC_FAR * )_StubMsg.Buffer)++ = *pcbLength;
        
        _StubMsg.MaxCount = ( unsigned long  )cbLength;
        _StubMsg.Offset = ( unsigned long  )0;
        _StubMsg.ActualCount = ( unsigned long  )(pcbLength ? *pcbLength : 0);
        
        NdrConformantVaryingArrayMarshall( (PMIDL_STUB_MESSAGE)& _StubMsg,
                                           (unsigned char __RPC_FAR *)pbValue,
                                           (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[38] );
        
        _StubMsg.Buffer = (unsigned char __RPC_FAR *)(((long)_StubMsg.Buffer + 3) & ~ 0x3);
        *(( HRESULT __RPC_FAR * )_StubMsg.Buffer)++ = _RetVal;
        
        }
    RpcFinally
        {
        _StubMsg.MaxCount = ( unsigned long  )cbLength;
        _StubMsg.Offset = ( unsigned long  )0;
        _StubMsg.ActualCount = ( unsigned long  )(pcbLength ? *pcbLength : 0);
        
        NdrPointerFree( &_StubMsg,
                        (unsigned char __RPC_FAR *)pbValue,
                        &__MIDL_TypeFormatString.Format[34] );
        
        }
    RpcEndFinally
    _pRpcMessage->BufferLength = 
        (unsigned int)(_StubMsg.Buffer - (unsigned char __RPC_FAR *)_pRpcMessage->Buffer);
    
}


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IMailMsgRecipientsBase_PutStringA_Proxy( 
    IMailMsgRecipientsBase __RPC_FAR * This,
    /* [in] */ DWORD dwIndex,
    /* [in] */ DWORD dwPropID,
    /* [unique][in] */ LPCSTR pszValue)
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
                      7);
        
        
        
        RpcTryFinally
            {
            
            _StubMsg.BufferLength = 4U + 4U + 16U;
            NdrPointerBufferSize( (PMIDL_STUB_MESSAGE) &_StubMsg,
                                  (unsigned char __RPC_FAR *)pszValue,
                                  (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[52] );
            
            NdrProxyGetBuffer(This, &_StubMsg);
            *(( DWORD __RPC_FAR * )_StubMsg.Buffer)++ = dwIndex;
            
            *(( DWORD __RPC_FAR * )_StubMsg.Buffer)++ = dwPropID;
            
            NdrPointerMarshall( (PMIDL_STUB_MESSAGE)& _StubMsg,
                                (unsigned char __RPC_FAR *)pszValue,
                                (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[52] );
            
            NdrProxySendReceive(This, &_StubMsg);
            
            if ( (_RpcMessage.DataRepresentation & 0X0000FFFFUL) != NDR_LOCAL_DATA_REPRESENTATION )
                NdrConvert( (PMIDL_STUB_MESSAGE) &_StubMsg, (PFORMAT_STRING) &__MIDL_ProcFormatString.Format[50] );
            
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

void __RPC_STUB IMailMsgRecipientsBase_PutStringA_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase)
{
    HRESULT _RetVal;
    MIDL_STUB_MESSAGE _StubMsg;
    DWORD dwIndex;
    DWORD dwPropID;
    LPCSTR pszValue;
    
NdrStubInitialize(
                     _pRpcMessage,
                     &_StubMsg,
                     &Object_StubDesc,
                     _pRpcChannelBuffer);
    ( LPCSTR  )pszValue = 0;
    RpcTryFinally
        {
        if ( (_pRpcMessage->DataRepresentation & 0X0000FFFFUL) != NDR_LOCAL_DATA_REPRESENTATION )
            NdrConvert( (PMIDL_STUB_MESSAGE) &_StubMsg, (PFORMAT_STRING) &__MIDL_ProcFormatString.Format[50] );
        
        dwIndex = *(( DWORD __RPC_FAR * )_StubMsg.Buffer)++;
        
        dwPropID = *(( DWORD __RPC_FAR * )_StubMsg.Buffer)++;
        
        NdrPointerUnmarshall( (PMIDL_STUB_MESSAGE) &_StubMsg,
                              (unsigned char __RPC_FAR * __RPC_FAR *)&pszValue,
                              (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[52],
                              (unsigned char)0 );
        
        
        *_pdwStubPhase = STUB_CALL_SERVER;
        _RetVal = (((IMailMsgRecipientsBase*) ((CStdStubBuffer *)This)->pvServerObject)->lpVtbl) -> PutStringA(
              (IMailMsgRecipientsBase *) ((CStdStubBuffer *)This)->pvServerObject,
              dwIndex,
              dwPropID,
              pszValue);
        
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


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IMailMsgRecipientsBase_GetStringA_Proxy( 
    IMailMsgRecipientsBase __RPC_FAR * This,
    /* [in] */ DWORD dwIndex,
    /* [in] */ DWORD dwPropID,
    /* [in] */ DWORD cchLength,
    /* [size_is][out] */ LPSTR pszValue)
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
        
        
        
        if(!pszValue)
            {
            RpcRaiseException(RPC_X_NULL_REF_POINTER);
            }
        RpcTryFinally
            {
            
            _StubMsg.BufferLength = 4U + 4U + 4U;
            NdrProxyGetBuffer(This, &_StubMsg);
            *(( DWORD __RPC_FAR * )_StubMsg.Buffer)++ = dwIndex;
            
            *(( DWORD __RPC_FAR * )_StubMsg.Buffer)++ = dwPropID;
            
            *(( DWORD __RPC_FAR * )_StubMsg.Buffer)++ = cchLength;
            
            NdrProxySendReceive(This, &_StubMsg);
            
            if ( (_RpcMessage.DataRepresentation & 0X0000FFFFUL) != NDR_LOCAL_DATA_REPRESENTATION )
                NdrConvert( (PMIDL_STUB_MESSAGE) &_StubMsg, (PFORMAT_STRING) &__MIDL_ProcFormatString.Format[60] );
            
            NdrConformantStringUnmarshall( (PMIDL_STUB_MESSAGE) &_StubMsg,
                                           (unsigned char __RPC_FAR * __RPC_FAR *)&pszValue,
                                           (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[60],
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
        _StubMsg.MaxCount = ( unsigned long  )cchLength;
        
        NdrClearOutParameters(
                         ( PMIDL_STUB_MESSAGE  )&_StubMsg,
                         ( PFORMAT_STRING  )&__MIDL_TypeFormatString.Format[56],
                         ( void __RPC_FAR * )pszValue);
        _RetVal = NdrProxyErrorHandler(RpcExceptionCode());
        }
    RpcEndExcept
    return _RetVal;
}

void __RPC_STUB IMailMsgRecipientsBase_GetStringA_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase)
{
    HRESULT _RetVal;
    MIDL_STUB_MESSAGE _StubMsg;
    DWORD cchLength;
    DWORD dwIndex;
    DWORD dwPropID;
    LPSTR pszValue;
    
NdrStubInitialize(
                     _pRpcMessage,
                     &_StubMsg,
                     &Object_StubDesc,
                     _pRpcChannelBuffer);
    ( LPSTR  )pszValue = 0;
    RpcTryFinally
        {
        if ( (_pRpcMessage->DataRepresentation & 0X0000FFFFUL) != NDR_LOCAL_DATA_REPRESENTATION )
            NdrConvert( (PMIDL_STUB_MESSAGE) &_StubMsg, (PFORMAT_STRING) &__MIDL_ProcFormatString.Format[60] );
        
        dwIndex = *(( DWORD __RPC_FAR * )_StubMsg.Buffer)++;
        
        dwPropID = *(( DWORD __RPC_FAR * )_StubMsg.Buffer)++;
        
        cchLength = *(( DWORD __RPC_FAR * )_StubMsg.Buffer)++;
        
        pszValue = NdrAllocate(&_StubMsg,cchLength * 1);
        
        *_pdwStubPhase = STUB_CALL_SERVER;
        _RetVal = (((IMailMsgRecipientsBase*) ((CStdStubBuffer *)This)->pvServerObject)->lpVtbl) -> GetStringA(
              (IMailMsgRecipientsBase *) ((CStdStubBuffer *)This)->pvServerObject,
              dwIndex,
              dwPropID,
              cchLength,
              pszValue);
        
        *_pdwStubPhase = STUB_MARSHAL;
        
        _StubMsg.BufferLength = 12U + 11U;
        _StubMsg.MaxCount = ( unsigned long  )cchLength;
        
        NdrConformantStringBufferSize( (PMIDL_STUB_MESSAGE) &_StubMsg,
                                       (unsigned char __RPC_FAR *)pszValue,
                                       (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[60] );
        
        _StubMsg.BufferLength += 16;
        
        NdrStubGetBuffer(This, _pRpcChannelBuffer, &_StubMsg);
        _StubMsg.MaxCount = ( unsigned long  )cchLength;
        
        NdrConformantStringMarshall( (PMIDL_STUB_MESSAGE)& _StubMsg,
                                     (unsigned char __RPC_FAR *)pszValue,
                                     (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[60] );
        
        _StubMsg.Buffer = (unsigned char __RPC_FAR *)(((long)_StubMsg.Buffer + 3) & ~ 0x3);
        *(( HRESULT __RPC_FAR * )_StubMsg.Buffer)++ = _RetVal;
        
        }
    RpcFinally
        {
        _StubMsg.MaxCount = ( unsigned long  )cchLength;
        
        NdrPointerFree( &_StubMsg,
                        (unsigned char __RPC_FAR *)pszValue,
                        &__MIDL_TypeFormatString.Format[56] );
        
        }
    RpcEndFinally
    _pRpcMessage->BufferLength = 
        (unsigned int)(_StubMsg.Buffer - (unsigned char __RPC_FAR *)_pRpcMessage->Buffer);
    
}


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IMailMsgRecipientsBase_PutStringW_Proxy( 
    IMailMsgRecipientsBase __RPC_FAR * This,
    /* [in] */ DWORD dwIndex,
    /* [in] */ DWORD dwPropID,
    /* [unique][in] */ LPCWSTR pszValue)
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
                      9);
        
        
        
        RpcTryFinally
            {
            
            _StubMsg.BufferLength = 4U + 4U + 16U;
            NdrPointerBufferSize( (PMIDL_STUB_MESSAGE) &_StubMsg,
                                  (unsigned char __RPC_FAR *)pszValue,
                                  (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[66] );
            
            NdrProxyGetBuffer(This, &_StubMsg);
            *(( DWORD __RPC_FAR * )_StubMsg.Buffer)++ = dwIndex;
            
            *(( DWORD __RPC_FAR * )_StubMsg.Buffer)++ = dwPropID;
            
            NdrPointerMarshall( (PMIDL_STUB_MESSAGE)& _StubMsg,
                                (unsigned char __RPC_FAR *)pszValue,
                                (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[66] );
            
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

void __RPC_STUB IMailMsgRecipientsBase_PutStringW_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase)
{
    HRESULT _RetVal;
    MIDL_STUB_MESSAGE _StubMsg;
    DWORD dwIndex;
    DWORD dwPropID;
    LPCWSTR pszValue;
    
NdrStubInitialize(
                     _pRpcMessage,
                     &_StubMsg,
                     &Object_StubDesc,
                     _pRpcChannelBuffer);
    ( LPCWSTR  )pszValue = 0;
    RpcTryFinally
        {
        if ( (_pRpcMessage->DataRepresentation & 0X0000FFFFUL) != NDR_LOCAL_DATA_REPRESENTATION )
            NdrConvert( (PMIDL_STUB_MESSAGE) &_StubMsg, (PFORMAT_STRING) &__MIDL_ProcFormatString.Format[72] );
        
        dwIndex = *(( DWORD __RPC_FAR * )_StubMsg.Buffer)++;
        
        dwPropID = *(( DWORD __RPC_FAR * )_StubMsg.Buffer)++;
        
        NdrPointerUnmarshall( (PMIDL_STUB_MESSAGE) &_StubMsg,
                              (unsigned char __RPC_FAR * __RPC_FAR *)&pszValue,
                              (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[66],
                              (unsigned char)0 );
        
        
        *_pdwStubPhase = STUB_CALL_SERVER;
        _RetVal = (((IMailMsgRecipientsBase*) ((CStdStubBuffer *)This)->pvServerObject)->lpVtbl) -> PutStringW(
              (IMailMsgRecipientsBase *) ((CStdStubBuffer *)This)->pvServerObject,
              dwIndex,
              dwPropID,
              pszValue);
        
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


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IMailMsgRecipientsBase_GetStringW_Proxy( 
    IMailMsgRecipientsBase __RPC_FAR * This,
    /* [in] */ DWORD dwIndex,
    /* [in] */ DWORD dwPropID,
    /* [in] */ DWORD cchLength,
    /* [size_is][out] */ LPWSTR pszValue)
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
                      10);
        
        
        
        if(!pszValue)
            {
            RpcRaiseException(RPC_X_NULL_REF_POINTER);
            }
        RpcTryFinally
            {
            
            _StubMsg.BufferLength = 4U + 4U + 4U;
            NdrProxyGetBuffer(This, &_StubMsg);
            *(( DWORD __RPC_FAR * )_StubMsg.Buffer)++ = dwIndex;
            
            *(( DWORD __RPC_FAR * )_StubMsg.Buffer)++ = dwPropID;
            
            *(( DWORD __RPC_FAR * )_StubMsg.Buffer)++ = cchLength;
            
            NdrProxySendReceive(This, &_StubMsg);
            
            if ( (_RpcMessage.DataRepresentation & 0X0000FFFFUL) != NDR_LOCAL_DATA_REPRESENTATION )
                NdrConvert( (PMIDL_STUB_MESSAGE) &_StubMsg, (PFORMAT_STRING) &__MIDL_ProcFormatString.Format[82] );
            
            NdrConformantStringUnmarshall( (PMIDL_STUB_MESSAGE) &_StubMsg,
                                           (unsigned char __RPC_FAR * __RPC_FAR *)&pszValue,
                                           (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[74],
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
        _StubMsg.MaxCount = ( unsigned long  )cchLength;
        
        NdrClearOutParameters(
                         ( PMIDL_STUB_MESSAGE  )&_StubMsg,
                         ( PFORMAT_STRING  )&__MIDL_TypeFormatString.Format[70],
                         ( void __RPC_FAR * )pszValue);
        _RetVal = NdrProxyErrorHandler(RpcExceptionCode());
        }
    RpcEndExcept
    return _RetVal;
}

void __RPC_STUB IMailMsgRecipientsBase_GetStringW_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase)
{
    HRESULT _RetVal;
    MIDL_STUB_MESSAGE _StubMsg;
    DWORD cchLength;
    DWORD dwIndex;
    DWORD dwPropID;
    LPWSTR pszValue;
    
NdrStubInitialize(
                     _pRpcMessage,
                     &_StubMsg,
                     &Object_StubDesc,
                     _pRpcChannelBuffer);
    ( LPWSTR  )pszValue = 0;
    RpcTryFinally
        {
        if ( (_pRpcMessage->DataRepresentation & 0X0000FFFFUL) != NDR_LOCAL_DATA_REPRESENTATION )
            NdrConvert( (PMIDL_STUB_MESSAGE) &_StubMsg, (PFORMAT_STRING) &__MIDL_ProcFormatString.Format[82] );
        
        dwIndex = *(( DWORD __RPC_FAR * )_StubMsg.Buffer)++;
        
        dwPropID = *(( DWORD __RPC_FAR * )_StubMsg.Buffer)++;
        
        cchLength = *(( DWORD __RPC_FAR * )_StubMsg.Buffer)++;
        
        pszValue = NdrAllocate(&_StubMsg,cchLength * 2);
        
        *_pdwStubPhase = STUB_CALL_SERVER;
        _RetVal = (((IMailMsgRecipientsBase*) ((CStdStubBuffer *)This)->pvServerObject)->lpVtbl) -> GetStringW(
              (IMailMsgRecipientsBase *) ((CStdStubBuffer *)This)->pvServerObject,
              dwIndex,
              dwPropID,
              cchLength,
              pszValue);
        
        *_pdwStubPhase = STUB_MARSHAL;
        
        _StubMsg.BufferLength = 12U + 10U;
        _StubMsg.MaxCount = ( unsigned long  )cchLength;
        
        NdrConformantStringBufferSize( (PMIDL_STUB_MESSAGE) &_StubMsg,
                                       (unsigned char __RPC_FAR *)pszValue,
                                       (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[74] );
        
        _StubMsg.BufferLength += 16;
        
        NdrStubGetBuffer(This, _pRpcChannelBuffer, &_StubMsg);
        _StubMsg.MaxCount = ( unsigned long  )cchLength;
        
        NdrConformantStringMarshall( (PMIDL_STUB_MESSAGE)& _StubMsg,
                                     (unsigned char __RPC_FAR *)pszValue,
                                     (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[74] );
        
        _StubMsg.Buffer = (unsigned char __RPC_FAR *)(((long)_StubMsg.Buffer + 3) & ~ 0x3);
        *(( HRESULT __RPC_FAR * )_StubMsg.Buffer)++ = _RetVal;
        
        }
    RpcFinally
        {
        _StubMsg.MaxCount = ( unsigned long  )cchLength;
        
        NdrPointerFree( &_StubMsg,
                        (unsigned char __RPC_FAR *)pszValue,
                        &__MIDL_TypeFormatString.Format[70] );
        
        }
    RpcEndFinally
    _pRpcMessage->BufferLength = 
        (unsigned int)(_StubMsg.Buffer - (unsigned char __RPC_FAR *)_pRpcMessage->Buffer);
    
}


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IMailMsgRecipientsBase_PutDWORD_Proxy( 
    IMailMsgRecipientsBase __RPC_FAR * This,
    /* [in] */ DWORD dwIndex,
    /* [in] */ DWORD dwPropID,
    /* [in] */ DWORD dwValue)
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
                      11);
        
        
        
        RpcTryFinally
            {
            
            _StubMsg.BufferLength = 4U + 4U + 4U;
            NdrProxyGetBuffer(This, &_StubMsg);
            *(( DWORD __RPC_FAR * )_StubMsg.Buffer)++ = dwIndex;
            
            *(( DWORD __RPC_FAR * )_StubMsg.Buffer)++ = dwPropID;
            
            *(( DWORD __RPC_FAR * )_StubMsg.Buffer)++ = dwValue;
            
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

void __RPC_STUB IMailMsgRecipientsBase_PutDWORD_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase)
{
    HRESULT _RetVal;
    MIDL_STUB_MESSAGE _StubMsg;
    DWORD dwIndex;
    DWORD dwPropID;
    DWORD dwValue;
    
NdrStubInitialize(
                     _pRpcMessage,
                     &_StubMsg,
                     &Object_StubDesc,
                     _pRpcChannelBuffer);
    RpcTryFinally
        {
        if ( (_pRpcMessage->DataRepresentation & 0X0000FFFFUL) != NDR_LOCAL_DATA_REPRESENTATION )
            NdrConvert( (PMIDL_STUB_MESSAGE) &_StubMsg, (PFORMAT_STRING) &__MIDL_ProcFormatString.Format[94] );
        
        dwIndex = *(( DWORD __RPC_FAR * )_StubMsg.Buffer)++;
        
        dwPropID = *(( DWORD __RPC_FAR * )_StubMsg.Buffer)++;
        
        dwValue = *(( DWORD __RPC_FAR * )_StubMsg.Buffer)++;
        
        
        *_pdwStubPhase = STUB_CALL_SERVER;
        _RetVal = (((IMailMsgRecipientsBase*) ((CStdStubBuffer *)This)->pvServerObject)->lpVtbl) -> PutDWORD(
            (IMailMsgRecipientsBase *) ((CStdStubBuffer *)This)->pvServerObject,
            dwIndex,
            dwPropID,
            dwValue);
        
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


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IMailMsgRecipientsBase_GetDWORD_Proxy( 
    IMailMsgRecipientsBase __RPC_FAR * This,
    /* [in] */ DWORD dwIndex,
    /* [in] */ DWORD dwPropID,
    /* [out] */ DWORD __RPC_FAR *pdwValue)
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
                      12);
        
        
        
        if(!pdwValue)
            {
            RpcRaiseException(RPC_X_NULL_REF_POINTER);
            }
        RpcTryFinally
            {
            
            _StubMsg.BufferLength = 4U + 4U;
            NdrProxyGetBuffer(This, &_StubMsg);
            *(( DWORD __RPC_FAR * )_StubMsg.Buffer)++ = dwIndex;
            
            *(( DWORD __RPC_FAR * )_StubMsg.Buffer)++ = dwPropID;
            
            NdrProxySendReceive(This, &_StubMsg);
            
            if ( (_RpcMessage.DataRepresentation & 0X0000FFFFUL) != NDR_LOCAL_DATA_REPRESENTATION )
                NdrConvert( (PMIDL_STUB_MESSAGE) &_StubMsg, (PFORMAT_STRING) &__MIDL_ProcFormatString.Format[102] );
            
            *pdwValue = *(( DWORD __RPC_FAR * )_StubMsg.Buffer)++;
            
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
                         ( PFORMAT_STRING  )&__MIDL_TypeFormatString.Format[2],
                         ( void __RPC_FAR * )pdwValue);
        _RetVal = NdrProxyErrorHandler(RpcExceptionCode());
        }
    RpcEndExcept
    return _RetVal;
}

void __RPC_STUB IMailMsgRecipientsBase_GetDWORD_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase)
{
    DWORD _M18;
    HRESULT _RetVal;
    MIDL_STUB_MESSAGE _StubMsg;
    DWORD dwIndex;
    DWORD dwPropID;
    DWORD __RPC_FAR *pdwValue;
    
NdrStubInitialize(
                     _pRpcMessage,
                     &_StubMsg,
                     &Object_StubDesc,
                     _pRpcChannelBuffer);
    ( DWORD __RPC_FAR * )pdwValue = 0;
    RpcTryFinally
        {
        if ( (_pRpcMessage->DataRepresentation & 0X0000FFFFUL) != NDR_LOCAL_DATA_REPRESENTATION )
            NdrConvert( (PMIDL_STUB_MESSAGE) &_StubMsg, (PFORMAT_STRING) &__MIDL_ProcFormatString.Format[102] );
        
        dwIndex = *(( DWORD __RPC_FAR * )_StubMsg.Buffer)++;
        
        dwPropID = *(( DWORD __RPC_FAR * )_StubMsg.Buffer)++;
        
        pdwValue = &_M18;
        
        *_pdwStubPhase = STUB_CALL_SERVER;
        _RetVal = (((IMailMsgRecipientsBase*) ((CStdStubBuffer *)This)->pvServerObject)->lpVtbl) -> GetDWORD(
            (IMailMsgRecipientsBase *) ((CStdStubBuffer *)This)->pvServerObject,
            dwIndex,
            dwPropID,
            pdwValue);
        
        *_pdwStubPhase = STUB_MARSHAL;
        
        _StubMsg.BufferLength = 4U + 4U;
        NdrStubGetBuffer(This, _pRpcChannelBuffer, &_StubMsg);
        *(( DWORD __RPC_FAR * )_StubMsg.Buffer)++ = *pdwValue;
        
        *(( HRESULT __RPC_FAR * )_StubMsg.Buffer)++ = _RetVal;
        
        }
    RpcFinally
        {
        }
    RpcEndFinally
    _pRpcMessage->BufferLength = 
        (unsigned int)(_StubMsg.Buffer - (unsigned char __RPC_FAR *)_pRpcMessage->Buffer);
    
}


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IMailMsgRecipientsBase_PutBool_Proxy( 
    IMailMsgRecipientsBase __RPC_FAR * This,
    /* [in] */ DWORD dwIndex,
    /* [in] */ DWORD dwPropID,
    /* [in] */ DWORD dwValue)
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
                      13);
        
        
        
        RpcTryFinally
            {
            
            _StubMsg.BufferLength = 4U + 4U + 4U;
            NdrProxyGetBuffer(This, &_StubMsg);
            *(( DWORD __RPC_FAR * )_StubMsg.Buffer)++ = dwIndex;
            
            *(( DWORD __RPC_FAR * )_StubMsg.Buffer)++ = dwPropID;
            
            *(( DWORD __RPC_FAR * )_StubMsg.Buffer)++ = dwValue;
            
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

void __RPC_STUB IMailMsgRecipientsBase_PutBool_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase)
{
    HRESULT _RetVal;
    MIDL_STUB_MESSAGE _StubMsg;
    DWORD dwIndex;
    DWORD dwPropID;
    DWORD dwValue;
    
NdrStubInitialize(
                     _pRpcMessage,
                     &_StubMsg,
                     &Object_StubDesc,
                     _pRpcChannelBuffer);
    RpcTryFinally
        {
        if ( (_pRpcMessage->DataRepresentation & 0X0000FFFFUL) != NDR_LOCAL_DATA_REPRESENTATION )
            NdrConvert( (PMIDL_STUB_MESSAGE) &_StubMsg, (PFORMAT_STRING) &__MIDL_ProcFormatString.Format[94] );
        
        dwIndex = *(( DWORD __RPC_FAR * )_StubMsg.Buffer)++;
        
        dwPropID = *(( DWORD __RPC_FAR * )_StubMsg.Buffer)++;
        
        dwValue = *(( DWORD __RPC_FAR * )_StubMsg.Buffer)++;
        
        
        *_pdwStubPhase = STUB_CALL_SERVER;
        _RetVal = (((IMailMsgRecipientsBase*) ((CStdStubBuffer *)This)->pvServerObject)->lpVtbl) -> PutBool(
           (IMailMsgRecipientsBase *) ((CStdStubBuffer *)This)->pvServerObject,
           dwIndex,
           dwPropID,
           dwValue);
        
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


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IMailMsgRecipientsBase_GetBool_Proxy( 
    IMailMsgRecipientsBase __RPC_FAR * This,
    /* [in] */ DWORD dwIndex,
    /* [in] */ DWORD dwPropID,
    /* [out] */ DWORD __RPC_FAR *pdwValue)
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
                      14);
        
        
        
        if(!pdwValue)
            {
            RpcRaiseException(RPC_X_NULL_REF_POINTER);
            }
        RpcTryFinally
            {
            
            _StubMsg.BufferLength = 4U + 4U;
            NdrProxyGetBuffer(This, &_StubMsg);
            *(( DWORD __RPC_FAR * )_StubMsg.Buffer)++ = dwIndex;
            
            *(( DWORD __RPC_FAR * )_StubMsg.Buffer)++ = dwPropID;
            
            NdrProxySendReceive(This, &_StubMsg);
            
            if ( (_RpcMessage.DataRepresentation & 0X0000FFFFUL) != NDR_LOCAL_DATA_REPRESENTATION )
                NdrConvert( (PMIDL_STUB_MESSAGE) &_StubMsg, (PFORMAT_STRING) &__MIDL_ProcFormatString.Format[102] );
            
            *pdwValue = *(( DWORD __RPC_FAR * )_StubMsg.Buffer)++;
            
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
                         ( PFORMAT_STRING  )&__MIDL_TypeFormatString.Format[2],
                         ( void __RPC_FAR * )pdwValue);
        _RetVal = NdrProxyErrorHandler(RpcExceptionCode());
        }
    RpcEndExcept
    return _RetVal;
}

void __RPC_STUB IMailMsgRecipientsBase_GetBool_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase)
{
    DWORD _M19;
    HRESULT _RetVal;
    MIDL_STUB_MESSAGE _StubMsg;
    DWORD dwIndex;
    DWORD dwPropID;
    DWORD __RPC_FAR *pdwValue;
    
NdrStubInitialize(
                     _pRpcMessage,
                     &_StubMsg,
                     &Object_StubDesc,
                     _pRpcChannelBuffer);
    ( DWORD __RPC_FAR * )pdwValue = 0;
    RpcTryFinally
        {
        if ( (_pRpcMessage->DataRepresentation & 0X0000FFFFUL) != NDR_LOCAL_DATA_REPRESENTATION )
            NdrConvert( (PMIDL_STUB_MESSAGE) &_StubMsg, (PFORMAT_STRING) &__MIDL_ProcFormatString.Format[102] );
        
        dwIndex = *(( DWORD __RPC_FAR * )_StubMsg.Buffer)++;
        
        dwPropID = *(( DWORD __RPC_FAR * )_StubMsg.Buffer)++;
        
        pdwValue = &_M19;
        
        *_pdwStubPhase = STUB_CALL_SERVER;
        _RetVal = (((IMailMsgRecipientsBase*) ((CStdStubBuffer *)This)->pvServerObject)->lpVtbl) -> GetBool(
           (IMailMsgRecipientsBase *) ((CStdStubBuffer *)This)->pvServerObject,
           dwIndex,
           dwPropID,
           pdwValue);
        
        *_pdwStubPhase = STUB_MARSHAL;
        
        _StubMsg.BufferLength = 4U + 4U;
        NdrStubGetBuffer(This, _pRpcChannelBuffer, &_StubMsg);
        *(( DWORD __RPC_FAR * )_StubMsg.Buffer)++ = *pdwValue;
        
        *(( HRESULT __RPC_FAR * )_StubMsg.Buffer)++ = _RetVal;
        
        }
    RpcFinally
        {
        }
    RpcEndFinally
    _pRpcMessage->BufferLength = 
        (unsigned int)(_StubMsg.Buffer - (unsigned char __RPC_FAR *)_pRpcMessage->Buffer);
    
}

const CINTERFACE_PROXY_VTABLE(15) _IMailMsgRecipientsBaseProxyVtbl = 
{
    &IID_IMailMsgRecipientsBase,
    IUnknown_QueryInterface_Proxy,
    IUnknown_AddRef_Proxy,
    IUnknown_Release_Proxy ,
    IMailMsgRecipientsBase_Count_Proxy ,
    IMailMsgRecipientsBase_Item_Proxy ,
    IMailMsgRecipientsBase_PutProperty_Proxy ,
    IMailMsgRecipientsBase_GetProperty_Proxy ,
    IMailMsgRecipientsBase_PutStringA_Proxy ,
    IMailMsgRecipientsBase_GetStringA_Proxy ,
    IMailMsgRecipientsBase_PutStringW_Proxy ,
    IMailMsgRecipientsBase_GetStringW_Proxy ,
    IMailMsgRecipientsBase_PutDWORD_Proxy ,
    IMailMsgRecipientsBase_GetDWORD_Proxy ,
    IMailMsgRecipientsBase_PutBool_Proxy ,
    IMailMsgRecipientsBase_GetBool_Proxy
};


static const PRPC_STUB_FUNCTION IMailMsgRecipientsBase_table[] =
{
    IMailMsgRecipientsBase_Count_Stub,
    IMailMsgRecipientsBase_Item_Stub,
    IMailMsgRecipientsBase_PutProperty_Stub,
    IMailMsgRecipientsBase_GetProperty_Stub,
    IMailMsgRecipientsBase_PutStringA_Stub,
    IMailMsgRecipientsBase_GetStringA_Stub,
    IMailMsgRecipientsBase_PutStringW_Stub,
    IMailMsgRecipientsBase_GetStringW_Stub,
    IMailMsgRecipientsBase_PutDWORD_Stub,
    IMailMsgRecipientsBase_GetDWORD_Stub,
    IMailMsgRecipientsBase_PutBool_Stub,
    IMailMsgRecipientsBase_GetBool_Stub
};

const CInterfaceStubVtbl _IMailMsgRecipientsBaseStubVtbl =
{
    &IID_IMailMsgRecipientsBase,
    0,
    15,
    &IMailMsgRecipientsBase_table[-3],
    CStdStubBuffer_METHODS
};


/* Object interface: IMailMsgRecipientsAdd, ver. 0.0,
   GUID={0x4c28a700,0xa892,0x11d1,{0xaa,0x91,0x00,0xaa,0x00,0x6b,0xc8,0x0b}} */


extern const MIDL_STUB_DESC Object_StubDesc;


#pragma code_seg(".orpc")
const CINTERFACE_PROXY_VTABLE(17) _IMailMsgRecipientsAddProxyVtbl = 
{
    &IID_IMailMsgRecipientsAdd,
    IUnknown_QueryInterface_Proxy,
    IUnknown_AddRef_Proxy,
    IUnknown_Release_Proxy ,
    IMailMsgRecipientsBase_Count_Proxy ,
    IMailMsgRecipientsBase_Item_Proxy ,
    IMailMsgRecipientsBase_PutProperty_Proxy ,
    IMailMsgRecipientsBase_GetProperty_Proxy ,
    IMailMsgRecipientsBase_PutStringA_Proxy ,
    IMailMsgRecipientsBase_GetStringA_Proxy ,
    IMailMsgRecipientsBase_PutStringW_Proxy ,
    IMailMsgRecipientsBase_GetStringW_Proxy ,
    IMailMsgRecipientsBase_PutDWORD_Proxy ,
    IMailMsgRecipientsBase_GetDWORD_Proxy ,
    IMailMsgRecipientsBase_PutBool_Proxy ,
    IMailMsgRecipientsBase_GetBool_Proxy ,
    0 /* IMailMsgRecipientsAdd_AddPrimary_Proxy */ ,
    0 /* IMailMsgRecipientsAdd_AddSecondary_Proxy */
};


static const PRPC_STUB_FUNCTION IMailMsgRecipientsAdd_table[] =
{
    IMailMsgRecipientsBase_Count_Stub,
    IMailMsgRecipientsBase_Item_Stub,
    IMailMsgRecipientsBase_PutProperty_Stub,
    IMailMsgRecipientsBase_GetProperty_Stub,
    IMailMsgRecipientsBase_PutStringA_Stub,
    IMailMsgRecipientsBase_GetStringA_Stub,
    IMailMsgRecipientsBase_PutStringW_Stub,
    IMailMsgRecipientsBase_GetStringW_Stub,
    IMailMsgRecipientsBase_PutDWORD_Stub,
    IMailMsgRecipientsBase_GetDWORD_Stub,
    IMailMsgRecipientsBase_PutBool_Stub,
    IMailMsgRecipientsBase_GetBool_Stub,
    STUB_FORWARDING_FUNCTION,
    STUB_FORWARDING_FUNCTION
};

const CInterfaceStubVtbl _IMailMsgRecipientsAddStubVtbl =
{
    &IID_IMailMsgRecipientsAdd,
    0,
    17,
    &IMailMsgRecipientsAdd_table[-3],
    CStdStubBuffer_METHODS
};


/* Object interface: IMailMsgRecipients, ver. 0.0,
   GUID={0x19507fe0,0xa892,0x11d1,{0xaa,0x91,0x00,0xaa,0x00,0x6b,0xc8,0x0b}} */


extern const MIDL_STUB_DESC Object_StubDesc;


#pragma code_seg(".orpc")

/* [helpstring] */ HRESULT STDMETHODCALLTYPE IMailMsgRecipients_Commit_Proxy( 
    IMailMsgRecipients __RPC_FAR * This,
    /* [in] */ DWORD dwIndex,
    /* [unique][in] */ IMailMsgNotify __RPC_FAR *pNotify)
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
                      15);
        
        
        
        RpcTryFinally
            {
            
            _StubMsg.BufferLength = 4U + 0U;
            NdrInterfacePointerBufferSize( (PMIDL_STUB_MESSAGE) &_StubMsg,
                                           (unsigned char __RPC_FAR *)pNotify,
                                           (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[80] );
            
            NdrProxyGetBuffer(This, &_StubMsg);
            *(( DWORD __RPC_FAR * )_StubMsg.Buffer)++ = dwIndex;
            
            NdrInterfacePointerMarshall( (PMIDL_STUB_MESSAGE)& _StubMsg,
                                         (unsigned char __RPC_FAR *)pNotify,
                                         (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[80] );
            
            NdrProxySendReceive(This, &_StubMsg);
            
            if ( (_RpcMessage.DataRepresentation & 0X0000FFFFUL) != NDR_LOCAL_DATA_REPRESENTATION )
                NdrConvert( (PMIDL_STUB_MESSAGE) &_StubMsg, (PFORMAT_STRING) &__MIDL_ProcFormatString.Format[112] );
            
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

void __RPC_STUB IMailMsgRecipients_Commit_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase)
{
    HRESULT _RetVal;
    MIDL_STUB_MESSAGE _StubMsg;
    DWORD dwIndex;
    IMailMsgNotify __RPC_FAR *pNotify;
    
NdrStubInitialize(
                     _pRpcMessage,
                     &_StubMsg,
                     &Object_StubDesc,
                     _pRpcChannelBuffer);
    pNotify = 0;
    RpcTryFinally
        {
        if ( (_pRpcMessage->DataRepresentation & 0X0000FFFFUL) != NDR_LOCAL_DATA_REPRESENTATION )
            NdrConvert( (PMIDL_STUB_MESSAGE) &_StubMsg, (PFORMAT_STRING) &__MIDL_ProcFormatString.Format[112] );
        
        dwIndex = *(( DWORD __RPC_FAR * )_StubMsg.Buffer)++;
        
        NdrInterfacePointerUnmarshall( (PMIDL_STUB_MESSAGE) &_StubMsg,
                                       (unsigned char __RPC_FAR * __RPC_FAR *)&pNotify,
                                       (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[80],
                                       (unsigned char)0 );
        
        
        *_pdwStubPhase = STUB_CALL_SERVER;
        _RetVal = (((IMailMsgRecipients*) ((CStdStubBuffer *)This)->pvServerObject)->lpVtbl) -> Commit(
          (IMailMsgRecipients *) ((CStdStubBuffer *)This)->pvServerObject,
          dwIndex,
          pNotify);
        
        *_pdwStubPhase = STUB_MARSHAL;
        
        _StubMsg.BufferLength = 4U;
        NdrStubGetBuffer(This, _pRpcChannelBuffer, &_StubMsg);
        *(( HRESULT __RPC_FAR * )_StubMsg.Buffer)++ = _RetVal;
        
        }
    RpcFinally
        {
        NdrInterfacePointerFree( &_StubMsg,
                                 (unsigned char __RPC_FAR *)pNotify,
                                 &__MIDL_TypeFormatString.Format[80] );
        
        }
    RpcEndFinally
    _pRpcMessage->BufferLength = 
        (unsigned int)(_StubMsg.Buffer - (unsigned char __RPC_FAR *)_pRpcMessage->Buffer);
    
}


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IMailMsgRecipients_DomainCount_Proxy( 
    IMailMsgRecipients __RPC_FAR * This,
    /* [out] */ DWORD __RPC_FAR *pdwCount)
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
                      16);
        
        
        
        if(!pdwCount)
            {
            RpcRaiseException(RPC_X_NULL_REF_POINTER);
            }
        RpcTryFinally
            {
            
            _StubMsg.BufferLength = 0U;
            NdrProxyGetBuffer(This, &_StubMsg);
            NdrProxySendReceive(This, &_StubMsg);
            
            if ( (_RpcMessage.DataRepresentation & 0X0000FFFFUL) != NDR_LOCAL_DATA_REPRESENTATION )
                NdrConvert( (PMIDL_STUB_MESSAGE) &_StubMsg, (PFORMAT_STRING) &__MIDL_ProcFormatString.Format[4] );
            
            *pdwCount = *(( DWORD __RPC_FAR * )_StubMsg.Buffer)++;
            
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
                         ( PFORMAT_STRING  )&__MIDL_TypeFormatString.Format[2],
                         ( void __RPC_FAR * )pdwCount);
        _RetVal = NdrProxyErrorHandler(RpcExceptionCode());
        }
    RpcEndExcept
    return _RetVal;
}

void __RPC_STUB IMailMsgRecipients_DomainCount_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase)
{
    DWORD _M20;
    HRESULT _RetVal;
    MIDL_STUB_MESSAGE _StubMsg;
    DWORD __RPC_FAR *pdwCount;
    
NdrStubInitialize(
                     _pRpcMessage,
                     &_StubMsg,
                     &Object_StubDesc,
                     _pRpcChannelBuffer);
    ( DWORD __RPC_FAR * )pdwCount = 0;
    RpcTryFinally
        {
        pdwCount = &_M20;
        
        *_pdwStubPhase = STUB_CALL_SERVER;
        _RetVal = (((IMailMsgRecipients*) ((CStdStubBuffer *)This)->pvServerObject)->lpVtbl) -> DomainCount((IMailMsgRecipients *) ((CStdStubBuffer *)This)->pvServerObject,pdwCount);
        
        *_pdwStubPhase = STUB_MARSHAL;
        
        _StubMsg.BufferLength = 4U + 4U;
        NdrStubGetBuffer(This, _pRpcChannelBuffer, &_StubMsg);
        *(( DWORD __RPC_FAR * )_StubMsg.Buffer)++ = *pdwCount;
        
        *(( HRESULT __RPC_FAR * )_StubMsg.Buffer)++ = _RetVal;
        
        }
    RpcFinally
        {
        }
    RpcEndFinally
    _pRpcMessage->BufferLength = 
        (unsigned int)(_StubMsg.Buffer - (unsigned char __RPC_FAR *)_pRpcMessage->Buffer);
    
}


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IMailMsgRecipients_DomainItem_Proxy( 
    IMailMsgRecipients __RPC_FAR * This,
    /* [in] */ DWORD dwIndex,
    /* [in] */ DWORD cchLength,
    /* [size_is][out] */ LPSTR pszDomain,
    /* [out] */ DWORD __RPC_FAR *pdwRecipientIndex,
    /* [out] */ DWORD __RPC_FAR *pdwRecipientCount)
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
                      17);
        
        
        
        if(!pszDomain)
            {
            RpcRaiseException(RPC_X_NULL_REF_POINTER);
            }
        if(!pdwRecipientIndex)
            {
            RpcRaiseException(RPC_X_NULL_REF_POINTER);
            }
        if(!pdwRecipientCount)
            {
            RpcRaiseException(RPC_X_NULL_REF_POINTER);
            }
        RpcTryFinally
            {
            
            _StubMsg.BufferLength = 4U + 4U;
            NdrProxyGetBuffer(This, &_StubMsg);
            *(( DWORD __RPC_FAR * )_StubMsg.Buffer)++ = dwIndex;
            
            *(( DWORD __RPC_FAR * )_StubMsg.Buffer)++ = cchLength;
            
            NdrProxySendReceive(This, &_StubMsg);
            
            if ( (_RpcMessage.DataRepresentation & 0X0000FFFFUL) != NDR_LOCAL_DATA_REPRESENTATION )
                NdrConvert( (PMIDL_STUB_MESSAGE) &_StubMsg, (PFORMAT_STRING) &__MIDL_ProcFormatString.Format[120] );
            
            NdrConformantStringUnmarshall( (PMIDL_STUB_MESSAGE) &_StubMsg,
                                           (unsigned char __RPC_FAR * __RPC_FAR *)&pszDomain,
                                           (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[102],
                                           (unsigned char)0 );
            
            _StubMsg.Buffer = (unsigned char __RPC_FAR *)(((long)_StubMsg.Buffer + 3) & ~ 0x3);
            *pdwRecipientIndex = *(( DWORD __RPC_FAR * )_StubMsg.Buffer)++;
            
            *pdwRecipientCount = *(( DWORD __RPC_FAR * )_StubMsg.Buffer)++;
            
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
        _StubMsg.MaxCount = ( unsigned long  )cchLength;
        
        NdrClearOutParameters(
                         ( PMIDL_STUB_MESSAGE  )&_StubMsg,
                         ( PFORMAT_STRING  )&__MIDL_TypeFormatString.Format[98],
                         ( void __RPC_FAR * )pszDomain);
        NdrClearOutParameters(
                         ( PMIDL_STUB_MESSAGE  )&_StubMsg,
                         ( PFORMAT_STRING  )&__MIDL_TypeFormatString.Format[2],
                         ( void __RPC_FAR * )pdwRecipientIndex);
        NdrClearOutParameters(
                         ( PMIDL_STUB_MESSAGE  )&_StubMsg,
                         ( PFORMAT_STRING  )&__MIDL_TypeFormatString.Format[2],
                         ( void __RPC_FAR * )pdwRecipientCount);
        _RetVal = NdrProxyErrorHandler(RpcExceptionCode());
        }
    RpcEndExcept
    return _RetVal;
}

void __RPC_STUB IMailMsgRecipients_DomainItem_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase)
{
    DWORD _M23;
    DWORD _M24;
    HRESULT _RetVal;
    MIDL_STUB_MESSAGE _StubMsg;
    DWORD cchLength;
    DWORD dwIndex;
    DWORD __RPC_FAR *pdwRecipientCount;
    DWORD __RPC_FAR *pdwRecipientIndex;
    LPSTR pszDomain;
    
NdrStubInitialize(
                     _pRpcMessage,
                     &_StubMsg,
                     &Object_StubDesc,
                     _pRpcChannelBuffer);
    ( LPSTR  )pszDomain = 0;
    ( DWORD __RPC_FAR * )pdwRecipientIndex = 0;
    ( DWORD __RPC_FAR * )pdwRecipientCount = 0;
    RpcTryFinally
        {
        if ( (_pRpcMessage->DataRepresentation & 0X0000FFFFUL) != NDR_LOCAL_DATA_REPRESENTATION )
            NdrConvert( (PMIDL_STUB_MESSAGE) &_StubMsg, (PFORMAT_STRING) &__MIDL_ProcFormatString.Format[120] );
        
        dwIndex = *(( DWORD __RPC_FAR * )_StubMsg.Buffer)++;
        
        cchLength = *(( DWORD __RPC_FAR * )_StubMsg.Buffer)++;
        
        pszDomain = NdrAllocate(&_StubMsg,cchLength * 1);
        pdwRecipientIndex = &_M23;
        pdwRecipientCount = &_M24;
        
        *_pdwStubPhase = STUB_CALL_SERVER;
        _RetVal = (((IMailMsgRecipients*) ((CStdStubBuffer *)This)->pvServerObject)->lpVtbl) -> DomainItem(
              (IMailMsgRecipients *) ((CStdStubBuffer *)This)->pvServerObject,
              dwIndex,
              cchLength,
              pszDomain,
              pdwRecipientIndex,
              pdwRecipientCount);
        
        *_pdwStubPhase = STUB_MARSHAL;
        
        _StubMsg.BufferLength = 12U + 11U + 7U + 7U;
        _StubMsg.MaxCount = ( unsigned long  )cchLength;
        
        NdrConformantStringBufferSize( (PMIDL_STUB_MESSAGE) &_StubMsg,
                                       (unsigned char __RPC_FAR *)pszDomain,
                                       (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[102] );
        
        _StubMsg.BufferLength += 16;
        
        NdrStubGetBuffer(This, _pRpcChannelBuffer, &_StubMsg);
        _StubMsg.MaxCount = ( unsigned long  )cchLength;
        
        NdrConformantStringMarshall( (PMIDL_STUB_MESSAGE)& _StubMsg,
                                     (unsigned char __RPC_FAR *)pszDomain,
                                     (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[102] );
        
        _StubMsg.Buffer = (unsigned char __RPC_FAR *)(((long)_StubMsg.Buffer + 3) & ~ 0x3);
        *(( DWORD __RPC_FAR * )_StubMsg.Buffer)++ = *pdwRecipientIndex;
        
        *(( DWORD __RPC_FAR * )_StubMsg.Buffer)++ = *pdwRecipientCount;
        
        *(( HRESULT __RPC_FAR * )_StubMsg.Buffer)++ = _RetVal;
        
        }
    RpcFinally
        {
        _StubMsg.MaxCount = ( unsigned long  )cchLength;
        
        NdrPointerFree( &_StubMsg,
                        (unsigned char __RPC_FAR *)pszDomain,
                        &__MIDL_TypeFormatString.Format[98] );
        
        }
    RpcEndFinally
    _pRpcMessage->BufferLength = 
        (unsigned int)(_StubMsg.Buffer - (unsigned char __RPC_FAR *)_pRpcMessage->Buffer);
    
}


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IMailMsgRecipients_AllocNewList_Proxy( 
    IMailMsgRecipients __RPC_FAR * This,
    /* [out] */ IMailMsgRecipientsAdd __RPC_FAR *__RPC_FAR *ppNewList)
{

    HRESULT _RetVal;
    
    RPC_MESSAGE _RpcMessage;
    
    MIDL_STUB_MESSAGE _StubMsg;
    
    if(ppNewList)
        {
        MIDL_memset(
               ppNewList,
               0,
               sizeof( IMailMsgRecipientsAdd __RPC_FAR *__RPC_FAR * ));
        }
    RpcTryExcept
        {
        NdrProxyInitialize(
                      ( void __RPC_FAR *  )This,
                      ( PRPC_MESSAGE  )&_RpcMessage,
                      ( PMIDL_STUB_MESSAGE  )&_StubMsg,
                      ( PMIDL_STUB_DESC  )&Object_StubDesc,
                      18);
        
        
        
        if(!ppNewList)
            {
            RpcRaiseException(RPC_X_NULL_REF_POINTER);
            }
        RpcTryFinally
            {
            
            _StubMsg.BufferLength = 0U;
            NdrProxyGetBuffer(This, &_StubMsg);
            NdrProxySendReceive(This, &_StubMsg);
            
            if ( (_RpcMessage.DataRepresentation & 0X0000FFFFUL) != NDR_LOCAL_DATA_REPRESENTATION )
                NdrConvert( (PMIDL_STUB_MESSAGE) &_StubMsg, (PFORMAT_STRING) &__MIDL_ProcFormatString.Format[138] );
            
            NdrPointerUnmarshall( (PMIDL_STUB_MESSAGE) &_StubMsg,
                                  (unsigned char __RPC_FAR * __RPC_FAR *)&ppNewList,
                                  (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[108],
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
                         ( PFORMAT_STRING  )&__MIDL_TypeFormatString.Format[108],
                         ( void __RPC_FAR * )ppNewList);
        _RetVal = NdrProxyErrorHandler(RpcExceptionCode());
        }
    RpcEndExcept
    return _RetVal;
}

void __RPC_STUB IMailMsgRecipients_AllocNewList_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase)
{
    IMailMsgRecipientsAdd __RPC_FAR *_M25;
    HRESULT _RetVal;
    MIDL_STUB_MESSAGE _StubMsg;
    IMailMsgRecipientsAdd __RPC_FAR *__RPC_FAR *ppNewList;
    
NdrStubInitialize(
                     _pRpcMessage,
                     &_StubMsg,
                     &Object_StubDesc,
                     _pRpcChannelBuffer);
    ( IMailMsgRecipientsAdd __RPC_FAR *__RPC_FAR * )ppNewList = 0;
    RpcTryFinally
        {
        ppNewList = &_M25;
        _M25 = 0;
        
        *_pdwStubPhase = STUB_CALL_SERVER;
        _RetVal = (((IMailMsgRecipients*) ((CStdStubBuffer *)This)->pvServerObject)->lpVtbl) -> AllocNewList((IMailMsgRecipients *) ((CStdStubBuffer *)This)->pvServerObject,ppNewList);
        
        *_pdwStubPhase = STUB_MARSHAL;
        
        _StubMsg.BufferLength = 0U + 4U;
        NdrPointerBufferSize( (PMIDL_STUB_MESSAGE) &_StubMsg,
                              (unsigned char __RPC_FAR *)ppNewList,
                              (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[108] );
        
        _StubMsg.BufferLength += 16;
        
        NdrStubGetBuffer(This, _pRpcChannelBuffer, &_StubMsg);
        NdrPointerMarshall( (PMIDL_STUB_MESSAGE)& _StubMsg,
                            (unsigned char __RPC_FAR *)ppNewList,
                            (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[108] );
        
        _StubMsg.Buffer = (unsigned char __RPC_FAR *)(((long)_StubMsg.Buffer + 3) & ~ 0x3);
        *(( HRESULT __RPC_FAR * )_StubMsg.Buffer)++ = _RetVal;
        
        }
    RpcFinally
        {
        NdrPointerFree( &_StubMsg,
                        (unsigned char __RPC_FAR *)ppNewList,
                        &__MIDL_TypeFormatString.Format[108] );
        
        }
    RpcEndFinally
    _pRpcMessage->BufferLength = 
        (unsigned int)(_StubMsg.Buffer - (unsigned char __RPC_FAR *)_pRpcMessage->Buffer);
    
}


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IMailMsgRecipients_WriteList_Proxy( 
    IMailMsgRecipients __RPC_FAR * This,
    /* [unique][in] */ IMailMsgRecipientsAdd __RPC_FAR *pNewList)
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
                      19);
        
        
        
        RpcTryFinally
            {
            
            _StubMsg.BufferLength = 0U;
            NdrInterfacePointerBufferSize( (PMIDL_STUB_MESSAGE) &_StubMsg,
                                           (unsigned char __RPC_FAR *)pNewList,
                                           (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[112] );
            
            NdrProxyGetBuffer(This, &_StubMsg);
            NdrInterfacePointerMarshall( (PMIDL_STUB_MESSAGE)& _StubMsg,
                                         (unsigned char __RPC_FAR *)pNewList,
                                         (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[112] );
            
            NdrProxySendReceive(This, &_StubMsg);
            
            if ( (_RpcMessage.DataRepresentation & 0X0000FFFFUL) != NDR_LOCAL_DATA_REPRESENTATION )
                NdrConvert( (PMIDL_STUB_MESSAGE) &_StubMsg, (PFORMAT_STRING) &__MIDL_ProcFormatString.Format[144] );
            
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

void __RPC_STUB IMailMsgRecipients_WriteList_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase)
{
    HRESULT _RetVal;
    MIDL_STUB_MESSAGE _StubMsg;
    IMailMsgRecipientsAdd __RPC_FAR *pNewList;
    
NdrStubInitialize(
                     _pRpcMessage,
                     &_StubMsg,
                     &Object_StubDesc,
                     _pRpcChannelBuffer);
    pNewList = 0;
    RpcTryFinally
        {
        if ( (_pRpcMessage->DataRepresentation & 0X0000FFFFUL) != NDR_LOCAL_DATA_REPRESENTATION )
            NdrConvert( (PMIDL_STUB_MESSAGE) &_StubMsg, (PFORMAT_STRING) &__MIDL_ProcFormatString.Format[144] );
        
        NdrInterfacePointerUnmarshall( (PMIDL_STUB_MESSAGE) &_StubMsg,
                                       (unsigned char __RPC_FAR * __RPC_FAR *)&pNewList,
                                       (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[112],
                                       (unsigned char)0 );
        
        
        *_pdwStubPhase = STUB_CALL_SERVER;
        _RetVal = (((IMailMsgRecipients*) ((CStdStubBuffer *)This)->pvServerObject)->lpVtbl) -> WriteList((IMailMsgRecipients *) ((CStdStubBuffer *)This)->pvServerObject,pNewList);
        
        *_pdwStubPhase = STUB_MARSHAL;
        
        _StubMsg.BufferLength = 4U;
        NdrStubGetBuffer(This, _pRpcChannelBuffer, &_StubMsg);
        *(( HRESULT __RPC_FAR * )_StubMsg.Buffer)++ = _RetVal;
        
        }
    RpcFinally
        {
        NdrInterfacePointerFree( &_StubMsg,
                                 (unsigned char __RPC_FAR *)pNewList,
                                 &__MIDL_TypeFormatString.Format[112] );
        
        }
    RpcEndFinally
    _pRpcMessage->BufferLength = 
        (unsigned int)(_StubMsg.Buffer - (unsigned char __RPC_FAR *)_pRpcMessage->Buffer);
    
}


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IMailMsgRecipients_SetNextDomain_Proxy( 
    IMailMsgRecipients __RPC_FAR * This,
    /* [in] */ DWORD dwDomainIndex,
    /* [in] */ DWORD dwNextDomainIndex,
    /* [in] */ DWORD dwFlags)
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
                      20);
        
        
        
        RpcTryFinally
            {
            
            _StubMsg.BufferLength = 4U + 4U + 4U;
            NdrProxyGetBuffer(This, &_StubMsg);
            *(( DWORD __RPC_FAR * )_StubMsg.Buffer)++ = dwDomainIndex;
            
            *(( DWORD __RPC_FAR * )_StubMsg.Buffer)++ = dwNextDomainIndex;
            
            *(( DWORD __RPC_FAR * )_StubMsg.Buffer)++ = dwFlags;
            
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

void __RPC_STUB IMailMsgRecipients_SetNextDomain_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase)
{
    HRESULT _RetVal;
    MIDL_STUB_MESSAGE _StubMsg;
    DWORD dwDomainIndex;
    DWORD dwFlags;
    DWORD dwNextDomainIndex;
    
NdrStubInitialize(
                     _pRpcMessage,
                     &_StubMsg,
                     &Object_StubDesc,
                     _pRpcChannelBuffer);
    RpcTryFinally
        {
        if ( (_pRpcMessage->DataRepresentation & 0X0000FFFFUL) != NDR_LOCAL_DATA_REPRESENTATION )
            NdrConvert( (PMIDL_STUB_MESSAGE) &_StubMsg, (PFORMAT_STRING) &__MIDL_ProcFormatString.Format[94] );
        
        dwDomainIndex = *(( DWORD __RPC_FAR * )_StubMsg.Buffer)++;
        
        dwNextDomainIndex = *(( DWORD __RPC_FAR * )_StubMsg.Buffer)++;
        
        dwFlags = *(( DWORD __RPC_FAR * )_StubMsg.Buffer)++;
        
        
        *_pdwStubPhase = STUB_CALL_SERVER;
        _RetVal = (((IMailMsgRecipients*) ((CStdStubBuffer *)This)->pvServerObject)->lpVtbl) -> SetNextDomain(
                 (IMailMsgRecipients *) ((CStdStubBuffer *)This)->pvServerObject,
                 dwDomainIndex,
                 dwNextDomainIndex,
                 dwFlags);
        
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


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IMailMsgRecipients_InitializeRecipientFilterContext_Proxy( 
    IMailMsgRecipients __RPC_FAR * This,
    /* [unique][in] */ LPRECIPIENT_FILTER_CONTEXT pContext,
    /* [in] */ DWORD dwStartingDomain,
    /* [in] */ DWORD dwFilterFlags,
    /* [in] */ DWORD dwFilterMask)
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
                      21);
        
        
        
        RpcTryFinally
            {
            
            _StubMsg.BufferLength = 8U + 11U + 7U + 7U;
            NdrPointerBufferSize( (PMIDL_STUB_MESSAGE) &_StubMsg,
                                  (unsigned char __RPC_FAR *)pContext,
                                  (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[130] );
            
            NdrProxyGetBuffer(This, &_StubMsg);
            NdrPointerMarshall( (PMIDL_STUB_MESSAGE)& _StubMsg,
                                (unsigned char __RPC_FAR *)pContext,
                                (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[130] );
            
            _StubMsg.Buffer = (unsigned char __RPC_FAR *)(((long)_StubMsg.Buffer + 3) & ~ 0x3);
            *(( DWORD __RPC_FAR * )_StubMsg.Buffer)++ = dwStartingDomain;
            
            *(( DWORD __RPC_FAR * )_StubMsg.Buffer)++ = dwFilterFlags;
            
            *(( DWORD __RPC_FAR * )_StubMsg.Buffer)++ = dwFilterMask;
            
            NdrProxySendReceive(This, &_StubMsg);
            
            if ( (_RpcMessage.DataRepresentation & 0X0000FFFFUL) != NDR_LOCAL_DATA_REPRESENTATION )
                NdrConvert( (PMIDL_STUB_MESSAGE) &_StubMsg, (PFORMAT_STRING) &__MIDL_ProcFormatString.Format[150] );
            
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

void __RPC_STUB IMailMsgRecipients_InitializeRecipientFilterContext_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase)
{
    HRESULT _RetVal;
    MIDL_STUB_MESSAGE _StubMsg;
    DWORD dwFilterFlags;
    DWORD dwFilterMask;
    DWORD dwStartingDomain;
    LPRECIPIENT_FILTER_CONTEXT pContext;
    
NdrStubInitialize(
                     _pRpcMessage,
                     &_StubMsg,
                     &Object_StubDesc,
                     _pRpcChannelBuffer);
    ( LPRECIPIENT_FILTER_CONTEXT  )pContext = 0;
    RpcTryFinally
        {
        if ( (_pRpcMessage->DataRepresentation & 0X0000FFFFUL) != NDR_LOCAL_DATA_REPRESENTATION )
            NdrConvert( (PMIDL_STUB_MESSAGE) &_StubMsg, (PFORMAT_STRING) &__MIDL_ProcFormatString.Format[150] );
        
        NdrPointerUnmarshall( (PMIDL_STUB_MESSAGE) &_StubMsg,
                              (unsigned char __RPC_FAR * __RPC_FAR *)&pContext,
                              (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[130],
                              (unsigned char)0 );
        
        _StubMsg.Buffer = (unsigned char __RPC_FAR *)(((long)_StubMsg.Buffer + 3) & ~ 0x3);
        dwStartingDomain = *(( DWORD __RPC_FAR * )_StubMsg.Buffer)++;
        
        dwFilterFlags = *(( DWORD __RPC_FAR * )_StubMsg.Buffer)++;
        
        dwFilterMask = *(( DWORD __RPC_FAR * )_StubMsg.Buffer)++;
        
        
        *_pdwStubPhase = STUB_CALL_SERVER;
        _RetVal = (((IMailMsgRecipients*) ((CStdStubBuffer *)This)->pvServerObject)->lpVtbl) -> InitializeRecipientFilterContext(
                                    (IMailMsgRecipients *) ((CStdStubBuffer *)This)->pvServerObject,
                                    pContext,
                                    dwStartingDomain,
                                    dwFilterFlags,
                                    dwFilterMask);
        
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


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IMailMsgRecipients_TerminateRecipientFilterContext_Proxy( 
    IMailMsgRecipients __RPC_FAR * This,
    /* [unique][in] */ LPRECIPIENT_FILTER_CONTEXT pContext)
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
                      22);
        
        
        
        RpcTryFinally
            {
            
            _StubMsg.BufferLength = 8U;
            NdrPointerBufferSize( (PMIDL_STUB_MESSAGE) &_StubMsg,
                                  (unsigned char __RPC_FAR *)pContext,
                                  (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[130] );
            
            NdrProxyGetBuffer(This, &_StubMsg);
            NdrPointerMarshall( (PMIDL_STUB_MESSAGE)& _StubMsg,
                                (unsigned char __RPC_FAR *)pContext,
                                (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[130] );
            
            NdrProxySendReceive(This, &_StubMsg);
            
            if ( (_RpcMessage.DataRepresentation & 0X0000FFFFUL) != NDR_LOCAL_DATA_REPRESENTATION )
                NdrConvert( (PMIDL_STUB_MESSAGE) &_StubMsg, (PFORMAT_STRING) &__MIDL_ProcFormatString.Format[162] );
            
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

void __RPC_STUB IMailMsgRecipients_TerminateRecipientFilterContext_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase)
{
    HRESULT _RetVal;
    MIDL_STUB_MESSAGE _StubMsg;
    LPRECIPIENT_FILTER_CONTEXT pContext;
    
NdrStubInitialize(
                     _pRpcMessage,
                     &_StubMsg,
                     &Object_StubDesc,
                     _pRpcChannelBuffer);
    ( LPRECIPIENT_FILTER_CONTEXT  )pContext = 0;
    RpcTryFinally
        {
        if ( (_pRpcMessage->DataRepresentation & 0X0000FFFFUL) != NDR_LOCAL_DATA_REPRESENTATION )
            NdrConvert( (PMIDL_STUB_MESSAGE) &_StubMsg, (PFORMAT_STRING) &__MIDL_ProcFormatString.Format[162] );
        
        NdrPointerUnmarshall( (PMIDL_STUB_MESSAGE) &_StubMsg,
                              (unsigned char __RPC_FAR * __RPC_FAR *)&pContext,
                              (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[130],
                              (unsigned char)0 );
        
        
        *_pdwStubPhase = STUB_CALL_SERVER;
        _RetVal = (((IMailMsgRecipients*) ((CStdStubBuffer *)This)->pvServerObject)->lpVtbl) -> TerminateRecipientFilterContext((IMailMsgRecipients *) ((CStdStubBuffer *)This)->pvServerObject,pContext);
        
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


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IMailMsgRecipients_GetNextRecipient_Proxy( 
    IMailMsgRecipients __RPC_FAR * This,
    /* [unique][in] */ LPRECIPIENT_FILTER_CONTEXT pContext,
    /* [out] */ DWORD __RPC_FAR *pdwRecipientIndex)
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
                      23);
        
        
        
        if(!pdwRecipientIndex)
            {
            RpcRaiseException(RPC_X_NULL_REF_POINTER);
            }
        RpcTryFinally
            {
            
            _StubMsg.BufferLength = 8U;
            NdrPointerBufferSize( (PMIDL_STUB_MESSAGE) &_StubMsg,
                                  (unsigned char __RPC_FAR *)pContext,
                                  (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[130] );
            
            NdrProxyGetBuffer(This, &_StubMsg);
            NdrPointerMarshall( (PMIDL_STUB_MESSAGE)& _StubMsg,
                                (unsigned char __RPC_FAR *)pContext,
                                (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[130] );
            
            NdrProxySendReceive(This, &_StubMsg);
            
            if ( (_RpcMessage.DataRepresentation & 0X0000FFFFUL) != NDR_LOCAL_DATA_REPRESENTATION )
                NdrConvert( (PMIDL_STUB_MESSAGE) &_StubMsg, (PFORMAT_STRING) &__MIDL_ProcFormatString.Format[168] );
            
            *pdwRecipientIndex = *(( DWORD __RPC_FAR * )_StubMsg.Buffer)++;
            
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
                         ( PFORMAT_STRING  )&__MIDL_TypeFormatString.Format[2],
                         ( void __RPC_FAR * )pdwRecipientIndex);
        _RetVal = NdrProxyErrorHandler(RpcExceptionCode());
        }
    RpcEndExcept
    return _RetVal;
}

void __RPC_STUB IMailMsgRecipients_GetNextRecipient_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase)
{
    DWORD _M26;
    HRESULT _RetVal;
    MIDL_STUB_MESSAGE _StubMsg;
    LPRECIPIENT_FILTER_CONTEXT pContext;
    DWORD __RPC_FAR *pdwRecipientIndex;
    
NdrStubInitialize(
                     _pRpcMessage,
                     &_StubMsg,
                     &Object_StubDesc,
                     _pRpcChannelBuffer);
    ( LPRECIPIENT_FILTER_CONTEXT  )pContext = 0;
    ( DWORD __RPC_FAR * )pdwRecipientIndex = 0;
    RpcTryFinally
        {
        if ( (_pRpcMessage->DataRepresentation & 0X0000FFFFUL) != NDR_LOCAL_DATA_REPRESENTATION )
            NdrConvert( (PMIDL_STUB_MESSAGE) &_StubMsg, (PFORMAT_STRING) &__MIDL_ProcFormatString.Format[168] );
        
        NdrPointerUnmarshall( (PMIDL_STUB_MESSAGE) &_StubMsg,
                              (unsigned char __RPC_FAR * __RPC_FAR *)&pContext,
                              (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[130],
                              (unsigned char)0 );
        
        pdwRecipientIndex = &_M26;
        
        *_pdwStubPhase = STUB_CALL_SERVER;
        _RetVal = (((IMailMsgRecipients*) ((CStdStubBuffer *)This)->pvServerObject)->lpVtbl) -> GetNextRecipient(
                    (IMailMsgRecipients *) ((CStdStubBuffer *)This)->pvServerObject,
                    pContext,
                    pdwRecipientIndex);
        
        *_pdwStubPhase = STUB_MARSHAL;
        
        _StubMsg.BufferLength = 4U + 4U;
        NdrStubGetBuffer(This, _pRpcChannelBuffer, &_StubMsg);
        *(( DWORD __RPC_FAR * )_StubMsg.Buffer)++ = *pdwRecipientIndex;
        
        *(( HRESULT __RPC_FAR * )_StubMsg.Buffer)++ = _RetVal;
        
        }
    RpcFinally
        {
        }
    RpcEndFinally
    _pRpcMessage->BufferLength = 
        (unsigned int)(_StubMsg.Buffer - (unsigned char __RPC_FAR *)_pRpcMessage->Buffer);
    
}

const CINTERFACE_PROXY_VTABLE(24) _IMailMsgRecipientsProxyVtbl = 
{
    &IID_IMailMsgRecipients,
    IUnknown_QueryInterface_Proxy,
    IUnknown_AddRef_Proxy,
    IUnknown_Release_Proxy ,
    IMailMsgRecipientsBase_Count_Proxy ,
    IMailMsgRecipientsBase_Item_Proxy ,
    IMailMsgRecipientsBase_PutProperty_Proxy ,
    IMailMsgRecipientsBase_GetProperty_Proxy ,
    IMailMsgRecipientsBase_PutStringA_Proxy ,
    IMailMsgRecipientsBase_GetStringA_Proxy ,
    IMailMsgRecipientsBase_PutStringW_Proxy ,
    IMailMsgRecipientsBase_GetStringW_Proxy ,
    IMailMsgRecipientsBase_PutDWORD_Proxy ,
    IMailMsgRecipientsBase_GetDWORD_Proxy ,
    IMailMsgRecipientsBase_PutBool_Proxy ,
    IMailMsgRecipientsBase_GetBool_Proxy ,
    IMailMsgRecipients_Commit_Proxy ,
    IMailMsgRecipients_DomainCount_Proxy ,
    IMailMsgRecipients_DomainItem_Proxy ,
    IMailMsgRecipients_AllocNewList_Proxy ,
    IMailMsgRecipients_WriteList_Proxy ,
    IMailMsgRecipients_SetNextDomain_Proxy ,
    IMailMsgRecipients_InitializeRecipientFilterContext_Proxy ,
    IMailMsgRecipients_TerminateRecipientFilterContext_Proxy ,
    IMailMsgRecipients_GetNextRecipient_Proxy
};


static const PRPC_STUB_FUNCTION IMailMsgRecipients_table[] =
{
    IMailMsgRecipientsBase_Count_Stub,
    IMailMsgRecipientsBase_Item_Stub,
    IMailMsgRecipientsBase_PutProperty_Stub,
    IMailMsgRecipientsBase_GetProperty_Stub,
    IMailMsgRecipientsBase_PutStringA_Stub,
    IMailMsgRecipientsBase_GetStringA_Stub,
    IMailMsgRecipientsBase_PutStringW_Stub,
    IMailMsgRecipientsBase_GetStringW_Stub,
    IMailMsgRecipientsBase_PutDWORD_Stub,
    IMailMsgRecipientsBase_GetDWORD_Stub,
    IMailMsgRecipientsBase_PutBool_Stub,
    IMailMsgRecipientsBase_GetBool_Stub,
    IMailMsgRecipients_Commit_Stub,
    IMailMsgRecipients_DomainCount_Stub,
    IMailMsgRecipients_DomainItem_Stub,
    IMailMsgRecipients_AllocNewList_Stub,
    IMailMsgRecipients_WriteList_Stub,
    IMailMsgRecipients_SetNextDomain_Stub,
    IMailMsgRecipients_InitializeRecipientFilterContext_Stub,
    IMailMsgRecipients_TerminateRecipientFilterContext_Stub,
    IMailMsgRecipients_GetNextRecipient_Stub
};

const CInterfaceStubVtbl _IMailMsgRecipientsStubVtbl =
{
    &IID_IMailMsgRecipients,
    0,
    24,
    &IMailMsgRecipients_table[-3],
    CStdStubBuffer_METHODS
};


/* Object interface: IMailMsgProperties, ver. 0.0,
   GUID={0xab95fb40,0xa34f,0x11d1,{0xaa,0x8a,0x00,0xaa,0x00,0x6b,0xc8,0x0b}} */


/* Object interface: IMailMsgValidate, ver. 0.0,
   GUID={0x6717b03c,0x072c,0x11d3,{0x94,0xff,0x00,0xc0,0x4f,0xa3,0x79,0xf1}} */


/* Object interface: IMailMsgPropertyManagement, ver. 0.0,
   GUID={0xa2f196c0,0xa351,0x11d1,{0xaa,0x8a,0x00,0xaa,0x00,0x6b,0xc8,0x0b}} */


extern const MIDL_STUB_DESC Object_StubDesc;


#pragma code_seg(".orpc")

/* [helpstring] */ HRESULT STDMETHODCALLTYPE IMailMsgPropertyManagement_AllocPropIDRange_Proxy( 
    IMailMsgPropertyManagement __RPC_FAR * This,
    /* [in] */ REFGUID rguid,
    /* [in] */ DWORD cCount,
    /* [out] */ DWORD __RPC_FAR *pdwStart)
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
        
        
        
        if(!rguid)
            {
            RpcRaiseException(RPC_X_NULL_REF_POINTER);
            }
        if(!pdwStart)
            {
            RpcRaiseException(RPC_X_NULL_REF_POINTER);
            }
        RpcTryFinally
            {
            
            _StubMsg.BufferLength = 0U + 11U;
            NdrSimpleStructBufferSize( (PMIDL_STUB_MESSAGE) &_StubMsg,
                                       (unsigned char __RPC_FAR *)rguid,
                                       (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[156] );
            
            NdrProxyGetBuffer(This, &_StubMsg);
            NdrSimpleStructMarshall( (PMIDL_STUB_MESSAGE)& _StubMsg,
                                     (unsigned char __RPC_FAR *)rguid,
                                     (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[156] );
            
            *(( DWORD __RPC_FAR * )_StubMsg.Buffer)++ = cCount;
            
            NdrProxySendReceive(This, &_StubMsg);
            
            if ( (_RpcMessage.DataRepresentation & 0X0000FFFFUL) != NDR_LOCAL_DATA_REPRESENTATION )
                NdrConvert( (PMIDL_STUB_MESSAGE) &_StubMsg, (PFORMAT_STRING) &__MIDL_ProcFormatString.Format[178] );
            
            *pdwStart = *(( DWORD __RPC_FAR * )_StubMsg.Buffer)++;
            
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
                         ( PFORMAT_STRING  )&__MIDL_TypeFormatString.Format[2],
                         ( void __RPC_FAR * )pdwStart);
        _RetVal = NdrProxyErrorHandler(RpcExceptionCode());
        }
    RpcEndExcept
    return _RetVal;
}

void __RPC_STUB IMailMsgPropertyManagement_AllocPropIDRange_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase)
{
    DWORD _M27;
    HRESULT _RetVal;
    MIDL_STUB_MESSAGE _StubMsg;
    DWORD cCount;
    DWORD __RPC_FAR *pdwStart;
    REFGUID rguid;
    
NdrStubInitialize(
                     _pRpcMessage,
                     &_StubMsg,
                     &Object_StubDesc,
                     _pRpcChannelBuffer);
    ( REFGUID  )rguid = 0;
    ( DWORD __RPC_FAR * )pdwStart = 0;
    RpcTryFinally
        {
        if ( (_pRpcMessage->DataRepresentation & 0X0000FFFFUL) != NDR_LOCAL_DATA_REPRESENTATION )
            NdrConvert( (PMIDL_STUB_MESSAGE) &_StubMsg, (PFORMAT_STRING) &__MIDL_ProcFormatString.Format[178] );
        
        NdrSimpleStructUnmarshall( (PMIDL_STUB_MESSAGE) &_StubMsg,
                                   (unsigned char __RPC_FAR * __RPC_FAR *)&rguid,
                                   (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[156],
                                   (unsigned char)0 );
        
        cCount = *(( DWORD __RPC_FAR * )_StubMsg.Buffer)++;
        
        pdwStart = &_M27;
        
        *_pdwStubPhase = STUB_CALL_SERVER;
        _RetVal = (((IMailMsgPropertyManagement*) ((CStdStubBuffer *)This)->pvServerObject)->lpVtbl) -> AllocPropIDRange(
                    (IMailMsgPropertyManagement *) ((CStdStubBuffer *)This)->pvServerObject,
                    rguid,
                    cCount,
                    pdwStart);
        
        *_pdwStubPhase = STUB_MARSHAL;
        
        _StubMsg.BufferLength = 4U + 4U;
        NdrStubGetBuffer(This, _pRpcChannelBuffer, &_StubMsg);
        *(( DWORD __RPC_FAR * )_StubMsg.Buffer)++ = *pdwStart;
        
        *(( HRESULT __RPC_FAR * )_StubMsg.Buffer)++ = _RetVal;
        
        }
    RpcFinally
        {
        }
    RpcEndFinally
    _pRpcMessage->BufferLength = 
        (unsigned int)(_StubMsg.Buffer - (unsigned char __RPC_FAR *)_pRpcMessage->Buffer);
    
}

const CINTERFACE_PROXY_VTABLE(4) _IMailMsgPropertyManagementProxyVtbl = 
{
    &IID_IMailMsgPropertyManagement,
    IUnknown_QueryInterface_Proxy,
    IUnknown_AddRef_Proxy,
    IUnknown_Release_Proxy ,
    IMailMsgPropertyManagement_AllocPropIDRange_Proxy
};


static const PRPC_STUB_FUNCTION IMailMsgPropertyManagement_table[] =
{
    IMailMsgPropertyManagement_AllocPropIDRange_Stub
};

const CInterfaceStubVtbl _IMailMsgPropertyManagementStubVtbl =
{
    &IID_IMailMsgPropertyManagement,
    0,
    4,
    &IMailMsgPropertyManagement_table[-3],
    CStdStubBuffer_METHODS
};


/* Object interface: IMailMsgEnumMessages, ver. 0.0,
   GUID={0xe760a840,0xc8f1,0x11d1,{0x9f,0xf2,0x00,0xc0,0x4f,0xa3,0x73,0x48}} */


/* Object interface: IMailMsgStoreDriver, ver. 0.0,
   GUID={0x246aae60,0xacc4,0x11d1,{0xaa,0x91,0x00,0xaa,0x00,0x6b,0xc8,0x0b}} */


/* Object interface: IMailMsgQueueMgmt, ver. 0.0,
   GUID={0xb2564d0a,0xd5a1,0x11d1,{0x9f,0xf7,0x00,0xc0,0x4f,0xa3,0x73,0x48}} */


extern const MIDL_STUB_DESC Object_StubDesc;


#pragma code_seg(".orpc")

/* [helpstring] */ HRESULT STDMETHODCALLTYPE IMailMsgQueueMgmt_AddUsage_Proxy( 
    IMailMsgQueueMgmt __RPC_FAR * This)
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
            NdrProxyGetBuffer(This, &_StubMsg);
            NdrProxySendReceive(This, &_StubMsg);
            
            if ( (_RpcMessage.DataRepresentation & 0X0000FFFFUL) != NDR_LOCAL_DATA_REPRESENTATION )
                NdrConvert( (PMIDL_STUB_MESSAGE) &_StubMsg, (PFORMAT_STRING) &__MIDL_ProcFormatString.Format[190] );
            
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

void __RPC_STUB IMailMsgQueueMgmt_AddUsage_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase)
{
    HRESULT _RetVal;
    MIDL_STUB_MESSAGE _StubMsg;
    
NdrStubInitialize(
                     _pRpcMessage,
                     &_StubMsg,
                     &Object_StubDesc,
                     _pRpcChannelBuffer);
    RpcTryFinally
        {
        
        *_pdwStubPhase = STUB_CALL_SERVER;
        _RetVal = (((IMailMsgQueueMgmt*) ((CStdStubBuffer *)This)->pvServerObject)->lpVtbl) -> AddUsage((IMailMsgQueueMgmt *) ((CStdStubBuffer *)This)->pvServerObject);
        
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


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IMailMsgQueueMgmt_ReleaseUsage_Proxy( 
    IMailMsgQueueMgmt __RPC_FAR * This)
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
        
        
        
        RpcTryFinally
            {
            
            _StubMsg.BufferLength = 0U;
            NdrProxyGetBuffer(This, &_StubMsg);
            NdrProxySendReceive(This, &_StubMsg);
            
            if ( (_RpcMessage.DataRepresentation & 0X0000FFFFUL) != NDR_LOCAL_DATA_REPRESENTATION )
                NdrConvert( (PMIDL_STUB_MESSAGE) &_StubMsg, (PFORMAT_STRING) &__MIDL_ProcFormatString.Format[190] );
            
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

void __RPC_STUB IMailMsgQueueMgmt_ReleaseUsage_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase)
{
    HRESULT _RetVal;
    MIDL_STUB_MESSAGE _StubMsg;
    
NdrStubInitialize(
                     _pRpcMessage,
                     &_StubMsg,
                     &Object_StubDesc,
                     _pRpcChannelBuffer);
    RpcTryFinally
        {
        
        *_pdwStubPhase = STUB_CALL_SERVER;
        _RetVal = (((IMailMsgQueueMgmt*) ((CStdStubBuffer *)This)->pvServerObject)->lpVtbl) -> ReleaseUsage((IMailMsgQueueMgmt *) ((CStdStubBuffer *)This)->pvServerObject);
        
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


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IMailMsgQueueMgmt_SetRecipientCount_Proxy( 
    IMailMsgQueueMgmt __RPC_FAR * This,
    /* [in] */ DWORD dwCount)
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
            
            _StubMsg.BufferLength = 4U;
            NdrProxyGetBuffer(This, &_StubMsg);
            *(( DWORD __RPC_FAR * )_StubMsg.Buffer)++ = dwCount;
            
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

void __RPC_STUB IMailMsgQueueMgmt_SetRecipientCount_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase)
{
    HRESULT _RetVal;
    MIDL_STUB_MESSAGE _StubMsg;
    DWORD dwCount;
    
NdrStubInitialize(
                     _pRpcMessage,
                     &_StubMsg,
                     &Object_StubDesc,
                     _pRpcChannelBuffer);
    RpcTryFinally
        {
        if ( (_pRpcMessage->DataRepresentation & 0X0000FFFFUL) != NDR_LOCAL_DATA_REPRESENTATION )
            NdrConvert( (PMIDL_STUB_MESSAGE) &_StubMsg, (PFORMAT_STRING) &__MIDL_ProcFormatString.Format[0] );
        
        dwCount = *(( DWORD __RPC_FAR * )_StubMsg.Buffer)++;
        
        
        *_pdwStubPhase = STUB_CALL_SERVER;
        _RetVal = (((IMailMsgQueueMgmt*) ((CStdStubBuffer *)This)->pvServerObject)->lpVtbl) -> SetRecipientCount((IMailMsgQueueMgmt *) ((CStdStubBuffer *)This)->pvServerObject,dwCount);
        
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


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IMailMsgQueueMgmt_GetRecipientCount_Proxy( 
    IMailMsgQueueMgmt __RPC_FAR * This,
    /* [out] */ DWORD __RPC_FAR *pdwCount)
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
                      6);
        
        
        
        if(!pdwCount)
            {
            RpcRaiseException(RPC_X_NULL_REF_POINTER);
            }
        RpcTryFinally
            {
            
            _StubMsg.BufferLength = 0U;
            NdrProxyGetBuffer(This, &_StubMsg);
            NdrProxySendReceive(This, &_StubMsg);
            
            if ( (_RpcMessage.DataRepresentation & 0X0000FFFFUL) != NDR_LOCAL_DATA_REPRESENTATION )
                NdrConvert( (PMIDL_STUB_MESSAGE) &_StubMsg, (PFORMAT_STRING) &__MIDL_ProcFormatString.Format[4] );
            
            *pdwCount = *(( DWORD __RPC_FAR * )_StubMsg.Buffer)++;
            
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
                         ( PFORMAT_STRING  )&__MIDL_TypeFormatString.Format[2],
                         ( void __RPC_FAR * )pdwCount);
        _RetVal = NdrProxyErrorHandler(RpcExceptionCode());
        }
    RpcEndExcept
    return _RetVal;
}

void __RPC_STUB IMailMsgQueueMgmt_GetRecipientCount_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase)
{
    DWORD _M28;
    HRESULT _RetVal;
    MIDL_STUB_MESSAGE _StubMsg;
    DWORD __RPC_FAR *pdwCount;
    
NdrStubInitialize(
                     _pRpcMessage,
                     &_StubMsg,
                     &Object_StubDesc,
                     _pRpcChannelBuffer);
    ( DWORD __RPC_FAR * )pdwCount = 0;
    RpcTryFinally
        {
        pdwCount = &_M28;
        
        *_pdwStubPhase = STUB_CALL_SERVER;
        _RetVal = (((IMailMsgQueueMgmt*) ((CStdStubBuffer *)This)->pvServerObject)->lpVtbl) -> GetRecipientCount((IMailMsgQueueMgmt *) ((CStdStubBuffer *)This)->pvServerObject,pdwCount);
        
        *_pdwStubPhase = STUB_MARSHAL;
        
        _StubMsg.BufferLength = 4U + 4U;
        NdrStubGetBuffer(This, _pRpcChannelBuffer, &_StubMsg);
        *(( DWORD __RPC_FAR * )_StubMsg.Buffer)++ = *pdwCount;
        
        *(( HRESULT __RPC_FAR * )_StubMsg.Buffer)++ = _RetVal;
        
        }
    RpcFinally
        {
        }
    RpcEndFinally
    _pRpcMessage->BufferLength = 
        (unsigned int)(_StubMsg.Buffer - (unsigned char __RPC_FAR *)_pRpcMessage->Buffer);
    
}


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IMailMsgQueueMgmt_DecrementRecipientCount_Proxy( 
    IMailMsgQueueMgmt __RPC_FAR * This,
    /* [in] */ DWORD dwDecrement)
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
                      7);
        
        
        
        RpcTryFinally
            {
            
            _StubMsg.BufferLength = 4U;
            NdrProxyGetBuffer(This, &_StubMsg);
            *(( DWORD __RPC_FAR * )_StubMsg.Buffer)++ = dwDecrement;
            
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

void __RPC_STUB IMailMsgQueueMgmt_DecrementRecipientCount_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase)
{
    HRESULT _RetVal;
    MIDL_STUB_MESSAGE _StubMsg;
    DWORD dwDecrement;
    
NdrStubInitialize(
                     _pRpcMessage,
                     &_StubMsg,
                     &Object_StubDesc,
                     _pRpcChannelBuffer);
    RpcTryFinally
        {
        if ( (_pRpcMessage->DataRepresentation & 0X0000FFFFUL) != NDR_LOCAL_DATA_REPRESENTATION )
            NdrConvert( (PMIDL_STUB_MESSAGE) &_StubMsg, (PFORMAT_STRING) &__MIDL_ProcFormatString.Format[0] );
        
        dwDecrement = *(( DWORD __RPC_FAR * )_StubMsg.Buffer)++;
        
        
        *_pdwStubPhase = STUB_CALL_SERVER;
        _RetVal = (((IMailMsgQueueMgmt*) ((CStdStubBuffer *)This)->pvServerObject)->lpVtbl) -> DecrementRecipientCount((IMailMsgQueueMgmt *) ((CStdStubBuffer *)This)->pvServerObject,dwDecrement);
        
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


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IMailMsgQueueMgmt_IncrementRecipientCount_Proxy( 
    IMailMsgQueueMgmt __RPC_FAR * This,
    /* [in] */ DWORD dwIncrement)
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
        
        
        
        RpcTryFinally
            {
            
            _StubMsg.BufferLength = 4U;
            NdrProxyGetBuffer(This, &_StubMsg);
            *(( DWORD __RPC_FAR * )_StubMsg.Buffer)++ = dwIncrement;
            
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

void __RPC_STUB IMailMsgQueueMgmt_IncrementRecipientCount_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase)
{
    HRESULT _RetVal;
    MIDL_STUB_MESSAGE _StubMsg;
    DWORD dwIncrement;
    
NdrStubInitialize(
                     _pRpcMessage,
                     &_StubMsg,
                     &Object_StubDesc,
                     _pRpcChannelBuffer);
    RpcTryFinally
        {
        if ( (_pRpcMessage->DataRepresentation & 0X0000FFFFUL) != NDR_LOCAL_DATA_REPRESENTATION )
            NdrConvert( (PMIDL_STUB_MESSAGE) &_StubMsg, (PFORMAT_STRING) &__MIDL_ProcFormatString.Format[0] );
        
        dwIncrement = *(( DWORD __RPC_FAR * )_StubMsg.Buffer)++;
        
        
        *_pdwStubPhase = STUB_CALL_SERVER;
        _RetVal = (((IMailMsgQueueMgmt*) ((CStdStubBuffer *)This)->pvServerObject)->lpVtbl) -> IncrementRecipientCount((IMailMsgQueueMgmt *) ((CStdStubBuffer *)This)->pvServerObject,dwIncrement);
        
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


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IMailMsgQueueMgmt_Delete_Proxy( 
    IMailMsgQueueMgmt __RPC_FAR * This,
    /* [unique][in] */ IMailMsgNotify __RPC_FAR *pNotify)
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
                      9);
        
        
        
        RpcTryFinally
            {
            
            _StubMsg.BufferLength = 0U;
            NdrInterfacePointerBufferSize( (PMIDL_STUB_MESSAGE) &_StubMsg,
                                           (unsigned char __RPC_FAR *)pNotify,
                                           (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[80] );
            
            NdrProxyGetBuffer(This, &_StubMsg);
            NdrInterfacePointerMarshall( (PMIDL_STUB_MESSAGE)& _StubMsg,
                                         (unsigned char __RPC_FAR *)pNotify,
                                         (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[80] );
            
            NdrProxySendReceive(This, &_StubMsg);
            
            if ( (_RpcMessage.DataRepresentation & 0X0000FFFFUL) != NDR_LOCAL_DATA_REPRESENTATION )
                NdrConvert( (PMIDL_STUB_MESSAGE) &_StubMsg, (PFORMAT_STRING) &__MIDL_ProcFormatString.Format[192] );
            
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

void __RPC_STUB IMailMsgQueueMgmt_Delete_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase)
{
    HRESULT _RetVal;
    MIDL_STUB_MESSAGE _StubMsg;
    IMailMsgNotify __RPC_FAR *pNotify;
    
NdrStubInitialize(
                     _pRpcMessage,
                     &_StubMsg,
                     &Object_StubDesc,
                     _pRpcChannelBuffer);
    pNotify = 0;
    RpcTryFinally
        {
        if ( (_pRpcMessage->DataRepresentation & 0X0000FFFFUL) != NDR_LOCAL_DATA_REPRESENTATION )
            NdrConvert( (PMIDL_STUB_MESSAGE) &_StubMsg, (PFORMAT_STRING) &__MIDL_ProcFormatString.Format[192] );
        
        NdrInterfacePointerUnmarshall( (PMIDL_STUB_MESSAGE) &_StubMsg,
                                       (unsigned char __RPC_FAR * __RPC_FAR *)&pNotify,
                                       (PFORMAT_STRING) &__MIDL_TypeFormatString.Format[80],
                                       (unsigned char)0 );
        
        
        *_pdwStubPhase = STUB_CALL_SERVER;
        _RetVal = (((IMailMsgQueueMgmt*) ((CStdStubBuffer *)This)->pvServerObject)->lpVtbl) -> Delete((IMailMsgQueueMgmt *) ((CStdStubBuffer *)This)->pvServerObject,pNotify);
        
        *_pdwStubPhase = STUB_MARSHAL;
        
        _StubMsg.BufferLength = 4U;
        NdrStubGetBuffer(This, _pRpcChannelBuffer, &_StubMsg);
        *(( HRESULT __RPC_FAR * )_StubMsg.Buffer)++ = _RetVal;
        
        }
    RpcFinally
        {
        NdrInterfacePointerFree( &_StubMsg,
                                 (unsigned char __RPC_FAR *)pNotify,
                                 &__MIDL_TypeFormatString.Format[80] );
        
        }
    RpcEndFinally
    _pRpcMessage->BufferLength = 
        (unsigned int)(_StubMsg.Buffer - (unsigned char __RPC_FAR *)_pRpcMessage->Buffer);
    
}

const CINTERFACE_PROXY_VTABLE(10) _IMailMsgQueueMgmtProxyVtbl = 
{
    &IID_IMailMsgQueueMgmt,
    IUnknown_QueryInterface_Proxy,
    IUnknown_AddRef_Proxy,
    IUnknown_Release_Proxy ,
    IMailMsgQueueMgmt_AddUsage_Proxy ,
    IMailMsgQueueMgmt_ReleaseUsage_Proxy ,
    IMailMsgQueueMgmt_SetRecipientCount_Proxy ,
    IMailMsgQueueMgmt_GetRecipientCount_Proxy ,
    IMailMsgQueueMgmt_DecrementRecipientCount_Proxy ,
    IMailMsgQueueMgmt_IncrementRecipientCount_Proxy ,
    IMailMsgQueueMgmt_Delete_Proxy
};


static const PRPC_STUB_FUNCTION IMailMsgQueueMgmt_table[] =
{
    IMailMsgQueueMgmt_AddUsage_Stub,
    IMailMsgQueueMgmt_ReleaseUsage_Stub,
    IMailMsgQueueMgmt_SetRecipientCount_Stub,
    IMailMsgQueueMgmt_GetRecipientCount_Stub,
    IMailMsgQueueMgmt_DecrementRecipientCount_Stub,
    IMailMsgQueueMgmt_IncrementRecipientCount_Stub,
    IMailMsgQueueMgmt_Delete_Stub
};

const CInterfaceStubVtbl _IMailMsgQueueMgmtStubVtbl =
{
    &IID_IMailMsgQueueMgmt,
    0,
    10,
    &IMailMsgQueueMgmt_table[-3],
    CStdStubBuffer_METHODS
};


/* Object interface: ISMTPStoreDriver, ver. 0.0,
   GUID={0xee51588c,0xd64a,0x11d1,{0x9f,0xf7,0x00,0xc0,0x4f,0xa3,0x73,0x48}} */


/* Object interface: IMailMsgBind, ver. 0.0,
   GUID={0x38cb448a,0xca62,0x11d1,{0x9f,0xf3,0x00,0xc0,0x4f,0xa3,0x73,0x48}} */


/* Object interface: IMailMsgPropertyBag, ver. 0.0,
   GUID={0xd6d0509c,0xec51,0x11d1,{0xaa,0x65,0x00,0xc0,0x4f,0xa3,0x5b,0x82}} */


/* Object interface: IMailMsgLoggingPropertyBag, ver. 0.0,
   GUID={0x4cb17416,0xec53,0x11d1,{0xaa,0x65,0x00,0xc0,0x4f,0xa3,0x5b,0x82}} */


/* Object interface: IMailMsgCleanupCallback, ver. 0.0,
   GUID={0x951C04A1,0x29F0,0x4b8e,{0x9E,0xD5,0x83,0x6C,0x73,0x76,0x60,0x51}} */


/* Object interface: IMailMsgRegisterCleanupCallback, ver. 0.0,
   GUID={0x00561C2F,0x5E90,0x49e5,{0x9E,0x73,0x7B,0xF9,0x12,0x92,0x98,0xA0}} */


/* Standard interface: __MIDL_itf_MailMsg_0260, ver. 0.0,
   GUID={0x00000000,0x0000,0x0000,{0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00}} */


/* Object interface: ISMTPServer, ver. 0.0,
   GUID={0x22625594,0xd822,0x11d1,{0x9f,0xf7,0x00,0xc0,0x4f,0xa3,0x73,0x48}} */


/* Object interface: ISMTPServerInternal, ver. 0.0,
   GUID={0x57EE6C15,0x1870,0x11d2,{0xA6,0x89,0x00,0xC0,0x4F,0xA3,0x49,0x0A}} */


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
			0x4e,		/* FC_IN_PARAM_BASETYPE */
			0x8,		/* FC_LONG */
/*  2 */	0x53,		/* FC_RETURN_PARAM_BASETYPE */
			0x8,		/* FC_LONG */
/*  4 */	
			0x51,		/* FC_OUT_PARAM */
#ifndef _ALPHA_
			0x1,		/* x86, MIPS & PPC stack size = 1 */
#else
			0x2,		/* Alpha stack size = 2 */
#endif
/*  6 */	NdrFcShort( 0x2 ),	/* Type Offset=2 */
/*  8 */	0x53,		/* FC_RETURN_PARAM_BASETYPE */
			0x8,		/* FC_LONG */
/* 10 */	0x4e,		/* FC_IN_PARAM_BASETYPE */
			0x8,		/* FC_LONG */
/* 12 */	0x4e,		/* FC_IN_PARAM_BASETYPE */
			0x8,		/* FC_LONG */
/* 14 */	0x4e,		/* FC_IN_PARAM_BASETYPE */
			0x8,		/* FC_LONG */
/* 16 */	
			0x51,		/* FC_OUT_PARAM */
#ifndef _ALPHA_
			0x1,		/* x86, MIPS & PPC stack size = 1 */
#else
			0x2,		/* Alpha stack size = 2 */
#endif
/* 18 */	NdrFcShort( 0x6 ),	/* Type Offset=6 */
/* 20 */	0x53,		/* FC_RETURN_PARAM_BASETYPE */
			0x8,		/* FC_LONG */
/* 22 */	0x4e,		/* FC_IN_PARAM_BASETYPE */
			0x8,		/* FC_LONG */
/* 24 */	0x4e,		/* FC_IN_PARAM_BASETYPE */
			0x8,		/* FC_LONG */
/* 26 */	0x4e,		/* FC_IN_PARAM_BASETYPE */
			0x8,		/* FC_LONG */
/* 28 */	
			0x4d,		/* FC_IN_PARAM */
#ifndef _ALPHA_
			0x1,		/* x86, MIPS & PPC stack size = 1 */
#else
			0x2,		/* Alpha stack size = 2 */
#endif
/* 30 */	NdrFcShort( 0x10 ),	/* Type Offset=16 */
/* 32 */	0x53,		/* FC_RETURN_PARAM_BASETYPE */
			0x8,		/* FC_LONG */
/* 34 */	0x4e,		/* FC_IN_PARAM_BASETYPE */
			0x8,		/* FC_LONG */
/* 36 */	0x4e,		/* FC_IN_PARAM_BASETYPE */
			0x8,		/* FC_LONG */
/* 38 */	0x4e,		/* FC_IN_PARAM_BASETYPE */
			0x8,		/* FC_LONG */
/* 40 */	
			0x51,		/* FC_OUT_PARAM */
#ifndef _ALPHA_
			0x1,		/* x86, MIPS & PPC stack size = 1 */
#else
			0x2,		/* Alpha stack size = 2 */
#endif
/* 42 */	NdrFcShort( 0x2 ),	/* Type Offset=2 */
/* 44 */	
			0x51,		/* FC_OUT_PARAM */
#ifndef _ALPHA_
			0x1,		/* x86, MIPS & PPC stack size = 1 */
#else
			0x2,		/* Alpha stack size = 2 */
#endif
/* 46 */	NdrFcShort( 0x22 ),	/* Type Offset=34 */
/* 48 */	0x53,		/* FC_RETURN_PARAM_BASETYPE */
			0x8,		/* FC_LONG */
/* 50 */	0x4e,		/* FC_IN_PARAM_BASETYPE */
			0x8,		/* FC_LONG */
/* 52 */	0x4e,		/* FC_IN_PARAM_BASETYPE */
			0x8,		/* FC_LONG */
/* 54 */	
			0x4d,		/* FC_IN_PARAM */
#ifndef _ALPHA_
			0x1,		/* x86, MIPS & PPC stack size = 1 */
#else
			0x2,		/* Alpha stack size = 2 */
#endif
/* 56 */	NdrFcShort( 0x34 ),	/* Type Offset=52 */
/* 58 */	0x53,		/* FC_RETURN_PARAM_BASETYPE */
			0x8,		/* FC_LONG */
/* 60 */	0x4e,		/* FC_IN_PARAM_BASETYPE */
			0x8,		/* FC_LONG */
/* 62 */	0x4e,		/* FC_IN_PARAM_BASETYPE */
			0x8,		/* FC_LONG */
/* 64 */	0x4e,		/* FC_IN_PARAM_BASETYPE */
			0x8,		/* FC_LONG */
/* 66 */	
			0x51,		/* FC_OUT_PARAM */
#ifndef _ALPHA_
			0x1,		/* x86, MIPS & PPC stack size = 1 */
#else
			0x2,		/* Alpha stack size = 2 */
#endif
/* 68 */	NdrFcShort( 0x38 ),	/* Type Offset=56 */
/* 70 */	0x53,		/* FC_RETURN_PARAM_BASETYPE */
			0x8,		/* FC_LONG */
/* 72 */	0x4e,		/* FC_IN_PARAM_BASETYPE */
			0x8,		/* FC_LONG */
/* 74 */	0x4e,		/* FC_IN_PARAM_BASETYPE */
			0x8,		/* FC_LONG */
/* 76 */	
			0x4d,		/* FC_IN_PARAM */
#ifndef _ALPHA_
			0x1,		/* x86, MIPS & PPC stack size = 1 */
#else
			0x2,		/* Alpha stack size = 2 */
#endif
/* 78 */	NdrFcShort( 0x42 ),	/* Type Offset=66 */
/* 80 */	0x53,		/* FC_RETURN_PARAM_BASETYPE */
			0x8,		/* FC_LONG */
/* 82 */	0x4e,		/* FC_IN_PARAM_BASETYPE */
			0x8,		/* FC_LONG */
/* 84 */	0x4e,		/* FC_IN_PARAM_BASETYPE */
			0x8,		/* FC_LONG */
/* 86 */	0x4e,		/* FC_IN_PARAM_BASETYPE */
			0x8,		/* FC_LONG */
/* 88 */	
			0x51,		/* FC_OUT_PARAM */
#ifndef _ALPHA_
			0x1,		/* x86, MIPS & PPC stack size = 1 */
#else
			0x2,		/* Alpha stack size = 2 */
#endif
/* 90 */	NdrFcShort( 0x46 ),	/* Type Offset=70 */
/* 92 */	0x53,		/* FC_RETURN_PARAM_BASETYPE */
			0x8,		/* FC_LONG */
/* 94 */	0x4e,		/* FC_IN_PARAM_BASETYPE */
			0x8,		/* FC_LONG */
/* 96 */	0x4e,		/* FC_IN_PARAM_BASETYPE */
			0x8,		/* FC_LONG */
/* 98 */	0x4e,		/* FC_IN_PARAM_BASETYPE */
			0x8,		/* FC_LONG */
/* 100 */	0x53,		/* FC_RETURN_PARAM_BASETYPE */
			0x8,		/* FC_LONG */
/* 102 */	0x4e,		/* FC_IN_PARAM_BASETYPE */
			0x8,		/* FC_LONG */
/* 104 */	0x4e,		/* FC_IN_PARAM_BASETYPE */
			0x8,		/* FC_LONG */
/* 106 */	
			0x51,		/* FC_OUT_PARAM */
#ifndef _ALPHA_
			0x1,		/* x86, MIPS & PPC stack size = 1 */
#else
			0x2,		/* Alpha stack size = 2 */
#endif
/* 108 */	NdrFcShort( 0x2 ),	/* Type Offset=2 */
/* 110 */	0x53,		/* FC_RETURN_PARAM_BASETYPE */
			0x8,		/* FC_LONG */
/* 112 */	0x4e,		/* FC_IN_PARAM_BASETYPE */
			0x8,		/* FC_LONG */
/* 114 */	
			0x4d,		/* FC_IN_PARAM */
#ifndef _ALPHA_
			0x1,		/* x86, MIPS & PPC stack size = 1 */
#else
			0x2,		/* Alpha stack size = 2 */
#endif
/* 116 */	NdrFcShort( 0x50 ),	/* Type Offset=80 */
/* 118 */	0x53,		/* FC_RETURN_PARAM_BASETYPE */
			0x8,		/* FC_LONG */
/* 120 */	0x4e,		/* FC_IN_PARAM_BASETYPE */
			0x8,		/* FC_LONG */
/* 122 */	0x4e,		/* FC_IN_PARAM_BASETYPE */
			0x8,		/* FC_LONG */
/* 124 */	
			0x51,		/* FC_OUT_PARAM */
#ifndef _ALPHA_
			0x1,		/* x86, MIPS & PPC stack size = 1 */
#else
			0x2,		/* Alpha stack size = 2 */
#endif
/* 126 */	NdrFcShort( 0x62 ),	/* Type Offset=98 */
/* 128 */	
			0x51,		/* FC_OUT_PARAM */
#ifndef _ALPHA_
			0x1,		/* x86, MIPS & PPC stack size = 1 */
#else
			0x2,		/* Alpha stack size = 2 */
#endif
/* 130 */	NdrFcShort( 0x2 ),	/* Type Offset=2 */
/* 132 */	
			0x51,		/* FC_OUT_PARAM */
#ifndef _ALPHA_
			0x1,		/* x86, MIPS & PPC stack size = 1 */
#else
			0x2,		/* Alpha stack size = 2 */
#endif
/* 134 */	NdrFcShort( 0x2 ),	/* Type Offset=2 */
/* 136 */	0x53,		/* FC_RETURN_PARAM_BASETYPE */
			0x8,		/* FC_LONG */
/* 138 */	
			0x51,		/* FC_OUT_PARAM */
#ifndef _ALPHA_
			0x1,		/* x86, MIPS & PPC stack size = 1 */
#else
			0x2,		/* Alpha stack size = 2 */
#endif
/* 140 */	NdrFcShort( 0x6c ),	/* Type Offset=108 */
/* 142 */	0x53,		/* FC_RETURN_PARAM_BASETYPE */
			0x8,		/* FC_LONG */
/* 144 */	
			0x4d,		/* FC_IN_PARAM */
#ifndef _ALPHA_
			0x1,		/* x86, MIPS & PPC stack size = 1 */
#else
			0x2,		/* Alpha stack size = 2 */
#endif
/* 146 */	NdrFcShort( 0x70 ),	/* Type Offset=112 */
/* 148 */	0x53,		/* FC_RETURN_PARAM_BASETYPE */
			0x8,		/* FC_LONG */
/* 150 */	
			0x4d,		/* FC_IN_PARAM */
#ifndef _ALPHA_
			0x1,		/* x86, MIPS & PPC stack size = 1 */
#else
			0x2,		/* Alpha stack size = 2 */
#endif
/* 152 */	NdrFcShort( 0x82 ),	/* Type Offset=130 */
/* 154 */	0x4e,		/* FC_IN_PARAM_BASETYPE */
			0x8,		/* FC_LONG */
/* 156 */	0x4e,		/* FC_IN_PARAM_BASETYPE */
			0x8,		/* FC_LONG */
/* 158 */	0x4e,		/* FC_IN_PARAM_BASETYPE */
			0x8,		/* FC_LONG */
/* 160 */	0x53,		/* FC_RETURN_PARAM_BASETYPE */
			0x8,		/* FC_LONG */
/* 162 */	
			0x4d,		/* FC_IN_PARAM */
#ifndef _ALPHA_
			0x1,		/* x86, MIPS & PPC stack size = 1 */
#else
			0x2,		/* Alpha stack size = 2 */
#endif
/* 164 */	NdrFcShort( 0x82 ),	/* Type Offset=130 */
/* 166 */	0x53,		/* FC_RETURN_PARAM_BASETYPE */
			0x8,		/* FC_LONG */
/* 168 */	
			0x4d,		/* FC_IN_PARAM */
#ifndef _ALPHA_
			0x1,		/* x86, MIPS & PPC stack size = 1 */
#else
			0x2,		/* Alpha stack size = 2 */
#endif
/* 170 */	NdrFcShort( 0x82 ),	/* Type Offset=130 */
/* 172 */	
			0x51,		/* FC_OUT_PARAM */
#ifndef _ALPHA_
			0x1,		/* x86, MIPS & PPC stack size = 1 */
#else
			0x2,		/* Alpha stack size = 2 */
#endif
/* 174 */	NdrFcShort( 0x2 ),	/* Type Offset=2 */
/* 176 */	0x53,		/* FC_RETURN_PARAM_BASETYPE */
			0x8,		/* FC_LONG */
/* 178 */	
			0x4d,		/* FC_IN_PARAM */
#ifndef _ALPHA_
			0x1,		/* x86, MIPS & PPC stack size = 1 */
#else
			0x2,		/* Alpha stack size = 2 */
#endif
/* 180 */	NdrFcShort( 0x92 ),	/* Type Offset=146 */
/* 182 */	0x4e,		/* FC_IN_PARAM_BASETYPE */
			0x8,		/* FC_LONG */
/* 184 */	
			0x51,		/* FC_OUT_PARAM */
#ifndef _ALPHA_
			0x1,		/* x86, MIPS & PPC stack size = 1 */
#else
			0x2,		/* Alpha stack size = 2 */
#endif
/* 186 */	NdrFcShort( 0x2 ),	/* Type Offset=2 */
/* 188 */	0x53,		/* FC_RETURN_PARAM_BASETYPE */
			0x8,		/* FC_LONG */
/* 190 */	0x53,		/* FC_RETURN_PARAM_BASETYPE */
			0x8,		/* FC_LONG */
/* 192 */	
			0x4d,		/* FC_IN_PARAM */
#ifndef _ALPHA_
			0x1,		/* x86, MIPS & PPC stack size = 1 */
#else
			0x2,		/* Alpha stack size = 2 */
#endif
/* 194 */	NdrFcShort( 0x50 ),	/* Type Offset=80 */
/* 196 */	0x53,		/* FC_RETURN_PARAM_BASETYPE */
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
			0x11, 0xc,	/* FC_RP [alloced_on_stack] [simple_pointer] */
/*  4 */	0x8,		/* FC_LONG */
			0x5c,		/* FC_PAD */
/*  6 */	
			0x11, 0x0,	/* FC_RP */
/*  8 */	NdrFcShort( 0x2 ),	/* Offset= 2 (10) */
/* 10 */	
			0x22,		/* FC_C_CSTRING */
			0x44,		/* FC_STRING_SIZED */
/* 12 */	0x29,		/* Corr desc:  parameter, FC_ULONG */
			0x0,		/*  */
#ifndef _ALPHA_
/* 14 */	NdrFcShort( 0xc ),	/* x86, MIPS, PPC Stack size/offset = 12 */
#else
			NdrFcShort( 0x18 ),	/* Alpha Stack size/offset = 24 */
#endif
/* 16 */	
			0x12, 0x0,	/* FC_UP */
/* 18 */	NdrFcShort( 0x2 ),	/* Offset= 2 (20) */
/* 20 */	
			0x1c,		/* FC_CVARRAY */
			0x0,		/* 0 */
/* 22 */	NdrFcShort( 0x1 ),	/* 1 */
/* 24 */	0x29,		/* Corr desc:  parameter, FC_ULONG */
			0x0,		/*  */
#ifndef _ALPHA_
/* 26 */	NdrFcShort( 0xc ),	/* x86, MIPS, PPC Stack size/offset = 12 */
#else
			NdrFcShort( 0x18 ),	/* Alpha Stack size/offset = 24 */
#endif
/* 28 */	0x29,		/* Corr desc:  parameter, FC_ULONG */
			0x0,		/*  */
#ifndef _ALPHA_
/* 30 */	NdrFcShort( 0xc ),	/* x86, MIPS, PPC Stack size/offset = 12 */
#else
			NdrFcShort( 0x18 ),	/* Alpha Stack size/offset = 24 */
#endif
/* 32 */	0x1,		/* FC_BYTE */
			0x5b,		/* FC_END */
/* 34 */	
			0x11, 0x0,	/* FC_RP */
/* 36 */	NdrFcShort( 0x2 ),	/* Offset= 2 (38) */
/* 38 */	
			0x1c,		/* FC_CVARRAY */
			0x0,		/* 0 */
/* 40 */	NdrFcShort( 0x1 ),	/* 1 */
/* 42 */	0x29,		/* Corr desc:  parameter, FC_ULONG */
			0x0,		/*  */
#ifndef _ALPHA_
/* 44 */	NdrFcShort( 0xc ),	/* x86, MIPS, PPC Stack size/offset = 12 */
#else
			NdrFcShort( 0x18 ),	/* Alpha Stack size/offset = 24 */
#endif
/* 46 */	0x29,		/* Corr desc:  parameter, FC_ULONG */
			0x54,		/* FC_DEREFERENCE */
#ifndef _ALPHA_
/* 48 */	NdrFcShort( 0x10 ),	/* x86, MIPS, PPC Stack size/offset = 16 */
#else
			NdrFcShort( 0x20 ),	/* Alpha Stack size/offset = 32 */
#endif
/* 50 */	0x1,		/* FC_BYTE */
			0x5b,		/* FC_END */
/* 52 */	
			0x12, 0x8,	/* FC_UP [simple_pointer] */
/* 54 */	
			0x22,		/* FC_C_CSTRING */
			0x5c,		/* FC_PAD */
/* 56 */	
			0x11, 0x0,	/* FC_RP */
/* 58 */	NdrFcShort( 0x2 ),	/* Offset= 2 (60) */
/* 60 */	
			0x22,		/* FC_C_CSTRING */
			0x44,		/* FC_STRING_SIZED */
/* 62 */	0x29,		/* Corr desc:  parameter, FC_ULONG */
			0x0,		/*  */
#ifndef _ALPHA_
/* 64 */	NdrFcShort( 0xc ),	/* x86, MIPS, PPC Stack size/offset = 12 */
#else
			NdrFcShort( 0x18 ),	/* Alpha Stack size/offset = 24 */
#endif
/* 66 */	
			0x12, 0x8,	/* FC_UP [simple_pointer] */
/* 68 */	
			0x25,		/* FC_C_WSTRING */
			0x5c,		/* FC_PAD */
/* 70 */	
			0x11, 0x0,	/* FC_RP */
/* 72 */	NdrFcShort( 0x2 ),	/* Offset= 2 (74) */
/* 74 */	
			0x25,		/* FC_C_WSTRING */
			0x44,		/* FC_STRING_SIZED */
/* 76 */	0x29,		/* Corr desc:  parameter, FC_ULONG */
			0x0,		/*  */
#ifndef _ALPHA_
/* 78 */	NdrFcShort( 0xc ),	/* x86, MIPS, PPC Stack size/offset = 12 */
#else
			NdrFcShort( 0x18 ),	/* Alpha Stack size/offset = 24 */
#endif
/* 80 */	
			0x2f,		/* FC_IP */
			0x5a,		/* FC_CONSTANT_IID */
/* 82 */	NdrFcLong( 0xf7c3c30 ),	/* 259800112 */
/* 86 */	NdrFcShort( 0xa8ad ),	/* -22355 */
/* 88 */	NdrFcShort( 0x11d1 ),	/* 4561 */
/* 90 */	0xaa,		/* 170 */
			0x91,		/* 145 */
/* 92 */	0x0,		/* 0 */
			0xaa,		/* 170 */
/* 94 */	0x0,		/* 0 */
			0x6b,		/* 107 */
/* 96 */	0xc8,		/* 200 */
			0xb,		/* 11 */
/* 98 */	
			0x11, 0x0,	/* FC_RP */
/* 100 */	NdrFcShort( 0x2 ),	/* Offset= 2 (102) */
/* 102 */	
			0x22,		/* FC_C_CSTRING */
			0x44,		/* FC_STRING_SIZED */
/* 104 */	0x29,		/* Corr desc:  parameter, FC_ULONG */
			0x0,		/*  */
#ifndef _ALPHA_
/* 106 */	NdrFcShort( 0x8 ),	/* x86, MIPS, PPC Stack size/offset = 8 */
#else
			NdrFcShort( 0x10 ),	/* Alpha Stack size/offset = 16 */
#endif
/* 108 */	
			0x11, 0x14,	/* FC_RP [alloced_on_stack] [pointer_deref] */
/* 110 */	NdrFcShort( 0x2 ),	/* Offset= 2 (112) */
/* 112 */	
			0x2f,		/* FC_IP */
			0x5a,		/* FC_CONSTANT_IID */
/* 114 */	NdrFcLong( 0x4c28a700 ),	/* 1277732608 */
/* 118 */	NdrFcShort( 0xa892 ),	/* -22382 */
/* 120 */	NdrFcShort( 0x11d1 ),	/* 4561 */
/* 122 */	0xaa,		/* 170 */
			0x91,		/* 145 */
/* 124 */	0x0,		/* 0 */
			0xaa,		/* 170 */
/* 126 */	0x0,		/* 0 */
			0x6b,		/* 107 */
/* 128 */	0xc8,		/* 200 */
			0xb,		/* 11 */
/* 130 */	
			0x12, 0x0,	/* FC_UP */
/* 132 */	NdrFcShort( 0x2 ),	/* Offset= 2 (134) */
/* 134 */	
			0x15,		/* FC_STRUCT */
			0x3,		/* 3 */
/* 136 */	NdrFcShort( 0x18 ),	/* 24 */
/* 138 */	0x8,		/* FC_LONG */
			0x8,		/* FC_LONG */
/* 140 */	0x8,		/* FC_LONG */
			0x8,		/* FC_LONG */
/* 142 */	0x8,		/* FC_LONG */
			0x8,		/* FC_LONG */
/* 144 */	0x5c,		/* FC_PAD */
			0x5b,		/* FC_END */
/* 146 */	
			0x11, 0x0,	/* FC_RP */
/* 148 */	NdrFcShort( 0x8 ),	/* Offset= 8 (156) */
/* 150 */	
			0x1d,		/* FC_SMFARRAY */
			0x0,		/* 0 */
/* 152 */	NdrFcShort( 0x8 ),	/* 8 */
/* 154 */	0x2,		/* FC_CHAR */
			0x5b,		/* FC_END */
/* 156 */	
			0x15,		/* FC_STRUCT */
			0x3,		/* 3 */
/* 158 */	NdrFcShort( 0x10 ),	/* 16 */
/* 160 */	0x8,		/* FC_LONG */
			0x6,		/* FC_SHORT */
/* 162 */	0x6,		/* FC_SHORT */
			0x4c,		/* FC_EMBEDDED_COMPLEX */
/* 164 */	0x0,		/* 0 */
			NdrFcShort( 0xfffffff1 ),	/* Offset= -15 (150) */
			0x5b,		/* FC_END */

			0x0
        }
    };

const CInterfaceProxyVtbl * _MailMsg_ProxyVtblList[] = 
{
    ( CInterfaceProxyVtbl *) &_IMailMsgRecipientsAddProxyVtbl,
    ( CInterfaceProxyVtbl *) &_IMailMsgQueueMgmtProxyVtbl,
    ( CInterfaceProxyVtbl *) &_IMailMsgRecipientsBaseProxyVtbl,
    ( CInterfaceProxyVtbl *) &_IMailMsgNotifyProxyVtbl,
    ( CInterfaceProxyVtbl *) &_IMailMsgPropertyManagementProxyVtbl,
    ( CInterfaceProxyVtbl *) &_IMailMsgRecipientsProxyVtbl,
    0
};

const CInterfaceStubVtbl * _MailMsg_StubVtblList[] = 
{
    ( CInterfaceStubVtbl *) &_IMailMsgRecipientsAddStubVtbl,
    ( CInterfaceStubVtbl *) &_IMailMsgQueueMgmtStubVtbl,
    ( CInterfaceStubVtbl *) &_IMailMsgRecipientsBaseStubVtbl,
    ( CInterfaceStubVtbl *) &_IMailMsgNotifyStubVtbl,
    ( CInterfaceStubVtbl *) &_IMailMsgPropertyManagementStubVtbl,
    ( CInterfaceStubVtbl *) &_IMailMsgRecipientsStubVtbl,
    0
};

PCInterfaceName const _MailMsg_InterfaceNamesList[] = 
{
    "IMailMsgRecipientsAdd",
    "IMailMsgQueueMgmt",
    "IMailMsgRecipientsBase",
    "IMailMsgNotify",
    "IMailMsgPropertyManagement",
    "IMailMsgRecipients",
    0
};


#define _MailMsg_CHECK_IID(n)	IID_GENERIC_CHECK_IID( _MailMsg, pIID, n)

int __stdcall _MailMsg_IID_Lookup( const IID * pIID, int * pIndex )
{
    IID_BS_LOOKUP_SETUP

    IID_BS_LOOKUP_INITIAL_TEST( _MailMsg, 6, 4 )
    IID_BS_LOOKUP_NEXT_TEST( _MailMsg, 2 )
    IID_BS_LOOKUP_NEXT_TEST( _MailMsg, 1 )
    IID_BS_LOOKUP_RETURN_RESULT( _MailMsg, 6, *pIndex )
    
}

const ExtendedProxyFileInfo MailMsg_ProxyFileInfo = 
{
    (PCInterfaceProxyVtblList *) & _MailMsg_ProxyVtblList,
    (PCInterfaceStubVtblList *) & _MailMsg_StubVtblList,
    (const PCInterfaceName * ) & _MailMsg_InterfaceNamesList,
    0, // no delegation
    & _MailMsg_IID_Lookup, 
    6,
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
#define USE_STUBLESS_PROXY


/* verify that the <rpcproxy.h> version is high enough to compile this file*/
#ifndef __REDQ_RPCPROXY_H_VERSION__
#define __REQUIRED_RPCPROXY_H_VERSION__ 475
#endif


#include "rpcproxy.h"
#ifndef __RPCPROXY_H_VERSION__
#error this stub requires an updated version of <rpcproxy.h>
#endif // __RPCPROXY_H_VERSION__


#include "MailMsg.h"

#define TYPE_FORMAT_STRING_SIZE   185                               
#define PROC_FORMAT_STRING_SIZE   1375                              
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


/* Standard interface: __MIDL_itf_MailMsg_0000, ver. 0.0,
   GUID={0x00000000,0x0000,0x0000,{0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00}} */


/* Object interface: IUnknown, ver. 0.0,
   GUID={0x00000000,0x0000,0x0000,{0xC0,0x00,0x00,0x00,0x00,0x00,0x00,0x46}} */


/* Object interface: IMailMsgNotify, ver. 0.0,
   GUID={0x0f7c3c30,0xa8ad,0x11d1,{0xaa,0x91,0x00,0xaa,0x00,0x6b,0xc8,0x0b}} */


extern const MIDL_STUB_DESC Object_StubDesc;


extern const MIDL_SERVER_INFO IMailMsgNotify_ServerInfo;

#pragma code_seg(".orpc")
static const unsigned short IMailMsgNotify_FormatStringOffsetTable[] = 
    {
    0
    };

static const MIDL_SERVER_INFO IMailMsgNotify_ServerInfo = 
    {
    &Object_StubDesc,
    0,
    __MIDL_ProcFormatString.Format,
    &IMailMsgNotify_FormatStringOffsetTable[-3],
    0,
    0,
    0,
    0
    };

static const MIDL_STUBLESS_PROXY_INFO IMailMsgNotify_ProxyInfo =
    {
    &Object_StubDesc,
    __MIDL_ProcFormatString.Format,
    &IMailMsgNotify_FormatStringOffsetTable[-3],
    0,
    0,
    0
    };

CINTERFACE_PROXY_VTABLE(4) _IMailMsgNotifyProxyVtbl = 
{
    &IMailMsgNotify_ProxyInfo,
    &IID_IMailMsgNotify,
    IUnknown_QueryInterface_Proxy,
    IUnknown_AddRef_Proxy,
    IUnknown_Release_Proxy ,
    (void *)-1 /* IMailMsgNotify::Notify */
};

const CInterfaceStubVtbl _IMailMsgNotifyStubVtbl =
{
    &IID_IMailMsgNotify,
    &IMailMsgNotify_ServerInfo,
    4,
    0, /* pure interpreted */
    CStdStubBuffer_METHODS
};


/* Standard interface: __MIDL_itf_MailMsg_0244, ver. 0.0,
   GUID={0x00000000,0x0000,0x0000,{0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00}} */


/* Object interface: IMailMsgPropertyStream, ver. 0.0,
   GUID={0xa44819c0,0xa7cf,0x11d1,{0xaa,0x91,0x00,0xaa,0x00,0x6b,0xc8,0x0b}} */


/* Object interface: IMailMsgRecipientsBase, ver. 0.0,
   GUID={0xd1a97920,0xa891,0x11d1,{0xaa,0x91,0x00,0xaa,0x00,0x6b,0xc8,0x0b}} */


extern const MIDL_STUB_DESC Object_StubDesc;


extern const MIDL_SERVER_INFO IMailMsgRecipientsBase_ServerInfo;

#pragma code_seg(".orpc")
static const unsigned short IMailMsgRecipientsBase_FormatStringOffsetTable[] = 
    {
    38,
    76,
    132,
    188,
    250,
    300,
    356,
    406,
    462,
    512,
    562,
    612
    };

static const MIDL_SERVER_INFO IMailMsgRecipientsBase_ServerInfo = 
    {
    &Object_StubDesc,
    0,
    __MIDL_ProcFormatString.Format,
    &IMailMsgRecipientsBase_FormatStringOffsetTable[-3],
    0,
    0,
    0,
    0
    };

static const MIDL_STUBLESS_PROXY_INFO IMailMsgRecipientsBase_ProxyInfo =
    {
    &Object_StubDesc,
    __MIDL_ProcFormatString.Format,
    &IMailMsgRecipientsBase_FormatStringOffsetTable[-3],
    0,
    0,
    0
    };

CINTERFACE_PROXY_VTABLE(15) _IMailMsgRecipientsBaseProxyVtbl = 
{
    &IMailMsgRecipientsBase_ProxyInfo,
    &IID_IMailMsgRecipientsBase,
    IUnknown_QueryInterface_Proxy,
    IUnknown_AddRef_Proxy,
    IUnknown_Release_Proxy ,
    (void *)-1 /* IMailMsgRecipientsBase::Count */ ,
    (void *)-1 /* IMailMsgRecipientsBase::Item */ ,
    (void *)-1 /* IMailMsgRecipientsBase::PutProperty */ ,
    (void *)-1 /* IMailMsgRecipientsBase::GetProperty */ ,
    (void *)-1 /* IMailMsgRecipientsBase::PutStringA */ ,
    (void *)-1 /* IMailMsgRecipientsBase::GetStringA */ ,
    (void *)-1 /* IMailMsgRecipientsBase::PutStringW */ ,
    (void *)-1 /* IMailMsgRecipientsBase::GetStringW */ ,
    (void *)-1 /* IMailMsgRecipientsBase::PutDWORD */ ,
    (void *)-1 /* IMailMsgRecipientsBase::GetDWORD */ ,
    (void *)-1 /* IMailMsgRecipientsBase::PutBool */ ,
    (void *)-1 /* IMailMsgRecipientsBase::GetBool */
};

const CInterfaceStubVtbl _IMailMsgRecipientsBaseStubVtbl =
{
    &IID_IMailMsgRecipientsBase,
    &IMailMsgRecipientsBase_ServerInfo,
    15,
    0, /* pure interpreted */
    CStdStubBuffer_METHODS
};


/* Object interface: IMailMsgRecipientsAdd, ver. 0.0,
   GUID={0x4c28a700,0xa892,0x11d1,{0xaa,0x91,0x00,0xaa,0x00,0x6b,0xc8,0x0b}} */


extern const MIDL_STUB_DESC Object_StubDesc;


extern const MIDL_SERVER_INFO IMailMsgRecipientsAdd_ServerInfo;

#pragma code_seg(".orpc")
static const unsigned short IMailMsgRecipientsAdd_FormatStringOffsetTable[] = 
    {
    38,
    76,
    132,
    188,
    250,
    300,
    356,
    406,
    462,
    512,
    562,
    612,
    (unsigned short) -1,
    (unsigned short) -1
    };

static const MIDL_SERVER_INFO IMailMsgRecipientsAdd_ServerInfo = 
    {
    &Object_StubDesc,
    0,
    __MIDL_ProcFormatString.Format,
    &IMailMsgRecipientsAdd_FormatStringOffsetTable[-3],
    0,
    0,
    0,
    0
    };

static const MIDL_STUBLESS_PROXY_INFO IMailMsgRecipientsAdd_ProxyInfo =
    {
    &Object_StubDesc,
    __MIDL_ProcFormatString.Format,
    &IMailMsgRecipientsAdd_FormatStringOffsetTable[-3],
    0,
    0,
    0
    };

CINTERFACE_PROXY_VTABLE(17) _IMailMsgRecipientsAddProxyVtbl = 
{
    &IMailMsgRecipientsAdd_ProxyInfo,
    &IID_IMailMsgRecipientsAdd,
    IUnknown_QueryInterface_Proxy,
    IUnknown_AddRef_Proxy,
    IUnknown_Release_Proxy ,
    (void *)-1 /* IMailMsgRecipientsBase::Count */ ,
    (void *)-1 /* IMailMsgRecipientsBase::Item */ ,
    (void *)-1 /* IMailMsgRecipientsBase::PutProperty */ ,
    (void *)-1 /* IMailMsgRecipientsBase::GetProperty */ ,
    (void *)-1 /* IMailMsgRecipientsBase::PutStringA */ ,
    (void *)-1 /* IMailMsgRecipientsBase::GetStringA */ ,
    (void *)-1 /* IMailMsgRecipientsBase::PutStringW */ ,
    (void *)-1 /* IMailMsgRecipientsBase::GetStringW */ ,
    (void *)-1 /* IMailMsgRecipientsBase::PutDWORD */ ,
    (void *)-1 /* IMailMsgRecipientsBase::GetDWORD */ ,
    (void *)-1 /* IMailMsgRecipientsBase::PutBool */ ,
    (void *)-1 /* IMailMsgRecipientsBase::GetBool */ ,
    0 /* (void *)-1 /* IMailMsgRecipientsAdd::AddPrimary */ ,
    0 /* (void *)-1 /* IMailMsgRecipientsAdd::AddSecondary */
};

const CInterfaceStubVtbl _IMailMsgRecipientsAddStubVtbl =
{
    &IID_IMailMsgRecipientsAdd,
    &IMailMsgRecipientsAdd_ServerInfo,
    17,
    0, /* pure interpreted */
    CStdStubBuffer_METHODS
};


/* Object interface: IMailMsgRecipients, ver. 0.0,
   GUID={0x19507fe0,0xa892,0x11d1,{0xaa,0x91,0x00,0xaa,0x00,0x6b,0xc8,0x0b}} */


extern const MIDL_STUB_DESC Object_StubDesc;


extern const MIDL_SERVER_INFO IMailMsgRecipients_ServerInfo;

#pragma code_seg(".orpc")
static const unsigned short IMailMsgRecipients_FormatStringOffsetTable[] = 
    {
    38,
    76,
    132,
    188,
    250,
    300,
    356,
    406,
    462,
    512,
    562,
    612,
    662,
    706,
    744,
    806,
    844,
    882,
    932,
    988,
    1026
    };

static const MIDL_SERVER_INFO IMailMsgRecipients_ServerInfo = 
    {
    &Object_StubDesc,
    0,
    __MIDL_ProcFormatString.Format,
    &IMailMsgRecipients_FormatStringOffsetTable[-3],
    0,
    0,
    0,
    0
    };

static const MIDL_STUBLESS_PROXY_INFO IMailMsgRecipients_ProxyInfo =
    {
    &Object_StubDesc,
    __MIDL_ProcFormatString.Format,
    &IMailMsgRecipients_FormatStringOffsetTable[-3],
    0,
    0,
    0
    };

CINTERFACE_PROXY_VTABLE(24) _IMailMsgRecipientsProxyVtbl = 
{
    &IMailMsgRecipients_ProxyInfo,
    &IID_IMailMsgRecipients,
    IUnknown_QueryInterface_Proxy,
    IUnknown_AddRef_Proxy,
    IUnknown_Release_Proxy ,
    (void *)-1 /* IMailMsgRecipientsBase::Count */ ,
    (void *)-1 /* IMailMsgRecipientsBase::Item */ ,
    (void *)-1 /* IMailMsgRecipientsBase::PutProperty */ ,
    (void *)-1 /* IMailMsgRecipientsBase::GetProperty */ ,
    (void *)-1 /* IMailMsgRecipientsBase::PutStringA */ ,
    (void *)-1 /* IMailMsgRecipientsBase::GetStringA */ ,
    (void *)-1 /* IMailMsgRecipientsBase::PutStringW */ ,
    (void *)-1 /* IMailMsgRecipientsBase::GetStringW */ ,
    (void *)-1 /* IMailMsgRecipientsBase::PutDWORD */ ,
    (void *)-1 /* IMailMsgRecipientsBase::GetDWORD */ ,
    (void *)-1 /* IMailMsgRecipientsBase::PutBool */ ,
    (void *)-1 /* IMailMsgRecipientsBase::GetBool */ ,
    (void *)-1 /* IMailMsgRecipients::Commit */ ,
    (void *)-1 /* IMailMsgRecipients::DomainCount */ ,
    (void *)-1 /* IMailMsgRecipients::DomainItem */ ,
    (void *)-1 /* IMailMsgRecipients::AllocNewList */ ,
    (void *)-1 /* IMailMsgRecipients::WriteList */ ,
    (void *)-1 /* IMailMsgRecipients::SetNextDomain */ ,
    (void *)-1 /* IMailMsgRecipients::InitializeRecipientFilterContext */ ,
    (void *)-1 /* IMailMsgRecipients::TerminateRecipientFilterContext */ ,
    (void *)-1 /* IMailMsgRecipients::GetNextRecipient */
};

const CInterfaceStubVtbl _IMailMsgRecipientsStubVtbl =
{
    &IID_IMailMsgRecipients,
    &IMailMsgRecipients_ServerInfo,
    24,
    0, /* pure interpreted */
    CStdStubBuffer_METHODS
};


/* Object interface: IMailMsgProperties, ver. 0.0,
   GUID={0xab95fb40,0xa34f,0x11d1,{0xaa,0x8a,0x00,0xaa,0x00,0x6b,0xc8,0x0b}} */


/* Object interface: IMailMsgValidate, ver. 0.0,
   GUID={0x6717b03c,0x072c,0x11d3,{0x94,0xff,0x00,0xc0,0x4f,0xa3,0x79,0xf1}} */


/* Object interface: IMailMsgPropertyManagement, ver. 0.0,
   GUID={0xa2f196c0,0xa351,0x11d1,{0xaa,0x8a,0x00,0xaa,0x00,0x6b,0xc8,0x0b}} */


extern const MIDL_STUB_DESC Object_StubDesc;


extern const MIDL_SERVER_INFO IMailMsgPropertyManagement_ServerInfo;

#pragma code_seg(".orpc")
static const unsigned short IMailMsgPropertyManagement_FormatStringOffsetTable[] = 
    {
    1070
    };

static const MIDL_SERVER_INFO IMailMsgPropertyManagement_ServerInfo = 
    {
    &Object_StubDesc,
    0,
    __MIDL_ProcFormatString.Format,
    &IMailMsgPropertyManagement_FormatStringOffsetTable[-3],
    0,
    0,
    0,
    0
    };

static const MIDL_STUBLESS_PROXY_INFO IMailMsgPropertyManagement_ProxyInfo =
    {
    &Object_StubDesc,
    __MIDL_ProcFormatString.Format,
    &IMailMsgPropertyManagement_FormatStringOffsetTable[-3],
    0,
    0,
    0
    };

CINTERFACE_PROXY_VTABLE(4) _IMailMsgPropertyManagementProxyVtbl = 
{
    &IMailMsgPropertyManagement_ProxyInfo,
    &IID_IMailMsgPropertyManagement,
    IUnknown_QueryInterface_Proxy,
    IUnknown_AddRef_Proxy,
    IUnknown_Release_Proxy ,
    (void *)-1 /* IMailMsgPropertyManagement::AllocPropIDRange */
};

const CInterfaceStubVtbl _IMailMsgPropertyManagementStubVtbl =
{
    &IID_IMailMsgPropertyManagement,
    &IMailMsgPropertyManagement_ServerInfo,
    4,
    0, /* pure interpreted */
    CStdStubBuffer_METHODS
};


/* Object interface: IMailMsgEnumMessages, ver. 0.0,
   GUID={0xe760a840,0xc8f1,0x11d1,{0x9f,0xf2,0x00,0xc0,0x4f,0xa3,0x73,0x48}} */


/* Object interface: IMailMsgStoreDriver, ver. 0.0,
   GUID={0x246aae60,0xacc4,0x11d1,{0xaa,0x91,0x00,0xaa,0x00,0x6b,0xc8,0x0b}} */


/* Object interface: IMailMsgQueueMgmt, ver. 0.0,
   GUID={0xb2564d0a,0xd5a1,0x11d1,{0x9f,0xf7,0x00,0xc0,0x4f,0xa3,0x73,0x48}} */


extern const MIDL_STUB_DESC Object_StubDesc;


extern const MIDL_SERVER_INFO IMailMsgQueueMgmt_ServerInfo;

#pragma code_seg(".orpc")
static const unsigned short IMailMsgQueueMgmt_FormatStringOffsetTable[] = 
    {
    1120,
    1152,
    1184,
    1222,
    1260,
    1298,
    1336
    };

static const MIDL_SERVER_INFO IMailMsgQueueMgmt_ServerInfo = 
    {
    &Object_StubDesc,
    0,
    __MIDL_ProcFormatString.Format,
    &IMailMsgQueueMgmt_FormatStringOffsetTable[-3],
    0,
    0,
    0,
    0
    };

static const MIDL_STUBLESS_PROXY_INFO IMailMsgQueueMgmt_ProxyInfo =
    {
    &Object_StubDesc,
    __MIDL_ProcFormatString.Format,
    &IMailMsgQueueMgmt_FormatStringOffsetTable[-3],
    0,
    0,
    0
    };

CINTERFACE_PROXY_VTABLE(10) _IMailMsgQueueMgmtProxyVtbl = 
{
    &IMailMsgQueueMgmt_ProxyInfo,
    &IID_IMailMsgQueueMgmt,
    IUnknown_QueryInterface_Proxy,
    IUnknown_AddRef_Proxy,
    IUnknown_Release_Proxy ,
    (void *)-1 /* IMailMsgQueueMgmt::AddUsage */ ,
    (void *)-1 /* IMailMsgQueueMgmt::ReleaseUsage */ ,
    (void *)-1 /* IMailMsgQueueMgmt::SetRecipientCount */ ,
    (void *)-1 /* IMailMsgQueueMgmt::GetRecipientCount */ ,
    (void *)-1 /* IMailMsgQueueMgmt::DecrementRecipientCount */ ,
    (void *)-1 /* IMailMsgQueueMgmt::IncrementRecipientCount */ ,
    (void *)-1 /* IMailMsgQueueMgmt::Delete */
};

const CInterfaceStubVtbl _IMailMsgQueueMgmtStubVtbl =
{
    &IID_IMailMsgQueueMgmt,
    &IMailMsgQueueMgmt_ServerInfo,
    10,
    0, /* pure interpreted */
    CStdStubBuffer_METHODS
};


/* Object interface: ISMTPStoreDriver, ver. 0.0,
   GUID={0xee51588c,0xd64a,0x11d1,{0x9f,0xf7,0x00,0xc0,0x4f,0xa3,0x73,0x48}} */


/* Object interface: IMailMsgBind, ver. 0.0,
   GUID={0x38cb448a,0xca62,0x11d1,{0x9f,0xf3,0x00,0xc0,0x4f,0xa3,0x73,0x48}} */


/* Object interface: IMailMsgPropertyBag, ver. 0.0,
   GUID={0xd6d0509c,0xec51,0x11d1,{0xaa,0x65,0x00,0xc0,0x4f,0xa3,0x5b,0x82}} */


/* Object interface: IMailMsgLoggingPropertyBag, ver. 0.0,
   GUID={0x4cb17416,0xec53,0x11d1,{0xaa,0x65,0x00,0xc0,0x4f,0xa3,0x5b,0x82}} */


/* Object interface: IMailMsgCleanupCallback, ver. 0.0,
   GUID={0x951C04A1,0x29F0,0x4b8e,{0x9E,0xD5,0x83,0x6C,0x73,0x76,0x60,0x51}} */


/* Object interface: IMailMsgRegisterCleanupCallback, ver. 0.0,
   GUID={0x00561C2F,0x5E90,0x49e5,{0x9E,0x73,0x7B,0xF9,0x12,0x92,0x98,0xA0}} */


/* Standard interface: __MIDL_itf_MailMsg_0260, ver. 0.0,
   GUID={0x00000000,0x0000,0x0000,{0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00}} */


/* Object interface: ISMTPServer, ver. 0.0,
   GUID={0x22625594,0xd822,0x11d1,{0x9f,0xf7,0x00,0xc0,0x4f,0xa3,0x73,0x48}} */


/* Object interface: ISMTPServerInternal, ver. 0.0,
   GUID={0x57EE6C15,0x1870,0x11d2,{0xA6,0x89,0x00,0xC0,0x4F,0xA3,0x49,0x0A}} */


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

	/* Procedure Notify */

			0x33,		/* FC_AUTO_HANDLE */
			0x6c,		/* Old Flags:  object, Oi2 */
/*  2 */	NdrFcLong( 0x0 ),	/* 0 */
/*  6 */	NdrFcShort( 0x3 ),	/* 3 */
/*  8 */	NdrFcShort( 0x18 ),	/* ia64, axp64 Stack size/offset = 24 */
/* 10 */	NdrFcShort( 0x8 ),	/* 8 */
/* 12 */	NdrFcShort( 0x8 ),	/* 8 */
/* 14 */	0x44,		/* Oi2 Flags:  has return, has ext, */
			0x2,		/* 2 */
/* 16 */	0xa,		/* 10 */
			0x1,		/* Ext Flags:  new corr desc, */
/* 18 */	NdrFcShort( 0x0 ),	/* 0 */
/* 20 */	NdrFcShort( 0x0 ),	/* 0 */
/* 22 */	NdrFcShort( 0x0 ),	/* 0 */
/* 24 */	NdrFcShort( 0x0 ),	/* 0 */

	/* Parameter hrRes */

/* 26 */	NdrFcShort( 0x48 ),	/* Flags:  in, base type, */
/* 28 */	NdrFcShort( 0x8 ),	/* ia64, axp64 Stack size/offset = 8 */
/* 30 */	0x8,		/* FC_LONG */
			0x0,		/* 0 */

	/* Return value */

/* 32 */	NdrFcShort( 0x70 ),	/* Flags:  out, return, base type, */
/* 34 */	NdrFcShort( 0x10 ),	/* ia64, axp64 Stack size/offset = 16 */
/* 36 */	0x8,		/* FC_LONG */
			0x0,		/* 0 */

	/* Procedure Count */

/* 38 */	0x33,		/* FC_AUTO_HANDLE */
			0x6c,		/* Old Flags:  object, Oi2 */
/* 40 */	NdrFcLong( 0x0 ),	/* 0 */
/* 44 */	NdrFcShort( 0x3 ),	/* 3 */
/* 46 */	NdrFcShort( 0x18 ),	/* ia64, axp64 Stack size/offset = 24 */
/* 48 */	NdrFcShort( 0x0 ),	/* 0 */
/* 50 */	NdrFcShort( 0x10 ),	/* 16 */
/* 52 */	0x44,		/* Oi2 Flags:  has return, has ext, */
			0x2,		/* 2 */
/* 54 */	0xa,		/* 10 */
			0x1,		/* Ext Flags:  new corr desc, */
/* 56 */	NdrFcShort( 0x0 ),	/* 0 */
/* 58 */	NdrFcShort( 0x0 ),	/* 0 */
/* 60 */	NdrFcShort( 0x0 ),	/* 0 */
/* 62 */	NdrFcShort( 0x0 ),	/* 0 */

	/* Parameter pdwCount */

/* 64 */	NdrFcShort( 0x2150 ),	/* Flags:  out, base type, simple ref, srv alloc size=8 */
/* 66 */	NdrFcShort( 0x8 ),	/* ia64, axp64 Stack size/offset = 8 */
/* 68 */	0x8,		/* FC_LONG */
			0x0,		/* 0 */

	/* Return value */

/* 70 */	NdrFcShort( 0x70 ),	/* Flags:  out, return, base type, */
/* 72 */	NdrFcShort( 0x10 ),	/* ia64, axp64 Stack size/offset = 16 */
/* 74 */	0x8,		/* FC_LONG */
			0x0,		/* 0 */

	/* Procedure Item */

/* 76 */	0x33,		/* FC_AUTO_HANDLE */
			0x6c,		/* Old Flags:  object, Oi2 */
/* 78 */	NdrFcLong( 0x0 ),	/* 0 */
/* 82 */	NdrFcShort( 0x4 ),	/* 4 */
/* 84 */	NdrFcShort( 0x30 ),	/* ia64, axp64 Stack size/offset = 48 */
/* 86 */	NdrFcShort( 0x18 ),	/* 24 */
/* 88 */	NdrFcShort( 0x8 ),	/* 8 */
/* 90 */	0x45,		/* Oi2 Flags:  srv must size, has return, has ext, */
			0x5,		/* 5 */
/* 92 */	0xa,		/* 10 */
			0x3,		/* Ext Flags:  new corr desc, clt corr check, */
/* 94 */	NdrFcShort( 0x1 ),	/* 1 */
/* 96 */	NdrFcShort( 0x0 ),	/* 0 */
/* 98 */	NdrFcShort( 0x0 ),	/* 0 */
/* 100 */	NdrFcShort( 0x0 ),	/* 0 */

	/* Parameter dwIndex */

/* 102 */	NdrFcShort( 0x48 ),	/* Flags:  in, base type, */
/* 104 */	NdrFcShort( 0x8 ),	/* ia64, axp64 Stack size/offset = 8 */
/* 106 */	0x8,		/* FC_LONG */
			0x0,		/* 0 */

	/* Parameter dwWhichName */

/* 108 */	NdrFcShort( 0x48 ),	/* Flags:  in, base type, */
/* 110 */	NdrFcShort( 0x10 ),	/* ia64, axp64 Stack size/offset = 16 */
/* 112 */	0x8,		/* FC_LONG */
			0x0,		/* 0 */

	/* Parameter cchLength */

/* 114 */	NdrFcShort( 0x48 ),	/* Flags:  in, base type, */
/* 116 */	NdrFcShort( 0x18 ),	/* ia64, axp64 Stack size/offset = 24 */
/* 118 */	0x8,		/* FC_LONG */
			0x0,		/* 0 */

	/* Parameter pszName */

/* 120 */	NdrFcShort( 0x113 ),	/* Flags:  must size, must free, out, simple ref, */
/* 122 */	NdrFcShort( 0x20 ),	/* ia64, axp64 Stack size/offset = 32 */
/* 124 */	NdrFcShort( 0xa ),	/* Type Offset=10 */

	/* Return value */

/* 126 */	NdrFcShort( 0x70 ),	/* Flags:  out, return, base type, */
/* 128 */	NdrFcShort( 0x28 ),	/* ia64, axp64 Stack size/offset = 40 */
/* 130 */	0x8,		/* FC_LONG */
			0x0,		/* 0 */

	/* Procedure PutProperty */

/* 132 */	0x33,		/* FC_AUTO_HANDLE */
			0x6c,		/* Old Flags:  object, Oi2 */
/* 134 */	NdrFcLong( 0x0 ),	/* 0 */
/* 138 */	NdrFcShort( 0x5 ),	/* 5 */
/* 140 */	NdrFcShort( 0x30 ),	/* ia64, axp64 Stack size/offset = 48 */
/* 142 */	NdrFcShort( 0x18 ),	/* 24 */
/* 144 */	NdrFcShort( 0x8 ),	/* 8 */
/* 146 */	0x46,		/* Oi2 Flags:  clt must size, has return, has ext, */
			0x5,		/* 5 */
/* 148 */	0xa,		/* 10 */
			0x5,		/* Ext Flags:  new corr desc, srv corr check, */
/* 150 */	NdrFcShort( 0x0 ),	/* 0 */
/* 152 */	NdrFcShort( 0x1 ),	/* 1 */
/* 154 */	NdrFcShort( 0x0 ),	/* 0 */
/* 156 */	NdrFcShort( 0x0 ),	/* 0 */

	/* Parameter dwIndex */

/* 158 */	NdrFcShort( 0x48 ),	/* Flags:  in, base type, */
/* 160 */	NdrFcShort( 0x8 ),	/* ia64, axp64 Stack size/offset = 8 */
/* 162 */	0x8,		/* FC_LONG */
			0x0,		/* 0 */

	/* Parameter dwPropID */

/* 164 */	NdrFcShort( 0x48 ),	/* Flags:  in, base type, */
/* 166 */	NdrFcShort( 0x10 ),	/* ia64, axp64 Stack size/offset = 16 */
/* 168 */	0x8,		/* FC_LONG */
			0x0,		/* 0 */

	/* Parameter cbLength */

/* 170 */	NdrFcShort( 0x48 ),	/* Flags:  in, base type, */
/* 172 */	NdrFcShort( 0x18 ),	/* ia64, axp64 Stack size/offset = 24 */
/* 174 */	0x8,		/* FC_LONG */
			0x0,		/* 0 */

	/* Parameter pbValue */

/* 176 */	NdrFcShort( 0xb ),	/* Flags:  must size, must free, in, */
/* 178 */	NdrFcShort( 0x20 ),	/* ia64, axp64 Stack size/offset = 32 */
/* 180 */	NdrFcShort( 0x12 ),	/* Type Offset=18 */

	/* Return value */

/* 182 */	NdrFcShort( 0x70 ),	/* Flags:  out, return, base type, */
/* 184 */	NdrFcShort( 0x28 ),	/* ia64, axp64 Stack size/offset = 40 */
/* 186 */	0x8,		/* FC_LONG */
			0x0,		/* 0 */

	/* Procedure GetProperty */

/* 188 */	0x33,		/* FC_AUTO_HANDLE */
			0x6c,		/* Old Flags:  object, Oi2 */
/* 190 */	NdrFcLong( 0x0 ),	/* 0 */
/* 194 */	NdrFcShort( 0x6 ),	/* 6 */
/* 196 */	NdrFcShort( 0x38 ),	/* ia64, axp64 Stack size/offset = 56 */
/* 198 */	NdrFcShort( 0x18 ),	/* 24 */
/* 200 */	NdrFcShort( 0x10 ),	/* 16 */
/* 202 */	0x45,		/* Oi2 Flags:  srv must size, has return, has ext, */
			0x6,		/* 6 */
/* 204 */	0xa,		/* 10 */
			0x3,		/* Ext Flags:  new corr desc, clt corr check, */
/* 206 */	NdrFcShort( 0x1 ),	/* 1 */
/* 208 */	NdrFcShort( 0x0 ),	/* 0 */
/* 210 */	NdrFcShort( 0x0 ),	/* 0 */
/* 212 */	NdrFcShort( 0x0 ),	/* 0 */

	/* Parameter dwIndex */

/* 214 */	NdrFcShort( 0x48 ),	/* Flags:  in, base type, */
/* 216 */	NdrFcShort( 0x8 ),	/* ia64, axp64 Stack size/offset = 8 */
/* 218 */	0x8,		/* FC_LONG */
			0x0,		/* 0 */

	/* Parameter dwPropID */

/* 220 */	NdrFcShort( 0x48 ),	/* Flags:  in, base type, */
/* 222 */	NdrFcShort( 0x10 ),	/* ia64, axp64 Stack size/offset = 16 */
/* 224 */	0x8,		/* FC_LONG */
			0x0,		/* 0 */

	/* Parameter cbLength */

/* 226 */	NdrFcShort( 0x48 ),	/* Flags:  in, base type, */
/* 228 */	NdrFcShort( 0x18 ),	/* ia64, axp64 Stack size/offset = 24 */
/* 230 */	0x8,		/* FC_LONG */
			0x0,		/* 0 */

	/* Parameter pcbLength */

/* 232 */	NdrFcShort( 0x2150 ),	/* Flags:  out, base type, simple ref, srv alloc size=8 */
/* 234 */	NdrFcShort( 0x20 ),	/* ia64, axp64 Stack size/offset = 32 */
/* 236 */	0x8,		/* FC_LONG */
			0x0,		/* 0 */

	/* Parameter pbValue */

/* 238 */	NdrFcShort( 0x113 ),	/* Flags:  must size, must free, out, simple ref, */
/* 240 */	NdrFcShort( 0x28 ),	/* ia64, axp64 Stack size/offset = 40 */
/* 242 */	NdrFcShort( 0x2c ),	/* Type Offset=44 */

	/* Return value */

/* 244 */	NdrFcShort( 0x70 ),	/* Flags:  out, return, base type, */
/* 246 */	NdrFcShort( 0x30 ),	/* ia64, axp64 Stack size/offset = 48 */
/* 248 */	0x8,		/* FC_LONG */
			0x0,		/* 0 */

	/* Procedure PutStringA */

/* 250 */	0x33,		/* FC_AUTO_HANDLE */
			0x6c,		/* Old Flags:  object, Oi2 */
/* 252 */	NdrFcLong( 0x0 ),	/* 0 */
/* 256 */	NdrFcShort( 0x7 ),	/* 7 */
/* 258 */	NdrFcShort( 0x28 ),	/* ia64, axp64 Stack size/offset = 40 */
/* 260 */	NdrFcShort( 0x10 ),	/* 16 */
/* 262 */	NdrFcShort( 0x8 ),	/* 8 */
/* 264 */	0x46,		/* Oi2 Flags:  clt must size, has return, has ext, */
			0x4,		/* 4 */
/* 266 */	0xa,		/* 10 */
			0x1,		/* Ext Flags:  new corr desc, */
/* 268 */	NdrFcShort( 0x0 ),	/* 0 */
/* 270 */	NdrFcShort( 0x0 ),	/* 0 */
/* 272 */	NdrFcShort( 0x0 ),	/* 0 */
/* 274 */	NdrFcShort( 0x0 ),	/* 0 */

	/* Parameter dwIndex */

/* 276 */	NdrFcShort( 0x48 ),	/* Flags:  in, base type, */
/* 278 */	NdrFcShort( 0x8 ),	/* ia64, axp64 Stack size/offset = 8 */
/* 280 */	0x8,		/* FC_LONG */
			0x0,		/* 0 */

	/* Parameter dwPropID */

/* 282 */	NdrFcShort( 0x48 ),	/* Flags:  in, base type, */
/* 284 */	NdrFcShort( 0x10 ),	/* ia64, axp64 Stack size/offset = 16 */
/* 286 */	0x8,		/* FC_LONG */
			0x0,		/* 0 */

	/* Parameter pszValue */

/* 288 */	NdrFcShort( 0xb ),	/* Flags:  must size, must free, in, */
/* 290 */	NdrFcShort( 0x18 ),	/* ia64, axp64 Stack size/offset = 24 */
/* 292 */	NdrFcShort( 0x3e ),	/* Type Offset=62 */

	/* Return value */

/* 294 */	NdrFcShort( 0x70 ),	/* Flags:  out, return, base type, */
/* 296 */	NdrFcShort( 0x20 ),	/* ia64, axp64 Stack size/offset = 32 */
/* 298 */	0x8,		/* FC_LONG */
			0x0,		/* 0 */

	/* Procedure GetStringA */

/* 300 */	0x33,		/* FC_AUTO_HANDLE */
			0x6c,		/* Old Flags:  object, Oi2 */
/* 302 */	NdrFcLong( 0x0 ),	/* 0 */
/* 306 */	NdrFcShort( 0x8 ),	/* 8 */
/* 308 */	NdrFcShort( 0x30 ),	/* ia64, axp64 Stack size/offset = 48 */
/* 310 */	NdrFcShort( 0x18 ),	/* 24 */
/* 312 */	NdrFcShort( 0x8 ),	/* 8 */
/* 314 */	0x45,		/* Oi2 Flags:  srv must size, has return, has ext, */
			0x5,		/* 5 */
/* 316 */	0xa,		/* 10 */
			0x3,		/* Ext Flags:  new corr desc, clt corr check, */
/* 318 */	NdrFcShort( 0x1 ),	/* 1 */
/* 320 */	NdrFcShort( 0x0 ),	/* 0 */
/* 322 */	NdrFcShort( 0x0 ),	/* 0 */
/* 324 */	NdrFcShort( 0x0 ),	/* 0 */

	/* Parameter dwIndex */

/* 326 */	NdrFcShort( 0x48 ),	/* Flags:  in, base type, */
/* 328 */	NdrFcShort( 0x8 ),	/* ia64, axp64 Stack size/offset = 8 */
/* 330 */	0x8,		/* FC_LONG */
			0x0,		/* 0 */

	/* Parameter dwPropID */

/* 332 */	NdrFcShort( 0x48 ),	/* Flags:  in, base type, */
/* 334 */	NdrFcShort( 0x10 ),	/* ia64, axp64 Stack size/offset = 16 */
/* 336 */	0x8,		/* FC_LONG */
			0x0,		/* 0 */

	/* Parameter cchLength */

/* 338 */	NdrFcShort( 0x48 ),	/* Flags:  in, base type, */
/* 340 */	NdrFcShort( 0x18 ),	/* ia64, axp64 Stack size/offset = 24 */
/* 342 */	0x8,		/* FC_LONG */
			0x0,		/* 0 */

	/* Parameter pszValue */

/* 344 */	NdrFcShort( 0x113 ),	/* Flags:  must size, must free, out, simple ref, */
/* 346 */	NdrFcShort( 0x20 ),	/* ia64, axp64 Stack size/offset = 32 */
/* 348 */	NdrFcShort( 0x46 ),	/* Type Offset=70 */

	/* Return value */

/* 350 */	NdrFcShort( 0x70 ),	/* Flags:  out, return, base type, */
/* 352 */	NdrFcShort( 0x28 ),	/* ia64, axp64 Stack size/offset = 40 */
/* 354 */	0x8,		/* FC_LONG */
			0x0,		/* 0 */

	/* Procedure PutStringW */

/* 356 */	0x33,		/* FC_AUTO_HANDLE */
			0x6c,		/* Old Flags:  object, Oi2 */
/* 358 */	NdrFcLong( 0x0 ),	/* 0 */
/* 362 */	NdrFcShort( 0x9 ),	/* 9 */
/* 364 */	NdrFcShort( 0x28 ),	/* ia64, axp64 Stack size/offset = 40 */
/* 366 */	NdrFcShort( 0x10 ),	/* 16 */
/* 368 */	NdrFcShort( 0x8 ),	/* 8 */
/* 370 */	0x46,		/* Oi2 Flags:  clt must size, has return, has ext, */
			0x4,		/* 4 */
/* 372 */	0xa,		/* 10 */
			0x1,		/* Ext Flags:  new corr desc, */
/* 374 */	NdrFcShort( 0x0 ),	/* 0 */
/* 376 */	NdrFcShort( 0x0 ),	/* 0 */
/* 378 */	NdrFcShort( 0x0 ),	/* 0 */
/* 380 */	NdrFcShort( 0x0 ),	/* 0 */

	/* Parameter dwIndex */

/* 382 */	NdrFcShort( 0x48 ),	/* Flags:  in, base type, */
/* 384 */	NdrFcShort( 0x8 ),	/* ia64, axp64 Stack size/offset = 8 */
/* 386 */	0x8,		/* FC_LONG */
			0x0,		/* 0 */

	/* Parameter dwPropID */

/* 388 */	NdrFcShort( 0x48 ),	/* Flags:  in, base type, */
/* 390 */	NdrFcShort( 0x10 ),	/* ia64, axp64 Stack size/offset = 16 */
/* 392 */	0x8,		/* FC_LONG */
			0x0,		/* 0 */

	/* Parameter pszValue */

/* 394 */	NdrFcShort( 0xb ),	/* Flags:  must size, must free, in, */
/* 396 */	NdrFcShort( 0x18 ),	/* ia64, axp64 Stack size/offset = 24 */
/* 398 */	NdrFcShort( 0x4e ),	/* Type Offset=78 */

	/* Return value */

/* 400 */	NdrFcShort( 0x70 ),	/* Flags:  out, return, base type, */
/* 402 */	NdrFcShort( 0x20 ),	/* ia64, axp64 Stack size/offset = 32 */
/* 404 */	0x8,		/* FC_LONG */
			0x0,		/* 0 */

	/* Procedure GetStringW */

/* 406 */	0x33,		/* FC_AUTO_HANDLE */
			0x6c,		/* Old Flags:  object, Oi2 */
/* 408 */	NdrFcLong( 0x0 ),	/* 0 */
/* 412 */	NdrFcShort( 0xa ),	/* 10 */
/* 414 */	NdrFcShort( 0x30 ),	/* ia64, axp64 Stack size/offset = 48 */
/* 416 */	NdrFcShort( 0x18 ),	/* 24 */
/* 418 */	NdrFcShort( 0x8 ),	/* 8 */
/* 420 */	0x45,		/* Oi2 Flags:  srv must size, has return, has ext, */
			0x5,		/* 5 */
/* 422 */	0xa,		/* 10 */
			0x3,		/* Ext Flags:  new corr desc, clt corr check, */
/* 424 */	NdrFcShort( 0x1 ),	/* 1 */
/* 426 */	NdrFcShort( 0x0 ),	/* 0 */
/* 428 */	NdrFcShort( 0x0 ),	/* 0 */
/* 430 */	NdrFcShort( 0x0 ),	/* 0 */

	/* Parameter dwIndex */

/* 432 */	NdrFcShort( 0x48 ),	/* Flags:  in, base type, */
/* 434 */	NdrFcShort( 0x8 ),	/* ia64, axp64 Stack size/offset = 8 */
/* 436 */	0x8,		/* FC_LONG */
			0x0,		/* 0 */

	/* Parameter dwPropID */

/* 438 */	NdrFcShort( 0x48 ),	/* Flags:  in, base type, */
/* 440 */	NdrFcShort( 0x10 ),	/* ia64, axp64 Stack size/offset = 16 */
/* 442 */	0x8,		/* FC_LONG */
			0x0,		/* 0 */

	/* Parameter cchLength */

/* 444 */	NdrFcShort( 0x48 ),	/* Flags:  in, base type, */
/* 446 */	NdrFcShort( 0x18 ),	/* ia64, axp64 Stack size/offset = 24 */
/* 448 */	0x8,		/* FC_LONG */
			0x0,		/* 0 */

	/* Parameter pszValue */

/* 450 */	NdrFcShort( 0x113 ),	/* Flags:  must size, must free, out, simple ref, */
/* 452 */	NdrFcShort( 0x20 ),	/* ia64, axp64 Stack size/offset = 32 */
/* 454 */	NdrFcShort( 0x56 ),	/* Type Offset=86 */

	/* Return value */

/* 456 */	NdrFcShort( 0x70 ),	/* Flags:  out, return, base type, */
/* 458 */	NdrFcShort( 0x28 ),	/* ia64, axp64 Stack size/offset = 40 */
/* 460 */	0x8,		/* FC_LONG */
			0x0,		/* 0 */

	/* Procedure PutDWORD */

/* 462 */	0x33,		/* FC_AUTO_HANDLE */
			0x6c,		/* Old Flags:  object, Oi2 */
/* 464 */	NdrFcLong( 0x0 ),	/* 0 */
/* 468 */	NdrFcShort( 0xb ),	/* 11 */
/* 470 */	NdrFcShort( 0x28 ),	/* ia64, axp64 Stack size/offset = 40 */
/* 472 */	NdrFcShort( 0x18 ),	/* 24 */
/* 474 */	NdrFcShort( 0x8 ),	/* 8 */
/* 476 */	0x44,		/* Oi2 Flags:  has return, has ext, */
			0x4,		/* 4 */
/* 478 */	0xa,		/* 10 */
			0x1,		/* Ext Flags:  new corr desc, */
/* 480 */	NdrFcShort( 0x0 ),	/* 0 */
/* 482 */	NdrFcShort( 0x0 ),	/* 0 */
/* 484 */	NdrFcShort( 0x0 ),	/* 0 */
/* 486 */	NdrFcShort( 0x0 ),	/* 0 */

	/* Parameter dwIndex */

/* 488 */	NdrFcShort( 0x48 ),	/* Flags:  in, base type, */
/* 490 */	NdrFcShort( 0x8 ),	/* ia64, axp64 Stack size/offset = 8 */
/* 492 */	0x8,		/* FC_LONG */
			0x0,		/* 0 */

	/* Parameter dwPropID */

/* 494 */	NdrFcShort( 0x48 ),	/* Flags:  in, base type, */
/* 496 */	NdrFcShort( 0x10 ),	/* ia64, axp64 Stack size/offset = 16 */
/* 498 */	0x8,		/* FC_LONG */
			0x0,		/* 0 */

	/* Parameter dwValue */

/* 500 */	NdrFcShort( 0x48 ),	/* Flags:  in, base type, */
/* 502 */	NdrFcShort( 0x18 ),	/* ia64, axp64 Stack size/offset = 24 */
/* 504 */	0x8,		/* FC_LONG */
			0x0,		/* 0 */

	/* Return value */

/* 506 */	NdrFcShort( 0x70 ),	/* Flags:  out, return, base type, */
/* 508 */	NdrFcShort( 0x20 ),	/* ia64, axp64 Stack size/offset = 32 */
/* 510 */	0x8,		/* FC_LONG */
			0x0,		/* 0 */

	/* Procedure GetDWORD */

/* 512 */	0x33,		/* FC_AUTO_HANDLE */
			0x6c,		/* Old Flags:  object, Oi2 */
/* 514 */	NdrFcLong( 0x0 ),	/* 0 */
/* 518 */	NdrFcShort( 0xc ),	/* 12 */
/* 520 */	NdrFcShort( 0x28 ),	/* ia64, axp64 Stack size/offset = 40 */
/* 522 */	NdrFcShort( 0x10 ),	/* 16 */
/* 524 */	NdrFcShort( 0x10 ),	/* 16 */
/* 526 */	0x44,		/* Oi2 Flags:  has return, has ext, */
			0x4,		/* 4 */
/* 528 */	0xa,		/* 10 */
			0x1,		/* Ext Flags:  new corr desc, */
/* 530 */	NdrFcShort( 0x0 ),	/* 0 */
/* 532 */	NdrFcShort( 0x0 ),	/* 0 */
/* 534 */	NdrFcShort( 0x0 ),	/* 0 */
/* 536 */	NdrFcShort( 0x0 ),	/* 0 */

	/* Parameter dwIndex */

/* 538 */	NdrFcShort( 0x48 ),	/* Flags:  in, base type, */
/* 540 */	NdrFcShort( 0x8 ),	/* ia64, axp64 Stack size/offset = 8 */
/* 542 */	0x8,		/* FC_LONG */
			0x0,		/* 0 */

	/* Parameter dwPropID */

/* 544 */	NdrFcShort( 0x48 ),	/* Flags:  in, base type, */
/* 546 */	NdrFcShort( 0x10 ),	/* ia64, axp64 Stack size/offset = 16 */
/* 548 */	0x8,		/* FC_LONG */
			0x0,		/* 0 */

	/* Parameter pdwValue */

/* 550 */	NdrFcShort( 0x2150 ),	/* Flags:  out, base type, simple ref, srv alloc size=8 */
/* 552 */	NdrFcShort( 0x18 ),	/* ia64, axp64 Stack size/offset = 24 */
/* 554 */	0x8,		/* FC_LONG */
			0x0,		/* 0 */

	/* Return value */

/* 556 */	NdrFcShort( 0x70 ),	/* Flags:  out, return, base type, */
/* 558 */	NdrFcShort( 0x20 ),	/* ia64, axp64 Stack size/offset = 32 */
/* 560 */	0x8,		/* FC_LONG */
			0x0,		/* 0 */

	/* Procedure PutBool */

/* 562 */	0x33,		/* FC_AUTO_HANDLE */
			0x6c,		/* Old Flags:  object, Oi2 */
/* 564 */	NdrFcLong( 0x0 ),	/* 0 */
/* 568 */	NdrFcShort( 0xd ),	/* 13 */
/* 570 */	NdrFcShort( 0x28 ),	/* ia64, axp64 Stack size/offset = 40 */
/* 572 */	NdrFcShort( 0x18 ),	/* 24 */
/* 574 */	NdrFcShort( 0x8 ),	/* 8 */
/* 576 */	0x44,		/* Oi2 Flags:  has return, has ext, */
			0x4,		/* 4 */
/* 578 */	0xa,		/* 10 */
			0x1,		/* Ext Flags:  new corr desc, */
/* 580 */	NdrFcShort( 0x0 ),	/* 0 */
/* 582 */	NdrFcShort( 0x0 ),	/* 0 */
/* 584 */	NdrFcShort( 0x0 ),	/* 0 */
/* 586 */	NdrFcShort( 0x0 ),	/* 0 */

	/* Parameter dwIndex */

/* 588 */	NdrFcShort( 0x48 ),	/* Flags:  in, base type, */
/* 590 */	NdrFcShort( 0x8 ),	/* ia64, axp64 Stack size/offset = 8 */
/* 592 */	0x8,		/* FC_LONG */
			0x0,		/* 0 */

	/* Parameter dwPropID */

/* 594 */	NdrFcShort( 0x48 ),	/* Flags:  in, base type, */
/* 596 */	NdrFcShort( 0x10 ),	/* ia64, axp64 Stack size/offset = 16 */
/* 598 */	0x8,		/* FC_LONG */
			0x0,		/* 0 */

	/* Parameter dwValue */

/* 600 */	NdrFcShort( 0x48 ),	/* Flags:  in, base type, */
/* 602 */	NdrFcShort( 0x18 ),	/* ia64, axp64 Stack size/offset = 24 */
/* 604 */	0x8,		/* FC_LONG */
			0x0,		/* 0 */

	/* Return value */

/* 606 */	NdrFcShort( 0x70 ),	/* Flags:  out, return, base type, */
/* 608 */	NdrFcShort( 0x20 ),	/* ia64, axp64 Stack size/offset = 32 */
/* 610 */	0x8,		/* FC_LONG */
			0x0,		/* 0 */

	/* Procedure GetBool */

/* 612 */	0x33,		/* FC_AUTO_HANDLE */
			0x6c,		/* Old Flags:  object, Oi2 */
/* 614 */	NdrFcLong( 0x0 ),	/* 0 */
/* 618 */	NdrFcShort( 0xe ),	/* 14 */
/* 620 */	NdrFcShort( 0x28 ),	/* ia64, axp64 Stack size/offset = 40 */
/* 622 */	NdrFcShort( 0x10 ),	/* 16 */
/* 624 */	NdrFcShort( 0x10 ),	/* 16 */
/* 626 */	0x44,		/* Oi2 Flags:  has return, has ext, */
			0x4,		/* 4 */
/* 628 */	0xa,		/* 10 */
			0x1,		/* Ext Flags:  new corr desc, */
/* 630 */	NdrFcShort( 0x0 ),	/* 0 */
/* 632 */	NdrFcShort( 0x0 ),	/* 0 */
/* 634 */	NdrFcShort( 0x0 ),	/* 0 */
/* 636 */	NdrFcShort( 0x0 ),	/* 0 */

	/* Parameter dwIndex */

/* 638 */	NdrFcShort( 0x48 ),	/* Flags:  in, base type, */
/* 640 */	NdrFcShort( 0x8 ),	/* ia64, axp64 Stack size/offset = 8 */
/* 642 */	0x8,		/* FC_LONG */
			0x0,		/* 0 */

	/* Parameter dwPropID */

/* 644 */	NdrFcShort( 0x48 ),	/* Flags:  in, base type, */
/* 646 */	NdrFcShort( 0x10 ),	/* ia64, axp64 Stack size/offset = 16 */
/* 648 */	0x8,		/* FC_LONG */
			0x0,		/* 0 */

	/* Parameter pdwValue */

/* 650 */	NdrFcShort( 0x2150 ),	/* Flags:  out, base type, simple ref, srv alloc size=8 */
/* 652 */	NdrFcShort( 0x18 ),	/* ia64, axp64 Stack size/offset = 24 */
/* 654 */	0x8,		/* FC_LONG */
			0x0,		/* 0 */

	/* Return value */

/* 656 */	NdrFcShort( 0x70 ),	/* Flags:  out, return, base type, */
/* 658 */	NdrFcShort( 0x20 ),	/* ia64, axp64 Stack size/offset = 32 */
/* 660 */	0x8,		/* FC_LONG */
			0x0,		/* 0 */

	/* Procedure Commit */

/* 662 */	0x33,		/* FC_AUTO_HANDLE */
			0x6c,		/* Old Flags:  object, Oi2 */
/* 664 */	NdrFcLong( 0x0 ),	/* 0 */
/* 668 */	NdrFcShort( 0xf ),	/* 15 */
/* 670 */	NdrFcShort( 0x20 ),	/* ia64, axp64 Stack size/offset = 32 */
/* 672 */	NdrFcShort( 0x8 ),	/* 8 */
/* 674 */	NdrFcShort( 0x8 ),	/* 8 */
/* 676 */	0x46,		/* Oi2 Flags:  clt must size, has return, has ext, */
			0x3,		/* 3 */
/* 678 */	0xa,		/* 10 */
			0x1,		/* Ext Flags:  new corr desc, */
/* 680 */	NdrFcShort( 0x0 ),	/* 0 */
/* 682 */	NdrFcShort( 0x0 ),	/* 0 */
/* 684 */	NdrFcShort( 0x0 ),	/* 0 */
/* 686 */	NdrFcShort( 0x0 ),	/* 0 */

	/* Parameter dwIndex */

/* 688 */	NdrFcShort( 0x48 ),	/* Flags:  in, base type, */
/* 690 */	NdrFcShort( 0x8 ),	/* ia64, axp64 Stack size/offset = 8 */
/* 692 */	0x8,		/* FC_LONG */
			0x0,		/* 0 */

	/* Parameter pNotify */

/* 694 */	NdrFcShort( 0xb ),	/* Flags:  must size, must free, in, */
/* 696 */	NdrFcShort( 0x10 ),	/* ia64, axp64 Stack size/offset = 16 */
/* 698 */	NdrFcShort( 0x5e ),	/* Type Offset=94 */

	/* Return value */

/* 700 */	NdrFcShort( 0x70 ),	/* Flags:  out, return, base type, */
/* 702 */	NdrFcShort( 0x18 ),	/* ia64, axp64 Stack size/offset = 24 */
/* 704 */	0x8,		/* FC_LONG */
			0x0,		/* 0 */

	/* Procedure DomainCount */

/* 706 */	0x33,		/* FC_AUTO_HANDLE */
			0x6c,		/* Old Flags:  object, Oi2 */
/* 708 */	NdrFcLong( 0x0 ),	/* 0 */
/* 712 */	NdrFcShort( 0x10 ),	/* 16 */
/* 714 */	NdrFcShort( 0x18 ),	/* ia64, axp64 Stack size/offset = 24 */
/* 716 */	NdrFcShort( 0x0 ),	/* 0 */
/* 718 */	NdrFcShort( 0x10 ),	/* 16 */
/* 720 */	0x44,		/* Oi2 Flags:  has return, has ext, */
			0x2,		/* 2 */
/* 722 */	0xa,		/* 10 */
			0x1,		/* Ext Flags:  new corr desc, */
/* 724 */	NdrFcShort( 0x0 ),	/* 0 */
/* 726 */	NdrFcShort( 0x0 ),	/* 0 */
/* 728 */	NdrFcShort( 0x0 ),	/* 0 */
/* 730 */	NdrFcShort( 0x0 ),	/* 0 */

	/* Parameter pdwCount */

/* 732 */	NdrFcShort( 0x2150 ),	/* Flags:  out, base type, simple ref, srv alloc size=8 */
/* 734 */	NdrFcShort( 0x8 ),	/* ia64, axp64 Stack size/offset = 8 */
/* 736 */	0x8,		/* FC_LONG */
			0x0,		/* 0 */

	/* Return value */

/* 738 */	NdrFcShort( 0x70 ),	/* Flags:  out, return, base type, */
/* 740 */	NdrFcShort( 0x10 ),	/* ia64, axp64 Stack size/offset = 16 */
/* 742 */	0x8,		/* FC_LONG */
			0x0,		/* 0 */

	/* Procedure DomainItem */

/* 744 */	0x33,		/* FC_AUTO_HANDLE */
			0x6c,		/* Old Flags:  object, Oi2 */
/* 746 */	NdrFcLong( 0x0 ),	/* 0 */
/* 750 */	NdrFcShort( 0x11 ),	/* 17 */
/* 752 */	NdrFcShort( 0x38 ),	/* ia64, axp64 Stack size/offset = 56 */
/* 754 */	NdrFcShort( 0x10 ),	/* 16 */
/* 756 */	NdrFcShort( 0x18 ),	/* 24 */
/* 758 */	0x45,		/* Oi2 Flags:  srv must size, has return, has ext, */
			0x6,		/* 6 */
/* 760 */	0xa,		/* 10 */
			0x3,		/* Ext Flags:  new corr desc, clt corr check, */
/* 762 */	NdrFcShort( 0x1 ),	/* 1 */
/* 764 */	NdrFcShort( 0x0 ),	/* 0 */
/* 766 */	NdrFcShort( 0x0 ),	/* 0 */
/* 768 */	NdrFcShort( 0x0 ),	/* 0 */

	/* Parameter dwIndex */

/* 770 */	NdrFcShort( 0x48 ),	/* Flags:  in, base type, */
/* 772 */	NdrFcShort( 0x8 ),	/* ia64, axp64 Stack size/offset = 8 */
/* 774 */	0x8,		/* FC_LONG */
			0x0,		/* 0 */

	/* Parameter cchLength */

/* 776 */	NdrFcShort( 0x48 ),	/* Flags:  in, base type, */
/* 778 */	NdrFcShort( 0x10 ),	/* ia64, axp64 Stack size/offset = 16 */
/* 780 */	0x8,		/* FC_LONG */
			0x0,		/* 0 */

	/* Parameter pszDomain */

/* 782 */	NdrFcShort( 0x113 ),	/* Flags:  must size, must free, out, simple ref, */
/* 784 */	NdrFcShort( 0x18 ),	/* ia64, axp64 Stack size/offset = 24 */
/* 786 */	NdrFcShort( 0x74 ),	/* Type Offset=116 */

	/* Parameter pdwRecipientIndex */

/* 788 */	NdrFcShort( 0x2150 ),	/* Flags:  out, base type, simple ref, srv alloc size=8 */
/* 790 */	NdrFcShort( 0x20 ),	/* ia64, axp64 Stack size/offset = 32 */
/* 792 */	0x8,		/* FC_LONG */
			0x0,		/* 0 */

	/* Parameter pdwRecipientCount */

/* 794 */	NdrFcShort( 0x2150 ),	/* Flags:  out, base type, simple ref, srv alloc size=8 */
/* 796 */	NdrFcShort( 0x28 ),	/* ia64, axp64 Stack size/offset = 40 */
/* 798 */	0x8,		/* FC_LONG */
			0x0,		/* 0 */

	/* Return value */

/* 800 */	NdrFcShort( 0x70 ),	/* Flags:  out, return, base type, */
/* 802 */	NdrFcShort( 0x30 ),	/* ia64, axp64 Stack size/offset = 48 */
/* 804 */	0x8,		/* FC_LONG */
			0x0,		/* 0 */

	/* Procedure AllocNewList */

/* 806 */	0x33,		/* FC_AUTO_HANDLE */
			0x6c,		/* Old Flags:  object, Oi2 */
/* 808 */	NdrFcLong( 0x0 ),	/* 0 */
/* 812 */	NdrFcShort( 0x12 ),	/* 18 */
/* 814 */	NdrFcShort( 0x18 ),	/* ia64, axp64 Stack size/offset = 24 */
/* 816 */	NdrFcShort( 0x0 ),	/* 0 */
/* 818 */	NdrFcShort( 0x8 ),	/* 8 */
/* 820 */	0x45,		/* Oi2 Flags:  srv must size, has return, has ext, */
			0x2,		/* 2 */
/* 822 */	0xa,		/* 10 */
			0x1,		/* Ext Flags:  new corr desc, */
/* 824 */	NdrFcShort( 0x0 ),	/* 0 */
/* 826 */	NdrFcShort( 0x0 ),	/* 0 */
/* 828 */	NdrFcShort( 0x0 ),	/* 0 */
/* 830 */	NdrFcShort( 0x0 ),	/* 0 */

	/* Parameter ppNewList */

/* 832 */	NdrFcShort( 0x13 ),	/* Flags:  must size, must free, out, */
/* 834 */	NdrFcShort( 0x8 ),	/* ia64, axp64 Stack size/offset = 8 */
/* 836 */	NdrFcShort( 0x7c ),	/* Type Offset=124 */

	/* Return value */

/* 838 */	NdrFcShort( 0x70 ),	/* Flags:  out, return, base type, */
/* 840 */	NdrFcShort( 0x10 ),	/* ia64, axp64 Stack size/offset = 16 */
/* 842 */	0x8,		/* FC_LONG */
			0x0,		/* 0 */

	/* Procedure WriteList */

/* 844 */	0x33,		/* FC_AUTO_HANDLE */
			0x6c,		/* Old Flags:  object, Oi2 */
/* 846 */	NdrFcLong( 0x0 ),	/* 0 */
/* 850 */	NdrFcShort( 0x13 ),	/* 19 */
/* 852 */	NdrFcShort( 0x18 ),	/* ia64, axp64 Stack size/offset = 24 */
/* 854 */	NdrFcShort( 0x0 ),	/* 0 */
/* 856 */	NdrFcShort( 0x8 ),	/* 8 */
/* 858 */	0x46,		/* Oi2 Flags:  clt must size, has return, has ext, */
			0x2,		/* 2 */
/* 860 */	0xa,		/* 10 */
			0x1,		/* Ext Flags:  new corr desc, */
/* 862 */	NdrFcShort( 0x0 ),	/* 0 */
/* 864 */	NdrFcShort( 0x0 ),	/* 0 */
/* 866 */	NdrFcShort( 0x0 ),	/* 0 */
/* 868 */	NdrFcShort( 0x0 ),	/* 0 */

	/* Parameter pNewList */

/* 870 */	NdrFcShort( 0xb ),	/* Flags:  must size, must free, in, */
/* 872 */	NdrFcShort( 0x8 ),	/* ia64, axp64 Stack size/offset = 8 */
/* 874 */	NdrFcShort( 0x80 ),	/* Type Offset=128 */

	/* Return value */

/* 876 */	NdrFcShort( 0x70 ),	/* Flags:  out, return, base type, */
/* 878 */	NdrFcShort( 0x10 ),	/* ia64, axp64 Stack size/offset = 16 */
/* 880 */	0x8,		/* FC_LONG */
			0x0,		/* 0 */

	/* Procedure SetNextDomain */

/* 882 */	0x33,		/* FC_AUTO_HANDLE */
			0x6c,		/* Old Flags:  object, Oi2 */
/* 884 */	NdrFcLong( 0x0 ),	/* 0 */
/* 888 */	NdrFcShort( 0x14 ),	/* 20 */
/* 890 */	NdrFcShort( 0x28 ),	/* ia64, axp64 Stack size/offset = 40 */
/* 892 */	NdrFcShort( 0x18 ),	/* 24 */
/* 894 */	NdrFcShort( 0x8 ),	/* 8 */
/* 896 */	0x44,		/* Oi2 Flags:  has return, has ext, */
			0x4,		/* 4 */
/* 898 */	0xa,		/* 10 */
			0x1,		/* Ext Flags:  new corr desc, */
/* 900 */	NdrFcShort( 0x0 ),	/* 0 */
/* 902 */	NdrFcShort( 0x0 ),	/* 0 */
/* 904 */	NdrFcShort( 0x0 ),	/* 0 */
/* 906 */	NdrFcShort( 0x0 ),	/* 0 */

	/* Parameter dwDomainIndex */

/* 908 */	NdrFcShort( 0x48 ),	/* Flags:  in, base type, */
/* 910 */	NdrFcShort( 0x8 ),	/* ia64, axp64 Stack size/offset = 8 */
/* 912 */	0x8,		/* FC_LONG */
			0x0,		/* 0 */

	/* Parameter dwNextDomainIndex */

/* 914 */	NdrFcShort( 0x48 ),	/* Flags:  in, base type, */
/* 916 */	NdrFcShort( 0x10 ),	/* ia64, axp64 Stack size/offset = 16 */
/* 918 */	0x8,		/* FC_LONG */
			0x0,		/* 0 */

	/* Parameter dwFlags */

/* 920 */	NdrFcShort( 0x48 ),	/* Flags:  in, base type, */
/* 922 */	NdrFcShort( 0x18 ),	/* ia64, axp64 Stack size/offset = 24 */
/* 924 */	0x8,		/* FC_LONG */
			0x0,		/* 0 */

	/* Return value */

/* 926 */	NdrFcShort( 0x70 ),	/* Flags:  out, return, base type, */
/* 928 */	NdrFcShort( 0x20 ),	/* ia64, axp64 Stack size/offset = 32 */
/* 930 */	0x8,		/* FC_LONG */
			0x0,		/* 0 */

	/* Procedure InitializeRecipientFilterContext */

/* 932 */	0x33,		/* FC_AUTO_HANDLE */
			0x6c,		/* Old Flags:  object, Oi2 */
/* 934 */	NdrFcLong( 0x0 ),	/* 0 */
/* 938 */	NdrFcShort( 0x15 ),	/* 21 */
/* 940 */	NdrFcShort( 0x30 ),	/* ia64, axp64 Stack size/offset = 48 */
/* 942 */	NdrFcShort( 0x40 ),	/* 64 */
/* 944 */	NdrFcShort( 0x8 ),	/* 8 */
/* 946 */	0x44,		/* Oi2 Flags:  has return, has ext, */
			0x5,		/* 5 */
/* 948 */	0xa,		/* 10 */
			0x1,		/* Ext Flags:  new corr desc, */
/* 950 */	NdrFcShort( 0x0 ),	/* 0 */
/* 952 */	NdrFcShort( 0x0 ),	/* 0 */
/* 954 */	NdrFcShort( 0x0 ),	/* 0 */
/* 956 */	NdrFcShort( 0x0 ),	/* 0 */

	/* Parameter pContext */

/* 958 */	NdrFcShort( 0xa ),	/* Flags:  must free, in, */
/* 960 */	NdrFcShort( 0x8 ),	/* ia64, axp64 Stack size/offset = 8 */
/* 962 */	NdrFcShort( 0x92 ),	/* Type Offset=146 */

	/* Parameter dwStartingDomain */

/* 964 */	NdrFcShort( 0x48 ),	/* Flags:  in, base type, */
/* 966 */	NdrFcShort( 0x10 ),	/* ia64, axp64 Stack size/offset = 16 */
/* 968 */	0x8,		/* FC_LONG */
			0x0,		/* 0 */

	/* Parameter dwFilterFlags */

/* 970 */	NdrFcShort( 0x48 ),	/* Flags:  in, base type, */
/* 972 */	NdrFcShort( 0x18 ),	/* ia64, axp64 Stack size/offset = 24 */
/* 974 */	0x8,		/* FC_LONG */
			0x0,		/* 0 */

	/* Parameter dwFilterMask */

/* 976 */	NdrFcShort( 0x48 ),	/* Flags:  in, base type, */
/* 978 */	NdrFcShort( 0x20 ),	/* ia64, axp64 Stack size/offset = 32 */
/* 980 */	0x8,		/* FC_LONG */
			0x0,		/* 0 */

	/* Return value */

/* 982 */	NdrFcShort( 0x70 ),	/* Flags:  out, return, base type, */
/* 984 */	NdrFcShort( 0x28 ),	/* ia64, axp64 Stack size/offset = 40 */
/* 986 */	0x8,		/* FC_LONG */
			0x0,		/* 0 */

	/* Procedure TerminateRecipientFilterContext */

/* 988 */	0x33,		/* FC_AUTO_HANDLE */
			0x6c,		/* Old Flags:  object, Oi2 */
/* 990 */	NdrFcLong( 0x0 ),	/* 0 */
/* 994 */	NdrFcShort( 0x16 ),	/* 22 */
/* 996 */	NdrFcShort( 0x18 ),	/* ia64, axp64 Stack size/offset = 24 */
/* 998 */	NdrFcShort( 0x28 ),	/* 40 */
/* 1000 */	NdrFcShort( 0x8 ),	/* 8 */
/* 1002 */	0x44,		/* Oi2 Flags:  has return, has ext, */
			0x2,		/* 2 */
/* 1004 */	0xa,		/* 10 */
			0x1,		/* Ext Flags:  new corr desc, */
/* 1006 */	NdrFcShort( 0x0 ),	/* 0 */
/* 1008 */	NdrFcShort( 0x0 ),	/* 0 */
/* 1010 */	NdrFcShort( 0x0 ),	/* 0 */
/* 1012 */	NdrFcShort( 0x0 ),	/* 0 */

	/* Parameter pContext */

/* 1014 */	NdrFcShort( 0xa ),	/* Flags:  must free, in, */
/* 1016 */	NdrFcShort( 0x8 ),	/* ia64, axp64 Stack size/offset = 8 */
/* 1018 */	NdrFcShort( 0x92 ),	/* Type Offset=146 */

	/* Return value */

/* 1020 */	NdrFcShort( 0x70 ),	/* Flags:  out, return, base type, */
/* 1022 */	NdrFcShort( 0x10 ),	/* ia64, axp64 Stack size/offset = 16 */
/* 1024 */	0x8,		/* FC_LONG */
			0x0,		/* 0 */

	/* Procedure GetNextRecipient */

/* 1026 */	0x33,		/* FC_AUTO_HANDLE */
			0x6c,		/* Old Flags:  object, Oi2 */
/* 1028 */	NdrFcLong( 0x0 ),	/* 0 */
/* 1032 */	NdrFcShort( 0x17 ),	/* 23 */
/* 1034 */	NdrFcShort( 0x20 ),	/* ia64, axp64 Stack size/offset = 32 */
/* 1036 */	NdrFcShort( 0x28 ),	/* 40 */
/* 1038 */	NdrFcShort( 0x10 ),	/* 16 */
/* 1040 */	0x44,		/* Oi2 Flags:  has return, has ext, */
			0x3,		/* 3 */
/* 1042 */	0xa,		/* 10 */
			0x1,		/* Ext Flags:  new corr desc, */
/* 1044 */	NdrFcShort( 0x0 ),	/* 0 */
/* 1046 */	NdrFcShort( 0x0 ),	/* 0 */
/* 1048 */	NdrFcShort( 0x0 ),	/* 0 */
/* 1050 */	NdrFcShort( 0x0 ),	/* 0 */

	/* Parameter pContext */

/* 1052 */	NdrFcShort( 0xa ),	/* Flags:  must free, in, */
/* 1054 */	NdrFcShort( 0x8 ),	/* ia64, axp64 Stack size/offset = 8 */
/* 1056 */	NdrFcShort( 0x92 ),	/* Type Offset=146 */

	/* Parameter pdwRecipientIndex */

/* 1058 */	NdrFcShort( 0x2150 ),	/* Flags:  out, base type, simple ref, srv alloc size=8 */
/* 1060 */	NdrFcShort( 0x10 ),	/* ia64, axp64 Stack size/offset = 16 */
/* 1062 */	0x8,		/* FC_LONG */
			0x0,		/* 0 */

	/* Return value */

/* 1064 */	NdrFcShort( 0x70 ),	/* Flags:  out, return, base type, */
/* 1066 */	NdrFcShort( 0x18 ),	/* ia64, axp64 Stack size/offset = 24 */
/* 1068 */	0x8,		/* FC_LONG */
			0x0,		/* 0 */

	/* Procedure AllocPropIDRange */

/* 1070 */	0x33,		/* FC_AUTO_HANDLE */
			0x6c,		/* Old Flags:  object, Oi2 */
/* 1072 */	NdrFcLong( 0x0 ),	/* 0 */
/* 1076 */	NdrFcShort( 0x3 ),	/* 3 */
/* 1078 */	NdrFcShort( 0x28 ),	/* ia64, axp64 Stack size/offset = 40 */
/* 1080 */	NdrFcShort( 0x28 ),	/* 40 */
/* 1082 */	NdrFcShort( 0x10 ),	/* 16 */
/* 1084 */	0x44,		/* Oi2 Flags:  has return, has ext, */
			0x4,		/* 4 */
/* 1086 */	0xa,		/* 10 */
			0x1,		/* Ext Flags:  new corr desc, */
/* 1088 */	NdrFcShort( 0x0 ),	/* 0 */
/* 1090 */	NdrFcShort( 0x0 ),	/* 0 */
/* 1092 */	NdrFcShort( 0x0 ),	/* 0 */
/* 1094 */	NdrFcShort( 0x0 ),	/* 0 */

	/* Parameter rguid */

/* 1096 */	NdrFcShort( 0x10a ),	/* Flags:  must free, in, simple ref, */
/* 1098 */	NdrFcShort( 0x8 ),	/* ia64, axp64 Stack size/offset = 8 */
/* 1100 */	NdrFcShort( 0xac ),	/* Type Offset=172 */

	/* Parameter cCount */

/* 1102 */	NdrFcShort( 0x48 ),	/* Flags:  in, base type, */
/* 1104 */	NdrFcShort( 0x10 ),	/* ia64, axp64 Stack size/offset = 16 */
/* 1106 */	0x8,		/* FC_LONG */
			0x0,		/* 0 */

	/* Parameter pdwStart */

/* 1108 */	NdrFcShort( 0x2150 ),	/* Flags:  out, base type, simple ref, srv alloc size=8 */
/* 1110 */	NdrFcShort( 0x18 ),	/* ia64, axp64 Stack size/offset = 24 */
/* 1112 */	0x8,		/* FC_LONG */
			0x0,		/* 0 */

	/* Return value */

/* 1114 */	NdrFcShort( 0x70 ),	/* Flags:  out, return, base type, */
/* 1116 */	NdrFcShort( 0x20 ),	/* ia64, axp64 Stack size/offset = 32 */
/* 1118 */	0x8,		/* FC_LONG */
			0x0,		/* 0 */

	/* Procedure AddUsage */

/* 1120 */	0x33,		/* FC_AUTO_HANDLE */
			0x6c,		/* Old Flags:  object, Oi2 */
/* 1122 */	NdrFcLong( 0x0 ),	/* 0 */
/* 1126 */	NdrFcShort( 0x3 ),	/* 3 */
/* 1128 */	NdrFcShort( 0x10 ),	/* ia64, axp64 Stack size/offset = 16 */
/* 1130 */	NdrFcShort( 0x0 ),	/* 0 */
/* 1132 */	NdrFcShort( 0x8 ),	/* 8 */
/* 1134 */	0x44,		/* Oi2 Flags:  has return, has ext, */
			0x1,		/* 1 */
/* 1136 */	0xa,		/* 10 */
			0x1,		/* Ext Flags:  new corr desc, */
/* 1138 */	NdrFcShort( 0x0 ),	/* 0 */
/* 1140 */	NdrFcShort( 0x0 ),	/* 0 */
/* 1142 */	NdrFcShort( 0x0 ),	/* 0 */
/* 1144 */	NdrFcShort( 0x0 ),	/* 0 */

	/* Return value */

/* 1146 */	NdrFcShort( 0x70 ),	/* Flags:  out, return, base type, */
/* 1148 */	NdrFcShort( 0x8 ),	/* ia64, axp64 Stack size/offset = 8 */
/* 1150 */	0x8,		/* FC_LONG */
			0x0,		/* 0 */

	/* Procedure ReleaseUsage */

/* 1152 */	0x33,		/* FC_AUTO_HANDLE */
			0x6c,		/* Old Flags:  object, Oi2 */
/* 1154 */	NdrFcLong( 0x0 ),	/* 0 */
/* 1158 */	NdrFcShort( 0x4 ),	/* 4 */
/* 1160 */	NdrFcShort( 0x10 ),	/* ia64, axp64 Stack size/offset = 16 */
/* 1162 */	NdrFcShort( 0x0 ),	/* 0 */
/* 1164 */	NdrFcShort( 0x8 ),	/* 8 */
/* 1166 */	0x44,		/* Oi2 Flags:  has return, has ext, */
			0x1,		/* 1 */
/* 1168 */	0xa,		/* 10 */
			0x1,		/* Ext Flags:  new corr desc, */
/* 1170 */	NdrFcShort( 0x0 ),	/* 0 */
/* 1172 */	NdrFcShort( 0x0 ),	/* 0 */
/* 1174 */	NdrFcShort( 0x0 ),	/* 0 */
/* 1176 */	NdrFcShort( 0x0 ),	/* 0 */

	/* Return value */

/* 1178 */	NdrFcShort( 0x70 ),	/* Flags:  out, return, base type, */
/* 1180 */	NdrFcShort( 0x8 ),	/* ia64, axp64 Stack size/offset = 8 */
/* 1182 */	0x8,		/* FC_LONG */
			0x0,		/* 0 */

	/* Procedure SetRecipientCount */

/* 1184 */	0x33,		/* FC_AUTO_HANDLE */
			0x6c,		/* Old Flags:  object, Oi2 */
/* 1186 */	NdrFcLong( 0x0 ),	/* 0 */
/* 1190 */	NdrFcShort( 0x5 ),	/* 5 */
/* 1192 */	NdrFcShort( 0x18 ),	/* ia64, axp64 Stack size/offset = 24 */
/* 1194 */	NdrFcShort( 0x8 ),	/* 8 */
/* 1196 */	NdrFcShort( 0x8 ),	/* 8 */
/* 1198 */	0x44,		/* Oi2 Flags:  has return, has ext, */
			0x2,		/* 2 */
/* 1200 */	0xa,		/* 10 */
			0x1,		/* Ext Flags:  new corr desc, */
/* 1202 */	NdrFcShort( 0x0 ),	/* 0 */
/* 1204 */	NdrFcShort( 0x0 ),	/* 0 */
/* 1206 */	NdrFcShort( 0x0 ),	/* 0 */
/* 1208 */	NdrFcShort( 0x0 ),	/* 0 */

	/* Parameter dwCount */

/* 1210 */	NdrFcShort( 0x48 ),	/* Flags:  in, base type, */
/* 1212 */	NdrFcShort( 0x8 ),	/* ia64, axp64 Stack size/offset = 8 */
/* 1214 */	0x8,		/* FC_LONG */
			0x0,		/* 0 */

	/* Return value */

/* 1216 */	NdrFcShort( 0x70 ),	/* Flags:  out, return, base type, */
/* 1218 */	NdrFcShort( 0x10 ),	/* ia64, axp64 Stack size/offset = 16 */
/* 1220 */	0x8,		/* FC_LONG */
			0x0,		/* 0 */

	/* Procedure GetRecipientCount */

/* 1222 */	0x33,		/* FC_AUTO_HANDLE */
			0x6c,		/* Old Flags:  object, Oi2 */
/* 1224 */	NdrFcLong( 0x0 ),	/* 0 */
/* 1228 */	NdrFcShort( 0x6 ),	/* 6 */
/* 1230 */	NdrFcShort( 0x18 ),	/* ia64, axp64 Stack size/offset = 24 */
/* 1232 */	NdrFcShort( 0x0 ),	/* 0 */
/* 1234 */	NdrFcShort( 0x10 ),	/* 16 */
/* 1236 */	0x44,		/* Oi2 Flags:  has return, has ext, */
			0x2,		/* 2 */
/* 1238 */	0xa,		/* 10 */
			0x1,		/* Ext Flags:  new corr desc, */
/* 1240 */	NdrFcShort( 0x0 ),	/* 0 */
/* 1242 */	NdrFcShort( 0x0 ),	/* 0 */
/* 1244 */	NdrFcShort( 0x0 ),	/* 0 */
/* 1246 */	NdrFcShort( 0x0 ),	/* 0 */

	/* Parameter pdwCount */

/* 1248 */	NdrFcShort( 0x2150 ),	/* Flags:  out, base type, simple ref, srv alloc size=8 */
/* 1250 */	NdrFcShort( 0x8 ),	/* ia64, axp64 Stack size/offset = 8 */
/* 1252 */	0x8,		/* FC_LONG */
			0x0,		/* 0 */

	/* Return value */

/* 1254 */	NdrFcShort( 0x70 ),	/* Flags:  out, return, base type, */
/* 1256 */	NdrFcShort( 0x10 ),	/* ia64, axp64 Stack size/offset = 16 */
/* 1258 */	0x8,		/* FC_LONG */
			0x0,		/* 0 */

	/* Procedure DecrementRecipientCount */

/* 1260 */	0x33,		/* FC_AUTO_HANDLE */
			0x6c,		/* Old Flags:  object, Oi2 */
/* 1262 */	NdrFcLong( 0x0 ),	/* 0 */
/* 1266 */	NdrFcShort( 0x7 ),	/* 7 */
/* 1268 */	NdrFcShort( 0x18 ),	/* ia64, axp64 Stack size/offset = 24 */
/* 1270 */	NdrFcShort( 0x8 ),	/* 8 */
/* 1272 */	NdrFcShort( 0x8 ),	/* 8 */
/* 1274 */	0x44,		/* Oi2 Flags:  has return, has ext, */
			0x2,		/* 2 */
/* 1276 */	0xa,		/* 10 */
			0x1,		/* Ext Flags:  new corr desc, */
/* 1278 */	NdrFcShort( 0x0 ),	/* 0 */
/* 1280 */	NdrFcShort( 0x0 ),	/* 0 */
/* 1282 */	NdrFcShort( 0x0 ),	/* 0 */
/* 1284 */	NdrFcShort( 0x0 ),	/* 0 */

	/* Parameter dwDecrement */

/* 1286 */	NdrFcShort( 0x48 ),	/* Flags:  in, base type, */
/* 1288 */	NdrFcShort( 0x8 ),	/* ia64, axp64 Stack size/offset = 8 */
/* 1290 */	0x8,		/* FC_LONG */
			0x0,		/* 0 */

	/* Return value */

/* 1292 */	NdrFcShort( 0x70 ),	/* Flags:  out, return, base type, */
/* 1294 */	NdrFcShort( 0x10 ),	/* ia64, axp64 Stack size/offset = 16 */
/* 1296 */	0x8,		/* FC_LONG */
			0x0,		/* 0 */

	/* Procedure IncrementRecipientCount */

/* 1298 */	0x33,		/* FC_AUTO_HANDLE */
			0x6c,		/* Old Flags:  object, Oi2 */
/* 1300 */	NdrFcLong( 0x0 ),	/* 0 */
/* 1304 */	NdrFcShort( 0x8 ),	/* 8 */
/* 1306 */	NdrFcShort( 0x18 ),	/* ia64, axp64 Stack size/offset = 24 */
/* 1308 */	NdrFcShort( 0x8 ),	/* 8 */
/* 1310 */	NdrFcShort( 0x8 ),	/* 8 */
/* 1312 */	0x44,		/* Oi2 Flags:  has return, has ext, */
			0x2,		/* 2 */
/* 1314 */	0xa,		/* 10 */
			0x1,		/* Ext Flags:  new corr desc, */
/* 1316 */	NdrFcShort( 0x0 ),	/* 0 */
/* 1318 */	NdrFcShort( 0x0 ),	/* 0 */
/* 1320 */	NdrFcShort( 0x0 ),	/* 0 */
/* 1322 */	NdrFcShort( 0x0 ),	/* 0 */

	/* Parameter dwIncrement */

/* 1324 */	NdrFcShort( 0x48 ),	/* Flags:  in, base type, */
/* 1326 */	NdrFcShort( 0x8 ),	/* ia64, axp64 Stack size/offset = 8 */
/* 1328 */	0x8,		/* FC_LONG */
			0x0,		/* 0 */

	/* Return value */

/* 1330 */	NdrFcShort( 0x70 ),	/* Flags:  out, return, base type, */
/* 1332 */	NdrFcShort( 0x10 ),	/* ia64, axp64 Stack size/offset = 16 */
/* 1334 */	0x8,		/* FC_LONG */
			0x0,		/* 0 */

	/* Procedure Delete */

/* 1336 */	0x33,		/* FC_AUTO_HANDLE */
			0x6c,		/* Old Flags:  object, Oi2 */
/* 1338 */	NdrFcLong( 0x0 ),	/* 0 */
/* 1342 */	NdrFcShort( 0x9 ),	/* 9 */
/* 1344 */	NdrFcShort( 0x18 ),	/* ia64, axp64 Stack size/offset = 24 */
/* 1346 */	NdrFcShort( 0x0 ),	/* 0 */
/* 1348 */	NdrFcShort( 0x8 ),	/* 8 */
/* 1350 */	0x46,		/* Oi2 Flags:  clt must size, has return, has ext, */
			0x2,		/* 2 */
/* 1352 */	0xa,		/* 10 */
			0x1,		/* Ext Flags:  new corr desc, */
/* 1354 */	NdrFcShort( 0x0 ),	/* 0 */
/* 1356 */	NdrFcShort( 0x0 ),	/* 0 */
/* 1358 */	NdrFcShort( 0x0 ),	/* 0 */
/* 1360 */	NdrFcShort( 0x0 ),	/* 0 */

	/* Parameter pNotify */

/* 1362 */	NdrFcShort( 0xb ),	/* Flags:  must size, must free, in, */
/* 1364 */	NdrFcShort( 0x8 ),	/* ia64, axp64 Stack size/offset = 8 */
/* 1366 */	NdrFcShort( 0x5e ),	/* Type Offset=94 */

	/* Return value */

/* 1368 */	NdrFcShort( 0x70 ),	/* Flags:  out, return, base type, */
/* 1370 */	NdrFcShort( 0x10 ),	/* ia64, axp64 Stack size/offset = 16 */
/* 1372 */	0x8,		/* FC_LONG */
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
			0x11, 0xc,	/* FC_RP [alloced_on_stack] [simple_pointer] */
/*  4 */	0x8,		/* FC_LONG */
			0x5c,		/* FC_PAD */
/*  6 */	
			0x11, 0x0,	/* FC_RP */
/*  8 */	NdrFcShort( 0x2 ),	/* Offset= 2 (10) */
/* 10 */	
			0x22,		/* FC_C_CSTRING */
			0x44,		/* FC_STRING_SIZED */
/* 12 */	0x29,		/* Corr desc:  parameter, FC_ULONG */
			0x0,		/*  */
/* 14 */	NdrFcShort( 0x18 ),	/* ia64, axp64 Stack size/offset = 24 */
/* 16 */	NdrFcShort( 0x1 ),	/* Corr flags:  early, */
/* 18 */	
			0x12, 0x0,	/* FC_UP */
/* 20 */	NdrFcShort( 0x2 ),	/* Offset= 2 (22) */
/* 22 */	
			0x1c,		/* FC_CVARRAY */
			0x0,		/* 0 */
/* 24 */	NdrFcShort( 0x1 ),	/* 1 */
/* 26 */	0x29,		/* Corr desc:  parameter, FC_ULONG */
			0x0,		/*  */
/* 28 */	NdrFcShort( 0x18 ),	/* ia64, axp64 Stack size/offset = 24 */
/* 30 */	NdrFcShort( 0x1 ),	/* Corr flags:  early, */
/* 32 */	0x29,		/* Corr desc:  parameter, FC_ULONG */
			0x0,		/*  */
/* 34 */	NdrFcShort( 0x18 ),	/* ia64, axp64 Stack size/offset = 24 */
/* 36 */	NdrFcShort( 0x1 ),	/* Corr flags:  early, */
/* 38 */	0x1,		/* FC_BYTE */
			0x5b,		/* FC_END */
/* 40 */	
			0x11, 0x0,	/* FC_RP */
/* 42 */	NdrFcShort( 0x2 ),	/* Offset= 2 (44) */
/* 44 */	
			0x1c,		/* FC_CVARRAY */
			0x0,		/* 0 */
/* 46 */	NdrFcShort( 0x1 ),	/* 1 */
/* 48 */	0x29,		/* Corr desc:  parameter, FC_ULONG */
			0x0,		/*  */
/* 50 */	NdrFcShort( 0x18 ),	/* ia64, axp64 Stack size/offset = 24 */
/* 52 */	NdrFcShort( 0x1 ),	/* Corr flags:  early, */
/* 54 */	0x29,		/* Corr desc:  parameter, FC_ULONG */
			0x54,		/* FC_DEREFERENCE */
/* 56 */	NdrFcShort( 0x20 ),	/* ia64, axp64 Stack size/offset = 32 */
/* 58 */	NdrFcShort( 0x1 ),	/* Corr flags:  early, */
/* 60 */	0x1,		/* FC_BYTE */
			0x5b,		/* FC_END */
/* 62 */	
			0x12, 0x8,	/* FC_UP [simple_pointer] */
/* 64 */	
			0x22,		/* FC_C_CSTRING */
			0x5c,		/* FC_PAD */
/* 66 */	
			0x11, 0x0,	/* FC_RP */
/* 68 */	NdrFcShort( 0x2 ),	/* Offset= 2 (70) */
/* 70 */	
			0x22,		/* FC_C_CSTRING */
			0x44,		/* FC_STRING_SIZED */
/* 72 */	0x29,		/* Corr desc:  parameter, FC_ULONG */
			0x0,		/*  */
/* 74 */	NdrFcShort( 0x18 ),	/* ia64, axp64 Stack size/offset = 24 */
/* 76 */	NdrFcShort( 0x1 ),	/* Corr flags:  early, */
/* 78 */	
			0x12, 0x8,	/* FC_UP [simple_pointer] */
/* 80 */	
			0x25,		/* FC_C_WSTRING */
			0x5c,		/* FC_PAD */
/* 82 */	
			0x11, 0x0,	/* FC_RP */
/* 84 */	NdrFcShort( 0x2 ),	/* Offset= 2 (86) */
/* 86 */	
			0x25,		/* FC_C_WSTRING */
			0x44,		/* FC_STRING_SIZED */
/* 88 */	0x29,		/* Corr desc:  parameter, FC_ULONG */
			0x0,		/*  */
/* 90 */	NdrFcShort( 0x18 ),	/* ia64, axp64 Stack size/offset = 24 */
/* 92 */	NdrFcShort( 0x1 ),	/* Corr flags:  early, */
/* 94 */	
			0x2f,		/* FC_IP */
			0x5a,		/* FC_CONSTANT_IID */
/* 96 */	NdrFcLong( 0xf7c3c30 ),	/* 259800112 */
/* 100 */	NdrFcShort( 0xa8ad ),	/* -22355 */
/* 102 */	NdrFcShort( 0x11d1 ),	/* 4561 */
/* 104 */	0xaa,		/* 170 */
			0x91,		/* 145 */
/* 106 */	0x0,		/* 0 */
			0xaa,		/* 170 */
/* 108 */	0x0,		/* 0 */
			0x6b,		/* 107 */
/* 110 */	0xc8,		/* 200 */
			0xb,		/* 11 */
/* 112 */	
			0x11, 0x0,	/* FC_RP */
/* 114 */	NdrFcShort( 0x2 ),	/* Offset= 2 (116) */
/* 116 */	
			0x22,		/* FC_C_CSTRING */
			0x44,		/* FC_STRING_SIZED */
/* 118 */	0x29,		/* Corr desc:  parameter, FC_ULONG */
			0x0,		/*  */
/* 120 */	NdrFcShort( 0x10 ),	/* ia64, axp64 Stack size/offset = 16 */
/* 122 */	NdrFcShort( 0x1 ),	/* Corr flags:  early, */
/* 124 */	
			0x11, 0x10,	/* FC_RP [pointer_deref] */
/* 126 */	NdrFcShort( 0x2 ),	/* Offset= 2 (128) */
/* 128 */	
			0x2f,		/* FC_IP */
			0x5a,		/* FC_CONSTANT_IID */
/* 130 */	NdrFcLong( 0x4c28a700 ),	/* 1277732608 */
/* 134 */	NdrFcShort( 0xa892 ),	/* -22382 */
/* 136 */	NdrFcShort( 0x11d1 ),	/* 4561 */
/* 138 */	0xaa,		/* 170 */
			0x91,		/* 145 */
/* 140 */	0x0,		/* 0 */
			0xaa,		/* 170 */
/* 142 */	0x0,		/* 0 */
			0x6b,		/* 107 */
/* 144 */	0xc8,		/* 200 */
			0xb,		/* 11 */
/* 146 */	
			0x12, 0x0,	/* FC_UP */
/* 148 */	NdrFcShort( 0x2 ),	/* Offset= 2 (150) */
/* 150 */	
			0x15,		/* FC_STRUCT */
			0x3,		/* 3 */
/* 152 */	NdrFcShort( 0x18 ),	/* 24 */
/* 154 */	0x8,		/* FC_LONG */
			0x8,		/* FC_LONG */
/* 156 */	0x8,		/* FC_LONG */
			0x8,		/* FC_LONG */
/* 158 */	0x8,		/* FC_LONG */
			0x8,		/* FC_LONG */
/* 160 */	0x5c,		/* FC_PAD */
			0x5b,		/* FC_END */
/* 162 */	
			0x11, 0x0,	/* FC_RP */
/* 164 */	NdrFcShort( 0x8 ),	/* Offset= 8 (172) */
/* 166 */	
			0x1d,		/* FC_SMFARRAY */
			0x0,		/* 0 */
/* 168 */	NdrFcShort( 0x8 ),	/* 8 */
/* 170 */	0x2,		/* FC_CHAR */
			0x5b,		/* FC_END */
/* 172 */	
			0x15,		/* FC_STRUCT */
			0x3,		/* 3 */
/* 174 */	NdrFcShort( 0x10 ),	/* 16 */
/* 176 */	0x8,		/* FC_LONG */
			0x6,		/* FC_SHORT */
/* 178 */	0x6,		/* FC_SHORT */
			0x4c,		/* FC_EMBEDDED_COMPLEX */
/* 180 */	0x0,		/* 0 */
			NdrFcShort( 0xfffffff1 ),	/* Offset= -15 (166) */
			0x5b,		/* FC_END */

			0x0
        }
    };

const CInterfaceProxyVtbl * _MailMsg_ProxyVtblList[] = 
{
    ( CInterfaceProxyVtbl *) &_IMailMsgRecipientsAddProxyVtbl,
    ( CInterfaceProxyVtbl *) &_IMailMsgQueueMgmtProxyVtbl,
    ( CInterfaceProxyVtbl *) &_IMailMsgRecipientsBaseProxyVtbl,
    ( CInterfaceProxyVtbl *) &_IMailMsgNotifyProxyVtbl,
    ( CInterfaceProxyVtbl *) &_IMailMsgPropertyManagementProxyVtbl,
    ( CInterfaceProxyVtbl *) &_IMailMsgRecipientsProxyVtbl,
    0
};

const CInterfaceStubVtbl * _MailMsg_StubVtblList[] = 
{
    ( CInterfaceStubVtbl *) &_IMailMsgRecipientsAddStubVtbl,
    ( CInterfaceStubVtbl *) &_IMailMsgQueueMgmtStubVtbl,
    ( CInterfaceStubVtbl *) &_IMailMsgRecipientsBaseStubVtbl,
    ( CInterfaceStubVtbl *) &_IMailMsgNotifyStubVtbl,
    ( CInterfaceStubVtbl *) &_IMailMsgPropertyManagementStubVtbl,
    ( CInterfaceStubVtbl *) &_IMailMsgRecipientsStubVtbl,
    0
};

PCInterfaceName const _MailMsg_InterfaceNamesList[] = 
{
    "IMailMsgRecipientsAdd",
    "IMailMsgQueueMgmt",
    "IMailMsgRecipientsBase",
    "IMailMsgNotify",
    "IMailMsgPropertyManagement",
    "IMailMsgRecipients",
    0
};


#define _MailMsg_CHECK_IID(n)	IID_GENERIC_CHECK_IID( _MailMsg, pIID, n)

int __stdcall _MailMsg_IID_Lookup( const IID * pIID, int * pIndex )
{
    IID_BS_LOOKUP_SETUP

    IID_BS_LOOKUP_INITIAL_TEST( _MailMsg, 6, 4 )
    IID_BS_LOOKUP_NEXT_TEST( _MailMsg, 2 )
    IID_BS_LOOKUP_NEXT_TEST( _MailMsg, 1 )
    IID_BS_LOOKUP_RETURN_RESULT( _MailMsg, 6, *pIndex )
    
}

const ExtendedProxyFileInfo MailMsg_ProxyFileInfo = 
{
    (PCInterfaceProxyVtblList *) & _MailMsg_ProxyVtblList,
    (PCInterfaceStubVtblList *) & _MailMsg_StubVtblList,
    (const PCInterfaceName * ) & _MailMsg_InterfaceNamesList,
    0, // no delegation
    & _MailMsg_IID_Lookup, 
    6,
    2,
    0, /* table of [async_uuid] interfaces */
    0, /* Filler1 */
    0, /* Filler2 */
    0  /* Filler3 */
};


#endif /* defined(_M_IA64) || defined(_M_AXP64)*/

