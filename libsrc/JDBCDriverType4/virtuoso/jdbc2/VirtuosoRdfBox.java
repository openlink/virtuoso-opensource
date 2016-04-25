/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2016 OpenLink Software
 *
 *  This project is free software; you can redistribute it and/or modify it
 *  under the terms of the GNU General Public License as published by the
 *  Free Software Foundation; only version 2 of the License, dated June 1991.
 *
 *  This program is distributed in the hope that it will be useful, but
 *  WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
 *  General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License along
 *  with this program; if not, write to the Free Software Foundation, Inc.,
 *  51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA
 *
 */

package virtuoso.jdbc2;

import java.lang.*;
import java.io.*;
import java.util.*;
import java.sql.*;
import virtuoso.sql.RdfBox;

public class VirtuosoRdfBox implements RdfBox
{
    static final String gYear = "http://www.w3.org/2001/XMLSchema#gYear";
    static final String gYearMonth = "http://www.w3.org/2001/XMLSchema#gYearMonth";

    // rdf_box_t
    public short	rb_type;
    public short 	rb_lang;
    public boolean 	rb_is_complete;
    public boolean 	rb_is_outlined;
    public boolean 	rb_chksum_tail;
    public boolean 	rb_is_text_index;
    public boolean 	rb_id_only;
    public long 	rb_ro_id;
    public Object 	rb_box;

    // defaults
    public static final int RDF_BOX_DEFAULT_TYPE = 257;
    public static final int RDF_BOX_DEFAULT_LANG = 257;
    public static final int RDF_BOX_GEO_TYPE = 256;

    // bit position in flags
    public static final int RBS_OUTLINED = 0x01;
    public static final int RBS_COMPLETE = 0x02;
    public static final int RBS_HAS_LANG = 0x04;
    public static final int RBS_HAS_TYPE = 0x08;
    public static final int RBS_CHKSUM   = 0x10;
    public static final int RBS_64   	  = 0x20;
    public static final int RBS_SKIP_DTP = 0x40;
    public static final int RBS_EXT_TYPE = 0x80;

    private VirtuosoConnection connection = null;

    public VirtuosoRdfBox (VirtuosoConnection connection, Object box, boolean is_complete, boolean id_only, short type, short lang, long ro_id)
    {
	this.connection = connection;

        if (box instanceof DateObject)
          this.rb_box = ((DateObject)box).getValue(true);
        else
	  this.rb_box = box;

	this.rb_type = type;
	this.rb_lang = lang;
	this.rb_is_complete = is_complete;
	this.rb_ro_id = ro_id;
	this.rb_is_outlined = false;
	this.rb_chksum_tail = false;
        this.rb_id_only = id_only;
    }

    public VirtuosoRdfBox (Connection connection, Object box, String type, String lang)
    {
	long ro_id;
	this.connection = (VirtuosoConnection) connection;

        if (box instanceof DateObject)
          this.rb_box = ((DateObject)box).getValue(true);
        else
	  this.rb_box = box;

	ro_id = rdfMakeObj (this.rb_box, type, lang);
	this.rb_type = getTypeKey (type);
	this.rb_lang = getLangKey (lang);
	this.rb_is_complete = false;
	this.rb_ro_id = ro_id;
	this.rb_is_outlined = false;
	this.rb_chksum_tail = false;
        this.rb_id_only = false;
    }

    private long rdfMakeObj (Object box, String type, String lang)
    {
	long ro_id = 0;
	try
	{
	    VirtuosoPreparedStatement ps = (VirtuosoPreparedStatement) this.connection.prepareStatement
		("DB.DBA.RDF_MAKE_OBJ_OF_TYPEDSQLVAL (?, ?, ?)");
	    ps.setObject (1, box);
	    ps.setString (2, type);
	    ps.setString (3, lang);

	    VirtuosoPreparedStatement ro  = (VirtuosoPreparedStatement) this.connection.prepareStatement
		("select rdf_box_ro_id (?)");
	    ro.setObject (1, box);
	    try
	    {
		ps.executeQuery();
		ResultSet rs = ro.executeQuery();
		while(rs.next());
		{
		    long rc = rs.getLong (1);
		    ro_id = rc;
		}
	        ps.close ();
		this.connection.rdf_lang_hash.clear ();
		this.connection.rdf_type_hash.clear ();
		this.connection.rdf_lang_rev.clear ();
		this.connection.rdf_type_rev.clear ();
	    }
	    catch (SQLException e)
	    {
	    }
	}
	catch (VirtuosoException e)
	{
	}
	return ro_id;
    }

    public short getLangKey (String lang)
    {
      Integer k;
      if (lang == null)
	return (short) RDF_BOX_DEFAULT_LANG;
      ensureLangHash ();
      k = (Integer) this.connection.rdf_lang_rev.get (lang);
      return (k != null ? k.shortValue () : (short)RDF_BOX_DEFAULT_LANG);
    }

    public short getTypeKey (String type)
    {
      Integer k;
      if (type == null)
	return (short) RDF_BOX_DEFAULT_TYPE;
      ensureTypeHash ();
      k = (Integer) this.connection.rdf_type_rev.get (type);
      return (k != null ? k.shortValue () : (short) RDF_BOX_DEFAULT_TYPE);
    }

#if JDK_VER >= 16
    private void fillHashFromSQL (Hashtable<Integer,String> ht, Hashtable<String,Integer> rev, String sql) 
#else
    private void fillHashFromSQL (Hashtable ht, Hashtable rev, String sql) 
#endif
    {
	try
	{
	    Statement stmt = this.connection.createStatement ();
	    try
	    {
	      stmt.execute (sql);
	      stmt.setFetchSize(200);

	      ResultSet rs = stmt.getResultSet ();
	      while (rs.next ())
	      {
		  Integer k = (Integer) rs.getObject (1);
		  String  v = rs.getString (2);
		  ht.put (k, v);
		  rev.put (v, k);
	      }
	      stmt.close();
	    }
	    catch (SQLException e)
	    {
	    }
	}
	catch (VirtuosoException e)
	{
	}
    }

    private void ensureTypeHash ()
    {
      if (!this.connection.rdf_type_loaded)
      {
	fillHashFromSQL (this.connection.rdf_type_hash, this.connection.rdf_type_rev, "select RDT_TWOBYTE, RDT_QNAME from DB.DBA.RDF_DATATYPE");
	this.connection.rdf_type_loaded = true;
      }
    }

    private void ensureLangHash ()
    {
      if (!this.connection.rdf_lang_loaded)
      {
	fillHashFromSQL (this.connection.rdf_lang_hash, this.connection.rdf_lang_rev, "select RL_TWOBYTE, RL_ID from DB.DBA.RDF_LANGUAGE");
	this.connection.rdf_lang_loaded = true;
      }
    }

    private String _getType ()
    {
      ensureTypeHash ();
      return (String) this.connection.rdf_type_hash.get (new Integer (this.rb_type));
    }

    public String getType ()
    {
      if (this.rb_type == RDF_BOX_DEFAULT_TYPE)
        return null;

      String r = _getType();
      if (r == null) {
        synchronized(connection) {
          this.connection.rdf_type_loaded = false;
          r = _getType();
        }
      }
      return r;
    }

    private String _getLang ()
    {
      ensureLangHash ();
      return (String) this.connection.rdf_lang_hash.get (new Integer (this.rb_lang));
    }

    public String getLang ()
    {
      if (this.rb_lang == RDF_BOX_DEFAULT_LANG)
        return null;

      String r = _getLang();
      if (r == null) {
        synchronized(connection) {
          this.connection.rdf_lang_loaded = false;
          r = _getLang();
        }
      }
      return r;
    }

    public String toString ()
    {
        String retVal = "NULL";
        if (this.rb_box != null) {
          String o_type = getType();

          if (o_type!=null && o_type.equals(gYear)) 
          {
            if (rb_box instanceof VirtuosoDate) 
              retVal = ((VirtuosoDate) rb_box).toXSD_String().substring(0,4);
            else if (rb_box instanceof VirtuosoTimestamp)
              retVal = ((VirtuosoTimestamp) rb_box).toXSD_String().substring(0,4);
            else
    	      retVal = this.rb_box.toString ();
    	  } 
    	  else if (o_type!=null && o_type.equals(gYearMonth)) 
    	  {
            if (rb_box instanceof VirtuosoDate) 
              retVal = ((VirtuosoDate) rb_box).toXSD_String().substring(0,7);
            else if (rb_box instanceof VirtuosoTimestamp)
              retVal = ((VirtuosoTimestamp) rb_box).toXSD_String().substring(0,7);
            else
    	      retVal = this.rb_box.toString ();
          } else {
    	    retVal = this.rb_box.toString ();
          }
        }
        return retVal;
    }
}

