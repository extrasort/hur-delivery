// Advanced Admin Messaging Module
// Provides a rich support chat experience for the web admin dashboard and standalone tools.

window.AdminMessaging = (() => {
  const state = {
    currentUser: null,
    conversations: [],
    activeConversationId: null,
    messages: [],
    replyingTo: null,
    loading: {
      conversations: false,
      messages: false,
    },
  };

  const listeners = {
    conversations: new Set(),
    messages: new Set(),
    orders: new Set(),
  };

  function onOrders(callback, options = {}) {
    if (typeof callback !== 'function') return () => {};
    listeners.orders.add(callback);
    if (options.immediate !== false) {
      callback([]);
    }
    return () => listeners.orders.delete(callback);
  }

  let realtimeChannel = null;

  /* -------------------------------------------------------------------------- */
  /* Utilities                                                                  */
  /* -------------------------------------------------------------------------- */

  const cloneConversation = (conversation) => ({
    ...conversation,
    participants: conversation.participants?.map((p) => ({ ...p })) ?? [],
    meta: conversation.meta ? { ...conversation.meta } : {},
  });

  const cloneMessage = (message) => ({
    ...message,
    sender: message.sender ? { ...message.sender } : null,
    meta: message.meta
      ? {
          ...message.meta,
          replyPreview: message.meta.replyPreview
            ? { ...message.meta.replyPreview }
            : null,
        }
      : {},
  });

  const baseRole = (role) => (role || '').toString().toLowerCase();

  const formatRoleLabel = (role) => {
    switch (baseRole(role)) {
      case 'driver':
        return 'سائق';
      case 'merchant':
        return 'تاجر';
      case 'customer':
        return 'عميل';
      case 'admin':
        return 'دعم';
      default:
        return '';
    }
  };

  const formatDateTime = (iso, { includeDate = true, includeTime = true } = {}) => {
    if (!iso) return '';
    try {
      const date = new Date(iso);
      if (Number.isNaN(date.getTime())) return '';
      const options = {};
      if (includeDate) {
        options.year = 'numeric';
        options.month = '2-digit';
        options.day = '2-digit';
      }
      if (includeTime) {
        options.hour = '2-digit';
        options.minute = '2-digit';
        options.hour12 = false;
      }
      return date.toLocaleString('ar-IQ', options);
    } catch (_) {
      return iso;
    }
  };

  const chooseCounterpart = (participants) => {
    if (!participants.length) return null;
    const currentUserId = state.currentUser?.id;
    const nonAdmin = participants.find(
      (participant) => baseRole(participant?.role) !== 'admin' && participant?.id !== currentUserId,
    );
    if (nonAdmin) return nonAdmin;
    const notMe = participants.find((participant) => participant?.id !== currentUserId);
    if (notMe) return notMe;
    return participants[0];
  };

  const parseSupabaseId = (value) => {
    if (!value) return null;
    if (typeof value === 'string') return value;
    if (typeof value === 'number') return value.toString();
    if (Array.isArray(value) && value.length > 0) return parseSupabaseId(value[0]);
    if (typeof value === 'object') {
      return value.id || value.conversation_id || value.uuid || null;
    }
    return null;
  };

  const buildConversationMeta = (raw, participants) => {
    const currentRole = baseRole(
      state.currentUser?.user_metadata?.role ||
        state.currentUser?.app_metadata?.role ||
        state.currentUser?.role,
    );
    const counterpart = chooseCounterpart(participants);
    const createdLabel = formatDateTime(raw.created_at);
    const orderLabel = raw.order_id ? `طلب ${raw.order_id.slice(0, 8)}` : '';

    let title = raw.title?.trim() || '';
    let subtitle = '';

    if (raw.is_support) {
      if (['driver', 'merchant'].includes(currentRole)) {
        title = createdLabel;
        if (orderLabel) title = `${title} • ${orderLabel}`;
        subtitle = 'دعم فني';
      } else {
        const name = counterpart?.name || counterpart?.phone || 'مستخدم';
        title = name;
        subtitle = formatRoleLabel(counterpart?.role);
        if (orderLabel) subtitle = subtitle ? `${subtitle} • ${orderLabel}` : orderLabel;
      }
    } else {
      if (!title) title = counterpart?.name || counterpart?.phone || 'محادثة';
      subtitle = orderLabel || '';
    }

    const lastMessage = raw.last_message?.[0] || null;
    const lastMessagePreview = lastMessage?.body || '';
    const lastMessageAt = lastMessage?.created_at || raw.created_at;

    return {
      title: title || 'محادثة',
      subtitle,
      counterpart,
      counterpartRole: formatRoleLabel(counterpart?.role),
      createdLabel,
      lastMessagePreview,
      lastMessageAt,
    };
  };

  const enhanceConversation = (raw) => {
    const participants =
      (raw.conversation_participants || [])
        .map((entry) => entry?.user || null)
        .filter(Boolean) || [];
    const meta = buildConversationMeta(raw, participants);
    return {
      ...raw,
      participants,
      meta,
    };
  };

  const enhanceMessage = (raw) => {
    const sender = raw.sender || raw.user || null;
    const isMine = !!state.currentUser && raw.sender_id === state.currentUser.id;
    const displayName =
      sender?.name || sender?.phone || (isMine ? 'أنت' : 'مستخدم');
    const createdLabel = formatDateTime(raw.created_at, {
      includeDate: false,
      includeTime: true,
    });

    return {
      ...raw,
      sender,
      meta: {
        isMine,
        displayName,
        senderRole: formatRoleLabel(sender?.role),
        createdLabel,
        replyPreview: null,
      },
    };
  };

  const rebuildReplyPreviews = (messages) => {
    const index = new Map(messages.map((message) => [message.id, message]));
    messages.forEach((message) => {
      if (message.reply_to_message_id) {
        const referenced = index.get(message.reply_to_message_id);
        if (referenced) {
          message.meta.replyPreview = {
            id: referenced.id,
            author: referenced.meta.displayName,
            text: referenced.body,
          };
        }
      }
    });
    return messages;
  };

  /* -------------------------------------------------------------------------- */
  /* Notifications & Event Hooks                                                */
  /* -------------------------------------------------------------------------- */

  const notify = (type) => {
    const callbacks = listeners[type];
    if (!callbacks?.size) return;
    const payload =
      type === 'messages'
        ? state.messages.map(cloneMessage)
        : type === 'conversations'
        ? state.conversations.map(cloneConversation)
        : [];
    callbacks.forEach((callback) => {
      try {
        callback(payload);
      } catch (error) {
        console.error('[AdminMessaging] listener error', error);
      }
    });
  };

  const onConversations = (callback, options = {}) => {
    if (typeof callback !== 'function') return () => {};
    listeners.conversations.add(callback);
    if (options.immediate !== false) {
      callback(state.conversations.map(cloneConversation));
    }
    return () => listeners.conversations.delete(callback);
  };

  const onMessages = (callback, options = {}) => {
    if (typeof callback !== 'function') return () => {};
    listeners.messages.add(callback);
    if (options.immediate !== false) {
      callback(state.messages.map(cloneMessage));
    }
    return () => listeners.messages.delete(callback);
  };

  /* -------------------------------------------------------------------------- */
  /* Data Fetching                                                              */
  /* -------------------------------------------------------------------------- */

  const ensureCurrentUser = async () => {
    if (state.currentUser) return state.currentUser;
    try {
      const { data, error } = await supabaseClient.auth.getSession();
      if (error) {
        console.error('[AdminMessaging] failed to fetch session', error);
        return null;
      }
      state.currentUser = data?.session?.user ?? null;
    } catch (error) {
      console.error('[AdminMessaging] ensureCurrentUser error', error);
    }
    return state.currentUser;
  };

  const listConversations = async () => {
    await ensureCurrentUser();
    state.loading.conversations = true;
    notify('conversations');

    const { data, error } = await supabaseClient
      .from('conversations')
      .select(`
        id,
        title,
        order_id,
        is_support,
        created_at,
        conversation_participants:conversation_participants(
          user:users(
            id,
            name,
            role,
            phone
          )
        ),
        last_message:messages!messages_conversation_id_fkey(
          id,
          sender_id,
          body,
          kind,
          order_id,
          created_at,
          reply_to_message_id
        ).order(created_at.desc).limit(1)
      `)
      .order('created_at', { ascending: false });

    state.loading.conversations = false;

    if (error) {
      console.error('[AdminMessaging] listConversations error', error);
      return state.conversations;
    }

    state.conversations = (data || []).map(enhanceConversation);
      notify('conversations');
    return state.conversations;
  };

  async function selectConversation(id) {
    await ensureCurrentUser();
    if (!id) return [];

    state.activeConversationId = id;
    state.loading.messages = true;
    notify('conversations');

    const { data, error } = await supabaseClient
      .from('messages')
      .select(`
        id,
        conversation_id,
        sender_id,
        body,
        kind,
        order_id,
        created_at,
        reply_to_message_id,
        sender:users!messages_sender_id_fkey(
          id,
          name,
          role,
          phone
        )
      `)
      .eq('conversation_id', id)
      .order('created_at', { ascending: true });

    state.loading.messages = false;

    if (error) {
      console.error('[AdminMessaging] selectConversation error', error);
      state.messages = [];
    } else {
      state.messages = rebuildReplyPreviews((data || []).map(enhanceMessage));
    }

    notify('messages');
    // Load counterpart orders for quick actions
    try {
      const conv = state.conversations.find((c) => c.id === id);
      const counterpartId = conv?.meta?.counterpart?.id || null;
      if (counterpartId) {
        const orders = await listOrdersForUser(counterpartId);
        listeners.orders.forEach((cb) => {
          try { cb(orders); } catch (e) { /* noop */ }
        });
      } else {
        listeners.orders.forEach((cb) => { try { cb([]); } catch (_) {} });
      }
    } catch (e) {
      console.warn('[AdminMessaging] load orders warning', e);
      listeners.orders.forEach((cb) => { try { cb([]); } catch (_) {} });
    }
    return state.messages;
  }

  /* -------------------------------------------------------------------------- */
  /* Mutations                                                                  */
  /* -------------------------------------------------------------------------- */

  const sendMessage = async (body, options = {}) => {
    await ensureCurrentUser();
    if (!state.activeConversationId || !body) return;

    const replyContext = state.replyingTo
      ? {
          id: state.replyingTo.id,
          author:
            state.replyingTo.meta?.displayName ||
            state.replyingTo.sender?.name ||
            'مستخدم',
          text: state.replyingTo.body,
        }
      : null;

    const conversation = state.conversations.find((c) => c.id === state.activeConversationId);
    const fallbackOrderId = options.orderId ?? conversation?.order_id ?? null;
    const tempId = `local_${Date.now()}_${Math.random().toString(16).slice(2)}`;
    const createdAt = new Date().toISOString();

    const optimisticRaw = {
      id: tempId,
      conversation_id: state.activeConversationId,
      sender_id: state.currentUser?.id || null,
      body,
      kind: options.kind || 'text',
      order_id: fallbackOrderId,
      created_at: createdAt,
      reply_to_message_id: replyContext?.id || null,
      sender: {
        id: state.currentUser?.id || null,
        name:
          state.currentUser?.user_metadata?.name ||
          state.currentUser?.email ||
          'أنت',
        role:
          state.currentUser?.user_metadata?.role ||
          state.currentUser?.app_metadata?.role ||
          'admin',
        phone: state.currentUser?.user_metadata?.phone || null,
      },
    };

    const optimisticMessage = enhanceMessage(optimisticRaw);
    if (replyContext) optimisticMessage.meta.replyPreview = replyContext;

    state.messages = [...state.messages, optimisticMessage];
    state.replyingTo = null;
    notify('messages');

    try {
      // Ensure admin exists in public.users (FK safety)
      if (state.currentUser?.id) {
        try {
          await supabaseClient.rpc('ensure_user_exists', {
            p_id: state.currentUser.id,
            p_name: state.currentUser.user_metadata?.name || state.currentUser.email || 'Admin',
            p_role: 'admin',
            p_phone: state.currentUser.user_metadata?.phone || null,
          });
        } catch (e) {
          console.warn('[AdminMessaging] ensure_user_exists warning', e);
        }
      }

    const { data, error } = await supabaseClient.rpc('send_message', {
      p_conversation_id: state.activeConversationId,
      p_body: body,
        p_kind: optimisticRaw.kind,
        p_order_id: fallbackOrderId,
        p_reply_to: replyContext?.id || null,
        p_sender_id: state.currentUser?.id || null,
      });
      if (error) throw error;
      const newId = parseSupabaseId(data);
      if (newId) {
        await selectConversation(state.activeConversationId);
        await listConversations();
      }
    } catch (error) {
      console.error('[AdminMessaging] sendMessage error', error);
    }
  };

  async function startSupportConversation({ userId, orderId, initialMessage } = {}) {
    await ensureCurrentUser();
    const { data, error } = await supabaseClient.rpc('create_or_get_conversation', {
      p_order_id: orderId || null,
      p_participant_ids: userId ? [userId] : [],
      p_is_support: true,
    });
    if (error) {
      console.error('[AdminMessaging] startSupportConversation error', error);
      throw error;
    }
    const conversationId = parseSupabaseId(data);
    await listConversations();
    if (conversationId) {
      await selectConversation(conversationId);
      if (initialMessage) {
        await sendMessage(initialMessage);
      }
    }
    return conversationId;
  }

  const setReplyTo = (messageId) => {
    if (!messageId) {
      state.replyingTo = null;
      notify('messages');
      return;
    }
    const message = state.messages.find((m) => m.id === messageId);
    state.replyingTo = message || null;
    notify('messages');
  };

  const clearReplyTo = () => {
    state.replyingTo = null;
    notify('messages');
  };

  /* -------------------------------------------------------------------------- */
  /* Realtime                                                                   */
  /* -------------------------------------------------------------------------- */

  const initRealtime = async () => {
    await ensureCurrentUser();
    if (realtimeChannel) {
      supabaseClient.removeChannel(realtimeChannel);
      realtimeChannel = null;
    }

    realtimeChannel = supabaseClient
      .channel('admin-messaging-realtime-v2')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'conversations' }, async () => {
        await listConversations();
      })
      .on('postgres_changes', { event: '*', schema: 'public', table: 'messages' }, async (payload) => {
        const conversationId = payload.new?.conversation_id || payload.old?.conversation_id;
        await listConversations();
        if (conversationId && conversationId === state.activeConversationId) {
          await selectConversation(conversationId);
        }
      })
      .subscribe();

    await listConversations();
    if (state.activeConversationId) {
      await selectConversation(state.activeConversationId);
    }
    return state.conversations;
  };

  const destroy = () => {
    if (realtimeChannel) {
      supabaseClient.removeChannel(realtimeChannel);
      realtimeChannel = null;
  }
    state.conversations = [];
    state.messages = [];
    state.activeConversationId = null;
    state.replyingTo = null;
    notify('conversations');
    notify('messages');
  };

  async function listOrdersForUser(userId) {
    const { data, error } = await supabaseClient
      .from('orders')
      .select('id,status,customer_name,customer_phone,merchant_id,driver_id,created_at')
      .or(`driver_id.eq.${userId},merchant_id.eq.${userId}`)
      .order('created_at', { ascending: false })
      .limit(50);
    if (error) {
      console.error('[AdminMessaging] listOrdersForUser error', error);
      return [];
    }
    return data || [];
  }

  /* -------------------------------------------------------------------------- */
  /* Public API                                                                 */
  /* -------------------------------------------------------------------------- */

  return {
    state,
    initRealtime,
    listConversations,
    selectConversation,
    sendMessage,
    startSupportConversation,
    setReplyTo,
    clearReplyTo,
    onConversations,
    onMessages,
    onOrders,
    ensureCurrentUser,
    destroy,
  };
})();


