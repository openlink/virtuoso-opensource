//  
//  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
//  project.
//  
//  Copyright (C) 1998-2015 OpenLink Software
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
using System.Net;
using System.IO;
using System.Text;

public class Rest 
{
   public static int IntegerTest ()
    {
      return 1;
    }
  
   public static int FileAccessTest (String file_name)
    {
      FileInfo fi = new FileInfo (file_name);
      FileStream fs = fi.OpenRead ();
      Console.WriteLine (fi.Length);
      Byte [] bt = new byte [fi.Length];
      return fs.Read (bt, 0, (int) fi.Length);
    }

   public static int GetEnvTest ()
    {
      return Environment.GetEnvironmentVariable("PATH").Length;
    }
}

public class InternetConnect 
{
  public struct HotmailLoginInfo
    {
      private string m_URL;
      private CookieContainer m_PassportCookie;

      public HotmailLoginInfo(string ReferalURL, CookieContainer passportCookie)
	{
	  this.m_URL = ReferalURL;
	  this.m_PassportCookie = passportCookie;
	}

      public string ReferalURL
	{
	  get{return this.m_URL;}
	}

      public CookieContainer PassportCookie
	{
	  get{return this.m_PassportCookie;}
	}
    }

  public static string GetHotmailUsage(HotmailLoginInfo loginInfo)
    {
      HttpWebRequest webClient = null;
      HttpWebResponse Response = null;
      StreamReader readerStream = null;
      String sResponse;

      webClient = (HttpWebRequest)WebRequest.Create(loginInfo.ReferalURL);
      webClient.UserAgent = "Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.0)";
      webClient.CookieContainer = loginInfo.PassportCookie;	
      webClient.Method = "GET";

      Response = (HttpWebResponse)webClient.GetResponse();
      readerStream = (new StreamReader(Response.GetResponseStream()));
      sResponse = readerStream.ReadToEnd();
      readerStream.Close();

      if(sResponse.IndexOf("<title>Hotmail Home</title>") == -1)
	throw new Exception("Passport Login Failed");

      return sResponse;
    }

  public static HotmailLoginInfo LoginToHotmail(string rsUsername, string rsPassword)
    {
      HttpWebRequest webClient = null;
      HttpWebResponse Response = null;
      StreamReader readerStream = null;
      StreamWriter writerStream = null;
      CookieContainer cookies = null;
      char[] bytPostData;
      String sResponse;

      webClient = (HttpWebRequest)WebRequest.Create(@"https://lc3.law13.hotmail.passport.com/cgi-bin/dologin");
      webClient.UserAgent = "Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.0)";
      webClient.ContentType = "application/x-www-form-urlencoded";
      webClient.CookieContainer = (cookies = new CookieContainer());		
      webClient.Method = "POST";

      bytPostData = Encoding.ASCII.GetChars(Encoding.ASCII.GetBytes(@"domain=hotmail.com&login=" + rsUsername + "&passwd=" + rsPassword
	    + "&svc=mail&RemoteDAPost=" + "https://login.msnia.passport.com/ppsecure/post.asp&" 
	    + "sec=share&curmbox=ACTIVE&js=yes& lang=EN&ishotmail=1"
	    + "&is=2&fs=1&cb=lang%3dEN&ct=1010184077&mspp shared=1"));

      webClient.ContentLength = bytPostData.Length;

      writerStream = (new StreamWriter(webClient.GetRequestStream()));
      writerStream.Write(bytPostData, 0, bytPostData.Length);
      writerStream.Close();

      Response = (HttpWebResponse)webClient.GetResponse();
      readerStream = (new StreamReader(Response.GetResponseStream()));
      sResponse = readerStream.ReadToEnd();
      readerStream.Close();

      return new HotmailLoginInfo(sResponse.Substring(sResponse.IndexOf("<meta http-equiv=\"Refresh\" content=\"0; url=") + "<meta http-equiv=\"Refresh\" content=\"0; url=".Length, sResponse.LastIndexOf("\">") - sResponse.IndexOf("<meta http-equiv=\"Refresh\" content=\"0; url=") - "<meta http-equiv=\"Refresh\" content=\"0; url=".Length), cookies);
    }

  public String Call_Hotmail (String _user, String _pass)
    {
      String _res;
      HotmailLoginInfo t1 = new HotmailLoginInfo();

      t1 = LoginToHotmail (_user, _pass);

      try
	{
	  _res = GetHotmailUsage (t1);
	  return _res;
	}
      catch (Exception e)
	{
	  Console.WriteLine (e.Message);
	  return e.Message;
	}

    }
}
