# test-v3.ps1 — Valida o stack multi-preview (qa + pr-123 + pr-456)
$ErrorActionPreference = 'Stop'
$h = @{ 'Content-Type' = 'application/json' }

function Test-Preview {
    param([int]$Port, [string]$Label, [string]$Email, [string]$Brand, [string]$Model, [decimal]$Fipe)
    Write-Host ""
    Write-Host "=== $Label (porta $Port) ===" -ForegroundColor Cyan

    $body = @{ name = "Gabriel $Label"; email = $Email; phone = "(11) 99999-0000" } | ConvertTo-Json
    $lead = Invoke-RestMethod "http://localhost:$Port/api/leads" -Method POST -Headers $h -Body $body
    Write-Host "  lead         : id=$($lead.id) source=$($lead.source)"

    $body = @{ lead_id = $lead.id; license_plate = "ABC1D23"; brand = $Brand; model = $Model; year = 2024; fipe_value = $Fipe } | ConvertTo-Json
    $veh = Invoke-RestMethod "http://localhost:$Port/api/vehicles" -Method POST -Headers $h -Body $body
    Write-Host "  veiculo      : id=$($veh.id) $($veh.brand) $($veh.model)"

    $body = @{ lead_id = $lead.id; vehicle_id = $veh.id; coverage_type = "completo" } | ConvertTo-Json
    $q = Invoke-RestMethod "http://localhost:$Port/api/quotes" -Method POST -Headers $h -Body $body
    Write-Host "  quote        : $($q.quote.quote_number) -> R$ $($q.quote.monthly_premium)/mes"
    Write-Host "  pricing      : $($q.orchestration.pricing_engine.url) [$($q.orchestration.pricing_engine.source)]"
    Write-Host "  notification : $($q.orchestration.notification_service.url) [$($q.orchestration.notification_service.source)]"
    Write-Host "  db usado     : $($q.orchestration.db)"
    Write-Host "  email        : $($q.notification.status) -> $($q.lead.email)"
}

Test-Preview -Port 3001 -Label "PR-123" -Email "gabriel+pr123@youse.test" -Brand "Honda"  -Model "Civic Touring" -Fipe 185000
Test-Preview -Port 3002 -Label "PR-456" -Email "gabriel+pr456@youse.test" -Brand "Toyota" -Model "Corolla XEi"   -Fipe 165000

Write-Host ""
Write-Host "=== Contagem leads por DB ===" -ForegroundColor Yellow
docker exec postgres-qa-simulado psql -U youse -d monolithic_qa -tAc "SELECT 'monolithic_qa: ' || COUNT(*) || ' leads' FROM leads;"
docker exec postgres-qa-simulado psql -U youse -d preview_pr123 -tAc "SELECT 'preview_pr123: ' || COUNT(*) || ' leads' FROM leads;"
docker exec postgres-qa-simulado psql -U youse -d preview_pr456 -tAc "SELECT 'preview_pr456: ' || COUNT(*) || ' leads' FROM leads;"

Write-Host ""
Write-Host "=== Mailpit inbox ===" -ForegroundColor Yellow
(Invoke-RestMethod http://localhost:8025/api/v1/messages).messages |
    Select-Object @{n='From';e={$_.From.Address}}, @{n='To';e={$_.To.Address -join ','}}, Subject |
    Format-Table -AutoSize
