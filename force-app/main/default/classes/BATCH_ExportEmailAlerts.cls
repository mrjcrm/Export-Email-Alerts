//---------------------------------------------------------
// Export Email Alerts
//---------------------------------------------------------

//---------------------------------------------------------
// Purpose: Export all email alerts and active flow email actions to a CSV and email it to current user
// Strategy: Use Tooling API to read WorkflowAlerts and Flows
// Strategy: Use batch Apex to handle large volumes
// Read-only. No updates made to Salesforce data
// Author: Rod MacKenzie mr.jcrm@gmail.com
// How to install and run (admin privileges are required)
// - See GitHub repository "ExportSFDCAlerts" for details
// - Or, if you're comfortable with anonymous apex, deploy the classes and run Database.executeBatch(new BATCH_ExportEmailAlerts(),1); 
//---------------------------------------------------------

//---------------------------------------------------------
public with sharing class BATCH_ExportEmailAlerts implements Database.Batchable<String>, Database.Stateful, Database.AllowsCallouts  {
//---------------------------------------------------------

// Constants
static final string TOOLINGAPIVER = 'v57.0';
static final string DEVELOPER_EMAIL = 'exportsfdcalerts@gmail.com';
static final string APPNAME = 'ExportSFDCAlerts';
static final string SFDC_URL = Url.getSalesforceBaseUrl().toExternalForm(); 
  
//---------------------------------------------------------
@InvocableMethod(label='Export Email Alerts') public static void exportEmailAlerts() {
//---------------------------------------------------------
// This method makes the class available as an Apex Action in flow builder
Database.executeBatch(new BATCH_ExportEmailAlerts(),1); // Use batchsize=1 to be on the safe side.
} // end method
  
  // Vars for all batch jobs
  public string errorString= ''; // List of errors encountered by this job.
  integer totalErrors = 0;
        
  // Vars for this app
  
  // Exception variables
  public virtual class BadHTTPStatus_Exception extends Exception {}
    
  public string alertCSV = '';
  static final string query_start_workflowalert = 'Select+id+from+workflowalert';
  static final string query_start_flow = 'Select+id+from+flow+where+status=\'active\'+and+processtype=\'flow\'';
  public final string CSVHeading =
    '"Email",' +
    '"Alert name",' + // Email alert name, or Flow name + "/" + // Alert name
    '"Alert type",' + // "Flow email action" or "Email alert"
    '"SF user name",' + // First Name + Last Name (applies only to SFDC users) ????
    '"SF user status",' + // SFDC user active or inactive    
    '"Note",' + // Group, Role, Role-Sub, User, CcEmail  
    '"More",' + // SFDC_URL/01W... (WorkflowAlert), or SFDC_URL/301... (Flow)
    '\n'; 
  
  //--------------------------------------------------------------------
  // These static variables can be examined by a test class to verify the app works correctly.
  //--------------------------------------------------------------------
  @TestVisible static string copyOfAlertCSV=''; 
  
  //---------------------------------------------------------
  public BATCH_ExportEmailAlerts() { // Constructor
  //---------------------------------------------------------
  alertCSV = CSVHeading; // Initialize CSV
  } // end method
  
  //---------------------------------------------------------
  public Iterable<String> start(Database.BatchableContext BC) {
  //---------------------------------------------------------
  list<string> alertIds = new list<string>();  
  try {
  HttpRequest req = new HttpRequest();
  Http h = new Http();
  HttpResponse res;
  req.setHeader('Authorization', 'Bearer ' + UserInfo.getSessionID());
  req.setHeader('Content-Type', 'application/json');
  req.setMethod('GET'); 

  // Get WorkflowAlert ids using Tooling API
  req.setEndpoint(SFDC_URL + '/services/data/'+ TOOLINGAPIVER + '/tooling/query?q=' + query_start_workflowalert);
  getAlertIds (h, req, res, alertIds, 'WorkflowAlert');
  
  // Get Flow ids using REST/Tooling API
  req.setEndpoint(SFDC_URL + '/services/data/'+ TOOLINGAPIVER + '/tooling/query?q=' + query_start_flow);
  getAlertIds (h, req, res, alertIds,'Flow');

  return alertIds; // Return list of alert Ids.
  } // end try
   
  catch (exception e) {
    totalErrors++; errorString = '\n' + errorString + 'msg=' + e.getMessage() + ', line=' + e.getLineNumber()  + ', stacktrace=' + e.getStackTraceString();
    System.abortJob(BC.getJobId());
    finish(BC);
  } // end catch
  
  return alertIds;  
  } // end method
  
  //---------------------------------------------------------
  private void getAlertIds (Http h, HttpRequest req, HttpResponse res, list<string> alertIds, string recType) {
  //---------------------------------------------------------
  res = h.send(req);
  if (res.getStatus() != 'ok') { 
    throw new BadHTTPStatus_Exception ('method:GetAlertIds, rectype:' + recType + ', HTTP status:' + res.getStatus());
  }
  else {
    JSONParser parser = JSON.createParser(res.getBody());
    while (parser.nextToken() != null) {
      if ((parser.getCurrentToken() == JSONToken.FIELD_NAME) && (parser.getText() == 'Id')) {
        parser.nextToken(); // Get the Id.
        alertIds.add(parser.getText()); // Add the Id to a list.
      } // end if
    } // end while
  } // end if
  } // end method
  
  //---------------------------------------------------------
  public void execute(Database.BatchableContext BC, list<String> scope) {
  //---------------------------------------------------------
  HttpRequest req = new HttpRequest();
  Http h = new Http();
  HttpResponse res;
  req.setHeader('Authorization', 'Bearer ' + UserInfo.getSessionID());
  req.setHeader('Content-Type', 'application/json');
  req.setMethod('GET'); 

  for(Integer x = 0; x < scope.size(); x++) {

    if (scope[x].left(3) == '01W') { // 01W rec prefix = workflowalert
      req.setEndpoint(SFDC_URL + '/services/data/'+ TOOLINGAPIVER + '/tooling/sobjects/WorkflowAlert/' + scope[x]);
      res = h.send(req);
      addToSpreadsheet_WorkflowAlert(res);
    } 
    else if (scope[x].left(3) == '301') { // 301 rec prefix = flow)
      req.setEndpoint(SFDC_URL + '/services/data/'+ TOOLINGAPIVER + '/tooling/sobjects/Flow/' + scope[x]);
      res = h.send(req);
      addToSpreadsheet_Flow(res);
    } // end if 
  } // end for

  //debugging info
  //system.debug ('glixl-a: availableHeap=' + String.valueOf(Limits.getLimitHeapSize().format()) + ', usedHeap=' + String.valueOf(Limits.getHeapSize().format()));

  } // end method

  //----------------------------------------------------------
  public void finish(Database.BatchableContext BC) {
  //---------------------------------------------------------
  copyOfAlertCSV = alertCSV; // Enables copy of CSV to be passed to test class
  emailJobResult (BC);
  } // end method
  
  //---------------------------------------------------------
  public void addToSpreadsheet_WorkflowAlert(HttpResponse res) {
  //---------------------------------------------------------
  WorkflowAlert w = (WorkflowAlert)JSON.deserialize(res.getBody(), WorkflowAlert.class);
  
  list<user> userList;
  
  // CcEmails -----------------------------------------------
  if (w.CcEmails != null) { 
    list<string> ccEmailList = new list<string>(w.CcEmails.split(','));
    for (integer x=0; x < ccEmailList.size(); x++) {
      alertCSV = alertCSV + 
        '"' + ccEmailList[x] + '",' +
        '"' + w.Description + '",' +
        '"Email alert",' + // '"' + w.attributes.type + '",' + 
        '" ",' + // CSV: SF user name
        '" ",' + // CSV: SF user status
        '"' + 'Additional email' + '",' + // CSV: Note
        '"' + SFDC_URL + '/' + w.id + '",' +      
        '\n';
    }
  }
  
  // Recipients (Group, Role, RoleSubordinate, User) --------
  
  if (w.metadata.recipients.size() > 0) {
    for (integer x=0; x < w.metadata.recipients.size(); x++) {
     switch on w.Metadata.recipients[x].type {
  
      // Group  ----------------------------------------------
        when 'group' {
          userList = getUserList_Group(w.Metadata.recipients[x].recipient);
          writeRecipientCSV(w, x, userList);
        }
        
        // Role ---------------------------------------------
        when 'role' {
          userList = getUserList_Role(w.Metadata.recipients[x].recipient); // same as user.role.developername
          writeRecipientCSV(w, x, userList);
        }
  
        // Role & Subordinates ------------------------------      
        when 'roleSubordinates' {
          // Too bad we have to consume an SOQL query just to get the UserRole id.
          list<UserRole> roleList = new list<UserRole> ([SELECT Id FROM UserRole WHERE developerName = :w.Metadata.recipients[x].recipient]);
          writeRecipientCSV(w, x, getUsersUnderRole(roleList[0].Id));
        }
        
        // User ----------------------------------------------
        when 'user' {
          userList = getUserList_User(w.Metadata.recipients[x].recipient);
          writeRecipientCSV(w, x, userList);
        }
      } // end switch
  
    }
  }
  
  } // end method
  
  //---------------------------------------------------------
  private list<user> getUserList_Group (string groupName) {
  //---------------------------------------------------------
  list<user> userList = new list <user>();
  list<group> groupId = new list<group> ([SELECT Id FROM Group WHERE DeveloperName = :groupName LIMIT 1]);
  if (groupId.size() > 0) {
    id groupid0 = groupId[0].id;
    list<GroupMember> groupMembers = new list<groupmember> ([SELECT UserOrGroupId FROM groupmember WHERE GroupId = :groupid0]);
    list<id> groupmemZ = new list<id>();
    for (integer x=0; x < groupMembers.size(); x++) {
      groupmemZ.add(groupMembers[x].UserOrGroupId);  // Is there a better way than "groupmemZ?"
    }
    userList = [SELECT Id, Email, FirstName, LastName, IsActive FROM User WHERE Id in :groupmemZ];
  }
  return userList;
  } // end method
  
  //---------------------------------------------------------
  private list<user> getUserList_Role (string roleName) {
  //---------------------------------------------------------
  return [SELECT Id, Email, FirstName, LastName, IsActive FROM User WHERE UserRole.developerName = :roleName];
  } // end method
  
  //---------------------------------------------------------
  private list<user> getUserList_User (string emailAddress) {
  //---------------------------------------------------------
  return [SELECT Id, Email, FirstName, LastName, IsActive FROM User WHERE username = :emailAddress];
  } // end method

  /* glixl The method below is commented out until we decide whether to resolve contact/lead ids (from RecipientIDs in flow email actions) to actual email addresses
  //---------------------------------------------------------
  private string getObjectEmail (string objectId) {
  //---------------------------------------------------------
  if (objectId.left(3) == '003') { // Contact
    return [SELECT email FROM contact WHERE Id = :objectId LIMIT 1].Id;
  }
  else if (objectId.left(3) == '00Q') { // Lead
    return [SELECT email FROM Lead WHERE Id = :objectId LIMIT 1].Id;
  }
  // This app does not support person accounts
  //else if (objectId.left(3) == '001') { // Person account
  //  return [SELECT email FROM contact WHERE Id = :objectId LIMIT 1].Id;
  //}
  else {
    return null;
  }
  } // end method
  */

  //---------------------------------------------------------
  private void writeRecipientCSV (workFlowAlert w, integer whichRecip, list<user> userList) {
  //---------------------------------------------------------
  for (integer y=0; y < userList.size(); y++) {
    alertCSV = alertCSV + 
      '"' + userList[y].email + '",' + // CSV: Email
      '"' + w.Description + '",' + // CSV: Alert name
      '"Email alert",' + //'"' + w.attributes.type + '",' + // CSV: Alert type
      '"' + userList[y].firstName + ' ' + userList[y]. lastName + '",' + // CSV: SF user name
      '"' + (userList[y].isActive == true ? 'Active' : 'Inactive') + '",' + // CSV: SF user status
      '"' + 'sf ' + w.Metadata.recipients[whichRecip].type + '=' + w.Metadata.recipients[whichRecip].recipient + '",' + // CSV: Note
      '"' + SFDC_URL + '/' + w.id + '",' + // CSV: Alert URL
      '\n';
  }
  } // end method
  
  //---------------------------------------------------------
  public void addToSpreadsheet_Flow(HttpResponse res) {
  //---------------------------------------------------------
  Flow f = (Flow)JSON.deserialize(res.getBody(), Flow.class);
  // To be in the spreadsheet, the flow must have an "emailSimple" action.
  for (integer a=0; a < f.metadata.actionCalls.size(); a++) {
    if (f.metadata.actionCalls[a].actionType == 'emailSimple') {
      for (integer b=0; b < f.metadata.actionCalls[a].inputParameters.size(); b++) {
        if ((f.metadata.actionCalls[a].inputParameters[b].name == 'emailAddresses' || 
        // not supported f.metadata.actionCalls[a].inputParameters[b].name == 'emailAddressesArray' ||
        f.metadata.actionCalls[a].inputParameters[b].name == 'recipientId' ||
        f.metadata.actionCalls[a].inputParameters[b].name == 'bccRecipientAddressList' ||
        f.metadata.actionCalls[a].inputParameters[b].name == 'ccRecipientAddressList') &&
        (f.metadata.actionCalls[a].inputParameters[b].value.stringValue != null)) {
          list<string> emailList = new list<string>(f.metadata.actionCalls[a].inputParameters[b].value.stringValue.split(','));
          for (integer x=0; x < emailList.size(); x++) {
            alertCSV = alertCSV + 
            '"' + emailList[x] + '",' + // CSV: Email
            '"' + f.MasterLabel + '.' + f.Metadata.actionCalls[a].label + '",' + // CSV: Alert name
            '"Flow email action",' + //'"' + f.attributes.type + '",' + // CSV: Alert type
            '" ",' + // CSV: SF user name
            '" ",' + // CSV: SF user status
                        '" ",' + // CSV: Note
            '"' + SFDC_URL + '/' + f.id + '",' + // CSV: Alert URL
            '\n';
          }
        }
      }
    } // end if
  } // end for
  
  } // end method
        
  //---------------------------------------------------------
  public void emailJobResult(Database.BatchableContext BC) {
  //---------------------------------------------------------
  string subjectLine;
  Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
  integer csvRecs = alertCSV.split('\n').size() - 1; // Subtract 1 for header row.
  if (totalErrors > 0) {
    subjectLine = APPNAME + ': ' + totalErrors.format() + ' errors';
  }
  else if (csvRecs == 0) {
    subjectLine = 'No email alerts found';
  }
  else {
    subjectLine = 'List of email alerts';
    Messaging.EmailFileAttachment csvAttc = new Messaging.EmailFileAttachment();
    blob csvBlob = Blob.valueOf(alertCSV);
    string csvname= 'Email alerts.csv'; csvAttc.setFileName(csvname);
    csvAttc.setBody(csvBlob);
    mail.setFileAttachments(new Messaging.EmailFileAttachment[]{csvAttc});
  }
    
  String emailBody = 
  '\n' + 'Org: ' + UserInfo.getOrganizationName() + 
  '\n' + csvRecs.format() + ' csv records' +
  (totalErrors > 0 ? '\n' + totalErrors.format() + ' errors.' + errorString : '');

  mail.setSubject(subjectLine);
  Mail.setCharset('UTF-8');
  mail.setReplyTo('noreply@salesforce.com');
  mail.setSenderDisplayName(APPNAME);
  mail.setPlainTextBody(emailBody);
  mail.setToAddresses((UserInfo.getUserEmail() + ',' + DEVELOPER_EMAIL).split(','));
  Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });

  //debugging info
  //system.debug ('glixl-1: subject=' + subjectLine);
  //system.debug ('glixl-2: body=' + emailBody);
  } // end method

  //---------------------------------------------------------
  // Wrapper class for workFlowAlert sObject
  //---------------------------------------------------------
  public class WorkflowAlert {
    public wf_attributes attributes;
    public string Id;
    public wf_Metadata Metadata;
    public string CcEmails;
    public string Description;  
  }
  
  public class wf_attributes {
    public string type;
  }
  
  public class wf_Metadata {
    public list<wf_recipients> recipients;
  }
  
  public class wf_recipients {
    public string recipient;
    public string type;
  }
  

  //---------------------------------------------------------
  // Wrapper class for Flow sObject
  //---------------------------------------------------------
  public class Flow {
    public fl_attributes attributes;
    public string Id;
    public fl_Metadata Metadata;
    public string MasterLabel;
  }
  
  public class fl_attributes {
    public string type;
  }
  
  public class fl_Metadata {
    public list<fl_actionCalls> actionCalls;
  }
  
  public class fl_actionCalls {
    public string actionType; // "emailSimple"
    public list<fl_inputParameters> inputParameters;
    public string label;
  }
  
  public class fl_inputParameters {
    public string name; // "emailAddresses"
    public fl_value value; // was "public fl_value value;"
  }
  
  public class fl_value {
    public string stringValue; // "x@x.com,y@y.com"
  }
  
  //--------------------------------------------------------------------
  // Methods for getting role and subordinate users, for a specific role.
  // Thanks to Adrian Larson.
  // https://salesforce.stackexchange.com/questions/102733/find-users-under-a-node-in-role-hierarchy
  //--------------------------------------------------------------------
  
  //----------------------------------------------------------------------
  public static Map<Id, List<UserRole>> hierarchy {
  //----------------------------------------------------------------------
  get { // Is a get/set really required?
    if (hierarchy == null) {
      hierarchy = new Map<Id, List<UserRole>>();
      for (UserRole role : [SELECT ParentRoleId FROM UserRole]) {
        if (!hierarchy.containsKey(role.ParentRoleId)) {
          hierarchy.put(role.ParentRoleId, new List<UserRole>());
        }
        hierarchy.get(role.ParentRoleId).add(role);
      }
    }
    return hierarchy;
  } // end get
  private set;
  } // end method
  
  //----------------------------------------------------------------------
  public static List<UserRole> getChildren(Id userRoleId) {
  //----------------------------------------------------------------------
  return hierarchy.containsKey(userRoleId) ? hierarchy.get(userRoleId) : new List<UserRole>();
  } // end method
  
  //----------------------------------------------------------------------
  public static Set<Id> getSubHierarchyInclusive(Id userRoleId) {
  //----------------------------------------------------------------------
  Set<Id> roleIds = new Set<Id> { userRoleId };
  for (UserRole childRole : getChildren(userRoleId)) {
    roleIds.addAll(getSubHierarchyInclusive(childRole.Id));
  }
  return roleIds;
  } // end method
  
  //----------------------------------------------------------------------
  public static List<User> getUsersUnderRole(Id roleId) {
  //----------------------------------------------------------------------
  return [
    SELECT Id, Email, FirstName, LastName, IsActive 
    FROM User
    WHERE UserRoleId IN :getSubHierarchyInclusive(roleId)];
  } // end method
  
  //---------------------------------------------------------------------------
  // END OF methods for getting role and subordinate users, for a specific role
  //---------------------------------------------------------------------------

} // end class