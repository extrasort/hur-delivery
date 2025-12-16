import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/localization/app_localizations.dart';
import 'create_order_screen.dart';
import 'create_bulk_order_screen.dart';
import 'create_scheduled_order_screen.dart';
import 'create_voice_order_screen.dart';

/// Master screen for all order creation modes with swipeable carousel
class OrderCreationCarousel extends StatefulWidget {
  final int initialPage;
  
  const OrderCreationCarousel({
    super.key,
    this.initialPage = 0,
  });

  @override
  State<OrderCreationCarousel> createState() => _OrderCreationCarouselState();
}

class _OrderCreationCarouselState extends State<OrderCreationCarousel> {
  late PageController _pageController;
  int _currentPage = 0;
  
  List<OrderCreationMode> _getModes(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return [
      OrderCreationMode(
        title: loc.normalOrder,
        icon: Icons.delivery_dining_rounded,
        color: AppColors.primary,
      ),
      OrderCreationMode(
        title: loc.bulkOrdersTitle,
        icon: Icons.inventory_2_rounded,
        color: Colors.orange.shade600,
      ),
      OrderCreationMode(
        title: loc.scheduledOrdersTitle,
        icon: Icons.event_rounded,
        color: Colors.blue.shade600,
      ),
      OrderCreationMode(
        title: loc.voiceOrderTitle,
        icon: Icons.mic_rounded,
        color: Colors.purple.shade600,
      ),
    ];
  }

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage;
    _pageController = PageController(initialPage: widget.initialPage);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int page, BuildContext context) {
    final modes = _getModes(context);
    setState(() {
      _currentPage = page % modes.length;
    });
    
    // Handle infinite scroll loop
    if (page < 0) {
      Future.delayed(const Duration(milliseconds: 1), () {
        _pageController.jumpToPage(modes.length - 1);
      });
    } else if (page >= modes.length) {
      Future.delayed(const Duration(milliseconds: 1), () {
        _pageController.jumpToPage(0);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final modes = _getModes(context);
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: List.generate(modes.length, (index) {
            final isActive = index == _currentPage;
            final isPrevious = index < _currentPage;
            final isNext = index > _currentPage;
            
            return GestureDetector(
              onTap: () {
                _pageController.animateToPage(
                  index,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: EdgeInsets.symmetric(
                  horizontal: isActive ? 16 : 8,
                  vertical: isActive ? 8 : 6,
                ),
                decoration: BoxDecoration(
                  color: isActive 
                      ? modes[index].color
                      : modes[index].color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      modes[index].icon,
                      color: isActive 
                          ? Colors.white 
                          : modes[index].color.withOpacity(0.7),
                      size: isActive ? 20 : 16,
                    ),
                    if (isActive) ...[
                      const SizedBox(width: 6),
                      Text(
                        modes[index].title,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          // Page Indicator Dots
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(modes.length, (index) {
                final isActive = index == _currentPage;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: isActive ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isActive 
                        ? modes[index].color 
                        : modes[index].color.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
          ),
          
          // Swipeable Pages
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (page) => _onPageChanged(page, context),
              children: const [
                CreateOrderScreen(embedded: true),
                CreateBulkOrderScreen(embedded: true),
                CreateScheduledOrderScreen(embedded: true),
                CreateVoiceOrderScreen(embedded: true),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class OrderCreationMode {
  final String title;
  final IconData icon;
  final Color color;

  OrderCreationMode({
    required this.title,
    required this.icon,
    required this.color,
  });
}

