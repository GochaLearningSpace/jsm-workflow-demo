# Step 1: create the DEMO Jira Service Management project (idempotent).
. "$PSScriptRoot\_common.ps1"

$existing = $null
try { $existing = Invoke-Jira GET "/rest/api/3/project/$DemoKey" } catch { }
if ($existing) {
    Write-Host "Project $DemoKey already exists (id=$($existing.id)). Skipping."
    return
}

$me = Invoke-Jira GET '/rest/api/3/myself'
$project = Invoke-Jira POST '/rest/api/3/project' @{
    key                = $DemoKey
    name               = 'DEMO 社内申請・承認・制作管理'
    description        = 'JSM workflow demo: request / approval / production tracking. Isolated from SUP and SCRUM.'
    projectTypeKey     = 'service_desk'
    projectTemplateKey = 'com.atlassian.servicedesk:simplified-internal-service-desk'
    leadAccountId      = $me.accountId
    assigneeType       = 'UNASSIGNED'
}
Write-Host "Created project $($project.key) (id=$($project.id))"
