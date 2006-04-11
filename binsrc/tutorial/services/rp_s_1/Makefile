CS=csc.exe

CS_WINFORMS_IMPORTS=/R:System.DLL /R:System.Windows.Forms.DLL  /R:System.Drawing.DLL

OUTDIR=.

#set path to the Microsoft.WSDK.dll
CSLIBFLAGS=/lib:.

CS_EXE_FLAGS=/nologo $(CSLIBFLAGS)

TARGETS = \
  $(OUTDIR)\RoutingClient.exe
CLEANUP = \
  $(OUTDIR)\RoutingClient.exe \
  $(OUTDIR)\RoutingClient.pdb \
  $(OUTDIR)\*.webinfo \
  $(OUTDIR)\clientReferralCache.config \

IMPORTS=$(CS_WINFORMS_IMPORTS) /r:System.dll /r:System.Web.Services.dll /r:System.Data.dll /r:System.Xml.dll /r:Microsoft.WSDK.dll

all : $(TARGETS)

$(OUTDIR)\RoutingClient.exe : RoutingClient.cs
  @if not exist $(OUTDIR) md $(OUTDIR)
  $(CS) $(CS_EXE_FLAGS) $(IMPORTS) /out:$@ $**


clean :
  @for %i in ( $(CLEANUP) ) do @if exist %i del %i
