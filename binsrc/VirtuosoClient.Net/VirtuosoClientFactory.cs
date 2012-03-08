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

using System;
using System.Data;
using System.Diagnostics;
#if ADONET2
using System.Data.Common;
using System.Security;
using System.Security.Permissions;
#endif


#if ODBC_CLIENT
namespace OpenLink.Data.VirtuosoOdbcClient
#elif CLIENT
namespace OpenLink.Data.VirtuosoClient
#else
namespace OpenLink.Data.Virtuoso
#endif
{
	public sealed class VirtuosoClientFactory : DbProviderFactory
	{
	  private VirtuosoClientFactory () 
      {
      }

        public readonly static VirtuosoClientFactory Instance = new VirtuosoClientFactory ();
        #region DbProviderFactory overrides
#if false//jch
	  public override DbProviderSupportedClasses SupportedClasses {
	    get
	      {
		return  
		    DbProviderSupportedClasses.DbCommand
		    & DbProviderSupportedClasses.DbConnection
		    & DbProviderSupportedClasses.DbDataAdapter
		    & DbProviderSupportedClasses.DbParameter
            & DbProviderSupportedClasses.DbConnectionStringBuilder
            & DbProviderSupportedClasses.DbCommandBuilder
            & DbProviderSupportedClasses.CodeAccessPermission
            /*TODO:
		    + DbProviderSupportedClasses.SourceEnumerator
		    */
            ;
	      }

	  }
#endif

	  public override DbCommand CreateCommand ()
	    {
	      return new VirtuosoCommand ();
	    }
	  public override DbCommandBuilder CreateCommandBuilder ()
	    {
	      return new VirtuosoCommandBuilder (); 
	    }
	  public override DbConnection CreateConnection ()
	    {
	      return new VirtuosoConnection ();
	    }
	  public override DbConnectionStringBuilder CreateConnectionStringBuilder ()
	    {
            return new VirtuosoConnectionStringBuilder();
        }
	  public override DbDataAdapter CreateDataAdapter ()
	    {
	      return new VirtuosoDataAdapter ();
	    }
	  public override DbDataSourceEnumerator CreateDataSourceEnumerator ()
	    {
	      //TODO: add code here
	      throw new NotImplementedException ("VirtuosoClientFactory:CreateDataSourceEnumerator"); 
	    }
	  public override DbParameter CreateParameter ()
	    {
	      return new VirtuosoParameter ();
	    }
	  public override CodeAccessPermission CreatePermission (PermissionState state)
	    {
            return new VirtuosoCodeAccessPermission();
        }
#endregion
	}
}
