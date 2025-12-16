import { useEffect, useState, useRef } from 'react';
import { supabase, supabaseAdmin, type Order, type User } from '../lib/supabase-admin';
import mapboxgl from 'mapbox-gl';
import { config } from '../lib/config';

export default function Tracking() {
  const [activeOrders, setActiveOrders] = useState<(Order & { driver?: User })[]>([]);
  const [selectedOrder, setSelectedOrder] = useState<(Order & { driver?: User }) | null>(null);
  const [loading, setLoading] = useState(true);
  const [mapContainerReady, setMapContainerReady] = useState(false);
  const mapContainer = useRef<HTMLDivElement>(null);
  const map = useRef<mapboxgl.Map | null>(null);
  const markers = useRef<{ [key: string]: mapboxgl.Marker }>({});

  // Load orders and set up subscriptions
  useEffect(() => {
    loadActiveOrders();

    const channel = supabase
      .channel('tracking-changes')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'orders' }, () => {
        loadActiveOrders();
      })
      .on('postgres_changes', { event: '*', schema: 'public', table: 'users' }, () => {
        loadActiveOrders();
      })
      .subscribe();

    return () => {
      channel.unsubscribe();
    };
  }, []);

  // Initialize map when container is ready
  useEffect(() => {
    if (!mapContainerReady || !mapContainer.current || map.current) {
      return;
    }

    console.log('Tracking: Initializing map, container ready');
    
    const token = config.mapboxAccessToken || import.meta.env.VITE_MAPBOX_ACCESS_TOKEN;
    
    if (!token || token === '') {
      console.error('Tracking: Mapbox access token is missing!');
      console.error('Tracking: Please set VITE_MAPBOX_ACCESS_TOKEN in Netlify environment variables.');
      return;
    }
    
    try {
      mapboxgl.accessToken = token;
      map.current = new mapboxgl.Map({
        container: mapContainer.current,
        style: 'mapbox://styles/mapbox/streets-v12',
        center: [44.3661, 33.3152],
        zoom: 11,
        // Enable aggressive tile caching to reduce API calls and billing
        // Mapbox tiles are automatically cached by browser HTTP cache
        // This setting controls in-memory tile cache size (default is 50)
        maxTileCacheSize: 100, // Cache up to 100 tiles in memory (reduces re-fetching)
      });
      
      map.current.on('load', () => {
        console.log('Tracking: Map loaded successfully!');
        // Update markers after map is fully loaded
        setTimeout(() => {
          if (activeOrders.length > 0) {
            console.log('Tracking: Map loaded, updating markers for', activeOrders.length, 'orders');
            updateMapMarkers();
          }
        }, 500);
      });
      
      map.current.on('error', (e) => {
        console.error('Tracking: Map error:', e);
      });
      
      map.current.addControl(new mapboxgl.NavigationControl());
    } catch (error) {
      console.error('Tracking: Error initializing Mapbox:', error);
    }

    return () => {
      if (map.current) {
        map.current.remove();
        map.current = null;
      }
      Object.values(markers.current).forEach(marker => marker.remove());
    };
  }, [mapContainerReady]);

  useEffect(() => {
    // Only update markers if map exists and is loaded
    if (!map.current) {
      console.log('Tracking: Map not ready, skipping marker update');
      return;
    }
    
    // Check if map is loaded by checking if style is loaded
    if (map.current.isStyleLoaded()) {
      console.log('Tracking: Map style loaded, updating markers');
      updateMapMarkers();
    } else {
      console.log('Tracking: Map style not loaded, waiting for load event');
      // Wait for map to load
      const onLoad = () => {
        console.log('Tracking: Map load event fired, updating markers');
        updateMapMarkers();
        map.current?.off('load', onLoad);
      };
      map.current.on('load', onLoad);
    }
  }, [activeOrders]);

  const loadActiveOrders = async () => {
    setLoading(true);
    try {
      const { data: orders, error: ordersError } = await supabaseAdmin
        .from('orders')
        .select('*')
        .in('status', ['assigned', 'accepted', 'on_the_way'])
        .order('created_at', { ascending: false });

      if (ordersError) throw ordersError;

      // Load driver info for each order
      const ordersWithDrivers = await Promise.all(
        (orders || []).map(async (order) => {
          if (order.driver_id) {
            const { data: driver } = await supabaseAdmin
              .from('users')
              .select('*')
              .eq('id', order.driver_id)
              .single();
            return { ...order, driver };
          }
          return order;
        })
      );

      setActiveOrders(ordersWithDrivers);
    } catch (error) {
      console.error('Error loading active orders:', error);
    } finally {
      setLoading(false);
    }
  };

  const updateMapMarkers = () => {
    if (!map.current) {
      console.log('Tracking: Cannot update markers - map.current is null');
      return;
    }

    if (!map.current.isStyleLoaded()) {
      console.log('Tracking: Map style not loaded yet, waiting...');
      return;
    }

    console.log('Tracking: Updating markers for', activeOrders.length, 'orders');
    console.log('Tracking: Active orders data:', activeOrders.map(o => ({
      id: o.id,
      pickup: { lat: o.pickup_latitude, lng: o.pickup_longitude },
      delivery: { lat: o.delivery_latitude, lng: o.delivery_longitude },
      driver: o.driver ? { lat: o.driver.latitude, lng: o.driver.longitude } : null
    })));

    // Clear existing markers
    Object.values(markers.current).forEach(marker => marker.remove());
    markers.current = {};

    // Helper function to validate coordinates
    const isValidCoordinate = (lat: any, lng: any): boolean => {
      const latNum = typeof lat === 'number' ? lat : parseFloat(lat);
      const lngNum = typeof lng === 'number' ? lng : parseFloat(lng);
      return !isNaN(latNum) && !isNaN(lngNum) && 
             latNum >= -90 && latNum <= 90 && 
             lngNum >= -180 && lngNum <= 180;
    };

    // Add markers for each order
    activeOrders.forEach(order => {
      const orderId = order.id;

      // 1. Pickup location marker (green/blue)
      const pickupLat = order.pickup_latitude;
      const pickupLng = order.pickup_longitude;
      if (isValidCoordinate(pickupLat, pickupLng)) {
        console.log('Tracking: Creating pickup marker for order', orderId, 'at', pickupLat, pickupLng);
        const pickupEl = document.createElement('div');
        pickupEl.innerHTML = `
          <div class="bg-green-500 rounded-full p-2 shadow-lg cursor-pointer border-2 border-white">
            <i class="fas fa-map-marker-alt text-white text-xs"></i>
          </div>
        `;
        pickupEl.style.cursor = 'pointer';
        pickupEl.onclick = () => {
          if (map.current) {
            map.current.flyTo({
              center: [order.pickup_longitude, order.pickup_latitude],
              zoom: 15,
              duration: 2000,
            });
            setSelectedOrder(order);
          }
        };

        const pickupPopup = new mapboxgl.Popup({ offset: 25 })
          .setHTML(`
            <div class="p-2">
              <p class="font-semibold text-xs text-green-700">نقطة الاستلام / Pickup</p>
              <p class="text-xs text-gray-600">${order.pickup_address || 'No address'}</p>
              <p class="text-xs text-gray-500">Order #${order.id.slice(0, 8)}</p>
            </div>
          `);

        try {
          const lat = typeof pickupLat === 'number' ? pickupLat : parseFloat(pickupLat);
          const lng = typeof pickupLng === 'number' ? pickupLng : parseFloat(pickupLng);
          
          const pickupMarker = new mapboxgl.Marker(pickupEl)
            .setLngLat([lng, lat])
            .setPopup(pickupPopup)
            .addTo(map.current!);

          markers.current[`${orderId}-pickup`] = pickupMarker;
          console.log('Tracking: Successfully added pickup marker for order', orderId, 'at', [lng, lat]);
        } catch (error) {
          console.error('Tracking: Error adding pickup marker:', error, 'for order', orderId);
        }
      } else {
        console.log('Tracking: Skipping pickup marker for order', orderId, '- invalid coordinates:', pickupLat, pickupLng);
      }

      // 2. Dropoff/Delivery location marker (red)
      const deliveryLat = order.delivery_latitude;
      const deliveryLng = order.delivery_longitude;
      if (isValidCoordinate(deliveryLat, deliveryLng)) {
        console.log('Tracking: Creating dropoff marker for order', orderId, 'at', deliveryLat, deliveryLng);
        const dropoffEl = document.createElement('div');
        dropoffEl.innerHTML = `
          <div class="bg-red-500 rounded-full p-2 shadow-lg cursor-pointer border-2 border-white">
            <i class="fas fa-flag text-white text-xs"></i>
          </div>
        `;
        dropoffEl.style.cursor = 'pointer';
        dropoffEl.onclick = () => {
          if (map.current) {
            map.current.flyTo({
              center: [order.delivery_longitude, order.delivery_latitude],
              zoom: 15,
              duration: 2000,
            });
            setSelectedOrder(order);
          }
        };

        const dropoffPopup = new mapboxgl.Popup({ offset: 25 })
          .setHTML(`
            <div class="p-2">
              <p class="font-semibold text-xs text-red-700">نقطة التسليم / Dropoff</p>
              <p class="text-xs text-gray-600">${order.delivery_address || 'No address'}</p>
              <p class="text-xs text-gray-500">Order #${order.id.slice(0, 8)}</p>
            </div>
          `);

        try {
          const lat = typeof deliveryLat === 'number' ? deliveryLat : parseFloat(deliveryLat);
          const lng = typeof deliveryLng === 'number' ? deliveryLng : parseFloat(deliveryLng);
          
          const dropoffMarker = new mapboxgl.Marker(dropoffEl)
            .setLngLat([lng, lat])
            .setPopup(dropoffPopup)
            .addTo(map.current!);

          markers.current[`${orderId}-dropoff`] = dropoffMarker;
          console.log('Tracking: Successfully added dropoff marker for order', orderId, 'at', [lng, lat]);
        } catch (error) {
          console.error('Tracking: Error adding dropoff marker:', error, 'for order', orderId);
        }
      } else {
        console.log('Tracking: Skipping dropoff marker for order', orderId, '- invalid coordinates:', deliveryLat, deliveryLng);
      }

      // 3. Driver location marker (blue with motorcycle icon)
      const driverLat = order.driver?.latitude;
      const driverLng = order.driver?.longitude;
      if (order.driver && isValidCoordinate(driverLat, driverLng)) {
        console.log('Tracking: Creating driver marker for order', orderId, 'driver', order.driver.name, 'at', driverLat, driverLng);
        const driverEl = document.createElement('div');
        driverEl.innerHTML = `
          <div class="bg-blue-500 rounded-full p-3 shadow-lg cursor-pointer border-2 border-white">
            <i class="fas fa-motorcycle text-white"></i>
          </div>
        `;
        driverEl.style.cursor = 'pointer';
        driverEl.onclick = () => {
          if (map.current && order.driver?.longitude && order.driver?.latitude) {
            map.current.flyTo({
              center: [order.driver.longitude, order.driver.latitude],
              zoom: 15,
              duration: 2000,
            });
            setSelectedOrder(order);
          }
        };

        const driverPopup = new mapboxgl.Popup({ offset: 25 })
          .setHTML(`
            <div class="p-2">
              <p class="font-semibold text-xs text-blue-700">السائق / Driver</p>
              <p class="text-xs text-gray-600">${order.driver.name || 'Unknown'}</p>
              <p class="text-xs text-gray-500">Order #${order.id.slice(0, 8)}</p>
            </div>
          `);

        try {
          const lat = typeof driverLat === 'number' ? driverLat : parseFloat(String(driverLat || ''));
          const lng = typeof driverLng === 'number' ? driverLng : parseFloat(String(driverLng || ''));
          
          const driverMarker = new mapboxgl.Marker(driverEl)
            .setLngLat([lng, lat])
            .setPopup(driverPopup)
            .addTo(map.current!);

          markers.current[`${orderId}-driver`] = driverMarker;
          console.log('Tracking: Successfully added driver marker for order', orderId, 'at', [lng, lat]);
        } catch (error) {
          console.error('Tracking: Error adding driver marker:', error, 'for order', orderId);
        }
      } else {
        if (order.driver) {
          console.log('Tracking: Skipping driver marker for order', orderId, '- invalid coordinates:', driverLat, driverLng);
        } else {
          console.log('Tracking: Skipping driver marker for order', orderId, '- no driver assigned');
        }
      }
    });
    
    console.log('Tracking: Total markers added:', Object.keys(markers.current).length);
  };

  const focusOrder = (order: Order & { driver?: User }) => {
    if (!map.current) return;
    
    setSelectedOrder(order);
    
    // Collect all valid coordinates
    const coordinates: [number, number][] = [];
    
    // Add pickup location
    if (order.pickup_latitude && order.pickup_longitude) {
      const lat = typeof order.pickup_latitude === 'number' ? order.pickup_latitude : parseFloat(String(order.pickup_latitude || ''));
      const lng = typeof order.pickup_longitude === 'number' ? order.pickup_longitude : parseFloat(String(order.pickup_longitude || ''));
      if (!isNaN(lat) && !isNaN(lng)) {
        coordinates.push([lng, lat]);
      }
    }
    
    // Add delivery location
    if (order.delivery_latitude && order.delivery_longitude) {
      const lat = typeof order.delivery_latitude === 'number' ? order.delivery_latitude : parseFloat(String(order.delivery_latitude || ''));
      const lng = typeof order.delivery_longitude === 'number' ? order.delivery_longitude : parseFloat(String(order.delivery_longitude || ''));
      if (!isNaN(lat) && !isNaN(lng)) {
        coordinates.push([lng, lat]);
      }
    }
    
    // Add driver location
    if (order.driver?.latitude && order.driver?.longitude) {
      const lat = typeof order.driver.latitude === 'number' ? order.driver.latitude : parseFloat(String(order.driver.latitude || ''));
      const lng = typeof order.driver.longitude === 'number' ? order.driver.longitude : parseFloat(String(order.driver.longitude || ''));
      if (!isNaN(lat) && !isNaN(lng)) {
        coordinates.push([lng, lat]);
      }
    }
    
    if (coordinates.length === 0) {
      console.log('Tracking: No valid coordinates to focus on for order', order.id);
      return;
    }
    
    // If we have multiple points, fit bounds to show all of them
    if (coordinates.length > 1) {
      const bounds = coordinates.reduce((bounds, coord) => {
        return bounds.extend(coord as [number, number]);
      }, new mapboxgl.LngLatBounds(coordinates[0] as [number, number], coordinates[0] as [number, number]));
      
      map.current.fitBounds(bounds, {
        padding: 100,
        duration: 2000,
        maxZoom: 15
      });
      
      console.log('Tracking: Fitting bounds to show all points for order', order.id, 'with', coordinates.length, 'points');
    } else {
      // Single point, just fly to it
      map.current.flyTo({
        center: coordinates[0],
        zoom: 15,
        duration: 2000,
      });
      
      console.log('Tracking: Flying to single point for order', order.id);
    }
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center h-full">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary-500"></div>
      </div>
    );
  }

  return (
    <div className="h-[calc(100vh-8rem)] flex gap-6">
      {/* Orders List */}
      <div className="w-96 bg-white rounded-xl shadow-sm flex flex-col overflow-hidden">
        <div className="p-4 border-b border-gray-200">
          <h2 className="text-xl font-bold text-gray-900">التتبع المباشر / Live Tracking</h2>
          <p className="text-sm text-gray-600 mt-1">{activeOrders.length} طلب نشط</p>
        </div>

        <div className="flex-1 overflow-y-auto">
          {activeOrders.map(order => (
            <div
              key={order.id}
              onClick={() => focusOrder(order)}
              className={`p-4 border-b border-gray-100 hover:bg-gray-50 cursor-pointer ${
                selectedOrder?.id === order.id ? 'bg-blue-50' : ''
              }`}
            >
              <div className="flex items-center justify-between mb-2">
                <span className="text-sm font-mono text-gray-900">#{order.id.slice(0, 8)}</span>
                <span className={`px-2 py-1 text-xs rounded-full ${
                  order.status === 'assigned' ? 'bg-blue-100 text-blue-800' :
                  order.status === 'accepted' ? 'bg-indigo-100 text-indigo-800' :
                  'bg-purple-100 text-purple-800'
                }`}>
                  {order.status}
                </span>
              </div>

              <p className="text-sm font-medium text-gray-900 mb-1">{order.customer_name}</p>
              {order.driver && (
                <p className="text-xs text-gray-600 flex items-center gap-1">
                  <i className="fas fa-motorcycle"></i>
                  {order.driver?.name}
                  {order.driver?.latitude && (
                    <span className="text-green-600 mr-1">
                      <i className="fas fa-map-marker-alt"></i>
                    </span>
                  )}
                </p>
              )}

              <p className="text-xs text-gray-500 mt-2">
                {new Date(order.created_at).toLocaleTimeString('ar-IQ')}
              </p>
            </div>
          ))}

          {activeOrders.length === 0 && (
            <div className="text-center py-12 text-gray-500">
              <i className="fas fa-map-marked-alt text-4xl mb-2"></i>
              <p>لا توجد طلبات نشطة / No active orders</p>
            </div>
          )}
        </div>
      </div>

      {/* Map */}
      <div className="flex-1 bg-white rounded-xl shadow-sm overflow-hidden relative">
        <div 
          ref={(el) => {
            mapContainer.current = el;
            if (el && !mapContainerReady) {
              setMapContainerReady(true);
            }
          }} 
          className="w-full h-full"
        ></div>

        {selectedOrder && (
          <div className="absolute top-4 left-4 bg-white rounded-lg shadow-lg p-4 max-w-sm">
            <div className="flex items-center justify-between mb-3">
              <h3 className="font-bold text-gray-900">تفاصيل الطلب</h3>
              <button
                onClick={() => setSelectedOrder(null)}
                className="text-gray-400 hover:text-gray-600"
              >
                <i className="fas fa-times"></i>
              </button>
            </div>

            <div className="space-y-2 text-sm">
              <p><span className="font-medium">رقم الطلب:</span> #{selectedOrder.id.slice(0, 8)}</p>
              <p><span className="font-medium">العميل:</span> {selectedOrder.customer_name}</p>
              <p><span className="font-medium">الهاتف:</span> {selectedOrder.customer_phone}</p>
              {selectedOrder.driver && (
                <p><span className="font-medium">السائق:</span> {selectedOrder.driver.name}</p>
              )}
              <p><span className="font-medium">الحالة:</span> {selectedOrder.status}</p>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
