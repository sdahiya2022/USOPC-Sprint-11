/*******************************************************************************************
* @author           Suman
* @version          1.0 
* @date             09-JUN-2022
* @Status           In-Progress
* @Class Name     	PaymentRecsApprovalActionController
* @description      This apex class will be used by LWC - ListPaymentRecsSubmittedForApproval.

*********************************************************************************************
Version     Date      Team          Comments
*********************************************************************************************
* 3      June 2022    Suman          Refactored code, removed extra code
* 2      June 2022    Rupa           Added Logic
* 1      June 2022    Suman          Initial Creation
*********************************************************************************************/

public class PaymentRecsApprovalActionController {
    
    //Wrapper class to store the column values of data table
    public class SubmittedRecordsWrapper{
        @AuraEnabled public Id workItemId;
        @AuraEnabled public String recordId;
        @AuraEnabled public String recordName;
         @AuraEnabled public String paymentPeriod;
        @AuraEnabled public String submittedBy;
        @AuraEnabled public Date submittedDate;
        @AuraEnabled public String project;
        @AuraEnabled public String status;
    }
    
    @AuraEnabled
    public static List<SubmittedRecordsWrapper> getSubmittedPaymentRecords(){
        List<SubmittedRecordsWrapper> submittedRecsWrapperList = new List<SubmittedRecordsWrapper>();
        try{
            //Get the queue id to which the logged in user is part of.
            Set<Id> queueIdSet = PaymentEAHIRecsApprovalActionHelper.getQueueIdsForLoggedInUser();
            //Get the processInstance(Payment object) records for the Queues/Logged in user
            List<ProcessInstance> processInstanceList = PaymentEAHIRecsApprovalActionHelper.getApprovalProcessInstanceList(queueIdSet, PaymentEAHIApprovalCtrlConstant.OBJECT_PAYMENT);
            
            //Get the Payment record ids
            Set<String> paymentIdSet = new Set<String>(); 
            for(ProcessInstance item: processInstanceList)
                paymentIdSet.add(item.TargetObjectId);
            //Create Payment record id and Payment record Map
            Map<Id, usopc_Payment__c> paymentIdAndRecMap = PaymentEAHIRecsApprovalActionHelper.getIdAndPaymentMap(paymentIdSet);
            //Create wrapper records to be displayed to the user for approval/rejection
            submittedRecsWrapperList = getWrapperRecordsTobeDisplayed(processInstanceList,paymentIdAndRecMap);
        }catch(Exception e){
            System.debug('System Exception in getSubmittedPaymentRecords(): ' + e.getTypeName());
            System.debug(e.getMessage());
            System.debug(e.getStackTraceString());
            throw new AuraHandledException('System Exception occurred - '+e.getMessage());   
        }
        return submittedRecsWrapperList;
    }
    
    @AuraEnabled
    public static String processRecords(String processType,String strWraperRecs){
        List<SubmittedRecordsWrapper> selWrapperRecList = (List<SubmittedRecordsWrapper>)System.JSON.deserialize(strWraperRecs, List<SubmittedRecordsWrapper>.class);
        try{
            List<String> submittedWorkItemList = new List<String>();
            Set<String> selRecNameSet =new set<String>();
            for(SubmittedRecordsWrapper wrapperItem: selWrapperRecList){
                submittedWorkItemList.add(wrapperItem.workItemId);
                selRecNameSet.add(wrapperItem.recordName);
            }
            
            if(processType == PaymentEAHIApprovalCtrlConstant.PROCESSTYPE_HOLD){
                PaymentEAHIRecsApprovalActionHelper.putSelPaymentRecsOnHold(selRecNameSet);
                //processType = 'Removed';
            }
            else    
                PaymentEAHIRecsApprovalActionHelper.processWorkItemRecs(submittedWorkItemList,processType);
        }catch(Exception e){
            System.debug('System Exception in processRecords(): ' + e.getTypeName());
            System.debug(e.getMessage());
            System.debug(e.getStackTraceString());
            throw new AuraHandledException('System Exception occurred - '+e.getMessage());   
        }
        return PaymentEAHIApprovalCtrlConstant.STRING_SUCCESS;
    }
    
    public static List<SubmittedRecordsWrapper> getWrapperRecordsTobeDisplayed(List<ProcessInstance> processInstanceList,Map<Id, usopc_Payment__c> paymentIdAndRecMap){
        List<SubmittedRecordsWrapper> submittedRecsWrapperList = new List<SubmittedRecordsWrapper>();
        for(ProcessInstance ps : processInstanceList){
            if(!ps.WorkItems.isEmpty()){
                SubmittedRecordsWrapper objSubmittedRecordsWrapper = new SubmittedRecordsWrapper();
                objSubmittedRecordsWrapper.workItemId = ps.WorkItems[0].Id;
                objSubmittedRecordsWrapper.recordId = ps.TargetObjectId;
                objSubmittedRecordsWrapper.recordName = ps.TargetObject.Name;
                objSubmittedRecordsWrapper.paymentPeriod = paymentIdAndRecMap.get(objSubmittedRecordsWrapper.recordId).Payment_Period__r.Period_Name__c;
                objSubmittedRecordsWrapper.project = paymentIdAndRecMap.get(objSubmittedRecordsWrapper.recordId).Project__r.Name;
                objSubmittedRecordsWrapper.status = paymentIdAndRecMap.get(objSubmittedRecordsWrapper.recordId).Status__c;
                objSubmittedRecordsWrapper.submittedDate = Date.newInstance(ps.CreatedDate.year(),ps.CreatedDate.month(),ps.CreatedDate.day());
                if(!ps.steps.isEmpty())
                    objSubmittedRecordsWrapper.submittedBy = ps.steps[0].OriginalActor.Name;
                submittedRecsWrapperList.add(objSubmittedRecordsWrapper);
            }
        }
        return submittedRecsWrapperList;
    }
}