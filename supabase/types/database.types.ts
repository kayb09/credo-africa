export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  // Allows to automatically instantiate createClient with right options
  // instead of createClient<Database, { PostgrestVersion: 'XX' }>(URL, KEY)
  __InternalSupabase: {
    PostgrestVersion: "14.5"
  }
  public: {
    Tables: {
      activity_history: {
        Row: {
          activity_type: string
          business_id: string | null
          created_at: string | null
          id: string
          metadata: Json | null
        }
        Insert: {
          activity_type: string
          business_id?: string | null
          created_at?: string | null
          id?: string
          metadata?: Json | null
        }
        Update: {
          activity_type?: string
          business_id?: string | null
          created_at?: string | null
          id?: string
          metadata?: Json | null
        }
        Relationships: [
          {
            foreignKeyName: "activity_history_business_id_fkey"
            columns: ["business_id"]
            isOneToOne: false
            referencedRelation: "businesses"
            referencedColumns: ["id"]
          },
        ]
      }
      bot_sessions: {
        Row: {
          created_at: string | null
          data: Json | null
          phone: string
          step: number | null
        }
        Insert: {
          created_at?: string | null
          data?: Json | null
          phone: string
          step?: number | null
        }
        Update: {
          created_at?: string | null
          data?: Json | null
          phone?: string
          step?: number | null
        }
        Relationships: []
      }
      businesses: {
        Row: {
          age_years: number | null
          business_name: string | null
          business_type: string | null
          created_at: string | null
          employee_count: number | null
          has_bank_account: boolean | null
          id: string
          location: string | null
          monthly_revenue: number | null
          owner_id: string | null
        }
        Insert: {
          age_years?: number | null
          business_name?: string | null
          business_type?: string | null
          created_at?: string | null
          employee_count?: number | null
          has_bank_account?: boolean | null
          id?: string
          location?: string | null
          monthly_revenue?: number | null
          owner_id?: string | null
        }
        Update: {
          age_years?: number | null
          business_name?: string | null
          business_type?: string | null
          created_at?: string | null
          employee_count?: number | null
          has_bank_account?: boolean | null
          id?: string
          location?: string | null
          monthly_revenue?: number | null
          owner_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "businesses_owner_id_fkey"
            columns: ["owner_id"]
            isOneToOne: false
            referencedRelation: "owners"
            referencedColumns: ["id"]
          },
        ]
      }
      credit_scores: {
        Row: {
          business_id: string | null
          id: string
          score: number
          scored_at: string | null
          tier: string | null
        }
        Insert: {
          business_id?: string | null
          id?: string
          score: number
          scored_at?: string | null
          tier?: string | null
        }
        Update: {
          business_id?: string | null
          id?: string
          score?: number
          scored_at?: string | null
          tier?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "credit_scores_business_id_fkey"
            columns: ["business_id"]
            isOneToOne: false
            referencedRelation: "businesses"
            referencedColumns: ["id"]
          },
        ]
      }
      expense_entries: {
        Row: {
          amount: number
          business_id: string | null
          category: string | null
          created_at: string | null
          expense_date: string
          id: string
          notes: string | null
        }
        Insert: {
          amount: number
          business_id?: string | null
          category?: string | null
          created_at?: string | null
          expense_date: string
          id?: string
          notes?: string | null
        }
        Update: {
          amount?: number
          business_id?: string | null
          category?: string | null
          created_at?: string | null
          expense_date?: string
          id?: string
          notes?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "expense_entries_business_id_fkey"
            columns: ["business_id"]
            isOneToOne: false
            referencedRelation: "businesses"
            referencedColumns: ["id"]
          },
        ]
      }
      owners: {
        Row: {
          created_at: string | null
          full_name: string | null
          id: string
          phone: string
        }
        Insert: {
          created_at?: string | null
          full_name?: string | null
          id?: string
          phone: string
        }
        Update: {
          created_at?: string | null
          full_name?: string | null
          id?: string
          phone?: string
        }
        Relationships: []
      }
      revenue_entries: {
        Row: {
          amount: number
          business_id: string | null
          created_at: string | null
          entry_date: string
          id: string
          source: string | null
        }
        Insert: {
          amount: number
          business_id?: string | null
          created_at?: string | null
          entry_date: string
          id?: string
          source?: string | null
        }
        Update: {
          amount?: number
          business_id?: string | null
          created_at?: string | null
          entry_date?: string
          id?: string
          source?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "revenue_entries_business_id_fkey"
            columns: ["business_id"]
            isOneToOne: false
            referencedRelation: "businesses"
            referencedColumns: ["id"]
          },
        ]
      }
      supplier_records: {
        Row: {
          amount: number | null
          business_id: string | null
          created_at: string | null
          id: string
          purchase_date: string | null
          receipt_image_path: string | null
          supplier_name: string | null
        }
        Insert: {
          amount?: number | null
          business_id?: string | null
          created_at?: string | null
          id?: string
          purchase_date?: string | null
          receipt_image_path?: string | null
          supplier_name?: string | null
        }
        Update: {
          amount?: number | null
          business_id?: string | null
          created_at?: string | null
          id?: string
          purchase_date?: string | null
          receipt_image_path?: string | null
          supplier_name?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "supplier_records_business_id_fkey"
            columns: ["business_id"]
            isOneToOne: false
            referencedRelation: "businesses"
            referencedColumns: ["id"]
          },
        ]
      }
      trust_signals: {
        Row: {
          business_id: string | null
          confidence: number | null
          created_at: string | null
          id: string
          signal_type: string
        }
        Insert: {
          business_id?: string | null
          confidence?: number | null
          created_at?: string | null
          id?: string
          signal_type: string
        }
        Update: {
          business_id?: string | null
          confidence?: number | null
          created_at?: string | null
          id?: string
          signal_type?: string
        }
        Relationships: [
          {
            foreignKeyName: "trust_signals_business_id_fkey"
            columns: ["business_id"]
            isOneToOne: false
            referencedRelation: "businesses"
            referencedColumns: ["id"]
          },
        ]
      }
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      [_ in never]: never
    }
    Enums: {
      [_ in never]: never
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] &
        DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] &
        DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R
      }
      ? R
      : never
    : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I
      }
      ? I
      : never
    : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U
      }
      ? U
      : never
    : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends (DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never) = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends (PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never) = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  public: {
    Enums: {},
  },
} as const
