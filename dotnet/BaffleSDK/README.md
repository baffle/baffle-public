# BaffleSDK: Simplifying Baffle API Integration in C#

BaffleSDK is a software development kit that streamlines interaction with the Baffle API in C#, providing a convenient
wrapper for encryption solutions.

## Prerequisites:

Install the Newtonsoft.Json package from NuGet

`dotnet add package Newtonsoft.Json`

## Run the code:

`Program.cs`  contains the code that illustrates how a connection is made to the Baffle API and various important
encryption and decryption operations are performed.

```
// initialize Baffle API
BaffleAPI baffleAPI = new BaffleAPI();
baffleAPI.Connect("http://localhost:8443", true);

// check status of API
bool status = await baffleAPI.APIStatus();
Console.WriteLine($"Connection established: {status}");

String keyId = "2";

// encrypt Decrypt Name
Console.WriteLine("Name Encryption Decryption");
String name = "John Doe";
String encryptedName = await baffleAPI.EncryptName(keyId, name);
String decryptedName = await baffleAPI.DecryptName(keyId, encryptedName);
Console.WriteLine($"{name} encrypted -> {encryptedName}, and  {encryptedName} decrypted -> {decryptedName}");

```

To run the program, simply navigate to the directory containing the Program.cs file in your terminal or command prompt,
and enter the command:

`dotnet run`

