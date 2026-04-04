PHP SAPI module for Virtuoso
============================

This is a SAPI module for PHP 5.x, implemented as a Virtuoso loadable module.

Building php
------------

1. To build the plugin, you first need to build a `libphp5.so` configured with ZTS.
   ```
   Package	Version		From
   -------	-------		-----------------------------
   php		5.6.35		http://www.php.net/downloads/
   ```
2. In the php source directory, execute something similar to the 
   following.  ***NOTE**: The options here require a number of other 
   libraries be installed prior to building PHP. On systems where 
   these external libraries are not available as system libraries, 
   you may need additional configure options to point where certain 
   libraries are installed.*
   ```
   ./configure \
                --prefix=/usr/local/php-5.2.10 \
                --enable-maintainer-zts \
                --enable-embed=shared \
                --with-config-file-path=. \
                --with-tsrm-pthreads \
                --disable-static \
                --disable-cgi \
                --disable-ipv6 \
                --without-mysql \
                --without-pear \
                --enable-bcmath=shared \
                --enable-calendar \
                --enable-dbase=shared \
                --enable-dba=shared \
                --enable-dom=shared \
                --enable-exif=shared \
                --enable-ftp=shared \
                --enable-gd-native-ttf \
                --enable-mbstring=shared \
                --enable-pdo \
                --enable-shmop=shared \
                --enable-soap=shared \
                --enable-sockets=shared \
                --enable-sysvmsg=shared \
                --enable-sysvsem=shared \
                --enable-sysvshm=shared \
                --enable-wddx=shared \
                --enable-xmlreader=shared \
                --enable-xmlwriter=shared \
                --with-bz2=shared \
                --with-curl=shared \
                --with-gd=shared \
                --with-iodbc=/usr/local/iODBC \
                --with-ldap=shared \
                --with-mime-magic=shared \
                --with-openssl=shared \
                --with-pdo-odbc="generic,/usr/local/iODBC,iodbc,-L/usr/local/iODBC/lib,-I/usr/local/iODBC/include" \
                --with-sqlite=shared \
                --with-xmlrpc=shared \
                --with-xsl=shared \
                --with-xsl=shared \
                --with-zlib \
                ...
   ```
3. Next build and install the php packages.
   ```
   make
   make install
   ```
4. In the Virtuoso Open Source directory, tell the build process where 
   to find the necessary PHP header files with the following command --
   ```
   ./configure .... --enable-php5=/usr/local/php-5.2.10 ...... 
   ```
   -- or, if you previously configured Virtuoso in this directory --
   ```
   ./config.nice --enable-php5=/usr/local/php-5.2.10
   ```
5. At the end of the `configure` step, the summary screen should indicate that the 
`BUILD_OPTS` include `php5`. If this is not the case, the `config.log` file should 
contain information why `configure` was unable to locate your `php5` installation.


Installation
------------

1. Copy the `libphp5.so` into the same directory where Virtuoso installed the
   `hosting_php5.so` plugin, e.g. --
   ```
   PREFIX/hosting/libphp5.so
   ```
2. If you have built PHP with shared extensions, you can copy them to --
   ```
   PREFIX/hosting/php
   ```
3. Copy the `php.ini-recommended` from the php distro to the same directory
   as your `virtuoso.ini`, e.g. --
   ```
   PREFIX/database/php.ini
   ```
4. Edit your `php.ini` to change the `extensions_dir`
   setting to the directory where you put your extensions, e.g. --
   ```
   extensions_dir = PREFIX/hosting/php
   ```
5. Register the plugin in your `virtuoso.ini`:
   ```
   [Plugins]
   ...
   Load7 = attach, libphp5.so
   Load8 = Hosting, hosting_php.so
   ```

This will enable the `hosting_php` plugin to dynamically hook into the PHP library.



Virtuoso PHP Extensions
-----------------------

Settings
--------

The Virtuoso php hosting plugin adds the following default settings to the `php.ini` file:

```
[Virtuoso]
virtuoso.logging = On
virtuoso.local_dsn = Local Virtuoso
virtuoso.allow_dba = 0
```

If `virtuoso.logging` is `On`, all php messages are passed back to the Virtuoso logwriter.

The `virtuoso.local_dsn` is set by default to `Local Virtuoso` which is the DSN in 
your `odbc.ini` file normally associated with your local Virtuoso database.

The `virtuoso.allow_dba=0` option rejects the use of the `dba` userid when using `__virt_internal_dsn()`.

Functions
---------

#### `__virt_internal_dsn([optional dsn])`

Normally when programming a PHP application, you have to store datasource, username, and password
credentials for making ODBC connections back into the database. This can be a security risk and
requires the administrator to fix scripts manually when they want to run a hosted application under
its own sql account.

The `__virt_internal_dsn()` function returns an ODBC connect string based on the VSP user that owns
the Virtual Directory.

It starts by verifying that the Virtual Directory has been properly set up, and that there is a valid
user that has not been disabled and is allowed to make SQL connections; else, it will log a message
and return `FALSE`.

If the user is a system privileged user (like `dba` or `dav`) and the `virtuoso.allow.dba` setting is
disabled, the function will log a message and return `FALSE`.

The function will return an ODBC `SQLDriverConnect` string using either the supplied `optional_dsn` or
the `virtuoso.local_dsn` and the uid/pwd credentials of the virtual directory in the form:

    DSN=use_dsn;UID=uid;PWD=pwd

This string can be used directly with the `odbc_connect` function in your script. If you want your PHP
application also outside of the Virtuoso hosting environment, you can use it like this:

```
<?php
    //
    // ODBC Connection Variables
    //
    $o_DSN = 'ChangeMe';
    $o_UID = 'ChangeMe';
    $o_PWD = 'ChangeMe';

    if (function_exists ('__virt_internal_dsn')) {
        $db = odbc_connect (__virt_internal_dsn(), null, null);
    } else {
        $db = odbc_connect ($o_DSN, $o_UID, $o_PWD);
    }

    if (!$db)
        error_log ('odbc_connect failed');

    // .....

    odbc_disconnect ($db);
?>
```

Here is an example of a Virtuoso SQL script that creates a database
schema and a table, a user that owns the schema, and a `vhost` entry
that can be used for a PHP application.

```
myapp.sql:

    --
    --  Sample script
    --

    --
    --  Create the MYAPP schema
    --
    use MYAPP
    ;

    --
    --  Create a user MYADMIN who owns the table in this schema
    --
    db.dba.user_create (
	'MYADMIN',				-- Account name
	uuid (),				-- Random UUID as password
        vector ('LOGIN_QUALIFIER', 'MYAPP',
                'SQL_ENABLE', 1,
                'DAV_ENABLE', 0,
                'FULL_NAME', 'MYAPP Administrator'))
    ;

    --
    --  Create the tables in this schema
    --
    create table MYTABLE (
	mt_id INTEGER NOT NULL PRIMARY KEY,
        mt_value VARCHAR (32)
    )
    ;

    --
    --  Insert some sample data
    --
    insert into MYAPP.DBA.MYTABLE VALUES (1, 'Apple');
    insert into MYAPP.DBA.MYTABLE VALUES (2, 'Pear');
    insert into MYAPP.DBA.MYTABLE VALUES (3, 'Banana');
    insert into MYAPP.DBA.MYTABLE VALUES (4, 'Pineapple');
  
    --
    --  Add permissions
    --
    grant all privileges on MYAPP.DBA.MYTABLE to MYADMIN
    ;

    --
    --  Create a new virtual path in Virtuoso
    --
    --  Point to $VIRTUOSO/vsp/testapp on filesystem
    --
    db.dba.vhost_remove (lpath=>'/myapp');
    db.dba.vhost_define (
	lpath=>'/myapp', 
	ppath=>'/testapp', 
	is_dav=>0, 
	is_brws=>0, 
	vsp_user=>'MYADMIN', 
	def_page=>'myapp.php')
    ;

    --
    --  End of sample
    --
```

And the `$VIRTUOSO/vsp/testapp/myapp.php`:

```
<?php
    $db = odbc_connect (__virt_internal_dsn(), null, null);
    if (!$db)
        error_log ('odbc_connect failed');

        $rs = odbc_exec ($db, 'select * from MYAPP.DBA.MYTEST');

    odbc_result_all ($rs);

    odbc_close ($db);
    ?>
```
