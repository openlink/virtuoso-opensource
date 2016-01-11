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
// 
// $Id$
//

#if (!MONO)
using System;
using System.Data;
using System.Data.Common;
using System.Diagnostics;
using System.ComponentModel;
using System.ComponentModel.Design;
using System.Runtime.InteropServices;

#if ODBC_CLIENT
namespace OpenLink.Data.VirtuosoOdbcClient.Design
#elif CLIENT
namespace OpenLink.Data.VirtuosoClient.Design
#else
namespace OpenLink.Data.Virtuoso.Design
#endif
{
	/// <summary>
	/// Summary description for VirtuosoDataAdapter.
	/// </summary>
    public sealed class VirtuosoDataAdapterDesigner : System.ComponentModel.Design.ComponentDesigner

    {
        private VirtuosoDataAdapter _adapter;

        public VirtuosoDataAdapterDesigner()
        {
        }

        // This method provides an opportunity to perform processing when a designer is initialized.
        // The component parameter is the component that the designer is associated with.
        public override void Initialize(System.ComponentModel.IComponent component)
        {
            // Always call the base Initialize method in an override of this method.
            base.Initialize(component);
            System.Reflection.Assembly a = component.GetType ().Assembly;
            System.Reflection.Assembly b = typeof (VirtuosoDataAdapter).Assembly;
            _adapter = (VirtuosoDataAdapter) component;
        }

        // This method is invoked when the associated component is double-clicked.
        public override void DoDefaultAction()
        {
            this.onGenerateDataSet (null, null);
        }

        // This method provides designer verbs.
        public override System.ComponentModel.Design.DesignerVerbCollection Verbs
        {
            get
            {
                return new DesignerVerbCollection( 
                    new DesignerVerb[] 
                      {
                          new DesignerVerb(
                            "Generate DataSet ...", 
                            new EventHandler(this.onGenerateDataSet)
                          ) 
                      } 
                    );
            }
        }

        // Event handling method for the example designer verb
        private void onGenerateDataSet(object sender, EventArgs e)
        {
            IDesignerHost host = (IDesignerHost) GetService(typeof(IDesignerHost));
            IComponentChangeService c = (IComponentChangeService) GetService(typeof(IComponentChangeService));
            object item = GetService(typeof(EnvDTE.ProjectItem));
            VirtuosoGenerateDataSet dsDlg = new VirtuosoGenerateDataSet (host, item, _adapter);
            dsDlg.ShowDialog ();
        }
    }
}
#endif
