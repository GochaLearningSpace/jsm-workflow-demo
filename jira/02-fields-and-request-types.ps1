# Step 2: custom fields (DEMO-scoped), screen placement, request types.
# Idempotent: existing fields / request types with the same name are reused.
. "$PSScriptRoot\_common.ps1"

$project  = Invoke-Jira GET "/rest/api/3/project/$DemoKey"
$sdId     = ((Invoke-Jira GET '/rest/servicedeskapi/servicedesk').values | Where-Object projectKey -eq $DemoKey).id
$screenId = 10022   # "DEMO: Jira Service Management Screen" (DEMO-only screen)

$screen = (Invoke-Jira GET "/rest/api/3/screens?id=$screenId").values[0]
if ($screen.name -notlike "${DemoKey}:*") { throw "Screen $screenId is not a DEMO screen: $($screen.name)" }

# ---- 1. Custom fields ------------------------------------------------------
# Field names carry a [DEMO] prefix so they are recognisable in the site-wide field list.
$fieldDefs = @(
    @{ key='amount';   name='[DEMO] 金額（税込・円）'; type='float';          searcher='exactnumber' }
    @{ key='media';    name='[DEMO] 媒体';             type='select';         searcher='multiselectsearcher'; options=@('Web','印刷','動画') }
    @{ key='duration'; name='[DEMO] 尺（秒）';         type='float';          searcher='exactnumber' }
    @{ key='due';      name='[DEMO] 希望納期';         type='datepicker';     searcher='daterange' }
    @{ key='system';   name='[DEMO] 対象システム';     type='select';         searcher='multiselectsearcher'; options=@('Slack','GitHub','Jira') }
    @{ key='repo';     name='[DEMO] リポジトリ名';     type='textfield';      searcher='textsearcher' }
    @{ key='start';    name='[DEMO] 利用開始日';       type='datepicker';     searcher='daterange' }
)

$fields = @{}
foreach ($d in $fieldDefs) {
    $found = (Invoke-Jira GET "/rest/api/3/field/search?type=custom&query=$([uri]::EscapeDataString($d.name))").values |
             Where-Object name -eq $d.name | Select-Object -First 1
    if (-not $found) {
        $found = Invoke-Jira POST '/rest/api/3/field' @{
            name        = $d.name
            description = 'JSM workflow demo field (DEMO project only)'
            type        = "com.atlassian.jira.plugin.system.customfieldtypes:$($d.type)"
            searcherKey = "com.atlassian.jira.plugin.system.customfieldtypes:$($d.searcher)"
        }
        Write-Host "Created field $($found.id) $($d.name)"
    } else {
        Write-Host "Field exists  $($found.id) $($d.name)"
    }
    $fid = $found.id
    $fields[$d.key] = $fid

    # Jira Cloud no longer allows the global context to be changed or deleted
    # (CHANGE-3019). Isolation is achieved instead by:
    #   - a DEMO-specific context that holds the options / configuration
    #   - placing the field only on the DEMO-only screen (step 2 below)
    $contexts = @((Invoke-Jira GET "/rest/api/3/field/$fid/context").values)
    $ctx = $contexts | Where-Object { -not $_.isGlobalContext } | Select-Object -First 1
    if (-not $ctx) {
        $ctx = Invoke-Jira POST "/rest/api/3/field/$fid/context" @{
            name = "$DemoKey only"; description = "Scoped to $DemoKey"; projectIds = @("$($project.id)"); issueTypeIds = @()
        }
        Write-Host "  context $($ctx.id) created for $DemoKey"
    }

    # Select options
    if ($d.options) {
        $ctxId = $ctx.id
        $have = @((Invoke-Jira GET "/rest/api/3/field/$fid/context/$ctxId/option").values | ForEach-Object value)
        $missing = @($d.options | Where-Object { $_ -notin $have })
        if ($missing.Count) {
            Invoke-Jira POST "/rest/api/3/field/$fid/context/$ctxId/option" @{
                options = @($missing | ForEach-Object { @{ value = $_; disabled = $false } })
            } | Out-Null
            Write-Host "  options added: $($missing -join ', ')"
        }
    }
}

# ---- 2. Put fields on the DEMO screen --------------------------------------
$tabId = (Invoke-Jira GET "/rest/api/3/screens/$screenId/tabs")[0].id
$onScreen = @((Invoke-Jira GET "/rest/api/3/screens/$screenId/tabs/$tabId/fields") | ForEach-Object id)
foreach ($fid in $fields.Values) {
    if ($fid -notin $onScreen) {
        Invoke-Jira POST "/rest/api/3/screens/$screenId/tabs/$tabId/fields" @{ fieldId = $fid } | Out-Null
        Write-Host "Added $fid to screen"
    }
}

# ---- 3. Request types ------------------------------------------------------
$approvalIssueType = (Invoke-Jira GET "/rest/api/3/issuetype/project?projectId=$($project.id)") |
                     Where-Object name -eq 'Service Request with Approvals'

$requestTypes = @(
    @{ name='備品購入申請';       description='10万円以上は部長承認を自動追加';     helpText='品目は件名に、購入理由は説明に記入してください。' }
    @{ name='制作依頼';           description='承認後に工程別の子チケットを自動生成'; helpText='案件名は件名に、概要は説明に記入してください。媒体が「動画」の場合は尺が必須です。' }
    @{ name='アカウント発行申請'; description='対象システムで入力項目が変化';       helpText='対象システムが GitHub の場合はリポジトリ名が必須です。' }
)
# "Emailed request" is the email channel's default request type and cannot be deleted.
$keepNames = @($requestTypes | ForEach-Object name) + 'Emailed request'

$existing = (Invoke-Jira GET "/rest/servicedeskapi/servicedesk/$sdId/requesttype?limit=100").values
foreach ($rt in $requestTypes) {
    if ($existing | Where-Object name -eq $rt.name) { Write-Host "Request type exists: $($rt.name)"; continue }
    $created = Invoke-Jira POST "/rest/servicedeskapi/servicedesk/$sdId/requesttype" -Experimental @{
        issueTypeId = $approvalIssueType.id
        name        = $rt.name
        description = $rt.description
        helpText    = $rt.helpText
    }
    Write-Host "Created request type $($created.id) $($rt.name)"
}

# Remove template sample request types (DEMO project only).
foreach ($rt in $existing) {
    if ($rt.name -notin $keepNames) {
        Invoke-Jira DELETE "/rest/servicedeskapi/servicedesk/$sdId/requesttype/$($rt.id)" -Experimental | Out-Null
        Write-Host "Deleted template request type $($rt.id) $($rt.name)"
    }
}

# Save field ids for later steps.
$fields | ConvertTo-Json | Set-Content -Encoding UTF8 "$PSScriptRoot\fields.json"
Write-Host 'Field ids saved to jira/fields.json'
