//  
//  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
//  project.
//  
//  Copyright (C) 1998-2019 OpenLink Software
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
using System.Runtime.InteropServices;
using System.Diagnostics;
using System.Xml.Serialization;
using System.Web.Services.Protocols;
using System.Web.Services;

namespace OpenLink.Virtuoso.WSS.AsymmetricEncryption
{
    /// <summary>
    /// This is a sample which allows the user to send
    /// a message encrypted with an RSA and tripple-des keys.
    /// </summary>
    public class AddClient
    {
        int a, b;
	string url;

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
            Console.WriteLine("Usage: AsymmetricEncryptionClient /a number /b number");
            Console.WriteLine(" Required arguments:");
            Console.WriteLine("    /url The Secure service endpoint");
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

            // Get the Asymmetric key
            X509SecurityToken token = GetEncryptionToken();

            if (token == null)
                throw new ApplicationException("No security token provided.");

            // Add an EncryptedData element to the security collection
            // to encrypt the request.
            requestContext.Security.Elements.Add(new EncryptedData(token));
	    if (url != null)
	      serviceProxy.Url = url;

            // Call the service
            Console.WriteLine("Calling {0}", serviceProxy.Url);
            int sum = serviceProxy.AddInt(a, b);

            // Success!
            string message = string.Format("{0} + {1} = {2}", a, b, sum);
            Console.WriteLine("Web Service returned: {0}", message);
        }

        /// <summary>
        /// Returns the X.509 SecurityToken that will be used to encrypt the
        /// messages.
        /// </summary>
        /// <returns>Returns </returns>
        public X509SecurityToken GetEncryptionToken()
        {
            X509SecurityToken token = null;
            //
            // The certificate for the target receiver should have been imported
            // into the "My" certificate store. This store is listed as "Personal"
            // in the Certificate Manager
            //
            X509CertificateStore store = X509CertificateStore.CurrentUserStore(X509CertificateStore.MyStore);
            bool open = store.OpenRead();

            try
            {
                //
                // Open a dialog to allow user to select the certificate to use
                //
                StoreDialog dialog = new StoreDialog(store);
                X509Certificate cert = dialog.SelectCertificate(IntPtr.Zero, "Select Certificate", "Choose a Certificate below for encrypting.");
                if (cert == null)
                {
                    throw new ApplicationException("You chose not to select an X509 certificate for encrypting your messages.");
                }
                else if (!cert.SupportsDataEncryption)
                {
                    throw new ApplicationException("The certificate must support key encipherment.");
                }
                else
                {
                    token = new X509SecurityToken(cert);
                }
            }
            finally
            {
                if (store != null) { store.Close(); }
            }

            return token;
        }
    }

    class StoreDialog {

        X509CertificateStore store;

        public StoreDialog(X509CertificateStore store)
        {
            this.store = store;
        }

        static bool IsWinXP()
        {
            OperatingSystem os = Environment.OSVersion;
            Version v = os.Version;

            if (os.Platform == PlatformID.Win32NT && v.Major >= 5 && v.Minor >= 1)
            {
                return true;
            }

            return false;
        }

        /// <summary>
        /// Displays a dialog that can be used to select a certificate from the store.
        /// </summary>
        public X509Certificate SelectCertificate(IntPtr hwnd, string title, string displayString)
        {
            if (store.Handle == IntPtr.Zero)
                throw new InvalidOperationException("Store is not open");

            if (IsWinXP())
            {
                IntPtr certPtr = CryptUIDlgSelectCertificateFromStore(store.Handle, hwnd, title, displayString, 0/*dontUseColumn*/, 0 /*flags*/, IntPtr.Zero);
                if (certPtr != IntPtr.Zero)
                {
                    return new X509Certificate(certPtr);
                }
            }
            else
            {
                SelectCertificateDialog dlg = new SelectCertificateDialog(store);
                if (dlg.ShowDialog() != DialogResult.OK)
                {
                    return null;
                }
                else
                {
                    return dlg.Certificate;
                }
            }

            return null;
        }

        [DllImport("cryptui", CharSet=CharSet.Unicode, SetLastError=true)]
        internal extern static IntPtr CryptUIDlgSelectCertificateFromStore(IntPtr hCertStore, IntPtr hwnd, string pwszTitle, string pwszDisplayString, uint dwDontUseColumn, uint dwFlags, IntPtr pvReserved);
    }

    /// <summary>
    /// SelectCertificateDialog.
    /// </summary>
    class SelectCertificateDialog : System.Windows.Forms.Form
    {
        /// <summary>
        /// Required designer variable.
        /// </summary>
        private System.Windows.Forms.Button _okBtn;
        private System.Windows.Forms.Button _cancelBtn;

        private X509CertificateStore _store;
        private System.Windows.Forms.ListView _certList;
        private System.Windows.Forms.ColumnHeader _certName;
        private X509Certificate _certificate = null;

        public SelectCertificateDialog(X509CertificateStore store) : base()
        {
            _store = store;

            // Required for Windows Form Designer support
            //
            InitializeComponent();
        }

        public X509Certificate Certificate
        {
            get
            {
                return _certificate;
            }
        }

        /// <summary>
        /// Required method for Designer support - do not modify
        /// the contents of this method with the code editor.
        /// </summary>
        private void InitializeComponent()
        {
            this._okBtn = new System.Windows.Forms.Button();
            this._cancelBtn = new System.Windows.Forms.Button();
            this._certList = new System.Windows.Forms.ListView();
            this._certName = new System.Windows.Forms.ColumnHeader();
            this.SuspendLayout();
            //
            // _okBtn
            //
            this._okBtn.Location = new System.Drawing.Point(96, 232);
            this._okBtn.Name = "_okBtn";
            this._okBtn.TabIndex = 1;
            this._okBtn.Text = "OK";
            this._okBtn.Click += new System.EventHandler(this.OkBtn_Click);
            //
            // _cancelBtn
            //
            this._cancelBtn.DialogResult = System.Windows.Forms.DialogResult.Cancel;
            this._cancelBtn.Location = new System.Drawing.Point(192, 232);
            this._cancelBtn.Name = "_cancelBtn";
            this._cancelBtn.TabIndex = 2;
            this._cancelBtn.Text = "Cancel";
            this._cancelBtn.Click += new System.EventHandler(this.CancelBtn_Click);
            //
            // _certList
            //
            this._certList.Columns.AddRange(new System.Windows.Forms.ColumnHeader[]{
                                                                                       this._certName});
            this._certList.Dock = System.Windows.Forms.DockStyle.Top;
            this._certList.FullRowSelect = true;
            this._certList.MultiSelect = false;
            this._certList.Name = "_certList";
            this._certList.Size = new System.Drawing.Size(292, 176);
            this._certList.TabIndex = 3;
            this._certList.View = System.Windows.Forms.View.Details;
            //
            // _certName
            //
            this._certName.Text = "Name";
            this._certName.Width = 92;
            //
            // SelectCertificateDialog
            //
            this.AcceptButton = this._okBtn;
            this.AutoScaleBaseSize = new System.Drawing.Size(5, 13);
            this.CancelButton = this._cancelBtn;
            this.ClientSize = new System.Drawing.Size(292, 266);
            this.Controls.AddRange(new System.Windows.Forms.Control[]{
                                                                         this._certList,
                                                                         this._cancelBtn,
                                                                         this._okBtn});
            this.Name = "SelectCertificateDialog";
            this.Text = "SelectCertificateDialog";
            this.ResumeLayout(false);

        }

        protected override void OnLoad(EventArgs e)
        {
            base.OnLoad(e);

            if (_store == null)
            {
                throw new Exception("No store to open");
            }

            if (_store.Handle == IntPtr.Zero)
            {
                throw new Exception("Store not open for reading");
            }

            X509CertificateCollection coll = _store.Certificates;

            foreach(X509Certificate cert in coll)
            {
                ListViewItem item = new ListViewItem(cert.GetName());
                this._certList.Items.Add(item);
            }
        }

        private void OkBtn_Click(object sender, System.EventArgs e)
        {
            _certificate = null;

            if (_certList.SelectedItems != null && _certList.SelectedItems.Count == 1)
            {
                X509CertificateCollection coll = _store.FindCertificateBySubjectName(_certList.SelectedItems[0].Text);
                if (coll != null && coll.Count == 1)
                {
                    _certificate = coll[0] as X509Certificate;
                }
            }

            this.Close();
            this.DialogResult = DialogResult.OK;
        }

        private void CancelBtn_Click(object sender, System.EventArgs e)
        {
            _certificate = null;
        }
    }

    //
    // Web Service Proxy class
    //
    [System.Diagnostics.DebuggerStepThroughAttribute()]
    [System.ComponentModel.DesignerCategoryAttribute("code")]
    [System.Web.Services.WebServiceBindingAttribute(Name="VirtuosoWSSecure", Namespace="http://temp.uri/")]

    // Instead of deriving from System.Web.Services.Protocols.SoapHttpClientProtocol,
    // WSE Web Service proxies must derive from Microsoft.Web.Services.WebServicesClientProtocol
    public class AddNumbers : Microsoft.Web.Services2.WebServicesClientProtocol {

        public AddNumbers() {
            this.Url = "http://localhost:8890/SecureWebServices";
        }

	[System.Web.Services.Protocols.SoapRpcMethodAttribute("http://temp.uri/#AddInt", RequestNamespace="http://temp.uri/", ResponseNamespace="http://temp.uri/")]
        [return: System.Xml.Serialization.SoapElementAttribute("CallReturn")]
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
