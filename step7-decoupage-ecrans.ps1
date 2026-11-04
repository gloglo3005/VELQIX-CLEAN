<#
  ÉTAPE 7 — Découpage des écrans Flutter (fichiers `part` / `part of`)

  À lancer depuis la RACINE DU PROJET FLUTTER (le dossier qui contient pubspec.yaml et lib\) :

      powershell -ExecutionPolicy Bypass -File .\step7-decoupage-ecrans.ps1 -DryRun   # simulation, rien n'est écrit
      powershell -ExecutionPolicy Bypass -File .\step7-decoupage-ecrans.ps1           # découpage réel

  Options :
      -DryRun   affiche ce qui serait fait, sans rien modifier
      -Force    continue même si `git status` signale des modifications non enregistrées dans lib\

  Principe : les classes d'aide (_XxxSheet, _XxxCard, onglets, bulles...) sont DÉPLACÉES telles
  quelles dans des fichiers `part of` rangés dans un sous-dossier. Un fichier `part` fait toujours
  partie de la MÊME bibliothèque Dart que le fichier principal : aucun import, aucun nom, aucune
  visibilité ne change, et les autres fichiers qui importent l'écran continuent de marcher.

  Sécurité : après écriture, le script relit les fichiers et vérifie qu'aucune ligne n'a été perdue
  ni ajoutée (hors lignes `part`). En cas d'écart, le fichier d'origine est restauré.
  Un fichier déjà découpé est ignoré (le script peut être relancé sans risque).
#>
param(
  [switch]$DryRun,
  [switch]$Force
)

$ErrorActionPreference = 'Stop'
$root = (Get-Location).Path
$utf8 = New-Object System.Text.UTF8Encoding($false)

# Début d'une déclaration de niveau supérieur (colonne 0) : class, enum, mixin, extension.
$declRx = '^(?:abstract\s+|sealed\s+|final\s+|base\s+|interface\s+)*(?:class|enum|mixin|extension)\s+([A-Za-z_][A-Za-z0-9_]*)'

$plan = @(
  @{ File='lib/screens/auth_screens.dart'; Dir='auth'; Parts=@(
    @{ Name='onboarding_screen.dart'; Classes=@('OnboardingScreen','_OnboardPage') }
    @{ Name='login_screen.dart'; Classes=@('LoginScreen') }
    @{ Name='auth_layout.dart'; Classes=@('AuthBrandPanel') }
    @{ Name='register_screen.dart'; Classes=@('RegisterScreen') }
    @{ Name='forgot_password_screen.dart'; Classes=@('ForgotPasswordScreen') }
    @{ Name='verify_code_screen.dart'; Classes=@('VerifyCodeScreen') }
    @{ Name='reset_password_screen.dart'; Classes=@('ResetPasswordScreen') }
  ) }
  @{ File='lib/screens/home_screen.dart'; Dir='home'; Parts=@(
    @{ Name='home_widgets.dart'; Classes=@('_BannerSlide','_AdBannerCard','_SuggestionChip','_QuickStat') }
  ) }
  @{ File='lib/screens/property_detail_screen.dart'; Dir='property_detail'; Parts=@(
    @{ Name='share_widgets.dart'; Classes=@('_ShareOption','_SocialIcon','_InstagramIcon') }
    @{ Name='avis_widgets.dart'; Classes=@('_AvisCard','_AvisForm') }
    @{ Name='media_widgets.dart'; Classes=@('_VideoCard','_VideoPlayerDialog','_FullscreenImageViewer') }
    @{ Name='info_widgets.dart'; Classes=@('_StatusBanner','_OwnerStat','_OwnerStatDivider') }
  ) }
  @{ File='lib/screens/profile_screen.dart'; Dir='profile'; Parts=@(
    @{ Name='profile_widgets.dart'; Classes=@('_StatPill','_MenuGroup','_MenuItem','_TabBtn','_PwdField','_EditField') }
    @{ Name='edit_profile_sheet.dart'; Classes=@('EditProfileSheet') }
  ) }
  @{ File='lib/screens/admin_dashboard_screen.dart'; Dir='admin_dashboard'; Parts=@(
    @{ Name='annonce_card.dart'; Classes=@('_AdminRealAnnonceCard') }
    @{ Name='create_staff_sheet.dart'; Classes=@('_CreateStaffSheet') }
    @{ Name='reports_panel.dart'; Classes=@('_ReportFilter','_AdminReportsPanel','_ReportActionSheet') }
  ) }
  @{ File='lib/screens/messages_screen.dart'; Dir='messages'; Parts=@(
    @{ Name='conversation_widgets.dart'; Classes=@('_ConversationAvatar','_NewConversationSheet') }
    @{ Name='chat_screen.dart'; Classes=@('ChatScreen') }
    @{ Name='message_bubbles.dart'; Classes=@('_ImageMessageBubble','_VoiceMessageBubble','_TypingDot') }
  ) }
  @{ File='lib/screens/add_listing_screen.dart'; Dir='add_listing'; Parts=@(
    @{ Name='listing_widgets.dart'; Classes=@('_MediaButton','_PhotoThumb','_TypeCard','_ListingTypeOption','_CameraMenuBtn') }
    @{ Name='video_thumb.dart'; Classes=@('_VideoThumb') }
  ) }
  @{ File='lib/widgets/widgets.dart'; Dir='parts'; Parts=@(
    @{ Name='property_card.dart'; Classes=@('PropertyCard','_VerticalCard','_HorizontalCard','_TypeBadge','FavoriteButton') }
    @{ Name='share_widgets.dart'; Classes=@('ShareButton','_ShareSheet','_MoreShareSheet','_ShareOption','_ShareOptionCustom','_WhatsAppIcon','_WhatsAppPainter','_InstagramIcon','_InstagramPainter') }
    @{ Name='basic_widgets.dart'; Classes=@('SectionHeader','CustomAppBar','UserAvatar','EmptyState','StatCard','LoadingCard','AppTextField','PrimaryButton') }
  ) }
  @{ File='lib/screens/agent_workspace_screen.dart'; Dir='agent_workspace'; Parts=@(
    @{ Name='report_sheet.dart'; Classes=@('_ReportSheet') }
    @{ Name='tabs.dart'; Classes=@('_EarningsTab','_AvailabilityTab') }
    @{ Name='settings_screen.dart'; Classes=@('_AgentSettingsScreen') }
  ) }
  @{ File='lib/screens/my_listings_screen.dart'; Dir='my_listings'; Parts=@(
    @{ Name='listing_cards.dart'; Classes=@('_ListingManageCard','_PendingPropertyCard') }
    @{ Name='availability_history_sheet.dart'; Classes=@('_AvailabilityHistorySheet') }
  ) }
  @{ File='lib/screens/admin_tabs/admin_ops_tab.dart'; Dir='admin_ops'; Parts=@(
    @{ Name='missions_panel.dart'; Classes=@('_MissionsPanel') }
    @{ Name='pricing_panel.dart'; Classes=@('_PriceField','_PricingPanel','_PricingForm') }
    @{ Name='finance_panel.dart'; Classes=@('_FinancePanel','_PayoutsPanel','_AuditPanel') }
  ) }
)

function Split-Lines([string]$text) {
  $list = New-Object System.Collections.Generic.List[string]
  foreach ($s in [regex]::Split($text, '(?<=\n)')) {
    if ($s.Length -gt 0) { $list.Add($s) }
  }
  return ,$list
}

# Empreinte du contenu : lignes non vides (hors lignes `part`), triées, hachées.
function Get-Fingerprint([string[]]$texts) {
  $all = New-Object System.Collections.Generic.List[string]
  foreach ($t in $texts) {
    foreach ($l in ($t -split "`r?`n")) {
      $x = $l.Trim()
      if ($x.Length -gt 0 -and -not $x.StartsWith("part '") -and -not $x.StartsWith("part of '")) { $all.Add($x) }
    }
  }
  $arr = $all.ToArray()
  [Array]::Sort($arr, [StringComparer]::Ordinal)
  $sha = [System.Security.Cryptography.SHA256]::Create()
  $hash = [BitConverter]::ToString($sha.ComputeHash($utf8.GetBytes([string]::Join("`n", $arr))))
  return "$hash/$($arr.Length)"
}

function Invoke-Split($spec) {
  $rel = $spec.File
  $path = Join-Path $root $rel
  if (-not (Test-Path $path)) { Write-Host "  ! introuvable : $rel" -ForegroundColor Yellow; return $false }

  $text = [System.IO.File]::ReadAllText($path)
  if ($text -match "(?m)^part\s+'") { Write-Host "  = déjà découpé : $rel" -ForegroundColor DarkGray; return $true }

  $eol = "`n"
  if ($text.Contains("`r`n")) { $eol = "`r`n" }
  $lines = Split-Lines $text
  if (-not $lines[$lines.Count - 1].EndsWith("`n")) { $lines[$lines.Count - 1] = $lines[$lines.Count - 1] + $eol }

  # 1. Repérer les déclarations de niveau supérieur (avec les commentaires / annotations qui les précèdent).
  $starts = New-Object System.Collections.Generic.List[int]
  $names = New-Object System.Collections.Generic.List[string]
  for ($i = 0; $i -lt $lines.Count; $i++) {
    $m = [regex]::Match($lines[$i].TrimEnd("`r", "`n"), $declRx)
    if ($m.Success) {
      $j = $i
      while ($j -gt 0) {
        $t = $lines[$j - 1].Trim()
        if ($t.StartsWith('//') -or $t.StartsWith('@')) { $j-- } else { break }
      }
      $starts.Add($j)
      $names.Add($m.Groups[1].Value)
    }
  }
  if ($starts.Count -eq 0) { Write-Host "  ! aucune classe trouvée : $rel" -ForegroundColor Yellow; return $false }

  # 2. Affecter chaque bloc (classe + sa classe State) à un fichier part.
  $assigned = @{}
  $found = @{}
  foreach ($part in $spec.Parts) {
    $cl = $part.Classes
    for ($k = 0; $k -lt $names.Count; $k++) {
      $n = $names[$k]
      if ($cl -contains $n) { $assigned[$k] = $part.Name; $found[$n] = $true }
      elseif ($n.EndsWith('State')) {
        $b = $n.Substring(0, $n.Length - 5)
        if (($cl -contains $b) -or ($cl -contains $b.TrimStart('_'))) { $assigned[$k] = $part.Name }
      }
    }
    foreach ($c in $cl) {
      if (-not $found.ContainsKey($c)) {
        Write-Host "  ! classe '$c' introuvable dans $rel : fichier laissé intact" -ForegroundColor Yellow
        return $false
      }
    }
  }

  # 3. Fin du dernier import/export de l'en-tête (les directives `part` viennent juste après).
  $last = -1
  for ($i = 0; $i -lt $starts[0]; $i++) {
    if ($lines[$i] -match '^\s*(import|export)\s') {
      $last = $i
      while (($lines[$last] -notmatch ';') -and ($last -lt $starts[0] - 1)) { $last++ }
    }
  }
  if ($last -lt 0) { Write-Host "  ! aucun import trouvé : $rel" -ForegroundColor Yellow; return $false }

  # 4. Construire le fichier principal et les fichiers part.
  $parentName = Split-Path $path -Leaf
  $parent = New-Object System.Collections.Generic.List[string]
  for ($i = 0; $i -le $last; $i++) { $parent.Add($lines[$i]) }
  $parent.Add($eol)
  foreach ($part in $spec.Parts) { $parent.Add("part '" + $spec.Dir + "/" + $part.Name + "';" + $eol) }
  for ($i = $last + 1; $i -lt $starts[0]; $i++) { $parent.Add($lines[$i]) }

  $partLines = @{}
  foreach ($part in $spec.Parts) {
    $pl = New-Object System.Collections.Generic.List[string]
    $pl.Add("part of '../" + $parentName + "';" + $eol)
    $pl.Add($eol)
    $partLines[$part.Name] = $pl
  }
  for ($k = 0; $k -lt $names.Count; $k++) {
    $first = $starts[$k]
    $lastLine = $lines.Count - 1
    if ($k + 1 -lt $starts.Count) { $lastLine = $starts[$k + 1] - 1 }
    if ($assigned.ContainsKey($k)) { $target = $partLines[$assigned[$k]] } else { $target = $parent }
    for ($i = $first; $i -le $lastLine; $i++) { $target.Add($lines[$i]) }
  }

  $dir = Join-Path (Split-Path $path -Parent) $spec.Dir
  Write-Host "  $rel : $($lines.Count) lignes -> $($parent.Count) (principal) + $($spec.Parts.Count) fichier(s) part" -ForegroundColor Green
  foreach ($part in $spec.Parts) { Write-Host ("      {0}/{1} ({2} lignes)" -f $spec.Dir, $part.Name, $partLines[$part.Name].Count) }
  if ($DryRun) { return $true }

  # 5. Écrire, relire et vérifier ; restaurer en cas d'écart.
  if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
  foreach ($part in $spec.Parts) {
    [System.IO.File]::WriteAllText((Join-Path $dir $part.Name), ($partLines[$part.Name] -join ''), $utf8)
  }
  [System.IO.File]::WriteAllText($path, ($parent -join ''), $utf8)

  $back = New-Object System.Collections.Generic.List[string]
  $back.Add([System.IO.File]::ReadAllText($path))
  foreach ($part in $spec.Parts) { $back.Add([System.IO.File]::ReadAllText((Join-Path $dir $part.Name))) }
  if ((Get-Fingerprint @($text)) -ne (Get-Fingerprint $back.ToArray())) {
    Write-Host "  ✗ vérification échouée pour $rel : restauration de l'original" -ForegroundColor Red
    [System.IO.File]::WriteAllText($path, $text, $utf8)
    foreach ($part in $spec.Parts) { Remove-Item (Join-Path $dir $part.Name) -Force -ErrorAction SilentlyContinue }
    return $false
  }
  return $true
}

# ─── Vérifications préalables ───────────────────────────────────────────────
Write-Host "`n=== Étape 7 : découpage des écrans Flutter ===" -ForegroundColor Cyan
if (-not (Test-Path (Join-Path $root 'pubspec.yaml')) -or -not (Test-Path (Join-Path $root 'lib'))) {
  throw "pubspec.yaml ou lib\ introuvable. Lancez ce script depuis la racine du projet Flutter."
}
if (-not $Force -and -not $DryRun -and (Test-Path (Join-Path $root '.git')) -and (Get-Command git -ErrorAction SilentlyContinue)) {
  $dirty = git status --porcelain -- lib
  if ($dirty) {
    throw "Des modifications non enregistrées existent dans lib\. Enregistrez-les d'abord (git add -A ; git commit -m `"avant étape 7`") ou relancez avec -Force."
  }
}
if ($DryRun) { Write-Host "(simulation : rien ne sera écrit)" -ForegroundColor Yellow }

$ok = 0
$ko = 0
foreach ($spec in $plan) {
  if (Invoke-Split $spec) { $ok++ } else { $ko++ }
}

Write-Host "`nTerminé : $ok fichier(s) traité(s), $ko en échec." -ForegroundColor Cyan
if ($ko -gt 0) { Write-Host "Les fichiers en échec sont restés intacts : copiez les messages ci-dessus dans la discussion." -ForegroundColor Yellow }
if (-not $DryRun) {
  Write-Host "`nÀ faire maintenant :" -ForegroundColor Cyan
  Write-Host "  flutter analyze                       # doit donner le même résultat qu'avant"
  Write-Host "  flutter run -d chrome                 # vérification visuelle rapide"
  Write-Host "  git add -A ; git commit -m `"refactor: découpage des écrans en fichiers part (étape 7)`""
  Write-Host "`nPour tout annuler (si vous aviez enregistré avant) :" -ForegroundColor DarkGray
  Write-Host "  git checkout -- lib ; git clean -fd lib" -ForegroundColor DarkGray
}
