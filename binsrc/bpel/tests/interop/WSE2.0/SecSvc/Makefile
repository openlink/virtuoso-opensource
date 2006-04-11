CS=csc.exe

CS_WINFORMS_IMPORTS=/R:System.DLL /R:System.Windows.Forms.DLL  /R:System.Drawing.DLL

OUTDIR=bin\.

CSLIBFLAGS=/lib:.

CS_EXE_FLAGS=/nologo $(CSLIBFLAGS)

TARGETS = \
  $(OUTDIR)\SecSvc.dll

CLEANUP = \
  $(OUTDIR)\SecSvc.dll

IMPORTS=$(CS_WINFORMS_IMPORTS) /r:System.dll /r:System.Web.Services.dll /r:System.Data.dll /r:System.Xml.dll /r:Microsoft.Web.Services2.dll

all : $(TARGETS)

$(OUTDIR)\SecSvc.dll : SecSvc.asmx.cs
  @if not exist $(OUTDIR) md $(OUTDIR)
  $(CS) $(CS_EXE_FLAGS) $(IMPORTS) /target:library /out:$@ $**


clean :
  @for %i in ( $(CLEANUP) ) do @if exist %i del %i
