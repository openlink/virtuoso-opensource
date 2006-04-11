CS=csc.exe

CS_WINFORMS_IMPORTS=/R:System.DLL /R:System.Windows.Forms.DLL  /R:System.Drawing.DLL

OUTDIR=.

#this should be set to the path to the Microsoft.Web.Services.dll
CSLIBFLAGS=/lib:.

CS_EXE_FLAGS=/nologo $(CSLIBFLAGS)

TARGETS = \
  $(OUTDIR)\x509Client.exe
CLEANUP = \
  $(OUTDIR)\x509Client.exe \
  $(OUTDIR)\x509Client.pdb

IMPORTS=$(CS_WINFORMS_IMPORTS) /r:System.dll /r:System.Web.Services.dll /r:System.Data.dll /r:System.Xml.dll /r:Microsoft.Web.Services2.dll

all : $(TARGETS)

$(OUTDIR)\x509Client.exe : x509Client.cs
  @if not exist $(OUTDIR) md $(OUTDIR)
  $(CS) $(CS_EXE_FLAGS) $(IMPORTS) /out:$@ $**

clean :
  @for %i in ( $(CLEANUP) ) do @if exist %i del %i
