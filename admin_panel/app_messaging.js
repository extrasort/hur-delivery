// Admin Messaging Panel (Conversations + Messages + Quick Actions)
// Minimal module to be included in admin UI. Assumes Supabase client appears as `supabaseClient`.

window.AdminMessaging = (function () {
  const state = {
    conversations: [],
    activeConversationId: null,
    messages: [],
  };

  const listeners = {
    conversations: new Set(),
    messages: new Set(),
  };

  function notify(type) {
    listeners[type].forEach((callback) => {
      try {
        callback(Array.isArray(state[type]) ? [...state[type]] : state[type]);
      } catch (err) {
        console.error('[AdminMessaging] listener error', err);
      }
    });
  }

  function onConversations(callback, options = {}) {
    if (typeof callback !== 'function') return () => {};
    listeners.conversations.add(callback);
    if (options.immediate !== false) {
      callback([...state.conversations]);
    }
    return () => listeners.conversations.delete(callback);
  }

  function onMessages(callback, options = {}) {
    if (typeof callback !== 'function') return () => {};
    listeners.messages.add(callback);
    if (options.immediate !== false) {
      callback([...state.messages]);
    }
    return () => listeners.messages.delete(callback);
  }

  async function listConversations() {
    const { data, error } = await supabaseClient
      .from('conversations')
      .select('id, title, order_id, is_support, created_at')
      .order('created_at', { ascending: false });
    if (!error) {
      state.conversations = data || [];
      notify('conversations');
    }
    return state.conversations;
  }

  async function initRealtime() {
    await listConversations();
    supabaseClient
      .channel('admin_messaging_conversations')
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'conversations' },
        (_payload) => listConversations()
      )
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'messages' },
        (_payload) => {
          if (state.activeConversationId) selectConversation(state.activeConversationId);
        }
      )
      .subscribe();
  }

  async function selectConversation(id) {
    state.activeConversationId = id;
    const { data, error } = await supabaseClient
      .from('messages')
      .select('id, sender_id, body, kind, order_id, created_at')
      .eq('conversation_id', id)
      .order('created_at', { ascending: true });
    state.messages = error ? [] : data || [];
    notify('messages');
    return state.messages;
  }

  async function sendMessage(body, kind = 'text') {
    if (!state.activeConversationId || !body) return;
    const { data, error } = await supabaseClient.rpc('send_message', {
      p_conversation_id: state.activeConversationId,
      p_body: body,
      p_kind: kind,
      p_order_id: extractOrderId(body),
    });
    if (error) {
      console.error('sendMessage error', error);
    } else {
      await selectConversation(state.activeConversationId);
    }
  }

  function extractOrderId(text) {
    const m = text && text.match(/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/i);
    return m ? m[0] : null;
  }

  async function quickReassign(orderId) {
    const { error } = await supabaseClient.rpc('auto_assign_order', { p_order_id: orderId });
    if (error) console.error('reassign error', error);
  }

  async function quickCancel(orderId, reason = 'admin_cancel') {
    const { error } = await supabaseClient
      .from('orders')
      .update({ status: 'cancelled', rejection_reason: reason, updated_at: new Date().toISOString() })
      .eq('id', orderId);
    if (error) console.error('cancel error', error);
  }

  async function quickAdjustWallet(userId, amount, note) {
    const { error } = await supabaseClient.rpc('add_wallet_balance', {
      p_user_id: userId,
      p_amount: amount,
      p_reason: note || 'admin_adjustment',
    });
    if (error) console.error('wallet adjust error', error);
  }

  return {
    state,
    initRealtime,
    listConversations,
    selectConversation,
    sendMessage,
    quickReassign,
    quickCancel,
    quickAdjustWallet,
    onConversations,
    onMessages,
  };
})();


