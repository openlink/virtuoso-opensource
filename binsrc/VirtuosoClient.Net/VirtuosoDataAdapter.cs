//  
//  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
//  project.
//  
//  Copyright (C) 1998-2006 OpenLink Software
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

using System;
using System.Data;
using System.Data.Common;
using System.Diagnostics;
#if (!MONO)
using System.Drawing;
using System.ComponentModel;
using System.ComponentModel.Design;
#endif

#if ODBC_CLIENT
namespace OpenLink.Data.VirtuosoOdbcClient
#elif CLIENT
namespace OpenLink.Data.VirtuosoClient
#else
namespace OpenLink.Data.Virtuoso
#endif
{
    public sealed class VirtuosoConstants
    {
        public const string AssemblyVersion = "3.5.2728.1";
        public const string VirtuosoDesignSN = 
            VirtuosoDesignNSPrefix 
            + ", Version=" + AssemblyVersion
            + ", Culture=neutral"
            + ", PublicKeyToken=6654f6917d07cb95"
            ;

        public const string VirtuosoDesignNSPrefix =
            "OpenLink.Data.Virtuoso.Design";
    }
    // 3.5.2721.3
    // - ADO.NET 2.0 hooks
    // 3.5.2171.4
    // - ADO.NET 2.0 addition of ConnectionStringBuilder
    // 3.5.2171.5
    // - fixed RPC errors in numeric and DV_[LONG]VARBINARY 
    // 3.5.2171.6
    // - fixed Mono compatibility error : WeakReference not working.
    /// <summary>
    /// Summary description for VirtuosoDataAdapter.
    /// </summary>
#if (!MONO) // for now Mono doesn't have an IDE
    [Designer (
    VirtuosoConstants.VirtuosoDesignNSPrefix + ".VirtuosoDataAdapterDesigner, " 
         + VirtuosoConstants.VirtuosoDesignSN)]
    [ToolboxBitmap(typeof(VirtuosoDataAdapter), "OpenLink.Data.VirtuosoClient.VirtuosoDataAdapter.bmp") ]
#endif
    public sealed class VirtuosoDataAdapter : DbDataAdapter, IDbDataAdapter
    {
      internal readonly static BooleanSwitch Switch = 
	  new BooleanSwitch ("VirtuosoClient.VirtuosoDataAdaper", "Marshaling");
        private VirtuosoCommand selectCommand;
        private VirtuosoCommand insertCommand;
        private VirtuosoCommand updateCommand;
        private VirtuosoCommand deleteCommand;

        /*
                 * Inherit from Component through DbDataAdapter. The event
                 * mechanism is designed to work with the Component.Events
                 * property. These variables are the keys used to find the
                 * events in the components list of events.
                 */
        static private readonly object EventRowUpdated = new object();
        static private readonly object EventRowUpdating = new object();

        public VirtuosoDataAdapter ()
        {
        }

        public VirtuosoDataAdapter (VirtuosoCommand selectCommand) : this ()
        {
            SelectCommand = selectCommand;
        }

        public VirtuosoDataAdapter (string selectCommandText, VirtuosoConnection selectConnection)
            : this (new VirtuosoCommand (selectCommandText, selectConnection))
        {
        }

        public VirtuosoDataAdapter (string selectCommandText, string selectConnectionString)
            : this (new VirtuosoCommand (selectCommandText, new VirtuosoConnection (selectConnectionString)))
        {
        }

#if !ADONET2
        public VirtuosoCommand SelectCommand 
        {
            get { return selectCommand; }
            set { selectCommand = value; }
        }
#endif

        IDbCommand IDbDataAdapter.SelectCommand 
        {
            get { return selectCommand; }
            set { selectCommand = (VirtuosoCommand) value; }
        }

#if !ADONET2
        public VirtuosoCommand InsertCommand 
        {
            get { return insertCommand; }
            set { insertCommand = value; }
        }
#endif

        IDbCommand IDbDataAdapter.InsertCommand 
        {
            get { return insertCommand; }
            set { insertCommand = (VirtuosoCommand) value; }
        }

#if !ADONET2
        public VirtuosoCommand UpdateCommand 
        {
            get { return updateCommand; }
            set { updateCommand = value; }
        }
#endif

        IDbCommand IDbDataAdapter.UpdateCommand 
        {
            get { return updateCommand; }
            set { updateCommand = (VirtuosoCommand) value; }
        }

#if !ADONET2
        public VirtuosoCommand DeleteCommand 
        {
            get { return deleteCommand; }
            set { deleteCommand = value; }
        }
#endif

        IDbCommand IDbDataAdapter.DeleteCommand 
        {
            get { return deleteCommand; }
            set { deleteCommand = (VirtuosoCommand) value; }
        }

#if MONO
		ITableMappingCollection IDataAdapter.TableMappings
		{
			get { return base.TableMappings; }
		}
#endif

        /*
                 * Implement abstract methods inherited from DbDataAdapter.
                 */
        override protected RowUpdatedEventArgs CreateRowUpdatedEvent(DataRow dataRow, IDbCommand command, StatementType statementType, DataTableMapping tableMapping)
        {
            return new VirtuosoRowUpdatedEventArgs(dataRow, command, statementType, tableMapping);
        }

        override protected RowUpdatingEventArgs CreateRowUpdatingEvent(DataRow dataRow, IDbCommand command, StatementType statementType, DataTableMapping tableMapping)
        {
            Debug.WriteLineIf (CLI.FnTrace.Enabled, "VirtuosoDataAdapter.CreateRowUpdatingEvent()");
            Debug.WriteLineIf (Switch.Enabled, "  tableMapping " + (tableMapping == null ? "==" : "!=") + " null");
            return new VirtuosoRowUpdatingEventArgs(dataRow, command, statementType, tableMapping);
        }

        override protected void OnRowUpdating(RowUpdatingEventArgs value)
        {
            VirtuosoRowUpdatingEventHandler handler = (VirtuosoRowUpdatingEventHandler) Events[EventRowUpdating];
            if ((null != handler) && (value is VirtuosoRowUpdatingEventArgs)) 
            {
                handler(this, (VirtuosoRowUpdatingEventArgs) value);
            }
        }

        override protected void OnRowUpdated(RowUpdatedEventArgs value)
        {
            VirtuosoRowUpdatedEventHandler handler = (VirtuosoRowUpdatedEventHandler) Events[EventRowUpdated];
            if ((null != handler) && (value is VirtuosoRowUpdatedEventArgs)) 
            {
                handler(this, (VirtuosoRowUpdatedEventArgs) value);
            }
        }

        public event VirtuosoRowUpdatingEventHandler RowUpdating
        {
            add { Events.AddHandler(EventRowUpdating, value); }
            remove { Events.RemoveHandler(EventRowUpdating, value); }
        }

        public event VirtuosoRowUpdatedEventHandler RowUpdated
        {
            add { Events.AddHandler(EventRowUpdated, value); }
            remove { Events.RemoveHandler(EventRowUpdated, value); }
        }
/*
        public override DataTable [] FillSchema (DataSet ds, SchemaType schemaType)
        {
            try
            {
                return base.FillSchema (ds, schemaType);
            }
            catch (Exception e)
            {
                System.Diagnostics.Trace.WriteLine (e.StackTrace);
                throw;
            }
        }
*/
    }

    public delegate void VirtuosoRowUpdatingEventHandler(object sender, VirtuosoRowUpdatingEventArgs e);
    public delegate void VirtuosoRowUpdatedEventHandler(object sender, VirtuosoRowUpdatedEventArgs e);

    public class VirtuosoRowUpdatingEventArgs : RowUpdatingEventArgs
    {
        public VirtuosoRowUpdatingEventArgs(DataRow row, IDbCommand command, StatementType statementType, DataTableMapping tableMapping) 
            : base(row, command, statementType, tableMapping) 
        {
            Debug.WriteLineIf (CLI.FnTrace.Enabled, "VirtuosoRowUpdatingEventArgs.ctor()");
            Debug.WriteLineIf (VirtuosoDataAdapter.Switch.Enabled, 
		"  TableMapping " + (TableMapping == null ? "==" : "!=") + " null");
        }

        // Hide the inherited implementation of the command property.
        new public VirtuosoCommand Command
        {
            get  { return (VirtuosoCommand)base.Command; }
            set  { base.Command = value; }
        }
    }

    public class VirtuosoRowUpdatedEventArgs : RowUpdatedEventArgs
    {
        public VirtuosoRowUpdatedEventArgs(DataRow row, IDbCommand command, StatementType statementType, DataTableMapping tableMapping)
            : base(row, command, statementType, tableMapping) 
        {
        }

        // Hide the inherited implementation of the command property.
        new public VirtuosoCommand Command
        {
            get  { return (VirtuosoCommand)base.Command; }
        }
    }
}
