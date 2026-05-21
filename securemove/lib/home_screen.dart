import 'package:flutter/material.dart';

import 'auth_service.dart';
import 'bus_list_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

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

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          children: [
            FutureBuilder<UserProfile?>(
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
                              color: Color(0xFF6C7894),
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    InkWell(
                      borderRadius: BorderRadius.circular(22),
                      onTap: _openProfile,
                      child: Ink(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22),
                          gradient: const LinearGradient(
                            colors: [Color(0xFF1B3F92), Color(0xFF4D83FF)],
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x223667F5),
                              blurRadius: 18,
                              offset: Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            profile?.initials ?? 'SM',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF17357E), Color(0xFF3564F2), Color(0xFF72C8FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'Secure ticketing',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'From city to seat number in minutes.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Search routes, compare operators, and pay with the method that works best for you.',
                    style: TextStyle(
                      color: Color(0xE8FFFFFF),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: const [
                      _HeroMetric(value: '5', label: 'Operators'),
                      SizedBox(width: 12),
                      _HeroMetric(value: '24/7', label: 'Booking'),
                      SizedBox(width: 12),
                      _HeroMetric(value: 'QR', label: 'Tickets'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x100F2554),
                    blurRadius: 32,
                    offset: Offset(0, 18),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _LocationField(
                    label: 'From',
                    hint: 'Starting city',
                    icon: Icons.trip_origin_rounded,
                    controller: _fromController,
                    cities: _supportedCities,
                  ),
                  const SizedBox(height: 14),
                  _LocationField(
                    label: 'To',
                    hint: 'Destination city',
                    icon: Icons.location_on_outlined,
                    controller: _toController,
                    cities: _supportedCities,
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFF8FBFF), Color(0xFFEFF4FF)],
                      ),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.travel_explore_rounded,
                          color: Color(0xFF2F59CF),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Choose your cities from the dropdown, then search for available buses.',
                            style: TextStyle(
                              color: Color(0xFF60708E),
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
                      color: const Color(0xFFF4F7FD),
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
                              foregroundColor: const Color(0xFF244AA8),
                              backgroundColor: Colors.white,
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
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Popular routes',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _RouteSuggestion(
                  title: 'Lusaka to Kabwe',
                  subtitle: 'Fast morning departures',
                  accent: const Color(0xFFEFF4FF),
                  onTap: () => _applyRoute('Lusaka', 'Kabwe'),
                ),
                _RouteSuggestion(
                  title: 'Ndola to Kitwe',
                  subtitle: 'Frequent weekday trips',
                  accent: const Color(0xFFFFF5E6),
                  onTap: () => _applyRoute('Ndola', 'Kitwe'),
                ),
                _RouteSuggestion(
                  title: 'Livingstone to Lusaka',
                  subtitle: 'Evening comfort coaches',
                  accent: const Color(0xFFEAFBF4),
                  onTap: () => _applyRoute('Livingstone', 'Lusaka'),
                ),
              ],
            ),
          ],
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
  });

  final String label;
  final String hint;
  final IconData icon;
  final TextEditingController controller;
  final List<String> cities;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: () => _showCityPicker(context),
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FBFF),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFDCE6FA)),
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
                  colors: [Color(0xFFEFF4FF), Color(0xFFDDE8FF)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: const Color(0xFF2A54C6), size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: Color(0xFF7D8AA3),
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
                          ? const Color(0xFF94A0B8)
                          : const Color(0xFF15306B),
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
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Color(0xFF7D8AA3),
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
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1A244AA8),
                      blurRadius: 32,
                      offset: Offset(0, 18),
                    ),
                  ],
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
                            color: const Color(0xFFEFF4FF),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(icon, color: const Color(0xFF2A54C6)),
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
                                  color: Color(0xFF6C7894),
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
                                    color: Color(0xFF6C7894),
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
                                      ? const Color(0xFFEFF4FF)
                                      : const Color(0xFFF8FBFF),
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
                                            color: const Color(0xFF2A54C6),
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
      (context as Element).markNeedsBuild();
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
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xE8FFFFFF),
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
  });

  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
            const Icon(Icons.alt_route_rounded, color: Color(0xFF244AA8)),
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
                color: Color(0xFF687792),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
