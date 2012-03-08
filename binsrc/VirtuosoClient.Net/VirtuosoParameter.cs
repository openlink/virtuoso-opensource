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
#if ADONET2
using System.Data.Common;
#endif


#if ODBC_CLIENT
namespace OpenLink.Data.VirtuosoOdbcClient
#elif CLIENT
namespace OpenLink.Data.VirtuosoClient
#else
namespace OpenLink.Data.Virtuoso
#endif
{
	public sealed class VirtuosoParameter : 
#if ADONET2
        DbParameter, IDataParameter, ICloneable
#else    
	    MarshalByRefObject, IDbDataParameter, IDataParameter, ICloneable
#endif
	{
		internal static readonly DataType defaultType = DataTypeInfo.NVarChar;

		internal string paramName;
		internal object paramData;
		internal DataType paramType;
		internal BufferType bufferType;

		private ParameterDirection direction = ParameterDirection.Input;
		private bool isNullable = false;
		private byte precision = 0;
		private byte scale = 0;
		private int size = 0;
		private string sourceColumn;
		private DataRowVersion sourceVersion = DataRowVersion.Current;

		public VirtuosoParameter ()
		{
		}

		public VirtuosoParameter (string parameterName, object value)
		{
			this.ParameterName = parameterName;
			this.Value = value;
		}

		public VirtuosoParameter (string parameterName, VirtDbType vdbType)
		{
			this.ParameterName = parameterName;
			this.VirtDbType = vdbType;
		}

		public VirtuosoParameter (string parameterName, VirtDbType vdbType, int size)
		{
			this.ParameterName = parameterName;
			this.VirtDbType = vdbType;
			this.Size = size;
		}

		public VirtuosoParameter (string parameterName, VirtDbType vdbType, int size, string sourceColumn)
		{
			this.ParameterName = parameterName;
			this.VirtDbType = vdbType;
			this.Size = size;
			this.SourceColumn = sourceColumn;
		}

		public VirtuosoParameter (string parameterName, VirtDbType vdbType, int size,
			ParameterDirection direction, Boolean isNullable, Byte precision, Byte scale,
			string sourceColumn, DataRowVersion sourceVersion, object value)
		{
			this.ParameterName = parameterName;
			this.VirtDbType = vdbType;
			this.Size = size;
			this.Direction = direction;
			this.IsNullable = isNullable;
			this.Precision = precision;
			this.Scale = scale;
			this.SourceColumn = sourceColumn;
			this.SourceVersion = sourceVersion;
			this.Value = value;
		}

#if ADONET2
		public override DbType DbType
#else
		public DbType DbType
#endif
		{
			get
			{
				return GetDataType().dbType;
			}
			set
			{
				paramType = DataTypeInfo.MapDbType (value);
				if (paramType == null)
					throw new ArgumentOutOfRangeException ("Invalid or unsupported DbType value.");
				bufferType = null;
			}
		}

#if ADONET2
		public override ParameterDirection Direction 
#else
		public ParameterDirection Direction 
#endif
		{
			get
			{
				return direction;
			}
			set
			{
				switch (direction)
				{
					case ParameterDirection.Input:
					case ParameterDirection.InputOutput:
					case ParameterDirection.Output:
					case ParameterDirection.ReturnValue:
						direction = value;
						break;
					default:
						throw new ArgumentException ("Invalid Direction value.");
				}
			}
		}

#if ADONET2
        public override bool IsNullable 
#else
        public bool IsNullable 
#endif
        {
            get { return isNullable; }
			set { isNullable = value; }
		}

#if ADONET2
		public override string ParameterName 
#else
		public string ParameterName 
#endif
		{
			get
			{
				return paramName != null ? paramName : "";
			}
			set
			{
				paramName = value;
			}
		}

		public byte Precision
		{
			get	{ return precision; }
			set	{ precision = value; }
		}

		public byte Scale
		{
			get	{ return scale;	}
			set	{ scale = value; }
		}

#if ADONET2
		public override int Size
#else
		public int Size
#endif
		{
			get
			{
				return size;
			}
			set
			{
				if (size < 0)
					throw new ArgumentException ("Invalid Size value.");
				size = value;
			}
		}

#if ADONET2
		public override string SourceColumn 
#else
		public string SourceColumn 
#endif
		{
			get { return sourceColumn != null ? sourceColumn : ""; }
			set { sourceColumn = value; }
		}

#if ADONET2
		public override DataRowVersion SourceVersion 
#else
		public DataRowVersion SourceVersion 
#endif
		{
			get
			{
				return sourceVersion;
			}
			set
			{
				switch (value)
				{
					case DataRowVersion.Current:
					case DataRowVersion.Default:
					case DataRowVersion.Original:
					case DataRowVersion.Proposed:
						sourceVersion = value;
						break;
					default:
						throw new ArgumentException ("Invalid SourceVersion value.");
				}
			}
		}

#if ADONET2
		public override object Value 
#else
		public object Value 
#endif
		{
			get
			{
				return paramData;
			}
			set
			{
				paramData = value;
				bufferType = null;
			}
		}

		public VirtDbType VirtDbType
		{
			get
			{
				return GetDataType().vdbType;
			}
			set
			{
				paramType = DataTypeInfo.MapVirtDbType (value);
				if (paramType == null)
					throw new SystemException ("Invalid data type");
				bufferType = null;
			}
		}

		public override string ToString ()
		{
			return ParameterName;
		}

		object ICloneable.Clone ()
		{
			VirtuosoParameter p = new VirtuosoParameter ();
			p.paramName = paramName;
			if (paramData != null && paramData is ICloneable)
				p.paramData = ((ICloneable) paramData).Clone ();
			else
				p.paramData = paramData;
			p.paramType = paramType;
			p.bufferType = bufferType;
			p.direction = direction;
			p.isNullable = isNullable;
			p.precision = precision;
			p.scale = scale;
			p.size = size;
			p.sourceColumn = sourceColumn;
			p.sourceVersion = sourceVersion;
			return p;
		}

		private DataType GetDataType ()
		{
			return paramType != null ? paramType : defaultType;
		}

#region ADO.NET 2.0
#if ADONET2
        
        public override void  ResetDbType()
        {
 	      paramType = null;
        }

        //TODO: check/extend this imp
// jch ???
//        int offset;
//        public override int Offset
//        {
//            get
//            {
//                return offset;
//            }
//
//            set
//            {
//                offset = value;
//            }
//        }

        //TODO: check/extend this imp
        bool sourceColumnNullMapping;
        public override bool SourceColumnNullMapping
        {
            get
            {
                return sourceColumnNullMapping;
            }

            set
            {
                sourceColumnNullMapping = value;
            }
        }


// jch ~??
//
//        public override void CopyTo(DbParameter destination)
//        {
//            VirtuosoParameter p = (VirtuosoParameter)destination;
//            p.paramName = paramName;
//            if (paramData != null && paramData is ICloneable)
//                p.paramData = ((ICloneable)paramData).Clone();
//            else
//                p.paramData = paramData;
//            p.paramType = paramType;
//            p.bufferType = bufferType;
//            p.direction = direction;
//            p.isNullable = isNullable;
//            p.precision = precision;
//            p.scale = scale;
//            p.size = size;
//            p.sourceColumn = sourceColumn;
//            p.sourceVersion = sourceVersion;
//        }
#endif
#endregion
	}
}
