---++ODS Users Administration Implementation Guide

The goal of the project is to port *.vsp user's pages to the following programming languages: AJAX, PHP, VSP and JSP.

   1. CVS location: The implemented pages are located in folder 'users' of the ODS Framework Application.
   1. Endpoint: The Endpoint is http://[host]:[port]/ods/users/[the name of the corresponding page].
   1. Implementation:
      1. Common files:
         * css/users.css.
         * js/users.js: contains AJAX and common functions
   1. After VAD installing new ODBC connection is created with name 'LocalVirtuosoDemo'.

---+++AJAX Implementation

   1. The page name is 'users.html'
   1. The endpoint URL is http://[host]:[port]/javascript/users/users.html. The alternate URL is http://[host]:[port]/ods/users/users.html
   1. Configuration:
     1. Start the Virtuoso executive
     1. Install the ods_framework_dav.vad package.


---+++PHP Implementation

   1. PHP: The supported version of PHP is 5.2.4, so you should use Virtuoso with php5 plugin.

[Plugins]
LoadPath = ../hosting
....
Load8    = attach, php5ts
Load9    = Hosting, hosting_php.dll
....

   1. The page name is 'users.php'.
   1. The endpoint URL is http://[host]:[port]/php/users/users.php. The alternate URL is http://[host]:[port]/ods/users/users.php
   1. Configuration:
      1. Start Virtuoso executive
      1. Install the ods_framework_dav.vad package


---+++VSP Implementation

   1. The page name is 'users.vsp'.
   1. The endpoint URL is http://[host]:[port]/vsp/users/users.vsp. The alternate URL is http://[host]:[port]/ods/users/users.vsp
   1. Configuration:
      1. Start Virtuoso executive
      1. Install the ods_framework_dav.vad package


---+++JSP (Java Server Pages) Implementation

Note: you should have the users.jsp and users_dsn.jsp (created after installation) file physically located on your machine.

   1. The implementation uses Java version 1.5 (version 5), so you should run the corresponding Virtuoso executive. You need also to have installed Tomcat version 5.5.x. Download and install following packages: Commons FileUpload, Commons IO.
   1. The page name is 'users.jsp'.
   1. The Endpoint URL is http://[host]:[port]/jsp/users/users.jsp
   1. Configuration
      1. Start Virtuoso executive
      1. Install Tomcat
      1. Download 'Apache FileUpload package' from http://commons.apache.org/fileupload/ and next copy file 'commons-fileupload-1.2.1.jar' into '[Tomcat installation folder]/common/lib'
      1. Download 'Apache IO package' from http://commons.apache.org/io/ and next copy file 'commons-io-1.4.jar' into '[Tomcat installation folder]/common/lib'
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
         1. If directory link '/jsp/users' exists update it with properties described below or click the "New Directory" link.
         1. Click the "Type" radio-box and select from the drop-down list the value "Proxy server".
         1. Click "Next".
         1. In the shown form:
            1. For field "Virtual directory path" enter the value: /jsp/users
            1. For field "Proxy to" enter the value: http://[Tomcat Host]:[Tomcat Port]/users/jsp
            1. For "VSP User" select from the drop-down list: dba
         1. Click the "Save changes" button.
      1. Install the ods_framework_dav.vad package.
      1. Go to http://[host]:[port]/jsp/users/users.jsp.
