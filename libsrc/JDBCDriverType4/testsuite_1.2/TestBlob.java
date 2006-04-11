// Copyright © 1998-2000 Enterworks, Inc., All rights reserved
package testsuite;

import java.util.*;
import java.io.*;
import java.sql.*;

public class TestBlob
{

  // ************************************************************
  public static void main(String[] args) throws Exception
  {


     System.out.println("driver");
     Connection conn = null;
     if (args.length == 0)
     {
        System.err.println("Usage: TestEmpty ora | eds | edsj | ms7 | tds");
        System.exit(1);
     }
     System.out.println("connect");
     if (args[0].equals("eds"))
     {
        Class.forName("sun.jdbc.odbc.JdbcOdbcDriver");
        conn = DriverManager.getConnection("jdbc:odbc:Local ES","EWSYS","EWSYS");
     }

     else if (args[0].equals("edsj"))
     {
        Class.forName("virtuoso.jdbc.Driver");
        // conn = DriverManager.getConnection ("jdbc:virtuoso://localhost:1111","EWSYS","EWSYS");
        conn = DriverManager.getConnection ("jdbc:virtuoso://localhost:1111/timeout=60","dba","dba");
     }
     else if (args[0].equals("ora"))
     {
        Class.forName("oracle.jdbc.driver.OracleDriver");
        conn = DriverManager.getConnection ("jdbc:oracle:thin:@localhost:1521:ent70071","EWSYS","EWSYS");
     }
     else if (args[0].equals("ms7"))
     {
        Class.forName("sun.jdbc.odbc.JdbcOdbcDriver");
        conn = DriverManager.getConnection("jdbc:odbc:Local ES MS7","EWSYS","EWSYS");
     }
     else if (args[0].equals("tds"))
     {
        DriverManager.setLogStream(System.out);
        Class.forName("com.thinweb.tds.Driver");
        conn = DriverManager.getConnection("jdbc:twtds:sqlserver://sgaetjen/EWSYS","EWSYS","EWSYS");
     }
     else if (args[0].equals("spr"))
     {
        DriverManager.setLogStream(System.out);
        Class.forName("com.inet.tds.TdsDriver");
        conn = DriverManager.getConnection("jdbc:inetdae7:sgaetjen","EWSYS","EWSYS");
     }
     conn.setAutoCommit(false);
     System.out.println( "DRIVER NAME:" + conn.getMetaData().getDriverName() );
     System.out.println( "DRIVER VER:" + conn.getMetaData().getDriverVersion() );

     System.out.println("(TRANSACTION_READ_COMMITTED) :" + Connection.TRANSACTION_READ_COMMITTED);
     System.out.println("(TRANSACTION_READ_UNCOMMITTED) :" + Connection.TRANSACTION_READ_UNCOMMITTED);
     System.out.println("(TRANSACTION_REPEATABLE_READ) :" + Connection.TRANSACTION_REPEATABLE_READ);
     System.out.println("(TRANSACTION_SERIALIZABLE) :" + Connection.TRANSACTION_SERIALIZABLE);
     System.out.println("(TRANSACTION_NONE) :" + Connection.TRANSACTION_NONE);

     int transactionIsolation = conn.getTransactionIsolation();
     System.out.println("connected: default isolation="+transactionIsolation+":"+Connection.TRANSACTION_NONE);

     conn.setTransactionIsolation(Connection.TRANSACTION_READ_COMMITTED);


     try
     {

            Statement stmt = conn.createStatement();
	    try
	      {
		stmt.executeUpdate ("drop table BUG1129..TESTBLOB");
	      }
	    catch (Exception e)
	      {
	      }
	    stmt.executeUpdate ("create table BUG1129..TESTBLOB ( BLOB_COL LONG VARBINARY )");
            // create table BUG1129..TESTBLOB ( BLOB_COL LONG VARBINARY );
            PreparedStatement ps = conn.prepareStatement("insert into BUG1129..TESTBLOB (BLOB_COL) values(?)");

            /*
            String data = new String("113066");
            byte byteData[];
            byteData = data.getBytes();
            */

            File file = new File ("bloor.pdf");
            BufferedInputStream bufferedInputStream = new BufferedInputStream(new FileInputStream(file));
            byte[] byteData = new byte [ (int) file.length() ];
            bufferedInputStream.read(byteData);
            bufferedInputStream.close();

            // ps.setBinaryStream(index,new ByteArrayInputStream(byteData),byteData.length);
            ps.setBytes(1, byteData);

            System.out.println("insert execute update" );
            int ires = ps.executeUpdate();
            System.out.println("insert results:"+ires);
            ps.close();
            System.out.println("insert commit");
            conn.commit();


            System.out.println("********* SELECT *****************************");
            ps = conn.prepareStatement("SELECT BLOB_COL FROM BUG1129..TESTBLOB");
            System.out.println("select execute");
            ResultSet rs = ps.executeQuery();
            while ( rs.next() )
            {
                System.out.println("result0");

                // reads 12 bytes and returns
                // byte[] x = rs.getBytes("BLOB_COL");

                InputStream stream = rs.getBinaryStream("BLOB_COL");
                ByteArrayOutputStream ostream = new ByteArrayOutputStream();



                // very slow processing
                // throws read timeout periodically after a few hundred bytes
                // or stops processing after 3600 bytes
                /*
                int c;
                int index = 0;
                while ((c = stream.read()) != -1)
                {
                    ++index;
                    if (( index % 100 ) == 0 )
                        System.err.println ( "bytes read: " + index );
                    ostream.write(c);
                }
                */


                /*
                java.io.IOException
                at virtuoso.jdbc2.VirtuosoBlobStream.read(VirtuosoBlobStream.java:93)
                at java.io.InputStream.read(InputStream.java:91)
                at TestBlob.main(TestBlob.java:140)
                */

                int length;
                // int index = 0;
                System.out.println("result1");
                // while ((length = stream.read(buffer)) != -1)
                while (true)
                {
                    byte[] buffer = new byte[32767];
                    System.out.println("result2");
                    length = stream.read(buffer);
                    System.out.println("result3:" + length);
                    if ( length < 0 )
                        break;
                    ostream.write(buffer, 0, length);
                }

                byte[] x = ostream.toByteArray();

                // String x = new String ( buffer );
                System.out.println ( "select results: len=" +x.length);
		if (x.length != byteData.length)
		  throw new Exception ("different length orig=" + byteData.length + " returned=" + x.length);

		FileOutputStream os = new FileOutputStream ("out.pdf");
		os.write (x);
            }
            rs.close();
            ps.close();

     }
     catch ( SQLException e )
     {
        System.err.println ( "SQLEXP:" + e);
        System.err.println ( "SQLEXP(error code):" + e.getErrorCode() );
        System.err.println ( "SQLEXP(sql state):" + e.getSQLState() );
        e.printStackTrace();
     }
     catch ( Exception e )
     {
        System.err.println ( "************* exception 1:" + e);
        e.printStackTrace();
     }

     try
     {
        System.out.println("close");
        conn.commit();
        conn.close();
        System.out.println("done");
     }
     catch ( Exception c2 )
     {
        System.err.println ( "************* exception close:" + c2);
        c2.printStackTrace();
     }
  }
}
