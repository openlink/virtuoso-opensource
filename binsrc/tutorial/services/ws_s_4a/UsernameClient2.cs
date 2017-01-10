//  
//  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
//  project.
//  
//  Copyright (C) 1998-2017 OpenLink Software
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
using System.Windows.Forms;
using System.Security.Cryptography;
using System.Text;
using Microsoft.Web.Services2;
using Microsoft.Web.Services2.Security;
using Microsoft.Web.Services2.Security.Tokens;
using Microsoft.Web.Services2.Security.X509;
using System.Diagnostics;
using System.Xml.Serialization;
using System.Web.Services.Protocols;
using System.Web.Services;
using System.Runtime.InteropServices;

namespace OpenLink.Virtuoso.WSS.UsenameSigning
{
  /// <summary>
  /// This is a sample which allows to send
  /// a message signed with an X509 certificate.
  /// </summary>
  public class AddClient
    {
      int a, b;
      string url, user = "demo", pass = "demo";

      AddClient(string[] args)
	{
	  Hashtable arguments = null;

	  ParseArguments(args, ref arguments);
	  if (arguments.Contains("?"))
	    {
	      Usage();
	    }

	  try
	    {
	      ConvertArgument(arguments, "a", ref a);
	      ConvertArgument(arguments, "b", ref b);
	      url = (string) arguments["url"];
	      user = (string) arguments["user"];
	      pass = (string) arguments["pass"];
	    }
	  catch (Exception)
	    {
	      Usage();
	      throw;
	    }
	}

      /// <summary>
      /// The main entry point for the application.
      /// </summary>
      [STAThread]
	  static void Main(string[] args)
	    {
	      AddClient client = null;
	      try
		{
		  client = new AddClient(args);
		}
	      catch (Exception)
		{
		  Console.WriteLine("\nOne or more of the required arguments are missing or incorrectly formed.");
		  return;
		}

	      try
		{
		  client.Run();
		}
	      catch (Exception ex)
		{
		  Error(ex);
		  return;
		}
	    }

      void Run()
	{
	  CallWebService(a, b, url);
	}

      void Usage()
	{
	  Console.WriteLine("Usage: UsernameSigningClient /a number /b number");
	  Console.WriteLine(" Required arguments:");
	  Console.WriteLine("    /url The Secure service endpoint");
	  Console.WriteLine("    /user The username");
	  Console.WriteLine("    /pass The password");
	  Console.WriteLine("    /" + "a".PadRight(20) + "An integer. First number to add.");
	  Console.WriteLine("    /" + "b".PadRight(20) + "An integer. Second number to add.");
	}

      protected void ConvertArgument(Hashtable args, string argName, ref int arg)
	{
	  if (!args.Contains(argName))
	    {
	      throw new ArgumentException(argName);
	    }
	  arg = int.Parse(args[argName] as string);
	}

      protected void ConvertArgument(Hashtable args, string argName, ref long arg)
	{
	  if (!args.Contains(argName))
	    {
	      throw new ArgumentException(argName);
	    }
	  arg = long.Parse(args[argName] as string);
	}

      protected void ConvertArgument(Hashtable args, string argName, ref bool arg)
	{
	  if (!args.Contains(argName))
	    {
	      throw new ArgumentException(argName);
	    }
	  arg = bool.Parse(args[argName] as string);
	}

      protected string GetOption(string arg)
	{
	  if (!arg.StartsWith("/") && !arg.StartsWith("-"))
	    return null;
	  return arg.Substring(1);
	}

      protected void ParseArguments(string[] args, ref Hashtable table)
	{
	  table = new Hashtable();
	  int index = 0;
	  while (index < args.Length)
	    {
	      string option = GetOption(args[index]);
	      if (option != null)
		{
		  if (index+1 < args.Length && GetOption(args[index+1]) == null)
		    {
		      table[option] = args[++index];
		    }
		  else
		    {
		      table[option] = "true";
		    }
		}
	      index++;
	    }
	}

      protected static void Error(Exception e)
	{
	  StringBuilder sb = new StringBuilder();
	  if (e is System.Web.Services.Protocols.SoapException)
	    {
	      System.Web.Services.Protocols.SoapException se = e as System.Web.Services.Protocols.SoapException;
	      sb.Append("SOAP-Fault code: " + se.Code.ToString());
	      sb.Append("\n");
	    }
	  if (e != null)
	    {
	      sb.Append(e.ToString());
	    }
	  Console.WriteLine("*** Exception Raised ***");
	  Console.WriteLine(sb.ToString());
	  Console.WriteLine("************************");
	}

      private void CallWebService(int a, int b, string url)
	{
	  // Instantiate an instance of the web service proxy
	  AddNumbers serviceProxy = new AddNumbers();
	  SoapContext requestContext = serviceProxy.RequestSoapContext;

	  // Get our security token
	  UsernameToken token = token = new UsernameToken(user, pass, PasswordOption.SendHashed);
	  
	  // Add the signature element to a security section on the request
	  // to sign the request
	  requestContext.Security.Tokens.Add(token);
	  requestContext.Security.Elements.Add(new MessageSignature(token));

	  // requestContext.Timestamp.Ttl = 6000000;
	  // Call the service
	  if (url != null)
	    serviceProxy.Url = url;
	  Console.WriteLine("Calling {0}", serviceProxy.Url);
	  int sum = serviceProxy.AddInt(a, b);

	  // Success!
	  string message = string.Format("{0} + {1} = {2}", a, b, sum);
	  Console.WriteLine("Web Service returned: {0}", message);
	}


      //
      // Web Service Proxy class
      //
      [System.Diagnostics.DebuggerStepThroughAttribute()]
	  [System.ComponentModel.DesignerCategoryAttribute("code")]
	  [System.Web.Services.WebServiceBindingAttribute(Name="VirtuosoWSSecure", Namespace="http://temp.uri/")]

	  public class AddNumbers : Microsoft.Web.Services2.WebServicesClientProtocol {

	    /// <remarks/>
	    public AddNumbers() {
	      this.Url = "http://localhost:8890/SecureWebServices";
	    }

	    /// <remarks/>
	    [System.Web.Services.Protocols.SoapRpcMethodAttribute("http://temp.uri/#AddInt", RequestNamespace="http://temp.uri/", ResponseNamespace="http://temp.uri/")]
            [return: System.Xml.Serialization.SoapElementAttribute("CallReturn")]
		public int AddInt(int a, int b) {
		  object[] results = this.Invoke("AddInt", new object[] {
		      a,
		      b});
		  return ((int)(results[0]));
		}

	    /// <remarks/>
	    public System.IAsyncResult BeginAddInt(int a, int b, System.AsyncCallback callback, object asyncState) {
	      return this.BeginInvoke("AddInt", new object[] {
		  a,
		  b}, callback, asyncState);
	    }

	    /// <remarks/>
	    public int EndAddInt(System.IAsyncResult asyncResult) {
	      object[] results = this.EndInvoke(asyncResult);
	      return ((int)(results[0]));
	    }
	  }
    }
}
