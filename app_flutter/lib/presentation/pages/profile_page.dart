import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/user_stats_controller.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userStatsAsync = ref.watch(userStatsStreamProvider);
    final isPro = userStatsAsync.value?.isPro ?? false;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 32),
            // User Info Section
            Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5DFD3),
                    shape: BoxShape.circle,
                    image: const DecorationImage(
                      image: AssetImage(
                          'assets/images/default_avatar.png'), // Will fallback if not exists
                      fit: BoxFit.cover,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(Icons.person, size: 32, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '林小舒',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF4A4238),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isPro ? '尊贵的 PRO 会员' : '免费版用户',
                      style: TextStyle(
                        fontSize: 14,
                        color: isPro
                            ? const Color(0xFFD4AF37)
                            : const Color(0xFF8BA888),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 48),

            // Premium PRO Card
            GestureDetector(
              onTap: () {
                ref.read(userStatsControllerProvider).togglePro(!isPro);
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: isPro
                      ? const LinearGradient(
                          colors: [
                            Color(0xFFEAD28B),
                            Color(0xFFD4AF37),
                            Color(0xFFB0891D)
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : const LinearGradient(
                          colors: [Color(0xFF4A4238), Color(0xFF2B2520)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                  boxShadow: [
                    BoxShadow(
                      color: isPro
                          ? const Color(0xFFD4AF37).withOpacity(0.4)
                          : Colors.black.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'CozyClean PRO',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                            color:
                                isPro ? Colors.white : const Color(0xFFEAD28B),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        Icon(
                          Icons.workspace_premium_rounded,
                          color: isPro ? Colors.white : const Color(0xFFEAD28B),
                          size: 32,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      isPro ? '已解锁无限体力及全部高级特权' : '升级解锁无限体力与时光机',
                      style: TextStyle(
                        fontSize: 15,
                        color: isPro
                            ? Colors.white.withOpacity(0.9)
                            : Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      isPro ? '点击取消体验' : '点击立即升级 (¥8/月)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isPro
                            ? Colors.white.withOpacity(0.6)
                            : const Color(0xFFEAD28B),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
