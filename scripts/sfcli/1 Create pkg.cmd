REM To prevent autoupdate of sfdx-project.json during package create, set the following windows env variable:
REM set SF_PROJECT_AUTOUPDATE_DISABLE_FOR_PACKAGE_CREATE=true

sf package create --name="Export Email Alerts" --package-type="Unlocked" --path="force-app" --target-dev-hub="mr.jcrm.devhub@gmail.com" --error-notification-username="mr.jcrm.devhub@gmail.com" --description="Finally, a list of all the email alerts in your org!"