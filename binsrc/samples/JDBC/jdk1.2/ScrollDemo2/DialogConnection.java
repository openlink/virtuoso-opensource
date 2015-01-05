/*
 *  DialogConnection.java
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

public class DialogConnection extends Dialog
{
  void buttonCancel_Clicked(Event event)
  {
    this.hide();
  }

  void buttonOK_Clicked(Event event)
  {
    Event myEvent = new Event(getParent(), -1, textURL.getText());
    getParent().handleEvent(myEvent);
    if (bShowDriver)
    {
      myEvent = new Event(getParent(), -2, textDriver.getText());
      getParent().handleEvent(myEvent);
    }
    this.hide();
  }


  public DialogConnection(Frame parent, boolean modal, String urlText, String driverText, boolean bShowDriver)
  {
    super(parent, modal);
    this.bShowDriver = bShowDriver;
    jdkVersion  = (System.getProperty("java.version")).substring(0,3);
    addNotify();
    resize(insets().left + insets().right + 350,insets().top + insets().bottom + 150);
    setBackground(new Color(12632256));
    GridBagLayout gbl = new GridBagLayout();
    setLayout(gbl);
    GridBagConstraints gbc = new GridBagConstraints();
    gbc.insets = new Insets(2,2,2,2);

    if (bShowDriver)
    {
      gbc.fill = GridBagConstraints.VERTICAL;
      gbc.anchor = GridBagConstraints.WEST;
      gbc.weightx = 1;
      gbc.gridwidth=1;
      gbc.gridx=0;
      label2 = new java.awt.Label("Driver Name :");
      gbl.setConstraints(label2,gbc);
      add(label2);

      textDriver = new java.awt.TextField();
      gbc.fill = GridBagConstraints.HORIZONTAL;
      gbc.gridwidth=GridBagConstraints.REMAINDER ;
      gbc.anchor = GridBagConstraints.CENTER;
      gbl.setConstraints(textDriver,gbc);
      add(textDriver);
    }

    gbc.fill = GridBagConstraints.VERTICAL;
    gbc.anchor = GridBagConstraints.WEST;
    gbc.weightx = 1;
    gbc.gridwidth=1;
    gbc.gridx=0;
    label1 = new java.awt.Label("Connection URL :");
    gbl.setConstraints(label1,gbc);
    add(label1);

    textURL = new java.awt.TextField();
    gbc.fill = GridBagConstraints.BOTH;
    gbc.gridwidth=GridBagConstraints.REMAINDER ;
    gbc.anchor = GridBagConstraints.CENTER;
    gbl.setConstraints(textURL,gbc);
    add(textURL);


    panel3 = new java.awt.Panel();
    gbc.anchor = GridBagConstraints.WEST;
    gbc.gridx=0;
    gbc.weightx = 1;
    gbc.gridwidth=1;
    gbc.fill = GridBagConstraints.BOTH;
    gbl.setConstraints(panel3,gbc);
    add(panel3);

    gbc.gridx=GridBagConstraints.RELATIVE;
    buttonOK = new java.awt.Button("OK");
    gbl.setConstraints(buttonOK,gbc);
    add(buttonOK);

    buttonCancel = new java.awt.Button("Cancel");
    gbl.setConstraints(buttonCancel,gbc);
    add(buttonCancel);
    setTitle("Connection");
    if (bShowDriver)
      textDriver.setText(driverText);
    textURL.setText(urlText);
  }


  public void show()
  {

    Rectangle bounds = getParent().bounds();
    Rectangle abounds = bounds();

    move(bounds.x + (bounds.width - abounds.width)/ 2,
	 bounds.y + (bounds.height - abounds.height)/2);
    super.show();
  }


  public boolean handleEvent(Event event)
  {
    if(event.id == Event.WINDOW_DESTROY)
    {
      hide();
      return true;
    }
    if (event.target == buttonOK && event.id == Event.ACTION_EVENT)
    {
      buttonOK_Clicked(event);
      return true;
    }
    if (event.target == buttonCancel && event.id == Event.ACTION_EVENT)
    {
      buttonCancel_Clicked(event);
      return true;
    }
    return super.handleEvent(event);
  }

  java.awt.Panel panel1, panel2, panel3;
  java.awt.TextField textURL, textDriver;
  java.awt.Label label1, label2;
  java.awt.Button buttonOK;
  java.awt.Button buttonCancel;
  String jdkVersion;
  boolean bShowDriver=false;
}
