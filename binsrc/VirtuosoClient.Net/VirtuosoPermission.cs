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

using System;
using System.Security;
using System.Security.Permissions;
using System.Text;

#if ODBC_CLIENT
namespace OpenLink.Data.VirtuosoOdbcClient
#elif CLIENT
namespace OpenLink.Data.VirtuosoClient
#else
namespace OpenLink.Data.Virtuoso
#endif
{
	public sealed class VirtuosoPermission : CodeAccessPermission, IUnrestrictedPermission
	{
		private bool isUnrestricted;

		public VirtuosoPermission ()
			: base ()
		{
		}

		public VirtuosoPermission (PermissionState state)
			: base ()
		{
			if (state == PermissionState.Unrestricted)
				isUnrestricted = true;
			else if (state == PermissionState.None)
				isUnrestricted = false;
			else
				throw new ArgumentException ("Invalid PermissionState value", "state");
		}

		public bool IsUnrestricted ()
		{
			return isUnrestricted;
		}

		public override IPermission Copy ()
		{
			VirtuosoPermission copy = new VirtuosoPermission ();
			copy.isUnrestricted = this.isUnrestricted;
			return copy;
		}

		public override IPermission Intersect (IPermission target)
		{
			if (null == target)
				return null;

			if (!(target is VirtuosoPermission))
				throw new ArgumentException ("The object is not VirtuosoPermission", "target");
			VirtuosoPermission that = (VirtuosoPermission) target;

			VirtuosoPermission result = new VirtuosoPermission ();
			result.isUnrestricted = this.isUnrestricted && that.isUnrestricted;
			return result;
		}

		public override bool IsSubsetOf (IPermission target)
		{  
			if (null == target)
				return false;

			if (!(target is VirtuosoPermission))
				throw new ArgumentException ("The object is not VirtuosoPermission", "target");

			return ((VirtuosoPermission) target).isUnrestricted ? true : isUnrestricted == false;
		}

		public override void FromXml (SecurityElement securityElement)
		{
			if (null == securityElement)
				throw new ArgumentNullException ("securityElement");

			string tag = securityElement.Tag;
			if (tag != "IPermission")
				throw new ArgumentException ("Invalid SecurityElement", "securityElement");

			string version = securityElement.Attribute ("version");
			if (version != "1")
				throw new ArgumentException ("Invalid SecurityElement version", "securityElement");

			string unrestricted = securityElement.Attribute ("Unrestricted");
			if (null != unrestricted)
				isUnrestricted = Convert.ToBoolean (unrestricted);
		}

		public override SecurityElement ToXml ()
		{
			SecurityElement securityElement = new SecurityElement ("IPermission");
			Type type = GetType ();
			StringBuilder assemblyName = new StringBuilder (type.Assembly.ToString ());
			assemblyName.Replace ('\"', '\'');
			securityElement.AddAttribute ("class", type.FullName + ", " + assemblyName);
			securityElement.AddAttribute ("version", "1");
			if (isUnrestricted)
				securityElement.AddAttribute ("Unrestricted", "true");
			return securityElement;
		}

		public override IPermission Union (IPermission target)
		{
			if (null == target)
				return Copy ();

			if (!(target is VirtuosoPermission))
				throw new ArgumentException ("The object is not VirtuosoPermission", "target");
			VirtuosoPermission that = (VirtuosoPermission) target;

			VirtuosoPermission result = new VirtuosoPermission ();
			result.isUnrestricted = this.isUnrestricted || that.isUnrestricted;
			return result;
		}
	}
}
