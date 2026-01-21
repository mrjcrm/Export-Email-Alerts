REM To prevent autoupdate of sfdx-project.json during package versioncreate, set the following windows env variable:
REM set SF_PROJECT_AUTOUPDATE_DISABLE_FOR_PACKAGE_VERSION_CREATE=true

sf package version create --installation-key-bypass --package=0Hoak0000001DODCA2 --wait="10" --version-description="Export Salesforce alerts to CSV" --version-name="Beta" --version-number="1.0.0.NEXT" --code-coverage --path="force-app" --verbose --target-dev-hub="mr.jcrm.devhub@gmail.com" --tag="gitid 1234567"