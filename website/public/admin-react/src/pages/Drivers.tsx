import { useEffect, useState, useRef } from 'react';
import { supabase, supabaseAdmin, type User } from '../lib/supabase-admin';
import mapboxgl from 'mapbox-gl';
import { config } from '../lib/config';

export default function Drivers() {
  const [drivers, setDrivers] = useState<User[]>([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState('');
  const [filter, setFilter] = useState<'all' | 'online' | 'offline' | 'available'>('all');
  const [selectedDriver, setSelectedDriver] = useState<User | null>(null);
  const [mapContainerReady, setMapContainerReady] = useState(false);
  const mapContainer = useRef<HTMLDivElement>(null);
  const map = useRef<mapboxgl.Map | null>(null);
  const markers = useRef<{ [key: string]: mapboxgl.Marker }>({});

  // Load drivers and set up subscriptions
  useEffect(() => {
    loadDrivers();

    const channel = supabase
      .channel('drivers-changes')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'users' }, (payload) => {
        if (payload.new && (payload.new as User).role === 'driver') {
          loadDrivers();
        }
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

    console.log('Drivers: Initializing map, container ready');
    
    const token = config.mapboxAccessToken || import.meta.env.VITE_MAPBOX_ACCESS_TOKEN;
    
    if (!token || token === '') {
      console.error('Drivers: Mapbox access token is missing!');
      console.error('Drivers: Please set VITE_MAPBOX_ACCESS_TOKEN in Netlify environment variables.');
      return;
    }
    
    try {
      mapboxgl.accessToken = token;
      map.current = new mapboxgl.Map({
        container: mapContainer.current,
        style: 'mapbox://styles/mapbox/streets-v12',
        center: [44.3661, 33.3152], // Baghdad coordinates
        zoom: 11,
        // Enable aggressive tile caching to reduce API calls and billing
        // Mapbox tiles are automatically cached by browser HTTP cache
        // This setting controls in-memory tile cache size (default is 50)
        maxTileCacheSize: 100, // Cache up to 100 tiles in memory (reduces re-fetching)
      });
      
      map.current.on('load', () => {
        console.log('Drivers: Map loaded successfully!');
        // Update markers after map is fully loaded
        setTimeout(() => {
          if (drivers.length > 0) {
            console.log('Drivers: Map loaded, updating markers for', drivers.length, 'drivers');
            updateMapMarkers();
          }
        }, 500);
      });
      
      map.current.on('error', (e) => {
        console.error('Drivers: Map error:', e);
      });

      map.current.addControl(new mapboxgl.NavigationControl());
    } catch (error) {
      console.error('Drivers: Error initializing Mapbox:', error);
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
      console.log('Drivers: Map not ready, skipping marker update');
      return;
    }
    
    // Check if map is loaded by checking if style is loaded
    if (map.current.isStyleLoaded()) {
      console.log('Drivers: Map style loaded, updating markers');
      updateMapMarkers();
    } else {
      console.log('Drivers: Map style not loaded, waiting for load event');
      // Wait for map to load
      const onLoad = () => {
        console.log('Drivers: Map load event fired, updating markers');
        updateMapMarkers();
        map.current?.off('load', onLoad);
      };
      map.current.on('load', onLoad);
    }
  }, [drivers]);

  const loadDrivers = async () => {
    setLoading(true);
    try {
      const { data, error } = await supabaseAdmin
        .from('users')
        .select('*')
        .eq('role', 'driver')
        .order('created_at', { ascending: false });

      if (error) throw error;
      setDrivers(data || []);
    } catch (error) {
      console.error('Error loading drivers:', error);
    } finally {
      setLoading(false);
    }
  };

  const updateMapMarkers = () => {
    if (!map.current) {
      console.log('Drivers: Cannot update markers - map.current is null');
      return;
    }

    if (!map.current.isStyleLoaded()) {
      console.log('Drivers: Map style not loaded yet, waiting...');
      return;
    }

    console.log('Drivers: Updating markers for', drivers.length, 'drivers');
    console.log('Drivers: Driver locations:', drivers.map(d => ({
      id: d.id,
      name: d.name,
      lat: d.latitude,
      lng: d.longitude
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

    // Add markers for drivers with location
    drivers.forEach(driver => {
      const driverLat = driver.latitude;
      const driverLng = driver.longitude;
      
      if (isValidCoordinate(driverLat, driverLng)) {
        console.log('Drivers: Creating marker for driver', driver.name, 'at', driverLat, driverLng);
        const el = document.createElement('div');
        el.className = 'driver-marker';
        el.innerHTML = `
          <div class="relative">
            <div class="${driver.is_online ? 'bg-green-500' : 'bg-gray-400'} rounded-full p-2 shadow-lg">
              <i class="fas fa-motorcycle text-white text-sm"></i>
            </div>
            ${driver.is_online ? '<div class="absolute -top-1 -right-1 w-3 h-3 bg-green-400 rounded-full animate-ping"></div>' : ''}
          </div>
        `;
        el.style.cursor = 'pointer';
        el.onclick = () => focusDriver(driver);

        // Create popup with driver name
        const popup = new mapboxgl.Popup({ offset: 25 })
          .setHTML(`
            <div class="p-2">
              <p class="font-semibold text-sm">${driver.name || 'Unknown'}</p>
              <p class="text-xs text-gray-600">${driver.phone || ''}</p>
              ${driver.is_online ? '<span class="text-xs text-green-600">متصل / Online</span>' : '<span class="text-xs text-gray-500">غير متصل / Offline</span>'}
            </div>
          `);

        try {
          const lat = typeof driverLat === 'number' ? driverLat : parseFloat(String(driverLat || ''));
          const lng = typeof driverLng === 'number' ? driverLng : parseFloat(String(driverLng || ''));
          
          const marker = new mapboxgl.Marker(el)
            .setLngLat([lng, lat])
            .setPopup(popup)
            .addTo(map.current!);

          markers.current[driver.id] = marker;
          console.log('Drivers: Successfully added marker for driver', driver.name, 'at', [lng, lat]);
        } catch (error) {
          console.error('Drivers: Error adding marker for driver', driver.name, ':', error);
        }
      } else {
        console.log('Drivers: Skipping marker for driver', driver.name, '- invalid coordinates:', driverLat, driverLng);
      }
    });
    
    console.log('Drivers: Total markers added:', Object.keys(markers.current).length);
  };

  const filteredDrivers = drivers.filter(driver => {
    // Search filter
    if (searchTerm) {
      const search = searchTerm.toLowerCase();
      const matchesSearch = driver.name?.toLowerCase().includes(search) ||
                           driver.phone?.includes(search);
      if (!matchesSearch) return false;
    }

    const isOnline = driver.is_online === true;
    const isAvailable = driver.is_available ?? isOnline;

    // Status filter
    if (filter === 'online' && !isOnline) return false;
    if (filter === 'offline' && isOnline) return false;
    if (filter === 'available' && !isAvailable) return false;

    return true;
  });

  const focusDriver = (driver: User) => {
    if (map.current && driver.latitude && driver.longitude) {
      map.current.flyTo({
        center: [driver.longitude, driver.latitude],
        zoom: 15,
        duration: 2000,
      });
      setSelectedDriver(driver);
    }
  };

  const copyCoordinates = (lat: number, lng: number) => {
    navigator.clipboard.writeText(`${lat}, ${lng}`);
    alert('تم نسخ الإحداثيات / Coordinates copied');
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
      {/* Drivers List */}
      <div className="w-96 bg-white rounded-xl shadow-sm flex flex-col overflow-hidden">
        <div className="p-4 border-b border-gray-200">
          <h2 className="text-xl font-bold text-gray-900 mb-4">السائقون / Drivers</h2>
          
          <input
            type="search"
            placeholder="البحث... / Search..."
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 outline-none mb-3"
          />

          <div className="flex gap-2">
            <button
              onClick={() => setFilter('all')}
              className={`flex-1 px-3 py-1 text-xs rounded ${filter === 'all' ? 'bg-primary-500 text-white' : 'bg-gray-100 text-gray-700'}`}
            >
              الكل / All
            </button>
            <button
              onClick={() => setFilter('online')}
              className={`flex-1 px-3 py-1 text-xs rounded ${filter === 'online' ? 'bg-green-500 text-white' : 'bg-gray-100 text-gray-700'}`}
            >
              متصل / Online
            </button>
            <button
              onClick={() => setFilter('available')}
              className={`flex-1 px-3 py-1 text-xs rounded ${filter === 'available' ? 'bg-blue-500 text-white' : 'bg-gray-100 text-gray-700'}`}
            >
              متاح / Available
            </button>
          </div>
        </div>

        <div className="flex-1 overflow-y-auto">
          {filteredDrivers.map(driver => {
            const isOnline = driver.is_online === true;
            const isAvailable = driver.is_available ?? isOnline;

            return (
            <div
              key={driver.id}
              onClick={() => focusDriver(driver)}
              className={`p-4 border-b border-gray-100 hover:bg-gray-50 cursor-pointer transition-colors ${
                selectedDriver?.id === driver.id ? 'bg-blue-50' : ''
              }`}
            >
              <div className="flex items-start justify-between mb-2">
                <div className="flex items-center gap-3">
                  <div className={`w-10 h-10 rounded-full flex items-center justify-center ${
                    isOnline ? 'bg-green-100' : 'bg-gray-100'
                  }`}>
                    <i className={`fas fa-motorcycle ${isOnline ? 'text-green-600' : 'text-gray-500'}`}></i>
                  </div>
                  <div>
                    <p className="text-sm font-medium text-gray-900">{driver.name}</p>
                    <p className="text-xs text-gray-500">{driver.phone}</p>
                  </div>
                </div>
                {isOnline && (
                  <span className="inline-flex items-center gap-1 px-2 py-1 bg-green-100 text-green-800 text-xs rounded-full">
                    <span className="w-1.5 h-1.5 bg-green-500 rounded-full animate-pulse"></span>
                    متصل
                  </span>
                )}
              </div>

              <div className="flex items-center gap-4 text-xs text-gray-600">
                {driver.vehicle_type && (
                  <span className="flex items-center gap-1">
                    <i className="fas fa-motorcycle"></i>
                    {driver.vehicle_type}
                  </span>
                )}
                {isAvailable && (
                  <span className="flex items-center gap-1 text-blue-600">
                    <i className="fas fa-check-circle"></i>
                    متاح
                  </span>
                )}
                {driver.latitude && driver.longitude && (
                  <span className="flex items-center gap-1 text-purple-600">
                    <i className="fas fa-map-marker-alt"></i>
                    موقع نشط
                  </span>
                )}
              </div>

              {driver.last_location_update && (
                <p className="text-xs text-gray-400 mt-2">
                  آخر تحديث: {new Date(driver.last_location_update).toLocaleString('ar-IQ')}
                </p>
              )}
            </div>
            );
          })}

          {filteredDrivers.length === 0 && (
            <div className="text-center py-12 text-gray-500">
              <i className="fas fa-motorcycle text-4xl mb-2"></i>
              <p>لا يوجد سائقون / No drivers found</p>
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

        {/* Driver Info Overlay */}
        {selectedDriver && (
          <div className="absolute top-4 left-4 bg-white rounded-lg shadow-lg p-4 max-w-sm">
            <div className="flex items-start justify-between mb-3">
              <div className="flex items-center gap-3">
                <div className={`w-12 h-12 rounded-full flex items-center justify-center ${
                  selectedDriver.is_online ? 'bg-green-100' : 'bg-gray-100'
                }`}>
                  <i className={`fas fa-motorcycle text-xl ${
                    selectedDriver.is_online ? 'text-green-600' : 'text-gray-500'
                  }`}></i>
                </div>
                <div>
                  <p className="font-medium text-gray-900">{selectedDriver.name}</p>
                  <p className="text-sm text-gray-500">{selectedDriver.phone}</p>
                </div>
              </div>
              <button
                onClick={() => setSelectedDriver(null)}
                className="text-gray-400 hover:text-gray-600"
              >
                <i className="fas fa-times"></i>
              </button>
            </div>

            <div className="space-y-2 text-sm">
              <div className="flex items-center justify-between">
                <span className="text-gray-600">الحالة / Status:</span>
                <span className={`px-2 py-1 rounded text-xs ${
                  selectedDriver.is_online ? 'bg-green-100 text-green-800' : 'bg-gray-100 text-gray-800'
                }`}>
                  {selectedDriver.is_online ? 'متصل / Online' : 'غير متصل / Offline'}
                </span>
              </div>

              {selectedDriver.is_available !== undefined && (
                <div className="flex items-center justify-between">
                  <span className="text-gray-600">التوفر / Availability:</span>
                  <span className={`px-2 py-1 rounded text-xs ${
                    selectedDriver.is_available ? 'bg-blue-100 text-blue-800' : 'bg-gray-100 text-gray-800'
                  }`}>
                    {selectedDriver.is_available ? 'متاح / Available' : 'مشغول / Busy'}
                  </span>
                </div>
              )}

              {selectedDriver.vehicle_type && (
                <div className="flex items-center justify-between">
                  <span className="text-gray-600">نوع المركبة / Vehicle:</span>
                  <span className="font-medium">{selectedDriver.vehicle_type}</span>
                </div>
              )}

              {selectedDriver.wallet_balance !== undefined && (
                <div className="flex items-center justify-between">
                  <span className="text-gray-600">الرصيد / Balance:</span>
                  <span className="font-medium">{selectedDriver.wallet_balance.toLocaleString()} IQD</span>
                </div>
              )}

              {selectedDriver.latitude && selectedDriver.longitude && (
                <div className="pt-2 border-t border-gray-200">
                  <div className="flex items-center justify-between">
                    <span className="text-gray-600">الإحداثيات / Coordinates:</span>
                    <button
                      onClick={() => copyCoordinates(selectedDriver.latitude!, selectedDriver.longitude!)}
                      className="text-primary-600 hover:text-primary-800 text-xs"
                    >
                      <i className="fas fa-copy mr-1"></i>
                      نسخ / Copy
                    </button>
                  </div>
                  <p className="text-xs text-gray-500 mt-1 font-mono">
                    {selectedDriver.latitude?.toFixed(6)}, {selectedDriver.longitude?.toFixed(6)}
                  </p>
                </div>
              )}
            </div>

            <div className="mt-3 pt-3 border-t border-gray-200">
              <button
                onClick={() => window.location.href = `tel:${selectedDriver.phone}`}
                className="w-full px-4 py-2 bg-green-500 hover:bg-green-600 text-white rounded-lg transition-colors flex items-center justify-center gap-2"
              >
                <i className="fas fa-phone"></i>
                <span>اتصال / Call</span>
              </button>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
