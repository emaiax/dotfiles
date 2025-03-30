# Exit on error
set -e

# Request sudo upfront and keep it active
sudo -v
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

# This script uninstalls Nix from macOS and cleans up related files and configurations.
nix --extra-experimental-features "nix-command flakes" run nix-darwin#darwin-uninstaller

# Stop and remove the Nix daemon services
if [ -f /Library/LaunchDaemons/org.nixos.nix-daemon.plist ]; then
    echo "Unloading and removing org.nixos.nix-daemon..."

    sudo launchctl unload /Library/LaunchDaemons/org.nixos.nix-daemon.plist
    sudo rm /Library/LaunchDaemons/org.nixos.nix-daemon.plist
fi

if [ -f /Library/LaunchDaemons/org.nixos.darwin-store.plist ]; then
    echo "Unloading and removing org.nixos.darwin-store..."

    sudo launchctl unload /Library/LaunchDaemons/org.nixos.darwin-store.plist
    sudo rm /Library/LaunchDaemons/org.nixos.darwin-store.plist
fi

# Remove the nixbld group and the _nixbuildN users
if dscl . -read /Groups/nixbld >/dev/null 2>&1; then
    echo "Removing nixbld group..."
    sudo dscl . -delete /Groups/nixbld
fi

echo "Removing nixbld users..."
for u in $(sudo dscl . -list /Users | grep _nixbld); do
    sudo dscl . -delete /Users/"$u"
done

# Remove the /nix entry from /etc/fstab if it exists
echo "Cleaning up /etc/fstab..."
sudo sed -i '' '/\/nix/d' /etc/fstab

# Remove the Nix installation directory
echo "Removing Nix installation directory..."
sudo rm -rf /nix/store /nix/var

# Remove additional Nix-related files and configurations
echo "Removing additional Nix files..."
sudo rm -rf /etc/nix /var/root/.nix-profile /var/root/.nix-defexpr /var/root/.nix-channels
sudo rm -rf $HOME/.nix-profile $HOME/.nix-defexpr $HOME/.nix-channels

if [ -f /etc/synthetic.conf ]; then
    echo "Removing /etc/synthetic.conf..."
    sudo rm /etc/synthetic.conf
fi

# Try to remove the Nix storage volume if it exists
if diskutil list | grep -q "Nix"; then
    echo "Deleting Nix storage volume..."
    sudo diskutil apfs deleteVolume /nix
fi

# Invalidate sudo timestamp and finish
sudo -k
echo "Nix uninstallation complete."
