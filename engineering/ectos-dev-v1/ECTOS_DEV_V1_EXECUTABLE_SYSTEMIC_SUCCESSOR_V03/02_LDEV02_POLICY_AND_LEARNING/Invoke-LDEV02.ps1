Set-StrictMode -Version Latest

function Get-ECTOSPolicySha256 {
    param([Parameter(Mandatory=$true)][byte[]]$Bytes)
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($Bytes))).Replace('-','') }
    finally { $sha.Dispose() }
}

function ConvertTo-ECTOSCanonicalValue {
    param($Value)
    if ($null -eq $Value) { return $null }
    if ($Value -is [string] -or $Value -is [ValueType]) { return $Value }
    if ($Value -is [System.Collections.IDictionary]) {
        $ordered = [ordered]@{}
        foreach ($key in @($Value.Keys | Sort-Object)) { $ordered[$key] = ConvertTo-ECTOSCanonicalValue -Value $Value[$key] }
        return $ordered
    }
    if ($Value -is [System.Collections.IEnumerable] -and -not ($Value -is [pscustomobject])) {
        $items = @()
        foreach ($item in $Value) { $items += ,(ConvertTo-ECTOSCanonicalValue -Value $item) }
        return $items
    }
    $object = [ordered]@{}
    foreach ($property in @($Value.PSObject.Properties.Name | Sort-Object)) {
        $object[$property] = ConvertTo-ECTOSCanonicalValue -Value $Value.$property
    }
    return $object
}

function Get-ECTOSCanonicalProfileSha256 {
    param([Parameter(Mandatory=$true)]$Profile)
    $root = [ordered]@{}
    foreach ($property in @($Profile.PSObject.Properties.Name | Where-Object { $_ -ne 'profile_sha256' } | Sort-Object)) {
        $root[$property] = ConvertTo-ECTOSCanonicalValue -Value $Profile.$property
    }
    $json = $root | ConvertTo-Json -Depth 32 -Compress
    return Get-ECTOSPolicySha256 -Bytes ([Text.Encoding]::UTF8.GetBytes($json))
}

function Get-ECTOSRulesetSha256 {
    param([Parameter(Mandatory=$true)][string]$RepositoryRoot,[Parameter(Mandatory=$true)][string[]]$RulePaths)
    $paths = [string[]]@($RulePaths)
    [Array]::Sort($paths,[StringComparer]::Ordinal)
    $stream = New-Object IO.MemoryStream
    try {
        foreach ($path in $paths) {
            $pathBytes = [Text.Encoding]::UTF8.GetBytes($path.Replace('\','/'))
            $fileBytes = [IO.File]::ReadAllBytes((Join-Path $RepositoryRoot $path))
            $stream.Write($pathBytes,0,$pathBytes.Length);$stream.WriteByte(0)
            $stream.Write($fileBytes,0,$fileBytes.Length);$stream.WriteByte(0)
        }
        return Get-ECTOSPolicySha256 -Bytes $stream.ToArray()
    } finally { $stream.Dispose() }
}

function Invoke-ECTOSLDEV02 {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)]$Target,[Parameter(Mandatory=$true)][string]$RepositoryRoot)
    if ($null -eq $Target) { throw 'LDEV02_TARGET_NULL' }
    foreach ($name in @('target_id','language','target_runtime','rule_profile_path')) {
        if (-not ($Target.PSObject.Properties.Name -contains $name)) { throw ('LDEV02_TARGET_FIELD_MISSING:' + $name) }
    }
    $ruleProfilePath = Join-Path $RepositoryRoot ([string]$Target.rule_profile_path)
    if (-not (Test-Path -LiteralPath $ruleProfilePath -PathType Leaf)) { throw 'LDEV02_RULE_PROFILE_NOT_FOUND' }
    try { $ruleProfile = Get-Content -LiteralPath $ruleProfilePath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop } catch { throw ('LDEV02_RULE_PROFILE_INVALID:' + $_.Exception.Message) }
    if ([string]$ruleProfile.language -ne [string]$Target.language -or [string]$ruleProfile.target_runtime -ne [string]$Target.target_runtime) { throw 'LDEV02_APPLICABILITY_NOT_PROVEN' }
    if ([string]$ruleProfile.promotion_authority -ne 'ECTOS_FACTORY' -or [bool]$ruleProfile.dev_self_promotion) { throw 'LDEV02_PROMOTION_AUTHORITY_NOT_PROVEN' }

    $selectorPath = Join-Path $RepositoryRoot ([string]$ruleProfile.current_selector)
    $selector = Get-Content -LiteralPath $selectorPath -Raw | ConvertFrom-Json
    if ([string]$selector.status -ne 'CURRENT_SELECTOR') { throw 'LDEV02_SELECTOR_CURRENTNESS_FAIL' }
    if ([string]$selector.current_pointer -ne [string]$ruleProfile.expected_current_pointer) { throw 'LDEV02_SELECTOR_MISMATCH' }
    $pointerPath = Join-Path $RepositoryRoot ([string]$selector.current_pointer)
    $pointer = Get-Content -LiteralPath $pointerPath -Raw | ConvertFrom-Json
    if ([string]$pointer.status -ne 'CURRENT') { throw 'LDEV02_POINTER_CURRENTNESS_FAIL' }

    $profilePath = Join-Path $RepositoryRoot ([string]$pointer.default_powershell_profile)
    $policyProfile = Get-Content -LiteralPath $profilePath -Raw | ConvertFrom-Json
    if ([string]$policyProfile.currentness_state -ne 'CURRENT') { throw 'LDEV02_PROFILE_CURRENTNESS_FAIL' }
    $profileSha = Get-ECTOSCanonicalProfileSha256 -Profile $policyProfile
    if ($profileSha -ne [string]$policyProfile.profile_sha256 -or $profileSha -ne [string]$ruleProfile.profile_sha256) { throw 'LDEV02_PROFILE_MISMATCH' }
    $profileSidecar = (Get-Content -LiteralPath (Join-Path $RepositoryRoot ([string]$pointer.profile_sha_sidecar)) -Raw).Split()[0].ToUpperInvariant()
    if ($profileSidecar -ne $profileSha) { throw 'LDEV02_PROFILE_SIDECAR_MISMATCH' }

    $contract = Get-Content -LiteralPath (Join-Path $RepositoryRoot ([string]$pointer.agent_consumption_contract)) -Raw | ConvertFrom-Json
    $rulesetSha = Get-ECTOSRulesetSha256 -RepositoryRoot $RepositoryRoot -RulePaths @($contract.retrieve.rule_set)
    $rulesetSidecar = (Get-Content -LiteralPath (Join-Path $RepositoryRoot ([string]$pointer.ruleset_sha_sidecar)) -Raw).Split()[0].ToUpperInvariant()
    if ($rulesetSha -ne [string]$ruleProfile.ruleset_sha256 -or $rulesetSha -ne [string]$policyProfile.ruleset_sha256 -or $rulesetSha -ne $rulesetSidecar) { throw 'LDEV02_RULESET_SHA256_MISMATCH' }

    $ruleRecords = @()
    foreach ($path in @($contract.retrieve.rule_set)) {
        $rule = Get-Content -LiteralPath (Join-Path $RepositoryRoot $path) -Raw | ConvertFrom-Json
        if ([string]$rule.currentness -ne 'CURRENT' -or [string]$rule.status -ne 'ACTIVE') { throw ('LDEV02_RULE_CURRENTNESS_FAIL:' + [string]$rule.rule_id) }
        $rawSha = (Get-FileHash -LiteralPath (Join-Path $RepositoryRoot $path) -Algorithm SHA256).Hash
        $ruleRecords += [pscustomobject][ordered]@{rule_id=[string]$rule.rule_id;path=$path;sha256=$rawSha;defect_family_id=[string]$rule.defect_family_id;currentness='CURRENT';status='ACTIVE'}
    }
    if (@($ruleRecords).Count -ne @($ruleProfile.rules).Count) { throw 'LDEV02_RULE_MEMBER_MISMATCH' }
    foreach ($expectedRuleId in @($ruleProfile.rules)) { if (@($ruleRecords | Where-Object { $_.rule_id -eq $expectedRuleId }).Count -ne 1) { throw ('LDEV02_RULE_MEMBER_MISMATCH:' + $expectedRuleId) } }

    $fixtureRecords = @()
    foreach ($fixturePath in @($contract.retrieve.regression_fixtures)) {
        $full = Join-Path $RepositoryRoot $fixturePath
        if (-not (Test-Path -LiteralPath $full -PathType Leaf)) { throw ('LDEV02_FIXTURE_BINDING_FAIL:' + $fixturePath) }
        $fixtureRecords += [pscustomobject][ordered]@{path=$fixturePath;sha256=(Get-FileHash -LiteralPath $full -Algorithm SHA256).Hash}
    }

    $receipt = [pscustomobject][ordered]@{
        schema_id='ECTOS_LDEV02_POLICY_IDENTITY_RECEIPT_V02';contract_id='ECTOS_LDEV02_POLICY_IDENTITY_CONTRACT_V02';closure_state='PASS_PHYSICALLY_PROVEN'
        target_id=[string]$Target.target_id;selector_path=[string]$ruleProfile.current_selector;selector_sha256=(Get-FileHash -LiteralPath $selectorPath -Algorithm SHA256).Hash
        current_pointer=[string]$selector.current_pointer;pointer_sha256=(Get-FileHash -LiteralPath $pointerPath -Algorithm SHA256).Hash
        profile_path=[string]$pointer.default_powershell_profile;profile_sha256=$profileSha;ruleset_sha256=$rulesetSha
        active_rule_member_set=@($ruleRecords);fixture_bindings=@($fixtureRecords);applicability=([string]$Target.language + '|' + [string]$Target.target_runtime)
        learning_promotion_authority=[string]$ruleProfile.promotion_authority;dev_self_promotion=$false;audit_evidence_identity=$null
    }
    $receipt.audit_evidence_identity = Get-ECTOSPolicySha256 -Bytes ([Text.Encoding]::UTF8.GetBytes(($receipt | ConvertTo-Json -Depth 16 -Compress)))
    return $receipt
}
