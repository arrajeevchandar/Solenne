import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/organic_background.dart';
import '../../core/widgets/solenne_button.dart';
import '../../core/widgets/solenne_card.dart';
import '../../core/widgets/solenne_visuals.dart';
import '../auth/auth_providers.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(firebaseAuthProvider).currentUser;
    return Scaffold(
      body: OrganicBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
            children: [
              const SectionLabel('Account'),
              const SizedBox(height: 8),
              Text(
                'Profile',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 20),
              SolenneCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Center(child: SolenneOrb(size: 88)),
                    const SizedBox(height: 18),
                    Text(
                      user?.displayName ?? 'Solenne user',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      user?.email ?? '',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 20),
                    const SectionLabel('Privacy'),
                    const SizedBox(height: 8),
                    Text(
                      'Insights, consent controls, and privacy export will be added with the backend analysis milestone.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              SolenneButton(
                label: 'Sign Out',
                icon: Icons.logout_rounded,
                isSecondary: true,
                onPressed: () async {
                  await ref.read(authRepositoryProvider).signOut();
                  if (context.mounted) context.go('/login');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
