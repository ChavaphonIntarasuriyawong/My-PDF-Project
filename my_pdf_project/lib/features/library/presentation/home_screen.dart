import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_bottom_nav_bar.dart';
import '../../../shared/widgets/app_drawer.dart';
import '../../../shared/widgets/pdf_card.dart';
import '../../auth/presentation/auth_providers.dart';
import 'library_providers.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning';
    if (h < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    // userProfileProvider watches Firestore directly → real-time updates
    final user = ref.watch(userProfileProvider).valueOrNull;
    final allBooks = ref.watch(allBooksProvider);
    final books = allBooks.valueOrNull ?? [];

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      drawer: AppDrawer(
        active: NavSection.library,
        onClose: () => _scaffoldKey.currentState?.closeDrawer(),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Top app bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _scaffoldKey.currentState?.openDrawer(),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      child: const Icon(Icons.menu,
                          color: AppColors.primary, size: 20),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text('MYPDF', style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    letterSpacing: -0.9,
                    color: AppColors.primary,
                  )),
                ],
              ),
            ),
            Expanded(
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_greeting()}, ${user?.name ?? ''}'.toUpperCase(),
                            style: AppTypography.greeting,
                          ),
                          const SizedBox(height: 4),
                          Text('Your Digital Library',
                              style: AppTypography.headlineLarge),
                          const SizedBox(height: 32),
                          Text('All PDF', style: AppTypography.titleMedium),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                  if (allBooks.isLoading)
                    const SliverToBoxAdapter(child: _ShimmerList(count: 2))
                  else if (books.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 48),
                        child: Center(
                          child: Text(
                            'No books yet. Tap Create to add one.',
                            style: AppTypography.bodyMedium,
                          ),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 128),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (ctx, i) => Padding(
                            padding: const EdgeInsets.only(bottom: 24),
                            child: SizedBox(
                              height: 548,
                              child: PdfCard(
                                book: books[i],
                                onTap: () =>
                                    context.push('/book/${books[i].id}'),
                              ),
                            ),
                          ),
                          childCount: books.length,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: AppBottomNavBar(
        onTap: (tab) {
          if (tab == NavTab.create) context.push(AppRoutes.newBook);
          if (tab == NavTab.profile) context.push(AppRoutes.profile);
        },
      ),
    );
  }
}

class _ShimmerList extends StatelessWidget {
  final int count;
  const _ShimmerList({required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: List.generate(
          count,
          (_) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
    );
  }
}
