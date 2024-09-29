# Export Email Alerts  ![SFDCLogo transparent 03pct](https://user-images.githubusercontent.com/16543260/233866155-fcd090d8-82cd-49fa-90d7-d2c2f2ee4b00.png)
## Genesis
Over the years I've seen people asking how can I get a list of all the email addresses used by my org's email alerts?  [How to do abc?](https://shit.com), [How to do def?](https://shit.com) Some of the solutions are not bad.  But I thought a no-holds-barred solution would be nice - simple, configuration-free, examines alerts for all sObjects, and expands targets like groups or roles.  And yes, it includes flow Email Actions.<br>
<br><br>*Use the GitHub [Issues tab](https://github.com/50471736/Export_Email_Alerts/issues) to report bugs or request enhancements.*
## Architecture
- REST/Tooling API to read the WorkflowAlert and Flow sObjects
- Batch Apex to handle large numbers of alerts
## Author
Rod MacKenzie mr.jcrm@gmail.com
## Installation
[![Install Unlocked Package in Production](./images/btn-install-unlocked-package-prod-de.png)](https://login.salesforce.com/packaging/installPackage.apexp?p0=04tak00000030Y9AAI)<br>
[![Install Unlocked Package in Sandbox](./images/btn-install-unlocked-package-sandbox-scratch.png)](https://test.salesforce.com/packaging/installPackage.apexp?p0=04tak00000030Y9AAI)<br>
## How to run
<br><img src="images/HowToLaunch.png" alt="Alt text" title="Optional title" width="600"/>
<br><img src="images/HowToLaunch2.png" alt="Alt text" title="Optional title" width="600"/>
## Known issues
- After clicking an alert URL in the CSV, the detail page is shown in SFDC Classic, not Lightning.
## Sample CSV
<img width="769" alt="Email alerts" src="https://user-images.githubusercontent.com/16543260/233796850-b12af254-c27e-4de3-ba76-dd4aa726b339.png">
