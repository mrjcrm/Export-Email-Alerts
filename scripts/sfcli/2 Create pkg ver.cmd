REM To prevent autoupdate of sfdx-project.json during package versioncreate, set the following windows env variable:
REM set SF_PROJECT_AUTOUPDATE_DISABLE_FOR_PACKAGE_VERSION_CREATE=true
REM Where to update version number: 
REM - sfdx-project.json
REM - main apex class
REM - readme.md (version number, and id of new package version)

sf package version create --installation-key-bypass --package=0Hoak0000001E8zCAE --wait="20" --version-description="List all the email alerts in your org" --version-name="Final" --code-coverage --path="force-app" --verbose --target-dev-hub="mr.jcrm.devhub@gmail.com" --tag="gitid 1234567" --releasenotes-url="https://github.com/mrjcrm/Export-Email-Alerts"