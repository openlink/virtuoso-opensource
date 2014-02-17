/*
 *  JDBCDemo.java
 *
 *  $Id$
 *
 *  Sample JDBC program
 *  
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *  
 *  Copyright (C) 1998-2014 OpenLink Software
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

import java.awt.*;
import java.sql.*;

public class JDBCDemo extends Frame  implements Runnable
{

  void NewThread_Action(Event event)
  {
    JDBCDemo p = new JDBCDemo(urlList,isApplet);
    new Thread(p).start();
  }

  void Exit_Action(Event event)
  {
    hide();         // hide the Frame
    dispose();      // free the system resources
    synchronized (this)
    {
      numThreads--;
    }
    if (numThreads == 0)
      System.exit(0); // close the application
  }

  void CloseConnection_Action(Event event)
  {
    textStatus.setText("Closing connection");
    try
    {
      if(conn!=null)
      {
	stmt.close();
	stmt = null;
	conn.close();
	conn = null;
      }
      textStatus.setText("Done.");
    }
    catch(Exception e)
    {
      textStatus.setText(e.toString());
    }
  }


  void OpenConnection_Action(Event event)
  {
    /*BEGIN_WEBJDBC
    (new DialogConnection(this, true,connectionURL,driverName, false)).show();
    END_WEBJDBC*/
    ////BEGIN_NOT_WEBJDBC
    (new DialogConnection(this, true,connectionURL,driverName, true)).show();
    ////END_NOT_WEBJDBC
  }

  void PickConnection_Action(Event event)
  {
    (new DialogConnectionList(this, true, urlList)).show();
  }

  void buttonNext_Clicked(Event event)
  {
    textStatus.setText("Going to the next row");
    try
    {
      if(result.next())
	updateInfo();
    }
    catch(Exception e)
    {
      textStatus.setText(e.toString());
    }
  }

  void buttonQuery_Clicked(Event event)
  {
    try
    {
      ExecuteQuery (textQuery.getText());
    }
    catch (Exception e)
    {
      textStatus.setText(e.toString());
    }
  }


  void ExecuteQuery (String query)
    throws Exception
  {
    int count;

    if(conn!=null)
    {
      stmt.close();
      stmt = null;
      conn.close();
      conn = null;
    }
    textStatus.setText("Connecting to :"+connectionURL);

    conn = DriverManager.getConnection (connectionURL);

    // Execute Query
    stmt = conn.createStatement ();
    textStatus.setText("Executing query");
    result = stmt.executeQuery (query);
    // Get Resultset information
    meta = result.getMetaData ();
    count = meta.getColumnCount ();
    labelColumnName = new Label[count];
    textColumnValue = new TextField[count];
    data = new String[count][1];
    Info.removeAll();
    GridBagLayout gbl = new GridBagLayout();
    Info.setLayout(gbl);
    GridBagConstraints gbc = new GridBagConstraints();
    gbc.insets = new Insets(0,0,0,0);
    gbc.fill = GridBagConstraints.BOTH;
    gbc.weighty = 1;

    for (int c = 1; c <= count; c++)
    {
      data[c-1][0] = new String();
      labelColumnName[c-1]= new Label(meta.getColumnName (c),Label.RIGHT);
      gbc.anchor = GridBagConstraints.WEST;
      gbc.gridwidth = 1;
      gbc.weightx = 1;
      gbl.setConstraints(labelColumnName[c-1],gbc);
      Info.add(labelColumnName[c-1]);
      textColumnValue[c-1] = new TextField();
      gbc.gridwidth = GridBagConstraints.REMAINDER;
      gbc.weightx = 3;
      gbl.setConstraints(textColumnValue[c-1],gbc);
      Info.add(textColumnValue[c-1]);
    }
    result.next();
    updateInfo();
    super.show();
  }

  void updateInfo()
  {
    textStatus.setText("Fetching result");
    try
    {
      for (int c = 1; c <= meta.getColumnCount (); c++)
      {
	String s = result.getString(c);
	textColumnValue[c-1].setText (s);
      }
      textStatus.setText("Done.");
    }
    catch(Exception e)
    {
      textStatus.setText(e.toString());
    }
  }

  // Unfortunately, there appears to be a bug in the IE4 classloader when you try
  // to load and register the driver with Class.forName(driverName).
  // The IE4 appears to retrieve the class file from the server, but the class's
  // static initializer block is never executed. As the driver registers itself
  // in the static initializer block, this bug produces the "no suitable driver error"
  // if you try to register a driver using Class.forName().
  // Unfortunately, in an applet, you can't manipulate the system properties to
  // put the driver in there. Thus it is necessary to create an instance of the
  // driver here, and register it with the DriverManager manually.
  void loadDriver(String driverName)
  {
    try
    {
      Class clsDriver = Class.forName(driverName);
      java.sql.Driver driver = (java.sql.Driver)clsDriver.newInstance();
      DriverManager.registerDriver (driver);
    }
    catch(Exception e)
    {
      textStatus.setText(e.toString());
    }
    this.driverName = driverName;
  }

  public JDBCDemo(String URL[],boolean isApplet)
  {
    if (URL != null && URL.length > 0)
      connectionURL = URL[0];
    jdkVersion  = (System.getProperty("java.version")).substring(0,3);
    this.isApplet = isApplet;
    menuBar1 = new java.awt.MenuBar();
    menuFile = new java.awt.Menu("File");
    menuFile.add("New Thread");
    menuFile.add("Set Connection URL...");
    if (isApplet)
      menuFile.add("Pick Connection URL...");
    menuFile.add("Close Connection");
    if (!isApplet)
      menuFile.add("Exit");
    menuBar1.add(menuFile);

    menu1 = new java.awt.Menu("Go To");
    menu1.add("Next");
    menuBar1.add(menu1);
    setMenuBar(menuBar1);

    setLayout(new BorderLayout(0,5));
    addNotify();
    super.show();
    resize(insets().left + insets().right + 600,insets().top + insets().bottom + 325);
    setBackground(new Color(12632256));
    panel3 = new java.awt.Panel();
    panel3.setLayout(new BorderLayout(5,10));
    panel3.reshape(insets().left + 0,insets().top + 0,600,21);
    panel3.setBackground(new Color(12632256));
    add("North", panel3);
    textQuery = new java.awt.TextField();
    textQuery.setText("SELECT * FROM \"Customers\"");
    textQuery.reshape(0,0,600,21);
    textQuery.setBackground(new Color(16777215));
    panel3.add("Center", textQuery);
    buttonQuery = new java.awt.Button("Query");
    buttonQuery.reshape(552,0,48,21);
    panel3.add("East", buttonQuery);
    Info = new java.awt.Panel();
    GridBagLayout gridBagLayout;
    gridBagLayout = new GridBagLayout();
    Info.setLayout(gridBagLayout);
    Info.reshape(insets().left + 0,insets().top + 21,600,196);
    Info.setBackground(new Color(12632256));
    add("Center", Info);
    label1 = new java.awt.Label("",Label.RIGHT);
    label1.reshape(141,95,14,21);
    GridBagConstraints gbc;
    gbc = new GridBagConstraints();
    gbc.weightx = 1;
    gbc.weighty = 1;
    gbc.fill = GridBagConstraints.NONE;
    gbc.insets = new Insets(0,0,0,0);
    gridBagLayout.setConstraints(label1, gbc);
    Info.add(label1);
    textField1 = new java.awt.TextField();
    textField1.reshape(438,95,20,21);
    gbc = new GridBagConstraints();
    gbc.weightx = 1;
    gbc.weighty = 1;
    gbc.fill = GridBagConstraints.NONE;
    gbc.insets = new Insets(0,0,0,0);
    gridBagLayout.setConstraints(textField1, gbc);
    Info.add(textField1);
    panel4 = new java.awt.Panel();
    panel4.setLayout(new GridLayout(0,1,0,1));
    add("South", panel4);
    buttonNext = new java.awt.Button("Next");
    buttonNext.setFont(new Font("Dialog", Font.PLAIN, 10));
    panel4.add(buttonNext);
    textStatus = new java.awt.TextField();
    textStatus.setEditable(false);
    textStatus.reshape(0,62,600,30);
    textStatus.setFont(new Font("Dialog", Font.PLAIN, 10));
    panel4.add(textStatus);
    setTitle("OpenLink JDBC Demo");

    Info.remove(label1);
    Info.remove(textField1);
    urlList = URL;
    loadDriver("virtuoso.jdbc2.Driver");
  }

  public void show()
  {
    move(20*myThreadNum, 20*myThreadNum);
    super.show();
  }

  public String MakeConnectURL(String inurl, String inkey, String invalue)
  {
    int inkeypos, endpos;

	inkeypos = inurl.indexOf(inkey+"=",0);
	if (inkeypos <0)
	{
		return inurl + "/" + inkey + "=" + invalue;
	}
	endpos = inurl.indexOf("/",inkeypos);
	if (endpos <0)
	{
		return inurl.substring(0,inkeypos) + inkey + "=" + invalue;
	}

	return inurl.substring(0,inkeypos) + inkey + "=" + invalue + inurl.substring(endpos);
  }

  public boolean handleEvent(Event event)
  {
    if (event.id == -1)
    {
      connectionURL = (String)(event.arg);
      textStatus.setText("Connection URL is  :"+connectionURL);
      return true;
    }
    else if (event.id == -2)
    {
      driverName = (String)(event.arg);
      textStatus.setText("Driver name is :"+driverName);
      loadDriver(driverName);
      return true;
    }
    else if (event.id == -5)
    {
      DbName = (String)(event.arg);
      connectionURL = MakeConnectURL(connectionURL, "DATABASE", DbName);
      textStatus.setText("Connection URL is  :"+connectionURL);
      return true;
    }
    else if (event.id == -3)
    {
      userName = (String)(event.arg);
      connectionURL = MakeConnectURL(connectionURL, "UID", userName);
      textStatus.setText("Connection URL is  :"+connectionURL);
      return true;
    }
    else if (event.id == -4)
    {
      password = (String)(event.arg);
      connectionURL = MakeConnectURL(connectionURL, "PWD", password);
      textStatus.setText("Connection URL is  :"+connectionURL);
      return true;
    }
    if (event.id == Event.WINDOW_DESTROY)
    {
      try
      {
	stmt.close();
	conn.close();
      }
      catch(Exception e)
      {
      }
      if (isApplet)
      {
	hide();         // hide the Frame
	dispose();      // free the system resources
      }
      else
      {
	Exit_Action(event);
      }
      return true;
    }

    if (event.target == buttonQuery && event.id == Event.ACTION_EVENT)
    {
      buttonQuery_Clicked(event);
      return true;
    }
    if (event.target == buttonNext && event.id == Event.ACTION_EVENT)
    {
      buttonNext_Clicked(event);
      return true;
    }
    return super.handleEvent(event);
  }

  public boolean action(Event event, Object arg)
  {
    if (arg.toString().equalsIgnoreCase("Set Connection URL..."))
    {
      OpenConnection_Action(event);
      return true;
    }
    if (arg.toString().equalsIgnoreCase("Pick Connection URL..."))
    {
      PickConnection_Action(event);
      return true;
    }
    if (arg.toString().equalsIgnoreCase("Close Connection"))
    {
      CloseConnection_Action(event);
      return true;
    }
    if (arg.toString().equalsIgnoreCase("Exit"))
    {
      Exit_Action(event);
      return true;
    }
    if (arg.toString().equalsIgnoreCase("Next"))
    {
      buttonNext_Clicked(event);
      return true;
    }
    if (arg.toString().equalsIgnoreCase("New Thread"))
    {
      NewThread_Action(event);
      return true;
    }
    return super.action(event, arg);
  }

  static public void main(String args[])
  {
    String URL=null;
    if(args.length>0)
      URL = args[0];
    JDBCDemo jd = new JDBCDemo(args,false);
    jd.show();
  }

  public void run()
  {
    synchronized (this)
    {
      numThreads++;
      numThreadsInvoked++;
      myThreadNum = numThreadsInvoked;
    }
    show();
  }

  java.awt.TextField textQuery;
  java.awt.Button buttonQuery;
  java.awt.Panel Info;
  java.awt.Label label1;
  java.awt.TextField textField1;
  java.awt.Panel panel3;
  java.awt.Panel panel4;
  java.awt.Panel panel5;
  java.awt.Button buttonNext;
  java.awt.TextField textPos;
  java.awt.TextField textStatus;

  java.awt.MenuBar menuBar1;
  java.awt.Menu menuFile;
  java.awt.Menu menu1;

  java.sql.ResultSetMetaData meta=null;
  java.sql.Statement stmt=null;
  java.sql.ResultSet result=null;
  java.sql.Connection conn=null;
  java.awt.Label[] labelColumnName;
  java.awt.TextField[] textColumnValue;
  int bookmark=0;
  public String connectionURL="jdbc:virtuoso://localhost:1112/UID=demo/PWD=demo";
  String[][] data;
  static int numThreads = 1;
  static int numThreadsInvoked = 1;
  int myThreadNum;
  String[] urlList;
  String userName, password, driverName, DbName;
  boolean isApplet=false;
  String jdkVersion;
}



