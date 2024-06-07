

using System.Reflection;

public class ClientMailingCrypto
{
    List<ColumnInfo> columnInfos = new List<ColumnInfo>(){
        new ColumnInfo{Name = "Name", DataType= "string", Format = "alphanum", KeyId = 2},
        new ColumnInfo{Name = "LastName", DataType= "string", Format =  "alphanum", KeyId = 2},
        new ColumnInfo{Name = "FirstName", DataType= "string", Format = "alphanum", KeyId = 2},
        new ColumnInfo{Name = "MiddleName", DataType= "string", Format = "alphanum", KeyId = 2},
        new ColumnInfo{Name = "Emp_Address_Line_1", DataType= "string", Format = "alphanum", KeyId = 2},
        new ColumnInfo{Name =  "Emp_Address_Line_2", DataType= "string", Format = "alphanum", KeyId = 2},
        new ColumnInfo{Name = "Emp_Address_Line_3",  DataType= "string",Format = "alphanum", KeyId = 2},
        new ColumnInfo{Name = "TaxpayerID", DataType= "string", Format = "decimal", KeyId = 2},
        new ColumnInfo{Name = "Account", DataType = "string", Format = "decimal", KeyId = 2},
        new ColumnInfo{Name = "EEID", DataType = "string", Format = "decimal", KeyId = 2}
    };

    const int MAX_NUM_RECORDS = 500;

    public async Task<List<ClientMailing>> encrypt(List<ClientMailing> clientMailingList, BaffleAPI baffle)
    {
        List<ClientMailing> modifyList = clientMailingList.Select(x => x.Clone()).ToList();

        var subLists = breakIntoSubList(modifyList);

        foreach (List<ClientMailing> sublist in subLists)
        {
            var requestData = convertClientMailingToBaffleBulkRequest(sublist);
            var responseData = await baffle.FPEBulkOperation(false, requestData);
            updateClientMailingWithEncryptedData(responseData, sublist);
        }
        return combineList(subLists);
    }

    private void updateClientMailingWithEncryptedData(BulkFpeResponseData responseData, List<ClientMailing> clientMailings)
    {
        foreach (FpeResponseData fpeData in responseData.fpeData)
        {
            string columnName = fpeData.columnName;
            Data data = fpeData.data[0];
            int index = data.id - 1;
            ClientMailing clientMailing = clientMailings[index];
            PropertyInfo property = clientMailing.GetType().GetProperty(columnName);
            property.SetValue(clientMailing, data.value);

        }
    }

    private BulkFpeRequestData convertClientMailingToBaffleBulkRequest(List<ClientMailing> clientMailings)
    {
        List<BulkFpeItem> fpeItems = new List<BulkFpeItem>();
        for (int i = 0; i < clientMailings.Count; i++)
        {
            ClientMailing clientMailing = clientMailings[i];
            foreach (ColumnInfo columnInfo in columnInfos)
            {
                BulkFpeItem fpeItem = new BulkFpeItem();
                fpeItem.keyId = columnInfo.KeyId;
                fpeItem.datatype = columnInfo.DataType;
                fpeItem.columnName = columnInfo.Name;
                BulkFpeData fpeData = new BulkFpeData();
                fpeData.format = columnInfo.Format;
                fpeData.data = new List<Data> { new Data { id = i + 1, value = (string)clientMailing.GetType().GetProperty(columnInfo.Name).GetValue(clientMailing, null) } };
                fpeItem.fpeData = new List<BulkFpeData>() { fpeData };
                fpeItems.Add(fpeItem);
            }
        }

        BulkFpeRequestData requestData = new BulkFpeRequestData();
        requestData.fpeItems = fpeItems;
        return requestData;
    }

    public async Task<List<ClientMailing>> decrypt(List<ClientMailing> clientMailingList, BaffleAPI baffle)
    {
        List<ClientMailing> modifyList = clientMailingList.Select(x => x.Clone()).ToList();
        var subLists = breakIntoSubList(modifyList);
        foreach (List<ClientMailing> sublist in subLists)
        {
            var requestData = convertClientMailingToBaffleBulkRequest(sublist);
            var responseData = await baffle.FPEBulkOperation(true, requestData);
            updateClientMailingWithEncryptedData(responseData, sublist);
        }
        return combineList(subLists);
    }

    private List<List<ClientMailing>> breakIntoSubList(List<ClientMailing> originalList)
    {
        return originalList
           .Select((item, index) => new { Item = item, Index = index })
           .GroupBy(x => x.Index / MAX_NUM_RECORDS)
           .Select(g => g.Select(x => x.Item).ToList())
           .ToList();
    }


    private List<ClientMailing> combineList(List<List<ClientMailing>> subLists)
    {
        return subLists.SelectMany(sublist => sublist).ToList();
    }

}
