# Shared helpers for Jira Cloud REST calls.
# Credentials come from env vars (process scope first, then Windows User scope).
# The API token is never printed.

function Get-JiraVar([string]$Name) {
    $v = [Environment]::GetEnvironmentVariable($Name, 'Process')
    if (-not $v) { $v = [Environment]::GetEnvironmentVariable($Name, 'User') }
    if (-not $v) { throw "Environment variable $Name is not set." }
    return $v
}

$script:JiraSite  = (Get-JiraVar 'JIRA_SITE').TrimEnd('/')
$script:JiraEmail = Get-JiraVar 'JIRA_EMAIL'
$script:JiraAuth  = 'Basic ' + [Convert]::ToBase64String(
    [Text.Encoding]::ASCII.GetBytes("$($script:JiraEmail):$(Get-JiraVar 'JIRA_API_TOKEN')"))

# Guard: these scripts must only ever touch the DEMO project.
$script:DemoKey = 'DEMO'
$script:ProtectedKeys = @('SUP', 'SCRUM')

function Invoke-Jira {
    param(
        [Parameter(Mandatory)][ValidateSet('GET','POST','PUT','DELETE')][string]$Method,
        [Parameter(Mandatory)][string]$Path,
        $Body,
        [switch]$Experimental
    )
    $headers = @{ Authorization = $script:JiraAuth; Accept = 'application/json' }
    if ($Experimental) { $headers['X-ExperimentalApi'] = 'opt-in' }
    $params = @{ Uri = "$($script:JiraSite)$Path"; Method = $Method; Headers = $headers }
    if ($null -ne $Body) {
        $params.ContentType = 'application/json; charset=utf-8'
        $params.Body = [Text.Encoding]::UTF8.GetBytes(($Body | ConvertTo-Json -Depth 20))
    }
    try {
        return Invoke-RestMethod @params
    } catch {
        $code = $_.Exception.Response.StatusCode.value__
        throw "Jira $Method $Path failed ($code): $($_.ErrorDetails.Message)"
    }
}
