import 'package:flutter/material.dart';

import 'auth_service.dart';
import 'bus_list_screen.dart';
import 'profile_screen.dart';
import 'theme/app_colors.dart';
import 'theme/breakpoints.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.embedded = false});

  /// When true, the screen is mounted inside [TravelerShell] — we hide the
  /// avatar tap-target since the bottom nav already exposes the profile tab.
  final bool embedded;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _supportedCities = [
    'Chingola',
    'Chipata',
    'Kabwe',
    'Kasama',
    'Katete',
    'Kitwe',
    'Livingstone',
    'Lusaka',
    'Mongu',
    'Mufulira',
    'Ndola',
    'Solwezi',
  ];

  final _fromController = TextEditingController(text: 'Lusaka');
  final _toController = TextEditingController(text: 'Kabwe');

  @override
  void dispose() {
    _fromController.dispose();
    _toController.dispose();
    super.dispose();
  }

  void _swapLocations() {
    final currentFrom = _fromController.text;
    _fromController.text = _toController.text;
    _toController.text = currentFrom;
    setState(() {});
  }

  void _applyRoute(String from, String to) {
    _fromController.text = from;
    _toController.text = to;
    setState(() {});
  }

  void _searchBuses() {
    final from = _fromController.text.trim();
    final to = _toController.text.trim();
    if (from.isEmpty || to.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter both origin and destination.')),
      );
      return;
    }

    if (!_supportedCities.contains(from) || !_supportedCities.contains(to)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Choose both cities from the Zambia city picker before searching.',
          ),
        ),
      );
      return;
    }

    if (from == to) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Origin and destination cannot be the same city.'),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BusListScreen(from: from, to: to),
      ),
    );
  }

  Future<void> _openProfile() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDesktop = Breakpoints.isDesktop(context);

    final greeting = FutureBuilder<UserProfile?>(
      future: AuthService.instance.getCurrentUserProfile(),
      builder: (context, snapshot) {
        final profile = snapshot.data;
        return Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Plan a smoother trip',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    profile == null
                        ? 'Book faster, pay securely, and keep every ticket in one place.'
                        : 'Welcome back, ${profile.displayName}. Your next ride is a few taps away.',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            if (!widget.embedded) ...[
              const SizedBox(width: 14),
              InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: _openProfile,
                child: Ink(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    gradient: AppColors.brandGradientShort,
                    boxShadow: const [AppColors.cardShadow],
                  ),
                  child: Center(
                    child: Text(
                      profile?.initials ?? 'SM',
                      style: const TextStyle(
                        color: AppColors.textOnBrand,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );

    final heroCard = Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppColors.brandGradient,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              'Secure ticketing',
              style: TextStyle(
                color: AppColors.textOnBrand,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'From city to seat number in minutes.',
            style: TextStyle(
              color: AppColors.textOnBrand,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              height: 1.15,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Search routes, compare operators, and pay with the method that works best for you.',
            style: TextStyle(color: AppColors.textOnBrandSoft, height: 1.5),
          ),
          const SizedBox(height: 20),
          const Row(
            children: [
              _HeroMetric(value: '5', label: 'Operators'),
              SizedBox(width: 12),
              _HeroMetric(value: '24/7', label: 'Booking'),
              SizedBox(width: 12),
              _HeroMetric(value: 'QR', label: 'Tickets'),
            ],
          ),
        ],
      ),
    );

    final searchCard = Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [AppColors.elevatedShadow],
      ),
      child: Column(
        children: [
          _LocationField(
            label: 'From',
            hint: 'Starting city',
            icon: Icons.trip_origin_rounded,
            controller: _fromController,
            cities: _supportedCities,
            onChanged: () => setState(() {}),
          ),
          const SizedBox(height: 14),
          _LocationField(
            label: 'To',
            hint: 'Destination city',
            icon: Icons.location_on_outlined,
            controller: _toController,
            cities: _supportedCities,
            onChanged: () => setState(() {}),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.brandWash, AppColors.brandTint],
              ),
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.travel_explore_rounded,
                  color: AppColors.brandPrimary,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Choose your cities from the dropdown, then search for available buses.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.neutralTint,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _swapLocations,
                    icon: const Icon(Icons.swap_vert_rounded),
                    label: const Text('Swap route'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.brandPrimary,
                      backgroundColor: AppColors.surface,
                      side: BorderSide.none,
                      minimumSize: const Size.fromHeight(54),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _searchBuses,
                    icon: const Icon(Icons.search_rounded),
                    label: const Text('Search'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brandVivid,
                      foregroundColor: AppColors.textOnBrand,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    final popularRoutes = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Popular routes',
          style: theme.textTheme.titleLarge?.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        if (isDesktop)
          Column(
            children: [
              _RouteSuggestion(
                title: 'Lusaka to Kabwe',
                subtitle: 'Fast morning departures',
                accent: AppColors.brandTint,
                onTap: () => _applyRoute('Lusaka', 'Kabwe'),
                full: true,
              ),
              const SizedBox(height: 12),
              _RouteSuggestion(
                title: 'Ndola to Kitwe',
                subtitle: 'Frequent weekday trips',
                accent: AppColors.warningTint,
                onTap: () => _applyRoute('Ndola', 'Kitwe'),
                full: true,
              ),
              const SizedBox(height: 12),
              _RouteSuggestion(
                title: 'Livingstone to Lusaka',
                subtitle: 'Evening comfort coaches',
                accent: AppColors.successTint,
                onTap: () => _applyRoute('Livingstone', 'Lusaka'),
                full: true,
              ),
            ],
          )
        else
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _RouteSuggestion(
                title: 'Lusaka to Kabwe',
                subtitle: 'Fast morning departures',
                accent: AppColors.brandTint,
                onTap: () => _applyRoute('Lusaka', 'Kabwe'),
              ),
              _RouteSuggestion(
                title: 'Ndola to Kitwe',
                subtitle: 'Frequent weekday trips',
                accent: AppColors.warningTint,
                onTap: () => _applyRoute('Ndola', 'Kitwe'),
              ),
              _RouteSuggestion(
                title: 'Livingstone to Lusaka',
                subtitle: 'Evening comfort coaches',
                accent: AppColors.successTint,
                onTap: () => _applyRoute('Livingstone', 'Lusaka'),
              ),
            ],
          ),
      ],
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: Breakpoints.contentMaxWidth),
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                isDesktop ? 32 : 20,
                16,
                isDesktop ? 32 : 20,
                28,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  greeting,
                  const SizedBox(height: 24),
                  if (isDesktop)
                    // Desktop: hero | search side by side, popular routes below
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(flex: 5, child: heroCard),
                              const SizedBox(width: 20),
                              Expanded(flex: 4, child: searchCard),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),
                        popularRoutes,
                      ],
                    )
                  else ...[
                    heroCard,
                    const SizedBox(height: 22),
                    searchCard,
                    const SizedBox(height: 24),
                    popularRoutes,
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LocationField extends StatelessWidget {
  const _LocationField({
    required this.label,
    required this.hint,
    required this.icon,
    required this.controller,
    required this.cities,
    required this.onChanged,
  });

  final String label;
  final String hint;
  final IconData icon;
  final TextEditingController controller;
  final List<String> cities;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: () => _showCityPicker(context),
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.brandWash,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.brandBorder),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0D244AA8),
              blurRadius: 18,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.brandTint, Color(0xFFDDE8FF)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: AppColors.brandPrimary, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    controller.text.trim().isEmpty ? hint : controller.text,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: controller.text.trim().isEmpty
                          ? AppColors.textMuted
                          : AppColors.brandDeep,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCityPicker(BuildContext context) async {
    final searchController = TextEditingController(text: controller.text);

    final selectedCity = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        var filteredCities = List<String>.from(cities);

        return StatefulBuilder(
          builder: (context, setModalState) {
            void filterCities(String value) {
              final query = value.trim().toLowerCase();
              setModalState(() {
                filteredCities = cities
                    .where(
                      (city) => city.toLowerCase().contains(query),
                    )
                    .toList();
              });
            }

            final bottomInset = MediaQuery.of(context).viewInsets.bottom;

            return Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset + 16),
              child: Container(
                constraints: const BoxConstraints(maxHeight: 520),
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: const [AppColors.elevatedShadow],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: AppColors.brandTint,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(icon, color: AppColors.brandPrimary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Choose $label city',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Search and pick a route point from the list below.',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: searchController,
                      autofocus: true,
                      onChanged: filterCities,
                      decoration: InputDecoration(
                        hintText: 'Search city',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: searchController.text.isEmpty
                            ? null
                            : IconButton(
                                onPressed: () {
                                  searchController.clear();
                                  filterCities('');
                                },
                                icon: const Icon(Icons.close_rounded),
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Flexible(
                      child: filteredCities.isEmpty
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 36),
                                child: Text(
                                  'No matching cities found.',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              itemCount: filteredCities.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final city = filteredCities[index];
                                final isSelected = city == controller.text;

                                return Material(
                                  color: isSelected
                                      ? AppColors.brandTint
                                      : AppColors.brandWash,
                                  borderRadius: BorderRadius.circular(20),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(20),
                                    onTap: () =>
                                        Navigator.of(sheetContext).pop(city),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 14,
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            isSelected
                                                ? Icons.check_circle_rounded
                                                : Icons.location_city_rounded,
                                            color: AppColors.brandPrimary,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              city,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 16,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    searchController.dispose();

    if (selectedCity != null) {
      controller.text = selectedCity;
      onChanged();
    }
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({
    required this.value,
    required this.label,
  });

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.16),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                color: AppColors.textOnBrand,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textOnBrandSoft,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RouteSuggestion extends StatelessWidget {
  const _RouteSuggestion({
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
    this.full = false,
  });

  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;

  /// When true, the card stretches to full width and uses a horizontal layout
  /// (icon | text | chevron). Used on desktop where vertical stacking wastes space.
  final bool full;

  @override
  Widget build(BuildContext context) {
    if (full) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: accent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.alt_route_rounded,
                  color: AppColors.brandPrimary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_rounded,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
      );
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Ink(
        width: 220,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: accent,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.alt_route_rounded, color: AppColors.brandPrimary),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: const TextStyle(
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
