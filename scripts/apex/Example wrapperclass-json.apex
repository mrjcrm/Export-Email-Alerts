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

String jsonInput = '{  "attributes" : {    "type" : "WorkflowAlert",    "url" : "servicesdatav56.0toolingsobjectsWorkflowAlert01W3c000000gDu2EAE"  },  "Id" : "01W3c000000gDu2EAE",  "TemplateId" : "00X80000001ExRoEAK",  "CcEmails" : "a@a.com,b@b.com",  "Description" : "aTest9",  "DeveloperName" : "aTest9",  "SenderType" : "CurrentUser",  "ManageableState" : "unmanaged",  "NamespacePrefix" : null,  "CreatedDate" : "2023-02-23T21:03:21.000+0000",  "CreatedById" : "00580000001hjv1AAA",  "LastModifiedDate" : "2023-03-09T16:56:17.000+0000",  "LastModifiedById" : "00580000001hjv1AAA",  "EntityDefinitionId" : "Account",  "Metadata" : {    "ccEmails" : [ "a@a.com,b@b.com" ],    "description" : "aTest9",    "protected" : false,    "recipients" : [ {      "field" : null,      "recipient" : "junkyard@yahoo.com",      "type" : "user"    }, {      "field" : null,      "recipient" : "mr.jcrm@gmail.com",      "type" : "user"    } ],    "senderAddress" : null,    "senderType" : "CurrentUser",    "template" : "unfiledp$?/ublicSalesNewCustomerEmail",    "urls" : null  },  "FullName" : "Account.aTest9"}';

WorkflowAlert w = (WorkflowAlert)JSON.deserialize(jsonInput, WorkflowAlert.class);
system.debug('---------------------------------------------------------------------------------');
system.debug('id=' + w.id + ' ccemails=' + w.ccemails + ' desc=' + w.Description + ' type=' + w.attributes.type);
system.debug('recip0=' + w.metadata.recipients[0].recipient + ' type=' + w.metadata.recipients[0].type);