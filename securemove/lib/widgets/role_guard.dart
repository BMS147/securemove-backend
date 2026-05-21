import 'package:flutter/material.dart';

import '../auth_service.dart';

class RoleGuard extends StatelessWidget {
  const RoleGuard({
    super.key,
    required this.allowedRoles,
    required this.child,
  });

  final Set<String> allowedRoles;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserProfile?>(
      future: AuthService.instance.getCurrentUserProfile(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final role = snapshot.data?.roleValue;
        if (role == null || !allowedRoles.contains(role)) {
          return Scaffold(
            appBar: AppBar(title: const Text('Access blocked')),
            body: const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Your account does not have access to this workspace.'),
              ),
            ),
          );
        }

        return child;
      },
    );
  }
}
