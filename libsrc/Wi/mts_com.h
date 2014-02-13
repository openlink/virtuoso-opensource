/*
 *  mts_com.h
 *
 *  $Id$
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
 */

#ifndef _MTS_COM_H
#define _MTS_COM_H

/* #include <Transact.h>
   #include <TxCoord.h>
#include <txdtc.h>
#include <xolehlp.h>
 #include <transact.h> */

/* #include <string>*/
/*#include <memory>*/

extern "C"
{
  /* #include "2pc.h" */
}

#ifdef _MTS_TRACE
#define MTS_TRACE(__what) \
	printf __what

#define MTS_THROW_ASSERT(__HR,__WHAT) \
 if(!SUCCEEDED(__HR))\
 {\
   throw mts_error((__HR),(__WHAT));\
 } else\
   printf("***MTS*** %s passed\n",(__WHAT));


#define MTS_THROW_SQLASSERT(__hr,__hdbc,__str) \
    if ((__hr!=SQL_SUCCESS) && (__hr!=SQL_SUCCESS_WITH_INFO)) \
    {\
	DoSQLError(__hdbc,0);\
        throw mts_error((__hr),(__str));\
    }
#else				/* _MTS_TRACE */
#define MTS_TRACE(__what)
#define MTS_THROW_ASSERT(__HR,__WHAT)\
 if(!SUCCEEDED(__HR))\
 {\
   throw mts_error((__HR),(__WHAT));\
 }
#define MTS_THROW_SQLASSERT(__hr,__hdbc,__str)\
    if ((__hr!=SQL_SUCCESS) && (__hr!=SQL_SUCCESS_WITH_INFO)) \
    {\
	DoSQLError(__hdbc,0);\
        throw mts_error((__hr),(__str));\
    }
#endif				/* _MTS_TRACE */


#define MTS_PREPARE 1
#define MTS_COMMIT 2
#define MTS_ABORT 3

class mts_error
{
protected:HRESULT hr;
  char why[255];
public: mts_error (HRESULT __hr, const char *str):hr (__hr)
  {
    strncpy (why, str, 254);
  };
  HRESULT get_errcode () const
  {
    return hr;
  }
  void dump () const
  {
#ifdef _MTS_TRACE
    printf ("***MTS***assert failed: %s, %x\n", why, hr);
#endif
  }
};

template < class T > class auto_interface
{
protected:
  T * iptr_;
public:
auto_interface (T * iptr):iptr_ (iptr)
  {
  };
auto_interface ():iptr_ (0)
  {
  };
  T *operator-> ()
  {
    return iptr_;
  }
  T *&get ()
  {
    return iptr_;
  }
  const T *operator-> () const
  {
    return iptr_;
  }
  T *release ()
  {
    T *pred = iptr_;
    iptr_ = 0;
    return pred;
  }
  ~auto_interface ()
  {
    if (iptr_)
      iptr_->Release ();
  }
};

template < class T > class auto_dkptr
{
protected:
  T * iptr_;
public:
auto_dkptr (T * iptr):iptr_ (iptr)
  {
  };
auto_dkptr ():iptr_ (0)
  {
  };
  T *operator-> ()
  {
    return iptr_;
  }
  T *&get ()
  {
    return iptr_;
  }
  const T *operator-> () const
  {
    return iptr_;
  }
  T *release ()
  {
    T *tmpptr = iptr_;
    iptr_ = 0;
    return tmpptr;
  }
  ~auto_dkptr ()
  {
    if (iptr_)
      dk_free (iptr_, -1);
  }
};


class CResMgrSink:public IResourceManagerSink
{
  ULONG ref_count;
public:
   CResMgrSink ();
  virtual ULONG STDMETHODCALLTYPE AddRef ();
  virtual ULONG STDMETHODCALLTYPE Release ();
  virtual HRESULT STDMETHODCALLTYPE QueryInterface (const struct _GUID &guid,
      void **iFace);
  virtual HRESULT STDMETHODCALLTYPE TMDown ();
};

class CTransactResourceAsync:public ITransactionResourceAsync
{
  ULONG ref_count;
  ITransactionEnlistmentAsync *trx_enlistment_;
  void *client_connection_;
public:
   CTransactResourceAsync ();
  ITransactionEnlistmentAsync *get_enlistment ()
  {
    return trx_enlistment_;
  };
  void *operator  new (size_t sz);
  void operator  delete (void *);
  void *get_connection ()
  {
    return client_connection_;
  };

  virtual void SetEnlistment (ITransactionEnlistmentAsync * trxea);
  virtual void SetConnection (void *client_connection);
  virtual ULONG STDMETHODCALLTYPE AddRef ();
  virtual ULONG STDMETHODCALLTYPE Release ();
  virtual HRESULT STDMETHODCALLTYPE QueryInterface (const struct _GUID &guid,
      void **iFace);
  virtual HRESULT STDMETHODCALLTYPE PrepareRequest (
      /* [in] */ BOOL fRetaining,
      /* [in] */ DWORD grfRM,
      /* [in] */ BOOL fWantMoniker,
      /* [in] */ BOOL fSinglePhase);
  virtual HRESULT STDMETHODCALLTYPE CommitRequest (
      /* [in] */ DWORD grfRM,
      /* [in] */ XACTUOW __RPC_FAR * pNewUOW);
  virtual HRESULT STDMETHODCALLTYPE AbortRequest (
      /* [in] */ BOID __RPC_FAR * pboidReason,
      /* [in] */ BOOL fRetaining,
      /* [in] */ XACTUOW __RPC_FAR * pNewUOW);
  virtual HRESULT STDMETHODCALLTYPE TMDown (void);
};

unsigned long mts_prepare_done (void *res, int trx_status);
unsigned long mts_commit_done (void *res, int trx_status);
unsigned long mts_abort_done (void *res, int trx_status);
unsigned long mts_prepare_set_log (tp_message_t * mm);

#ifdef _MTS_TRACE
#define mts_log_debug(x) log_debug x
#else
#define mts_log_debug(x)
#endif
int log_debug (char *format, ...);

#endif /* _MTS_COM_H */
