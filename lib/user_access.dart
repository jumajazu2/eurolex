import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:LegisTracerEU/main.dart';

class UserAccessWidget extends StatefulWidget {
  const UserAccessWidget({super.key});

  @override
  State<UserAccessWidget> createState() => _UserAccessWidgetState();
}

class _UserAccessWidgetState extends State<UserAccessWidget> {
  List<dynamic> users = [];
  List<dynamic> filteredUsers = [];
  bool loading = true;
  String? error;
  Map<String, dynamic>? statistics;
  final TextEditingController _filterController = TextEditingController();
  String _filterText = '';
  String _filterStatus = 'all'; // all, active, blocked, expired, trial, paid

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _loadStatistics();
    _filterController.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _filterController.dispose();
    super.dispose();
  }

  void _applyFilter() {
    setState(() {
      _filterText = _filterController.text.toLowerCase();
      _updateFilteredUsers();
    });
  }

  void _updateFilteredUsers() {
    filteredUsers =
        users.where((user) {
          // Text filter
          final email = (user['email'] ?? '').toString().toLowerCase();
          final passkey = (user['key'] ?? '').toString().toLowerCase();
          if (_filterText.isNotEmpty &&
              !email.contains(_filterText) &&
              !passkey.contains(_filterText)) {
            return false;
          }

          // Status filter
          if (_filterStatus == 'blocked' && !(user['blocked'] ?? false))
            return false;
          if (_filterStatus == 'expired' && !(user['isExpired'] ?? false))
            return false;
          if (_filterStatus == 'active' &&
              ((user['blocked'] ?? false) || (user['isExpired'] ?? false)))
            return false;
          if (_filterStatus == 'trial' && user['userType'] != 'trial')
            return false;
          if (_filterStatus == 'paid' && user['userType'] != 'paid')
            return false;
          if (_filterStatus == 'grace' && user['userType'] != 'grace')
            return false;

          return true;
        }).toList();
  }

  Future<void> _loadUsers() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final response = await http
          .get(
            Uri.parse('https://$osServer/api/users/list'),
            headers: {
              'x-api-key': '${jsonSettings['access_key']}',
              'x-email': '${jsonSettings['user_email']}',
              'x-admin-key': '7239',
            },
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception('Request timeout - server not responding');
            },
          );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          setState(() {
            users = data['users'] ?? [];
            _updateFilteredUsers();
            loading = false;
          });
        }
      } else {
        throw Exception('Failed to load users: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e.toString();
          loading = false;
        });
      }
    }
  }

  Future<void> _loadStatistics() async {
    try {
      final response = await http
          .get(
            Uri.parse('https://$osServer/api/users/statistics'),
            headers: {
              'x-api-key': '${jsonSettings['access_key']}',
              'x-email': '${jsonSettings['user_email']}',
              'x-admin-key': '7239',
            },
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception('Statistics timeout');
            },
          );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          setState(() {
            statistics = data['statistics'];
          });
        }
      }
    } catch (e) {
      print('Failed to load statistics: $e');
      // Don't show error to user - statistics are optional
      if (mounted) {
        setState(() {
          statistics = {
            'totalUsers': 0,
            'activeToday': 0,
            'totalSearchesToday': 0,
            'expiredAccounts': 0,
            'blockedAccounts': 0,
            'webSearchesToday': 0,
            'appSearchesToday': 0,
            'tradosSearchesToday': 0,
            'unknownSearchesToday': 0,
          };
        });
      }
    }
  }

  Future<void> _showTrialEmails() async {
    try {
      final response = await http
          .get(
            Uri.parse('https://$osServer/api/users/trial-emails'),
            headers: {
              'x-api-key': '${jsonSettings['access_key']}',
              'x-email': '${jsonSettings['user_email']}',
              'x-admin-key': '7239',
            },
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception('Request timeout');
            },
          );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final emails = data['emails'] as List;
        final uniqueCount = data['uniqueCount'] ?? 0;

        if (!mounted) return;

        showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                title: Text('Emails ($uniqueCount unique)'),
                content: SizedBox(
                  width: 600,
                  height: 400,
                  child:
                      emails.isEmpty
                          ? const Center(child: Text('No emails yet'))
                          : ListView.builder(
                            itemCount: emails.length,
                            itemBuilder: (context, index) {
                              final item = emails[index];
                              final timestamp = item['timestamp'] ?? '';
                              final email = item['email'] ?? '';
                              final date = DateTime.tryParse(timestamp);
                              final dateStr =
                                  date != null
                                      ? '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}'
                                      : timestamp;

                              return ListTile(
                                dense: true,
                                leading: const Icon(
                                  Icons.email_outlined,
                                  size: 16,
                                ),
                                title: Text(
                                  email,
                                  style: const TextStyle(fontSize: 13),
                                ),
                                subtitle: Text(
                                  dateStr,
                                  style: const TextStyle(fontSize: 11),
                                ),
                              );
                            },
                          ),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      // Copy all unique emails to clipboard
                      final uniqueEmails = emails
                          .map((e) => e['email'])
                          .toSet()
                          .join(', ');
                      // Simple clipboard copy would require clipboard package
                      // For now, just show in a text field they can select
                      showDialog(
                        context: context,
                        builder:
                            (context) => AlertDialog(
                              title: const Text('All Unique Emails'),
                              content: SelectableText(uniqueEmails),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Close'),
                                ),
                              ],
                            ),
                      );
                    },
                    child: const Text('Copy All'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              ),
        );
      } else {
        throw Exception('Failed to load emails: ${response.body}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading emails: $e')));
      }
    }
  }

  Future<void> _addUser() async {
    final emailController = TextEditingController();
    final passkeyController = TextEditingController();
    final quotaController = TextEditingController(text: '1000');
    final expiresAtController = TextEditingController();
    String userType = 'paid';

    final result = await showDialog<bool>(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  title: const Text('Add New User'),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: emailController,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: passkeyController,
                          decoration: const InputDecoration(
                            labelText: 'Passkey',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: quotaController,
                          decoration: const InputDecoration(
                            labelText: 'Daily Quota',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: userType,
                          decoration: const InputDecoration(
                            labelText: 'User Type',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'paid',
                              child: Text('Paid'),
                            ),
                            DropdownMenuItem(
                              value: 'trial',
                              child: Text('Trial'),
                            ),
                            DropdownMenuItem(
                              value: 'grace',
                              child: Text('Grace (Courtesy)'),
                            ),
                          ],
                          onChanged: (value) {
                            setDialogState(() {
                              userType = value!;
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: expiresAtController,
                          decoration: const InputDecoration(
                            labelText: 'Expires At (YYYY-MM-DD)',
                            hintText: 'Leave empty for no expiration',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        if (emailController.text.isEmpty ||
                            passkeyController.text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Email and passkey are required'),
                            ),
                          );
                          return;
                        }

                        try {
                          final response = await http
                              .post(
                                Uri.parse('https://$osServer/api/users/add'),
                                headers: {
                                  'x-api-key': '${jsonSettings['access_key']}',
                                  'x-email': '${jsonSettings['user_email']}',
                                  'x-admin-key': '7239',
                                  'Content-Type': 'application/json',
                                },
                                body: json.encode({
                                  'email': emailController.text,
                                  'passkey': passkeyController.text,
                                  'dailyQuota':
                                      int.tryParse(quotaController.text) ??
                                      1000,
                                  'userType': userType,
                                  'expiresAt':
                                      expiresAtController.text.isNotEmpty
                                          ? expiresAtController.text
                                          : null,
                                }),
                              )
                              .timeout(
                                const Duration(seconds: 10),
                                onTimeout: () {
                                  throw Exception('Request timeout');
                                },
                              );

                          if (response.statusCode == 200) {
                            Navigator.pop(context, true);
                          } else {
                            try {
                              final error = json.decode(response.body);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(error['error'] ?? 'Failed'),
                                ),
                              );
                            } catch (_) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Error ${response.statusCode}: ${response.body}',
                                  ),
                                ),
                              );
                            }
                          }
                        } catch (e) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text('Error: $e')));
                        }
                      },
                      child: const Text('Add User'),
                    ),
                  ],
                ),
          ),
    );

    if (result == true) {
      _loadUsers();
      _loadStatistics();
    }
  }

  Future<void> _updateQuota(String passkey, int currentQuota) async {
    final quotaController = TextEditingController(
      text: currentQuota.toString(),
    );

    final result = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Update Daily Quota'),
            content: TextField(
              controller: quotaController,
              decoration: const InputDecoration(
                labelText: 'Daily Quota',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  try {
                    final response = await http
                        .post(
                          Uri.parse('https://$osServer/api/users/set-quota'),
                          headers: {
                            'x-api-key': '${jsonSettings['access_key']}',
                            'x-email': '${jsonSettings['user_email']}',
                            'x-admin-key': '7239',
                            'Content-Type': 'application/json',
                          },
                          body: json.encode({
                            'passkey': passkey,
                            'dailyQuota':
                                int.tryParse(quotaController.text) ??
                                currentQuota,
                          }),
                        )
                        .timeout(
                          const Duration(seconds: 10),
                          onTimeout: () {
                            throw Exception('Request timeout');
                          },
                        );

                    if (response.statusCode == 200) {
                      Navigator.pop(context, true);
                    } else {
                      throw Exception(
                        'Failed to update quota: ${response.body}',
                      );
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                },
                child: const Text('Update'),
              ),
            ],
          ),
    );

    if (result == true) {
      _loadUsers();
    }
  }

  Future<void> _changeUserType(String passkey, String currentType) async {
    String selectedType = currentType;

    final result = await showDialog<bool>(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setState) => AlertDialog(
                  title: const Text('Change User Type'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      RadioListTile<String>(
                        title: const Text('Paid'),
                        value: 'paid',
                        groupValue: selectedType,
                        onChanged: (value) {
                          setState(() {
                            selectedType = value!;
                          });
                        },
                      ),
                      RadioListTile<String>(
                        title: const Text('Trial'),
                        value: 'trial',
                        groupValue: selectedType,
                        onChanged: (value) {
                          setState(() {
                            selectedType = value!;
                          });
                        },
                      ),
                      RadioListTile<String>(
                        title: const Text('Grace (Courtesy)'),
                        value: 'grace',
                        groupValue: selectedType,
                        onChanged: (value) {
                          setState(() {
                            selectedType = value!;
                          });
                        },
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        try {
                          final response = await http
                              .post(
                                Uri.parse(
                                  'https://$osServer/api/users/set-type',
                                ),
                                headers: {
                                  'x-api-key': '${jsonSettings['access_key']}',
                                  'x-email': '${jsonSettings['user_email']}',
                                  'x-admin-key': '7239',
                                  'Content-Type': 'application/json',
                                },
                                body: json.encode({
                                  'passkey': passkey,
                                  'userType': selectedType,
                                }),
                              )
                              .timeout(
                                const Duration(seconds: 10),
                                onTimeout: () {
                                  throw Exception('Request timeout');
                                },
                              );

                          if (response.statusCode == 200) {
                            Navigator.pop(context, true);
                          } else {
                            throw Exception(
                              'Failed to change user type: ${response.body}',
                            );
                          }
                        } catch (e) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text('Error: $e')));
                        }
                      },
                      child: const Text('Update'),
                    ),
                  ],
                ),
          ),
    );

    if (result == true) {
      _loadUsers();
    }
  }

  Future<void> _resetDailyUsage(String passkey, String email) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Reset Daily Usage'),
            content: Text(
              'Reset daily quota usage to 0 for:\n$email ($passkey)?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Reset'),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      try {
        final response = await http
            .post(
              Uri.parse('https://$osServer/api/users/reset-daily-usage'),
              headers: {
                'x-api-key': '${jsonSettings['access_key']}',
                'x-email': '${jsonSettings['user_email']}',
                'x-admin-key': '7239',
                'Content-Type': 'application/json',
              },
              body: json.encode({'passkey': passkey}),
            )
            .timeout(
              const Duration(seconds: 10),
              onTimeout: () {
                throw Exception('Request timeout');
              },
            );

        if (response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Daily usage reset successfully')),
          );
          _loadUsers();
        } else {
          throw Exception('Failed to reset daily usage: ${response.body}');
        }
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _toggleBlock(
    String passkey,
    bool currentlyBlocked,
    String email,
  ) async {
    final action = currentlyBlocked ? 'unblock' : 'block';
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Confirm ${action.toUpperCase()}'),
            content: Text(
              'Are you sure you want to $action user:\n$email ($passkey)?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      currentlyBlocked ? Colors.green : Colors.orange,
                ),
                onPressed: () => Navigator.pop(context, true),
                child: Text(action.toUpperCase()),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      try {
        final response = await http
            .post(
              Uri.parse('https://$osServer/api/users/block'),
              headers: {
                'x-api-key': '${jsonSettings['access_key']}',
                'x-email': '${jsonSettings['user_email']}',
                'x-admin-key': '7239',
                'Content-Type': 'application/json',
              },
              body: json.encode({
                'passkey': passkey,
                'blocked': !currentlyBlocked,
              }),
            )
            .timeout(
              const Duration(seconds: 10),
              onTimeout: () {
                throw Exception('Request timeout');
              },
            );

        if (response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('User ${action}ed successfully')),
          );
          _loadUsers();
        } else {
          throw Exception('Failed to $action user: ${response.body}');
        }
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _deleteUser(String passkey, String email) async {
    final emailController = TextEditingController();
    final passkeyController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Confirm User Deletion'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'This action cannot be undone!\n\nTo confirm deletion, please enter both:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: emailController,
                  decoration: InputDecoration(
                    labelText: 'Email ($email)',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passkeyController,
                  decoration: InputDecoration(
                    labelText: 'Passkey ($passkey)',
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () {
                  if (emailController.text == email &&
                      passkeyController.text == passkey) {
                    Navigator.pop(context, true);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Email and passkey do not match'),
                      ),
                    );
                  }
                },
                child: const Text('DELETE USER'),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      try {
        final response = await http
            .delete(
              Uri.parse('https://$osServer/api/users/delete'),
              headers: {
                'x-api-key': '${jsonSettings['access_key']}',
                'x-email': '${jsonSettings['user_email']}',
                'x-admin-key': '7239',
                'Content-Type': 'application/json',
              },
              body: json.encode({'email': email, 'passkey': passkey}),
            )
            .timeout(
              const Duration(seconds: 10),
              onTimeout: () {
                throw Exception('Request timeout');
              },
            );

        if (response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User deleted successfully')),
          );
          _loadUsers();
          _loadStatistics();
        } else {
          throw Exception('Failed to delete user: ${response.body}');
        }
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header with statistics and add button
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'User Access Management',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Spacer(),
                  if (statistics != null) ...[
                    _StatCard('Users', statistics!['totalUsers'].toString()),
                    const SizedBox(width: 8),
                    _StatCard('Active', statistics!['activeToday'].toString()),
                    const SizedBox(width: 8),
                    _StatCard(
                      'Today',
                      statistics!['totalSearchesToday'].toString(),
                    ),
                    const SizedBox(width: 8),
                    _StatCard(
                      'Web',
                      statistics!['webSearchesToday']?.toString() ?? '0',
                      color: Colors.blue.shade700,
                    ),
                    const SizedBox(width: 8),
                    _StatCard(
                      'App',
                      statistics!['appSearchesToday']?.toString() ?? '0',
                      color: Colors.green.shade700,
                    ),
                    const SizedBox(width: 8),
                    _StatCard(
                      'Trados',
                      statistics!['tradosSearchesToday']?.toString() ?? '0',
                      color: Colors.purple.shade700,
                    ),
                    const SizedBox(width: 8),
                    _StatCard(
                      'Expired',
                      statistics!['expiredAccounts'].toString(),
                      color: Colors.orange,
                    ),
                    const SizedBox(width: 8),
                    _StatCard(
                      'Blocked',
                      statistics!['blockedAccounts'].toString(),
                      color: Colors.red,
                    ),
                    const SizedBox(width: 12),
                  ],
                  ElevatedButton.icon(
                    onPressed: _addUser,
                    icon: const Icon(Icons.person_add, size: 18),
                    label: const Text('Add'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _showTrialEmails,
                    icon: const Icon(Icons.email, size: 18),
                    label: const Text('Emails'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () {
                      _loadUsers();
                      _loadStatistics();
                    },
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Refresh',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Filter bar
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _filterController,
                      decoration: InputDecoration(
                        hintText: 'Filter by email or passkey...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        suffixIcon:
                            _filterText.isNotEmpty
                                ? IconButton(
                                  icon: const Icon(Icons.clear, size: 20),
                                  onPressed: () => _filterController.clear(),
                                )
                                : null,
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        isDense: true,
                      ),
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  const SizedBox(width: 12),
                  DropdownButton<String>(
                    value: _filterStatus,
                    isDense: true,
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('All')),
                      DropdownMenuItem(value: 'active', child: Text('Active')),
                      DropdownMenuItem(
                        value: 'blocked',
                        child: Text('Blocked'),
                      ),
                      DropdownMenuItem(
                        value: 'expired',
                        child: Text('Expired'),
                      ),
                      DropdownMenuItem(value: 'trial', child: Text('Trial')),
                      DropdownMenuItem(value: 'paid', child: Text('Paid')),
                      DropdownMenuItem(value: 'grace', child: Text('Grace')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _filterStatus = value ?? 'all';
                        _updateFilteredUsers();
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${filteredUsers.length} / ${users.length}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Divider(),
        // User list
        Expanded(
          child:
              loading
                  ? const Center(child: CircularProgressIndicator())
                  : error != null
                  ? Center(child: Text('Error: $error'))
                  : filteredUsers.isEmpty
                  ? const Center(child: Text('No users match the filter'))
                  : ListView.builder(
                    itemCount: filteredUsers.length,
                    itemBuilder: (context, index) {
                      final user = filteredUsers[index];
                      final blocked = user['blocked'] ?? false;
                      final expiresAt = user['expiresAt'];
                      final isExpired = user['isExpired'] ?? false;
                      final totalSearches = user['totalSearches'] ?? 0;
                      final searchesToday = user['quotaUsed'] ?? 0;
                      final isTrial = user['userType'] == 'trial';

                      // Historical stats
                      final totalSearches30Days =
                          user['totalSearches30Days'] ?? 0;
                      final last7DaysTotal = user['last7DaysTotal'] ?? 0;
                      final activeDaysCount = user['activeDaysCount'] ?? 0;
                      final avgSearchesPerDay = user['avgSearchesPerDay'] ?? 0;
                      final daysSinceLastActive = user['daysSinceLastActive'];
                      final daysSinceFirstUse = user['daysSinceFirstUse'];

                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        color:
                            blocked
                                ? Colors.red.withOpacity(0.1)
                                : isExpired
                                ? Colors.orange.withOpacity(0.1)
                                : isTrial
                                ? Colors.orange.withOpacity(0.05)
                                : null,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          child: Column(
                            children: [
                              // Main row with primary info
                              Row(
                                children: [
                                  // Status Icon
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color:
                                          blocked
                                              ? Colors.red
                                              : isExpired
                                              ? Colors.orange
                                              : user['userType'] == 'paid'
                                              ? Colors.green
                                              : user['userType'] == 'trial'
                                              ? Colors.orange
                                              : user['userType'] == 'grace'
                                              ? Colors.purple
                                              : Colors.blue,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      blocked
                                          ? Icons.block
                                          : isExpired
                                          ? Icons.access_time
                                          : user['userType'] == 'paid'
                                          ? Icons.verified
                                          : user['userType'] == 'trial'
                                          ? Icons.timer
                                          : user['userType'] == 'grace'
                                          ? Icons.card_giftcard
                                          : Icons.person,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Email and basic info
                                  Expanded(
                                    flex: 3,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          user['email'] ?? 'no-email',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            decoration:
                                                blocked
                                                    ? TextDecoration.lineThrough
                                                    : null,
                                          ),
                                        ),
                                        Text(
                                          'Key: ${user['key']} • ${user['userType']}',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Search statistics
                                  Expanded(
                                    flex: 2,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Today: $searchesToday',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blue,
                                          ),
                                        ),
                                        Text(
                                          'Last 7d: $last7DaysTotal',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey,
                                          ),
                                        ),
                                        Text(
                                          '30d: $totalSearches30Days',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey,
                                          ),
                                        ),
                                        // Client type breakdown (30 days)
                                        if ((user['webSearches'] ?? 0) > 0 ||
                                            (user['appSearches'] ?? 0) > 0 ||
                                            (user['tradosSearches'] ?? 0) > 0)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 2,
                                            ),
                                            child: Row(
                                              children: [
                                                if ((user['webSearches'] ?? 0) >
                                                    0) ...[
                                                  Icon(
                                                    Icons.web,
                                                    size: 10,
                                                    color: Colors.blue.shade700,
                                                  ),
                                                  const SizedBox(width: 2),
                                                  Text(
                                                    '${user['webSearches']}',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color:
                                                          Colors.blue.shade700,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                ],
                                                if ((user['appSearches'] ?? 0) >
                                                    0) ...[
                                                  Icon(
                                                    Icons.phone_android,
                                                    size: 10,
                                                    color:
                                                        Colors.green.shade700,
                                                  ),
                                                  const SizedBox(width: 2),
                                                  Text(
                                                    '${user['appSearches']}',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color:
                                                          Colors.green.shade700,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                ],
                                                if ((user['tradosSearches'] ??
                                                        0) >
                                                    0) ...[
                                                  Icon(
                                                    Icons.translate,
                                                    size: 10,
                                                    color:
                                                        Colors.purple.shade700,
                                                  ),
                                                  const SizedBox(width: 2),
                                                  Text(
                                                    '${user['tradosSearches']}',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color:
                                                          Colors
                                                              .purple
                                                              .shade700,
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  // Activity info
                                  Expanded(
                                    flex: 2,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Quota: ${user['quotaUsed']}/${user['dailyQuota']}',
                                          style: const TextStyle(fontSize: 13),
                                        ),
                                        if (daysSinceLastActive != null)
                                          Text(
                                            daysSinceLastActive == 0
                                                ? 'Active today'
                                                : 'Last: ${daysSinceLastActive}d ago',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color:
                                                  daysSinceLastActive > 7
                                                      ? Colors.orange
                                                      : Colors.grey,
                                            ),
                                          ),
                                        if (avgSearchesPerDay > 0)
                                          Text(
                                            'Avg: $avgSearchesPerDay/day',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  // Expiration
                                  Expanded(
                                    flex: 2,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (expiresAt != null)
                                          Text(
                                            'Exp: $expiresAt',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color:
                                                  isExpired
                                                      ? Colors.red
                                                      : Colors.grey,
                                            ),
                                          )
                                        else
                                          const Text(
                                            'No expiration',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        if (activeDaysCount > 0)
                                          Text(
                                            'Active: $activeDaysCount days',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  // Action buttons
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(
                                          Icons.numbers,
                                          size: 18,
                                        ),
                                        tooltip: 'Change Quota',
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        color: Colors.blue,
                                        onPressed:
                                            () => _updateQuota(
                                              user['key'],
                                              user['dailyQuota'],
                                            ),
                                      ),
                                      const SizedBox(width: 4),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.category,
                                          size: 18,
                                        ),
                                        tooltip:
                                            'Change Status (Paid/Trial/Grace)',
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        color: Colors.purple,
                                        onPressed:
                                            () => _changeUserType(
                                              user['key'],
                                              user['userType'] ?? 'paid',
                                            ),
                                      ),
                                      const SizedBox(width: 4),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.refresh,
                                          size: 18,
                                        ),
                                        tooltip: 'Reset Daily Usage',
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        color: Colors.teal,
                                        onPressed:
                                            () => _resetDailyUsage(
                                              user['key'],
                                              user['email'] ?? 'no-email',
                                            ),
                                      ),
                                      const SizedBox(width: 4),
                                      IconButton(
                                        icon: Icon(
                                          blocked
                                              ? Icons.check_circle
                                              : Icons.block,
                                          size: 18,
                                        ),
                                        tooltip: blocked ? 'Unblock' : 'Block',
                                        color:
                                            blocked
                                                ? Colors.green
                                                : Colors.orange,
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        onPressed:
                                            () => _toggleBlock(
                                              user['key'],
                                              blocked,
                                              user['email'],
                                            ),
                                      ),
                                      const SizedBox(width: 4),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete,
                                          size: 18,
                                        ),
                                        tooltip: 'Delete User',
                                        color: Colors.red,
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        onPressed:
                                            () => _deleteUser(
                                              user['key'],
                                              user['email'],
                                            ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              // Additional row for trial account monitoring
                              if (isTrial && daysSinceFirstUse != null)
                                Container(
                                  margin: const EdgeInsets.only(top: 8),
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.analytics,
                                        size: 16,
                                        color: Colors.orange,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Trial Account: ${daysSinceFirstUse}d old • ${activeDaysCount} active days • ${avgSearchesPerDay} avg searches/day',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ),
                                      if (daysSinceLastActive != null &&
                                          daysSinceLastActive > 7)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.orange,
                                            borderRadius: BorderRadius.circular(
                                              3,
                                            ),
                                          ),
                                          child: Text(
                                            daysSinceLastActive > 30
                                                ? 'INACTIVE'
                                                : 'DORMANT',
                                            style: const TextStyle(
                                              fontSize: 10,
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      if (daysSinceLastActive != null &&
                                          daysSinceLastActive <= 7 &&
                                          avgSearchesPerDay >= 3)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.green,
                                            borderRadius: BorderRadius.circular(
                                              3,
                                            ),
                                          ),
                                          child: const Text(
                                            'CONVERT POTENTIAL',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _StatCard(this.label, this.value, {this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color?.withOpacity(0.1) ?? Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: color?.withOpacity(0.3) ?? Colors.blue.withOpacity(0.3),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(label, style: const TextStyle(fontSize: 10)),
        ],
      ),
    );
  }
}
