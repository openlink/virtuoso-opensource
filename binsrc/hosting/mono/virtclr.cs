//
//  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
//  project.
//
//  Copyright (C) 1998-2016 OpenLink Software
//
//  This project is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the
//  Free Software Foundation; only version 2 of the License, dated June 1991.
//
//  This program is distributed in the hope that it will be useful, but
//  WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
//  General Public License for more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA
//
//
using System;
using System.Runtime.Remoting;
using System.Collections;
using System.Reflection;
using System.Security;
using System.Text;
using System.IO;
using System.Runtime.InteropServices;
using System.Runtime.Serialization;
using System.Runtime.Serialization.Formatters.Binary;
using System.Runtime.Serialization.Formatters.Soap;
using System.Runtime.CompilerServices;
using System.Security.Permissions;
using System.Reflection.Emit;
using System.Globalization;
using System.Threading;
using System.Management;
using Microsoft.Win32;
using System.Web;
using System.Web.Hosting;
using System.Xml.Serialization;

using System.CodeDom;
using System.CodeDom.Compiler;
using Microsoft.CSharp;
using System.Diagnostics;
using System.Collections.Specialized;


[assembly:AssemblyVersionAttribute("1.0.2.1")]
[assembly:AssemblyCompanyAttribute("OpenLink Software")]
[assembly:AssemblyKeyFileAttribute("virtkey.snk")]

[ClassInterface(ClassInterfaceType.AutoDual)]
public class VInvoke
{

  private ResolveEventHandler hndlr;
  private static StringCollection assemblies;
//private static Hashtable assem_perm_list;
  public VInvoke() {
    hndlr = new ResolveEventHandler (MyResolveEventHandler);
    assemblies = new StringCollection();
//  assem_perm_list = new Hashtable ();
  }

  #region public interface
  public Object[] call_method_asm (Int32 asem_type, Int32 sec_unrestricted, String assem, String atype,
      String method, Object[] vparams, IntPtr [] oparams)
    {
      Object [] ret = new Object[2];
#if !MONO
      try
	{
#endif
	  Type type = get_type (asem_type, assem, atype);

	  vparams = change_ptr (vparams, oparams);

	  /* Get the methods from the type */
	  MethodInfo[] methods = type.GetMethods();

	  if(methods == null)
	    {
	      throw new Exception ("No methods Found in " + type.FullName);
	    }

	  StringBuilder failureExcuses = new StringBuilder();

	  try
	    {
	      foreach(MethodInfo m in methods)
		{
		  if (m.Name == method && CheckArgs (m, vparams))
		    {
#if !MONO
		      if (sec_unrestricted == 0)
			{
			  ZoneIdentityPermission zip = new ZoneIdentityPermission(SecurityZone.NoZone);
			  zip.PermitOnly();
			}
#endif
		      return res_to_ptr (m.Invoke (null, vparams));
		    }
		}
	    }
	  catch (TargetInvocationException e)
	    {
	      throw e.InnerException;
	    }

	  throw new Exception ("No method " + method + " called");
#if !MONO
	}
      catch (Exception e)
	{
	  ret[0] = 0;
	  ret[1] = e.Message;
	  return ret;
	}
#endif
    }


  public Object[] get_copy (IntPtr in_gc)
    {
      if (in_gc == (IntPtr) 0)
	throw new Exception ("object handle not supposed to be 0");
      GCHandle real_instance;
      Object [] ret = new Object[2];
      real_instance = (GCHandle) (in_gc);
      Object new_instance = real_instance.Target;

      GCHandle to_save = GCHandle.Alloc (new_instance, GCHandleType.Normal);

      ret[0]=6;
      ret[1]=(int)(IntPtr) to_save;
      if (in_gc == (IntPtr) to_save)
	throw new Exception ("copied object handle is the same as the original");

      return ret;
    }



  public Object[] obj_serialize (IntPtr in_gc)
    {
      GCHandle real_instance;
      Object new_instance;

      if (in_gc == (IntPtr) 0)
	throw new Exception ("object handle not supposed to be 0");
      real_instance = (GCHandle) (in_gc);
      new_instance = real_instance.Target;
      return res_to_ptr (obj_serialize_int (new_instance, new BinaryFormatter()));
    }


  public Object[] obj_serialize_soap (IntPtr in_gc)
    {
      GCHandle real_instance;
      Object new_instance;
      if (in_gc == (IntPtr) 0)
	throw new Exception ("object handle not supposed to be 0");
      real_instance = (GCHandle) (in_gc);
      new_instance = real_instance.Target;
      return res_to_ptr (obj_serialize_int (new_instance, new SoapFormatter()));
    }



  public Object[] obj_deserialize (byte [] in_bytes, Int32 asem_type, String assem, String atype)
    {
      IFormatter fmt;
      if (in_bytes != null && in_bytes.Length > 2 && in_bytes[0] == 0x3c && in_bytes[1] == 0x53)
	fmt = new SoapFormatter();
      else
	fmt = new BinaryFormatter();
      return obj_deserialize_int (in_bytes, asem_type, assem, atype, fmt);
    }


  public Object[] obj_deserialize_soap (byte [] in_bytes, Int32 asem_type, String assem, String atype)
    {
      return obj_deserialize_int (in_bytes, asem_type, assem, atype, new SoapFormatter());
    }


  public Object[] obj_deserialize_bin (byte [] in_bytes, Int32 asem_type, String assem, String atype)
    {
      return obj_deserialize_int (in_bytes, asem_type, assem, atype, new BinaryFormatter());
    }


  public static Object get_inst (IntPtr in_gc)
    {
      if (in_gc == (IntPtr) 0)
	throw new Exception ("object handle not supposed to be 0");
      GCHandle real_instance;
      Object ret_instance;

      real_instance = (GCHandle) (in_gc);

      if (real_instance.IsAllocated)
	{
	  ret_instance = real_instance.Target;
	}
      else
	{
	  throw new Exception ("Can't get instance of the Object");
	}

      return ret_instance;
    }


  public Object[] call_ins (IntPtr instance, Int32 sec_unrestricted, String method,
      			    Object[] vparams, IntPtr [] oparams)
    {
      Object new_instance;
      Type instance_type;
      String assem_name;
      Object [] ret = new Object[2];

#if !MONO
      try
	{
#endif
	  new_instance = get_inst (instance);
	  instance_type = new_instance.GetType();
	  assem_name = instance_type.Assembly.FullName.ToString();
	  int pos = assem_name.IndexOf (",");
	  if (pos != -1)
	    assem_name = assem_name.Substring (0, pos);

	  vparams = change_ptr (vparams, oparams);
	  MethodInfo[] methods = instance_type.GetMethods();
	  /* TODO Change to temp.GetMethod (strin, Binding Flags, NULL, Type[], NULL) */
	  try
	    {
	      foreach(MethodInfo m in methods)
		{
		  if (m.Name != method)
		    {
		      continue;
		    }
		  else
		    {
		      if (CheckArgs(m, vparams))
			{
#if !MONO
			  if (sec_unrestricted == 0)
			    {
			      ZoneIdentityPermission zip = new ZoneIdentityPermission(SecurityZone.NoZone);
			      zip.PermitOnly();
			    }
#endif
			  /* ->  Ready  <- */
			  return res_to_ptr (m.Invoke(new_instance, vparams));
			}
		      else
			continue;
		    }
		}
	    }
	  catch (TargetInvocationException e)
	    {
	      throw e.InnerException;
	    }

	  throw new Exception ("Method " + method + " not found in call_ins");
#if !MONO
	}
      catch (Exception e)
	{
	  ret[0] = 0;
	  ret[1] = e.Message;
	  return ret;
	}
#endif
    }



  public Object[] get_prop (IntPtr instance, String prop_name)
    {
      Object [] ret = new Object[2];
      if (instance == (IntPtr) 0)
	throw new Exception ("object handle not supposed to be 0");

      GCHandle real_instance;
      Object new_instance;
      Type instance_type;
      real_instance = (GCHandle) (instance);
      new_instance = real_instance.Target;
      instance_type = new_instance.GetType();

      FieldInfo[] field_infos = instance_type.GetFields(BindingFlags.NonPublic |
	  BindingFlags.Instance | BindingFlags.Public);
      foreach(FieldInfo fi in field_infos)
	{
	  if (fi.Name == prop_name && !fi.IsStatic)
	    {
	      try
		{
		  Object ret_m = null;

		  ret_m = fi.GetValue(new_instance);

		  return res_to_ptr (ret_m);
		}
	      catch
		{
		  continue;
		}
	    }
	}

      PropertyInfo[] props = instance_type.GetProperties(BindingFlags.NonPublic |
	  BindingFlags.Instance | BindingFlags.Public);
      foreach(PropertyInfo p in props)
	{
	  if (p.Name == prop_name)
	    {
	      try
		{
		  Object ret_m = null;

		  ret_m = p.GetValue(new_instance, null);

		  return res_to_ptr (ret_m);
		}
	      catch
		{
		  continue;
		}
	    }
	}

      throw new Exception ("Property " + prop_name + " not found");
    }


  public Object[] set_prop (IntPtr instance, String prop_name, Object[] vparams, IntPtr [] oparams)
    {
      Object [] ret = new Object[2];
      if (instance == (IntPtr) 0)
	throw new Exception ("object handle not supposed to be 0");

      GCHandle real_instance = (GCHandle) (instance);;
      Object new_instance = real_instance.Target;
      Type instance_type = new_instance.GetType();
      int is_call = 0;

      vparams = change_ptr (vparams, oparams);

      FieldInfo[] field_infos = instance_type.GetFields(BindingFlags.NonPublic |
	  BindingFlags.Instance | BindingFlags.Public);

      foreach(FieldInfo fi in field_infos)
	{
	  if (fi.Name == prop_name && !fi.IsStatic)
	    {
	      try
		{
		  fi.SetValue(new_instance, vparams[0]);
		  is_call = 1;
		}
	      catch
		{
		  continue;
		}
	    }
	}

      if (is_call != 1)
	{
	  PropertyInfo[] prop_infos = instance_type.GetProperties();

	  foreach(PropertyInfo fi in prop_infos)
	    {
	  if (fi.Name != prop_name)
	    {
	      continue;
	    }
	  else
	    {
	      try
		{
		  Object ret_m = null;

		  ret_m = instance_type.GetField (prop_name);
		  fi.SetValue(new_instance, vparams[0], null);
		  is_call = 1;
		}
	      catch
		{
		  continue;
		    }
		}
	    }
	}

      if (is_call == 1)
	{
	  ret[0]=7;
	  ret[1]=0;
	}
      else
	{
	  throw new Exception ("Property " + prop_name + " not found in set_prop");
	}
      return ret;
    }


  public Object[] create_ins_asm (Int32 asem_type, String assem, String atype,
      Object[] vparams, IntPtr [] oparams)
    {
      Object [] ret = new Object[2];

      Type type = get_type (asem_type, assem, atype);

      /* Get the methods from the type */
      MethodInfo[] methods = type.GetMethods();

      if(methods == null)
	{
	  throw new Exception ("No Matching Types Found");
	}

      vparams = change_ptr (vparams, oparams);

      Object instance = null;
      instance = Activator.CreateInstance(type, vparams);

      GCHandle to_save = GCHandle.Alloc (instance, GCHandleType.Normal);

      ret[0]=6;
      ret[1]=(int)(IntPtr) to_save;

      return ret;
    }


  public Object[] free_ins (IntPtr instance)
  {
    if (instance == (IntPtr) 0)
      throw new Exception ("object handle not supposed to be 0");
    GCHandle real_instance;
    Object [] ret = new Object[2];
    real_instance = (GCHandle) (instance);
    real_instance.Free();
    ret[0]=7;
    ret[1]=1;

    return ret;
  }


  public Object[] get_stat_prop (Int32 asem_type, String assem, String atype, String prop)
  {
    Object [] ret = new Object[2];

    Type instance_type = get_type (asem_type, assem, atype);

    FieldInfo[] field_infos = instance_type.GetFields(BindingFlags.NonPublic |
      BindingFlags.Static | BindingFlags.Public);
    foreach(FieldInfo fi in field_infos)
    {
      /*Console.WriteLine ("fld: " + fi.Name);*/
      if (fi.Name == prop && fi.IsStatic)
      {
	try
	{
	  Object ret_m = null;

	  ret_m = fi.GetValue(null);

	  return res_to_ptr (ret_m);
	}
	catch /*(Exception e)*/
	{
	  continue;
	}
      }
    }

    PropertyInfo[] props = instance_type.GetProperties(BindingFlags.NonPublic |
      BindingFlags.Static | BindingFlags.Public);
    foreach(PropertyInfo p in props)
    {
      /*Console.WriteLine ("p: " + p.Name);*/
      if (p.Name == prop)
      {
	try
	{
	  Object ret_m = null;

	  ret_m = p.GetValue(null, null);
	  /*Console.WriteLine ("p: " + p.Name);*/

	  return res_to_ptr (ret_m);
	}
	catch /*(Exception e)*/
	{
	  /*Console.WriteLine (e);*/
	  continue;
	}
      }
    }

    throw new Exception ("Static property " + prop + " not found");
  }


  public Object[] get_IsInstanceOf (IntPtr val, Int32 asem_type, String assem, String atype)
  {
    if (val == (IntPtr) 0)
      throw new Exception ("object handle not supposed to be 0");
    Object[] ret = new Object[1];
    try
    {
      GCHandle real_instance = (GCHandle) (val);
      Object new_instance = real_instance.Target;
      Type type = get_type (asem_type, assem, atype);
/*    if (assem == type.ToString())
	{
	  ret[0]=(Boolean) true;
	  return ret;
	}*/
      if (type.IsInstanceOfType(new_instance)
	|| (new_instance != null && new_instance.GetType() == type))
	ret[0]=(Boolean) true;
      else
	ret[0]=(Boolean) false;
    }
    catch
    {
      ret[0] = (Boolean) false;
    }
    return ret;
  }

  public String get_instance_name (IntPtr instance)
  {
    /*Console.WriteLine ("get_instance_name: " + ((GCHandle) (instance)).Target.GetType().FullName);*/
    return ((GCHandle) (instance)).Target.GetType().FullName;
  }

/*
#if !MONO
  public Object[] remove_instance_from_hash (String instance)
  {
    Object[] ret = new Object[1];

//    assem_perm_list.Remove (instance);
    instances.Remove (instance);

    ret[0]=(Boolean) true;
    return ret;
  }

  public Object[] add_assem_to_sec_hash (String assem_name)
  {
    Object[] ret = new Object[1];

//    assem_perm_list [assem_name] = 1;

    ret[0]=(Boolean) true;
    return ret;
  }
#endif
*/

  #endregion

  #region helper funcs
  private static byte[] obj_serialize_int (Object new_instance, IFormatter bf)
  {
    Object [] ret = new Object[2];

    System.IO.MemoryStream mem_strim = new System.IO.MemoryStream ();
    bf.Serialize(mem_strim, new_instance);
    mem_strim.Flush();

    byte [] byte_array = new byte []{};
    byte_array = mem_strim.ToArray();

    return byte_array;
  }


  private static bool CheckArgs(MethodInfo method, Object[] args)
  {
    ParameterInfo[] param = method.GetParameters();

    if (param.Length != args.Length)
      return false;

    for(int index = 0; index < args.Length;index++)
    {
      if (args[index] != null &&
	  ((!(args[index].GetType().IsInstanceOfType (param[index].ParameterType) ||
	      (param[index].ParameterType != null && param[index].ParameterType.GetType() == args[index].GetType())
	     ))) && param[index].ParameterType != args[index].GetType())
	{
	  return false;
	}
    }

    return true;
  }


  private static Object[] obj_deserialize_int (byte [] in_bytes, Int32 asem_type, String assem, String atype, IFormatter bf)
  {
    Object [] ret = new Object[2];
    System.IO.MemoryStream mem_strim = new System.IO.MemoryStream ();

    Type type = new VInvoke().get_type (asem_type, assem, atype);

    mem_strim.Seek(0, SeekOrigin.Begin);
    mem_strim.Write (in_bytes, 0, (int) in_bytes.Length);

    mem_strim.Seek(0, SeekOrigin.Begin);
    Object org_obj = bf.Deserialize(mem_strim);

    if (!(type.IsInstanceOfType (org_obj) || (org_obj != null && type == org_obj.GetType())))
      throw new Exception ("The deserialized object is not an instance of " + type.FullName);

    return res_to_ptr (org_obj);
  }


  private static Object[] change_ptr (Object[] vparams, IntPtr[] oparams)
    {
      for ( int i =0; i < vparams.Length; i++ )
	{
	  if (oparams[i] != (IntPtr) 0)
	    {
	      GCHandle real_instance;

	      if (oparams[i] == (IntPtr)0)
		throw new Exception ("object handle not supposed to be 0");
	      real_instance = (GCHandle) oparams[i];
	      vparams[i] = real_instance.Target;
	    }
	}

      return vparams;
    }


  private static Object[] res_to_ptr (Object obj)
    {
      Object [] ret = new Object[2];


      if (obj == null)
	{
	  ret[0]=1;
	  ret[1]=0;
	  return ret;
	}
      else if (obj.GetType() ==  typeof (System.String))
	{
	  ret[0]=1;
	  ret[1]=obj;
	  return ret;
	}
      else if (obj.GetType() ==  typeof (System.Int32))
	{
	  ret[0]=2;
	  ret[1]=obj;
	  return ret;
	}
      else if (obj.GetType() ==  typeof (System.String []))
	{
	  String [] temp_s = new String []{};
	  temp_s = (String []) obj;
	  Object [] list_ret = new Object[temp_s.Length + 1];
	  list_ret[0]=3;
	  for(int index = 0; index < temp_s.Length;index++)
	    {
	      list_ret[index + 1]=temp_s[index];
	    }
	  return list_ret;
	}
      else if (obj.GetType() ==  typeof (System.Int32 []))
	{
	  Int32 [] temp_i = new Int32 []{};
	  temp_i = (Int32 []) obj;
	  Object [] list_ret = new Object[temp_i.Length + 1];
	  list_ret [0]=4;
	  for(int index = 0; index < temp_i.Length;index++)
	    {
	      list_ret[index + 1]=temp_i[index];
	    }
	  return list_ret;
	}
      else if (obj.GetType() ==  typeof (System.Int32 [])
	  || (obj.GetType() == typeof (System.Byte[])))
	{
	  byte [] temp_i = new byte []{};
	  temp_i = (byte []) obj;
	  Object [] list_ret = new Object[temp_i.Length + 1];
	  list_ret [0]=11;
	  for(int index = 0; index < temp_i.Length;index++)
	    {
	      list_ret[index + 1]=temp_i[index];
	    }
	  return list_ret;
	}
      else if (obj.GetType().IsArray)
	{
	  Array arr = (Array)obj;

	  GCHandle to_save;
	  Int32 ii;

	  Object [] list_ret = new Object[arr.Length + 1];
	  list_ret [0]=5;
	  int arr_index = 1;
	  foreach (Object xx in arr)
	    {
	      to_save = GCHandle.Alloc (xx, GCHandleType.Normal);

	      ii =(Int32)(IntPtr) to_save;

	      list_ret [arr_index++]=ii;
	    }

	  return list_ret;
	}
      else if (obj.GetType() ==  typeof (System.Single))
	{
	  ret[0]=7;
	  ret[1]=obj;
	  return ret;
	}
      else if (obj.GetType() ==  typeof (System.Double))
	{
	  ret[0]=8;
	  ret[1]=obj;
	  return ret;
	}
      else if (obj.GetType() ==  typeof (System.Boolean))
	{
	  ret[0]=9;
	  ret[1]=obj;
	  return ret;
	}
      else if (obj.GetType() ==  typeof (void))
	{
	  ret[0]=17;
	  ret[1]=obj;
	  return ret;
	}
      else
	{
	  GCHandle to_save = GCHandle.Alloc (obj, GCHandleType.Normal);
	  ret[0]=6;
	  ret[1]=(int)(IntPtr) to_save;
	  return ret;
	}

    }

  class CustomException:Exception
    {
      public CustomException(String m):base(m){}
      public CustomException(String m, Exception n):base(m,n){}
    }

  private Type get_type (Int32 asem_type, String assem, string atype)
  {
      Assembly assembly;
#if MONO
      hndlr = new ResolveEventHandler (MyResolveEventHandler);
#endif
   try
    {
      AppDomain.CurrentDomain.AssemblyResolve -= this.hndlr;
    }
    catch  {};

      AppDomain.CurrentDomain.AssemblyResolve += this.hndlr;
      if (asem_type == 0)
	{
	  assembly = Assembly.Load(assem);
	}
      else
	{
	  assembly = Assembly.LoadFrom(assem);
	}
      return assembly.GetType(atype, true);
  }
  #endregion


  static Hashtable instances;

  private static Hashtable get_domain_hashtable ()
    {
	AppDomain currentDomain = AppDomain.CurrentDomain;
	String dataName = "instances";
	Hashtable ret;

	ret = (Hashtable) currentDomain.GetData(dataName);

	if (ret == null)
	  {
	    ret = new Hashtable ();
	    currentDomain.SetData(dataName, ret);
	  }

	return ret;
    }

  private Assembly MyResolveEventHandler (object sender, ResolveEventArgs args)
    {
      Assembly ret;
      String my_name = args.Name;
      int pos = my_name.IndexOf (",");

      if (pos != -1)
	my_name = my_name.Substring (0, pos);

      instances = get_domain_hashtable ();

      ret = (Assembly) instances [my_name];

      if (ret == null)
	{
	try
	  {
#if MONO
	    ret = LoadAssemblyFromVirtuoso (my_name);
	    instances [my_name] = ret;
#else
	    int currp = GetModuleHandle (null);
	    int proc_addr = GetProcAddress (currp, "dotnet_unmanaged_call");
	    IntPtr str1 = Marshal.StringToCoTaskMemAnsi (my_name);
	    byte_size_ptr_t arg = new byte_size_ptr_t ();
	    arg.size = 0;
	    arg.data = IntPtr.Zero;
	    arg.name = str1;
	    int thr_id = CreateThread (0, 0, proc_addr, ref arg, 0, 0);
	    WaitForSingleObject (thr_id, INFINITE);
	    CloseHandle (thr_id);
	    Marshal.FreeCoTaskMem (str1);
	    if (arg.size > 0 && arg.data != IntPtr.Zero)
	      {
		byte [] bytes = new byte[arg.size];
		Marshal.Copy (arg.data, bytes, 0, arg.size);
		Marshal.FreeCoTaskMem (arg.data);
		arg.data = IntPtr.Zero;
		ret = Assembly.Load (bytes);

		instances [my_name] = ret;
	      }
	    else
	      return null;
#endif
	  }
	catch
	  {
	    return null;
	  }
      }

    return ret;
  }

  /* Add reference for compiler, after compilation the list will be cleared */
  public Object[] add_comp_reference (String assembly_ref)
  {
#if MONO
    if (assemblies == null)
	    assemblies = new StringCollection();
#endif

    assemblies.Add (assembly_ref);
    return res_to_ptr(0);
  }

  public Object[] compile_source (String source, String outfile)
  {
    String[] ret = new String[1];
    ICodeCompiler csc = (new CSharpCodeProvider()).CreateCompiler();
    System.CodeDom.Compiler.CompilerParameters parameters = new CompilerParameters();
    parameters.OutputAssembly = outfile;

    foreach (String r in assemblies)
      {
	parameters.ReferencedAssemblies.Add(r);
      }


    CompilerResults results = csc.CompileAssemblyFromSource(parameters,source);
    assemblies.Clear();

    if (results.Errors.Count > 0)
      {
	String errstr = null;
	foreach(CompilerError CompErr in results.Errors)
	  {
	    errstr += "Line: " + CompErr.Line +
		", ErrorNumber: " + CompErr.ErrorNumber +
		", '" + CompErr.ErrorText + "'" +
		Environment.NewLine;
	  }
	ret[0] = errstr;
      }
    else
      ret[0] = "OK";
    return res_to_ptr (ret);
  }

#if !MONO
  #region bytesize_ptr def
  [ StructLayout( LayoutKind.Sequential, CharSet=CharSet.Ansi ) ]
    private struct byte_size_ptr_t
  {
    public IntPtr name;
    public int size;
    public IntPtr data;
  }
  #endregion

  #region extern defs
  [DllImport ("kernel32")]
  private static extern int CreateThread (int SecurityAttributes, System.UInt32 stack_size,
    int start_routine, ref byte_size_ptr_t my_data, UInt32 flags, int thr_id);

  [DllImport ("kernel32", CharSet=CharSet.Auto)]
  private static extern int GetModuleHandle (string name);

  [DllImport ("kernel32", CharSet=CharSet.Ansi)]
  private static extern int GetProcAddress (int  hmodule, string proc_name);

  private const UInt32 INFINITE = 0xFFFFFFFF;
  [DllImport ("kernel32", CharSet=CharSet.Ansi)]
  private static extern UInt32 WaitForSingleObject (int handle, UInt32 msecs);

  [DllImport ("kernel32", CharSet=CharSet.Ansi)]
  private static extern long CloseHandle (int handle);
  #endregion

#else
  [MethodImplAttribute (MethodImplOptions.InternalCall)]
  private extern Assembly LoadAssemblyFromVirtuoso (String assem_name);
#endif
}

