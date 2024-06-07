// initialize Baffle API
using System.Diagnostics;

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


List<ClientMailing> clientMailings = new List<ClientMailing>();

Random rand = new Random();

int numRecords = 10000;
for (int i = 0; i < numRecords; i++)
{
    clientMailings.Add(new ClientMailing
    {
        RecordID = $"RecordID_{i}",
        CompanyName = $"Company_{i}",
        Co_Address_Line_1 = $"Address_{i}",
        Co_Address_Line_2 = $"Address2_{i}",
        Co_Address_Line_3 = $"Address3_{i}",
        EmployerTaxID = $"TaxID_{i}",
        Name = $"Name_{i}",
        LastName = $"Lastname_{i}",
        FirstName = $"Firstname_{i}",
        MiddleName = $"Middlename_{i}",
        Emp_Address_Line_1 = $"EmpAddress_{i}",
        Emp_Address_Line_2 = $"EmpAddress2_{i}",
        Emp_Address_Line_3 = $"EmpAddress3_{i}",
        City = $"City_{i}",
        State = $"State_{i}",
        Zip = $"Zip_{i}",
        Country = $"Country_{i}",
        TaxpayerID = rand.Next(100000, 999999).ToString(), // random numeric value
        OptionGranted = $"OptionGranted_{i}",
        OptionExercised = $"OptionExercised_{i}",
        FMV = $"FMV_{i}",
        FMVG = $"FMVG_{i}",
        FMVE = $"FMVE_{i}",
        SharePrice = $"SharePrice_{i}",
        SharePriceDetermined = $"SharePriceDetermined_{i}",
        SharesTransferred = $"SharesTransferred_{i}",
        TransferDate = $"TransferDate_{i}",
        Account = rand.Next(100000, 999999).ToString(), // random numeric value
        ClientID = $"ClientID_{i}",
        FilingYear = $"FilingYear_{i}",
        Other1 = $"Other1_{i}",
        Other2 = $"Other2_{i}",
        Other3 = $"Other3_{i}",
        Other4 = $"Other4_{i}",
        FormID = $"FormID_{i}",
        Corrected = $"Corrected_{i}",
        FileName = $"FileName_{i}",
        SortOrderDetailKey = $"SortOrderDetailKey_{i}",
        SortOrderBaseKey = $"SortOrderBaseKey_{i}",
        CreatedBy = $"CreatedBy_{i}",
        EEID = rand.Next(100000, 999999).ToString(), // random numeric value
        RecordCreatedDate = $"RecordCreatedDate_{i}",
        RecordFixedInd = $"RecordFixedInd_{i}",
        ImportID = $"ImportID_{i}",
        upsize_ts = $"upsize_ts_{i}",
    });
}

ClientMailingCrypto clientMailingCrypto = new ClientMailingCrypto();

Stopwatch sw = Stopwatch.StartNew();
List<ClientMailing> encryptedClientMailings = await clientMailingCrypto.encrypt(clientMailings, baffleAPI);
sw.Stop();
Console.WriteLine($"Encrypting {numRecords} rows took {sw.Elapsed}");

bool areEncryptEqual = clientMailings.SequenceEqual(encryptedClientMailings, new ClientMailingEqualityComparer());
Console.WriteLine($"plain list  and  encrypted list are same -> {areEncryptEqual}");

sw = Stopwatch.StartNew();
List<ClientMailing> decryptedClientMailings = await clientMailingCrypto.decrypt(encryptedClientMailings, baffleAPI);
sw.Stop();
Console.WriteLine($"Decrypting {numRecords} rows took {sw.Elapsed}");

bool areDecryptEqual = clientMailings.SequenceEqual(decryptedClientMailings, new ClientMailingEqualityComparer());
Console.WriteLine($"plain list  and  decrypted list are same -> {areDecryptEqual}");
