//
//  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
//  project.
//
//  Copyright (C) 1998-2017 OpenLink Software
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
using System.IO;
using System.Web;
using System.Threading;
using System.Text;
using System.Web.Hosting;
using System.Reflection;
using System.Collections;
using System.Windows.Forms;
using System.Runtime.Remoting;
using System.Runtime.Remoting.Lifetime;

[assembly:AssemblyVersionAttribute("1.0.0.0")]
[assembly:AssemblyCompanyAttribute("OpenLink Software")]
[assembly:AssemblyKeyFileAttribute("virtkey.snk")]

namespace Virt_aspx
{

  public class VirtHost  : MarshalByRefObject
    {

      static Hashtable hosts = new Hashtable ();

      public override Object InitializeLifetimeService()
	{

	  ILease lease = (ILease)base.InitializeLifetimeService();
	  if (lease.CurrentState == LeaseState.Initial){
	    lease.InitialLeaseTime = TimeSpan.Zero;
	  }
	  return lease;
	}

      public static bool RunningOnMono ()
	{
	  try
	    {
	      Assembly ass = Assembly.Load ("mscorlib");
	      if (null != ass.GetType ("Mono.Runtime", true))
		return true;
	    }
	  catch (Exception e)
	    {
	    }
	  return false;
	}

      public String [] ProcessRequest_int(String page, String post, String parameters,
	  String in_headers, String client_ip, String server_port,
	  String localhost_name, String virtualDir, String physicalDir, Object odbcPort)
	{
	  String [] ret_str = new String [3];
          try {
	    StringWriter all_text = new StringWriter();
	    SimpleWorkerRequest req =
		(SimpleWorkerRequest) new VirtSimpleWorkerRequest(page, post, parameters, in_headers,
								  client_ip, server_port, localhost_name,
								  virtualDir, physicalDir, all_text);
	    //Console.WriteLine (String.Format ("FilePath=[{0}] FilePathTranslated=[{1}]", req.GetFilePath(), req.GetFilePathTranslated()));
	    //Console.WriteLine (String.Format ("AppPath=[{0}] AppPathTranslated=[{1}]", req.GetAppPath(), req.GetAppPathTranslated()));
	    //Console.WriteLine (String.Format ("HttpVerbName=[{0}] HttpVersion=[{1}]", req.GetHttpVerbName(), req.GetHttpVersion()));
	    //Console.WriteLine (String.Format ("parameters=[{0}] GetQueryString=[{1}] GetQueryStringRawBytes=[{2}] HasEntityBody=[{3}]", parameters, req.GetQueryString (), req.GetQueryStringRawBytes(), req.HasEntityBody()));
	    AppDomain.CurrentDomain.SetData ("OpenLink.Virtuoso.InProcessPort", odbcPort);
	    HttpRuntime.ProcessRequest(req);
	    if (VirtHost.RunningOnMono ())
	      ((VirtSimpleWorkerRequest) req).mtx.WaitOne ();
	    ret_str [0] = (String) all_text.ToString().Clone();
	    ret_str [1] = (String) ((VirtSimpleWorkerRequest)req).out_headers_get().Clone();
	    ret_str [2] = (String) ((VirtSimpleWorkerRequest)req).out_status_get().Clone();
//	    HttpRuntime.Close();
//          Console.WriteLine (ret_str[2]);
//          Console.WriteLine (ret_str[1]);
//          Console.WriteLine (ret_str[0]);
	    return ret_str;
          } catch (Exception e) {
            //Console.WriteLine ("xx");
            //Console.WriteLine (e);
	    ret_str [0] = e.ToString();
	    ret_str [1] = "";
	    ret_str [2] = "500 Internal Hosting error";
            return ret_str;
          }

	}
      private AppDomain GetWorkerDomain ()
	{
	  return AppDomain.CurrentDomain;
	}

      public static String [] Call_aspx2 (String page, String physicalDir, String virtualDir,
	  String headers, String client_ip, String server_port, String localhost_name,
	  String post, String parameters, String http_root, String runtime_name)
	{
          // XXX
	  //Console.WriteLine ("====================================");
	  //Console.WriteLine ("page = [{0}]", page);
	  //Console.WriteLine ("physicalDir = [{0}]", physicalDir);
	  //Console.WriteLine ("virtualDir = [{0}]", virtualDir);
	  //Console.WriteLine ("headers = [{0}]", headers);
	  //Console.WriteLine ("client_ip = [{0}]", client_ip);
	  //Console.WriteLine ("server_port = [{0}]", server_port);
	  //Console.WriteLine ("localhost_name = [{0}]", localhost_name);
	  //Console.WriteLine ("post = [{0}]", post);
	  //Console.WriteLine ("parameters = [{0}]", parameters);
	  //Console.WriteLine ("http_root = [{0}]", http_root);
	  //Console.WriteLine ("runtime_name = [{0}]", runtime_name);
	  //Console.WriteLine ("====================================");

	  VirtHost my_host;
	  String [] ret;
	  physicalDir = physicalDir.Replace ('/', Path.DirectorySeparatorChar);

	  //Console.WriteLine (String.Format ("virtualDir = [{0}] physicalDir=[{1}] page=[{2}]", virtualDir, physicalDir, page));
	  my_host = GetHost (virtualDir, physicalDir);
	  //Console.WriteLine ("------------------------------------");
	  //Console.WriteLine ("page = [{0}]", page);
	  //Console.WriteLine ("physicalDir = [{0}]", physicalDir);
	  //Console.WriteLine ("virtualDir = [{0}]", virtualDir);
	  //Console.WriteLine ("headers = [{0}]", headers);
	  //Console.WriteLine ("client_ip = [{0}]", client_ip);
	  //Console.WriteLine ("server_port = [{0}]", server_port);
	  //Console.WriteLine ("localhost_name = [{0}]", localhost_name);
	  //Console.WriteLine ("post = [{0}]", post);
	  //Console.WriteLine ("parameters = [{0}]", parameters);
	  //Console.WriteLine ("http_root = [{0}]", http_root);
	  //Console.WriteLine ("runtime_name = [{0}]", runtime_name);
	  //Console.WriteLine ("====================================");

	  ret = my_host.ProcessRequest_int(page, post, parameters, headers, client_ip,
	      server_port, localhost_name, virtualDir, physicalDir,
	      AppDomain.CurrentDomain.GetData ("OpenLink.Virtuoso.InProcessPort"));
	  return ret;
	}


      private static VirtHost GetHost (String virtualDir, String physicalDir)
	{

	  VirtHost ret;

	  ret = (Virt_aspx.VirtHost) hosts [virtualDir];

	  if (ret == null)
	    {
	      ret = (Virt_aspx.VirtHost)System.Web.Hosting.ApplicationHost.CreateApplicationHost(
		  typeof(Virt_aspx.VirtHost), virtualDir, physicalDir);

#if WINDOWS
	      ILease serverLease;
	      serverLease = (ILease)RemotingServices.GetLifetimeService((MarshalByRefObject)ret);
#endif

	      hosts [virtualDir] = ret;
	    }
	  return ret;
	}
    }

  public class VirtSimpleWorkerRequest:SimpleWorkerRequest
    {
      public String out_status = "", gl_client_ip;
      public String gl_localhost_name, gl_server_port, gl_virtualDir;
      public String [] out_headers = new String [50];
      public int lastDot, lastSlh, pos_out_headers = 0;
      private String gl_pathInfo;
      private String[][] gl_unknownRequestHeaders;
      String [] known_headers = new String [50];
      String [] unknown_headers = new String [50];
      String [][] all_headers = new String [50][];
      String gl_fpath, gl_fpath_trans, gl_parameters;
      String http_verb = "GET", http_version = "HTTP/1.0";
      string _queryString = String.Empty;
      public AutoResetEvent mtx = new AutoResetEvent (false);

      public VirtSimpleWorkerRequest (String page, String post, String parameters, String headers,
	  String client_ip, String server_port, String localhost_name,
	  String virtualDir, String physicalDir, TextWriter outstring)
		: base (String.Empty, null, outstring)
	    {

              gl_parameters = parameters;
	      if (page != null && page.StartsWith ("/~/"))
		page = page.Substring (2);

	      lastDot = page.LastIndexOf('.');
	      lastSlh = page.LastIndexOf('/');

	      if (lastDot >= 0 && lastSlh >= 0 && lastDot < lastSlh)
		{
		  int ipi = page.IndexOf('/', lastDot);
		  gl_fpath = page.Substring(0, ipi);
		  gl_pathInfo = page.Substring(ipi);
		}
	      else
		{
		  gl_fpath = page;
		  gl_pathInfo = String.Empty;
		}

	      gl_fpath_trans = MapPath (gl_fpath);
	      String separator = ";;";
	      gl_client_ip = client_ip;
	      gl_server_port = server_port;
	      gl_localhost_name = localhost_name;
	      gl_virtualDir = virtualDir;
	      String hd_name, hd_value;
	      String [] Names = new String [50];
	      int i, unknown_pos = 0, headers_len = 0;

	      for (i=0; 50 > i; i++)
		{
		  try
		    {
		      Names[i] = HttpWorkerRequest.GetKnownRequestHeaderName(i);
		      known_headers [i] = null;
		    }
		  catch
		    {
		      break;
		    }
		}

	      while (true)
		{
		  String line;
		  int dpos, known_pos = 0, pos = headers.IndexOf (separator);

		  if (pos == -1)
		    break;

		  line = headers.Substring(0, pos);
		  dpos = line.IndexOf (":");

		  hd_name = line.Substring (0, dpos);
		  hd_value = line.Remove (0, dpos + 1);

		  for (i=0; Names.Length > i; i++)
		    {
		      if (0 == String.Compare (hd_name, Names[i], true))
			known_pos = i + 1;
		    }

		  if (known_pos > 0)
		    {
		     //Console.WriteLine (String.Format ("Setting known [{0}] = [{1}]", Names[known_pos - 1], hd_value));
		    known_headers[known_pos - 1] = hd_value.Trim();
		    }
		  else
		    {
		     //Console.WriteLine (String.Format ("Setting unknown [{0}] = [{1}]", hd_name, hd_value));
		      unknown_headers [unknown_pos] = hd_name.Trim();
		      unknown_headers [unknown_pos + 1] = hd_value.Trim();
		      unknown_pos = + 2;
		    }

		  headers = headers.Remove (0, pos + 2);

		  all_headers[headers_len] = new String[2];
		  all_headers[headers_len][0] = hd_name.Trim();
		  all_headers[headers_len][1] = hd_value.Trim();
		  headers_len ++;
		}

	      // copy to array unknown headers

	      gl_unknownRequestHeaders = new String[headers_len][];

	      for (i = 0; i < headers_len; i++)
		{
		  gl_unknownRequestHeaders[i] = new String[2];
		  gl_unknownRequestHeaders[i][0] = all_headers[i][0];
		  gl_unknownRequestHeaders[i][1] = all_headers[i][1];
		}

	      GetRequestLine (post);
	    }
      public override void EndOfRequest ()
	{
	  //Console.WriteLine ("notification");
	  if (VirtHost.RunningOnMono ())
	    mtx.Set ();
	}
      public override String GetUriPath()
	{
//	    Console.WriteLine ("GetUriPath _path = " + gl_fpath);
	    return gl_fpath;
	}

    public override String GetPathInfo()
	{
//	    Console.WriteLine ("GetPathInfo gl_pathInfo = " + gl_pathInfo);
	    return gl_pathInfo;
	}

      public override byte [] GetPreloadedEntityBody ()
        {
//	   Console.WriteLine ("In GetPreloadedEntityBody");
	   if (gl_parameters != null && gl_parameters != String.Empty)
	     {
	       char [] q = gl_parameters.ToCharArray();
	       byte [] ret = new byte[q.Length];
	       for (int i = 0; i < q.Length; i++)
	         ret[i] = (byte) q[i];
//	       Console.WriteLine (String.Format ("GetPreloadedEntityBody ret = [{0}] [{1}]", ret, gl_parameters));
	       return ret;
	     }
	   else
             {
//	       Console.WriteLine ("GetPreloadedEntityBody ret = null");
	       return null;
             }
	}
      public override bool IsEntireEntityBodyIsPreloaded()
        {
//	   Console.WriteLine ("In IsEntireEntityBodyIsPreloaded");
	   return true;
	}

      public override string GetFilePath ()
        {
//	   Console.WriteLine ("In GetFilePath " + gl_fpath);
	   return gl_fpath;
	}
//#if !MONO
      /* MONO KIT 0717 */
      public override string GetFilePathTranslated ()
        {
	   //Console.WriteLine ("In GetFilePathTranslated");
	   return gl_fpath_trans;
	}
//#endif
      public String out_headers_get()
	{
	  String all_headers = "";

	  for (int i=0; pos_out_headers > i; i++)
	    {
	      all_headers = all_headers + out_headers[i] + ";;";
	    }

	  return all_headers;
	}
      public override int ReadEntityBody (byte [] buffer, int size)
        {
	  //Console.WriteLine (String.Format ("ReadEntityBody"));
	  return 0;
	}

      public String out_status_get()
	{
	  return out_status;
	}

      public override String GetUnknownRequestHeader(String Name)
	{
//	  Console.WriteLine (String.Format ("In GetUnknownRequestHeader [{0}]", Name));
	  String ret = null;
	  for (int i=0; 50 > i; i=i+2)
	    {
	      if (unknown_headers[i] == Name)
		{
		  ret = unknown_headers[i+1];
		  break;
		}
	    }
//	  Console.WriteLine (String.Format ("In GetUnknownRequestHeader ret=[{0}]", ret));
	  return ret;
	}

      public override String GetKnownRequestHeader(int x)
	{
	  //Console.WriteLine (String.Format ("In GetKnownRequestHeader x={0}[{2}] ret=[{1}]", x,
	  //	known_headers[x] == null ? "<NULL>" : known_headers[x],
	  //	HttpWorkerRequest.GetKnownRequestHeaderName(x)));
	  return known_headers[x];
	}

      public override void SendKnownResponseHeader(int x, String value)
	{
	  //Console.WriteLine (String.Format ("In SendKnownResponseHeader x={0} val=[{1}]", x, value));
	  out_headers[pos_out_headers] = HttpWorkerRequest.GetKnownResponseHeaderName(x) + ":" + value;
	  pos_out_headers ++;
	}

      public override void SendUnknownResponseHeader(String name, String value)
	{
	  //Console.WriteLine (String.Format ("In SendUnknownResponseHeader name={0} val=[{1}]", name, value));
	  out_headers[pos_out_headers] = name + ":" + value;
	  pos_out_headers ++;
	}

      public override void SendStatus(int statusCode, String statusDescription)
	{
	  //Console.WriteLine (String.Format ("In SendStatus code={0} desc=[{1}]", statusCode, statusDescription));
	  out_status = statusCode.ToString() + " " + statusDescription;
	}

      public override String GetLocalAddress()
	{
//	  Console.WriteLine ("In GetLocalAddress gl_localhost_name = " + gl_localhost_name);
	  return gl_localhost_name;
	}

      public override int GetLocalPort()
	{
//	  Console.WriteLine ("In GetLocalPort gl_server_port = " + gl_server_port);
	  return Convert.ToInt32 (gl_server_port);
	}

      public override String GetAppPath()
	{
//	  Console.WriteLine ("In GetAppPath " + gl_virtualDir);
	  return gl_virtualDir;
	}

/*    public override String GetFilePathTranslated()
	{
	  Console.WriteLine ("In GetFilePathTranslated" + base.MapPath ("/"));
	  return base.MapPath ("/");
	}*/

      public override String GetRemoteAddress()
	{
	  //Console.WriteLine (String.Format ("In GetRemoteAddress"));
	  return gl_client_ip;
	}

      public override string MapPath (string path)
	{
	  string ret = base.MapPath (path);
	  string root = base.MapPath ("/");
	  string h1 = base.MapPath ("");
	  root = root + Path.DirectorySeparatorChar;

	  //Console.WriteLine (String.Format ("MapPath [{0}]=[{1}]", path, ret));
	  if (ret != null)
	    ret = ret.Replace ('/', Path.DirectorySeparatorChar);

          if (ret != null && root != null && h1 != null && ret.IndexOf (root) < 0)
	    ret = ret.Replace (h1, root);

	  if (ret == null)
	    ret = base.MapPath (gl_virtualDir + path);

	  //Console.WriteLine (String.Format ("MapPath [{0}]=[{1}]", path, ret));
	  return ret;
	}

      private bool GetRequestLine (String _req)
	{
	  //Console.WriteLine (String.Format ("GetRequestLine(req=[{0}])", _req));
	  String _path;
	  if (_req == null)
	    return false;

	  _queryString = String.Empty;
	  _req = _req.Trim ();
	  int length = _req.Length;
	  if (length >= 5 && 0 == String.Compare ("GET ", _req.Substring (0, 4), true))
	    this.http_verb = "GET";
	  else if (length >= 6 && 0 == String.Compare ("POST ", _req.Substring (0, 5), true))
	    this.http_verb = "POST";
	  else
	    throw new InvalidOperationException ("Unsupported method in query: " + _req);

	  _req = _req.Substring (this.http_verb.Length + 1).TrimStart ();
	  string [] s = _req.Split (' ');
	  length = s.Length;

	  switch (length) {
	    case 1:
		_path = s [0];
		break;
	    case 2:
		_path = s [0];
		this.http_version = s [1];
		break;
	    default:
		return false;
	  }

	  int qmark = _path.IndexOf ('?');
	  if (qmark != -1) {
	    _queryString = _path.Substring (qmark + 1);
	    _path = _path.Substring (0, qmark);
	  }

	  return true;
	}
      public override string GetHttpVerbName ()
        {
	  //Console.WriteLine (String.Format ("GetHttpVerbName"));
	  return this.http_verb;
	}
      public override string GetHttpVersion ()
        {
	  //Console.WriteLine (String.Format ("GetHttpVersion"));
	  return this.http_version;
	}

      public override string GetQueryString ()
	{
	  return _queryString;
	}


      public override String[][] GetUnknownRequestHeaders()
	{
//	    Console.WriteLine ("GetUnknownRequestHeaders is called.");
	    return gl_unknownRequestHeaders;
        }

/*    public override byte [] GetQueryStringRawBytes ()
	{
	  if (_queryString == String.Empty)
	    return null;
	  return Encoding.GetBytes (_queryString);
	}
*/

    }
}
