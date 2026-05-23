REM Get all package subscriber orgs that have an installed package created by the org you’re logged in to

sf data query --target-org=devhub --query="SELECT Id, SystemModstamp, OrgKey, OrgStatus, OrgName, OrgType, InstanceName, MetadataPackageId, MetadataPackageVersionId FROM PackageSubscriber WHERE InstalledStatus = 'i'"