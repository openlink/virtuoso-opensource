//  
//  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
//  project.
//  
//  Copyright (C) 1998-2017 OpenLink Software
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
using System.Collections;

#if ODBC_CLIENT
namespace OpenLink.Data.VirtuosoOdbcClient
#elif CLIENT
namespace OpenLink.Data.VirtuosoClient
#else
namespace OpenLink.Data.Virtuoso
#endif
{
	public sealed class VirtuosoParameterCollection : 
#if ADONET2
        DbParameterCollection
#else
        MarshalByRefObject, IDataParameterCollection, ICollection, IEnumerable, IList
#endif
	{
		private VirtuosoCommand command;
		private ArrayList items;

		internal VirtuosoParameterCollection (VirtuosoCommand command)
		{
			this.command = command;
			this.items = new ArrayList ();
		}

		//=======================================
		// METHODS / PROPERTIES FROM ICollection
		//=======================================

#if ADONET2
        public override int Count
#else
		public int Count
#endif
		{
			get { return items.Count; }
		}

#if !ADONET2
		bool ICollection.IsSynchronized
		{
			get { return false; }
		}

		object ICollection.SyncRoot
		{
			get { return items.SyncRoot; }
		}
#endif

#if ADONET2
        public override void CopyTo (Array array, int index)
#else
		public void CopyTo (Array array, int index)
#endif
		{
			items.CopyTo (array, index);
		}

		//=======================================
		// METHODS / PROPERTIES FROM IEnumerable
		//=======================================

#if ADONET2
        public override IEnumerator GetEnumerator ()
#else
		public IEnumerator GetEnumerator ()
#endif
		{
			return items.GetEnumerator ();
		}

		//=================================
		// METHODS / PROPERTIES FROM IList
		//=================================


#if !ADONET2
		bool IList.IsFixedSize
		{
			get { return false; }
		}

		bool IList.IsReadOnly
		{
			get { return false; }
		}

		object IList.this[int index] 
		{
			get
			{
				return items[index];
			}
			set
			{
				CheckParameter (value);
				items[index] = value;
			}
		}
#endif


#if ADONET2
        public override int Add (object value)
#else
		public int Add (object value)
#endif
		{
			CheckParameter (value);
			return items.Add (value);
		}

#if ADONET2
        public override void Clear ()
#else
		public void Clear ()
#endif
		{
			items.Clear ();
		}

#if ADONET2
        public override bool Contains (object value)
#else
		public bool Contains (object value)
#endif
		{
			return (-1 != IndexOf (value));
		}

#if ADONET2
        public override int IndexOf (object value)
#else
		public int IndexOf (object value)
#endif
		{
			int index = 0;
			foreach (VirtuosoParameter item in items)
			{
				if (item == value)
					return index;
				index++;
			}
			return -1;
		}

#if ADONET2
        public override void Insert (int index, object value)
#else
		public void Insert (int index, object value)
#endif
		{
			CheckParameter (value);
			items.Insert (index, value);
		}

#if ADONET2
        public override void Remove (object value)
#else
		public void Remove (object value)
#endif
		{
			items.Remove (value);
		}

#if ADONET2
        public override void RemoveAt (int index)
#else
		public void RemoveAt (int index)
#endif
		{
			items.RemoveAt (index);
		}

		//====================================================
		// METHODS / PROPERTIES FROM IDataParameterCollection
		//====================================================

#if !ADONET2
		object IDataParameterCollection.this[string parameterName]
		{
			get
			{
				return items[IndexOf (parameterName)];
			}
			set
			{
				CheckParameter (value);
				items[IndexOf (parameterName)] = value;
			}
	}
#endif

#if ADONET2
        public override bool Contains (string parameterName)
#else
		public bool Contains (string parameterName)
#endif
		{
			return (-1 != IndexOf (parameterName));
		}

#if ADONET2
        public override int IndexOf (string parameterName)
#else
		public int IndexOf (string parameterName)
#endif
		{
			int index = 0;
			foreach (VirtuosoParameter item in this) 
			{
				if (0 == Platform.CaseInsensitiveCompare (item.ParameterName, parameterName))
					return index;
				index++;
			}
			return -1;
		}

#if ADONET2
        public override void RemoveAt (string parameterName)
#else
		public void RemoveAt (string parameterName)
#endif
		{
			items.RemoveAt (IndexOf (parameterName));
		}

		//======================
		// METHODS / PROPERTIES 
		//======================

#if !ADONET2
		public VirtuosoParameter this[int index]
		{
			get
			{
				return (VirtuosoParameter) items[index];
			}
			set
			{
				CheckParameter (value);
				items[index] = value;
			}
		}
#endif

#if !ADONET2
        public VirtuosoParameter this[string parameterName]
		{
			get
			{
				return (VirtuosoParameter) items[IndexOf (parameterName)];
			}
			set
			{
				CheckParameter (value);
				items[IndexOf (parameterName)] = value;
			}
		}
#endif

        public int Add (VirtuosoParameter value)
		{
			CheckParameter (value);
			return items.Add (value);
		}

		public int Add (string parameterName, VirtDbType dbType)
		{
			return Add (new VirtuosoParameter (parameterName, dbType));
		}

		public int Add (string parameterName, object value)
		{
			return Add (new VirtuosoParameter (parameterName, value));
		}

		public int Add (string parameterName, VirtDbType dbType, int size)
		{
			return Add (new VirtuosoParameter (parameterName, dbType, size));
		}

		public int Add (string parameterName, VirtDbType dbType, int size, string sourceColumn)
		{
			return Add (new VirtuosoParameter (parameterName, dbType, size, sourceColumn));
		}

		private void CheckParameter (object value)
		{
			if (value == null)
				throw new ArgumentNullException ("value");
			if (!(value is VirtuosoParameter))
				throw new InvalidCastException ("The parameter is not a VirtuosoParameter object.");
			CheckParameterInner ((VirtuosoParameter) value);
		}

		private void CheckParameter (VirtuosoParameter value)
		{
			if (value == null)
				throw new ArgumentNullException ("value");
			CheckParameterInner (value);
		}

		private void CheckParameterInner (VirtuosoParameter value)
		{
			string name = value.ParameterName;
			if (name == null || name.Length == 0)
				throw new ArgumentException("parameter must be named");
        }
        #region ADO.NET 2.0
#if ADONET2
        public override bool IsFixedSize
        {
            get {
                // TODO: full implementation needed.
                return true;
            }
        }
        public override bool IsReadOnly
        {
            get {
                // TODO: full implementation needed.
                return false;
            }
        }
        public override bool IsSynchronized
        {
            get {
                // TODO: full implementation needed.
                return false;
            }
        }

        public override object SyncRoot
        {
            get
            {
                //TODO: full implementation needed
                throw new NotImplementedException ();
            }
        }


        public override void AddRange(Array values)
        {
            //TODO: full implementation needed
            throw new NotImplementedException();
        }


// jch ???
//        protected override int CheckName(string parameterName)
//        {
//            //TODO: full implementation needed
//            throw new NotImplementedException();
//        }

		protected override DbParameter GetParameter (int index)
		{
				return (DbParameter) items[index];
        }

		protected override DbParameter GetParameter (string parameterName)
		{
				int index = IndexOf (parameterName);
				DbParameter ret = index == -1 ? null : this [index];
				return ret;
        }

		protected override void SetParameter (int index, DbParameter value)
		{
				CheckParameter (value);
				items[index] = value;
		}

		protected override void SetParameter (string parameterName, DbParameter value)
		{
				CheckParameter (value);
				this [IndexOf(parameterName)] = (VirtuosoParameter) value;
		}
#endif
        #endregion

    }
}
