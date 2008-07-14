package virtuoso.jdbc2;

import java.lang.*;
import java.io.*;
import java.util.*;
import java.sql.*;
import virtuoso.sql.RdfBox;

public class VirtuosoRdfBox implements RdfBox
{
    // rdf_box_t
    public short	rb_type;
    public short 	rb_lang;
    public boolean 	rb_is_complete;
    public boolean 	rb_is_outlined;
    public boolean 	rb_chksum_tail;
    public boolean 	rb_is_text_index;
    public long 	rb_ro_id;
    public Object 	rb_box;

    // defaults
    public static final int RDF_BOX_DEFAULT_TYPE = 257;
    public static final int RDF_BOX_DEFAULT_LANG = 257;

    // bit position in flags 
    public static final int RBS_OUTLINED = 0x01;
    public static final int RBS_COMPLETE = 0x02;
    public static final int RBS_HAS_LANG = 0x04;
    public static final int RBS_HAS_TYPE = 0x08;
    public static final int RBS_CHKSUM   = 0x10;
    public static final int RBS_64   	  = 0x20;

    private VirtuosoConnection connection = null;
 
    public VirtuosoRdfBox (VirtuosoConnection connection, Object box, boolean is_complete,  short type, short lang, long ro_id)
    {
	this.connection = connection;
	this.rb_box = box;
	this.rb_type = type;
	this.rb_lang = lang;
	this.rb_is_complete = is_complete;
	this.rb_ro_id = ro_id;
	this.rb_is_outlined = false;
	this.rb_chksum_tail = false;
    }

    public VirtuosoRdfBox (Connection connection, Object box, String type, String lang)
    {
	long ro_id;
	this.connection = (VirtuosoConnection) connection;
	this.rb_box = box;
	ro_id = rdfMakeObj (box, type, lang);
	this.rb_type = getTypeKey (type);
	this.rb_lang = getLangKey (lang);
	this.rb_is_complete = false;
	this.rb_ro_id = ro_id;
	this.rb_is_outlined = false;
	this.rb_chksum_tail = false;
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

    private void fillHashFromSQL (Hashtable ht, Hashtable rev, String sql) 
    {
	try 
	{
	    Statement stmt = this.connection.createStatement ();
	    try 
	    {
	      stmt.execute (sql);

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
      if (this.connection.rdf_type_hash.isEmpty ())
      {
	fillHashFromSQL (this.connection.rdf_type_hash, this.connection.rdf_type_rev, "select RDT_TWOBYTE, RDT_QNAME from DB.DBA.RDF_DATATYPE");
      }
    }

    private void ensureLangHash ()
    {
      if (this.connection.rdf_lang_hash.isEmpty ())
      {
	fillHashFromSQL (this.connection.rdf_lang_hash, this.connection.rdf_lang_rev, "select RL_TWOBYTE, RL_ID from DB.DBA.RDF_LANGUAGE");
      }
    }

    public String getType ()
    {
      String r;
      ensureTypeHash ();
      r = (String) this.connection.rdf_type_hash.get (new Integer (this.rb_type));
      return r;	
    }

    public String getLang ()
    {
      String r;
      ensureLangHash ();
      r = (String) this.connection.rdf_lang_hash.get (new Integer (this.rb_lang));
      return r;
    }

    public String toString ()
    {
	return this.rb_box.toString ();
    }
}

