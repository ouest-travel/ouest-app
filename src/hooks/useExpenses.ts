"use client";

import { useState, useEffect } from 'react';
import { supabase } from '../lib/supabase';
import { useDemoMode } from '../contexts/DemoModeContext';
import { useAuth } from '../contexts/AuthContext';

export interface Expense {
  id: string;
  trip_id?: string | number;
  title: string;
  amount: number;
  currency: string;
  category: 'food' | 'transport' | 'stay' | 'activities' | 'other';
  paid_by: string;
  splitAmong?: number;
  split_among?: string[];
  date: string;
  has_chat?: boolean;
  hasChat?: boolean;
  created_at?: string;
}

// Demo expenses for different trips
const getDemoExpenses = (tripId: number | null): Expense[] => {
  if (tripId === 1) {
    return [
      {
        id: "1",
        title: "Sushi Zanmai Dinner",
        amount: 120,
        currency: "CAD",
        category: "food",
        // paidBy: "Timmy",
        paid_by: "Timmy",
        splitAmong: 4,
        date: "2025-10-13",
        hasChat: true,
      },
      {
        id: "2",
        title: "Subway Tickets",
        amount: 45,
        currency: "CAD",
        category: "transport",
        // paidBy: "Jason",
        paid_by: "Jason",
        splitAmong: 4,
        date: "2025-10-13",
        hasChat: true,
      },
      {
        id: "3",
        title: "Hotel Check-in",
        amount: 380,
        currency: "CAD",
        category: "stay",
        // paidBy: "Sandra",
        paid_by: "Sandra",
        splitAmong: 4,
        date: "2025-10-12",
        hasChat: false,
      },
      {
        id: "4",
        title: "TeamLab Borderless Tickets",
        amount: 95,
        currency: "CAD",
        category: "activities",
        // paidBy: "Trey",
        paid_by: "Trey",
        splitAmong: 4,
        date: "2025-10-12",
        hasChat: true,
      },
    ];
  } else if (tripId === 2) {
    return [
      {
        id: "p1",
        title: "Eiffel Tower Tickets",
        amount: 85,
        currency: "EUR",
        category: "activities",
        // paidBy: "Trey",
        paid_by: "Trey",
        splitAmong: 3,
        date: "2026-01-11",
        hasChat: false,
      },
      {
        id: "p2",
        title: "Metro Pass",
        amount: 32,
        currency: "EUR",
        category: "transport",
        // paidBy: "Sandra",
        paid_by: "Sandra",
        splitAmong: 3,
        date: "2026-01-10",
        hasChat: false,
      },
    ];
  } else if (tripId === 3) {
    return [
      {
        id: "b1",
        title: "Sagrada Familia Tour",
        amount: 140,
        currency: "EUR",
        category: "activities",
        // paidBy: "Jason",
        paid_by: "Jason",
        splitAmong: 4,
        date: "2024-09-02",
        hasChat: false,
      },
      {
        id: "b2",
        title: "Beachfront Dinner",
        amount: 180,
        currency: "EUR",
        category: "food",
        // paidBy: "Timmy",
        paid_by: "Timmy",
        splitAmong: 4,
        date: "2024-09-03",
        hasChat: false,
      },
      {
        id: "b3",
        title: "Airbnb Payment",
        amount: 560,
        currency: "EUR",
        category: "stay",
        // paidBy: "Sandra",
        paid_by: "Sandra",
        splitAmong: 4,
        date: "2024-09-01",
        hasChat: false,
      },
    ];
  }
  return [];
};

export function useExpenses(tripId: string | number | null) {
  const [expenses, setExpenses] = useState<Expense[]>([]);
  const [loading, setLoading] = useState(true);
  const { isDemoMode } = useDemoMode();
  const { user } = useAuth();

  useEffect(() => {
    if (isDemoMode) {
      const demoData = getDemoExpenses(typeof tripId === 'number' ? tripId : null);
      setExpenses(demoData);
      setLoading(false);
      return;
    }

    if (!user || !tripId) {
      setExpenses([]);
      setLoading(false);
      return;
    }

    loadExpenses();

    // Subscribe to real-time changes
    const subscription = supabase
      .channel(`expenses_${tripId}`)
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'expenses',
          filter: `trip_id=eq.${tripId}`,
        },
        () => {
          loadExpenses();
        }
      )
      .subscribe();

    return () => {
      subscription.unsubscribe();
    };
  }, [isDemoMode, user, tripId]);

  const loadExpenses = async () => {
    if (!tripId) return;

    setLoading(true);

    const { data, error } = await supabase
      .from('expenses')
      .select('*')
      .eq('trip_id', tripId)
      .order('date', { ascending: false });

    if (error) {
      console.error('Error loading expenses:', error);
    } else {
      setExpenses(data || []);
    }

    setLoading(false);
  };

  const addExpense = async (expenseData: Partial<Expense>) => {
    if (isDemoMode) {
      const newExpense: Expense = {
        id: Date.now().toString(),
        ...expenseData,
      } as Expense;
      setExpenses((prev) => [newExpense, ...prev]);
      return { data: newExpense, error: null };
    }

    if (!user || !tripId) {
      return { data: null, error: new Error('Missing user or trip ID') };
    }

    const { data, error } = await supabase
      .from('expenses')
      .insert({
        trip_id: tripId,
        title: expenseData.title || '',
        amount: expenseData.amount || 0,
        currency: expenseData.currency || 'USD',
        category: expenseData.category || 'other',
        paid_by: expenseData.paid_by || user.id,
        split_among: expenseData.split_among || [user.id],
        date: expenseData.date || new Date().toISOString(),
        has_chat: expenseData.has_chat || false,
      })
      .select()
      .single();

    if (error) {
      console.error('Error adding expense:', error);
      return { data: null, error };
    }

    return { data, error: null };
  };

  const updateExpense = async (expenseId: string, updates: Partial<Expense>) => {
    if (isDemoMode) {
      setExpenses((prev) =>
        prev.map((exp) => (exp.id === expenseId ? { ...exp, ...updates } : exp))
      );
      return { error: null };
    }

    const { error } = await supabase
      .from('expenses')
      .update(updates)
      .eq('id', expenseId);

    if (error) {
      console.error('Error updating expense:', error);
    }

    return { error };
  };

  const deleteExpense = async (expenseId: string) => {
    if (isDemoMode) {
      setExpenses((prev) => prev.filter((exp) => exp.id !== expenseId));
      return { error: null };
    }

    const { error } = await supabase.from('expenses').delete().eq('id', expenseId);

    if (error) {
      console.error('Error deleting expense:', error);
    }

    return { error };
  };

  return {
    expenses,
    loading,
    addExpense,
    updateExpense,
    deleteExpense,
    refreshExpenses: loadExpenses,
  };
}

