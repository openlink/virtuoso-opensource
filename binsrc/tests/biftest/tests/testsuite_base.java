/*
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
 */

import java.util.*;

public class testsuite_base  implements java.io.Serializable {

  public static final int static_ro_I = 1;
  public static int static_I = 2;
  protected static int protected_static_I = 3;
  protected int protected_I = 4;
  private static int private_static_I = 13;
  private int private_I = 14;

  public boolean Z = true;
  public boolean falseZ = false;
  public byte B = 5;
  public char C = 'a';
  public short S = 6;
  public int I = 7;
  public long J = 8;
  public float F = 0.1234F;
  public double D = 8.1234567890123456D;
  public Short L = new Short ((short) 9);
  public int AI [] = { 1, 2, 3 };
  public Short AL [] = { new Short ((short) 10), new Short ((short) 11), new Short ((short) 12) };
  public String str = "abc";
  public Date dat = new GregorianCalendar (1972, 7, 29, 17, 30, 15).getTime();

  public testsuite_base ()
    {
/*      System.err.println ("testsuite_base.java:testsuite_base:Z[" + Z + "]");
      System.err.println ("testsuite_base.java:testsuite_base:falseZ[" + falseZ + "]");
      System.err.println ("testsuite_base.java:testsuite_base:B[" + B + "]");
      System.err.println ("testsuite_base.java:testsuite_base:C[" + C + "]");
      System.err.println ("testsuite_base.java:testsuite_base:S[" + S + "]");
      System.err.println ("testsuite_base.java:testsuite_base:I[" + I + "]");
      System.err.println ("testsuite_base.java:testsuite_base:J[" + J + "]");
      System.err.println ("testsuite_base.java:testsuite_base:F[" + F + "]");
      System.err.println ("testsuite_base.java:testsuite_base:D[" + D + "]");
      System.err.println ("testsuite_base.java:testsuite_base:L[" + L + "]");
      System.err.println ("testsuite_base.java:testsuite_base:AI[" + AI + "]");
      System.err.println ("testsuite_base.java:testsuite_base:AL[" + AL + "]"); */
    }

  public static boolean test_bool (int x)
    {
      boolean ret;
      if (x != 0)
	ret = true;
      else
	ret = false;
      //System.err.println ("testsuite_base.java:test_bool:ret=" + ret);
      return ret;
    }


  public testsuite_base (int i)
    {
      this.I = i;
    }
  public static Double echoDouble (double in) {
    return new Double (in);
  };

  public static String getObjectType (Object obj)
    {
      return obj.getClass().getName();
    }
  public static int echoThis (testsuite_base in)
    {
      in.I *= -1;
      return in.I;
    }
  public static int static_echoInt (int in) {
    return in;
  }

  public static int change_it (testsuite_base in)
    {
      in.I *= -1;
      return in.I;
    }

  public int overload_method (int i)
    {
      return i + 2;
    }

  public int echoInt (int in) {
    return in + 12;
  }

  public int echoInt (double d)
    {
      return new Double(d).intValue() + 13;
    }
  protected int protected_echo_int (int in)
    {
      return in;
    }
  private int private_echo_int (int in)
    {
      return in;
    }
  public double echoDbl (double in) {
    return in;
  }

}
