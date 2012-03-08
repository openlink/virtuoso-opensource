/*
 *  DialogConnectionList1.java
 *
 *  $Id$
 *
 *  URL picklist
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
import java.awt.*;
import java.awt.event.*;


class DialogConnectionList1 extends Dialog implements ActionListener
{
  List urlList;
  Panel panel1, panel2, panel3;
  Label label1, label2, label3, label4;
  Button buttonOK;
  Button buttonCancel;
  TextField textUser, textPass, textDb;
  boolean OK = false;
  String Database;
  String User;
  String Password;
  String SelectedItem;

  public DialogConnectionList1(Frame parent, boolean modal, String paramList[])
  {
    super(parent, modal);
    this.enableEvents(AWTEvent.WINDOW_EVENT_MASK);
    setSize(getInsets().left + getInsets().right + 400,getInsets().top + getInsets().bottom +250);
    setBackground(new Color(12632256));
    GridBagLayout gbl = new GridBagLayout();
    setLayout(gbl);
    GridBagConstraints gbc = new GridBagConstraints();
    gbc.insets = new Insets(2,2,2,2);
    gbc.fill = GridBagConstraints.VERTICAL;
    gbc.anchor = GridBagConstraints.WEST;
    gbc.weightx = 1;
    label1 = new java.awt.Label("Choose URL:");
    gbl.setConstraints(label1,gbc);
    add(label1);
    panel1 = new java.awt.Panel();
    gbc.gridwidth=GridBagConstraints.REMAINDER ;
    gbl.setConstraints(panel1,gbc);
    add(panel1);
    urlList = new java.awt.List();
    gbc.weighty = 1;
    gbc.fill = GridBagConstraints.BOTH;
    gbc.anchor = GridBagConstraints.CENTER;
    gbl.setConstraints(urlList,gbc);
    add(urlList);

    panel2 = new java.awt.Panel();
    gbc.weighty = 0;
    gbc.gridwidth=1;
    gbc.fill = GridBagConstraints.BOTH;
    gbl.setConstraints(panel2,gbc);
    add(panel2);

    label4 = new java.awt.Label("Database:");
    gbc.gridwidth=1;
    gbl.setConstraints(label4,gbc);
    add(label4);
    textDb = new java.awt.TextField();
    gbc.gridwidth=GridBagConstraints.REMAINDER ;
    gbl.setConstraints(textDb,gbc);
    add(textDb);

    label2 = new java.awt.Label("Username:");
    gbc.gridwidth=1;
    gbl.setConstraints(label2,gbc);
    add(label2);
    textUser = new java.awt.TextField();
    gbc.gridwidth=GridBagConstraints.REMAINDER ;
    gbl.setConstraints(textUser,gbc);
    add(textUser);

    label3 = new java.awt.Label("Password:");
    gbc.gridwidth=1;
    gbl.setConstraints(label3,gbc);
    add(label3);
    textPass = new java.awt.TextField();
    textPass.setEchoChar('*');
    gbc.gridwidth=GridBagConstraints.REMAINDER ;
    gbl.setConstraints(textPass,gbc);
    add(textPass);


    panel3 = new java.awt.Panel();
    gbc.gridwidth=1;
    gbc.fill = GridBagConstraints.BOTH;
    gbl.setConstraints(panel2,gbc);
    add(panel2);
    buttonOK = new java.awt.Button("OK");
    buttonOK.addActionListener(this);
    gbl.setConstraints(buttonOK,gbc);
    add(buttonOK);
    buttonCancel = new java.awt.Button("Cancel");
    buttonCancel.addActionListener(this);
    gbl.setConstraints(buttonCancel,gbc);
    add(buttonCancel);

    setTitle("Pick Connection URL");
    if (paramList != null && paramList.length >0)
    {
      for (int i = 0; i < paramList.length; i++)
	urlList.add(paramList[i]);
    }
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
       SelectedItem = urlList.getSelectedItem();
       Database = textDb.getText();
       User = textUser.getText();
       Password = textPass.getText();
       hide();
    }
    else
    if (c == buttonCancel) {
       hide();
    }
  }

}
