//  
//  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
//  project.
//  
//  Copyright (C) 1998-2019 OpenLink Software
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
using System.Text;
using System.IO;

namespace Test
{
  public class One
    {
      int xxxx;

      public One (int _in)
	{
	  xxxx = _in;
	}
    }

  public class Two
    {

      int xxxx;

      public int int_test = 125;

      public static Object stat_obj (int i)
	{
	  return new Two(i);
	}

      public Two (int _in)
	{
	  xxxx = _in;
	}

      public Two ()
	{
	  xxxx = 123;
	}

      public int set_val (int _in)
	{
	  xxxx = _in;
	  return _in;
	}


      public int get_v (int _in, int _w)
	{
	  return _in + _w;
	}


      public int MyInt(Int32 i, Int32 t)
	{
	  return i + t;
	}

      public int TestInt(int i, int t)
	{
	  return i + t;
	}

      public int Get_v (int i, int w)
	{
	  return i + w;
	}

      public float TestFloat (float i, float t)
	{
	  return (i + t);
	}

      public Double TestDouble (Double i, Double t)
	{
	  return (i + t);
	}

      public Boolean TestBoolean (int i)
	{
	  return (i == 0);
	}

      public String [] TestSringArray ()
	{
	  return new String [3] {"aa", "bb", "cc"};
	}
    }

  public class a1
    {
      public virtual string ToString_o ()
	{
	  return "String";
	}
    }

  public class a2:a1
    {
      public bool v_true = true;
      public bool v_false = false;

      public override string ToString_o ()
	{
	  return "String1";
	}
      public string ToZdravko ()
	{
	  return "String2";
	}
      public bool ret_true ()
	{
	  return true;
	}
      public bool ret_false ()
	{
	  return false;
	}

    }
}
