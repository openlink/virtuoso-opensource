/*
 *  maildrop.cpp
 *
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2012 OpenLink Software
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
 */

#include <libutil.h>
#include <util/mpl.h>

/* Swell - FAILED is redefined in Dkernel.h - restore value from winerror.h */
#undef FAILED
#define FAILED(Status) ((HRESULT)(Status)<0)

#include <atlbase.h>
extern CComModule _Module;
#include <atlcom.h>
#include "maildrop.h"
#include "mailmsg.h"
#include "mailmsgprops.h"
#include "smtpevent.h"
#include "seo.h"
#define SMTPINITGUID
#include <smtpguid.h>

#if _MSC_VER < 1400
/* Nasty - workaround for buggy vc7 */
typedef enum __MIDL___MIDL_itf_msado15_0000_0013 PositionEnum;
#import "msado15.tlb" raw_interfaces_only, raw_native_types, no_namespace, named_guids
#endif
#import "CDOSys.Tlb" raw_interfaces_only, raw_native_types, no_namespace, named_guids

#include "sysexits.h"

class ATL_NO_VTABLE CMailDrop :
  public CComObjectRootEx<CComMultiThreadModel>,
  public CComCoClass<CMailDrop, &CLSID_MailDrop>,
  public IDispatchImpl<IMailDrop, &IID_IMailDrop, &LIBID_OpenLink>,
  public IDispatchImpl<ISMTPOnArrival, &IID_ISMTPOnArrival, &LIBID_CDO>,
  public IDispatchImpl<INNTPOnPost, &IID_INNTPOnPost, &LIBID_CDO>,
  public IEventIsCacheable,
  public IPersistPropertyBag
{
public:
  CMailDrop() : g_szCommand (NULL), g_bBounceBadMail (FALSE)
  {
  }

  ~CMailDrop()
  {
    if (g_szCommand)
      free (g_szCommand);
  }

  DECLARE_REGISTRY_RESOURCEID(2)

//DECLARE_NOT_AGGREGATABLE(CMailDrop)

  DECLARE_PROTECT_FINAL_CONSTRUCT()

  BEGIN_COM_MAP(CMailDrop)
    COM_INTERFACE_ENTRY(IMailDrop)
    COM_INTERFACE_ENTRY(ISMTPOnArrival)
    COM_INTERFACE_ENTRY(INNTPOnPost)
    COM_INTERFACE_ENTRY(IEventIsCacheable)
    COM_INTERFACE_ENTRY(IPersistPropertyBag)
    COM_INTERFACE_ENTRY2(IDispatch, IMailDrop)
  END_COM_MAP()

  /*
  ** IEventIsCacheable
  */
  STDMETHOD (IsCacheable) (void) { return S_OK; }

  /*
  ** IPersistPropertyBag : IPersist
  */
  STDMETHOD (GetClassID) (CLSID *pClassID);
  STDMETHOD (InitNew) (void);
  STDMETHOD (Load) (IPropertyBag* pBag,IErrorLog *pErrorLog);
  STDMETHOD (Save) (IPropertyBag *pPropBag, BOOL fClearDirty,
	  BOOL fSaveAllProperties);

  /*
  ** ISMTPOnArrival
  */
  STDMETHOD (OnArrival) (IMessage *pMsg, CdoEventStatus *EventStatus);

  /*
  ** INNTPOnPost
  */
  STDMETHOD (OnPost) (IMessage * pMsg, CdoEventStatus * EventStatus);

private:
  LPSTR g_szCommand;
  BOOL g_bBounceBadMail;
};


/* I/O block size */
#ifdef DEBUG
#define BLKSIZE		512
#else
#define BLKSIZE		4096
#endif

/* Time to wait for child to closes it's stdout */
#define PCLOSETIMEOUT	5 * 60 * 1000

/* Time to wait for child after it closes it's stdout */
#define PWAITTIMEOUT	1 * 60 * 1000

/* Debugging */
#ifdef DEBUG
# define DEBUG0(X)	fprintf (debugFd, X)
# define DEBUG1(X,Y)	fprintf (debugFd, X, Y)
#else
# define DEBUG0(X)
# define DEBUG1(X,Y)
#endif


/* Recipient array entry */
struct RECIPIENT
  {
    LPSTR szRecipient;
    BOOL bDelivered;
  };

/* Reader thread context */
struct THRCTX
  {
    HANDLE hRd;
    HANDLE hSem;
    BOOL bFailed;
    MPL pool;
  };


/*
 *  Convert wide char string to ansi string
 */
static LPSTR
wstr_to_cstr (LPCWSTR wStr)
{
  LPSTR mbstr;
  INT len;

  if (wStr == NULL)
    return NULL;

  len = WideCharToMultiByte (CP_ACP, 0, wStr, -1, NULL, 0, NULL, NULL);

  if ((mbstr = (LPSTR) malloc (len)) == NULL)
    return NULL;

  WideCharToMultiByte (CP_ACP, 0, wStr, -1, mbstr, len, NULL, NULL);

  return mbstr;
}


/*
 *  Convert ansi string to wide char string
 */
static LPWSTR
cstr_to_wstr (LPCSTR szStr)
{
  LPWSTR wStr;
  INT len;

  if (szStr == NULL)
    return NULL;

  len = MultiByteToWideChar (CP_ACP, MB_PRECOMPOSED, szStr, -1, NULL, 0);
  wStr = (LPWSTR) malloc (len * sizeof (WCHAR));
  len = MultiByteToWideChar (CP_ACP, MB_PRECOMPOSED, szStr, -1, wStr, len);
  return wStr;
}


/*
 *  Convert ansi string to BSTR
 *  This is a wide char string, but placed in special memory
 */
static BSTR
cstr_to_bstr (LPCSTR szStr)
{
  LPWSTR wStr;
  BSTR retStr;

  if ((wStr = cstr_to_wstr (szStr)) == NULL)
    return NULL;

  retStr = SysAllocString (wStr);
  free (wStr);

  return retStr;
}


static DWORD WINAPI
ReaderThread (LPVOID arg)
{
  THRCTX *pCtx = (THRCTX *) arg;
  HANDLE hWr = GetStdHandle (STD_OUTPUT_HANDLE);
  BYTE buffer[8192];
  DWORD dwRead;

  /* Tell main thread we're all set */
  ReleaseSemaphore (pCtx->hSem, 1, NULL);

  /* Collect data from child */
  while (ReadFile (pCtx->hRd, buffer, sizeof (buffer), &dwRead, NULL))
    {
      mpl_grow (&pCtx->pool, (memptr_t) buffer, (memsz_t) dwRead);
    }

  pCtx->bFailed = (GetLastError () != ERROR_BROKEN_PIPE);
  CloseHandle (pCtx->hRd);

  /* Tell main thread we're dead meat */
  ReleaseSemaphore (pCtx->hSem, 1, NULL);
  return 0;
}


static int
EnvSorter (const void *p1, const void *p2)
{
  char **s1 = (char **) p1;
  char **s2 = (char **) p2;
  return _stricmp (*s1, *s2);
}


/*
 *  Delivers a message through a pipe
 */
void
DeliverPipe (
    LPSTR szCmd,	/* [in] Command to run */
    LPSTR szSender,	/* [in] Envelope Sender (MAIL FROM) */
    LPSTR szRecipient,	/* [in] Envelope Recipient (RCPT TO) */
    _Stream *pStream,	/* [in] Message stream */
    DWORD *pdwExitCode,	/* [out] exit code from sysexits.h */
    BSTR *bErrors,	/* [out,optional] failure text */
    FILE *debugFd)	/* [in,optional] debug output stream */
{
  PROCESS_INFORMATION processInformation;
  SECURITY_ATTRIBUTES attr;
  STARTUPINFO startupInfo;
  HANDLE hRd[2], hWr[2];
  HANDLE hProc;
  HANDLE hDup;
  DWORD dwThrId;
  THRCTX thrCtx;
  BOOL bFailed;
  BOOL bKillIt;
  void *envbuf;
  size_t envlen;
  int envcnt;
  char **saveenv;
  char **env;
  int i;
  char *s;

  *bErrors = NULL;

  /* Save old environment */
  saveenv = environ;
  environ = NULL;

  /* New environment strings */
  make_env ("SENDER", szSender);
  make_env ("RECIPIENT", szRecipient);
  char *at = strchr (szRecipient, '@');
  if (at)
    {
      *at = 0;
      make_env ("LOCAL", szRecipient);
      make_env ("HOST", at + 1);
      *at = '@';
    }
  else
    {
      make_env ("LOCAL", szRecipient);
      make_env ("HOST", "localhost");
    }

  /* Convert environ vector into windows code */
  if (saveenv)
    {
      for (i = 0; saveenv[i]; i++)
	{
	  if ((s = strchr (saveenv[i], '=')) != NULL)
	    {
	      *s = 0;
	      make_env (saveenv[i], s + 1);
	      *s = '=';
	    }
	}
    }

  env = environ;
  if (env != NULL)
    {
      envlen = 1;
      for (envcnt = 0; env[envcnt]; envcnt++)
        envlen += strlen (env[envcnt]) + 1;

      /* Windows expects a sorted environment (ugh) */
      qsort (env, envcnt, sizeof (char *), EnvSorter);

      envbuf = malloc (envlen);
      if (envbuf)
        {
	  char *envptr = (char *) envbuf;
          for (envcnt = 0; env[envcnt]; envcnt++)
	    envptr = stpcpy (envptr, env[envcnt]) + 1;
	  *envptr = 0;
	}
    }
  else
    envbuf = NULL;

  /* Security descriptor that grants inheritance */
  attr.lpSecurityDescriptor = NULL;
  attr.nLength = sizeof (attr);
  attr.bInheritHandle = TRUE;

  /* Child I/O pipes */
  if (!CreatePipe (&hRd[0], &hRd[1], &attr, 0) ||
      !CreatePipe (&hWr[0], &hWr[1], &attr, 0))
    return;

  /* Make our sides of the pipes not inheritable */
  hProc = GetCurrentProcess ();
  DuplicateHandle (hProc, hRd[1], hProc, &hDup, 0, FALSE,
      DUPLICATE_SAME_ACCESS);
  CloseHandle (hRd[1]);
  hRd[1] = hDup;

  DuplicateHandle (hProc, hWr[0], hProc, &hDup, 0, FALSE,
      DUPLICATE_SAME_ACCESS);
  CloseHandle (hWr[0]);
  hWr[0] = hDup;

  /* Set startup info */
  memset (&startupInfo, 0, sizeof (startupInfo));
  startupInfo.cb = sizeof (startupInfo);
  startupInfo.dwFlags = STARTF_USESTDHANDLES;
  startupInfo.hStdInput = hRd[0];
  startupInfo.hStdOutput = hWr[1];
  startupInfo.hStdError = hWr[1];

  memset (&processInformation, 0, sizeof (processInformation));

  bKillIt = FALSE;
  bFailed = !CreateProcess (
      szCmd,			// application name
      szCmd,			// command line
      NULL,			// security attributes
      NULL,			// thread attributes
      TRUE,			// inherit handles
      0,
      envbuf,			// environment
      NULL,			// current directory
      &startupInfo,
      &processInformation);

  if (envbuf)
    free (envbuf);
  if (env)
    {
      for (i = 0; env[i]; i++)
	free (env[i]);
      free (env);
    }
  environ = saveenv;

  /* unix wisdom holds here */
  CloseHandle (hRd[0]);
  CloseHandle (hWr[1]);

  /* Check for CreateProcess failure */
  if (bFailed)
    {
      CloseHandle (hRd[1]);
      CloseHandle (hWr[0]);
      *pdwExitCode = EX_UNAVAILABLE;
      *bErrors = cstr_to_bstr ("Unable to spawn the delivery process\n");
      return;
    }

  /* Set up reader thread */
  thrCtx.bFailed = FALSE;
  thrCtx.hSem = CreateSemaphore (NULL, 0, 2, NULL);
  thrCtx.hRd = hWr[0];
  mpl_init (&thrCtx.pool);

  /* Create & wait till reader thread is ready */
  CreateThread (NULL, 0, ReaderThread, (LPVOID) &thrCtx, 0, &dwThrId);
  if (WaitForSingleObject (thrCtx.hSem, 5000) != WAIT_OBJECT_0)
    {
      DEBUG1 ("THREAD FAILED %d\n", GetLastError ());
      bFailed = TRUE;
      CloseHandle (thrCtx.hRd); /* paranoia? */
    }
  else
    {
      char mbstr[2 * (BLKSIZE + 1)];
      BSTR bData;
      DWORD dwWritten;
      ADO_LONGPTR nBytes;
      ADO_LONGPTR nRemain;
      HRESULT hr;

      nRemain = 0;
      hr = pStream->get_Size (&nRemain);
      DEBUG1 ("SIZE %d\n", (int) nRemain);
      pStream->put_Position (0);
      while (nRemain > 0)
	{
	  nBytes = nRemain > BLKSIZE ? BLKSIZE : nRemain;
	  hr = pStream->ReadText ((long) nBytes, &bData);
	  if (FAILED (hr))
	    break;

	  /* Ok, this MIGHT fail when IETF adopts unicode mail :-) */
	  bData[nBytes] = 0;
	  WideCharToMultiByte (CP_ACP, 0,
	      bData, (int) (nBytes + 1),
	      mbstr, sizeof (mbstr),
	      NULL, NULL);
	  SysFreeString (bData);
	  nRemain -= nBytes;

	  nBytes = strlen (mbstr); // REALLY necessary?
	  if (!WriteFile (hRd[1], mbstr, (DWORD) nBytes, &dwWritten, NULL) ||
	      dwWritten != (DWORD) nBytes)
	    {
	      /* Check for "The pipe is being closed" */
	      if ((bFailed = (GetLastError () != ERROR_NO_DATA)))
		CloseHandle (thrCtx.hRd);
	      break;
	    }
	}
      if (FAILED (hr))
	{
	  bFailed = TRUE;
	  CloseHandle (thrCtx.hRd);
	}
    }

  /* Done sending, shutdown pipe */
  CloseHandle (hRd[1]);

  /* Wait for child to close the pipe */
  if (WaitForSingleObject (thrCtx.hSem, PCLOSETIMEOUT) != WAIT_OBJECT_0)
    {
      DEBUG1 ("THREAD2 FAILED %d\n", GetLastError ());
      bKillIt = TRUE;
    }
  /* Wait for child to exit */
  else if (WaitForSingleObject (processInformation.hProcess,
	PWAITTIMEOUT) != WAIT_OBJECT_0)
    {
      DEBUG1 ("CHILDWAIT FAILED %d\n", GetLastError ());
      bKillIt = TRUE;
    }
  /* Get it's exit code */
  else if (!GetExitCodeProcess (processInformation.hProcess, pdwExitCode))
    bKillIt = TRUE;

  /* Who wants to live forever? */
  if (bKillIt)
    {
      TerminateProcess (processInformation.hProcess, 1);
      bFailed = TRUE;
    }

  DEBUG1 ("Failed %d\n", bFailed);
  DEBUG1 ("Thread Failed %d\n", thrCtx.bFailed);
  DEBUG1 ("kill it %d\n", bKillIt);

  if (bFailed || thrCtx.bFailed)
    {
      *pdwExitCode = EX_IOERR;
      *bErrors = cstr_to_bstr ("Delivery process timed out\n");
    }
  else
    {
      char *mailMesg;
      int32 mailSize;

      mpl_1grow (&thrCtx.pool, 0);
      mailSize = (int32) mpl_object_size (&thrCtx.pool) - 1;
      mailMesg = (char *) mpl_finish (&thrCtx.pool);

      *bErrors = SysAllocStringLen (NULL, mailSize + 1);
      if (*bErrors)
	MultiByteToWideChar (CP_ACP, MB_PRECOMPOSED,
	    mailMesg, mailSize, *bErrors, mailSize + 1);
    }

  CloseHandle (hRd[1]);
  CloseHandle (hWr[0]);
  CloseHandle (processInformation.hProcess);
  CloseHandle (processInformation.hThread);
  CloseHandle (thrCtx.hSem);
  mpl_destroy (&thrCtx.pool);
}


/* Formulate a reply message */
static HRESULT
PostReplyMsg (IMessage *pMsg, LPCSTR szRecipient, BSTR bErrors, FILE *debugFd)
{
  CComPtr<Fields> pSmtpEnv;
  CComPtr<IMessage> pReplyMsg;
  CComPtr<IBodyPart> pBodyPart;
  CComPtr<IBodyPart> pBodyPart1;
  CComPtr<IBodyPart> pBodyPart2;
  CComPtr<Fields> pFields;
  CComPtr<Field> pFldValue;
  CComPtr<_Stream> ist;
  CComPtr<_Stream> ost;
  CComBSTR bContent;
  CComBSTR bRecipient;
  CComBSTR bBody;
  CComPtr<IConfiguration> pConfig;
  HRESULT hr;

  if (szRecipient == NULL || szRecipient[0] == 0)
    return S_OK;

  /* Create new Message */
  hr = pReplyMsg.CoCreateInstance (CLSID_Message);
  if (FAILED (hr))
    return hr;

  /* Set From: */
  hr = pReplyMsg->put_From (CComBSTR (L"MAILER-DAEMON < >"));
  if (FAILED (hr))
    return hr;

  /* Set To: <return-path value> */
  hr = pMsg->get_EnvelopeFields (&pSmtpEnv);
  if (FAILED (hr))
    return hr;

  hr = pSmtpEnv->get_Item (CComVariant (cdoSenderEmailAddress), &pFldValue);
  if (FAILED (hr))
    return hr;

  CComVariant varValue;
  hr = pFldValue->get_Value (&varValue);
  if (FAILED (hr) || !varValue.bstrVal || varValue.bstrVal[0] == 0)
    return hr;

  hr = pReplyMsg->put_To (varValue.bstrVal);
  if (FAILED (hr))
    return hr;

  /* Set Subject: */
  pReplyMsg->put_Subject (CComBSTR (
      L"Mail delivery failed: returning message to sender"));

  /* Other fields */
  hr = pReplyMsg->get_Fields (&pFields);
  if (FAILED (hr))
    return hr;

  /* set X-Mailer: */
  hr = pFields->get_Item (CComVariant (CComBSTR (cdoXMailer)), &pFldValue);
  if (!FAILED (hr))
    {
      pFldValue->put_Value (CComVariant (
	CComBSTR (L"OpenLink Application Mailer/1.0")));
    }

  /* set X-Failed-recipients: */
  hr = pFields->get_Item (CComVariant (
	CComBSTR (L"urn:schemas:mailheader:x-Failed-recipients")), &pFldValue);
  if (!FAILED (hr))
    {
      bRecipient = cstr_to_bstr (szRecipient);
      pFldValue->put_Value (CComVariant (bRecipient));
    }

  pFields->Update ();

  /*
   *  Now, construct multiparts
   */

  hr = pReplyMsg->get_BodyPart (&pBodyPart);
  if (FAILED (hr))
    return hr;

  hr = pBodyPart->get_Fields (&pFields);
  if (FAILED (hr))
    return hr;

  hr = pFields->get_Item (CComVariant (CComBSTR (cdoContentType)), &pFldValue);
  if (FAILED (hr))
    return hr;

  hr = pFldValue->put_Value (CComVariant (CComBSTR (L"multipart/mixed")));
  if (FAILED (hr))
    return hr;

  hr = pFields->Update ();
  if (FAILED (hr))
    return hr;

  hr = pBodyPart->AddBodyPart (-1, &pBodyPart1);
  if (FAILED (hr))
    return hr;

  ///
  //  part1
  //    Content-Type: text/plain
  //    Content-Transfer-Encoding: 7bit

  hr = pBodyPart1->AddBodyPart (-1, &pBodyPart2);
  if (FAILED (hr))
    return hr;
  hr = pBodyPart2->get_Fields (&pFields);
  if (FAILED (hr))
    return hr;

  /* Content-Type: */
  hr = pFields->get_Item (CComVariant (CComBSTR (cdoContentType)), &pFldValue);
  if (!FAILED (hr))
    hr = pFldValue->put_Value (CComVariant (CComBSTR (L"text/plain")));

  /* Content-Transfer-Encoding: */
  hr = pFields->get_Item (CComVariant (CComBSTR (cdoContentTransferEncoding)),
      &pFldValue);
  if (!FAILED (hr))
    hr = pFldValue->put_Value (CComVariant (CComBSTR (L"7bit")));

  pFields->Update ();

  hr = pBodyPart2->GetDecodedContentStream (&ost);
  if (FAILED (hr))
    return hr;

  bBody =
    L"This message was created automatically by mail delivery software.\n"
    L"\n"
    L"A message that you sent could not be delivered to one or more of its\n"
    L"recipients. This is a permanent error. The following address failed:\n"
    L"\n";

  /* failed recipient here */
  bBody += bRecipient;
  bBody += L"\n";

  /* error output here */
  if (bErrors)
    {
      bBody +=
	  L"\nThe following text was generated during the delivery attempt:\n";
      bBody += bErrors;
    }

  ost->WriteText (bBody, (StreamWriteEnum) 0);
  ost->Flush ();

  ///
  //  part2
  //    Content-Type: text/plain
  //    Content-Transfer-Encoding: 7bit

  hr = pBodyPart1->AddBodyPart (-1, &pBodyPart2);
  if (FAILED (hr))
    return hr;
  hr = pBodyPart2->get_Fields (&pFields);
  if (FAILED (hr))
    return hr;

  /* Content-Type: */
  hr = pFields->get_Item (CComVariant (CComBSTR (cdoContentType)), &pFldValue);
  if (!FAILED (hr))
    hr = pFldValue->put_Value (CComVariant (CComBSTR (L"text/plain")));

  /* Content-Transfer-Encoding: */
  hr = pFields->get_Item (CComVariant (CComBSTR (cdoContentTransferEncoding)),
      &pFldValue);
  if (!FAILED (hr))
    hr = pFldValue->put_Value (CComVariant (CComBSTR (L"7bit")));

  pFields->Update ();

  hr = pMsg->GetStream (&ist);
  if (FAILED (hr))
    return hr;

  hr = pBodyPart2->GetDecodedContentStream (&ost);
  if (FAILED (hr))
    return hr;

  hr = ist->ReadText (-1, &bContent);
  if (FAILED (hr))
    return hr;

  ost->WriteText (bContent, (StreamWriteEnum)0);
  ost->Flush ();

#ifdef DEBUG
  if (debugFd)
    {
      hr = pReplyMsg->GetStream (&ist);
      if (FAILED (hr))
	return hr;

      hr = ist->ReadText (-1, &bContent);
      if (FAILED (hr))
	return hr;

      fprintf (debugFd, "------------ REPLY MESSAGE ----------\n");
      fprintf (debugFd, "%ls\n", bContent);
      fprintf (debugFd, "------------ END REPLY --------------\n");
      fflush (debugFd);
    }
#endif

  hr = pReplyMsg->Send ();
  if (FAILED (hr))
    return hr;

  return hr;
}


#ifdef DEBUG
BOOL dump_core = FALSE;
LPSTR force_core_dump = NULL;
#endif


STDMETHODIMP
CMailDrop::OnArrival (
    IMessage *pMsg,
    CdoEventStatus *EventStatus)
{
  CComPtr<Fields> pSmtpEnv;	/* SMTP Envelope fields collection */
  CComPtr<Field> pFldRecipients;/* SMTP Envelope recipient list field */
  CComPtr<Field> pFldSender;	/* SMTP Envelope sender field */
  CComPtr<Field> pFldMsgStatus;	/* SMTP Envelope message status field */
  CComPtr<Field> pFldDate;	/* SMTP Envelope Date field */
  CComPtr<Field> pFldIP;	/* SMTP Envelope client-ip field */
  CComPtr<_Stream> st;		/* Message reader stream */
  CComBSTR bContent;		/* Actual mail message + headers */
  LPSTR szRecipients = NULL;	/* SMTP Envelope recipient list */
  LPSTR szSender = NULL;	/* SMTP Envelope sender */
  LPSTR szDate = NULL;
  LPSTR szIP = NULL;
  LPSTR szNewRecipients = NULL;	/* Rewritten final recipient list */
  LPSTR szRecipient;		/* tmp for walking for szNewRecipients */
  DWORD dwExitCode;		/* exit code <sysexits.h> for delivery proc */
  HRESULT hr;			/* COM status code */
  LONG msgStatus = -1;		/* Current message status */
  MPL rcpPool;			/* pool with recipient list */
  RECIPIENT tRecipient;		/* tmp for adding recipient to pool */
  RECIPIENT *pRecipients;	/* finished pool with recipients */
  DWORD nRecipients;		/* total # recipients on pool*/
  DWORD i;			/* Temp */
  LPSTR ps;			/* Temp */
  FILE *debugFd = NULL;		/* Debug file */

  mpl_init (&rcpPool);

  if (EventStatus == NULL)
    return E_POINTER;

#ifdef DEBUG
  if ((debugFd = fopen ("c:\\debug.txt", "a")) == NULL)
    return E_POINTER;
#endif

  if (g_szCommand == NULL)
    {
#ifdef DEBUG
      DEBUG0 ("No COMMAND!\n");
#endif
      *EventStatus = cdoRunNextSink;
      hr = S_OK;
      goto failed;
    }

  hr = pMsg->get_EnvelopeFields (&pSmtpEnv);
  if (FAILED (hr))
    goto failed;

  /* Envelope's MessageStatus */
  hr = pSmtpEnv->get_Item (CComVariant (CComBSTR (cdoMessageStatus)),
      &pFldMsgStatus);
  if (!FAILED (hr))
    {
      CComVariant varValue;
      hr = pFldMsgStatus->get_Value (&varValue);
      if (!FAILED (hr))
	msgStatus = varValue.lVal;
    }

  /* Envelope's RecipientList */
  hr = pSmtpEnv->get_Item (CComVariant (cdoRecipientList), &pFldRecipients);
  if (!FAILED (hr))
    {
      CComVariant varValue;
      hr = pFldRecipients->get_Value (&varValue);
      if (!FAILED (hr))
	szRecipients = wstr_to_cstr (varValue.bstrVal);
    }

  /* Envelope's Sender */
  hr = pSmtpEnv->get_Item (CComVariant (cdoSenderEmailAddress), &pFldSender);
  if (!FAILED (hr))
    {
      CComVariant varValue;
      hr = pFldSender->get_Value (&varValue);
      if (!FAILED (hr))
	szSender = wstr_to_cstr (varValue.bstrVal);
    }

#if 0 /* TODO construct the UnixFromLine */
  /* Envelope's Date */
  hr = pSmtpEnv->get_Item (CComVariant (cdoArrivalTime), &pFldDate);
  if (!FAILED (hr) && pFldDate && szSender)
    {
      CComVariant varValue;
      hr = pFldDate->get_Value (&varValue);
      if (!FAILED (hr))
	{
	  ULONG flags = 0;
	  UDATE udate;
	  VarUdateFromDate (varValue.date, flags, &udate);
#ifdef DEBUG
	  const char *szDayNames = "SunMonTueWedThuFriSat";
	  const char *szMonthNames = "JanFebMarAprMayJunJulAugSepOctNovDec";
	  fprintf (debugFd, "From %s %3.3s %3.3s %02u %02u:%02u:%02u %04u\r\n",
	      szSender,
	      szDayNames + 3 * udate.st.wDayOfWeek,
	      szMonthNames + 3 * (udate.st.wMonth - 1), udate.st.wDay,
	      udate.st.wHour, udate.st.wMinute, udate.st.wSecond,
	      udate.st.wYear);
	}
#endif
    }
#endif

#if 0
  /* Envelope's Client IP */
  hr = pSmtpEnv->get_Item (CComVariant (cdoClientIPAddress), &pFldIP);
  if (!FAILED (hr) && pFldIP)
    {
      CComVariant varValue;
      hr = pFldIP->get_Value (&varValue);
      if (!FAILED (hr))
	szIP = wstr_to_cstr (varValue.bstrVal);
    }
#endif

  if (msgStatus != cdoStatSuccess || // maybe other sink has flagged this
      szRecipients == NULL)
    {
      *EventStatus = cdoRunNextSink;
      goto failed;
    }

  /* Message as stream */
  hr = pMsg->GetStream (&st);
  if (FAILED (hr))
    goto failed;

#ifdef DEBUG
  /* Read full text */
  hr = st->ReadText (-1, &bContent);
  if (FAILED (hr))
    goto failed;

  DEBUG1 ("\nSender: %s\n", szSender);
  DEBUG1 ("Recipients: %s\n", szRecipients);
  DEBUG1 ("Status: %d\n", msgStatus);
  DEBUG1 ("Command: %s\n", g_szCommand);
  DEBUG1 ("BounceBadMail: %d\n", g_bBounceBadMail);
  DEBUG0 ("============ MESSAGE =========\n");
  DEBUG1 ("%ls\n", bContent);
  DEBUG0 ("============== END ===========\n");
#endif

  /* Build recipient list into pRecipients, nRecipients */
  nRecipients = 0;
  for (szRecipient = strtok (szRecipients, ";");
       szRecipient;
       szRecipient = strtok (NULL, ";"))
    {
      if (szRecipient[0] == 0)
	break;
      if (strncmp (szRecipient, "SMTP:", 5))
	continue;
      tRecipient.szRecipient = szRecipient + 5;
      tRecipient.bDelivered = FALSE;
      mpl_grow (&rcpPool, (memptr_t) &tRecipient, sizeof (tRecipient));
      nRecipients++;
    }
  pRecipients = (RECIPIENT *) mpl_finish (&rcpPool);

  /* Deliver to each recipient */
  for (i = 0; i < nRecipients; i++)
    {
      BSTR bErrors;

      /* Deliver */
      szRecipient = pRecipients[i].szRecipient;
      DEBUG1 ("DELIVERING TO %s\n", szRecipient);
      dwExitCode = EX_UNAVAILABLE;
      DeliverPipe (g_szCommand, szSender, szRecipient, st, &dwExitCode,
	  &bErrors, debugFd);

#ifdef DEBUG
      DEBUG1 ("EXIT CODE IS %d\n", dwExitCode);
      if (debugFd && bErrors && dwExitCode != EX_OK)
	{
	  fprintf (debugFd, "------------ ERROR TEXT ----------\n");
	  fprintf (debugFd, "%ls\n", bErrors);
	  fprintf (debugFd, "------------ END ERROR TEXT --------------\n");
	  fflush (debugFd);
	}

      /* To FORCE unloading the maildrop.dll later on */
      if (!strncmp ("coredump@", szRecipient, 9))
	dump_core = TRUE;
#endif

      /* Deal with success & failures */
      switch (dwExitCode)
	{
	/* all went well - remove from recipients list */
	case EX_OK:
	  pRecipients[i].bDelivered = TRUE;
	  break;

	/*
	 *  These should be retried later
	 *  XXX FIGURE OUT HOW XXX
	 *  Return E_XXX for S_FALSE does NOT work
	 *  Anybody? (PmN)
	 */
	case EX_TEMPFAIL:
	case EX_OSERR:
	case EX_IOERR:
	  /* Fall through for now */

	/*
	 *  User unknown : let the next sink in the chain handle this.
	 *  With Exchange installed, a bounce will be sent if
	 *  the user has no other mailbox. If it's not installed,
	 *  we can do the bounce ourselves, if configured.
	 */
	case EX_NOUSER:
	  if (!g_bBounceBadMail)
	    break;

	default:
	  /* Bounce other messages */
	  if (g_bBounceBadMail &&
	      PostReplyMsg (pMsg, szRecipient, bErrors, debugFd) == S_OK)
	    {
	      pRecipients[i].bDelivered = TRUE;
	      break;
	    }

	  /* If we couldn't bounce, it's undeliverable */
	  msgStatus = cdoStatBadMail;
	  *EventStatus = cdoSkipRemainingSinks;
	  if (bErrors)
	    SysFreeString (bErrors);
	  goto failed1;
	}
      if (bErrors)
	SysFreeString (bErrors);
    }

  /* Now modify the list to reflect the remaining recipients */
  szNewRecipients = ps = _strdup (szRecipients);
  for (i = 0; i < nRecipients; i++)
    {
      if (!pRecipients[i].bDelivered)
	{
	  ps = stpcpy (ps, "SMTP:");
	  ps = stpcpy (ps, pRecipients[i].szRecipient);
	  *ps++ = ';';
	}
    }
  *ps = '\0';

  /* If any recipients remaining, pass them on to the next sink */
  if (szNewRecipients[0])
    {
      BSTR bRecipients = cstr_to_bstr (szNewRecipients);
      DEBUG1 ("REMAINING RCPTS '%ls'\n", bRecipients);

      /* Update recipient list with new value */
      hr = pFldRecipients->put_Value (CComVariant (bRecipients));
      if (!FAILED (hr))
	hr = pSmtpEnv->Update ();
      if (FAILED (hr))
	DEBUG0 ("REMAINING RCPTS UPDATE FAILED\n");

      SysFreeString (bRecipients);
      *EventStatus = cdoRunNextSink;
    }
  else
    {
      DEBUG0 ("NO MORE RCPTS - ABORTING FURTHER DELIVERY\n");
      *EventStatus = cdoSkipRemainingSinks;
      msgStatus = cdoStatAbortDelivery; /* we delivered it */
      hr = S_OK;
    }

failed1:
  /* Update message status, if this has changed:
   * cdoStatAbortDelivery	Discard message and do not deliver.
   * cdoStatBadMail		Do not deliver message.
   *				Place it in the location for undeliverable mail.
   */
  if (msgStatus != cdoStatSuccess)
    {
      DEBUG1 ("SET MESG STATUS TO %d\n", msgStatus);
      hr = pFldMsgStatus->put_Value (CComVariant (msgStatus));
      if (!FAILED (hr))
	hr = pSmtpEnv->Update ();
      if (FAILED (hr))
	DEBUG0 ("MESG STATUS UPDATE FAILED\n");
    }

  /* All done */
  hr = S_OK;

failed:
  if (szSender)
    free (szSender);
  if (szRecipients)
    free (szRecipients);
  if (szDate)
    free (szDate);
  if (szIP)
    free (szIP);
  if (szNewRecipients)
    free (szNewRecipients);
  mpl_destroy (&rcpPool);

#ifdef DEBUG
  DEBUG1 ("=== END OF DELIVERY (HR=%p) ===\n", hr);
  if (debugFd)
    fclose (debugFd);
  if (dump_core)
    *force_core_dump = 0;
#endif

  return hr;
}


/*
 *  INNTPOnPost
 */
STDMETHODIMP
CMailDrop::OnPost (IMessage *pMsg, CdoEventStatus *EventStatus)
{
  // TODO
  // Fields:
  // cdoNewsgroupList
  // cdoNNTPProcessing
  *EventStatus = cdoRunNextSink;
  return S_OK;
}


/*
** IPersistPropertyBag : IPersist
*/
STDMETHODIMP
CMailDrop::GetClassID (CLSID *pClassID)
{
  return S_OK;
}


STDMETHODIMP
CMailDrop::InitNew (void)
{
  return S_OK;
}


STDMETHODIMP
CMailDrop::Load (IPropertyBag *pBag, IErrorLog *pErrorLog)
{
  CComVariant varVal;
  HRESULT hr;

  if (pBag == NULL)
    return E_POINTER;

  if (g_szCommand)
    return S_OK;

  varVal.vt = VT_BSTR;
  hr = pBag->Read (L"Command", &varVal, pErrorLog);
  if (!FAILED (hr))
    {
      if (g_szCommand)
	free (g_szCommand);
      g_szCommand = wstr_to_cstr (varVal.bstrVal);
    }

  varVal.vt = VT_BOOL;
  hr = pBag->Read (L"BounceBadMail", &varVal, NULL);
  if (!FAILED (hr))
    {
      g_bBounceBadMail = varVal.boolVal;
    }

  return S_OK;
}


STDMETHODIMP CMailDrop::Save (
    IPropertyBag *pPropBag,
    BOOL fClearDirty,
    BOOL fSaveAllProperties)
{
    return S_OK;
}


/////////////////////////////////////////////////////////////////////////////
// Module registration table

BEGIN_OBJECT_MAP(ObjectMap)
OBJECT_ENTRY(CLSID_MailDrop, CMailDrop)
END_OBJECT_MAP()

CComModule _Module;

/* Guids */
#include "maildrop_i.c"

/////////////////////////////////////////////////////////////////////////////
// DLL Entry Point

extern "C" BOOL WINAPI
DllMain (HINSTANCE hInstance, DWORD dwReason, LPVOID lpReserved)
{
  switch (dwReason)
    {
    case DLL_PROCESS_ATTACH:
      _Module.Init (ObjectMap, hInstance, &LIBID_OpenLink);
      DisableThreadLibraryCalls (hInstance);
      break;
    case DLL_PROCESS_DETACH:
      _Module.Term ();
      break;
    }
  return TRUE;
}

/////////////////////////////////////////////////////////////////////////////
// Used to determine whether the DLL can be unloaded by OLE

STDAPI
DllCanUnloadNow (void)
{
  return (_Module.GetLockCount () == 0) ? S_OK : S_FALSE;
}

/////////////////////////////////////////////////////////////////////////////
// Returns a class factory to create an object of the requested type

STDAPI
DllGetClassObject (REFCLSID rclsid, REFIID riid, LPVOID* ppv)
{
  return _Module.GetClassObject (rclsid, riid, ppv);
}

/////////////////////////////////////////////////////////////////////////////
// DllRegisterServer - Adds entries to the system registry

STDAPI
DllRegisterServer (void)
{
  return _Module.RegisterServer (TRUE);
}

/////////////////////////////////////////////////////////////////////////////
// DllUnregisterServer - Removes entries from the system registry

STDAPI
DllUnregisterServer (void)
{
  return _Module.UnregisterServer (TRUE);
}
