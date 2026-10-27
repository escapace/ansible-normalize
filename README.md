# ansible-normalize

Prepares CentOS Stream and Rocky Linux 9+ hosts for subsequent golden-image builds.
It creates an administrator account, updates packages, configures SELinux, and
switches boot-time networking to systemd-networkd. Changes to the kernel, SELinux,
networking, `/tmp`, or journald configuration can trigger one end-of-role reboot
before later image-build roles run. Reboots are skipped for `provider: ec2` and
Docker; those callers must arrange any required reboot.

Run with root privileges, gathered facts, and a systemd executable, including for
offline preparation. Ensure SSH-key access or another recovery method before
applying the default password locks.

## Variables

- `normalize_username` is a required nonempty account name. The role grants it
  passwordless sudo.
- `normalize_password` is an optional nonempty plaintext password secret, with no
  default. Store it in Ansible Vault or another secret store. Setting it updates
  the account password; omitting it uses the password-lock policy below.
- `normalize_key` has no default and accepts an SSH authorized-key string. Unset,
  `null`, empty, or whitespace-only values leave existing keys unchanged.
- `normalize_lock_user_password_when_undefined` defaults to `true`; it replaces the
  account password with a locked value when `normalize_password` is omitted.
  `false` preserves an existing password in that case.
- `normalize_lock_root_password` defaults to `true`. Setting it to `false` leaves
  root's current password-lock state unchanged; it does not unlock root.
- `normalize_selinux_state` defaults to `enforcing`; choices are `enforcing`,
  `permissive`, and `disabled`, using the targeted policy. Full disablement may
  also require the `selinux=0` kernel boot option.
- `normalize_tmp_mount_size` defaults to `"50%%"`. It accepts a native tmpfs size
  expression such as `1g` or `50%%`; escape percent signs as `%%` for systemd.
  The role configures `/tmp` with `nodev`, `noexec`, and `nosuid` for the next mount.
- `normalize_reboot_delay` defaults to `180`: the nonnegative wait in seconds
  after a reboot.
- `normalize_remove_ssh_host_keys` defaults to `true` and applies only to cleanup.
- `provider` has no default. `ec2` suppresses reboots; `vagrant_vmware` and
  `vagrant_qemu` add their respective guest setup. Other values use normal setup
  and reboot behavior.

```yaml
- name: prepare the image-build host
  hosts: image_builders
  become: true
  gather_facts: true
  roles:
    - role: ansible-normalize
      normalize_username: builder
      normalize_key: "{{ lookup('ansible.builtin.file', '~/.ssh/id_ed25519.pub') }}"
```

## Operational notes

Normalization removes all `cockpit*` packages without autoremoving unrelated
dependencies. It persistently masks `cockpit.socket` and `cockpit.service`, even
when the packages are absent, and stops active Cockpit units without starting
inactive ones. The masks prevent package presets from reactivating Cockpit after
a later reinstall.

The role disables NetworkManager at boot in favor of systemd-networkd, disables
Postfix and kdump, removes rsyslog, and configures volatile journal storage. It
enables `logrotate.timer` for file-based logs at boot without explicitly starting
it. Plan for these networking and logging changes before using it on an existing
host.

Normalization also removes `/var/lib/rsyslog/` and the regular files
`/var/log/cron`, `/var/log/maillog`, `/var/log/messages`, `/var/log/secure`, and
`/var/log/spooler`, including numbered or date-stamped rotations and their gzip
copies. It does not remove custom rsyslog destinations. The final cleanup step can
recreate empty versions of some of these standard log files.

Run `--tags normalize-cleanup` only as the final image-sealing step, after any
required reboot and SELinux relabeling. Cleanup refuses to run while `/.autorelabel`
exists. This skips normal normalization tasks; role argument validation still runs.
Cleanup removes
host identity, cloud-init state, logs, temporary files, and (by default) SSH host
keys; it also truncates `/etc/resolv.conf`, zero-fills free space, and wipes and
reformats detected swap. Do not run further provisioning afterward. The next boot
must regenerate host identity and SSH host keys. Cleanup is destructive and is not
intended for ordinary running systems.
