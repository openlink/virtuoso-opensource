//  
//  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
//  project.
//  
//  Copyright (C) 1998-2014 OpenLink Software
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
using System.Diagnostics;
using System.Text;
using System.Collections;
using System.Collections.Generic;

#if ODBC_CLIENT
namespace OpenLink.Data.VirtuosoOdbcClient
#elif CLIENT
namespace OpenLink.Data.VirtuosoClient
#else
namespace OpenLink.Data.Virtuoso
#endif
{

  internal enum SqlRdfBoxFlags {
    	RBS_OUTLINED = 0x01,
        RBS_COMPLETE = 0x02,
        RBS_HAS_LANG = 0x04,
        RBS_HAS_TYPE = 0x08,
        RBS_CHKSUM   = 0x10,
        RBS_64       = 0x20,
  }

  public sealed class SqlRdfBox
    {
      internal const int DEFAULT_TYPE = 257;
      internal const int DEFAULT_LANG = 257;

      private short  rb_type;
      private short  rb_lang;
      private bool   rb_is_complete;
      private bool   rb_is_outlined;
      private bool   rb_chksum_tail;
      private bool   rb_is_text_index;
      private long   rb_ro_id;
      private object rb_box;

      private ManagedConnection connection = null;

      internal SqlRdfBox (ManagedConnection connection, object box, bool is_complete, short rtype, short lang, long ro_id)
      {
	Debug.WriteLineIf (CLI.FnTrace.Enabled, "SqlRdfBox.ctor (connection, box, is_complete, rtype, lang, ro_id)");
	this.connection = connection;
	this.rb_box = box;
	this.rb_type = rtype;
	this.rb_lang = lang;
	this.rb_is_complete = is_complete;
	this.rb_ro_id = ro_id;
	this.rb_is_outlined = false;
	this.rb_chksum_tail = false;
      }

      internal SqlRdfBox (ManagedConnection connection, object box, string rtype, string lang)
      {
	Debug.WriteLineIf (CLI.FnTrace.Enabled, "SqlRdfBox.ctor (connection, box, rtype, lang)");
	long ro_id;
	this.connection = connection;
	this.rb_box = box;
	ro_id = rdfMakeObj (box, rtype, lang);
	this.rb_type = GetTypeKey (rtype);
	this.rb_lang = GetLangKey (lang);
	this.rb_is_complete = false;
	this.rb_ro_id = ro_id;
	this.rb_is_outlined = false;
	this.rb_chksum_tail = false;
      }



      private long rdfMakeObj (object box, string rtype, string lang)
      {
	long ro_id = 0;
	VirtuosoParameterCollection p0 = new VirtuosoParameterCollection (null);
        p0.Add("box", box);
	p0.Add("type", rtype);
        p0.Add("lang", lang);

	ManagedCommand cmd0 = new ManagedCommand (connection);
	cmd0.SetParameters (p0);
	try
	{
		cmd0.Execute ("DB.DBA.RDF_MAKE_OBJ_OF_TYPEDSQLVAL (?, ?, ?)");
	}
	finally
	{
		cmd0.CloseCursor (true);
		cmd0.Dispose ();
	}

	VirtuosoParameterCollection p1 = new VirtuosoParameterCollection (null);
        p1.Add("box", box);

	ManagedCommand cmd1 = new ManagedCommand (connection);
	cmd1.SetParameters (p1);
	try
	{
		cmd1.Execute ("select rdf_box_ro_id (?)");
                while(cmd1.Fetch())
                {
		    object data = cmd1.GetColumnData (0, cmd1.GetColumnMetaData ());
		    if (data != null)
			  ro_id = (long) data;
                }
	}
	finally
	{
		cmd1.CloseCursor (true);
		cmd1.Dispose ();
	}
	return ro_id;
      }

      internal short GetLangKey (string lang)
      {
        object k = null;  	
        if (lang == null)
	        return (short) DEFAULT_LANG;
        ensureLangHash ();
        k = connection.rdf_lang_rev[lang];
        return (k != null ? (short)k : (short)DEFAULT_LANG);
      }

      internal short GetTypeKey (string type)
      { 
        object k = null; 	
        if (type == null)
	        return (short) DEFAULT_TYPE;
        ensureTypeHash ();
        k = connection.rdf_type_rev[type];
        return (k != null ? (short)k : (short) DEFAULT_TYPE);
      }

      private void fillHashFromSQL (Dictionary<int,string> ht, Hashtable rev, string sql) 
      {
	ManagedCommand cmd = new ManagedCommand (connection);
	cmd.SetParameters (null);
	try
	{
		cmd.Execute (sql);
                while(cmd.Fetch())
                {
                    int k = 0;
                    string v = null;
		    object data = cmd.GetColumnData (0, cmd.GetColumnMetaData ());
		    if (data != null)
			  k = (int) data;
		    data = cmd.GetColumnData (1, cmd.GetColumnMetaData ());
		    if (data != null && data is string)
			  v = (string) data;
		    ht[k] =  v;
                    rev[v] = k;
                }
	}
	finally
	{
		cmd.CloseCursor (true);
		cmd.Dispose ();
	}
      }

      private void ensureTypeHash ()
      {
        if (connection.rdf_type_hash.Count == 0)
        {
	        fillHashFromSQL (connection.rdf_type_hash, connection.rdf_type_rev, "select RDT_TWOBYTE, RDT_QNAME from DB.DBA.RDF_DATATYPE");
        }
      }

      private void ensureLangHash ()
      {
        if (connection.rdf_lang_hash.Count == 0)
        {
	        fillHashFromSQL (connection.rdf_lang_hash, connection.rdf_lang_rev, "select RL_TWOBYTE, RL_ID from DB.DBA.RDF_LANGUAGE");
        }
      }

      public string StrType 
      {
        get {
        	ensureTypeHash ();
            string s;
            if (connection.rdf_type_hash.TryGetValue(rb_type, out s))
                return s;
            else
                return null;
	}
      }

      public string StrLang 
      {
        get {
          	ensureLangHash ();
            string s;
            if (connection.rdf_lang_hash.TryGetValue(rb_lang, out s))
                return s;
            else
                return null;
	}
      }

      public object Value 
      {
        get {
        	return rb_box;
	}
      }

      public override string ToString() 
      {
	Debug.WriteLineIf (CLI.FnTrace.Enabled, "SqlRdfBox.ToString ()");
        return rb_box.ToString();
      }

    }
}
