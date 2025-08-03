{
  config,
  lib,
  pkgs,
  name,
  package ? pkgs.vscode,
  configDir ? "${config.home.homeDirectory}/Library/Application Support/Code",
  userConfigDir ? "${configDir}/User",
  enable ? true,
  enableUpdateCheck ? null,
  enableExtensionUpdateCheck ? null,
  mutableExtensionsDir ? null,
  userDataDir ? null,
  extensionsDir ? null,
  globalSnippetsDir ? null,
  userSnippetsDir ? null,
  keybindings ? [ ],
  settings ? { },
  userSettings ? null,
  workspaceSettings ? null,
  folderSettings ? null,
  extensions ? [ ],
  language ? null,
  extraArgs ? [ ],
  extraWrapperArgs ? [ ],
  mimeTypes ? { },
  associations ? { },
  policies ? { },
  profiles ? { },
  ...
}:
let
  cfg = {
    inherit
      enable
      enableUpdateCheck
      enableExtensionUpdateCheck
      mutableExtensionsDir
      userDataDir
      extensionsDir
      globalSnippetsDir
      userSnippetsDir
      keybindings
      settings
      userSettings
      workspaceSettings
      folderSettings
      extensions
      language
      extraArgs
      extraWrapperArgs
      mimeTypes
      associations
      policies
      profiles
      ;
  };

  # Helper function to merge profile configurations
  mergeProfileConfig =
    baseProfile: profileOverrides: lib.recursiveUpdate baseProfile profileOverrides;

  # Default profile configuration
  defaultProfile = {
    keybindings = [ ];
    settings = { };
    extensions = [ ];
  };

  # Process profiles with inheritance
  processedProfiles = lib.mapAttrs (
    profileName: profileConfig:
    let
      # If profile extends another profile, merge them
      finalConfig =
        if profileConfig ? extends && profiles ? ${profileConfig.extends} then
          mergeProfileConfig profiles.${profileConfig.extends} (
            lib.filterAttrs (k: v: k != "extends") profileConfig
          )
        else
          profileConfig;
    in
    mergeProfileConfig defaultProfile finalConfig
  ) profiles;

  # Generate VS Code configuration
  vscodeConfig = {
    programs.vscode = {
      inherit
        enable
        enableUpdateCheck
        enableExtensionUpdateCheck
        mutableExtensionsDir
        userDataDir
        extensionsDir
        globalSnippetsDir
        userSnippetsDir
        keybindings
        settings
        userSettings
        workspaceSettings
        folderSettings
        extensions
        language
        extraArgs
        extraWrapperArgs
        mimeTypes
        associations
        policies
        profiles
        ;
    };
  };

  # Generate home packages if package is specified
  homePackages = lib.optional (package != null) {
    home.packages = [ package ];
  };

  # Generate activation scripts for macOS-specific settings
  activationScripts = lib.optional (config.system ? darwin) {
    home.activation = {
      "${name}VimModeKeyRepeat" = lib.hm.dag.entryAfter [ "installPackages" "vscodeProfiles" ] ''
        /usr/bin/defaults write com.microsoft.VSCode ApplePressAndHoldEnabled -bool false
      '';
    };
  };

  # Generate file associations for macOS
  fileAssociations = lib.optional (config.system ? darwin && associations != { }) {
    system.defaults.NSGlobalDomain."NSNavLastRootDirectory" = "~/";
  };

  # Generate mime type associations
  mimeTypeAssociations = lib.optional (mimeTypes != { }) {
    xdg.mimeApps.defaultApplications = mimeTypes;
  };

  # Generate settings file if userSettings is provided
  settingsFile = lib.optional (userSettings != null) {
    xdg.configFile."${userConfigDir}/settings.json".source =
      config.lib.file.mkOutOfStoreSymlink userSettings;
  };

  # Generate keybindings file if keybindings are provided
  keybindingsFile = lib.optional (keybindings != [ ]) {
    xdg.configFile."${userConfigDir}/keybindings.json".source = config.lib.file.mkOutOfStoreSymlink (
      pkgs.writeText "keybindings.json" (builtins.toJSON keybindings)
    );
  };

  # Generate workspace settings if provided
  workspaceSettingsFile = lib.optional (workspaceSettings != null) {
    xdg.configFile."${userConfigDir}/workspaceStorage".source =
      config.lib.file.mkOutOfStoreSymlink workspaceSettings;
  };

  # Generate folder settings if provided
  folderSettingsFile = lib.optional (folderSettings != null) {
    xdg.configFile."${userConfigDir}/User/workspaceStorage".source =
      config.lib.file.mkOutOfStoreSymlink folderSettings;
  };

  # Generate snippets directories if provided
  snippetsDirs = lib.optional (globalSnippetsDir != null || userSnippetsDir != null) {
    xdg.configFile =
      lib.mkIf (globalSnippetsDir != null) {
        "${userConfigDir}/snippets".source = config.lib.file.mkOutOfStoreSymlink globalSnippetsDir;
      }
      // lib.mkIf (userSnippetsDir != null) {
        "${userConfigDir}/User/snippets".source = config.lib.file.mkOutOfStoreSymlink userSnippetsDir;
      };
  };

  # Generate policies file if policies are provided
  policiesFile = lib.optional (policies != { }) {
    xdg.configFile."${userConfigDir}/policies.json".source = pkgs.writeText "policies.json" (
      builtins.toJSON policies
    );
  };

  # Generate extensions configuration if extensions are provided
  extensionsConfig = lib.optional (extensions != [ ]) {
    xdg.configFile."${userConfigDir}/extensions/extensions.json".source =
      pkgs.writeText "extensions.json"
        (
          builtins.toJSON {
            recommendations = extensions;
          }
        );
  };

  # Generate language-specific settings
  languageSettings = lib.optional (language != null) {
    programs.vscode.languageSupport = {
      ${language} = {
        enable = true;
      };
    };
  };

  # Generate update check settings
  updateCheckSettings = lib.optional (enableUpdateCheck != null) {
    programs.vscode.enableUpdateCheck = enableUpdateCheck;
  };

  # Generate extension update check settings
  extensionUpdateCheckSettings = lib.optional (enableExtensionUpdateCheck != null) {
    programs.vscode.enableExtensionUpdateCheck = enableExtensionUpdateCheck;
  };

  # Generate mutable extensions directory settings
  mutableExtensionsDirSettings = lib.optional (mutableExtensionsDir != null) {
    programs.vscode.mutableExtensionsDir = mutableExtensionsDir;
  };

  # Generate user data directory settings
  userDataDirSettings = lib.optional (userDataDir != null) {
    programs.vscode.userDataDir = userDataDir;
  };

  # Generate extensions directory settings
  extensionsDirSettings = lib.optional (extensionsDir != null) {
    programs.vscode.extensionsDir = extensionsDir;
  };

  # Generate global snippets directory settings
  globalSnippetsDirSettings = lib.optional (globalSnippetsDir != null) {
    programs.vscode.globalSnippetsDir = globalSnippetsDir;
  };

  # Generate user snippets directory settings
  userSnippetsDirSettings = lib.optional (userSnippetsDir != null) {
    programs.vscode.userSnippetsDir = userSnippetsDir;
  };

  # Generate extra arguments settings
  extraArgsSettings = lib.optional (extraArgs != [ ]) {
    programs.vscode.extraArgs = extraArgs;
  };

  # Generate extra wrapper arguments settings
  extraWrapperArgsSettings = lib.optional (extraWrapperArgs != [ ]) {
    programs.vscode.extraWrapperArgs = extraWrapperArgs;
  };

  # Generate mime types settings
  mimeTypesSettings = lib.optional (mimeTypes != { }) {
    programs.vscode.mimeTypes = mimeTypes;
  };

  # Generate associations settings
  associationsSettings = lib.optional (associations != { }) {
    programs.vscode.associations = associations;
  };

  # Generate policies settings
  policiesSettings = lib.optional (policies != { }) {
    programs.vscode.policies = policies;
  };

  # Generate profiles settings
  profilesSettings = lib.optional (profiles != { }) {
    programs.vscode.profiles = processedProfiles;
  };

  # Generate user settings settings
  userSettingsSettings = lib.optional (userSettings != null) {
    programs.vscode.userSettings = userSettings;
  };

  # Generate workspace settings settings
  workspaceSettingsSettings = lib.optional (workspaceSettings != null) {
    programs.vscode.workspaceSettings = workspaceSettings;
  };

  # Generate folder settings settings
  folderSettingsSettings = lib.optional (folderSettings != null) {
    programs.vscode.folderSettings = folderSettings;
  };

  # Generate keybindings settings
  keybindingsSettings = lib.optional (keybindings != [ ]) {
    programs.vscode.keybindings = keybindings;
  };

  # Generate settings settings
  settingsSettings = lib.optional (settings != { }) {
    programs.vscode.settings = settings;
  };

  # Generate extensions settings
  extensionsSettings = lib.optional (extensions != [ ]) {
    programs.vscode.extensions = extensions;
  };

  # Generate language settings
  languageSettingsSettings = lib.optional (language != null) {
    programs.vscode.language = language;
  };

  # Combine all configurations
  combinedConfig = lib.mkMerge [
    vscodeConfig
    homePackages
    activationScripts
    fileAssociations
    mimeTypeAssociations
    settingsFile
    keybindingsFile
    workspaceSettingsFile
    folderSettingsFile
    snippetsDirs
    policiesFile
    extensionsConfig
    languageSettings
    updateCheckSettings
    extensionUpdateCheckSettings
    mutableExtensionsDirSettings
    userDataDirSettings
    extensionsDirSettings
    globalSnippetsDirSettings
    userSnippetsDirSettings
    extraArgsSettings
    extraWrapperArgsSettings
    mimeTypesSettings
    associationsSettings
    policiesSettings
    profilesSettings
    userSettingsSettings
    workspaceSettingsSettings
    folderSettingsSettings
    keybindingsSettings
    settingsSettings
    extensionsSettings
    languageSettingsSettings
  ];

in
combinedConfig
