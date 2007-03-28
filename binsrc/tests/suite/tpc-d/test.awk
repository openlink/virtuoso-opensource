BEGIN { a=""
    	print "<table> <tr> <th> Query </th> <th> Time msec. </th> </tr>"
      }

/ msec./ {
    	      if (mode == "virt" || mode == "oracle")
	      {
		  a=$4
	      }
	      else
	      {
		  next
	      }
         }

/Time:.*/      {
    	      if (mode == "postgesql")
		  a=$2
	      else
		  next
         }

/: Q/    {
    	      if (mode == "oracle")
		  print  "<tr><td>" $2 " </td><td> " a " </td></tr>"
	      else
		  print  "<tr><td>" $5 " </td><td> " a " </td></tr>"
         }

	{
        }
END {  print "</table>" }
