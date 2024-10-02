package io.baffle;

public class BaffleClientTest {

  public static void main(String[] args) throws Exception {

    // Initialize Baffle Client
    BaffleClient baffleClient = new BaffleClient("10.151.0.158", "3");
//    BaffleClient baffleClient = new BaffleClient("http://localhost:8443", "2", true, "testing");

    String accountNumber = "7200538537601127";
    String encryptedAccountNumber = baffleClient.fpeEncryptDecimal(accountNumber);
    System.out.println(String.format("AccountNumber: %s \"Not Equal\"  Encrypted AccountNumber: %s", accountNumber, encryptedAccountNumber));
    String decryptAccountNumber = baffleClient.fpeDecryptDecimal(encryptedAccountNumber);
    System.out.println(String.format("Decrypted AccountNumber: %s \"Equal\" AccountNumber: %s", decryptAccountNumber, accountNumber));


    String name = "John Smith";
    String encryptedName = baffleClient.fpeEncrypt(name);
    System.out.println(String.format("Name: %s \"Not Equal\"  Encrypted Name: %s", name, encryptedName));
    String decryptName = baffleClient.fpeDecrypt(encryptedName);
    System.out.println(String.format("Decrypted Name: %s \"Equal\" Name: %s", decryptName, name));

  }
}
