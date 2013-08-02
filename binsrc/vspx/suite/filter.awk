# This filter should:
#  
#  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
#  project.
#  
#  Copyright (C) 1998-2013 OpenLink Software
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
# 1. Add "server" "port" line (from parameters values)
# 2. If GET - remove all lines expect first
# 3. If POST - remove line with "Host: ..."
# 4. Anycase - remove "User Agent:"

BEGIN {
        if("x"server != "x" && "x"port != "x") {
          print server" "port
        }
        else {
          if("x"server != "x") {
            print server
          }
          else {
            print "localhost 80"
          }
        }
        is_post=0
      }

/GET.*/ {
          print $0
          exit
        }
	 
/POST.*/ {
           is_post = 1
           print $0
           next
         }
	 
/Host:.*/ {
            next
          }
	 
/User Agent:.*/ {
                  next
                }
	 
/Referer:.*/ {
               print $2 >"temp_file"
               expr = "awk ' BEGIN {{FS = \"\/\"}{ORS=\"\"}} {for(k=4; k<=NF; k++) {{print FS} {print $k}}}' < temp_file > temp_file2"
               system(expr)
	       saveORS = ORS
	       ORS = ""
	       print "Referer: http:\/\/"server":"port
	       system("cat temp_file2")
               system("rm -f temp_file") 
	       system("rm -f temp_file2")
	       ORS = saveORS
	       print ""
              next
             }
	 
/.*/ {
        print $0
        next
      }	 

END {
      if(is_post == 1) {
        print "ENDPOST"
      }
    }

