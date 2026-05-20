param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]] $FlutterArgs
)

if (-not $FlutterArgs -or $FlutterArgs.Count -eq 0) {
    $FlutterArgs = @("run")
}

$env:DART_VM_OPTIONS = "--old_gen_heap_size=4096"

& flutter @FlutterArgs
exit $LASTEXITCODE
