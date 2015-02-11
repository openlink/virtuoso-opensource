//  
//  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
//  project.
//  
//  Copyright (C) 1998-2015 OpenLink Software
//  
//  This project is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the
//  Free Software Foundation; only version 2 of the License, dated June 1991.
//  
//  This program is distributed in the hope that it will be useful, but
//  WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
//  General Public License for more details.
//  
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA
//  
//  
using System;
using System.Collections;
using System.ComponentModel;
using System.Text;
using System.Net;
using System.IO;
using System.Data;
using System.Diagnostics;
using System.Web;
using System.Web.Services;
using System.Web.Services.Protocols;
using System.Xml.Serialization;
using Microsoft.Web.Services2;
using Microsoft.Web.Services2.Addressing;
using Microsoft.Web.Services2.Security;
using Microsoft.Web.Services2.Security.Tokens;
using Microsoft.Web.Services2.Security.X509;


namespace SecSvc
{
  /// <summary>
  /// Summary description for Service1.
  /// </summary>
  [WebService(Namespace="services.wsdl")]
      public class SecSvc : System.Web.Services.WebService
	{
	  public static string ClientBase64KeyId = "gBfo0147lM6cKnTbbMSuMVvmFY4=";
	  public static string ServerBase64KeyId = "bBwPfItvKp3b6TNDq+14qs58VJQ=";

	  public SecSvc()
	    {
	      InitializeComponent();
	    }

#region Component Designer generated code

	  //Required by the Web Services Designer 
	  private IContainer components = null;

	  /// <summary>
	  /// Required method for Designer support - do not modify
	  /// the contents of this method with the code editor.
	  /// </summary>
	  private void InitializeComponent()
	    {
	    }

	  /// <summary>
	  /// Clean up any resources being used.
	  /// </summary>
	  protected override void Dispose( bool disposing )
	    {
	      if(disposing && components != null)
		{
		  components.Dispose();
		}
	      base.Dispose(disposing);		
	    }

#endregion

	  public static SecurityToken GetEncryptingToken(SoapContext context)
	    {
	      SecurityToken encryptingToken = null;

	      foreach (ISecurityElement element in context.Security.Elements)
		{
		  if (element is EncryptedData)
		    {
		      EncryptedData encryptedData = element as EncryptedData;
		      System.Xml.XmlElement targetElement = encryptedData.TargetElement;										

		      if ( SoapEnvelope.IsSoapBody(targetElement))
			{
			  // The given context has the Body element Encrypted.
			  encryptingToken = encryptedData.SecurityToken;
			}
		    }
		}

	      return encryptingToken;
	    }
	  public static X509SecurityToken GetServerToken()
	    {
	      X509SecurityToken token = null;
	      X509CertificateStore store = null;

	      // For server, open the LocalMachine Certificate Store and try Personal store.
	      store = X509CertificateStore.LocalMachineStore( X509CertificateStore.MyStore );
	      token = RetrieveTokenFromStore(store, ServerBase64KeyId);

	      return token;
	    }
	  private static X509SecurityToken RetrieveTokenFromStore(X509CertificateStore store, string keyIdentifier) 
	    {
	      if ( store == null )
		throw new ArgumentNullException("store");

	      X509SecurityToken token = null;

	      try 
		{
		  if( store.OpenRead() ) 
		    {
		      // Place the key ID of the certificate in a byte array
		      // This KeyID represents the Wse2Quickstart certificate included with the WSE 2.0 Quickstarts
		      // ClientBase64KeyId is defined in the ClientBase.AppBase class
		      X509CertificateCollection certs = store.FindCertificateByKeyIdentifier( Convert.FromBase64String( keyIdentifier ) );

		      if (certs.Count > 0)
			{
			  // Get the first certificate in the collection
			  token = new X509SecurityToken( ((X509Certificate) certs[0]) );
			}        
		    } 
		}
	      finally
		{
		  if ( store != null )
		    store.Close();
		}

	      return token;
	    }

	  public static void VerifyMessageParts(SoapContext context) 
	    {
	      // Body
	      if ( context.Envelope.Body == null )
		throw new ApplicationException("The message must contain a soap:Body element");
	    }

	  public static SecurityToken GetSigningToken(SoapContext context)
	    {
	      foreach ( ISecurityElement element in context.Security.Elements )
		{
		  if ( element is MessageSignature )
		    {
		      // The given context contains a Signature element.
		      MessageSignature sig = element as MessageSignature;

		      if (CheckSignature(context, sig))
			{
			  // The SOAP Body is signed.
			  return sig.SigningToken;
			}
		    }
		}

	      return null;
	    }

	  static bool CheckSignature(SoapContext context, MessageSignature signature)
	    {
	      //
	      // Now verify which parts of the message were actually signed.
	      //
	      SignatureOptions actualOptions   = signature.SignatureOptions;
	      SignatureOptions expectedOptions = SignatureOptions.IncludeSoapBody;

	      if (context.Security != null && context.Security.Timestamp != null  
		  && context.Security.Timestamp.TargetElement != null) 
		expectedOptions |= SignatureOptions.IncludeTimestamp;

	      //
	      // The <Action> and <To> are required addressing elements.
	      //
	      expectedOptions |= SignatureOptions.IncludeAction;
	      expectedOptions |= SignatureOptions.IncludeTo;

	      if ( context.Addressing.FaultTo != null && context.Addressing.FaultTo.TargetElement != null )
		expectedOptions |= SignatureOptions.IncludeFaultTo;

	      if ( context.Addressing.From != null && context.Addressing.From.TargetElement != null )
		expectedOptions |= SignatureOptions.IncludeFrom;

	      if ( context.Addressing.MessageID != null && context.Addressing.MessageID.TargetElement != null )
		expectedOptions |= SignatureOptions.IncludeMessageId;

	      if ( context.Addressing.RelatesTo != null && context.Addressing.RelatesTo.TargetElement != null )
		expectedOptions |= SignatureOptions.IncludeRelatesTo;

	      if ( context.Addressing.ReplyTo != null && context.Addressing.ReplyTo.TargetElement != null )
		expectedOptions |= SignatureOptions.IncludeReplyTo;
	      //
	      // Check if the all the expected options are the present.
	      //
	      return ( ( expectedOptions & actualOptions ) == expectedOptions );

	    }
	  public static bool CompareArray(byte[] a, byte[] b)
	    {
	      if (a != null && b != null && a.Length == b.Length)
		{
		  int index = a.Length;
		  while (--index > -1)
		    if (a[index] != b[index])
		      return false;
		  return true;
		}
	      else if (a == null && b == null)
		return true;
	      else
		return false;
	    }

	  [WebMethod]
	  [SoapDocumentMethod(Action="#echoSync")]
	  [return:XmlElement("CallReturn")]
	  public string echoSync (string var)
	    {
	      // Reject any requests which are not valid SOAP requests
	      if (RequestSoapContext.Current == null)
		throw new ApplicationException("Only SOAP requests are permitted.");

	      // Check if the soap message contains all the required message parts
	      VerifyMessageParts(RequestSoapContext.Current);

	      // Check if the Soap Message is Signed.
	      X509SecurityToken x509Token = GetSigningToken(RequestSoapContext.Current) as X509SecurityToken;
	      if (x509Token == null || 
		  !CompareArray(x509Token.KeyIdentifier.Value, Convert.FromBase64String(ClientBase64KeyId)))
		{
		  throw new SecurityFault(SecurityFault.FailedAuthenticationMessage, SecurityFault.FailedAuthenticationCode);
		}


	      // Check if the Soap Message is Encrypted.
	      x509Token = GetEncryptingToken(RequestSoapContext.Current) as X509SecurityToken;
	      if (x509Token == null)
		{
		  throw new SecurityFault(SecurityFault.FailedCheckMessage, SecurityFault.FailedCheckCode, 
		      new Exception("The message body is not encrypted with an x509 security token."));
		}

	      X509SecurityToken serverCert = GetServerToken();
	      if (serverCert == null)
		{
		  throw new SecurityFault(SecurityFault.FailedCheckMessage, SecurityFault.FailedCheckCode, 
		      new Exception("Unable to validate encrypting token."));
		}

	      if (!serverCert.Equals(x509Token))
		{
		  throw new SecurityFault(SecurityFault.FailedCheckMessage, SecurityFault.FailedCheckCode, 
		      new Exception("The encrypting token is invalid."));
		}

	      x509Token = GetSigningToken(RequestSoapContext.Current) as X509SecurityToken;
	      ResponseSoapContext.Current.Security.Elements.Add (new EncryptedData (x509Token));

	      return "IIS reply="+var;
	    }
	}
}
