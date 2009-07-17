PHP SAPI module for Virtuoso
============================

This is a SAPI module for PHP 5.x, implemented as a Virtuoso loadable
module.

Building:

  To build the plugin, you first need to build a libphp5.so,
  configured with ZTS.

    Package	Version		From
    -------	-------		-----------------------------
    php		5.2.8		http://www.php.net/downloads/


  In the php source directory, execute something similar to:

	./configure \
		--prefix=/where/to/put/it \
		--enable-maintainer-zts \
		--with-tsrm-pthreads \
		--enable-embed=shared \
		--disable-static \
		--with-config-file-path=. \
		--disable-cgi \
		--disable-cli \
		--disable-ipv6 \
		--disable-pdo \
		--without-mysql \
		--without-pear \
		--with-zlib \
		--with-iodbc=/usr
		.....

	make

	make install


  In the Virtuoso Open Source directory, execute the following command:

	./config.nice --enable-php5=/where/to/put/it

  or

	./configure --enable-php5=/where/to/put/it .......

  so the build process knows where to find the necessary PHP header files.



Installation:

1. Copy the libphp5.so into same directory where virtuoso installs the
   hosting_php5.so plugin e.g. PREFIX/hosting/libphp5.so. If you
   have build PHP with shared extensions, you can put them in
   PREFIX/hosting/php/extensions

2. Copy the php.ini-recommended from the php distro to the same directory
   as your virtuoso.ini. Edit your php.ini to change the extensions_dir
   setting to the directory where you put your extensions

3. Register the plugin in your virtuoso.ini:

    [Plugins]
    ..
    Load7 = attach, libphp5.so
    Load8 = Hosting, hosting_php.so

  This will enable the hosting_php plugin to dynamically hook into the 
  PHP library.
