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
        showGrid: true,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 112),
            children: [
              const SolenneSectionTitle(
                eyebrow: 'Private account',
                title: 'Profile',
                subtitle: 'Your reflection space and setup controls.',
              ),
              const SizedBox(height: 18),
              SolenneCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Center(child: SolenneLogoOrb(size: 96)),
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
                    const Text(
                      'Your videos are saved as private journal entries. ML insights, consent controls, and exports arrive in the backend milestone.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const SolenneCard(
                child: Row(
                  children: [
                    Icon(Icons.lock_outline_rounded),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Solenne is a wellness journal, not medical care.',
                      ),
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
