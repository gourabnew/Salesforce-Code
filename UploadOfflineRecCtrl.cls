public class UploadOfflineRecCtrl {
	public Document paymentFile { get; set;}
	public Boolean isCorrectHeader { get; set;}
	public Boolean isFileCorrect { get; set;}
	public List<ErrorResponseWrapper> errWrapList { get; set;}

	public UploadOfflineRecCtrl() {
		paymentFile = new Document();		
	}

	public PageReference parseCSVFile(){
        system.debug(paymentFile);
		errWrapList											= new List<ErrorResponseWrapper>();
		List<Payment__c> paymentList 						= new List<Payment__c>();
		Map<String, Offline_Payment_Mapping_File__c> mcs 	= Offline_Payment_Mapping_File__c.getAll();
		Map<String, Schema.SObjectField> paymentFieldMap 	= new Map<String, Schema.SObjectField>();
		paymentFieldMap										= DonationUtility.getObjectFieldMap('Payment__c');
		List<Opportunity> oppList 							= new List<Opportunity>();
		Map<String, Opportunity> paymentIdOppMap 			= new Map<String, Opportunity>();
		oppList												= DonationUtility.getAllPipelinesWithPaymentId();
		if(!oppList.isEmpty()){
			paymentIdOppMap = getPaymentIdOppMap(oppList);
		}

		List<String> bodyLinesList = new List<String>();
		if((paymentFile.Name).endsWithIgnoreCase('.csv') || (paymentFile.Name).endsWithIgnoreCase('.text') || (paymentFile.Name).endsWithIgnoreCase('.txt')){
			Blob fileBody = paymentFile.Body;
			String fileBodyStr = fileBody.toString();
			bodyLinesList = fileBodyStr.split('\n');
			Integer i = 1;
			isCorrectHeader = true;
			isFileCorrect   = true;
			for(String row: bodyLinesList){
 				String[] inputvalues = new String[]{};
 				inputvalues = row.split(',');
				if(i == 1){
					parseHeaderRecord(mcs, inputvalues);
				}else{
					if(isCorrectHeader){
						parseEntryRecord(mcs, inputvalues, row, paymentFieldMap, paymentIdOppMap, paymentList);
					}
				}
				i++;
			}
			if(isCorrectHeader && isFileCorrect){
				try{
					insert paymentList;
					ApexPages.addmessage(new ApexPages.message(ApexPages.severity.INFO,'Upload Successful.'));
				}catch(Exception e){
					ApexPages.addmessage(new ApexPages.message(ApexPages.severity.ERROR,'Insert Failed : '+e.getMessage()));  		
				}
			}else{
				createErrorFile(bodyLinesList);
			}

			}else{
				isCorrectHeader = false;
				isFileCorrect   = false;
				ApexPages.addmessage(new ApexPages.message(ApexPages.severity.ERROR,'Only CSV file needs to be Uploaded.'));  
			}
			return ApexPages.currentPage().setRedirect(false);
	}

	public void parseHeaderRecord(Map<String, Offline_Payment_Mapping_File__c> mcs, String[] inputvalues){
		if( mcs.keySet().size() != inputvalues.size()){
			ApexPages.addmessage(new ApexPages.message(ApexPages.severity.ERROR,'Headers are not in correct format.Please check with Admin for Correct format.'));
			}else{
				for(String headerIndex : mcs.keySet()){
					String csHeaderValue = mcs.get(headerIndex).Column_Header__c;
					String fHeaderValue  = inputvalues[Integer.valueOf(mcs.get(headerIndex).Name) - 1];
					fHeaderValue         = fHeaderValue.trim();
					if(!csHeaderValue.equalsIgnoreCase(fHeaderValue)){
						isCorrectHeader = false;
						ApexPages.addmessage(new ApexPages.message(ApexPages.severity.ERROR,'Headers are not in correct format.Please check with Admin for Correct format.'));
						break;
					}
				}
			}
	}

	public void parseEntryRecord(Map<String, Offline_Payment_Mapping_File__c> mcs, String[] inputvalues, String row, Map<String, Schema.SObjectField> paymentFieldMap, Map<String, Opportunity> paymentIdOppMap, List<Payment__c> paymentList){
		Integer j = 1;
		Payment__c paymentObj = new Payment__c();
		paymentObj.Online_Donation__c = false;
		try{
			for(String inputvalue : inputvalues){			
				if(mcs.get(String.valueOf(j)).Payment_Field_API_Name__c != null){
					Schema.DisplayType lfieldType = paymentFieldMap.get(mcs.get(String.valueOf(j)).Payment_Field_API_Name__c).getDescribe().getType();
					String lfielddataType = String.valueOf(lfieldType);
					
					if(lfielddataType == 'DATE'){
						try{
							inputvalue = inputvalue.trim();
							List<String> inputDate = inputvalue.split('-');
                            if(inputDate.size() != 3) inputDate = inputvalue.split('/');
							inputvalue = inputDate[2] + '-' + inputDate[1] + '-'+ inputDate[0];
							Date inpVal = Date.valueOf(inputvalue);
							paymentObj.put(mcs.get(String.valueOf(j)).Payment_Field_API_Name__c, inpVal);	
						}catch(Exception e){
							throw new CustomException('Error in Field '+mcs.get(String.valueOf(j)).Column_Header__c+' :'+e.getMessage());
						}
					}

					if(lfielddataType == 'CURRENCY' || lfielddataType == 'DOUBLE'){
						try{
							Decimal inpVal = Decimal.valueOf(inputvalue);
							paymentObj.put(mcs.get(String.valueOf(j)).Payment_Field_API_Name__c, inpVal);
						}catch(Exception e){
							throw new CustomException('Error in Field '+mcs.get(String.valueOf(j)).Column_Header__c+' :'+e.getMessage());
						}
					}

					if(lfielddataType == 'TEXTAREA' || lfielddataType == 'STRING' || lfielddataType == 'PICKLIST' || lfielddataType == 'TEXTAREA' || lfielddataType == 'ID' || lfielddataType == 'EMAIL'){
						try{
							paymentObj.put(mcs.get(String.valueOf(j)).Payment_Field_API_Name__c, inputvalue);
						}catch(Exception e){
							throw new CustomException('Error in Field '+mcs.get(String.valueOf(j)).Column_Header__c+' :'+e.getMessage());
						}
					}

					if(lfielddataType == 'DATETIME'){
						try{
							Datetime inpVal = Datetime.valueOf(inputvalue);
							paymentObj.put(mcs.get(String.valueOf(j)).Payment_Field_API_Name__c, inpVal);
						}catch(Exception e){
							throw new CustomException('Error in Field '+mcs.get(String.valueOf(j)).Column_Header__c+' :'+e.getMessage());
						}
					}

					if(lfielddataType == 'BOOLEAN'){
						try{
							Boolean inpVal = Boolean.valueOf(inputvalue);
							paymentObj.put(mcs.get(String.valueOf(j)).Payment_Field_API_Name__c, inpVal);
						}catch(Exception e){
							throw new CustomException('Error in Field '+mcs.get(String.valueOf(j)).Column_Header__c+' :'+e.getMessage());
						}
					}

					if(mcs.get(String.valueOf(j)).Payment_Field_API_Name__c == 'Payment_Id_Dev_Pipeline__c'){
						inputvalue = inputvalue.trim();
						if(paymentIdOppMap.containsKey(inputvalue)){
							paymentObj.Opportunity__c = paymentIdOppMap.get(inputvalue).Id;
						}else{
							throw new CustomException('No Development Pipeline for this Payment Id: '+inputvalue);
						}
					}
				}
				j++;
			}
			paymentObj.Status__c = 'Paid';
			ErrorResponseWrapper erWrapObj = new ErrorResponseWrapper(row, false, null);
			errWrapList.add(erWrapObj);
		}catch(Exception e){
			isFileCorrect = false;
			ErrorResponseWrapper erWrapObj = new ErrorResponseWrapper(row, true, e.getMessage());
			errWrapList.add(erWrapObj);
		}
		paymentList.add(paymentObj);		
	}

	public void createErrorFile(List<String> bodyLinesList){
		String errFile = bodyLinesList[0]+',Error\n';
		for(ErrorResponseWrapper errObj: errWrapList){
			if(errObj.isError) errFile = errFile + errObj.rowLine +','+errObj.errorMessage + '\n';
			else errFile = errFile + errObj.rowLine +',\n';
			}

		Document document = new Document();
	    document.Body = Blob.valueOf(errFile); 
    	document.ContentType = '.csv';
    	document.IsPublic = true;
    	document.Name = 'Error_File '+Datetime.now()+'.csv';
    	document.FolderId = DonationUtility.getFolderDetails('Error Files(Offline Payment)').Id;
    	insert document;
		ApexPages.addmessage(new ApexPages.message(ApexPages.severity.ERROR,'Insert Failed. Please find the Error file : <a target="_blank" href="'+URL.getSalesforceBaseUrl().toExternalForm()+'/'+document.Id+'">Click here</a>'));
	}

	public Map<String, Opportunity> getPaymentIdOppMap(List<Opportunity> oppList){
		Map<String, Opportunity> oppPaymentIdMap = new Map<String, Opportunity>();
		for(Opportunity oppObj: oppList){
			oppPaymentIdMap.put(oppObj.Payment_Id__c, oppObj);
		}
		return oppPaymentIdMap;
	}

	public class ErrorResponseWrapper{
		public String rowLine {get ; set;}
		public Boolean isError {get ; set;}
		public String errorMessage {get ; set;}

		public ErrorResponseWrapper(String rowLine, Boolean isError, String errorMessage){
			this.rowLine 		= rowLine;
			this.isError 		= isError;
			this.errorMessage 	= errorMessage;
		}
	}
}