Module round2_base
    Function checkarray(ByVal x, ByVal y) As Integer

        Dim inx As Integer

        If (x.Length() <> y.length()) Then
            Return 0
        End If

        For inx = 0 To x.length() - 1
            If (x(inx) <> y(inx)) Then
                Return 0
            End If
        Next

        Return 1
    End Function
    Sub testString(ByRef InteropTest)
        Dim inputString, outputString As String
        inputString = "test1"
        outputString = InteropTest.echoString(inputString)
        System.Console.WriteLine(inputString)
        System.Console.WriteLine(outputString)
        If (inputString = outputString) Then
            System.Console.WriteLine("echoString OK")
        Else
            System.Console.WriteLine("echoString differ")
        End If
    End Sub
    Sub testStringArray(ByRef InteropTest)
        Dim inputString, outputString As String
        inputString = "test1"
        outputString = InteropTest.echoString(inputString)
        System.Console.WriteLine(inputString)
        System.Console.WriteLine(outputString)
        If (inputString = outputString) Then
            System.Console.WriteLine("echoString OK")
        Else
            System.Console.WriteLine("echoString differ")
        End If
    End Sub
    Sub testInteger(ByRef InteropTest)
        Dim inputInteger, outputInteger As Integer
        inputInteger = 1
        outputInteger = InteropTest.echoInteger(inputInteger)
        System.Console.WriteLine(inputInteger)
        System.Console.WriteLine(outputInteger)
        If (inputInteger = outputInteger) Then
            System.Console.WriteLine("echoInteger OK")
        Else
            System.Console.WriteLine("echoInteger differ")
        End If
    End Sub
    Sub testIntegerArray(ByRef InteropTest)
        Dim inputIntegerArray(2), outputIntegerArray(2) As Integer
        inputIntegerArray(0) = 1
        inputIntegerArray(1) = 2
        inputIntegerArray(2) = 3
        outputIntegerArray = InteropTest.echoIntegerArray(inputIntegerArray)
        System.Console.WriteLine(inputIntegerArray)
        System.Console.WriteLine(outputIntegerArray)
        If (checkarray(inputIntegerArray, outputIntegerArray)) Then
            System.Console.WriteLine("echoIntegerArray OK")
        Else
            System.Console.WriteLine("echoIntegerArray differ")
        End If
    End Sub
    Sub testFloat(ByRef InteropTest)
        Dim inputFloat, outputFloat As Single
        inputFloat = 1.234
        outputFloat = InteropTest.echoFloat(inputFloat)
        System.Console.WriteLine(inputFloat)
        System.Console.WriteLine(outputFloat)
        If (inputFloat = outputFloat) Then
            System.Console.WriteLine("echoFloat OK")
        Else
            System.Console.WriteLine("echoFloat differ")
        End If
    End Sub
    Sub testFloatArray(ByRef InteropTest)
        Dim inputFloatArray(2), outputFloatArray(2) As Single
        inputFloatArray(0) = 1.234
        inputFloatArray(1) = 2.345
        inputFloatArray(2) = 3.456
        outputFloatArray = InteropTest.echoFloatArray(inputFloatArray)
        System.Console.WriteLine(inputFloatArray)
        System.Console.WriteLine(outputFloatArray)
        If (checkarray(inputFloatArray, outputFloatArray)) Then
            System.Console.WriteLine("echoFloatArray OK")
        Else
            System.Console.WriteLine("echoFloatArray differ")
        End If
    End Sub
    Sub testBoolean(ByRef InteropTest)
        Dim inputBoolean, outputBoolean As Boolean
        inputBoolean = True
        outputBoolean = InteropTest.echoBoolean(inputBoolean)
        System.Console.WriteLine(inputBoolean)
        System.Console.WriteLine(outputBoolean)
        If (inputBoolean = outputBoolean) Then
            System.Console.WriteLine("echoBoolean OK")
        Else
            System.Console.WriteLine("echoBoolean differ")
        End If
    End Sub
    Sub testDate(ByRef InteropTest)
        Dim inputDate, outputDate As Date
        inputDate = "12/31/2001"
        outputDate = InteropTest.echoDate(inputDate)
        System.Console.WriteLine(inputDate)
        System.Console.WriteLine(outputDate)
        If (inputDate = outputDate) Then
            System.Console.WriteLine("echoDate OK")
        Else
            System.Console.WriteLine("echoDate differ")
        End If
    End Sub
    Sub testDecimal(ByRef InteropTest)
        Dim inputDecimal, outputDecimal As Decimal
        inputDecimal = 12.34567
        outputDecimal = InteropTest.echoDecimal(inputDecimal)
        System.Console.WriteLine(inputDecimal)
        System.Console.WriteLine(outputDecimal)
        If (inputDecimal = outputDecimal) Then
            System.Console.WriteLine("echoDecimal OK")
        Else
            System.Console.WriteLine("echoDecimal differ")
        End If
    End Sub
    Sub testBase64(ByRef InteropTest)
        Dim inputBase64(2), outputBase64(2) As Byte
        inputBase64(0) = 64
        inputBase64(1) = 65
        inputBase64(2) = 66
        outputBase64 = InteropTest.echoBase64(inputBase64)
        System.Console.WriteLine(inputBase64)
        System.Console.WriteLine(outputBase64)
        If (checkarray(inputBase64, outputBase64)) Then
            System.Console.WriteLine("echoBase64 OK")
        Else
            System.Console.WriteLine("echoBase64 differ")
        End If
    End Sub
    Sub testStruct(ByRef InteropTest)
        Dim inputStruct As New ilab2.[web reference].SOAPStruct()
        Dim outputStruct As ilab2.[web reference].SOAPStruct

        inputStruct.varFloat = 123.456
        inputStruct.varInt = 2
        inputStruct.varString = 3
        outputStruct = InteropTest.echoStruct(inputStruct)
        System.Console.WriteLine(inputStruct)
        System.Console.WriteLine(outputStruct)
        If (inputStruct.varFloat = outputStruct.varFloat And inputStruct.varInt = outputStruct.varInt And inputStruct.varString = outputStruct.varString) Then
            System.Console.WriteLine("echoStruct OK")
        Else
            System.Console.WriteLine("echoStruct differ")
        End If
    End Sub
    Sub testStructArray(ByRef InteropTest)
        Dim inputStructArray(1) As ilab2.[web reference].SOAPStruct
        Dim outputStructArray(1) As ilab2.[web reference].SOAPStruct

        inputStructArray(0) = New ilab2.[web reference].SOAPStruct()
        inputStructArray(0).varFloat = 123.456
        inputStructArray(0).varInt = 2
        inputStructArray(0).varString = "3"
        inputStructArray(1) = New ilab2.[web reference].SOAPStruct()
        inputStructArray(1).varFloat = 123.4567
        inputStructArray(1).varInt = 22
        inputStructArray(1).varString = "33"
        outputStructArray = InteropTest.echoStructArray(inputStructArray)
        System.Console.WriteLine(inputStructArray)
        System.Console.WriteLine(outputStructArray)
        If (inputStructArray(0).varFloat = outputStructArray(0).varFloat And inputStructArray(0).varInt = outputStructArray(0).varInt And inputStructArray(0).varString = outputStructArray(0).varString And inputStructArray(1).varFloat = outputStructArray(1).varFloat And inputStructArray(1).varInt = outputStructArray(1).varInt And inputStructArray(1).varString = outputStructArray(1).varString) Then
            System.Console.WriteLine("echoStructArray OK")
        Else
            System.Console.WriteLine("echoStructArray differ")
        End If
    End Sub
    Sub Main()

        Dim InteropTest As New ilab2.[web reference].VirtuosoSOAP()

        testString(InteropTest)
        testStringArray(InteropTest)
        testInteger(InteropTest)
        testIntegerArray(InteropTest)
        testFloat(InteropTest)
        testFloatArray(InteropTest)
        testBoolean(InteropTest)
        testDate(InteropTest)
        testDecimal(InteropTest)
        testBase64(InteropTest)
        testStruct(InteropTest)
        Try
            testStructArray(InteropTest)
        Catch
        System.Console.WriteLine("Exception in structArray")
        End Try

        InteropTest.echoVoid()
    End Sub

End Module
