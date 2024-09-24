# Export Email Alerts  ![SFDCLogo transparent 03pct](https://user-images.githubusercontent.com/16543260/233866155-fcd090d8-82cd-49fa-90d7-d2c2f2ee4b00.png)
## Purpose
Several administrators have expressed a need to list all Salesforce email alerts, including email addresses. This solution exports all email alerts (including flow email actions) to a CSV and emails it to the current user.
<br><br>*Use the GitHub [Issues tab](https://github.com/50471736/Export_Email_Alerts/issues) to report bugs or request enhancements.*
## Architecture
- REST/Tooling API to read the WorkflowAlert and Flow sObjects
- Batch Apex to handle large numbers of alerts
## Author
Rod MacKenzie mr.jcrm@gmail.com
## Installation
Install unlocked package in DE org or production org https://login.salesforce.com/packaging/installPackage.apexp?p0=04tak00000030Y9AAI<br>
Install unlocked package in sandbox org or scratch org https://test.salesforce.com/packaging/installPackage.apexp?p0=<br>
[![Install Unlocked Package in Production](./images/btn-install-unlocked-package-production.png)](https://login.salesforce.com/packaging/installPackage.apexp?p0=04tak00000030Y9AAI)<br>
[![Install Unlocked Package in Production](./images/btn-install-unlocked-package-sandbox-scratch.png)](https://login.salesforce.com/packaging/installPackage.apexp?p0=04tak00000030Y9AAI)<br>
## How to run
![xx](images/HowToLaunch.png)
<br><img src="images/HowToLaunch.png" alt="Alt text" title="Optional title" width="300"/>
## Known issues
- After clicking an alert URL in the CSV, the detail page is shown in SFDC Classic, not Lightning.
## Sample CSV
<img width="769" alt="Email alerts" src="https://user-images.githubusercontent.com/16543260/233796850-b12af254-c27e-4de3-ba76-dd4aa726b339.png">