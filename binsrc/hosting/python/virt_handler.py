#
#  virt_handler.py
#
#  $Id$
#
#  python proxy for OpenLink python plugin
#  
#  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
#  project.
#  
#  Copyright (C) 1998-2012 OpenLink Software
#  
#  This project is free software; you can redistribute it and/or modify it
#  under the terms of the GNU General Public License as published by the
#  Free Software Foundation; only version 2 of the License, dated June 1991.
#  
#  This program is distributed in the hope that it will be useful, but
#  WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
#  General Public License for more details.
#  
#  You should have received a copy of the GNU General Public License along
#  with this program; if not, write to the Free Software Foundation, Inc.,
#  51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA
#  
#  

import os;
import sys;
import traceback;

class VirtNullIO:
    def tell(self): return 0
    def read(self, n = -1): return ""
    def readline(self, length = None): return ""
    def readlines(self): return []
    def write(self, s): pass
    def writelines(self, list):
        self.write("".join(list))
    def isatty(self): return 0
    def flush(self): pass
    def close(self): pass
    def seek(self, pos, mode = 0): pass


class VirtCGIStdin(VirtNullIO):
    def __init__(self, init_val):
        self.pos = 0
        # note that self.buf sometimes contains leftovers
        # that were read, but not used when readline was used
        self.buf = init_val

    def read(self, n = -1):
        if n <= 0:
            return ""

        n2 = n + self.pos;
        if self.buf:
            s = self.buf[self.pos:n2]
            n = n - len(s)
        else:
            s = ""
        self.pos = self.pos + len(s)
        return s

    def readlines(self):
        s = (self.buf).split('\n')
        return map(lambda s: s + '\n', s)

    def readline(self, n = -1):

        if n == 0:
            return ""

        # look for \n in the buffer
        i = self.buf.find('\n')
        if i == -1:
            i = len (self.buf) - 1
        # carve out the piece, then shorten the buffer
        result = self.buf[:i+1]
        self.buf = self.buf[i+1:]
        self.pos = self.pos + len(result)
        return result
        

class VirtCGIStdout(VirtNullIO):

    def __init__(self):
        self.pos = 0
        self.headers_sent = 0
        self.headers = ""
        self.req_text = ""
	self.html_mode=0
        
    def write(self, s):

        if not s: return

        if self.html_mode and not self.headers_sent:
            self.headers = self.headers + s

            headers_over = 0

            ss = self.headers.split('\r\n\r\n', 1)
            if len(ss) < 2:
                ss = self.headers.split('\n\n', 1)
                if len(ss) >= 2:
                    headers_over = 1
            else:
                headers_over = 1
                    
            if headers_over:
                self.headers_sent = 1

        else:
            self.req_text = self.req_text + s
        
        self.pos = self.pos + len(s)

    def tell(self): return self.pos

    def get_headers(self) : return self.headers;
    def get_body(self) : return self.req_text;
    def set_html_mode(self) : self.html_mode=1;


def setup_cgi(env, stdin_txt, new_stdout, new_stderr):

    save_env = os.environ.copy()
    if env.has_key ("__VIRT_CGI") and env["__VIRT_CGI"] == '1':
        new_stdout.set_html_mode ();
    
    si = sys.stdin
    so = sys.stdout
    sr = sys.stderr

    os.environ.update(env)
 
    sys.stdout = new_stdout
    sys.stdin = VirtCGIStdin(stdin_txt)
    sys.stderr = new_stderr

    return save_env, si, so, sr
     

def restore_nocgi(sav_env, si, so, sr):

    osenv = os.environ

    for k in osenv.keys():
        del osenv[k]
    for k in sav_env:
        osenv[k] = sav_env[k]

    sys.stdout = si
    sys.stdin = so
    sys.stderr = sr


def call_string(base_uri,content,opts,params,lines):
	new_stdout = VirtCGIStdout();
	new_stderr = VirtCGIStdout();

	sys.argv = [ base_uri ];

	sav_env, si, so, sr = setup_cgi (opts, params, new_stdout, '')
	try:
	    eval (compile (content, base_uri, 'exec'), {})
	    restore_nocgi (sav_env, si, so, sr)

            body=new_stdout.get_body ();
            hdr=new_stdout.get_headers ();
            err=new_stderr.get_headers () + new_stderr.get_body ();
	    return body, hdr, err
	except:
	    restore_nocgi (sav_env, si, so, sr)
            a,b,c = sys.exc_info ();
	    ex_text = "".join (traceback.format_exception (a,b,c));
            body=new_stdout.get_body ();
            hdr=new_stdout.get_headers ();
            err=new_stderr.get_headers () + new_stderr.get_body ();
            return body, hdr, err, ex_text


def call_file(base_uri,opts,params,lines):
	new_stdout = VirtCGIStdout();
	new_stderr = VirtCGIStdout();

	sys.argv = [ base_uri ];

	sav_env, si, so, sr = setup_cgi (opts, params, new_stdout, '')
	try:
	    execfile (base_uri, {});
	    restore_nocgi (sav_env, si, so, sr)

            body=new_stdout.get_body ();
            hdr=new_stdout.get_headers ();
            err=new_stderr.get_headers () + new_stderr.get_body ();
	    return body, hdr, err
	except:
	    restore_nocgi (sav_env, si, so, sr)
            a,b,c = sys.exc_info ();
	    ex_text = "".join (traceback.format_exception (a,b,c));
            body=new_stdout.get_body ();
            hdr=new_stdout.get_headers ();
            err=new_stderr.get_headers () + new_stderr.get_body ();
            return body, hdr, err, ex_text

# testting code
if __name__ == '__main__':
    if os.environ.has_key ("__VIRT_CGI") and os.environ["__VIRT_CGI"] != '1' and not 12 == 11:
       print ("xx");
       
    a,b,c = call_file ('../lib/suite/admin/cgitest.py', { '__VIRT_CGI': '1' }, '', '');
    d = ''
    sys.stderr.write ('\n['+a+']['+b+']['+c+']['+d+']\n');
