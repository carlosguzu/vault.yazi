# vault.yazi

A native [Yazi](https://github.com/sxyazi/yazi) plugin to manage, mount, and navigate encrypted directories powered by **gocryptfs** directly inside your terminal file manager.

## Features

- **100% Native TUI**: Uses Yazi's built-in floating prompt (`ya.input` with `obscure = true`) to enter passwords with masked input (`*`). No external scripts or popups required.
- **Completely Invisible When Locked**:
  - The encrypted ciphertext lives in `~/.Vault.encrypted` (hidden dotfile).
  - The mountpoint directory `~/Vault` is created dynamically on unlock and removed on unmount. When locked, it does not exist on disk at all.
- **Secure Password Handling**: Passes the passphrase securely through an internal memory pipe (`-passfile /dev/stdin`) without writing plain text to disk or command-line arguments.
- **Auto-Navigation**:
  - Automatically navigates into `~/Vault` when unlocked.
  - Automatically steps out to `$HOME` before locking to avoid `EBUSY` (folder busy) unmount errors.
- **Safe Fallback**: Tries standard unmount (`fusermount -u`), falling back to lazy unmount (`-z`) if any background process holds a handle.
- **Native Notifications**: Shows status updates and clean error messages directly inside Yazi with `ya.notify`.

---

## Dependencies

This plugin requires **`gocryptfs`** and **`fuse`** (`fusermount`):

### Arch Linux / Manjaro
```bash
sudo pacman -S gocryptfs fuse3
```

### Ubuntu / Debian / Pop!_OS / Linux Mint
```bash
sudo apt install gocryptfs fuse3
```

### Fedora / RHEL
```bash
sudo dnf install gocryptfs fuse3
```

### NixOS
Add to `configuration.nix` or `home.nix`:
```nix
environment.systemPackages = with pkgs; [
  gocryptfs
  fuse
];
```

### macOS (via Homebrew)
```bash
brew install --cask macfuse
brew install gocryptfs
```

---

## First-time Initialization

Run this once in your terminal to initialize your encrypted vault and choose your master password:

```bash
mkdir -p ~/.Vault.encrypted
gocryptfs -init ~/.Vault.encrypted
```

> **Warning:** Save the master recovery key printed by `gocryptfs -init` in a safe offline location.

---

## Installation

### Using Yazi Package Manager

```sh
ya pkg add carlosguzu/vault
```

### Using Git

Clone the repository directly into your Yazi plugins directory:

```sh
git clone https://github.com/carlosguzu/vault.yazi.git ~/.config/yazi/plugins/vault.yazi
```

---

## Configuration

Add the keybindings to your `~/.config/yazi/keymap.toml`:

```toml
[[mgr.prepend_keymap]]
on   = [ "u", "v" ]
run  = "plugin vault"
desc = "Toggle encrypted vault (lock / unlock)"

[[mgr.prepend_keymap]]
on   = [ "g", "V" ]
run  = "plugin vault cd"
desc = "Go to Vault (unlock if needed)"
```

---

## Usage

| Keybinding | Action | Description |
|---|---|---|
| `g` `V` | `plugin vault cd` | **Go to Vault**: Jumps straight to `~/Vault` if already mounted. If locked, prompts for password and enters. |
| `u` `v` | `plugin vault` | **Toggle Vault**: If locked, asks for password and enters `~/Vault`. If unlocked, exits folder, unmounts, and removes the mountpoint directory. |

---

## Directory Structure

- **Ciphertext (Hidden scrambled data):** `~/.Vault.encrypted`
- **Plaintext (Mountpoint):** `~/Vault` *(only exists while unlocked)*

---

## License

This plugin is MIT-licensed. See [LICENSE](LICENSE) for details.
