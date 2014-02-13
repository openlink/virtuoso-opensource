/*
 *  ScrollDemo2.java
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


class ScrollDemo2 extends Frame implements Runnable
{

  void NewThread_Action(Event event)
  {
    try
    {
      ScrollDemo2 p = new ScrollDemo2(urlList,isApplet);
      new Thread(p).start();
    }
    catch(Exception e)
    {
      textStatus.setText(e.toString());
    }
  }

  void buttonUpdate_Clicked(Event event)
  {
    textStatus.setText("Updating row");
    for(int c=1; c<= columnCount; c++)
      try{
        result.updateString(c, textColumnValue[c-1].getText());
      }
      catch(Exception e){
	textStatus.setText(e.toString());
      }
    try{
      result.updateRow();
      updateInfo();
    }
    catch(Exception e){
      textStatus.setText(e.toString());
    }
  }

  void buttonInsert_Clicked(Event event)
  {
    textStatus.setText("Inserting row");
    try{
      result.moveToInsertRow();
      }
    catch(Exception e){
      textStatus.setText(e.toString());
      return;
    }
    for(int c=1; c<= columnCount; c++)
      try{
        result.updateString(c, textColumnValue[c-1].getText());
      }
      catch(Exception e){
	textStatus.setText(e.toString());
      }
    try{
      result.insertRow();
      result.moveToCurrentRow();
      updateInfo();
    }
    catch(Exception e){
      textStatus.setText(e.toString());
    }
  }

  void buttonAbsolute_Clicked(Event event)
  {
    int position = Integer.parseInt(textPos.getText());
    MoveToPos(position);
  }

  public void MoveToPos(int pos)
  {
    textStatus.setText("Going to position "+pos);
    try{
      if(result.absolute(pos))
	updateInfo();
    }
    catch(Exception e){
      textStatus.setText(e.toString());
    }
  }

  void buttonRelative_Clicked(Event event)
  {
    int position = Integer.parseInt(textPos.getText());
    MoveRelative(position);
  }

  public void MoveRelative(int pos)
  {
    textStatus.setText("Going to relative position "+pos);
    try{
      if(result.relative(pos))
	updateInfo();
    }
    catch(Exception e){
      textStatus.setText(e.toString());
    }
  }

  void Absolute_Action(Event event) {
    int position = Integer.parseInt(textPos.getText());
    MoveToPos(position);
  }

  void Relative_Action(Event event) {
    int position = Integer.parseInt(textPos.getText());
    MoveRelative(position);
  }


  void buttonRefresh_Clicked(Event event)
  {
    textStatus.setText("Refreshing the current row");
    try{
      result.refreshRow();
      updateInfo();
    }
    catch(Exception e){
      textStatus.setText(e.toString());
    }
  }

  void buttonDelete_Clicked(Event event)
  {
    textStatus.setText("Deleting the current row");
    try{
      result.deleteRow();
      updateInfo();
    }
    catch(Exception e){
      textStatus.setText(e.toString());
    }
  }

  void buttonLast_Clicked(Event event)
  {
    textStatus.setText("Going to the last row");
    try{
      if(result.last())
	updateInfo();
    }
    catch(Exception e){
      textStatus.setText(e.toString());
    }
  }

  void buttonFirst_Clicked(Event event)
  {
    textStatus.setText("Going to the first row");
    try{
      if(result.first())
	updateInfo();
    }
    catch(Exception e){
      textStatus.setText(e.toString());
    }
  }

  void buttonPrevious_Clicked(Event event)
  {
    textStatus.setText("Going to the previous row");
    try{
      if(result.previous())
	updateInfo();
    }
    catch(Exception e){
      textStatus.setText(e.toString());
    }
  }

  void buttonNext_Clicked(Event event)
  {
    textStatus.setText("Going to the next row");
    try{
      if(result.next())
	updateInfo();
    }
    catch(Exception e){
      textStatus.setText(e.toString());
    }
  }

  void buttonQuery_Clicked(Event event)
  {
    try{
      ExecuteQuery (textQuery.getText());
    }
    catch (Exception e){
      textStatus.setText(e.toString());
    }
  }


  void Exit_Action(Event event) {
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
    try{
      if(conn!=null)
      {
	stmt.close();
	stmt = null;
	conn.close();
	conn = null;
      }
      textStatus.setText("Done.");
    }
    catch(Exception e){
      textStatus.setText(e.toString());
    }
    conn=null;
  }

  void OpenConnection_Action(Event event)
  {
    (new DialogConnection(this, true, connectionURL, driverName, true)).show();
  }


  void PickConnection_Action(Event event)
  {
    (new DialogConnectionList(this, true, urlList)).show();
  }


  void ExecuteQuery (String query)
    throws Exception
  {

    if(conn!=null)
    {
      stmt.close();
      stmt = null;
      conn.close();
      conn = null;
    }
    textStatus.setText("Connecting to :"+connectionURL);
    if (userName != null || password != null)
      conn = DriverManager.getConnection (connectionURL,userName, password);
    else
      conn = DriverManager.getConnection (connectionURL);

    // Execute Query
    // Execute Query
    stmt = conn.createStatement (ResultSet.TYPE_SCROLL_SENSITIVE,ResultSet.CONCUR_UPDATABLE);
    textStatus.setText("Executing query");
    result = stmt.executeQuery (query);
    // Get Resultset information
    meta = result.getMetaData ();
    columnCount = meta.getColumnCount ();
    labelColumnName = new Label[columnCount];
    textColumnValue = new TextField[columnCount];
    data = new String[columnCount][1];
    Info.removeAll();
    GridBagLayout gbl = new GridBagLayout();
    Info.setLayout(gbl);
    GridBagConstraints gbc = new GridBagConstraints();
    gbc.insets = new Insets(0,0,0,0);
    gbc.fill = GridBagConstraints.BOTH;
    gbc.weighty = 1;

    for (int c = 1; c <= columnCount; c++)
    {
      //data[c-1][0] = new String();
      //result.bindColumn(c,data[c-1]);
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
    try{
      for (int c = 1; c <= columnCount; c++){
	textColumnValue[c-1].setText (result.getString(c));
      }
      textStatus.setText("Done.");
    }
    catch(Exception e){
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

  public ScrollDemo2(String URL[],boolean isApplet)
    throws Exception
  {
    if (URL != null && URL.length > 0)
      connectionURL = URL[0];
    jdkVersion  = (System.getProperty("java.version")).substring(0,3);
    if (jdkVersion.equalsIgnoreCase("1.0")
	|| jdkVersion.equalsIgnoreCase("1.1"))
      throw new Exception("Wrong Java Virtual Machine");
    this.isApplet = isApplet;
    urlList = URL;
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
    menu1.add("First");
    menu1.add("Previous");
    menu1.add("Next");
    menu1.add("Last");
    menu1.add("Absolute");
    menuBar1.add(menu1);
    setMenuBar(menuBar1);

    setLayout(new BorderLayout(0,5));
    addNotify();
    resize(insets().left + insets().right + 600,insets().top + insets().bottom + 325);
    setBackground(new Color(12632256));
    panel3 = new java.awt.Panel();
    panel3.setLayout(new BorderLayout(5,10));
    panel3.reshape(insets().left + 0,insets().top + 0,600,21);
    panel3.setBackground(new Color(12632256));
    add("North", panel3);
    textQuery = new java.awt.TextField();
    textQuery.setText("select * from Customers");
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
    panel4.reshape(insets().left + 0,insets().top + 233,600,92);
    add("South", panel4);
    Toolbar = new java.awt.Panel();
    Toolbar.setLayout(new FlowLayout(FlowLayout.CENTER,10,1));
    Toolbar.reshape(0,0,600,30);
    Toolbar.setBackground(new Color(12632256));
    panel4.add(Toolbar);
    panel1 = new java.awt.Panel();
    panel1.setLayout(new GridLayout(1,0,2,0));
    panel1.reshape(56,5,178,21);
    Toolbar.add(panel1);
    buttonFirst = new java.awt.Button("  First  ");
    buttonFirst.reshape(0,0,43,21);
    buttonFirst.setFont(new Font("Dialog", Font.PLAIN, 10));
    panel1.add(buttonFirst);
    buttonPrevious = new java.awt.Button("Previous");
    buttonPrevious.reshape(45,0,43,21);
    buttonPrevious.setFont(new Font("Dialog", Font.PLAIN, 10));
    panel1.add(buttonPrevious);
    buttonNext = new java.awt.Button("Next");
    buttonNext.reshape(90,0,43,21);
    buttonNext.setFont(new Font("Dialog", Font.PLAIN, 10));
    panel1.add(buttonNext);
    buttonLast = new java.awt.Button("Last");
    buttonLast.reshape(135,0,43,21);
    buttonLast.setFont(new Font("Dialog", Font.PLAIN, 10));
    panel1.add(buttonLast);
    panel2 = new java.awt.Panel();
    panel2.setLayout(new GridLayout(1,0,2,0));
    panel2.reshape(239,5,304,21);
    Toolbar.add(panel2);
    buttonDelete = new java.awt.Button("Delete");
    buttonDelete.reshape(0,0,49,21);
    buttonDelete.setFont(new Font("Dialog", Font.PLAIN, 10));
    panel2.add(buttonDelete);
    buttonRefresh = new java.awt.Button("Refresh");
    buttonRefresh.reshape(51,0,49,21);
    buttonRefresh.setFont(new Font("Dialog", Font.PLAIN, 10));
    panel2.add(buttonRefresh);
    buttonInsert = new java.awt.Button("Insert");
    buttonInsert.reshape(204,0,49,21);
    buttonInsert.setFont(new Font("Dialog", Font.PLAIN, 10));
    panel2.add(buttonInsert);
    buttonUpdate = new java.awt.Button("Update");
    buttonUpdate.reshape(255,0,49,21);
    buttonUpdate.setFont(new Font("Dialog", Font.PLAIN, 10));
    panel2.add(buttonUpdate);
    panel5 = new java.awt.Panel();
    panel5.setLayout(new FlowLayout(FlowLayout.CENTER,2,0));
    panel5.reshape(0,31,600,30);
    panel4.add(panel5);
    buttonAbsolute = new java.awt.Button("Absolute");
    buttonAbsolute.reshape(262,5,44,21);
    buttonAbsolute.setFont(new Font("Dialog", Font.PLAIN, 12));
    panel5.add(buttonAbsolute);
    buttonRelative = new java.awt.Button("Relative");
    buttonRelative.reshape(348,5,44,21);
    buttonRelative.setFont(new Font("Dialog", Font.PLAIN, 12));
    panel5.add(buttonRelative);
    textPos = new java.awt.TextField();
    textPos.setText("1");
    textPos.reshape(397,5,28,21);
    panel5.add(textPos);
    textStatus = new java.awt.TextField();
    textStatus.setEditable(false);
    textStatus.reshape(0,62,600,30);
    textStatus.setFont(new Font("Dialog", Font.PLAIN, 10));
    panel4.add(textStatus);
    setTitle("OpenLink Virtuoso JDBC 2.0 Scrollable Cursor Demo");

    Info.remove(label1);
    Info.remove(textField1);
    loadDriver("virtuoso.jdbc2.Driver");
  }

  public void show()
  {
    move(20*myThreadNum, 20*myThreadNum);
    super.show();
  }

  public boolean handleEvent(Event event) {
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
    else if (event.id == -3)
    {
      userName = (String)(event.arg);
      return true;
    }
    else if (event.id == -4)
    {
      password = (String)(event.arg);
      return true;
    }
    if (event.id == Event.WINDOW_DESTROY)
    {
      try
      {
	if(conn!=null)
	{
	  stmt.close();
	  stmt = null;
	  conn.close();
	  conn = null;
	}
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
    if (event.target == buttonQuery && event.id == Event.ACTION_EVENT) {
      buttonQuery_Clicked(event);
      return true;
    }
    if (event.target == buttonNext && event.id == Event.ACTION_EVENT) {
      buttonNext_Clicked(event);
      return true;
    }
    if (event.target == buttonPrevious && event.id == Event.ACTION_EVENT) {
      buttonPrevious_Clicked(event);
      return true;
    }
    if (event.target == buttonFirst && event.id == Event.ACTION_EVENT) {
      buttonFirst_Clicked(event);
      return true;
    }
    if (event.target == buttonLast && event.id == Event.ACTION_EVENT) {
      buttonLast_Clicked(event);
      return true;
    }
    if (event.target == buttonDelete && event.id == Event.ACTION_EVENT) {
      buttonDelete_Clicked(event);
      return true;
    }
    if (event.target == buttonRefresh && event.id == Event.ACTION_EVENT) {
      buttonRefresh_Clicked(event);
      return true;
    }
    if (event.target == buttonAbsolute && event.id == Event.ACTION_EVENT) {
      buttonAbsolute_Clicked(event);
      return true;
    }
    if (event.target == buttonRelative && event.id == Event.ACTION_EVENT) {
      buttonRelative_Clicked(event);
      return true;
    }
    if (event.target == buttonInsert && event.id == Event.ACTION_EVENT) {
      buttonInsert_Clicked(event);
      return true;
    }
    if (event.target == buttonUpdate && event.id == Event.ACTION_EVENT) {
      buttonUpdate_Clicked(event);
      return true;
    }
    return super.handleEvent(event);
  }

  public boolean action(Event event, Object arg) {
    if (arg.toString().equalsIgnoreCase("Set Connection URL...")) {
      OpenConnection_Action(event);
      return true;
    }
    if (arg.toString().equalsIgnoreCase("Pick Connection URL..."))
    {
      PickConnection_Action(event);
      return true;
    }
    if (arg.toString().equalsIgnoreCase("Close Connection")) {
      CloseConnection_Action(event);
      return true;
    }
    if (arg.toString().equalsIgnoreCase("Exit"))
    {
      Exit_Action(event);
      return true;
    }
    if (arg.toString().equalsIgnoreCase("First")) {
      buttonFirst_Clicked(event);
      return true;
    }
    if (arg.toString().equalsIgnoreCase("Last")) {
      buttonLast_Clicked(event);
      return true;
    }
    if (arg.toString().equalsIgnoreCase("Previous")) {
      buttonPrevious_Clicked(event);
      return true;
    }
    if (arg.toString().equalsIgnoreCase("Next")) {
      buttonNext_Clicked(event);
      return true;
    }
    if (arg.toString().equalsIgnoreCase("Absolute")) {
      Absolute_Action(event);
      return true;
    }
    if (arg.toString().equalsIgnoreCase("New Thread")) {
	    NewThread_Action(event);
	    return true;
    }
    return super.action(event, arg);
  }


  static public void main(String args[])
    throws Exception
  {
    ScrollDemo2 sd = new ScrollDemo2(args, false);
    if(args.length>0)
      sd.connectionURL = args[0];
    sd.show();
  }

  public void run() {
    synchronized (this)
    {
      numThreads++;
      numThreadsInvoked++;
      myThreadNum = numThreadsInvoked;
    }
    show();
  }

  java.awt.Panel panel3;
  java.awt.TextField textQuery;
  java.awt.Button buttonQuery;
  java.awt.Panel Info;
  java.awt.Label label1;
  java.awt.TextField textField1;
  java.awt.Panel panel4;
  java.awt.Panel Toolbar;
  java.awt.Panel panel1;
  java.awt.Button buttonFirst;
  java.awt.Button buttonPrevious;
  java.awt.Button buttonNext;
  java.awt.Button buttonLast;
  java.awt.Panel panel2;
  java.awt.Button buttonDelete;
  java.awt.Button buttonRefresh;
  java.awt.Button buttonInsert;
  java.awt.Button buttonUpdate;
  java.awt.Panel panel5;
  java.awt.Button buttonAbsolute;
  java.awt.Button buttonRelative;
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
  int columnCount;
  public String connectionURL="jdbc:virtuoso://localhost:1112/UID=demo/PWD=demo";
  String[][] data;
  static int numThreads = 1;
  static int numThreadsInvoked = 1;
  int myThreadNum;
  String[] urlList;
  String userName, password, driverName;
  boolean isApplet=false;
  String jdkVersion;
}
