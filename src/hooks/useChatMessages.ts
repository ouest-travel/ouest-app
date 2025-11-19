"use client";

import { useState, useEffect } from 'react';
import { supabase } from '../lib/supabase';
import { useDemoMode } from '../contexts/DemoModeContext';
import { useAuth } from '../contexts/AuthContext';

export interface ChatMessage {
  id: string;
  trip_id?: string | number;
  user_id?: string;
  type?: 'text' | 'expense' | 'summary';
  message_type?: 'text' | 'expense' | 'summary';
  user?: string;
  avatar?: string;
  content?: string | null;
  timestamp?: string;
  created_at?: string;
  metadata?: any;
  // Expense-specific fields
  expenseTitle?: string;
  amount?: number;
  currency?: string;
  splitAmong?: number;
  // Summary-specific fields
  debts?: any[];
}

const demoMessages: ChatMessage[] = [
  {
    id: "1",
    type: "text",
    user: "Trey",
    avatar: "👨🏻",
    content: "Just booked our hotel in Shibuya! 🏨",
    timestamp: "2:34 PM",
  },
  {
    id: "2",
    type: "text",
    user: "Sandra",
    avatar: "👩🏽",
    content: "Amazing! Can't wait 🎉",
    timestamp: "2:35 PM",
  },
  {
    id: "3",
    type: "expense",
    user: "Timmy",
    avatar: "👨🏾",
    expenseTitle: "Sushi Zanmai Dinner",
    amount: 120,
    currency: "CAD",
    splitAmong: 4,
    timestamp: "3:12 PM",
  },
  {
    id: "4",
    type: "text",
    user: "Jason",
    avatar: "👨🏼",
    content: "That sushi was incredible! 🍣",
    timestamp: "3:15 PM",
  },
  {
    id: "5",
    type: "expense",
    user: "Jason",
    avatar: "👨🏼",
    expenseTitle: "Subway Tickets",
    amount: 45,
    currency: "CAD",
    splitAmong: 4,
    timestamp: "4:22 PM",
  },
  {
    id: "6",
    type: "text",
    user: "Sandra",
    avatar: "👩🏽",
    content: "Let's settle up before we leave!",
    timestamp: "5:10 PM",
  },
  {
    id: "7",
    type: "summary",
    user: "Jason",
    avatar: "👨🏼",
    timestamp: "5:12 PM",
    debts: [
      { from: "Trey", to: "Timmy", amount: 6.25, currency: "CAD" },
      { from: "Trey", to: "Sandra", amount: 18.75, currency: "CAD" },
      { from: "Jason", to: "Sandra", amount: 76.25, currency: "CAD" },
    ],
  },
];

export function useChatMessages(tripId: string | number | null) {
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [loading, setLoading] = useState(true);
  const { isDemoMode } = useDemoMode();
  const { user } = useAuth();

  useEffect(() => {
    if (isDemoMode) {
      setMessages(demoMessages);
      setLoading(false);
      return;
    }

    if (!user || !tripId) {
      setMessages([]);
      setLoading(false);
      return;
    }

    loadMessages();

    // Subscribe to real-time changes
    const subscription = supabase
      .channel(`chat_${tripId}`)
      .on(
        'postgres_changes',
        {
          event: 'INSERT',
          schema: 'public',
          table: 'chat_messages',
          filter: `trip_id=eq.${tripId}`,
        },
        (payload) => {
          setMessages((prev) => [...prev, payload.new as ChatMessage]);
        }
      )
      .subscribe();

    return () => {
      subscription.unsubscribe();
    };
  }, [isDemoMode, user, tripId]);

  const loadMessages = async () => {
    if (!tripId) return;

    setLoading(true);

    const { data, error } = await supabase
      .from('chat_messages')
      .select('*, profiles(display_name, avatar_url)')
      .eq('trip_id', tripId)
      .order('created_at', { ascending: true });

    if (error) {
      console.error('Error loading messages:', error);
    } else {
      setMessages(data || []);
    }

    setLoading(false);
  };

  const sendMessage = async (content: string, messageType: 'text' | 'expense' | 'summary' = 'text', metadata?: any) => {
    if (isDemoMode) {
      const newMessage: ChatMessage = {
        id: Date.now().toString(),
        type: messageType,
        user: "You",
        avatar: "👤",
        content,
        timestamp: new Date().toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit' }),
        metadata,
      };
      setMessages((prev) => [...prev, newMessage]);
      return { data: newMessage, error: null };
    }

    if (!user || !tripId) {
      return { data: null, error: new Error('Missing user or trip ID') };
    }

    const { data, error } = await supabase
      .from('chat_messages')
      .insert({
        trip_id: tripId,
        user_id: user.id,
        content,
        message_type: messageType,
        metadata,
      } as any)
      .select()
      .single();

    if (error) {
      console.error('Error sending message:', error);
      return { data: null, error };
    }

    return { data, error: null };
  };

  return {
    messages,
    loading,
    sendMessage,
    refreshMessages: loadMessages,
  };
}

