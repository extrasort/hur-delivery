import { useEffect, useState } from 'react';
import { supabase, supabaseAdmin } from '../lib/supabase-admin';

interface Review {
  id: string;
  order_id: string;
  driver_id?: string;
  driver_name?: string;
  customer_name?: string;
  rating: number;
  comment?: string;
  created_at: string;
}

export default function Reviews() {
  const [reviews, setReviews] = useState<Review[]>([]);
  const [loading, setLoading] = useState(true);
  const [filter, setFilter] = useState<number | 'all'>('all');

  useEffect(() => {
    loadReviews();
  }, []);

  const loadReviews = async () => {
    setLoading(true);
    try {
      const { data, error } = await supabase
        .from('reviews')
        .select('*')
        .order('created_at', { ascending: false })
        .limit(100);

      // Handle missing table gracefully
      if (error) {
        if (error.code === 'PGRST116' || error.message?.includes('does not exist') || error.code === '42P01') {
          // Table doesn't exist, set empty state
          setReviews([]);
          return;
        }
        throw error;
      }

      const orderIds = Array.from(new Set((data || []).map((r) => r.order_id).filter(Boolean)));
      const driverIds = Array.from(new Set((data || []).map((r) => r.driver_id).filter(Boolean)));

      let ordersById: Record<string, { customer_name?: string }> = {};
      if (orderIds.length) {
        const { data: orderRows } = await supabaseAdmin
          .from('orders')
          .select('id, customer_name')
          .in('id', orderIds);
        ordersById = (orderRows || []).reduce((acc, order) => {
          acc[order.id] = { customer_name: order.customer_name || 'Unknown' };
          return acc;
        }, {} as Record<string, { customer_name?: string }>);
      }

      let driversById: Record<string, { name?: string }> = {};
      if (driverIds.length) {
        const { data: driverRows } = await supabaseAdmin
          .from('users')
          .select('id, name')
          .in('id', driverIds);
        driversById = (driverRows || []).reduce((acc, user) => {
          acc[user.id] = { name: user.name || 'Unknown' };
          return acc;
        }, {} as Record<string, { name?: string }>);
      }

      const formatted = (data || []).map((r) => ({
        id: r.id,
        order_id: r.order_id,
        driver_id: r.driver_id,
        driver_name: (r.driver_id && driversById[r.driver_id]?.name) || 'Unknown',
        customer_name: (r.order_id && ordersById[r.order_id]?.customer_name) || 'Unknown',
        rating: r.rating,
        comment: r.comment,
        created_at: r.created_at,
      }));

      setReviews(formatted);
    } catch (error) {
      console.error('Error loading reviews:', error);
    } finally {
      setLoading(false);
    }
  };

  const filteredReviews = reviews.filter(r => filter === 'all' || r.rating === filter);

  const averageRating = reviews.length > 0
    ? (reviews.reduce((sum, r) => sum + r.rating, 0) / reviews.length).toFixed(1)
    : '0.0';

  const renderStars = (rating: number) => {
    return (
      <div className="flex items-center gap-1">
        {[1, 2, 3, 4, 5].map(star => (
          <i
            key={star}
            className={`fas fa-star ${star <= rating ? 'text-yellow-400' : 'text-gray-300'}`}
          ></i>
        ))}
      </div>
    );
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
        <h2 className="text-2xl font-bold text-gray-900">التقييمات / Reviews</h2>
        <p className="text-gray-600 text-sm mt-1">تقييمات العملاء وآراؤهم / Customer ratings and feedback</p>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-4 gap-6">
        <div className="bg-white rounded-xl shadow-sm p-6 text-center">
          <i className="fas fa-star text-4xl text-yellow-400 mb-2"></i>
          <p className="text-3xl font-bold text-gray-900">{averageRating}</p>
          <p className="text-sm text-gray-600">متوسط التقييم / Average Rating</p>
        </div>

        <div className="bg-white rounded-xl shadow-sm p-6 text-center">
          <i className="fas fa-comments text-4xl text-blue-500 mb-2"></i>
          <p className="text-3xl font-bold text-gray-900">{reviews.length}</p>
          <p className="text-sm text-gray-600">إجمالي التقييمات / Total Reviews</p>
        </div>

        <div className="bg-white rounded-xl shadow-sm p-6 text-center">
          <i className="fas fa-thumbs-up text-4xl text-green-500 mb-2"></i>
          <p className="text-3xl font-bold text-gray-900">{reviews.filter(r => r.rating >= 4).length}</p>
          <p className="text-sm text-gray-600">تقييمات إيجابية / Positive Reviews</p>
        </div>

        <div className="bg-white rounded-xl shadow-sm p-6 text-center">
          <i className="fas fa-thumbs-down text-4xl text-red-500 mb-2"></i>
          <p className="text-3xl font-bold text-gray-900">{reviews.filter(r => r.rating <= 2).length}</p>
          <p className="text-sm text-gray-600">تقييمات سلبية / Negative Reviews</p>
        </div>
      </div>

      <div className="bg-white rounded-xl shadow-sm p-4">
        <div className="flex gap-2 flex-wrap">
          <button
            onClick={() => setFilter('all')}
            className={`px-4 py-2 rounded-lg text-sm font-medium ${
              filter === 'all' ? 'bg-primary-500 text-white' : 'bg-gray-100 text-gray-700'
            }`}
          >
            الكل / All
          </button>
          {[5, 4, 3, 2, 1].map(rating => (
            <button
              key={rating}
              onClick={() => setFilter(rating)}
              className={`px-4 py-2 rounded-lg text-sm font-medium flex items-center gap-1 ${
                filter === rating ? 'bg-yellow-400 text-white' : 'bg-gray-100 text-gray-700'
              }`}
            >
              <i className="fas fa-star"></i>
              {rating}
            </button>
          ))}
        </div>
      </div>

      <div className="space-y-4">
        {filteredReviews.map(review => (
          <div key={review.id} className="bg-white rounded-xl shadow-sm p-6">
            <div className="flex items-start justify-between mb-4">
              <div className="flex items-center gap-3">
                <div className="w-12 h-12 bg-primary-100 rounded-full flex items-center justify-center">
                  <i className="fas fa-user text-primary-600 text-xl"></i>
                </div>
                <div>
                  <p className="font-medium text-gray-900">{review.customer_name}</p>
                  <p className="text-sm text-gray-500">السائق: {review.driver_name}</p>
                </div>
              </div>
              <div className="text-right">
                {renderStars(review.rating)}
                <p className="text-xs text-gray-500 mt-1">
                  {new Date(review.created_at).toLocaleDateString('ar-IQ')}
                </p>
              </div>
            </div>

            {review.comment && (
              <div className="bg-gray-50 rounded-lg p-4">
                <p className="text-gray-700">{review.comment}</p>
              </div>
            )}

            <p className="text-xs text-gray-500 mt-3">
              <i className="fas fa-box mr-1"></i>
              طلب رقم: #{review.order_id.slice(0, 8)}
            </p>
          </div>
        ))}
      </div>

      {filteredReviews.length === 0 && (
        <div className="bg-white rounded-xl shadow-sm p-12 text-center text-gray-500">
          <i className="fas fa-star text-4xl mb-2"></i>
          <p>لا توجد تقييمات / No reviews found</p>
        </div>
      )}
    </div>
  );
}
