/*******************************************************************************************
* @author           Suman
* @version          1.0 
* @date             20-JUN-2022
* @Status           In-Progress
* @Class Name     	EAHIRecsApprovalActionController
* @description      This apex class will be used by LWC - ListEAHIRecsSubmittedForApproval.

*********************************************************************************************
Version     Date      Team          Comments
*********************************************************************************************
* 3      June 2022    Suman          Refactored code, removed extra code
* 2      June 2022    Rupa           Added Logic
* 1      June 2022    Suman          Initial Creation
*********************************************************************************************/
public class EAHIRecsApprovalActionController {    
    //Wrapper class to store the column values of data table
    public class SubmittedRecordsWrapper{
        @AuraEnabled public Id workItemId;
        @AuraEnabled public String recordId;
        @AuraEnabled public String recordName;
        @AuraEnabled public String recordNameDesc;
        @AuraEnabled public String submittedBy;
        @AuraEnabled public Date submittedDate;
        @AuraEnabled public String project;
        @AuraEnabled public String status;
    }
    
    @AuraEnabled
    public static List<SubmittedRecordsWrapper> getSubmittedEAHIRecords(){
        List<SubmittedRecordsWrapper> submittedRecsWrapperList = new List<SubmittedRecordsWrapper>();
        try{
            //Get the queue id to which the logged in user is part of.
            Set<Id> queueIdSet = PaymentEAHIRecsApprovalActionHelper.getQueueIdsForLoggedInUser();
            //Get the processInstance(EAHI object) records for the Queues/Logged in user
            List<ProcessInstance> processInstanceList = PaymentEAHIRecsApprovalActionHelper.getApprovalProcessInstanceList(queueIdSet,PaymentEAHIApprovalCtrlConstant.OBJECT_EAHI);
            
            //Get the EAHI record ids
            Set<String> EAHIIdSet = new Set<String>(); 
            for(ProcessInstance item: processInstanceList)
                EAHIIdSet.add(item.TargetObjectId);
            //Create EAHI record id and Record Map
            Map<Id, usopc_EAHI_Allocation__c> EAHIAndProjectIdMap = PaymentEAHIRecsApprovalActionHelper.getIdAndEAHIRecMap(EAHIIdSet);
            System.debug(EAHIAndProjectIdMap);
            //Create wrapper records to be displayed to the user for approval/rejection
            submittedRecsWrapperList = getWrapperRecordsTobeDisplayed(processInstanceList,EAHIAndProjectIdMap);
        }catch(Exception e){
            System.debug('System Exception in getSubmittedEAHIRecords(): ' + e.getTypeName());
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
            PaymentEAHIRecsApprovalActionHelper.processWorkItemRecs(submittedWorkItemList,processType);
        }catch(Exception e){
            System.debug('System Exception in processRecords(): ' + e.getTypeName());
            System.debug(e.getMessage());
            System.debug(e.getStackTraceString());
            throw new AuraHandledException('System Exception occurred - '+e.getMessage());   
        }
        
        return PaymentEAHIApprovalCtrlConstant.STRING_SUCCESS;
    }
    
    public static List<SubmittedRecordsWrapper> getWrapperRecordsTobeDisplayed(List<ProcessInstance> processInstanceList,Map<Id, usopc_EAHI_Allocation__c> EAHIAndProjectIdMap){
        List<SubmittedRecordsWrapper> submittedRecsWrapperList = new List<SubmittedRecordsWrapper>();
        for(ProcessInstance ps : processInstanceList){
            if(!ps.WorkItems.isEmpty()){
                SubmittedRecordsWrapper objSubmittedRecordsWrapper = new SubmittedRecordsWrapper();
                objSubmittedRecordsWrapper.workItemId = ps.WorkItems[0].Id;
                objSubmittedRecordsWrapper.recordId = ps.TargetObjectId;
                objSubmittedRecordsWrapper.recordName = ps.TargetObject.Name;
                objSubmittedRecordsWrapper.recordNameDesc = EAHIAndProjectIdMap.get(objSubmittedRecordsWrapper.recordId).usopc_EAHI_Allocation_Name__c;
                objSubmittedRecordsWrapper.project = EAHIAndProjectIdMap.get(objSubmittedRecordsWrapper.recordId).usopc_Project__r.Name;
                objSubmittedRecordsWrapper.status = EAHIAndProjectIdMap.get(objSubmittedRecordsWrapper.recordId).usopc_Status__c;
                objSubmittedRecordsWrapper.submittedDate = Date.newInstance(ps.CreatedDate.year(),ps.CreatedDate.month(),ps.CreatedDate.day());
                if(!ps.steps.isEmpty())
                    objSubmittedRecordsWrapper.submittedBy = ps.steps[0].OriginalActor.Name;
                submittedRecsWrapperList.add(objSubmittedRecordsWrapper);
            }
        }
        return submittedRecsWrapperList;
    }
}