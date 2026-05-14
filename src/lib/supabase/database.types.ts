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
      categories: {
        Row: {
          client_id: string
          created_at: string
          id: string
          name: string
          sort_order: number
        }
        Insert: {
          client_id: string
          created_at?: string
          id?: string
          name: string
          sort_order?: number
        }
        Update: {
          client_id?: string
          created_at?: string
          id?: string
          name?: string
          sort_order?: number
        }
        Relationships: [
          {
            foreignKeyName: "categories_client_id_fkey"
            columns: ["client_id"]
            isOneToOne: false
            referencedRelation: "clients"
            referencedColumns: ["id"]
          },
        ]
      }
      clients: {
        Row: {
          business_number: string | null
          contract_end_date: string | null
          contract_start_date: string | null
          created_at: string
          deleted_at: string | null
          email: string | null
          factory_id: string
          id: string
          manager_name: string | null
          manager_phone: string | null
          name: string
        }
        Insert: {
          business_number?: string | null
          contract_end_date?: string | null
          contract_start_date?: string | null
          created_at?: string
          deleted_at?: string | null
          email?: string | null
          factory_id: string
          id?: string
          manager_name?: string | null
          manager_phone?: string | null
          name: string
        }
        Update: {
          business_number?: string | null
          contract_end_date?: string | null
          contract_start_date?: string | null
          created_at?: string
          deleted_at?: string | null
          email?: string | null
          factory_id?: string
          id?: string
          manager_name?: string | null
          manager_phone?: string | null
          name?: string
        }
        Relationships: [
          {
            foreignKeyName: "clients_factory_id_fkey"
            columns: ["factory_id"]
            isOneToOne: false
            referencedRelation: "factories"
            referencedColumns: ["id"]
          },
        ]
      }
      factories: {
        Row: {
          address: string | null
          created_at: string
          deleted_at: string | null
          id: string
          name: string
          phone: string | null
        }
        Insert: {
          address?: string | null
          created_at?: string
          deleted_at?: string | null
          id?: string
          name: string
          phone?: string | null
        }
        Update: {
          address?: string | null
          created_at?: string
          deleted_at?: string | null
          id?: string
          name?: string
          phone?: string | null
        }
        Relationships: []
      }
      inventory: {
        Row: {
          client_id: string
          factory_id: string
          id: string
          item_id: string
          quantity: number
          updated_at: string
        }
        Insert: {
          client_id: string
          factory_id: string
          id?: string
          item_id: string
          quantity?: number
          updated_at?: string
        }
        Update: {
          client_id?: string
          factory_id?: string
          id?: string
          item_id?: string
          quantity?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "inventory_client_id_fkey"
            columns: ["client_id"]
            isOneToOne: false
            referencedRelation: "clients"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "inventory_factory_id_fkey"
            columns: ["factory_id"]
            isOneToOne: false
            referencedRelation: "factories"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "inventory_item_id_fkey"
            columns: ["item_id"]
            isOneToOne: false
            referencedRelation: "items"
            referencedColumns: ["id"]
          },
        ]
      }
      inventory_logs: {
        Row: {
          after_quantity: number | null
          client_id: string
          created_at: string
          created_by: string | null
          factory_id: string
          id: string
          inventory_id: string
          item_id: string
          log_type: Database["public"]["Enums"]["log_type"]
          note: string | null
          processed_at: string
          quantity: number
          shipout_id: string | null
        }
        Insert: {
          after_quantity?: number | null
          client_id: string
          created_at?: string
          created_by?: string | null
          factory_id: string
          id?: string
          inventory_id: string
          item_id: string
          log_type: Database["public"]["Enums"]["log_type"]
          note?: string | null
          processed_at?: string
          quantity: number
          shipout_id?: string | null
        }
        Update: {
          after_quantity?: number | null
          client_id?: string
          created_at?: string
          created_by?: string | null
          factory_id?: string
          id?: string
          inventory_id?: string
          item_id?: string
          log_type?: Database["public"]["Enums"]["log_type"]
          note?: string | null
          processed_at?: string
          quantity?: number
          shipout_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "inventory_logs_client_id_fkey"
            columns: ["client_id"]
            isOneToOne: false
            referencedRelation: "clients"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "inventory_logs_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "inventory_logs_factory_id_fkey"
            columns: ["factory_id"]
            isOneToOne: false
            referencedRelation: "factories"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "inventory_logs_inventory_id_fkey"
            columns: ["inventory_id"]
            isOneToOne: false
            referencedRelation: "inventory"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "inventory_logs_item_id_fkey"
            columns: ["item_id"]
            isOneToOne: false
            referencedRelation: "items"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "inventory_logs_shipout_id_fkey"
            columns: ["shipout_id"]
            isOneToOne: false
            referencedRelation: "shipouts"
            referencedColumns: ["id"]
          },
        ]
      }
      invoice_attachments: {
        Row: {
          created_at: string
          file_name: string | null
          file_url: string
          id: string
          invoice_id: string
          mime_type: string | null
        }
        Insert: {
          created_at?: string
          file_name?: string | null
          file_url: string
          id?: string
          invoice_id: string
          mime_type?: string | null
        }
        Update: {
          created_at?: string
          file_name?: string | null
          file_url?: string
          id?: string
          invoice_id?: string
          mime_type?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "invoice_attachments_invoice_id_fkey"
            columns: ["invoice_id"]
            isOneToOne: false
            referencedRelation: "invoices"
            referencedColumns: ["id"]
          },
        ]
      }
      invoice_items: {
        Row: {
          amount: number
          category_name: string | null
          created_at: string
          id: string
          invoice_id: string
          item_name_en: string | null
          item_name_ko: string
          item_name_zh: string | null
          quantity: number
          sort_order: number
          unit_price: number
        }
        Insert: {
          amount?: number
          category_name?: string | null
          created_at?: string
          id?: string
          invoice_id: string
          item_name_en?: string | null
          item_name_ko: string
          item_name_zh?: string | null
          quantity?: number
          sort_order?: number
          unit_price?: number
        }
        Update: {
          amount?: number
          category_name?: string | null
          created_at?: string
          id?: string
          invoice_id?: string
          item_name_en?: string | null
          item_name_ko?: string
          item_name_zh?: string | null
          quantity?: number
          sort_order?: number
          unit_price?: number
        }
        Relationships: [
          {
            foreignKeyName: "invoice_items_invoice_id_fkey"
            columns: ["invoice_id"]
            isOneToOne: false
            referencedRelation: "invoices"
            referencedColumns: ["id"]
          },
        ]
      }
      invoice_memos: {
        Row: {
          content: string | null
          created_at: string
          created_by: string | null
          id: string
          invoice_id: string
          title: string | null
        }
        Insert: {
          content?: string | null
          created_at?: string
          created_by?: string | null
          id?: string
          invoice_id: string
          title?: string | null
        }
        Update: {
          content?: string | null
          created_at?: string
          created_by?: string | null
          id?: string
          invoice_id?: string
          title?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "invoice_memos_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "invoice_memos_invoice_id_fkey"
            columns: ["invoice_id"]
            isOneToOne: false
            referencedRelation: "invoices"
            referencedColumns: ["id"]
          },
        ]
      }
      invoices: {
        Row: {
          client_id: string
          created_at: string
          created_by: string | null
          discount: number
          factory_id: string
          id: string
          period_end: string
          period_start: string
          snapshot_client: Json | null
          snapshot_factory: Json | null
          subtotal: number
          total: number
          vat: number
        }
        Insert: {
          client_id: string
          created_at?: string
          created_by?: string | null
          discount?: number
          factory_id: string
          id?: string
          period_end: string
          period_start: string
          snapshot_client?: Json | null
          snapshot_factory?: Json | null
          subtotal?: number
          total?: number
          vat?: number
        }
        Update: {
          client_id?: string
          created_at?: string
          created_by?: string | null
          discount?: number
          factory_id?: string
          id?: string
          period_end?: string
          period_start?: string
          snapshot_client?: Json | null
          snapshot_factory?: Json | null
          subtotal?: number
          total?: number
          vat?: number
        }
        Relationships: [
          {
            foreignKeyName: "invoices_client_id_fkey"
            columns: ["client_id"]
            isOneToOne: false
            referencedRelation: "clients"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "invoices_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "invoices_factory_id_fkey"
            columns: ["factory_id"]
            isOneToOne: false
            referencedRelation: "factories"
            referencedColumns: ["id"]
          },
        ]
      }
      item_prices: {
        Row: {
          client_id: string
          created_at: string
          effective_from: string
          id: string
          item_id: string
          unit_price: number
        }
        Insert: {
          client_id: string
          created_at?: string
          effective_from: string
          id?: string
          item_id: string
          unit_price?: number
        }
        Update: {
          client_id?: string
          created_at?: string
          effective_from?: string
          id?: string
          item_id?: string
          unit_price?: number
        }
        Relationships: [
          {
            foreignKeyName: "item_prices_client_id_fkey"
            columns: ["client_id"]
            isOneToOne: false
            referencedRelation: "clients"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "item_prices_item_id_fkey"
            columns: ["item_id"]
            isOneToOne: false
            referencedRelation: "items"
            referencedColumns: ["id"]
          },
        ]
      }
      items: {
        Row: {
          category_id: string
          client_id: string
          created_at: string
          id: string
          name_en: string | null
          name_ko: string
          name_zh: string | null
          nickname: string | null
          sort_order: number
        }
        Insert: {
          category_id: string
          client_id: string
          created_at?: string
          id?: string
          name_en?: string | null
          name_ko: string
          name_zh?: string | null
          nickname?: string | null
          sort_order?: number
        }
        Update: {
          category_id?: string
          client_id?: string
          created_at?: string
          id?: string
          name_en?: string | null
          name_ko?: string
          name_zh?: string | null
          nickname?: string | null
          sort_order?: number
        }
        Relationships: [
          {
            foreignKeyName: "items_category_id_fkey"
            columns: ["category_id"]
            isOneToOne: false
            referencedRelation: "categories"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "items_client_id_fkey"
            columns: ["client_id"]
            isOneToOne: false
            referencedRelation: "clients"
            referencedColumns: ["id"]
          },
        ]
      }
      shipouts: {
        Row: {
          client_id: string
          created_at: string
          created_by: string | null
          deleted_at: string | null
          factory_id: string
          id: string
          memo: string | null
        }
        Insert: {
          client_id: string
          created_at?: string
          created_by?: string | null
          deleted_at?: string | null
          factory_id: string
          id?: string
          memo?: string | null
        }
        Update: {
          client_id?: string
          created_at?: string
          created_by?: string | null
          deleted_at?: string | null
          factory_id?: string
          id?: string
          memo?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "shipouts_client_id_fkey"
            columns: ["client_id"]
            isOneToOne: false
            referencedRelation: "clients"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "shipouts_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "shipouts_factory_id_fkey"
            columns: ["factory_id"]
            isOneToOne: false
            referencedRelation: "factories"
            referencedColumns: ["id"]
          },
        ]
      }
      profiles: {
        Row: {
          created_at: string
          deleted_at: string | null
          factory_id: string | null
          full_name: string | null
          id: string
          phone: string | null
          role: Database["public"]["Enums"]["user_role"]
        }
        Insert: {
          created_at?: string
          deleted_at?: string | null
          factory_id?: string | null
          full_name?: string | null
          id: string
          phone?: string | null
          role?: Database["public"]["Enums"]["user_role"]
        }
        Update: {
          created_at?: string
          deleted_at?: string | null
          factory_id?: string | null
          full_name?: string | null
          id?: string
          phone?: string | null
          role?: Database["public"]["Enums"]["user_role"]
        }
        Relationships: [
          {
            foreignKeyName: "profiles_factory_id_fkey"
            columns: ["factory_id"]
            isOneToOne: false
            referencedRelation: "factories"
            referencedColumns: ["id"]
          },
        ]
      }
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      create_item_with_price: {
        Args: {
          p_client_id: string
          p_category_id: string
          p_name_ko: string
          p_unit_price?: number
        }
        Returns: Json
      }
      delete_shipout: {
        Args: {
          p_shipout_id: string
          p_deleted_by: string
          p_restore_inventory?: boolean
        }
        Returns: Json
      }
      execute_shipout: {
        Args: {
          p_factory_id: string
          p_client_id: string
          p_items: Json
          p_created_by: string
          p_memo?: string | null
        }
        Returns: Json
      }
      process_inventory_delta: {
        Args: {
          p_factory_id: string
          p_client_id: string
          p_item_id: string
          p_delta: number
        }
        Returns: Json
      }
      update_shipout: {
        Args: {
          p_shipout_id: string
          p_items: Json
          p_updated_by: string
        }
        Returns: Json
      }
      get_unit_price: {
        Args: { p_date: string; p_item_id: string }
        Returns: number
      }
      my_factory_id: { Args: never; Returns: string }
      my_role: {
        Args: never
        Returns: Database["public"]["Enums"]["user_role"]
      }
      process_inventory_out: {
        Args: {
          p_created_by: string
          p_inventory_id: string
          p_note?: string
          p_quantity: number
        }
        Returns: Json
      }
      show_limit: { Args: never; Returns: number }
      show_trgm: { Args: { "": string }; Returns: string[] }
    }
    Enums: {
      log_type: "in" | "out"
      user_role: "super_admin" | "factory_admin" | "worker"
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
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never = never,
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
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
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
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
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
  EnumName extends DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never = never,
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
  CompositeTypeName extends PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  public: {
    Enums: {
      log_type: ["in", "out"],
      user_role: ["super_admin", "factory_admin", "worker"],
    },
  },
} as const
