//  
//  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
//  project.
//  
//  Copyright (C) 1998-2013 OpenLink Software
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
using System.Diagnostics;
using System.Xml.Serialization;
using System.ComponentModel;
using System.Web.Services;
using System.Web.Services.Protocols;
using Microsoft.Web.Services2.Security;
using Microsoft.Web.Services2.Security.Tokens;
using Microsoft.Web.Services2.Security.X509;

namespace SecClient 
{

  /// <summary>
  /// 
  /// </summary>
  class SecureClient 
    {
      public static string ClientBase64KeyId = "gBfo0147lM6cKnTbbMSuMVvmFY4=";
      public static string ServerBase64KeyId = "bBwPfItvKp3b6TNDq+14qs58VJQ=";
      public string url;
      [MTAThread]  
      static void Main (string[] args) 
	{
	  string input = "hello";
	  SecureClient client = null;
	  try 
	    {
	      client = new SecureClient ();
	      if (args.Length > 1)
		{
		  client.url = args[0]; 
		  input = args[1];
		  client.Run (input);
		}
	      else
		{
		  Console.WriteLine ("Usage: SecClient.exe [url] [input string]");
		}
	    } 
	  catch (Exception ex) 
	    {
	      Console.WriteLine (ex);
	    } 
	  Console.WriteLine ("");
	} 
      
      public static X509SecurityToken GetClientToken ()
	{
	  X509SecurityToken token = null;
	  // Open the CurrentUser Certificate Store and try MyStore only
	  X509CertificateStore store = X509CertificateStore.CurrentUserStore (X509CertificateStore.MyStore);
	  token = RetrieveTokenFromStore (store, ClientBase64KeyId);
	  return token;
	}
      
      private static X509SecurityToken RetrieveTokenFromStore (X509CertificateStore store, string keyIdentifier) 
	{
	  if (store == null)
	    throw new ArgumentNullException ("store");
	  X509SecurityToken token = null;
	  try 
	    {
	      if (store.OpenRead ())
		{
		  // Place the key ID of the certificate in a byte array
		  // This KeyID represents the Wse2Quickstart certificate included with the WSE 2.0 Quickstarts
		  // ClientBase64KeyId is defined in the ClientBase.AppBase class
		  X509CertificateCollection certs =
		      store.FindCertificateByKeyIdentifier (Convert.FromBase64String (keyIdentifier));
		  if (certs.Count > 0)

		    {
		      // Get the first certificate in the collection
		      token = new X509SecurityToken (((X509Certificate) certs[0]));
		    }
		}
	    }
	  finally 
	    {
	      if (store != null)
		store.Close ();
	    }
	  return token;
	}
      
      public static X509SecurityToken GetServerToken () 
	{
	  X509SecurityToken token = null;
	  X509CertificateStore store = null;
	  store = X509CertificateStore.CurrentUserStore (X509CertificateStore.OtherPeople);
	  token = RetrieveTokenFromStore (store, ServerBase64KeyId);

	  //
	  // If we failed to retrieve it from the OtherPeople,
	  // we now try the MyStore
	  //
	  if (token == null)
	    {
	      store = X509CertificateStore.CurrentUserStore (X509CertificateStore.MyStore);
	      token = RetrieveTokenFromStore (store, ServerBase64KeyId);
	    }
	  return token;
	}

      public void Run (string input) 
	{

	  string var;

	  // Create an instance of the Web service proxy
	  echoWse serviceProxy = new echoWse ();

	  X509SecurityToken token = GetClientToken ();
	  if (token == null)
	    throw new ApplicationException ("Unable to obtain security token.");

	  // Add an EncryptedData element to the security collection
	  // to encrypt the request.
	  serviceProxy.RequestSoapContext.Security.Elements.Add (new EncryptedData (token));

	  // Add the signature element to a security section on the request
	  // to sign the request
	  token = GetServerToken ();
	  if (token == null)
	    throw new ApplicationException ("Unable to obtain security token.");

	  serviceProxy.RequestSoapContext.Security.Tokens.Add (token);
	  serviceProxy.RequestSoapContext.Security.Elements.Add (new MessageSignature (token));

	  // Call the service
	  serviceProxy.Url = this.url;
	  Console.WriteLine ("Calling {0}", serviceProxy.Url);

	  var = input;
	  serviceProxy.echo (ref var);

	  Console.WriteLine ("Web Service called successfully.\n" + var);
	}
    }

  /// <remarks/>
  [System.Diagnostics.DebuggerStepThroughAttribute ()] 
  [System.ComponentModel.DesignerCategoryAttribute ("code")] 
  [System.Web.Services.WebServiceBindingAttribute (Name = "echoBinding", Namespace = "http://temp.org")]  
  public class echoWse:Microsoft.Web.Services2.WebServicesClientProtocol
    {

      /// <remarks/>
      [System.Web.Services.Protocols.SoapDocumentMethodAttribute ("#echo",
	  RequestNamespace = "http://temp.org", ResponseNamespace = "http://temp.org", 
	  Use = System.Web.Services.Description.SoapBindingUse.Literal,
	  ParameterStyle = System.Web.Services.Protocols.SoapParameterStyle.Wrapped)]  
	  public void echo (ref string varString)
	    {
	      object[]results = this.Invoke ("echo", new object[] { varString } );
	      varString = ((string) (results[0]));
	    } 

      /// <remarks/>
      public System.IAsyncResult Beginecho (string varString, System.AsyncCallback callback, object asyncState)
	{
	  return this.BeginInvoke ("echo", new object[] { varString } , callback, asyncState);
	}

      /// <remarks/>
      public void Endecho (System.IAsyncResult asyncResult, out string varString)
	{
	  object[]results = this.EndInvoke (asyncResult);
	  varString = ((string) (results[0]));
	} 
    } 
} 
