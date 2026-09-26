import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_theme.dart';
import '../../theme/app_icons.dart';
import '../../theme/demo_data.dart';
import '../../theme/app_widgets.dart';

/// Staff view — mirrors the HTML staff section (team list).
class StaffView extends ConsumerStatefulWidget {
  const StaffView({super.key});

  @override
  ConsumerState<StaffView> createState() => _StaffViewState();
}

class _StaffViewState extends ConsumerState<StaffView> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final d = demo;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        SectionCard(
          title: 'Team',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Pill.paid('${d.staff.length} members'),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: () => _showRoleManager(context),
                icon: const Icon(AppIcons.shield, size: 15),
                label: const Text('Roles & permissions'),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: () => _showStaffDialog(),
                icon: const Icon(AppIcons.plus, size: 16),
                label: const Text('Add staff'),
              ),
            ],
          ),
          bodyPadding: EdgeInsets.zero,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                color: isDark ? AppColors.darkCard2 : AppColors.card2,
                child: const Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        'Name',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'Role',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'Phone',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'Hired',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'Status',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              for (final s in d.staff)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: isDark ? AppColors.darkLine2 : AppColors.line2,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Row(
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFFF8A4C), AppColors.brand],
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                s.name
                                    .split(' ')
                                    .take(2)
                                    .map((w) => w[0])
                                    .join()
                                    .toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              s.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Pill(
                          s.role.toUpperCase(),
                          color: s.role == 'Owner'
                              ? AppColors.green
                              : s.role == 'Manager'
                              ? AppColors.blue
                              : s.role == 'Cashier'
                              ? AppColors.violet
                              : s.role == 'Chef'
                              ? AppColors.amber
                              : AppColors.teal,
                          background: s.role == 'Owner'
                              ? AppColors.greenT
                              : s.role == 'Manager'
                              ? AppColors.blueT
                              : s.role == 'Cashier'
                              ? AppColors.violetT
                              : s.role == 'Chef'
                              ? AppColors.amberT
                              : AppColors.tealT,
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          s.phone,
                          style: TextStyle(
                            color: isDark
                                ? AppColors.darkText2
                                : AppColors.text2,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          s.hired,
                          style: TextStyle(
                            color: isDark
                                ? AppColors.darkText2
                                : AppColors.text2,
                          ),
                        ),
                      ),
                      Expanded(
                        child: s.active
                            ? const Pill.paid('ACTIVE')
                            : const Pill.cancel('OFF DUTY'),
                      ),
                      SizedBox(
                        width: 40,
                        child: PopupMenuButton<String>(
                          icon: Icon(
                            AppIcons.sliders,
                            size: 17,
                            color: isDark
                                ? AppColors.darkText3
                                : AppColors.text3,
                          ),
                          onSelected: (v) {
                            if (v == 'edit') {
                              _showStaffDialog(member: s);
                            } else if (v == 'toggle') {
                              setState(() => s.active = !s.active);
                              demo.updateStaff(s);
                              showToast(
                                context,
                                s.active
                                    ? '${s.name} is now active'
                                    : '${s.name} set off duty',
                                icon: s.active ? AppIcons.check : AppIcons.x,
                              );
                            } else if (v == 'permissions') {
                              _showMemberPermissions(context, s);
                            } else if (v == 'password') {
                              _showChangePasswordDialog(s);
                            } else if (v == 'delete') {
                              _confirmRemoveStaff(context, s);
                            }
                          },
                          itemBuilder: (ctx) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Text('Edit member'),
                            ),
                            if (s.canLogIn)
                              const PopupMenuItem(
                                value: 'password',
                                child: Text('Change password'),
                              ),
                            const PopupMenuItem(
                              value: 'permissions',
                              child: Text('View permissions'),
                            ),
                            PopupMenuItem(
                              value: 'toggle',
                              child: Text(
                                s.active ? 'Set off duty' : 'Set active',
                              ),
                            ),
                            const PopupMenuDivider(),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text(
                                'Remove member',
                                style: TextStyle(color: AppColors.red),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// Confirms and performs removal of a staff member (deletes the DB row
  /// and the linked auth user via cascade).
  void _confirmRemoveStaff(BuildContext context, StaffMember s) {
    if (s.role.toLowerCase() == 'owner') {
      showToast(
        context,
        'The workspace owner cannot be removed',
        icon: AppIcons.shield,
        kind: 'warn',
      );
      return;
    }
    showDialog<void>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: Text('Remove ${s.name}?'),
        content: Text(
          'This deletes the staff record of ${s.name}'
          '${s.canLogIn ? ' and their login account' : ''}. '
          'They will no longer be able to sign in. Past orders keep their name.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(dctx);
              final idx = demo.staff.indexOf(s);
              demo.deleteStaff(s);
              final undo = demo.scheduleDbDelete(
                () => demo.deleteStaffDb(s),
                undoUi: () {
                  if (idx >= 0) {
                    demo.staff.insert(idx.clamp(0, demo.staff.length), s);
                  } else {
                    demo.staff.add(s);
                  }
                },
              );
              showToast(
                context,
                '${s.name} removed',
                subtitle: 'Deleting in 5s',
                icon: AppIcons.trash,
                kind: 'danger',
                actionLabel: 'Undo',
                onAction: () {
                  undo();
                  demo.addAudit('Delete undone', 'update', s.name);
                },
                duration: const Duration(seconds: 5),
              );
              setState(() {});
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  /// Lets the owner/manager set a new login password for [s]. The password
  /// is sent to the `set_staff_password` RPC — it is never stored in the
  /// app or in the plain-text settings.
  void _showChangePasswordDialog(StaffMember s) {
    final pw = TextEditingController();
    final confirm = TextEditingController();
    var obscure = true;
    var saving = false;
    String? error;
    showDialog<void>(
      context: context,
      builder: (dctx) => StatefulBuilder(
        builder: (dctx, setDialog) => AlertDialog(
          title: Text('Change password · ${s.name}'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.email == null || s.email!.isEmpty
                      ? 'This member signs in with the email on their staff '
                            'record.'
                      : 'They sign in as ${s.email}.',
                  style: Theme.of(dctx).textTheme.bodySmall,
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: pw,
                  autofocus: true,
                  obscureText: obscure,
                  decoration: InputDecoration(
                    labelText: 'NEW PASSWORD (MIN. 8 CHARACTERS)',
                    prefixIcon: const Icon(AppIcons.lock, size: 18),
                    suffixIcon: IconButton(
                      onPressed: () => setDialog(() => obscure = !obscure),
                      icon: Icon(
                        obscure ? AppIcons.eye : AppIcons.x,
                        size: 18,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirm,
                  obscureText: obscure,
                  decoration: const InputDecoration(
                    labelText: 'CONFIRM NEW PASSWORD',
                    prefixIcon: Icon(AppIcons.lock, size: 18),
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    error!,
                    style: const TextStyle(
                      color: AppColors.red,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Text(
                  'The member keeps their email; only the password changes. '
                  'Share the new password with them — it cannot be viewed '
                  'here afterwards.',
                  style: Theme.of(dctx).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(dctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (pw.text.length < 8) {
                        setDialog(
                          () => error = 'Password must be at least 8 characters.',
                        );
                        return;
                      }
                      if (pw.text != confirm.text) {
                        setDialog(
                          () => error = 'The two passwords do not match.',
                        );
                        return;
                      }
                      setDialog(() {
                        saving = true;
                        error = null;
                      });
                      final err = await demo.changeStaffPassword(s, pw.text);
                      if (!mounted) return;
                      if (err != null) {
                        setDialog(() {
                          saving = false;
                          error = err;
                        });
                        return;
                      }
                      if (dctx.mounted) Navigator.pop(dctx);
                      setState(() {});
                      showToast(
                        context,
                        'Password changed',
                        subtitle: '${s.name} can sign in with the new '
                            'password.',
                        icon: AppIcons.check,
                      );
                    },
              child: Text(saving ? 'Saving…' : 'Change password'),
            ),
          ],
        ),
      ),
    );
  }

  /// Read-only list of what a member can access via their role.
  void _showMemberPermissions(BuildContext context, StaffMember s) {
    final perms = demo.permissionsFor(s);
    final isAll = perms.contains(Permissions.all);
    showDialog<void>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: Text('${s.name} · permissions'),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Role: ${s.role}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              if (isAll)
                const Text(
                  'This member has full access to every area of the workspace.',
                )
              else
                for (final p in Permissions.labels.entries)
                  if (perms.contains(p.key))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          const Icon(
                            AppIcons.check,
                            size: 14,
                            color: AppColors.green,
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: Text(p.value, style: const TextStyle(fontSize: 12.5))),
                        ],
                      ),
                    ),
              if (!isAll && perms.isEmpty)
                const Text('No permissions granted — this member cannot sign in to any area.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dctx),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dctx);
              _showRoleManager(context);
            },
            child: const Text('Edit roles'),
          ),
        ],
      ),
    );
  }

  /// Create / rename / delete custom roles and toggle their permissions.
  void _showRoleManager(BuildContext context) {
    // Work on a mutable copy; saved atomically on "Save".
    var roles = List<StaffRole>.of(demo.roles);
    showDialog<void>(
      context: context,
      builder: (dctx) => StatefulBuilder(
        builder: (dctx, setDlg) => AlertDialog(
          title: const Text('Roles & permissions'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Each role grants access to specific areas. Members with '
                  '"Full access" can open every screen. The Owner always has '
                  'full access.',
                  style: TextStyle(fontSize: 12, color: AppColors.text3),
                ),
                const SizedBox(height: 14),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        for (var i = 0; i < roles.length; i++)
                          Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? AppColors.darkCard2
                                  : AppColors.card2,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: TextEditingController(text: roles[i].name),
                                        decoration: const InputDecoration(
                                          labelText: 'Role name',
                                          isDense: true,
                                        ),
                                        onChanged: (v) {
                                          roles[i] = StaffRole(
                                            name: v,
                                            permissions: roles[i].permissions,
                                          );
                                        },
                                      ),
                                    ),
                                    // Owner row is fixed.
                                    if (roles[i].name != 'Owner' && roles.length > 1)
                                      IconButton(
                                        visualDensity: VisualDensity.compact,
                                        tooltip: 'Remove role',
                                        onPressed: () => setDlg(() => roles.removeAt(i)),
                                        icon: const Icon(
                                          AppIcons.trash,
                                          size: 15,
                                          color: AppColors.red,
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: [
                                    for (final p in Permissions.labels.entries)
                                      InkWell(
                                        onTap: () => setDlg(() {
                                          final perms = Set<String>.of(roles[i].permissions);
                                          if (p.key == Permissions.all) {
                                            perms
                                              ..clear()
                                              ..add(Permissions.all);
                                          } else {
                                            perms.remove(Permissions.all);
                                            if (!perms.add(p.key)) perms.remove(p.key);
                                          }
                                          roles[i] = StaffRole(
                                            name: roles[i].name,
                                            permissions: perms,
                                          );
                                        }),
                                        borderRadius: BorderRadius.circular(99),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 9,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: roles[i].can(p.key)
                                                ? AppColors.brandT
                                                : Colors.transparent,
                                            border: Border.all(
                                              color: roles[i].can(p.key)
                                                  ? AppColors.brand
                                                  : AppColors.line,
                                            ),
                                            borderRadius: BorderRadius.circular(99),
                                          ),
                                          child: Text(
                                            p.value,
                                            style: TextStyle(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w700,
                                              color: roles[i].can(p.key)
                                                  ? AppColors.brand
                                                  : AppColors.text3,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                TextButton.icon(
                  onPressed: () => setDlg(
                    () => roles.add(
                      const StaffRole(name: 'New role', permissions: {}),
                    ),
                  ),
                  icon: const Icon(AppIcons.plus, size: 15),
                  label: const Text('Add role'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                // Drop roles without a name.
                final valid = roles
                    .where((r) => r.name.trim().isNotEmpty)
                    .map((r) => StaffRole(name: r.name.trim(), permissions: r.permissions))
                    .toList();
                if (valid.isEmpty) return;
                Navigator.pop(dctx);
                demo.saveRoles(valid);
                showToast(
                  context,
                  'Roles saved',
                  subtitle: 'Permissions apply immediately',
                  icon: AppIcons.check,
                );
                setState(() {});
              },
              child: const Text('Save roles'),
            ),
          ],
        ),
      ),
    );
  }

  void _showStaffDialog({StaffMember? member}) {
    final name = TextEditingController(text: member?.name ?? '');
    final phone = TextEditingController(text: member?.phone ?? '');
    final hired = TextEditingController(text: member?.hired ?? '');
    final email = TextEditingController(text: member?.email ?? '');
    final password = TextEditingController();
    bool obscure = true;
    bool creating = false;
    String? role = member?.role ?? 'Waiter';
    // Roles come from the owner-configurable list (Roles & permissions).
    final roles = demo.roles.map((r) => r.name).toList();
    if (!roles.contains(role)) role = roles.isNotEmpty ? roles.first : 'Waiter';

    showDialog<void>(
      context: context,
      builder: (dctx) => StatefulBuilder(
        builder: (dctx, setDialog) => AlertDialog(
          title: Text(member == null ? 'Add staff' : 'Edit · ${member.name}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  decoration: const InputDecoration(
                    labelText: 'FULL NAME',
                    hintText: 'e.g. Annette Black',
                    prefixIcon: Icon(AppIcons.user, size: 18),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: role,
                  decoration: const InputDecoration(labelText: 'ROLE'),
                  items: [
                    for (final r in roles)
                      DropdownMenuItem(value: r, child: Text(r)),
                  ],
                  onChanged: (v) => role = v,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'PHONE NUMBER',
                    hintText: '+34 …',
                    prefixIcon: Icon(AppIcons.card, size: 18),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: hired,
                  decoration: const InputDecoration(
                    labelText: 'HIRED DATE',
                    hintText: 'e.g. Jan 08, 2026',
                    prefixIcon: Icon(AppIcons.clock, size: 18),
                  ),
                ),
                if (member == null) ...[
                  const Divider(height: 28),
                  Text(
                    'Login account',
                    style: Theme.of(dctx).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'The staff member uses this email and password to sign '
                    'in to this workspace.',
                    style: Theme.of(dctx).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'EMAIL',
                      hintText: 'name@restaurant.com',
                      prefixIcon: Icon(AppIcons.card, size: 18),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: password,
                    obscureText: obscure,
                    decoration: InputDecoration(
                      labelText: 'TEMPORARY PASSWORD (MIN. 8 CHARS)',
                      prefixIcon: const Icon(AppIcons.lock, size: 18),
                      suffixIcon: IconButton(
                        onPressed: () =>
                            setDialog(() => obscure = !obscure),
                        icon: Icon(
                          obscure ? AppIcons.eye : AppIcons.x,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ] else if (member.email != null && member.email!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Signs in as ${member.email}'
                    '${member.canLogIn ? '' : ' (login not provisioned)'}',
                    style: Theme.of(dctx).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: creating ? null : () => Navigator.pop(dctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: creating
                  ? null
                  : () async {
                      if (name.text.trim().isEmpty) return;
                      if (member == null) {
                        if (!email.text.contains('@')) {
                          setDialog(() {});
                          return;
                        }
                        if (password.text.length < 8) {
                          setDialog(() {});
                          return;
                        }
                        setDialog(() => creating = true);
                        final error = await demo.addStaff(
                          name: name.text.trim(),
                          email: email.text.trim(),
                          password: password.text,
                          role: role ?? 'Waiter',
                          phone: phone.text.trim(),
                          hired: hired.text.trim().isEmpty
                              ? demo.dateNow
                              : hired.text.trim(),
                        );
                        if (!mounted) return;
                        if (dctx.mounted) Navigator.pop(dctx);
                        if (error != null) {
                          setState(() {});
                          showToast(
                            context,
                            'Could not create the account',
                            subtitle: error,
                            icon: AppIcons.x,
                            kind: 'err',
                          );
                        } else {
                          setState(() {});
                          showToast(
                            context,
                            'Staff account created',
                            subtitle:
                                '${name.text.trim()} can now sign in with the '
                                'email and password you set.',
                            icon: AppIcons.check,
                          );
                        }
                        return;
                      }
                      member.name = name.text.trim();
                      member.role = role ?? member.role;
                      member.phone = phone.text.trim();
                      member.hired = hired.text.trim();
                      demo.updateStaff(member);
                      demo.addAudit(
                        'Staff member updated',
                        'update',
                        '${name.text.trim()} · $role',
                      );
                      Navigator.pop(dctx);
                      setState(() {});
                      showToast(
                        context,
                        'Staff member updated',
                        icon: AppIcons.check,
                      );
                    },
              child: creating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
