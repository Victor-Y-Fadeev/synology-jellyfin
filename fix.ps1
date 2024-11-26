$adapters = Get-NetAdapterLso -IncludeHidden

foreach ($adapter in $adapters) {
	Write-Host "Disabling LSO for adapter: $($adapter.Name)"
	Disable-NetAdapterLso -IncludeHidden -Name $adapter.Name -Confirm:$false
}
