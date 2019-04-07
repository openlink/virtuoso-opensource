/*
 *  DialogConnection1.java
 *
 *  $Id$
 *
 *  Sample JDBC program
 *  
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *  
 *  Copyright (C) 1998-2019 OpenLink Software
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
import java.awt.event.*;

public class DialogConnection1 extends Dialog implements ActionListener
{
  Panel panel1, panel2, panel3;
  TextField textURL, textDriver;
  Label label1, label2;
  Button buttonOK;
  Button buttonCancel;
  boolean bShowDriver=false;
  boolean OK = false;
  String URL;
  String Driver;


  public DialogConnection1(Frame parent, boolean modal, String urlText, String driverText, boolean bShowDriver)
  {
    super(parent, modal);
    this.bShowDriver = bShowDriver;
    this.enableEvents(AWTEvent.WINDOW_EVENT_MASK);
    setSize(getInsets().left + getInsets().right + 350,getInsets().top + getInsets().bottom + 180);
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
    buttonOK.addActionListener(this);
    gbl.setConstraints(buttonOK,gbc);
    add(buttonOK);

    buttonCancel = new java.awt.Button("Cancel");
    buttonCancel.addActionListener(this);
    gbl.setConstraints(buttonCancel,gbc);
    add(buttonCancel);
    setTitle("Connection");
    if (bShowDriver)
      textDriver.setText(driverText);
    textURL.setText(urlText);
  }


  public void show()
  {

    Rectangle bounds = getParent().getBounds();
    Rectangle abounds = getBounds();

    setLocation(bounds.x + (bounds.width - abounds.width)/ 2,
	 bounds.y + (bounds.height - abounds.height)/2);
    super.show();
  }



  /**Overridden so we can exit when window is closed*/
  protected void processWindowEvent(WindowEvent e) {
    if (e.getID() == WindowEvent.WINDOW_CLOSING) {
       hide();
    }
    super.processWindowEvent(e);
  }

  public void actionPerformed(ActionEvent e) {
    Object c = e.getSource();
    if (c == buttonOK) {
       OK = true;
       URL = textURL.getText();
       if (bShowDriver)
          Driver = textDriver.getText();
       this.hide();
    }
    else
    if (c == buttonCancel) {
       hide();
    }
  }

}
