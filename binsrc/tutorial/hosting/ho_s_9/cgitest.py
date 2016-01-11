# Import the CGI module
#  
#  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
#  project.
#  
#  Copyright (C) 1998-2016 OpenLink Software
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
import cgi
import os
import sys
#import cgitb
#cgitb.enable()

# Required header that tells the browser how to render the HTML.
print "Content-Type: text/html\n\n"

# Define function to generate HTML form.
def generate_form():
    if os.environ.has_key ('REQUEST_URI'):
       req=os.environ['REQUEST_URI']
    else:
       req='cgitest.py'
    print "<HTML>\n"
    print "<HEAD>\n"
    print "\t<TITLE>Info Form</TITLE>\n"
    print "</HEAD>\n"
    print "<BODY BGCOLOR = white>\n"
    print "\t<H3>Please, enter your name and age.</H3>\n"
    print "\t<TABLE BORDER = 0>\n"
    print "\t\t<FORM METHOD = post ACTION = \""+req+"\">\n"
    print "\t\t<TR><TH>Name:</TH><TD><INPUT type = text name = \"name\"></TD><TR>\n"
    print "\t\t<TR><TH>Age:</TH><TD><INPUT type = text name = \"age\"></TD></TR>\n"
    print "\t</TABLE>\n"
    print "\t<INPUT TYPE = hidden NAME = \"action\" VALUE = \"display\">\n"
    print "\t<INPUT TYPE = submit VALUE = \"Enter\">\n"
    print "\t</FORM>\n"
    print "</BODY>\n"
    print "</HTML>\n"

    # Define function display data.
def display_data(name, age):
    print "<HTML>\n"
    print "<HEAD>\n"
    print "\t<TITLE>Info Form</TITLE>\n"
    print "</HEAD>\n"
    print "<BODY BGCOLOR = white>\n"
    print name, ", you are", age, "years old."
    print "</BODY>\n"
    print "</HTML>\n"

    # Define main function.
def main():
        form = cgi.FieldStorage()
        if (form.has_key("action") and form.has_key("name") and form.has_key("age")):
                 if (form["action"].value == "display"):
                    display_data(form["name"].value, form["age"].value)
        else:
                 generate_form()

    # Call main function.
main()
