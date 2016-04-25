//  
//  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
//  project.
//  
//  Copyright (C) 1998-2016 OpenLink Software
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
using Microsoft.WSDK;
using Microsoft.WSDK.Security;
using Microsoft.WSDK.Security.Cryptography;
using System;
using System.Collections;
using System.ComponentModel;
using System.Configuration;
using System.Windows.Forms;
using System.Security.Cryptography;
using System.Security.Cryptography.Xml;
using System.Text;
using System.Diagnostics;
using System.Xml.Serialization;
using System.Web.Services;
using System.Web.Services.Protocols;

namespace OpenLink.Virtuoso.WSS.SymmetricEncryption
{
    /// <summary>
    /// This is a sample which allows the user to send a message
    /// encrypted with a tripple-des encryption algorithm.
    /// </summary>
    public class AddClient
    {
        int a, b;

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
            CallWebService(a, b);
        }

        void Usage()
        {
            Console.WriteLine("Usage: SymmetricEncryptionClient");
            Console.WriteLine("    /" + "?".PadRight(16) + "command line help.");
            Console.WriteLine("    /" + "a".PadRight(16) + "An integer. First number to add.");
            Console.WriteLine("    /" + "b".PadRight(16) + "An integer. Second number to add.");
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

        private void CallWebService(int a, int b)
        {
            // Get the Symmetric key
            EncryptionKey key = GetEncryptionKey();

            // Instantiate an instance of the web service proxy
            AddNumbers serviceProxy = new AddNumbers();
            SoapContext requestContext = serviceProxy.RequestSoapContext;

            // Set the encryption key for this request
            requestContext.Security.Elements.Add(new EncryptedData(key));

            // Set the TTL to one minute
            requestContext.Timestamp.Ttl = 60000;

            // Call the service
            Console.WriteLine("Calling {0}", serviceProxy.Url);
            int sum = serviceProxy.AddInt(a, b);

            // Success!
            string message = string.Format("{0} + {1} = {2}", a, b, sum);
            Console.WriteLine("Web Service returned: {0}", message);
        }

        /// <summary>
        /// Creates a key used to encrypt messages.
        /// </summary>
        /// <returns>The encryption key</returns>
        private EncryptionKey GetEncryptionKey()
        {

            // We generated a symmetric key using triple DES and stored the
            // key in the configuration file for this application.

            string keyData = ConfigurationSettings.AppSettings["symmetricKey"];
            if (keyData == null)
            {
                throw new ApplicationException("Symmetric key not found.");
            }

            byte[] keyBytes = Convert.FromBase64String(keyData);
            SymmetricEncryptionKey key = new SymmetricEncryptionKey(TripleDES.Create(), keyBytes);

            KeyInfoName keyName = new KeyInfoName();

            keyName.Value  = "WSDK Sample Symmetric Key";

            key.KeyInfo.AddClause(keyName);

            return key;
        }
    }

    //
    // Web Service Proxy class
    //
    [System.Diagnostics.DebuggerStepThroughAttribute()]
    [System.ComponentModel.DesignerCategoryAttribute("code")]
    [System.Web.Services.WebServiceBindingAttribute(Name="VirtuosoWSSecure", Namespace="http://temp.uri/")]

    // Instead of deriving from System.Web.Services.Protocols.SoapHttpClientProtocol,
    // WSDK Web Service proxies must derive from WSDKClientProtocol
    public class AddNumbers : WSDKClientProtocol {

        public AddNumbers() {
            this.Url = "http://<virtuoso:port>/SecureWebServices";
        }

        [System.Web.Services.Protocols.SoapDocumentMethodAttribute("http://temp.uri/#AddInt", RequestNamespace="http://temp.uri/", ResponseNamespace="http://temp.uri/", Use=System.Web.Services.Description.SoapBindingUse.Encoded)]
        public int AddInt(int a, int b) {
            object[] results = this.Invoke("AddInt", new object[] {
                        a,
                        b});
            return ((int)(results[0]));
        }

        public System.IAsyncResult BeginAddInt(int a, int b, System.AsyncCallback callback, object asyncState) {
            return this.BeginInvoke("AddInt", new object[] {
                        a,
                        b}, callback, asyncState);
        }

        public int EndAddInt(System.IAsyncResult asyncResult) {
            object[] results = this.EndInvoke(asyncResult);
            return ((int)(results[0]));
	}
    }
}
