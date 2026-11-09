# Step 4: allow the reporter to approve their own request in the DEMO approval workflow.
# The demo site has a single licensed user, so the template's "exclude reporter" rule
# leaves every request with zero eligible approvers. Only the DEMO-only workflow is changed.
# Usage: .\jira\04-allow-self-approval.ps1            -> allow self-approval (exclude: assignee)
#        .\jira\04-allow-self-approval.ps1 -Restore   -> restore template default (exclude: reporter, assignee)
param([switch]$Restore)

. "$PSScriptRoot\_common.ps1"

$name = 'DEMO: Service Request Fulfilment with Approvals workflow for Jira Service Management'
$approvalStatusRef = '10010'   # Waiting for approval

$res = Invoke-Jira -Method POST -Path '/rest/api/3/workflows?expand=values.transitions' -Body @{ workflowNames = @($name) }
$wf = $res.workflows[0]
if (-not $wf) { throw "Workflow '$name' not found." }

# Guard: refuse to touch a workflow used by any project other than DEMO.
$demoId = (Invoke-Jira -Method GET -Path "/rest/api/3/project/$($script:DemoKey)").id
$usages = Invoke-Jira -Method GET -Path "/rest/api/3/workflow/$($wf.id)/projectUsages"
$others = @($usages.projects.values | Where-Object { $_.id -ne $demoId })
if ($others.Count -gt 0) { throw "Workflow is also used by other projects: $($others.id -join ', '). Aborting." }

$ap = ($wf.statuses | Where-Object { $_.statusReference -eq $approvalStatusRef }).approvalConfiguration
$target = if ($Restore) { @('reporter', 'assignee') } else { @('assignee') }
Write-Host "approval exclude: $($ap.exclude -join ',') -> $($target -join ',')"
if ((@($ap.exclude) -join ',') -eq ($target -join ',')) { Write-Host 'Already set. Nothing to do.'; return }
$ap.exclude = $target

$statusPayload = @($res.statuses | ForEach-Object {
    @{ id = $_.id; name = $_.name; statusCategory = $_.statusCategory; statusReference = $_.statusReference } })
$wfPayload = @{ id = $wf.id; version = $wf.version; statuses = $wf.statuses; transitions = $wf.transitions; description = $wf.description }
if ($wf.startPointLayout) { $wfPayload.startPointLayout = $wf.startPointLayout }

$out = Invoke-Jira -Method POST -Path '/rest/api/3/workflows/update' -Body @{ statuses = $statusPayload; workflows = @($wfPayload) }
Write-Host "Workflow updated to version $($out.workflows[0].version.versionNumber)."
Write-Host 'Note: approvals already open keep their old approver list; only new requests use the new rule.'
