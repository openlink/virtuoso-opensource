//  
//  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
//  project.
//  
//  Copyright (C) 1998-2012 OpenLink Software
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
using System.ComponentModel;
using System.Drawing.Design;
using System.Windows.Forms;
namespace OpenLink.Data.Virtuoso.Design
{
    public sealed class VirtuosoConnectionStringEditor  : System.Drawing.Design.UITypeEditor
    {
        //TODO: name ? private String m_name;

        #region constructor
        public VirtuosoConnectionStringEditor ()
        {
           //TODO: name m_name = "haha";
        }
        #endregion

        #region UITypeEdtior overrides
        public override object EditValue(
            ITypeDescriptorContext context,
            IServiceProvider provider,
            object value
            )
        {
            VirtuosoDotNetDSNForm f = new VirtuosoDotNetDSNForm ("", (string) value);
            f.ShowDialog ();
            if (f.ConnectString != null)
            {
                value = f.ConnectString;
            }
            f.Close ();
            return value;
        }

        public override UITypeEditorEditStyle GetEditStyle(
            ITypeDescriptorContext context
            )
        {
            return UITypeEditorEditStyle.Modal;
        }
        #endregion
    }
}
#endif