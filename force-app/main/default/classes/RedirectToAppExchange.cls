public class RedirectToAppExchange {

    public RedirectToAppExchange(){}
    
    Public PageReference redirectHandler(){
        return new PageReference('https://appexchange.salesforce.com/appxConsultingListingDetail?listingId=a0N3u00000ONTzTEAX');
    }
}