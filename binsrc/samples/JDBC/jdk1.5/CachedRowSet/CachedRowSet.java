/*
 *  CachedRowSet.java
 *
 *  $Id$
 *
 *  Sample JDBC program
 *  
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *  
 *  Copyright (C) 1998-2015 OpenLink Software
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
import java.awt.font.*;
import java.awt.event.*;
import java.sql.*;
import java.util.*;
import java.io.*;
import javax.sql.*;
import virtuoso.javax.*;

public class CachedRowSet extends Frame implements Runnable
{

  Panel Info;
  TextField textQuery;
  Label label1;
  TextField textField1;
  Button buttonQuery;
  Button buttonAccept;
  Button buttonFirst;
  Button buttonPrevious;
  Button buttonNext;
  Button buttonLast;
  Button buttonDelete;
  Button buttonRefresh;
  Button buttonInsert;
  Button buttonUpdate;
  Button buttonAbsolute;
  Button buttonRelative;
  Button buttonCancelDel;
  Button buttonCancelIns;
  Button buttonCancelUpd;
  Button buttonOriginalAll;
  Button buttonOriginalRow;
  Button buttonRestoreOriginal;
  TextField textPos;
  TextField textStatus;

  MenuBar menuBar1;
  Menu menuFile;
  Menu menu1;
  Menu menu2;
  MenuItem mnNewThread;
  MenuItem mnLoad;
  MenuItem mnSave;
  MenuItem mnSetConn;
  MenuItem mnPickConn;
  MenuItem mnCloseConn;
  MenuItem mnExit;
  MenuItem mnFirst;
  MenuItem mnLast;
  MenuItem mnPrev;
  MenuItem mnNext;
  MenuItem mnAbsolute;
  CheckboxMenuItem mnShowDeleted;

  ActionListener bListener;
  ActionListener mListener;
  ItemListener mIListener;

  StatusMsg status = new StatusMsg();
  java.sql.ResultSetMetaData meta=null;
  OPLCachedRowSet  result=null;
  Label[] labelColumnName;
  TextField[] textColumnValue;
  int bookmark=0;
  int columnCount;
  public String connectionURL="jdbc:virtuoso://localhost:1112/UID=demo/PWD=demo";
  String[][] data;
  static int numThreads = 1;
  static int numThreadsInvoked = 1;
  int myThreadNum;
  String[] urlList;
  String userName, password, driverName, DbName;
  boolean isApplet=false;
  String jdkVersion;
  boolean showDeleted = false;


  void NewThread_Action(ActionEvent event)
  {
    try
    {
      CachedRowSet p = new CachedRowSet(urlList, isApplet);
      new Thread(p).start();
    }
    catch(Exception e)
    {
      status.msg = e.toString();
      textStatus.setText(status.toString());
    }
  }

  void buttonUpdate_Clicked(ActionEvent event)
  {
    status.msg = "Updating row";
    textStatus.setText(status.toString());
    for(int c=1; c<= columnCount; c++)
      try{
        result.updateString(c, textColumnValue[c-1].getText());
      }
      catch(Exception e){
        status.msg = e.toString();
        textStatus.setText(status.toString());
      }
    try{
      result.updateRow();
      updateInfo();
    }
    catch(Exception e){
      status.msg = e.toString();
      textStatus.setText(status.toString());
    }
  }

  void buttonInsert_Clicked(ActionEvent event)
  {
    status.msg = "Inserting row";
    textStatus.setText(status.toString());
    try{
      result.moveToInsertRow();
      }
    catch(Exception e){
      status.msg = e.toString();
      textStatus.setText(status.toString());
      return;
    }
    for(int c=1; c<= columnCount; c++)
      try{
        result.updateString(c, textColumnValue[c-1].getText());
      }
      catch(Exception e){
        status.msg = e.toString();
        textStatus.setText(status.toString());
      }
    try{
      result.insertRow();
      result.moveToCurrentRow();
      updateInfo();
    }
    catch(Exception e){
      status.msg = e.toString();
      textStatus.setText(status.toString());
    }
  }

  void buttonAbsolute_Clicked(ActionEvent event)
  {
    int position = Integer.parseInt(textPos.getText());
    MoveToPos(position);
  }

  public void MoveToPos(int pos)
  {
    status.msg = "Going to position "+pos;
    textStatus.setText(status.toString());
    try{
      result.absolute(pos);
      updateInfo();
    }
    catch(Exception e){
      status.msg = e.toString();
      textStatus.setText(status.toString());
    }
  }

  void buttonRelative_Clicked(ActionEvent event)
  {
    int position = Integer.parseInt(textPos.getText());
    MoveRelative(position);
  }

  public void MoveRelative(int pos)
  {
    status.msg = "Going to relative position "+pos;
    textStatus.setText(status.toString());
    try{
        result.relative(pos);
	updateInfo();
    }
    catch(Exception e){
      status.msg = e.toString();
      textStatus.setText(status.toString());
    }
  }

  void buttonRefresh_Clicked(ActionEvent event)
  {
    status.msg = "Refreshing the current row";
    textStatus.setText(status.toString());
    try{
      result.refreshRow();
      updateInfo();
    }
    catch(Exception e){
      status.msg = e.toString();
      textStatus.setText(status.toString());
    }
  }

  void buttonDelete_Clicked(ActionEvent event)
  {
    status.msg = "Deleting the current row";
    textStatus.setText(status.toString());
    try{
      result.deleteRow();
      updateInfo();
    }
    catch(Exception e){
      status.msg = e.toString();
      textStatus.setText(status.toString());
    }
  }

  void buttonLast_Clicked(ActionEvent event)
  {
    status.msg = "Going to the last row";
    textStatus.setText(status.toString());
    try{
       result.last();
       updateInfo();
    }
    catch(Exception e){
      status.msg = e.toString();
      textStatus.setText(status.toString());
    }
  }

  void buttonFirst_Clicked(ActionEvent event)
  {
    status.msg = "Going to the first row";
    textStatus.setText(status.toString());
    try{
       result.first();
       updateInfo();
    }
    catch(Exception e){
      status.msg = e.toString();
      textStatus.setText(status.toString());
    }
  }

  void buttonPrevious_Clicked(ActionEvent event)
  {
    status.msg = "Going to the previous row";
    textStatus.setText(status.toString());
    try{
       result.previous();
       updateInfo();
    }
    catch(Exception e){
      status.msg = e.toString();
      textStatus.setText(status.toString());
    }
  }

  void buttonNext_Clicked(ActionEvent event)
  {
    status.msg = "Going to the next row";
    textStatus.setText(status.toString());
    try{
       result.next();
       updateInfo();
    }
    catch(Exception e){
      status.msg = e.toString();
      textStatus.setText(status.toString());
    }
  }

  void buttonQuery_Clicked(ActionEvent event)
  {
    try{
      ExecuteQuery (textQuery.getText());
    }
    catch (Exception e){
      status.msg = e.toString();
      textStatus.setText(status.toString());
    }
  }

  void buttonAccept_Clicked(ActionEvent event)
  {
    try{
      result.acceptChanges();
      result.first();
      updateInfo();
    }
    catch (Exception e){
      status.msg = e.toString();
      textStatus.setText(status.toString());
    }
  }

  void buttonCancelDel_Clicked(ActionEvent event)
  {
    try{
      result.cancelRowDelete();
      updateInfo();
    }
    catch (Exception e){
      status.msg = e.toString();
      textStatus.setText(status.toString());
    }
  }


  void buttonCancelIns_Clicked(ActionEvent event)
  {
    try{
      result.cancelRowInsert();
      updateInfo();
    }
    catch (Exception e){
      status.msg = e.toString();
      textStatus.setText(status.toString());
    }
  }


  void buttonCancelUpd_Clicked(ActionEvent event)
  {
    try{
      result.cancelRowUpdates();
      updateInfo();
    }
    catch (Exception e){
      status.msg = e.toString();
      textStatus.setText(status.toString());
    }
  }

  void buttonOriginalAll_Clicked(ActionEvent event)
  {
    try{
      result.setOriginal();
      updateInfo();
    }
    catch (Exception e){
      status.msg = e.toString();
      textStatus.setText(status.toString());
    }
  }

  void buttonOriginalRow_Clicked(ActionEvent event)
  {
    try{
      result.setOriginalRow();
      updateInfo();
    }
    catch (Exception e){
      status.msg = e.toString();
      textStatus.setText(status.toString());
    }
  }

  void buttonRestoreOriginal_Clicked(ActionEvent event)
  {
    try{
      result.restoreOriginal();
      result.first();
      updateInfo();
    }
    catch (Exception e){
      status.msg = e.toString();
      textStatus.setText(status.toString());
    }
  }




  void Exit_Action(ActionEvent event) {
    hide();         // hide the Frame
    dispose();      // free the system resources
    synchronized (this)
    {
      numThreads--;
    }
    if (numThreads == 0)
      System.exit(0); // close the application
  }

  void CloseConnection_Action(ActionEvent event)
  {
    status.clear();
    status.msg = "Closing RowSet";
    textStatus.setText(status.toString());
    try{
      if(result!=null)
      {
	result.close();
	result = null;
      }
      status.msg = "Done.";
      textStatus.setText(status.toString());
    }
    catch(Exception e){
      status.msg = e.toString();
      textStatus.setText(status.toString());
    }
    result=null;
  }

  void OpenConnection_Action(ActionEvent event)
  {
    DialogConnection1 d = new DialogConnection1(this, true, connectionURL, driverName, true);
    d.show();
    if (d.OK) {
      status.clear();
      if (d.URL != null) {
         connectionURL = d.URL;
         status.msg = "Connection URL is  :"+connectionURL;
         textStatus.setText(status.toString());
       }
      if (d.Driver != null) {
         driverName = d.Driver;
         status.msg = "Driver name is :"+driverName;
         textStatus.setText(status.toString());
         loadDriver(driverName);
      }
    }
  }


  void PickConnection_Action(ActionEvent event)
  {
    DialogConnectionList1 d = new DialogConnectionList1(this, true, urlList);
    d.show();
    if (d.OK) {
      status.clear();
      if (d.SelectedItem != null) {
         connectionURL = d.SelectedItem;
         status.msg = "Connection URL is  :"+connectionURL;
         textStatus.setText(status.toString());
       }
      if (d.Database != null) {
         DbName = d.Database;
         connectionURL = MakeConnectURL(connectionURL, "DATABASE", DbName);
         status.msg = "Connection URL is  :"+connectionURL;
         textStatus.setText(status.toString());
      }
      if (d.Password != null) {
         password = d.Password;
         connectionURL = MakeConnectURL(connectionURL, "PWD", password);
         status.msg = "Connection URL is  :"+connectionURL;
         textStatus.setText(status.toString());
      }
      if (d.User != null) {
         userName = d.User;
         connectionURL = MakeConnectURL(connectionURL, "UID", userName);
         status.msg = "Connection URL is  :"+connectionURL;
         textStatus.setText(status.toString());
      }
    }
  }


  void ShowDeleted_Action(ItemEvent event) {
    try{
      showDeleted = ((CheckboxMenuItem)event.getSource()).getState();
      if (result != null) {
         result.setShowDeleted(showDeleted);
 	 updateInfo();
      }
    }
    catch (Exception e){
      status.msg = e.toString();
      textStatus.setText(status.toString());
    }
  }

  void Load_Action(ActionEvent event)
  {
    FileDialog d = new FileDialog(this, "Load RowSet from File", FileDialog.LOAD);
    d.show();
    String file = d.getFile();
    if (file != null) {
      file = d.getDirectory() + file;
      status.msg = "Loading rowset from file " +file;
      textStatus.setText(status.toString());

      try {
         if (result != null) {
            result.close();
            result = null;
         }
         Info.removeAll();
         super.show();
         ObjectInputStream in = new ObjectInputStream(new FileInputStream(file));
         result = (OPLCachedRowSet)in.readObject();
         in.close();
         status.clear();
         setInfo();
      } catch (Exception e) {
        status.msg = e.toString();
        textStatus.setText(status.toString());
      }
      status.msg = "Done.";
      textStatus.setText(status.toString());
    }
  }

  void Save_Action(ActionEvent event)
  {
    if (result == null) {
      status.msg = "RowSet is empty.";
      textStatus.setText(status.toString());
      return;
    }
    FileDialog d = new FileDialog(this, "Save RowSet to File", FileDialog.SAVE);
    d.show();
    String file = d.getFile();
    if (file != null) {
      file = d.getDirectory() + file;
      status.msg = "Saving rowset to file " +file;
      textStatus.setText(status.toString());

      try {
       ObjectOutputStream out = new ObjectOutputStream(new FileOutputStream(file));
       out.writeObject(result);
       out.close();
      } catch (Exception e) {
        status.msg = e.toString();
        textStatus.setText(status.toString());
      }

      status.msg = "Done.";
      textStatus.setText(status.toString());
    }
  }

  void this_windowClosing(WindowEvent event) {
    try {
      if (result!=null) {
	result.close();
	result = null;
      }
    } catch(Exception e) { }
    if (isApplet) {
	hide();         // hide the Frame
	dispose();      // free the system resources
    } else {
	Exit_Action(new ActionEvent(event.getSource(), event.getID(), "Exit"));
    }
  }

  void ExecuteQuery (String query)
    throws Exception
  {
    if (result != null) {
      result.close();
      result = null;
    }

    result = new OPLCachedRowSet();
    result.setUrl(connectionURL);
    result.setCommand(query);
    status.msg = "Connecting to :"+connectionURL + " and executing...";
    textStatus.setText(status.toString());
    result.execute();
    result.setShowDeleted(showDeleted);
    Info.removeAll();
    setInfo();
  }

  void setInfo() throws Exception {
    // Get Resultset information
    meta = result.getMetaData ();
    columnCount = meta.getColumnCount ();
    labelColumnName = new Label[columnCount];
    textColumnValue = new TextField[columnCount];
    data = new String[columnCount][1];
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
    status.msg = "Fetching result";
    textStatus.setText(status.toString());
    Color clr = Color.white;
    String msgEOF = null;
    try {
      if (result.rowDeleted())
        clr = Color.lightGray;
    } catch (SQLException e) { }

    for (int c = 1; c <= columnCount; c++){
        textColumnValue[c-1].setBackground(clr);
        try {
	  textColumnValue[c-1].setText (result.getString(c));
        } catch (SQLException e) {
	  textColumnValue[c-1].setText ("");
          status.msg = e.toString();
          textStatus.setText(status.toString());
        }
    }
    try {
      status.row = result.getRow();
      status.isDeleted = result.rowDeleted();
      status.isInserted = result.rowInserted();
      status.isUpdated = result.rowUpdated();
      if (result.isAfterLast())
        msgEOF = "(AfterLast) ";
      else if (result.isBeforeFirst())
        msgEOF = "(BeforeFirst) ";
      else if (result.isFirst())
        msgEOF = "(First) ";
      else if (result.isLast())
        msgEOF = "(Last) ";
    } catch (SQLException e) {}

    status.msg = (msgEOF != null ? msgEOF : "") + "   Done.";
    textStatus.setText(status.toString());
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
      status.msg = e.toString();
      textStatus.setText(status.toString());
    }
    this.driverName = driverName;
  }

  public CachedRowSet(String URL[], boolean isApplet)
    throws Exception
  {
    Panel panel1;
    Panel panel2;
    Panel panel3;
    Panel panel4;
    Panel panel5;
    Panel panel6;
    Panel panel7;
    Panel Toolbar;
    Font smallFont = new Font("Dialog", Font.PLAIN, 10);

    if (URL != null && URL.length > 0)
      connectionURL = URL[0];
    jdkVersion  = (System.getProperty("java.version")).substring(0,3);
    if (jdkVersion.equalsIgnoreCase("1.0")
	|| jdkVersion.equalsIgnoreCase("1.1"))
      throw new Exception("Wrong Java Virtual Machine");
    this.isApplet = isApplet;
    this.enableEvents(AWTEvent.WINDOW_EVENT_MASK);
    bListener = new BActionListener();
    mListener = new MActionListener();
    mIListener = new MItemListener();

    urlList = URL;
    menuBar1 = new MenuBar();
    menuFile = new Menu("File");
    mnNewThread = new MenuItem("New Thread");
    mnNewThread.addActionListener(mListener);
    menuFile.add(mnNewThread);
    if (!isApplet) {
      mnLoad = new MenuItem("Load from file...");
      mnLoad.addActionListener(mListener);
      menuFile.add(mnLoad);
      mnSave = new MenuItem("Save to file...");
      mnSave.addActionListener(mListener);
      menuFile.add(mnSave);
    }
    mnSetConn = new MenuItem("Set Connection URL...");
    mnSetConn.addActionListener(mListener);
    menuFile.add(mnSetConn);
    if (isApplet) {
      mnPickConn = new MenuItem("Pick Connection URL...");
      mnPickConn.addActionListener(mListener);
      menuFile.add(mnPickConn);
    }
    mnCloseConn = new MenuItem("Close RowSet");
    mnCloseConn.addActionListener(mListener);
    menuFile.add(mnCloseConn);
    if (!isApplet) {
      mnExit = new MenuItem("Exit");
      mnExit.addActionListener(mListener);
      menuFile.add(mnExit);
    }
    menuBar1.add(menuFile);

    menu1 = new Menu("Go To");
    mnFirst = new MenuItem("First");
    mnFirst.addActionListener(mListener);
    menu1.add(mnFirst);
    mnPrev = new MenuItem("Previous");
    mnPrev.addActionListener(mListener);
    menu1.add(mnPrev);
    mnNext = new MenuItem("Next");
    mnNext.addActionListener(mListener);
    menu1.add(mnNext);
    mnLast = new MenuItem("Last");
    mnLast.addActionListener(mListener);
    menu1.add(mnLast);
    mnAbsolute = new MenuItem("Absolute");
    mnAbsolute.addActionListener(mListener);
    menu1.add(mnAbsolute);
    menuBar1.add(menu1);
    menu2 = new Menu("Options");
    mnShowDeleted = new java.awt.CheckboxMenuItem("showDeleted");
    mnShowDeleted.addItemListener(mIListener);
    menu2.add(mnShowDeleted);
    menuBar1.add(menu2);

    setMenuBar(menuBar1);

    setLayout(new BorderLayout(0,5));
    setSize(getInsets().left + getInsets().right + 750,getInsets().top + getInsets().bottom + 500);
    setBackground(new Color(12632256));

    panel3 = new java.awt.Panel(new BorderLayout(5,10));
    panel3.setBackground(new Color(12632256));
    add("North", panel3);
    textQuery = new java.awt.TextField("SELECT * FROM \"Customers\"");
    textQuery.setBackground(new Color(16777215));
    panel3.add("Center", textQuery);


    Panel panelB = new Panel(new GridLayout(2, 1, 5, 5));
    buttonQuery = new java.awt.Button("Execute");
    buttonQuery.addActionListener(bListener);
    panelB.add(buttonQuery);

    buttonAccept = new java.awt.Button("Accept");
    buttonAccept.addActionListener(bListener);
    panelB.add(buttonAccept);

    panel3.add("East", panelB);

    Info = new java.awt.Panel();
    GridBagLayout gridBagLayout = new GridBagLayout();
    Info.setLayout(gridBagLayout);
    Info.setBackground(new Color(12632256));
    add("Center", Info);

    label1 = new java.awt.Label("",Label.RIGHT);
    label1.setBounds(141,95,14,21);
    GridBagConstraints gbc;
    gbc = new GridBagConstraints();
    gbc.weightx = 1;
    gbc.weighty = 1;
    gbc.fill = GridBagConstraints.NONE;
    gbc.insets = new Insets(0,0,0,0);
    gridBagLayout.setConstraints(label1, gbc);
    Info.add(label1);
    textField1 = new java.awt.TextField();
    textField1.setBounds(438,95,20,21);
    gbc = new GridBagConstraints();
    gbc.weightx = 1;
    gbc.weighty = 1;
    gbc.fill = GridBagConstraints.NONE;
    gbc.insets = new Insets(0,0,0,0);
    gridBagLayout.setConstraints(textField1, gbc);
    Info.add(textField1);
    panel4 = new java.awt.Panel();
    panel4.setLayout(new GridLayout(0,1,0,1));
    panel4.setBounds(getInsets().left + 0,getInsets().top + 233,600,92);
    add("South", panel4);

    Toolbar = new java.awt.Panel(new FlowLayout(FlowLayout.CENTER,10,1));
    Toolbar.setBackground(new Color(12632256));
    panel4.add(Toolbar);

    panel1 = new java.awt.Panel(new FlowLayout(FlowLayout.CENTER,2,0));
    Toolbar.add(panel1);
    buttonFirst = new java.awt.Button("  First  ");
    buttonFirst.setFont(smallFont);
    buttonFirst.addActionListener(bListener);
    panel1.add(buttonFirst);
    buttonPrevious = new java.awt.Button("Previous");
    buttonPrevious.setFont(smallFont);
    buttonPrevious.addActionListener(bListener);
    panel1.add(buttonPrevious);
    buttonNext = new java.awt.Button("  Next  ");
    buttonNext.setFont(smallFont);
    buttonNext.addActionListener(bListener);
    panel1.add(buttonNext);
    buttonLast = new java.awt.Button("  Last  ");
    buttonLast.setFont(smallFont);
    buttonLast.addActionListener(bListener);
    panel1.add(buttonLast);

    panel2 = new java.awt.Panel();
    panel2.setLayout(new FlowLayout(FlowLayout.CENTER,2,0));
    Toolbar.add(panel2);
    buttonDelete = new java.awt.Button("Delete");
    buttonDelete.setFont(smallFont);
    buttonDelete.addActionListener(bListener);
    panel2.add(buttonDelete);
    buttonRefresh = new java.awt.Button("Refresh");
    buttonRefresh.setFont(smallFont);
    buttonRefresh.addActionListener(bListener);
    panel2.add(buttonRefresh);
    buttonInsert = new java.awt.Button("Insert");
    buttonInsert.setFont(smallFont);
    buttonInsert.addActionListener(bListener);
    panel2.add(buttonInsert);
    buttonUpdate = new java.awt.Button("Update");
    buttonUpdate.setFont(smallFont);
    buttonUpdate.addActionListener(bListener);
    panel2.add(buttonUpdate);

    panel5 = new java.awt.Panel(new FlowLayout(FlowLayout.CENTER,2,0));
    panel4.add(panel5);
    buttonAbsolute = new java.awt.Button("Absolute");
    buttonAbsolute.setFont(smallFont);
    buttonAbsolute.addActionListener(bListener);
    panel5.add(buttonAbsolute);
    buttonRelative = new java.awt.Button("Relative");
    buttonRelative.setFont(smallFont);
    buttonRelative.addActionListener(bListener);
    panel5.add(buttonRelative);
    textPos = new java.awt.TextField();
    textPos.setText("1");
    textPos.setBounds(397,5,28,21);
    textPos.setFont(smallFont);
    panel5.add(textPos);

    Toolbar = new java.awt.Panel(new FlowLayout(FlowLayout.CENTER,10,1));
    Toolbar.setBackground(new Color(12632256));
    panel4.add(Toolbar);

    panel6 = new java.awt.Panel(new FlowLayout(FlowLayout.CENTER,2,0));
    Toolbar.add(panel6);
    buttonCancelDel = new java.awt.Button("CancelDelete");
    buttonCancelDel.setFont(smallFont);
    buttonCancelDel.addActionListener(bListener);
    panel6.add(buttonCancelDel);
    buttonCancelIns = new java.awt.Button("CancelInsert");
    buttonCancelIns.setFont(smallFont);
    buttonCancelIns.addActionListener(bListener);
    panel6.add(buttonCancelIns);
    buttonCancelUpd = new java.awt.Button("CancelUpdate");
    buttonCancelUpd.setFont(smallFont);
    buttonCancelUpd.addActionListener(bListener);
    panel6.add(buttonCancelUpd);

    panel7 = new java.awt.Panel(new FlowLayout(FlowLayout.CENTER,2,0));
    Toolbar.add(panel7);
    buttonOriginalAll = new java.awt.Button    (" SetOriginal ");
    buttonOriginalAll.setFont(smallFont);
    buttonOriginalAll.addActionListener(bListener);
    panel7.add(buttonOriginalAll);
    buttonOriginalRow = new java.awt.Button    ("SetOriginalRow");
    buttonOriginalRow.setFont(smallFont);
    buttonOriginalRow.addActionListener(bListener);
    panel7.add(buttonOriginalRow);
    buttonRestoreOriginal = new java.awt.Button("RestoreOriginal");
    buttonRestoreOriginal.setFont(smallFont);
    buttonRestoreOriginal.addActionListener(bListener);
    panel7.add(buttonRestoreOriginal);

    textStatus = new java.awt.TextField();
    textStatus.setEditable(false);
    textStatus.setBounds(0,62,600,30);
    panel4.add(textStatus);
    setTitle("OpenLink Virtuoso JDBC CachedRowSet Demo");

    Info.remove(label1);
    Info.remove(textField1);

    loadDriver("virtuoso.jdbc3.Driver");
  }

  public void show()
  {
    setLocation(20*myThreadNum, 20*myThreadNum);
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


  /**Overridden so we can exit when window is closed*/
  protected void processWindowEvent(WindowEvent e) {
    if (e.getID() == WindowEvent.WINDOW_CLOSING) {
       this_windowClosing(e);
    }
    super.processWindowEvent(e);
  }


  static public void main(String args[])
    throws Exception
  {
    CachedRowSet sd = new CachedRowSet(args, false);
    if(args.length > 0)
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


  class BActionListener implements ActionListener {
    public void actionPerformed(ActionEvent e) {
      Object c = e.getSource();
      if (c == buttonQuery)
          buttonQuery_Clicked(e);
      else
      if (c == buttonAccept)
          buttonAccept_Clicked(e);
      else
      if (c == buttonFirst)
          buttonFirst_Clicked(e);
      else
      if (c == buttonPrevious)
          buttonPrevious_Clicked(e);
      else
      if (c == buttonNext)
          buttonNext_Clicked(e);
      else
      if (c == buttonLast)
          buttonLast_Clicked(e);
      else
      if (c == buttonDelete)
          buttonDelete_Clicked(e);
      else
      if (c == buttonRefresh)
          buttonRefresh_Clicked(e);
      else
      if (c == buttonInsert)
          buttonInsert_Clicked(e);
      else
      if (c == buttonUpdate)
          buttonUpdate_Clicked(e);
      else
      if (c == buttonAbsolute)
          buttonAbsolute_Clicked(e);
      else
      if (c == buttonRelative)
          buttonRelative_Clicked(e);
      else
      if (c == buttonCancelDel)
          buttonCancelDel_Clicked(e);
      else
      if (c == buttonCancelIns)
          buttonCancelIns_Clicked(e);
      else
      if (c == buttonCancelUpd)
          buttonCancelUpd_Clicked(e);
      else
      if (c == buttonOriginalAll)
          buttonOriginalAll_Clicked(e);
      else
      if (c == buttonOriginalRow)
          buttonOriginalRow_Clicked(e);
      else
      if (c == buttonRestoreOriginal)
          buttonRestoreOriginal_Clicked(e);
    }
  }

  class MActionListener implements ActionListener {
    public void actionPerformed(ActionEvent e) {
      Object c = e.getSource();
      if (c == mnNewThread)
          NewThread_Action(e);
      else
      if (c == mnSetConn)
          OpenConnection_Action(e);
      else
      if (c == mnPickConn)
          PickConnection_Action(e);
      else
      if (c == mnCloseConn)
          CloseConnection_Action(e);
      else
      if (c == mnExit)
          Exit_Action(e);
      else
      if (c == mnFirst)
          buttonFirst_Clicked(e);
      else
      if (c == mnPrev)
          buttonPrevious_Clicked(e);
      else
      if (c == mnNext)
          buttonNext_Clicked(e);
      else
      if (c == mnLast)
          buttonLast_Clicked(e);
      else
      if (c == mnAbsolute)
          buttonAbsolute_Clicked(e);
      else
      if (c == mnLoad)
          Load_Action(e);
      else
      if (c == mnSave)
          Save_Action(e);
    }
  }

  class MItemListener implements ItemListener {
    public void itemStateChanged(ItemEvent e) {
      Object c = e.getSource();
      if (c == mnShowDeleted) {
          ShowDeleted_Action(e);
      }
    }
  }

  class StatusMsg {
    int row;
    boolean isDeleted;
    boolean isInserted;
    boolean isUpdated;
    String msg = "";

    void clear() {
      row = 0;
      isDeleted = false;
      isInserted = false;
      isUpdated = false;
      msg = "";
    }
    public String toString() {
      StringBuffer tmp = new StringBuffer();
      tmp.append("Row ");
      tmp.append(row);
      tmp.append(" [");
      tmp.append(isDeleted  ? 'D' : ' ');
      tmp.append(':' );
      tmp.append(isInserted ? 'I' : ' ');
      tmp.append(':' );
      tmp.append(isUpdated  ? 'U' : ' ');
      tmp.append("] ");
      tmp.append(msg);
      return tmp.toString();
    }
  }

}
