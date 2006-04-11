
#pragma warning( disable: 4049 )  /* more than 64k source lines */

/* this ALWAYS GENERATED file contains the definitions for the interfaces */


 /* File created by MIDL compiler version 5.03.0280 */
/* at Wed Nov 01 16:03:46 2000
 */
/* Compiler settings for D:\Program Files\Microsoft Platform SDK\Include\Seo.Idl:
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

#ifndef __Seo_h__
#define __Seo_h__

/* Forward Declarations */ 

#ifndef __ISEODictionaryItem_FWD_DEFINED__
#define __ISEODictionaryItem_FWD_DEFINED__
typedef interface ISEODictionaryItem ISEODictionaryItem;
#endif 	/* __ISEODictionaryItem_FWD_DEFINED__ */


#ifndef __ISEODictionary_FWD_DEFINED__
#define __ISEODictionary_FWD_DEFINED__
typedef interface ISEODictionary ISEODictionary;
#endif 	/* __ISEODictionary_FWD_DEFINED__ */


#ifndef __IEventLock_FWD_DEFINED__
#define __IEventLock_FWD_DEFINED__
typedef interface IEventLock IEventLock;
#endif 	/* __IEventLock_FWD_DEFINED__ */


#ifndef __ISEORouter_FWD_DEFINED__
#define __ISEORouter_FWD_DEFINED__
typedef interface ISEORouter ISEORouter;
#endif 	/* __ISEORouter_FWD_DEFINED__ */


#ifndef __IMCISMessageFilter_FWD_DEFINED__
#define __IMCISMessageFilter_FWD_DEFINED__
typedef interface IMCISMessageFilter IMCISMessageFilter;
#endif 	/* __IMCISMessageFilter_FWD_DEFINED__ */


#ifndef __ISEOBindingRuleEngine_FWD_DEFINED__
#define __ISEOBindingRuleEngine_FWD_DEFINED__
typedef interface ISEOBindingRuleEngine ISEOBindingRuleEngine;
#endif 	/* __ISEOBindingRuleEngine_FWD_DEFINED__ */


#ifndef __ISEOEventSink_FWD_DEFINED__
#define __ISEOEventSink_FWD_DEFINED__
typedef interface ISEOEventSink ISEOEventSink;
#endif 	/* __ISEOEventSink_FWD_DEFINED__ */


#ifndef __ISEORegDictionary_FWD_DEFINED__
#define __ISEORegDictionary_FWD_DEFINED__
typedef interface ISEORegDictionary ISEORegDictionary;
#endif 	/* __ISEORegDictionary_FWD_DEFINED__ */


#ifndef __ISEOBindingConverter_FWD_DEFINED__
#define __ISEOBindingConverter_FWD_DEFINED__
typedef interface ISEOBindingConverter ISEOBindingConverter;
#endif 	/* __ISEOBindingConverter_FWD_DEFINED__ */


#ifndef __ISEODispatcher_FWD_DEFINED__
#define __ISEODispatcher_FWD_DEFINED__
typedef interface ISEODispatcher ISEODispatcher;
#endif 	/* __ISEODispatcher_FWD_DEFINED__ */


#ifndef __IEventDeliveryOptions_FWD_DEFINED__
#define __IEventDeliveryOptions_FWD_DEFINED__
typedef interface IEventDeliveryOptions IEventDeliveryOptions;
#endif 	/* __IEventDeliveryOptions_FWD_DEFINED__ */


#ifndef __IEventTypeSinks_FWD_DEFINED__
#define __IEventTypeSinks_FWD_DEFINED__
typedef interface IEventTypeSinks IEventTypeSinks;
#endif 	/* __IEventTypeSinks_FWD_DEFINED__ */


#ifndef __IEventType_FWD_DEFINED__
#define __IEventType_FWD_DEFINED__
typedef interface IEventType IEventType;
#endif 	/* __IEventType_FWD_DEFINED__ */


#ifndef __IEventPropertyBag_FWD_DEFINED__
#define __IEventPropertyBag_FWD_DEFINED__
typedef interface IEventPropertyBag IEventPropertyBag;
#endif 	/* __IEventPropertyBag_FWD_DEFINED__ */


#ifndef __IEventBinding_FWD_DEFINED__
#define __IEventBinding_FWD_DEFINED__
typedef interface IEventBinding IEventBinding;
#endif 	/* __IEventBinding_FWD_DEFINED__ */


#ifndef __IEventBindings_FWD_DEFINED__
#define __IEventBindings_FWD_DEFINED__
typedef interface IEventBindings IEventBindings;
#endif 	/* __IEventBindings_FWD_DEFINED__ */


#ifndef __IEventTypes_FWD_DEFINED__
#define __IEventTypes_FWD_DEFINED__
typedef interface IEventTypes IEventTypes;
#endif 	/* __IEventTypes_FWD_DEFINED__ */


#ifndef __IEventBindingManager_FWD_DEFINED__
#define __IEventBindingManager_FWD_DEFINED__
typedef interface IEventBindingManager IEventBindingManager;
#endif 	/* __IEventBindingManager_FWD_DEFINED__ */


#ifndef __IEventBindingManagerCopier_FWD_DEFINED__
#define __IEventBindingManagerCopier_FWD_DEFINED__
typedef interface IEventBindingManagerCopier IEventBindingManagerCopier;
#endif 	/* __IEventBindingManagerCopier_FWD_DEFINED__ */


#ifndef __IEventRouter_FWD_DEFINED__
#define __IEventRouter_FWD_DEFINED__
typedef interface IEventRouter IEventRouter;
#endif 	/* __IEventRouter_FWD_DEFINED__ */


#ifndef __IEventDispatcher_FWD_DEFINED__
#define __IEventDispatcher_FWD_DEFINED__
typedef interface IEventDispatcher IEventDispatcher;
#endif 	/* __IEventDispatcher_FWD_DEFINED__ */


#ifndef __IEventSource_FWD_DEFINED__
#define __IEventSource_FWD_DEFINED__
typedef interface IEventSource IEventSource;
#endif 	/* __IEventSource_FWD_DEFINED__ */


#ifndef __IEventSources_FWD_DEFINED__
#define __IEventSources_FWD_DEFINED__
typedef interface IEventSources IEventSources;
#endif 	/* __IEventSources_FWD_DEFINED__ */


#ifndef __IEventSourceType_FWD_DEFINED__
#define __IEventSourceType_FWD_DEFINED__
typedef interface IEventSourceType IEventSourceType;
#endif 	/* __IEventSourceType_FWD_DEFINED__ */


#ifndef __IEventSourceTypes_FWD_DEFINED__
#define __IEventSourceTypes_FWD_DEFINED__
typedef interface IEventSourceTypes IEventSourceTypes;
#endif 	/* __IEventSourceTypes_FWD_DEFINED__ */


#ifndef __IEventManager_FWD_DEFINED__
#define __IEventManager_FWD_DEFINED__
typedef interface IEventManager IEventManager;
#endif 	/* __IEventManager_FWD_DEFINED__ */


#ifndef __IEventDatabasePlugin_FWD_DEFINED__
#define __IEventDatabasePlugin_FWD_DEFINED__
typedef interface IEventDatabasePlugin IEventDatabasePlugin;
#endif 	/* __IEventDatabasePlugin_FWD_DEFINED__ */


#ifndef __IEventDatabaseManager_FWD_DEFINED__
#define __IEventDatabaseManager_FWD_DEFINED__
typedef interface IEventDatabaseManager IEventDatabaseManager;
#endif 	/* __IEventDatabaseManager_FWD_DEFINED__ */


#ifndef __IEventUtil_FWD_DEFINED__
#define __IEventUtil_FWD_DEFINED__
typedef interface IEventUtil IEventUtil;
#endif 	/* __IEventUtil_FWD_DEFINED__ */


#ifndef __IEventComCat_FWD_DEFINED__
#define __IEventComCat_FWD_DEFINED__
typedef interface IEventComCat IEventComCat;
#endif 	/* __IEventComCat_FWD_DEFINED__ */


#ifndef __IEventNotifyBindingChange_FWD_DEFINED__
#define __IEventNotifyBindingChange_FWD_DEFINED__
typedef interface IEventNotifyBindingChange IEventNotifyBindingChange;
#endif 	/* __IEventNotifyBindingChange_FWD_DEFINED__ */


#ifndef __IEventNotifyBindingChangeDisp_FWD_DEFINED__
#define __IEventNotifyBindingChangeDisp_FWD_DEFINED__
typedef interface IEventNotifyBindingChangeDisp IEventNotifyBindingChangeDisp;
#endif 	/* __IEventNotifyBindingChangeDisp_FWD_DEFINED__ */


#ifndef __ISEOInitObject_FWD_DEFINED__
#define __ISEOInitObject_FWD_DEFINED__
typedef interface ISEOInitObject ISEOInitObject;
#endif 	/* __ISEOInitObject_FWD_DEFINED__ */


#ifndef __IEventRuleEngine_FWD_DEFINED__
#define __IEventRuleEngine_FWD_DEFINED__
typedef interface IEventRuleEngine IEventRuleEngine;
#endif 	/* __IEventRuleEngine_FWD_DEFINED__ */


#ifndef __IEventPersistBinding_FWD_DEFINED__
#define __IEventPersistBinding_FWD_DEFINED__
typedef interface IEventPersistBinding IEventPersistBinding;
#endif 	/* __IEventPersistBinding_FWD_DEFINED__ */


#ifndef __IEventSinkNotify_FWD_DEFINED__
#define __IEventSinkNotify_FWD_DEFINED__
typedef interface IEventSinkNotify IEventSinkNotify;
#endif 	/* __IEventSinkNotify_FWD_DEFINED__ */


#ifndef __IEventSinkNotifyDisp_FWD_DEFINED__
#define __IEventSinkNotifyDisp_FWD_DEFINED__
typedef interface IEventSinkNotifyDisp IEventSinkNotifyDisp;
#endif 	/* __IEventSinkNotifyDisp_FWD_DEFINED__ */


#ifndef __IEventIsCacheable_FWD_DEFINED__
#define __IEventIsCacheable_FWD_DEFINED__
typedef interface IEventIsCacheable IEventIsCacheable;
#endif 	/* __IEventIsCacheable_FWD_DEFINED__ */


#ifndef __IEventCreateOptions_FWD_DEFINED__
#define __IEventCreateOptions_FWD_DEFINED__
typedef interface IEventCreateOptions IEventCreateOptions;
#endif 	/* __IEventCreateOptions_FWD_DEFINED__ */


#ifndef __IEventDispatcherChain_FWD_DEFINED__
#define __IEventDispatcherChain_FWD_DEFINED__
typedef interface IEventDispatcherChain IEventDispatcherChain;
#endif 	/* __IEventDispatcherChain_FWD_DEFINED__ */


#ifndef __ISEODictionaryItem_FWD_DEFINED__
#define __ISEODictionaryItem_FWD_DEFINED__
typedef interface ISEODictionaryItem ISEODictionaryItem;
#endif 	/* __ISEODictionaryItem_FWD_DEFINED__ */


#ifndef __ISEODictionary_FWD_DEFINED__
#define __ISEODictionary_FWD_DEFINED__
typedef interface ISEODictionary ISEODictionary;
#endif 	/* __ISEODictionary_FWD_DEFINED__ */


#ifndef __IEventLock_FWD_DEFINED__
#define __IEventLock_FWD_DEFINED__
typedef interface IEventLock IEventLock;
#endif 	/* __IEventLock_FWD_DEFINED__ */


#ifndef __ISEORouter_FWD_DEFINED__
#define __ISEORouter_FWD_DEFINED__
typedef interface ISEORouter ISEORouter;
#endif 	/* __ISEORouter_FWD_DEFINED__ */


#ifndef __IMCISMessageFilter_FWD_DEFINED__
#define __IMCISMessageFilter_FWD_DEFINED__
typedef interface IMCISMessageFilter IMCISMessageFilter;
#endif 	/* __IMCISMessageFilter_FWD_DEFINED__ */


#ifndef __ISEOBindingRuleEngine_FWD_DEFINED__
#define __ISEOBindingRuleEngine_FWD_DEFINED__
typedef interface ISEOBindingRuleEngine ISEOBindingRuleEngine;
#endif 	/* __ISEOBindingRuleEngine_FWD_DEFINED__ */


#ifndef __ISEOEventSink_FWD_DEFINED__
#define __ISEOEventSink_FWD_DEFINED__
typedef interface ISEOEventSink ISEOEventSink;
#endif 	/* __ISEOEventSink_FWD_DEFINED__ */


#ifndef __ISEORegDictionary_FWD_DEFINED__
#define __ISEORegDictionary_FWD_DEFINED__
typedef interface ISEORegDictionary ISEORegDictionary;
#endif 	/* __ISEORegDictionary_FWD_DEFINED__ */


#ifndef __ISEOBindingConverter_FWD_DEFINED__
#define __ISEOBindingConverter_FWD_DEFINED__
typedef interface ISEOBindingConverter ISEOBindingConverter;
#endif 	/* __ISEOBindingConverter_FWD_DEFINED__ */


#ifndef __ISEODispatcher_FWD_DEFINED__
#define __ISEODispatcher_FWD_DEFINED__
typedef interface ISEODispatcher ISEODispatcher;
#endif 	/* __ISEODispatcher_FWD_DEFINED__ */


#ifndef __IEventDeliveryOptions_FWD_DEFINED__
#define __IEventDeliveryOptions_FWD_DEFINED__
typedef interface IEventDeliveryOptions IEventDeliveryOptions;
#endif 	/* __IEventDeliveryOptions_FWD_DEFINED__ */


#ifndef __IEventTypeSinks_FWD_DEFINED__
#define __IEventTypeSinks_FWD_DEFINED__
typedef interface IEventTypeSinks IEventTypeSinks;
#endif 	/* __IEventTypeSinks_FWD_DEFINED__ */


#ifndef __IEventType_FWD_DEFINED__
#define __IEventType_FWD_DEFINED__
typedef interface IEventType IEventType;
#endif 	/* __IEventType_FWD_DEFINED__ */


#ifndef __IEventPropertyBag_FWD_DEFINED__
#define __IEventPropertyBag_FWD_DEFINED__
typedef interface IEventPropertyBag IEventPropertyBag;
#endif 	/* __IEventPropertyBag_FWD_DEFINED__ */


#ifndef __IEventBinding_FWD_DEFINED__
#define __IEventBinding_FWD_DEFINED__
typedef interface IEventBinding IEventBinding;
#endif 	/* __IEventBinding_FWD_DEFINED__ */


#ifndef __IEventBindings_FWD_DEFINED__
#define __IEventBindings_FWD_DEFINED__
typedef interface IEventBindings IEventBindings;
#endif 	/* __IEventBindings_FWD_DEFINED__ */


#ifndef __IEventTypes_FWD_DEFINED__
#define __IEventTypes_FWD_DEFINED__
typedef interface IEventTypes IEventTypes;
#endif 	/* __IEventTypes_FWD_DEFINED__ */


#ifndef __IEventBindingManager_FWD_DEFINED__
#define __IEventBindingManager_FWD_DEFINED__
typedef interface IEventBindingManager IEventBindingManager;
#endif 	/* __IEventBindingManager_FWD_DEFINED__ */


#ifndef __IEventSource_FWD_DEFINED__
#define __IEventSource_FWD_DEFINED__
typedef interface IEventSource IEventSource;
#endif 	/* __IEventSource_FWD_DEFINED__ */


#ifndef __IEventSources_FWD_DEFINED__
#define __IEventSources_FWD_DEFINED__
typedef interface IEventSources IEventSources;
#endif 	/* __IEventSources_FWD_DEFINED__ */


#ifndef __IEventSourceType_FWD_DEFINED__
#define __IEventSourceType_FWD_DEFINED__
typedef interface IEventSourceType IEventSourceType;
#endif 	/* __IEventSourceType_FWD_DEFINED__ */


#ifndef __IEventSourceTypes_FWD_DEFINED__
#define __IEventSourceTypes_FWD_DEFINED__
typedef interface IEventSourceTypes IEventSourceTypes;
#endif 	/* __IEventSourceTypes_FWD_DEFINED__ */


#ifndef __IEventManager_FWD_DEFINED__
#define __IEventManager_FWD_DEFINED__
typedef interface IEventManager IEventManager;
#endif 	/* __IEventManager_FWD_DEFINED__ */


#ifndef __ISEOInitObject_FWD_DEFINED__
#define __ISEOInitObject_FWD_DEFINED__
typedef interface ISEOInitObject ISEOInitObject;
#endif 	/* __ISEOInitObject_FWD_DEFINED__ */


#ifndef __IEventDatabasePlugin_FWD_DEFINED__
#define __IEventDatabasePlugin_FWD_DEFINED__
typedef interface IEventDatabasePlugin IEventDatabasePlugin;
#endif 	/* __IEventDatabasePlugin_FWD_DEFINED__ */


#ifndef __IEventDatabaseManager_FWD_DEFINED__
#define __IEventDatabaseManager_FWD_DEFINED__
typedef interface IEventDatabaseManager IEventDatabaseManager;
#endif 	/* __IEventDatabaseManager_FWD_DEFINED__ */


#ifndef __IEventUtil_FWD_DEFINED__
#define __IEventUtil_FWD_DEFINED__
typedef interface IEventUtil IEventUtil;
#endif 	/* __IEventUtil_FWD_DEFINED__ */


#ifndef __IEventComCat_FWD_DEFINED__
#define __IEventComCat_FWD_DEFINED__
typedef interface IEventComCat IEventComCat;
#endif 	/* __IEventComCat_FWD_DEFINED__ */


#ifndef __IEventNotifyBindingChange_FWD_DEFINED__
#define __IEventNotifyBindingChange_FWD_DEFINED__
typedef interface IEventNotifyBindingChange IEventNotifyBindingChange;
#endif 	/* __IEventNotifyBindingChange_FWD_DEFINED__ */


#ifndef __IEventNotifyBindingChangeDisp_FWD_DEFINED__
#define __IEventNotifyBindingChangeDisp_FWD_DEFINED__
typedef interface IEventNotifyBindingChangeDisp IEventNotifyBindingChangeDisp;
#endif 	/* __IEventNotifyBindingChangeDisp_FWD_DEFINED__ */


#ifndef __IEventRouter_FWD_DEFINED__
#define __IEventRouter_FWD_DEFINED__
typedef interface IEventRouter IEventRouter;
#endif 	/* __IEventRouter_FWD_DEFINED__ */


#ifndef __IEventDispatcher_FWD_DEFINED__
#define __IEventDispatcher_FWD_DEFINED__
typedef interface IEventDispatcher IEventDispatcher;
#endif 	/* __IEventDispatcher_FWD_DEFINED__ */


#ifndef __IEventRuleEngine_FWD_DEFINED__
#define __IEventRuleEngine_FWD_DEFINED__
typedef interface IEventRuleEngine IEventRuleEngine;
#endif 	/* __IEventRuleEngine_FWD_DEFINED__ */


#ifndef __IEventSinkNotify_FWD_DEFINED__
#define __IEventSinkNotify_FWD_DEFINED__
typedef interface IEventSinkNotify IEventSinkNotify;
#endif 	/* __IEventSinkNotify_FWD_DEFINED__ */


#ifndef __IEventSinkNotifyDisp_FWD_DEFINED__
#define __IEventSinkNotifyDisp_FWD_DEFINED__
typedef interface IEventSinkNotifyDisp IEventSinkNotifyDisp;
#endif 	/* __IEventSinkNotifyDisp_FWD_DEFINED__ */


#ifndef __IEventPersistBinding_FWD_DEFINED__
#define __IEventPersistBinding_FWD_DEFINED__
typedef interface IEventPersistBinding IEventPersistBinding;
#endif 	/* __IEventPersistBinding_FWD_DEFINED__ */


#ifndef __IEventIsCacheable_FWD_DEFINED__
#define __IEventIsCacheable_FWD_DEFINED__
typedef interface IEventIsCacheable IEventIsCacheable;
#endif 	/* __IEventIsCacheable_FWD_DEFINED__ */


#ifndef __IEventCreateOptions_FWD_DEFINED__
#define __IEventCreateOptions_FWD_DEFINED__
typedef interface IEventCreateOptions IEventCreateOptions;
#endif 	/* __IEventCreateOptions_FWD_DEFINED__ */


#ifndef __IEventDispatcherChain_FWD_DEFINED__
#define __IEventDispatcherChain_FWD_DEFINED__
typedef interface IEventDispatcherChain IEventDispatcherChain;
#endif 	/* __IEventDispatcherChain_FWD_DEFINED__ */


#ifndef __CSEORegDictionary_FWD_DEFINED__
#define __CSEORegDictionary_FWD_DEFINED__

#ifdef __cplusplus
typedef class CSEORegDictionary CSEORegDictionary;
#else
typedef struct CSEORegDictionary CSEORegDictionary;
#endif /* __cplusplus */

#endif 	/* __CSEORegDictionary_FWD_DEFINED__ */


#ifndef __CSEOMimeDictionary_FWD_DEFINED__
#define __CSEOMimeDictionary_FWD_DEFINED__

#ifdef __cplusplus
typedef class CSEOMimeDictionary CSEOMimeDictionary;
#else
typedef struct CSEOMimeDictionary CSEOMimeDictionary;
#endif /* __cplusplus */

#endif 	/* __CSEOMimeDictionary_FWD_DEFINED__ */


#ifndef __CSEOMemDictionary_FWD_DEFINED__
#define __CSEOMemDictionary_FWD_DEFINED__

#ifdef __cplusplus
typedef class CSEOMemDictionary CSEOMemDictionary;
#else
typedef struct CSEOMemDictionary CSEOMemDictionary;
#endif /* __cplusplus */

#endif 	/* __CSEOMemDictionary_FWD_DEFINED__ */


#ifndef __CSEOMetaDictionary_FWD_DEFINED__
#define __CSEOMetaDictionary_FWD_DEFINED__

#ifdef __cplusplus
typedef class CSEOMetaDictionary CSEOMetaDictionary;
#else
typedef struct CSEOMetaDictionary CSEOMetaDictionary;
#endif /* __cplusplus */

#endif 	/* __CSEOMetaDictionary_FWD_DEFINED__ */


#ifndef __CSEODictionaryItem_FWD_DEFINED__
#define __CSEODictionaryItem_FWD_DEFINED__

#ifdef __cplusplus
typedef class CSEODictionaryItem CSEODictionaryItem;
#else
typedef struct CSEODictionaryItem CSEODictionaryItem;
#endif /* __cplusplus */

#endif 	/* __CSEODictionaryItem_FWD_DEFINED__ */


#ifndef __CSEORouter_FWD_DEFINED__
#define __CSEORouter_FWD_DEFINED__

#ifdef __cplusplus
typedef class CSEORouter CSEORouter;
#else
typedef struct CSEORouter CSEORouter;
#endif /* __cplusplus */

#endif 	/* __CSEORouter_FWD_DEFINED__ */


#ifndef __CEventLock_FWD_DEFINED__
#define __CEventLock_FWD_DEFINED__

#ifdef __cplusplus
typedef class CEventLock CEventLock;
#else
typedef struct CEventLock CEventLock;
#endif /* __cplusplus */

#endif 	/* __CEventLock_FWD_DEFINED__ */


#ifndef __CSEOStream_FWD_DEFINED__
#define __CSEOStream_FWD_DEFINED__

#ifdef __cplusplus
typedef class CSEOStream CSEOStream;
#else
typedef struct CSEOStream CSEOStream;
#endif /* __cplusplus */

#endif 	/* __CSEOStream_FWD_DEFINED__ */


#ifndef __CEventManager_FWD_DEFINED__
#define __CEventManager_FWD_DEFINED__

#ifdef __cplusplus
typedef class CEventManager CEventManager;
#else
typedef struct CEventManager CEventManager;
#endif /* __cplusplus */

#endif 	/* __CEventManager_FWD_DEFINED__ */


#ifndef __CEventBindingManager_FWD_DEFINED__
#define __CEventBindingManager_FWD_DEFINED__

#ifdef __cplusplus
typedef class CEventBindingManager CEventBindingManager;
#else
typedef struct CEventBindingManager CEventBindingManager;
#endif /* __cplusplus */

#endif 	/* __CEventBindingManager_FWD_DEFINED__ */


#ifndef __CSEOGenericMoniker_FWD_DEFINED__
#define __CSEOGenericMoniker_FWD_DEFINED__

#ifdef __cplusplus
typedef class CSEOGenericMoniker CSEOGenericMoniker;
#else
typedef struct CSEOGenericMoniker CSEOGenericMoniker;
#endif /* __cplusplus */

#endif 	/* __CSEOGenericMoniker_FWD_DEFINED__ */


#ifndef __CEventMetabaseDatabaseManager_FWD_DEFINED__
#define __CEventMetabaseDatabaseManager_FWD_DEFINED__

#ifdef __cplusplus
typedef class CEventMetabaseDatabaseManager CEventMetabaseDatabaseManager;
#else
typedef struct CEventMetabaseDatabaseManager CEventMetabaseDatabaseManager;
#endif /* __cplusplus */

#endif 	/* __CEventMetabaseDatabaseManager_FWD_DEFINED__ */


#ifndef __CEventUtil_FWD_DEFINED__
#define __CEventUtil_FWD_DEFINED__

#ifdef __cplusplus
typedef class CEventUtil CEventUtil;
#else
typedef struct CEventUtil CEventUtil;
#endif /* __cplusplus */

#endif 	/* __CEventUtil_FWD_DEFINED__ */


#ifndef __CEventComCat_FWD_DEFINED__
#define __CEventComCat_FWD_DEFINED__

#ifdef __cplusplus
typedef class CEventComCat CEventComCat;
#else
typedef struct CEventComCat CEventComCat;
#endif /* __cplusplus */

#endif 	/* __CEventComCat_FWD_DEFINED__ */


#ifndef __CEventRouter_FWD_DEFINED__
#define __CEventRouter_FWD_DEFINED__

#ifdef __cplusplus
typedef class CEventRouter CEventRouter;
#else
typedef struct CEventRouter CEventRouter;
#endif /* __cplusplus */

#endif 	/* __CEventRouter_FWD_DEFINED__ */


/* header files for imported files */
#include "wtypes.h"
#include "ocidl.h"

#ifdef __cplusplus
extern "C"{
#endif 

void __RPC_FAR * __RPC_USER MIDL_user_allocate(size_t);
void __RPC_USER MIDL_user_free( void __RPC_FAR * ); 

/* interface __MIDL_itf_Seo_0000 */
/* [local] */ 

/*++

Copyright (c) 1999  Microsoft Corporation

Module Name:

     seo.idl / seo.h

Abstract:

     This module contains definitions for the COM interface for
     Server Extension Objects.


--*/
#ifndef SEODLLIMPORT
     #define SEODLLIMPORT _declspec(dllimport)
#endif
#ifndef SEODLLEXPORT
     #define SEODLLEXPORT _declspec(dllexport)
#endif
#ifndef SEODLLDEF
     #ifndef SEODLL_IMPLEMENTATION
             #define SEODLLDEF EXTERN_C SEODLLIMPORT
     #else
             #define SEODLLDEF EXTERN_C SEODLLEXPORT
     #endif
#endif
#define BD_OBJECT                    "Object"
#define BD_PROGID                    "ProgID"
#define BD_PRIORITY                  "Priority"
#define BD_RULEENGINE                "RuleEngine"
#define BD_EXCLUSIVE                 "Exclusive"
#define BD_BINDINGS                  "Bindings"
#define BD_DISPATCHER                "Dispatcher"
#define BD_BINDINGPOINTS             "BindingPoints"
#define BD_RULE                              "Rule"
#define PRIO_HIGHEST                 0
#define PRIO_HIGH                    8191
#define PRIO_MEDIUM                  16383
#define PRIO_LOW                     24575
#define PRIO_LOWEST                  32767
#define PRIO_DEFAULT                 PRIO_LOW
#define PRIO_HIGHEST_STR             L"PRIO_HIGHEST"
#define PRIO_HIGH_STR                L"PRIO_HIGH"
#define PRIO_MEDIUM_STR              L"PRIO_MEDIUM"
#define PRIO_LOW_STR                 L"PRIO_LOW"
#define PRIO_LOWEST_STR              L"PRIO_LOWEST"
#define PRIO_DEFAULT_STR             L"PRIO_DEFAULT"
#define PRIO_MIN                     PRIO_HIGHEST
#define PRIO_MAX                     PRIO_LOWEST


extern RPC_IF_HANDLE __MIDL_itf_Seo_0000_v0_0_c_ifspec;
extern RPC_IF_HANDLE __MIDL_itf_Seo_0000_v0_0_s_ifspec;

#ifndef __ISEODictionaryItem_INTERFACE_DEFINED__
#define __ISEODictionaryItem_INTERFACE_DEFINED__

/* interface ISEODictionaryItem */
/* [uuid][unique][object][hidden][helpstring][dual] */ 


EXTERN_C const IID IID_ISEODictionaryItem;

#if defined(__cplusplus) && !defined(CINTERFACE)
    
    MIDL_INTERFACE("16d63630-83ae-11d0-a9e3-00aa00685c74")
    ISEODictionaryItem : public IDispatch
    {
    public:
        virtual /* [id][propget][helpstring] */ HRESULT STDMETHODCALLTYPE get_Value( 
            /* [optional][in] */ VARIANT __RPC_FAR *pvarIndex,
            /* [retval][out] */ VARIANT __RPC_FAR *pvarResult) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE AddValue( 
            /* [in] */ VARIANT __RPC_FAR *pvarIndex,
            /* [in] */ VARIANT __RPC_FAR *pvarValue) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE DeleteValue( 
            /* [in] */ VARIANT __RPC_FAR *pvarIndex) = 0;
        
        virtual /* [propget][helpstring] */ HRESULT STDMETHODCALLTYPE get_Count( 
            /* [retval][out] */ VARIANT __RPC_FAR *pvarResult) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE GetStringA( 
            /* [in] */ DWORD dwIndex,
            /* [out][in] */ DWORD __RPC_FAR *pchCount,
            /* [size_is][out] */ LPSTR pszResult) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE GetStringW( 
            /* [in] */ DWORD dwIndex,
            /* [out][in] */ DWORD __RPC_FAR *pchCount,
            /* [size_is][out] */ LPWSTR pszResult) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE AddStringA( 
            /* [in] */ DWORD dwIndex,
            /* [in] */ LPCSTR pszValue) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE AddStringW( 
            /* [in] */ DWORD dwIndex,
            /* [in] */ LPCWSTR pszValue) = 0;
        
    };
    
#else 	/* C style interface */

    typedef struct ISEODictionaryItemVtbl
    {
        BEGIN_INTERFACE
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *QueryInterface )( 
            ISEODictionaryItem __RPC_FAR * This,
            /* [in] */ REFIID riid,
            /* [iid_is][out] */ void __RPC_FAR *__RPC_FAR *ppvObject);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *AddRef )( 
            ISEODictionaryItem __RPC_FAR * This);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *Release )( 
            ISEODictionaryItem __RPC_FAR * This);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetTypeInfoCount )( 
            ISEODictionaryItem __RPC_FAR * This,
            /* [out] */ UINT __RPC_FAR *pctinfo);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetTypeInfo )( 
            ISEODictionaryItem __RPC_FAR * This,
            /* [in] */ UINT iTInfo,
            /* [in] */ LCID lcid,
            /* [out] */ ITypeInfo __RPC_FAR *__RPC_FAR *ppTInfo);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetIDsOfNames )( 
            ISEODictionaryItem __RPC_FAR * This,
            /* [in] */ REFIID riid,
            /* [size_is][in] */ LPOLESTR __RPC_FAR *rgszNames,
            /* [in] */ UINT cNames,
            /* [in] */ LCID lcid,
            /* [size_is][out] */ DISPID __RPC_FAR *rgDispId);
        
        /* [local] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *Invoke )( 
            ISEODictionaryItem __RPC_FAR * This,
            /* [in] */ DISPID dispIdMember,
            /* [in] */ REFIID riid,
            /* [in] */ LCID lcid,
            /* [in] */ WORD wFlags,
            /* [out][in] */ DISPPARAMS __RPC_FAR *pDispParams,
            /* [out] */ VARIANT __RPC_FAR *pVarResult,
            /* [out] */ EXCEPINFO __RPC_FAR *pExcepInfo,
            /* [out] */ UINT __RPC_FAR *puArgErr);
        
        /* [id][propget][helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *get_Value )( 
            ISEODictionaryItem __RPC_FAR * This,
            /* [optional][in] */ VARIANT __RPC_FAR *pvarIndex,
            /* [retval][out] */ VARIANT __RPC_FAR *pvarResult);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *AddValue )( 
            ISEODictionaryItem __RPC_FAR * This,
            /* [in] */ VARIANT __RPC_FAR *pvarIndex,
            /* [in] */ VARIANT __RPC_FAR *pvarValue);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *DeleteValue )( 
            ISEODictionaryItem __RPC_FAR * This,
            /* [in] */ VARIANT __RPC_FAR *pvarIndex);
        
        /* [propget][helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *get_Count )( 
            ISEODictionaryItem __RPC_FAR * This,
            /* [retval][out] */ VARIANT __RPC_FAR *pvarResult);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetStringA )( 
            ISEODictionaryItem __RPC_FAR * This,
            /* [in] */ DWORD dwIndex,
            /* [out][in] */ DWORD __RPC_FAR *pchCount,
            /* [size_is][out] */ LPSTR pszResult);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetStringW )( 
            ISEODictionaryItem __RPC_FAR * This,
            /* [in] */ DWORD dwIndex,
            /* [out][in] */ DWORD __RPC_FAR *pchCount,
            /* [size_is][out] */ LPWSTR pszResult);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *AddStringA )( 
            ISEODictionaryItem __RPC_FAR * This,
            /* [in] */ DWORD dwIndex,
            /* [in] */ LPCSTR pszValue);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *AddStringW )( 
            ISEODictionaryItem __RPC_FAR * This,
            /* [in] */ DWORD dwIndex,
            /* [in] */ LPCWSTR pszValue);
        
        END_INTERFACE
    } ISEODictionaryItemVtbl;

    interface ISEODictionaryItem
    {
        CONST_VTBL struct ISEODictionaryItemVtbl __RPC_FAR *lpVtbl;
    };

    

#ifdef COBJMACROS


#define ISEODictionaryItem_QueryInterface(This,riid,ppvObject)	\
    (This)->lpVtbl -> QueryInterface(This,riid,ppvObject)

#define ISEODictionaryItem_AddRef(This)	\
    (This)->lpVtbl -> AddRef(This)

#define ISEODictionaryItem_Release(This)	\
    (This)->lpVtbl -> Release(This)


#define ISEODictionaryItem_GetTypeInfoCount(This,pctinfo)	\
    (This)->lpVtbl -> GetTypeInfoCount(This,pctinfo)

#define ISEODictionaryItem_GetTypeInfo(This,iTInfo,lcid,ppTInfo)	\
    (This)->lpVtbl -> GetTypeInfo(This,iTInfo,lcid,ppTInfo)

#define ISEODictionaryItem_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)	\
    (This)->lpVtbl -> GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)

#define ISEODictionaryItem_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)	\
    (This)->lpVtbl -> Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)


#define ISEODictionaryItem_get_Value(This,pvarIndex,pvarResult)	\
    (This)->lpVtbl -> get_Value(This,pvarIndex,pvarResult)

#define ISEODictionaryItem_AddValue(This,pvarIndex,pvarValue)	\
    (This)->lpVtbl -> AddValue(This,pvarIndex,pvarValue)

#define ISEODictionaryItem_DeleteValue(This,pvarIndex)	\
    (This)->lpVtbl -> DeleteValue(This,pvarIndex)

#define ISEODictionaryItem_get_Count(This,pvarResult)	\
    (This)->lpVtbl -> get_Count(This,pvarResult)

#define ISEODictionaryItem_GetStringA(This,dwIndex,pchCount,pszResult)	\
    (This)->lpVtbl -> GetStringA(This,dwIndex,pchCount,pszResult)

#define ISEODictionaryItem_GetStringW(This,dwIndex,pchCount,pszResult)	\
    (This)->lpVtbl -> GetStringW(This,dwIndex,pchCount,pszResult)

#define ISEODictionaryItem_AddStringA(This,dwIndex,pszValue)	\
    (This)->lpVtbl -> AddStringA(This,dwIndex,pszValue)

#define ISEODictionaryItem_AddStringW(This,dwIndex,pszValue)	\
    (This)->lpVtbl -> AddStringW(This,dwIndex,pszValue)

#endif /* COBJMACROS */


#endif 	/* C style interface */



/* [id][propget][helpstring] */ HRESULT STDMETHODCALLTYPE ISEODictionaryItem_get_Value_Proxy( 
    ISEODictionaryItem __RPC_FAR * This,
    /* [optional][in] */ VARIANT __RPC_FAR *pvarIndex,
    /* [retval][out] */ VARIANT __RPC_FAR *pvarResult);


void __RPC_STUB ISEODictionaryItem_get_Value_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE ISEODictionaryItem_AddValue_Proxy( 
    ISEODictionaryItem __RPC_FAR * This,
    /* [in] */ VARIANT __RPC_FAR *pvarIndex,
    /* [in] */ VARIANT __RPC_FAR *pvarValue);


void __RPC_STUB ISEODictionaryItem_AddValue_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE ISEODictionaryItem_DeleteValue_Proxy( 
    ISEODictionaryItem __RPC_FAR * This,
    /* [in] */ VARIANT __RPC_FAR *pvarIndex);


void __RPC_STUB ISEODictionaryItem_DeleteValue_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [propget][helpstring] */ HRESULT STDMETHODCALLTYPE ISEODictionaryItem_get_Count_Proxy( 
    ISEODictionaryItem __RPC_FAR * This,
    /* [retval][out] */ VARIANT __RPC_FAR *pvarResult);


void __RPC_STUB ISEODictionaryItem_get_Count_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE ISEODictionaryItem_GetStringA_Proxy( 
    ISEODictionaryItem __RPC_FAR * This,
    /* [in] */ DWORD dwIndex,
    /* [out][in] */ DWORD __RPC_FAR *pchCount,
    /* [size_is][out] */ LPSTR pszResult);


void __RPC_STUB ISEODictionaryItem_GetStringA_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE ISEODictionaryItem_GetStringW_Proxy( 
    ISEODictionaryItem __RPC_FAR * This,
    /* [in] */ DWORD dwIndex,
    /* [out][in] */ DWORD __RPC_FAR *pchCount,
    /* [size_is][out] */ LPWSTR pszResult);


void __RPC_STUB ISEODictionaryItem_GetStringW_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE ISEODictionaryItem_AddStringA_Proxy( 
    ISEODictionaryItem __RPC_FAR * This,
    /* [in] */ DWORD dwIndex,
    /* [in] */ LPCSTR pszValue);


void __RPC_STUB ISEODictionaryItem_AddStringA_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE ISEODictionaryItem_AddStringW_Proxy( 
    ISEODictionaryItem __RPC_FAR * This,
    /* [in] */ DWORD dwIndex,
    /* [in] */ LPCWSTR pszValue);


void __RPC_STUB ISEODictionaryItem_AddStringW_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);



#endif 	/* __ISEODictionaryItem_INTERFACE_DEFINED__ */


#ifndef __ISEODictionary_INTERFACE_DEFINED__
#define __ISEODictionary_INTERFACE_DEFINED__

/* interface ISEODictionary */
/* [uuid][unique][object][hidden][helpstring][dual] */ 


EXTERN_C const IID IID_ISEODictionary;

#if defined(__cplusplus) && !defined(CINTERFACE)
    
    MIDL_INTERFACE("d8177b40-7bac-11d0-a9e0-00aa00685c74")
    ISEODictionary : public IDispatch
    {
    public:
        virtual /* [propget][id][helpstring] */ HRESULT STDMETHODCALLTYPE get_Item( 
            /* [in] */ VARIANT __RPC_FAR *pvarName,
            /* [retval][out] */ VARIANT __RPC_FAR *pvarResult) = 0;
        
        virtual /* [propput][helpstring] */ HRESULT STDMETHODCALLTYPE put_Item( 
            /* [in] */ VARIANT __RPC_FAR *pvarName,
            /* [in] */ VARIANT __RPC_FAR *pvarValue) = 0;
        
        virtual /* [hidden][propget][id][helpstring] */ HRESULT STDMETHODCALLTYPE get__NewEnum( 
            /* [retval][out] */ IUnknown __RPC_FAR *__RPC_FAR *ppunkResult) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE GetVariantA( 
            /* [in] */ LPCSTR pszName,
            /* [retval][out] */ VARIANT __RPC_FAR *pvarResult) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE GetVariantW( 
            /* [in] */ LPCWSTR pszName,
            /* [retval][out] */ VARIANT __RPC_FAR *pvarResult) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE SetVariantA( 
            /* [in] */ LPCSTR pszName,
            /* [in] */ VARIANT __RPC_FAR *pvarValue) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE SetVariantW( 
            /* [in] */ LPCWSTR pszName,
            /* [in] */ VARIANT __RPC_FAR *pvarValue) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE GetStringA( 
            /* [in] */ LPCSTR pszName,
            /* [out][in] */ DWORD __RPC_FAR *pchCount,
            /* [size_is][out] */ LPSTR pszResult) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE GetStringW( 
            /* [in] */ LPCWSTR pszName,
            /* [out][in] */ DWORD __RPC_FAR *pchCount,
            /* [size_is][out] */ LPWSTR pszResult) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE SetStringA( 
            /* [in] */ LPCSTR pszName,
            /* [in] */ DWORD chCount,
            /* [size_is][in] */ LPCSTR pszValue) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE SetStringW( 
            /* [in] */ LPCWSTR pszName,
            /* [in] */ DWORD chCount,
            /* [size_is][in] */ LPCWSTR pszValue) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE GetDWordA( 
            /* [in] */ LPCSTR pszName,
            /* [retval][out] */ DWORD __RPC_FAR *pdwResult) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE GetDWordW( 
            /* [in] */ LPCWSTR pszName,
            /* [retval][out] */ DWORD __RPC_FAR *pdwResult) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE SetDWordA( 
            /* [in] */ LPCSTR pszName,
            /* [in] */ DWORD dwValue) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE SetDWordW( 
            /* [in] */ LPCWSTR pszName,
            /* [in] */ DWORD dwValue) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE GetInterfaceA( 
            /* [in] */ LPCSTR pszName,
            /* [in] */ REFIID iidDesired,
            /* [retval][iid_is][out] */ IUnknown __RPC_FAR *__RPC_FAR *ppunkResult) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE GetInterfaceW( 
            /* [in] */ LPCWSTR pszName,
            /* [in] */ REFIID iidDesired,
            /* [retval][iid_is][out] */ IUnknown __RPC_FAR *__RPC_FAR *ppunkResult) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE SetInterfaceA( 
            /* [in] */ LPCSTR pszName,
            /* [unique][in] */ IUnknown __RPC_FAR *punkValue) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE SetInterfaceW( 
            /* [in] */ LPCWSTR pszName,
            /* [unique][in] */ IUnknown __RPC_FAR *punkValue) = 0;
        
    };
    
#else 	/* C style interface */

    typedef struct ISEODictionaryVtbl
    {
        BEGIN_INTERFACE
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *QueryInterface )( 
            ISEODictionary __RPC_FAR * This,
            /* [in] */ REFIID riid,
            /* [iid_is][out] */ void __RPC_FAR *__RPC_FAR *ppvObject);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *AddRef )( 
            ISEODictionary __RPC_FAR * This);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *Release )( 
            ISEODictionary __RPC_FAR * This);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetTypeInfoCount )( 
            ISEODictionary __RPC_FAR * This,
            /* [out] */ UINT __RPC_FAR *pctinfo);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetTypeInfo )( 
            ISEODictionary __RPC_FAR * This,
            /* [in] */ UINT iTInfo,
            /* [in] */ LCID lcid,
            /* [out] */ ITypeInfo __RPC_FAR *__RPC_FAR *ppTInfo);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetIDsOfNames )( 
            ISEODictionary __RPC_FAR * This,
            /* [in] */ REFIID riid,
            /* [size_is][in] */ LPOLESTR __RPC_FAR *rgszNames,
            /* [in] */ UINT cNames,
            /* [in] */ LCID lcid,
            /* [size_is][out] */ DISPID __RPC_FAR *rgDispId);
        
        /* [local] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *Invoke )( 
            ISEODictionary __RPC_FAR * This,
            /* [in] */ DISPID dispIdMember,
            /* [in] */ REFIID riid,
            /* [in] */ LCID lcid,
            /* [in] */ WORD wFlags,
            /* [out][in] */ DISPPARAMS __RPC_FAR *pDispParams,
            /* [out] */ VARIANT __RPC_FAR *pVarResult,
            /* [out] */ EXCEPINFO __RPC_FAR *pExcepInfo,
            /* [out] */ UINT __RPC_FAR *puArgErr);
        
        /* [propget][id][helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *get_Item )( 
            ISEODictionary __RPC_FAR * This,
            /* [in] */ VARIANT __RPC_FAR *pvarName,
            /* [retval][out] */ VARIANT __RPC_FAR *pvarResult);
        
        /* [propput][helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *put_Item )( 
            ISEODictionary __RPC_FAR * This,
            /* [in] */ VARIANT __RPC_FAR *pvarName,
            /* [in] */ VARIANT __RPC_FAR *pvarValue);
        
        /* [hidden][propget][id][helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *get__NewEnum )( 
            ISEODictionary __RPC_FAR * This,
            /* [retval][out] */ IUnknown __RPC_FAR *__RPC_FAR *ppunkResult);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetVariantA )( 
            ISEODictionary __RPC_FAR * This,
            /* [in] */ LPCSTR pszName,
            /* [retval][out] */ VARIANT __RPC_FAR *pvarResult);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetVariantW )( 
            ISEODictionary __RPC_FAR * This,
            /* [in] */ LPCWSTR pszName,
            /* [retval][out] */ VARIANT __RPC_FAR *pvarResult);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *SetVariantA )( 
            ISEODictionary __RPC_FAR * This,
            /* [in] */ LPCSTR pszName,
            /* [in] */ VARIANT __RPC_FAR *pvarValue);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *SetVariantW )( 
            ISEODictionary __RPC_FAR * This,
            /* [in] */ LPCWSTR pszName,
            /* [in] */ VARIANT __RPC_FAR *pvarValue);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetStringA )( 
            ISEODictionary __RPC_FAR * This,
            /* [in] */ LPCSTR pszName,
            /* [out][in] */ DWORD __RPC_FAR *pchCount,
            /* [size_is][out] */ LPSTR pszResult);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetStringW )( 
            ISEODictionary __RPC_FAR * This,
            /* [in] */ LPCWSTR pszName,
            /* [out][in] */ DWORD __RPC_FAR *pchCount,
            /* [size_is][out] */ LPWSTR pszResult);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *SetStringA )( 
            ISEODictionary __RPC_FAR * This,
            /* [in] */ LPCSTR pszName,
            /* [in] */ DWORD chCount,
            /* [size_is][in] */ LPCSTR pszValue);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *SetStringW )( 
            ISEODictionary __RPC_FAR * This,
            /* [in] */ LPCWSTR pszName,
            /* [in] */ DWORD chCount,
            /* [size_is][in] */ LPCWSTR pszValue);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetDWordA )( 
            ISEODictionary __RPC_FAR * This,
            /* [in] */ LPCSTR pszName,
            /* [retval][out] */ DWORD __RPC_FAR *pdwResult);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetDWordW )( 
            ISEODictionary __RPC_FAR * This,
            /* [in] */ LPCWSTR pszName,
            /* [retval][out] */ DWORD __RPC_FAR *pdwResult);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *SetDWordA )( 
            ISEODictionary __RPC_FAR * This,
            /* [in] */ LPCSTR pszName,
            /* [in] */ DWORD dwValue);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *SetDWordW )( 
            ISEODictionary __RPC_FAR * This,
            /* [in] */ LPCWSTR pszName,
            /* [in] */ DWORD dwValue);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetInterfaceA )( 
            ISEODictionary __RPC_FAR * This,
            /* [in] */ LPCSTR pszName,
            /* [in] */ REFIID iidDesired,
            /* [retval][iid_is][out] */ IUnknown __RPC_FAR *__RPC_FAR *ppunkResult);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetInterfaceW )( 
            ISEODictionary __RPC_FAR * This,
            /* [in] */ LPCWSTR pszName,
            /* [in] */ REFIID iidDesired,
            /* [retval][iid_is][out] */ IUnknown __RPC_FAR *__RPC_FAR *ppunkResult);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *SetInterfaceA )( 
            ISEODictionary __RPC_FAR * This,
            /* [in] */ LPCSTR pszName,
            /* [unique][in] */ IUnknown __RPC_FAR *punkValue);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *SetInterfaceW )( 
            ISEODictionary __RPC_FAR * This,
            /* [in] */ LPCWSTR pszName,
            /* [unique][in] */ IUnknown __RPC_FAR *punkValue);
        
        END_INTERFACE
    } ISEODictionaryVtbl;

    interface ISEODictionary
    {
        CONST_VTBL struct ISEODictionaryVtbl __RPC_FAR *lpVtbl;
    };

    

#ifdef COBJMACROS


#define ISEODictionary_QueryInterface(This,riid,ppvObject)	\
    (This)->lpVtbl -> QueryInterface(This,riid,ppvObject)

#define ISEODictionary_AddRef(This)	\
    (This)->lpVtbl -> AddRef(This)

#define ISEODictionary_Release(This)	\
    (This)->lpVtbl -> Release(This)


#define ISEODictionary_GetTypeInfoCount(This,pctinfo)	\
    (This)->lpVtbl -> GetTypeInfoCount(This,pctinfo)

#define ISEODictionary_GetTypeInfo(This,iTInfo,lcid,ppTInfo)	\
    (This)->lpVtbl -> GetTypeInfo(This,iTInfo,lcid,ppTInfo)

#define ISEODictionary_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)	\
    (This)->lpVtbl -> GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)

#define ISEODictionary_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)	\
    (This)->lpVtbl -> Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)


#define ISEODictionary_get_Item(This,pvarName,pvarResult)	\
    (This)->lpVtbl -> get_Item(This,pvarName,pvarResult)

#define ISEODictionary_put_Item(This,pvarName,pvarValue)	\
    (This)->lpVtbl -> put_Item(This,pvarName,pvarValue)

#define ISEODictionary_get__NewEnum(This,ppunkResult)	\
    (This)->lpVtbl -> get__NewEnum(This,ppunkResult)

#define ISEODictionary_GetVariantA(This,pszName,pvarResult)	\
    (This)->lpVtbl -> GetVariantA(This,pszName,pvarResult)

#define ISEODictionary_GetVariantW(This,pszName,pvarResult)	\
    (This)->lpVtbl -> GetVariantW(This,pszName,pvarResult)

#define ISEODictionary_SetVariantA(This,pszName,pvarValue)	\
    (This)->lpVtbl -> SetVariantA(This,pszName,pvarValue)

#define ISEODictionary_SetVariantW(This,pszName,pvarValue)	\
    (This)->lpVtbl -> SetVariantW(This,pszName,pvarValue)

#define ISEODictionary_GetStringA(This,pszName,pchCount,pszResult)	\
    (This)->lpVtbl -> GetStringA(This,pszName,pchCount,pszResult)

#define ISEODictionary_GetStringW(This,pszName,pchCount,pszResult)	\
    (This)->lpVtbl -> GetStringW(This,pszName,pchCount,pszResult)

#define ISEODictionary_SetStringA(This,pszName,chCount,pszValue)	\
    (This)->lpVtbl -> SetStringA(This,pszName,chCount,pszValue)

#define ISEODictionary_SetStringW(This,pszName,chCount,pszValue)	\
    (This)->lpVtbl -> SetStringW(This,pszName,chCount,pszValue)

#define ISEODictionary_GetDWordA(This,pszName,pdwResult)	\
    (This)->lpVtbl -> GetDWordA(This,pszName,pdwResult)

#define ISEODictionary_GetDWordW(This,pszName,pdwResult)	\
    (This)->lpVtbl -> GetDWordW(This,pszName,pdwResult)

#define ISEODictionary_SetDWordA(This,pszName,dwValue)	\
    (This)->lpVtbl -> SetDWordA(This,pszName,dwValue)

#define ISEODictionary_SetDWordW(This,pszName,dwValue)	\
    (This)->lpVtbl -> SetDWordW(This,pszName,dwValue)

#define ISEODictionary_GetInterfaceA(This,pszName,iidDesired,ppunkResult)	\
    (This)->lpVtbl -> GetInterfaceA(This,pszName,iidDesired,ppunkResult)

#define ISEODictionary_GetInterfaceW(This,pszName,iidDesired,ppunkResult)	\
    (This)->lpVtbl -> GetInterfaceW(This,pszName,iidDesired,ppunkResult)

#define ISEODictionary_SetInterfaceA(This,pszName,punkValue)	\
    (This)->lpVtbl -> SetInterfaceA(This,pszName,punkValue)

#define ISEODictionary_SetInterfaceW(This,pszName,punkValue)	\
    (This)->lpVtbl -> SetInterfaceW(This,pszName,punkValue)

#endif /* COBJMACROS */


#endif 	/* C style interface */



/* [propget][id][helpstring] */ HRESULT STDMETHODCALLTYPE ISEODictionary_get_Item_Proxy( 
    ISEODictionary __RPC_FAR * This,
    /* [in] */ VARIANT __RPC_FAR *pvarName,
    /* [retval][out] */ VARIANT __RPC_FAR *pvarResult);


void __RPC_STUB ISEODictionary_get_Item_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [propput][helpstring] */ HRESULT STDMETHODCALLTYPE ISEODictionary_put_Item_Proxy( 
    ISEODictionary __RPC_FAR * This,
    /* [in] */ VARIANT __RPC_FAR *pvarName,
    /* [in] */ VARIANT __RPC_FAR *pvarValue);


void __RPC_STUB ISEODictionary_put_Item_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [hidden][propget][id][helpstring] */ HRESULT STDMETHODCALLTYPE ISEODictionary_get__NewEnum_Proxy( 
    ISEODictionary __RPC_FAR * This,
    /* [retval][out] */ IUnknown __RPC_FAR *__RPC_FAR *ppunkResult);


void __RPC_STUB ISEODictionary_get__NewEnum_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE ISEODictionary_GetVariantA_Proxy( 
    ISEODictionary __RPC_FAR * This,
    /* [in] */ LPCSTR pszName,
    /* [retval][out] */ VARIANT __RPC_FAR *pvarResult);


void __RPC_STUB ISEODictionary_GetVariantA_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE ISEODictionary_GetVariantW_Proxy( 
    ISEODictionary __RPC_FAR * This,
    /* [in] */ LPCWSTR pszName,
    /* [retval][out] */ VARIANT __RPC_FAR *pvarResult);


void __RPC_STUB ISEODictionary_GetVariantW_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE ISEODictionary_SetVariantA_Proxy( 
    ISEODictionary __RPC_FAR * This,
    /* [in] */ LPCSTR pszName,
    /* [in] */ VARIANT __RPC_FAR *pvarValue);


void __RPC_STUB ISEODictionary_SetVariantA_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE ISEODictionary_SetVariantW_Proxy( 
    ISEODictionary __RPC_FAR * This,
    /* [in] */ LPCWSTR pszName,
    /* [in] */ VARIANT __RPC_FAR *pvarValue);


void __RPC_STUB ISEODictionary_SetVariantW_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE ISEODictionary_GetStringA_Proxy( 
    ISEODictionary __RPC_FAR * This,
    /* [in] */ LPCSTR pszName,
    /* [out][in] */ DWORD __RPC_FAR *pchCount,
    /* [size_is][out] */ LPSTR pszResult);


void __RPC_STUB ISEODictionary_GetStringA_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE ISEODictionary_GetStringW_Proxy( 
    ISEODictionary __RPC_FAR * This,
    /* [in] */ LPCWSTR pszName,
    /* [out][in] */ DWORD __RPC_FAR *pchCount,
    /* [size_is][out] */ LPWSTR pszResult);


void __RPC_STUB ISEODictionary_GetStringW_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE ISEODictionary_SetStringA_Proxy( 
    ISEODictionary __RPC_FAR * This,
    /* [in] */ LPCSTR pszName,
    /* [in] */ DWORD chCount,
    /* [size_is][in] */ LPCSTR pszValue);


void __RPC_STUB ISEODictionary_SetStringA_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE ISEODictionary_SetStringW_Proxy( 
    ISEODictionary __RPC_FAR * This,
    /* [in] */ LPCWSTR pszName,
    /* [in] */ DWORD chCount,
    /* [size_is][in] */ LPCWSTR pszValue);


void __RPC_STUB ISEODictionary_SetStringW_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE ISEODictionary_GetDWordA_Proxy( 
    ISEODictionary __RPC_FAR * This,
    /* [in] */ LPCSTR pszName,
    /* [retval][out] */ DWORD __RPC_FAR *pdwResult);


void __RPC_STUB ISEODictionary_GetDWordA_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE ISEODictionary_GetDWordW_Proxy( 
    ISEODictionary __RPC_FAR * This,
    /* [in] */ LPCWSTR pszName,
    /* [retval][out] */ DWORD __RPC_FAR *pdwResult);


void __RPC_STUB ISEODictionary_GetDWordW_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE ISEODictionary_SetDWordA_Proxy( 
    ISEODictionary __RPC_FAR * This,
    /* [in] */ LPCSTR pszName,
    /* [in] */ DWORD dwValue);


void __RPC_STUB ISEODictionary_SetDWordA_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE ISEODictionary_SetDWordW_Proxy( 
    ISEODictionary __RPC_FAR * This,
    /* [in] */ LPCWSTR pszName,
    /* [in] */ DWORD dwValue);


void __RPC_STUB ISEODictionary_SetDWordW_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE ISEODictionary_GetInterfaceA_Proxy( 
    ISEODictionary __RPC_FAR * This,
    /* [in] */ LPCSTR pszName,
    /* [in] */ REFIID iidDesired,
    /* [retval][iid_is][out] */ IUnknown __RPC_FAR *__RPC_FAR *ppunkResult);


void __RPC_STUB ISEODictionary_GetInterfaceA_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE ISEODictionary_GetInterfaceW_Proxy( 
    ISEODictionary __RPC_FAR * This,
    /* [in] */ LPCWSTR pszName,
    /* [in] */ REFIID iidDesired,
    /* [retval][iid_is][out] */ IUnknown __RPC_FAR *__RPC_FAR *ppunkResult);


void __RPC_STUB ISEODictionary_GetInterfaceW_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE ISEODictionary_SetInterfaceA_Proxy( 
    ISEODictionary __RPC_FAR * This,
    /* [in] */ LPCSTR pszName,
    /* [unique][in] */ IUnknown __RPC_FAR *punkValue);


void __RPC_STUB ISEODictionary_SetInterfaceA_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE ISEODictionary_SetInterfaceW_Proxy( 
    ISEODictionary __RPC_FAR * This,
    /* [in] */ LPCWSTR pszName,
    /* [unique][in] */ IUnknown __RPC_FAR *punkValue);


void __RPC_STUB ISEODictionary_SetInterfaceW_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);



#endif 	/* __ISEODictionary_INTERFACE_DEFINED__ */


#ifndef __IEventLock_INTERFACE_DEFINED__
#define __IEventLock_INTERFACE_DEFINED__

/* interface IEventLock */
/* [uuid][hidden][unique][object][helpstring][dual] */ 


EXTERN_C const IID IID_IEventLock;

#if defined(__cplusplus) && !defined(CINTERFACE)
    
    MIDL_INTERFACE("1b7058f0-af88-11d0-a9eb-00aa00685c74")
    IEventLock : public IDispatch
    {
    public:
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE LockRead( 
            /* [in] */ int iTimeoutMS) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE UnlockRead( void) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE LockWrite( 
            /* [in] */ int iTimeoutMS) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE UnlockWrite( void) = 0;
        
    };
    
#else 	/* C style interface */

    typedef struct IEventLockVtbl
    {
        BEGIN_INTERFACE
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *QueryInterface )( 
            IEventLock __RPC_FAR * This,
            /* [in] */ REFIID riid,
            /* [iid_is][out] */ void __RPC_FAR *__RPC_FAR *ppvObject);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *AddRef )( 
            IEventLock __RPC_FAR * This);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *Release )( 
            IEventLock __RPC_FAR * This);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetTypeInfoCount )( 
            IEventLock __RPC_FAR * This,
            /* [out] */ UINT __RPC_FAR *pctinfo);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetTypeInfo )( 
            IEventLock __RPC_FAR * This,
            /* [in] */ UINT iTInfo,
            /* [in] */ LCID lcid,
            /* [out] */ ITypeInfo __RPC_FAR *__RPC_FAR *ppTInfo);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetIDsOfNames )( 
            IEventLock __RPC_FAR * This,
            /* [in] */ REFIID riid,
            /* [size_is][in] */ LPOLESTR __RPC_FAR *rgszNames,
            /* [in] */ UINT cNames,
            /* [in] */ LCID lcid,
            /* [size_is][out] */ DISPID __RPC_FAR *rgDispId);
        
        /* [local] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *Invoke )( 
            IEventLock __RPC_FAR * This,
            /* [in] */ DISPID dispIdMember,
            /* [in] */ REFIID riid,
            /* [in] */ LCID lcid,
            /* [in] */ WORD wFlags,
            /* [out][in] */ DISPPARAMS __RPC_FAR *pDispParams,
            /* [out] */ VARIANT __RPC_FAR *pVarResult,
            /* [out] */ EXCEPINFO __RPC_FAR *pExcepInfo,
            /* [out] */ UINT __RPC_FAR *puArgErr);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *LockRead )( 
            IEventLock __RPC_FAR * This,
            /* [in] */ int iTimeoutMS);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *UnlockRead )( 
            IEventLock __RPC_FAR * This);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *LockWrite )( 
            IEventLock __RPC_FAR * This,
            /* [in] */ int iTimeoutMS);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *UnlockWrite )( 
            IEventLock __RPC_FAR * This);
        
        END_INTERFACE
    } IEventLockVtbl;

    interface IEventLock
    {
        CONST_VTBL struct IEventLockVtbl __RPC_FAR *lpVtbl;
    };

    

#ifdef COBJMACROS


#define IEventLock_QueryInterface(This,riid,ppvObject)	\
    (This)->lpVtbl -> QueryInterface(This,riid,ppvObject)

#define IEventLock_AddRef(This)	\
    (This)->lpVtbl -> AddRef(This)

#define IEventLock_Release(This)	\
    (This)->lpVtbl -> Release(This)


#define IEventLock_GetTypeInfoCount(This,pctinfo)	\
    (This)->lpVtbl -> GetTypeInfoCount(This,pctinfo)

#define IEventLock_GetTypeInfo(This,iTInfo,lcid,ppTInfo)	\
    (This)->lpVtbl -> GetTypeInfo(This,iTInfo,lcid,ppTInfo)

#define IEventLock_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)	\
    (This)->lpVtbl -> GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)

#define IEventLock_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)	\
    (This)->lpVtbl -> Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)


#define IEventLock_LockRead(This,iTimeoutMS)	\
    (This)->lpVtbl -> LockRead(This,iTimeoutMS)

#define IEventLock_UnlockRead(This)	\
    (This)->lpVtbl -> UnlockRead(This)

#define IEventLock_LockWrite(This,iTimeoutMS)	\
    (This)->lpVtbl -> LockWrite(This,iTimeoutMS)

#define IEventLock_UnlockWrite(This)	\
    (This)->lpVtbl -> UnlockWrite(This)

#endif /* COBJMACROS */


#endif 	/* C style interface */



/* [helpstring] */ HRESULT STDMETHODCALLTYPE IEventLock_LockRead_Proxy( 
    IEventLock __RPC_FAR * This,
    /* [in] */ int iTimeoutMS);


void __RPC_STUB IEventLock_LockRead_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IEventLock_UnlockRead_Proxy( 
    IEventLock __RPC_FAR * This);


void __RPC_STUB IEventLock_UnlockRead_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IEventLock_LockWrite_Proxy( 
    IEventLock __RPC_FAR * This,
    /* [in] */ int iTimeoutMS);


void __RPC_STUB IEventLock_LockWrite_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IEventLock_UnlockWrite_Proxy( 
    IEventLock __RPC_FAR * This);


void __RPC_STUB IEventLock_UnlockWrite_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);



#endif 	/* __IEventLock_INTERFACE_DEFINED__ */


#ifndef __ISEORouter_INTERFACE_DEFINED__
#define __ISEORouter_INTERFACE_DEFINED__

/* interface ISEORouter */
/* [uuid][unique][object][hidden][helpstring] */ 


EXTERN_C const IID IID_ISEORouter;

#if defined(__cplusplus) && !defined(CINTERFACE)
    
    MIDL_INTERFACE("2b6ac0f0-7e03-11d0-a9e0-00aa00685c74")
    ISEORouter : public IUnknown
    {
    public:
        virtual /* [propget][helpstring] */ HRESULT STDMETHODCALLTYPE get_Database( 
            /* [retval][out] */ ISEODictionary __RPC_FAR *__RPC_FAR *ppdictResult) = 0;
        
        virtual /* [propput][helpstring] */ HRESULT STDMETHODCALLTYPE put_Database( 
            /* [unique][in] */ ISEODictionary __RPC_FAR *pdictDatabase) = 0;
        
        virtual /* [propget][helpstring] */ HRESULT STDMETHODCALLTYPE get_Server( 
            /* [retval][out] */ ISEODictionary __RPC_FAR *__RPC_FAR *ppdictResult) = 0;
        
        virtual /* [propput][helpstring] */ HRESULT STDMETHODCALLTYPE put_Server( 
            /* [unique][in] */ ISEODictionary __RPC_FAR *pdictServer) = 0;
        
        virtual /* [propget][helpstring] */ HRESULT STDMETHODCALLTYPE get_Applications( 
            /* [retval][out] */ ISEODictionary __RPC_FAR *__RPC_FAR *ppdictResult) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE GetDispatcher( 
            /* [in] */ REFIID iidEvent,
            /* [in] */ REFIID iidDesired,
            /* [retval][iid_is][out] */ IUnknown __RPC_FAR *__RPC_FAR *ppUnkResult) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE GetDispatcherByCLSID( 
            /* [in] */ REFCLSID clsidDispatcher,
            /* [in] */ REFIID iidEvent,
            /* [in] */ REFIID iidDesired,
            /* [retval][iid_is][out] */ IUnknown __RPC_FAR *__RPC_FAR *ppUnkResult) = 0;
        
    };
    
#else 	/* C style interface */

    typedef struct ISEORouterVtbl
    {
        BEGIN_INTERFACE
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *QueryInterface )( 
            ISEORouter __RPC_FAR * This,
            /* [in] */ REFIID riid,
            /* [iid_is][out] */ void __RPC_FAR *__RPC_FAR *ppvObject);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *AddRef )( 
            ISEORouter __RPC_FAR * This);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *Release )( 
            ISEORouter __RPC_FAR * This);
        
        /* [propget][helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *get_Database )( 
            ISEORouter __RPC_FAR * This,
            /* [retval][out] */ ISEODictionary __RPC_FAR *__RPC_FAR *ppdictResult);
        
        /* [propput][helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *put_Database )( 
            ISEORouter __RPC_FAR * This,
            /* [unique][in] */ ISEODictionary __RPC_FAR *pdictDatabase);
        
        /* [propget][helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *get_Server )( 
            ISEORouter __RPC_FAR * This,
            /* [retval][out] */ ISEODictionary __RPC_FAR *__RPC_FAR *ppdictResult);
        
        /* [propput][helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *put_Server )( 
            ISEORouter __RPC_FAR * This,
            /* [unique][in] */ ISEODictionary __RPC_FAR *pdictServer);
        
        /* [propget][helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *get_Applications )( 
            ISEORouter __RPC_FAR * This,
            /* [retval][out] */ ISEODictionary __RPC_FAR *__RPC_FAR *ppdictResult);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetDispatcher )( 
            ISEORouter __RPC_FAR * This,
            /* [in] */ REFIID iidEvent,
            /* [in] */ REFIID iidDesired,
            /* [retval][iid_is][out] */ IUnknown __RPC_FAR *__RPC_FAR *ppUnkResult);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetDispatcherByCLSID )( 
            ISEORouter __RPC_FAR * This,
            /* [in] */ REFCLSID clsidDispatcher,
            /* [in] */ REFIID iidEvent,
            /* [in] */ REFIID iidDesired,
            /* [retval][iid_is][out] */ IUnknown __RPC_FAR *__RPC_FAR *ppUnkResult);
        
        END_INTERFACE
    } ISEORouterVtbl;

    interface ISEORouter
    {
        CONST_VTBL struct ISEORouterVtbl __RPC_FAR *lpVtbl;
    };

    

#ifdef COBJMACROS


#define ISEORouter_QueryInterface(This,riid,ppvObject)	\
    (This)->lpVtbl -> QueryInterface(This,riid,ppvObject)

#define ISEORouter_AddRef(This)	\
    (This)->lpVtbl -> AddRef(This)

#define ISEORouter_Release(This)	\
    (This)->lpVtbl -> Release(This)


#define ISEORouter_get_Database(This,ppdictResult)	\
    (This)->lpVtbl -> get_Database(This,ppdictResult)

#define ISEORouter_put_Database(This,pdictDatabase)	\
    (This)->lpVtbl -> put_Database(This,pdictDatabase)

#define ISEORouter_get_Server(This,ppdictResult)	\
    (This)->lpVtbl -> get_Server(This,ppdictResult)

#define ISEORouter_put_Server(This,pdictServer)	\
    (This)->lpVtbl -> put_Server(This,pdictServer)

#define ISEORouter_get_Applications(This,ppdictResult)	\
    (This)->lpVtbl -> get_Applications(This,ppdictResult)

#define ISEORouter_GetDispatcher(This,iidEvent,iidDesired,ppUnkResult)	\
    (This)->lpVtbl -> GetDispatcher(This,iidEvent,iidDesired,ppUnkResult)

#define ISEORouter_GetDispatcherByCLSID(This,clsidDispatcher,iidEvent,iidDesired,ppUnkResult)	\
    (This)->lpVtbl -> GetDispatcherByCLSID(This,clsidDispatcher,iidEvent,iidDesired,ppUnkResult)

#endif /* COBJMACROS */


#endif 	/* C style interface */



/* [propget][helpstring] */ HRESULT STDMETHODCALLTYPE ISEORouter_get_Database_Proxy( 
    ISEORouter __RPC_FAR * This,
    /* [retval][out] */ ISEODictionary __RPC_FAR *__RPC_FAR *ppdictResult);


void __RPC_STUB ISEORouter_get_Database_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [propput][helpstring] */ HRESULT STDMETHODCALLTYPE ISEORouter_put_Database_Proxy( 
    ISEORouter __RPC_FAR * This,
    /* [unique][in] */ ISEODictionary __RPC_FAR *pdictDatabase);


void __RPC_STUB ISEORouter_put_Database_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [propget][helpstring] */ HRESULT STDMETHODCALLTYPE ISEORouter_get_Server_Proxy( 
    ISEORouter __RPC_FAR * This,
    /* [retval][out] */ ISEODictionary __RPC_FAR *__RPC_FAR *ppdictResult);


void __RPC_STUB ISEORouter_get_Server_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [propput][helpstring] */ HRESULT STDMETHODCALLTYPE ISEORouter_put_Server_Proxy( 
    ISEORouter __RPC_FAR * This,
    /* [unique][in] */ ISEODictionary __RPC_FAR *pdictServer);


void __RPC_STUB ISEORouter_put_Server_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [propget][helpstring] */ HRESULT STDMETHODCALLTYPE ISEORouter_get_Applications_Proxy( 
    ISEORouter __RPC_FAR * This,
    /* [retval][out] */ ISEODictionary __RPC_FAR *__RPC_FAR *ppdictResult);


void __RPC_STUB ISEORouter_get_Applications_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE ISEORouter_GetDispatcher_Proxy( 
    ISEORouter __RPC_FAR * This,
    /* [in] */ REFIID iidEvent,
    /* [in] */ REFIID iidDesired,
    /* [retval][iid_is][out] */ IUnknown __RPC_FAR *__RPC_FAR *ppUnkResult);


void __RPC_STUB ISEORouter_GetDispatcher_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE ISEORouter_GetDispatcherByCLSID_Proxy( 
    ISEORouter __RPC_FAR * This,
    /* [in] */ REFCLSID clsidDispatcher,
    /* [in] */ REFIID iidEvent,
    /* [in] */ REFIID iidDesired,
    /* [retval][iid_is][out] */ IUnknown __RPC_FAR *__RPC_FAR *ppUnkResult);


void __RPC_STUB ISEORouter_GetDispatcherByCLSID_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);



#endif 	/* __ISEORouter_INTERFACE_DEFINED__ */


#ifndef __IMCISMessageFilter_INTERFACE_DEFINED__
#define __IMCISMessageFilter_INTERFACE_DEFINED__

/* interface IMCISMessageFilter */
/* [uuid][unique][object][hidden][helpstring] */ 


EXTERN_C const IID IID_IMCISMessageFilter;

#if defined(__cplusplus) && !defined(CINTERFACE)
    
    MIDL_INTERFACE("f174e5b0-9046-11d0-a9e8-00aa00685c74")
    IMCISMessageFilter : public IUnknown
    {
    public:
        virtual HRESULT STDMETHODCALLTYPE OnMessage( 
            /* [unique][in] */ IStream __RPC_FAR *pstreamMessage,
            /* [unique][in] */ ISEODictionary __RPC_FAR *pdictEnvelope,
            /* [unique][in] */ ISEODictionary __RPC_FAR *pdictBinding) = 0;
        
    };
    
#else 	/* C style interface */

    typedef struct IMCISMessageFilterVtbl
    {
        BEGIN_INTERFACE
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *QueryInterface )( 
            IMCISMessageFilter __RPC_FAR * This,
            /* [in] */ REFIID riid,
            /* [iid_is][out] */ void __RPC_FAR *__RPC_FAR *ppvObject);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *AddRef )( 
            IMCISMessageFilter __RPC_FAR * This);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *Release )( 
            IMCISMessageFilter __RPC_FAR * This);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *OnMessage )( 
            IMCISMessageFilter __RPC_FAR * This,
            /* [unique][in] */ IStream __RPC_FAR *pstreamMessage,
            /* [unique][in] */ ISEODictionary __RPC_FAR *pdictEnvelope,
            /* [unique][in] */ ISEODictionary __RPC_FAR *pdictBinding);
        
        END_INTERFACE
    } IMCISMessageFilterVtbl;

    interface IMCISMessageFilter
    {
        CONST_VTBL struct IMCISMessageFilterVtbl __RPC_FAR *lpVtbl;
    };

    

#ifdef COBJMACROS


#define IMCISMessageFilter_QueryInterface(This,riid,ppvObject)	\
    (This)->lpVtbl -> QueryInterface(This,riid,ppvObject)

#define IMCISMessageFilter_AddRef(This)	\
    (This)->lpVtbl -> AddRef(This)

#define IMCISMessageFilter_Release(This)	\
    (This)->lpVtbl -> Release(This)


#define IMCISMessageFilter_OnMessage(This,pstreamMessage,pdictEnvelope,pdictBinding)	\
    (This)->lpVtbl -> OnMessage(This,pstreamMessage,pdictEnvelope,pdictBinding)

#endif /* COBJMACROS */


#endif 	/* C style interface */



HRESULT STDMETHODCALLTYPE IMCISMessageFilter_OnMessage_Proxy( 
    IMCISMessageFilter __RPC_FAR * This,
    /* [unique][in] */ IStream __RPC_FAR *pstreamMessage,
    /* [unique][in] */ ISEODictionary __RPC_FAR *pdictEnvelope,
    /* [unique][in] */ ISEODictionary __RPC_FAR *pdictBinding);


void __RPC_STUB IMCISMessageFilter_OnMessage_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);



#endif 	/* __IMCISMessageFilter_INTERFACE_DEFINED__ */


#ifndef __ISEOBindingRuleEngine_INTERFACE_DEFINED__
#define __ISEOBindingRuleEngine_INTERFACE_DEFINED__

/* interface ISEOBindingRuleEngine */
/* [uuid][unique][object][hidden][helpstring] */ 


EXTERN_C const IID IID_ISEOBindingRuleEngine;

#if defined(__cplusplus) && !defined(CINTERFACE)
    
    MIDL_INTERFACE("f2d1daf0-2236-11d0-a9ce-00aa00685c74")
    ISEOBindingRuleEngine : public IUnknown
    {
    public:
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE Evaluate( 
            /* [unique][in] */ ISEODictionary __RPC_FAR *pdictEvent,
            /* [unique][in] */ ISEODictionary __RPC_FAR *pdictBinding) = 0;
        
    };
    
#else 	/* C style interface */

    typedef struct ISEOBindingRuleEngineVtbl
    {
        BEGIN_INTERFACE
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *QueryInterface )( 
            ISEOBindingRuleEngine __RPC_FAR * This,
            /* [in] */ REFIID riid,
            /* [iid_is][out] */ void __RPC_FAR *__RPC_FAR *ppvObject);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *AddRef )( 
            ISEOBindingRuleEngine __RPC_FAR * This);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *Release )( 
            ISEOBindingRuleEngine __RPC_FAR * This);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *Evaluate )( 
            ISEOBindingRuleEngine __RPC_FAR * This,
            /* [unique][in] */ ISEODictionary __RPC_FAR *pdictEvent,
            /* [unique][in] */ ISEODictionary __RPC_FAR *pdictBinding);
        
        END_INTERFACE
    } ISEOBindingRuleEngineVtbl;

    interface ISEOBindingRuleEngine
    {
        CONST_VTBL struct ISEOBindingRuleEngineVtbl __RPC_FAR *lpVtbl;
    };

    

#ifdef COBJMACROS


#define ISEOBindingRuleEngine_QueryInterface(This,riid,ppvObject)	\
    (This)->lpVtbl -> QueryInterface(This,riid,ppvObject)

#define ISEOBindingRuleEngine_AddRef(This)	\
    (This)->lpVtbl -> AddRef(This)

#define ISEOBindingRuleEngine_Release(This)	\
    (This)->lpVtbl -> Release(This)


#define ISEOBindingRuleEngine_Evaluate(This,pdictEvent,pdictBinding)	\
    (This)->lpVtbl -> Evaluate(This,pdictEvent,pdictBinding)

#endif /* COBJMACROS */


#endif 	/* C style interface */



/* [helpstring] */ HRESULT STDMETHODCALLTYPE ISEOBindingRuleEngine_Evaluate_Proxy( 
    ISEOBindingRuleEngine __RPC_FAR * This,
    /* [unique][in] */ ISEODictionary __RPC_FAR *pdictEvent,
    /* [unique][in] */ ISEODictionary __RPC_FAR *pdictBinding);


void __RPC_STUB ISEOBindingRuleEngine_Evaluate_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);



#endif 	/* __ISEOBindingRuleEngine_INTERFACE_DEFINED__ */


#ifndef __ISEOEventSink_INTERFACE_DEFINED__
#define __ISEOEventSink_INTERFACE_DEFINED__

/* interface ISEOEventSink */
/* [uuid][unique][object][hidden][helpstring] */ 


EXTERN_C const IID IID_ISEOEventSink;

#if defined(__cplusplus) && !defined(CINTERFACE)
    
    MIDL_INTERFACE("1cab4c20-94f4-11d0-a9e8-00aa00685c74")
    ISEOEventSink : public IUnknown
    {
    public:
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE OnEvent( void) = 0;
        
    };
    
#else 	/* C style interface */

    typedef struct ISEOEventSinkVtbl
    {
        BEGIN_INTERFACE
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *QueryInterface )( 
            ISEOEventSink __RPC_FAR * This,
            /* [in] */ REFIID riid,
            /* [iid_is][out] */ void __RPC_FAR *__RPC_FAR *ppvObject);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *AddRef )( 
            ISEOEventSink __RPC_FAR * This);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *Release )( 
            ISEOEventSink __RPC_FAR * This);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *OnEvent )( 
            ISEOEventSink __RPC_FAR * This);
        
        END_INTERFACE
    } ISEOEventSinkVtbl;

    interface ISEOEventSink
    {
        CONST_VTBL struct ISEOEventSinkVtbl __RPC_FAR *lpVtbl;
    };

    

#ifdef COBJMACROS


#define ISEOEventSink_QueryInterface(This,riid,ppvObject)	\
    (This)->lpVtbl -> QueryInterface(This,riid,ppvObject)

#define ISEOEventSink_AddRef(This)	\
    (This)->lpVtbl -> AddRef(This)

#define ISEOEventSink_Release(This)	\
    (This)->lpVtbl -> Release(This)


#define ISEOEventSink_OnEvent(This)	\
    (This)->lpVtbl -> OnEvent(This)

#endif /* COBJMACROS */


#endif 	/* C style interface */



/* [helpstring] */ HRESULT STDMETHODCALLTYPE ISEOEventSink_OnEvent_Proxy( 
    ISEOEventSink __RPC_FAR * This);


void __RPC_STUB ISEOEventSink_OnEvent_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);



#endif 	/* __ISEOEventSink_INTERFACE_DEFINED__ */


#ifndef __ISEORegDictionary_INTERFACE_DEFINED__
#define __ISEORegDictionary_INTERFACE_DEFINED__

/* interface ISEORegDictionary */
/* [uuid][unique][object][helpstring] */ 

typedef long SEO_HKEY;


EXTERN_C const IID IID_ISEORegDictionary;

#if defined(__cplusplus) && !defined(CINTERFACE)
    
    MIDL_INTERFACE("347cacb0-2d1e-11d0-a9cf-00aa00685c74")
    ISEORegDictionary : public ISEODictionary
    {
    public:
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE Load( 
            /* [in] */ LPCOLESTR pszMachine,
            /* [in] */ SEO_HKEY skBaseKey,
            /* [in] */ LPCOLESTR pszSubKey,
            /* [unique][in] */ IErrorLog __RPC_FAR *pErrorLog) = 0;
        
    };
    
#else 	/* C style interface */

    typedef struct ISEORegDictionaryVtbl
    {
        BEGIN_INTERFACE
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *QueryInterface )( 
            ISEORegDictionary __RPC_FAR * This,
            /* [in] */ REFIID riid,
            /* [iid_is][out] */ void __RPC_FAR *__RPC_FAR *ppvObject);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *AddRef )( 
            ISEORegDictionary __RPC_FAR * This);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *Release )( 
            ISEORegDictionary __RPC_FAR * This);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetTypeInfoCount )( 
            ISEORegDictionary __RPC_FAR * This,
            /* [out] */ UINT __RPC_FAR *pctinfo);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetTypeInfo )( 
            ISEORegDictionary __RPC_FAR * This,
            /* [in] */ UINT iTInfo,
            /* [in] */ LCID lcid,
            /* [out] */ ITypeInfo __RPC_FAR *__RPC_FAR *ppTInfo);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetIDsOfNames )( 
            ISEORegDictionary __RPC_FAR * This,
            /* [in] */ REFIID riid,
            /* [size_is][in] */ LPOLESTR __RPC_FAR *rgszNames,
            /* [in] */ UINT cNames,
            /* [in] */ LCID lcid,
            /* [size_is][out] */ DISPID __RPC_FAR *rgDispId);
        
        /* [local] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *Invoke )( 
            ISEORegDictionary __RPC_FAR * This,
            /* [in] */ DISPID dispIdMember,
            /* [in] */ REFIID riid,
            /* [in] */ LCID lcid,
            /* [in] */ WORD wFlags,
            /* [out][in] */ DISPPARAMS __RPC_FAR *pDispParams,
            /* [out] */ VARIANT __RPC_FAR *pVarResult,
            /* [out] */ EXCEPINFO __RPC_FAR *pExcepInfo,
            /* [out] */ UINT __RPC_FAR *puArgErr);
        
        /* [propget][id][helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *get_Item )( 
            ISEORegDictionary __RPC_FAR * This,
            /* [in] */ VARIANT __RPC_FAR *pvarName,
            /* [retval][out] */ VARIANT __RPC_FAR *pvarResult);
        
        /* [propput][helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *put_Item )( 
            ISEORegDictionary __RPC_FAR * This,
            /* [in] */ VARIANT __RPC_FAR *pvarName,
            /* [in] */ VARIANT __RPC_FAR *pvarValue);
        
        /* [hidden][propget][id][helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *get__NewEnum )( 
            ISEORegDictionary __RPC_FAR * This,
            /* [retval][out] */ IUnknown __RPC_FAR *__RPC_FAR *ppunkResult);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetVariantA )( 
            ISEORegDictionary __RPC_FAR * This,
            /* [in] */ LPCSTR pszName,
            /* [retval][out] */ VARIANT __RPC_FAR *pvarResult);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetVariantW )( 
            ISEORegDictionary __RPC_FAR * This,
            /* [in] */ LPCWSTR pszName,
            /* [retval][out] */ VARIANT __RPC_FAR *pvarResult);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *SetVariantA )( 
            ISEORegDictionary __RPC_FAR * This,
            /* [in] */ LPCSTR pszName,
            /* [in] */ VARIANT __RPC_FAR *pvarValue);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *SetVariantW )( 
            ISEORegDictionary __RPC_FAR * This,
            /* [in] */ LPCWSTR pszName,
            /* [in] */ VARIANT __RPC_FAR *pvarValue);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetStringA )( 
            ISEORegDictionary __RPC_FAR * This,
            /* [in] */ LPCSTR pszName,
            /* [out][in] */ DWORD __RPC_FAR *pchCount,
            /* [size_is][out] */ LPSTR pszResult);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetStringW )( 
            ISEORegDictionary __RPC_FAR * This,
            /* [in] */ LPCWSTR pszName,
            /* [out][in] */ DWORD __RPC_FAR *pchCount,
            /* [size_is][out] */ LPWSTR pszResult);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *SetStringA )( 
            ISEORegDictionary __RPC_FAR * This,
            /* [in] */ LPCSTR pszName,
            /* [in] */ DWORD chCount,
            /* [size_is][in] */ LPCSTR pszValue);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *SetStringW )( 
            ISEORegDictionary __RPC_FAR * This,
            /* [in] */ LPCWSTR pszName,
            /* [in] */ DWORD chCount,
            /* [size_is][in] */ LPCWSTR pszValue);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetDWordA )( 
            ISEORegDictionary __RPC_FAR * This,
            /* [in] */ LPCSTR pszName,
            /* [retval][out] */ DWORD __RPC_FAR *pdwResult);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetDWordW )( 
            ISEORegDictionary __RPC_FAR * This,
            /* [in] */ LPCWSTR pszName,
            /* [retval][out] */ DWORD __RPC_FAR *pdwResult);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *SetDWordA )( 
            ISEORegDictionary __RPC_FAR * This,
            /* [in] */ LPCSTR pszName,
            /* [in] */ DWORD dwValue);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *SetDWordW )( 
            ISEORegDictionary __RPC_FAR * This,
            /* [in] */ LPCWSTR pszName,
            /* [in] */ DWORD dwValue);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetInterfaceA )( 
            ISEORegDictionary __RPC_FAR * This,
            /* [in] */ LPCSTR pszName,
            /* [in] */ REFIID iidDesired,
            /* [retval][iid_is][out] */ IUnknown __RPC_FAR *__RPC_FAR *ppunkResult);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetInterfaceW )( 
            ISEORegDictionary __RPC_FAR * This,
            /* [in] */ LPCWSTR pszName,
            /* [in] */ REFIID iidDesired,
            /* [retval][iid_is][out] */ IUnknown __RPC_FAR *__RPC_FAR *ppunkResult);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *SetInterfaceA )( 
            ISEORegDictionary __RPC_FAR * This,
            /* [in] */ LPCSTR pszName,
            /* [unique][in] */ IUnknown __RPC_FAR *punkValue);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *SetInterfaceW )( 
            ISEORegDictionary __RPC_FAR * This,
            /* [in] */ LPCWSTR pszName,
            /* [unique][in] */ IUnknown __RPC_FAR *punkValue);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *Load )( 
            ISEORegDictionary __RPC_FAR * This,
            /* [in] */ LPCOLESTR pszMachine,
            /* [in] */ SEO_HKEY skBaseKey,
            /* [in] */ LPCOLESTR pszSubKey,
            /* [unique][in] */ IErrorLog __RPC_FAR *pErrorLog);
        
        END_INTERFACE
    } ISEORegDictionaryVtbl;

    interface ISEORegDictionary
    {
        CONST_VTBL struct ISEORegDictionaryVtbl __RPC_FAR *lpVtbl;
    };

    

#ifdef COBJMACROS


#define ISEORegDictionary_QueryInterface(This,riid,ppvObject)	\
    (This)->lpVtbl -> QueryInterface(This,riid,ppvObject)

#define ISEORegDictionary_AddRef(This)	\
    (This)->lpVtbl -> AddRef(This)

#define ISEORegDictionary_Release(This)	\
    (This)->lpVtbl -> Release(This)


#define ISEORegDictionary_GetTypeInfoCount(This,pctinfo)	\
    (This)->lpVtbl -> GetTypeInfoCount(This,pctinfo)

#define ISEORegDictionary_GetTypeInfo(This,iTInfo,lcid,ppTInfo)	\
    (This)->lpVtbl -> GetTypeInfo(This,iTInfo,lcid,ppTInfo)

#define ISEORegDictionary_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)	\
    (This)->lpVtbl -> GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)

#define ISEORegDictionary_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)	\
    (This)->lpVtbl -> Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)


#define ISEORegDictionary_get_Item(This,pvarName,pvarResult)	\
    (This)->lpVtbl -> get_Item(This,pvarName,pvarResult)

#define ISEORegDictionary_put_Item(This,pvarName,pvarValue)	\
    (This)->lpVtbl -> put_Item(This,pvarName,pvarValue)

#define ISEORegDictionary_get__NewEnum(This,ppunkResult)	\
    (This)->lpVtbl -> get__NewEnum(This,ppunkResult)

#define ISEORegDictionary_GetVariantA(This,pszName,pvarResult)	\
    (This)->lpVtbl -> GetVariantA(This,pszName,pvarResult)

#define ISEORegDictionary_GetVariantW(This,pszName,pvarResult)	\
    (This)->lpVtbl -> GetVariantW(This,pszName,pvarResult)

#define ISEORegDictionary_SetVariantA(This,pszName,pvarValue)	\
    (This)->lpVtbl -> SetVariantA(This,pszName,pvarValue)

#define ISEORegDictionary_SetVariantW(This,pszName,pvarValue)	\
    (This)->lpVtbl -> SetVariantW(This,pszName,pvarValue)

#define ISEORegDictionary_GetStringA(This,pszName,pchCount,pszResult)	\
    (This)->lpVtbl -> GetStringA(This,pszName,pchCount,pszResult)

#define ISEORegDictionary_GetStringW(This,pszName,pchCount,pszResult)	\
    (This)->lpVtbl -> GetStringW(This,pszName,pchCount,pszResult)

#define ISEORegDictionary_SetStringA(This,pszName,chCount,pszValue)	\
    (This)->lpVtbl -> SetStringA(This,pszName,chCount,pszValue)

#define ISEORegDictionary_SetStringW(This,pszName,chCount,pszValue)	\
    (This)->lpVtbl -> SetStringW(This,pszName,chCount,pszValue)

#define ISEORegDictionary_GetDWordA(This,pszName,pdwResult)	\
    (This)->lpVtbl -> GetDWordA(This,pszName,pdwResult)

#define ISEORegDictionary_GetDWordW(This,pszName,pdwResult)	\
    (This)->lpVtbl -> GetDWordW(This,pszName,pdwResult)

#define ISEORegDictionary_SetDWordA(This,pszName,dwValue)	\
    (This)->lpVtbl -> SetDWordA(This,pszName,dwValue)

#define ISEORegDictionary_SetDWordW(This,pszName,dwValue)	\
    (This)->lpVtbl -> SetDWordW(This,pszName,dwValue)

#define ISEORegDictionary_GetInterfaceA(This,pszName,iidDesired,ppunkResult)	\
    (This)->lpVtbl -> GetInterfaceA(This,pszName,iidDesired,ppunkResult)

#define ISEORegDictionary_GetInterfaceW(This,pszName,iidDesired,ppunkResult)	\
    (This)->lpVtbl -> GetInterfaceW(This,pszName,iidDesired,ppunkResult)

#define ISEORegDictionary_SetInterfaceA(This,pszName,punkValue)	\
    (This)->lpVtbl -> SetInterfaceA(This,pszName,punkValue)

#define ISEORegDictionary_SetInterfaceW(This,pszName,punkValue)	\
    (This)->lpVtbl -> SetInterfaceW(This,pszName,punkValue)


#define ISEORegDictionary_Load(This,pszMachine,skBaseKey,pszSubKey,pErrorLog)	\
    (This)->lpVtbl -> Load(This,pszMachine,skBaseKey,pszSubKey,pErrorLog)

#endif /* COBJMACROS */


#endif 	/* C style interface */



/* [helpstring] */ HRESULT STDMETHODCALLTYPE ISEORegDictionary_Load_Proxy( 
    ISEORegDictionary __RPC_FAR * This,
    /* [in] */ LPCOLESTR pszMachine,
    /* [in] */ SEO_HKEY skBaseKey,
    /* [in] */ LPCOLESTR pszSubKey,
    /* [unique][in] */ IErrorLog __RPC_FAR *pErrorLog);


void __RPC_STUB ISEORegDictionary_Load_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);



#endif 	/* __ISEORegDictionary_INTERFACE_DEFINED__ */


#ifndef __ISEOBindingConverter_INTERFACE_DEFINED__
#define __ISEOBindingConverter_INTERFACE_DEFINED__

/* interface ISEOBindingConverter */
/* [uuid][unique][object][helpstring] */ 


EXTERN_C const IID IID_ISEOBindingConverter;

#if defined(__cplusplus) && !defined(CINTERFACE)
    
    MIDL_INTERFACE("ee4e64d0-31f1-11d0-a9d0-00aa00685c74")
    ISEOBindingConverter : public IUnknown
    {
    public:
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE Convert( 
            /* [in] */ LONG lEventData,
            /* [retval][out] */ ISEODictionary __RPC_FAR *__RPC_FAR *ppiResult) = 0;
        
    };
    
#else 	/* C style interface */

    typedef struct ISEOBindingConverterVtbl
    {
        BEGIN_INTERFACE
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *QueryInterface )( 
            ISEOBindingConverter __RPC_FAR * This,
            /* [in] */ REFIID riid,
            /* [iid_is][out] */ void __RPC_FAR *__RPC_FAR *ppvObject);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *AddRef )( 
            ISEOBindingConverter __RPC_FAR * This);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *Release )( 
            ISEOBindingConverter __RPC_FAR * This);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *Convert )( 
            ISEOBindingConverter __RPC_FAR * This,
            /* [in] */ LONG lEventData,
            /* [retval][out] */ ISEODictionary __RPC_FAR *__RPC_FAR *ppiResult);
        
        END_INTERFACE
    } ISEOBindingConverterVtbl;

    interface ISEOBindingConverter
    {
        CONST_VTBL struct ISEOBindingConverterVtbl __RPC_FAR *lpVtbl;
    };

    

#ifdef COBJMACROS


#define ISEOBindingConverter_QueryInterface(This,riid,ppvObject)	\
    (This)->lpVtbl -> QueryInterface(This,riid,ppvObject)

#define ISEOBindingConverter_AddRef(This)	\
    (This)->lpVtbl -> AddRef(This)

#define ISEOBindingConverter_Release(This)	\
    (This)->lpVtbl -> Release(This)


#define ISEOBindingConverter_Convert(This,lEventData,ppiResult)	\
    (This)->lpVtbl -> Convert(This,lEventData,ppiResult)

#endif /* COBJMACROS */


#endif 	/* C style interface */



/* [helpstring] */ HRESULT STDMETHODCALLTYPE ISEOBindingConverter_Convert_Proxy( 
    ISEOBindingConverter __RPC_FAR * This,
    /* [in] */ LONG lEventData,
    /* [retval][out] */ ISEODictionary __RPC_FAR *__RPC_FAR *ppiResult);


void __RPC_STUB ISEOBindingConverter_Convert_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);



#endif 	/* __ISEOBindingConverter_INTERFACE_DEFINED__ */


#ifndef __ISEODispatcher_INTERFACE_DEFINED__
#define __ISEODispatcher_INTERFACE_DEFINED__

/* interface ISEODispatcher */
/* [uuid][unique][object][hidden][helpstring] */ 


EXTERN_C const IID IID_ISEODispatcher;

#if defined(__cplusplus) && !defined(CINTERFACE)
    
    MIDL_INTERFACE("8ca89880-31f1-11d0-a9d0-00aa00685c74")
    ISEODispatcher : public IUnknown
    {
    public:
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE SetContext( 
            /* [unique][in] */ ISEORouter __RPC_FAR *piRouter,
            /* [unique][in] */ ISEODictionary __RPC_FAR *pdictBP) = 0;
        
    };
    
#else 	/* C style interface */

    typedef struct ISEODispatcherVtbl
    {
        BEGIN_INTERFACE
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *QueryInterface )( 
            ISEODispatcher __RPC_FAR * This,
            /* [in] */ REFIID riid,
            /* [iid_is][out] */ void __RPC_FAR *__RPC_FAR *ppvObject);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *AddRef )( 
            ISEODispatcher __RPC_FAR * This);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *Release )( 
            ISEODispatcher __RPC_FAR * This);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *SetContext )( 
            ISEODispatcher __RPC_FAR * This,
            /* [unique][in] */ ISEORouter __RPC_FAR *piRouter,
            /* [unique][in] */ ISEODictionary __RPC_FAR *pdictBP);
        
        END_INTERFACE
    } ISEODispatcherVtbl;

    interface ISEODispatcher
    {
        CONST_VTBL struct ISEODispatcherVtbl __RPC_FAR *lpVtbl;
    };

    

#ifdef COBJMACROS


#define ISEODispatcher_QueryInterface(This,riid,ppvObject)	\
    (This)->lpVtbl -> QueryInterface(This,riid,ppvObject)

#define ISEODispatcher_AddRef(This)	\
    (This)->lpVtbl -> AddRef(This)

#define ISEODispatcher_Release(This)	\
    (This)->lpVtbl -> Release(This)


#define ISEODispatcher_SetContext(This,piRouter,pdictBP)	\
    (This)->lpVtbl -> SetContext(This,piRouter,pdictBP)

#endif /* COBJMACROS */


#endif 	/* C style interface */



/* [helpstring] */ HRESULT STDMETHODCALLTYPE ISEODispatcher_SetContext_Proxy( 
    ISEODispatcher __RPC_FAR * This,
    /* [unique][in] */ ISEORouter __RPC_FAR *piRouter,
    /* [unique][in] */ ISEODictionary __RPC_FAR *pdictBP);


void __RPC_STUB ISEODispatcher_SetContext_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);



#endif 	/* __ISEODispatcher_INTERFACE_DEFINED__ */


#ifndef __IEventDeliveryOptions_INTERFACE_DEFINED__
#define __IEventDeliveryOptions_INTERFACE_DEFINED__

/* interface IEventDeliveryOptions */
/* [uuid][unique][oleautomation][object][helpstring][dual] */ 


EXTERN_C const IID IID_IEventDeliveryOptions;

#if defined(__cplusplus) && !defined(CINTERFACE)
    
    MIDL_INTERFACE("0688a660-a3ff-11d0-a9e9-00aa00685c74")
    IEventDeliveryOptions : public IDispatch
    {
    public:
    };
    
#else 	/* C style interface */

    typedef struct IEventDeliveryOptionsVtbl
    {
        BEGIN_INTERFACE
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *QueryInterface )( 
            IEventDeliveryOptions __RPC_FAR * This,
            /* [in] */ REFIID riid,
            /* [iid_is][out] */ void __RPC_FAR *__RPC_FAR *ppvObject);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *AddRef )( 
            IEventDeliveryOptions __RPC_FAR * This);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *Release )( 
            IEventDeliveryOptions __RPC_FAR * This);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetTypeInfoCount )( 
            IEventDeliveryOptions __RPC_FAR * This,
            /* [out] */ UINT __RPC_FAR *pctinfo);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetTypeInfo )( 
            IEventDeliveryOptions __RPC_FAR * This,
            /* [in] */ UINT iTInfo,
            /* [in] */ LCID lcid,
            /* [out] */ ITypeInfo __RPC_FAR *__RPC_FAR *ppTInfo);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetIDsOfNames )( 
            IEventDeliveryOptions __RPC_FAR * This,
            /* [in] */ REFIID riid,
            /* [size_is][in] */ LPOLESTR __RPC_FAR *rgszNames,
            /* [in] */ UINT cNames,
            /* [in] */ LCID lcid,
            /* [size_is][out] */ DISPID __RPC_FAR *rgDispId);
        
        /* [local] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *Invoke )( 
            IEventDeliveryOptions __RPC_FAR * This,
            /* [in] */ DISPID dispIdMember,
            /* [in] */ REFIID riid,
            /* [in] */ LCID lcid,
            /* [in] */ WORD wFlags,
            /* [out][in] */ DISPPARAMS __RPC_FAR *pDispParams,
            /* [out] */ VARIANT __RPC_FAR *pVarResult,
            /* [out] */ EXCEPINFO __RPC_FAR *pExcepInfo,
            /* [out] */ UINT __RPC_FAR *puArgErr);
        
        END_INTERFACE
    } IEventDeliveryOptionsVtbl;

    interface IEventDeliveryOptions
    {
        CONST_VTBL struct IEventDeliveryOptionsVtbl __RPC_FAR *lpVtbl;
    };

    

#ifdef COBJMACROS


#define IEventDeliveryOptions_QueryInterface(This,riid,ppvObject)	\
    (This)->lpVtbl -> QueryInterface(This,riid,ppvObject)

#define IEventDeliveryOptions_AddRef(This)	\
    (This)->lpVtbl -> AddRef(This)

#define IEventDeliveryOptions_Release(This)	\
    (This)->lpVtbl -> Release(This)


#define IEventDeliveryOptions_GetTypeInfoCount(This,pctinfo)	\
    (This)->lpVtbl -> GetTypeInfoCount(This,pctinfo)

#define IEventDeliveryOptions_GetTypeInfo(This,iTInfo,lcid,ppTInfo)	\
    (This)->lpVtbl -> GetTypeInfo(This,iTInfo,lcid,ppTInfo)

#define IEventDeliveryOptions_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)	\
    (This)->lpVtbl -> GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)

#define IEventDeliveryOptions_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)	\
    (This)->lpVtbl -> Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)


#endif /* COBJMACROS */


#endif 	/* C style interface */




#endif 	/* __IEventDeliveryOptions_INTERFACE_DEFINED__ */


#ifndef __IEventTypeSinks_INTERFACE_DEFINED__
#define __IEventTypeSinks_INTERFACE_DEFINED__

/* interface IEventTypeSinks */
/* [uuid][unique][oleautomation][object][helpstring][dual] */ 


EXTERN_C const IID IID_IEventTypeSinks;

#if defined(__cplusplus) && !defined(CINTERFACE)
    
    MIDL_INTERFACE("a1063f50-a654-11d0-a9ea-00aa00685c74")
    IEventTypeSinks : public IDispatch
    {
    public:
        virtual /* [id][helpstring] */ HRESULT STDMETHODCALLTYPE Item( 
            /* [in] */ long lIndex,
            /* [retval][out] */ BSTR __RPC_FAR *pstrTypeSink) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE Add( 
            /* [in] */ BSTR pszTypeSink) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE Remove( 
            /* [in] */ BSTR pszTypeSink) = 0;
        
        virtual /* [propget][helpstring] */ HRESULT STDMETHODCALLTYPE get_Count( 
            /* [retval][out] */ long __RPC_FAR *plCount) = 0;
        
        virtual /* [hidden][propget][id][helpstring] */ HRESULT STDMETHODCALLTYPE get__NewEnum( 
            /* [retval][out] */ IUnknown __RPC_FAR *__RPC_FAR *ppUnkEnum) = 0;
        
    };
    
#else 	/* C style interface */

    typedef struct IEventTypeSinksVtbl
    {
        BEGIN_INTERFACE
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *QueryInterface )( 
            IEventTypeSinks __RPC_FAR * This,
            /* [in] */ REFIID riid,
            /* [iid_is][out] */ void __RPC_FAR *__RPC_FAR *ppvObject);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *AddRef )( 
            IEventTypeSinks __RPC_FAR * This);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *Release )( 
            IEventTypeSinks __RPC_FAR * This);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetTypeInfoCount )( 
            IEventTypeSinks __RPC_FAR * This,
            /* [out] */ UINT __RPC_FAR *pctinfo);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetTypeInfo )( 
            IEventTypeSinks __RPC_FAR * This,
            /* [in] */ UINT iTInfo,
            /* [in] */ LCID lcid,
            /* [out] */ ITypeInfo __RPC_FAR *__RPC_FAR *ppTInfo);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetIDsOfNames )( 
            IEventTypeSinks __RPC_FAR * This,
            /* [in] */ REFIID riid,
            /* [size_is][in] */ LPOLESTR __RPC_FAR *rgszNames,
            /* [in] */ UINT cNames,
            /* [in] */ LCID lcid,
            /* [size_is][out] */ DISPID __RPC_FAR *rgDispId);
        
        /* [local] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *Invoke )( 
            IEventTypeSinks __RPC_FAR * This,
            /* [in] */ DISPID dispIdMember,
            /* [in] */ REFIID riid,
            /* [in] */ LCID lcid,
            /* [in] */ WORD wFlags,
            /* [out][in] */ DISPPARAMS __RPC_FAR *pDispParams,
            /* [out] */ VARIANT __RPC_FAR *pVarResult,
            /* [out] */ EXCEPINFO __RPC_FAR *pExcepInfo,
            /* [out] */ UINT __RPC_FAR *puArgErr);
        
        /* [id][helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *Item )( 
            IEventTypeSinks __RPC_FAR * This,
            /* [in] */ long lIndex,
            /* [retval][out] */ BSTR __RPC_FAR *pstrTypeSink);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *Add )( 
            IEventTypeSinks __RPC_FAR * This,
            /* [in] */ BSTR pszTypeSink);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *Remove )( 
            IEventTypeSinks __RPC_FAR * This,
            /* [in] */ BSTR pszTypeSink);
        
        /* [propget][helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *get_Count )( 
            IEventTypeSinks __RPC_FAR * This,
            /* [retval][out] */ long __RPC_FAR *plCount);
        
        /* [hidden][propget][id][helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *get__NewEnum )( 
            IEventTypeSinks __RPC_FAR * This,
            /* [retval][out] */ IUnknown __RPC_FAR *__RPC_FAR *ppUnkEnum);
        
        END_INTERFACE
    } IEventTypeSinksVtbl;

    interface IEventTypeSinks
    {
        CONST_VTBL struct IEventTypeSinksVtbl __RPC_FAR *lpVtbl;
    };

    

#ifdef COBJMACROS


#define IEventTypeSinks_QueryInterface(This,riid,ppvObject)	\
    (This)->lpVtbl -> QueryInterface(This,riid,ppvObject)

#define IEventTypeSinks_AddRef(This)	\
    (This)->lpVtbl -> AddRef(This)

#define IEventTypeSinks_Release(This)	\
    (This)->lpVtbl -> Release(This)


#define IEventTypeSinks_GetTypeInfoCount(This,pctinfo)	\
    (This)->lpVtbl -> GetTypeInfoCount(This,pctinfo)

#define IEventTypeSinks_GetTypeInfo(This,iTInfo,lcid,ppTInfo)	\
    (This)->lpVtbl -> GetTypeInfo(This,iTInfo,lcid,ppTInfo)

#define IEventTypeSinks_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)	\
    (This)->lpVtbl -> GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)

#define IEventTypeSinks_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)	\
    (This)->lpVtbl -> Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)


#define IEventTypeSinks_Item(This,lIndex,pstrTypeSink)	\
    (This)->lpVtbl -> Item(This,lIndex,pstrTypeSink)

#define IEventTypeSinks_Add(This,pszTypeSink)	\
    (This)->lpVtbl -> Add(This,pszTypeSink)

#define IEventTypeSinks_Remove(This,pszTypeSink)	\
    (This)->lpVtbl -> Remove(This,pszTypeSink)

#define IEventTypeSinks_get_Count(This,plCount)	\
    (This)->lpVtbl -> get_Count(This,plCount)

#define IEventTypeSinks_get__NewEnum(This,ppUnkEnum)	\
    (This)->lpVtbl -> get__NewEnum(This,ppUnkEnum)

#endif /* COBJMACROS */


#endif 	/* C style interface */



/* [id][helpstring] */ HRESULT STDMETHODCALLTYPE IEventTypeSinks_Item_Proxy( 
    IEventTypeSinks __RPC_FAR * This,
    /* [in] */ long lIndex,
    /* [retval][out] */ BSTR __RPC_FAR *pstrTypeSink);


void __RPC_STUB IEventTypeSinks_Item_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IEventTypeSinks_Add_Proxy( 
    IEventTypeSinks __RPC_FAR * This,
    /* [in] */ BSTR pszTypeSink);


void __RPC_STUB IEventTypeSinks_Add_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IEventTypeSinks_Remove_Proxy( 
    IEventTypeSinks __RPC_FAR * This,
    /* [in] */ BSTR pszTypeSink);


void __RPC_STUB IEventTypeSinks_Remove_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [propget][helpstring] */ HRESULT STDMETHODCALLTYPE IEventTypeSinks_get_Count_Proxy( 
    IEventTypeSinks __RPC_FAR * This,
    /* [retval][out] */ long __RPC_FAR *plCount);


void __RPC_STUB IEventTypeSinks_get_Count_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [hidden][propget][id][helpstring] */ HRESULT STDMETHODCALLTYPE IEventTypeSinks_get__NewEnum_Proxy( 
    IEventTypeSinks __RPC_FAR * This,
    /* [retval][out] */ IUnknown __RPC_FAR *__RPC_FAR *ppUnkEnum);


void __RPC_STUB IEventTypeSinks_get__NewEnum_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);



#endif 	/* __IEventTypeSinks_INTERFACE_DEFINED__ */


#ifndef __IEventType_INTERFACE_DEFINED__
#define __IEventType_INTERFACE_DEFINED__

/* interface IEventType */
/* [uuid][unique][oleautomation][object][helpstring][dual] */ 


EXTERN_C const IID IID_IEventType;

#if defined(__cplusplus) && !defined(CINTERFACE)
    
    MIDL_INTERFACE("4a993b80-a654-11d0-a9ea-00aa00685c74")
    IEventType : public IDispatch
    {
    public:
        virtual /* [propget][helpstring] */ HRESULT STDMETHODCALLTYPE get_ID( 
            /* [retval][out] */ BSTR __RPC_FAR *pstrID) = 0;
        
        virtual /* [propget][helpstring] */ HRESULT STDMETHODCALLTYPE get_DisplayName( 
            /* [retval][out] */ BSTR __RPC_FAR *pstrDisplayName) = 0;
        
        virtual /* [propget][helpstring] */ HRESULT STDMETHODCALLTYPE get_Sinks( 
            /* [retval][out] */ IEventTypeSinks __RPC_FAR *__RPC_FAR *ppTypeSinks) = 0;
        
    };
    
#else 	/* C style interface */

    typedef struct IEventTypeVtbl
    {
        BEGIN_INTERFACE
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *QueryInterface )( 
            IEventType __RPC_FAR * This,
            /* [in] */ REFIID riid,
            /* [iid_is][out] */ void __RPC_FAR *__RPC_FAR *ppvObject);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *AddRef )( 
            IEventType __RPC_FAR * This);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *Release )( 
            IEventType __RPC_FAR * This);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetTypeInfoCount )( 
            IEventType __RPC_FAR * This,
            /* [out] */ UINT __RPC_FAR *pctinfo);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetTypeInfo )( 
            IEventType __RPC_FAR * This,
            /* [in] */ UINT iTInfo,
            /* [in] */ LCID lcid,
            /* [out] */ ITypeInfo __RPC_FAR *__RPC_FAR *ppTInfo);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetIDsOfNames )( 
            IEventType __RPC_FAR * This,
            /* [in] */ REFIID riid,
            /* [size_is][in] */ LPOLESTR __RPC_FAR *rgszNames,
            /* [in] */ UINT cNames,
            /* [in] */ LCID lcid,
            /* [size_is][out] */ DISPID __RPC_FAR *rgDispId);
        
        /* [local] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *Invoke )( 
            IEventType __RPC_FAR * This,
            /* [in] */ DISPID dispIdMember,
            /* [in] */ REFIID riid,
            /* [in] */ LCID lcid,
            /* [in] */ WORD wFlags,
            /* [out][in] */ DISPPARAMS __RPC_FAR *pDispParams,
            /* [out] */ VARIANT __RPC_FAR *pVarResult,
            /* [out] */ EXCEPINFO __RPC_FAR *pExcepInfo,
            /* [out] */ UINT __RPC_FAR *puArgErr);
        
        /* [propget][helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *get_ID )( 
            IEventType __RPC_FAR * This,
            /* [retval][out] */ BSTR __RPC_FAR *pstrID);
        
        /* [propget][helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *get_DisplayName )( 
            IEventType __RPC_FAR * This,
            /* [retval][out] */ BSTR __RPC_FAR *pstrDisplayName);
        
        /* [propget][helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *get_Sinks )( 
            IEventType __RPC_FAR * This,
            /* [retval][out] */ IEventTypeSinks __RPC_FAR *__RPC_FAR *ppTypeSinks);
        
        END_INTERFACE
    } IEventTypeVtbl;

    interface IEventType
    {
        CONST_VTBL struct IEventTypeVtbl __RPC_FAR *lpVtbl;
    };

    

#ifdef COBJMACROS


#define IEventType_QueryInterface(This,riid,ppvObject)	\
    (This)->lpVtbl -> QueryInterface(This,riid,ppvObject)

#define IEventType_AddRef(This)	\
    (This)->lpVtbl -> AddRef(This)

#define IEventType_Release(This)	\
    (This)->lpVtbl -> Release(This)


#define IEventType_GetTypeInfoCount(This,pctinfo)	\
    (This)->lpVtbl -> GetTypeInfoCount(This,pctinfo)

#define IEventType_GetTypeInfo(This,iTInfo,lcid,ppTInfo)	\
    (This)->lpVtbl -> GetTypeInfo(This,iTInfo,lcid,ppTInfo)

#define IEventType_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)	\
    (This)->lpVtbl -> GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)

#define IEventType_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)	\
    (This)->lpVtbl -> Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)


#define IEventType_get_ID(This,pstrID)	\
    (This)->lpVtbl -> get_ID(This,pstrID)

#define IEventType_get_DisplayName(This,pstrDisplayName)	\
    (This)->lpVtbl -> get_DisplayName(This,pstrDisplayName)

#define IEventType_get_Sinks(This,ppTypeSinks)	\
    (This)->lpVtbl -> get_Sinks(This,ppTypeSinks)

#endif /* COBJMACROS */


#endif 	/* C style interface */



/* [propget][helpstring] */ HRESULT STDMETHODCALLTYPE IEventType_get_ID_Proxy( 
    IEventType __RPC_FAR * This,
    /* [retval][out] */ BSTR __RPC_FAR *pstrID);


void __RPC_STUB IEventType_get_ID_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [propget][helpstring] */ HRESULT STDMETHODCALLTYPE IEventType_get_DisplayName_Proxy( 
    IEventType __RPC_FAR * This,
    /* [retval][out] */ BSTR __RPC_FAR *pstrDisplayName);


void __RPC_STUB IEventType_get_DisplayName_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [propget][helpstring] */ HRESULT STDMETHODCALLTYPE IEventType_get_Sinks_Proxy( 
    IEventType __RPC_FAR * This,
    /* [retval][out] */ IEventTypeSinks __RPC_FAR *__RPC_FAR *ppTypeSinks);


void __RPC_STUB IEventType_get_Sinks_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);



#endif 	/* __IEventType_INTERFACE_DEFINED__ */


#ifndef __IEventPropertyBag_INTERFACE_DEFINED__
#define __IEventPropertyBag_INTERFACE_DEFINED__

/* interface IEventPropertyBag */
/* [uuid][unique][oleautomation][object][helpstring][dual] */ 


EXTERN_C const IID IID_IEventPropertyBag;

#if defined(__cplusplus) && !defined(CINTERFACE)
    
    MIDL_INTERFACE("aabb23e0-a705-11d0-a9ea-00aa00685c74")
    IEventPropertyBag : public IDispatch
    {
    public:
        virtual /* [id][helpstring] */ HRESULT STDMETHODCALLTYPE Item( 
            /* [in] */ VARIANT __RPC_FAR *pvarPropDesired,
            /* [retval][out] */ VARIANT __RPC_FAR *pvarPropValue) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE Name( 
            /* [in] */ long lPropIndex,
            /* [retval][out] */ BSTR __RPC_FAR *pstrPropName) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE Add( 
            /* [in] */ BSTR pszPropName,
            /* [in] */ VARIANT __RPC_FAR *pvarPropValue) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE Remove( 
            /* [in] */ VARIANT __RPC_FAR *pvarPropDesired) = 0;
        
        virtual /* [propget][helpstring] */ HRESULT STDMETHODCALLTYPE get_Count( 
            /* [retval][out] */ long __RPC_FAR *plCount) = 0;
        
        virtual /* [hidden][propget][id][helpstring] */ HRESULT STDMETHODCALLTYPE get__NewEnum( 
            /* [retval][out] */ IUnknown __RPC_FAR *__RPC_FAR *ppUnkEnum) = 0;
        
    };
    
#else 	/* C style interface */

    typedef struct IEventPropertyBagVtbl
    {
        BEGIN_INTERFACE
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *QueryInterface )( 
            IEventPropertyBag __RPC_FAR * This,
            /* [in] */ REFIID riid,
            /* [iid_is][out] */ void __RPC_FAR *__RPC_FAR *ppvObject);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *AddRef )( 
            IEventPropertyBag __RPC_FAR * This);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *Release )( 
            IEventPropertyBag __RPC_FAR * This);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetTypeInfoCount )( 
            IEventPropertyBag __RPC_FAR * This,
            /* [out] */ UINT __RPC_FAR *pctinfo);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetTypeInfo )( 
            IEventPropertyBag __RPC_FAR * This,
            /* [in] */ UINT iTInfo,
            /* [in] */ LCID lcid,
            /* [out] */ ITypeInfo __RPC_FAR *__RPC_FAR *ppTInfo);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetIDsOfNames )( 
            IEventPropertyBag __RPC_FAR * This,
            /* [in] */ REFIID riid,
            /* [size_is][in] */ LPOLESTR __RPC_FAR *rgszNames,
            /* [in] */ UINT cNames,
            /* [in] */ LCID lcid,
            /* [size_is][out] */ DISPID __RPC_FAR *rgDispId);
        
        /* [local] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *Invoke )( 
            IEventPropertyBag __RPC_FAR * This,
            /* [in] */ DISPID dispIdMember,
            /* [in] */ REFIID riid,
            /* [in] */ LCID lcid,
            /* [in] */ WORD wFlags,
            /* [out][in] */ DISPPARAMS __RPC_FAR *pDispParams,
            /* [out] */ VARIANT __RPC_FAR *pVarResult,
            /* [out] */ EXCEPINFO __RPC_FAR *pExcepInfo,
            /* [out] */ UINT __RPC_FAR *puArgErr);
        
        /* [id][helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *Item )( 
            IEventPropertyBag __RPC_FAR * This,
            /* [in] */ VARIANT __RPC_FAR *pvarPropDesired,
            /* [retval][out] */ VARIANT __RPC_FAR *pvarPropValue);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *Name )( 
            IEventPropertyBag __RPC_FAR * This,
            /* [in] */ long lPropIndex,
            /* [retval][out] */ BSTR __RPC_FAR *pstrPropName);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *Add )( 
            IEventPropertyBag __RPC_FAR * This,
            /* [in] */ BSTR pszPropName,
            /* [in] */ VARIANT __RPC_FAR *pvarPropValue);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *Remove )( 
            IEventPropertyBag __RPC_FAR * This,
            /* [in] */ VARIANT __RPC_FAR *pvarPropDesired);
        
        /* [propget][helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *get_Count )( 
            IEventPropertyBag __RPC_FAR * This,
            /* [retval][out] */ long __RPC_FAR *plCount);
        
        /* [hidden][propget][id][helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *get__NewEnum )( 
            IEventPropertyBag __RPC_FAR * This,
            /* [retval][out] */ IUnknown __RPC_FAR *__RPC_FAR *ppUnkEnum);
        
        END_INTERFACE
    } IEventPropertyBagVtbl;

    interface IEventPropertyBag
    {
        CONST_VTBL struct IEventPropertyBagVtbl __RPC_FAR *lpVtbl;
    };

    

#ifdef COBJMACROS


#define IEventPropertyBag_QueryInterface(This,riid,ppvObject)	\
    (This)->lpVtbl -> QueryInterface(This,riid,ppvObject)

#define IEventPropertyBag_AddRef(This)	\
    (This)->lpVtbl -> AddRef(This)

#define IEventPropertyBag_Release(This)	\
    (This)->lpVtbl -> Release(This)


#define IEventPropertyBag_GetTypeInfoCount(This,pctinfo)	\
    (This)->lpVtbl -> GetTypeInfoCount(This,pctinfo)

#define IEventPropertyBag_GetTypeInfo(This,iTInfo,lcid,ppTInfo)	\
    (This)->lpVtbl -> GetTypeInfo(This,iTInfo,lcid,ppTInfo)

#define IEventPropertyBag_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)	\
    (This)->lpVtbl -> GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)

#define IEventPropertyBag_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)	\
    (This)->lpVtbl -> Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)


#define IEventPropertyBag_Item(This,pvarPropDesired,pvarPropValue)	\
    (This)->lpVtbl -> Item(This,pvarPropDesired,pvarPropValue)

#define IEventPropertyBag_Name(This,lPropIndex,pstrPropName)	\
    (This)->lpVtbl -> Name(This,lPropIndex,pstrPropName)

#define IEventPropertyBag_Add(This,pszPropName,pvarPropValue)	\
    (This)->lpVtbl -> Add(This,pszPropName,pvarPropValue)

#define IEventPropertyBag_Remove(This,pvarPropDesired)	\
    (This)->lpVtbl -> Remove(This,pvarPropDesired)

#define IEventPropertyBag_get_Count(This,plCount)	\
    (This)->lpVtbl -> get_Count(This,plCount)

#define IEventPropertyBag_get__NewEnum(This,ppUnkEnum)	\
    (This)->lpVtbl -> get__NewEnum(This,ppUnkEnum)

#endif /* COBJMACROS */


#endif 	/* C style interface */



/* [id][helpstring] */ HRESULT STDMETHODCALLTYPE IEventPropertyBag_Item_Proxy( 
    IEventPropertyBag __RPC_FAR * This,
    /* [in] */ VARIANT __RPC_FAR *pvarPropDesired,
    /* [retval][out] */ VARIANT __RPC_FAR *pvarPropValue);


void __RPC_STUB IEventPropertyBag_Item_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IEventPropertyBag_Name_Proxy( 
    IEventPropertyBag __RPC_FAR * This,
    /* [in] */ long lPropIndex,
    /* [retval][out] */ BSTR __RPC_FAR *pstrPropName);


void __RPC_STUB IEventPropertyBag_Name_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IEventPropertyBag_Add_Proxy( 
    IEventPropertyBag __RPC_FAR * This,
    /* [in] */ BSTR pszPropName,
    /* [in] */ VARIANT __RPC_FAR *pvarPropValue);


void __RPC_STUB IEventPropertyBag_Add_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IEventPropertyBag_Remove_Proxy( 
    IEventPropertyBag __RPC_FAR * This,
    /* [in] */ VARIANT __RPC_FAR *pvarPropDesired);


void __RPC_STUB IEventPropertyBag_Remove_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [propget][helpstring] */ HRESULT STDMETHODCALLTYPE IEventPropertyBag_get_Count_Proxy( 
    IEventPropertyBag __RPC_FAR * This,
    /* [retval][out] */ long __RPC_FAR *plCount);


void __RPC_STUB IEventPropertyBag_get_Count_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [hidden][propget][id][helpstring] */ HRESULT STDMETHODCALLTYPE IEventPropertyBag_get__NewEnum_Proxy( 
    IEventPropertyBag __RPC_FAR * This,
    /* [retval][out] */ IUnknown __RPC_FAR *__RPC_FAR *ppUnkEnum);


void __RPC_STUB IEventPropertyBag_get__NewEnum_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);



#endif 	/* __IEventPropertyBag_INTERFACE_DEFINED__ */


#ifndef __IEventBinding_INTERFACE_DEFINED__
#define __IEventBinding_INTERFACE_DEFINED__

/* interface IEventBinding */
/* [uuid][unique][oleautomation][object][helpstring][dual] */ 


EXTERN_C const IID IID_IEventBinding;

#if defined(__cplusplus) && !defined(CINTERFACE)
    
    MIDL_INTERFACE("8e398ce0-a64e-11d0-a9ea-00aa00685c74")
    IEventBinding : public IDispatch
    {
    public:
        virtual /* [propget][helpstring] */ HRESULT STDMETHODCALLTYPE get_ID( 
            /* [retval][out] */ BSTR __RPC_FAR *pstrBindingID) = 0;
        
        virtual /* [propget][helpstring] */ HRESULT STDMETHODCALLTYPE get_DisplayName( 
            /* [retval][out] */ BSTR __RPC_FAR *pstrDisplayName) = 0;
        
        virtual /* [propput][helpstring] */ HRESULT STDMETHODCALLTYPE put_DisplayName( 
            /* [in] */ BSTR pszDisplayName) = 0;
        
        virtual /* [propputref][helpstring] */ HRESULT STDMETHODCALLTYPE putref_DisplayName( 
            /* [in] */ BSTR __RPC_FAR *ppszDisplayName) = 0;
        
        virtual /* [propget][helpstring] */ HRESULT STDMETHODCALLTYPE get_SinkClass( 
            /* [retval][out] */ BSTR __RPC_FAR *pstrSinkClass) = 0;
        
        virtual /* [propput][helpstring] */ HRESULT STDMETHODCALLTYPE put_SinkClass( 
            /* [in] */ BSTR pszSinkClass) = 0;
        
        virtual /* [propputref][helpstring] */ HRESULT STDMETHODCALLTYPE putref_SinkClass( 
            /* [in] */ BSTR __RPC_FAR *ppszSinkClass) = 0;
        
        virtual /* [propget][helpstring] */ HRESULT STDMETHODCALLTYPE get_SinkProperties( 
            /* [retval][out] */ IEventPropertyBag __RPC_FAR *__RPC_FAR *ppSinkProperties) = 0;
        
        virtual /* [propget][helpstring] */ HRESULT STDMETHODCALLTYPE get_SourceProperties( 
            /* [retval][out] */ IEventPropertyBag __RPC_FAR *__RPC_FAR *ppSourceProperties) = 0;
        
        virtual /* [propget][helpstring] */ HRESULT STDMETHODCALLTYPE get_EventBindingProperties( 
            /* [retval][out] */ IEventPropertyBag __RPC_FAR *__RPC_FAR *ppEventBindingProperties) = 0;
        
        virtual /* [propget][helpstring] */ HRESULT STDMETHODCALLTYPE get_Enabled( 
            /* [retval][out] */ VARIANT_BOOL __RPC_FAR *pbEnabled) = 0;
        
        virtual /* [propput][helpstring] */ HRESULT STDMETHODCALLTYPE put_Enabled( 
            /* [in] */ VARIANT_BOOL bEnabled) = 0;
        
        virtual /* [propputref][helpstring] */ HRESULT STDMETHODCALLTYPE putref_Enabled( 
            /* [in] */ VARIANT_BOOL __RPC_FAR *pbEnabled) = 0;
        
        virtual /* [propget][helpstring] */ HRESULT STDMETHODCALLTYPE get_Expiration( 
            /* [retval][out] */ DATE __RPC_FAR *pdateExpiration) = 0;
        
        virtual /* [propput][helpstring] */ HRESULT STDMETHODCALLTYPE put_Expiration( 
            /* [in] */ DATE dateExpiration) = 0;
        
        virtual /* [propputref][helpstring] */ HRESULT STDMETHODCALLTYPE putref_Expiration( 
            /* [in] */ DATE __RPC_FAR *pdateExpiration) = 0;
        
        virtual /* [propget][helpstring] */ HRESULT STDMETHODCALLTYPE get_MaxFirings( 
            /* [retval][out] */ long __RPC_FAR *plMaxFirings) = 0;
        
        virtual /* [propput][helpstring] */ HRESULT STDMETHODCALLTYPE put_MaxFirings( 
            /* [in] */ long lMaxFirings) = 0;
        
        virtual /* [propputref][helpstring] */ HRESULT STDMETHODCALLTYPE putref_MaxFirings( 
            /* [in] */ long __RPC_FAR *plMaxFirings) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE Save( void) = 0;
        
    };
    
#else 	/* C style interface */

    typedef struct IEventBindingVtbl
    {
        BEGIN_INTERFACE
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *QueryInterface )( 
            IEventBinding __RPC_FAR * This,
            /* [in] */ REFIID riid,
            /* [iid_is][out] */ void __RPC_FAR *__RPC_FAR *ppvObject);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *AddRef )( 
            IEventBinding __RPC_FAR * This);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *Release )( 
            IEventBinding __RPC_FAR * This);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetTypeInfoCount )( 
            IEventBinding __RPC_FAR * This,
            /* [out] */ UINT __RPC_FAR *pctinfo);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetTypeInfo )( 
            IEventBinding __RPC_FAR * This,
            /* [in] */ UINT iTInfo,
            /* [in] */ LCID lcid,
            /* [out] */ ITypeInfo __RPC_FAR *__RPC_FAR *ppTInfo);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetIDsOfNames )( 
            IEventBinding __RPC_FAR * This,
            /* [in] */ REFIID riid,
            /* [size_is][in] */ LPOLESTR __RPC_FAR *rgszNames,
            /* [in] */ UINT cNames,
            /* [in] */ LCID lcid,
            /* [size_is][out] */ DISPID __RPC_FAR *rgDispId);
        
        /* [local] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *Invoke )( 
            IEventBinding __RPC_FAR * This,
            /* [in] */ DISPID dispIdMember,
            /* [in] */ REFIID riid,
            /* [in] */ LCID lcid,
            /* [in] */ WORD wFlags,
            /* [out][in] */ DISPPARAMS __RPC_FAR *pDispParams,
            /* [out] */ VARIANT __RPC_FAR *pVarResult,
            /* [out] */ EXCEPINFO __RPC_FAR *pExcepInfo,
            /* [out] */ UINT __RPC_FAR *puArgErr);
        
        /* [propget][helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *get_ID )( 
            IEventBinding __RPC_FAR * This,
            /* [retval][out] */ BSTR __RPC_FAR *pstrBindingID);
        
        /* [propget][helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *get_DisplayName )( 
            IEventBinding __RPC_FAR * This,
            /* [retval][out] */ BSTR __RPC_FAR *pstrDisplayName);
        
        /* [propput][helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *put_DisplayName )( 
            IEventBinding __RPC_FAR * This,
            /* [in] */ BSTR pszDisplayName);
        
        /* [propputref][helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *putref_DisplayName )( 
            IEventBinding __RPC_FAR * This,
            /* [in] */ BSTR __RPC_FAR *ppszDisplayName);
        
        /* [propget][helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *get_SinkClass )( 
            IEventBinding __RPC_FAR * This,
            /* [retval][out] */ BSTR __RPC_FAR *pstrSinkClass);
        
        /* [propput][helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *put_SinkClass )( 
            IEventBinding __RPC_FAR * This,
            /* [in] */ BSTR pszSinkClass);
        
        /* [propputref][helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *putref_SinkClass )( 
            IEventBinding __RPC_FAR * This,
            /* [in] */ BSTR __RPC_FAR *ppszSinkClass);
        
        /* [propget][helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *get_SinkProperties )( 
            IEventBinding __RPC_FAR * This,
            /* [retval][out] */ IEventPropertyBag __RPC_FAR *__RPC_FAR *ppSinkProperties);
        
        /* [propget][helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *get_SourceProperties )( 
            IEventBinding __RPC_FAR * This,
            /* [retval][out] */ IEventPropertyBag __RPC_FAR *__RPC_FAR *ppSourceProperties);
        
        /* [propget][helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *get_EventBindingProperties )( 
            IEventBinding __RPC_FAR * This,
            /* [retval][out] */ IEventPropertyBag __RPC_FAR *__RPC_FAR *ppEventBindingProperties);
        
        /* [propget][helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *get_Enabled )( 
            IEventBinding __RPC_FAR * This,
            /* [retval][out] */ VARIANT_BOOL __RPC_FAR *pbEnabled);
        
        /* [propput][helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *put_Enabled )( 
            IEventBinding __RPC_FAR * This,
            /* [in] */ VARIANT_BOOL bEnabled);
        
        /* [propputref][helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *putref_Enabled )( 
            IEventBinding __RPC_FAR * This,
            /* [in] */ VARIANT_BOOL __RPC_FAR *pbEnabled);
        
        /* [propget][helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *get_Expiration )( 
            IEventBinding __RPC_FAR * This,
            /* [retval][out] */ DATE __RPC_FAR *pdateExpiration);
        
        /* [propput][helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *put_Expiration )( 
            IEventBinding __RPC_FAR * This,
            /* [in] */ DATE dateExpiration);
        
        /* [propputref][helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *putref_Expiration )( 
            IEventBinding __RPC_FAR * This,
            /* [in] */ DATE __RPC_FAR *pdateExpiration);
        
        /* [propget][helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *get_MaxFirings )( 
            IEventBinding __RPC_FAR * This,
            /* [retval][out] */ long __RPC_FAR *plMaxFirings);
        
        /* [propput][helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *put_MaxFirings )( 
            IEventBinding __RPC_FAR * This,
            /* [in] */ long lMaxFirings);
        
        /* [propputref][helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *putref_MaxFirings )( 
            IEventBinding __RPC_FAR * This,
            /* [in] */ long __RPC_FAR *plMaxFirings);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *Save )( 
            IEventBinding __RPC_FAR * This);
        
        END_INTERFACE
    } IEventBindingVtbl;

    interface IEventBinding
    {
        CONST_VTBL struct IEventBindingVtbl __RPC_FAR *lpVtbl;
    };

    

#ifdef COBJMACROS


#define IEventBinding_QueryInterface(This,riid,ppvObject)	\
    (This)->lpVtbl -> QueryInterface(This,riid,ppvObject)

#define IEventBinding_AddRef(This)	\
    (This)->lpVtbl -> AddRef(This)

#define IEventBinding_Release(This)	\
    (This)->lpVtbl -> Release(This)


#define IEventBinding_GetTypeInfoCount(This,pctinfo)	\
    (This)->lpVtbl -> GetTypeInfoCount(This,pctinfo)

#define IEventBinding_GetTypeInfo(This,iTInfo,lcid,ppTInfo)	\
    (This)->lpVtbl -> GetTypeInfo(This,iTInfo,lcid,ppTInfo)

#define IEventBinding_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)	\
    (This)->lpVtbl -> GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)

#define IEventBinding_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)	\
    (This)->lpVtbl -> Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)


#define IEventBinding_get_ID(This,pstrBindingID)	\
    (This)->lpVtbl -> get_ID(This,pstrBindingID)

#define IEventBinding_get_DisplayName(This,pstrDisplayName)	\
    (This)->lpVtbl -> get_DisplayName(This,pstrDisplayName)

#define IEventBinding_put_DisplayName(This,pszDisplayName)	\
    (This)->lpVtbl -> put_DisplayName(This,pszDisplayName)

#define IEventBinding_putref_DisplayName(This,ppszDisplayName)	\
    (This)->lpVtbl -> putref_DisplayName(This,ppszDisplayName)

#define IEventBinding_get_SinkClass(This,pstrSinkClass)	\
    (This)->lpVtbl -> get_SinkClass(This,pstrSinkClass)

#define IEventBinding_put_SinkClass(This,pszSinkClass)	\
    (This)->lpVtbl -> put_SinkClass(This,pszSinkClass)

#define IEventBinding_putref_SinkClass(This,ppszSinkClass)	\
    (This)->lpVtbl -> putref_SinkClass(This,ppszSinkClass)

#define IEventBinding_get_SinkProperties(This,ppSinkProperties)	\
    (This)->lpVtbl -> get_SinkProperties(This,ppSinkProperties)

#define IEventBinding_get_SourceProperties(This,ppSourceProperties)	\
    (This)->lpVtbl -> get_SourceProperties(This,ppSourceProperties)

#define IEventBinding_get_EventBindingProperties(This,ppEventBindingProperties)	\
    (This)->lpVtbl -> get_EventBindingProperties(This,ppEventBindingProperties)

#define IEventBinding_get_Enabled(This,pbEnabled)	\
    (This)->lpVtbl -> get_Enabled(This,pbEnabled)

#define IEventBinding_put_Enabled(This,bEnabled)	\
    (This)->lpVtbl -> put_Enabled(This,bEnabled)

#define IEventBinding_putref_Enabled(This,pbEnabled)	\
    (This)->lpVtbl -> putref_Enabled(This,pbEnabled)

#define IEventBinding_get_Expiration(This,pdateExpiration)	\
    (This)->lpVtbl -> get_Expiration(This,pdateExpiration)

#define IEventBinding_put_Expiration(This,dateExpiration)	\
    (This)->lpVtbl -> put_Expiration(This,dateExpiration)

#define IEventBinding_putref_Expiration(This,pdateExpiration)	\
    (This)->lpVtbl -> putref_Expiration(This,pdateExpiration)

#define IEventBinding_get_MaxFirings(This,plMaxFirings)	\
    (This)->lpVtbl -> get_MaxFirings(This,plMaxFirings)

#define IEventBinding_put_MaxFirings(This,lMaxFirings)	\
    (This)->lpVtbl -> put_MaxFirings(This,lMaxFirings)

#define IEventBinding_putref_MaxFirings(This,plMaxFirings)	\
    (This)->lpVtbl -> putref_MaxFirings(This,plMaxFirings)

#define IEventBinding_Save(This)	\
    (This)->lpVtbl -> Save(This)

#endif /* COBJMACROS */


#endif 	/* C style interface */



/* [propget][helpstring] */ HRESULT STDMETHODCALLTYPE IEventBinding_get_ID_Proxy( 
    IEventBinding __RPC_FAR * This,
    /* [retval][out] */ BSTR __RPC_FAR *pstrBindingID);


void __RPC_STUB IEventBinding_get_ID_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [propget][helpstring] */ HRESULT STDMETHODCALLTYPE IEventBinding_get_DisplayName_Proxy( 
    IEventBinding __RPC_FAR * This,
    /* [retval][out] */ BSTR __RPC_FAR *pstrDisplayName);


void __RPC_STUB IEventBinding_get_DisplayName_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [propput][helpstring] */ HRESULT STDMETHODCALLTYPE IEventBinding_put_DisplayName_Proxy( 
    IEventBinding __RPC_FAR * This,
    /* [in] */ BSTR pszDisplayName);


void __RPC_STUB IEventBinding_put_DisplayName_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [propputref][helpstring] */ HRESULT STDMETHODCALLTYPE IEventBinding_putref_DisplayName_Proxy( 
    IEventBinding __RPC_FAR * This,
    /* [in] */ BSTR __RPC_FAR *ppszDisplayName);


void __RPC_STUB IEventBinding_putref_DisplayName_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [propget][helpstring] */ HRESULT STDMETHODCALLTYPE IEventBinding_get_SinkClass_Proxy( 
    IEventBinding __RPC_FAR * This,
    /* [retval][out] */ BSTR __RPC_FAR *pstrSinkClass);


void __RPC_STUB IEventBinding_get_SinkClass_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [propput][helpstring] */ HRESULT STDMETHODCALLTYPE IEventBinding_put_SinkClass_Proxy( 
    IEventBinding __RPC_FAR * This,
    /* [in] */ BSTR pszSinkClass);


void __RPC_STUB IEventBinding_put_SinkClass_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [propputref][helpstring] */ HRESULT STDMETHODCALLTYPE IEventBinding_putref_SinkClass_Proxy( 
    IEventBinding __RPC_FAR * This,
    /* [in] */ BSTR __RPC_FAR *ppszSinkClass);


void __RPC_STUB IEventBinding_putref_SinkClass_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [propget][helpstring] */ HRESULT STDMETHODCALLTYPE IEventBinding_get_SinkProperties_Proxy( 
    IEventBinding __RPC_FAR * This,
    /* [retval][out] */ IEventPropertyBag __RPC_FAR *__RPC_FAR *ppSinkProperties);


void __RPC_STUB IEventBinding_get_SinkProperties_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [propget][helpstring] */ HRESULT STDMETHODCALLTYPE IEventBinding_get_SourceProperties_Proxy( 
    IEventBinding __RPC_FAR * This,
    /* [retval][out] */ IEventPropertyBag __RPC_FAR *__RPC_FAR *ppSourceProperties);


void __RPC_STUB IEventBinding_get_SourceProperties_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [propget][helpstring] */ HRESULT STDMETHODCALLTYPE IEventBinding_get_EventBindingProperties_Proxy( 
    IEventBinding __RPC_FAR * This,
    /* [retval][out] */ IEventPropertyBag __RPC_FAR *__RPC_FAR *ppEventBindingProperties);


void __RPC_STUB IEventBinding_get_EventBindingProperties_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [propget][helpstring] */ HRESULT STDMETHODCALLTYPE IEventBinding_get_Enabled_Proxy( 
    IEventBinding __RPC_FAR * This,
    /* [retval][out] */ VARIANT_BOOL __RPC_FAR *pbEnabled);


void __RPC_STUB IEventBinding_get_Enabled_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [propput][helpstring] */ HRESULT STDMETHODCALLTYPE IEventBinding_put_Enabled_Proxy( 
    IEventBinding __RPC_FAR * This,
    /* [in] */ VARIANT_BOOL bEnabled);


void __RPC_STUB IEventBinding_put_Enabled_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [propputref][helpstring] */ HRESULT STDMETHODCALLTYPE IEventBinding_putref_Enabled_Proxy( 
    IEventBinding __RPC_FAR * This,
    /* [in] */ VARIANT_BOOL __RPC_FAR *pbEnabled);


void __RPC_STUB IEventBinding_putref_Enabled_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [propget][helpstring] */ HRESULT STDMETHODCALLTYPE IEventBinding_get_Expiration_Proxy( 
    IEventBinding __RPC_FAR * This,
    /* [retval][out] */ DATE __RPC_FAR *pdateExpiration);


void __RPC_STUB IEventBinding_get_Expiration_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [propput][helpstring] */ HRESULT STDMETHODCALLTYPE IEventBinding_put_Expiration_Proxy( 
    IEventBinding __RPC_FAR * This,
    /* [in] */ DATE dateExpiration);


void __RPC_STUB IEventBinding_put_Expiration_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [propputref][helpstring] */ HRESULT STDMETHODCALLTYPE IEventBinding_putref_Expiration_Proxy( 
    IEventBinding __RPC_FAR * This,
    /* [in] */ DATE __RPC_FAR *pdateExpiration);


void __RPC_STUB IEventBinding_putref_Expiration_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [propget][helpstring] */ HRESULT STDMETHODCALLTYPE IEventBinding_get_MaxFirings_Proxy( 
    IEventBinding __RPC_FAR * This,
    /* [retval][out] */ long __RPC_FAR *plMaxFirings);


void __RPC_STUB IEventBinding_get_MaxFirings_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [propput][helpstring] */ HRESULT STDMETHODCALLTYPE IEventBinding_put_MaxFirings_Proxy( 
    IEventBinding __RPC_FAR * This,
    /* [in] */ long lMaxFirings);


void __RPC_STUB IEventBinding_put_MaxFirings_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [propputref][helpstring] */ HRESULT STDMETHODCALLTYPE IEventBinding_putref_MaxFirings_Proxy( 
    IEventBinding __RPC_FAR * This,
    /* [in] */ long __RPC_FAR *plMaxFirings);


void __RPC_STUB IEventBinding_putref_MaxFirings_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IEventBinding_Save_Proxy( 
    IEventBinding __RPC_FAR * This);


void __RPC_STUB IEventBinding_Save_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);



#endif 	/* __IEventBinding_INTERFACE_DEFINED__ */


#ifndef __IEventBindings_INTERFACE_DEFINED__
#define __IEventBindings_INTERFACE_DEFINED__

/* interface IEventBindings */
/* [uuid][unique][oleautomation][object][helpstring][dual] */ 


EXTERN_C const IID IID_IEventBindings;

#if defined(__cplusplus) && !defined(CINTERFACE)
    
    MIDL_INTERFACE("1080b910-a636-11d0-a9ea-00aa00685c74")
    IEventBindings : public IDispatch
    {
    public:
        virtual /* [id][helpstring] */ HRESULT STDMETHODCALLTYPE Item( 
            /* [in] */ VARIANT __RPC_FAR *pvarDesired,
            /* [retval][out] */ IEventBinding __RPC_FAR *__RPC_FAR *ppEventBinding) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE Add( 
            /* [in] */ BSTR strBinding,
            /* [retval][out] */ IEventBinding __RPC_FAR *__RPC_FAR *ppBinding) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE Remove( 
            /* [in] */ VARIANT __RPC_FAR *pvarDesired) = 0;
        
        virtual /* [propget][helpstring] */ HRESULT STDMETHODCALLTYPE get_Count( 
            /* [retval][out] */ long __RPC_FAR *plCount) = 0;
        
        virtual /* [hidden][propget][id][helpstring] */ HRESULT STDMETHODCALLTYPE get__NewEnum( 
            /* [retval][out] */ IUnknown __RPC_FAR *__RPC_FAR *ppUnkEnum) = 0;
        
    };
    
#else 	/* C style interface */

    typedef struct IEventBindingsVtbl
    {
        BEGIN_INTERFACE
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *QueryInterface )( 
            IEventBindings __RPC_FAR * This,
            /* [in] */ REFIID riid,
            /* [iid_is][out] */ void __RPC_FAR *__RPC_FAR *ppvObject);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *AddRef )( 
            IEventBindings __RPC_FAR * This);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *Release )( 
            IEventBindings __RPC_FAR * This);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetTypeInfoCount )( 
            IEventBindings __RPC_FAR * This,
            /* [out] */ UINT __RPC_FAR *pctinfo);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetTypeInfo )( 
            IEventBindings __RPC_FAR * This,
            /* [in] */ UINT iTInfo,
            /* [in] */ LCID lcid,
            /* [out] */ ITypeInfo __RPC_FAR *__RPC_FAR *ppTInfo);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetIDsOfNames )( 
            IEventBindings __RPC_FAR * This,
            /* [in] */ REFIID riid,
            /* [size_is][in] */ LPOLESTR __RPC_FAR *rgszNames,
            /* [in] */ UINT cNames,
            /* [in] */ LCID lcid,
            /* [size_is][out] */ DISPID __RPC_FAR *rgDispId);
        
        /* [local] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *Invoke )( 
            IEventBindings __RPC_FAR * This,
            /* [in] */ DISPID dispIdMember,
            /* [in] */ REFIID riid,
            /* [in] */ LCID lcid,
            /* [in] */ WORD wFlags,
            /* [out][in] */ DISPPARAMS __RPC_FAR *pDispParams,
            /* [out] */ VARIANT __RPC_FAR *pVarResult,
            /* [out] */ EXCEPINFO __RPC_FAR *pExcepInfo,
            /* [out] */ UINT __RPC_FAR *puArgErr);
        
        /* [id][helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *Item )( 
            IEventBindings __RPC_FAR * This,
            /* [in] */ VARIANT __RPC_FAR *pvarDesired,
            /* [retval][out] */ IEventBinding __RPC_FAR *__RPC_FAR *ppEventBinding);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *Add )( 
            IEventBindings __RPC_FAR * This,
            /* [in] */ BSTR strBinding,
            /* [retval][out] */ IEventBinding __RPC_FAR *__RPC_FAR *ppBinding);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *Remove )( 
            IEventBindings __RPC_FAR * This,
            /* [in] */ VARIANT __RPC_FAR *pvarDesired);
        
        /* [propget][helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *get_Count )( 
            IEventBindings __RPC_FAR * This,
            /* [retval][out] */ long __RPC_FAR *plCount);
        
        /* [hidden][propget][id][helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *get__NewEnum )( 
            IEventBindings __RPC_FAR * This,
            /* [retval][out] */ IUnknown __RPC_FAR *__RPC_FAR *ppUnkEnum);
        
        END_INTERFACE
    } IEventBindingsVtbl;

    interface IEventBindings
    {
        CONST_VTBL struct IEventBindingsVtbl __RPC_FAR *lpVtbl;
    };

    

#ifdef COBJMACROS


#define IEventBindings_QueryInterface(This,riid,ppvObject)	\
    (This)->lpVtbl -> QueryInterface(This,riid,ppvObject)

#define IEventBindings_AddRef(This)	\
    (This)->lpVtbl -> AddRef(This)

#define IEventBindings_Release(This)	\
    (This)->lpVtbl -> Release(This)


#define IEventBindings_GetTypeInfoCount(This,pctinfo)	\
    (This)->lpVtbl -> GetTypeInfoCount(This,pctinfo)

#define IEventBindings_GetTypeInfo(This,iTInfo,lcid,ppTInfo)	\
    (This)->lpVtbl -> GetTypeInfo(This,iTInfo,lcid,ppTInfo)

#define IEventBindings_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)	\
    (This)->lpVtbl -> GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)

#define IEventBindings_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)	\
    (This)->lpVtbl -> Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)


#define IEventBindings_Item(This,pvarDesired,ppEventBinding)	\
    (This)->lpVtbl -> Item(This,pvarDesired,ppEventBinding)

#define IEventBindings_Add(This,strBinding,ppBinding)	\
    (This)->lpVtbl -> Add(This,strBinding,ppBinding)

#define IEventBindings_Remove(This,pvarDesired)	\
    (This)->lpVtbl -> Remove(This,pvarDesired)

#define IEventBindings_get_Count(This,plCount)	\
    (This)->lpVtbl -> get_Count(This,plCount)

#define IEventBindings_get__NewEnum(This,ppUnkEnum)	\
    (This)->lpVtbl -> get__NewEnum(This,ppUnkEnum)

#endif /* COBJMACROS */


#endif 	/* C style interface */



/* [id][helpstring] */ HRESULT STDMETHODCALLTYPE IEventBindings_Item_Proxy( 
    IEventBindings __RPC_FAR * This,
    /* [in] */ VARIANT __RPC_FAR *pvarDesired,
    /* [retval][out] */ IEventBinding __RPC_FAR *__RPC_FAR *ppEventBinding);


void __RPC_STUB IEventBindings_Item_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IEventBindings_Add_Proxy( 
    IEventBindings __RPC_FAR * This,
    /* [in] */ BSTR strBinding,
    /* [retval][out] */ IEventBinding __RPC_FAR *__RPC_FAR *ppBinding);


void __RPC_STUB IEventBindings_Add_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IEventBindings_Remove_Proxy( 
    IEventBindings __RPC_FAR * This,
    /* [in] */ VARIANT __RPC_FAR *pvarDesired);


void __RPC_STUB IEventBindings_Remove_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [propget][helpstring] */ HRESULT STDMETHODCALLTYPE IEventBindings_get_Count_Proxy( 
    IEventBindings __RPC_FAR * This,
    /* [retval][out] */ long __RPC_FAR *plCount);


void __RPC_STUB IEventBindings_get_Count_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [hidden][propget][id][helpstring] */ HRESULT STDMETHODCALLTYPE IEventBindings_get__NewEnum_Proxy( 
    IEventBindings __RPC_FAR * This,
    /* [retval][out] */ IUnknown __RPC_FAR *__RPC_FAR *ppUnkEnum);


void __RPC_STUB IEventBindings_get__NewEnum_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);



#endif 	/* __IEventBindings_INTERFACE_DEFINED__ */


#ifndef __IEventTypes_INTERFACE_DEFINED__
#define __IEventTypes_INTERFACE_DEFINED__

/* interface IEventTypes */
/* [uuid][unique][oleautomation][object][helpstring][dual] */ 


EXTERN_C const IID IID_IEventTypes;

#if defined(__cplusplus) && !defined(CINTERFACE)
    
    MIDL_INTERFACE("cab29ef0-a64f-11d0-a9ea-00aa00685c74")
    IEventTypes : public IDispatch
    {
    public:
        virtual /* [id][helpstring] */ HRESULT STDMETHODCALLTYPE Item( 
            /* [in] */ VARIANT __RPC_FAR *pvarDesired,
            /* [retval][out] */ IEventType __RPC_FAR *__RPC_FAR *ppEventType) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE Add( 
            /* [in] */ BSTR pszEventType) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE Remove( 
            /* [in] */ BSTR pszEventType) = 0;
        
        virtual /* [propget][helpstring] */ HRESULT STDMETHODCALLTYPE get_Count( 
            /* [retval][out] */ long __RPC_FAR *plCount) = 0;
        
        virtual /* [hidden][propget][id][helpstring] */ HRESULT STDMETHODCALLTYPE get__NewEnum( 
            /* [retval][out] */ IUnknown __RPC_FAR *__RPC_FAR *ppUnkEnum) = 0;
        
    };
    
#else 	/* C style interface */

    typedef struct IEventTypesVtbl
    {
        BEGIN_INTERFACE
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *QueryInterface )( 
            IEventTypes __RPC_FAR * This,
            /* [in] */ REFIID riid,
            /* [iid_is][out] */ void __RPC_FAR *__RPC_FAR *ppvObject);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *AddRef )( 
            IEventTypes __RPC_FAR * This);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *Release )( 
            IEventTypes __RPC_FAR * This);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetTypeInfoCount )( 
            IEventTypes __RPC_FAR * This,
            /* [out] */ UINT __RPC_FAR *pctinfo);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetTypeInfo )( 
            IEventTypes __RPC_FAR * This,
            /* [in] */ UINT iTInfo,
            /* [in] */ LCID lcid,
            /* [out] */ ITypeInfo __RPC_FAR *__RPC_FAR *ppTInfo);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetIDsOfNames )( 
            IEventTypes __RPC_FAR * This,
            /* [in] */ REFIID riid,
            /* [size_is][in] */ LPOLESTR __RPC_FAR *rgszNames,
            /* [in] */ UINT cNames,
            /* [in] */ LCID lcid,
            /* [size_is][out] */ DISPID __RPC_FAR *rgDispId);
        
        /* [local] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *Invoke )( 
            IEventTypes __RPC_FAR * This,
            /* [in] */ DISPID dispIdMember,
            /* [in] */ REFIID riid,
            /* [in] */ LCID lcid,
            /* [in] */ WORD wFlags,
            /* [out][in] */ DISPPARAMS __RPC_FAR *pDispParams,
            /* [out] */ VARIANT __RPC_FAR *pVarResult,
            /* [out] */ EXCEPINFO __RPC_FAR *pExcepInfo,
            /* [out] */ UINT __RPC_FAR *puArgErr);
        
        /* [id][helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *Item )( 
            IEventTypes __RPC_FAR * This,
            /* [in] */ VARIANT __RPC_FAR *pvarDesired,
            /* [retval][out] */ IEventType __RPC_FAR *__RPC_FAR *ppEventType);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *Add )( 
            IEventTypes __RPC_FAR * This,
            /* [in] */ BSTR pszEventType);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *Remove )( 
            IEventTypes __RPC_FAR * This,
            /* [in] */ BSTR pszEventType);
        
        /* [propget][helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *get_Count )( 
            IEventTypes __RPC_FAR * This,
            /* [retval][out] */ long __RPC_FAR *plCount);
        
        /* [hidden][propget][id][helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *get__NewEnum )( 
            IEventTypes __RPC_FAR * This,
            /* [retval][out] */ IUnknown __RPC_FAR *__RPC_FAR *ppUnkEnum);
        
        END_INTERFACE
    } IEventTypesVtbl;

    interface IEventTypes
    {
        CONST_VTBL struct IEventTypesVtbl __RPC_FAR *lpVtbl;
    };

    

#ifdef COBJMACROS


#define IEventTypes_QueryInterface(This,riid,ppvObject)	\
    (This)->lpVtbl -> QueryInterface(This,riid,ppvObject)

#define IEventTypes_AddRef(This)	\
    (This)->lpVtbl -> AddRef(This)

#define IEventTypes_Release(This)	\
    (This)->lpVtbl -> Release(This)


#define IEventTypes_GetTypeInfoCount(This,pctinfo)	\
    (This)->lpVtbl -> GetTypeInfoCount(This,pctinfo)

#define IEventTypes_GetTypeInfo(This,iTInfo,lcid,ppTInfo)	\
    (This)->lpVtbl -> GetTypeInfo(This,iTInfo,lcid,ppTInfo)

#define IEventTypes_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)	\
    (This)->lpVtbl -> GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)

#define IEventTypes_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)	\
    (This)->lpVtbl -> Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)


#define IEventTypes_Item(This,pvarDesired,ppEventType)	\
    (This)->lpVtbl -> Item(This,pvarDesired,ppEventType)

#define IEventTypes_Add(This,pszEventType)	\
    (This)->lpVtbl -> Add(This,pszEventType)

#define IEventTypes_Remove(This,pszEventType)	\
    (This)->lpVtbl -> Remove(This,pszEventType)

#define IEventTypes_get_Count(This,plCount)	\
    (This)->lpVtbl -> get_Count(This,plCount)

#define IEventTypes_get__NewEnum(This,ppUnkEnum)	\
    (This)->lpVtbl -> get__NewEnum(This,ppUnkEnum)

#endif /* COBJMACROS */


#endif 	/* C style interface */



/* [id][helpstring] */ HRESULT STDMETHODCALLTYPE IEventTypes_Item_Proxy( 
    IEventTypes __RPC_FAR * This,
    /* [in] */ VARIANT __RPC_FAR *pvarDesired,
    /* [retval][out] */ IEventType __RPC_FAR *__RPC_FAR *ppEventType);


void __RPC_STUB IEventTypes_Item_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IEventTypes_Add_Proxy( 
    IEventTypes __RPC_FAR * This,
    /* [in] */ BSTR pszEventType);


void __RPC_STUB IEventTypes_Add_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IEventTypes_Remove_Proxy( 
    IEventTypes __RPC_FAR * This,
    /* [in] */ BSTR pszEventType);


void __RPC_STUB IEventTypes_Remove_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [propget][helpstring] */ HRESULT STDMETHODCALLTYPE IEventTypes_get_Count_Proxy( 
    IEventTypes __RPC_FAR * This,
    /* [retval][out] */ long __RPC_FAR *plCount);


void __RPC_STUB IEventTypes_get_Count_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [hidden][propget][id][helpstring] */ HRESULT STDMETHODCALLTYPE IEventTypes_get__NewEnum_Proxy( 
    IEventTypes __RPC_FAR * This,
    /* [retval][out] */ IUnknown __RPC_FAR *__RPC_FAR *ppUnkEnum);


void __RPC_STUB IEventTypes_get__NewEnum_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);



#endif 	/* __IEventTypes_INTERFACE_DEFINED__ */


#ifndef __IEventBindingManager_INTERFACE_DEFINED__
#define __IEventBindingManager_INTERFACE_DEFINED__

/* interface IEventBindingManager */
/* [uuid][unique][oleautomation][object][helpstring][dual] */ 


EXTERN_C const IID IID_IEventBindingManager;

#if defined(__cplusplus) && !defined(CINTERFACE)
    
    MIDL_INTERFACE("0b4cdbc0-a64f-11d0-a9ea-00aa00685c74")
    IEventBindingManager : public IDispatch
    {
    public:
        virtual /* [propget][helpstring] */ HRESULT STDMETHODCALLTYPE get_Bindings( 
            /* [in] */ BSTR pszEventType,
            /* [retval][out] */ IEventBindings __RPC_FAR *__RPC_FAR *ppBindings) = 0;
        
        virtual /* [hidden][propget][id][helpstring] */ HRESULT STDMETHODCALLTYPE get__NewEnum( 
            /* [retval][out] */ IUnknown __RPC_FAR *__RPC_FAR *ppUnkEnum) = 0;
        
    };
    
#else 	/* C style interface */

    typedef struct IEventBindingManagerVtbl
    {
        BEGIN_INTERFACE
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *QueryInterface )( 
            IEventBindingManager __RPC_FAR * This,
            /* [in] */ REFIID riid,
            /* [iid_is][out] */ void __RPC_FAR *__RPC_FAR *ppvObject);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *AddRef )( 
            IEventBindingManager __RPC_FAR * This);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *Release )( 
            IEventBindingManager __RPC_FAR * This);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetTypeInfoCount )( 
            IEventBindingManager __RPC_FAR * This,
            /* [out] */ UINT __RPC_FAR *pctinfo);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetTypeInfo )( 
            IEventBindingManager __RPC_FAR * This,
            /* [in] */ UINT iTInfo,
            /* [in] */ LCID lcid,
            /* [out] */ ITypeInfo __RPC_FAR *__RPC_FAR *ppTInfo);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetIDsOfNames )( 
            IEventBindingManager __RPC_FAR * This,
            /* [in] */ REFIID riid,
            /* [size_is][in] */ LPOLESTR __RPC_FAR *rgszNames,
            /* [in] */ UINT cNames,
            /* [in] */ LCID lcid,
            /* [size_is][out] */ DISPID __RPC_FAR *rgDispId);
        
        /* [local] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *Invoke )( 
            IEventBindingManager __RPC_FAR * This,
            /* [in] */ DISPID dispIdMember,
            /* [in] */ REFIID riid,
            /* [in] */ LCID lcid,
            /* [in] */ WORD wFlags,
            /* [out][in] */ DISPPARAMS __RPC_FAR *pDispParams,
            /* [out] */ VARIANT __RPC_FAR *pVarResult,
            /* [out] */ EXCEPINFO __RPC_FAR *pExcepInfo,
            /* [out] */ UINT __RPC_FAR *puArgErr);
        
        /* [propget][helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *get_Bindings )( 
            IEventBindingManager __RPC_FAR * This,
            /* [in] */ BSTR pszEventType,
            /* [retval][out] */ IEventBindings __RPC_FAR *__RPC_FAR *ppBindings);
        
        /* [hidden][propget][id][helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *get__NewEnum )( 
            IEventBindingManager __RPC_FAR * This,
            /* [retval][out] */ IUnknown __RPC_FAR *__RPC_FAR *ppUnkEnum);
        
        END_INTERFACE
    } IEventBindingManagerVtbl;

    interface IEventBindingManager
    {
        CONST_VTBL struct IEventBindingManagerVtbl __RPC_FAR *lpVtbl;
    };

    

#ifdef COBJMACROS


#define IEventBindingManager_QueryInterface(This,riid,ppvObject)	\
    (This)->lpVtbl -> QueryInterface(This,riid,ppvObject)

#define IEventBindingManager_AddRef(This)	\
    (This)->lpVtbl -> AddRef(This)

#define IEventBindingManager_Release(This)	\
    (This)->lpVtbl -> Release(This)


#define IEventBindingManager_GetTypeInfoCount(This,pctinfo)	\
    (This)->lpVtbl -> GetTypeInfoCount(This,pctinfo)

#define IEventBindingManager_GetTypeInfo(This,iTInfo,lcid,ppTInfo)	\
    (This)->lpVtbl -> GetTypeInfo(This,iTInfo,lcid,ppTInfo)

#define IEventBindingManager_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)	\
    (This)->lpVtbl -> GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)

#define IEventBindingManager_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)	\
    (This)->lpVtbl -> Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)


#define IEventBindingManager_get_Bindings(This,pszEventType,ppBindings)	\
    (This)->lpVtbl -> get_Bindings(This,pszEventType,ppBindings)

#define IEventBindingManager_get__NewEnum(This,ppUnkEnum)	\
    (This)->lpVtbl -> get__NewEnum(This,ppUnkEnum)

#endif /* COBJMACROS */


#endif 	/* C style interface */



/* [propget][helpstring] */ HRESULT STDMETHODCALLTYPE IEventBindingManager_get_Bindings_Proxy( 
    IEventBindingManager __RPC_FAR * This,
    /* [in] */ BSTR pszEventType,
    /* [retval][out] */ IEventBindings __RPC_FAR *__RPC_FAR *ppBindings);


void __RPC_STUB IEventBindingManager_get_Bindings_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [hidden][propget][id][helpstring] */ HRESULT STDMETHODCALLTYPE IEventBindingManager_get__NewEnum_Proxy( 
    IEventBindingManager __RPC_FAR * This,
    /* [retval][out] */ IUnknown __RPC_FAR *__RPC_FAR *ppUnkEnum);


void __RPC_STUB IEventBindingManager_get__NewEnum_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);



#endif 	/* __IEventBindingManager_INTERFACE_DEFINED__ */


#ifndef __IEventBindingManagerCopier_INTERFACE_DEFINED__
#define __IEventBindingManagerCopier_INTERFACE_DEFINED__

/* interface IEventBindingManagerCopier */
/* [uuid][unique][oleautomation][object][hidden][helpstring][dual] */ 


EXTERN_C const IID IID_IEventBindingManagerCopier;

#if defined(__cplusplus) && !defined(CINTERFACE)
    
    MIDL_INTERFACE("64bad540-f88d-11d0-aa14-00aa006bc80b")
    IEventBindingManagerCopier : public IDispatch
    {
    public:
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE Copy( 
            /* [in] */ long lTimeout,
            /* [retval][out] */ IEventBindingManager __RPC_FAR *__RPC_FAR *ppBindingManager) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE EmptyCopy( 
            /* [retval][out] */ IEventBindingManager __RPC_FAR *__RPC_FAR *ppBindingManager) = 0;
        
    };
    
#else 	/* C style interface */

    typedef struct IEventBindingManagerCopierVtbl
    {
        BEGIN_INTERFACE
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *QueryInterface )( 
            IEventBindingManagerCopier __RPC_FAR * This,
            /* [in] */ REFIID riid,
            /* [iid_is][out] */ void __RPC_FAR *__RPC_FAR *ppvObject);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *AddRef )( 
            IEventBindingManagerCopier __RPC_FAR * This);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *Release )( 
            IEventBindingManagerCopier __RPC_FAR * This);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetTypeInfoCount )( 
            IEventBindingManagerCopier __RPC_FAR * This,
            /* [out] */ UINT __RPC_FAR *pctinfo);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetTypeInfo )( 
            IEventBindingManagerCopier __RPC_FAR * This,
            /* [in] */ UINT iTInfo,
            /* [in] */ LCID lcid,
            /* [out] */ ITypeInfo __RPC_FAR *__RPC_FAR *ppTInfo);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetIDsOfNames )( 
            IEventBindingManagerCopier __RPC_FAR * This,
            /* [in] */ REFIID riid,
            /* [size_is][in] */ LPOLESTR __RPC_FAR *rgszNames,
            /* [in] */ UINT cNames,
            /* [in] */ LCID lcid,
            /* [size_is][out] */ DISPID __RPC_FAR *rgDispId);
        
        /* [local] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *Invoke )( 
            IEventBindingManagerCopier __RPC_FAR * This,
            /* [in] */ DISPID dispIdMember,
            /* [in] */ REFIID riid,
            /* [in] */ LCID lcid,
            /* [in] */ WORD wFlags,
            /* [out][in] */ DISPPARAMS __RPC_FAR *pDispParams,
            /* [out] */ VARIANT __RPC_FAR *pVarResult,
            /* [out] */ EXCEPINFO __RPC_FAR *pExcepInfo,
            /* [out] */ UINT __RPC_FAR *puArgErr);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *Copy )( 
            IEventBindingManagerCopier __RPC_FAR * This,
            /* [in] */ long lTimeout,
            /* [retval][out] */ IEventBindingManager __RPC_FAR *__RPC_FAR *ppBindingManager);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *EmptyCopy )( 
            IEventBindingManagerCopier __RPC_FAR * This,
            /* [retval][out] */ IEventBindingManager __RPC_FAR *__RPC_FAR *ppBindingManager);
        
        END_INTERFACE
    } IEventBindingManagerCopierVtbl;

    interface IEventBindingManagerCopier
    {
        CONST_VTBL struct IEventBindingManagerCopierVtbl __RPC_FAR *lpVtbl;
    };

    

#ifdef COBJMACROS


#define IEventBindingManagerCopier_QueryInterface(This,riid,ppvObject)	\
    (This)->lpVtbl -> QueryInterface(This,riid,ppvObject)

#define IEventBindingManagerCopier_AddRef(This)	\
    (This)->lpVtbl -> AddRef(This)

#define IEventBindingManagerCopier_Release(This)	\
    (This)->lpVtbl -> Release(This)


#define IEventBindingManagerCopier_GetTypeInfoCount(This,pctinfo)	\
    (This)->lpVtbl -> GetTypeInfoCount(This,pctinfo)

#define IEventBindingManagerCopier_GetTypeInfo(This,iTInfo,lcid,ppTInfo)	\
    (This)->lpVtbl -> GetTypeInfo(This,iTInfo,lcid,ppTInfo)

#define IEventBindingManagerCopier_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)	\
    (This)->lpVtbl -> GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)

#define IEventBindingManagerCopier_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)	\
    (This)->lpVtbl -> Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)


#define IEventBindingManagerCopier_Copy(This,lTimeout,ppBindingManager)	\
    (This)->lpVtbl -> Copy(This,lTimeout,ppBindingManager)

#define IEventBindingManagerCopier_EmptyCopy(This,ppBindingManager)	\
    (This)->lpVtbl -> EmptyCopy(This,ppBindingManager)

#endif /* COBJMACROS */


#endif 	/* C style interface */



/* [helpstring] */ HRESULT STDMETHODCALLTYPE IEventBindingManagerCopier_Copy_Proxy( 
    IEventBindingManagerCopier __RPC_FAR * This,
    /* [in] */ long lTimeout,
    /* [retval][out] */ IEventBindingManager __RPC_FAR *__RPC_FAR *ppBindingManager);


void __RPC_STUB IEventBindingManagerCopier_Copy_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IEventBindingManagerCopier_EmptyCopy_Proxy( 
    IEventBindingManagerCopier __RPC_FAR * This,
    /* [retval][out] */ IEventBindingManager __RPC_FAR *__RPC_FAR *ppBindingManager);


void __RPC_STUB IEventBindingManagerCopier_EmptyCopy_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);



#endif 	/* __IEventBindingManagerCopier_INTERFACE_DEFINED__ */


/* interface __MIDL_itf_Seo_0296 */
/* [local] */ 




extern RPC_IF_HANDLE __MIDL_itf_Seo_0296_v0_0_c_ifspec;
extern RPC_IF_HANDLE __MIDL_itf_Seo_0296_v0_0_s_ifspec;

#ifndef __IEventRouter_INTERFACE_DEFINED__
#define __IEventRouter_INTERFACE_DEFINED__

/* interface IEventRouter */
/* [uuid][unique][object][hidden][helpstring] */ 


EXTERN_C const IID IID_IEventRouter;

#if defined(__cplusplus) && !defined(CINTERFACE)
    
    MIDL_INTERFACE("1a00b970-eda0-11d0-aa10-00aa006bc80b")
    IEventRouter : public IUnknown
    {
    public:
        virtual /* [propget][helpstring] */ HRESULT STDMETHODCALLTYPE get_Database( 
            /* [retval][out] */ IEventBindingManager __RPC_FAR *__RPC_FAR *ppBindingManager) = 0;
        
        virtual /* [propput][helpstring] */ HRESULT STDMETHODCALLTYPE put_Database( 
            /* [unique][in] */ IEventBindingManager __RPC_FAR *pBindingManager) = 0;
        
        virtual /* [propputref][helpstring] */ HRESULT STDMETHODCALLTYPE putref_Database( 
            /* [unique][in] */ IEventBindingManager __RPC_FAR *__RPC_FAR *ppBindingManager) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE GetDispatcher( 
            /* [in] */ REFIID iidEvent,
            /* [in] */ REFIID iidDesired,
            /* [retval][iid_is][out] */ IUnknown __RPC_FAR *__RPC_FAR *ppUnkResult) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE GetDispatcherByCLSID( 
            /* [in] */ REFCLSID clsidDispatcher,
            /* [in] */ REFIID iidEvent,
            /* [in] */ REFIID iidDesired,
            /* [retval][iid_is][out] */ IUnknown __RPC_FAR *__RPC_FAR *ppUnkResult) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE GetDispatcherByClassFactory( 
            /* [in] */ REFCLSID clsidDispatcher,
            /* [in] */ IClassFactory __RPC_FAR *piClassFactory,
            /* [in] */ REFIID iidEvent,
            /* [in] */ REFIID iidDesired,
            /* [retval][iid_is][out] */ IUnknown __RPC_FAR *__RPC_FAR *ppUnkResult) = 0;
        
    };
    
#else 	/* C style interface */

    typedef struct IEventRouterVtbl
    {
        BEGIN_INTERFACE
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *QueryInterface )( 
            IEventRouter __RPC_FAR * This,
            /* [in] */ REFIID riid,
            /* [iid_is][out] */ void __RPC_FAR *__RPC_FAR *ppvObject);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *AddRef )( 
            IEventRouter __RPC_FAR * This);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *Release )( 
            IEventRouter __RPC_FAR * This);
        
        /* [propget][helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *get_Database )( 
            IEventRouter __RPC_FAR * This,
            /* [retval][out] */ IEventBindingManager __RPC_FAR *__RPC_FAR *ppBindingManager);
        
        /* [propput][helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *put_Database )( 
            IEventRouter __RPC_FAR * This,
            /* [unique][in] */ IEventBindingManager __RPC_FAR *pBindingManager);
        
        /* [propputref][helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *putref_Database )( 
            IEventRouter __RPC_FAR * This,
            /* [unique][in] */ IEventBindingManager __RPC_FAR *__RPC_FAR *ppBindingManager);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetDispatcher )( 
            IEventRouter __RPC_FAR * This,
            /* [in] */ REFIID iidEvent,
            /* [in] */ REFIID iidDesired,
            /* [retval][iid_is][out] */ IUnknown __RPC_FAR *__RPC_FAR *ppUnkResult);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetDispatcherByCLSID )( 
            IEventRouter __RPC_FAR * This,
            /* [in] */ REFCLSID clsidDispatcher,
            /* [in] */ REFIID iidEvent,
            /* [in] */ REFIID iidDesired,
            /* [retval][iid_is][out] */ IUnknown __RPC_FAR *__RPC_FAR *ppUnkResult);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetDispatcherByClassFactory )( 
            IEventRouter __RPC_FAR * This,
            /* [in] */ REFCLSID clsidDispatcher,
            /* [in] */ IClassFactory __RPC_FAR *piClassFactory,
            /* [in] */ REFIID iidEvent,
            /* [in] */ REFIID iidDesired,
            /* [retval][iid_is][out] */ IUnknown __RPC_FAR *__RPC_FAR *ppUnkResult);
        
        END_INTERFACE
    } IEventRouterVtbl;

    interface IEventRouter
    {
        CONST_VTBL struct IEventRouterVtbl __RPC_FAR *lpVtbl;
    };

    

#ifdef COBJMACROS


#define IEventRouter_QueryInterface(This,riid,ppvObject)	\
    (This)->lpVtbl -> QueryInterface(This,riid,ppvObject)

#define IEventRouter_AddRef(This)	\
    (This)->lpVtbl -> AddRef(This)

#define IEventRouter_Release(This)	\
    (This)->lpVtbl -> Release(This)


#define IEventRouter_get_Database(This,ppBindingManager)	\
    (This)->lpVtbl -> get_Database(This,ppBindingManager)

#define IEventRouter_put_Database(This,pBindingManager)	\
    (This)->lpVtbl -> put_Database(This,pBindingManager)

#define IEventRouter_putref_Database(This,ppBindingManager)	\
    (This)->lpVtbl -> putref_Database(This,ppBindingManager)

#define IEventRouter_GetDispatcher(This,iidEvent,iidDesired,ppUnkResult)	\
    (This)->lpVtbl -> GetDispatcher(This,iidEvent,iidDesired,ppUnkResult)

#define IEventRouter_GetDispatcherByCLSID(This,clsidDispatcher,iidEvent,iidDesired,ppUnkResult)	\
    (This)->lpVtbl -> GetDispatcherByCLSID(This,clsidDispatcher,iidEvent,iidDesired,ppUnkResult)

#define IEventRouter_GetDispatcherByClassFactory(This,clsidDispatcher,piClassFactory,iidEvent,iidDesired,ppUnkResult)	\
    (This)->lpVtbl -> GetDispatcherByClassFactory(This,clsidDispatcher,piClassFactory,iidEvent,iidDesired,ppUnkResult)

#endif /* COBJMACROS */


#endif 	/* C style interface */



/* [propget][helpstring] */ HRESULT STDMETHODCALLTYPE IEventRouter_get_Database_Proxy( 
    IEventRouter __RPC_FAR * This,
    /* [retval][out] */ IEventBindingManager __RPC_FAR *__RPC_FAR *ppBindingManager);


void __RPC_STUB IEventRouter_get_Database_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [propput][helpstring] */ HRESULT STDMETHODCALLTYPE IEventRouter_put_Database_Proxy( 
    IEventRouter __RPC_FAR * This,
    /* [unique][in] */ IEventBindingManager __RPC_FAR *pBindingManager);


void __RPC_STUB IEventRouter_put_Database_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [propputref][helpstring] */ HRESULT STDMETHODCALLTYPE IEventRouter_putref_Database_Proxy( 
    IEventRouter __RPC_FAR * This,
    /* [unique][in] */ IEventBindingManager __RPC_FAR *__RPC_FAR *ppBindingManager);


void __RPC_STUB IEventRouter_putref_Database_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IEventRouter_GetDispatcher_Proxy( 
    IEventRouter __RPC_FAR * This,
    /* [in] */ REFIID iidEvent,
    /* [in] */ REFIID iidDesired,
    /* [retval][iid_is][out] */ IUnknown __RPC_FAR *__RPC_FAR *ppUnkResult);


void __RPC_STUB IEventRouter_GetDispatcher_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IEventRouter_GetDispatcherByCLSID_Proxy( 
    IEventRouter __RPC_FAR * This,
    /* [in] */ REFCLSID clsidDispatcher,
    /* [in] */ REFIID iidEvent,
    /* [in] */ REFIID iidDesired,
    /* [retval][iid_is][out] */ IUnknown __RPC_FAR *__RPC_FAR *ppUnkResult);


void __RPC_STUB IEventRouter_GetDispatcherByCLSID_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IEventRouter_GetDispatcherByClassFactory_Proxy( 
    IEventRouter __RPC_FAR * This,
    /* [in] */ REFCLSID clsidDispatcher,
    /* [in] */ IClassFactory __RPC_FAR *piClassFactory,
    /* [in] */ REFIID iidEvent,
    /* [in] */ REFIID iidDesired,
    /* [retval][iid_is][out] */ IUnknown __RPC_FAR *__RPC_FAR *ppUnkResult);


void __RPC_STUB IEventRouter_GetDispatcherByClassFactory_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);



#endif 	/* __IEventRouter_INTERFACE_DEFINED__ */


#ifndef __IEventDispatcher_INTERFACE_DEFINED__
#define __IEventDispatcher_INTERFACE_DEFINED__

/* interface IEventDispatcher */
/* [uuid][unique][object][hidden][helpstring] */ 


EXTERN_C const IID IID_IEventDispatcher;

#if defined(__cplusplus) && !defined(CINTERFACE)
    
    MIDL_INTERFACE("c980f550-ed9e-11d0-aa10-00aa006bc80b")
    IEventDispatcher : public IUnknown
    {
    public:
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE SetContext( 
            /* [in] */ REFGUID guidEventType,
            /* [in] */ IEventRouter __RPC_FAR *piRouter,
            /* [in] */ IEventBindings __RPC_FAR *pBindings) = 0;
        
    };
    
#else 	/* C style interface */

    typedef struct IEventDispatcherVtbl
    {
        BEGIN_INTERFACE
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *QueryInterface )( 
            IEventDispatcher __RPC_FAR * This,
            /* [in] */ REFIID riid,
            /* [iid_is][out] */ void __RPC_FAR *__RPC_FAR *ppvObject);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *AddRef )( 
            IEventDispatcher __RPC_FAR * This);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *Release )( 
            IEventDispatcher __RPC_FAR * This);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *SetContext )( 
            IEventDispatcher __RPC_FAR * This,
            /* [in] */ REFGUID guidEventType,
            /* [in] */ IEventRouter __RPC_FAR *piRouter,
            /* [in] */ IEventBindings __RPC_FAR *pBindings);
        
        END_INTERFACE
    } IEventDispatcherVtbl;

    interface IEventDispatcher
    {
        CONST_VTBL struct IEventDispatcherVtbl __RPC_FAR *lpVtbl;
    };

    

#ifdef COBJMACROS


#define IEventDispatcher_QueryInterface(This,riid,ppvObject)	\
    (This)->lpVtbl -> QueryInterface(This,riid,ppvObject)

#define IEventDispatcher_AddRef(This)	\
    (This)->lpVtbl -> AddRef(This)

#define IEventDispatcher_Release(This)	\
    (This)->lpVtbl -> Release(This)


#define IEventDispatcher_SetContext(This,guidEventType,piRouter,pBindings)	\
    (This)->lpVtbl -> SetContext(This,guidEventType,piRouter,pBindings)

#endif /* COBJMACROS */


#endif 	/* C style interface */



/* [helpstring] */ HRESULT STDMETHODCALLTYPE IEventDispatcher_SetContext_Proxy( 
    IEventDispatcher __RPC_FAR * This,
    /* [in] */ REFGUID guidEventType,
    /* [in] */ IEventRouter __RPC_FAR *piRouter,
    /* [in] */ IEventBindings __RPC_FAR *pBindings);


void __RPC_STUB IEventDispatcher_SetContext_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);



#endif 	/* __IEventDispatcher_INTERFACE_DEFINED__ */


/* interface __MIDL_itf_Seo_0302 */
/* [local] */ 




extern RPC_IF_HANDLE __MIDL_itf_Seo_0302_v0_0_c_ifspec;
extern RPC_IF_HANDLE __MIDL_itf_Seo_0302_v0_0_s_ifspec;

#ifndef __IEventSource_INTERFACE_DEFINED__
#define __IEventSource_INTERFACE_DEFINED__

/* interface IEventSource */
/* [uuid][unique][oleautomation][object][helpstring][dual] */ 


EXTERN_C const IID IID_IEventSource;

#if defined(__cplusplus) && !defined(CINTERFACE)
    
    MIDL_INTERFACE("b1dcb040-a652-11d0-a9ea-00aa00685c74")
    IEventSource : public IDispatch
    {
    public:
        virtual /* [propget][helpstring] */ HRESULT STDMETHODCALLTYPE get_ID( 
            /* [retval][out] */ BSTR __RPC_FAR *pstrID) = 0;
        
        virtual /* [propget][helpstring] */ HRESULT STDMETHODCALLTYPE get_DisplayName( 
            /* [retval][out] */ BSTR __RPC_FAR *pstrDisplayName) = 0;
        
        virtual /* [propput][helpstring] */ HRESULT STDMETHODCALLTYPE put_DisplayName( 
            /* [in] */ BSTR pszDisplayName) = 0;
        
        virtual /* [propputref][helpstring] */ HRESULT STDMETHODCALLTYPE putref_DisplayName( 
            /* [in] */ BSTR __RPC_FAR *ppszDisplayName) = 0;
        
        virtual /* [propget][helpstring] */ HRESULT STDMETHODCALLTYPE get_BindingManagerMoniker( 
            /* [retval][out] */ IUnknown __RPC_FAR *__RPC_FAR *ppUnkMoniker) = 0;
        
        virtual /* [propput][helpstring] */ HRESULT STDMETHODCALLTYPE put_BindingManagerMoniker( 
            /* [in] */ IUnknown __RPC_FAR *pUnkMoniker) = 0;
        
        virtual /* [propputref][helpstring] */ HRESULT STDMETHODCALLTYPE putref_BindingManagerMoniker( 
            /* [in] */ IUnknown __RPC_FAR *__RPC_FAR *ppUnkMoniker) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE GetBindingManager( 
            /* [retval][out] */ IEventBindingManager __RPC_FAR *__RPC_FAR *ppBindingManager) = 0;
        
        virtual /* [propget][helpstring] */ HRESULT STDMETHODCALLTYPE get_Properties( 
            /* [retval][out] */ IEventPropertyBag __RPC_FAR *__RPC_FAR *ppProperties) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE Save( void) = 0;
        
    };
    
#else 	/* C style interface */

    typedef struct IEventSourceVtbl
    {
        BEGIN_INTERFACE
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *QueryInterface )( 
            IEventSource __RPC_FAR * This,
            /* [in] */ REFIID riid,
            /* [iid_is][out] */ void __RPC_FAR *__RPC_FAR *ppvObject);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *AddRef )( 
            IEventSource __RPC_FAR * This);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *Release )( 
            IEventSource __RPC_FAR * This);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetTypeInfoCount )( 
            IEventSource __RPC_FAR * This,
            /* [out] */ UINT __RPC_FAR *pctinfo);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetTypeInfo )( 
            IEventSource __RPC_FAR * This,
            /* [in] */ UINT iTInfo,
            /* [in] */ LCID lcid,
            /* [out] */ ITypeInfo __RPC_FAR *__RPC_FAR *ppTInfo);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetIDsOfNames )( 
            IEventSource __RPC_FAR * This,
            /* [in] */ REFIID riid,
            /* [size_is][in] */ LPOLESTR __RPC_FAR *rgszNames,
            /* [in] */ UINT cNames,
            /* [in] */ LCID lcid,
            /* [size_is][out] */ DISPID __RPC_FAR *rgDispId);
        
        /* [local] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *Invoke )( 
            IEventSource __RPC_FAR * This,
            /* [in] */ DISPID dispIdMember,
            /* [in] */ REFIID riid,
            /* [in] */ LCID lcid,
            /* [in] */ WORD wFlags,
            /* [out][in] */ DISPPARAMS __RPC_FAR *pDispParams,
            /* [out] */ VARIANT __RPC_FAR *pVarResult,
            /* [out] */ EXCEPINFO __RPC_FAR *pExcepInfo,
            /* [out] */ UINT __RPC_FAR *puArgErr);
        
        /* [propget][helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *get_ID )( 
            IEventSource __RPC_FAR * This,
            /* [retval][out] */ BSTR __RPC_FAR *pstrID);
        
        /* [propget][helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *get_DisplayName )( 
            IEventSource __RPC_FAR * This,
            /* [retval][out] */ BSTR __RPC_FAR *pstrDisplayName);
        
        /* [propput][helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *put_DisplayName )( 
            IEventSource __RPC_FAR * This,
            /* [in] */ BSTR pszDisplayName);
        
        /* [propputref][helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *putref_DisplayName )( 
            IEventSource __RPC_FAR * This,
            /* [in] */ BSTR __RPC_FAR *ppszDisplayName);
        
        /* [propget][helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *get_BindingManagerMoniker )( 
            IEventSource __RPC_FAR * This,
            /* [retval][out] */ IUnknown __RPC_FAR *__RPC_FAR *ppUnkMoniker);
        
        /* [propput][helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *put_BindingManagerMoniker )( 
            IEventSource __RPC_FAR * This,
            /* [in] */ IUnknown __RPC_FAR *pUnkMoniker);
        
        /* [propputref][helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *putref_BindingManagerMoniker )( 
            IEventSource __RPC_FAR * This,
            /* [in] */ IUnknown __RPC_FAR *__RPC_FAR *ppUnkMoniker);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetBindingManager )( 
            IEventSource __RPC_FAR * This,
            /* [retval][out] */ IEventBindingManager __RPC_FAR *__RPC_FAR *ppBindingManager);
        
        /* [propget][helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *get_Properties )( 
            IEventSource __RPC_FAR * This,
            /* [retval][out] */ IEventPropertyBag __RPC_FAR *__RPC_FAR *ppProperties);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *Save )( 
            IEventSource __RPC_FAR * This);
        
        END_INTERFACE
    } IEventSourceVtbl;

    interface IEventSource
    {
        CONST_VTBL struct IEventSourceVtbl __RPC_FAR *lpVtbl;
    };

    

#ifdef COBJMACROS


#define IEventSource_QueryInterface(This,riid,ppvObject)	\
    (This)->lpVtbl -> QueryInterface(This,riid,ppvObject)

#define IEventSource_AddRef(This)	\
    (This)->lpVtbl -> AddRef(This)

#define IEventSource_Release(This)	\
    (This)->lpVtbl -> Release(This)


#define IEventSource_GetTypeInfoCount(This,pctinfo)	\
    (This)->lpVtbl -> GetTypeInfoCount(This,pctinfo)

#define IEventSource_GetTypeInfo(This,iTInfo,lcid,ppTInfo)	\
    (This)->lpVtbl -> GetTypeInfo(This,iTInfo,lcid,ppTInfo)

#define IEventSource_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)	\
    (This)->lpVtbl -> GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)

#define IEventSource_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)	\
    (This)->lpVtbl -> Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)


#define IEventSource_get_ID(This,pstrID)	\
    (This)->lpVtbl -> get_ID(This,pstrID)

#define IEventSource_get_DisplayName(This,pstrDisplayName)	\
    (This)->lpVtbl -> get_DisplayName(This,pstrDisplayName)

#define IEventSource_put_DisplayName(This,pszDisplayName)	\
    (This)->lpVtbl -> put_DisplayName(This,pszDisplayName)

#define IEventSource_putref_DisplayName(This,ppszDisplayName)	\
    (This)->lpVtbl -> putref_DisplayName(This,ppszDisplayName)

#define IEventSource_get_BindingManagerMoniker(This,ppUnkMoniker)	\
    (This)->lpVtbl -> get_BindingManagerMoniker(This,ppUnkMoniker)

#define IEventSource_put_BindingManagerMoniker(This,pUnkMoniker)	\
    (This)->lpVtbl -> put_BindingManagerMoniker(This,pUnkMoniker)

#define IEventSource_putref_BindingManagerMoniker(This,ppUnkMoniker)	\
    (This)->lpVtbl -> putref_BindingManagerMoniker(This,ppUnkMoniker)

#define IEventSource_GetBindingManager(This,ppBindingManager)	\
    (This)->lpVtbl -> GetBindingManager(This,ppBindingManager)

#define IEventSource_get_Properties(This,ppProperties)	\
    (This)->lpVtbl -> get_Properties(This,ppProperties)

#define IEventSource_Save(This)	\
    (This)->lpVtbl -> Save(This)

#endif /* COBJMACROS */


#endif 	/* C style interface */



/* [propget][helpstring] */ HRESULT STDMETHODCALLTYPE IEventSource_get_ID_Proxy( 
    IEventSource __RPC_FAR * This,
    /* [retval][out] */ BSTR __RPC_FAR *pstrID);


void __RPC_STUB IEventSource_get_ID_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [propget][helpstring] */ HRESULT STDMETHODCALLTYPE IEventSource_get_DisplayName_Proxy( 
    IEventSource __RPC_FAR * This,
    /* [retval][out] */ BSTR __RPC_FAR *pstrDisplayName);


void __RPC_STUB IEventSource_get_DisplayName_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [propput][helpstring] */ HRESULT STDMETHODCALLTYPE IEventSource_put_DisplayName_Proxy( 
    IEventSource __RPC_FAR * This,
    /* [in] */ BSTR pszDisplayName);


void __RPC_STUB IEventSource_put_DisplayName_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [propputref][helpstring] */ HRESULT STDMETHODCALLTYPE IEventSource_putref_DisplayName_Proxy( 
    IEventSource __RPC_FAR * This,
    /* [in] */ BSTR __RPC_FAR *ppszDisplayName);


void __RPC_STUB IEventSource_putref_DisplayName_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [propget][helpstring] */ HRESULT STDMETHODCALLTYPE IEventSource_get_BindingManagerMoniker_Proxy( 
    IEventSource __RPC_FAR * This,
    /* [retval][out] */ IUnknown __RPC_FAR *__RPC_FAR *ppUnkMoniker);


void __RPC_STUB IEventSource_get_BindingManagerMoniker_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [propput][helpstring] */ HRESULT STDMETHODCALLTYPE IEventSource_put_BindingManagerMoniker_Proxy( 
    IEventSource __RPC_FAR * This,
    /* [in] */ IUnknown __RPC_FAR *pUnkMoniker);


void __RPC_STUB IEventSource_put_BindingManagerMoniker_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [propputref][helpstring] */ HRESULT STDMETHODCALLTYPE IEventSource_putref_BindingManagerMoniker_Proxy( 
    IEventSource __RPC_FAR * This,
    /* [in] */ IUnknown __RPC_FAR *__RPC_FAR *ppUnkMoniker);


void __RPC_STUB IEventSource_putref_BindingManagerMoniker_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IEventSource_GetBindingManager_Proxy( 
    IEventSource __RPC_FAR * This,
    /* [retval][out] */ IEventBindingManager __RPC_FAR *__RPC_FAR *ppBindingManager);


void __RPC_STUB IEventSource_GetBindingManager_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [propget][helpstring] */ HRESULT STDMETHODCALLTYPE IEventSource_get_Properties_Proxy( 
    IEventSource __RPC_FAR * This,
    /* [retval][out] */ IEventPropertyBag __RPC_FAR *__RPC_FAR *ppProperties);


void __RPC_STUB IEventSource_get_Properties_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IEventSource_Save_Proxy( 
    IEventSource __RPC_FAR * This);


void __RPC_STUB IEventSource_Save_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);



#endif 	/* __IEventSource_INTERFACE_DEFINED__ */


#ifndef __IEventSources_INTERFACE_DEFINED__
#define __IEventSources_INTERFACE_DEFINED__

/* interface IEventSources */
/* [uuid][unique][oleautomation][object][helpstring][dual] */ 


EXTERN_C const IID IID_IEventSources;

#if defined(__cplusplus) && !defined(CINTERFACE)
    
    MIDL_INTERFACE("73e8c930-a652-11d0-a9ea-00aa00685c74")
    IEventSources : public IDispatch
    {
    public:
        virtual /* [id][helpstring] */ HRESULT STDMETHODCALLTYPE Item( 
            /* [in] */ VARIANT __RPC_FAR *pvarDesired,
            /* [retval][out] */ IEventSource __RPC_FAR *__RPC_FAR *ppSource) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE Add( 
            /* [in] */ BSTR pszSource,
            /* [retval][out] */ IEventSource __RPC_FAR *__RPC_FAR *ppSource) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE Remove( 
            /* [in] */ VARIANT __RPC_FAR *pvarDesired) = 0;
        
        virtual /* [propget][helpstring] */ HRESULT STDMETHODCALLTYPE get_Count( 
            /* [retval][out] */ long __RPC_FAR *plCount) = 0;
        
        virtual /* [hidden][propget][id][helpstring] */ HRESULT STDMETHODCALLTYPE get__NewEnum( 
            /* [retval][out] */ IUnknown __RPC_FAR *__RPC_FAR *ppUnkEnum) = 0;
        
    };
    
#else 	/* C style interface */

    typedef struct IEventSourcesVtbl
    {
        BEGIN_INTERFACE
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *QueryInterface )( 
            IEventSources __RPC_FAR * This,
            /* [in] */ REFIID riid,
            /* [iid_is][out] */ void __RPC_FAR *__RPC_FAR *ppvObject);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *AddRef )( 
            IEventSources __RPC_FAR * This);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *Release )( 
            IEventSources __RPC_FAR * This);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetTypeInfoCount )( 
            IEventSources __RPC_FAR * This,
            /* [out] */ UINT __RPC_FAR *pctinfo);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetTypeInfo )( 
            IEventSources __RPC_FAR * This,
            /* [in] */ UINT iTInfo,
            /* [in] */ LCID lcid,
            /* [out] */ ITypeInfo __RPC_FAR *__RPC_FAR *ppTInfo);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetIDsOfNames )( 
            IEventSources __RPC_FAR * This,
            /* [in] */ REFIID riid,
            /* [size_is][in] */ LPOLESTR __RPC_FAR *rgszNames,
            /* [in] */ UINT cNames,
            /* [in] */ LCID lcid,
            /* [size_is][out] */ DISPID __RPC_FAR *rgDispId);
        
        /* [local] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *Invoke )( 
            IEventSources __RPC_FAR * This,
            /* [in] */ DISPID dispIdMember,
            /* [in] */ REFIID riid,
            /* [in] */ LCID lcid,
            /* [in] */ WORD wFlags,
            /* [out][in] */ DISPPARAMS __RPC_FAR *pDispParams,
            /* [out] */ VARIANT __RPC_FAR *pVarResult,
            /* [out] */ EXCEPINFO __RPC_FAR *pExcepInfo,
            /* [out] */ UINT __RPC_FAR *puArgErr);
        
        /* [id][helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *Item )( 
            IEventSources __RPC_FAR * This,
            /* [in] */ VARIANT __RPC_FAR *pvarDesired,
            /* [retval][out] */ IEventSource __RPC_FAR *__RPC_FAR *ppSource);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *Add )( 
            IEventSources __RPC_FAR * This,
            /* [in] */ BSTR pszSource,
            /* [retval][out] */ IEventSource __RPC_FAR *__RPC_FAR *ppSource);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *Remove )( 
            IEventSources __RPC_FAR * This,
            /* [in] */ VARIANT __RPC_FAR *pvarDesired);
        
        /* [propget][helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *get_Count )( 
            IEventSources __RPC_FAR * This,
            /* [retval][out] */ long __RPC_FAR *plCount);
        
        /* [hidden][propget][id][helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *get__NewEnum )( 
            IEventSources __RPC_FAR * This,
            /* [retval][out] */ IUnknown __RPC_FAR *__RPC_FAR *ppUnkEnum);
        
        END_INTERFACE
    } IEventSourcesVtbl;

    interface IEventSources
    {
        CONST_VTBL struct IEventSourcesVtbl __RPC_FAR *lpVtbl;
    };

    

#ifdef COBJMACROS


#define IEventSources_QueryInterface(This,riid,ppvObject)	\
    (This)->lpVtbl -> QueryInterface(This,riid,ppvObject)

#define IEventSources_AddRef(This)	\
    (This)->lpVtbl -> AddRef(This)

#define IEventSources_Release(This)	\
    (This)->lpVtbl -> Release(This)


#define IEventSources_GetTypeInfoCount(This,pctinfo)	\
    (This)->lpVtbl -> GetTypeInfoCount(This,pctinfo)

#define IEventSources_GetTypeInfo(This,iTInfo,lcid,ppTInfo)	\
    (This)->lpVtbl -> GetTypeInfo(This,iTInfo,lcid,ppTInfo)

#define IEventSources_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)	\
    (This)->lpVtbl -> GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)

#define IEventSources_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)	\
    (This)->lpVtbl -> Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)


#define IEventSources_Item(This,pvarDesired,ppSource)	\
    (This)->lpVtbl -> Item(This,pvarDesired,ppSource)

#define IEventSources_Add(This,pszSource,ppSource)	\
    (This)->lpVtbl -> Add(This,pszSource,ppSource)

#define IEventSources_Remove(This,pvarDesired)	\
    (This)->lpVtbl -> Remove(This,pvarDesired)

#define IEventSources_get_Count(This,plCount)	\
    (This)->lpVtbl -> get_Count(This,plCount)

#define IEventSources_get__NewEnum(This,ppUnkEnum)	\
    (This)->lpVtbl -> get__NewEnum(This,ppUnkEnum)

#endif /* COBJMACROS */


#endif 	/* C style interface */



/* [id][helpstring] */ HRESULT STDMETHODCALLTYPE IEventSources_Item_Proxy( 
    IEventSources __RPC_FAR * This,
    /* [in] */ VARIANT __RPC_FAR *pvarDesired,
    /* [retval][out] */ IEventSource __RPC_FAR *__RPC_FAR *ppSource);


void __RPC_STUB IEventSources_Item_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IEventSources_Add_Proxy( 
    IEventSources __RPC_FAR * This,
    /* [in] */ BSTR pszSource,
    /* [retval][out] */ IEventSource __RPC_FAR *__RPC_FAR *ppSource);


void __RPC_STUB IEventSources_Add_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IEventSources_Remove_Proxy( 
    IEventSources __RPC_FAR * This,
    /* [in] */ VARIANT __RPC_FAR *pvarDesired);


void __RPC_STUB IEventSources_Remove_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [propget][helpstring] */ HRESULT STDMETHODCALLTYPE IEventSources_get_Count_Proxy( 
    IEventSources __RPC_FAR * This,
    /* [retval][out] */ long __RPC_FAR *plCount);


void __RPC_STUB IEventSources_get_Count_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [hidden][propget][id][helpstring] */ HRESULT STDMETHODCALLTYPE IEventSources_get__NewEnum_Proxy( 
    IEventSources __RPC_FAR * This,
    /* [retval][out] */ IUnknown __RPC_FAR *__RPC_FAR *ppUnkEnum);


void __RPC_STUB IEventSources_get__NewEnum_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);



#endif 	/* __IEventSources_INTERFACE_DEFINED__ */


#ifndef __IEventSourceType_INTERFACE_DEFINED__
#define __IEventSourceType_INTERFACE_DEFINED__

/* interface IEventSourceType */
/* [uuid][unique][oleautomation][object][helpstring][dual] */ 


EXTERN_C const IID IID_IEventSourceType;

#if defined(__cplusplus) && !defined(CINTERFACE)
    
    MIDL_INTERFACE("063a62e0-a652-11d0-a9ea-00aa00685c74")
    IEventSourceType : public IDispatch
    {
    public:
        virtual /* [propget][helpstring] */ HRESULT STDMETHODCALLTYPE get_ID( 
            /* [retval][out] */ BSTR __RPC_FAR *pstrID) = 0;
        
        virtual /* [propget][helpstring] */ HRESULT STDMETHODCALLTYPE get_DisplayName( 
            /* [retval][out] */ BSTR __RPC_FAR *pstrDisplayName) = 0;
        
        virtual /* [propput][helpstring] */ HRESULT STDMETHODCALLTYPE put_DisplayName( 
            /* [in] */ BSTR pszDisplayName) = 0;
        
        virtual /* [propputref][helpstring] */ HRESULT STDMETHODCALLTYPE putref_DisplayName( 
            /* [in] */ BSTR __RPC_FAR *ppszDisplayName) = 0;
        
        virtual /* [propget][helpstring] */ HRESULT STDMETHODCALLTYPE get_EventTypes( 
            /* [retval][out] */ IEventTypes __RPC_FAR *__RPC_FAR *ppEventTypes) = 0;
        
        virtual /* [propget][helpstring] */ HRESULT STDMETHODCALLTYPE get_Sources( 
            /* [retval][out] */ IEventSources __RPC_FAR *__RPC_FAR *ppSources) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE Save( void) = 0;
        
    };
    
#else 	/* C style interface */

    typedef struct IEventSourceTypeVtbl
    {
        BEGIN_INTERFACE
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *QueryInterface )( 
            IEventSourceType __RPC_FAR * This,
            /* [in] */ REFIID riid,
            /* [iid_is][out] */ void __RPC_FAR *__RPC_FAR *ppvObject);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *AddRef )( 
            IEventSourceType __RPC_FAR * This);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *Release )( 
            IEventSourceType __RPC_FAR * This);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetTypeInfoCount )( 
            IEventSourceType __RPC_FAR * This,
            /* [out] */ UINT __RPC_FAR *pctinfo);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetTypeInfo )( 
            IEventSourceType __RPC_FAR * This,
            /* [in] */ UINT iTInfo,
            /* [in] */ LCID lcid,
            /* [out] */ ITypeInfo __RPC_FAR *__RPC_FAR *ppTInfo);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetIDsOfNames )( 
            IEventSourceType __RPC_FAR * This,
            /* [in] */ REFIID riid,
            /* [size_is][in] */ LPOLESTR __RPC_FAR *rgszNames,
            /* [in] */ UINT cNames,
            /* [in] */ LCID lcid,
            /* [size_is][out] */ DISPID __RPC_FAR *rgDispId);
        
        /* [local] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *Invoke )( 
            IEventSourceType __RPC_FAR * This,
            /* [in] */ DISPID dispIdMember,
            /* [in] */ REFIID riid,
            /* [in] */ LCID lcid,
            /* [in] */ WORD wFlags,
            /* [out][in] */ DISPPARAMS __RPC_FAR *pDispParams,
            /* [out] */ VARIANT __RPC_FAR *pVarResult,
            /* [out] */ EXCEPINFO __RPC_FAR *pExcepInfo,
            /* [out] */ UINT __RPC_FAR *puArgErr);
        
        /* [propget][helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *get_ID )( 
            IEventSourceType __RPC_FAR * This,
            /* [retval][out] */ BSTR __RPC_FAR *pstrID);
        
        /* [propget][helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *get_DisplayName )( 
            IEventSourceType __RPC_FAR * This,
            /* [retval][out] */ BSTR __RPC_FAR *pstrDisplayName);
        
        /* [propput][helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *put_DisplayName )( 
            IEventSourceType __RPC_FAR * This,
            /* [in] */ BSTR pszDisplayName);
        
        /* [propputref][helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *putref_DisplayName )( 
            IEventSourceType __RPC_FAR * This,
            /* [in] */ BSTR __RPC_FAR *ppszDisplayName);
        
        /* [propget][helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *get_EventTypes )( 
            IEventSourceType __RPC_FAR * This,
            /* [retval][out] */ IEventTypes __RPC_FAR *__RPC_FAR *ppEventTypes);
        
        /* [propget][helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *get_Sources )( 
            IEventSourceType __RPC_FAR * This,
            /* [retval][out] */ IEventSources __RPC_FAR *__RPC_FAR *ppSources);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *Save )( 
            IEventSourceType __RPC_FAR * This);
        
        END_INTERFACE
    } IEventSourceTypeVtbl;

    interface IEventSourceType
    {
        CONST_VTBL struct IEventSourceTypeVtbl __RPC_FAR *lpVtbl;
    };

    

#ifdef COBJMACROS


#define IEventSourceType_QueryInterface(This,riid,ppvObject)	\
    (This)->lpVtbl -> QueryInterface(This,riid,ppvObject)

#define IEventSourceType_AddRef(This)	\
    (This)->lpVtbl -> AddRef(This)

#define IEventSourceType_Release(This)	\
    (This)->lpVtbl -> Release(This)


#define IEventSourceType_GetTypeInfoCount(This,pctinfo)	\
    (This)->lpVtbl -> GetTypeInfoCount(This,pctinfo)

#define IEventSourceType_GetTypeInfo(This,iTInfo,lcid,ppTInfo)	\
    (This)->lpVtbl -> GetTypeInfo(This,iTInfo,lcid,ppTInfo)

#define IEventSourceType_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)	\
    (This)->lpVtbl -> GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)

#define IEventSourceType_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)	\
    (This)->lpVtbl -> Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)


#define IEventSourceType_get_ID(This,pstrID)	\
    (This)->lpVtbl -> get_ID(This,pstrID)

#define IEventSourceType_get_DisplayName(This,pstrDisplayName)	\
    (This)->lpVtbl -> get_DisplayName(This,pstrDisplayName)

#define IEventSourceType_put_DisplayName(This,pszDisplayName)	\
    (This)->lpVtbl -> put_DisplayName(This,pszDisplayName)

#define IEventSourceType_putref_DisplayName(This,ppszDisplayName)	\
    (This)->lpVtbl -> putref_DisplayName(This,ppszDisplayName)

#define IEventSourceType_get_EventTypes(This,ppEventTypes)	\
    (This)->lpVtbl -> get_EventTypes(This,ppEventTypes)

#define IEventSourceType_get_Sources(This,ppSources)	\
    (This)->lpVtbl -> get_Sources(This,ppSources)

#define IEventSourceType_Save(This)	\
    (This)->lpVtbl -> Save(This)

#endif /* COBJMACROS */


#endif 	/* C style interface */



/* [propget][helpstring] */ HRESULT STDMETHODCALLTYPE IEventSourceType_get_ID_Proxy( 
    IEventSourceType __RPC_FAR * This,
    /* [retval][out] */ BSTR __RPC_FAR *pstrID);


void __RPC_STUB IEventSourceType_get_ID_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [propget][helpstring] */ HRESULT STDMETHODCALLTYPE IEventSourceType_get_DisplayName_Proxy( 
    IEventSourceType __RPC_FAR * This,
    /* [retval][out] */ BSTR __RPC_FAR *pstrDisplayName);


void __RPC_STUB IEventSourceType_get_DisplayName_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [propput][helpstring] */ HRESULT STDMETHODCALLTYPE IEventSourceType_put_DisplayName_Proxy( 
    IEventSourceType __RPC_FAR * This,
    /* [in] */ BSTR pszDisplayName);


void __RPC_STUB IEventSourceType_put_DisplayName_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [propputref][helpstring] */ HRESULT STDMETHODCALLTYPE IEventSourceType_putref_DisplayName_Proxy( 
    IEventSourceType __RPC_FAR * This,
    /* [in] */ BSTR __RPC_FAR *ppszDisplayName);


void __RPC_STUB IEventSourceType_putref_DisplayName_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [propget][helpstring] */ HRESULT STDMETHODCALLTYPE IEventSourceType_get_EventTypes_Proxy( 
    IEventSourceType __RPC_FAR * This,
    /* [retval][out] */ IEventTypes __RPC_FAR *__RPC_FAR *ppEventTypes);


void __RPC_STUB IEventSourceType_get_EventTypes_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [propget][helpstring] */ HRESULT STDMETHODCALLTYPE IEventSourceType_get_Sources_Proxy( 
    IEventSourceType __RPC_FAR * This,
    /* [retval][out] */ IEventSources __RPC_FAR *__RPC_FAR *ppSources);


void __RPC_STUB IEventSourceType_get_Sources_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IEventSourceType_Save_Proxy( 
    IEventSourceType __RPC_FAR * This);


void __RPC_STUB IEventSourceType_Save_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);



#endif 	/* __IEventSourceType_INTERFACE_DEFINED__ */


#ifndef __IEventSourceTypes_INTERFACE_DEFINED__
#define __IEventSourceTypes_INTERFACE_DEFINED__

/* interface IEventSourceTypes */
/* [uuid][unique][oleautomation][object][helpstring][dual] */ 


EXTERN_C const IID IID_IEventSourceTypes;

#if defined(__cplusplus) && !defined(CINTERFACE)
    
    MIDL_INTERFACE("caf30fd0-a651-11d0-a9ea-00aa00685c74")
    IEventSourceTypes : public IDispatch
    {
    public:
        virtual /* [id][helpstring] */ HRESULT STDMETHODCALLTYPE Item( 
            /* [in] */ VARIANT __RPC_FAR *pvarDesired,
            /* [retval][out] */ IEventSourceType __RPC_FAR *__RPC_FAR *ppSourceType) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE Add( 
            /* [in] */ BSTR pszSourceType,
            /* [retval][out] */ IEventSourceType __RPC_FAR *__RPC_FAR *ppSourceType) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE Remove( 
            /* [in] */ VARIANT __RPC_FAR *pvarDesired) = 0;
        
        virtual /* [propget][helpstring] */ HRESULT STDMETHODCALLTYPE get_Count( 
            /* [retval][out] */ long __RPC_FAR *plCount) = 0;
        
        virtual /* [hidden][propget][id][helpstring] */ HRESULT STDMETHODCALLTYPE get__NewEnum( 
            /* [retval][out] */ IUnknown __RPC_FAR *__RPC_FAR *ppUnkEnum) = 0;
        
    };
    
#else 	/* C style interface */

    typedef struct IEventSourceTypesVtbl
    {
        BEGIN_INTERFACE
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *QueryInterface )( 
            IEventSourceTypes __RPC_FAR * This,
            /* [in] */ REFIID riid,
            /* [iid_is][out] */ void __RPC_FAR *__RPC_FAR *ppvObject);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *AddRef )( 
            IEventSourceTypes __RPC_FAR * This);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *Release )( 
            IEventSourceTypes __RPC_FAR * This);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetTypeInfoCount )( 
            IEventSourceTypes __RPC_FAR * This,
            /* [out] */ UINT __RPC_FAR *pctinfo);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetTypeInfo )( 
            IEventSourceTypes __RPC_FAR * This,
            /* [in] */ UINT iTInfo,
            /* [in] */ LCID lcid,
            /* [out] */ ITypeInfo __RPC_FAR *__RPC_FAR *ppTInfo);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetIDsOfNames )( 
            IEventSourceTypes __RPC_FAR * This,
            /* [in] */ REFIID riid,
            /* [size_is][in] */ LPOLESTR __RPC_FAR *rgszNames,
            /* [in] */ UINT cNames,
            /* [in] */ LCID lcid,
            /* [size_is][out] */ DISPID __RPC_FAR *rgDispId);
        
        /* [local] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *Invoke )( 
            IEventSourceTypes __RPC_FAR * This,
            /* [in] */ DISPID dispIdMember,
            /* [in] */ REFIID riid,
            /* [in] */ LCID lcid,
            /* [in] */ WORD wFlags,
            /* [out][in] */ DISPPARAMS __RPC_FAR *pDispParams,
            /* [out] */ VARIANT __RPC_FAR *pVarResult,
            /* [out] */ EXCEPINFO __RPC_FAR *pExcepInfo,
            /* [out] */ UINT __RPC_FAR *puArgErr);
        
        /* [id][helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *Item )( 
            IEventSourceTypes __RPC_FAR * This,
            /* [in] */ VARIANT __RPC_FAR *pvarDesired,
            /* [retval][out] */ IEventSourceType __RPC_FAR *__RPC_FAR *ppSourceType);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *Add )( 
            IEventSourceTypes __RPC_FAR * This,
            /* [in] */ BSTR pszSourceType,
            /* [retval][out] */ IEventSourceType __RPC_FAR *__RPC_FAR *ppSourceType);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *Remove )( 
            IEventSourceTypes __RPC_FAR * This,
            /* [in] */ VARIANT __RPC_FAR *pvarDesired);
        
        /* [propget][helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *get_Count )( 
            IEventSourceTypes __RPC_FAR * This,
            /* [retval][out] */ long __RPC_FAR *plCount);
        
        /* [hidden][propget][id][helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *get__NewEnum )( 
            IEventSourceTypes __RPC_FAR * This,
            /* [retval][out] */ IUnknown __RPC_FAR *__RPC_FAR *ppUnkEnum);
        
        END_INTERFACE
    } IEventSourceTypesVtbl;

    interface IEventSourceTypes
    {
        CONST_VTBL struct IEventSourceTypesVtbl __RPC_FAR *lpVtbl;
    };

    

#ifdef COBJMACROS


#define IEventSourceTypes_QueryInterface(This,riid,ppvObject)	\
    (This)->lpVtbl -> QueryInterface(This,riid,ppvObject)

#define IEventSourceTypes_AddRef(This)	\
    (This)->lpVtbl -> AddRef(This)

#define IEventSourceTypes_Release(This)	\
    (This)->lpVtbl -> Release(This)


#define IEventSourceTypes_GetTypeInfoCount(This,pctinfo)	\
    (This)->lpVtbl -> GetTypeInfoCount(This,pctinfo)

#define IEventSourceTypes_GetTypeInfo(This,iTInfo,lcid,ppTInfo)	\
    (This)->lpVtbl -> GetTypeInfo(This,iTInfo,lcid,ppTInfo)

#define IEventSourceTypes_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)	\
    (This)->lpVtbl -> GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)

#define IEventSourceTypes_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)	\
    (This)->lpVtbl -> Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)


#define IEventSourceTypes_Item(This,pvarDesired,ppSourceType)	\
    (This)->lpVtbl -> Item(This,pvarDesired,ppSourceType)

#define IEventSourceTypes_Add(This,pszSourceType,ppSourceType)	\
    (This)->lpVtbl -> Add(This,pszSourceType,ppSourceType)

#define IEventSourceTypes_Remove(This,pvarDesired)	\
    (This)->lpVtbl -> Remove(This,pvarDesired)

#define IEventSourceTypes_get_Count(This,plCount)	\
    (This)->lpVtbl -> get_Count(This,plCount)

#define IEventSourceTypes_get__NewEnum(This,ppUnkEnum)	\
    (This)->lpVtbl -> get__NewEnum(This,ppUnkEnum)

#endif /* COBJMACROS */


#endif 	/* C style interface */



/* [id][helpstring] */ HRESULT STDMETHODCALLTYPE IEventSourceTypes_Item_Proxy( 
    IEventSourceTypes __RPC_FAR * This,
    /* [in] */ VARIANT __RPC_FAR *pvarDesired,
    /* [retval][out] */ IEventSourceType __RPC_FAR *__RPC_FAR *ppSourceType);


void __RPC_STUB IEventSourceTypes_Item_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IEventSourceTypes_Add_Proxy( 
    IEventSourceTypes __RPC_FAR * This,
    /* [in] */ BSTR pszSourceType,
    /* [retval][out] */ IEventSourceType __RPC_FAR *__RPC_FAR *ppSourceType);


void __RPC_STUB IEventSourceTypes_Add_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IEventSourceTypes_Remove_Proxy( 
    IEventSourceTypes __RPC_FAR * This,
    /* [in] */ VARIANT __RPC_FAR *pvarDesired);


void __RPC_STUB IEventSourceTypes_Remove_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [propget][helpstring] */ HRESULT STDMETHODCALLTYPE IEventSourceTypes_get_Count_Proxy( 
    IEventSourceTypes __RPC_FAR * This,
    /* [retval][out] */ long __RPC_FAR *plCount);


void __RPC_STUB IEventSourceTypes_get_Count_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [hidden][propget][id][helpstring] */ HRESULT STDMETHODCALLTYPE IEventSourceTypes_get__NewEnum_Proxy( 
    IEventSourceTypes __RPC_FAR * This,
    /* [retval][out] */ IUnknown __RPC_FAR *__RPC_FAR *ppUnkEnum);


void __RPC_STUB IEventSourceTypes_get__NewEnum_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);



#endif 	/* __IEventSourceTypes_INTERFACE_DEFINED__ */


#ifndef __IEventManager_INTERFACE_DEFINED__
#define __IEventManager_INTERFACE_DEFINED__

/* interface IEventManager */
/* [uuid][unique][oleautomation][object][helpstring][dual] */ 


EXTERN_C const IID IID_IEventManager;

#if defined(__cplusplus) && !defined(CINTERFACE)
    
    MIDL_INTERFACE("5f6012b0-a651-11d0-a9ea-00aa00685c74")
    IEventManager : public IDispatch
    {
    public:
        virtual /* [propget][helpstring] */ HRESULT STDMETHODCALLTYPE get_SourceTypes( 
            /* [retval][out] */ IEventSourceTypes __RPC_FAR *__RPC_FAR *ppSourceTypes) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE CreateSink( 
            /* [unique][in] */ IEventBinding __RPC_FAR *pBinding,
            /* [unique][in] */ IEventDeliveryOptions __RPC_FAR *pDeliveryOptions,
            /* [retval][out] */ IUnknown __RPC_FAR *__RPC_FAR *ppUnkSink) = 0;
        
    };
    
#else 	/* C style interface */

    typedef struct IEventManagerVtbl
    {
        BEGIN_INTERFACE
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *QueryInterface )( 
            IEventManager __RPC_FAR * This,
            /* [in] */ REFIID riid,
            /* [iid_is][out] */ void __RPC_FAR *__RPC_FAR *ppvObject);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *AddRef )( 
            IEventManager __RPC_FAR * This);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *Release )( 
            IEventManager __RPC_FAR * This);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetTypeInfoCount )( 
            IEventManager __RPC_FAR * This,
            /* [out] */ UINT __RPC_FAR *pctinfo);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetTypeInfo )( 
            IEventManager __RPC_FAR * This,
            /* [in] */ UINT iTInfo,
            /* [in] */ LCID lcid,
            /* [out] */ ITypeInfo __RPC_FAR *__RPC_FAR *ppTInfo);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetIDsOfNames )( 
            IEventManager __RPC_FAR * This,
            /* [in] */ REFIID riid,
            /* [size_is][in] */ LPOLESTR __RPC_FAR *rgszNames,
            /* [in] */ UINT cNames,
            /* [in] */ LCID lcid,
            /* [size_is][out] */ DISPID __RPC_FAR *rgDispId);
        
        /* [local] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *Invoke )( 
            IEventManager __RPC_FAR * This,
            /* [in] */ DISPID dispIdMember,
            /* [in] */ REFIID riid,
            /* [in] */ LCID lcid,
            /* [in] */ WORD wFlags,
            /* [out][in] */ DISPPARAMS __RPC_FAR *pDispParams,
            /* [out] */ VARIANT __RPC_FAR *pVarResult,
            /* [out] */ EXCEPINFO __RPC_FAR *pExcepInfo,
            /* [out] */ UINT __RPC_FAR *puArgErr);
        
        /* [propget][helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *get_SourceTypes )( 
            IEventManager __RPC_FAR * This,
            /* [retval][out] */ IEventSourceTypes __RPC_FAR *__RPC_FAR *ppSourceTypes);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *CreateSink )( 
            IEventManager __RPC_FAR * This,
            /* [unique][in] */ IEventBinding __RPC_FAR *pBinding,
            /* [unique][in] */ IEventDeliveryOptions __RPC_FAR *pDeliveryOptions,
            /* [retval][out] */ IUnknown __RPC_FAR *__RPC_FAR *ppUnkSink);
        
        END_INTERFACE
    } IEventManagerVtbl;

    interface IEventManager
    {
        CONST_VTBL struct IEventManagerVtbl __RPC_FAR *lpVtbl;
    };

    

#ifdef COBJMACROS


#define IEventManager_QueryInterface(This,riid,ppvObject)	\
    (This)->lpVtbl -> QueryInterface(This,riid,ppvObject)

#define IEventManager_AddRef(This)	\
    (This)->lpVtbl -> AddRef(This)

#define IEventManager_Release(This)	\
    (This)->lpVtbl -> Release(This)


#define IEventManager_GetTypeInfoCount(This,pctinfo)	\
    (This)->lpVtbl -> GetTypeInfoCount(This,pctinfo)

#define IEventManager_GetTypeInfo(This,iTInfo,lcid,ppTInfo)	\
    (This)->lpVtbl -> GetTypeInfo(This,iTInfo,lcid,ppTInfo)

#define IEventManager_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)	\
    (This)->lpVtbl -> GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)

#define IEventManager_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)	\
    (This)->lpVtbl -> Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)


#define IEventManager_get_SourceTypes(This,ppSourceTypes)	\
    (This)->lpVtbl -> get_SourceTypes(This,ppSourceTypes)

#define IEventManager_CreateSink(This,pBinding,pDeliveryOptions,ppUnkSink)	\
    (This)->lpVtbl -> CreateSink(This,pBinding,pDeliveryOptions,ppUnkSink)

#endif /* COBJMACROS */


#endif 	/* C style interface */



/* [propget][helpstring] */ HRESULT STDMETHODCALLTYPE IEventManager_get_SourceTypes_Proxy( 
    IEventManager __RPC_FAR * This,
    /* [retval][out] */ IEventSourceTypes __RPC_FAR *__RPC_FAR *ppSourceTypes);


void __RPC_STUB IEventManager_get_SourceTypes_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IEventManager_CreateSink_Proxy( 
    IEventManager __RPC_FAR * This,
    /* [unique][in] */ IEventBinding __RPC_FAR *pBinding,
    /* [unique][in] */ IEventDeliveryOptions __RPC_FAR *pDeliveryOptions,
    /* [retval][out] */ IUnknown __RPC_FAR *__RPC_FAR *ppUnkSink);


void __RPC_STUB IEventManager_CreateSink_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);



#endif 	/* __IEventManager_INTERFACE_DEFINED__ */


#ifndef __IEventDatabasePlugin_INTERFACE_DEFINED__
#define __IEventDatabasePlugin_INTERFACE_DEFINED__

/* interface IEventDatabasePlugin */
/* [uuid][unique][oleautomation][object][hidden][helpstring] */ 


EXTERN_C const IID IID_IEventDatabasePlugin;

#if defined(__cplusplus) && !defined(CINTERFACE)
    
    MIDL_INTERFACE("4915fb10-af97-11d0-a9eb-00aa00685c74")
    IEventDatabasePlugin : public IUnknown
    {
    public:
        virtual /* [propget][helpstring] */ HRESULT STDMETHODCALLTYPE get_Database( 
            /* [retval][out] */ IEventPropertyBag __RPC_FAR *__RPC_FAR *ppDatabase) = 0;
        
        virtual /* [propput][helpstring] */ HRESULT STDMETHODCALLTYPE put_Database( 
            /* [in] */ IEventPropertyBag __RPC_FAR *pDatabase) = 0;
        
        virtual /* [propputref][helpstring] */ HRESULT STDMETHODCALLTYPE putref_Database( 
            /* [in] */ IEventPropertyBag __RPC_FAR *__RPC_FAR *ppDatabase) = 0;
        
        virtual /* [propget][helpstring] */ HRESULT STDMETHODCALLTYPE get_Name( 
            /* [retval][out] */ BSTR __RPC_FAR *pstrName) = 0;
        
        virtual /* [propput][helpstring] */ HRESULT STDMETHODCALLTYPE put_Name( 
            /* [in] */ BSTR strName) = 0;
        
        virtual /* [propputref][helpstring] */ HRESULT STDMETHODCALLTYPE putref_Name( 
            /* [in] */ BSTR __RPC_FAR *pstrName) = 0;
        
        virtual /* [propget][helpstring] */ HRESULT STDMETHODCALLTYPE get_Parent( 
            /* [retval][out] */ IEventPropertyBag __RPC_FAR *__RPC_FAR *ppParent) = 0;
        
        virtual /* [propput][helpstring] */ HRESULT STDMETHODCALLTYPE put_Parent( 
            /* [in] */ IEventPropertyBag __RPC_FAR *pParent) = 0;
        
        virtual /* [propputref][helpstring] */ HRESULT STDMETHODCALLTYPE putref_Parent( 
            /* [in] */ IEventPropertyBag __RPC_FAR *__RPC_FAR *ppParent) = 0;
        
    };
    
#else 	/* C style interface */

    typedef struct IEventDatabasePluginVtbl
    {
        BEGIN_INTERFACE
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *QueryInterface )( 
            IEventDatabasePlugin __RPC_FAR * This,
            /* [in] */ REFIID riid,
            /* [iid_is][out] */ void __RPC_FAR *__RPC_FAR *ppvObject);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *AddRef )( 
            IEventDatabasePlugin __RPC_FAR * This);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *Release )( 
            IEventDatabasePlugin __RPC_FAR * This);
        
        /* [propget][helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *get_Database )( 
            IEventDatabasePlugin __RPC_FAR * This,
            /* [retval][out] */ IEventPropertyBag __RPC_FAR *__RPC_FAR *ppDatabase);
        
        /* [propput][helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *put_Database )( 
            IEventDatabasePlugin __RPC_FAR * This,
            /* [in] */ IEventPropertyBag __RPC_FAR *pDatabase);
        
        /* [propputref][helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *putref_Database )( 
            IEventDatabasePlugin __RPC_FAR * This,
            /* [in] */ IEventPropertyBag __RPC_FAR *__RPC_FAR *ppDatabase);
        
        /* [propget][helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *get_Name )( 
            IEventDatabasePlugin __RPC_FAR * This,
            /* [retval][out] */ BSTR __RPC_FAR *pstrName);
        
        /* [propput][helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *put_Name )( 
            IEventDatabasePlugin __RPC_FAR * This,
            /* [in] */ BSTR strName);
        
        /* [propputref][helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *putref_Name )( 
            IEventDatabasePlugin __RPC_FAR * This,
            /* [in] */ BSTR __RPC_FAR *pstrName);
        
        /* [propget][helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *get_Parent )( 
            IEventDatabasePlugin __RPC_FAR * This,
            /* [retval][out] */ IEventPropertyBag __RPC_FAR *__RPC_FAR *ppParent);
        
        /* [propput][helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *put_Parent )( 
            IEventDatabasePlugin __RPC_FAR * This,
            /* [in] */ IEventPropertyBag __RPC_FAR *pParent);
        
        /* [propputref][helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *putref_Parent )( 
            IEventDatabasePlugin __RPC_FAR * This,
            /* [in] */ IEventPropertyBag __RPC_FAR *__RPC_FAR *ppParent);
        
        END_INTERFACE
    } IEventDatabasePluginVtbl;

    interface IEventDatabasePlugin
    {
        CONST_VTBL struct IEventDatabasePluginVtbl __RPC_FAR *lpVtbl;
    };

    

#ifdef COBJMACROS


#define IEventDatabasePlugin_QueryInterface(This,riid,ppvObject)	\
    (This)->lpVtbl -> QueryInterface(This,riid,ppvObject)

#define IEventDatabasePlugin_AddRef(This)	\
    (This)->lpVtbl -> AddRef(This)

#define IEventDatabasePlugin_Release(This)	\
    (This)->lpVtbl -> Release(This)


#define IEventDatabasePlugin_get_Database(This,ppDatabase)	\
    (This)->lpVtbl -> get_Database(This,ppDatabase)

#define IEventDatabasePlugin_put_Database(This,pDatabase)	\
    (This)->lpVtbl -> put_Database(This,pDatabase)

#define IEventDatabasePlugin_putref_Database(This,ppDatabase)	\
    (This)->lpVtbl -> putref_Database(This,ppDatabase)

#define IEventDatabasePlugin_get_Name(This,pstrName)	\
    (This)->lpVtbl -> get_Name(This,pstrName)

#define IEventDatabasePlugin_put_Name(This,strName)	\
    (This)->lpVtbl -> put_Name(This,strName)

#define IEventDatabasePlugin_putref_Name(This,pstrName)	\
    (This)->lpVtbl -> putref_Name(This,pstrName)

#define IEventDatabasePlugin_get_Parent(This,ppParent)	\
    (This)->lpVtbl -> get_Parent(This,ppParent)

#define IEventDatabasePlugin_put_Parent(This,pParent)	\
    (This)->lpVtbl -> put_Parent(This,pParent)

#define IEventDatabasePlugin_putref_Parent(This,ppParent)	\
    (This)->lpVtbl -> putref_Parent(This,ppParent)

#endif /* COBJMACROS */


#endif 	/* C style interface */



/* [propget][helpstring] */ HRESULT STDMETHODCALLTYPE IEventDatabasePlugin_get_Database_Proxy( 
    IEventDatabasePlugin __RPC_FAR * This,
    /* [retval][out] */ IEventPropertyBag __RPC_FAR *__RPC_FAR *ppDatabase);


void __RPC_STUB IEventDatabasePlugin_get_Database_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [propput][helpstring] */ HRESULT STDMETHODCALLTYPE IEventDatabasePlugin_put_Database_Proxy( 
    IEventDatabasePlugin __RPC_FAR * This,
    /* [in] */ IEventPropertyBag __RPC_FAR *pDatabase);


void __RPC_STUB IEventDatabasePlugin_put_Database_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [propputref][helpstring] */ HRESULT STDMETHODCALLTYPE IEventDatabasePlugin_putref_Database_Proxy( 
    IEventDatabasePlugin __RPC_FAR * This,
    /* [in] */ IEventPropertyBag __RPC_FAR *__RPC_FAR *ppDatabase);


void __RPC_STUB IEventDatabasePlugin_putref_Database_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [propget][helpstring] */ HRESULT STDMETHODCALLTYPE IEventDatabasePlugin_get_Name_Proxy( 
    IEventDatabasePlugin __RPC_FAR * This,
    /* [retval][out] */ BSTR __RPC_FAR *pstrName);


void __RPC_STUB IEventDatabasePlugin_get_Name_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [propput][helpstring] */ HRESULT STDMETHODCALLTYPE IEventDatabasePlugin_put_Name_Proxy( 
    IEventDatabasePlugin __RPC_FAR * This,
    /* [in] */ BSTR strName);


void __RPC_STUB IEventDatabasePlugin_put_Name_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [propputref][helpstring] */ HRESULT STDMETHODCALLTYPE IEventDatabasePlugin_putref_Name_Proxy( 
    IEventDatabasePlugin __RPC_FAR * This,
    /* [in] */ BSTR __RPC_FAR *pstrName);


void __RPC_STUB IEventDatabasePlugin_putref_Name_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [propget][helpstring] */ HRESULT STDMETHODCALLTYPE IEventDatabasePlugin_get_Parent_Proxy( 
    IEventDatabasePlugin __RPC_FAR * This,
    /* [retval][out] */ IEventPropertyBag __RPC_FAR *__RPC_FAR *ppParent);


void __RPC_STUB IEventDatabasePlugin_get_Parent_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [propput][helpstring] */ HRESULT STDMETHODCALLTYPE IEventDatabasePlugin_put_Parent_Proxy( 
    IEventDatabasePlugin __RPC_FAR * This,
    /* [in] */ IEventPropertyBag __RPC_FAR *pParent);


void __RPC_STUB IEventDatabasePlugin_put_Parent_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [propputref][helpstring] */ HRESULT STDMETHODCALLTYPE IEventDatabasePlugin_putref_Parent_Proxy( 
    IEventDatabasePlugin __RPC_FAR * This,
    /* [in] */ IEventPropertyBag __RPC_FAR *__RPC_FAR *ppParent);


void __RPC_STUB IEventDatabasePlugin_putref_Parent_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);



#endif 	/* __IEventDatabasePlugin_INTERFACE_DEFINED__ */


#ifndef __IEventDatabaseManager_INTERFACE_DEFINED__
#define __IEventDatabaseManager_INTERFACE_DEFINED__

/* interface IEventDatabaseManager */
/* [uuid][unique][oleautomation][object][helpstring] */ 


EXTERN_C const IID IID_IEventDatabaseManager;

#if defined(__cplusplus) && !defined(CINTERFACE)
    
    MIDL_INTERFACE("adc25b30-cbd8-11d0-a9f8-00aa00685c74")
    IEventDatabaseManager : public IDispatch
    {
    public:
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE CreateDatabase( 
            /* [in] */ BSTR strPath,
            /* [retval][out] */ IUnknown __RPC_FAR *__RPC_FAR *ppMonDatabase) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE EraseDatabase( 
            /* [in] */ BSTR strPath) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE MakeVServerPath( 
            /* [in] */ BSTR strService,
            /* [in] */ long lInstance,
            /* [retval][out] */ BSTR __RPC_FAR *pstrPath) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE MakeVRootPath( 
            /* [in] */ BSTR strService,
            /* [in] */ long lInstance,
            /* [in] */ BSTR strRoot,
            /* [retval][out] */ BSTR __RPC_FAR *pstrPath) = 0;
        
    };
    
#else 	/* C style interface */

    typedef struct IEventDatabaseManagerVtbl
    {
        BEGIN_INTERFACE
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *QueryInterface )( 
            IEventDatabaseManager __RPC_FAR * This,
            /* [in] */ REFIID riid,
            /* [iid_is][out] */ void __RPC_FAR *__RPC_FAR *ppvObject);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *AddRef )( 
            IEventDatabaseManager __RPC_FAR * This);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *Release )( 
            IEventDatabaseManager __RPC_FAR * This);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetTypeInfoCount )( 
            IEventDatabaseManager __RPC_FAR * This,
            /* [out] */ UINT __RPC_FAR *pctinfo);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetTypeInfo )( 
            IEventDatabaseManager __RPC_FAR * This,
            /* [in] */ UINT iTInfo,
            /* [in] */ LCID lcid,
            /* [out] */ ITypeInfo __RPC_FAR *__RPC_FAR *ppTInfo);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetIDsOfNames )( 
            IEventDatabaseManager __RPC_FAR * This,
            /* [in] */ REFIID riid,
            /* [size_is][in] */ LPOLESTR __RPC_FAR *rgszNames,
            /* [in] */ UINT cNames,
            /* [in] */ LCID lcid,
            /* [size_is][out] */ DISPID __RPC_FAR *rgDispId);
        
        /* [local] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *Invoke )( 
            IEventDatabaseManager __RPC_FAR * This,
            /* [in] */ DISPID dispIdMember,
            /* [in] */ REFIID riid,
            /* [in] */ LCID lcid,
            /* [in] */ WORD wFlags,
            /* [out][in] */ DISPPARAMS __RPC_FAR *pDispParams,
            /* [out] */ VARIANT __RPC_FAR *pVarResult,
            /* [out] */ EXCEPINFO __RPC_FAR *pExcepInfo,
            /* [out] */ UINT __RPC_FAR *puArgErr);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *CreateDatabase )( 
            IEventDatabaseManager __RPC_FAR * This,
            /* [in] */ BSTR strPath,
            /* [retval][out] */ IUnknown __RPC_FAR *__RPC_FAR *ppMonDatabase);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *EraseDatabase )( 
            IEventDatabaseManager __RPC_FAR * This,
            /* [in] */ BSTR strPath);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *MakeVServerPath )( 
            IEventDatabaseManager __RPC_FAR * This,
            /* [in] */ BSTR strService,
            /* [in] */ long lInstance,
            /* [retval][out] */ BSTR __RPC_FAR *pstrPath);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *MakeVRootPath )( 
            IEventDatabaseManager __RPC_FAR * This,
            /* [in] */ BSTR strService,
            /* [in] */ long lInstance,
            /* [in] */ BSTR strRoot,
            /* [retval][out] */ BSTR __RPC_FAR *pstrPath);
        
        END_INTERFACE
    } IEventDatabaseManagerVtbl;

    interface IEventDatabaseManager
    {
        CONST_VTBL struct IEventDatabaseManagerVtbl __RPC_FAR *lpVtbl;
    };

    

#ifdef COBJMACROS


#define IEventDatabaseManager_QueryInterface(This,riid,ppvObject)	\
    (This)->lpVtbl -> QueryInterface(This,riid,ppvObject)

#define IEventDatabaseManager_AddRef(This)	\
    (This)->lpVtbl -> AddRef(This)

#define IEventDatabaseManager_Release(This)	\
    (This)->lpVtbl -> Release(This)


#define IEventDatabaseManager_GetTypeInfoCount(This,pctinfo)	\
    (This)->lpVtbl -> GetTypeInfoCount(This,pctinfo)

#define IEventDatabaseManager_GetTypeInfo(This,iTInfo,lcid,ppTInfo)	\
    (This)->lpVtbl -> GetTypeInfo(This,iTInfo,lcid,ppTInfo)

#define IEventDatabaseManager_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)	\
    (This)->lpVtbl -> GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)

#define IEventDatabaseManager_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)	\
    (This)->lpVtbl -> Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)


#define IEventDatabaseManager_CreateDatabase(This,strPath,ppMonDatabase)	\
    (This)->lpVtbl -> CreateDatabase(This,strPath,ppMonDatabase)

#define IEventDatabaseManager_EraseDatabase(This,strPath)	\
    (This)->lpVtbl -> EraseDatabase(This,strPath)

#define IEventDatabaseManager_MakeVServerPath(This,strService,lInstance,pstrPath)	\
    (This)->lpVtbl -> MakeVServerPath(This,strService,lInstance,pstrPath)

#define IEventDatabaseManager_MakeVRootPath(This,strService,lInstance,strRoot,pstrPath)	\
    (This)->lpVtbl -> MakeVRootPath(This,strService,lInstance,strRoot,pstrPath)

#endif /* COBJMACROS */


#endif 	/* C style interface */



/* [helpstring] */ HRESULT STDMETHODCALLTYPE IEventDatabaseManager_CreateDatabase_Proxy( 
    IEventDatabaseManager __RPC_FAR * This,
    /* [in] */ BSTR strPath,
    /* [retval][out] */ IUnknown __RPC_FAR *__RPC_FAR *ppMonDatabase);


void __RPC_STUB IEventDatabaseManager_CreateDatabase_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IEventDatabaseManager_EraseDatabase_Proxy( 
    IEventDatabaseManager __RPC_FAR * This,
    /* [in] */ BSTR strPath);


void __RPC_STUB IEventDatabaseManager_EraseDatabase_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IEventDatabaseManager_MakeVServerPath_Proxy( 
    IEventDatabaseManager __RPC_FAR * This,
    /* [in] */ BSTR strService,
    /* [in] */ long lInstance,
    /* [retval][out] */ BSTR __RPC_FAR *pstrPath);


void __RPC_STUB IEventDatabaseManager_MakeVServerPath_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IEventDatabaseManager_MakeVRootPath_Proxy( 
    IEventDatabaseManager __RPC_FAR * This,
    /* [in] */ BSTR strService,
    /* [in] */ long lInstance,
    /* [in] */ BSTR strRoot,
    /* [retval][out] */ BSTR __RPC_FAR *pstrPath);


void __RPC_STUB IEventDatabaseManager_MakeVRootPath_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);



#endif 	/* __IEventDatabaseManager_INTERFACE_DEFINED__ */


#ifndef __IEventUtil_INTERFACE_DEFINED__
#define __IEventUtil_INTERFACE_DEFINED__

/* interface IEventUtil */
/* [uuid][unique][oleautomation][object][helpstring] */ 


EXTERN_C const IID IID_IEventUtil;

#if defined(__cplusplus) && !defined(CINTERFACE)
    
    MIDL_INTERFACE("c61670e0-cd6e-11d0-a9f8-00aa00685c74")
    IEventUtil : public IDispatch
    {
    public:
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE DisplayNameFromMoniker( 
            /* [in] */ IUnknown __RPC_FAR *pUnkMoniker,
            /* [retval][out] */ BSTR __RPC_FAR *pstrDisplayName) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE MonikerFromDisplayName( 
            /* [in] */ BSTR strDisplayName,
            /* [retval][out] */ IUnknown __RPC_FAR *__RPC_FAR *ppUnkMoniker) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE ObjectFromMoniker( 
            /* [in] */ IUnknown __RPC_FAR *pUnkMoniker,
            /* [retval][out] */ IUnknown __RPC_FAR *__RPC_FAR *ppUnkObject) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE GetNewGUID( 
            /* [retval][out] */ BSTR __RPC_FAR *pstrGUID) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE CopyPropertyBag( 
            /* [in] */ IUnknown __RPC_FAR *pUnkInput,
            /* [retval][out] */ IUnknown __RPC_FAR *__RPC_FAR *ppUnkOutput) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE CopyPropertyBagShallow( 
            /* [in] */ IUnknown __RPC_FAR *pUnkInput,
            /* [retval][out] */ IUnknown __RPC_FAR *__RPC_FAR *ppUnkOutput) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE DispatchFromObject( 
            /* [in] */ IUnknown __RPC_FAR *pUnkObject,
            /* [retval][out] */ IDispatch __RPC_FAR *__RPC_FAR *ppDispOutput) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE GetIndexedGUID( 
            /* [in] */ BSTR strGUID,
            /* [in] */ long lValue,
            /* [retval][out] */ BSTR __RPC_FAR *pstrResult) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE RegisterSource( 
            /* [in] */ BSTR strSourceType,
            /* [in] */ BSTR strSource,
            /* [in] */ long lInstance,
            /* [in] */ BSTR strService,
            /* [in] */ BSTR strVRoot,
            /* [in] */ BSTR strDatabaseManager,
            /* [in] */ BSTR strDisplayName,
            /* [retval][out] */ IEventBindingManager __RPC_FAR *__RPC_FAR *ppBindingManager) = 0;
        
    };
    
#else 	/* C style interface */

    typedef struct IEventUtilVtbl
    {
        BEGIN_INTERFACE
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *QueryInterface )( 
            IEventUtil __RPC_FAR * This,
            /* [in] */ REFIID riid,
            /* [iid_is][out] */ void __RPC_FAR *__RPC_FAR *ppvObject);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *AddRef )( 
            IEventUtil __RPC_FAR * This);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *Release )( 
            IEventUtil __RPC_FAR * This);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetTypeInfoCount )( 
            IEventUtil __RPC_FAR * This,
            /* [out] */ UINT __RPC_FAR *pctinfo);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetTypeInfo )( 
            IEventUtil __RPC_FAR * This,
            /* [in] */ UINT iTInfo,
            /* [in] */ LCID lcid,
            /* [out] */ ITypeInfo __RPC_FAR *__RPC_FAR *ppTInfo);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetIDsOfNames )( 
            IEventUtil __RPC_FAR * This,
            /* [in] */ REFIID riid,
            /* [size_is][in] */ LPOLESTR __RPC_FAR *rgszNames,
            /* [in] */ UINT cNames,
            /* [in] */ LCID lcid,
            /* [size_is][out] */ DISPID __RPC_FAR *rgDispId);
        
        /* [local] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *Invoke )( 
            IEventUtil __RPC_FAR * This,
            /* [in] */ DISPID dispIdMember,
            /* [in] */ REFIID riid,
            /* [in] */ LCID lcid,
            /* [in] */ WORD wFlags,
            /* [out][in] */ DISPPARAMS __RPC_FAR *pDispParams,
            /* [out] */ VARIANT __RPC_FAR *pVarResult,
            /* [out] */ EXCEPINFO __RPC_FAR *pExcepInfo,
            /* [out] */ UINT __RPC_FAR *puArgErr);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *DisplayNameFromMoniker )( 
            IEventUtil __RPC_FAR * This,
            /* [in] */ IUnknown __RPC_FAR *pUnkMoniker,
            /* [retval][out] */ BSTR __RPC_FAR *pstrDisplayName);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *MonikerFromDisplayName )( 
            IEventUtil __RPC_FAR * This,
            /* [in] */ BSTR strDisplayName,
            /* [retval][out] */ IUnknown __RPC_FAR *__RPC_FAR *ppUnkMoniker);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *ObjectFromMoniker )( 
            IEventUtil __RPC_FAR * This,
            /* [in] */ IUnknown __RPC_FAR *pUnkMoniker,
            /* [retval][out] */ IUnknown __RPC_FAR *__RPC_FAR *ppUnkObject);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetNewGUID )( 
            IEventUtil __RPC_FAR * This,
            /* [retval][out] */ BSTR __RPC_FAR *pstrGUID);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *CopyPropertyBag )( 
            IEventUtil __RPC_FAR * This,
            /* [in] */ IUnknown __RPC_FAR *pUnkInput,
            /* [retval][out] */ IUnknown __RPC_FAR *__RPC_FAR *ppUnkOutput);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *CopyPropertyBagShallow )( 
            IEventUtil __RPC_FAR * This,
            /* [in] */ IUnknown __RPC_FAR *pUnkInput,
            /* [retval][out] */ IUnknown __RPC_FAR *__RPC_FAR *ppUnkOutput);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *DispatchFromObject )( 
            IEventUtil __RPC_FAR * This,
            /* [in] */ IUnknown __RPC_FAR *pUnkObject,
            /* [retval][out] */ IDispatch __RPC_FAR *__RPC_FAR *ppDispOutput);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetIndexedGUID )( 
            IEventUtil __RPC_FAR * This,
            /* [in] */ BSTR strGUID,
            /* [in] */ long lValue,
            /* [retval][out] */ BSTR __RPC_FAR *pstrResult);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *RegisterSource )( 
            IEventUtil __RPC_FAR * This,
            /* [in] */ BSTR strSourceType,
            /* [in] */ BSTR strSource,
            /* [in] */ long lInstance,
            /* [in] */ BSTR strService,
            /* [in] */ BSTR strVRoot,
            /* [in] */ BSTR strDatabaseManager,
            /* [in] */ BSTR strDisplayName,
            /* [retval][out] */ IEventBindingManager __RPC_FAR *__RPC_FAR *ppBindingManager);
        
        END_INTERFACE
    } IEventUtilVtbl;

    interface IEventUtil
    {
        CONST_VTBL struct IEventUtilVtbl __RPC_FAR *lpVtbl;
    };

    

#ifdef COBJMACROS


#define IEventUtil_QueryInterface(This,riid,ppvObject)	\
    (This)->lpVtbl -> QueryInterface(This,riid,ppvObject)

#define IEventUtil_AddRef(This)	\
    (This)->lpVtbl -> AddRef(This)

#define IEventUtil_Release(This)	\
    (This)->lpVtbl -> Release(This)


#define IEventUtil_GetTypeInfoCount(This,pctinfo)	\
    (This)->lpVtbl -> GetTypeInfoCount(This,pctinfo)

#define IEventUtil_GetTypeInfo(This,iTInfo,lcid,ppTInfo)	\
    (This)->lpVtbl -> GetTypeInfo(This,iTInfo,lcid,ppTInfo)

#define IEventUtil_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)	\
    (This)->lpVtbl -> GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)

#define IEventUtil_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)	\
    (This)->lpVtbl -> Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)


#define IEventUtil_DisplayNameFromMoniker(This,pUnkMoniker,pstrDisplayName)	\
    (This)->lpVtbl -> DisplayNameFromMoniker(This,pUnkMoniker,pstrDisplayName)

#define IEventUtil_MonikerFromDisplayName(This,strDisplayName,ppUnkMoniker)	\
    (This)->lpVtbl -> MonikerFromDisplayName(This,strDisplayName,ppUnkMoniker)

#define IEventUtil_ObjectFromMoniker(This,pUnkMoniker,ppUnkObject)	\
    (This)->lpVtbl -> ObjectFromMoniker(This,pUnkMoniker,ppUnkObject)

#define IEventUtil_GetNewGUID(This,pstrGUID)	\
    (This)->lpVtbl -> GetNewGUID(This,pstrGUID)

#define IEventUtil_CopyPropertyBag(This,pUnkInput,ppUnkOutput)	\
    (This)->lpVtbl -> CopyPropertyBag(This,pUnkInput,ppUnkOutput)

#define IEventUtil_CopyPropertyBagShallow(This,pUnkInput,ppUnkOutput)	\
    (This)->lpVtbl -> CopyPropertyBagShallow(This,pUnkInput,ppUnkOutput)

#define IEventUtil_DispatchFromObject(This,pUnkObject,ppDispOutput)	\
    (This)->lpVtbl -> DispatchFromObject(This,pUnkObject,ppDispOutput)

#define IEventUtil_GetIndexedGUID(This,strGUID,lValue,pstrResult)	\
    (This)->lpVtbl -> GetIndexedGUID(This,strGUID,lValue,pstrResult)

#define IEventUtil_RegisterSource(This,strSourceType,strSource,lInstance,strService,strVRoot,strDatabaseManager,strDisplayName,ppBindingManager)	\
    (This)->lpVtbl -> RegisterSource(This,strSourceType,strSource,lInstance,strService,strVRoot,strDatabaseManager,strDisplayName,ppBindingManager)

#endif /* COBJMACROS */


#endif 	/* C style interface */



/* [helpstring] */ HRESULT STDMETHODCALLTYPE IEventUtil_DisplayNameFromMoniker_Proxy( 
    IEventUtil __RPC_FAR * This,
    /* [in] */ IUnknown __RPC_FAR *pUnkMoniker,
    /* [retval][out] */ BSTR __RPC_FAR *pstrDisplayName);


void __RPC_STUB IEventUtil_DisplayNameFromMoniker_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IEventUtil_MonikerFromDisplayName_Proxy( 
    IEventUtil __RPC_FAR * This,
    /* [in] */ BSTR strDisplayName,
    /* [retval][out] */ IUnknown __RPC_FAR *__RPC_FAR *ppUnkMoniker);


void __RPC_STUB IEventUtil_MonikerFromDisplayName_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IEventUtil_ObjectFromMoniker_Proxy( 
    IEventUtil __RPC_FAR * This,
    /* [in] */ IUnknown __RPC_FAR *pUnkMoniker,
    /* [retval][out] */ IUnknown __RPC_FAR *__RPC_FAR *ppUnkObject);


void __RPC_STUB IEventUtil_ObjectFromMoniker_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IEventUtil_GetNewGUID_Proxy( 
    IEventUtil __RPC_FAR * This,
    /* [retval][out] */ BSTR __RPC_FAR *pstrGUID);


void __RPC_STUB IEventUtil_GetNewGUID_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IEventUtil_CopyPropertyBag_Proxy( 
    IEventUtil __RPC_FAR * This,
    /* [in] */ IUnknown __RPC_FAR *pUnkInput,
    /* [retval][out] */ IUnknown __RPC_FAR *__RPC_FAR *ppUnkOutput);


void __RPC_STUB IEventUtil_CopyPropertyBag_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IEventUtil_CopyPropertyBagShallow_Proxy( 
    IEventUtil __RPC_FAR * This,
    /* [in] */ IUnknown __RPC_FAR *pUnkInput,
    /* [retval][out] */ IUnknown __RPC_FAR *__RPC_FAR *ppUnkOutput);


void __RPC_STUB IEventUtil_CopyPropertyBagShallow_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IEventUtil_DispatchFromObject_Proxy( 
    IEventUtil __RPC_FAR * This,
    /* [in] */ IUnknown __RPC_FAR *pUnkObject,
    /* [retval][out] */ IDispatch __RPC_FAR *__RPC_FAR *ppDispOutput);


void __RPC_STUB IEventUtil_DispatchFromObject_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IEventUtil_GetIndexedGUID_Proxy( 
    IEventUtil __RPC_FAR * This,
    /* [in] */ BSTR strGUID,
    /* [in] */ long lValue,
    /* [retval][out] */ BSTR __RPC_FAR *pstrResult);


void __RPC_STUB IEventUtil_GetIndexedGUID_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IEventUtil_RegisterSource_Proxy( 
    IEventUtil __RPC_FAR * This,
    /* [in] */ BSTR strSourceType,
    /* [in] */ BSTR strSource,
    /* [in] */ long lInstance,
    /* [in] */ BSTR strService,
    /* [in] */ BSTR strVRoot,
    /* [in] */ BSTR strDatabaseManager,
    /* [in] */ BSTR strDisplayName,
    /* [retval][out] */ IEventBindingManager __RPC_FAR *__RPC_FAR *ppBindingManager);


void __RPC_STUB IEventUtil_RegisterSource_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);



#endif 	/* __IEventUtil_INTERFACE_DEFINED__ */


#ifndef __IEventComCat_INTERFACE_DEFINED__
#define __IEventComCat_INTERFACE_DEFINED__

/* interface IEventComCat */
/* [uuid][unique][oleautomation][object][helpstring] */ 


EXTERN_C const IID IID_IEventComCat;

#if defined(__cplusplus) && !defined(CINTERFACE)
    
    MIDL_INTERFACE("65a70ec0-cd87-11d0-a9f8-00aa00685c74")
    IEventComCat : public IDispatch
    {
    public:
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE RegisterCategory( 
            /* [in] */ BSTR pszCategory,
            /* [in] */ BSTR pszDescription,
            /* [in] */ long lcidLanguage) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE UnRegisterCategory( 
            /* [in] */ BSTR pszCategory) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE RegisterClassImplementsCategory( 
            /* [in] */ BSTR pszClass,
            /* [in] */ BSTR pszCategory) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE UnRegisterClassImplementsCategory( 
            /* [in] */ BSTR pszClass,
            /* [in] */ BSTR pszCategory) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE RegisterClassRequiresCategory( 
            /* [in] */ BSTR pszClass,
            /* [in] */ BSTR pszCategory) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE UnRegisterClassRequiresCategory( 
            /* [in] */ BSTR pszClass,
            /* [in] */ BSTR pszCategory) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE GetCategories( 
            /* [retval][out] */ SAFEARRAY __RPC_FAR * __RPC_FAR *psaCategories) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE GetCategoryDescription( 
            /* [in] */ BSTR pszCategory,
            /* [in] */ long lcidLanguage,
            /* [retval][out] */ BSTR __RPC_FAR *pstrDescription) = 0;
        
    };
    
#else 	/* C style interface */

    typedef struct IEventComCatVtbl
    {
        BEGIN_INTERFACE
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *QueryInterface )( 
            IEventComCat __RPC_FAR * This,
            /* [in] */ REFIID riid,
            /* [iid_is][out] */ void __RPC_FAR *__RPC_FAR *ppvObject);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *AddRef )( 
            IEventComCat __RPC_FAR * This);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *Release )( 
            IEventComCat __RPC_FAR * This);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetTypeInfoCount )( 
            IEventComCat __RPC_FAR * This,
            /* [out] */ UINT __RPC_FAR *pctinfo);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetTypeInfo )( 
            IEventComCat __RPC_FAR * This,
            /* [in] */ UINT iTInfo,
            /* [in] */ LCID lcid,
            /* [out] */ ITypeInfo __RPC_FAR *__RPC_FAR *ppTInfo);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetIDsOfNames )( 
            IEventComCat __RPC_FAR * This,
            /* [in] */ REFIID riid,
            /* [size_is][in] */ LPOLESTR __RPC_FAR *rgszNames,
            /* [in] */ UINT cNames,
            /* [in] */ LCID lcid,
            /* [size_is][out] */ DISPID __RPC_FAR *rgDispId);
        
        /* [local] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *Invoke )( 
            IEventComCat __RPC_FAR * This,
            /* [in] */ DISPID dispIdMember,
            /* [in] */ REFIID riid,
            /* [in] */ LCID lcid,
            /* [in] */ WORD wFlags,
            /* [out][in] */ DISPPARAMS __RPC_FAR *pDispParams,
            /* [out] */ VARIANT __RPC_FAR *pVarResult,
            /* [out] */ EXCEPINFO __RPC_FAR *pExcepInfo,
            /* [out] */ UINT __RPC_FAR *puArgErr);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *RegisterCategory )( 
            IEventComCat __RPC_FAR * This,
            /* [in] */ BSTR pszCategory,
            /* [in] */ BSTR pszDescription,
            /* [in] */ long lcidLanguage);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *UnRegisterCategory )( 
            IEventComCat __RPC_FAR * This,
            /* [in] */ BSTR pszCategory);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *RegisterClassImplementsCategory )( 
            IEventComCat __RPC_FAR * This,
            /* [in] */ BSTR pszClass,
            /* [in] */ BSTR pszCategory);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *UnRegisterClassImplementsCategory )( 
            IEventComCat __RPC_FAR * This,
            /* [in] */ BSTR pszClass,
            /* [in] */ BSTR pszCategory);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *RegisterClassRequiresCategory )( 
            IEventComCat __RPC_FAR * This,
            /* [in] */ BSTR pszClass,
            /* [in] */ BSTR pszCategory);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *UnRegisterClassRequiresCategory )( 
            IEventComCat __RPC_FAR * This,
            /* [in] */ BSTR pszClass,
            /* [in] */ BSTR pszCategory);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetCategories )( 
            IEventComCat __RPC_FAR * This,
            /* [retval][out] */ SAFEARRAY __RPC_FAR * __RPC_FAR *psaCategories);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetCategoryDescription )( 
            IEventComCat __RPC_FAR * This,
            /* [in] */ BSTR pszCategory,
            /* [in] */ long lcidLanguage,
            /* [retval][out] */ BSTR __RPC_FAR *pstrDescription);
        
        END_INTERFACE
    } IEventComCatVtbl;

    interface IEventComCat
    {
        CONST_VTBL struct IEventComCatVtbl __RPC_FAR *lpVtbl;
    };

    

#ifdef COBJMACROS


#define IEventComCat_QueryInterface(This,riid,ppvObject)	\
    (This)->lpVtbl -> QueryInterface(This,riid,ppvObject)

#define IEventComCat_AddRef(This)	\
    (This)->lpVtbl -> AddRef(This)

#define IEventComCat_Release(This)	\
    (This)->lpVtbl -> Release(This)


#define IEventComCat_GetTypeInfoCount(This,pctinfo)	\
    (This)->lpVtbl -> GetTypeInfoCount(This,pctinfo)

#define IEventComCat_GetTypeInfo(This,iTInfo,lcid,ppTInfo)	\
    (This)->lpVtbl -> GetTypeInfo(This,iTInfo,lcid,ppTInfo)

#define IEventComCat_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)	\
    (This)->lpVtbl -> GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)

#define IEventComCat_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)	\
    (This)->lpVtbl -> Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)


#define IEventComCat_RegisterCategory(This,pszCategory,pszDescription,lcidLanguage)	\
    (This)->lpVtbl -> RegisterCategory(This,pszCategory,pszDescription,lcidLanguage)

#define IEventComCat_UnRegisterCategory(This,pszCategory)	\
    (This)->lpVtbl -> UnRegisterCategory(This,pszCategory)

#define IEventComCat_RegisterClassImplementsCategory(This,pszClass,pszCategory)	\
    (This)->lpVtbl -> RegisterClassImplementsCategory(This,pszClass,pszCategory)

#define IEventComCat_UnRegisterClassImplementsCategory(This,pszClass,pszCategory)	\
    (This)->lpVtbl -> UnRegisterClassImplementsCategory(This,pszClass,pszCategory)

#define IEventComCat_RegisterClassRequiresCategory(This,pszClass,pszCategory)	\
    (This)->lpVtbl -> RegisterClassRequiresCategory(This,pszClass,pszCategory)

#define IEventComCat_UnRegisterClassRequiresCategory(This,pszClass,pszCategory)	\
    (This)->lpVtbl -> UnRegisterClassRequiresCategory(This,pszClass,pszCategory)

#define IEventComCat_GetCategories(This,psaCategories)	\
    (This)->lpVtbl -> GetCategories(This,psaCategories)

#define IEventComCat_GetCategoryDescription(This,pszCategory,lcidLanguage,pstrDescription)	\
    (This)->lpVtbl -> GetCategoryDescription(This,pszCategory,lcidLanguage,pstrDescription)

#endif /* COBJMACROS */


#endif 	/* C style interface */



/* [helpstring] */ HRESULT STDMETHODCALLTYPE IEventComCat_RegisterCategory_Proxy( 
    IEventComCat __RPC_FAR * This,
    /* [in] */ BSTR pszCategory,
    /* [in] */ BSTR pszDescription,
    /* [in] */ long lcidLanguage);


void __RPC_STUB IEventComCat_RegisterCategory_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IEventComCat_UnRegisterCategory_Proxy( 
    IEventComCat __RPC_FAR * This,
    /* [in] */ BSTR pszCategory);


void __RPC_STUB IEventComCat_UnRegisterCategory_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IEventComCat_RegisterClassImplementsCategory_Proxy( 
    IEventComCat __RPC_FAR * This,
    /* [in] */ BSTR pszClass,
    /* [in] */ BSTR pszCategory);


void __RPC_STUB IEventComCat_RegisterClassImplementsCategory_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IEventComCat_UnRegisterClassImplementsCategory_Proxy( 
    IEventComCat __RPC_FAR * This,
    /* [in] */ BSTR pszClass,
    /* [in] */ BSTR pszCategory);


void __RPC_STUB IEventComCat_UnRegisterClassImplementsCategory_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IEventComCat_RegisterClassRequiresCategory_Proxy( 
    IEventComCat __RPC_FAR * This,
    /* [in] */ BSTR pszClass,
    /* [in] */ BSTR pszCategory);


void __RPC_STUB IEventComCat_RegisterClassRequiresCategory_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IEventComCat_UnRegisterClassRequiresCategory_Proxy( 
    IEventComCat __RPC_FAR * This,
    /* [in] */ BSTR pszClass,
    /* [in] */ BSTR pszCategory);


void __RPC_STUB IEventComCat_UnRegisterClassRequiresCategory_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IEventComCat_GetCategories_Proxy( 
    IEventComCat __RPC_FAR * This,
    /* [retval][out] */ SAFEARRAY __RPC_FAR * __RPC_FAR *psaCategories);


void __RPC_STUB IEventComCat_GetCategories_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IEventComCat_GetCategoryDescription_Proxy( 
    IEventComCat __RPC_FAR * This,
    /* [in] */ BSTR pszCategory,
    /* [in] */ long lcidLanguage,
    /* [retval][out] */ BSTR __RPC_FAR *pstrDescription);


void __RPC_STUB IEventComCat_GetCategoryDescription_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);



#endif 	/* __IEventComCat_INTERFACE_DEFINED__ */


#ifndef __IEventNotifyBindingChange_INTERFACE_DEFINED__
#define __IEventNotifyBindingChange_INTERFACE_DEFINED__

/* interface IEventNotifyBindingChange */
/* [uuid][unique][object][hidden][helpstring] */ 


EXTERN_C const IID IID_IEventNotifyBindingChange;

#if defined(__cplusplus) && !defined(CINTERFACE)
    
    MIDL_INTERFACE("08f4f2a0-dc5b-11d0-aa0f-00aa006bc80b")
    IEventNotifyBindingChange : public IUnknown
    {
    public:
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE OnChange( void) = 0;
        
    };
    
#else 	/* C style interface */

    typedef struct IEventNotifyBindingChangeVtbl
    {
        BEGIN_INTERFACE
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *QueryInterface )( 
            IEventNotifyBindingChange __RPC_FAR * This,
            /* [in] */ REFIID riid,
            /* [iid_is][out] */ void __RPC_FAR *__RPC_FAR *ppvObject);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *AddRef )( 
            IEventNotifyBindingChange __RPC_FAR * This);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *Release )( 
            IEventNotifyBindingChange __RPC_FAR * This);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *OnChange )( 
            IEventNotifyBindingChange __RPC_FAR * This);
        
        END_INTERFACE
    } IEventNotifyBindingChangeVtbl;

    interface IEventNotifyBindingChange
    {
        CONST_VTBL struct IEventNotifyBindingChangeVtbl __RPC_FAR *lpVtbl;
    };

    

#ifdef COBJMACROS


#define IEventNotifyBindingChange_QueryInterface(This,riid,ppvObject)	\
    (This)->lpVtbl -> QueryInterface(This,riid,ppvObject)

#define IEventNotifyBindingChange_AddRef(This)	\
    (This)->lpVtbl -> AddRef(This)

#define IEventNotifyBindingChange_Release(This)	\
    (This)->lpVtbl -> Release(This)


#define IEventNotifyBindingChange_OnChange(This)	\
    (This)->lpVtbl -> OnChange(This)

#endif /* COBJMACROS */


#endif 	/* C style interface */



/* [helpstring] */ HRESULT STDMETHODCALLTYPE IEventNotifyBindingChange_OnChange_Proxy( 
    IEventNotifyBindingChange __RPC_FAR * This);


void __RPC_STUB IEventNotifyBindingChange_OnChange_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);



#endif 	/* __IEventNotifyBindingChange_INTERFACE_DEFINED__ */


#ifndef __IEventNotifyBindingChangeDisp_INTERFACE_DEFINED__
#define __IEventNotifyBindingChangeDisp_INTERFACE_DEFINED__

/* interface IEventNotifyBindingChangeDisp */
/* [uuid][unique][object][hidden][helpstring][dual] */ 


EXTERN_C const IID IID_IEventNotifyBindingChangeDisp;

#if defined(__cplusplus) && !defined(CINTERFACE)
    
    MIDL_INTERFACE("dc3d83b0-e99f-11d0-aa10-00aa006bc80b")
    IEventNotifyBindingChangeDisp : public IDispatch
    {
    public:
        virtual /* [id][helpstring] */ HRESULT STDMETHODCALLTYPE OnChange( void) = 0;
        
    };
    
#else 	/* C style interface */

    typedef struct IEventNotifyBindingChangeDispVtbl
    {
        BEGIN_INTERFACE
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *QueryInterface )( 
            IEventNotifyBindingChangeDisp __RPC_FAR * This,
            /* [in] */ REFIID riid,
            /* [iid_is][out] */ void __RPC_FAR *__RPC_FAR *ppvObject);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *AddRef )( 
            IEventNotifyBindingChangeDisp __RPC_FAR * This);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *Release )( 
            IEventNotifyBindingChangeDisp __RPC_FAR * This);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetTypeInfoCount )( 
            IEventNotifyBindingChangeDisp __RPC_FAR * This,
            /* [out] */ UINT __RPC_FAR *pctinfo);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetTypeInfo )( 
            IEventNotifyBindingChangeDisp __RPC_FAR * This,
            /* [in] */ UINT iTInfo,
            /* [in] */ LCID lcid,
            /* [out] */ ITypeInfo __RPC_FAR *__RPC_FAR *ppTInfo);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetIDsOfNames )( 
            IEventNotifyBindingChangeDisp __RPC_FAR * This,
            /* [in] */ REFIID riid,
            /* [size_is][in] */ LPOLESTR __RPC_FAR *rgszNames,
            /* [in] */ UINT cNames,
            /* [in] */ LCID lcid,
            /* [size_is][out] */ DISPID __RPC_FAR *rgDispId);
        
        /* [local] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *Invoke )( 
            IEventNotifyBindingChangeDisp __RPC_FAR * This,
            /* [in] */ DISPID dispIdMember,
            /* [in] */ REFIID riid,
            /* [in] */ LCID lcid,
            /* [in] */ WORD wFlags,
            /* [out][in] */ DISPPARAMS __RPC_FAR *pDispParams,
            /* [out] */ VARIANT __RPC_FAR *pVarResult,
            /* [out] */ EXCEPINFO __RPC_FAR *pExcepInfo,
            /* [out] */ UINT __RPC_FAR *puArgErr);
        
        /* [id][helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *OnChange )( 
            IEventNotifyBindingChangeDisp __RPC_FAR * This);
        
        END_INTERFACE
    } IEventNotifyBindingChangeDispVtbl;

    interface IEventNotifyBindingChangeDisp
    {
        CONST_VTBL struct IEventNotifyBindingChangeDispVtbl __RPC_FAR *lpVtbl;
    };

    

#ifdef COBJMACROS


#define IEventNotifyBindingChangeDisp_QueryInterface(This,riid,ppvObject)	\
    (This)->lpVtbl -> QueryInterface(This,riid,ppvObject)

#define IEventNotifyBindingChangeDisp_AddRef(This)	\
    (This)->lpVtbl -> AddRef(This)

#define IEventNotifyBindingChangeDisp_Release(This)	\
    (This)->lpVtbl -> Release(This)


#define IEventNotifyBindingChangeDisp_GetTypeInfoCount(This,pctinfo)	\
    (This)->lpVtbl -> GetTypeInfoCount(This,pctinfo)

#define IEventNotifyBindingChangeDisp_GetTypeInfo(This,iTInfo,lcid,ppTInfo)	\
    (This)->lpVtbl -> GetTypeInfo(This,iTInfo,lcid,ppTInfo)

#define IEventNotifyBindingChangeDisp_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)	\
    (This)->lpVtbl -> GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)

#define IEventNotifyBindingChangeDisp_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)	\
    (This)->lpVtbl -> Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)


#define IEventNotifyBindingChangeDisp_OnChange(This)	\
    (This)->lpVtbl -> OnChange(This)

#endif /* COBJMACROS */


#endif 	/* C style interface */



/* [id][helpstring] */ HRESULT STDMETHODCALLTYPE IEventNotifyBindingChangeDisp_OnChange_Proxy( 
    IEventNotifyBindingChangeDisp __RPC_FAR * This);


void __RPC_STUB IEventNotifyBindingChangeDisp_OnChange_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);



#endif 	/* __IEventNotifyBindingChangeDisp_INTERFACE_DEFINED__ */


#ifndef __ISEOInitObject_INTERFACE_DEFINED__
#define __ISEOInitObject_INTERFACE_DEFINED__

/* interface ISEOInitObject */
/* [uuid][unique][object][hidden][helpstring] */ 


EXTERN_C const IID IID_ISEOInitObject;

#if defined(__cplusplus) && !defined(CINTERFACE)
    
    MIDL_INTERFACE("9bb6aab0-af6d-11d0-8bd2-00c04fd42e37")
    ISEOInitObject : public IPersistPropertyBag
    {
    public:
    };
    
#else 	/* C style interface */

    typedef struct ISEOInitObjectVtbl
    {
        BEGIN_INTERFACE
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *QueryInterface )( 
            ISEOInitObject __RPC_FAR * This,
            /* [in] */ REFIID riid,
            /* [iid_is][out] */ void __RPC_FAR *__RPC_FAR *ppvObject);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *AddRef )( 
            ISEOInitObject __RPC_FAR * This);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *Release )( 
            ISEOInitObject __RPC_FAR * This);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetClassID )( 
            ISEOInitObject __RPC_FAR * This,
            /* [out] */ CLSID __RPC_FAR *pClassID);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *InitNew )( 
            ISEOInitObject __RPC_FAR * This);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *Load )( 
            ISEOInitObject __RPC_FAR * This,
            /* [in] */ IPropertyBag __RPC_FAR *pPropBag,
            /* [in] */ IErrorLog __RPC_FAR *pErrorLog);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *Save )( 
            ISEOInitObject __RPC_FAR * This,
            /* [in] */ IPropertyBag __RPC_FAR *pPropBag,
            /* [in] */ BOOL fClearDirty,
            /* [in] */ BOOL fSaveAllProperties);
        
        END_INTERFACE
    } ISEOInitObjectVtbl;

    interface ISEOInitObject
    {
        CONST_VTBL struct ISEOInitObjectVtbl __RPC_FAR *lpVtbl;
    };

    

#ifdef COBJMACROS


#define ISEOInitObject_QueryInterface(This,riid,ppvObject)	\
    (This)->lpVtbl -> QueryInterface(This,riid,ppvObject)

#define ISEOInitObject_AddRef(This)	\
    (This)->lpVtbl -> AddRef(This)

#define ISEOInitObject_Release(This)	\
    (This)->lpVtbl -> Release(This)


#define ISEOInitObject_GetClassID(This,pClassID)	\
    (This)->lpVtbl -> GetClassID(This,pClassID)


#define ISEOInitObject_InitNew(This)	\
    (This)->lpVtbl -> InitNew(This)

#define ISEOInitObject_Load(This,pPropBag,pErrorLog)	\
    (This)->lpVtbl -> Load(This,pPropBag,pErrorLog)

#define ISEOInitObject_Save(This,pPropBag,fClearDirty,fSaveAllProperties)	\
    (This)->lpVtbl -> Save(This,pPropBag,fClearDirty,fSaveAllProperties)


#endif /* COBJMACROS */


#endif 	/* C style interface */




#endif 	/* __ISEOInitObject_INTERFACE_DEFINED__ */


#ifndef __IEventRuleEngine_INTERFACE_DEFINED__
#define __IEventRuleEngine_INTERFACE_DEFINED__

/* interface IEventRuleEngine */
/* [uuid][unique][object][helpstring] */ 


EXTERN_C const IID IID_IEventRuleEngine;

#if defined(__cplusplus) && !defined(CINTERFACE)
    
    MIDL_INTERFACE("da816090-f343-11d0-aa14-00aa006bc80b")
    IEventRuleEngine : public IUnknown
    {
    public:
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE Evaluate( 
            /* [unique][in] */ IUnknown __RPC_FAR *pEvent) = 0;
        
    };
    
#else 	/* C style interface */

    typedef struct IEventRuleEngineVtbl
    {
        BEGIN_INTERFACE
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *QueryInterface )( 
            IEventRuleEngine __RPC_FAR * This,
            /* [in] */ REFIID riid,
            /* [iid_is][out] */ void __RPC_FAR *__RPC_FAR *ppvObject);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *AddRef )( 
            IEventRuleEngine __RPC_FAR * This);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *Release )( 
            IEventRuleEngine __RPC_FAR * This);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *Evaluate )( 
            IEventRuleEngine __RPC_FAR * This,
            /* [unique][in] */ IUnknown __RPC_FAR *pEvent);
        
        END_INTERFACE
    } IEventRuleEngineVtbl;

    interface IEventRuleEngine
    {
        CONST_VTBL struct IEventRuleEngineVtbl __RPC_FAR *lpVtbl;
    };

    

#ifdef COBJMACROS


#define IEventRuleEngine_QueryInterface(This,riid,ppvObject)	\
    (This)->lpVtbl -> QueryInterface(This,riid,ppvObject)

#define IEventRuleEngine_AddRef(This)	\
    (This)->lpVtbl -> AddRef(This)

#define IEventRuleEngine_Release(This)	\
    (This)->lpVtbl -> Release(This)


#define IEventRuleEngine_Evaluate(This,pEvent)	\
    (This)->lpVtbl -> Evaluate(This,pEvent)

#endif /* COBJMACROS */


#endif 	/* C style interface */



/* [helpstring] */ HRESULT STDMETHODCALLTYPE IEventRuleEngine_Evaluate_Proxy( 
    IEventRuleEngine __RPC_FAR * This,
    /* [unique][in] */ IUnknown __RPC_FAR *pEvent);


void __RPC_STUB IEventRuleEngine_Evaluate_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);



#endif 	/* __IEventRuleEngine_INTERFACE_DEFINED__ */


#ifndef __IEventPersistBinding_INTERFACE_DEFINED__
#define __IEventPersistBinding_INTERFACE_DEFINED__

/* interface IEventPersistBinding */
/* [uuid][unique][object][helpstring] */ 


EXTERN_C const IID IID_IEventPersistBinding;

#if defined(__cplusplus) && !defined(CINTERFACE)
    
    MIDL_INTERFACE("e9311660-1a98-11d1-aa26-00aa006bc80b")
    IEventPersistBinding : public IPersist
    {
    public:
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE IsDirty( void) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE Load( 
            /* [in] */ IEventBinding __RPC_FAR *piBinding) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE Save( 
            /* [in] */ IEventBinding __RPC_FAR *piBinding,
            /* [in] */ VARIANT_BOOL fClearDirty) = 0;
        
    };
    
#else 	/* C style interface */

    typedef struct IEventPersistBindingVtbl
    {
        BEGIN_INTERFACE
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *QueryInterface )( 
            IEventPersistBinding __RPC_FAR * This,
            /* [in] */ REFIID riid,
            /* [iid_is][out] */ void __RPC_FAR *__RPC_FAR *ppvObject);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *AddRef )( 
            IEventPersistBinding __RPC_FAR * This);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *Release )( 
            IEventPersistBinding __RPC_FAR * This);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetClassID )( 
            IEventPersistBinding __RPC_FAR * This,
            /* [out] */ CLSID __RPC_FAR *pClassID);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *IsDirty )( 
            IEventPersistBinding __RPC_FAR * This);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *Load )( 
            IEventPersistBinding __RPC_FAR * This,
            /* [in] */ IEventBinding __RPC_FAR *piBinding);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *Save )( 
            IEventPersistBinding __RPC_FAR * This,
            /* [in] */ IEventBinding __RPC_FAR *piBinding,
            /* [in] */ VARIANT_BOOL fClearDirty);
        
        END_INTERFACE
    } IEventPersistBindingVtbl;

    interface IEventPersistBinding
    {
        CONST_VTBL struct IEventPersistBindingVtbl __RPC_FAR *lpVtbl;
    };

    

#ifdef COBJMACROS


#define IEventPersistBinding_QueryInterface(This,riid,ppvObject)	\
    (This)->lpVtbl -> QueryInterface(This,riid,ppvObject)

#define IEventPersistBinding_AddRef(This)	\
    (This)->lpVtbl -> AddRef(This)

#define IEventPersistBinding_Release(This)	\
    (This)->lpVtbl -> Release(This)


#define IEventPersistBinding_GetClassID(This,pClassID)	\
    (This)->lpVtbl -> GetClassID(This,pClassID)


#define IEventPersistBinding_IsDirty(This)	\
    (This)->lpVtbl -> IsDirty(This)

#define IEventPersistBinding_Load(This,piBinding)	\
    (This)->lpVtbl -> Load(This,piBinding)

#define IEventPersistBinding_Save(This,piBinding,fClearDirty)	\
    (This)->lpVtbl -> Save(This,piBinding,fClearDirty)

#endif /* COBJMACROS */


#endif 	/* C style interface */



/* [helpstring] */ HRESULT STDMETHODCALLTYPE IEventPersistBinding_IsDirty_Proxy( 
    IEventPersistBinding __RPC_FAR * This);


void __RPC_STUB IEventPersistBinding_IsDirty_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IEventPersistBinding_Load_Proxy( 
    IEventPersistBinding __RPC_FAR * This,
    /* [in] */ IEventBinding __RPC_FAR *piBinding);


void __RPC_STUB IEventPersistBinding_Load_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IEventPersistBinding_Save_Proxy( 
    IEventPersistBinding __RPC_FAR * This,
    /* [in] */ IEventBinding __RPC_FAR *piBinding,
    /* [in] */ VARIANT_BOOL fClearDirty);


void __RPC_STUB IEventPersistBinding_Save_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);



#endif 	/* __IEventPersistBinding_INTERFACE_DEFINED__ */


#ifndef __IEventSinkNotify_INTERFACE_DEFINED__
#define __IEventSinkNotify_INTERFACE_DEFINED__

/* interface IEventSinkNotify */
/* [uuid][unique][object][helpstring] */ 


EXTERN_C const IID IID_IEventSinkNotify;

#if defined(__cplusplus) && !defined(CINTERFACE)
    
    MIDL_INTERFACE("bdf065b0-f346-11d0-aa14-00aa006bc80b")
    IEventSinkNotify : public IUnknown
    {
    public:
        virtual /* [id][helpstring] */ HRESULT STDMETHODCALLTYPE OnEvent( void) = 0;
        
    };
    
#else 	/* C style interface */

    typedef struct IEventSinkNotifyVtbl
    {
        BEGIN_INTERFACE
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *QueryInterface )( 
            IEventSinkNotify __RPC_FAR * This,
            /* [in] */ REFIID riid,
            /* [iid_is][out] */ void __RPC_FAR *__RPC_FAR *ppvObject);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *AddRef )( 
            IEventSinkNotify __RPC_FAR * This);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *Release )( 
            IEventSinkNotify __RPC_FAR * This);
        
        /* [id][helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *OnEvent )( 
            IEventSinkNotify __RPC_FAR * This);
        
        END_INTERFACE
    } IEventSinkNotifyVtbl;

    interface IEventSinkNotify
    {
        CONST_VTBL struct IEventSinkNotifyVtbl __RPC_FAR *lpVtbl;
    };

    

#ifdef COBJMACROS


#define IEventSinkNotify_QueryInterface(This,riid,ppvObject)	\
    (This)->lpVtbl -> QueryInterface(This,riid,ppvObject)

#define IEventSinkNotify_AddRef(This)	\
    (This)->lpVtbl -> AddRef(This)

#define IEventSinkNotify_Release(This)	\
    (This)->lpVtbl -> Release(This)


#define IEventSinkNotify_OnEvent(This)	\
    (This)->lpVtbl -> OnEvent(This)

#endif /* COBJMACROS */


#endif 	/* C style interface */



/* [id][helpstring] */ HRESULT STDMETHODCALLTYPE IEventSinkNotify_OnEvent_Proxy( 
    IEventSinkNotify __RPC_FAR * This);


void __RPC_STUB IEventSinkNotify_OnEvent_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);



#endif 	/* __IEventSinkNotify_INTERFACE_DEFINED__ */


#ifndef __IEventSinkNotifyDisp_INTERFACE_DEFINED__
#define __IEventSinkNotifyDisp_INTERFACE_DEFINED__

/* interface IEventSinkNotifyDisp */
/* [uuid][unique][object][helpstring] */ 


EXTERN_C const IID IID_IEventSinkNotifyDisp;

#if defined(__cplusplus) && !defined(CINTERFACE)
    
    MIDL_INTERFACE("33a79660-f347-11d0-aa14-00aa006bc80b")
    IEventSinkNotifyDisp : public IDispatch
    {
    public:
        virtual /* [id][helpstring] */ HRESULT STDMETHODCALLTYPE OnEvent( void) = 0;
        
    };
    
#else 	/* C style interface */

    typedef struct IEventSinkNotifyDispVtbl
    {
        BEGIN_INTERFACE
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *QueryInterface )( 
            IEventSinkNotifyDisp __RPC_FAR * This,
            /* [in] */ REFIID riid,
            /* [iid_is][out] */ void __RPC_FAR *__RPC_FAR *ppvObject);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *AddRef )( 
            IEventSinkNotifyDisp __RPC_FAR * This);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *Release )( 
            IEventSinkNotifyDisp __RPC_FAR * This);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetTypeInfoCount )( 
            IEventSinkNotifyDisp __RPC_FAR * This,
            /* [out] */ UINT __RPC_FAR *pctinfo);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetTypeInfo )( 
            IEventSinkNotifyDisp __RPC_FAR * This,
            /* [in] */ UINT iTInfo,
            /* [in] */ LCID lcid,
            /* [out] */ ITypeInfo __RPC_FAR *__RPC_FAR *ppTInfo);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetIDsOfNames )( 
            IEventSinkNotifyDisp __RPC_FAR * This,
            /* [in] */ REFIID riid,
            /* [size_is][in] */ LPOLESTR __RPC_FAR *rgszNames,
            /* [in] */ UINT cNames,
            /* [in] */ LCID lcid,
            /* [size_is][out] */ DISPID __RPC_FAR *rgDispId);
        
        /* [local] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *Invoke )( 
            IEventSinkNotifyDisp __RPC_FAR * This,
            /* [in] */ DISPID dispIdMember,
            /* [in] */ REFIID riid,
            /* [in] */ LCID lcid,
            /* [in] */ WORD wFlags,
            /* [out][in] */ DISPPARAMS __RPC_FAR *pDispParams,
            /* [out] */ VARIANT __RPC_FAR *pVarResult,
            /* [out] */ EXCEPINFO __RPC_FAR *pExcepInfo,
            /* [out] */ UINT __RPC_FAR *puArgErr);
        
        /* [id][helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *OnEvent )( 
            IEventSinkNotifyDisp __RPC_FAR * This);
        
        END_INTERFACE
    } IEventSinkNotifyDispVtbl;

    interface IEventSinkNotifyDisp
    {
        CONST_VTBL struct IEventSinkNotifyDispVtbl __RPC_FAR *lpVtbl;
    };

    

#ifdef COBJMACROS


#define IEventSinkNotifyDisp_QueryInterface(This,riid,ppvObject)	\
    (This)->lpVtbl -> QueryInterface(This,riid,ppvObject)

#define IEventSinkNotifyDisp_AddRef(This)	\
    (This)->lpVtbl -> AddRef(This)

#define IEventSinkNotifyDisp_Release(This)	\
    (This)->lpVtbl -> Release(This)


#define IEventSinkNotifyDisp_GetTypeInfoCount(This,pctinfo)	\
    (This)->lpVtbl -> GetTypeInfoCount(This,pctinfo)

#define IEventSinkNotifyDisp_GetTypeInfo(This,iTInfo,lcid,ppTInfo)	\
    (This)->lpVtbl -> GetTypeInfo(This,iTInfo,lcid,ppTInfo)

#define IEventSinkNotifyDisp_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)	\
    (This)->lpVtbl -> GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)

#define IEventSinkNotifyDisp_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)	\
    (This)->lpVtbl -> Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)


#define IEventSinkNotifyDisp_OnEvent(This)	\
    (This)->lpVtbl -> OnEvent(This)

#endif /* COBJMACROS */


#endif 	/* C style interface */



/* [id][helpstring] */ HRESULT STDMETHODCALLTYPE IEventSinkNotifyDisp_OnEvent_Proxy( 
    IEventSinkNotifyDisp __RPC_FAR * This);


void __RPC_STUB IEventSinkNotifyDisp_OnEvent_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);



#endif 	/* __IEventSinkNotifyDisp_INTERFACE_DEFINED__ */


#ifndef __IEventIsCacheable_INTERFACE_DEFINED__
#define __IEventIsCacheable_INTERFACE_DEFINED__

/* interface IEventIsCacheable */
/* [uuid][unique][object][helpstring] */ 


EXTERN_C const IID IID_IEventIsCacheable;

#if defined(__cplusplus) && !defined(CINTERFACE)
    
    MIDL_INTERFACE("22e0f830-1e81-11d1-aa29-00aa006bc80b")
    IEventIsCacheable : public IUnknown
    {
    public:
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE IsCacheable( void) = 0;
        
    };
    
#else 	/* C style interface */

    typedef struct IEventIsCacheableVtbl
    {
        BEGIN_INTERFACE
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *QueryInterface )( 
            IEventIsCacheable __RPC_FAR * This,
            /* [in] */ REFIID riid,
            /* [iid_is][out] */ void __RPC_FAR *__RPC_FAR *ppvObject);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *AddRef )( 
            IEventIsCacheable __RPC_FAR * This);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *Release )( 
            IEventIsCacheable __RPC_FAR * This);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *IsCacheable )( 
            IEventIsCacheable __RPC_FAR * This);
        
        END_INTERFACE
    } IEventIsCacheableVtbl;

    interface IEventIsCacheable
    {
        CONST_VTBL struct IEventIsCacheableVtbl __RPC_FAR *lpVtbl;
    };

    

#ifdef COBJMACROS


#define IEventIsCacheable_QueryInterface(This,riid,ppvObject)	\
    (This)->lpVtbl -> QueryInterface(This,riid,ppvObject)

#define IEventIsCacheable_AddRef(This)	\
    (This)->lpVtbl -> AddRef(This)

#define IEventIsCacheable_Release(This)	\
    (This)->lpVtbl -> Release(This)


#define IEventIsCacheable_IsCacheable(This)	\
    (This)->lpVtbl -> IsCacheable(This)

#endif /* COBJMACROS */


#endif 	/* C style interface */



/* [helpstring] */ HRESULT STDMETHODCALLTYPE IEventIsCacheable_IsCacheable_Proxy( 
    IEventIsCacheable __RPC_FAR * This);


void __RPC_STUB IEventIsCacheable_IsCacheable_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);



#endif 	/* __IEventIsCacheable_INTERFACE_DEFINED__ */


#ifndef __IEventCreateOptions_INTERFACE_DEFINED__
#define __IEventCreateOptions_INTERFACE_DEFINED__

/* interface IEventCreateOptions */
/* [uuid][unique][object][hidden][helpstring] */ 


EXTERN_C const IID IID_IEventCreateOptions;

#if defined(__cplusplus) && !defined(CINTERFACE)
    
    MIDL_INTERFACE("c0287bfe-ef7f-11d1-9fff-00c04fa37348")
    IEventCreateOptions : public IEventDeliveryOptions
    {
    public:
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE CreateBindCtx( 
            /* [in] */ DWORD dwReserved,
            /* [out] */ IBindCtx __RPC_FAR *__RPC_FAR *ppBindCtx) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE MkParseDisplayName( 
            /* [in] */ IBindCtx __RPC_FAR *pBindCtx,
            /* [in] */ LPCOLESTR pszUserName,
            /* [out] */ ULONG __RPC_FAR *pchEaten,
            /* [out] */ LPMONIKER __RPC_FAR *ppMoniker) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE BindToObject( 
            /* [in] */ IMoniker __RPC_FAR *pMoniker,
            /* [in] */ IBindCtx __RPC_FAR *pBindCtx,
            /* [in] */ IMoniker __RPC_FAR *pmkLeft,
            /* [in] */ REFIID riidResult,
            /* [iid_is][out] */ LPVOID __RPC_FAR *ppvResult) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE CoCreateInstance( 
            /* [in] */ REFCLSID rclsidDesired,
            /* [in] */ IUnknown __RPC_FAR *pUnkOuter,
            /* [in] */ DWORD dwClsCtx,
            /* [in] */ REFIID riidResult,
            /* [iid_is][out] */ LPVOID __RPC_FAR *ppvResult) = 0;
        
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE Init( 
            /* [in] */ REFIID riidObject,
            /* [iid_is][out][in] */ IUnknown __RPC_FAR *__RPC_FAR *ppUnkObject,
            /* [unique][in] */ IEventBinding __RPC_FAR *pBinding,
            /* [unique][in] */ IUnknown __RPC_FAR *pInitProps) = 0;
        
    };
    
#else 	/* C style interface */

    typedef struct IEventCreateOptionsVtbl
    {
        BEGIN_INTERFACE
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *QueryInterface )( 
            IEventCreateOptions __RPC_FAR * This,
            /* [in] */ REFIID riid,
            /* [iid_is][out] */ void __RPC_FAR *__RPC_FAR *ppvObject);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *AddRef )( 
            IEventCreateOptions __RPC_FAR * This);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *Release )( 
            IEventCreateOptions __RPC_FAR * This);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetTypeInfoCount )( 
            IEventCreateOptions __RPC_FAR * This,
            /* [out] */ UINT __RPC_FAR *pctinfo);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetTypeInfo )( 
            IEventCreateOptions __RPC_FAR * This,
            /* [in] */ UINT iTInfo,
            /* [in] */ LCID lcid,
            /* [out] */ ITypeInfo __RPC_FAR *__RPC_FAR *ppTInfo);
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *GetIDsOfNames )( 
            IEventCreateOptions __RPC_FAR * This,
            /* [in] */ REFIID riid,
            /* [size_is][in] */ LPOLESTR __RPC_FAR *rgszNames,
            /* [in] */ UINT cNames,
            /* [in] */ LCID lcid,
            /* [size_is][out] */ DISPID __RPC_FAR *rgDispId);
        
        /* [local] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *Invoke )( 
            IEventCreateOptions __RPC_FAR * This,
            /* [in] */ DISPID dispIdMember,
            /* [in] */ REFIID riid,
            /* [in] */ LCID lcid,
            /* [in] */ WORD wFlags,
            /* [out][in] */ DISPPARAMS __RPC_FAR *pDispParams,
            /* [out] */ VARIANT __RPC_FAR *pVarResult,
            /* [out] */ EXCEPINFO __RPC_FAR *pExcepInfo,
            /* [out] */ UINT __RPC_FAR *puArgErr);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *CreateBindCtx )( 
            IEventCreateOptions __RPC_FAR * This,
            /* [in] */ DWORD dwReserved,
            /* [out] */ IBindCtx __RPC_FAR *__RPC_FAR *ppBindCtx);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *MkParseDisplayName )( 
            IEventCreateOptions __RPC_FAR * This,
            /* [in] */ IBindCtx __RPC_FAR *pBindCtx,
            /* [in] */ LPCOLESTR pszUserName,
            /* [out] */ ULONG __RPC_FAR *pchEaten,
            /* [out] */ LPMONIKER __RPC_FAR *ppMoniker);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *BindToObject )( 
            IEventCreateOptions __RPC_FAR * This,
            /* [in] */ IMoniker __RPC_FAR *pMoniker,
            /* [in] */ IBindCtx __RPC_FAR *pBindCtx,
            /* [in] */ IMoniker __RPC_FAR *pmkLeft,
            /* [in] */ REFIID riidResult,
            /* [iid_is][out] */ LPVOID __RPC_FAR *ppvResult);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *CoCreateInstance )( 
            IEventCreateOptions __RPC_FAR * This,
            /* [in] */ REFCLSID rclsidDesired,
            /* [in] */ IUnknown __RPC_FAR *pUnkOuter,
            /* [in] */ DWORD dwClsCtx,
            /* [in] */ REFIID riidResult,
            /* [iid_is][out] */ LPVOID __RPC_FAR *ppvResult);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *Init )( 
            IEventCreateOptions __RPC_FAR * This,
            /* [in] */ REFIID riidObject,
            /* [iid_is][out][in] */ IUnknown __RPC_FAR *__RPC_FAR *ppUnkObject,
            /* [unique][in] */ IEventBinding __RPC_FAR *pBinding,
            /* [unique][in] */ IUnknown __RPC_FAR *pInitProps);
        
        END_INTERFACE
    } IEventCreateOptionsVtbl;

    interface IEventCreateOptions
    {
        CONST_VTBL struct IEventCreateOptionsVtbl __RPC_FAR *lpVtbl;
    };

    

#ifdef COBJMACROS


#define IEventCreateOptions_QueryInterface(This,riid,ppvObject)	\
    (This)->lpVtbl -> QueryInterface(This,riid,ppvObject)

#define IEventCreateOptions_AddRef(This)	\
    (This)->lpVtbl -> AddRef(This)

#define IEventCreateOptions_Release(This)	\
    (This)->lpVtbl -> Release(This)


#define IEventCreateOptions_GetTypeInfoCount(This,pctinfo)	\
    (This)->lpVtbl -> GetTypeInfoCount(This,pctinfo)

#define IEventCreateOptions_GetTypeInfo(This,iTInfo,lcid,ppTInfo)	\
    (This)->lpVtbl -> GetTypeInfo(This,iTInfo,lcid,ppTInfo)

#define IEventCreateOptions_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)	\
    (This)->lpVtbl -> GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)

#define IEventCreateOptions_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)	\
    (This)->lpVtbl -> Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)



#define IEventCreateOptions_CreateBindCtx(This,dwReserved,ppBindCtx)	\
    (This)->lpVtbl -> CreateBindCtx(This,dwReserved,ppBindCtx)

#define IEventCreateOptions_MkParseDisplayName(This,pBindCtx,pszUserName,pchEaten,ppMoniker)	\
    (This)->lpVtbl -> MkParseDisplayName(This,pBindCtx,pszUserName,pchEaten,ppMoniker)

#define IEventCreateOptions_BindToObject(This,pMoniker,pBindCtx,pmkLeft,riidResult,ppvResult)	\
    (This)->lpVtbl -> BindToObject(This,pMoniker,pBindCtx,pmkLeft,riidResult,ppvResult)

#define IEventCreateOptions_CoCreateInstance(This,rclsidDesired,pUnkOuter,dwClsCtx,riidResult,ppvResult)	\
    (This)->lpVtbl -> CoCreateInstance(This,rclsidDesired,pUnkOuter,dwClsCtx,riidResult,ppvResult)

#define IEventCreateOptions_Init(This,riidObject,ppUnkObject,pBinding,pInitProps)	\
    (This)->lpVtbl -> Init(This,riidObject,ppUnkObject,pBinding,pInitProps)

#endif /* COBJMACROS */


#endif 	/* C style interface */



/* [helpstring] */ HRESULT STDMETHODCALLTYPE IEventCreateOptions_CreateBindCtx_Proxy( 
    IEventCreateOptions __RPC_FAR * This,
    /* [in] */ DWORD dwReserved,
    /* [out] */ IBindCtx __RPC_FAR *__RPC_FAR *ppBindCtx);


void __RPC_STUB IEventCreateOptions_CreateBindCtx_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IEventCreateOptions_MkParseDisplayName_Proxy( 
    IEventCreateOptions __RPC_FAR * This,
    /* [in] */ IBindCtx __RPC_FAR *pBindCtx,
    /* [in] */ LPCOLESTR pszUserName,
    /* [out] */ ULONG __RPC_FAR *pchEaten,
    /* [out] */ LPMONIKER __RPC_FAR *ppMoniker);


void __RPC_STUB IEventCreateOptions_MkParseDisplayName_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IEventCreateOptions_BindToObject_Proxy( 
    IEventCreateOptions __RPC_FAR * This,
    /* [in] */ IMoniker __RPC_FAR *pMoniker,
    /* [in] */ IBindCtx __RPC_FAR *pBindCtx,
    /* [in] */ IMoniker __RPC_FAR *pmkLeft,
    /* [in] */ REFIID riidResult,
    /* [iid_is][out] */ LPVOID __RPC_FAR *ppvResult);


void __RPC_STUB IEventCreateOptions_BindToObject_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IEventCreateOptions_CoCreateInstance_Proxy( 
    IEventCreateOptions __RPC_FAR * This,
    /* [in] */ REFCLSID rclsidDesired,
    /* [in] */ IUnknown __RPC_FAR *pUnkOuter,
    /* [in] */ DWORD dwClsCtx,
    /* [in] */ REFIID riidResult,
    /* [iid_is][out] */ LPVOID __RPC_FAR *ppvResult);


void __RPC_STUB IEventCreateOptions_CoCreateInstance_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);


/* [helpstring] */ HRESULT STDMETHODCALLTYPE IEventCreateOptions_Init_Proxy( 
    IEventCreateOptions __RPC_FAR * This,
    /* [in] */ REFIID riidObject,
    /* [iid_is][out][in] */ IUnknown __RPC_FAR *__RPC_FAR *ppUnkObject,
    /* [unique][in] */ IEventBinding __RPC_FAR *pBinding,
    /* [unique][in] */ IUnknown __RPC_FAR *pInitProps);


void __RPC_STUB IEventCreateOptions_Init_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);



#endif 	/* __IEventCreateOptions_INTERFACE_DEFINED__ */


#ifndef __IEventDispatcherChain_INTERFACE_DEFINED__
#define __IEventDispatcherChain_INTERFACE_DEFINED__

/* interface IEventDispatcherChain */
/* [uuid][unique][object][hidden][helpstring] */ 


EXTERN_C const IID IID_IEventDispatcherChain;

#if defined(__cplusplus) && !defined(CINTERFACE)
    
    MIDL_INTERFACE("58a90754-fb15-11d1-a00c-00c04fa37348")
    IEventDispatcherChain : public IUnknown
    {
    public:
        virtual /* [helpstring] */ HRESULT STDMETHODCALLTYPE SetPrevious( 
            /* [in] */ IUnknown __RPC_FAR *pUnkPrevious,
            /* [out] */ IUnknown __RPC_FAR *__RPC_FAR *ppUnkPreload) = 0;
        
    };
    
#else 	/* C style interface */

    typedef struct IEventDispatcherChainVtbl
    {
        BEGIN_INTERFACE
        
        HRESULT ( STDMETHODCALLTYPE __RPC_FAR *QueryInterface )( 
            IEventDispatcherChain __RPC_FAR * This,
            /* [in] */ REFIID riid,
            /* [iid_is][out] */ void __RPC_FAR *__RPC_FAR *ppvObject);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *AddRef )( 
            IEventDispatcherChain __RPC_FAR * This);
        
        ULONG ( STDMETHODCALLTYPE __RPC_FAR *Release )( 
            IEventDispatcherChain __RPC_FAR * This);
        
        /* [helpstring] */ HRESULT ( STDMETHODCALLTYPE __RPC_FAR *SetPrevious )( 
            IEventDispatcherChain __RPC_FAR * This,
            /* [in] */ IUnknown __RPC_FAR *pUnkPrevious,
            /* [out] */ IUnknown __RPC_FAR *__RPC_FAR *ppUnkPreload);
        
        END_INTERFACE
    } IEventDispatcherChainVtbl;

    interface IEventDispatcherChain
    {
        CONST_VTBL struct IEventDispatcherChainVtbl __RPC_FAR *lpVtbl;
    };

    

#ifdef COBJMACROS


#define IEventDispatcherChain_QueryInterface(This,riid,ppvObject)	\
    (This)->lpVtbl -> QueryInterface(This,riid,ppvObject)

#define IEventDispatcherChain_AddRef(This)	\
    (This)->lpVtbl -> AddRef(This)

#define IEventDispatcherChain_Release(This)	\
    (This)->lpVtbl -> Release(This)


#define IEventDispatcherChain_SetPrevious(This,pUnkPrevious,ppUnkPreload)	\
    (This)->lpVtbl -> SetPrevious(This,pUnkPrevious,ppUnkPreload)

#endif /* COBJMACROS */


#endif 	/* C style interface */



/* [helpstring] */ HRESULT STDMETHODCALLTYPE IEventDispatcherChain_SetPrevious_Proxy( 
    IEventDispatcherChain __RPC_FAR * This,
    /* [in] */ IUnknown __RPC_FAR *pUnkPrevious,
    /* [out] */ IUnknown __RPC_FAR *__RPC_FAR *ppUnkPreload);


void __RPC_STUB IEventDispatcherChain_SetPrevious_Stub(
    IRpcStubBuffer *This,
    IRpcChannelBuffer *_pRpcChannelBuffer,
    PRPC_MESSAGE _pRpcMessage,
    DWORD *_pdwStubPhase);



#endif 	/* __IEventDispatcherChain_INTERFACE_DEFINED__ */



#ifndef __SEOLib_LIBRARY_DEFINED__
#define __SEOLib_LIBRARY_DEFINED__

/* library SEOLib */
/* [version][uuid][helpstring] */ 








































#define	SEO_S_MOREDATA	( 0x41001 )

#define	SEO_E_NOTPRESENT	( 0x80041002 )

#define	SEO_E_TIMEOUT	( 0x80041003 )

#define	SEO_S_DONEPROCESSING	( 0x80041004 )

#define	EVENTS_E_BADDATA	( 0x80041005 )

#define	EVENTS_E_TIMEOUT	( 0x80041006 )

#define	EVENTS_E_DISABLED	( 0x80041007 )


EXTERN_C const IID LIBID_SEOLib;

EXTERN_C const CLSID CLSID_CSEORegDictionary;

#ifdef __cplusplus

class DECLSPEC_UUID("c4df0040-2d33-11d0-a9cf-00aa00685c74")
CSEORegDictionary;
#endif

EXTERN_C const CLSID CLSID_CSEOMimeDictionary;

#ifdef __cplusplus

class DECLSPEC_UUID("c4df0041-2d33-11d0-a9cf-00aa00685c74")
CSEOMimeDictionary;
#endif

EXTERN_C const CLSID CLSID_CSEOMemDictionary;

#ifdef __cplusplus

class DECLSPEC_UUID("c4df0042-2d33-11d0-a9cf-00aa00685c74")
CSEOMemDictionary;
#endif

EXTERN_C const CLSID CLSID_CSEOMetaDictionary;

#ifdef __cplusplus

class DECLSPEC_UUID("c4df0043-2d33-11d0-a9cf-00aa00685c74")
CSEOMetaDictionary;
#endif

EXTERN_C const CLSID CLSID_CSEODictionaryItem;

#ifdef __cplusplus

class DECLSPEC_UUID("2e3a0ec0-89d7-11d0-a9e6-00aa00685c74")
CSEODictionaryItem;
#endif

EXTERN_C const CLSID CLSID_CSEORouter;

#ifdef __cplusplus

class DECLSPEC_UUID("83d63730-94fd-11d0-a9e8-00aa00685c74")
CSEORouter;
#endif

EXTERN_C const CLSID CLSID_CEventLock;

#ifdef __cplusplus

class DECLSPEC_UUID("2e3abb30-af88-11d0-a9eb-00aa00685c74")
CEventLock;
#endif

EXTERN_C const CLSID CLSID_CSEOStream;

#ifdef __cplusplus

class DECLSPEC_UUID("ed1343b0-a8a6-11d0-a9ea-00aa00685c74")
CSEOStream;
#endif

EXTERN_C const CLSID CLSID_CEventManager;

#ifdef __cplusplus

class DECLSPEC_UUID("35172920-a700-11d0-a9ea-00aa00685c74")
CEventManager;
#endif

EXTERN_C const CLSID CLSID_CEventBindingManager;

#ifdef __cplusplus

class DECLSPEC_UUID("53d01080-af98-11d0-a9eb-00aa00685c74")
CEventBindingManager;
#endif

EXTERN_C const CLSID CLSID_CSEOGenericMoniker;

#ifdef __cplusplus

class DECLSPEC_UUID("7e3bf330-b28e-11d0-8bd8-00c04fd42e37")
CSEOGenericMoniker;
#endif

EXTERN_C const CLSID CLSID_CEventMetabaseDatabaseManager;

#ifdef __cplusplus

class DECLSPEC_UUID("8a58cdc0-cbdc-11d0-a9f8-00aa00685c74")
CEventMetabaseDatabaseManager;
#endif

EXTERN_C const CLSID CLSID_CEventUtil;

#ifdef __cplusplus

class DECLSPEC_UUID("a1e041d0-cd73-11d0-a9f8-00aa00685c74")
CEventUtil;
#endif

EXTERN_C const CLSID CLSID_CEventComCat;

#ifdef __cplusplus

class DECLSPEC_UUID("ae1ef300-cd8f-11d0-a9f8-00aa00685c74")
CEventComCat;
#endif

EXTERN_C const CLSID CLSID_CEventRouter;

#ifdef __cplusplus

class DECLSPEC_UUID("9f82f020-f6fd-11d0-aa14-00aa006bc80b")
CEventRouter;
#endif
#endif /* __SEOLib_LIBRARY_DEFINED__ */

/* interface __MIDL_itf_Seo_0349 */
/* [local] */ 

SEODLLDEF HRESULT STDAPICALLTYPE MCISInitSEOA(       LPCSTR pszService,
                                                                     DWORD dwVirtualServer,
                                                                     ISEORouter **pprouterResult);
SEODLLDEF HRESULT STDAPICALLTYPE MCISInitSEOW(       LPCWSTR pszService,
                                                                     DWORD dwVirtualServer,
                                                                     ISEORouter **pprouterResult);
SEODLLDEF HRESULT STDAPICALLTYPE SEOCreateDictionaryFromMultiSzA(    DWORD dwCount,
                                                                                                             LPCSTR *ppszNames,
                                                                                                             LPCSTR *ppszValues,
                                                                                                             BOOL bCopy,
                                                                                                             BOOL bReadOnly,
                                                                                                             ISEODictionary **ppdictResult);
SEODLLDEF HRESULT STDAPICALLTYPE SEOCreateDictionaryFromMultiSzW(    DWORD dwCount,
                                                                                                             LPCWSTR *ppszNames,
                                                                                                             LPCWSTR *ppszValues,
                                                                                                             BOOL bCopy,
                                                                                                             BOOL bReadOnly,
                                                                                                             ISEODictionary **ppdictResult);
SEODLLDEF HRESULT STDAPICALLTYPE SEOCreateMultiSzFromDictionaryA(    ISEODictionary *pdictDictionary,
                                                                                                             DWORD *pdwCount,
                                                                                                             LPSTR **pppszNames,
                                                                                                             LPSTR **pppszValues);
SEODLLDEF HRESULT STDAPICALLTYPE SEOCreateMultiSzFromDictionaryW(    ISEODictionary *pdictDictionary,
                                                                                                             DWORD *pdwCount,
                                                                                                             LPWSTR **pppszNames,
                                                                                                             LPWSTR **pppszValues);
SEODLLDEF HRESULT STDAPICALLTYPE MCISGetBindingInMetabaseA(  LPCSTR pszService,
                                                                                             DWORD dwVirtualServer,
                                                                                             REFGUID guidEventSource,
                                                                                             LPCSTR pszBinding,
                                                                                             BOOL bCreate,
                                                                                             BOOL fLock,
                                                                                             ISEODictionary **ppdictResult);
SEODLLDEF HRESULT STDAPICALLTYPE MCISGetBindingInMetabaseW(  LPCWSTR pszService,
                                                                                             DWORD dwVirtualServer,
                                                                                             REFGUID guidEventSource,
                                                                                             LPCWSTR pszBinding,
                                                                                             BOOL bCreate,
                                                                                             BOOL fLock,
                                                                                             ISEODictionary **ppdictResult);
SEODLLDEF HRESULT STDAPICALLTYPE SEOListenForEvent(  ISEORouter *piRouter,
                                                                             HANDLE hEvent,
                                                                             ISEOEventSink *psinkEventSink,
                                                                             BOOL bOnce,
                                                                             DWORD *pdwListenHandle);
SEODLLDEF HRESULT STDAPICALLTYPE SEOCancelListenForEvent(    DWORD dwHandle);
SEODLLDEF HRESULT STDAPICALLTYPE SEOCreateIStreamFromFileA(  HANDLE hFile,
                                                                                             LPCSTR pszFile,
                                                                                             IStream **ppstreamResult);
SEODLLDEF HRESULT STDAPICALLTYPE SEOCreateIStreamFromFileW(  HANDLE hFile,
                                                                                             LPCWSTR pszFile,
                                                                                             IStream **ppstreamResult);
SEODLLDEF HRESULT STDAPICALLTYPE SEOCopyDictionary(  ISEODictionary *pdictIn, ISEODictionary **ppdictResult);
SEODLLDEF HRESULT STDAPICALLTYPE SEOCreateDictionaryFromIStream(     IStream *pstreamIn, ISEODictionary **ppdictResult);
SEODLLDEF HRESULT STDAPICALLTYPE SEOWriteDictionaryToIStream(        ISEODictionary *pdictIn, IStream *pstreamOut);


extern RPC_IF_HANDLE __MIDL_itf_Seo_0349_v0_0_c_ifspec;
extern RPC_IF_HANDLE __MIDL_itf_Seo_0349_v0_0_s_ifspec;

/* Additional Prototypes for ALL interfaces */

unsigned long             __RPC_USER  BSTR_UserSize(     unsigned long __RPC_FAR *, unsigned long            , BSTR __RPC_FAR * ); 
unsigned char __RPC_FAR * __RPC_USER  BSTR_UserMarshal(  unsigned long __RPC_FAR *, unsigned char __RPC_FAR *, BSTR __RPC_FAR * ); 
unsigned char __RPC_FAR * __RPC_USER  BSTR_UserUnmarshal(unsigned long __RPC_FAR *, unsigned char __RPC_FAR *, BSTR __RPC_FAR * ); 
void                      __RPC_USER  BSTR_UserFree(     unsigned long __RPC_FAR *, BSTR __RPC_FAR * ); 

unsigned long             __RPC_USER  LPSAFEARRAY_UserSize(     unsigned long __RPC_FAR *, unsigned long            , LPSAFEARRAY __RPC_FAR * ); 
unsigned char __RPC_FAR * __RPC_USER  LPSAFEARRAY_UserMarshal(  unsigned long __RPC_FAR *, unsigned char __RPC_FAR *, LPSAFEARRAY __RPC_FAR * ); 
unsigned char __RPC_FAR * __RPC_USER  LPSAFEARRAY_UserUnmarshal(unsigned long __RPC_FAR *, unsigned char __RPC_FAR *, LPSAFEARRAY __RPC_FAR * ); 
void                      __RPC_USER  LPSAFEARRAY_UserFree(     unsigned long __RPC_FAR *, LPSAFEARRAY __RPC_FAR * ); 

unsigned long             __RPC_USER  VARIANT_UserSize(     unsigned long __RPC_FAR *, unsigned long            , VARIANT __RPC_FAR * ); 
unsigned char __RPC_FAR * __RPC_USER  VARIANT_UserMarshal(  unsigned long __RPC_FAR *, unsigned char __RPC_FAR *, VARIANT __RPC_FAR * ); 
unsigned char __RPC_FAR * __RPC_USER  VARIANT_UserUnmarshal(unsigned long __RPC_FAR *, unsigned char __RPC_FAR *, VARIANT __RPC_FAR * ); 
void                      __RPC_USER  VARIANT_UserFree(     unsigned long __RPC_FAR *, VARIANT __RPC_FAR * ); 

/* end of Additional Prototypes */

#ifdef __cplusplus
}
#endif

#endif


