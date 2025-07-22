{ host, ... }:
{
  # The hostname of your system, as visible from the command line and used by local and remote networks when connecting through SSH and Remote Login.
  networking.hostName = host.hostname; # scutil --set HostName

  # The user-friendly name for the system, set in Preferences > General > About > Name.
  networking.computerName = host.hostname; # scutil --set ComputerName

  # The local hostname, or local network name, set in Preferences > General > Sharing > Local hostname.
  # It identifies your Mac to Bonjour-compatible services.
  networking.localHostName = host.hostname; # scutil --set LocalHostName
}
