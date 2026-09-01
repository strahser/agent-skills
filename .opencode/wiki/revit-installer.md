# Revit Installer (WixSharp) — шаблоны и грабли

Сборка MSI для Revit-плагинов через `WixSharp` (`install\Installer.cs` + `Installer.Generator.cs`). Проверено на `MepTaggingSolution` 2026-08-31 (версия 1.0.1).

## Быстрый старт

```powershell
# 1. Собрать плагин
dotnet build MepTaggingSolution.sln -c Release

# 2. Собрать установщик (dotnet, без Nuke)
dotnet build install\Installer.csproj -c Release
& install\bin\Release\Installer.exe MepTagging\bin\Release\net48
# -> output\MepTaggingSolution-1.0.1-SingleUser.msi
# -> output\MepTaggingSolution-1.0.1-MultiUser.msi

# 3. Через Nuke (использует Build.Configuration.Version)
nuke CreateInstaller --configuration Release
# или build.cmd / build.ps1
```

Работает только из корня решения (`D:\Projects\MepTaggingSolution`), т.к. `BannerImage = install\Resources\...` — относительный путь.

## Структура

```
install\
  Installer.cs              # ManagedProject / Project, MajorUpgrade, Actions, WixSourceGenerated
  Installer.Generator.cs    # GenerateWixEntities() — сканирует bin\Release\net48, MepTagging.addin, Resources
  Installer.csproj          # net48, WixSharp.bin 1.*, WixSharp.wix.bin 3.*, Version/AssemblyVersion
  CustomActions.cs          # CleanPreviousInstall(Session)
  Resources\Icons\...       # BannerImage, BackgroundImage, ShellIcon.ico
output\*.msi                # SingleUser (perUser %AppDataFolder%) и MultiUser (perMachine %CommonAppDataFolder%)
```

`Generator` определяет версию Revit по имени папки (`20\d{2}` или `R24`/`R25`), создает `Dir(Id="INSTALL2024", Name="2024")` + `Dir(Id="MepTagging_2024", Name="MepTagging")` + `File(MepTagging.addin)`.

## Версионирование

- `build\Build.Configuration.cs:5` `const string Version = "1.0.1"` — источник для Nuke `SetVersion`.
- `install\Installer.csproj:10` `<Version>1.0.1</Version>` + `AssemblyVersion`/`FileVersion` — для `dotnet build` без Nuke (`Assembly.GetExecutingAssembly().GetName().Version` в `Installer.cs:17`).
- `Changelog.md` — добавить секцию `## 1.0.1`.
- `ProductId` — **обязательно** `Guid.NewGuid()` на каждую сборку (иначе переустановка той же версии с тем же `ProductId` уйдет в maintenance, а не major upgrade). `UpgradeCode` фиксирован `{5F0DFBAB-...}`.

```csharp
singleProject.ProductId = Guid.NewGuid();
multiProject.ProductId = Guid.NewGuid();
```

## MajorUpgrade — дружелюбная переустановка без "Уже установлена другая версия"

Ошибка `Уже установлена другая версия этого продукта. Продолжение установки невозможно.` — `MajorUpgrade.Default` (`AllowSameVersionUpgrades=false`). При новой сборке с тем же `Version=1.0.0` но новым `ProductId` MSI блокируется.

Фикс `install\Installer.cs:28`:

```csharp
MajorUpgrade = new MajorUpgrade {
  AllowSameVersionUpgrades = true,               // 1.0.1 -> 1.0.1 считается upgrade
  DowngradeErrorMessage = "A later version of [ProductName] is already installed. Setup will now exit.",
  IgnoreRemoveFailure = true,
  Schedule = UpgradeSchedule.afterInstallInitialize // RemoveExistingProducts до InstallFiles
}
```

- `AllowSameVersionUpgrades` и `AllowDowngrades` нельзя одновременно `true` (Wix `CNDL0035`). Для `1.0.1` достаточно `AllowSameVersionUpgrades`.
- `Schedule.afterInstallInitialize` — удаляет старую версию рано, до копирования новых файлов.
- Проверка WXS: `<MajorUpgrade AllowSameVersionUpgrades="yes" ... />`, `Upgrade` таблица: `Min=, Max=1.0.1` и `Min=1.0.1, Max=`.

Установка `msiexec /i .../1.0.1-SingleUser.msi /qn /L*V log.log` теперь:
`FindRelatedProducts` `1`, `RemoveExistingProducts` `1`, смена `ProductId {5F0DFBAB-...22CE3018} -> {135A0A26-...}` без диалога.

## Чистая установка — удаление артефактов

Требование: перед копированием удалить `MepTagging.addin` и каталог `MepTagging` (иначе остаются DLL от Yandex.Disk / старой версии).

Два уровня, работают даже если один откажет:

**1. Нативный MSI (`WixSourceGenerated`, без `WixUtilExtension`):**

```csharp
void AttachCleanHandler(WixProject proj) {
  proj.WixSourceGenerated += doc => {
    var ns = XNamespace.Get("http://schemas.microsoft.com/wix/2006/wi");
    // для каждого INSTALL2024
    var cleanId = $"CleanMepTagging_{ver}";
    new XElement(ns+"Component", new XAttribute("Id", cleanId), new XAttribute("Guid","*"),
      new XElement(ns+"RegistryValue", ... KeyPath="yes"),
      new XElement(ns+"RemoveFile", new XAttribute("Id",$"RemoveAddin_{ver}"), new XAttribute("Name","MepTagging.addin"), new XAttribute("On","install"))
    );
    // + второй компонент для MepTagging_2024: RemoveFile *.* On=install
  };
}
```

`Id="MepTagging_2024"` задается в `Generator.cs:130`: `new Dir(new Id($"MepTagging_{ver}"), "MepTagging", ...)`.

**2. Managed (`CustomActions.cs`):**

```csharp
public class CustomActions {
  [CustomAction]
  public static ActionResult CleanPreviousInstall(Session session) {
    foreach (var ver in new[]{"2024","2025","2026","2027","2028"}) {
      var baseDir = session["INSTALL"+ver]; // %AppData% или %CommonAppData%
      File.Delete(Path.Combine(baseDir, "MepTagging.addin"));
      Directory.Delete(Path.Combine(baseDir, "MepTagging"), true);
    }
    return ActionResult.Success;
  }
}
```

Планирование:

```csharp
// perUser: только immediate (deferred System -> SFXCA error 5)
// perMachine: deferred System + immediate
WixProject singleProject = new Project { ... }; // plain, без SFXCA
var multiProject = new ManagedProject { ... };
multiProject.Actions = new WixSharp.Action[] {
  new ElevatedManagedAction(CustomActions.CleanPreviousInstall, Return.ignore, When.Before, Step.InstallFiles, Condition.Always) { Execute=Execute.deferred, Impersonate=false },
  new ManagedAction(CustomActions.CleanPreviousInstall, Return.ignore, When.Before, Step.InstallFiles, Condition.Always)
};
```

**Важно:** `Project` (perUser) нельзя делать `ManagedProject` с `ElevatedManagedAction` — `WixSharp_InitRuntime` падает `SFXCA: Failed to create temp directory. Error 5` без прав администратора. Поэтому `singleProject = new Project`, `multiProject = new ManagedProject`.

Размеры: `SingleUser ~1.5MB` (без CA DLL), `MultiUser ~2.4MB` (с CA).

## WPF Pack URI — грабли `ResourceDictionary.Source`

Ошибка `Задание свойства "System.Windows.ResourceDictionary.Source" вызвало исключение.` при запуске через установщик, в debug из VS работает.

Причина `MepTagging.UI\UI\Views\*.xaml:9`:

```xml
<ResourceDictionary Source="pack://application:,,,/MepTagging;component/Base/Styles.xaml" />
```

`Styles.xaml` лежит в `MepTagging.UI\Base\Styles.xaml` (`MepTagging.UI.csproj:27` `<Resource Include="Base\Styles.xaml"/>`), сборка `MepTagging.UI.dll`, не `MepTagging.dll`.

Фикс: во всех 7 файлах `MepTagging` → `MepTagging.UI`:

- `TaggingWindow.xaml:13`, `ViewSelector.xaml:10`, `TagTypeSelector.xaml:9`, `CategorySelector.xaml:9`, `InputDialog.xaml:9`, `CustomDialog.xaml:13`, `CategoryManagementControl.xaml:7`

```xml
<ResourceDictionary Source="pack://application:,,,/MepTagging.UI;component/Base/Styles.xaml" />
```

Проверка: `strings MepTagging.UI.dll` содержит `MepTagging.UI;component`, не `MepTagging;component`. `UseWPF=true`, `Resource` vs `Page` — оба работают, но `Page` (BAML) предпочтительнее.

## Тестирование установщика

```powershell
# проверить установлен ли продукт
Get-WmiObject Win32_Product | ? Name -like '*MepTagging*'

# тихая установка с логом
msiexec /i output\MepTaggingSolution-1.0.1-SingleUser.msi /qn /L*V C:\Temp\install.log
Get-Content C:\Temp\install.log | Select-String "FindRelatedProducts|RemoveExistingProducts|CleanPreviousInstall|Another version"

# удаление
msiexec /x "{PRODUCT-GUID}" /qn

# проверка RemoveFile
$installer = New-Object -ComObject WindowsInstaller.Installer
$db = $installer.OpenDatabase("output\...SingleUser.msi",0)
$view = $db.OpenView("SELECT FileKey, Component_, FileName FROM RemoveFile")
$view.Execute(); while($rec=$view.Fetch()){ $rec.StringData(1) }
```

## Чек-лист перед релизом

- [ ] `build\Build.Configuration.cs` `Version` и `install\Installer.csproj` `Version` совпадают (например `1.0.1`)
- [ ] `MepTagging.UI` XAML pack URI → `MepTagging.UI`
- [ ] `Generator.cs` `MepTagging_{ver}` Id, `CustomActions.cs` покрывает 2024-2028
- [ ] `singleProject = new Project` (perUser), `multiProject = new ManagedProject` (perMachine) + `ProductId = Guid.NewGuid()`
- [ ] `MajorUpgrade.AllowSameVersionUpgrades=true`
- [ ] `dotnet build MepTaggingSolution.sln -c Release` и `Installer.exe` из корня без ошибок `CNDL0103`/`CNDL0062`
- [ ] `msiexec /qn` переустановка той же версии — без `1638`, `RemoveExistingProducts` `1`

## Связанные страницы

- Локально: `MepTaggingSolution\.opencode\wiki\installer-wpf-fixes.md` — история фиксов 1.0.1 (MepTaggingSolution)
- Скилл: `.opencode/skills/revit-installer/SKILL.md`
