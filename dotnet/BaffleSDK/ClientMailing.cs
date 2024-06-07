public class ClientMailing{
   public string RecordID { get; set; }
   public string CompanyName { get; set; }
   public string Co_Address_Line_1 { get; set; }
   public string Co_Address_Line_2 { get; set; }
   public string Co_Address_Line_3 { get; set; }
   public string EmployerTaxID { get; set; }
   public string Name { get; set; }
   public string LastName { get; set; }
   public string FirstName { get; set; }
   public string MiddleName { get; set; }
   public string Emp_Address_Line_1 { get; set; }
   public string Emp_Address_Line_2 { get; set; }
   public string Emp_Address_Line_3 { get; set; }
   public string City { get; set; }
   public string State { get; set; }
   public string Zip { get; set; }
   public string Country { get; set; }
   public string TaxpayerID { get; set; }
   public string OptionGranted { get; set; }
   public string OptionExercised { get; set; }
   public string FMV { get; set; }
   public string FMVG { get; set; }
   public string FMVE { get; set; }
   public string SharePrice { get; set; }
   public string SharePriceDetermined { get; set; }
   public string SharesTransferred { get; set; }
   public string TransferDate { get; set; }
   public string Account { get; set; }
   public string ClientID { get; set; }
   public string FilingYear { get; set; }
   public string Other1 { get; set; }
   public string Other2 { get; set; }
   public string Other3 { get; set; }
   public string Other4 { get; set; }
   public string FormID { get; set; }
   public string Corrected { get; set; }
   public string FileName { get; set; }
   public string SortOrderDetailKey { get; set; }
   public string SortOrderBaseKey { get; set; }
   public string CreatedBy { get; set; }
   public string EEID { get; set; }
   public string RecordCreatedDate { get; set; }
   public string RecordFixedInd { get; set; }
   public string ImportID { get; set; }
   public string upsize_ts { get; set; }
   public ClientMailing Clone()
    {
        return (ClientMailing)this.MemberwiseClone();
    }
}

public class ColumnInfo{
   public string Name { get; set; }

   public string DataType { get; set; }
   public string Format { get; set; }
      public int KeyId { get; set; }
}


public class ClientMailingEqualityComparer : IEqualityComparer<ClientMailing>
{
    public bool Equals(ClientMailing x, ClientMailing y)
    {
        // Compare the properties of the two objects
        return x.Name == y.Name &&
               x.LastName == y.LastName &&
               x.FirstName == y.FirstName &&
               x.MiddleName == y.MiddleName &&
               x.Emp_Address_Line_1 == y.Emp_Address_Line_1 &&
               x.Emp_Address_Line_2 == y.Emp_Address_Line_2 &&
               x.Emp_Address_Line_3 == y.Emp_Address_Line_3 &&
               x.TaxpayerID == y.TaxpayerID &&
               x.Account == y.Account &&
               x.EEID == y.EEID ;
    }

    public int GetHashCode(ClientMailing obj)
    {
        return obj.RecordID.GetHashCode() ^ obj.CompanyName.GetHashCode();
    }
}