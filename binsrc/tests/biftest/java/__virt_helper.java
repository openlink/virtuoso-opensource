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
 */

import java.rmi.*;

public class __virt_helper
{
   private final static ThreadGroup _applicationThreadGroup = Thread.currentThread().getThreadGroup();

   public Object deserialize (byte bytes[]) throws Exception
     {
//System.err.println ("deserialize: Bytes len=" + bytes.length);
       String sjsjsjs;
       java.io.ByteArrayInputStream bis = new java.io.ByteArrayInputStream (bytes);
       java.io.ObjectInputStream ois = new java.io.ObjectInputStream (bis);
//     System.err.println ("deserialize: before read_object");
       Object ret = ois.readObject();
//     System.err.println ("deserialize: after read_object : obj=" + ret.getClass().getName() + " [" + ret + "]");
       return ret;
     }
   public byte[] serialize (Object obj) throws Exception
     {
       //System.err.println ("serialize: Obj=" + obj.getClass().getName() + " [" + obj + "]");
       java.io.ByteArrayOutputStream bos = new java.io.ByteArrayOutputStream ();
       java.io.ObjectOutputStream oos = new java.io.ObjectOutputStream (bos);
       //System.err.println ("serialize: before writeObject");
       oos.writeObject(obj);
       //System.err.println ("serialize: before flush");
       oos.flush();
       //System.err.println ("serialize: before toByteArray");
       byte [] bytes = bos.toByteArray ();
       //System.err.println ("serialize: Bytes len=" + bytes.length);
       return bytes;
     }

   public void set_access_granter () throws Exception
     {
       if (System.getSecurityManager() == null)
	 System.setSecurityManager(new __virt_access_granter());
//     System.err.println ("set_access_granter is called !!!");
     }

   public void set_unresticted_perms () throws Exception
     {
       try
	 {
	   Thread.currentThread().setContextClassLoader(new __virt_class_loader_ur ());
	 }
       catch (Exception e)
	 {
//	   System.err.println("ERROR set_unresticted_perms");
	 }

//     System.err.println ("set_unresticted_perms");
     }

   public void set_resticted_perms () throws Exception
     {
       try
	 {
	   Thread.currentThread().setContextClassLoader(new __virt_class_loader_r ());
	 }
       catch (Exception e)
	 {
//	   System.err.println("ERROR set_resticted_perms");
	 }
     }
}

