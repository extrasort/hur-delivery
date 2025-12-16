import 'dart:async';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

/// Service for managing neighborhood labels on the map
class NeighborhoodLabelsService {
  /// Neighborhood data with Arabic names and coordinates
  static const List<Map<String, dynamic>> neighborhoods = [
    {'name': 'حي الحنانة', 'lat': 32.005098019966525, 'lng': 44.33383990544202},
    {'name': 'حي الحسين', 'lat': 32.009269314458365, 'lng': 44.33405568951555},
    {'name': 'حي الكرامة', 'lat': 32.0141041009887, 'lng': 44.34109272445229},
    {'name': 'حي الصحة', 'lat': 32.01054946938756, 'lng': 44.34299822147059},
    {'name': 'حي المرحلين', 'lat': 32.01611070014482, 'lng': 44.33646109047613},
    {'name': 'حي الشعراء', 'lat': 32.015286600917975, 'lng': 44.334957648580406},
    {'name': 'حي العلماء', 'lat': 32.014729862177376, 'lng': 44.330281366921625},
    {'name': 'حي الغدير', 'lat': 32.01671945886399, 'lng': 44.34596587742843},
    {'name': 'حي الفرات', 'lat': 32.01905614074013, 'lng': 44.35221769346194},
    {'name': 'حي العدالة', 'lat': 32.022208009344794, 'lng': 44.36066808441254},
    {'name': 'حي الامير', 'lat': 32.006866220904634, 'lng': 44.365070755049466},
    {'name': 'حي الاسكان', 'lat': 32.005873246619764, 'lng': 44.351395169982446},
    {'name': 'حي الاشتراكي', 'lat': 32.002552885161634, 'lng': 44.35368671726379},
    {'name': 'حي السعد', 'lat': 32.001939837707674, 'lng': 44.34195818316487},
    {'name': 'حي المثنى', 'lat': 31.99912663250187, 'lng': 44.34448442711137},
    {'name': 'حي ابو خالد', 'lat': 31.996544281582462, 'lng': 44.33683505069235},
    {'name': 'حي المعلمين', 'lat': 31.99273538973644, 'lng': 44.3401778584111},
    {'name': 'حي الامام المهدي', 'lat': 31.988623340357005, 'lng': 44.34301031379616},
    {'name': 'حي عدن', 'lat': 31.993176550307187, 'lng': 44.34976404916102},
    {'name': 'حي السواق', 'lat': 31.996239460692895, 'lng': 44.3566888915987},
    {'name': 'حي الزهراء', 'lat': 31.99913931599307, 'lng': 44.36480349357464},
    {'name': 'حي القادسية', 'lat': 32.001952520811024, 'lng': 44.37330085976419},
    {'name': 'مجمع عماد سكر', 'lat': 31.996640043305735, 'lng': 44.371777222699926},
    {'name': 'حي الانصار', 'lat': 31.98750286672427, 'lng': 44.358527429735965},
    {'name': 'حي القدس', 'lat': 31.979652543272294, 'lng': 44.35200693983141},
    {'name': 'شارع المدينة', 'lat': 31.9917764055857, 'lng': 44.32384620866347},
    {'name': 'خان المخضر', 'lat': 31.996902540072213, 'lng': 44.32922622329257},
    {'name': 'حي الجامعة', 'lat': 32.03500819380669, 'lng': 44.35241700977221},
    {'name': 'حي السلام', 'lat': 32.03063341531937, 'lng': 44.34191558841886},
    {'name': 'حي الغري الثاني', 'lat': 32.02349243873796, 'lng': 44.33474492677049},
    {'name': 'حي النفط', 'lat': 32.02160961260607, 'lng': 44.32800625098189},
    {'name': 'حي الغري الاول', 'lat': 32.01851574622202, 'lng': 44.328720744221336},
    {'name': 'حي الشهداء', 'lat': 32.04876110800057, 'lng': 44.34690650567454},
    {'name': 'حي الوفاء', 'lat': 32.04876110800057, 'lng': 44.34690650567454},
    {'name': 'حي الهندية', 'lat': 32.054857440412235, 'lng': 44.34340122018436},
    {'name': 'حي الاطباء', 'lat': 32.02031456425115, 'lng': 44.328579644709244},
    {'name': 'حي العروبة', 'lat': 32.045700052904415, 'lng': 44.33382422674479},
    {'name': 'حي الجزيرة', 'lat': 32.045700052904415, 'lng': 44.33382422674479},
    {'name': 'حي الجمعية', 'lat': 32.04055211727648, 'lng': 44.326577223808215},
    {'name': 'حي المكرمة', 'lat': 32.06230655222661, 'lng': 44.32594211721888},
    {'name': 'حي العسكري', 'lat': 32.0660260536408, 'lng': 44.337680220489936},
    {'name': 'قرية الغدير', 'lat': 32.08636097926253, 'lng': 44.3306111844946},
    {'name': 'حي الشرطة', 'lat': 31.98195467289134, 'lng': 44.329922441761155},
    {'name': 'الجديدة', 'lat': 31.988596767158885, 'lng': 44.326891103621406},
    {'name': 'حي الحرفيين', 'lat': 31.991522497645853, 'lng': 44.36870907337595},
    {'name': 'حي الرحمة', 'lat': 32.01852404889218, 'lng': 44.317189873491806},
    {'name': 'حي ابو طالب', 'lat': 32.025548805151125, 'lng': 44.314601451938344},
    {'name': 'حي المهندسين', 'lat': 32.03400225538525, 'lng': 44.3135416934223},
    {'name': 'حي النصر', 'lat': 32.041474945424476, 'lng': 44.31325266834865},
    {'name': 'حي الميلاد', 'lat': 32.05176454978557, 'lng': 44.31270197320495},
    {'name': 'حي النداء', 'lat': 32.079403622680566, 'lng': 44.30757208318381},
    {'name': 'حي ميسان', 'lat': 32.05154644260673, 'lng': 44.36236593351947},
    {'name': 'جامعة الكوفة', 'lat': 32.01862643282866, 'lng': 44.37702681179998},
    {'name': 'حي الصناعي', 'lat': 32.016806959872504, 'lng': 44.37797244115495},
    {'name': 'الكوفة حي الشرطة', 'lat': 32.02406631573205, 'lng': 44.38199946653831},
    {'name': 'حي المتنبي', 'lat': 32.030647503988334, 'lng': 44.38266102041013},
    {'name': 'الكوفة حي العسكري', 'lat': 32.03484214753685, 'lng': 44.38145924609706},
    {'name': 'السهلة', 'lat': 32.03989462609451, 'lng': 44.378233723989055},
    {'name': 'حي كندة 1', 'lat': 32.02615764669632, 'lng': 44.38848593789461},
    {'name': 'الكوفة حي المعلمين', 'lat': 32.031121436909714, 'lng': 44.39171145992998},
    {'name': 'حي كندة 2', 'lat': 32.02176226729833, 'lng': 44.38871132622159},
    {'name': 'حي ميثم التمار', 'lat': 32.01911264351798, 'lng': 44.39056868264109},
    {'name': 'الجمهورية', 'lat': 32.03325745684228, 'lng': 44.40054412866054},
    {'name': 'السفير', 'lat': 32.030483238931225, 'lng': 44.40641963813284},
    {'name': 'مجمع المختار السكني', 'lat': 32.026146848916504, 'lng': 44.40837348765892},
    {'name': 'البراكية', 'lat': 32.00945053255765, 'lng': 44.41963913733821},
  ];

  /// Simplify the map style by hiding unnecessary details
  static Future<void> simplifyMapStyle(MapboxMap mapboxMap) async {
    try {
      print('🗺️ Starting aggressive label hiding...');
      
      // Hide labels immediately (before they render) - CRITICAL: do this FIRST
      await _hideAllLabelsNow(mapboxMap);
      print('   ✅ First pass completed');
      
      // Multiple rapid attempts to catch labels as they load
      for (int i = 0; i < 20; i++) {
        await Future.delayed(Duration(milliseconds: 50 * (i + 1)));
        await _hideAllLabelsNow(mapboxMap);
        if (i % 5 == 0) {
          print('   ✅ Pass ${i + 1} completed');
        }
      }
      
      // Continue hiding for 10 more seconds at longer intervals
      for (int i = 0; i < 10; i++) {
        await Future.delayed(const Duration(milliseconds: 1000));
        await _hideAllLabelsNow(mapboxMap);
        print('   ✅ Extended pass ${i + 1} completed');
      }
      
      print('✅ Label hiding sequence completed');
    } catch (e) {
      print('⚠️ Error simplifying map style: $e');
      // Continue anyway - some layers may not exist in all styles
    }
  }
  
  /// Start a periodic timer to continuously hide labels
  static Timer? _labelHidingTimer;
  
  /// Start aggressive label hiding timer (hides labels every 500ms for maximum effectiveness)
  static void startLabelHidingTimer(MapboxMap mapboxMap) {
    // Cancel existing timer if any
    _labelHidingTimer?.cancel();
    
    // Hide labels immediately
    _hideAllLabelsNow(mapboxMap);
    
    // Then hide every 500ms to catch any labels that appear (very aggressive)
    _labelHidingTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      _hideAllLabelsNow(mapboxMap);
    });
    
    print('✅ Started aggressive label hiding timer (every 500ms)');
  }
  
  /// Stop the label hiding timer
  static void stopLabelHidingTimer() {
    _labelHidingTimer?.cancel();
    _labelHidingTimer = null;
  }
  
  /// Set up a listener to continuously hide labels when style loads
  static void setupLabelHidingListener(MapboxMap mapboxMap) {
    // Note: Style loaded listener is handled via onStyleLoadedListener in MapWidget
    // This method is kept for potential future use or manual calls
  }

  /// Hide a single layer with visibility, opacity, text-field removal, and text-opacity
  static Future<void> _hideLayer(MapboxMap mapboxMap, String layerName) async {
    try {
      // Hide with visibility
      await mapboxMap.style.setStyleLayerProperty(layerName, 'visibility', 'none');
      // Set opacity to 0
      await mapboxMap.style.setStyleLayerProperty(layerName, 'opacity', 0);
      // Remove text-field if it exists (for symbol layers)
      try {
        await mapboxMap.style.setStyleLayerProperty(layerName, 'text-field', '');
      } catch (_) {}
      // Set text-opacity to 0 (for text labels in symbol layers)
      try {
        await mapboxMap.style.setStyleLayerProperty(layerName, 'text-opacity', 0);
      } catch (_) {}
      // Set text-color to transparent
      try {
        await mapboxMap.style.setStyleLayerProperty(layerName, 'text-color', '#00000000');
      } catch (_) {}
    } catch (_) {}
  }

  /// Hide all label layers aggressively
  static Future<void> _hideAllLabelsNow(MapboxMap mapboxMap) async {
    try {
      // CRITICAL: First, try to get all layers and hide symbol types dynamically
      // This is more reliable than hardcoding layer names
      try {
        // Get all style layer IDs by attempting to access the style
        // Note: Mapbox Flutter SDK doesn't expose getAllLayers directly,
        // so we'll use a comprehensive list + pattern matching
        final allPossibleLabelLayers = [
          // Symbol layers (most common for labels)
          'symbol',
          'symbol-sm',
          'symbol-md',
          'symbol-lg',
          'symbol-shield',
          'symbol-icon',
          'symbol-text',
          // Common label prefixes in Mapbox styles
          'place',
          'road',
          'poi',
          'transit',
          'waterway',
          'admin',
          'settlement',
          'airport',
          'boundary',
          'country',
          'region',
          'marine',
          'mountain',
          'natural',
          'housenum',
          'address',
          'street',
          'water-name',
          'landform',
          'landcover',
          'park',
          'cemetery',
          'hospital',
          'school',
          'bridge',
          'tunnel',
          'ferry',
        ];
        
        // Hide all layers with label-related suffixes
        final suffixes = ['', '-label', '-label-sm', '-label-md', '-label-lg', '-name'];
        
        for (final base in allPossibleLabelLayers) {
          for (final suffix in suffixes) {
            final layerName = '$base$suffix';
            await _hideLayer(mapboxMap, layerName);
          }
        }
      } catch (e) {
        print('⚠️ Error in dynamic layer hiding: $e');
      }
      
      // IMPORTANT: Hide ALL symbol layers that might contain text
      // Symbol layers are the main source of text labels in Mapbox
      final symbolLayerPatterns = [
        'symbol',
        'symbol-sm',
        'symbol-md', 
        'symbol-lg',
        'symbol-shield',
        'symbol-icon',
        'symbol-text',
      ];
      
      for (final pattern in symbolLayerPatterns) {
        await _hideLayer(mapboxMap, pattern);
      }
      
      // Try to hide layers using a comprehensive list
      // We'll attempt to hide layers that commonly contain labels
      // Hide POI labels - use BOTH visibility and opacity
      await _hideLayer(mapboxMap, 'poi-label');

      // Hide road labels (we'll show only neighborhood names)
      await _hideLayer(mapboxMap, 'road-label');

      // Hide transit labels
      await _hideLayer(mapboxMap, 'transit-label');

      // Hide waterway labels
      await _hideLayer(mapboxMap, 'waterway-label');

      // Hide place labels (city/neighborhood names from Mapbox)
      await _hideLayer(mapboxMap, 'place-label');

      // Hide locality labels (local area names)
      await _hideLayer(mapboxMap, 'place-locality');

      // Hide neighborhood labels from Mapbox (we use our own)
      await _hideLayer(mapboxMap, 'place-neighbourhood');

      // Hide district labels
      await _hideLayer(mapboxMap, 'place-district');

      // Hide admin boundaries labels (keep only for context)
      await _hideLayer(mapboxMap, 'admin-1-boundary');

      // Hide admin labels (country/region names)
      await _hideLayer(mapboxMap, 'admin-label');

      // Hide city labels
      await _hideLayer(mapboxMap, 'place-city');

      // Hide state/province labels
      await _hideLayer(mapboxMap, 'place-state');

      // Hide country labels
      await _hideLayer(mapboxMap, 'place-country');

      // Hide village labels
      await _hideLayer(mapboxMap, 'place-village');

      // Hide town labels
      await _hideLayer(mapboxMap, 'place-town');

      // Hide suburb labels
      await _hideLayer(mapboxMap, 'place-suburb');

      // Hide region labels
      await _hideLayer(mapboxMap, 'place-region');

      // Hide other place labels
      await _hideLayer(mapboxMap, 'place-other');

      // Hide any remaining place label variants
      await _hideLayer(mapboxMap, 'place-label-sm'); // Small place labels
      await _hideLayer(mapboxMap, 'place-label-md'); // Medium place labels
      await _hideLayer(mapboxMap, 'place-label-lg'); // Large place labels

      // Hide settlement labels
      await _hideLayer(mapboxMap, 'settlement-label');

      // Hide any label layers (catch-all for other label types)
      // Note: This might catch some layers that don't exist, but that's okay
      final labelLayersToHide = [
        'airport-label',
        'boundary-label',
        'country-label',
        'region-label',
        'marine-label',
        'mountain-peak-label',
        'natural-point-label',
        'natural-line-label',
        'natural-polygon-label',
        'housenum-label', // House numbers
        'address-label', // Address labels
        'street-number-label', // Street numbers
        'water-name-label', // Water body names
        'landform-label', // Landform labels
        'landcover-label', // Landcover labels
        'park-label', // Park labels
        'cemetery-label', // Cemetery labels
        'hospital-label', // Hospital labels
        'school-label', // School labels
        'bridge-label', // Bridge labels
        'tunnel-label', // Tunnel labels
        'ferry-label', // Ferry labels
      ];

      // Hide label layers with both visibility and opacity
      for (final layerName in labelLayersToHide) {
        await _hideLayer(mapboxMap, layerName);
      }

      // Additional common label layers that might exist
      final additionalLabelLayers = [
        'place-label-variant',
        'place-label-variant-nl', // Non-Latin variants
        'housenum-label-sm',
        'housenum-label-md',
        'housenum-label-lg',
        'street-name-label',
        'street-name-label-sm',
        'street-name-label-md',
        'street-name-label-lg',
        'airport-label-sm',
        'airport-label-md',
        'airport-label-lg',
        'mountain-peak-label-sm',
        'mountain-peak-label-md',
        'mountain-peak-label-lg',
        // Additional variants that might appear
        'place-city-sm',
        'place-city-md',
        'place-city-lg',
        'place-neighbourhood-sm',
        'place-neighbourhood-md',
        'place-neighbourhood-lg',
        'place-village-sm',
        'place-village-md',
        'place-village-lg',
        'place-town-sm',
        'place-town-md',
        'place-town-lg',
        'place-suburb-sm',
        'place-suburb-md',
        'place-suburb-lg',
        'place-locality-sm',
        'place-locality-md',
        'place-locality-lg',
        // Road name labels
        'road-name',
        'road-name-sm',
        'road-name-md',
        'road-name-lg',
        // Text layers (often contain labels)
        'symbol',
      ];

      // Hide additional label layers
      for (final layerName in additionalLabelLayers) {
        await _hideLayer(mapboxMap, layerName);
      }
      
      // Try to hide symbol layers (which contain text/labels)
      // Hide symbol layers that are likely text labels
      final symbolLayers = ['symbol', 'symbol-sm', 'symbol-md', 'symbol-lg'];
      for (final symbolLayer in symbolLayers) {
        await _hideLayer(mapboxMap, symbolLayer);
      }

      // Reduce building visibility to make it less cluttered
      try {
        await mapboxMap.style.setStyleLayerProperty(
          'building',
          'opacity',
          0.3,
        );
      } catch (_) {}

      print('✅ All labels hidden (attempt)');
    } catch (e) {
      // Ignore errors - some layers may not exist
      print('⚠️ Error hiding some labels: $e');
    }
  }

  /// Add neighborhood labels to the map
  static Future<List<PointAnnotation>> addNeighborhoodLabels(
    PointAnnotationManager pointManager,
  ) async {
    final labels = <PointAnnotation>[];

    for (final neighborhood in neighborhoods) {
      try {
        final label = await pointManager.create(
          PointAnnotationOptions(
            geometry: Point(
              coordinates: Position(
                neighborhood['lng'] as double,
                neighborhood['lat'] as double,
              ),
            ),
            textField: neighborhood['name'] as String,
            textColor: 0xFF1E293B, // Dark slate gray for good visibility
            textHaloColor: 0xFFFFFFFF, // White halo for contrast
            textHaloWidth: 3.0, // Thick halo for readability
            textSize: 14.0, // Readable size
            textAnchor: TextAnchor.CENTER, // Center the text
          ),
        );
        labels.add(label);
      } catch (e) {
        print('⚠️ Error adding neighborhood label ${neighborhood['name']}: $e');
      }
    }

    print('✅ Added ${labels.length} neighborhood labels to map');
    return labels;
  }

  /// Remove all neighborhood labels
  static Future<void> removeNeighborhoodLabels(
    PointAnnotationManager pointManager,
    List<PointAnnotation> labels,
  ) async {
    for (final label in labels) {
      try {
        await pointManager.delete(label);
      } catch (e) {
        print('⚠️ Error removing neighborhood label: $e');
      }
    }
  }
}

