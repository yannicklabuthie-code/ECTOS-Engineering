Set-StrictMode -Version Latest

function Get-ECTOSQfReceipt {
    param([Parameter(Mandatory=$true)][string]$Path,[Parameter(Mandatory=$true)][string]$SchemaId,[Parameter(Mandatory=$true)][string]$FailurePrefix)
    if(-not(Test-Path -LiteralPath $Path -PathType Leaf)){throw ($FailurePrefix+'_MISSING')}
    try{$receipt=Get-Content -LiteralPath $Path -Raw -ErrorAction Stop|ConvertFrom-Json -ErrorAction Stop}catch{throw ($FailurePrefix+'_INVALID')}
    if([string]$receipt.schema_id -ne $SchemaId -or [string]$receipt.status -ne 'PASS_PHYSICALLY_PROVEN'){throw ($FailurePrefix+'_NOT_PROVEN')}
    if([string]::IsNullOrWhiteSpace([string]$receipt.package_content_identity)){throw ($FailurePrefix+'_IDENTITY_MISSING')}
    return $receipt
}

function Invoke-ECTOSQFHandoff {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]$BPFResult,
        [Parameter(Mandatory=$true)]$Target,
        [Parameter(Mandatory=$true)][string]$RepositoryRoot,
        [Parameter(Mandatory=$true)][string]$TrustBaseReceiptPath,
        [Parameter(Mandatory=$true)][string]$SelftestReceiptPath,
        [Parameter(Mandatory=$true)][string]$GraphClosureReceiptPath,
        [Parameter(Mandatory=$true)][string]$FinalClosureReceiptPath
    )
    if([string]$BPFResult.closure_state -ne 'PASS_PHYSICALLY_PROVEN'){throw 'QF_HANDOFF_BUILD_NOT_CLOSED'}
    if(-not($Target.PSObject.Properties.Name -contains 'qualification_profile_path')){throw 'QF_PROFILE_PATH_MISSING'}
    $profilePath=Join-Path $RepositoryRoot ([string]$Target.qualification_profile_path)
    if(-not(Test-Path -LiteralPath $profilePath -PathType Leaf)){throw 'QF_PROFILE_NOT_FOUND'}
    try{$qualificationProfile=Get-Content -LiteralPath $profilePath -Raw -ErrorAction Stop|ConvertFrom-Json -ErrorAction Stop}catch{throw ('QF_PROFILE_INVALID:'+ $_.Exception.Message)}
    if([string]$qualificationProfile.profile_id -ne 'ECTOS_DEV_SELFTEST_QF_HANDOFF_PROFILE_V03'){throw 'QF_PROFILE_SEMANTIC_FAIL'}
    if([string]$qualificationProfile.mode -ne 'HANDOFF_ONLY' -or -not[bool]$qualificationProfile.qualification_execution_authority_required -or [bool]$qualificationProfile.producer_may_qualify){throw 'QF_AUTHORITY_BOUNDARY_FAIL'}
    foreach($required in @('package','package_sha256','manifest','dependency_graph','entrypoint','trust_base_receipt','selftest_receipt','graph_closure_receipt','final_closure_receipt','environment_contract','evidence_contract')){
        if(@($qualificationProfile.required_inputs|Where-Object{[string]$_ -eq $required}).Count -ne 1){throw ('QF_REQUIRED_INPUT_MISSING:'+$required)}
    }
    if([string]$qualificationProfile.environment_contract.target_os -ne 'WINDOWS' -or [string]$qualificationProfile.environment_contract.target_runtime -ne 'WINDOWS_POWERSHELL_DESKTOP_5_1'){throw 'QF_ENVIRONMENT_CONTRACT_FAIL'}
    if(-not[bool]$qualificationProfile.evidence_contract.detached -or [bool]$qualificationProfile.evidence_contract.package_mutation_allowed){throw 'QF_EVIDENCE_CONTRACT_FAIL'}
    if($PSVersionTable.PSEdition -ne 'Desktop' -or $PSVersionTable.PSVersion.Major -ne 5 -or $PSVersionTable.PSVersion.Minor -ne 1){throw 'QF_RUNTIME_NOT_PS51'}

    $trust=Get-ECTOSQfReceipt -Path $TrustBaseReceiptPath -SchemaId 'ECTOS_QUALIFICATION_TRUST_BASE_RECEIPT_V02' -FailurePrefix 'QF_TRUST_BASE_RECEIPT'
    $selftest=Get-ECTOSQfReceipt -Path $SelftestReceiptPath -SchemaId 'ECTOS_PRODUCER_PREQUALIFICATION_SELFTEST_RECEIPT_V02' -FailurePrefix 'QF_SELFTEST_RECEIPT'
    $graphClosure=Get-ECTOSQfReceipt -Path $GraphClosureReceiptPath -SchemaId 'ECTOS_DETACHED_GRAPH_CLOSURE_RECEIPT_V02' -FailurePrefix 'QF_GRAPH_CLOSURE_RECEIPT'
    $finalClosure=Get-ECTOSQfReceipt -Path $FinalClosureReceiptPath -SchemaId 'ECTOS_DEV_FINAL_CLOSURE_RECEIPT_V02' -FailurePrefix 'QF_FINAL_CLOSURE_RECEIPT'
    $trustIdentity=[string]$trust.package_content_identity
    foreach($receipt in @($selftest,$graphClosure,$finalClosure)){if([string]$receipt.package_content_identity -ne $trustIdentity){throw 'QF_TRUST_RECEIPT_IDENTITY_MISMATCH'}}
    if([string]$graphClosure.graph_closure_state -ne 'PASS_PHYSICALLY_PROVEN'){throw 'QF_GRAPH_CLOSURE_NOT_PROVEN'}

    $manifestPath=Join-Path ([string]$BPFResult.package_root) 'ectos-package-manifest.json'
    if(-not(Test-Path -LiteralPath $manifestPath -PathType Leaf)){throw 'QF_PACKAGE_MANIFEST_MISSING'}
    try{$manifest=Get-Content -LiteralPath $manifestPath -Raw -ErrorAction Stop|ConvertFrom-Json -ErrorAction Stop}catch{throw 'QF_MANIFEST_SCHEMA_FAIL'}
    foreach($name in @('schema_id','package_type','package_id','version','source_commit','build_id','target_runtime','supported_os','entrypoint','expected_output_contract','side_effect_contract','mutation_policy','test_profile','qualification_profile','install_profile','rollback_profile','evidence_profile','dependency_graph')){
        if(-not($manifest.PSObject.Properties.Name -contains $name) -or [string]::IsNullOrWhiteSpace([string]$manifest.$name)){throw ('QF_MANIFEST_REQUIRED_FIELD_FAIL:'+$name)}
    }
    if([string]$manifest.schema_id -ne [string]$qualificationProfile.manifest_schema_id){throw 'QF_MANIFEST_SCHEMA_FAIL'}
    if([string]$manifest.package_id -ne [string]$BPFResult.package_id){throw 'QF_MANIFEST_PACKAGE_BINDING_FAIL'}
    $entryPath=Join-Path ([string]$BPFResult.package_root) ([string]$manifest.entrypoint)
    if(-not(Test-Path -LiteralPath $entryPath -PathType Leaf)){throw 'QF_ENTRYPOINT_MISSING'}

    $graphPath=Join-Path ([string]$BPFResult.package_root) ([string]$manifest.dependency_graph)
    if(-not(Test-Path -LiteralPath $graphPath -PathType Leaf)){throw 'QF_DEPENDENCY_GRAPH_MISSING'}
    try{$graph=Get-Content -LiteralPath $graphPath -Raw -ErrorAction Stop|ConvertFrom-Json -ErrorAction Stop}catch{throw 'QF_GRAPH_SCHEMA_FAIL'}
    foreach($name in @('schema_id','package','nodes','edges','closure','change_impact')){if(-not($graph.PSObject.Properties.Name -contains $name)){throw ('QF_GRAPH_REQUIRED_FIELD_FAIL:'+$name)}}
    if([string]$graph.schema_id -ne [string]$qualificationProfile.graph_schema_id){throw 'QF_GRAPH_SCHEMA_FAIL'}
    if([string]$graph.package.package_id -ne [string]$BPFResult.package_id){throw 'QF_GRAPH_PACKAGE_BINDING_FAIL'}
    if([string]$graph.closure.dependency_closure -ne [string]$qualificationProfile.graph_in_package_state){throw 'QF_GRAPH_IN_PACKAGE_STATE_FAIL'}
    foreach($countName in @('undeclared_dependency_count','unresolved_transitive_dependency_count','untested_dependency_count','implicit_environment_assumption_count','unknown_blast_radius_edge_count')){if([int]$graph.closure.$countName -ne 0){throw ('QF_GRAPH_CLOSURE_COUNT_FAIL:'+$countName)}}
    foreach($node in @($graph.nodes)){if([string]$node.currentness -ne 'CURRENT'){throw ('QF_GRAPH_NODE_CURRENTNESS_FAIL:'+[string]$node.dependency_id)}}
    foreach($edge in @($graph.edges)){if([string]$edge.status -ne 'RESOLVED' -or [string]$edge.currentness -ne 'CURRENT'){throw ('QF_GRAPH_EDGE_CLOSURE_FAIL:'+[string]$edge.edge_id)}}

    $actualZipHash=(Get-FileHash -LiteralPath ([string]$BPFResult.package_zip) -Algorithm SHA256).Hash
    if($actualZipHash -ne [string]$BPFResult.package_sha256){throw 'QF_PACKAGE_SHA256_MISMATCH'}
    $graphSha=(Get-FileHash -LiteralPath $graphPath -Algorithm SHA256).Hash
    $manifestSha=(Get-FileHash -LiteralPath $manifestPath -Algorithm SHA256).Hash
    [pscustomobject][ordered]@{
        schema_id='ECTOS_QF_HANDOFF_V03';contract_id='ECTOS_QF_PREQUALIFICATION_HANDOFF_CONTRACT_V03';status='HANDOFF_READY_FOR_INDEPENDENT_QUALIFICATION'
        candidate_package_id=[string]$BPFResult.package_id;candidate_package_sha256=$actualZipHash;candidate_package_content_identity=[string]$BPFResult.package_content_identity
        candidate_member_set_sha256=[string]$BPFResult.package_member_set_sha256;qualification_profile_id=[string]$qualificationProfile.profile_id
        manifest=$manifestPath;manifest_sha256=$manifestSha;dependency_graph=$graphPath;dependency_graph_sha256=$graphSha;candidate_graph_state=[string]$graph.closure.dependency_closure
        trust_base_package_content_identity=$trustIdentity;trust_base_receipt_sha256=(Get-FileHash -LiteralPath $TrustBaseReceiptPath -Algorithm SHA256).Hash
        selftest_receipt_sha256=(Get-FileHash -LiteralPath $SelftestReceiptPath -Algorithm SHA256).Hash;graph_closure_receipt_sha256=(Get-FileHash -LiteralPath $GraphClosureReceiptPath -Algorithm SHA256).Hash
        final_closure_receipt_sha256=(Get-FileHash -LiteralPath $FinalClosureReceiptPath -Algorithm SHA256).Hash;trust_base_graph_closure_state=[string]$graphClosure.graph_closure_state
        entrypoint=$entryPath;environment_state='PASS_PHYSICALLY_PROVEN';evidence_state='PASS_PHYSICALLY_PROVEN';independent_qualification_executed=$false;producer_is_qualifier=$false
    }
}
