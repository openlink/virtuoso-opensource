#
#  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
#  project.
#
#  Copyright (C) 1998-2015 OpenLink Software
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


if HAVE_MCS
TARGETS	= OpenLink.Data.Virtuoso.dll
endif

MCS_FLAGS = -sdk:2 /optimize+ /d:MONO /d:ADONET2 /d:MONO1231
SOURCES = \
	$(srcdir)/ArrayOfLongPacked.cs \
	$(srcdir)/AssemblyInfo.cs \
	$(srcdir)/BlobHandle.cs \
	$(srcdir)/BufferType.cs \
	$(srcdir)/CLI.cs \
	$(srcdir)/ConnectionOptions.cs \
	$(srcdir)/ConnectionPool.cs \
	$(srcdir)/ConnectionStringParser.cs \
	$(srcdir)/DataType.cs \
	$(srcdir)/DateTimeMarshaler.cs \
	$(srcdir)/Diagnostics.cs \
	$(srcdir)/DTC.cs \
	$(srcdir)/ExplicitString.cs \
	$(srcdir)/Future.cs \
	$(srcdir)/FutureList.cs \
	$(srcdir)/IConvertData.cs \
	$(srcdir)/ICreateErrors.cs \
	$(srcdir)/IInnerCommand.cs \
	$(srcdir)/IInnerConnection.cs \
	$(srcdir)/IMarshal.cs \
	$(srcdir)/InnerConnectionBase.cs \
	$(srcdir)/ISession.cs \
	$(srcdir)/IVirtuosoError.cs \
	$(srcdir)/ManagedCommand.cs \
	$(srcdir)/ManagedConnection.cs \
	$(srcdir)/ManagedErrors.cs \
	$(srcdir)/Marshaler.cs \
	$(srcdir)/MD5.cs \
	$(srcdir)/MemoryHandle.cs \
	$(srcdir)/Platform.cs \
	$(srcdir)/RPC.cs \
	$(srcdir)/Service.cs \
	$(srcdir)/SqlXml.cs \
	$(srcdir)/SqlExtendedString.cs \
	$(srcdir)/SqlRdfBox.cs \
	$(srcdir)/TcpConnection.cs \
	$(srcdir)/TcpSession.cs \
	$(srcdir)/Unix.cs \
	$(srcdir)/VirtDbType.cs \
	$(srcdir)/VirtuosoCommandBuilder.cs \
	$(srcdir)/VirtuosoCommand.cs \
	$(srcdir)/VirtuosoConnection.cs \
	$(srcdir)/VirtuosoDataAdapter.cs \
	$(srcdir)/VirtuosoDataReader.cs \
	$(srcdir)/VirtuosoDateTime.cs \
	$(srcdir)/VirtuosoDateTimeOffset.cs \
	$(srcdir)/VirtuosoErrorCollection.cs \
	$(srcdir)/VirtuosoError.cs \
	$(srcdir)/VirtuosoException.cs \
	$(srcdir)/VirtuosoInfoMessage.cs \
	$(srcdir)/VirtuosoParameterCollection.cs \
	$(srcdir)/VirtuosoParameter.cs \
	$(srcdir)/VirtuosoPermissionAttribute.cs \
	$(srcdir)/VirtuosoPermission.cs \
	$(srcdir)/VirtuosoTimeSpan.cs \
	$(srcdir)/VirtuosoTransaction.cs \
	$(srcdir)/VirtuosoWarning.cs \
	$(srcdir)/Win32.cs \
	$(srcdir)/VirtuosoClientFactory.cs \
	$(srcdir)/VirtuosoCodeAccessPermission.cs \
	$(srcdir)/VirtuosoConnectionStringBuilder.cs

RESOURCES = \
	/r:System.Data \
	/r:System.EnterpriseServices \
	/r:System.Drawing \
	/resource:$(srcdir)/OpenLink.Data.VirtuosoClient.VirtuosoConnection.bmp \
	/resource:$(srcdir)/OpenLink.Data.VirtuosoClient.VirtuosoCommand.bmp \
	/resource:$(srcdir)/OpenLink.Data.VirtuosoClient.VirtuosoDataAdapter.bmp

OpenLink.Data.Virtuoso.dll: $(SOURCES) Makefile.am
	$(MCS) /unsafe /target:library /out:OpenLink.Data.Virtuoso.dll $(MCS_FLAGS) $(SOURCES) $(RESOURCES)


if HAVE_MCS
install-exec-local:
	$(MKDIR_P) "$(DESTDIR)$(libdir)"
	$(INSTALL) $(TARGETS) "$(DESTDIR)$(libdir)"
endif

# ----------------------------------------------------------------------
#
#  Additional files to distribute
#
# ----------------------------------------------------------------------
EXTRA_DIST = \
	*.bmp \
	*.cs \
	Makefile.mono \
	design/*.cs \
	design/VirtuosoDotNetDSNForm.resx \
	VirtuosoClient.NET.csproj \
	VirtuosoClient.NET.vc2005.csproj \
	VirtuosoClient.snk
