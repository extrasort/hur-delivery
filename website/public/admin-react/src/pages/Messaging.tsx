import { useEffect, useState, useRef, useCallback } from 'react';
import {
  supabaseAdmin,
  supabase,
  type Conversation,
  type Message,
  type Order,
  type User,
} from '../lib/supabase-admin';

interface ConversationWithDetails extends Conversation {
  counterpart?: User;
  lastMessage?: Message;
  is_archived?: boolean;
  updated_at?: string;
}

interface OrderWithEditing extends Order {
  isEditing?: boolean;
}

type OrderEditForm = {
  status: string;
  driver_id: string;
  notes: string;
  customer_name: string;
  customer_phone: string;
  pickup_address: string;
  pickup_latitude: string;
  pickup_longitude: string;
  delivery_address: string;
  delivery_latitude: string;
  delivery_longitude: string;
  delivery_fee: string;
};

type DriverOption = {
  driver: User;
  distance: number | null;
};

type MessageWithAttachment = Message & {
  resolvedAttachmentUrl?: string | null;
  resolvedAttachmentType?: string | null;
};

type StoragePointer = {
  bucket: string;
  path: string;
};

type AttachmentRow = {
  message_id: string;
  storage_path?: string | null;
  content_type?: string | null;
};

const SIGNED_URL_TTL_SECONDS = 60 * 60 * 24; // 24 hours
const KNOWN_STORAGE_BUCKETS = new Set(['message_attachments', 'files', 'order_proofs', 'public', 'private']);
const STORAGE_FALLBACK_BUCKET = 'message_attachments';

const isHttpLikeUrl = (value?: string | null) => {
  if (!value) return false;
  return /^https?:\/\//i.test(value) || value.startsWith('data:');
};

const sanitizeStoragePath = (value: string) => {
  const trimmed = value.split('?')[0]?.trim() ?? '';
  const stripped = trimmed.replace(/^\/+/, '');
  try {
    return decodeURIComponent(stripped);
  } catch {
    return stripped;
  }
};

const resolveStoragePointer = (raw?: string | null): StoragePointer | null => {
  if (!raw) return null;
  if (isHttpLikeUrl(raw)) return null;

  const storageApiMatch = raw.match(/storage\/v1\/object\/(?:sign|public)\/(.+)$/i);
  const cleaned = sanitizeStoragePath(storageApiMatch ? storageApiMatch[1] : raw);

  if (!cleaned) return null;

  const segments = cleaned.split('/').filter(Boolean);
  if (!segments.length) return null;

  const [first, ...rest] = segments;

  if (KNOWN_STORAGE_BUCKETS.has(first) && rest.length) {
    return { bucket: first, path: rest.join('/') };
  }

  if (KNOWN_STORAGE_BUCKETS.has(first) && !rest.length) {
    return null;
  }

  return {
    bucket: STORAGE_FALLBACK_BUCKET,
    path: segments.join('/'),
  };
};

const FALLBACK_STATUSES = [
  'pending',
  'assigned',
  'accepted',
  'on_the_way',
  'delivered',
  'cancelled',
  'rejected',
];

const toRadians = (value: number) => (value * Math.PI) / 180;

const calculateDistanceInKm = (
  lat1?: number | null,
  lon1?: number | null,
  lat2?: number | null,
  lon2?: number | null
): number | null => {
  if (
    lat1 == null ||
    lon1 == null ||
    lat2 == null ||
    lon2 == null ||
    Number.isNaN(lat1) ||
    Number.isNaN(lon1) ||
    Number.isNaN(lat2) ||
    Number.isNaN(lon2)
  ) {
    return null;
  }

  const R = 6371;
  const dLat = toRadians(lat2 - lat1);
  const dLon = toRadians(lon2 - lon1);
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(toRadians(lat1)) * Math.cos(toRadians(lat2)) * Math.sin(dLon / 2) * Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
};

const buildOrderForm = (order: Order): OrderEditForm => ({
  status: order.status || '',
  driver_id: order.driver_id || '',
  notes: order.notes || '',
  customer_name: order.customer_name || '',
  customer_phone: order.customer_phone || '',
  pickup_address: order.pickup_address || '',
  pickup_latitude:
    order.pickup_latitude != null ? Number(order.pickup_latitude).toString() : '',
  pickup_longitude:
    order.pickup_longitude != null ? Number(order.pickup_longitude).toString() : '',
  delivery_address: order.delivery_address || '',
  delivery_latitude:
    order.delivery_latitude != null ? Number(order.delivery_latitude).toString() : '',
  delivery_longitude:
    order.delivery_longitude != null ? Number(order.delivery_longitude).toString() : '',
  delivery_fee: order.delivery_fee != null ? Number(order.delivery_fee).toString() : '',
});

const createEmptyOrderForm = (): OrderEditForm => ({
  status: '',
  driver_id: '',
  notes: '',
  customer_name: '',
  customer_phone: '',
  pickup_address: '',
  pickup_latitude: '',
  pickup_longitude: '',
  delivery_address: '',
  delivery_latitude: '',
  delivery_longitude: '',
  delivery_fee: '',
});

export default function Messaging() {
  const [conversations, setConversations] = useState<ConversationWithDetails[]>([]);
  const [messages, setMessages] = useState<MessageWithAttachment[]>([]);
  const [selectedConversationId, setSelectedConversationId] = useState<string | null>(null);
  const [messageBody, setMessageBody] = useState('');
  const [loading, setLoading] = useState(true);
  const [orders, setOrders] = useState<OrderWithEditing[]>([]);
  const [driverLocation, setDriverLocation] = useState<{ lat: number; lng: number } | null>(null);
  const [showArchived, setShowArchived] = useState(false);
  const [editingOrderId, setEditingOrderId] = useState<string | null>(null);
  const [orderStatusOptions, setOrderStatusOptions] = useState<string[]>(FALLBACK_STATUSES);
  const [orderEditForms, setOrderEditForms] = useState<Record<string, OrderEditForm>>({});
  const [highlightedOrderId, setHighlightedOrderId] = useState<string | null>(null);
  const [driverPickerOrder, setDriverPickerOrder] = useState<OrderWithEditing | null>(null);
  const [driverOptions, setDriverOptions] = useState<DriverOption[]>([]);
  const [loadingDrivers, setLoadingDrivers] = useState(false);
  const [orderLookup, setOrderLookup] = useState<Record<string, Order>>({});
  const [adminUserId, setAdminUserId] = useState<string | null>(null);
  const messagesEndRef = useRef<HTMLDivElement>(null);
  // Cache messages per conversation to avoid reloading when switching back
  const messagesCache = useRef<Record<string, MessageWithAttachment[]>>({});
  // Ref to track current selected conversation for realtime subscription callback
  const selectedConversationIdRef = useRef<string | null>(null);

  const createSignedUrl = useCallback(async (pointer: StoragePointer): Promise<string | undefined> => {
    if (!pointer.bucket || !pointer.path) return undefined;

    try {
      const { data, error } = await supabaseAdmin.storage
        .from(pointer.bucket)
        .createSignedUrl(pointer.path, SIGNED_URL_TTL_SECONDS);

      if (!error && data?.signedUrl) {
        return data.signedUrl;
      }

      const publicResult = supabaseAdmin.storage.from(pointer.bucket).getPublicUrl(pointer.path);
      return publicResult.data?.publicUrl ?? undefined;
    } catch (error) {
      console.warn('Unable to resolve storage URL', pointer, error);
      return undefined;
    }
  }, []);

  const enrichMessagesWithAttachments = useCallback(
    async (raw: Message[]): Promise<MessageWithAttachment[]> => {
      if (!raw.length) return [];

      const messageIds = raw.map((msg) => msg.id).filter(Boolean);
      let attachmentRows: AttachmentRow[] = [];

      if (messageIds.length) {
        try {
          const { data, error } = await supabaseAdmin
            .from('message_attachments')
            .select('message_id, storage_path, content_type')
            .in('message_id', messageIds);

          if (error) {
            console.warn('Error loading message attachment metadata', error);
          } else if (data) {
            attachmentRows = data as AttachmentRow[];
          }
        } catch (error) {
          console.warn('Error querying message attachments', error);
        }
      }

      const attachmentsByMessage = new Map<string, AttachmentRow>();
      attachmentRows.forEach((row) => {
        if (row?.message_id) {
          attachmentsByMessage.set(row.message_id, row);
        }
      });

      const pointerCache = new Map<string, string>();
      const resolved: MessageWithAttachment[] = [];

      for (const msg of raw) {
        const attachmentCandidates: Array<{ value?: string | null; type?: string | null }> = [
          { value: msg.attachment_url, type: msg.attachment_type },
        ];

        const attachmentRow = attachmentsByMessage.get(msg.id);
        if (attachmentRow?.storage_path) {
          attachmentCandidates.push({
            value: attachmentRow.storage_path,
            type: attachmentRow.content_type,
          });
        }

        let resolvedUrl: string | null | undefined = null;
        let resolvedType: string | null | undefined =
          msg.attachment_type || attachmentRow?.content_type || null;

        for (const candidate of attachmentCandidates) {
          if (!candidate?.value) continue;

          if (isHttpLikeUrl(candidate.value)) {
            resolvedUrl = candidate.value;
            if (!resolvedType && candidate.type) {
              resolvedType = candidate.type;
            }
            break;
          }

          const pointer = resolveStoragePointer(candidate.value);
          if (!pointer || !pointer.path) continue;

          const cacheKey = `${pointer.bucket}/${pointer.path}`;
          let signedUrl = pointerCache.get(cacheKey);
          if (!signedUrl) {
            signedUrl = await createSignedUrl(pointer);
            if (signedUrl) {
              pointerCache.set(cacheKey, signedUrl);
            }
          }

          if (signedUrl) {
            resolvedUrl = signedUrl;
            if (!resolvedType && candidate.type) {
              resolvedType = candidate.type;
            }
            break;
          }
        }

        resolved.push({
          ...msg,
          resolvedAttachmentUrl: resolvedUrl ?? msg.attachment_url ?? null,
          resolvedAttachmentType: resolvedType ?? msg.attachment_type ?? attachmentRow?.content_type ?? null,
        });
      }

      return resolved;
    },
    [createSignedUrl]
  );

  // Realtime subscription for messages - set up once and persist (not dependent on selectedConversationId)
  useEffect(() => {
    fetchOrderStatuses();
    loadConversations();

    // Single persistent channel for all messages (filtered in callback)
    const messagesChannel = supabase
      .channel('messaging-messages-persistent')
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'messages',
        },
        (payload) => {
          console.log('📨 Realtime message received:', payload);
          const newMessage = payload.new as Partial<Message> | null;
          if (newMessage?.conversation_id) {
            // Use ref to get current selected conversation ID (always up-to-date)
            const currentSelectedId = selectedConversationIdRef.current;
            if (newMessage.conversation_id === currentSelectedId) {
              console.log('📨 Loading messages for selected conversation (realtime update)');
              loadMessages(newMessage.conversation_id, false); // Don't use cache for realtime updates
            } else {
              // Invalidate cache for this conversation so it reloads when selected
              delete messagesCache.current[newMessage.conversation_id];
            }
            // Always reload conversations list to update last message preview
            loadConversations();
          }
        }
      )
      .subscribe((status) => {
        console.log('📡 Messages channel subscription status:', status);
        if (status === 'SUBSCRIBED') {
          console.log('✅ Successfully subscribed to messages channel');
        } else if (status === 'CHANNEL_ERROR') {
          console.error('❌ Messages channel subscription error');
        } else if (status === 'TIMED_OUT') {
          console.warn('⏱️ Messages channel subscription timed out, resubscribing...');
          messagesChannel.subscribe();
        }
      });

    const conversationsChannel = supabase
      .channel('messaging-conversations-persistent')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'conversations' }, () => {
        console.log('💬 Conversation updated, reloading list');
        loadConversations();
      })
      .subscribe((status) => {
        console.log('📡 Conversations channel subscription status:', status);
        if (status === 'TIMED_OUT') {
          console.warn('⏱️ Conversations channel subscription timed out, resubscribing...');
          conversationsChannel.subscribe();
        }
      });

    return () => {
      console.log('🧹 Cleaning up realtime subscriptions');
      messagesChannel.unsubscribe();
      conversationsChannel.unsubscribe();
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []); // Empty deps - set up once and persist

  useEffect(() => {
    let isMounted = true;

    const syncSession = async () => {
      const {
        data: { session },
      } = await supabase.auth.getSession();
      if (isMounted) {
        setAdminUserId(session?.user?.id ?? null);
      }
    };

    syncSession();
    const { data } = supabase.auth.onAuthStateChange((_event, session) => {
      setAdminUserId(session?.user?.id ?? null);
    });

    return () => {
      isMounted = false;
      data.subscription.unsubscribe();
    };
  }, []);

  useEffect(() => {
    loadConversations();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [showArchived]);

  // Update ref when selected conversation changes
  useEffect(() => {
    selectedConversationIdRef.current = selectedConversationId;
  }, [selectedConversationId]);

  // Load conversation data when selected - but don't reload if already loaded
  useEffect(() => {
    if (selectedConversationId) {
      // Only load messages if we don't have them or if conversation changed
      const hasMessages = messages.length > 0 && messages[0]?.conversation_id === selectedConversationId;
      if (!hasMessages) {
        loadMessages(selectedConversationId);
      }
      
      const conv = conversations.find((c) => c.id === selectedConversationId);
      if (conv?.counterpart) {
        // Only load orders if we don't have them for this user
        const hasOrdersForUser = orders.length > 0 && orders.some(o => 
          o.driver_id === conv.counterpart?.id || o.merchant_id === conv.counterpart?.id
        );
        if (!hasOrdersForUser) {
          loadOrdersForUser(conv.counterpart.id);
        }
        loadDriverLocation(conv.counterpart.id);
      }
    } else {
      // Only clear if we actually had a selection
      if (selectedConversationId === null && messages.length > 0) {
        setMessages([]);
        setOrders([]);
        setOrderEditForms({});
        setDriverLocation(null);
      }
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [selectedConversationId]);

  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages]);

  const fetchOrderStatuses = async () => {
    try {
      const { data, error } = await supabaseAdmin
        .from('orders')
        .select('status', { count: 'exact', head: false })
        .not('status', 'is', null)
        .limit(1000);

      if (error) throw error;
      const distinct = Array.from(new Set((data || []).map((row) => row.status))).filter(Boolean);
      if (distinct.length) {
        setOrderStatusOptions(distinct);
      }
    } catch (error) {
      console.warn('Unable to load distinct order statuses, using fallback list.', error);
      setOrderStatusOptions(FALLBACK_STATUSES);
    }
  };

  const loadConversations = async () => {
    setLoading(true);
    try {
      const { data: convs, error } = await supabaseAdmin
        .from('conversations')
        .select('*')
        .eq('is_support', true)
        .eq('is_archived', showArchived)
        .order('created_at', { ascending: false });

      if (error) throw error;

      const convsWithDetails = await Promise.all(
        (convs || []).map(async (conv) => {
          const { data: participants } = await supabaseAdmin
            .from('conversation_participants')
            .select('user_id, users(id, name, role, phone)')
            .eq('conversation_id', conv.id);

          const counterpart = participants?.find((p: any) => p.users?.role !== 'admin')
            ?.users as User | undefined;

          const { data: lastMsg, error: lastMsgError } = await supabaseAdmin
            .from('messages')
            .select('*')
            .eq('conversation_id', conv.id)
            .order('created_at', { ascending: false })
            .limit(1)
            .maybeSingle();

          if (lastMsgError && lastMsgError.code !== 'PGRST116') {
            console.warn('Unable to load last message for conversation', conv.id, lastMsgError);
          }

          let enhancedLastMessage: MessageWithAttachment | undefined;
          if (lastMsg) {
            const enrichedLast = await enrichMessagesWithAttachments([lastMsg as Message]);
            enhancedLastMessage = enrichedLast[0];
          }

          return {
            ...conv,
            counterpart,
            lastMessage: enhancedLastMessage || (lastMsg as Message | undefined),
            updated_at: (conv as any)?.updated_at,
          } as ConversationWithDetails;
        })
      );

      const deduped = new Map<string, ConversationWithDetails>();
      convsWithDetails.forEach((conv) => {
        const key = conv.counterpart?.id || conv.id;
        const existing = deduped.get(key);
        const currentTimestamp = new Date(
          conv.updated_at || conv.lastMessage?.created_at || conv.created_at
        ).getTime();
        const existingTimestamp = existing
          ? new Date(existing.updated_at || existing.lastMessage?.created_at || existing.created_at).getTime()
          : -Infinity;

        if (!existing || currentTimestamp > existingTimestamp) {
          deduped.set(key, conv);
        }
      });

      const ordered = Array.from(deduped.values()).sort((a, b) => {
        const aDate = new Date(a.updated_at || a.lastMessage?.created_at || a.created_at).getTime();
        const bDate = new Date(b.updated_at || b.lastMessage?.created_at || b.created_at).getTime();
        return bDate - aDate;
      });

      setConversations(ordered);
    } catch (error) {
      console.error('Error loading conversations:', error);
    } finally {
      setLoading(false);
    }
  };

  const loadMessages = async (conversationId: string, useCache = true) => {
    // Check cache first if useCache is true
    if (useCache && messagesCache.current[conversationId]) {
      console.log('📦 Loading messages from cache for conversation', conversationId);
      setMessages(messagesCache.current[conversationId]);
      return;
    }

    try {
      const { data, error } = await supabaseAdmin
        .from('messages')
        .select('*')
        .eq('conversation_id', conversationId)
        .order('created_at', { ascending: true });

      if (error) throw error;
      const enriched = await enrichMessagesWithAttachments((data || []) as Message[]);
      
      // Cache the messages
      messagesCache.current[conversationId] = enriched;
      setMessages(enriched);

      const orderIds = Array.from(
        new Set((data || []).map((msg) => msg.order_id).filter(Boolean) as string[])
      );
      if (orderIds.length) {
        await ensureOrdersLoaded(orderIds);
      }
    } catch (error) {
      console.error('Error loading messages:', error);
    }
  };

  const ensureOrdersLoaded = async (orderIds: string[]) => {
    const missing = orderIds.filter((id) => !orderLookup[id]);
    if (!missing.length) return;

    try {
      const { data, error } = await supabaseAdmin.from('orders').select('*').in('id', missing);
      if (error) throw error;

      if (data && data.length) {
        setOrderLookup((prev) => {
          const next = { ...prev };
          data.forEach((order) => {
            next[order.id] = order as Order;
          });
          return next;
        });
      }
    } catch (error) {
      console.error('Error loading referenced orders:', error);
    }
  };

  const loadOrdersForUser = async (userId: string) => {
    try {
      const { data, error } = await supabaseAdmin
        .from('orders')
        .select('*')
        .or(`driver_id.eq.${userId},merchant_id.eq.${userId}`)
        .order('created_at', { ascending: false })
        .limit(25);

      if (error) throw error;

      const result = (data || []) as OrderWithEditing[];
      setOrders(result);

      setOrderLookup((prev) => {
        const next = { ...prev };
        result.forEach((order) => {
          next[order.id] = order;
        });
        return next;
      });

      setOrderEditForms((prev) => {
        const next = { ...prev };
        result.forEach((order) => {
          if (!next[order.id]) {
            next[order.id] = buildOrderForm(order);
          }
        });
        return next;
      });
    } catch (error) {
      console.error('Error loading orders:', error);
      setOrders([]);
    }
  };

  const loadDriverLocation = async (userId: string) => {
    try {
      const { data, error } = await supabaseAdmin
        .from('users')
        .select('latitude, longitude, role')
        .eq('id', userId)
        .maybeSingle();

      if (error) {
        console.warn('Error loading driver location:', error);
        setDriverLocation(null);
        return;
      }

      if (data && data.role === 'driver' && data.latitude && data.longitude) {
        setDriverLocation({ lat: data.latitude, lng: data.longitude });
      } else {
        setDriverLocation(null);
      }
    } catch (error) {
      console.warn('Error loading driver location:', error);
      setDriverLocation(null);
    }
  };

  const handleSelectConversation = (id: string) => {
    setSelectedConversationId(id);
  };

  const getAdminUserId = async () => {
    const {
      data: { session },
    } = await supabase.auth.getSession();
    return session?.user?.id || null;
  };

  const handleSendMessage = async () => {
    if (!messageBody.trim() || !selectedConversationId) return;

    try {
      const {
        data: { session },
      } = await supabase.auth.getSession();
      const adminUserId = session?.user?.id;

      // Send the message
      await supabaseAdmin.rpc('send_message', {
        p_conversation_id: selectedConversationId,
        p_body: messageBody.trim(),
        p_kind: 'text',
        p_sender_id: adminUserId || null,
      });

      // Get recipient user ID from conversation
      const selectedConv = conversations.find(c => c.id === selectedConversationId);
      const recipientId = selectedConv?.counterpart?.id;

      // Send push notification directly via edge function (without saving to notifications table)
      if (recipientId && adminUserId) {
        // Get admin name from users table
        let adminName = 'مشرف / Admin';
        try {
          const { data: adminUser } = await supabaseAdmin
            .from('users')
            .select('name')
            .eq('id', adminUserId)
            .maybeSingle();
          if (adminUser?.name) {
            adminName = adminUser.name;
          }
        } catch (err) {
          console.warn('Failed to fetch admin name:', err);
        }
        
        const messagePreview = messageBody.trim().substring(0, 100);
        
        // Send notification asynchronously (non-blocking) to avoid lag
        supabase.functions.invoke('send-push-notification', {
          body: {
            user_id: recipientId,
            title: 'دعم حر',
            body: messagePreview,
            data: {
              conversation_id: selectedConversationId,
              sender_id: adminUserId,
              sender_name: adminName,
              type: 'message'
            }
          }
        }).catch((notifError) => {
          // Log but don't fail the message send if notification fails
          console.warn('Failed to send push notification:', notifError);
        });
      }

      setMessageBody('');
      // Reload messages without cache to show the new message immediately
      loadMessages(selectedConversationId, false);
    } catch (error) {
      console.error('Error sending message:', error);
      alert('فشل إرسال الرسالة / Failed to send message. Check console for details.');
    }
  };

  const copyCoordinates = () => {
    if (driverLocation) {
      navigator.clipboard.writeText(`${driverLocation.lat}, ${driverLocation.lng}`);
      alert('تم نسخ الإحداثيات / Coordinates copied');
    }
  };

  const archiveConversation = async () => {
    if (!selectedConversationId) return;

    try {
      const { error } = await supabaseAdmin.rpc('archive_conversation', {
        p_conversation_id: selectedConversationId,
      });

      if (error) throw error;

      alert('تم أرشفة المحادثة / Conversation archived');
      setSelectedConversationId(null);
      loadConversations();
    } catch (error) {
      console.error('Error archiving conversation:', error);
      alert('فشل في الأرشفة / Failed to archive');
    }
  };

  const getOrderById = (orderId: string): Order | undefined =>
    orderLookup[orderId] || orders.find((order) => order.id === orderId);

  const handleStartEditing = (order: OrderWithEditing) => {
    setEditingOrderId(order.id);
    setOrderEditForms((prev) => ({
      ...prev,
      [order.id]: prev[order.id] || buildOrderForm(order),
    }));
  };

  const handleOrderFieldChange = (orderId: string, field: keyof OrderEditForm, value: string) => {
    setOrderEditForms((prev) => {
      const base = getOrderById(orderId);
      const existing = prev[orderId] || (base ? buildOrderForm(base) : createEmptyOrderForm());
      return {
        ...prev,
        [orderId]: { ...existing, [field]: value },
      };
    });
  };

  const handleSaveOrder = async (orderId: string) => {
    const form = orderEditForms[orderId];
    if (!form) return;

    const safeNumber = (value: string) => {
      if (!value.trim()) return null;
      const parsed = Number(value);
      return Number.isNaN(parsed) ? null : parsed;
    };

    const payload = {
      p_order_id: orderId,
      p_status: form.status || null,
      p_driver_id: form.driver_id || null,
      p_notes: form.notes?.trim() ? form.notes.trim() : null,
      p_customer_name: form.customer_name?.trim() || null,
      p_customer_phone: form.customer_phone?.trim() || null,
      p_pickup_address: form.pickup_address?.trim() || null,
      p_pickup_latitude: safeNumber(form.pickup_latitude),
      p_pickup_longitude: safeNumber(form.pickup_longitude),
      p_delivery_address: form.delivery_address?.trim() || null,
      p_delivery_latitude: safeNumber(form.delivery_latitude),
      p_delivery_longitude: safeNumber(form.delivery_longitude),
      p_delivery_fee: safeNumber(form.delivery_fee),
    };

    try {
      const { error } = await supabaseAdmin.rpc('update_order_from_chat', payload);
      if (error) throw error;

      if (selectedConversation?.counterpart?.id) {
        await loadOrdersForUser(selectedConversation.counterpart.id);
      }

      if (selectedConversationId) {
        const adminUserId = await getAdminUserId();
        const messageBody = `تم تحديث بيانات الطلب (${orderId.slice(0, 8)}) بواسطة المشرف.`;
        
        await supabaseAdmin.rpc('send_message', {
          p_conversation_id: selectedConversationId,
          p_body: messageBody,
          p_kind: 'text',
          p_sender_id: adminUserId,
        });

        // Send push notification directly via edge function (without saving to notifications table)
        const selectedConv = conversations.find(c => c.id === selectedConversationId);
        const recipientId = selectedConv?.counterpart?.id;
        
        if (recipientId && adminUserId) {
          // Get admin name from users table
          let adminName = 'مشرف / Admin';
          try {
            const { data: adminUser } = await supabaseAdmin
              .from('users')
              .select('name')
              .eq('id', adminUserId)
              .maybeSingle();
            if (adminUser?.name) {
              adminName = adminUser.name;
            }
          } catch (err) {
            console.warn('Failed to fetch admin name:', err);
          }
          
          // Send notification asynchronously (non-blocking) to avoid lag
          supabase.functions.invoke('send-push-notification', {
            body: {
              user_id: recipientId,
              title: 'دعم حر',
              body: messageBody,
              data: {
                conversation_id: selectedConversationId,
                sender_id: adminUserId,
                sender_name: adminName,
                type: 'message',
                order_id: orderId
              }
            }
          }).catch((notifError) => {
            // Log but don't fail if notification fails
            console.warn('Failed to send push notification:', notifError);
          });
        }
        
        await loadMessages(selectedConversationId, false);
      }

      setEditingOrderId(null);
      alert('تم حفظ التعديلات / Changes saved');
    } catch (error: any) {
      console.error('Error updating order:', error);
      alert(error.message || 'فشل في تحديث الطلب / Failed to update order');
    }
  };

  const openDriverPicker = async (order: OrderWithEditing) => {
    setDriverPickerOrder(order);
    setLoadingDrivers(true);
    try {
      const { data, error } = await supabaseAdmin
        .from('users')
        .select('id, name, phone, latitude, longitude, is_online')
        .eq('role', 'driver')
        .eq('is_online', true);

      if (error) throw error;

      const anchorLat =
        order.pickup_latitude != null ? Number(order.pickup_latitude) : null;
      const anchorLng =
        order.pickup_longitude != null ? Number(order.pickup_longitude) : null;

      const options =
        (data || []).map((driver: any) => ({
          driver: driver as User,
          distance: calculateDistanceInKm(
            anchorLat,
            anchorLng,
            driver.latitude,
            driver.longitude
          ),
        })) || [];

      const sorted = options.sort((a, b) => {
        if (a.distance == null) return 1;
        if (b.distance == null) return -1;
        return a.distance - b.distance;
      });

      setDriverOptions(sorted);
    } catch (error) {
      console.error('Error loading driver options:', error);
      setDriverOptions([]);
    } finally {
      setLoadingDrivers(false);
    }
  };

  const handleDriverSelect = (orderId: string, driver: User) => {
    setOrderEditForms((prev) => {
      const base = getOrderById(orderId);
      const existing = prev[orderId] || (base ? buildOrderForm(base) : createEmptyOrderForm());
      return {
        ...prev,
        [orderId]: { ...existing, driver_id: driver.id },
      };
    });
    setDriverPickerOrder(null);
  };

  const ensureOrderVisible = async (orderId: string) => {
    const exists = orders.some((order) => order.id === orderId);
    if (!exists) {
      try {
        const { data } = await supabaseAdmin
          .from('orders')
          .select('*')
          .eq('id', orderId)
          .maybeSingle();
        if (data) {
          setOrders((prev) => [data as OrderWithEditing, ...prev]);
          setOrderLookup((prev) => ({ ...prev, [orderId]: data as Order }));
          setOrderEditForms((prev) => ({
            ...prev,
            [orderId]: prev[orderId] || buildOrderForm(data as Order),
          }));
        }
      } catch (error) {
        console.warn('Unable to fetch order for highlighting', error);
      }
    }
  };

  const focusOrder = async (orderId: string) => {
    await ensureOrdersLoaded([orderId]);
    await ensureOrderVisible(orderId);
    setHighlightedOrderId(orderId);
    document.getElementById(`order-${orderId}`)?.scrollIntoView({ behavior: 'smooth', block: 'center' });
    setTimeout(() => {
      setHighlightedOrderId((current) => (current === orderId ? null : current));
    }, 4000);
  };

  const selectedConversation = conversations.find((c) => c.id === selectedConversationId);

  if (loading) {
    return (
      <div className="flex items-center justify-center h-full">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary-500"></div>
      </div>
    );
  }

  return (
    <div className="h-[calc(100vh-12rem)] flex gap-6">
      <div className="w-80 bg-white rounded-xl shadow-sm flex flex-col overflow-hidden">
        <div className="p-4 border-b border-gray-200">
          <h3 className="font-semibold text-gray-900 mb-3">المحادثات / Conversations</h3>
          <button
            onClick={() => {
              setShowArchived(!showArchived);
              setSelectedConversationId(null);
              setMessages([]);
            }}
            className="w-full px-3 py-2 text-sm bg-gray-100 hover:bg-gray-200 rounded-lg transition-colors"
          >
            {showArchived ? '✓ عرض المؤرشفة / Archived' : 'عرض النشطة / Active'}
          </button>
        </div>
        <div className="flex-1 overflow-y-auto">
          {conversations.map((conv) => (
            <div
              key={conv.id}
              onClick={() => handleSelectConversation(conv.id)}
              className={`p-4 border-b border-gray-100 cursor-pointer hover:bg-gray-50 transition-colors ${
                conv.id === selectedConversationId ? 'bg-primary-50' : ''
              }`}
            >
              <div className="flex items-center gap-3 mb-2">
                <div className="w-10 h-10 bg-primary-100 rounded-full flex items-center justify-center">
                  <i className="fas fa-user text-primary-600"></i>
                </div>
                <div className="flex-1 min-w-0">
                  <p className="font-medium text-gray-900 truncate">
                    {conv.counterpart?.name || 'مستخدم'}
                  </p>
                  <p className="text-xs text-gray-500">{conv.counterpart?.role}</p>
                </div>
              </div>
              {conv.lastMessage && (
                <p className="text-sm text-gray-600 truncate flex items-center gap-2">
                  {(() => {
                    const last = conv.lastMessage as MessageWithAttachment;
                    const attachmentUrl = last?.resolvedAttachmentUrl || last?.attachment_url;
                    const isFromAdmin = adminUserId && last?.sender_id === adminUserId;
                    const content = conv.lastMessage.body?.trim()
                      ? conv.lastMessage.body
                      : 'مرفق / Attachment';

                    if (attachmentUrl) {
                      return (
                    <>
                      <i className="fas fa-paperclip text-primary-500"></i>
                      <span>
                            {isFromAdmin && (
                              <span className="font-semibold text-primary-600">أنت: </span>
                            )}
                            {content}
                      </span>
                    </>
                      );
                    }

                    return (
                      <>
                        {isFromAdmin && (
                          <span className="font-semibold text-primary-600">أنت: </span>
                        )}
                        <span>{conv.lastMessage.body}</span>
                      </>
                    );
                  })()}
                </p>
              )}
            </div>
          ))}
          {conversations.length === 0 && (
            <div className="text-center py-12 text-gray-500">
              <i className="fas fa-comments text-4xl mb-2"></i>
              <p className="text-sm">لا توجد محادثات / No conversations</p>
            </div>
          )}
        </div>
      </div>

      <div className="flex-1 bg-white rounded-xl shadow-sm flex flex-col overflow-hidden">
        {selectedConversation ? (
          <>
            <div className="p-4 border-b border-gray-200 flex items-center justify-between">
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 bg-primary-100 rounded-full flex items-center justify-center">
                  <i className="fas fa-user text-primary-600"></i>
                </div>
                <div>
                  <p className="font-semibold text-gray-900">
                    {selectedConversation.counterpart?.name || 'مستخدم'}
                  </p>
                  <p className="text-xs text-gray-500">{selectedConversation.counterpart?.phone}</p>
                </div>
              </div>

              {!showArchived && (
                <button
                  onClick={archiveConversation}
                  className="px-4 py-2 bg-green-500 hover:bg-green-600 text-white text-sm rounded-lg transition-colors flex items-center gap-2"
                  title="Mark as Complete & Archive"
                >
                  <i className="fas fa-check"></i>
                  <span>إكمال / Complete</span>
                </button>
              )}
            </div>

            <div className="flex-1 overflow-y-auto p-4 space-y-4">
              {messages.map((msg) => {
                const counterpartId = selectedConversation.counterpart?.id;
                const isAdminMessage = adminUserId
                  ? msg.sender_id === adminUserId
                  : counterpartId
                  ? msg.sender_id !== counterpartId
                  : false;
                const alignmentClass = isAdminMessage ? 'justify-end' : 'justify-start';
                const bubbleClass = isAdminMessage
                  ? 'bg-primary-500 text-white'
                  : 'bg-gray-100 text-gray-900';
                const metaClass = isAdminMessage ? 'text-primary-100' : 'text-gray-500';
                const actionButtonClass = isAdminMessage
                  ? 'border-primary-100 text-white hover:bg-primary-600/80'
                  : 'border-gray-300 text-gray-600 hover:bg-gray-200';

                return (
                  <div key={msg.id} className={`flex ${alignmentClass}`}>
                    <div className={`max-w-[70%] rounded-lg p-3 space-y-2 ${bubbleClass}`}>
                      {adminUserId && (
                        <p
                          className={`text-[11px] font-semibold uppercase tracking-wide ${
                            isAdminMessage ? 'text-white/70' : 'text-primary-500/70'
                          }`}
                        >
                          {isAdminMessage ? 'أنت' : selectedConversation.counterpart?.name || 'مستخدم'}
                        </p>
                      )}
                    {msg.body?.trim() && (
                      <p className="text-sm whitespace-pre-wrap break-words">{msg.body}</p>
                    )}
                      {(() => {
                        const attachmentUrl =
                          msg.resolvedAttachmentUrl ||
                          (isHttpLikeUrl(msg.attachment_url) ? msg.attachment_url : null);
                        if (!attachmentUrl) return null;
                        return (
                          <a
                            href={attachmentUrl}
                        target="_blank"
                        rel="noopener noreferrer"
                            className={`block overflow-hidden rounded-lg border ${
                              isAdminMessage ? 'border-white/30' : 'border-white/40'
                            }`}
                      >
                        <img
                              src={attachmentUrl}
                          alt="Message attachment"
                          className="max-h-64 w-full object-cover"
                          loading="lazy"
                        />
                      </a>
                        );
                      })()}
                      <div className={`flex items-center justify-between gap-2 text-xs ${metaClass}`}>
                      <span>
                        {new Date(msg.created_at).toLocaleTimeString('ar-IQ', {
                          hour: '2-digit',
                          minute: '2-digit',
                        })}
                      </span>
                        <div className="flex items-center gap-2">
                      {msg.order_id && (
                        <button
                          onClick={() => focusOrder(msg.order_id!)}
                              className={`inline-flex items-center gap-1 px-2 py-1 rounded-full border text-xs transition-colors ${actionButtonClass}`}
                        >
                          <i className="fas fa-link"></i>
                          الطلب {msg.order_id.slice(0, 6)}
                        </button>
                      )}
                          {(() => {
                            const attachmentUrl =
                              msg.resolvedAttachmentUrl ||
                              (isHttpLikeUrl(msg.attachment_url) ? msg.attachment_url : null);
                            if (!attachmentUrl) return null;
                            return (
                              <a
                                href={attachmentUrl}
                          target="_blank"
                          rel="noopener noreferrer"
                                className={`inline-flex items-center gap-1 px-2 py-1 rounded-full border text-xs transition-colors ${actionButtonClass}`}
                        >
                          <i className="fas fa-download"></i>
                          حفظ / Save
                        </a>
                            );
                          })()}
                    </div>
                  </div>
                </div>
                  </div>
                );
              })}
              <div ref={messagesEndRef} />
            </div>

            <div className="p-4 border-t border-gray-200">
              <div className="flex gap-2">
                <input
                  type="text"
                  value={messageBody}
                  onChange={(e) => setMessageBody(e.target.value)}
                  onKeyDown={(e) => {
                    if (e.key === 'Enter' && !e.shiftKey) {
                      e.preventDefault();
                      handleSendMessage();
                    }
                  }}
                  placeholder="اكتب رسالة... / Type a message..."
                  className="flex-1 px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 outline-none"
                />
                <button
                  onClick={handleSendMessage}
                  className="px-6 py-2 bg-primary-500 hover:bg-primary-600 text-white rounded-lg transition-colors"
                >
                  <i className="fas fa-paper-plane"></i>
                </button>
              </div>
            </div>
          </>
        ) : (
          <div className="flex-1 flex items-center justify-center text-gray-500">
            <div className="text-center">
              <i className="fas fa-comments text-6xl mb-4"></i>
              <p>اختر محادثة / Select a conversation</p>
            </div>
          </div>
        )}
      </div>

      {selectedConversation && (
        <div className="w-80 bg-white rounded-xl shadow-sm overflow-hidden">
          <div className="border-b border-gray-200">
            <div className="p-4">
              <h4 className="font-semibold text-gray-900">الطلبات / Orders</h4>
            </div>
            <div className="max-h-60 overflow-y-auto p-4 space-y-3">
              {orders.map((order) => {
                const form = orderEditForms[order.id] || buildOrderForm(order);
                const isEditing = editingOrderId === order.id;
                const isHighlighted = highlightedOrderId === order.id;

                return (
                  <div
                    key={order.id}
                    id={`order-${order.id}`}
                    className={`p-3 bg-gray-50 rounded-lg text-sm border transition-shadow ${
                      isHighlighted ? 'border-primary-400 shadow-lg' : 'border-gray-200'
                    }`}
                  >
                    <div className="flex items-center justify-between mb-2">
                      <p className="font-medium text-gray-900">#{order.id.slice(0, 8)}</p>
                      {isEditing ? (
                        <button
                          onClick={() => setEditingOrderId(null)}
                          className="text-xs text-gray-600 hover:text-gray-800"
                        >
                          <i className="fas fa-times mr-1"></i>
                          إلغاء
                        </button>
                      ) : (
                        <button
                          onClick={() => handleStartEditing(order)}
                          className="text-xs text-blue-600 hover:text-blue-800"
                        >
                          <i className="fas fa-edit mr-1"></i>
                          تعديل
                        </button>
                      )}
                    </div>

                    <p className="text-gray-700 mb-1">{order.customer_name}</p>
                    <p className="text-gray-600 text-xs mb-2">{order.customer_phone}</p>

                    {isEditing ? (
                      <div className="space-y-3 pt-2 border-t border-gray-300">
                        <div>
                          <label className="block text-xs font-medium text-gray-700">
                            الحالة / Status
                          </label>
                          <select
                            value={form.status}
                            onChange={(e) =>
                              handleOrderFieldChange(order.id, 'status', e.target.value)
                            }
                            className="w-full px-2 py-1 border border-gray-300 rounded text-xs"
                          >
                            {orderStatusOptions.map((status) => (
                              <option key={status} value={status}>
                                {status}
                              </option>
                            ))}
                          </select>
                        </div>

                        <div className="grid grid-cols-1 gap-2">
                          <div>
                            <label className="block text-xs font-medium text-gray-700">
                              اسم العميل
                            </label>
                            <input
                              value={form.customer_name}
                              onChange={(e) =>
                                handleOrderFieldChange(order.id, 'customer_name', e.target.value)
                              }
                              className="w-full px-2 py-1 border border-gray-300 rounded text-xs"
                            />
                          </div>
                          <div>
                            <label className="block text-xs font-medium text-gray-700">
                              هاتف العميل
                            </label>
                            <input
                              value={form.customer_phone}
                              onChange={(e) =>
                                handleOrderFieldChange(order.id, 'customer_phone', e.target.value)
                              }
                              className="w-full px-2 py-1 border border-gray-300 rounded text-xs"
                            />
                          </div>
                        </div>

                        <div className="grid grid-cols-1 gap-3 pt-2 border-t border-gray-200">
                          <div>
                            <label className="block text-xs font-medium text-gray-700">
                              عنوان الاستلام / Pickup Address
                            </label>
                            <textarea
                              value={form.pickup_address}
                              onChange={(e) =>
                                handleOrderFieldChange(order.id, 'pickup_address', e.target.value)
                              }
                              className="w-full px-2 py-1 border border-gray-300 rounded text-xs"
                            />
                          </div>
                          <div className="grid grid-cols-2 gap-2">
                            <div>
                              <label className="block text-xs font-medium text-gray-700">
                                خط العرض / Latitude
                              </label>
                              <input
                                value={form.pickup_latitude}
                                onChange={(e) =>
                                  handleOrderFieldChange(order.id, 'pickup_latitude', e.target.value)
                                }
                                className="w-full px-2 py-1 border border-gray-300 rounded text-xs"
                              />
                            </div>
                            <div>
                              <label className="block text-xs font-medium text-gray-700">
                                خط الطول / Longitude
                              </label>
                              <input
                                value={form.pickup_longitude}
                                onChange={(e) =>
                                  handleOrderFieldChange(order.id, 'pickup_longitude', e.target.value)
                                }
                                className="w-full px-2 py-1 border border-gray-300 rounded text-xs"
                              />
                            </div>
                          </div>
                        </div>

                        <div className="grid grid-cols-1 gap-3 pt-2 border-t border-gray-200">
                          <div>
                            <label className="block text-xs font-medium text-gray-700">
                              عنوان التسليم / Delivery Address
                            </label>
                            <textarea
                              value={form.delivery_address}
                              onChange={(e) =>
                                handleOrderFieldChange(order.id, 'delivery_address', e.target.value)
                              }
                              className="w-full px-2 py-1 border border-gray-300 rounded text-xs"
                            />
                          </div>
                          <div className="grid grid-cols-2 gap-2">
                            <div>
                              <label className="block text-xs font-medium text-gray-700">
                                خط العرض / Latitude
                              </label>
                              <input
                                value={form.delivery_latitude}
                                onChange={(e) =>
                                  handleOrderFieldChange(order.id, 'delivery_latitude', e.target.value)
                                }
                                className="w-full px-2 py-1 border border-gray-300 rounded text-xs"
                              />
                            </div>
                            <div>
                              <label className="block text-xs font-medium text-gray-700">
                                خط الطول / Longitude
                              </label>
                              <input
                                value={form.delivery_longitude}
                                onChange={(e) =>
                                  handleOrderFieldChange(order.id, 'delivery_longitude', e.target.value)
                                }
                                className="w-full px-2 py-1 border border-gray-300 rounded text-xs"
                              />
                            </div>
                          </div>
                        </div>

                        <div>
                          <label className="block text-xs font-medium text-gray-700">
                            رسوم التوصيل / Delivery Fee
                          </label>
                          <input
                            type="number"
                            value={form.delivery_fee}
                            onChange={(e) =>
                              handleOrderFieldChange(order.id, 'delivery_fee', e.target.value)
                            }
                            className="w-full px-2 py-1 border border-gray-300 rounded text-xs"
                          />
                        </div>

                        <div>
                          <label className="block text-xs font-medium text-gray-700">
                            ملاحظات الطلب
                          </label>
                          <textarea
                            value={form.notes}
                            onChange={(e) => handleOrderFieldChange(order.id, 'notes', e.target.value)}
                            className="w-full px-2 py-1 border border-gray-300 rounded text-xs"
                          />
                        </div>

                        <button
                          onClick={() => {
                            if (order.customer_phone) {
                              window.location.href = `tel:${order.customer_phone}`;
                            }
                          }}
                          className="w-full px-2 py-1 bg-blue-500 hover:bg-blue-600 text-white text-xs rounded flex items-center justify-center gap-1"
                        >
                          <i className="fas fa-phone"></i>
                          اتصال بالعميل / Call Customer
                        </button>

                        <div className="mt-2">
                          <label className="block text-xs font-medium text-gray-700 mb-1">
                            إعادة تعيين السائق / Reassign Driver
                          </label>
                          <div className="flex items-center gap-2">
                            <button
                              onClick={() => openDriverPicker(order)}
                              className="flex-1 px-2 py-1 bg-primary-500 hover:bg-primary-600 text-white text-xs rounded transition-colors"
                            >
                              اختيار سائق / Choose Driver
                            </button>
                            {form.driver_id && (
                              <span className="text-xs text-gray-600">
                                ID: {form.driver_id.slice(0, 6)}
                              </span>
                            )}
                          </div>
                        </div>

                        <div className="flex items-center justify-between pt-2">
                          <button
                            onClick={() => handleSaveOrder(order.id)}
                            className="flex-1 px-2 py-1 bg-green-500 hover:bg-green-600 text-white text-xs rounded"
                          >
                            حفظ التعديلات / Save
                          </button>
                        </div>
                      </div>
                    ) : (
                      <span
                        className={`inline-block px-2 py-1 text-xs rounded ${
                          order.status === 'pending'
                            ? 'bg-yellow-100 text-yellow-800'
                            : order.status === 'assigned'
                            ? 'bg-blue-100 text-blue-800'
                            : order.status === 'accepted'
                            ? 'bg-indigo-100 text-indigo-800'
                            : order.status === 'on_the_way'
                            ? 'bg-purple-100 text-purple-800'
                            : order.status === 'delivered'
                            ? 'bg-green-100 text-green-800'
                            : order.status === 'cancelled'
                            ? 'bg-red-100 text-red-800'
                            : 'bg-gray-100 text-gray-800'
                        }`}
                      >
                        {order.status}
                      </span>
                    )}
                  </div>
                );
              })}
              {orders.length === 0 && (
                <p className="text-gray-500 text-sm text-center">لا توجد طلبات مرتبطة</p>
              )}
            </div>
          </div>

          <div className="p-4">
            <h4 className="font-semibold text-gray-900 mb-3">موقع السائق / Driver Location</h4>
            {driverLocation ? (
              <div className="space-y-2">
                <p className="text-sm text-gray-600">
                  <span className="font-medium">Lat:</span> {driverLocation.lat.toFixed(6)}
                </p>
                <p className="text-sm text-gray-600">
                  <span className="font-medium">Lng:</span> {driverLocation.lng.toFixed(6)}
                </p>
                <button
                  onClick={copyCoordinates}
                  className="w-full px-4 py-2 bg-primary-50 hover:bg-primary-100 text-primary-600 rounded-lg text-sm font-medium transition-colors"
                >
                  <i className="fas fa-copy mr-2"></i>
                  نسخ الإحداثيات / Copy Coordinates
                </button>
              </div>
            ) : (
              <p className="text-gray-500 text-sm text-center">لا يوجد موقع متاح</p>
            )}
          </div>
        </div>
      )}

      {driverPickerOrder && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4">
          <div className="bg-white rounded-xl shadow-xl max-w-lg w-full max-h-[80vh] overflow-hidden">
            <div className="flex items-center justify-between p-4 border-b border-gray-200">
              <h3 className="text-lg font-semibold text-gray-900">
                اختر سائق للطلب #{driverPickerOrder.id.slice(0, 8)}
              </h3>
              <button
                onClick={() => setDriverPickerOrder(null)}
                className="text-gray-400 hover:text-gray-600"
              >
                <i className="fas fa-times text-xl"></i>
              </button>
            </div>

            <div className="p-4 space-y-3 max-h-[60vh] overflow-y-auto">
              {loadingDrivers && (
                <div className="flex items-center justify-center py-6">
                  <div className="animate-spin rounded-full h-10 w-10 border-b-2 border-primary-500"></div>
                </div>
              )}

              {!loadingDrivers && driverOptions.length === 0 && (
                <p className="text-sm text-gray-500 text-center">
                  لا يوجد سائقون متصلون بالقرب حاليًا
                </p>
              )}

              {!loadingDrivers &&
                driverOptions.map(({ driver, distance }) => (
                  <button
                    key={driver.id}
                    onClick={() => handleDriverSelect(driverPickerOrder.id, driver)}
                    className="w-full text-right px-4 py-3 bg-gray-50 hover:bg-primary-50 rounded-lg border border-gray-200 transition-colors flex items-center justify-between"
                  >
                    <div>
                      <p className="font-medium text-gray-900">{driver.name}</p>
                      <p className="text-xs text-gray-500">{driver.phone}</p>
                    </div>
                    <div className="text-xs text-gray-600 flex flex-col items-end">
                      <span>
                        {distance != null ? `${distance.toFixed(2)} كم` : 'المسافة غير معروفة'}
                      </span>
                      {(driver.is_available ?? driver.is_online) === false && (
                        <span className="text-red-500 mt-1">غير متاح</span>
                      )}
                    </div>
                  </button>
                ))}
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

