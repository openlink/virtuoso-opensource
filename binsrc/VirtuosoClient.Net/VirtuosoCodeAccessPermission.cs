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
//
// $Id$
//

using System;
using System.Data;
using System.Data.Common;
using System.Security;
using System.Security.Permissions;


#if ODBC_CLIENT
namespace OpenLink.Data.VirtuosoOdbcClient
#elif CLIENT
namespace OpenLink.Data.VirtuosoClient
#else
namespace OpenLink.Data.Virtuoso
#endif
{
  [Serializable()]
  public sealed class VirtuosoCodeAccessPermission : CodeAccessPermission, IUnrestrictedPermission
  {
      #region CodeAccessPermission overrides
      internal VirtuosoCodeAccessPermission() : base ()
      {
      }

      public override IPermission Copy()
      {
          return new VirtuosoCodeAccessPermission();
      }

      public override bool IsSubsetOf(IPermission target)
      {
          if (target == null)
          {
              return false;
          }

          if (target is VirtuosoCodeAccessPermission)
              return true;
          else
              return false;

      }

      public override IPermission Intersect(IPermission target)
      {
          if (target == null)
              return null;

          return this.Copy();
      }


      public override SecurityElement ToXml()
      {
          SecurityElement esd = new SecurityElement("IPermission");
          String name = typeof(VirtuosoCodeAccessPermission).AssemblyQualifiedName;
          esd.AddAttribute("class", name);
          esd.AddAttribute("version", "1.0");

          return esd;
      }

      public override void FromXml(SecurityElement e)
      {
      }
      #endregion

      #region IUnrestrictedPermission overrides
      public bool IsUnrestricted()
      {
          return true;
      }
      #endregion
  }
}
