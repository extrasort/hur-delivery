import { useEffect, useState } from 'react';
import { supabaseAdmin } from '../lib/supabase-admin';

interface SystemSetting {
  key: string;
  value: string;
  value_type: 'string' | 'number' | 'boolean';
  description?: string;
  is_public: boolean;
}

export default function Settings() {
  const [settings, setSettings] = useState<SystemSetting[]>([]);
  const [loading, setLoading] = useState(true);
  const [editing, setEditing] = useState<string | null>(null);
  const [editValue, setEditValue] = useState('');

  useEffect(() => {
    loadSettings();
  }, []);

  const loadSettings = async () => {
    setLoading(true);
    try {
      const { data, error } = await supabaseAdmin
        .from('system_settings')
        .select('*')
        .order('key');

      if (error) throw error;
      setSettings(data || []);
    } catch (error) {
      console.error('Error loading settings:', error);
    } finally {
      setLoading(false);
    }
  };

  const updateSetting = async (key: string, newValue: string) => {
    try {
      const { error } = await supabaseAdmin
        .from('system_settings')
        .update({ value: newValue, updated_at: new Date().toISOString() })
        .eq('key', key);

      if (error) throw error;

      // If system_enabled changed, handle special logic
      if (key === 'system_enabled' && newValue === 'false') {
        // Force all drivers offline
        await supabaseAdmin.rpc('force_all_drivers_offline');
        alert('تم تعطيل النظام وإخراج جميع السائقين / System disabled, all drivers logged out');
      } else if (key === 'system_enabled' && newValue === 'true') {
        alert('تم تفعيل النظام / System enabled');
      }

      setEditing(null);
      loadSettings();
    } catch (error: any) {
      console.error('Error updating setting:', error);
      alert(error.message || 'فشل التحديث / Update failed');
    }
  };

  const startEdit = (setting: SystemSetting) => {
    setEditing(setting.key);
    setEditValue(setting.value);
  };

  const cancelEdit = () => {
    setEditing(null);
    setEditValue('');
  };

  const renderValue = (setting: SystemSetting) => {
    if (editing === setting.key) {
      if (setting.value_type === 'boolean') {
        return (
          <select
            value={editValue}
            onChange={(e) => setEditValue(e.target.value)}
            className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 outline-none"
          >
            <option value="true">نعم / True</option>
            <option value="false">لا / False</option>
          </select>
        );
      } else if (setting.value_type === 'number') {
        return (
          <input
            type="number"
            value={editValue}
            onChange={(e) => setEditValue(e.target.value)}
            className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 outline-none"
          />
        );
      } else {
        return (
          <input
            type="text"
            value={editValue}
            onChange={(e) => setEditValue(e.target.value)}
            className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 outline-none"
          />
        );
      }
    }

    if (setting.value_type === 'boolean') {
      return (
        <span className={`px-3 py-1 rounded-full text-sm font-medium ${
          setting.value === 'true' ? 'bg-green-100 text-green-800' : 'bg-red-100 text-red-800'
        }`}>
          {setting.value === 'true' ? 'نعم / Yes' : 'لا / No'}
        </span>
      );
    }

    return <span className="text-gray-900">{setting.value}</span>;
  };

  const getSettingIcon = (key: string) => {
    if (key.includes('maintenance') || key.includes('enabled')) return 'fa-power-off';
    if (key.includes('version')) return 'fa-code-branch';
    if (key.includes('fee') || key.includes('balance')) return 'fa-coins';
    if (key.includes('timeout') || key.includes('time')) return 'fa-clock';
    if (key.includes('commission')) return 'fa-percentage';
    return 'fa-cog';
  };

  const getSettingColor = (key: string) => {
    if (key === 'system_enabled') {
      const setting = settings.find(s => s.key === key);
      return setting?.value === 'true' ? 'bg-green-100' : 'bg-red-100';
    }
    return 'bg-blue-100';
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center h-full">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary-500"></div>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-2xl font-bold text-gray-900">إعدادات النظام / System Settings</h2>
        <p className="text-gray-600 text-sm mt-1">التحكم في إعدادات النظام / Control system configuration</p>
      </div>

      {/* Critical Settings */}
      <div className="bg-gradient-to-r from-red-50 to-orange-50 border border-red-200 rounded-xl p-6">
        <div className="flex items-center gap-3 mb-4">
          <i className="fas fa-exclamation-triangle text-red-600 text-2xl"></i>
          <div>
            <h3 className="font-bold text-gray-900">إعدادات حرجة / Critical Settings</h3>
            <p className="text-sm text-gray-600">تأثر هذه الإعدادات على النظام بأكمله</p>
          </div>
        </div>

        {settings.filter(s => s.key === 'system_enabled' || s.key === 'maintenance_mode').map(setting => (
          <div key={setting.key} className="bg-white rounded-lg p-4 mb-2">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-4">
                <div className={`w-12 h-12 rounded-full flex items-center justify-center ${getSettingColor(setting.key)}`}>
                  <i className={`fas ${getSettingIcon(setting.key)} text-xl`}></i>
                </div>
                <div>
                  <p className="font-medium text-gray-900">{setting.key.replace(/_/g, ' ').toUpperCase()}</p>
                  {setting.description && <p className="text-sm text-gray-600">{setting.description}</p>}
                </div>
              </div>

              <div className="flex items-center gap-3">
                {editing === setting.key ? (
                  <>
                    {renderValue(setting)}
                    <button
                      onClick={() => updateSetting(setting.key, editValue)}
                      className="px-3 py-2 bg-green-500 hover:bg-green-600 text-white rounded-lg text-sm"
                    >
                      <i className="fas fa-check"></i>
                    </button>
                    <button
                      onClick={cancelEdit}
                      className="px-3 py-2 bg-gray-500 hover:bg-gray-600 text-white rounded-lg text-sm"
                    >
                      <i className="fas fa-times"></i>
                    </button>
                  </>
                ) : (
                  <>
                    {renderValue(setting)}
                    <button
                      onClick={() => startEdit(setting)}
                      className="px-3 py-2 bg-blue-500 hover:bg-blue-600 text-white rounded-lg text-sm"
                    >
                      <i className="fas fa-edit"></i>
                    </button>
                  </>
                )}
              </div>
            </div>
          </div>
        ))}
      </div>

      {/* Other Settings */}
      <div className="bg-white rounded-xl shadow-sm overflow-hidden">
        <div className="p-6 border-b border-gray-200">
          <h3 className="text-lg font-bold text-gray-900">جميع الإعدادات / All Settings</h3>
        </div>

        <div className="divide-y divide-gray-200">
          {settings.filter(s => s.key !== 'system_enabled' && s.key !== 'maintenance_mode').map(setting => (
            <div key={setting.key} className="p-4 hover:bg-gray-50">
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-4 flex-1">
                  <div className={`w-10 h-10 rounded-full flex items-center justify-center ${getSettingColor(setting.key)}`}>
                    <i className={`fas ${getSettingIcon(setting.key)}`}></i>
                  </div>
                  <div className="flex-1">
                    <p className="font-medium text-gray-900">{setting.key}</p>
                    {setting.description && <p className="text-sm text-gray-600">{setting.description}</p>}
                    <p className="text-xs text-gray-500 mt-1">
                      Type: {setting.value_type} | {setting.is_public ? 'Public' : 'Private'}
                    </p>
                  </div>
                </div>

                <div className="flex items-center gap-3">
                  {editing === setting.key ? (
                    <>
                      <div className="w-48">{renderValue(setting)}</div>
                      <button
                        onClick={() => updateSetting(setting.key, editValue)}
                        className="px-3 py-2 bg-green-500 hover:bg-green-600 text-white rounded-lg text-sm"
                      >
                        <i className="fas fa-check"></i>
                      </button>
                      <button
                        onClick={cancelEdit}
                        className="px-3 py-2 bg-gray-500 hover:bg-gray-600 text-white rounded-lg text-sm"
                      >
                        <i className="fas fa-times"></i>
                      </button>
                    </>
                  ) : (
                    <>
                      <div className="w-48">{renderValue(setting)}</div>
                      <button
                        onClick={() => startEdit(setting)}
                        className="px-3 py-2 bg-blue-500 hover:bg-blue-600 text-white rounded-lg text-sm"
                      >
                        <i className="fas fa-edit"></i>
                      </button>
                    </>
                  )}
                </div>
              </div>
            </div>
          ))}
        </div>
      </div>

      {settings.length === 0 && (
        <div className="bg-white rounded-xl shadow-sm p-12 text-center text-gray-500">
          <i className="fas fa-cog text-4xl mb-2"></i>
          <p>لا توجد إعدادات / No settings found</p>
        </div>
      )}
    </div>
  );
}

