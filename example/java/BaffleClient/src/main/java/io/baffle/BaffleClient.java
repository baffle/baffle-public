package io.baffle;

import com.google.gson.Gson;
import okhttp3.*;

import javax.net.ssl.SSLContext;
import javax.net.ssl.TrustManager;
import javax.net.ssl.X509TrustManager;
import java.io.IOException;
import java.security.KeyManagementException;
import java.security.NoSuchAlgorithmException;
import java.util.List;
import java.util.Objects;

public class BaffleClient {

  private static final MediaType JSON = MediaType.get("application/json");
  private static final String FPE_URL   = "%s/api/v3/fpe-%s/string?format=%s&keyId=%s";

  private static final Gson gson = new Gson();
  private OkHttpClient client;
  private String hostname;
  private String jwtToken;
  private String apiKey;
  private String keyId;

  public BaffleClient(String hostname,String keyId, String apiKey, String jwtToken) {
    try {
      assert hostname != null;
      assert keyId != null;
      this.hostname = hostname;
      this.apiKey = apiKey;
      this.jwtToken = jwtToken;
      this.keyId = keyId;
      this.initialize();
    } catch (NoSuchAlgorithmException | KeyManagementException  e) {
      throw new RuntimeException(e.getMessage());
    }
  }

  public BaffleClient(String hostname, String keyId) {
    this(hostname, keyId, null, null);
  }

  public BaffleClient(String hostname, String keyId, boolean useApiKey, String keyOrToken) {
    this(hostname, keyId, useApiKey ? keyOrToken : null , useApiKey ? null : keyOrToken);
  }

  private final TrustManager[] trustAllCerts = new TrustManager[]{
      new X509TrustManager() {
        @Override
        public void checkClientTrusted(java.security.cert.X509Certificate[] chain, String authType) {
        }

        @Override
        public void checkServerTrusted(java.security.cert.X509Certificate[] chain, String authType) {
        }

        @Override
        public java.security.cert.X509Certificate[] getAcceptedIssuers() {
          return new java.security.cert.X509Certificate[]{};
        }
      }
  };

  private void initialize() throws NoSuchAlgorithmException, KeyManagementException {
    SSLContext sslContext = SSLContext.getInstance("SSL");
    sslContext.init(null, trustAllCerts, new java.security.SecureRandom());
    OkHttpClient.Builder newBuilder = new OkHttpClient.Builder();
    newBuilder.sslSocketFactory(sslContext.getSocketFactory(), (X509TrustManager) trustAllCerts[0]);
    newBuilder.hostnameVerifier((hostname, session) -> true);
    this.client = newBuilder.build();
  }


  public String fpeEncryptDecimal(String value) throws IOException{
    return fpeOperation(value,  true, "decimal");
  }

  public String fpeDecryptDecimal(String value) throws IOException{
    return fpeOperation(value,  false, "decimal");
  }

  public String fpeEncrypt(String value) throws IOException{
    return fpeOperation(value,  true, "alphanum");
  }

  public String fpeDecrypt(String value) throws IOException{
    return fpeOperation(value,  false, "alphanum");
  }

  private String fpeOperation(String value, boolean encrypt, String format) throws IOException {
      final String url = String.format(FPE_URL, hostname, encrypt? "encrypt": "decrypt" ,format, keyId);
      RequestBody body = RequestBody.create(getJsonData(value), JSON);

      Request request ;

       if (Objects.nonNull(jwtToken) || Objects.nonNull(apiKey)) {
         if (Objects.nonNull(jwtToken)){
           request = new Request.Builder()
               .url(url)
               .post(body)
               .addHeader("Authorization", "Bearer " + jwtToken)
               .build();
          } else {
           request = new Request.Builder()
               .url(url)
               .post(body)
               .addHeader("x-api-key", apiKey)
               .build();
         }
       } else {
         request = new Request.Builder()
             .url(url)
             .post(body)
             .build();
       }

      try (Response response = client.newCall(request).execute()) {
        if (response.isSuccessful()) {
            return getFpeResponse(response.body().string()).getFpeData().get(0).getTxt();
        } else {
          throw new IOException("Unexpected error " + response);
        }
      }
  }

  private String getJsonData(String value) {
    // FpeRequest takes a list of Data to support BULK
    FpeRequest fpeRequest = new FpeRequest(List.of(new Data("1", value)));
    return gson.toJson(fpeRequest);
  }

  private FpeResponse getFpeResponse(String response){
    return gson.fromJson(response, FpeResponse.class);
  }

  private static class FpeRequest {
    private List<Data> data;

    public FpeRequest(List<Data> data) {
      this.data = data;
    }

    public List<Data> getData() {
      return data;
    }

    public void setData(List<Data> data) {
      this.data = data;
    }
  }

  private static class FpeResponse {
    private List<Data> fpeData;

    public FpeResponse(List<Data> fpeData) {
      this.fpeData = fpeData;
    }

    public List<Data> getFpeData() {
      return fpeData;
    }

    public void setFpeData(List<Data> fpeData) {
      this.fpeData = fpeData;
    }
  }

  private static class Data {
    private String id;
    private String txt;
    private String status;
    private String keyId;

    public Data(String id, String txt) {
      this.id = id;
      this.txt = txt;
    }

    public String getId() {
      return id;
    }

    public void setId(String id) {
      this.id = id;
    }

    public String getTxt() {
      return txt;
    }

    public void setTxt(String txt) {
      this.txt = txt;
    }

    public String getStatus() {
      return status;
    }

    public void setStatus(String status) {
      this.status = status;
    }

    public String getKeyId() {
      return keyId;
    }

    public void setKeyId(String keyId) {
      this.keyId = keyId;
    }
  }

}
