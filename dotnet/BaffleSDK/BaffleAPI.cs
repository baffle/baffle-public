using System.Net.Http;
using System.Text;
using System.Threading.Tasks;
using Newtonsoft.Json;

public class BaffleAPI
{
    private string? _hostUrl;
    private string? _authenticationToken;
    private HttpClient _client;

    public void Connect(string hostUrl)
    {
        this.Connect(hostUrl, false, null);
    }

    public void Connect(string hostUrl, bool noVerifySSL)
    {
        this.Connect(hostUrl, noVerifySSL, null);
    }

    public void Connect(string hostUrl, bool noVerifySSL, string? authenticationToken)
    {
        _hostUrl = hostUrl;
        _authenticationToken = authenticationToken;

        if (noVerifySSL)
        {
            // Create a HttpClientHandler
            var handler = new HttpClientHandler();
            // Set the ServerCertificateCustomValidationCallback to a lambda that always returns true
            handler.ServerCertificateCustomValidationCallback = (sender, cert, chain, sslPolicyErrors) => true;
            _client = new HttpClient(handler);
        }
        else
        {
            _client = new HttpClient();
        }

        if (!string.IsNullOrEmpty(_authenticationToken))
        {
            _client.DefaultRequestHeaders.Add("Authentication", $"Bearer {_authenticationToken}");
        }
    }

    public async Task<bool> APIStatus()
    {
        return await GetAPIStatus();
    }



    private async Task<bool> GetAPIStatus()
    {
        HttpResponseMessage result = await _client.GetAsync($"{_hostUrl}/api/service/status");

        if (result.IsSuccessStatusCode)
        {
            return true;
        }
        return false;
    }


    public async Task<string> EncryptName(string keyId, string value)
    {
        return await FPEOperation(false, "alphanum", keyId, value);
    }

    public async Task<string> EncryptAddress(string keyId, string value)
    {
        return await FPEOperation(false, "alphanum", keyId, value);
    }

    public async Task<string> EncryptSSN(string keyId, string value)
    {
        return await FPEOperation(false, "decimal", keyId, value);
    }

    public async Task<string> EncryptCreditCard(string keyId, string value)
    {
        return await FPEOperation(false, "cc", keyId, value);
    }

    public async Task<string> DecryptName(string keyId, string value)
    {
        return await FPEOperation(true, "alphanum", keyId, value);
    }

    public async Task<string> DecryptSSN(string keyId, string value)
    {
        return await FPEOperation(true, "decimal", keyId, value);
    }

    public async Task<string> DecryptAddress(string keyId, string value)
    {
        return await FPEOperation(true, "alphanum", keyId, value);
    }

    public async Task<string> DecryptCreditCard(string keyId, string value)
    {
        return await FPEOperation(true, "cc", keyId, value);
    }

    private async Task<string> FPEOperation(bool decrypt, string format, string keyId, string value)
    {
        var operation = decrypt ? "decrypt" : "encrypt";
        var data = $"{{\"data\" :[{{\"id\" : \"1\",\"txt\" : \"{value}\"}}]}}";
        var content = new StringContent(data, Encoding.UTF8, "application/json");

        HttpResponseMessage response = await _client.PostAsync($"{_hostUrl}/api/v3/fpe-{operation}/string?format={format}&keyId={keyId}", content);

        if (response.IsSuccessStatusCode)
        {
            var jsonString = response.Content.ReadAsStringAsync().Result;
            var root = JsonConvert.DeserializeObject<Root>(jsonString);
            return root.fpeData.First().txt;
        }
        return "";
    }

}

public class FpeDat
{
    public string txt { get; set; }
    public int keyId { get; set; }
    public int id { get; set; }
    public string status { get; set; }
}

public class Root
{
    public List<FpeDat> fpeData { get; set; }
}