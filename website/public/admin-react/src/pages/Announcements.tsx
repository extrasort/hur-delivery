import { useEffect, useState } from 'react';
import { supabaseAdmin } from '../lib/supabase-admin';

interface Announcement {
  id: string;
  title: string;
  message: string;
  type: 'maintenance' | 'event' | 'update' | 'info' | 'warning' | 'success';
  is_active: boolean;
  is_dismissable: boolean;
  target_roles: string[];
  start_time?: string;
  end_time?: string;
  created_at: string;
}

export default function Announcements() {
  const [announcements, setAnnouncements] = useState<Announcement[]>([]);
  const [loading, setLoading] = useState(true);
  const [showModal, setShowModal] = useState(false);
  const [editingAnnouncement, setEditingAnnouncement] = useState<Announcement | null>(null);
  const [formData, setFormData] = useState({
    title: '',
    message: '',
    type: 'info' as Announcement['type'],
    is_dismissable: true,
    target_roles: ['driver', 'merchant'] as string[],
    start_time: '',
    end_time: '',
  });

  useEffect(() => {
    loadAnnouncements();
  }, []);

  const loadAnnouncements = async () => {
    setLoading(true);
    try {
      const { data, error } = await supabaseAdmin
        .from('system_announcements')
        .select('*')
        .order('created_at', { ascending: false });

      if (error) throw error;
      setAnnouncements(data || []);
    } catch (error) {
      console.error('Error loading announcements:', error);
    } finally {
      setLoading(false);
    }
  };

  const saveAnnouncement = async () => {
    try {
      if (editingAnnouncement) {
        const { error } = await supabaseAdmin
          .from('system_announcements')
          .update({
            title: formData.title,
            message: formData.message,
            type: formData.type,
            is_dismissable: formData.is_dismissable,
            target_roles: formData.target_roles,
            start_time: formData.start_time || null,
            end_time: formData.end_time || null,
          })
          .eq('id', editingAnnouncement.id);

        if (error) throw error;
        alert('تم تحديث الإعلان / Announcement updated');
      } else {
        const { error } = await supabaseAdmin
          .from('system_announcements')
          .insert({
            title: formData.title,
            message: formData.message,
            type: formData.type,
            is_dismissable: formData.is_dismissable,
            target_roles: formData.target_roles,
            start_time: formData.start_time || null,
            end_time: formData.end_time || null,
          });

        if (error) throw error;
        alert('تم إنشاء الإعلان / Announcement created');
      }

      setShowModal(false);
      setEditingAnnouncement(null);
      resetForm();
      loadAnnouncements();
    } catch (error: any) {
      console.error('Error saving announcement:', error);
      alert(error.message || 'فشل الحفظ / Save failed');
    }
  };

  const toggleAnnouncement = async (id: string, currentStatus: boolean) => {
    try {
      const { error } = await supabaseAdmin
        .from('system_announcements')
        .update({ is_active: !currentStatus })
        .eq('id', id);

      if (error) throw error;
      loadAnnouncements();
    } catch (error: any) {
      console.error('Error toggling announcement:', error);
      alert(error.message || 'فشل التحديث / Update failed');
    }
  };

  const deleteAnnouncement = async (id: string) => {
    if (!confirm('هل أنت متأكد من حذف هذا الإعلان؟ / Delete this announcement?')) return;

    try {
      const { error } = await supabaseAdmin
        .from('system_announcements')
        .delete()
        .eq('id', id);

      if (error) throw error;
      loadAnnouncements();
    } catch (error: any) {
      console.error('Error deleting announcement:', error);
      alert(error.message || 'فشل الحذف / Delete failed');
    }
  };

  const openCreateModal = () => {
    resetForm();
    setEditingAnnouncement(null);
    setShowModal(true);
  };

  const openEditModal = (announcement: Announcement) => {
    setFormData({
      title: announcement.title,
      message: announcement.message,
      type: announcement.type,
      is_dismissable: announcement.is_dismissable,
      target_roles: announcement.target_roles,
      start_time: announcement.start_time?.slice(0, 16) || '',
      end_time: announcement.end_time?.slice(0, 16) || '',
    });
    setEditingAnnouncement(announcement);
    setShowModal(true);
  };

  const resetForm = () => {
    setFormData({
      title: '',
      message: '',
      type: 'info',
      is_dismissable: true,
      target_roles: ['driver', 'merchant'],
      start_time: '',
      end_time: '',
    });
  };

  const toggleRole = (role: string) => {
    if (formData.target_roles.includes(role)) {
      setFormData({ ...formData, target_roles: formData.target_roles.filter(r => r !== role) });
    } else {
      setFormData({ ...formData, target_roles: [...formData.target_roles, role] });
    }
  };

  const getTypeBadge = (type: Announcement['type']) => {
    const badges = {
      maintenance: 'bg-yellow-100 text-yellow-800',
      event: 'bg-purple-100 text-purple-800',
      update: 'bg-blue-100 text-blue-800',
      info: 'bg-gray-100 text-gray-800',
      warning: 'bg-red-100 text-red-800',
      success: 'bg-green-100 text-green-800',
    };
    return badges[type] || badges.info;
  };

  const getTypeIcon = (type: Announcement['type']) => {
    const icons = {
      maintenance: 'fa-wrench',
      event: 'fa-calendar-star',
      update: 'fa-sync-alt',
      info: 'fa-info-circle',
      warning: 'fa-exclamation-triangle',
      success: 'fa-check-circle',
    };
    return icons[type] || icons.info;
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
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-2xl font-bold text-gray-900">الإعلانات / Announcements</h2>
          <p className="text-gray-600 text-sm mt-1">إدارة إعلانات النظام / Manage system announcements</p>
        </div>
        <button
          onClick={openCreateModal}
          className="px-4 py-2 bg-primary-500 hover:bg-primary-600 text-white rounded-lg font-medium"
        >
          <i className="fas fa-plus mr-2"></i>
          إنشاء إعلان / Create
        </button>
      </div>

      <div className="grid grid-cols-1 gap-4">
        {announcements.map(announcement => (
          <div key={announcement.id} className="bg-white rounded-xl shadow-sm p-6">
            <div className="flex items-start justify-between mb-4">
              <div className="flex items-start gap-4 flex-1">
                <div className={`w-12 h-12 rounded-full flex items-center justify-center ${
                  announcement.is_active ? getTypeBadge(announcement.type) : 'bg-gray-100'
                }`}>
                  <i className={`fas ${getTypeIcon(announcement.type)} text-xl`}></i>
                </div>
                <div className="flex-1">
                  <div className="flex items-center gap-3 mb-2">
                    <h3 className="text-lg font-bold text-gray-900">{announcement.title}</h3>
                    <span className={`px-3 py-1 text-xs font-medium rounded-full ${getTypeBadge(announcement.type)}`}>
                      {announcement.type}
                    </span>
                    {announcement.is_active ? (
                      <span className="px-3 py-1 text-xs font-medium rounded-full bg-green-100 text-green-800">
                        <i className="fas fa-check-circle mr-1"></i>نشط
                      </span>
                    ) : (
                      <span className="px-3 py-1 text-xs font-medium rounded-full bg-gray-100 text-gray-800">
                        <i className="fas fa-pause-circle mr-1"></i>موقوف
                      </span>
                    )}
                  </div>
                  <p className="text-gray-700 mb-3">{announcement.message}</p>
                  <div className="flex flex-wrap gap-4 text-sm text-gray-600">
                    <span>
                      <i className="fas fa-users mr-1"></i>
                      الأدوار: {announcement.target_roles.join(', ')}
                    </span>
                    {announcement.start_time && (
                      <span>
                        <i className="fas fa-calendar-check mr-1"></i>
                        من: {new Date(announcement.start_time).toLocaleString('ar-IQ')}
                      </span>
                    )}
                    {announcement.end_time && (
                      <span>
                        <i className="fas fa-calendar-times mr-1"></i>
                        إلى: {new Date(announcement.end_time).toLocaleString('ar-IQ')}
                      </span>
                    )}
                    <span>
                      {announcement.is_dismissable ? (
                        <><i className="fas fa-times-circle mr-1 text-blue-600"></i>يمكن إغلاقه</>
                      ) : (
                        <><i className="fas fa-ban mr-1 text-red-600"></i>لا يمكن إغلاقه</>
                      )}
                    </span>
                  </div>
                </div>
              </div>
              <div className="flex gap-2">
                <button
                  onClick={() => toggleAnnouncement(announcement.id, announcement.is_active)}
                  className={`px-3 py-2 rounded-lg text-sm ${
                    announcement.is_active 
                      ? 'bg-yellow-100 text-yellow-800 hover:bg-yellow-200'
                      : 'bg-green-100 text-green-800 hover:bg-green-200'
                  }`}
                  title={announcement.is_active ? 'تعطيل' : 'تفعيل'}
                >
                  <i className={`fas ${announcement.is_active ? 'fa-pause' : 'fa-play'}`}></i>
                </button>
                <button
                  onClick={() => openEditModal(announcement)}
                  className="px-3 py-2 bg-blue-100 text-blue-800 hover:bg-blue-200 rounded-lg text-sm"
                >
                  <i className="fas fa-edit"></i>
                </button>
                <button
                  onClick={() => deleteAnnouncement(announcement.id)}
                  className="px-3 py-2 bg-red-100 text-red-800 hover:bg-red-200 rounded-lg text-sm"
                >
                  <i className="fas fa-trash"></i>
                </button>
              </div>
            </div>
          </div>
        ))}
      </div>

      {announcements.length === 0 && (
        <div className="bg-white rounded-xl shadow-sm p-12 text-center text-gray-500">
          <i className="fas fa-bullhorn text-4xl mb-2"></i>
          <p>لا توجد إعلانات / No announcements</p>
        </div>
      )}

      {/* Create/Edit Modal */}
      {showModal && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-xl shadow-xl max-w-2xl w-full max-h-[90vh] overflow-y-auto">
            <div className="flex items-center justify-between p-6 border-b border-gray-200">
              <h3 className="text-xl font-bold text-gray-900">
                {editingAnnouncement ? 'تعديل الإعلان / Edit' : 'إنشاء إعلان / Create'} Announcement
              </h3>
              <button onClick={() => setShowModal(false)} className="text-gray-400 hover:text-gray-600">
                <i className="fas fa-times text-xl"></i>
              </button>
            </div>

            <div className="p-6 space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">العنوان / Title</label>
                <input
                  type="text"
                  value={formData.title}
                  onChange={(e) => setFormData({ ...formData, title: e.target.value })}
                  className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 outline-none"
                  placeholder="مثال: صيانة مجدولة"
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">الرسالة / Message</label>
                <textarea
                  value={formData.message}
                  onChange={(e) => setFormData({ ...formData, message: e.target.value })}
                  rows={4}
                  className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 outline-none"
                  placeholder="رسالة الإعلان..."
                ></textarea>
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">النوع / Type</label>
                <select
                  value={formData.type}
                  onChange={(e) => setFormData({ ...formData, type: e.target.value as Announcement['type'] })}
                  className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 outline-none"
                >
                  <option value="info">ℹ️ معلومات / Info</option>
                  <option value="success">✅ نجاح / Success</option>
                  <option value="warning">⚠️ تحذير / Warning</option>
                  <option value="maintenance">🔧 صيانة / Maintenance</option>
                  <option value="event">🎉 حدث / Event</option>
                  <option value="update">📱 تحديث / Update</option>
                </select>
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">الأدوار المستهدفة / Target Roles</label>
                <div className="flex flex-wrap gap-2">
                  {['driver', 'merchant', 'customer', 'admin'].map(role => (
                    <button
                      key={role}
                      type="button"
                      onClick={() => toggleRole(role)}
                      className={`px-4 py-2 rounded-lg text-sm font-medium ${
                        formData.target_roles.includes(role)
                          ? 'bg-primary-500 text-white'
                          : 'bg-gray-100 text-gray-700'
                      }`}
                    >
                      {role === 'driver' ? 'سائق' : role === 'merchant' ? 'تاجر' : role === 'customer' ? 'عميل' : 'مشرف'}
                    </button>
                  ))}
                </div>
              </div>

              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-2">وقت البدء / Start Time</label>
                  <input
                    type="datetime-local"
                    value={formData.start_time}
                    onChange={(e) => setFormData({ ...formData, start_time: e.target.value })}
                    className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 outline-none"
                  />
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-2">وقت الانتهاء / End Time</label>
                  <input
                    type="datetime-local"
                    value={formData.end_time}
                    onChange={(e) => setFormData({ ...formData, end_time: e.target.value })}
                    className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 outline-none"
                  />
                </div>
              </div>

              <div className="flex items-center gap-2">
                <input
                  type="checkbox"
                  id="dismissable"
                  checked={formData.is_dismissable}
                  onChange={(e) => setFormData({ ...formData, is_dismissable: e.target.checked })}
                  className="w-4 h-4 text-primary-500 rounded focus:ring-primary-500"
                />
                <label htmlFor="dismissable" className="text-sm text-gray-700">
                  يمكن للمستخدمين إغلاق هذا الإعلان / Users can dismiss this announcement
                </label>
              </div>
            </div>

            <div className="flex items-center justify-end gap-3 p-6 border-t border-gray-200">
              <button
                onClick={() => setShowModal(false)}
                className="px-6 py-2 border border-gray-300 text-gray-700 rounded-lg hover:bg-gray-50"
              >
                إلغاء / Cancel
              </button>
              <button
                onClick={saveAnnouncement}
                disabled={!formData.title || !formData.message || formData.target_roles.length === 0}
                className="px-6 py-2 bg-primary-500 hover:bg-primary-600 text-white rounded-lg disabled:opacity-50"
              >
                <i className="fas fa-save mr-2"></i>
                {editingAnnouncement ? 'حفظ / Save' : 'إنشاء / Create'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

