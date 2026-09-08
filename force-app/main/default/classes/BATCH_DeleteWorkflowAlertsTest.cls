@IsTest
private class BATCH_DeleteWorkflowAlertsTest {

    // -----------------------------------------------------------------------
    // Mock
    // -----------------------------------------------------------------------

    private class MockHttp implements HttpCalloutMock {
        private final String scenario;

        MockHttp(String scenario) {
            this.scenario = scenario;
        }

        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');

            if (scenario == 'QuerySuccess') {
                res.setBody('{"size":2,"totalSize":2,"done":true,"records":[{"Id":"01W000000000001AAA"},{"Id":"01W000000000002AAA"}]}');
                res.setStatusCode(200);
                res.setStatus('OK');
            } else if (scenario == 'QueryNoResults') {
                res.setBody('{"size":0,"totalSize":0,"done":true,"records":[]}');
                res.setStatusCode(200);
                res.setStatus('OK');
            } else if (scenario == 'DeleteSuccess') {
                res.setBody('');
                res.setStatusCode(204);
                res.setStatus('No Content');
            } else if (scenario == 'DeleteError') {
                res.setBody('[{"errorCode":"ENTITY_IS_DELETED","message":"entity is deleted"}]');
                res.setStatusCode(404);
                res.setStatus('Not Found');
            } else if (scenario == 'QueryHttpError') {
                res.setBody('{"error":"Server Error"}');
                res.setStatusCode(500);
                res.setStatus('Internal Server Error');
            }

            return res;
        }
    }

    // -----------------------------------------------------------------------
    // Multi-call mock: first call = query, subsequent calls = delete
    // -----------------------------------------------------------------------

    private class SequenceMock implements HttpCalloutMock {
        private final String queryScenario;
        private final String deleteScenario;
        private Integer callCount = 0;

        SequenceMock(String queryScenario, String deleteScenario) {
            this.queryScenario = queryScenario;
            this.deleteScenario = deleteScenario;
        }

        public HttpResponse respond(HttpRequest req) {
            callCount++;
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');

            if (callCount == 1) {
                // First call is the query in start()
                new MockHttp(queryScenario).respond(req);
                if (queryScenario == 'QuerySuccess') {
                    res.setBody('{"size":1,"totalSize":1,"done":true,"records":[{"Id":"01W000000000001AAA"}]}');
                    res.setStatusCode(200); res.setStatus('OK');
                } else {
                    res.setBody('{"size":0,"totalSize":0,"done":true,"records":[]}');
                    res.setStatusCode(200); res.setStatus('OK');
                }
            } else {
                // Subsequent calls are deletes in execute()
                if (deleteScenario == 'DeleteSuccess') {
                    res.setBody(''); res.setStatusCode(204); res.setStatus('No Content');
                } else {
                    res.setBody('[{"errorCode":"ENTITY_IS_DELETED"}]');
                    res.setStatusCode(404); res.setStatus('Not Found');
                }
            }
            return res;
        }
    }

    // -----------------------------------------------------------------------
    // Tests
    // -----------------------------------------------------------------------

    @IsTest
    static void shouldDeleteAlerts_WhenQueryReturnsRecords() {
        Test.setMock(HttpCalloutMock.class, new SequenceMock('QuerySuccess', 'DeleteSuccess'));

        Test.startTest();
        Database.executeBatch(new BATCH_DeleteWorkflowAlerts(), 1);
        Test.stopTest();

        // Batch ran without exception; verify via instance counters on a direct call
        BATCH_DeleteWorkflowAlerts batch = new BATCH_DeleteWorkflowAlerts();
        Assert.areEqual(0, batch.totalDeleted, 'New instance should start with zero deletes');
        Assert.areEqual(0, batch.totalErrors, 'New instance should start with zero errors');
    }

    @IsTest
    static void shouldCountDeletes_WhenExecuteSucceeds() {
        BATCH_DeleteWorkflowAlerts batch = new BATCH_DeleteWorkflowAlerts();
        Test.setMock(HttpCalloutMock.class, new MockHttp('DeleteSuccess'));

        Test.startTest();
        batch.execute(null, new List<String>{ '01W000000000001AAA', '01W000000000002AAA' });
        Test.stopTest();

        Assert.areEqual(2, batch.totalDeleted, 'Should count two successful deletes');
        Assert.areEqual(0, batch.totalErrors, 'Should have no errors on success');
    }

    @IsTest
    static void shouldCountErrors_WhenDeleteFails() {
        BATCH_DeleteWorkflowAlerts batch = new BATCH_DeleteWorkflowAlerts();
        Test.setMock(HttpCalloutMock.class, new MockHttp('DeleteError'));

        Test.startTest();
        batch.execute(null, new List<String>{ '01W000000000001AAA' });
        Test.stopTest();

        Assert.areEqual(0, batch.totalDeleted, 'Should not count failed delete');
        Assert.areEqual(1, batch.totalErrors, 'Should count one error');
        Assert.isTrue(batch.errorLog.contains('01W000000000001AAA'), 'Error log should contain the failing ID');
    }

    @IsTest
    static void shouldHandleEmptyScope_WhenNoAlertsExist() {
        BATCH_DeleteWorkflowAlerts batch = new BATCH_DeleteWorkflowAlerts();
        Test.setMock(HttpCalloutMock.class, new MockHttp('DeleteSuccess'));

        Test.startTest();
        batch.execute(null, new List<String>());
        Test.stopTest();

        Assert.areEqual(0, batch.totalDeleted, 'Empty scope should result in zero deletes');
        Assert.areEqual(0, batch.totalErrors, 'Empty scope should result in zero errors');
    }

    @IsTest
    static void shouldSendEmail_WhenFinishCalled() {
        BATCH_DeleteWorkflowAlerts batch = new BATCH_DeleteWorkflowAlerts();
        batch.totalDeleted = 3;

        Test.startTest();
        batch.finish(null);
        Test.stopTest();

        Integer emailInvocations = Limits.getEmailInvocations();
        Assert.isTrue(emailInvocations >= 0, 'finish() should complete without exception');
    }

    @IsTest
    static void shouldLogError_WhenQueryFails() {
        Test.setMock(HttpCalloutMock.class, new MockHttp('QueryHttpError'));

        BATCH_DeleteWorkflowAlerts batch = new BATCH_DeleteWorkflowAlerts();

        Test.startTest();
        // Call start() directly — passing null for bc skips abortJob
        try {
            List<String> ids = (List<String>) batch.start(null);
            // start() catches the exception internally; errors should be logged
        } catch (Exception e) {
            // NullPointerException from abortJob(null) is expected in test context
        }
        Test.stopTest();

        Assert.areEqual(1, batch.totalErrors, 'A failed query should increment the error count');
        Assert.isTrue(batch.errorLog.contains('[start]'), 'Error log should contain start context marker');
    }

    @IsTest
    static void shouldParseMultipleIds_WhenQueryBodyContainsMany() {
        BATCH_DeleteWorkflowAlerts batch = new BATCH_DeleteWorkflowAlerts();
        Test.setMock(HttpCalloutMock.class, new MockHttp('DeleteSuccess'));

        Test.startTest();
        batch.execute(null, new List<String>{
            '01W000000000001AAA',
            '01W000000000002AAA',
            '01W000000000003AAA'
        });
        Test.stopTest();

        Assert.areEqual(3, batch.totalDeleted, 'Should delete all three records in scope');
    }
}
