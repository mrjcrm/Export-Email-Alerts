/**
 * Fetches all Flow versions that contain at least one action call
 * with actionType = "emailSimple" via the Tooling API.
 *
 * Run via anonymous Apex:
List<tempFlowEmailAlertSelector.FlowResult> results = tempFlowEmailAlertSelector.getFlowsWithEmailAlerts();
for (tempFlowEmailAlertSelector.FlowResult r : results) {
    System.debug(r.developerName + ' (' + r.label + ') — status: ' + r.status);
}
**/
public with sharing class tempFlowEmailAlertSelector {

    private static final String TOOLING_API_VER    = 'v67.0';
    private static final String SFDC_URL            = Url.getOrgDomainURL().toExternalForm();
    private static final String ACTION_TYPE_FILTER  = 'emailSimple';

    // -----------------------------------------------------------------------
    // Result DTO
    // -----------------------------------------------------------------------

    /**
     * Lightweight result record returned for each matching Flow.
     */
    public class FlowResult {
        /** Tooling API record Id of the Flow version. */
        public String id;
        /** API/developer name of the Flow. */
        public String developerName;
        /** User-visible label of the Flow. */
        public String label;
        /** Activation status, e.g. "Active", "Draft", "Obsolete". */
        public String status;
        /** API version the Flow was last saved against. */
        public Decimal apiVersion;
    }

    // -----------------------------------------------------------------------
    // Public API
    // -----------------------------------------------------------------------

    /**
     * Returns all Flow versions that contain at least one Send Email action
     * (actionType = "emailSimple").
     *
     * Queries the Tooling API in two steps:
     *   1. Retrieve all Flow versions (Id, MasterLabel, FullName, VersionNumber, Status, ApiVersion).
     *   2. Fetch the Metadata field for each version and inspect actionCalls.
     *
     * @return List of FlowResult DTOs; empty list when none are found or on error.
     * @example
     * List<FlowEmailAlertSelector.FlowResult> flows =
     *     FlowEmailAlertSelector.getFlowsWithEmailAlerts();
     */
    public static List<FlowResult> getFlowsWithEmailAlerts() {
        List<Map<String, Object>> allVersions = queryAllFlowVersions();
        if (allVersions.isEmpty()) {
            return new List<FlowResult>();
        }

        List<FlowResult> matching = new List<FlowResult>();
        for (Map<String, Object> version : allVersions) {
            String flowId = (String) version.get('Id');
            if (String.isBlank(flowId)) {
                continue;
            }
            if (flowVersionHasEmailAlert(flowId)) {
                FlowResult result  = new FlowResult();
                result.id          = flowId;
                result.developerName = (String) version.get('FullName');
                result.label       = (String) version.get('MasterLabel');
                result.status      = (String) version.get('Status');
                result.apiVersion  = version.get('ApiVersion') != null
                    ? Decimal.valueOf(String.valueOf(version.get('ApiVersion')))
                    : null;
                matching.add(result);
            }
        }
        return matching;
    }

    // -----------------------------------------------------------------------
    // Private helpers
    // -----------------------------------------------------------------------

    /**
     * Queries all Flow versions from the Tooling API.
     * Returns a list of raw record maps; empty on error.
     */
    private static List<Map<String, Object>> queryAllFlowVersions() {
        String soql = 'SELECT+Id,MasterLabel,FullName,Status,ApiVersion+FROM+Flow+limit+1';
        String endpoint = SFDC_URL + '/services/data/' + TOOLING_API_VER
            + '/tooling/query?q=' + soql;

        try {
            HttpResponse res = sendRequest('GET', endpoint);
            Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            List<Object> records = (List<Object>) body.get('records');
            if (records == null) {
                return new List<Map<String, Object>>();
            }
            List<Map<String, Object>> versions = new List<Map<String, Object>>();
            for (Object rec : records) {
                versions.add((Map<String, Object>) rec);
            }
            return versions;
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR,
                'FlowEmailAlertSelector.queryAllFlowVersions error: ' + e.getMessage());
            return new List<Map<String, Object>>();
        }
    }

    /**
     * Fetches the Metadata field for a single Flow version and returns true
     * when at least one actionCalls entry has actionType = "emailSimple".
     *
     * @param flowId Tooling API Id of the Flow version record
     * @return true if an emailSimple actionCall is found; false otherwise
     */
    private static Boolean flowVersionHasEmailAlert(String flowId) {
        String endpoint = SFDC_URL + '/services/data/' + TOOLING_API_VER
            + '/tooling/sobjects/Flow/' + flowId + '?fields=Metadata';

        try {
            HttpResponse res = sendRequest('GET', endpoint);
            Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            Map<String, Object> metadata = (Map<String, Object>) body.get('Metadata');
            if (metadata == null) {
                return false;
            }
            return metadataContainsEmailAlert(metadata);
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR,
                'FlowEmailAlertSelector.flowVersionHasEmailAlert error for ' + flowId
                + ': ' + e.getMessage());
            return false;
        }
    }

    /**
     * Inspects the deserialized Metadata map for actionCalls entries
     * whose actionType matches "emailSimple" (case-insensitive).
     *
     * @param metadata Deserialized Metadata JSON map from the Tooling API response
     * @return true if any matching actionCall is found
     */
    @TestVisible
    private static Boolean metadataContainsEmailAlert(Map<String, Object> metadata) {
        Object actionCallsRaw = metadata.get('actionCalls');
        if (actionCallsRaw == null) {
            return false;
        }

        // actionCalls can be a single Map (one element) or a List (multiple elements)
        List<Object> actionCallsList;
        if (actionCallsRaw instanceof List<Object>) {
            actionCallsList = (List<Object>) actionCallsRaw;
        } else {
            actionCallsList = new List<Object>{ actionCallsRaw };
        }

        for (Object raw : actionCallsList) {
            Map<String, Object> actionCall = (Map<String, Object>) raw;
            String actionType = (String) actionCall.get('actionType');
            if (ACTION_TYPE_FILTER.equalsIgnoreCase(actionType)) {
                return true;
            }
        }
        return false;
    }

    /**
     * Sends an authenticated GET request to the Tooling API and validates the response.
     *
     * @param method   HTTP method (e.g. "GET")
     * @param endpoint Full URL to call
     * @return HttpResponse on success
     * @throws FlowSelectorException on non-2xx status code
     */
    private static HttpResponse sendRequest(String method, String endpoint) {
        HttpRequest req = new HttpRequest();
        req.setMethod(method);
        req.setEndpoint(endpoint);
        req.setHeader('Authorization', 'Bearer ' + UserInfo.getSessionId());
        req.setHeader('Content-Type', 'application/json');

        HttpResponse res = new Http().send(req);
        if (res.getStatusCode() < 200 || res.getStatusCode() >= 300) {
            throw new FlowSelectorException(
                'HTTP ' + res.getStatusCode() + ' ' + res.getStatus()
                + ' | endpoint=' + endpoint
                + ' | body=' + res.getBody()
            );
        }
        return res;
    }

    // -----------------------------------------------------------------------
    // Exception
    // -----------------------------------------------------------------------

    /** Thrown when the Tooling API returns a non-2xx response. */
    public class FlowSelectorException extends Exception {}
}
