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


// encrypt Decrypt Address
Console.WriteLine("Address Encryption Decryption");
String address = "936 Kiehn Route, West Ned, Tennessee";
String encryptedAddress = await baffleAPI.EncryptAddress(keyId, address);
String decryptedAddress = await baffleAPI.DecryptAddress(keyId, encryptedAddress);
Console.WriteLine($"{address} encrypted -> {encryptedAddress}, and  {encryptedAddress} decrypted -> {decryptedAddress}");


// encrypt Decrypt Name
Console.WriteLine("SSN Encryption Decryption");
String ssn = "673-76-8742";
String encryptedSSN = await baffleAPI.EncryptSSN(keyId, ssn);
String decryptedSSN = await baffleAPI.DecryptSSN(keyId, encryptedSSN);
Console.WriteLine($"{ssn} encrypted -> {encryptedSSN}, and  {encryptedSSN} decrypted -> {decryptedSSN}");


// encrypt Decrypt Credit card
Console.WriteLine("Credit Card Encryption Decryption");
String cc = "3480-7644-8742-8976";
String encryptedCC = await baffleAPI.EncryptSSN(keyId, cc);
String decryptedCC = await baffleAPI.DecryptSSN(keyId, encryptedCC);
Console.WriteLine($"{cc} encrypted -> {encryptedCC}, and  {encryptedCC} decrypted -> {decryptedCC}");
