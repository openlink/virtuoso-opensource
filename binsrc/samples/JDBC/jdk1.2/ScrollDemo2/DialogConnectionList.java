/*
 *  DialogConnectionList.java
 *
 *  $Id$
 *
 *  URL picklist
 *  
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *  
 *  Copyright (C) 1998-2018 OpenLink Software
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


class DialogConnectionList extends Dialog
{

  void buttonCancel_Clicked(Event event)
  {
    this.hide();
  }

  void buttonOK_Clicked(Event event)
  {
    Event myEvent = new Event(getParent(), -1, urlList.getSelectedItem());
    getParent().handleEvent(myEvent);
    myEvent = new Event(getParent(), -5, textDb.getText());
    getParent().handleEvent(myEvent);
    myEvent = new Event(getParent(), -3, textUser.getText());
    getParent().handleEvent(myEvent);
    myEvent = new Event(getParent(), -4, textPass.getText());
    getParent().handleEvent(myEvent);
    this.hide();
  }


  public DialogConnectionList(Frame parent, boolean modal, String paramList[])
  {
    super(parent, modal);
    addNotify();
    resize(insets().left + insets().right + 400,insets().top + insets().bottom +250);
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
    textPass.setEchoCharacter('*');
    gbc.gridwidth=GridBagConstraints.REMAINDER ;
    gbl.setConstraints(textPass,gbc);
    add(textPass);


    panel3 = new java.awt.Panel();
    gbc.gridwidth=1;
    gbc.fill = GridBagConstraints.BOTH;
    gbl.setConstraints(panel2,gbc);
    add(panel2);
    buttonOK = new java.awt.Button("OK");
    gbl.setConstraints(buttonOK,gbc);
    add(buttonOK);
    buttonCancel = new java.awt.Button("Cancel");
    gbl.setConstraints(buttonCancel,gbc);
    add(buttonCancel);

    setTitle("Pick Connection URL");
    if (paramList != null && paramList.length >0)
    {
      for (int i = 0; i < paramList.length; i++)
	urlList.addItem(paramList[i]);
    }
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

  java.awt.List urlList;
  java.awt.Panel panel1, panel2, panel3;
  java.awt.Label label1, label2, label3, label4;
  java.awt.Button buttonOK;
  java.awt.Button buttonCancel;
  java.awt.TextField textUser, textPass, textDb;
}
