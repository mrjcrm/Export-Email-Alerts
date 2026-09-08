/**
 * Deletes all WorkflowAlert records in the org via the Tooling API.
 *
 * WorkflowAlert is a metadata entity — it cannot be removed via standard Apex DML.
 * This batch queries all IDs in start(), then issues a Tooling API DELETE per record
 * in execute(). Batch size of 1 is recommended to stay within callout limits per transaction.
 *
 * Run via anonymous Apex:
 *   Database.executeBatch(new BATCH_DeleteWorkflowAlerts(), 1);
 */
public with sharing class BATCH_DeleteWorkflowAlerts
    implements Database.Batchable<String>, Database.Stateful, Database.AllowsCallouts {

    private static final String TOOLING_API_VER = 'v67.0';
    private static final String SFDC_URL = Url.getOrgDomainURL().toExternalForm();
    private static final String QUERY_ALL_WORKFLOW_ALERTS = 'Select+id+from+WorkflowAlert';

    public Integer totalDeleted = 0;
    public Integer totalErrors = 0;
    public String errorLog = '';

    public virtual class ToolingApiException extends Exception {}

    // -----------------------------------------------------------------------
    // Batchable interface
    // -----------------------------------------------------------------------

    /**
     * Queries all WorkflowAlert IDs via the Tooling API and returns them as the batch scope.
     *
     * @param bc Batch context provided by the platform
     * @return Iterable list of WorkflowAlert IDs
     */
    public Iterable<String> start(Database.BatchableContext bc) {
        List<String> alertIds = new List<String>();
        try {
            HttpRequest req = buildRequest('GET', SFDC_URL + '/services/data/' + TOOLING_API_VER
                + '/tooling/query?q=' + QUERY_ALL_WORKFLOW_ALERTS);
            HttpResponse res = new Http().send(req);
            validateResponse(res, 'start/query');
            alertIds = parseIds(res.getBody());
        } catch (Exception e) {
            totalErrors++;
            errorLog += '\n[start] ' + e.getMessage() + ' | line=' + e.getLineNumber();
            System.abortJob(bc.getJobId());
            finish(bc);
        }
        return alertIds;
    }

    /**
     * Deletes each WorkflowAlert ID in the current batch scope via the Tooling API DELETE endpoint.
     *
     * @param bc    Batch context provided by the platform
     * @param scope List of WorkflowAlert IDs to delete in this chunk
     */
    public void execute(Database.BatchableContext bc, List<String> scope) {
        for (String alertId : scope) {
            try {
                HttpRequest req = buildRequest('DELETE', SFDC_URL + '/services/data/' + TOOLING_API_VER
                    + '/tooling/sobjects/WorkflowAlert/' + alertId);
                HttpResponse res = new Http().send(req);
                validateResponse(res, 'execute/delete/' + alertId);
                totalDeleted++;
            } catch (Exception e) {
                totalErrors++;
                errorLog += '\n[execute] id=' + alertId + ' | ' + e.getMessage();
            }
        }
    }

    /**
     * Sends a completion email to the running user summarising deleted counts and any errors.
     *
     * @param bc Batch context provided by the platform
     */
    public void finish(Database.BatchableContext bc) {
        sendSummaryEmail();
    }

    // -----------------------------------------------------------------------
    // Private helpers
    // -----------------------------------------------------------------------

    private static HttpRequest buildRequest(String method, String endpoint) {
        HttpRequest req = new HttpRequest();
        req.setMethod(method);
        req.setEndpoint(endpoint);
        req.setHeader('Authorization', 'Bearer ' + UserInfo.getSessionId());
        req.setHeader('Content-Type', 'application/json');
        return req;
    }

    private static void validateResponse(HttpResponse res, String context) {
        if (res.getStatusCode() < 200 || res.getStatusCode() >= 300) {
            throw new ToolingApiException(
                'HTTP ' + res.getStatusCode() + ' ' + res.getStatus()
                + ' | context=' + context
                + ' | body=' + res.getBody()
            );
        }
    }

    private static List<String> parseIds(String responseBody) {
        List<String> ids = new List<String>();
        JSONParser parser = JSON.createParser(responseBody);
        while (parser.nextToken() != null) {
            if (parser.getCurrentToken() == JSONToken.FIELD_NAME && parser.getText() == 'Id') {
                parser.nextToken();
                ids.add(parser.getText());
            }
        }
        return ids;
    }

    private void sendSummaryEmail() {
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(new List<String>{ UserInfo.getUserEmail() });
        mail.setReplyTo('noreply@salesforce.com');
        mail.setSenderDisplayName('BATCH_DeleteWorkflowAlerts');

        if (totalErrors > 0) {
            mail.setSubject('Delete WorkflowAlerts: completed with ' + totalErrors + ' error(s)');
        } else {
            mail.setSubject('Delete WorkflowAlerts: completed successfully');
        }

        mail.setPlainTextBody(
            'Org: ' + UserInfo.getOrganizationName()
            + '\nDeleted: ' + totalDeleted
            + '\nErrors: ' + totalErrors
            + (String.isBlank(errorLog) ? '' : '\n\nError details:' + errorLog)
        );

        Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail });
    }
}
