Imports System.ComponentModel
Imports System.Drawing
Imports System.WinForms


Public Class Form1
    Inherits System.WinForms.Form

    Public Sub New()
        MyBase.New

        Form1 = Me

        'This call is required by the Win Form Designer.
        InitializeComponent

        'TODO: Add any initialization after the InitializeComponent() call
    End Sub

    'Form overrides dispose to clean up the component list.
    Overrides Public Sub Dispose()
        MyBase.Dispose
        components.Dispose
    End Sub
    
    Dim sk As New MSSOAPLib.SoapClient()
    
#Region " Windows Form Designer generated code "
    
    'Required by the Windows Form Designer
    Private components As System.ComponentModel.Container
    Private WithEvents Label3 As System.WinForms.Label
    Private WithEvents soap_param As System.WinForms.TextBox
    Private WithEvents soap_meth As System.WinForms.ComboBox
    Private WithEvents get_wsdl As System.WinForms.Button
    
    
    
    Private WithEvents Label2 As System.WinForms.Label
    Private WithEvents Label1 As System.WinForms.Label
    
    
    Private WithEvents xsl_url As System.WinForms.TextBox
    Private WithEvents wsdl_url As System.WinForms.TextBox
    
    Private WithEvents RichTextBox1 As System.WinForms.RichTextBox
    Private WithEvents start_button As System.WinForms.Button
    
    Dim WithEvents Form1 As System.WinForms.Form
    
    
    'NOTE: The following procedure is required by the Windows Form Designer
    'It can be modified using the Windows Form Designer.  
    'Do not modify it using the code editor.
    Private Sub InitializeComponent()
        Me.components = New System.ComponentModel.Container()
        Me.soap_meth = New System.WinForms.ComboBox()
        Me.wsdl_url = New System.WinForms.TextBox()
        Me.Label2 = New System.WinForms.Label()
        Me.Label1 = New System.WinForms.Label()
        Me.soap_param = New System.WinForms.TextBox()
        Me.start_button = New System.WinForms.Button()
        Me.Label3 = New System.WinForms.Label()
        Me.get_wsdl = New System.WinForms.Button()
        Me.xsl_url = New System.WinForms.TextBox()
        Me.RichTextBox1 = New System.WinForms.RichTextBox()
        
        '@design Me.TrayHeight = 90
        '@design Me.TrayLargeIcon = False
        '@design Me.TrayAutoArrange = True
        soap_meth.Location = New System.Drawing.Point(104, 80)
        soap_meth.Size = New System.Drawing.Size(121, 21)
        soap_meth.TabIndex = 7
        Dim a__1(1) As Object
        a__1(0) = ""
        soap_meth.Items.All = a__1
        
        wsdl_url.Location = New System.Drawing.Point(104, 16)
        wsdl_url.TabIndex = 2
        wsdl_url.Size = New System.Drawing.Size(336, 20)
        
        Label2.Location = New System.Drawing.Point(16, 48)
        Label2.Text = "XSL-T sheet"
        Label2.Size = New System.Drawing.Size(72, 16)
        Label2.TabIndex = 5
        
        Label1.Location = New System.Drawing.Point(16, 24)
        Label1.Text = "WSDL"
        Label1.Size = New System.Drawing.Size(40, 16)
        Label1.TabIndex = 4
        
        soap_param.Location = New System.Drawing.Point(248, 80)
        soap_param.TabIndex = 8
        soap_param.Size = New System.Drawing.Size(192, 20)
        
        start_button.Visible = False
        start_button.Location = New System.Drawing.Point(480, 48)
        start_button.Size = New System.Drawing.Size(75, 23)
        start_button.TabIndex = 0
        start_button.Text = "Start"
        
        Label3.Location = New System.Drawing.Point(32, 88)
        Label3.Text = "Method"
        Label3.Size = New System.Drawing.Size(48, 24)
        Label3.TabIndex = 9
        
        get_wsdl.Location = New System.Drawing.Point(480, 16)
        get_wsdl.Size = New System.Drawing.Size(75, 23)
        get_wsdl.TabIndex = 6
        get_wsdl.Text = "Initialize"
        
        xsl_url.Location = New System.Drawing.Point(104, 48)
        xsl_url.TabIndex = 3
        xsl_url.Size = New System.Drawing.Size(336, 20)
        
        RichTextBox1.Size = New System.Drawing.Size(544, 200)
        RichTextBox1.TabIndex = 1
        RichTextBox1.Location = New System.Drawing.Point(16, 136)
        Me.Text = "SOAP client"
        Me.AutoScaleBaseSize = New System.Drawing.Size(5, 13)
        Me.ClientSize = New System.Drawing.Size(584, 357)
        
        Me.Controls.Add(Label3)
        Me.Controls.Add(soap_param)
        Me.Controls.Add(soap_meth)
        Me.Controls.Add(get_wsdl)
        Me.Controls.Add(Label2)
        Me.Controls.Add(Label1)
        Me.Controls.Add(xsl_url)
        Me.Controls.Add(wsdl_url)
        Me.Controls.Add(RichTextBox1)
        Me.Controls.Add(start_button)
    End Sub
    
#End Region
    
    Protected Sub get_wsdl_Click(ByVal sender As Object, ByVal e As System.EventArgs)
        
        sk.mssoapinit(wsdl_url.Value())
        get_wsdl.Hide()
        start_button.Show()
        
        Dim Reader As New MSSOAPLib.WSDLReader()
        Dim EnumService As MSSOAPLib.EnumWSDLService
        Dim Service As MSSOAPLib.WSDLService
        Dim Fetched As Long
        Dim EnumPort As MSSOAPLib.EnumWSDLPorts
        Dim Port As MSSOAPLib.WSDLPort
        Dim EnumOperation As MSSOAPLib.EnumWSDLOperations
        Dim Operation As MSSOAPLib.WSDLOperation
        
        
        Reader.Load(wsdl_url.Value(), "")
        Reader.GetSoapServices(EnumService)
        Try
            EnumService.Next(1, Service, Fetched)
            If Fetched = 1 Then
                Service.GetSoapPorts(EnumPort)
                EnumPort.Next(1, Port, Fetched)
                If Fetched = 1 Then
                    Port.GetSoapOperations(EnumOperation)
                    EnumOperation.Next(1, Operation, Fetched)
                    Do While Fetched = 1
                        soap_meth.Items.Add(Operation.name.ToString())
                        Fetched = 0
                        EnumOperation.Next(1, Operation, Fetched)
                    Loop
                End If
            End If
        Catch ex As Exception
        End Try
        
    End Sub
    
    Protected Sub start_button_Click(ByVal sender As Object, ByVal e As System.EventArgs)
        call_soap()
    End Sub
    
    Sub call_soap()
        
        Dim g As New MSXML2.DOMDocument30()
        Dim sh As New MSXML2.DOMDocument30()
        Dim res
        Dim res2
        
        RichTextBox1.Clear()
        
        If (soap_meth.SelectedItem.ToString = "get_NasdaqQuotes") Then
            res2 = sk.get_NasdaqQuotes(soap_param.Value())
        ElseIf (soap_meth.SelectedItem.ToString = "fishselect") Then
            res2 = sk.fishselect(soap_param.Value())
        Else
            RichTextBox1.AppendText("This demo can be used against get_NasdaqQuotes or fishselect services")
            Goto endf
        End If
        
        sh.Load(xsl_url.Value())
        
        If (g.loadXML(res2)) Then
            res = g.transformNode(sh)
            RichTextBox1.AppendText(res)
        Else
            RichTextBox1.AppendText(res2)
        End If
Endf:
    End Sub
    
    
End Class
