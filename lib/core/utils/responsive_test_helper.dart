import 'package:flutter/material.dart';
import 'responsive_helper.dart';

/// Helper class for testing responsive design on different screen sizes
class ResponsiveTestHelper {
  static const Map<String, Size> testScreenSizes = {
    'iPhone SE': Size(375, 667),      // Very small screen
    'iPhone 12 mini': Size(375, 812), // Small screen
    'iPhone 12': Size(390, 844),      // Standard screen
    'iPhone 12 Pro Max': Size(428, 926), // Large screen
    'Samsung Galaxy S21': Size(384, 854), // Android standard
    'Pixel 5': Size(393, 851),        // Android compact
    'OnePlus 9': Size(412, 915),      // Android large
  };

  /// Creates a test widget that shows responsive behavior
  static Widget createResponsiveTestWidget() {
    return MaterialApp(
      title: 'Responsive Design Test',
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Responsive Design Test'),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Screen Size Information',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Builder(
                builder: (context) {
                  final screenSize = MediaQuery.of(context).size;
                  final isVerySmall = ResponsiveHelper.isVerySmallScreen(context);
                  final isSmall = ResponsiveHelper.isSmallScreen(context);
                  final isMobile = ResponsiveHelper.isMobile(context);
                  
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Screen Width: ${screenSize.width.toStringAsFixed(0)}px'),
                          Text('Screen Height: ${screenSize.height.toStringAsFixed(0)}px'),
                          const SizedBox(height: 8),
                          Text('Very Small Screen: ${isVerySmall ? "Yes" : "No"}'),
                          Text('Small Screen: ${isSmall ? "Yes" : "No"}'),
                          Text('Mobile Screen: ${isMobile ? "Yes" : "No"}'),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              const Text(
                'Responsive Text Examples',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Builder(
                builder: (context) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Heading 1 (Responsive)',
                        style: TextStyle(
                          fontSize: ResponsiveHelper.getResponsiveFontSize(context, 32),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Heading 2 (Responsive)',
                        style: TextStyle(
                          fontSize: ResponsiveHelper.getResponsiveFontSize(context, 24),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Body Text (Responsive)',
                        style: TextStyle(
                          fontSize: ResponsiveHelper.getResponsiveFontSize(context, 16),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Small Text (Responsive)',
                        style: TextStyle(
                          fontSize: ResponsiveHelper.getResponsiveFontSize(context, 14),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
              const Text(
                'Responsive Button Examples',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Builder(
                builder: (context) {
                  return Column(
                    children: [
                      SizedBox(
                        width: ResponsiveHelper.getResponsiveWidth(context, 200),
                        height: ResponsiveHelper.getResponsiveButtonHeight(context, 50),
                        child: ElevatedButton(
                          onPressed: () {},
                          child: Text(
                            'Responsive Button',
                            style: TextStyle(
                              fontSize: ResponsiveHelper.getResponsiveFontSize(context, 16),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: ResponsiveHelper.getResponsiveWidth(context, 150),
                        height: ResponsiveHelper.getResponsiveButtonHeight(context, 40),
                        child: OutlinedButton(
                          onPressed: () {},
                          child: Text(
                            'Small Button',
                            style: TextStyle(
                              fontSize: ResponsiveHelper.getResponsiveFontSize(context, 14),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
              const Text(
                'Responsive Spacing Examples',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Builder(
                builder: (context) {
                  return Column(
                    children: [
                      Container(
                        width: double.infinity,
                        height: ResponsiveHelper.getResponsiveSpacing(context, 20),
                        color: Colors.blue.withValues(alpha: 0.3),
                        child: const Center(child: Text('Responsive Height: 20')),
                      ),
                      SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, 16)),
                      Container(
                        width: double.infinity,
                        height: ResponsiveHelper.getResponsiveSpacing(context, 40),
                        color: Colors.green.withValues(alpha: 0.3),
                        child: const Center(child: Text('Responsive Height: 40')),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
              const Text(
                'Icon Size Examples',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Builder(
                builder: (context) {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Icon(
                        Icons.star,
                        size: ResponsiveHelper.getResponsiveIconSize(context, 24),
                        color: Colors.amber,
                      ),
                      Icon(
                        Icons.favorite,
                        size: ResponsiveHelper.getResponsiveIconSize(context, 32),
                        color: Colors.red,
                      ),
                      Icon(
                        Icons.home,
                        size: ResponsiveHelper.getResponsiveIconSize(context, 40),
                        color: Colors.blue,
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Creates a test route for different screen sizes
  static Route createTestRoute() {
    return MaterialPageRoute(
      builder: (context) => createResponsiveTestWidget(),
    );
  }
}
