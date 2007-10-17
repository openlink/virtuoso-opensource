---++ODS Users Administration Implementation Guide

The goal of the project is to port *.vsp user's pages to the following programming languages: AJAX, PHP and JSP.

   1. CVS location: The implemented pages are located in folder 'users' of the ODS Framework Application.
   1. Endpoint: The Endpoint is http://[host]:[port]/ods/users/[the name of the corresponding page].
   1. Implementation:
      1. Common files:
         * users_api.sql: contains ODS Users WEB Services API, which supports login, logout, register, etc..
         * oid_login.vsp: contains OpenID login and registration implementation.
         * css/users.css.
         * js/users.js: contains AJAX and common functions
         * js/oid_login.js: contains functions for OpenID login and registration
   1. After VAD installing new ODBC connection is created with name 'LocalVirtuosoDemo'.

---+++AJAX Implementation

   1. The page name is 'users.html'
   1. The Endpoint URL is http://[host]:[port]/ods/users/users.html
   1. Configuration:
     1. Start the Virtuoso executive
     1. Install the ods_framework_dav.vad package.


---+++PHP Implementation

   1. PHP: The supported version of PHP is 5, so you should use Virtuoso php5 executive.
   1. The page name is 'users.php'.
   1. The Endpoint URL is http://[host]:[port]/ods/users/users.php
   1. Configuration:
      1. Start Virtuoso executive
      1. Install the ods_framework_dav.vad package
      1. After VAD installing new page is created in folder '/DAV/VAD/wa/users' - 'users_dsn.php'. This page contains connection information - host, user, password. If some database parameters are changed this file must be updated:
         1. Go to http://host:port/conductor
         1. Login as dba user. The password by default is dba.
         1. Go to tab WebDAV & HTTP
         1. Go to path "DAV/VAD/wa/users"
         1. Update file 'users_dsn.php' file by changing the values of the following PHP variables:

   $_dsn -- this is the ODBC connection name.
   $_pass -- this is the dba user password


---+++JSP (Java Server Pages) Implementation

Note: you should have the users.jsp and users_dsn.jsp (created after installation) file physically located on your machine.

   1. The implementation uses Java version 1.5 (version 5), so you should run the corresponding Virtuoso executive. You need also to have installed Tomcat version 5.5.x.
   1. The page name is 'users.jsp'.
   1. The Endpoint URL is http://[host]:[port]/ods/users/jsp/users.jsp
   1. Configuration
      1. Start Virtuoso executive
      1. Install Tomcat
      1. Copy file 'virtjdbc3.jar' into '[Tomcat installation folder]/common/lib'
      1. Create file with name 'users#jsp.xml' in '[Tomcat installation folder]/conf/Catalina/[host]/' with content:

<!--
  Context configuration file for the ODS-Users Web Application
-->
<Context docBase="[Enter here the physical location to the users.jsp file]"
         privileged="true"
         antiResourceLocking="false"
         antiJARLocking="false">
</Context>

      1. Start Tomcat
      1. Build and install the conductor_dav.vad package
      1. Setting Virtual Directory:
         1. Go to http://[host]:[port]/conductor
         1. Login as dba user.
         1. Go to "WebDAV & HTTP"->"HTTP Hosts & Directories" tab.
         1. For {Default Web Site} click the "New Directory" link.
         1. Click the "Type" radio-box and select from the drop-down list the value "Proxy server".
         1. Click "Next".
         1. In the shown form:
            1. For field "Virtual directory path" enter the value: /ods/users/jsp
            1. For field "Proxy to" enter the value: http://[Tomcat Host]:[Tomcat Port]/users/jsp
            1. For "VSP User" select from the drop-down list: dba
         1. Click the "Save changes" button.
      1. After VAD installing new page is created in folder '/DAV/VAD/wa/users' - 'users_dsn.jsp'. This page contains connection information - host, user, password.
      1. Files 'users.jsp' and 'users_dsn.jsp' must downloaded into local file system.
      1. If some database parameters are changed after installation file 'users_dsn.jsp' must be updated. Go to your physical location of the 'users_dsn.jsp' file and set the correct values for the connection to the database:

conn = DriverManager.getConnection("jdbc:virtuoso://[host]:[SQL Server port]", "dba", "dba");

      1. Install the ods_framework_dav.vad package.
      1. Go to http://[host]:[port]/ods/users/jsp/users.jsp.

