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
using System.Drawing;
using System.Collections;
using System.ComponentModel;
using System.Windows.Forms;

#if ODBC_CLIENT
namespace OpenLink.Data.VirtuosoOdbcClient.Design
#elif CLIENT
namespace OpenLink.Data.VirtuosoClient.Design
#else
namespace OpenLink.Data.Virtuoso.Design
#endif
{
	/// <summary>
	/// Class to edit a connection string
	/// </summary>
	public class VirtuosoDotNetDSNForm : System.Windows.Forms.Form
	{
            private System.Windows.Forms.Label label2;
            private System.Windows.Forms.Label label1;
            private System.Windows.Forms.TextBox tbSourceName;
            private System.Windows.Forms.TextBox tbHostName;
            private System.Windows.Forms.Label label3;
            private System.Windows.Forms.Label label4;
            private System.Windows.Forms.Label label5;
            private System.Windows.Forms.TextBox tbUserID;
            private System.Windows.Forms.TextBox tbPort;
            private System.Windows.Forms.TextBox tbPwd;
            private System.Windows.Forms.Button btnAdd;
            private System.Windows.Forms.Button btnCancel;
            private string connect_string;
            private string source_name;

            public String ConnectString
            {
                get 
                {
                    return connect_string;
                }
            }
            public String SourceName
            {
                get 
                {
                    return source_name;
                }
            }
            /// <summary>
		/// Required designer variable.
		/// </summary>
		private System.ComponentModel.Container components = null;

		public VirtuosoDotNetDSNForm(String name)
		{
			//
			// Required for Windows Form Designer support
			//
			InitializeComponent();

                    this.tbSourceName.Text = name;
		}

            public VirtuosoDotNetDSNForm(String name, String connect_string)
                : this(name)
            {
                VirtuosoConnection c = new VirtuosoConnection (connect_string);

                try
                {
                    string [] hp = c.GetConnectionOption ("HOST").Split (":".ToCharArray ());
                    string host, port;
                    if (hp.Length > 1)
                    {
                        host = hp[0];
                        port = hp[1];
                    }
                    else
                    {
                        host = "localhost";
                        port = "1111";
                        try
                        {
                            if (int.Parse(hp[0]) > 0)
                            {
                                host = "localhost";
                                port = hp[0];
                            }
                        }
                        catch
                        {
                            port = "1111";
                            host = hp[0];
                        }
                    }
                    this.tbHostName.Text = hp.Length > 1 ? hp[0] : "localhost";
                    this.tbPort.Text = hp.Length > 1 ? hp[1] : hp[0];
                }
                catch
                {
                }

                try { this.tbUserID.Text = c.GetConnectionOption ("UID"); } catch {}                                                           

                try { this.tbPwd.Text = c.GetConnectionOption ("PWD"); } catch {}                                                         

                this.tbSourceName.Enabled = false;
                this.Text = "Edit Data Source";
            }

            /// <summary>
		/// Clean up any resources being used.
		/// </summary>
		protected override void Dispose( bool disposing )
		{
			if( disposing )
			{
				if(components != null)
				{
					components.Dispose();
				}
			}
			base.Dispose( disposing );
		}

		#region Windows Form Designer generated code
		/// <summary>
		/// Required method for Designer support - do not modify
		/// the contents of this method with the code editor.
		/// </summary>
		private void InitializeComponent()
		{
                    this.label2 = new System.Windows.Forms.Label();
                    this.tbSourceName = new System.Windows.Forms.TextBox();
                    this.tbHostName = new System.Windows.Forms.TextBox();
                    this.label1 = new System.Windows.Forms.Label();
                    this.tbPort = new System.Windows.Forms.TextBox();
                    this.label3 = new System.Windows.Forms.Label();
                    this.tbUserID = new System.Windows.Forms.TextBox();
                    this.label4 = new System.Windows.Forms.Label();
                    this.tbPwd = new System.Windows.Forms.TextBox();
                    this.label5 = new System.Windows.Forms.Label();
                    this.btnAdd = new System.Windows.Forms.Button();
                    this.btnCancel = new System.Windows.Forms.Button();
                    this.SuspendLayout();
                    // 
                    // label2
                    // 
                    this.label2.Location = new System.Drawing.Point(16, 10);
                    this.label2.Name = "label2";
                    this.label2.Size = new System.Drawing.Size(80, 16);
                    this.label2.TabIndex = 1;
                    this.label2.Text = "Source Name";
                    // 
                    // tbSourceName
                    // 
                    this.tbSourceName.Location = new System.Drawing.Point(96, 8);
                    this.tbSourceName.Name = "tbSourceName";
                    this.tbSourceName.Size = new System.Drawing.Size(272, 20);
                    this.tbSourceName.TabIndex = 1;
                    this.tbSourceName.Text = "";
                    // 
                    // tbHostName
                    // 
                    this.tbHostName.Location = new System.Drawing.Point(96, 32);
                    this.tbHostName.Name = "tbHostName";
                    this.tbHostName.Size = new System.Drawing.Size(272, 20);
                    this.tbHostName.TabIndex = 2;
                    this.tbHostName.Text = "localhost";
                    // 
                    // label1
                    // 
                    this.label1.Location = new System.Drawing.Point(16, 34);
                    this.label1.Name = "label1";
                    this.label1.Size = new System.Drawing.Size(80, 16);
                    this.label1.TabIndex = 1;
                    this.label1.Text = "Host name";
                    // 
                    // tbPort
                    // 
                    this.tbPort.Location = new System.Drawing.Point(96, 56);
                    this.tbPort.Name = "tbPort";
                    this.tbPort.Size = new System.Drawing.Size(48, 20);
                    this.tbPort.TabIndex = 3;
                    this.tbPort.Text = "1111";
                    // 
                    // label3
                    // 
                    this.label3.Location = new System.Drawing.Point(16, 58);
                    this.label3.Name = "label3";
                    this.label3.Size = new System.Drawing.Size(80, 16);
                    this.label3.TabIndex = 3;
                    this.label3.Text = "Port number";
                    // 
                    // tbUserID
                    // 
                    this.tbUserID.Location = new System.Drawing.Point(96, 80);
                    this.tbUserID.Name = "tbUserID";
                    this.tbUserID.Size = new System.Drawing.Size(272, 20);
                    this.tbUserID.TabIndex = 4;
                    this.tbUserID.Text = "dba";
                    // 
                    // label4
                    // 
                    this.label4.Location = new System.Drawing.Point(16, 82);
                    this.label4.Name = "label4";
                    this.label4.Size = new System.Drawing.Size(80, 16);
                    this.label4.TabIndex = 5;
                    this.label4.Text = "User ID";
                    // 
                    // tbPwd
                    // 
                    this.tbPwd.Location = new System.Drawing.Point(96, 104);
                    this.tbPwd.Name = "tbPwd";
                    this.tbPwd.PasswordChar = '*';
                    this.tbPwd.Size = new System.Drawing.Size(272, 20);
                    this.tbPwd.TabIndex = 5;
                    this.tbPwd.Text = "dba";
                    // 
                    // label5
                    // 
                    this.label5.Location = new System.Drawing.Point(16, 106);
                    this.label5.Name = "label5";
                    this.label5.Size = new System.Drawing.Size(80, 16);
                    this.label5.TabIndex = 7;
                    this.label5.Text = "Password";
                    // 
                    // btnAdd
                    // 
                    this.btnAdd.Location = new System.Drawing.Point(16, 136);
                    this.btnAdd.Name = "btnAdd";
                    this.btnAdd.TabIndex = 6;
                    this.btnAdd.Text = "Add";
                    this.btnAdd.Click += new System.EventHandler(this.btnAdd_Click);
                    // 
                    // btnCancel
                    // 
                    this.btnCancel.DialogResult = System.Windows.Forms.DialogResult.Cancel;
                    this.btnCancel.Location = new System.Drawing.Point(293, 136);
                    this.btnCancel.Name = "btnCancel";
                    this.btnCancel.TabIndex = 7;
                    this.btnCancel.Text = "Cancel";
                    this.btnCancel.Click += new System.EventHandler(this.btnCancel_Click);
                    // 
                    // VirtuosoDotNetDSNForm
                    // 
                    this.AcceptButton = this.btnAdd;
                    this.AutoScaleBaseSize = new System.Drawing.Size(5, 13);
                    this.CancelButton = this.btnCancel;
                    this.ClientSize = new System.Drawing.Size(384, 166);
                    this.Controls.Add(this.btnCancel);
                    this.Controls.Add(this.btnAdd);
                    this.Controls.Add(this.tbPwd);
                    this.Controls.Add(this.label5);
                    this.Controls.Add(this.tbUserID);
                    this.Controls.Add(this.label4);
                    this.Controls.Add(this.tbPort);
                    this.Controls.Add(this.label3);
                    this.Controls.Add(this.tbSourceName);
                    this.Controls.Add(this.label2);
                    this.Controls.Add(this.tbHostName);
                    this.Controls.Add(this.label1);
                    this.MaximizeBox = false;
                    this.MinimizeBox = false;
                    this.Name = "VirtuosoDotNetDSNForm";
                    this.StartPosition = System.Windows.Forms.FormStartPosition.CenterParent;
                    this.Text = "Add New Data Source";
                    this.ResumeLayout(false);

                }
		#endregion

            private void btnAdd_Click(object sender, System.EventArgs e)
            {
                this.connect_string = String.Format ("HOST={0}:{1};UID={2};PWD={3}",
                    this.tbHostName.Text,
                    this.tbPort.Text,
                    this.tbUserID.Text,
                    this.tbPwd.Text);
                this.source_name = this.tbSourceName.Text;
                this.Hide ();
            }

            private void btnCancel_Click(object sender, System.EventArgs e)
            {
                this.connect_string = null;
                this.source_name = null;
                this.Hide ();
            }
	}
}
