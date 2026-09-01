---
name: revit-installer
description: >
  Build and test WixSharp MSI installers for Revit add-ins (MepTagging pattern).
  USE FOR: creating perUser/perMachine MSI, MajorUpgrade same-version friendly reinstall,
  clean install (RemoveFile + managed CleanPreviousInstall), WPF pack URI fixes.
  DO NOT USE FOR: general Revit API modeling.
license: MIT
---

# Revit Installer (WixSharp)

Шаблон сборки MSI для Revit-плагинов, отработан на `MepTaggingSolution` 1.0.1. Делает переустановку дружелюбной (без "Уже установлена другая версия") и чистит артефакты.

## When to use

- Сборка `SingleUser` (`%AppDataFolder%`) и `MultiUser` (`%CommonAppDataFolder%`) из `MepTagging\bin\Release\net48`
- Нужна переустановка той же версии без ручного удаления
- Нужно удалить `MepTagging.addin` + `MepTagging\` перед копированием

## When not to use

- Чистое Revit API без установщика
- Отдельные `exe`/`msix` вне WixSharp

## Quick Build

```powershell
dotnet build MepTaggingSolution.sln -c Release
dotnet build install\Installer.csproj -c Release
& install\bin\Release\Installer.exe MepTagging\bin\Release\net48
# из корня решения, иначе BannerImage  CNDL0103
```

Nuke: `nuke CreateInstaller` (берет `build\Build.Configuration.cs:Version`).

## Version

- `build\Build.Configuration.cs:5` `const string Version = "1.0.1"`
- `install\Installer.csproj` `<Version>1.0.1</Version>` + `AssemblyVersion`/`FileVersion`
- `Version` в `Installer.cs:17` = `Assembly.GetExecutingAssembly().GetName().Version.ClearRevision()`
- Каждый MSI: `ProductId = Guid.NewGuid()` (иначе переустановка той же версии уйдет в maintenance, а не major upgrade)

## MajorUpgrade — дружелюбно

```csharp
MajorUpgrade = new MajorUpgrade {
  AllowSameVersionUpgrades = true, // 1.0.1 -> 1.0.1 считается upgrade
  DowngradeErrorMessage = "A later version of [ProductName] is already installed. Setup will now exit.",
  IgnoreRemoveFailure = true,
  Schedule = UpgradeSchedule.afterInstallInitialize
}
```

`AllowSameVersionUpgrades` и `AllowDowngrades` нельзя вместе `true` (`CNDL0035`). Проверка WXS: `<MajorUpgrade AllowSameVersionUpgrades="yes" .../>`.

## Clean Install — два уровня

**WixSourceGenerated (нативный, без WixUtilExtension):**

```csharp
// Generator.cs:130  new Dir(new Id($"MepTagging_{ver}"), "MepTagging", ...)
void AttachCleanHandler(WixProject proj) {
  proj.WixSourceGenerated += doc => {
    // INSTALL2024 -> CleanMepTagging_2024: RemoveFile MepTagging.addin On=install
    // MepTagging_2024 -> CleanMepTaggingFiles_2024: RemoveFile *.* On=install
  };
}
```

**Managed (`install\CustomActions.cs`):**

```csharp
[CustomAction] public static ActionResult CleanPreviousInstall(Session s) {
  foreach(var ver in new[]{"2024","2025","2026","2027","2028"}) {
    var baseDir = s["INSTALL"+ver];
    File.Delete(Path.Combine(baseDir, "MepTagging.addin"));
    Directory.Delete(Path.Combine(baseDir, "MepTagging"), true);
  }
  return ActionResult.Success;
}
```

Планирование с разделением perUser/perMachine (иначе `SFXCA: Failed to create temp directory. Error 5` для perUser):

```csharp
WixProject singleProject = new Project { ... }; // perUser, без ManagedAction
var multiProject = new ManagedProject { ... }; // perMachine
multiProject.Actions = new WixSharp.Action[] {
  new ElevatedManagedAction(CustomActions.CleanPreviousInstall, Return.ignore, When.Before, Step.InstallFiles, Condition.Always) { Execute=Execute.deferred, Impersonate=false },
  new ManagedAction(CustomActions.CleanPreviousInstall, Return.ignore, When.Before, Step.InstallFiles, Condition.Always)
};
```

Размеры: SingleUser ~1.5MB, MultiUser ~2.4MB.

## WPF Pack URI

Ошибка `ResourceDictionary.Source` при запуске из `ProgramData`/`AppData`, в VS работает:

```xml
<!-- плохо -->
<ResourceDictionary Source="pack://application:,,,/MepTagging;component/Base/Styles.xaml" />
<!-- хорошо -->
<ResourceDictionary Source="pack://application:,,,/MepTagging.UI;component/Base/Styles.xaml" />
```

`Base\Styles.xaml` лежит в `MepTagging.UI` (`MepTagging.UI.csproj` `<Resource Include="Base\Styles.xaml"/>`), сборка `MepTagging.UI.dll`. Проверить 7 файлов: `TaggingWindow.xaml`, `ViewSelector.xaml`, `TagTypeSelector.xaml`, `CategorySelector.xaml`, `InputDialog.xaml`, `CustomDialog.xaml`, `CategoryManagementControl.xaml`.

## Validation

- [ ] `msiexec /i output\...SingleUser.msi /qn /L*V log` — `FindRelatedProducts` `1`, `RemoveExistingProducts` `1`, без `1638`
- [ ] `Select-String WXS MajorUpgrade` содержит `AllowSameVersionUpgrades="yes"`
- [ ] `Get-Content Msi RemoveFile` содержит `RemoveAddin_2024` и `RemoveMepTaggingContent_2024`
- [ ] `strings MepTagging.UI.dll` содержит `MepTagging.UI;component`, не `MepTagging;component`

## Pitfalls

| Pitfall | Fix |
|---------|-----|
| `CNDL0103 BannerImage` | Запускать `Installer.exe` из корня (`workdir = D:\Projects\MepTaggingSolution`) |
| `CNDL0062 Component/@Directory` | `Component` внутри `Directory` — не ставить `Directory="INSTALL..."` атрибут |
| `CNDL0035 AllowSameVersion + AllowDowngrades` | Оставить только `AllowSameVersionUpgrades` |
| `CNDL0010 DowngradeErrorMessage required` | Задать сообщение, если `AllowDowngrades` false |
| `ValidateBackgroundImage` | `ValidateBackgroundImage=false` для `BannerImage` 156x312 |
| `SFXCA error 5` perUser | `singleProject = new Project` (plain), без `ElevatedManagedAction` |

## References

- Wiki: `.opencode/wiki/revit-installer.md`, проектная `MepTaggingSolution\.opencode\wiki\installer-wpf-fixes.md`
- Исходник: `MepTaggingSolution\install\Installer.cs`, `CustomActions.cs`, `Installer.Generator.cs`
