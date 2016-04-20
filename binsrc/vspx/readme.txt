VSPX Setup & Test
=================

1) on a freash demo DB replay the vspx_demo_init.sql
   ie.
   isql 1111 dba dba vspx_demo_init.sql

   the script makes a virtual directory /vspx (for testing purposes)
   and load demo procedures.

2) make a symbolic link (or make a copy) of ~/binsrc/vspx ,
    under ~/binsrc/vsp directory

3) Try some examples
   http://[yourhost:httpport]/vspx/sample.vspx  - generic update form
   http://[yourhost:httpport]/vspx/datagrid.vspx - data grid control
   http://[yourhost:httpport]/vspx/search.vspx	 - generic form + scriptable button & data grid
   http://[yourhost:httpport]/vspx/login.vspx    - login sample
   http://[yourhost:httpport]/vspx/label.vspx    - some more simple controls : url, label

   or

   simply enter
   http://[yourhost:httpport]/vspx/ to got list of them


making a VSPX docs
============

1) starup a virtuoso server
2) edit make_docs.sql file and put inital path for working home ie. $HOME
3) ensure directory docs/ under vspx one (ie. current)
4) run the script ie. isql 1111 dba dba make_docs.sql
