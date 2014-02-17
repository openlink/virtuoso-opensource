//  
//  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
//  project.
//  
//  Copyright (C) 1998-2014 OpenLink Software
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

namespace OpenLink.Virtuoso.WSRP.Client
{
    public class AddClient 
    {
        int a, b;

        AddClient(string[] args)
        {
            Hashtable arguments = null;
            
            ParseArguments(args, ref arguments);

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
            Console.WriteLine("Usage: RoutingClient /a number /b number");
            Console.WriteLine(" Required arguments:");
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

        private void CallWebService(int a, int b)
        {
            AddNumbers serviceProxy = new AddNumbers();
            SoapContext requestContext = serviceProxy.RequestSoapContext;

            requestContext.Timestamp.Ttl = 60000;              

            Console.WriteLine("Calling {0}", serviceProxy.Url);
            int sum = serviceProxy.AddInt(a, b);

            string message = string.Format("{0} + {1} = {2}", a, b, sum);
            Console.WriteLine("Web Service called successfully: {0}", message);            
        }
    }
    [System.Diagnostics.DebuggerStepThroughAttribute()]
    [System.ComponentModel.DesignerCategoryAttribute("code")]
    [System.Web.Services.WebServiceBindingAttribute(Name="VirtuosoSumService", Namespace="http://temp.uri")]
    public class AddNumbers : WSDKClientProtocol {

        public AddNumbers() {
            this.Url = "http://<virtuoso:port>/SumService";
        }

        [System.Web.Services.Protocols.SoapRpcMethodAttribute("http://temp.uri#AddInt", RequestNamespace="http://temp.uri", ResponseNamespace="http://temp.uri")]
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
