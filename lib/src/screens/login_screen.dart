import 'package:flutter/material.dart';

class LoginScreen extends StatelessWidget {
  static const routeName = '/login';
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      // Lágy, “erdei” háttérátmenet – nem zavaró, a kártya olvasható marad
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFEFF7F1), // mohazöldes
              Color(0xFFF6F1EA), // nagyon halvány bézs/barnás
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: Column(
                  children: [
                    const Spacer(),
                    // App cím / szlogen
                    Text(
                      'Pathfinder',
                      style:
                          Theme.of(context).textTheme.headlineMedium?.copyWith(
                                color: const Color(0xFF1E3A2F),
                                fontWeight: FontWeight.w700,
                              ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Fedezd fel a környéket – túrázz okosan.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF465A4C),
                          ),
                    ),
                    const SizedBox(height: 24),

                    // Kártya a bejelentkezéshez
                    Card(
                      elevation: 6,
                      color: Colors.white,
                      shadowColor: const Color(0x332F6B3E),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          children: [
                            TextField(
                              decoration: const InputDecoration(
                                labelText: 'Email',
                                prefixIcon: Icon(Icons.email_outlined),
                              ),
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              decoration: const InputDecoration(
                                labelText: 'Jelszó',
                                prefixIcon: Icon(Icons.lock_outline),
                              ),
                              obscureText: true,
                              onSubmitted: (_) {},
                            ),
                            const SizedBox(height: 18),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed: () {
                                  // TODO: később login logika
                                },
                                child: const Text('Belépés'),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () {},
                                child: const Text('Elfelejtett jelszó'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Kisegítő sor alul
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Nincs még fiókod?'),
                        TextButton(
                          onPressed: () {},
                          child: const Text('Regisztráció'),
                        ),
                      ],
                    ),
                    const Spacer(),
                    // Apró “természetes” díszcsík
                    Container(
                      height: 4,
                      width: 120,
                      decoration: BoxDecoration(
                        color: cs.primary,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
