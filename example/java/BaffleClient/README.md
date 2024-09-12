
# BaffleClient: Simplifying Baffle API Integration for JAVA

BaffleClient is a software development kit that streamlines interaction with the Baffle API in java, providing a convenient
wrapper for encryption solutions.

## Prerequisites:

Add following dependency to gradle or maven 

Gradle
```
    implementation 'com.squareup.okhttp3:okhttp:4.12.0'
    implementation 'com.google.code.gson:gson:2.11.0'
```        

Maven
```
    <dependency>
        <groupId>com.squareup.okhttp3</groupId>
        <artifactId>okhttp</artifactId>
        <version>4.12.0</version>
    </dependency>

    <dependency>
        <groupId>com.google.code.gson</groupId>
        <artifactId>gson</artifactId>
        <version>2.11.0</version>
    </dependency>
```

## Run the code:

`BaffleClientTest`  contains the code that illustrates how a initialize BaffleClient. The 
use Baffle's encrypt and decrypt operations.

```

    // Initialize Baffle Client
    BaffleClient baffleClient = new BaffleClient("10.151.0.158", "3");

    String accountNumber = "7200538537601127";
    // encrypt the account number which is varchar
    String encryptedAccountNumber = baffleClient.fpeEncryptDecimal(accountNumber);
    System.out.println(String.format("AccountNumber: %s \"Not Equal\"  Encrypted AccountNumber: %s", accountNumber, encryptedAccountNumber));
    // decrypt the enceypted account number
    String decryptAccountNumber = baffleClient.fpeDecryptDecimal(encryptedAccountNumber);
    System.out.println(String.format("Decrypted AccountNumber: %s \"Equal\" AccountNumber: %s", decryptAccountNumber, accountNumber));


    String name = "John Smith";
     // encrypt the name
    String encryptedName = baffleClient.fpeEncrypt(name);
    System.out.println(String.format("Name: %s \"Not Equal\"  Encrypted Name: %s", name, encryptedName));
    // decrypt the name
    String decryptName = baffleClient.fpeDecrypt(encryptedName);
    System.out.println(String.format("Decrypted Name: %s \"Equal\" Name: %s", decryptName, name));
```

Output will be below
```
AccountNumber: 7200538537601127 "Not Equal"  Encrypted AccountNumber: 1893082795394667
Decrypted AccountNumber: 7200538537601127 "Equal" AccountNumber: 7200538537601127
Name: John Smith "Not Equal"  Encrypted Name: BXup yCECu
Decrypted Name: John Smith "Equal" Name: John Smith
```
