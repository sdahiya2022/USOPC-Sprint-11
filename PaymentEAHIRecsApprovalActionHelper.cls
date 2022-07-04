/*******************************************************************************************
* @author           Suman
* @version          1.0 
* @date             17-JUN-2022
* @Status           In-Progress
* @Class Name     	PaymentEAHIRecsApprovalActionHelper
* @description      This is a helper class for - PaymentRecsApprovalActionController,EAHIRecsApprovalActionController.

*********************************************************************************************
 Version     Date      Team          Comments
*********************************************************************************************
* 1      June 2022    Suman          Initial Creation
*********************************************************************************************/
public with sharing class PaymentEAHIRecsApprovalActionHelper {
    public class AppProcessWorkItemException extends Exception {}
    
    public static Set<Id> getQueueIdsForLoggedInUser(){
        Set<Id> queueIdSet=new Set<Id>();
        for(GroupMember grpItem: [SELECT Group.Name,Group.ID FROM GroupMember WHERE UserOrGroupId =: UserInfo.getUserId() AND Group.Type =: PaymentEAHIApprovalCtrlConstant.GROUP_QUEUE WITH SECURITY_ENFORCED])
            queueIdSet.add(grpItem.Group.ID);
        return queueIdSet;
    }
    
    public static List<ProcessInstance> getApprovalProcessInstanceList(Set<Id> queueIdSet, String objectName){
        List<ProcessInstance> processInstanceList = new List<ProcessInstance>();
        if (Schema.sObjectType.ProcessInstance.isAccessible() && Schema.sObjectType.ProcessInstanceStep.isAccessible() && Schema.sObjectType.ProcessInstanceWorkitem.isAccessible()) 
            for(ProcessInstance item: [SELECT Id,TargetObjectId,TargetObject.Name,CreatedDate,
                                       (SELECT ID FROM WorkItems WHERE OriginalActorId IN : queueIdSet),
                                       (SELECT OriginalActor.Name,Comments FROM Steps WHERE StepStatus =: PaymentEAHIApprovalCtrlConstant.APPSTEPSTATUS_STARTED) 
                                       FROM ProcessInstance WHERE Status =: PaymentEAHIApprovalCtrlConstant.APPSTATUS_PENDING 
                                       ORDER BY CreatedDate DESC LIMIT 10000]){
                                           if(getObjectName(item.TargetObjectId) == objectName)
                                               processInstanceList.add(item);
                                       }
        
        return processInstanceList;
    }
    
    //To get the object label name
    public static String getObjectName(String recordId){
        String keyPrefix = recordId.subString(0,3);
        String objectName = PaymentEAHIApprovalCtrlConstant.STRING_EMPTY;
        Map<String,Schema.SObjectType> sobjectTypeMap = Schema.getGlobalDescribe();
        for(String obj : sobjectTypeMap.keySet()){
            Schema.DescribeSObjectResult sobjectResult = sobjectTypeMap.get(obj).getDescribe();
            if(sobjectResult.getKeyPrefix() == keyPrefix){
                objectName = sobjectResult.getLabel();
                break;
            }
        }
        return objectName;
    }
    
    public static Map<Id,usopc_Payment__c> getIdAndPaymentMap(Set<String> paymentIdSet){
        Map<Id, usopc_Payment__c> paymentAndProjectIdMap = new Map<Id,usopc_Payment__c>();
        
        for(usopc_Payment__c item: [SELECT Id, Name, Project__r.Name,Payment_Period__r.Period_Name__c, Status__c FROM usopc_Payment__c where id IN: paymentIdSet WITH SECURITY_ENFORCED]){
            if(!String.isBlank(item.Project__c))
                paymentAndProjectIdMap.put(item.Id, item);
        }
        
        return paymentAndProjectIdMap;
    }
    
    public static Map<Id,usopc_EAHI_Allocation__c> getIdAndEAHIRecMap(Set<String> EAHIIdSet){
        Map<Id, usopc_EAHI_Allocation__c> EAHIAndProjectIdMap = new Map<Id,usopc_EAHI_Allocation__c>();
        
        for(usopc_EAHI_Allocation__c item: [SELECT Id, Name,usopc_EAHI_Allocation_Name__c,usopc_Status__c, usopc_Project__r.Name FROM usopc_EAHI_Allocation__c where id IN: EAHIIdSet WITH SECURITY_ENFORCED]){
            if(!String.isBlank(item.usopc_Project__c))
                EAHIAndProjectIdMap.put(item.Id, item);
        }
        
        return EAHIAndProjectIdMap;
    }
    
    public static void putSelPaymentRecsOnHold(Set<String> recordNames){
        List<usopc_Payment__c> paymentRecList =[SELECT Id, Name, project__c, Status__c FROM usopc_Payment__c where Name in: recordNames WITH SECURITY_ENFORCED];
        //Update Payment recs status to 'On Hold'
        for (usopc_Payment__c paymentItem : paymentRecList)
            paymentItem.Status__c = PaymentEAHIApprovalCtrlConstant.PAYSTATUS_HOLD;
        
        if (Schema.sObjectType.usopc_Payment__c.isUpdateable()) 
        	update paymentRecList;
    }
    
    //Approve,reject or remove process the record programmatically
    public static String processWorkItemRecs(List<String> submittedWorkItemList,String processType)
    {
        String comments = (processType == 'Removed') ? 'Removed' :  (processType == 'Approve') ? 'Approved' : 'Rejected'; 
        //ProcessWorkitemRequest class has methods to programmatically process submitted records
        List<Approval.ProcessWorkitemRequest> lstWorkItemRequest = new List<Approval.ProcessWorkitemRequest>();
        for(String workItemId : submittedWorkItemList){
            Approval.ProcessWorkitemRequest objWorkItemRequest = new Approval.ProcessWorkitemRequest();
            objWorkItemRequest.setComments(comments);
            objWorkItemRequest.setAction(processType);//approve or reject
            objWorkItemRequest.setWorkitemId(workItemId);
            lstWorkItemRequest.add(objWorkItemRequest);
        }
        Approval.ProcessResult[] lstProcessResult = Approval.process(lstWorkItemRequest,FALSE);
        
        String errorMsg = PaymentEAHIApprovalCtrlConstant.STRING_EMPTY;
        for(Approval.ProcessResult processResult : lstProcessResult){
            if(!processResult.isSuccess()){
                for(Database.Error error : processResult.getErrors())
                    errorMsg += error.getMessage();
                if(!String.isBlank(errorMsg))
                    throw new AppProcessWorkItemException('Approval process exception : ' + errorMsg);
            }
        }
        return PaymentEAHIApprovalCtrlConstant.STRING_SUCCESS;
    }

}