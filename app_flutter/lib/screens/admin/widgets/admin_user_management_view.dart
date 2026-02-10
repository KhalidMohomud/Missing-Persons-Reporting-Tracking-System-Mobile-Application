import 'package:flutter/material.dart';

import '../admin_utils.dart';

class AdminUserManagementView extends StatelessWidget {
  final List<Map<String, dynamic>> users;
  final String? error;
  final Future<void> Function(String id, String role) onRoleChanged;
  final Future<void> Function(String id) onDelete;

  const AdminUserManagementView({
    super.key,
    required this.users,
    required this.error,
    required this.onRoleChanged,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final widgets = <Widget>[];
    final roleOptions = _buildRoleOptions(users);

    if (error != null) {
      widgets.add(_ErrorBanner(message: error!));
      widgets.add(const SizedBox(height: 12));
    }

    if (users.isEmpty) {
      widgets.add(const _EmptyState(text: 'No users available.'));
    } else {
      widgets.addAll(
        users.map(
          (user) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _UserCard(
              user: user,
              onRoleChanged: onRoleChanged,
              onDelete: onDelete,
              roleOptions: roleOptions,
            ),
          ),
        ),
      );
    }

    return ListView(
      key: const ValueKey('users'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      physics: const AlwaysScrollableScrollPhysics(),
      children: widgets,
    );
  }

  List<String> _buildRoleOptions(List<Map<String, dynamic>> users) {
    final roles = <String>{'admin', 'public', 'staff'};
    for (final user in users) {
      final role = AdminUtils.safeString(user['role']).toLowerCase();
      if (role.isNotEmpty) roles.add(role);
    }
    return roles.toList()..sort();
  }
}

class _UserCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final Future<void> Function(String id, String role) onRoleChanged;
  final Future<void> Function(String id) onDelete;
  final List<String> roleOptions;

  const _UserCard({
    required this.user,
    required this.onRoleChanged,
    required this.onDelete,
    required this.roleOptions,
  });

  @override
  Widget build(BuildContext context) {
    final id = AdminUtils.safeString(user['id']);
    final fullName = AdminUtils.safeString(user['fullName']);
    final firstName = AdminUtils.safeString(user['firstName']);
    final lastName = AdminUtils.safeString(user['lastName']);
    final displayName = fullName.isNotEmpty
        ? fullName
        : [firstName, lastName].where((value) => value.isNotEmpty).join(' ');
    final email = AdminUtils.safeString(user['email']);
    final role = AdminUtils.safeString(user['role'], 'public').toLowerCase();
    final createdAt = AdminUtils.formatDate(user['createdAt']);

    final nameText = displayName.isNotEmpty ? displayName : email;
    final subtitle = email.isNotEmpty ? email : id;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.blueGrey.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.person_outline, color: Colors.grey.shade500),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nameText.isNotEmpty ? nameText : 'Unnamed user',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style:
                            TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                    if (createdAt.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Created $createdAt',
                        style:
                            TextStyle(fontSize: 11, color: Colors.grey.shade500),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                onPressed: id.isEmpty ? null : () => onDelete(id),
                tooltip: 'Delete user',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Role',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: roleOptions.contains(role) ? role : 'public',
                  items: roleOptions
                      .map(
                        (item) => DropdownMenuItem(
                          value: item,
                          child: Text(item.toUpperCase()),
                        ),
                      )
                      .toList(),
                  onChanged: id.isEmpty
                      ? null
                      : (value) {
                          if (value != null && value != role) {
                            onRoleChanged(id, value);
                          }
                        },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String text;

  const _EmptyState({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(Icons.inbox_outlined, size: 32, color: Colors.grey.shade400),
          const SizedBox(height: 10),
          Text(
            text,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;

  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.red.shade400),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: Colors.red.shade700, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
