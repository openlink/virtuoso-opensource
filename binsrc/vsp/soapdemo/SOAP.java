/*
 *  
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *  
 *  Copyright (C) 1998-2012 OpenLink Software
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
 *  
*/
import java.net.*;
import java.awt.*;
import java.awt.event.*;
import java.util.*;
import java.applet.*;
import org.xmlsoap.*;
import org.xmlsoap.http.*;
import org.xmlsoap.rt.*;
import org.xml.sax.*;
import java.io.*;

public class SOAP extends Applet implements ActionListener, Runnable
{
  TextArea outp;
  TextField string;
  Button btn;
  java.net.URL url;

  public String callTheServer (String mask) throws java.io.IOException, org.xml.sax.SAXException, org.xmlsoap.http.HttpSoapFault
    {
      System.out.println ("server called mask : " + mask);
      Object obj = new fishselect(mask);
      System.out.println ("fishselect req created");

      System.out.println(url.getClass().getName()+ " : "+ url.toString());

      java.net.URLConnection connection = url.openConnection();
      connection.setDoInput(true);
      connection.setDoOutput(true);
      connection.setRequestProperty("Content-Type", "text/xml");
      connection.setRequestProperty("Connection", "close");
      System.out.println ("connection opened");

      org.xmlsoap.rt.SoapSerializer serializer = new org.xmlsoap.rt.SoapSerializer(null);
      System.out.println ("serializer created");
      org.xmlsoap.rt.ISoapSerializer root = 
	  serializer.getTypeMapper().getSerializerForObject(obj, false, serializer);
      System.out.println ("typemapper gotten");
      connection.setRequestProperty("SOAPMethodName", root.getTypeURI() + "#" + root.getTypeName());
      System.out.println ("SOAPMethodName http prop set");

      String [] nsuris = { root.getTypeURI() };
      System.out.println ("nsuris set");
      serializer.init(connection.getOutputStream(), nsuris);
      System.out.println ("serializer initialized");
      serializer.appendBody(obj, null, null, false);
      System.out.println ("obj parsed");

      System.out.println ("response code checked");
      java.io.InputStream in = connection.getInputStream();
      System.out.println ("input stream got");
      org.xmlsoap.rt.SoapParser parser = new org.xmlsoap.rt.SoapParser(null, null);
      System.out.println ("input stream parser created");
      parser.parse(new org.xml.sax.InputSource(connection.getInputStream()));
      System.out.println ("input parsed");
      Object response = parser.getBody();
      System.out.println ("body received");
      if (response instanceof org.xmlsoap.Fault)
	throw new SoapFault((org.xmlsoap.Fault)response);
      System.out.println ("SOAP response verified");

      fishselectResponse resp = (fishselectResponse)response;
      System.out.println ("server called 3");
      return resp.CallReturn;
    };

  public void run ()
    {
      try 
	{
	  btn.setEnabled(false);
	  String result = callTheServer(string.getText());
	  outp.setText (result);
	  btn.setEnabled(true);
	}
      catch (Exception e)
	{
	  outp.setText("Error : " + e.getMessage());
	  System.out.println (e.getMessage());
	  e.printStackTrace();
	}
    }

  public String htmlIt (String mask)
    {
      try 
	{
	  if (mask == null)
	    mask = "";
	  String sc, soutp;
	  sc = callTheServer(mask + "%");
	  StringTokenizer tn = new StringTokenizer (sc, "\t\n");
	  soutp = "<TABLE border=1><TR><TD><B>CompanyName</B></TD><TD><B>OrderDate</B></TD><TD><B>ProductName</B></TD></TR>\n";
	  while (tn.hasMoreTokens())
	    {
		soutp = soutp + "<TR>";
		if (tn.hasMoreTokens())
		  soutp = soutp + "<TD>" + tn.nextToken() + "</TD>";
		if (tn.hasMoreTokens())
		  soutp = soutp + "<TD>" + tn.nextToken() + "</TD>";
		if (tn.hasMoreTokens())
		  soutp = soutp + "<TD>" + tn.nextToken() + "</TD>";
		soutp = soutp + "</TR>\n";
	    }
	  return soutp + "</TABLE>";
	}
      catch (Exception e)
	{
	  return ("<P>" + e.getMessage() + "</P>");
	}
    }

  public void actionPerformed(java.awt.event.ActionEvent e1)
    {
      System.out.println ("action performed");
      Thread worker = new Thread(this);
      worker.start();
    }

  public void init()
    {
      Panel topp = new Panel (new BorderLayout());
      string = new TextField ("G%");
      topp.add (string, BorderLayout.CENTER);
      btn = new Button ("Go7");
      btn.addActionListener (this);
      topp.add (btn, BorderLayout.EAST);

      outp = new TextArea("", 20, 80, TextArea.SCROLLBARS_BOTH);
//      setLayout (new BorderLayout());
//      add (topp, BorderLayout.NORTH);
//     add (outp, BorderLayout.CENTER);

      url = getDocumentBase();
      try {
	String host = url.getHost();
	if (host == null || host.length() < 1)
	  url = new URL ("http", "localhost", 6666, "/SOAP");
	else
	  url = new URL ("http", url.getHost(), url.getPort(), "/SOAP");
      }
      catch (Exception e)
	{
	  try {
	    url = new URL ("http://localhost:6666/SOAP");
	  }
	  catch (Exception e1) {};
	}
      System.out.println(url.toString());
      org.xmlsoap.rt.SoapTypeMapper.getCurrentTypeMapper().bindClassToTypeName(
	  fishselect.class, 
	  "urn:openlinksw-com:virtuoso", 
	  "fishselect", 
	  false);
      org.xmlsoap.rt.SoapTypeMapper.getCurrentTypeMapper().bindClassToTypeName(
	  fishselectResponse.class, 
	  "urn:openlinksw-com:virtuoso", 
	  "fishselectResponse", 
	  false);
    }
  public void start ()
    {
      btn.setEnabled(true);
      System.out.println("started");
    }

  public void stop ()
    {
      btn.setEnabled(false);
      System.out.println("stopped");
    }
}
