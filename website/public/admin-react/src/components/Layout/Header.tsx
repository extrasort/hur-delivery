import { useState, useEffect } from 'react';

export default function Header() {
  const [currentTime, setCurrentTime] = useState(new Date());

  useEffect(() => {
    const timer = setInterval(() => setCurrentTime(new Date()), 1000);
    return () => clearInterval(timer);
  }, []);

  return (
    <header className="bg-white border-b border-gray-200 px-6 py-4 sticky top-0 z-20">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">لوحة التحكم الإدارية</h1>
          <p className="text-sm text-gray-500">Hur Delivery Admin Panel</p>
        </div>
        
        <div className="flex items-center gap-4">
          <div className="text-right">
            <div className="text-sm font-medium text-gray-900">
              {currentTime.toLocaleDateString('ar-IQ', { 
                weekday: 'long', 
                year: 'numeric', 
                month: 'long', 
                day: 'numeric' 
              })}
            </div>
            <div className="text-xs text-gray-500">
              {currentTime.toLocaleTimeString('ar-IQ')}
            </div>
          </div>
          
          <div className="w-px h-10 bg-gray-200"></div>
          
          <button className="relative p-2 text-gray-600 hover:text-primary-600 hover:bg-gray-50 rounded-lg transition-colors">
            <i className="fas fa-bell text-xl"></i>
            <span className="absolute top-1 right-1 w-2 h-2 bg-red-500 rounded-full"></span>
          </button>
        </div>
      </div>
    </header>
  );
}

