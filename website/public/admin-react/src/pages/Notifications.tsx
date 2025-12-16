import { useState } from 'react';
import { supabaseAdmin } from '../lib/supabase-admin';

export default function Notifications() {
  const [title, setTitle] = useState('');
  const [message, setMessage] = useState('');
  const [target, setTarget] = useState<'all' | 'drivers' | 'merchants' | 'customers'>('all');
  const [sending, setSending] = useState(false);

  const sendNotification = async () => {
    if (!title || !message) {
      alert('الرجاء ملء جميع الحقول / Please fill all fields');
      return;
    }

    setSending(true);
    try {
      const { error } = await supabaseAdmin.rpc('send_notification', {
        p_title: title,
        p_message: message,
        p_target_role: target === 'all' ? null : target,
      });

      if (error) throw error;

      alert('تم إرسال الإشعار بنجاح / Notification sent successfully');
      setTitle('');
      setMessage('');
    } catch (error: any) {
      console.error('Error sending notification:', error);
      alert(error.message || 'فشل إرسال الإشعار / Failed to send notification');
    } finally {
      setSending(false);
    }
  };

  return (
    <div className="max-w-3xl mx-auto space-y-6">
      <div>
        <h2 className="text-2xl font-bold text-gray-900">الإشعارات / Notifications</h2>
        <p className="text-gray-600 text-sm mt-1">إرسال إشعارات للمستخدمين / Send notifications to users</p>
      </div>

      <div className="bg-white rounded-xl shadow-sm p-6 space-y-6">
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-2">
            العنوان / Title
          </label>
          <input
            type="text"
            value={title}
            onChange={(e) => setTitle(e.target.value)}
            placeholder="أدخل عنوان الإشعار / Enter notification title"
            className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 outline-none"
          />
        </div>

        <div>
          <label className="block text-sm font-medium text-gray-700 mb-2">
            الرسالة / Message
          </label>
          <textarea
            value={message}
            onChange={(e) => setMessage(e.target.value)}
            placeholder="أدخل نص الإشعار / Enter notification message"
            rows={5}
            className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 outline-none"
          ></textarea>
        </div>

        <div>
          <label className="block text-sm font-medium text-gray-700 mb-2">
            الفئة المستهدفة / Target Audience
          </label>
          <select
            value={target}
            onChange={(e) => setTarget(e.target.value as any)}
            className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 outline-none"
          >
            <option value="all">الجميع / All Users</option>
            <option value="drivers">السائقون / Drivers</option>
            <option value="merchants">التجار / Merchants</option>
            <option value="customers">العملاء / Customers</option>
          </select>
        </div>

        <button
          onClick={sendNotification}
          disabled={sending}
          className="w-full px-6 py-3 bg-primary-500 hover:bg-primary-600 text-white rounded-lg font-medium disabled:opacity-50 disabled:cursor-not-allowed"
        >
          {sending ? (
            <><i className="fas fa-spinner fa-spin mr-2"></i>جاري الإرسال...</>
          ) : (
            <><i className="fas fa-paper-plane mr-2"></i>إرسال الإشعار / Send Notification</>
          )}
        </button>
      </div>

      <div className="bg-blue-50 border-l-4 border-blue-500 p-4">
        <div className="flex items-start gap-3">
          <i className="fas fa-info-circle text-blue-500 mt-1"></i>
          <div className="text-sm text-blue-800">
            <p className="font-medium mb-1">ملاحظة / Note:</p>
            <p>سيتم إرسال الإشعار إلى جميع المستخدمين في الفئة المحددة. تأكد من صحة المعلومات قبل الإرسال.</p>
            <p>The notification will be sent to all users in the selected category. Verify the information before sending.</p>
          </div>
        </div>
      </div>
    </div>
  );
}
