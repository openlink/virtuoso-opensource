# Import the CGI module
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
require "cgi"

# Required header that tells the browser how to render the HTML.
print "Content-Type: text/xml\n\n"

# Define function to generate HTML form.
def generate_form()
    req = ENV["REQUEST_URI"]
    req ||= "cgitest.rb"
    puts <<EOF
    <HTML>
    	<HEAD>
    		<TITLE>Info Form</TITLE>
    	</HEAD>
    	<BODY BGCOLOR = white>
    		<H3>Please, enter your name and age.</H3>
    		<FORM METHOD="post" ACTION = "#{req}">
			<TABLE BORDER="0">
    				<TR><TH>Name:</TH><TD><INPUT type="text" name="name"></TD><TR>
    				<TR><TH>Age:</TH><TD><INPUT type="text" name="age"></TD></TR>
			</TABLE>
    			<INPUT TYPE="hidden" NAME="action" VALUE="display">
    			<INPUT TYPE="submit" VALUE="Enter">
		</FORM>
    	</BODY>
    </HTML>
EOF
end

# Define function display data.
def display_data(name, age)
  puts <<EOF
    <HTML>
    	<HEAD>
    		<TITLE>Info Form</TITLE>
    	</HEAD>
    	<BODY BGCOLOR = white>
    		#{name}, you are, #{age}, years old.
    	</BODY>
    </HTML>
EOF
end

# Define main function.
def main()
    form=CGI.new
    if (form.has_key?('action') and form.has_key?('name') and form.has_key?('age'))
			if (form['action'] == "display")
    	    display_data(form['name'], form['age'])
      end
    else
        generate_form()
    end
end

# Call main function.
main
