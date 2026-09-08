/**
 * Test class for FlowEmailAlertSelector.
 */
@isTest
private class FlowEmailAlertSelectorTest {

    // -----------------------------------------------------------------------
    // Mock responses
    // -----------------------------------------------------------------------

    private static final String FLOW_ID_WITH_ALERT    = 'a005g00000ExampleAA1';
    private static final String FLOW_ID_WITHOUT_ALERT = 'a005g00000ExampleAA2';

    private static final String QUERY_RESPONSE = JSON.serialize(new Map<String, Object>{
        'size' => 2,
        'done' => true,
        'records' => new List<Object>{
            new Map<String, Object>{
                'Id'           => FLOW_ID_WITH_ALERT,
                'MasterLabel'  => 'Send Welcome Email Flow',
                'FullName'     => 'Send_Welcome_Email_Flow',
                'Status'       => 'Active',
                'ApiVersion'   => 67.0
            },
            new Map<String, Object>{
                'Id'           => FLOW_ID_WITHOUT_ALERT,
                'MasterLabel'  => 'Account Update Flow',
                'FullName'     => 'Account_Update_Flow',
                'Status'       => 'Active',
                'ApiVersion'   => 67.0
            }
        }
    });

    private static final String METADATA_WITH_ALERT = JSON.serialize(new Map<String, Object>{
        'Id'       => FLOW_ID_WITH_ALERT,
        'Metadata' => new Map<String, Object>{
            'label'        => 'Send Welcome Email Flow',
            'actionCalls'  => new List<Object>{
                new Map<String, Object>{
                    'name'       => 'Send_Email',
                    'label'      => 'Send Email',
                    'actionType' => 'emailSimple',
                    'actionName' => 'emailSimple'
                }
            }
        }
    });

    private static final String METADATA_WITHOUT_ALERT = JSON.serialize(new Map<String, Object>{
        'Id'       => FLOW_ID_WITHOUT_ALERT,
        'Metadata' => new Map<String, Object>{
            'label'       => 'Account Update Flow',
            'actionCalls' => new List<Object>{
                new Map<String, Object>{
                    'name'       => 'Update_Record',
                    'label'      => 'Update Record',
                    'actionType' => 'recordUpdate',
                    'actionName' => 'Account'
                }
            }
        }
    });

    // -----------------------------------------------------------------------
    // Multi-request mock
    // -----------------------------------------------------------------------

    private class ToolingApiMock implements HttpCalloutMock {

        private Map<String, String> responsesByEndpointFragment;

        public ToolingApiMock(Map<String, String> responsesByEndpointFragment) {
            this.responsesByEndpointFragment = responsesByEndpointFragment;
        }

        public HTTPResponse respond(HTTPRequest req) {
            String endpoint = req.getEndpoint();
            for (String fragment : responsesByEndpointFragment.keySet()) {
                if (endpoint.contains(fragment)) {
                    HttpResponse res = new HttpResponse();
                    res.setStatusCode(200);
                    res.setHeader('Content-Type', 'application/json');
                    res.setBody(responsesByEndpointFragment.get(fragment));
                    return res;
                }
            }
            HttpResponse notFound = new HttpResponse();
            notFound.setStatusCode(404);
            notFound.setBody('{"message":"Not found","errorCode":"NOT_FOUND"}');
            return notFound;
        }
    }

    private class ErrorMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(401);
            res.setBody('{"message":"Unauthorized","errorCode":"INVALID_SESSION_ID"}');
            return res;
        }
    }

    // -----------------------------------------------------------------------
    // Tests — getFlowsWithEmailAlerts
    // -----------------------------------------------------------------------

    @isTest
    static void getFlowsWithEmailAlerts_ReturnsOnlyFlowsContainingEmailSimple() {
        // Given
        Map<String, String> responses = new Map<String, String>{
            'tooling/query'                        => QUERY_RESPONSE,
            'sobjects/Flow/' + FLOW_ID_WITH_ALERT  => METADATA_WITH_ALERT,
            'sobjects/Flow/' + FLOW_ID_WITHOUT_ALERT => METADATA_WITHOUT_ALERT
        };
        Test.setMock(HttpCalloutMock.class, new ToolingApiMock(responses));

        // When
        Test.startTest();
        List<FlowEmailAlertSelector.FlowResult> results =
            FlowEmailAlertSelector.getFlowsWithEmailAlerts();
        Test.stopTest();

        // Then
        Assert.areEqual(1, results.size(), 'Only one flow should contain emailSimple');
        Assert.areEqual(FLOW_ID_WITH_ALERT, results[0].id,
            'Returned flow id should match the flow with an emailSimple action');
        Assert.areEqual('Send_Welcome_Email_Flow', results[0].developerName,
            'Developer name should match');
        Assert.areEqual('Send Welcome Email Flow', results[0].label, 'Label should match');
        Assert.areEqual('Active', results[0].status, 'Status should match');
    }

    @isTest
    static void getFlowsWithEmailAlerts_ReturnsEmptyList_WhenNoFlowsExist() {
        // Given — query returns no records
        String emptyResponse = JSON.serialize(new Map<String, Object>{
            'size' => 0,
            'done' => true,
            'records' => new List<Object>()
        });
        Test.setMock(HttpCalloutMock.class, new ToolingApiMock(
            new Map<String, String>{ 'tooling/query' => emptyResponse }
        ));

        // When
        Test.startTest();
        List<FlowEmailAlertSelector.FlowResult> results =
            FlowEmailAlertSelector.getFlowsWithEmailAlerts();
        Test.stopTest();

        // Then
        Assert.areEqual(0, results.size(), 'Should return empty list when no flows exist');
    }

    @isTest
    static void getFlowsWithEmailAlerts_ReturnsEmptyList_WhenQueryFails() {
        // Given — Tooling API returns 401
        Test.setMock(HttpCalloutMock.class, new ErrorMock());

        // When
        Test.startTest();
        List<FlowEmailAlertSelector.FlowResult> results =
            FlowEmailAlertSelector.getFlowsWithEmailAlerts();
        Test.stopTest();

        // Then — no exception propagated; error is logged and empty list returned
        Assert.areEqual(0, results.size(),
            'Should return empty list on Tooling API error');
    }

    @isTest
    static void getFlowsWithEmailAlerts_ReturnsEmptyList_WhenAllFlowsLackEmailSimple() {
        // Given — both flows have no emailSimple actions
        String metadataNoActions = JSON.serialize(new Map<String, Object>{
            'Id'       => FLOW_ID_WITH_ALERT,
            'Metadata' => new Map<String, Object>{ 'label' => 'Flow Without Actions' }
        });
        Map<String, String> responses = new Map<String, String>{
            'tooling/query'                        => QUERY_RESPONSE,
            'sobjects/Flow/' + FLOW_ID_WITH_ALERT  => metadataNoActions,
            'sobjects/Flow/' + FLOW_ID_WITHOUT_ALERT => METADATA_WITHOUT_ALERT
        };
        Test.setMock(HttpCalloutMock.class, new ToolingApiMock(responses));

        // When
        Test.startTest();
        List<FlowEmailAlertSelector.FlowResult> results =
            FlowEmailAlertSelector.getFlowsWithEmailAlerts();
        Test.stopTest();

        // Then
        Assert.areEqual(0, results.size(),
            'Should return empty list when no flows have emailSimple actions');
    }

    // -----------------------------------------------------------------------
    // Tests — metadataContainsEmailAlert (unit tested directly via @TestVisible)
    // -----------------------------------------------------------------------

    @isTest
    static void metadataContainsEmailAlert_ReturnsTrue_WhenSingleEmailSimpleActionCall() {
        // Given
        Map<String, Object> metadata = new Map<String, Object>{
            'actionCalls' => new Map<String, Object>{
                'actionType' => 'emailSimple',
                'name'       => 'MyEmailAction'
            }
        };

        // When / Then
        Assert.isTrue(
            FlowEmailAlertSelector.metadataContainsEmailAlert(metadata),
            'Should return true for a single emailSimple actionCall (map form)'
        );
    }

    @isTest
    static void metadataContainsEmailAlert_ReturnsTrue_WhenListContainsEmailSimple() {
        // Given
        Map<String, Object> metadata = new Map<String, Object>{
            'actionCalls' => new List<Object>{
                new Map<String, Object>{ 'actionType' => 'recordUpdate', 'name' => 'UpRec' },
                new Map<String, Object>{ 'actionType' => 'emailSimple',  'name' => 'SendEmail' }
            }
        };

        // When / Then
        Assert.isTrue(
            FlowEmailAlertSelector.metadataContainsEmailAlert(metadata),
            'Should return true when list contains at least one emailSimple action'
        );
    }

    @isTest
    static void metadataContainsEmailAlert_ReturnsFalse_WhenNoEmailSimplePresent() {
        // Given
        Map<String, Object> metadata = new Map<String, Object>{
            'actionCalls' => new List<Object>{
                new Map<String, Object>{ 'actionType' => 'recordUpdate', 'name' => 'UpRec' }
            }
        };

        // When / Then
        Assert.isFalse(
            FlowEmailAlertSelector.metadataContainsEmailAlert(metadata),
            'Should return false when no emailSimple action is present'
        );
    }

    @isTest
    static void metadataContainsEmailAlert_ReturnsFalse_WhenActionCallsIsNull() {
        // Given
        Map<String, Object> metadata = new Map<String, Object>{ 'label' => 'Flow No Actions' };

        // When / Then
        Assert.isFalse(
            FlowEmailAlertSelector.metadataContainsEmailAlert(metadata),
            'Should return false when actionCalls key is absent'
        );
    }

    @isTest
    static void metadataContainsEmailAlert_ReturnsTrue_WhenActionTypeIsMixedCase() {
        // Given — verify case-insensitive comparison
        Map<String, Object> metadata = new Map<String, Object>{
            'actionCalls' => new List<Object>{
                new Map<String, Object>{ 'actionType' => 'EmailSimple', 'name' => 'EA' }
            }
        };

        // When / Then
        Assert.isTrue(
            FlowEmailAlertSelector.metadataContainsEmailAlert(metadata),
            'Should return true regardless of actionType casing'
        );
    }
}
